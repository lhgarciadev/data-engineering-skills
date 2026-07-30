---
name: dataeng-sql
description: SQL query writing, review, and optimization guidance — joins, aggregations, window functions, CTEs, query optimization, and procedural extensions (PL/SQL, T-SQL, PL/pgSQL, MySQL stored routines). Use when writing, reviewing, or optimizing a query, or diagnosing one that's slow, wrong, or a misbehaving stored procedure. Primary engines — PostgreSQL, MySQL, SQL Server, Snowflake, BigQuery, and Redshift — plus targeted Oracle, Azure Synapse Analytics, and Microsoft Fabric Warehouse notes; see Overview for exact scope. Does not cover schema/dimensional modeling (see dataeng-data-modeling).
---

# SQL for Data Engineering

## Overview

Senior-level judgment calls for writing, reviewing, and optimizing SQL — which construct to reach for, which trap it avoids, and how it behaves differently across engines. Each reference file pairs a concept with the failure mode it exists to prevent, and calls out where PostgreSQL, MySQL, SQL Server, Snowflake, BigQuery, and Redshift genuinely diverge rather than assuming one engine's behavior is universal. For Oracle's declarative SQL specifically, and for Azure Synapse Analytics/Microsoft Fabric Warehouse, coverage is targeted to only what's been independently verified — recursive CTEs, MERGE, and (for Synapse/Fabric) distribution/cost model — not the full six-engine treatment; check the relevant reference file before relying on this skill for other declarative behavior on any of the three. Synapse dedicated SQL pools and Fabric Warehouse are related but distinct products (Fabric is Microsoft's actively-developed successor) and genuinely diverge on some of these points — don't treat them as interchangeable. Procedural extensions (PL/SQL, T-SQL, PL/pgSQL, MySQL stored routines) are a separate exception to "targeted": [procedural-extensions.md](references/procedural-extensions.md) covers all four at the same fundamentals-to-senior depth as the rest of this skill, not a narrow note. Read the relevant file(s) before writing or reviewing a query; don't rely on the table below alone.

## When to use

- Writing or reviewing an analytical query: joins, aggregations, window functions, CTEs
- A query returns the wrong row count or a suspiciously large/small aggregate result
- Deduplicating records, finding gaps/streaks, sessionizing events, or writing an idempotent upsert
- A query is slow and the cause isn't obvious
- Deciding how to index a table, or reading an execution plan
- Checking whether a query pattern is portable across engines (Postgres, MySQL, SQL Server, Snowflake, BigQuery, Redshift)
- Not for schema or dimensional modeling design (star schema, SCDs at the modeling level) — that's `dataeng-data-modeling`
- Writing or reviewing a stored procedure/function in Oracle PL/SQL, SQL Server T-SQL, PostgreSQL PL/pgSQL, or MySQL — cursors, exception handling, dynamic SQL, transaction control

## Quick reference

