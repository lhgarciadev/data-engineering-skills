# Engineering Query Patterns

The patterns section — a set of idioms every data engineer should be able to produce from memory, not derive from scratch.

A note on portability: the gaps-and-islands and sessionization examples below use PostgreSQL syntax for casts and interval arithmetic (`::int`, `INTERVAL '30 minutes'`) to keep the SQL concise. Neither runs unmodified elsewhere — BigQuery and SQL Server don't support `::` casts (use `CAST(x AS INT)`, or BigQuery's `SAFE_CAST`), and interval literals are engine-native (e.g., SQL Server has no `INTERVAL` type at all and needs `DATEADD`/`DATEDIFF`, BigQuery uses `INTERVAL 30 MINUTE` without quotes). Adapt the date/interval arithmetic to the target engine; the underlying window-function logic is portable even where the syntax isn't.

## Deduplication (canonical form)

Covered in full in [window-functions.md](window-functions.md): CTE + `ROW_NUMBER() OVER (PARTITION BY key ORDER BY updated_at DESC)` + filter to `rn = 1`. This is the pattern behind CDC deduplication and "keep the latest version of each row."

## Gaps and islands

Detecting consecutive runs (streaks) or gaps in a sequence — consecutive active days, session runs, missing dates in a time series. The standard trick: subtract a `ROW_NUMBER()` from the sequence value itself. Rows in the same contiguous run get the same difference, because both the sequence and the row number advance by 1 together within a run:

```sql
WITH numbered AS (
  SELECT
    user_id,
    activity_date,
    activity_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY activity_date))::int AS island_id
  FROM daily_activity
)
SELECT user_id, MIN(activity_date) AS streak_start, MAX(activity_date) AS streak_end, COUNT(*) AS streak_length
FROM numbered
GROUP BY user_id, island_id;
```

This shows up in user-session analysis and in detecting gaps in data pipelines themselves (missing partition dates).

## Sessionization

Group events into sessions when the gap between them exceeds a threshold, by combining `LAG` (time since the previous event) with a running sum of "session starts":

```sql
WITH gaps AS (
  SELECT
    user_id,
    event_time,
    event_time - LAG(event_time) OVER (PARTITION BY user_id ORDER BY event_time) > INTERVAL '30 minutes'
      AS is_new_session
  FROM events
),
sessions AS (
  SELECT
    *,
    SUM(CASE WHEN is_new_session OR is_new_session IS NULL THEN 1 ELSE 0 END)
      OVER (PARTITION BY user_id ORDER BY event_time
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS session_id
  FROM gaps
)
SELECT * FROM sessions;
```

The `session_id` running total needs the explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` frame, not the implicit default — see [window-functions.md](window-functions.md)'s RANGE vs ROWS trap. Without it, two events tied on `event_time` would fall under the same `RANGE` peer group and get bumped into the new session together, corrupting the session boundary exactly on the ties you'd least expect it.

## Pivoting and unpivoting

Pivot with conditional aggregation (see [aggregation-patterns.md](aggregation-patterns.md)). Unpivot with `UNION ALL` of one `SELECT` per source column, or the engine's native `UNPIVOT`/`LATERAL` construct where available — support and syntax for native unpivot vary by engine, so `UNION ALL` remains the portable default.

## Idempotent upserts with MERGE

The pattern that makes a load idempotent — the piece a report-writing analyst rarely touches, but a data engineer has to own (connects directly to the idempotency discussion in [python's production-patterns.md](../../python-data-engineering/references/production-patterns.md)):

```sql
MERGE INTO dim_customer t
USING staging_customer s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET t.name = s.name, t.email = s.email
WHEN NOT MATCHED THEN INSERT (customer_id, name, email)
                     VALUES (s.customer_id, s.name, s.email);
