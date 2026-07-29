# Engineering Query Patterns

The patterns section — a set of idioms every data engineer should be able to produce from memory, not derive from scratch.

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
      OVER (PARTITION BY user_id ORDER BY event_time) AS session_id
  FROM gaps
)
SELECT * FROM sessions;
```

## Pivoting and unpivoting

Pivot with conditional aggregation (see [aggregation-patterns.md](aggregation-patterns.md)). Unpivot with `UNION ALL` of one `SELECT` per source column, or the engine's native `UNPIVOT`/`LATERAL` construct where available — support and syntax for native unpivot vary by engine, so `UNION ALL` remains the portable default.

## Idempotent upserts with MERGE

The pattern that makes a load idempotent — the piece a report-writing analyst rarely touches, but a data engineer has to own (connects directly to the idempotency discussion in [python's production-patterns.md](../../python/references/production-patterns.md)):

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

**Oracle note:** Oracle's `MERGE` support and restriction details (e.g., limits on matching a target row more than once per statement) have not been verified against Oracle documentation for this skill — confirm before treating Oracle-specific `MERGE` details in this section as authoritative.

## Slowly Changing Dimension Type 2

When a dimension attribute changes and you need to preserve history, you don't overwrite — you **close out the current row** (set an end-date and `is_current = false`) and **insert a new row** for the changed version, keyed by a surrogate key rather than the natural key alone. Being able to describe the mechanics precisely — validity dates, a current-row flag, a surrogate key that lets the same natural key have multiple historical rows — is what separates someone who has built a warehouse from someone who has only queried one.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Blind `INSERT`/append on every load | Duplicates rows on any rerun or backfill | `MERGE` (or `INSERT ... ON CONFLICT` on Postgres < 15) keyed by natural/business key |
| Writing a `MERGE ... RETURNING` example without checking the Postgres version | Fails on PG15/16 — `RETURNING` support is PG17+ | Confirm target Postgres version, or use a separate `SELECT` to inspect affected rows on older versions |
| Overwriting a dimension row in place when history matters | Loses the ability to report "as it was at the time" | SCD Type 2: close the old row, insert a new one, surrogate key |
| Reaching for a self-join or procedural loop for gaps/islands or sessionization | Slower and far more code than the window-function idiom | Use the `ROW_NUMBER` subtraction trick (gaps/islands) or `LAG` + running sum (sessionization) |
