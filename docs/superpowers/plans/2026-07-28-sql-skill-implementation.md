# SQL Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the `sql` domain skill (`SKILL.md` + 7 reference files) for the `data-engineering-skills` repo, and validate it with fresh-agent discoverability/correctness scenarios.

**Architecture:** Same shape as the existing `python` skill — a `SKILL.md` with overview/when-to-use/quick-reference/common-mistakes, and one reference file per heavy topic under `references/`. Content is the verified, corrected version of the user's original draft plus targeted additions from `wshobson/agents`' `sql-optimization-patterns` (MIT, attributed).

**Tech Stack:** Markdown, git.

## Global Constraints

- Content in English; code examples in SQL (per `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §3).
- `SKILL.md` frontmatter limited to `name` + `description` — no Claude-specific fields (spec §2).
- Skill identifier is `sql` (lowercase, matches folder name).
- Engines in scope, named explicitly wherever they diverge: PostgreSQL, MySQL, SQL Server, Snowflake, BigQuery, Redshift. Oracle: only ANSI-baseline claims — do not assert Oracle-specific behavior (hierarchical query syntax, `MERGE` restrictions) without verifying first; this plan explicitly does not verify Oracle (see `docs/superpowers/specs/2026-07-28-sql-skill-design.md` §5).
- Does not cover: schema/dimensional modeling (→ `data-modeling`), dbt project architecture/medallion/naming conventions (→ future `pipelines-architecture`, same treatment as Airflow/Dagster/Prefect in `skills/python/references/production-patterns.md` today), procedural extensions — PL/SQL, T-SQL stored procedures, PL/pgSQL (not one of the suite's 8 domains).
- `wshobson/agents` content used in this plan (index types beyond B-tree, monitoring queries) is adapted with attribution, not copied verbatim — per the same policy already used for other suite research (spec §4).

---

## File Structure

**Create, in `data-engineering-skills/skills/sql/`:**
- `SKILL.md` — overview, when to use, quick reference table, two universal traps, common mistakes table.
- `references/query-execution-and-null-semantics.md` — logical execution order, three-valued logic, `NOT IN` vs `NOT EXISTS`, aggregate NULL handling, `COALESCE`/`NULLIF`.
- `references/joins.md` — join semantics, outer-join-filter trap, fan-out, semi/anti-joins.
- `references/aggregation-patterns.md` — `COUNT` variants, conditional aggregation (`CASE`/`FILTER`), `GROUPING SETS`/`ROLLUP`/`CUBE`.
- `references/window-functions.md` — anatomy, ranking functions, deduplication, top-N per group, `LAG`/`LEAD`, running totals, the `RANGE`/`ROWS` frame trap.
- `references/ctes-and-recursion.md` — CTEs for readability, optimization-barrier nuance, correlated vs non-correlated subqueries, recursive CTEs.
- `references/engineering-query-patterns.md` — dedup cross-link, gaps and islands, sessionization, pivot/unpivot, `MERGE`, SCD Type 2.
- `references/query-optimization-and-production.md` — execution plans, index types and cost, columnar-warehouse pruning/pushdown, per-engine cost model, sargability, SQL-in-dbt boundary.

Each reference file stands alone as its own task — a reviewer could approve `joins.md` while rejecting `window-functions.md`. `SKILL.md` comes last because its quick-reference table names all seven files. Validation is a final task against the fully assembled skill.

---

### Task 1: `references/query-execution-and-null-semantics.md`

**Files:**
- Create: `data-engineering-skills/skills/sql/references/query-execution-and-null-semantics.md`

**Interfaces:**
- Produces: the file `query-execution-and-null-semantics.md`, linked from `SKILL.md` (Task 8) and from `joins.md` (Task 2, anti-join section) and `aggregation-patterns.md` (Task 3, `HAVING` cross-link).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/sql/references/query-execution-and-null-semantics.md`:

```markdown
# Query Execution Order and NULL Semantics

Two ideas that order everything else in SQL, and the fastest way to tell a mid-level query writer from a senior one.

## Logical execution order

SQL doesn't run in the order you write it. The logical processing order is:

\`\`\`
FROM/JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT
\`\`\`

Three consequences follow directly, and interviewers test all three:

- **You can't reference a SELECT alias in WHERE.** WHERE runs before SELECT, so the alias doesn't exist yet.
  \`\`\`sql
  -- fails: "column total_price does not exist" (alias not yet defined)
  SELECT price * qty AS total_price FROM orders WHERE total_price > 100;

  -- works: repeat the expression, or move the filter to an outer query
  SELECT price * qty AS total_price FROM orders WHERE price * qty > 100;
  \`\`\`
- **WHERE filters rows before grouping; HAVING filters groups after aggregating.** A condition on a raw column belongs in WHERE (cheaper — discards rows before the aggregation work); a condition on an aggregate result (`SUM(...)`, `COUNT(...)`) has to go in HAVING, because the aggregate doesn't exist until GROUP BY has run.
- **Window functions evaluate in the SELECT phase — after HAVING, before DISTINCT/ORDER BY.** You cannot filter directly on a window function's result in WHERE (it doesn't exist there yet) or HAVING (window functions aren't aggregates). Wrap the query in a subquery or CTE and filter the outer layer:
  \`\`\`sql
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
  \`\`\`

This order holds across PostgreSQL, MySQL, SQL Server, Snowflake, and BigQuery — it's ANSI logical processing, not an engine quirk.

## NULL and three-valued logic

SQL comparisons don't evaluate to true/false — they evaluate to **true / false / unknown**. `NULL = NULL` is not true, it's unknown; that's why you compare with `IS NULL` / `IS NOT NULL` instead of `=`. WHERE and HAVING keep a row only when the condition is true — both false and unknown get dropped.

The trap that bites most often:

**`NOT IN` with a NULL in the list returns zero rows.** `x NOT IN (a, b, NULL)` expands to `x <> a AND x <> b AND x <> NULL`. That last comparison is unknown, and combining it with `AND` poisons the whole expression to unknown — so **every row** gets dropped, silently, with no error thrown. This is standard-mandated three-valued-logic behavior, not an optimizer bug, and it's identical across PostgreSQL, MySQL, SQL Server, Snowflake, and BigQuery.

\`\`\`sql
-- silently returns ZERO rows if any customer_id in the subquery is NULL
SELECT * FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders);

-- correct: NOT EXISTS is NULL-safe
SELECT * FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
\`\`\`

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
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/sql/references/query-execution-and-null-semantics.md`
Expected: `4` (four `##` sections: Logical execution order, NULL and three-valued logic, The senior framing, Common mistakes).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/sql/references/query-execution-and-null-semantics.md
git commit -m "Add sql skill: query execution order and NULL semantics"
```

---

### Task 2: `references/joins.md`

**Files:**
- Create: `data-engineering-skills/skills/sql/references/joins.md`

**Interfaces:**
- Consumes: cross-links to `query-execution-and-null-semantics.md` (Task 1) for the WHERE/NULL mechanics behind the outer-join-filter trap and the `NOT IN` anti-join warning.
- Produces: the file `joins.md`, linked from `SKILL.md` (Task 8).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/sql/references/joins.md`:

```markdown
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

\`\`\`sql
-- WRONG: discards every customer with no matching order, defeating the LEFT JOIN
SELECT c.*, o.status
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.status = 'active';

-- RIGHT: the condition belongs in ON, so the LEFT JOIN is preserved
SELECT c.*, o.status
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id AND o.status = 'active';
\`\`\`

The rule: any condition on the *preserved* side's own columns can go in `WHERE` freely; any condition on the *optional* side belongs in `ON` if you want unmatched rows to survive.

## Fan-out (cardinality inflation)

Joining against a table where the join key isn't unique multiplies every left row by however many matches exist on the right — silently, with no error. If you then `SUM` or `COUNT` after that join, the total is inflated by however much fan-out happened, and nothing about the query signals it.

\`\`\`sql
-- if a customer has 3 orders, this multiplies every row of `customers`
-- for that customer by 3 before the SUM runs
SELECT c.id, SUM(o.amount)
FROM customers c
JOIN orders o ON c.id = o.customer_id
GROUP BY c.id;
\`\`\`

Before writing a join that feeds an aggregate, ask: does this join preserve one row per key, or does it multiply? If the right-hand side isn't unique on the join key, either aggregate it *before* the join (pre-compute `SUM(amount) GROUP BY customer_id` as its own subquery/CTE, then join that), or deduplicate it first.

## Semi-joins and anti-joins

"Customers who have orders" (semi-join) and "customers who don't" (anti-join) are expressed idiomatically with `EXISTS` / `NOT EXISTS`:

\`\`\`sql
-- anti-join, NULL-safe
SELECT c.*
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
\`\`\`

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
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/sql/references/joins.md`
Expected: `6`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/sql/references/joins.md
git commit -m "Add sql skill: joins"
```

---

### Task 3: `references/aggregation-patterns.md`

**Files:**
- Create: `data-engineering-skills/skills/sql/references/aggregation-patterns.md`

**Interfaces:**
- Consumes: cross-links to `query-execution-and-null-semantics.md` (Task 1) for the WHERE/HAVING distinction.
- Produces: the file `aggregation-patterns.md`, linked from `SKILL.md` (Task 8) and from `engineering-query-patterns.md` (Task 6) for the pivot pattern.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/sql/references/aggregation-patterns.md`:

```markdown
# Aggregation Patterns

## Counting, precisely

`COUNT(*)` counts rows, including ones with NULLs anywhere in them. `COUNT(column)` counts only the non-NULL values in that column. `COUNT(DISTINCT column)` counts distinct non-NULL values. Mixing these up produces a metric that's subtly wrong rather than obviously broken — the query runs fine, the number is just not what you think it is.

\`\`\`sql
SELECT
  COUNT(*)                    AS total_rows,
  COUNT(shipped_at)           AS shipped_rows,        -- NULLs in shipped_at excluded
  COUNT(DISTINCT customer_id) AS distinct_customers
FROM orders;
\`\`\`

`GROUP BY` groups rows before aggregating; `HAVING` filters those groups after the aggregate is computed — see [query-execution-and-null-semantics.md](query-execution-and-null-semantics.md) for why a condition on an aggregate can't live in `WHERE`.

## Conditional aggregation (pivoting with CASE)

Instead of running separate queries per condition, aggregate by condition within the same pass — the pattern behind most hand-built pivot tables:

\`\`\`sql
SELECT
  customer_id,
  SUM(CASE WHEN status = 'paid'    THEN amount ELSE 0 END) AS total_paid,
  SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END) AS total_pending
FROM orders
GROUP BY customer_id;
\`\`\`

The SQL-standard `FILTER (WHERE ...)` clause expresses the same intent more cleanly:

\`\`\`sql
SELECT
  customer_id,
  COUNT(*) FILTER (WHERE status = 'paid') AS num_paid
FROM orders
GROUP BY customer_id;
\`\`\`

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

\`\`\`sql
SELECT region, product, SUM(amount)
FROM sales
GROUP BY ROLLUP (region, product);
\`\`\`

**Engine support is not universal** — the one real gap: **MySQL (through at least 8.4) supports only `ROLLUP`** (via `WITH ROLLUP` or standard `GROUP BY ... ROLLUP()` syntax since 8.0.12); it has no native `CUBE` or `GROUPING SETS`, which have to be emulated with `UNION ALL` of separate `GROUP BY` queries. PostgreSQL (9.5+), SQL Server, Snowflake, and BigQuery support all three.

In a pre-computed aggregates pipeline, reaching for these instead of unioning several queries by hand is what separates someone who's only used a flat `GROUP BY` from someone who's built reporting tables at scale.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Confusing `COUNT(*)` with `COUNT(column)` | Silently wrong metric when the column has NULLs | Pick deliberately based on whether NULLs should count |
| Assuming `FILTER (WHERE ...)` runs everywhere | Fails outright on Snowflake; unavailable on current SQL Server/MySQL | Use `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` unless the target engine is confirmed to support FILTER |
| Assuming `CUBE`/`GROUPING SETS` work on MySQL | Not supported through 8.4 — query fails | Emulate with `UNION ALL`, or use `ROLLUP` if that's sufficient |
| Running N separate GROUP BY queries for N subtotal levels | Wasteful, multiple passes over the data | `ROLLUP`/`CUBE`/`GROUPING SETS` compute them in one pass |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/sql/references/aggregation-patterns.md`
Expected: `4`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/sql/references/aggregation-patterns.md
git commit -m "Add sql skill: aggregation patterns"
```

---

### Task 4: `references/window-functions.md`

**Files:**
- Create: `data-engineering-skills/skills/sql/references/window-functions.md`

**Interfaces:**
- Produces: the file `window-functions.md`, linked from `SKILL.md` (Task 8) and from `engineering-query-patterns.md` (Task 6) for the deduplication cross-link.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/sql/references/window-functions.md`:

```markdown
# Window Functions

The flagship topic — this is where window functions replace expensive self-joins and imperative logic with a single declarative pass, and where the line between mid-level and senior SQL is clearest.

## Anatomy

A window function computes across a set of related rows *without collapsing them* — unlike `GROUP BY`, every input row survives in the output. The shape is:

\`\`\`sql
function() OVER (PARTITION BY ... ORDER BY ... frame_clause)
\`\`\`

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

\`\`\`sql
WITH ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) AS rn
  FROM events
)
SELECT * FROM ranked WHERE rn = 1;
\`\`\`

**CTE + `ROW_NUMBER` + filter to `rn = 1`** is the pattern behind CDC deduplication, "latest version of each row," and general duplicate cleanup. It should come out automatically — that fluency is a direct senior signal.

### Top-N per group

"Top 3 best-selling products per category":

\`\`\`sql
SELECT * FROM (
  SELECT *, DENSE_RANK() OVER (PARTITION BY category ORDER BY sales DESC) AS rnk
  FROM products
) ranked
WHERE rnk <= 3;
\`\`\`

The choice between `RANK` and `DENSE_RANK` here depends on intent: do you want exactly 3 rows, or "everyone tied for 3rd place too"? `ROW_NUMBER` would give exactly 3 rows but arbitrarily picks which of several ties to include — usually the wrong choice for a "top N" business question.

## Comparing rows: LAG / LEAD

Access the previous or next row's value within the same partition — built for deltas, period-over-period growth, or time between events:

\`\`\`sql
SELECT
  sale_date,
  revenue,
  revenue - LAG(revenue) OVER (ORDER BY sale_date) AS delta_vs_prior_day
FROM daily_sales;
\`\`\`

## Running totals and moving averages: the frame clause

This is the detail that separates someone who's used window functions from someone who actually understands them. A running total is:

\`\`\`sql
SUM(amount) OVER (ORDER BY sale_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
\`\`\`

A 7-day moving average is:

\`\`\`sql
AVG(amount) OVER (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
\`\`\`

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
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/sql/references/window-functions.md`
Expected: `6`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/sql/references/window-functions.md
git commit -m "Add sql skill: window functions"
```

---

### Task 5: `references/ctes-and-recursion.md`

**Files:**
- Create: `data-engineering-skills/skills/sql/references/ctes-and-recursion.md`

**Interfaces:**
- Produces: the file `ctes-and-recursion.md`, linked from `SKILL.md` (Task 8) and from `query-optimization-and-production.md` (Task 7) for the correlated-subquery rewrite cross-link.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/sql/references/ctes-and-recursion.md`:

```markdown
# CTEs, Subqueries, and Recursion

## CTEs for readability and reuse

`WITH` clauses decompose a complex query into named, readable steps and avoid repeating a subquery. One nuance worth knowing: in some engines a CTE is an **optimization barrier** — it gets materialized as-is and isn't fused with the rest of the query plan — while in others (modern PostgreSQL, since 12) the planner can inline it like a subquery when that's cheaper. In cloud warehouses this generally doesn't matter for performance, but knowing the difference exists — and checking your engine's specific behavior when a CTE-heavy query is unexpectedly slow — is a sign of depth beyond "I use CTEs for readability."

## Correlated vs non-correlated subqueries

A **correlated** subquery references a column from the outer query and gets re-evaluated once per outer row — potentially slow at scale. A **non-correlated** subquery is self-contained and evaluated once. Recognizing a slow correlated subquery and rewriting it as a join or a window function is a standard senior move:

\`\`\`sql
-- correlated: re-evaluated per row of `orders`
SELECT *,
  (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = orders.id) AS item_count
FROM orders;

-- rewritten as a join + aggregate, evaluated once
SELECT o.*, COALESCE(oi.item_count, 0) AS item_count
FROM orders o
LEFT JOIN (SELECT order_id, COUNT(*) AS item_count FROM order_items GROUP BY order_id) oi
  ON oi.order_id = o.id;
\`\`\`

## Recursive CTEs

For hierarchies (org charts, nested categories, bill-of-materials explosion) and for generating series (a date spine covering every date in a range). The pattern is an **anchor member**, `UNION ALL`, and a **recursive member** that joins back to the CTE itself, terminating when the recursive member returns no more rows:

\`\`\`sql
WITH RECURSIVE org_chart AS (
  SELECT id, manager_id, name, 1 AS level
  FROM employees WHERE manager_id IS NULL        -- anchor: the root

  UNION ALL

  SELECT e.id, e.manager_id, e.name, o.level + 1
  FROM employees e
  JOIN org_chart o ON e.manager_id = o.id         -- recursive step
)
SELECT * FROM org_chart ORDER BY level;
\`\`\`

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
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/sql/references/ctes-and-recursion.md`
Expected: `5`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/sql/references/ctes-and-recursion.md
git commit -m "Add sql skill: CTEs, subqueries, and recursion"
```

---

### Task 6: `references/engineering-query-patterns.md`

**Files:**
- Create: `data-engineering-skills/skills/sql/references/engineering-query-patterns.md`

**Interfaces:**
- Consumes: cross-links to `window-functions.md` (Task 4, deduplication), `aggregation-patterns.md` (Task 3, pivot pattern), and `skills/python/references/production-patterns.md` (already migrated, idempotency discussion).
- Produces: the file `engineering-query-patterns.md`, linked from `SKILL.md` (Task 8) and from `query-optimization-and-production.md` (Task 7) for the `unique_key`/`MERGE` idempotency cross-link.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/sql/references/engineering-query-patterns.md`:

```markdown
# Engineering Query Patterns

The patterns section — a set of idioms every data engineer should be able to produce from memory, not derive from scratch.

## Deduplication (canonical form)

Covered in full in [window-functions.md](window-functions.md): CTE + `ROW_NUMBER() OVER (PARTITION BY key ORDER BY updated_at DESC)` + filter to `rn = 1`. This is the pattern behind CDC deduplication and "keep the latest version of each row."

## Gaps and islands

Detecting consecutive runs (streaks) or gaps in a sequence — consecutive active days, session runs, missing dates in a time series. The standard trick: subtract a `ROW_NUMBER()` from the sequence value itself. Rows in the same contiguous run get the same difference, because both the sequence and the row number advance by 1 together within a run:

\`\`\`sql
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
\`\`\`

This shows up in user-session analysis and in detecting gaps in data pipelines themselves (missing partition dates).

## Sessionization

Group events into sessions when the gap between them exceeds a threshold, by combining `LAG` (time since the previous event) with a running sum of "session starts":

\`\`\`sql
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
\`\`\`

## Pivoting and unpivoting

Pivot with conditional aggregation (see [aggregation-patterns.md](aggregation-patterns.md)). Unpivot with `UNION ALL` of one `SELECT` per source column, or the engine's native `UNPIVOT`/`LATERAL` construct where available — support and syntax for native unpivot vary by engine, so `UNION ALL` remains the portable default.

## Idempotent upserts with MERGE

The pattern that makes a load idempotent — the piece a report-writing analyst rarely touches, but a data engineer has to own (connects directly to the idempotency discussion in [python's production-patterns.md](../../python/references/production-patterns.md)):

\`\`\`sql
MERGE INTO dim_customer t
USING staging_customer s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET t.name = s.name, t.email = s.email
WHEN NOT MATCHED THEN INSERT (customer_id, name, email)
                     VALUES (s.customer_id, s.name, s.email);
\`\`\`

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
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/sql/references/engineering-query-patterns.md`
Expected: `7`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/sql/references/engineering-query-patterns.md
git commit -m "Add sql skill: engineering query patterns"
```

---

### Task 7: `references/query-optimization-and-production.md`

**Files:**
- Create: `data-engineering-skills/skills/sql/references/query-optimization-and-production.md`

**Interfaces:**
- Consumes: cross-links to `ctes-and-recursion.md` (Task 5, correlated-subquery rewrite) and `engineering-query-patterns.md` (Task 6, `MERGE`/`unique_key` idempotency link).
- Produces: the file `query-optimization-and-production.md`, linked from `SKILL.md` (Task 8).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/sql/references/query-optimization-and-production.md`:

```markdown
# Query Optimization and Production

Everything else in this skill is "knows SQL." This is "knows how to make SQL run fast and cheap at scale" — what actually separates a senior engineer's answer from a "let's just add an index" reflex.

## Read the plan first

The answer never starts with "add an index." It starts with `EXPLAIN` (or `EXPLAIN ANALYZE`, which actually executes the query and reports real timings, not just estimates): identify the single most expensive operator — a full table scan, a nested loop over millions of rows, a sort spilling to disk — before touching anything. Optimizing without reading the plan is guessing.

\`\`\`sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42;
\`\`\`

## Indexes and their cost

A B-tree index takes an equality/range filter or join on that column from an O(n) scan to roughly O(log n) lookup — at the cost of slower writes (every `INSERT`/`UPDATE`/`DELETE` has to update every index) and extra storage. An index on a low-cardinality column (a boolean, a handful of status values) barely helps, because the planner still has to visit a large fraction of the table either way. Composite indexes follow the **leftmost-prefix rule**: an index on `(a, b, c)` serves queries filtering on `a`, or `a AND b`, or `a AND b AND c` — but not efficiently on `b` alone.

PostgreSQL isn't limited to B-tree — the other index types are worth knowing when a plain B-tree doesn't fit the query shape:

| Index type | Use case |
|---|---|
| B-tree | Equality and range filters, sorting, the default |
| GIN | Full-text search, JSONB containment (`@>`), array membership |
| GiST | Geometric data, range types, nearest-neighbor search |
| BRIN | Very large tables that are naturally sorted/clustered on disk (e.g., an append-only, time-ordered table) — tiny index size, block-range summaries instead of per-row entries |

Once an index exists, `pg_stat_user_indexes` shows whether it's actually being used, and `pg_stat_statements` surfaces the queries actually consuming the most total time — check both before deciding an index helps or is dead weight.

*(Index-type coverage and the monitoring queries above are adapted, with attribution, from `wshobson/agents`'s `sql-optimization-patterns` skill, MIT-licensed.)*

## Columnar cloud warehouses: a different mental model

In Snowflake, BigQuery, and Redshift, there's no traditional secondary B-tree index — the mechanism is different per engine, and the vocabulary doesn't transfer between them:

- **Snowflake**: data is organized into **micro-partitions** (50–500MB chunks) with metadata-driven pruning; an optional **clustering key** controls how data is co-located across those micro-partitions.
- **BigQuery**: **partitioning** (typically by date) plus **clustering** (reordering within partitions) drive pruning — no secondary index concept at all.
- **Redshift**: uses **sort keys** (physically sorts data on disk), **zone maps** (per-block min/max values enabling block skipping — conceptually similar to BRIN above), and **distribution keys** (control how rows are spread across nodes for join/aggregation locality). "Clustering key" and "micro-partition" are Snowflake vocabulary — don't apply them to Redshift; its mechanisms and their names are genuinely different.

## Partition pruning, predicate pushdown, projection pushdown

- **Partition pruning**: the engine skips reading partitions that don't match a filter on the partitioning column (typically date) — the single highest-impact optimization available in a data lake, which is exactly why partitioning well and filtering on that column matters more than almost anything else.
- **Predicate pushdown**: filters get pushed as close to the data source as possible (into Parquet row-group filtering, or down to a remote database) so less data ever gets read.
- **Projection pushdown**: only the referenced columns get read — the reason `SELECT *` is an anti-pattern on columnar formats (Parquet, ORC) and columnar warehouses: you pay to read columns you never use.

## Cost in cloud warehouses

The mental model shifts here: cost and latency aren't governed by "query complexity" the way they might feel in a general-purpose language — but the exact driver differs by engine, and conflating them is a real mistake:

- **BigQuery on-demand**: billed directly by **bytes scanned** ($/TB), independent of how complex the query logic is. (BigQuery also offers slot-based/Editions pricing that is *not* bytes-based — know which billing model a given project is on.)
- **Snowflake**: billed by **warehouse compute time** (credits per second, with a minimum), which *correlates* with bytes scanned but isn't equal to it — query complexity (joins, sorts, spills) independently affects runtime even for the same volume of bytes scanned.

The levers either way: partition/cluster by the filter column, materialize frequently-recomputed aggregates, avoid `SELECT *`, and filter early on the partition column. Distinguishing "BigQuery is bytes-scanned pricing, Snowflake is compute-time pricing correlated with bytes scanned" — instead of collapsing both into "pay for bytes scanned" — is what marks someone who has actually operated at scale with a real budget, rather than repeating a slogan.

## Sargable rewrites

Applying a function to a filtered/indexed/partitioned column defeats the optimizer's ability to use an index or prune partitions on it — the predicate becomes **non-sargable**:

\`\`\`sql
-- non-sargable: the function on ts blocks index use and partition pruning
WHERE DATE(ts) = '2024-01-01'

-- sargable: a plain range comparison on the raw column
WHERE ts >= '2024-01-01' AND ts < '2024-01-02'
\`\`\`

Other classic rewrites: a correlated subquery into a join or window function (see [ctes-and-recursion.md](ctes-and-recursion.md)); a large `IN` list into a `JOIN`/`EXISTS`; filtering before aggregating rather than after.

## SQL in ELT/dbt

A large share of a data engineer's SQL ends up living inside dbt as versioned models. From the SQL side, two things matter directly: **incremental models depend on the same idempotency mechanism as `MERGE`** — the `unique_key` config drives an update/insert (upsert) instead of a blind append, exactly the pattern in [engineering-query-patterns.md](engineering-query-patterns.md) — and dbt's generic tests (`unique`, `not_null`, `accepted_values`, `relationships`) are data-quality checks expressed directly as SQL assertions rather than a separate framework.

Everything beyond that — medallion architecture, model layering and naming conventions, the dependency graph between models, project structure — is dbt as an orchestrator for the transformation layer, not a SQL-language concern; that content belongs to `pipelines-architecture`, alongside Airflow, Dagster, and Prefect.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Adding an index before reading the query plan | Might not fix the actual bottleneck, adds write overhead for nothing | Run `EXPLAIN ANALYZE` first, target the most expensive operator |
| `SELECT *` on a columnar format/warehouse | Reads and pays for columns you never use | Select only the columns actually needed |
| Applying a function to a filtered/partitioned column | Non-sargable — blocks index use and partition pruning | Rewrite as a plain range/equality comparison on the raw column |
| Calling Redshift's storage mechanism a "clustering key" or "micro-partition" | Those are Snowflake terms — Redshift uses sort keys/zone maps/distribution keys | Use the terminology of the actual engine in question |
| Saying "I optimize for bytes scanned" for both BigQuery and Snowflake | Accurate for BigQuery on-demand, an oversimplification for Snowflake's compute-time billing | Name the actual cost driver per engine |
| Treating dbt project/model-layering concerns as a SQL topic | Conflates the transformation-orchestration layer with the query language | SQL-level idempotency and tests stay here; architecture questions go to `pipelines-architecture` |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/sql/references/query-optimization-and-production.md`
Expected: `8`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/sql/references/query-optimization-and-production.md
git commit -m "Add sql skill: query optimization and production"
```

---

### Task 8: `SKILL.md`

**Files:**
- Create: `data-engineering-skills/skills/sql/SKILL.md`

**Interfaces:**
- Consumes: the exact filenames of all 7 reference files from Tasks 1-7.
- Produces: `skills/sql/SKILL.md` — completes the skill, what Task 9 validates.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/sql/SKILL.md`:

```markdown
---
name: sql
description: Use when writing, reviewing, or optimizing SQL queries — analytical queries, aggregations, window functions, CTEs, joins, or query performance tuning. Covers logical execution order and NULL/three-valued logic, join semantics and the outer-join-filter trap, aggregation and conditional pivoting, window functions (ranking, deduplication, running totals, the frame clause), CTEs and recursion, engineering query patterns (gaps and islands, sessionization, MERGE, SCD Type 2), and query optimization (execution plans, indexing, partition pruning, cost model by cloud warehouse). Covers PostgreSQL, MySQL, SQL Server, Snowflake, and BigQuery, calling out engine-specific divergence where it exists. Does not cover schema/dimensional modeling (see data-modeling) or procedural extensions like PL/SQL and T-SQL stored procedures.
---

# SQL for Data Engineering

## Overview

Senior-level judgment calls for writing, reviewing, and optimizing SQL — which construct to reach for, which trap it avoids, and how it behaves differently across engines. Each reference file pairs a concept with the failure mode it exists to prevent, and calls out where PostgreSQL, MySQL, SQL Server, Snowflake, and BigQuery genuinely diverge rather than assuming one engine's behavior is universal. Read the relevant file(s) before writing or reviewing a query; don't rely on the table below alone.

## When to use

- Writing or reviewing an analytical query: joins, aggregations, window functions, CTEs
- A query returns the wrong row count or a suspiciously large/small aggregate result
- Deduplicating records, finding gaps/streaks, sessionizing events, or writing an idempotent upsert
- A query is slow and the cause isn't obvious
- Deciding how to index a table, or reading an execution plan
- Checking whether a query pattern is portable across engines (Postgres, MySQL, SQL Server, Snowflake, BigQuery)
- Not for schema or dimensional modeling design (star schema, SCDs at the modeling level) — that's `data-modeling`
- Not for procedural extensions (PL/SQL, T-SQL stored procedures, PL/pgSQL) — this skill covers declarative SQL

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
| A slow correlated subquery | Rewrite as a join or window function | [ctes-and-recursion.md](references/ctes-and-recursion.md) |
| Org charts, nested categories, date spines | Recursive CTE (`WITH RECURSIVE`, anchor + `UNION ALL`) | [ctes-and-recursion.md](references/ctes-and-recursion.md) |
| Consecutive streaks or gaps in a sequence | Gaps-and-islands (`ROW_NUMBER` subtraction trick) | [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| Grouping events into sessions | `LAG` + running sum of session starts | [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| A load needs to be safely re-runnable | `MERGE` (or `INSERT ... ON CONFLICT` pre-PG15) keyed by business key | [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| Preserving dimension history on change | SCD Type 2 (end-date, is_current flag, surrogate key) | [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| A query is slow and the cause isn't obvious | Read `EXPLAIN`/`EXPLAIN ANALYZE` before touching anything | [query-optimization-and-production.md](references/query-optimization-and-production.md) |
| Deciding whether/how to index a column | B-tree cost, leftmost-prefix rule, GIN/GiST/BRIN | [query-optimization-and-production.md](references/query-optimization-and-production.md) |
| Query is slow/expensive on a cloud warehouse | Partition pruning, predicate/projection pushdown, per-engine cost model | [query-optimization-and-production.md](references/query-optimization-and-production.md) |

## Two traps everyone hits first

**`NOT IN` with a NULL in the list silently returns zero rows** — not an error, just an empty result:

\`\`\`sql
-- returns ZERO rows if any customer_id in the subquery is NULL
SELECT * FROM customers WHERE id NOT IN (SELECT customer_id FROM orders);

-- correct: NULL-safe
SELECT * FROM customers c WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);
\`\`\`

**A right-table condition in WHERE silently turns a LEFT JOIN into an INNER JOIN**, because unmatched rows get NULL on the right and fail any WHERE predicate except `IS NULL`:

\`\`\`sql
-- WRONG: discards every row with no match, defeating the LEFT JOIN
... LEFT JOIN orders o ON c.id = o.customer_id WHERE o.status = 'active';

-- RIGHT: condition belongs in ON
... LEFT JOIN orders o ON c.id = o.customer_id AND o.status = 'active';
\`\`\`

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| `NOT IN` against a column that can contain NULL | Silently returns zero rows | Use `NOT EXISTS`; see [query-execution-and-null-semantics.md](references/query-execution-and-null-semantics.md) |
| Filtering the optional side of a LEFT JOIN in WHERE | Silently collapses it to an INNER JOIN | Move the condition into ON; see [joins.md](references/joins.md) |
| Joining to a non-unique key before aggregating | Fan-out inflates SUM/COUNT with no error | Pre-aggregate or dedupe the right side first; see [joins.md](references/joins.md) |
| Assuming `FILTER (WHERE ...)` is universally portable | Fails outright on Snowflake, unavailable on current SQL Server/MySQL | Use `SUM(CASE WHEN ...)` unless the engine is confirmed; see [aggregation-patterns.md](references/aggregation-patterns.md) |
| Relying on the implicit window frame default for a running total | Silently switches to peer-inclusive behavior on tied ORDER BY values | Always specify `ROWS BETWEEN ... AND CURRENT ROW`; see [window-functions.md](references/window-functions.md) |
| Blind append-only writes on every load | Duplicates rows on any rerun/backfill | `MERGE` keyed by business key; see [engineering-query-patterns.md](references/engineering-query-patterns.md) |
| Adding an index before reading the execution plan | Might not fix the actual bottleneck | Run `EXPLAIN ANALYZE` first; see [query-optimization-and-production.md](references/query-optimization-and-production.md) |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "](references/" data-engineering-skills/skills/sql/SKILL.md`
Expected: a number ≥ 18 (every quick-reference and common-mistakes row links into a reference file).

Run: `for f in data-engineering-skills/skills/sql/references/*.md; do grep -q "$(basename "$f")" data-engineering-skills/skills/sql/SKILL.md || echo "MISSING LINK: $f"; done`
Expected: no output (every one of the 7 reference files is linked from `SKILL.md`).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/sql/SKILL.md
git commit -m "Add sql skill: SKILL.md"
```

---

### Task 9: Validate the `sql` skill

**Owner:** Claude, using the `Agent` tool to run fresh-context scenarios (same method used to validate `python` and the `data-engineering` orchestrator).

**Interfaces:**
- Consumes: `skills/sql/` (Tasks 1-8), symlinked into a live Claude Code environment so a fresh agent can discover it.

Two scenarios test both discoverability and whether the corrected technical content actually surfaces — not just that the skill fires.

- [x] **Step 1: Symlink the skill for testing**

```bash
ln -sf "$(pwd)/data-engineering-skills/skills/sql" ~/.claude/skills/sql
```

Confirmed 2026-07-28: symlink present and resolving correctly.

- [x] **Step 2: Run the NULL-trap correctness scenario**

Dispatch a fresh `general-purpose` agent with this prompt:

> "You have a list of available skills — check it. Then answer: 'Review this query: `SELECT * FROM customers WHERE id NOT IN (SELECT customer_id FROM orders)` — it's meant to find customers with no orders. The orders table can have NULL customer_id from guest checkouts. Will this work correctly?' After answering, report which skill(s) you invoked."

Expected: the agent invokes `sql`, correctly identifies that `NOT IN` with a NULL in the subquery's result silently returns zero rows (not an error), and recommends `NOT EXISTS` as the fix.

**Result (2026-07-28): PASS.** Agent invoked `sql`, correctly explained the three-valued-logic mechanics (`id <> NULL` → UNKNOWN, poisoning the whole `AND` chain), stated the query silently returns zero rows with no error, and recommended `NOT EXISTS` as the default fix.

- [x] **Step 3: Run the window-function frame-default scenario**

Dispatch a fresh `general-purpose` agent with this prompt:

> "You have a list of available skills — check it. Then answer: 'I need a running total of daily revenue in Snowflake, ordered by date, using `SUM(revenue) OVER (ORDER BY sale_date)` with no explicit frame clause. Some dates might have duplicate rows (multiple entries same day before aggregation). What should I watch out for?' After answering, report which skill(s) you invoked."

Expected: the agent invokes `sql`, explains that the implicit default frame is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` (not `ROWS`), that `RANGE` includes all rows tied on the `ORDER BY` value at each of those rows (causing the running total to jump on duplicate dates), and recommends an explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` frame.

**Result (2026-07-28): PASS — exceeds expectations.** Agent invoked `sql` (citing `references/window-functions.md`), correctly explained the RANGE default and that Snowflake follows the ANSI default for aggregate functions specifically (not a blanket Snowflake exception), recommended an explicit `ROWS` frame, and additionally caught a grain-mismatch issue (pre-aggregating to daily grain before windowing) that went beyond the literal question.

- [x] **Step 4: Record the result**

If either scenario fails (skill doesn't fire, or the technical answer is wrong/vague), fix the relevant wording in the affected reference file or `SKILL.md`'s quick-reference table, and re-run only the failing scenario.

Both scenarios passed on the first run — no content changes needed.

---

## Addendum (2026-07-29): Oracle verification closed, final-review findings fixed

This plan (Global Constraints, and the Oracle notes embedded in Tasks 5 and 6's file content above) explicitly deferred Oracle-specific claims as unverified. That gap is now closed:

- **Recursive CTEs** (`ctes-and-recursion.md`): Oracle supports both `CONNECT BY PRIOR` and ANSI recursive subquery factoring (since 11g Release 2 / 11.2.0.1) — verified against Oracle's official SQL Language Reference. Gotcha: Oracle's `WITH` clause does not accept the literal `RECURSIVE` keyword; recursion is inferred automatically.
- **MERGE** (`engineering-query-patterns.md`): Oracle has had `MERGE` since 9i. Verified against Oracle's official MERGE reference: it is a "deterministic statement" — updating the same target row twice in one execution raises `ORA-30926`, not silent single-application. Exactly one `WHEN MATCHED` and one `WHEN NOT MATCHED` clause per statement (no SQL-Server-style multiple conditional branches).

Also folded into the same pass: a whole-branch final review (dispatched separately from this plan, most capable model) found 5 Important + 5 Minor issues after Task 9 (Redshift missing from `SKILL.md`'s engine list; SCD Type 2 section contradicting the skill's own modeling-vs-query-mechanics boundary; a sessionization example violating the skill's own RANGE/ROWS frame rule; the `QUALIFY` clause entirely missing for Snowflake/BigQuery/Redshift; vague "some engines" language in the CTE-materialization discussion; plus wording/attribution/staleness nits). All were fixed in one dispatch and scoped re-review; two residual issues surfaced by the re-review (a RANK worked-example arithmetic error, and Redshift dropped from two engine lists in the same fix) were corrected in a follow-up pass alongside the Oracle closure above.

See `docs/superpowers/specs/2026-07-28-sql-skill-design.md` (Estado line, and §2/§4.5/§4.6/§5) for the updated spec-level record. No further open items for the `sql` skill.

**Second addendum, same day:** the skill identifier itself was then renamed from `sql` to `dataeng-sql` (folder: `skills/dataeng-sql/`), part of prefixing every skill in the suite with `dataeng-` to avoid collisions in the flat, shared `~/.claude/skills/`/`~/.agents/skills/` namespace. This plan's tasks above still say `sql` throughout — historical record of what Tasks 1-9 actually built under that name at the time. See the suite spec's Estado line for the rename rationale.

---

## Self-Review Notes

- **Spec coverage**: Task 1 ↔ spec §4.1; Task 2 ↔ §4.2; Task 3 ↔ §4.3; Task 4 ↔ §4.4; Task 5 ↔ §4.5; Task 6 ↔ §4.6; Task 7 ↔ §4.7; Task 8 ties them together per spec §4's file-structure diagram; Task 9 mirrors the discoverability validation already run for `python` and `data-engineering`.
- **No placeholders**: every task's content is the actual final file content (English, corrections from spec §4 incorporated), not a description of what to write.
- **Type/name consistency**: reference filenames match exactly between the spec (§4), the File Structure section above, each task's own file, and `SKILL.md`'s quick-reference table links — verified via Task 8 Step 2's link-check commands.