```

Re-running this doesn't duplicate rows — it updates what already exists and inserts what's new.

**Version note:** `MERGE` is standard across SQL Server, Oracle, Snowflake, and BigQuery, but in **PostgreSQL it only exists from v15 (October 2022)** — anything older needs an `INSERT ... ON CONFLICT DO UPDATE` upsert instead. `MERGE ... RETURNING` (and `merge_action()` to tell which branch fired) wasn't added until **PostgreSQL 17 (September 2024)** — don't write a `RETURNING`-based `MERGE` example against a PG15/16 target.

**Azure Synapse Analytics / Microsoft Fabric Warehouse note:** these two diverge sharply on `MERGE`, and the difference matters more than a version footnote — check which product you're actually targeting. Synapse dedicated SQL pools have supported `MERGE` since October 2020, but Microsoft's own docs still tag it **preview**, years later, with real restrictions: no `merge_hint` or `TOP`, `WHEN NOT MATCHED INSERT` doesn't work against `IDENTITY` columns, no table-value constructor in `USING`, and `WHEN NOT MATCHED BY TARGET` requires the target table to be `HASH`-distributed. Fabric Warehouse ships `MERGE` as a fully **generally available** feature with none of those dedicated-pool restrictions carried over. Since Fabric Warehouse is Microsoft's actively-developed successor to Synapse dedicated SQL pools (Microsoft's own migration guidance steers new workloads there), a `MERGE` pattern verified against one is not automatically safe on the other.

**Oracle note:** Oracle has had `MERGE` since 9i, and Oracle's own reference is explicit that "MERGE is a deterministic statement: you cannot update the same row of the target table multiple times in the same MERGE statement." If the source produces more than one row matching the same target row, Oracle doesn't silently apply one and drop the rest — it raises `ORA-30926` ("unable to get a stable set of rows in the source tables"). Oracle also allows exactly one `WHEN MATCHED` and one `WHEN NOT MATCHED` clause per statement (each can carry its own conditional `WHERE`, and `WHEN MATCHED` can nest a `DELETE WHERE` that only removes rows the same statement just matched/updated) — there's no SQL-Server-style multiple conditional branches or `WHEN NOT MATCHED BY SOURCE`.

## Incremental extraction: the watermark pattern

`MERGE` above solves the *write* side of incremental loading — once you have the changed rows, apply them idempotently. It doesn't solve the *read* side: how do you identify which rows are new or changed since the last run? That's the watermark (a.k.a. high-water-mark) pattern — a column holding either the last-updated timestamp or a monotonically incrementing key, filtered against the value captured at the end of the previous run:

```sql
SELECT *
FROM orders
WHERE updated_at > :last_watermark
  AND updated_at <= :current_watermark;