| Concern | Reach for | Reference |
|---|---|---|
| A SELECT alias doesn't work in WHERE | Understand logical execution order | [query-execution-and-null-semantics.md](references/query-execution-and-null-semantics.md) |
| `NOT IN` returns zero rows unexpectedly | Three-valued logic with NULL; use `NOT EXISTS` instead | [query-execution-and-null-semantics.md](references/query-execution-and-null-semantics.md) |
| A LEFT JOIN behaves like an INNER JOIN | Move the right-table condition from WHERE into ON | [joins.md](references/joins.md) |
| An aggregate after a join is inflated | Check for fan-out — non-unique join key multiplying rows | [joins.md](references/joins.md) |
| "Customers with no orders" | Anti-join via `NOT EXISTS`, not `NOT IN` | [joins.md](references/joins.md) |
| A pivot-table-style report in one query | Conditional aggregation (`CASE`/`FILTER`, engine-dependent) | [aggregation-patterns.md](references/aggregation-patterns.md) |
| Subtotals across several dimension combinations | `ROLLUP`/`CUBE`/`GROUPING SETS` | [aggregation-patterns.md](references/aggregation-patterns.md) |
| "Keep only the latest row per key" | `ROW_NUMBER()` + CTE + filter `rn = 1` | [window-functions.md](references/window-functions.md) |
| Top-N per group, period-over-period deltas | `RANK`/`DENSE_RANK`, `LAG`/`LEAD` | [window-functions.md](references/window-functions.md) |
| A running total jumps unexpectedly on tied dates | Implicit `RANGE` frame default — make the frame explicit (`ROWS ...`) | [window-functions.md](references/window-functions.md) |
| Filtering a window function's result on Snowflake/BigQuery/Redshift | `QUALIFY` clause (no CTE needed) | [window-functions.md](references/window-functions.md) |
| A slow correlated subquery | Rewrite as a join or window function | [ctes-and-recursion.md](references/ctes-and-recursion.md) |
| Org charts, nested categories, date spines | Recursive CTE (`WITH RECURSIVE`, anchor + `UNION ALL`) | [ctes-and-recursion.md](references/ctes-and-recursion.md) |
| Consecutive streaks or gaps in a sequence | Gaps-and-islands (`ROW_NUMBER` subtraction trick) | [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| Grouping events into sessions | `LAG` + running sum of session starts | [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| A load needs to be safely re-runnable | `MERGE` (or `INSERT ... ON CONFLICT` pre-PG15) keyed by business key | [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| Preserving dimension history on change | SCD Type 2 (end-date, is_current flag, surrogate key) | [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| A query is slow and the cause isn't obvious | Read `EXPLAIN`/`EXPLAIN ANALYZE` before touching anything | [query-optimization-and-production.md](references/query-optimization-and-production.md) |
| Deciding whether/how to index a column | B-tree cost, leftmost-prefix rule, GIN/GiST/BRIN | [query-optimization-and-production.md](references/query-optimization-and-production.md) |
| Query is slow/expensive on a cloud warehouse | Partition pruning, predicate/projection pushdown, per-engine cost model | [query-optimization-and-production.md](references/query-optimization-and-production.md) |
| A procedural loop processes rows one at a time | RBAR anti-pattern — rewrite as a set-based query first | [procedural-extensions.md](references/procedural-extensions.md) |
| A stored procedure needs to commit/rollback mid-execution | Only PROCEDURE (not FUNCTION) can in Postgres/MySQL; Oracle functions need `PRAGMA AUTONOMOUS_TRANSACTION` | [procedural-extensions.md](references/procedural-extensions.md) |
| A T-SQL procedure is fast for one caller, slow for another | Parameter sniffing — `OPTION (RECOMPILE)` or `OPTIMIZE FOR` | [procedural-extensions.md](references/procedural-extensions.md) |

## Two traps everyone hits first

**`NOT IN` with a NULL in the list silently returns zero rows** — not an error, just an empty result:

```sql
-- returns ZERO rows if any customer_id in the subquery is NULL
SELECT * FROM customers WHERE id NOT IN (SELECT customer_id FROM orders);

-- correct: NULL-safe
SELECT * FROM customers c WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
```

**A right-table condition in WHERE silently turns a LEFT JOIN into an INNER JOIN**, because unmatched rows get NULL on the right and fail any WHERE predicate except `IS NULL`:

```sql
-- WRONG: discards every row with no match, defeating the LEFT JOIN
... LEFT JOIN orders o ON c.id = o.customer_id WHERE o.status = 'active';

-- RIGHT: condition belongs in ON
... LEFT JOIN orders o ON c.id = o.customer_id AND o.status = 'active';
```

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| `NOT IN` against a column that can contain NULL | Silently returns zero rows | Use `NOT EXISTS`; see [query-execution-and-null-semantics.md](references/query-execution-and-null-semantics.md) |
| Filtering the optional side of a LEFT JOIN in WHERE | Silently collapses it to an INNER JOIN | Move the condition into ON; see [joins.md](references/joins.md) |
| Joining to a non-unique key before aggregating | Fan-out inflates SUM/COUNT with no error | Pre-aggregate or dedupe the right side first; see [joins.md](references/joins.md) |
| Assuming `FILTER (WHERE ...)` is universally portable | Fails outright on Snowflake, unavailable on current SQL Server/MySQL | Use `SUM(CASE WHEN ...)` unless the engine is confirmed; see [aggregation-patterns.md](references/aggregation-patterns.md) |
| Relying on the implicit window frame default for a running total | Silently switches to peer-inclusive behavior on tied ORDER BY values | Always specify `ROWS BETWEEN ... AND CURRENT ROW`; see [window-functions.md](references/window-functions.md) |
| Blind append-only writes on every load | Duplicates rows on any rerun/backfill | `MERGE` keyed by business key; see [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| Assuming a CTE is never an optimization barrier | On pre-12 PostgreSQL it always is | Know your engine's CTE inlining behavior; force materialization with `AS MATERIALIZED` on PG12+ if needed; see [ctes-and-recursion.md](references/ctes-and-recursion.md) |
| Adding an index before reading the execution plan | Might not fix the actual bottleneck | Run `EXPLAIN ANALYZE` first; see [query-optimization-and-production.md](references/query-optimization-and-production.md) |
| Reaching for a cursor loop instead of a set-based rewrite | RBAR — pays per-row overhead a single statement wouldn't | Rewrite as a query first; see [procedural-extensions.md](references/procedural-extensions.md) |
