# Query Optimization and Production

Everything else in this skill is "knows SQL." This is "knows how to make SQL run fast and cheap at scale" — what actually separates a senior engineer's answer from a "let's just add an index" reflex.

## Read the plan first

The answer never starts with "add an index." It starts with `EXPLAIN` (or `EXPLAIN ANALYZE`, which actually executes the query and reports real timings, not just estimates): identify the single most expensive operator — a full table scan, a nested loop over millions of rows, a sort spilling to disk — before touching anything. Optimizing without reading the plan is guessing.

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42;
```

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

```sql
-- non-sargable: the function on ts blocks index use and partition pruning
WHERE DATE(ts) = '2024-01-01'

-- sargable: a plain range comparison on the raw column
WHERE ts >= '2024-01-01' AND ts < '2024-01-02'
```

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