```

**The boundary choice is a real trade-off, not a style preference.** An exclusive-lower/inclusive-upper boundary (`>` ... `<=`, shown above) never re-reads the same row twice, but risks a gap: if a transaction commits *after* `:current_watermark` was captured, yet its `updated_at` timestamp is *before* that value (a slow transaction racing the watermark read), the row falls outside this run's window — and the next run's `last_watermark` has already moved past it, so it's silently skipped. An inclusive-lower boundary (`>=`) avoids that gap by re-reading the boundary row on every sync, at the cost of guaranteed duplicate emission on each run — which then needs downstream dedup, exactly the CTE + `ROW_NUMBER()` pattern from the top of this file. Neither boundary is "correct" in the abstract; which risk you'd rather own (silent gap vs. duplicate-then-dedupe) is the actual decision.

The watermark value itself needs to persist between runs somewhere — a small control table is the simplest SQL-native option:

```sql
CREATE TABLE watermark_control (
  source_table   TEXT PRIMARY KEY,
  last_watermark TIMESTAMP NOT NULL
);
```

updated only after the extraction run succeeds, never before — updating it first and failing partway through would silently drop rows on the next run.

**Timestamp vs. a monotonic sequence:** an application `updated_at` column depends on the application setting it correctly and on the row's transaction being visible by the time the watermark query runs — both can fail quietly. Where the source engine exposes a true monotonic change-sequence (SQL Server/Azure SQL's Change Tracking `SYS_CHANGE_VERSION` is the clearest example — a version number bumped on every insert *and* update, unlike a plain auto-increment primary key, which only ever catches new inserts and says nothing about updates to existing rows), prefer that over an application timestamp. This is a narrower claim than "IDs beat timestamps" — a raw PK isn't a substitute for a real change-sequence, and most sources don't expose one, so the timestamp watermark above remains the common case.

This is a polling pattern — it works against any source with a queryable `updated_at`/version column, on a schedule. Log-based CDC (reading the database's own transaction log — e.g. Debezium, or vendor binlog/WAL readers) is a fundamentally different, lower-latency mechanism that doesn't poll the table at all; it's out of scope here — see [`stream-processing-patterns.md`](../../streaming-data-engineering/references/stream-processing-patterns.md#cdc-as-a-stream) in `streaming-data-engineering` for the mechanics.

## Full load (truncate-and-reload)

Not every table needs incremental machinery. For small or infrequently-updated tables — most dimension tables, reference/lookup data — rebuilding the whole thing on every run is often simpler and just as fast as maintaining watermark state and upsert logic, and it can't drift out of sync with the source the way an incremental pipeline can if a run is ever silently skipped. Snowflake's own guidance states this directly: full table materialization is preferable for small, infrequently-updated tables, and incremental only pays off once the source is large and updates often; dbt's materialization guidance follows the same shape — start simple, add incrementality only once a full rebuild is measurably too slow.

**`TRUNCATE` is not a drop-in faster `DELETE`** — its transactional behavior genuinely diverges by engine, and assuming otherwise is the trap:

| Engine | Rollback-able in a transaction? | Can run inside a transaction at all? |
|---|---|---|
| PostgreSQL | Yes — transaction-safe by design | Yes |
| MySQL | No — implicit commit | **No** — DDL, cannot run inside a transaction |
| SQL Server | Yes — DDL, but still fully rollback-able | Yes |
| Snowflake | Classified as DML (like `DELETE`); no direct rollback example found in Snowflake's own docs, but the classification implies it behaves like one | Yes |
| BigQuery | Yes — DML, supported inside multi-statement transactions | Yes |
| Redshift | **No — commits the surrounding transaction immediately**, even mid-transaction | Runs, but commits on execution |

**Redshift is the gotcha most likely to bite someone who assumes "Redshift is Postgres."** It isn't, here: `TRUNCATE` on Redshift commits the transaction it runs in, full stop — `BEGIN; TRUNCATE t; ROLLBACK;` leaves the table empty, the exact opposite of vanilla PostgreSQL's behavior. MySQL is the strictest in the other direction — `TRUNCATE TABLE` can't be issued inside a transaction at all, since it's DDL that drops and recreates the table under the hood (which is also why it resets `AUTO_INCREMENT`, unlike an unqualified `DELETE`). Both engines also reject `TRUNCATE` on a table with incoming foreign-key references, with no `CASCADE` escape hatch the way PostgreSQL has one.

**The table above is only half the risk — the other half is at pipeline level, and no engine setting fixes it.** `TRUNCATE` followed by `INSERT` as two statements leaves the table **empty for as long as the load takes**, and if the load fails partway you are left with some tables reloaded and others empty. That second failure is *cross-table*, so per-statement transactional guarantees do not prevent it: it happens on PostgreSQL, where `TRUNCATE` rolls back cleanly, just as it does on Redshift. Ingestion tooling names the same trade-off from the other side — dlt ships three `replace` strategies whose entire difference is this: `truncate-and-insert` truncates first and inserts outside that transaction, `insert-from-staging` loads into staging and then truncates and inserts in one transaction, and `staging-optimized` buys speed by dropping and recreating the target, which takes any views or constraints on it along with it. That is the sharper argument for the swap pattern below, beyond downtime: it is the only shape that never publishes a partial state.

**A build-new-then-swap pattern beats truncate-and-reload for zero-downtime full refreshes**, but how well-supported it is varies sharply by engine — don't assume the same command exists everywhere:

- **Snowflake** has a purpose-built, genuinely atomic command: `ALTER TABLE t SWAP WITH t_new` renames two tables in a single transaction.
- **Redshift** documents a named pattern, "deep copy": build the replacement with `CREATE TABLE ... (...)` + `INSERT ... SELECT`, then `DROP` the original and `RENAME` the copy into place — not a rename-rename swap, an explicit drop-then-rename.
- **MySQL** supports an atomic multi-table `RENAME TABLE a TO tmp, b TO a, tmp TO b` swap, but its docs never connect this to `CREATE TABLE ... SELECT` as a named reload technique — you're composing two separately-documented primitives.
- **PostgreSQL and BigQuery** have the individual primitives (`CREATE TABLE AS`, `RENAME TO`) but no vendor-endorsed swap-for-reload pattern; BigQuery's own docs steer full-refresh use cases toward `CREATE OR REPLACE TABLE ... AS SELECT` or a `WRITE_TRUNCATE` load job instead.

**`dbt --full-refresh` is drop-and-recreate, not truncate-and-reload** — dbt drops the existing target table outright and rebuilds it from the model's `SELECT`, running in non-incremental mode. It's required (not optional) after removing a column from the model — `dbt run` without it fails outright — and dbt's own guidance recommends it after any change to incremental logic, though `on_schema_change` (`append_new_columns`/`sync_all_columns`) can reduce, not eliminate, how often it's needed; none of its modes backfill historical values for a newly added column. A full-refresh run ignores `unique_key` entirely — there's no matched/not-matched to key on, everything rebuilds from scratch.

## Slowly Changing Dimension Type 2

When a dimension attribute changes and you need to preserve history, you don't overwrite — you **close out the current row** (set an end-date and `is_current = false`) and **insert a new row** for the changed version, keyed by a surrogate key rather than the natural key alone. The mechanics are a two-statement pattern (or a single `MERGE` that fires both branches), not a modeling exercise:

```sql
-- Step 1: close out the current row for any customer whose attributes changed
UPDATE dim_customer
SET end_date = CURRENT_DATE, is_current = false
WHERE is_current = true
  AND customer_id IN (
    SELECT s.customer_id
    FROM staging_customer s
    JOIN dim_customer d
      ON d.customer_id = s.customer_id AND d.is_current = true
    WHERE s.email <> d.email OR s.address <> d.address
  );

