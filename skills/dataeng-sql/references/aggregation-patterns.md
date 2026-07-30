# Aggregation Patterns

## Counting, precisely

`COUNT(*)` counts rows, including ones with NULLs anywhere in them. `COUNT(column)` counts only the non-NULL values in that column. `COUNT(DISTINCT column)` counts distinct non-NULL values. Mixing these up produces a metric that's subtly wrong rather than obviously broken — the query runs fine, the number is just not what you think it is.

```sql
SELECT
  COUNT(*)                    AS total_rows,
  COUNT(shipped_at)           AS shipped_rows,        -- NULLs in shipped_at excluded
  COUNT(DISTINCT customer_id) AS distinct_customers
FROM orders;
```

`GROUP BY` groups rows before aggregating; `HAVING` filters those groups after the aggregate is computed — see [query-execution-and-null-semantics.md](query-execution-and-null-semantics.md) for why a condition on an aggregate can't live in `WHERE`.

## Conditional aggregation (pivoting with CASE)

Instead of running separate queries per condition, aggregate by condition within the same pass — the pattern behind most hand-built pivot tables:

```sql
SELECT
  customer_id,
  SUM(CASE WHEN status = 'paid'    THEN amount ELSE 0 END) AS total_paid,
  SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END) AS total_pending
FROM orders
GROUP BY customer_id;
```

The SQL-standard `FILTER (WHERE ...)` clause expresses the same intent more cleanly:

```sql
SELECT
  customer_id,
  COUNT(*) FILTER (WHERE status = 'paid') AS num_paid
FROM orders
GROUP BY customer_id;
```

**`FILTER` is not the "portable" form it's often assumed to be — check the target engine first:**

| Engine | `FILTER (WHERE ...)` support |
|---|---|
| PostgreSQL | Yes, since 9.4 |
| BigQuery | Yes |
| Snowflake | **No — not supported at all**; `CASE WHEN` is the only option |
| SQL Server | Only from SQL Server 2025 — not available in 2016–2022, still the majority of deployed instances |
| MySQL | Only from 9.7.0 — not available in 8.0/8.4, the current LTS lines |

In practice, for anything that has to run on Snowflake, current SQL Server, or current MySQL, `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` isn't a fallback — it's the only form that works today. Treat `FILTER` as a Postgres/BigQuery convenience, not a cross-engine default.

## Subtotals in one pass: GROUPING SETS, ROLLUP, CUBE

When a report needs subtotals across several combinations of dimensions, computing them in one pass beats running (and unioning) several separate `GROUP BY` queries:

- `ROLLUP(region, product)` produces rows grouped by `(region, product)`, by `(region)` alone, and a grand total.
- `CUBE(region, product)` produces every combination: `(region, product)`, `(region)`, `(product)`, and the grand total.
- `GROUPING SETS((region, product), (region), ())` lets you specify exactly which combinations you want, when ROLLUP/CUBE would generate more than you need.

```sql
SELECT region, product, SUM(amount)
FROM sales
GROUP BY ROLLUP (region, product);
```

**Engine support is not universal** — the one real gap: **MySQL (through at least 8.4) supports only `ROLLUP`** (via `WITH ROLLUP` or standard `GROUP BY ... ROLLUP()` syntax since 8.0.12); it has no native `CUBE` or `GROUPING SETS`, which have to be emulated with `UNION ALL` of separate `GROUP BY` queries. PostgreSQL (9.5+), SQL Server, Snowflake, and BigQuery support all three.

In a pre-computed aggregates pipeline, reaching for these instead of unioning several queries by hand is what separates someone who's only used a flat `GROUP BY` from someone who's built reporting tables at scale.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Confusing `COUNT(*)` with `COUNT(column)` | Silently wrong metric when the column has NULLs | Pick deliberately based on whether NULLs should count |
| Assuming `FILTER (WHERE ...)` runs everywhere | Fails outright on Snowflake; unavailable on current SQL Server/MySQL | Use `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` unless the target engine is confirmed to support FILTER |
| Assuming `CUBE`/`GROUPING SETS` work on MySQL | Not supported through 8.4 — query fails | Emulate with `UNION ALL`, or use `ROLLUP` if that's sufficient |
| Running N separate GROUP BY queries for N subtotal levels | Wasteful, multiple passes over the data | `ROLLUP`/`CUBE`/`GROUPING SETS` compute them in one pass |
