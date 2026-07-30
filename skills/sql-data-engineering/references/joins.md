# Joins

## Join types and their semantics

- **INNER JOIN** — only rows with a match on both sides.
- **LEFT JOIN / RIGHT JOIN** — keep every row from the preserved side even without a match; unmatched columns from the other side come back NULL.
- **FULL JOIN** — keep every row from both sides.
- **CROSS JOIN** — the full cartesian product; used deliberately to generate combinations (all products × all regions) or a date spine (every date × every entity).
- **SELF JOIN** — a table joined to itself, for hierarchies (employee → manager) or row-to-row comparisons within the same table.

This part is assumed knowledge at any level. The signal is in what follows.

## The outer-join-filter trap

Putting a condition on the *right-hand* table in `WHERE` silently turns a `LEFT JOIN` into an `INNER JOIN`, because unmatched rows get `NULL` on the right side, and `NULL` fails any `WHERE` predicate other than `IS NULL` (see [query-execution-and-null-semantics.md](query-execution-and-null-semantics.md)):

```sql
-- WRONG: discards every customer with no matching order, defeating the LEFT JOIN
SELECT c.*, o.status
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.status = 'active';

-- RIGHT: the condition belongs in ON, so the LEFT JOIN is preserved
SELECT c.*, o.status
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id AND o.status = 'active';
```

The rule: any condition on the *preserved* side's own columns can go in `WHERE` freely; any condition on the *optional* side belongs in `ON` if you want unmatched rows to survive.

## Fan-out (cardinality inflation)

Joining against a table where the join key isn't unique multiplies every left row by however many matches exist on the right — silently, with no error. If you then `SUM` or `COUNT` after that join, the total is inflated by however much fan-out happened, and nothing about the query signals it.

```sql
-- if a customer has 3 orders, this multiplies every row of `customers`
-- for that customer by 3 before the SUM runs
SELECT c.id, SUM(o.amount)
FROM customers c
JOIN orders o ON c.id = o.customer_id
GROUP BY c.id;
```

Before writing a join that feeds an aggregate, ask: does this join preserve one row per key, or does it multiply? If the right-hand side isn't unique on the join key, either aggregate it *before* the join (pre-compute `SUM(amount) GROUP BY customer_id` as its own subquery/CTE, then join that), or deduplicate it first.

## Semi-joins and anti-joins

"Customers who have orders" (semi-join) and "customers who don't" (anti-join) are expressed idiomatically with `EXISTS` / `NOT EXISTS`:

```sql
-- anti-join, NULL-safe
SELECT c.*
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
```

There are three ways to write an anti-join — `NOT EXISTS`, `LEFT JOIN ... WHERE right.key IS NULL`, and `NOT IN` — and **they are not equivalent** once the right-hand join column can contain NULL: `NOT IN` breaks silently in that case (see [query-execution-and-null-semantics.md](query-execution-and-null-semantics.md)); the other two handle NULLs correctly. Knowing that distinction, unprompted, is a direct signal of real join experience rather than memorized syntax.

## The senior framing

Every join decision runs on three axes: **semantics** (which rows do I actually want to keep), **grain** (how many rows does this produce per key — does it preserve or multiply), and **performance** (which side is large, is the join column indexed, does the engine need a broadcast hint in a distributed system like Spark). Reasoning about grain *before* writing the aggregate is what catches fan-out before it ships as a wrong number in a dashboard.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Filtering the optional side of a LEFT JOIN in WHERE | Silently collapses it to an INNER JOIN | Move the condition into ON |
| Joining to a non-unique key before aggregating | Fan-out inflates SUM/COUNT with no error | Pre-aggregate the right side, or dedupe it, before the join |
| Using `NOT IN` for an anti-join | Silently returns zero rows if the right column has any NULL | Use `NOT EXISTS` |
| Assuming CROSS JOIN is always a mistake | It's the correct tool for generating combinations or a date spine | Use it deliberately, not by accident |