-- Step 2: insert the new version as a fresh row, new surrogate key, open-ended
INSERT INTO dim_customer (customer_id, email, address, start_date, end_date, is_current)
SELECT s.customer_id, s.email, s.address, CURRENT_DATE, NULL, true
FROM staging_customer s
WHERE NOT EXISTS (
  SELECT 1 FROM dim_customer d
  WHERE d.customer_id = s.customer_id AND d.is_current = true
);
```

The same two branches collapse into a single `MERGE`, provided the engine's `MERGE` supports it — the `WHEN MATCHED` branch closes out the old row and the `WHEN NOT MATCHED` branch inserts the new one:

```sql
MERGE INTO dim_customer t
USING staging_customer s
ON t.customer_id = s.customer_id AND t.is_current = true
WHEN MATCHED AND (t.email <> s.email OR t.address <> s.address) THEN
  UPDATE SET end_date = CURRENT_DATE, is_current = false
WHEN NOT MATCHED THEN
  INSERT (customer_id, email, address, start_date, end_date, is_current)
  VALUES (s.customer_id, s.email, s.address, CURRENT_DATE, NULL, true);
```

Note the `MERGE` form above only closes the old row — it does **not** insert the new version in the same statement (a single `MERGE` can't both update an existing row and insert a fresh row for the same match), so it still needs the `INSERT` from Step 2 run afterward. This is why SCD Type 2 is usually written as the explicit two-statement `UPDATE` + `INSERT` pattern rather than forced into one `MERGE`. Being able to produce this SQL from memory — not just describe validity dates and a current-row flag conceptually — is what separates someone who has built a warehouse from someone who has only queried one.

This is the *implementation* side of SCD Type 2. For the *conceptual* side — when Type 2 is the right call versus Types 0/1/3/4/6, how surrogate keys and late-arriving facts/dimensions fit around it, and how a Type-2 dimension is used elsewhere in a star schema — see the `modeling-data-engineering` skill's [scd-and-dimension-patterns.md](../../modeling-data-engineering/references/scd-and-dimension-patterns.md).

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Blind `INSERT`/append on every load | Duplicates rows on any rerun or backfill | `MERGE` (or `INSERT ... ON CONFLICT` on Postgres < 15) keyed by natural/business key |
| Writing a `MERGE ... RETURNING` example without checking the Postgres version | Fails on PG15/16 — `RETURNING` support is PG17+ | Confirm target Postgres version, or use a separate `SELECT` to inspect affected rows on older versions |
| Overwriting a dimension row in place when history matters | Loses the ability to report "as it was at the time" | SCD Type 2: close the old row, insert a new one, surrogate key |
| Reaching for a self-join or procedural loop for gaps/islands or sessionization | Slower and far more code than the window-function idiom | Use the `ROW_NUMBER` subtraction trick (gaps/islands) or `LAG` + running sum (sessionization) |
| A staging table with duplicate keys feeding a `MERGE` on Oracle | Raises `ORA-30926` — Oracle refuses to update the same target row twice in one `MERGE` | Deduplicate the source (see [window-functions.md](window-functions.md)'s `ROW_NUMBER` pattern) before the `MERGE`, don't rely on the engine to pick one |
| Assuming Synapse dedicated SQL pool's `MERGE` restrictions apply to Fabric Warehouse (or vice versa) | They diverge — Synapse dedicated's `MERGE` is still preview with real restrictions (no `IDENTITY` inserts, `HASH`-distribution required); Fabric's is GA with none of those | Verify against the specific product — Fabric Warehouse is the actively-developed successor, not a drop-in-identical rebrand |
| Assuming Redshift's `TRUNCATE` is rollback-able because "Redshift is Postgres" | It commits the surrounding transaction immediately — the exact opposite of PostgreSQL's behavior | Verify per-engine before relying on `TRUNCATE` inside a transaction; never assume Redshift inherits PostgreSQL's semantics here |
| Wrapping `TRUNCATE TABLE` in an explicit transaction on MySQL | Fails outright — MySQL's `TRUNCATE` is DDL and cannot run inside a transaction at all | Use `DELETE` if the statement genuinely needs to run inside a transaction on MySQL |
| Treating an exclusive-lower watermark boundary (`>` ... `<=`) as risk-free | A transaction that commits after `:current_watermark` was captured, with an `updated_at` before it, is silently skipped and never reappears | Either accept the gap risk consciously, or switch to an inclusive-lower boundary and dedupe downstream |
| Running `dbt run` after removing a column from an incremental model, without `--full-refresh` | Fails outright — dbt can't reconcile the target table's existing schema with the model | Run `--full-refresh` after any incremental-logic or column-removal change |
