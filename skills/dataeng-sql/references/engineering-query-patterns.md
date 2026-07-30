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

The pattern that makes a load idempotent — the piece a report-writing analyst rarely touches, but a data engineer has to own (connects directly to the idempotency discussion in [python's production-patterns.md](../../dataeng-python/references/production-patterns.md)):

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

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Blind `INSERT`/append on every load | Duplicates rows on any rerun or backfill | `MERGE` (or `INSERT ... ON CONFLICT` on Postgres < 15) keyed by natural/business key |
| Writing a `MERGE ... RETURNING` example without checking the Postgres version | Fails on PG15/16 — `RETURNING` support is PG17+ | Confirm target Postgres version, or use a separate `SELECT` to inspect affected rows on older versions |
| Overwriting a dimension row in place when history matters | Loses the ability to report "as it was at the time" | SCD Type 2: close the old row, insert a new one, surrogate key |
| Reaching for a self-join or procedural loop for gaps/islands or sessionization | Slower and far more code than the window-function idiom | Use the `ROW_NUMBER` subtraction trick (gaps/islands) or `LAG` + running sum (sessionization) |
| A staging table with duplicate keys feeding a `MERGE` on Oracle | Raises `ORA-30926` — Oracle refuses to update the same target row twice in one `MERGE` | Deduplicate the source (see [window-functions.md](window-functions.md)'s `ROW_NUMBER` pattern) before the `MERGE`, don't rely on the engine to pick one |
| Assuming Synapse dedicated SQL pool's `MERGE` restrictions apply to Fabric Warehouse (or vice versa) | They diverge — Synapse dedicated's `MERGE` is still preview with real restrictions (no `IDENTITY` inserts, `HASH`-distribution required); Fabric's is GA with none of those | Verify against the specific product — Fabric Warehouse is the actively-developed successor, not a drop-in-identical rebrand |
