# Window Functions

The flagship topic — this is where window functions replace expensive self-joins and imperative logic with a single declarative pass, and where the line between mid-level and senior SQL is clearest.

## Anatomy

A window function computes across a set of related rows *without collapsing them* — unlike `GROUP BY`, every input row survives in the output. The shape is:

```sql
function() OVER (PARTITION BY ... ORDER BY ... frame_clause)
```

- `PARTITION BY` defines the groups the function operates within (like `GROUP BY`, but without collapsing rows).
- `ORDER BY` defines the order within each partition — required for ranking, `LAG`/`LEAD`, and running calculations.
- The **frame clause** defines exactly which rows, relative to the current one, participate in the calculation (see below — this is where most of the subtlety lives).

## Ranking: ROW_NUMBER vs RANK vs DENSE_RANK

The difference is entirely in how ties are handled — and it's asked about almost every time:

| Function | Ties | Example output (two rows tied for 1st) |
|---|---|---|
| `ROW_NUMBER()` | Unique, sequential — ties broken arbitrarily | 1, 2, 3, 4 |
| `RANK()` | Same rank for ties, **leaves gaps** afterward | 1, 1, 3, 4 |
| `DENSE_RANK()` | Same rank for ties, **no gaps** | 1, 1, 2, 3 |

### Deduplication — the canonical engineering pattern

"Keep only the most recent record per customer" is a `ROW_NUMBER` problem, not a self-join problem:

```sql
WITH ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) AS rn
  FROM events
)
SELECT * FROM ranked WHERE rn = 1;
```

**CTE + `ROW_NUMBER` + filter to `rn = 1`** is the pattern behind CDC deduplication, "latest version of each row," and general duplicate cleanup. It should come out automatically — that fluency is a direct senior signal.

### Top-N per group

"Top 3 best-selling products per category":

```sql
SELECT * FROM (
  SELECT *, DENSE_RANK() OVER (PARTITION BY category ORDER BY sales DESC) AS rnk
  FROM products
) ranked
WHERE rnk <= 3;
```

The choice between `RANK` and `DENSE_RANK` here depends on intent: do you want exactly 3 rows, or "everyone tied for 3rd place too"? `ROW_NUMBER` would give exactly 3 rows but arbitrarily picks which of several ties to include — usually the wrong choice for a "top N" business question.

## Comparing rows: LAG / LEAD

Access the previous or next row's value within the same partition — built for deltas, period-over-period growth, or time between events:

```sql
SELECT
  sale_date,
  revenue,
  revenue - LAG(revenue) OVER (ORDER BY sale_date) AS delta_vs_prior_day
FROM daily_sales;
```

## Running totals and moving averages: the frame clause

This is the detail that separates someone who's used window functions from someone who actually understands them. A running total is:

```sql
SUM(amount) OVER (ORDER BY sale_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
```

A 7-day moving average is:

```sql
AVG(amount) OVER (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
```

### The RANGE vs ROWS trap

When `ORDER BY` is present with no explicit frame, the default is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` — **not `ROWS`**. This holds for PostgreSQL, SQL Server, MySQL 8.0+, and BigQuery. `RANGE` treats every row *tied* on the `ORDER BY` value as occupying the same logical position: if two sales happen to fall on the same date, a "running total" over `ORDER BY sale_date` with the implicit `RANGE` default includes **both** tied rows' amounts at each of those rows — producing a total that jumps unexpectedly on tie dates instead of accumulating strictly row-by-row. `ROWS` counts one row at a time regardless of ties. Knowing that the default is `RANGE`, and where it bites, is one of the details that reliably impresses in a senior technical conversation.

**Snowflake is the real exception, and it's more specific than "some engines differ":** for aggregate functions (`SUM`, `COUNT`, `AVG`, etc.) Snowflake's default *does* follow the ANSI `RANGE` default described above. But for value functions — `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE` — Snowflake's default frame is `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`. Snowflake's own documentation states this does **not** comply with the ANSI standard and recommends always specifying an explicit frame rather than relying on the default in any case. Name Snowflake specifically when this comes up — don't gesture vaguely at "engine differences."

## The senior framing

Window functions exist to avoid expensive self-joins and to express logic that would otherwise be imperative — deduplication, sessionization, row-to-row comparison — declaratively, in one pass. And always be explicit about the frame: the implicit `RANGE` default is a source of silent bugs in running totals the moment the ordering column has ties.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Using `RANK` when you want exactly N rows for "top N" | Gaps mean you might get more or fewer rows than expected depending on ties | Use `ROW_NUMBER` for exactly N, `DENSE_RANK`/`RANK` for "N places, ties included" |
| Relying on the implicit frame default for a running total | Silently switches to peer-inclusive `RANGE` behavior on tied ORDER BY values | Always write `ROWS BETWEEN ... AND CURRENT ROW` explicitly |
| Assuming Snowflake's default frame matches Postgres/SQL Server | Diverges for value functions (`FIRST_VALUE`/`LAST_VALUE`/`NTH_VALUE`) | Always specify the frame explicitly on Snowflake, per Snowflake's own recommendation |
| Solving deduplication with a self-join on `MAX(updated_at)` | Correct but slower and more verbose than necessary | `ROW_NUMBER() OVER (PARTITION BY key ORDER BY updated_at DESC)` + filter `rn = 1` |
