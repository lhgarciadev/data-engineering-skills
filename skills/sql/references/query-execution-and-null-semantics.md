# Query Execution Order and NULL Semantics

Two ideas that order everything else in SQL, and the fastest way to tell a mid-level query writer from a senior one.

## Logical execution order

SQL doesn't run in the order you write it. The logical processing order is:

```
FROM/JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT
```

Three consequences follow directly, and interviewers test all three:

- **You can't reference a SELECT alias in WHERE — on PostgreSQL, MySQL, SQL Server, and BigQuery.** WHERE runs before SELECT, so the alias doesn't exist yet:
  ```sql
  -- fails on PostgreSQL, MySQL, SQL Server, BigQuery: "column total_price does not exist" (alias not yet defined)
  SELECT price * qty AS total_price FROM orders WHERE total_price > 100;

  -- works everywhere: repeat the expression, or move the filter to an outer query
  SELECT price * qty AS total_price FROM orders WHERE price * qty > 100;
  ```
  **Snowflake is a genuine, documented exception, not "some engines allow it."** Snowflake's own SQL Command Reference (SELECT page, Usage Notes) states that a SELECT-list column alias can be referenced in that same query's WHERE clause (and its JOIN, FROM, and GROUP BY too) — the first query above runs fine, unmodified, on Snowflake. This isn't true alias binding, though: Snowflake re-evaluates the aliased expression rather than reusing a computed value, so it's expression substitution, not scoping. That distinction matters the moment the expression is non-deterministic (a UDF with side effects, `RANDOM()`, a sequence) — WHERE can evaluate to something different than what SELECT displayed. Don't port this assumption to any other engine, and don't lean on it even on Snowflake for anything non-deterministic.
- **WHERE filters rows before grouping; HAVING filters groups after aggregating.** A condition on a raw column belongs in WHERE (cheaper — discards rows before the aggregation work); a condition on an aggregate result (`SUM(...)`, `COUNT(...)`) has to go in HAVING, because the aggregate doesn't exist until GROUP BY has run.
- **Window functions evaluate in the SELECT phase — after HAVING, before DISTINCT/ORDER BY.** You cannot filter directly on a window function's result in WHERE (it doesn't exist there yet) or HAVING (window functions aren't aggregates). Wrap the query in a subquery or CTE and filter the outer layer:
  ```sql
  -- fails: window functions are not allowed in WHERE
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) AS rn
  FROM orders
  WHERE rn = 1;

  -- works
  WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) AS rn
    FROM orders
  )
  SELECT * FROM ranked WHERE rn = 1;
  ```
  On Snowflake, BigQuery, and Redshift, `QUALIFY` filters a window function's result directly, without the CTE wrap — see [window-functions.md](window-functions.md) for the syntax and why PostgreSQL/MySQL/SQL Server still need the CTE form.

This underlying logical order — WHERE conceptually evaluated before SELECT, aggregates before HAVING, window functions after HAVING — holds across PostgreSQL, MySQL, SQL Server, Snowflake, and BigQuery; it's ANSI logical processing, not an engine quirk. Snowflake's alias-in-WHERE support (above) doesn't change that order — it's a documented syntax convenience layered on top via expression substitution, not a different evaluation sequence.

## NULL and three-valued logic

SQL comparisons don't evaluate to true/false — they evaluate to **true / false / unknown**. `NULL = NULL` is not true, it's unknown; that's why you compare with `IS NULL` / `IS NOT NULL` instead of `=`. WHERE and HAVING keep a row only when the condition is true — both false and unknown get dropped.

The trap that bites most often:

**`NOT IN` with a NULL in the list returns zero rows.** `x NOT IN (a, b, NULL)` expands to `x <> a AND x <> b AND x <> NULL`. That last comparison is unknown, and combining it with `AND` poisons the whole expression to unknown — so **every row** gets dropped, silently, with no error thrown. This is standard-mandated three-valued-logic behavior, not an optimizer bug, and it's identical across PostgreSQL, MySQL, SQL Server, Snowflake, and BigQuery.

```sql
-- silently returns ZERO rows if any customer_id in the subquery is NULL
SELECT * FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders);

-- correct: NOT EXISTS is NULL-safe
SELECT * FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
```

Default to `NOT EXISTS` for anti-joins. Reach for `NOT IN` only when you can prove the right-hand column is `NOT NULL` — and even then, `NOT EXISTS` costs nothing and removes the risk entirely.

**Aggregates ignore NULLs — except `COUNT(*)`.** `SUM`, `AVG`, `MIN`, `MAX`, and `COUNT(column)` skip NULLs in the aggregated column; `COUNT(*)` counts rows regardless of what's NULL in them. `AVG(discount)` averages only the non-NULL discounts — if NULL means "no discount applied" rather than "unknown," that's the wrong average, and you want `AVG(COALESCE(discount, 0))` instead. `SUM` of zero rows returns NULL, not zero — a downstream `COALESCE` is often needed to avoid propagating that NULL further.

**Two functions to reach for:**
- `COALESCE(a, b, c)` returns the first non-NULL argument — the general-purpose default-value tool.
- `NULLIF(a, b)` returns NULL if `a = b`, otherwise `a` — built specifically to defuse division by zero: `x / NULLIF(y, 0)` returns NULL instead of erroring when `y` is 0.

## The senior framing

NULLs aren't a syntax detail in data engineering — they're a data-quality problem wearing a syntax costume. A `NOT IN` written against a column that "usually" has no NULLs but occasionally does can silently empty a pipeline's output with no error, no warning, just zero rows downstream. Audit nullability on join/filter columns before writing the query, and default to `NOT EXISTS` over `NOT IN` as a habit, not a case-by-case judgment call.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Referencing a SELECT alias inside WHERE | Fails — WHERE runs before SELECT in logical order | Repeat the expression, or filter in an outer query/CTE |
| Filtering an aggregate result in WHERE | Fails — the aggregate doesn't exist until GROUP BY runs | Use HAVING for aggregate conditions |
| Filtering a window function's result directly in WHERE | Fails — window functions evaluate in SELECT, after WHERE/HAVING | Wrap in a CTE/subquery, filter the outer layer |
| `NOT IN` against a column that can contain NULL | Silently returns zero rows, no error | Use `NOT EXISTS` |
| Comparing to NULL with `= NULL` | Always unknown, row is dropped | Use `IS NULL` / `IS NOT NULL` |
| Trusting `AVG(col)` when NULL means "zero," not "unknown" | Averages only non-NULL rows — wrong denominator | `AVG(COALESCE(col, 0))` when NULL means zero |
