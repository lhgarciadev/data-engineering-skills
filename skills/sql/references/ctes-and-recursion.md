# CTEs, Subqueries, and Recursion

## CTEs for readability and reuse

`WITH` clauses decompose a complex query into named, readable steps and avoid repeating a subquery. One nuance worth knowing: in some engines a CTE is an **optimization barrier** — it gets materialized as-is and isn't fused with the rest of the query plan — while in others (modern PostgreSQL, since 12) the planner can inline it like a subquery when that's cheaper. In cloud warehouses this generally doesn't matter for performance, but knowing the difference exists — and checking your engine's specific behavior when a CTE-heavy query is unexpectedly slow — is a sign of depth beyond "I use CTEs for readability."

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

**Recursive CTE support is not uniformly old across engines** — PostgreSQL has had `WITH RECURSIVE` since 8.4 (2009) and SQL Server since 2005, but **BigQuery only added `WITH RECURSIVE` around February 2022** (initially as a preview feature). Don't assume a recursive-CTE pattern is safely portable to a BigQuery pipeline without confirming the platform version, especially for anything built before 2022.

**Oracle note:** Oracle traditionally expresses hierarchical queries with `CONNECT BY PRIOR` rather than (or alongside) an ANSI recursive `WITH` clause — the exact current support, syntax, and any behavioral differences from `WITH RECURSIVE` have not been verified against Oracle documentation for this skill and should be confirmed before relying on this section for an Oracle target.

## The senior framing

CTEs are for legibility and for expressing recursion — not a performance tool by default, and not always free of cost depending on the engine. Recognize a correlated subquery that should be a join or window function on sight.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Writing a correlated subquery instead of a join for a per-row aggregate | Re-evaluates once per outer row — slow at scale | Rewrite as a join against a pre-aggregated subquery, or a window function |
| Assuming a CTE never affects the query plan | On engines where it's an optimization barrier, it can force a suboptimal plan | Check the specific engine's CTE materialization behavior when a CTE-heavy query is unexpectedly slow |
| Assuming `WITH RECURSIVE` works identically on any warehouse | BigQuery only added it in ~2022 | Confirm platform version/support before relying on it |
| Reaching for recursion to generate a date range when a built-in generator exists | More verbose than necessary on engines with native series generation (e.g. Postgres `GENERATE_SERIES`) | Prefer the engine's native series-generation function when available |
