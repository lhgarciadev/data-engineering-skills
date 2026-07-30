# CTEs, Subqueries, and Recursion

## CTEs for readability and reuse

`WITH` clauses decompose a complex query into named, readable steps and avoid repeating a subquery. One nuance worth knowing, named per engine rather than gestured at: **PostgreSQL before version 12 always materializes a CTE** — a true optimization barrier, evaluated once and spooled to a temp result regardless of how the outer query uses it. **PostgreSQL 12+ flips the default**: the planner can inline a CTE like a subquery when that's cheaper, unless you force the old behavior explicitly with `AS MATERIALIZED`. **SQL Server never treats a CTE as a materialization barrier** — a CTE there is just an aliased subquery/view over the query text, always inlined into the surrounding plan. **Snowflake and BigQuery's optimizers likewise inline CTEs into the overall plan rather than materializing them by default.** Knowing your engine's specific behavior — and reaching for `AS MATERIALIZED` on PG12+ when you deliberately want the old barrier (e.g., to avoid re-evaluating an expensive volatile expression multiple times) — is a sign of depth beyond "I use CTEs for readability."

## Correlated vs non-correlated subqueries

A **correlated** subquery references a column from the outer query and gets re-evaluated once per outer row — potentially slow at scale. A **non-correlated** subquery is self-contained and evaluated once. Recognizing a slow correlated subquery and rewriting it as a join or a window function is a standard senior move:

```sql
-- correlated: re-evaluated per row of `orders`
SELECT *,
  (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = orders.id) AS item_count
FROM orders;

-- rewritten as a join + aggregate, evaluated once
SELECT o.*, COALESCE(oi.item_count, 0) AS item_count
FROM orders o
LEFT JOIN (SELECT order_id, COUNT(*) AS item_count FROM order_items GROUP BY order_id) oi
  ON oi.order_id = o.id;
```

## Recursive CTEs

For hierarchies (org charts, nested categories, bill-of-materials explosion) and for generating series (a date spine covering every date in a range). The pattern is an **anchor member**, `UNION ALL`, and a **recursive member** that joins back to the CTE itself, terminating when the recursive member returns no more rows:

```sql
WITH RECURSIVE org_chart AS (
  SELECT id, manager_id, name, 1 AS level
  FROM employees WHERE manager_id IS NULL        -- anchor: the root

  UNION ALL

  SELECT e.id, e.manager_id, e.name, o.level + 1
  FROM employees e
  JOIN org_chart o ON e.manager_id = o.id         -- recursive step
)
SELECT * FROM org_chart ORDER BY level;
```

**Recursive CTE support is not uniformly old across engines** — PostgreSQL has had `WITH RECURSIVE` since 8.4 (2009) and SQL Server since 2005, but **BigQuery only added `WITH RECURSIVE` in February 2022**, initially in preview; it reached general availability in March 2023. Don't assume a recursive-CTE pattern is safely portable to a BigQuery pipeline running on anything built before then.

**Azure Synapse Analytics and Microsoft Fabric Warehouse don't support recursive CTEs at all.** Unlike every other engine in this skill's scope — and unlike Oracle below — a self-referencing `WITH` clause is rejected outright on both: Microsoft's own T-SQL reference lists it as unsupported for Synapse dedicated SQL pools, and Fabric Warehouse's T-SQL surface-area documentation excludes recursive CTEs the same way (non-recursive, sequential, and nested CTEs all work fine on both — just not self-referencing ones). This isn't a preview-vs-GA gap like `MERGE` gets in [engineering-query-patterns.md](engineering-query-patterns.md); there's no supported path to true recursion in either product. The workaround is the one that predates recursive CTEs everywhere: unroll a bounded hierarchy depth with repeated self-joins, or move the recursion into the calling application.

**Oracle supports both forms, and the syntax has a real gotcha.** Oracle has had `CONNECT BY PRIOR ... START WITH` since long before the ANSI form existed, and added ANSI-style recursive subquery factoring in **Oracle Database 11g Release 2 (11.2.0.1)**. The gotcha: Oracle's `WITH` clause doesn't take (and doesn't support) the literal `RECURSIVE` keyword — recursion is inferred automatically whenever a `WITH` query references its own name, so the query above runs on Oracle only after dropping the word `RECURSIVE` (`WITH org_chart AS (...)`, not `WITH RECURSIVE org_chart AS (...)`). Oracle's own docs frame recursive `WITH` as strictly more capable than `CONNECT BY` (it adds `SEARCH`/`CYCLE` clauses for ordering and cycle detection, and supports multiple recursive branches), but `CONNECT BY` remains fully supported and stays the terser, idiomatic choice for a simple single-root hierarchy.

## The senior framing

CTEs are for legibility and for expressing recursion — not a performance tool by default, and not always free of cost depending on the engine. Recognize a correlated subquery that should be a join or window function on sight.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Writing a correlated subquery instead of a join for a per-row aggregate | Re-evaluates once per outer row — slow at scale | Rewrite as a join against a pre-aggregated subquery, or a window function |
| Assuming a CTE is never an optimization barrier | On pre-12 PostgreSQL it always is; SQL Server, Snowflake, and BigQuery inline it, so the barrier isn't universal either | Know your engine's CTE inlining behavior; force materialization with `AS MATERIALIZED` on PG12+ if needed |
| Assuming `WITH RECURSIVE` works identically on any warehouse | BigQuery only added it in 2022 (GA since March 2023) | Confirm platform version/support before relying on it |
| Reaching for recursion to generate a date range when a built-in generator exists | More verbose than necessary on engines with native series generation (e.g. Postgres `GENERATE_SERIES`) | Prefer the engine's native series-generation function when available |
| Writing `WITH RECURSIVE` on Oracle | Fails — Oracle infers recursion automatically and doesn't accept the `RECURSIVE` keyword | Drop the keyword: `WITH query_name AS (...)`, same as any other CTE there |
| Reaching for a recursive CTE on Synapse dedicated SQL pool or Fabric Warehouse | Rejected outright — neither supports self-referencing CTEs, with no keyword workaround | Unroll a bounded hierarchy with repeated joins, or move the recursion to the calling application |
