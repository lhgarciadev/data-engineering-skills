# Spark Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the `dataeng-spark` domain skill (`SKILL.md` + 7 reference files) for the `data-engineering-skills` repo, and validate it with fresh-agent discoverability/correctness scenarios.

**Architecture:** Same shape as `dataeng-sql`/`dataeng-python` — a `SKILL.md` with overview/when-to-use/quick-reference/common-mistakes, and one reference file per heavy topic under `references/`. Content is the verified, corrected version of the user's original draft plus targeted additions from `wshobson/agents`' `spark-optimization` (MIT, attributed) and the executor/driver-memory + PySpark-specific sections already scoped by the suite spec.

**Tech Stack:** Markdown, PySpark code examples, git.

## Global Constraints

- Content in English; code examples in PySpark, the language most relevant to the topic (per `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §3).
- `SKILL.md` frontmatter limited to `name` + `description` — no Claude-specific fields (spec §2).
- Skill identifier is `dataeng-spark` (lowercase, matches folder name, carries the suite-wide `dataeng-` prefix per the 2026-07-29 rename decision — see `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` Estado line).
- Version scope: Apache Spark 3.x/4.x current behavior. Where behavior changed at a specific version (AQE enabled by default since 3.2.0, skew-join optimization enabled by default since 3.0.0, Arrow-by-default UDF serialization since 4.2.0, `spark.memory.fraction`=0.6 since 2.0.0), name the version explicitly — never generalize to "recent Spark."
- Does not cover: Structured Streaming (→ future `dataeng-streaming`), Spark cluster deployment/infrastructure (→ future `dataeng-iac-cloud`), Delta Lake/Iceberg/Hudi table-format specifics (out of scope for now, per `docs/superpowers/specs/2026-07-29-spark-skill-design.md` §5), dimensional/schema modeling (→ future `dataeng-data-modeling`).
- `wshobson/agents` content used in this plan (bucket joins, checkpointing, programmatic skew detection via `spark_partition_id()`, `approx_count_distinct`) is adapted with attribution, not copied verbatim — per the same policy already used for `dataeng-sql`.
- "Catalyst" and "wide dependency" are standard industry terminology (from the original RDD paper and Databricks' own engineering materials) that do not appear in Spark's prose documentation — present them as correct standard usage, not as quotes from spark.apache.org/docs.

---

## File Structure

**Create, in `data-engineering-skills/skills/dataeng-spark/`:**
- `SKILL.md` — overview, when to use, quick reference table, two traps, common mistakes table.
- `references/execution-model.md` — lazy evaluation, the DAG, the query optimizer ("Catalyst"), transformations vs. actions, narrow vs. wide dependencies.
- `references/shuffle-and-partitioning.md` — shuffle cost, `repartition` vs. `coalesce`.
- `references/joins-and-skew.md` — broadcast joins, AQE automatic skew-join optimization, manual salting as fallback, bucket joins.
- `references/caching-and-file-formats.md` — `.cache()`/`.persist()`, checkpointing, Parquet pushdown, partitioning on write.
- `references/adaptive-query-execution-and-benchmarking.md` — AQE's documented optimizations, the cold/warm cache benchmarking pitfall.
- `references/memory-management.md` — the unified memory model, executor vs. driver memory, broadcast variable placement.
- `references/pyspark-specifics.md` — Python UDF overhead (the real mechanism, not py4j), Pandas UDFs/Arrow, `.collect()`/`.toPandas()` driver-memory risk.

Each reference file stands alone as its own task. `SKILL.md` comes last because its quick-reference table names all seven files. Validation is a final task against the fully assembled skill.

---

### Task 1: `references/execution-model.md`

**Files:**
- Create: `data-engineering-skills/skills/dataeng-spark/references/execution-model.md`

**Interfaces:**
- Produces: the file `execution-model.md`, linked from `SKILL.md` (Task 8) and from `shuffle-and-partitioning.md` (Task 2, wide-dependency cross-link).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/dataeng-spark/references/execution-model.md`:

````markdown
# Execution Model: Lazy Evaluation, the DAG, and Catalyst

This is the model that makes Spark behave the way it does — code that "does nothing" for ten seconds and then bursts into activity, a stack trace that points at `.count()` instead of the line that's actually wrong, a `groupBy` that looks free until it isn't. None of that is mysterious once you know Spark never executes a transformation on the spot: it builds a plan, optimizes it, and only runs it when something forces the question.

## Lazy evaluation: nothing runs until you ask for it

Every transformation you call — `filter`, `select`, `withColumn`, `join` — returns a *new* DataFrame immediately, without touching a single row of data. What actually happens is that Spark extends an internal logical plan. Chaining ten transformations costs the same as chaining one: both are just plan-building, and the cost is paid exactly once, when an action forces materialization.

```python
df = spark.read.parquet("s3://bucket/events/")

# None of this touches data - it only extends the logical plan
filtered = df.filter(df.event_type == "purchase")
selected = filtered.select("user_id", "amount", "event_ts")
enriched = selected.withColumn("amount_usd", selected.amount * 1.0)

print("Plan built, zero rows processed so far")

enriched.count()  # <- this is what submits a job and actually reads data
```

The part people get wrong about "errors surface late": it's not universally true. A bad column reference or type mismatch is caught **immediately**, while you're still building the plan, because Spark resolves and validates the logical plan (the analysis phase) as soon as you call the transformation:

```python
# Raises AnalysisException right here - no action needed
bad = df.select("this_column_does_not_exist")
```

What genuinely waits for an action is anything that depends on the *data*, not the *schema* — a division by zero, a bad cast, a corrupt row, an out-of-memory executor:

```python
risky = df.withColumn("ratio", df.numerator / df.denominator)
risky.count()  # <- the runtime failure surfaces here, far from where you wrote the transformation
```

## Transformations vs actions

This is Spark's own vocabulary, used consistently in both the RDD programming guide and the Dataset API docs — knowing which bucket an operation falls into tells you whether calling it costs anything.

| Category | Examples | What calling it does |
|---|---|---|
| Transformation | `map`, `filter`, `select`, `join`, `groupBy`, `withColumn`, `distinct` | Returns a new DataFrame/RDD; only extends the logical plan — lazy |
| Action | `count`, `collect`, `show`, `take`, `write`, `foreach` | Submits a job to the cluster; forces every upstream transformation to actually execute |

The practical consequence: writing a transformation chain and never calling an action on it is a no-op. If you're debugging why a pipeline "isn't doing anything," check whether the last line is an action or just another transformation.

## The DAG: the plan, made concrete

Once an action fires, Spark's scheduler turns the accumulated chain of transformations into a **DAG** — a directed acyclic graph of the computations and their dependencies. This is the artifact Spark actually schedules and runs: it gets split into stages, stages get split into tasks, and tasks run on executors.

Worth being precise about where this term lives: "DAG" is not prose you'll find explained at length in the programming guides — it's the language of Spark's *tooling*. Open the Spark web UI and the Jobs tab shows a DAG visualization for each job; the Stages tab breaks it into the stage boundaries that visualization implies. That UI is the primary place to actually look at one, and it's the first place to check when a job is slow or skewed.

You can also get a textual view of the same lineage from the driver, without opening the UI:

```python
print(enriched.rdd.toDebugString().decode())
```

## Narrow vs wide dependencies: what turns the DAG into stages

Not all transformations are equal in cost, and the distinction is exactly what decides where a stage boundary lands:

- **Narrow dependency** — each parent partition feeds at most one child partition (`filter`, `map`, `select`). No data moves between partitions, so Spark pipelines these together into a single stage with no network cost.
- **Wide dependency** — each parent partition can feed *multiple* child partitions (`groupBy`, `join`, `distinct`, `repartition`, `orderBy`), because rows that need to end up together might currently live anywhere in the cluster. That requires a **shuffle** — data written out and re-read across the network — and it's the one thing that forces a new stage.

```python
# All narrow - pipelined into one stage, no shuffle
narrow_only = df.filter(df.amount > 0).select("user_id", "amount")
narrow_only.count()

# groupBy is wide - Spark must shuffle rows so matching keys land
# on the same partition before it can aggregate them
wide = df.groupBy("user_id").sum("amount")
wide.count()  # two stages: pre-shuffle and post-shuffle
```

Precision on where these terms actually live in Spark's own materials, because it's easy to overstate: "narrow dependency" is real Spark terminology — it's the `NarrowDependency` abstract class in the Scala API (with `OneToOneDependency` and `RangeDependency` as concrete subclasses) — but it appears in the API reference, not the prose programming guide. "Wide dependency" is the term everyone uses for the other case, but there's no `WideDependency` class in the codebase at all; the class that actually implements it is `ShuffleDependency`. Both terms trace back to the original RDD paper (Zaharia et al., linked from spark.apache.org/research.html), not to the guide docs — accurate and standard vocabulary, just sourced from a different layer of Spark's materials than you'd assume.

## The query optimizer, commonly called "Catalyst"

Before your DAG becomes physical tasks, Spark rewrites it. It resolves references (analysis), applies rule-based rewrites like predicate pushdown, constant folding, and column pruning (logical optimization), picks concrete execution strategies like broadcast vs. sort-merge join (physical planning), and generates JVM bytecode for the result (whole-stage code generation). That pipeline is Spark's query optimizer.

Be precise about the name: **"Catalyst" does not appear in Spark's own prose documentation.** It's absent from the RDD programming guide, the SQL guide, and the performance tuning guide — all three just say "Spark's query optimizer." That doesn't make "Catalyst" informal or wrong; it's the real, standard industry name, sourced from the original Databricks engineering paper/blog that introduced it and baked directly into the codebase as the `org.apache.spark.sql.catalyst` package. Use it — just don't attribute it to Spark's prose docs as if you were quoting them.

The scope point that actually matters day to day: **Catalyst optimizes the DataFrame/Dataset/SQL logical plan — raw RDDs never go through it.** An RDD has no logical plan for the optimizer to analyze or rewrite; a `.map(lambda row: ...)` on an RDD is an opaque Python closure Spark can't see into. That's a concrete, measurable reason DataFrame/SQL code tends to outperform equivalent RDD code.

```python
enriched.filter("amount_usd > 100").explain(True)
# == Parsed Logical Plan ==
# == Analyzed Logical Plan ==
# == Optimized Logical Plan ==   <- Catalyst's rewrite: pushed filters, pruned columns
# == Physical Plan ==

# No equivalent exists for this - there's no plan for Catalyst to touch
df.rdd.filter(lambda row: row.amount_usd > 100)
```

## The senior framing

All of this is one story: transformations are free to write because they're just plan edits; the plan is a DAG that only gets scheduled when an action forces the question; the shape of that DAG — how many stages it has — is decided by narrow vs. wide dependencies; and before any of it runs, Catalyst has already rewritten the DataFrame/SQL version of that plan into something cheaper to execute, a rewrite raw RDDs never get. `.explain()` is how you check any of this without paying for a job. And wide dependencies are exactly what triggers a shuffle — covered in detail in [shuffle-and-partitioning.md](shuffle-and-partitioning.md).

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Assuming a transformation "ran" because the line executed without error | Transformations are lazy — nothing touched data, so timing/logging assumptions built around that line are wrong | Trigger an action (or use `.explain()`) at the point you actually want to force or inspect evaluation |
| Assuming all errors are deferred until an action runs | Schema/type errors are caught immediately at plan-build time (analysis phase); only data-dependent runtime errors wait for an action | Read the stack trace for which phase failed — an `AnalysisException` points at the transformation line, a runtime error points at the action |
| Treating `groupBy`/`join`/`distinct` as free because "it's lazy anyway" | Lazy means deferred, not cheap — a wide dependency still forces a full network shuffle and a new stage the moment an action runs | See [shuffle-and-partitioning.md](shuffle-and-partitioning.md) for sizing and avoiding shuffles |
| Writing heavy logic as RDD `.map()`/`.filter()` lambdas by default | RDDs have no logical plan, so Catalyst can't apply predicate pushdown, column pruning, or any other rewrite to that code | Prefer the DataFrame/Dataset/SQL API so the optimizer can actually see and rewrite the plan |
| Citing "Catalyst" as if quoting Spark's official documentation | The word doesn't appear in the RDD, SQL, or tuning guides — they only say "Spark's query optimizer" | Use "Catalyst" as the correct standard name (from the original engineering paper and the `org.apache.spark.sql.catalyst` package), but attribute it accurately, not as guide prose |
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/dataeng-spark/references/execution-model.md`
Expected: `7`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/dataeng-spark/references/execution-model.md
git commit -m "Add spark skill: execution model (lazy eval, DAG, Catalyst)"
```

---

### Task 2: `references/shuffle-and-partitioning.md`

**Files:**
- Create: `data-engineering-skills/skills/dataeng-spark/references/shuffle-and-partitioning.md`

**Interfaces:**
- Consumes: cross-link to `execution-model.md` (Task 1) for the wide-dependency definition.
- Produces: the file `shuffle-and-partitioning.md`, linked from `SKILL.md` (Task 8), `joins-and-skew.md` (Task 3), and `adaptive-query-execution-and-benchmarking.md` (Task 5, coalescing cross-link).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/dataeng-spark/references/shuffle-and-partitioning.md`:

````markdown
# Shuffle and Partitioning

Most non-trivial Spark jobs get slow for one of two reasons: a shuffle that didn't need to happen, or a shuffle that ran the way it had to but left data spread unevenly across the resulting partitions. Knowing what a shuffle actually costs — and what each partition-count API does and doesn't promise — is the difference between guessing at `.repartition(200)` and knowing what to fix.

## What shuffle is, and what it costs

Shuffle is Spark redistributing data across partitions — and usually across nodes — by key, so that rows the next stage needs to see together end up on the same partition. Any wide transformation triggers one: `groupBy`, a non-broadcast `join`, `distinct`, `repartition`, `orderBy`.

Spark's own docs (RDD Programming Guide, "Shuffle operations" → "Performance Impact") name exactly three cost factors — not just "it's slow because network": **disk I/O** (writing and reading shuffle files), **data serialization** (encoding/decoding records to move them), and **network I/O** (moving those files between executors). All three stack on every shuffle; there's no version of a shuffle that only pays one of these costs.

That's the senior framing behind every partitioning decision in this file: **first try to avoid the shuffle; if you can't, try to reduce its volume; and avoid skew.** An unevenly distributed shuffle key turns "expensive but manageable" into "one task runs for an hour while the other 199 finish in a minute." Detecting and fixing skew itself — salting, AQE's skew join handling — is covered in [joins-and-skew.md](joins-and-skew.md); this file stays focused on shuffle mechanics and the partition-count APIs sitting on top of it.

```python
# triggers a shuffle: groupBy needs every row for a given key on the same partition
df.groupBy("customer_id").agg({"amount": "sum"})

# avoids one: if the smaller side fits in memory, broadcast it - no shuffle for the join
from pyspark.sql.functions import broadcast
df.join(broadcast(small_df), "customer_id")
```

## `repartition` vs `coalesce`: full shuffle vs local merge

Both change how many partitions a DataFrame has, but they get there by different mechanisms:

- **`repartition(n)`** / **`repartition(n, *cols)`** — a full shuffle, wide dependency. Every partition's data gets redistributed across the cluster. Can move partition count up *or* down.
- **`coalesce(n)`** — merges existing partitions locally, a narrow dependency, no full shuffle. Cheaper, but because it just glues neighboring partitions together instead of redistributing rows, the result can come out unbalanced.

Practical rule: reach for `coalesce` right before a write, to collapse an overpartitioned DataFrame into a handful of output files — thousands of tiny files slow down every downstream read and put unnecessary load on the driver and the storage layer's file listing. Reach for `repartition` when you need to rebalance lopsided partitions or increase parallelism ahead of an expensive downstream transformation.

```python
# writing 200 shuffle partitions worth of data as-is -> thousands of small files
df.write.parquet("s3://bucket/output")

# coalesce first: cheap, no shuffle, collapses partitions before the write
df.coalesce(10).write.parquet("s3://bucket/output")
```

If you're also partitioning the output by a column (`df.write.partitionBy("country")`), that column's cardinality matters too: Spark's own `DataFrameWriter.partitionBy` docs recommend keeping partition columns under tens of thousands of distinct values, since each distinct value becomes its own output directory.

## `repartition` does not guarantee an even split

It's tempting to reach for `repartition(n, "customer_id")` and assume Spark evens the data out. It doesn't, and Spark's own docs don't promise that it does:

- The column-based overloads (`repartition(cols...)`, `repartition(n, cols...)`) redistribute via **hash partitioning** when given columns, which can still skew on a low-cardinality key — not a guaranteed even balance. Hash partitioning spreads *distinct key values* across partitions, not *rows*; if one key value dominates the dataset, every row for it lands in the same partition no matter how large `n` is.
- The columnless overload (`repartition(n)`) doesn't document its internal partitioning strategy in the official API reference at all — treat it as an implementation detail, not a balance guarantee.

```python
# hash-partitions by customer_id; if one customer_id is 40% of the rows,
# that single output partition ends up ~40% of the data regardless of n
df.repartition(200, "customer_id")
```

If the key itself is skewed, that's a skew problem, not something `repartition` will fix by adding more partitions — see [joins-and-skew.md](joins-and-skew.md) for salting and other mitigations.

## `coalesce(shuffle=True)`: an RDD-only escape hatch

Coming from the RDD API, you may remember `coalesce` taking a `shuffle: Boolean` parameter, default `false`. That parameter exists only on `RDD.coalesce(numPartitions, shuffle, ...)` — `DataFrame`/`Dataset.coalesce` has no such parameter and, by design, never shuffles.

```python
# RDD API only: shuffle=True adds an actual shuffle step, the only way
# to *increase* partition count through coalesce
rdd.coalesce(100, shuffle=True)

# DataFrame API: coalesce can only reduce partitions, never increase them
df.coalesce(1000)  # if df currently has 50 partitions, this is a silent no-op - still 50
```

Asking `coalesce` for more partitions than currently exist, without `shuffle=True` (or on the DataFrame API, which has no such option at all), is a documented no-op: partition count stays exactly where it was — no error, no warning.

## The senior framing

Every partitioning decision runs through the same order: can this shuffle be avoided entirely — a broadcast join, pre-partitioned storage, filtering before the wide operation? If not, can its volume be cut — project down to the columns actually needed, filter earlier in the plan? Only after that does "how do I control partition count" become the real question, and even then `repartition`'s hash-based redistribution is a rebalancing tool, not a guarantee — it will not rescue you from a genuinely skewed key. That's where [joins-and-skew.md](joins-and-skew.md) picks up: what happens when a shuffle meets a skewed key, and how to fix it.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Calling `.repartition(n, "key")` and assuming an even split | Hash partitioning distributes distinct key values, not rows — a dominant key value still lands on one partition | Diagnose actual skew first; use salting or AQE skew handling, not a bigger `n` |
| Using `repartition` to shrink partitions before a write | Pays for a full shuffle when a cheaper option exists | Use `coalesce` instead — narrow dependency, no full shuffle |
| Assuming `coalesce` can increase partition count | On the DataFrame API it silently no-ops; even on RDDs it needs `shuffle=True` | Use `repartition` to increase partitions, or `RDD.coalesce(n, shuffle=True)` |
| Leaving default shuffle partition count (200) on both tiny and huge jobs | Too many partitions for a small job wastes overhead; too few for a big job means each task handles too much data | Size shuffle partitions to the data, or let Adaptive Query Execution (AQE) coalesce them post-shuffle |
| High-cardinality `partitionBy` column on write | Explodes into huge numbers of output directories, each with small files | Keep partition columns under tens of thousands of distinct values; `coalesce` before writing |
| Treating "reduce shuffle volume" and "fix skew" as the same problem | A small, evenly-distributed shuffle and a small, skewed one behave completely differently | Address them separately - see [joins-and-skew.md](joins-and-skew.md) for skew specifically |
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/dataeng-spark/references/shuffle-and-partitioning.md`
Expected: `6`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/dataeng-spark/references/shuffle-and-partitioning.md
git commit -m "Add spark skill: shuffle and partitioning"
```

---

### Task 3: `references/joins-and-skew.md`

**Files:**
- Create: `data-engineering-skills/skills/dataeng-spark/references/joins-and-skew.md`

**Interfaces:**
- Consumes: cross-links to `shuffle-and-partitioning.md` (Task 2) and `adaptive-query-execution-and-benchmarking.md` (Task 5).
- Produces: the file `joins-and-skew.md`, linked from `SKILL.md` (Task 8) and from `shuffle-and-partitioning.md` (Task 2, already written — no back-edit needed since Task 2's cross-link is a forward reference by filename only).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/dataeng-spark/references/joins-and-skew.md`:

````markdown
# Joins and Data Skew

A join between two large, distributed DataFrames needs a shuffle so that matching keys land on the same executor — full stop, unless something avoids it. Spark gives you three ways to avoid or control that shuffle: broadcast the small side so no shuffle happens at all, let Adaptive Query Execution (AQE) rebalance an uneven shuffle after the fact, or pre-shuffle once at write time with bucketing so no join-time shuffle is needed at all. Picking the wrong strategy — or not knowing skew has a purpose-built automatic fix before reaching for manual workarounds — is what separates a job that finishes in minutes from one that limps along with one task running two hours after all the others finished. For shuffle mechanics themselves, see [shuffle-and-partitioning.md](shuffle-and-partitioning.md); for AQE's other optimizations, see [adaptive-query-execution-and-benchmarking.md](adaptive-query-execution-and-benchmarking.md).

## Broadcast joins: skip the shuffle for the small side

If one side of a join is small enough to fit comfortably in memory on every executor, Spark can send a full copy to each executor instead of shuffling both DataFrames. No shuffle means no network-bound stage and no risk of skew on that join at all — the join becomes a local, in-memory lookup on every partition of the large side.

You get this two ways. Explicitly, with the `broadcast()` hint:

```python
from pyspark.sql.functions import broadcast

result = orders.join(broadcast(dim_country), "country_code")
```

Or automatically: Spark estimates the size of each side from the query plan's statistics and broadcasts it if that estimate is under `spark.sql.autoBroadcastJoinThreshold`, whose default has been **10MB (10485760 bytes)** since Spark 1.1.0.

```python
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 100 * 1024 * 1024)  # raise to 100MB
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", -1)  # disable automatic broadcasting entirely
```

The failure mode runs in both directions. Leave the threshold too low and a dimension table that's genuinely small (say, 40MB) falls back to a full shuffle for no reason — you pay the shuffle cost for a join that didn't need it. Push the threshold up carelessly, or hint `broadcast()` on a table that turns out to be large, and every executor tries to hold a full copy in memory at once; that's a broadcast-timeout error or an executor OOM, not a performance win. Broadcast is for dimension tables and lookup tables, not for anything that could grow past a few hundred MB.

## Detecting data skew before you treat it as skew

Before reaching for any skew-mitigation technique, confirm you actually have skew rather than just a slow join. The fastest check is to count rows per output partition and look for one that dwarfs the rest:

```python
from pyspark.sql import functions as F

partition_counts = (
    df.groupBy(F.spark_partition_id().alias("partition_id"))
    .count()
)
stats = partition_counts.agg(
    F.max("count").alias("max_count"),
    F.avg("count").alias("avg_count"),
).first()

if stats["max_count"] / stats["avg_count"] > 2:
    print("Skew detected: largest partition is more than 2x the average")
```

A `max_count / avg_count` ratio past roughly 2x is a working heuristic for "one task is going to run far longer than the rest." (Pattern adapted from wshobson/agents' spark-optimization skill, MIT.) Skip this step and you risk salting a join that was actually slow for an unrelated reason — an under-provisioned cluster, a bad broadcast decision, or a genuinely large shuffle that's just... large.

## AQE's automatic skew-join optimization is the default fix

On Spark 3.0+, skew in a **sort-merge join** is Spark's problem to solve first, not yours. Adaptive Query Execution inspects actual shuffle output sizes at runtime — after the map stage has run, not from static estimates — and if it finds a skewed partition, it splits that partition's tasks into smaller sub-tasks (replicating the matching partition on the other side as needed) so no single task is stuck processing a disproportionate share of the data.

Both flags that gate this are already `true` by default in current Spark, so most jobs get this for free:

```python
spark.conf.get("spark.sql.adaptive.enabled")           # default true since Spark 3.2.0
spark.conf.get("spark.sql.adaptive.skewJoin.enabled")   # default true since Spark 3.0.0
```

A partition is classified as skewed, and eligible for the automatic split, when **both** conditions hold:

- its size exceeds `spark.sql.adaptive.skewJoin.skewedPartitionFactor` (default **5.0**) times the median partition size, **and**
- its size exceeds `spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes` (default **256MB**).

Both conditions exist so a tiny job with naturally uneven partitions (5x of a 2MB median is still nothing) doesn't trigger pointless splitting. If your join is skewed and both flags are at their defaults, you likely don't need to do anything — check the Spark UI's SQL tab for a "number of skewed partitions" annotation on the join stage before writing a single line of workaround code.

## Where skew-join optimization doesn't reach: aggregations

The automatic split above is scoped to **sort-merge joins only**. It does not fire for a skewed shuffle produced by a plain `groupBy`/aggregation — that shuffle has no join partner to replicate against, so there's nothing for the join-specific optimizer to split.

```python
# a skewed groupBy shuffle is NOT auto-fixed by skewJoin.enabled
df.groupBy("customer_id").agg(F.sum("amount"))
```

AQE has a related knob, `spark.sql.adaptive.optimizeSkewsInRebalancePartitions.enabled` (default `true`), but it only acts on partitions produced by an explicit `REBALANCE` hint — it is not automatic for a bare aggregation:

```python
df.hint("REBALANCE", "customer_id").groupBy("customer_id").agg(F.sum("amount"))
```

Without that hint, a skewed aggregation gets none of the automatic help a skewed join gets. This is the gap manual salting exists to fill.

## Manual salting: the fallback, not the default

Reach for salting when the automatic path genuinely doesn't apply: AQE or `skewJoin.enabled` is off, you're on Spark <3.0, or the skew lives in an aggregation with no `REBALANCE` hint. It is not the first tool to reach for on a modern, default-configured Spark cluster — treating it as the default is solving a problem Spark 3.0+ mostly solves for you, at the cost of code that's harder to read and easier to get subtly wrong (forgetting to strip the salt before the final aggregate is a classic bug).

The technique: append a random suffix to the hot key on **both** sides of the join, so rows that used to collide on one key now spread across several synthetic keys, then remove the suffix (or re-aggregate across it) afterward.

```python
from pyspark.sql import functions as F

SALT_BUCKETS = 10

orders_salted = orders.withColumn(
    "salted_key", F.concat(F.col("customer_id"), F.lit("_"), (F.rand() * SALT_BUCKETS).cast("int"))
)

# explode the small side across every salt bucket so each salted key on the left has a match
customers_salted = customers.crossJoin(
    spark.range(SALT_BUCKETS).withColumnRenamed("id", "salt")
).withColumn("salted_key", F.concat(F.col("customer_id"), F.lit("_"), F.col("salt")))

result = orders_salted.join(customers_salted, "salted_key")
```

For a skewed aggregation without a `REBALANCE` hint available, the same idea applies: salt the group key, aggregate at the salted grain, then aggregate again across the salt to collapse it back to the true grain.

## Bucket joins: eliminating the shuffle at write time

Broadcast avoids the shuffle by copying; AQE's skew handling repairs an uneven shuffle after the fact. Bucketing avoids the shuffle altogether, at query time, by doing the equivalent work once at write time instead. `bucketBy` pre-partitions rows by hash of the join key into a fixed number of buckets, `sortBy` sorts within each bucket, and the result is written so that two tables bucketed identically on the same key can be joined with **no shuffle at all** — each bucket file is already co-located and sorted, so Spark reads matching buckets straight into a sort-merge join with the shuffle step skipped entirely.

```python
(
    orders.write
    .bucketBy(200, "customer_id")
    .sortBy("customer_id")
    .saveAsTable("orders_bucketed")
)

(
    customers.write
    .bucketBy(200, "customer_id")
    .sortBy("customer_id")
    .saveAsTable("customers_bucketed")
)

# joining two tables bucketed on the same key, with the same bucket count, needs no shuffle
spark.table("orders_bucketed").join(spark.table("customers_bucketed"), "customer_id")
```

(Adapted from wshobson/agents' spark-optimization skill, MIT.) The upfront cost is a shuffle at write time and committing to a fixed bucket count for both tables — get the bucket count or column mismatched between the two tables and Spark silently falls back to a full shuffle join, so this pays off specifically for tables that get joined repeatedly on the same key, not for a one-off join.

## The senior framing

Every distributed join decision runs on the same question as any single-node join, plus one more axis: **can the shuffle be avoided, repaired, or pre-paid?** Broadcast avoids it outright for small tables. AQE's skew-join optimization repairs an uneven shuffle after Spark has already seen the real partition sizes — and it's the default answer for sort-merge join skew on Spark 3.0+, not something you reimplement by hand. Bucketing pre-pays the shuffle once, at write time, for keys you know you'll join on repeatedly. Manual salting is what's left over for the cases those three don't cover — a skewed aggregation with no `REBALANCE` hint, an old Spark version, or AQE deliberately disabled. Knowing that ordering, and reaching for the Spark UI to confirm skew before writing salting code, is what separates someone who's read about skew from someone who's actually debugged it in production.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Salting every skewed join by default | Reimplements, by hand and worse, what AQE's skew-join optimization already does automatically on Spark 3.0+ | Confirm `spark.sql.adaptive.skewJoin.enabled` is on and check the Spark UI before writing salting code |
| Assuming skew-join optimization fixes a skewed `groupBy` | It only fires for sort-merge joins, not aggregation shuffles | Add a `REBALANCE` hint, or salt the aggregation manually |
| Raising `autoBroadcastJoinThreshold` without checking table size | A table that's actually large gets broadcast, causing executor OOM or a broadcast timeout | Only raise the threshold for tables you've confirmed stay well under it |
| Bucketing two tables with mismatched bucket counts or columns | Spark silently falls back to a full shuffle join, losing the entire point of bucketing | Match bucket count and bucket column exactly on both tables |
| Treating a slow join as skew without checking partition sizes | Wastes effort salting a join that was slow for an unrelated reason | Run a `spark_partition_id()` count check first; only treat >2x max/avg as skew |
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/dataeng-spark/references/joins-and-skew.md`
Expected: `8`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/dataeng-spark/references/joins-and-skew.md
git commit -m "Add spark skill: joins and data skew"
```

---

### Task 4: `references/caching-and-file-formats.md`

**Files:**
- Create: `data-engineering-skills/skills/dataeng-spark/references/caching-and-file-formats.md`

**Interfaces:**
- Consumes: cross-links to `memory-management.md` (Task 6) and `pyspark-specifics.md` (Task 7) — both forward references by filename.
- Produces: the file `caching-and-file-formats.md`, linked from `SKILL.md` (Task 8).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/dataeng-spark/references/caching-and-file-formats.md`:

````markdown
# Caching and File Formats

Spark's laziness means a DataFrame is a recipe, not a result — every action re-walks the lineage from source to output. That's fine when a DataFrame is consumed once. It becomes expensive fast when the same DataFrame feeds multiple downstream actions, when its lineage itself grows long enough to be costly to plan, or when the storage format forces Spark to read more than the query actually needs. This file covers the tools for each: caching and checkpointing to control recomputation, and Parquet's pushdown/partitioning behavior to control how much gets read off disk in the first place.

## Caching and persisting reused DataFrames

Call `.cache()` or `.persist()` when a DataFrame feeds more than one action — otherwise Spark recomputes its entire lineage, from the original read, once per action.

```python
df_clean = (
    spark.read.parquet("s3://bucket/events/")
    .filter(F.col("status") == "active")
    .withColumn("day", F.to_date("ts"))
)

df_clean.persist()

daily_counts = df_clean.groupBy("day").count()
top_users = df_clean.groupBy("user_id").count().orderBy(F.desc("count")).limit(100)
```

Without `persist()`, both `daily_counts` and `top_users` trigger a fresh read-and-filter of the underlying Parquet files. With it, the second action reuses the materialized result from the first.

## Storage levels: memory vs disk, serialized vs not

`.cache()` is shorthand for `.persist()` with a default storage level — but the default is not the same for RDDs and DataFrames, and this trips people up. RDD's `.cache()` defaults to `MEMORY_ONLY`: if it doesn't fit, the excess partitions are simply dropped and recomputed on demand. DataFrame's `.persist()` default is different — it lands in the `MEMORY_AND_DISK` family, deserialized, spilling to disk instead of dropping data when memory runs out. (Spark's own docs aren't fully consistent on the exact constant name here — treat "MEMORY_AND_DISK family, deserialized" as the accurate description rather than memorizing one literal symbol.)

Pick explicitly when the default doesn't fit the workload:

```python
from pyspark import StorageLevel

df_clean.persist(StorageLevel.MEMORY_ONLY_SER)    # serialized: less memory, more CPU to deserialize on read
df_clean.persist(StorageLevel.DISK_ONLY)           # won't touch execution memory at all
df_clean.persist(StorageLevel.MEMORY_AND_DISK_2)   # replicated to a second node, survives executor loss
df_clean.persist(StorageLevel.OFF_HEAP)            # outside the JVM heap, needs off-heap memory configured
```

Serialized levels (`_SER`) trade CPU for memory footprint — worth it for wide rows or high cardinality. The `_2` suffix replicates each partition to two nodes, which costs double the storage for resilience against losing a single executor's cache. Persisted data draws from the same pool as execution memory, so caching too aggressively causes the pressure discussed in [memory-management.md](memory-management.md) — it doesn't sidestep it.

## Unpersisting: no leak detector, only LRU and your judgment

Spark does not warn you about a DataFrame that's cached and never released. There's no leak-detection pass — cached blocks just sit there until either memory pressure forces an LRU eviction, or you call `.unpersist()` yourself.

```python
df_clean.unpersist()               # non-blocking: returns immediately, eviction happens async
df_clean.unpersist(blocking=True)  # wait until the blocks are actually freed before continuing
```

Waiting on LRU works, but it means a stale cache sits in memory competing with everything else until pressure forces it out — degrading other jobs in the meantime. If you know a DataFrame won't be reused again, `.unpersist()` it explicitly rather than letting eviction pressure be your memory management strategy.

## Checkpointing: truncating lineage, not just materializing it

*(Adapted from wshobson/agents' spark-optimization skill, MIT.)*

Caching and checkpointing solve different problems. Caching materializes data but keeps the lineage graph around, so Spark can recompute from it if the cached partitions are evicted. Checkpointing writes the DataFrame to reliable storage and discards the lineage entirely — there's nothing left to recompute from.

```python
spark.sparkContext.setCheckpointDir("s3://bucket/checkpoints/")

long_chain = (
    df1.join(df2, "id")
    .join(df3, "id")
    .groupBy("category")
    .agg(F.sum("amount").alias("total"))
)
checkpointed = long_chain.checkpoint()
```

Reach for this when the lineage graph itself — not just the data — is the expensive part: many chained joins and aggregations produce a DAG that's costly for the driver to track and for the catalyst optimizer to plan against on every subsequent action. Checkpointing resets that graph to a single read from the checkpoint files. Caching a DataFrame in the same situation still leaves the long lineage attached as a fallback.

## Parquet and predicate pushdown

Parquet is the default columnar format for Spark workloads, and predicate pushdown is a real, measurable optimization on top of it — gated by `spark.sql.parquet.filterPushdown`, which defaults to `true`.

```python
spark.conf.get("spark.sql.parquet.filterPushdown")  # 'true'

df.filter(F.col("event_date") == "2024-01-15").select("user_id", "amount")
```

With pushdown on, the `event_date` filter is handed to the Parquet reader itself, which uses the min/max statistics stored in each row group's footer to skip row groups that can't match — without decompressing or scanning them.

## Projection pushdown: column pruning without a flag

The `.select("user_id", "amount")` above also benefits from projection pushdown — Spark reads only the referenced columns off disk, which Parquet's columnar layout makes cheap. It's a real optimization, but it isn't a separately named, gated feature the way predicate pushdown is: there's no `spark.sql.parquet.projectionPushdown` toggle to check or disable. It's simply the default behavior of a columnar reader given a `.select()`. Selecting fewer columns earlier in a pipeline is close to free — don't wait until a later stage to trim columns you never use.

## Partitioning on write: sizing partitions sanely

`df.write.partitionBy(...)` avoids two opposite failure modes: one enormous file that can't be read in parallel, or, at the other extreme, an explosion of tiny files where per-file overhead dominates actual work — a pattern the community calls the "small files problem" (that's practitioner vocabulary, not a phrase Spark's own docs use).

```python
df.write.partitionBy("country", "event_date").parquet("s3://bucket/output/")
```

Spark's `DataFrameWriter.partitionBy` guidance gives a concrete cardinality boundary: the number of distinct values in a partition column should typically stay under tens of thousands. Partitioning by something like `user_id` blows past that — millions of directories, each holding a handful of rows, dominated by file-open and listing overhead rather than actual scan work. Past that cardinality threshold, use `bucketBy` instead, which doesn't have the same ceiling.

## `approx_count_distinct`: skip the shuffle when exact isn't needed

*(Adapted from wshobson/agents' spark-optimization skill, MIT.)*

`countDistinct` requires a full shuffle to deduplicate values across partitions before it can count them — expensive at high cardinality. When an approximate cardinality is good enough (dashboards, monitoring, order-of-magnitude checks), `approx_count_distinct` uses a HyperLogLog sketch instead, which merges cheaply across partitions without a full shuffle.

```python
df.select(F.approx_count_distinct("user_id", rsd=0.05)).show()
```

`rsd` controls the accuracy/cost tradeoff — smaller values are more precise and cost more sketch memory. This is not a drop-in replacement when the exact count matters (billing, dedup logic); it's for the common case where "roughly 4.2 million distinct users" is exactly as useful as "4,213,908."

Getting caching, checkpointing, and file layout right is what separates a job that runs once and a job that runs correctly every day at 3x the data volume. Caching and checkpointing are about controlling *recomputation* — decide explicitly whether Spark should hold materialized data with a lineage fallback, or cut the lineage entirely. Parquet's pushdown and partitioning are about controlling *how much gets read in the first place* — before caching or checkpointing even become relevant. None of this replaces watching driver memory on `.collect()`/`.toPandas()` (see [pyspark-specifics.md](pyspark-specifics.md)) or understanding how persisted data competes with execution memory (see [memory-management.md](memory-management.md)) — it's a companion to both, not a substitute.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Calling `.persist()` and assuming it behaves like RDD's `MEMORY_ONLY` | DataFrame's default is the `MEMORY_AND_DISK` family — different eviction and spill behavior than expected | Know the actual default, or pass an explicit `StorageLevel` |
| Never calling `.unpersist()` on DataFrames that are done being reused | Stale cached data competes with execution memory until LRU eviction eventually forces it out | Unpersist explicitly once a DataFrame's reuse is over |
| Reaching for `.cache()` on a DataFrame built from a long join/aggregation chain | Caching keeps the expensive lineage graph attached as a fallback — doesn't solve planning overhead | Use `.checkpoint()` to truncate the lineage instead |
| Assuming projection pushdown is a config flag like predicate pushdown | There's no equivalent boolean to check or disable — it's implicit reader behavior | Just call `.select()` early; verify via the physical plan, not a config |
| Partitioning writes by a high-cardinality column (e.g. `user_id`) | Produces millions of tiny files - listing/open overhead dominates actual I/O | Keep partition columns under roughly tens of thousands of distinct values; use `bucketBy` beyond that |
| Using `countDistinct` when an approximate cardinality is good enough | Forces a full shuffle to get exactness nobody needed | Use `approx_count_distinct` with a tolerable `rsd` |
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/dataeng-spark/references/caching-and-file-formats.md`
Expected: `9`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/dataeng-spark/references/caching-and-file-formats.md
git commit -m "Add spark skill: caching and file formats"
```

---

### Task 5: `references/adaptive-query-execution-and-benchmarking.md`

**Files:**
- Create: `data-engineering-skills/skills/dataeng-spark/references/adaptive-query-execution-and-benchmarking.md`

**Interfaces:**
- Consumes: cross-links to `shuffle-and-partitioning.md` (Task 2) and `joins-and-skew.md` (Task 3).
- Produces: the file `adaptive-query-execution-and-benchmarking.md`, linked from `SKILL.md` (Task 8).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/dataeng-spark/references/adaptive-query-execution-and-benchmarking.md`:

````markdown
# Adaptive Query Execution and Benchmarking

A physical query plan built before execution is a bet on statistics that are frequently wrong — stale table metadata, a UDF whose output size the optimizer can't estimate, a filter that turns out far more selective than the histogram predicted. Adaptive Query Execution (AQE) exists to correct that bet mid-flight, using real numbers instead of guesses. But even a perfectly optimized plan can produce a misleading benchmark if you measure it under cache conditions that don't match production — a mistake that has nothing to do with Spark's optimizer and everything to do with how you ran the timer. Both topics are about the same underlying discipline: don't trust a static assumption when a runtime measurement is available instead.

## Why AQE exists: runtime beats static estimates

Spark's cost-based optimizer picks join strategies, shuffle partition counts, and join ordering using statistics gathered *before* the query runs — table row counts, column histograms, size estimates propagated through each operator. Those estimates degrade fast: `ANALYZE TABLE` wasn't rerun after a large load, a `WHERE` clause is more selective than the histogram assumes, or a UDF output size is simply unknowable ahead of time. AQE was redesigned in Spark 3.0.0 to address exactly this — it splits the physical plan at shuffle boundaries (materialization points) and, once a stage actually finishes, re-optimizes the *remaining* stages using the real row counts and partition sizes that stage produced. It became enabled by default starting in Spark 3.2.0 (`spark.sql.adaptive.enabled=true`), so unless you're running an older cluster or someone explicitly disabled it, it's already in play.

## At least five documented optimizations, not three

A lot of write-ups repeat "AQE has three features" — that was true of the early 3.0 docs, but Spark's current official documentation (4.2.0) lists at least five, and treating the number as fixed is how you get caught flat-footed by a release note. Say "at least five documented optimizations" rather than committing to a count that has already changed once:

- **Coalescing post-shuffle partitions** — merging many small shuffle partitions into fewer, right-sized ones (see below).
- **Converting sort-merge join to broadcast join** when runtime stats reveal one side is actually small.
- **Converting sort-merge join to shuffled-hash join** when a partition's build side is small enough to hash in memory without a full-table broadcast.
- **Optimizing skew joins** — covered in depth in [joins-and-skew.md](joins-and-skew.md); the mechanics aren't repeated here.
- At least one more, depending on the exact release — check the docs for the Spark version you're actually running instead of assuming the list from a blog post or a training you did two years ago is still complete.

## Coalescing shuffle partitions: automating what you used to do by hand

Before AQE, getting shuffle partition count right meant tuning `spark.sql.shuffle.partitions` for the whole job and living with the consequences on every stage — too high and you get thousands of tiny tasks dominated by scheduling overhead, too low and each task spills. AQE removes the single-number tradeoff: it starts from a high partition count, then, once a shuffle stage completes, merges adjacent small partitions together so each output partition lands near `spark.sql.adaptive.advisoryPartitionSizeInBytes` (default 64MB). This is the runtime, automatic counterpart to the manual `repartition()`/`coalesce()` guidance in [shuffle-and-partitioning.md](shuffle-and-partitioning.md) — that file covers when and why to call those APIs directly; this is Spark doing the same right-sizing for you, after the shuffle, based on actual bytes written instead of a guess made before any data moved.

```python
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")  # default: true
spark.conf.set("spark.sql.adaptive.advisoryPartitionSizeInBytes", "128m")
```

## Switching join strategies once the real sizes are known

The classic failure mode: a static plan sees a large table on one side of a join and picks sort-merge join (SMJ) — full shuffle of both sides — because the pre-execution size estimate says neither side qualifies for a broadcast. After an upstream filter or aggregation actually runs, the filtered side might be a few megabytes. AQE checks the *actual* post-shuffle size against `spark.sql.adaptive.autoBroadcastJoinThreshold` and, if it now qualifies, swaps in a broadcast hash join before the join stage executes — skipping a shuffle that a static plan would have paid for unconditionally. A similar runtime check converts SMJ to shuffled-hash join when a given partition's build side is small enough to hash in memory, without needing the whole relation to clear the broadcast threshold.

```python
df_result = large_df.join(maybe_small_df, "customer_id")
df_result.explain("formatted")  # look for "AdaptiveSparkPlan isFinalPlan=true"
                                  # and check which join physical operator actually ran
```

Skew join handling is the fifth (well-documented) AQE optimization from the list above, and it deserves its own treatment rather than a paragraph here — see [joins-and-skew.md](joins-and-skew.md) for how AQE detects and splits skewed partitions.

## Confirming AQE actually did something

`explain("formatted")` on a completed (or completing) query shows `AdaptiveSparkPlan isFinalPlan=true` once the final, runtime-adjusted plan is locked in. If you're debugging "why didn't AQE kick in," check three things in order: is `spark.sql.adaptive.enabled` actually true on this session (someone may have disabled it for a reproducibility test), does the query even have a shuffle boundary for AQE to re-optimize around (a single-stage scan has nothing to adapt), and is `spark.sql.adaptive.coalescePartitions.enabled` / `.skewJoin.enabled` also on — the umbrella flag doesn't imply the sub-features are.

## The cache state you benchmark on is not optional context — it's the result

This part is not in Spark's own documentation. It's worth saying plainly rather than inventing a citation: a full-text search of Spark's official `tuning.html` and `sql-performance-tuning.html` turns up nothing about cold-vs-warm benchmarking — this is standard distributed-systems and JVM benchmarking discipline, not a Spark-specific feature. A first run against a table is cold in three independent ways at once: nothing is cached or persisted in Spark, the JVM hasn't JIT-compiled the hot code paths yet, and the OS page cache on the executors hasn't been primed with the relevant blocks. A benchmark taken on that first run and a benchmark taken on the tenth run of the same query can differ by multiples — and which one you report determines whether the job looks "slow" or "fine."

```python
import time

# WRONG when production runs this query repeatedly on a warm cluster:
# this times cold I/O and JIT warmup, not steady-state performance.
start = time.perf_counter()
spark.sql("SELECT * FROM fact_orders WHERE order_date = '2026-07-28'").collect()
print(f"cold: {time.perf_counter() - start:.2f}s")
```

```python
# Matching a warm, steady-state production profile: materialize first,
# discard that timing, then measure the run that actually resembles prod.
df = spark.sql("SELECT * FROM fact_orders WHERE order_date = '2026-07-28'")
df.cache()
df.count()  # forces materialization and warms the cache - not the number you report

start = time.perf_counter()
df.count()  # this is the steady-state number
print(f"warm: {time.perf_counter() - start:.2f}s")
```

## Matching your benchmark to production, not the other way around

The fix isn't "always benchmark warm" or "always benchmark cold" — it's that whichever one production actually is, your benchmark has to match it, or the number is fiction. A job that runs once nightly on freshly-provisioned executors is genuinely a cold-cache workload — benchmarking it warm will understate its real runtime and hide a problem that will show up in production every single night. A job hitting a long-lived cluster with data already cached from upstream jobs is a warm workload — benchmarking it cold will overstate the fix's impact and make a change look like a bigger win than it is in steady state. Neither is more "correct" in the abstract; the only wrong answer is picking one without checking which one production is.

## Senior framing

Anyone can turn on `spark.sql.adaptive.enabled` and move on — it's true by default anyway on any cluster running 3.2+. What separates a senior engineer is knowing *why* AQE exists (static estimates rot, runtime stats don't), being able to point at `explain("formatted")` and show which specific optimization fired instead of asserting AQE "did something," and treating benchmark methodology as part of the deliverable rather than an afterthought. A number without a stated cache state is not a benchmark, it's an anecdote — and the honest answer to "is this fast" is "fast under which conditions, and do those conditions match where it actually runs."

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Claiming AQE has "three main features" | The list has grown since Spark 3.0 - current docs list at least five | Say "at least five documented optimizations" and check the version's actual docs |
| Assuming AQE ran just because it's "on by default" | The umbrella flag doesn't guarantee coalescing/skew sub-flags are enabled, or that the query even has a shuffle boundary to adapt | Check `explain("formatted")` for `AdaptiveSparkPlan isFinalPlan=true` and confirm the sub-feature flags |
| Manually tuning `spark.sql.shuffle.partitions` to fix small-partition overhead | AQE already coalesces post-shuffle partitions at runtime - a static override can fight it | Let `spark.sql.adaptive.coalescePartitions.enabled` and `advisoryPartitionSizeInBytes` handle it, tune those instead |
| Re-explaining skew-join mechanics here instead of cross-referencing | Duplicates content that's covered properly elsewhere and drifts out of sync | Point to [joins-and-skew.md](joins-and-skew.md) for the mechanics |
| Benchmarking a job cold when production runs it warm (or vice versa) | Inverts the perceived result - a "slow" cold benchmark can be fast in production's steady state, or a fine-looking cold number can hide a real warm-cache problem | Match the benchmark's cache state to production's actual cache state before trusting the number |
| Citing Spark's official docs for the cold/warm benchmarking pitfall | It isn't there - verified absent from `tuning.html` and `sql-performance-tuning.html` | Attribute it to general distributed-systems/JVM benchmarking practice, not a Spark doc |
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/dataeng-spark/references/adaptive-query-execution-and-benchmarking.md`
Expected: `9`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/dataeng-spark/references/adaptive-query-execution-and-benchmarking.md
git commit -m "Add spark skill: adaptive query execution and benchmarking"
```

---

### Task 6: `references/memory-management.md`

**Files:**
- Create: `data-engineering-skills/skills/dataeng-spark/references/memory-management.md`

**Interfaces:**
- Consumes: cross-link to `pyspark-specifics.md` (Task 7, forward reference by filename).
- Produces: the file `memory-management.md`, linked from `SKILL.md` (Task 8) and from `caching-and-file-formats.md` (Task 4, already written).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/dataeng-spark/references/memory-management.md`:

````markdown
# Executor and Driver Memory Management

Most Spark memory problems aren't "not enough RAM" — they're "the JVM heap is subdivided in a way you don't understand, and the abstraction just leaked." A job that spills to disk mid-shuffle isn't broken; a cache that silently gets evicted isn't broken either — but a `.collect()` that OOMs the driver absolutely is, and knowing which failure mode you're looking at is the difference between tuning a config and rewriting a pipeline.

## The unified memory region

Since Spark 1.6, execution memory (shuffles, joins, sorts, aggregations) and storage memory (cached/persisted RDDs and DataFrames) share a single region of the executor's JVM heap instead of living in separate, statically-sized pools. That region is carved out of the heap after a fixed reservation for Spark's own internal bookkeeping (300 MB by default, non-configurable in production).

Two properties control the split:

- `spark.memory.fraction` — the share of (heap − reserved memory) given to the unified execution+storage region. **Default 0.6**, set in Spark **2.0.0** (SPARK-15796) — this is not a recent 3.x tuning change, it's a long-standing default.
- `spark.memory.storageFraction` — within that unified region, the fraction **guaranteed** to storage before execution is allowed to evict it. **Default 0.5**.

```
spark.driver.memory            4g
spark.executor.memory          8g
spark.memory.fraction          0.6   # default since 2.0.0
spark.memory.storageFraction   0.5   # default
```

The remaining 40% of the post-reservation heap is user memory — your own objects, UDF state, data structures outside Spark's managed regions — and Spark doesn't arbitrate that part at all.

## Execution and storage borrow from each other, but not equally

Because the region is unified, execution and storage don't have hard-walled sub-allocations — each can borrow space the other isn't currently using. The catch is priority: **execution memory always wins**. If a shuffle or sort needs more space than is currently free, it can evict cached blocks down to storage's guaranteed minimum (`storageFraction`); storage can never evict execution to make room for itself.

When execution itself runs out of room — a sort or a shuffle that doesn't fit even after reclaiming everything it can — it doesn't fail the job. It **spills** the excess to disk and keeps going, just slower. That's the correct mental model for "job got slow" vs. "job died": spilling degrades performance, it doesn't throw.

## Cached data eviction is silent — that's what makes it dangerous

When execution reclaims space from storage, the evicted blocks are chosen by LRU. That cached DataFrame or RDD you `.persist()`'d doesn't disappear — it's just gone from memory. The next time something reads it, Spark recomputes it from lineage, transparently, with no error and no log line shouting about it.

That's exactly the trap: nothing fails, so nothing tells you it happened. A pipeline that "used to be fast" after someone added a memory-heavy join upstream is a classic symptom — the cache is being silently evicted and recomputed every iteration. Two ways to confirm and fix it:

- Check the **Storage** tab in the Spark UI — "Fraction Cached" below 100% means eviction is happening.
- If recomputation from lineage is expensive (long DAG, expensive source read) and you need the result to actually stick, `checkpoint()` it instead of just `persist()` — checkpointing writes to reliable storage and truncates lineage, so there's nothing to fall back to and nothing to recompute.

## The driver is a coordinator, not a worker

The driver hosts the `SparkContext`, builds the DAG, and schedules tasks onto executors — it does not participate in distributed computation. Executors are where partitions actually get processed, and each executor's own execution/storage split (as above) governs only its own partitions.

The driver's memory problems come from a different source entirely: anything that pulls distributed data back to a single JVM. `.collect()` is the textbook case — it materializes every partition, from every executor, into the driver's heap at once. A DataFrame that's perfectly fine distributed across 200 executors can trivially OOM a driver sized for coordination, not for holding the whole dataset. (See [pyspark-specifics.md](pyspark-specifics.md) for the PySpark-specific version of this — `.toPandas()` carries the identical risk, plus a serialization cost on top.)

```python
# Fine: aggregation stays distributed, only the small result comes back
summary = df.groupBy("region").count().collect()

# Driver OOM waiting to happen: every row of a large DataFrame lands on one JVM
all_rows = huge_df.collect()
```

## Broadcast variables: built by the driver, held by every executor

A common misreading of the model: because the driver *creates* a broadcast variable, it's tempting to think the driver keeps holding it. It doesn't, in any way that matters for sizing. The driver serializes the value once and ships it out; from then on, **each executor caches its own local copy** in its own executor memory, so it can be read locally by every task on that executor without repeated network round-trips.

```python
from pyspark.sql.functions import broadcast

# small_df is broadcast to every executor and cached there - not on the driver
result = large_df.join(broadcast(small_df), "id")
```

That means an oversized broadcast doesn't primarily threaten the driver's steady-state memory — it threatens every executor's storage region, all at once, which is a much easier way to trigger cluster-wide pressure than it sounds.

## Sizing the two pools

`spark.executor.memory` sizes the heap each executor's execution/storage split is carved from; `spark.driver.memory` sizes the driver's own heap. They're independent knobs for independent jobs — the driver coordinates and occasionally collects, executors compute — and driver memory in particular needs real headroom for anything the application deliberately pulls back (`.collect()`, `.toPandas()`, accumulator results, broadcast build data before it ships), not just for running the scheduler.

None of this is exotic tuning — it's the baseline model for reading a Spark UI page without guessing. "Executor lost / OOM" reads differently once you know whether it's the driver or an executor, and "job is slow but didn't fail" reads differently once spilling and cache eviction are on your list of suspects instead of shrugged off as noise.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Assuming `spark.memory.fraction` is a Spark 3.x tuning knob | Leads to hunting for the wrong changelog/version notes when tuning older clusters | It's a Spark 2.0.0 default (SPARK-15796); the unified model itself is from 1.6 |
| Treating cache eviction as "the cache is broken" | Masks the real issue - execution pressure upstream - and wastes time debugging the wrong stage | Check the Storage tab for Fraction Cached; if lineage is expensive, `checkpoint()` instead of relying on `persist()` |
| `.collect()` / `.toPandas()` on a DataFrame sized for the cluster, not the driver | Silently fine in dev on small data, OOMs the driver in production at scale | Aggregate/filter down first, or write to storage and read back if the full dataset is genuinely needed on one machine |
| Assuming a large broadcast table only costs the driver | Actually pressures every executor's storage region simultaneously - a cluster-wide spike, not a single-node one | Keep broadcast tables small (tens of MB, not GB) and check `spark.sql.autoBroadcastJoinThreshold` before relying on auto-broadcast |
| Bumping `spark.executor.memory` to fix spilling without checking `storageFraction` | Can throw memory at a problem that's actually about execution/storage balance, not total size | Look at whether it's spilling (execution-bound) or evicting cache (storage-bound) before resizing anything |
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/dataeng-spark/references/memory-management.md`
Expected: `7`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/dataeng-spark/references/memory-management.md
git commit -m "Add spark skill: executor and driver memory management"
```

---

### Task 7: `references/pyspark-specifics.md`

**Files:**
- Create: `data-engineering-skills/skills/dataeng-spark/references/pyspark-specifics.md`

**Interfaces:**
- Consumes: cross-link to `memory-management.md` (Task 6, already written).
- Produces: the file `pyspark-specifics.md`, linked from `SKILL.md` (Task 8) and from `memory-management.md` (Task 6, already written) and `caching-and-file-formats.md` (Task 4, already written).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/dataeng-spark/references/pyspark-specifics.md`:

````markdown
# PySpark-Specific Concerns

PySpark's execution engine lives entirely in the JVM: DataFrame API calls build a logical plan that Catalyst optimizes and executors run natively, with zero Python in the hot path. That changes the moment you introduce a row-at-a-time Python UDF, or call `.collect()` / `.toPandas()` — each forces data or control across the JVM↔Python boundary in a specific, costly way. Misdiagnosing *where* and *why* that boundary gets crossed is the single most common source of "PySpark is slow" and "the driver just OOM'd" tickets.

## Why a regular Python UDF is slow — and it isn't Py4J

Py4J is a driver-only mechanism. It's how your Python driver process talks to the driver's JVM (submitting jobs, receiving results) — it never runs on executors and it is not involved in executing your UDF's row logic. Blaming "py4j overhead" for slow UDFs is a common but wrong diagnosis.

What actually happens on each executor, per Spark's own ["Debugging PySpark"](https://spark.apache.org/docs/latest/api/python/development/debugging.html) documentation and the Apache Spark project's ["PySpark Internals"](https://cwiki.apache.org/confluence/display/SPARK/PySpark+Internals) wiki page: every executor JVM launches a **separate Python worker subprocess**. Row data is serialized on the JVM side, streamed to that worker over a local socket/pipe, deserialized into Python objects, run through your function one row at a time, then serialized back and sent to the JVM. There is no shared memory and no in-process call — it's full inter-process communication, per row.

That per-row serialize → IPC → deserialize → execute → serialize → IPC round trip is what makes row-at-a-time UDFs slow, not any single hop. A native Spark SQL expression (`col + 1`, `when/otherwise`, built-in functions) never leaves the JVM at all. A Scala/Java UDF runs inside the executor JVM, in-process. A Python UDF pays cross-process tax on every single row.

```python
from pyspark.sql.functions import udf
from pyspark.sql.types import DoubleType

# Each row: JVM -> serialize -> pipe -> Python worker -> deserialize ->
# run function -> serialize -> pipe -> JVM. Repeated per row, per partition.
@udf(returnType=DoubleType())
def celsius_to_fahrenheit(c):
    return c * 9.0 / 5.0 + 32.0 if c is not None else None

df = df.withColumn("temp_f", celsius_to_fahrenheit(df.temp_c))
```

As of Spark 4.2.0, regular UDFs use Apache Arrow for (de)serialization by default (`spark.sql.execution.pythonUDF.arrow.enabled`), replacing plain pickle. That reduces serialization cost, but the UDF still runs one row at a time in a separate process — Arrow makes the crossing cheaper, it doesn't remove the crossing.

## Pandas UDFs: amortizing the IPC tax over a batch

"Pandas UDFs" (a.k.a. "Vectorized UDFs" — this is still Spark's current official terminology, introduced in Spark 2.3.0) fix the *unit of transfer*, not the mechanism: data still moves JVM↔Python, but as whole Arrow-backed batches of a pandas Series/DataFrame instead of one row at a time. Your function is called once per batch, operates with vectorized pandas/NumPy operations, and returns a batch back. The fixed per-call serialization and IPC cost is paid once per batch instead of once per row, which is why Pandas UDFs are meaningfully faster than row-at-a-time UDFs at scale.

```python
import pandas as pd
from pyspark.sql.functions import pandas_udf
from pyspark.sql.types import DoubleType

# Called once per batch: the JVM<->Python crossing happens per Arrow
# record batch, and the body runs as a single vectorized pandas op.
@pandas_udf(DoubleType())
def celsius_to_fahrenheit_vectorized(c: pd.Series) -> pd.Series:
    return c * 9.0 / 5.0 + 32.0

df = df.withColumn("temp_f", celsius_to_fahrenheit_vectorized(df.temp_c))
```

Separately, "Pandas Function APIs" — `mapInPandas` and `applyInPandas` — are newer *additions* built on the same Arrow/Pandas UDF machinery, for cases where you need to transform a whole partition's worth of rows (arbitrary row count in, arbitrary row count out) rather than a column-in/column-out mapping. They are not a replacement for Pandas UDFs; pick based on the shape of the transformation (column-wise vectorized math → Pandas UDF; group-wise or row-count-changing logic → the Function APIs), not because one is "the new one."

## The driver-memory trap: `.collect()` and `.toPandas()`

Both methods pull the **entire distributed DataFrame** into the driver process as a single in-memory Python structure — a `list[Row]` for `.collect()`, a `pandas.DataFrame` for `.toPandas()`. This isn't an implementation detail you have to infer: Spark's own API docs for both methods carry an explicit warning that they "should only be used if the resulting data is expected to be small, as all the data is loaded into the driver's memory." Calling either on a full production-size DataFrame is the single most common cause of driver OOM in a PySpark job — the driver has one JVM heap plus one Python process, not a cluster's worth of memory.

```python
# Dangerous on anything but a small/aggregated result: every row lands
# in the driver's memory as a single Python object, all at once.
rows = df.collect()
pdf = df.toPandas()

# Safer: bound what actually leaves the cluster.
sample_pdf = df.limit(10_000).toPandas()
summary_pdf = df.groupBy("region").count().toPandas()   # aggregated first
df.write.parquet("s3://bucket/output/")                  # let executors write, not the driver
```

`toPandas()` has an Arrow-accelerated path (`spark.sql.execution.arrow.pyspark.enabled`) that speeds up the JVM→pandas conversion itself — batches move via Arrow instead of row-by-row pickling. Don't mistake this for a fix to the memory risk: it makes the *transfer* faster, it does not change the fact that the full result still has to fit in driver memory. A faster OOM is still an OOM. See [memory-management.md](memory-management.md) for the general driver-memory-pressure mechanics this feeds into.

## The senior framing

The senior instinct with PySpark isn't "avoid Python, write everything in Scala" — it's "know exactly where and how often your code crosses the JVM/Python boundary, and what unit of data pays for the crossing." Native Spark SQL expressions never cross it. Pandas UDFs cross it once per batch. Row-at-a-time UDFs cross it once per row. `.collect()`/`.toPandas()` cross it once, for everything, into a single process with a fixed memory ceiling. Diagnosing a slow job or an OOM'd driver starts with identifying which of these you're actually doing — not with reflexively blaming "Python overhead" or a serialization library that isn't even in the code path you think it is.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Blaming "py4j overhead" for slow row-at-a-time UDFs | Py4J only bridges the driver; the real cost is per-row serialization + IPC between the executor JVM and its Python worker subprocess | Diagnose it as JVM↔Python worker IPC, and prefer native functions or a Pandas UDF |
| Writing a Python UDF when a built-in Spark SQL function would do the same thing | Every row pays a cross-process round trip that a native Catalyst expression never pays | Check `pyspark.sql.functions` first; reach for a UDF only when no built-in exists |
| Reaching for a row-at-a-time UDF for bulk numeric/string transforms | Pays full serialize/IPC cost per row instead of once per batch | Use a Pandas UDF (`@pandas_udf`) to vectorize the same logic |
| Assuming Pandas Function APIs (`mapInPandas`/`applyInPandas`) replaced Pandas UDFs | They're a separate, newer addition for row-count-changing/group-wise logic, not a supersede | Use Pandas UDFs for column-wise vectorized math; use the Function APIs for partition/group transforms |
| Calling `.collect()` or `.toPandas()` on a full-size production DataFrame "just to inspect it" | Both materialize the entire result set in the driver's single process - the top cause of driver OOM | Aggregate/filter/`.limit()` before collecting, or write results to storage and let executors do the I/O |
| Enabling `spark.sql.execution.arrow.pyspark.enabled` and assuming it fixes OOM risk | Arrow speeds up the JVM→pandas conversion; it does not shrink what has to fit in driver memory | Treat Arrow as a transfer-speed optimization, not a memory-safety fix - bound the result size instead |
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/dataeng-spark/references/pyspark-specifics.md`
Expected: `5`.

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/dataeng-spark/references/pyspark-specifics.md
git commit -m "Add spark skill: pyspark-specific concerns"
```

---

### Task 8: `SKILL.md`

**Files:**
- Create: `data-engineering-skills/skills/dataeng-spark/SKILL.md`

**Interfaces:**
- Consumes: the exact filenames of all 7 reference files from Tasks 1-7.
- Produces: `skills/dataeng-spark/SKILL.md` — completes the skill, what Task 9 validates.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/dataeng-spark/SKILL.md`:

````markdown
---
name: dataeng-spark
description: Spark and PySpark architecture, tuning, and code-review guidance — lazy evaluation and the execution model (DAG, Catalyst), shuffle and partitioning (repartition vs coalesce), joins and data skew (broadcast, AQE skew-join, salting, bucketing), caching and file formats (persist, checkpoint, Parquet pushdown), Adaptive Query Execution, executor/driver memory, and PySpark-specific concerns (UDF overhead, pandas UDFs/Arrow, collect()/toPandas() memory risk). Use when designing, reviewing, or optimizing a Spark or PySpark job, or diagnosing why one is slow, skewed, or running out of memory. Does not cover Structured Streaming (see dataeng-streaming) or Spark cluster deployment/infrastructure (see dataeng-iac-cloud).
---

# Spark for Data Engineering

## Overview

Senior-level judgment calls for designing, reviewing, and tuning Spark and PySpark jobs — which construct to reach for, which failure mode it prevents, and where Spark's actual behavior diverges from common assumptions. Each reference file pairs a concept with the failure mode it exists to prevent, and calls out the specific Spark version where behavior changed rather than gesturing at "recent Spark." Read the relevant file(s) before designing or reviewing a job; don't rely on the table below alone.

## When to use

- Designing or reviewing a Spark or PySpark job, batch or otherwise
- A job is slow and the cause isn't obvious — shuffle, skew, spilling, or a misleading benchmark
- Choosing between `repartition` and `coalesce`, or deciding whether/how to broadcast a join
- Diagnosing or fixing data skew in a join or an aggregation
- Deciding whether to cache, persist, or checkpoint a DataFrame
- A PySpark UDF is slow, or `.collect()`/`.toPandas()` is risking driver OOM
- Not for Structured Streaming (watermarks, exactly-once semantics) — that's `dataeng-streaming`
- Not for cluster deployment or infrastructure decisions (Terraform, Docker, cluster sizing) — that's `dataeng-iac-cloud`

## Quick reference

| Concern | Reach for | Reference |
|---|---|---|
| A job seems to do nothing until `.count()`/`.write()` runs | Lazy evaluation — transformations only extend the plan | [execution-model.md](references/execution-model.md) |
| A DataFrame job outperforms an equivalent RDD job for no obvious reason | Catalyst optimizes the DataFrame/SQL logical plan; RDDs never go through it | [execution-model.md](references/execution-model.md) |
| Deciding whether a transformation will trigger a shuffle | Narrow vs. wide dependency | [execution-model.md](references/execution-model.md) |
| A job is slow and shuffle is suspected | Shuffle costs disk I/O, serialization, and network I/O — all three | [shuffle-and-partitioning.md](references/shuffle-and-partitioning.md) |
| Reducing partition count before a write | `coalesce` — no full shuffle | [shuffle-and-partitioning.md](references/shuffle-and-partitioning.md) |
| Rebalancing skewed partitions or raising parallelism | `repartition` — full shuffle, hash-based, not a balance guarantee | [shuffle-and-partitioning.md](references/shuffle-and-partitioning.md) |
| Joining a large table against a small lookup/dimension table | Broadcast join (`broadcast()` hint or the 10MB auto threshold) | [joins-and-skew.md](references/joins-and-skew.md) |
| One task in a sort-merge join runs far longer than the rest | AQE's automatic skew-join optimization (primary fix on Spark 3.0+) | [joins-and-skew.md](references/joins-and-skew.md) |
| Skew in a `groupBy`/aggregation, not a join | `REBALANCE` hint, or manual salting as the fallback | [joins-and-skew.md](references/joins-and-skew.md) |
| A table gets joined repeatedly on the same key | Bucket joins (`bucketBy` + `sortBy`) — no shuffle at query time | [joins-and-skew.md](references/joins-and-skew.md) |
| A DataFrame feeds more than one action | `.cache()`/`.persist()` | [caching-and-file-formats.md](references/caching-and-file-formats.md) |
| A long chain of joins/aggregations makes planning itself slow | `.checkpoint()` to truncate lineage | [caching-and-file-formats.md](references/caching-and-file-formats.md) |
| Reading only what a query needs from Parquet | Predicate pushdown (`filterPushdown`) and projection pushdown | [caching-and-file-formats.md](references/caching-and-file-formats.md) |
| A write produces too many or too few output files | `partitionBy` with a bounded-cardinality column | [caching-and-file-formats.md](references/caching-and-file-formats.md) |
| A static plan picked a bad join strategy or partition count | AQE's runtime re-optimization | [adaptive-query-execution-and-benchmarking.md](references/adaptive-query-execution-and-benchmarking.md) |
| Confirming AQE actually changed the plan | `explain("formatted")` → `AdaptiveSparkPlan isFinalPlan=true` | [adaptive-query-execution-and-benchmarking.md](references/adaptive-query-execution-and-benchmarking.md) |
| A benchmark result looks suspiciously fast or slow | Cold-cache vs. warm-cache mismatch with production | [adaptive-query-execution-and-benchmarking.md](references/adaptive-query-execution-and-benchmarking.md) |
| A job spills to disk, evicts cache, or OOMs — telling these apart | The unified memory model — execution wins over storage, spill vs. silent eviction vs. failure | [memory-management.md](references/memory-management.md) |
| The driver runs out of memory | Something pulled distributed data into the driver — check `.collect()` first | [memory-management.md](references/memory-management.md) |
| A row-at-a-time Python UDF is slow | JVM↔Python worker-process IPC — not py4j (py4j is driver-only) | [pyspark-specifics.md](references/pyspark-specifics.md) |
| Vectorizing a UDF for performance | Pandas UDF — Arrow-backed batches instead of row-at-a-time | [pyspark-specifics.md](references/pyspark-specifics.md) |
| Driver OOM after `.collect()`/`.toPandas()` | Both load the full result into driver memory — bound it first | [pyspark-specifics.md](references/pyspark-specifics.md) |

## Two traps everyone hits first

**Salting is not the first tool for a skewed join.** Spark 3.0+ ships Adaptive Query Execution with an automatic skew-join optimization, enabled by default since Spark 3.2.0 — it detects and splits skewed partitions in a sort-merge join at runtime, with no code change needed:

```python
spark.conf.get("spark.sql.adaptive.enabled")          # default true since 3.2.0
spark.conf.get("spark.sql.adaptive.skewJoin.enabled")  # default true since 3.0.0
```

Reach for manual salting only when this genuinely doesn't apply — AQE disabled, Spark <3.0, or skew in an aggregation with no `REBALANCE` hint. See [joins-and-skew.md](references/joins-and-skew.md).

**"py4j overhead" is not why a Python UDF is slow.** Py4J only bridges the driver's Python process to its JVM. On the executor, a regular row-at-a-time UDF runs in a separate Python worker subprocess, with row data serialized and piped to it — that per-row inter-process communication is the actual cost, not py4j:

```python
# Each row crosses the JVM<->Python worker boundary independently - the
# cost is IPC + serialization per row, not "py4j overhead"
@udf(returnType=DoubleType())
def slow(x):
    return x * 2.0
```

See [pyspark-specifics.md](references/pyspark-specifics.md) for the corrected mechanism and how Pandas UDFs amortize this cost over a batch.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Assuming a transformation "ran" because the line executed without error | Transformations are lazy — nothing touched data yet | Trigger an action or use `.explain()`; see [execution-model.md](references/execution-model.md) |
| Using `repartition` to shrink partitions before a write | Pays for a full shuffle when a cheaper option exists | Use `coalesce` instead; see [shuffle-and-partitioning.md](references/shuffle-and-partitioning.md) |
| Salting every skewed join by default | Reimplements, by hand and worse, what AQE's skew-join optimization already does automatically on Spark 3.0+ | Confirm `spark.sql.adaptive.skewJoin.enabled` and check the Spark UI first; see [joins-and-skew.md](references/joins-and-skew.md) |
| Never calling `.unpersist()` on DataFrames done being reused | Stale cached data competes with execution memory until LRU eviction forces it out | Unpersist explicitly; see [caching-and-file-formats.md](references/caching-and-file-formats.md) |
| Assuming AQE ran just because it's on by default | The umbrella flag doesn't guarantee sub-features fired, or that the query even has a shuffle boundary | Check `explain("formatted")` for `AdaptiveSparkPlan isFinalPlan=true`; see [adaptive-query-execution-and-benchmarking.md](references/adaptive-query-execution-and-benchmarking.md) |
| Bumping `spark.executor.memory` to fix spilling without checking whether it's execution- or storage-bound | Can throw memory at the wrong side of the unified region | Diagnose spill vs. cache eviction first; see [memory-management.md](references/memory-management.md) |
| Blaming "py4j overhead" for slow row-at-a-time UDFs | Py4J only bridges the driver; the real cost is per-row IPC with the executor's Python worker | Diagnose it correctly, or use a Pandas UDF; see [pyspark-specifics.md](references/pyspark-specifics.md) |
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "](references/" data-engineering-skills/skills/dataeng-spark/SKILL.md`
Expected: a number ≥ 19 (every quick-reference and common-mistakes row links into a reference file).

Run: `for f in data-engineering-skills/skills/dataeng-spark/references/*.md; do grep -q "$(basename "$f")" data-engineering-skills/skills/dataeng-spark/SKILL.md || echo "MISSING LINK: $f"; done`
Expected: no output (every one of the 7 reference files is linked from `SKILL.md`).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/dataeng-spark/SKILL.md
git commit -m "Add spark skill: SKILL.md"
```

---

### Task 9: Review against `writing-great-skills`

**Owner:** Claude, applying the mattpocock `writing-great-skills` reference directly against the assembled skill — same method already used this session to audit `dataeng`, `dataeng-python`, and `dataeng-sql` (see commit `6bd7ef1`, which fixed a leading-word violation in all three descriptions and an incomplete common-mistakes table in `dataeng-python`). This is a self-review checklist, not a subagent dispatch — same posture as the Self-Review Notes below.

**Interfaces:**
- Consumes: `skills/dataeng-spark/SKILL.md` and all 7 reference files (Tasks 1-8).

- [ ] **Step 1: Read the standard**

Read `.agents/skills/writing-great-skills/SKILL.md` (and `GLOSSARY.md` in the same folder if it defines a term used below) as the authoritative reference.

- [ ] **Step 2: Check the description**

Confirm `SKILL.md`'s `description` front-loads a leading word/identity clause rather than opening with "Use when…" (the exact violation found and fixed in `dataeng`, `dataeng-python`, `dataeng-sql` earlier this session), gives one trigger per branch with no duplicated synonyms, and doesn't restate identity already covered in the Overview body.

- [ ] **Step 3: Check information hierarchy**

Across all 7 reference files, check for content in `SKILL.md` that belongs behind a reference-file pointer instead, or reference-only content every branch actually needs inline. Check co-location: does each concept's rule stay with its caveat, or is anything split across files that shouldn't be?

- [ ] **Step 4: Check pruning**

Hunt for duplication, no-op sentences, and sediment across the 7 files and `SKILL.md` — a sentence that doesn't change behavior versus the model's default should go.

- [ ] **Step 5: Check the suite's own §3 template compliance**

Confirm `SKILL.md`'s common-mistakes table cites all 7 reference files, not a subset — this is the exact gap the earlier audit found in `dataeng-python` (3 of 7 files were missing from its table). Confirm overview/when-to-use/quick-reference/common-mistakes are all present.

- [ ] **Step 6: Fix and record**

Fix any findings inline in the relevant file(s). If nothing needs fixing, record that explicitly in the Self-Review Notes below rather than leaving the question open.

---

### Task 10: Validate the `dataeng-spark` skill

**Owner:** Claude, using the `Agent` tool to run fresh-context scenarios (same method used to validate `dataeng-python`, `dataeng`, and `dataeng-sql`).

**Interfaces:**
- Consumes: `skills/dataeng-spark/` (Tasks 1-9), symlinked into a live Claude Code environment so a fresh agent can discover it.

Two scenarios test both discoverability and whether the two corrected findings from this build (AQE skew-join vs. salting, and the py4j misdiagnosis) actually surface — not just that the skill fires.

- [ ] **Step 1: Symlink the skill for testing**

```bash
ln -sf "$(pwd)/data-engineering-skills/skills/dataeng-spark" ~/.claude/skills/dataeng-spark
ln -sf "$(pwd)/data-engineering-skills/skills/dataeng-spark" ~/.agents/skills/dataeng-spark
```

- [ ] **Step 2: Run the skew-handling correctness scenario**

Dispatch a fresh `general-purpose` agent with this prompt:

> "You have a list of available skills — check it. Then answer: 'I have a sort-merge join in Spark 3.4 that's skewed — one task takes way longer than the rest to finish. A teammate suggested salting the join key. Is that the right first move?' After answering, report which skill(s) you invoked."

Expected: the agent invokes `dataeng-spark`, explains that Spark 3.4's Adaptive Query Execution has automatic skew-join optimization enabled by default (since 3.0.0/3.2.0) that should be checked/confirmed first, and frames manual salting as the fallback rather than agreeing it's the right first move.

- [ ] **Step 3: Run the PySpark UDF mechanism scenario**

Dispatch a fresh `general-purpose` agent with this prompt:

> "You have a list of available skills — check it. Then answer: 'Why are Python UDFs in PySpark so much slower than native Spark SQL functions? Is it because of py4j?' After answering, report which skill(s) you invoked."

Expected: the agent invokes `dataeng-spark`, corrects the py4j misconception (py4j is driver-only), and explains the actual mechanism — a separate Python worker subprocess per executor communicating over local pipes/sockets, with per-row serialization as the real cost.

- [ ] **Step 4: Record the result**

If either scenario fails (skill doesn't fire, or the technical answer is wrong/vague), fix the relevant wording in the affected reference file or `SKILL.md`'s quick-reference table/two-traps section, and re-run only the failing scenario.

---

## Self-Review Notes

- **Spec coverage**: Task 1 ↔ design spec §4.1; Task 2 ↔ §4.2; Task 3 ↔ §4.3; Task 4 ↔ §4.4; Task 5 ↔ §4.5; Task 6 ↔ §4.6; Task 7 ↔ §4.7; Task 8 ties them together per the design spec's file-structure diagram; Task 9 applies the `writing-great-skills` standard (added after the original plan review, matching the QA gate already used to audit the other 3 skills this session); Task 10 mirrors the discoverability validation already run for `dataeng-python`, `dataeng`, and `dataeng-sql`.
- **No placeholders**: every task's content is the actual final file content (English, all corrections from the design spec §4 incorporated: 3-cost shuffle, non-guaranteed `repartition` balance, AQE-first skew framing, MEMORY_AND_DISK-family persist default, 5-not-3 AQE features, `spark.memory.fraction` dated to 2.0.0, broadcast variables on executors not driver, py4j corrected to worker-process IPC), not a description of what to write.
- **Type/name consistency**: reference filenames match exactly between the design spec (§4), the File Structure section above, each task's own file, and `SKILL.md`'s quick-reference table links — verified via Task 8 Step 2's link-check commands. Cross-links between reference files (execution-model → shuffle-and-partitioning; shuffle-and-partitioning → joins-and-skew; joins-and-skew → adaptive-query-execution-and-benchmarking; caching-and-file-formats → memory-management, pyspark-specifics; memory-management → pyspark-specifics) all resolve to filenames actually produced by this plan.
- **Attribution consistency**: every wshobson/agents-sourced addition (bucket joins, checkpointing, programmatic skew detection, `approx_count_distinct`) carries an inline "(Adapted from wshobson/agents' spark-optimization skill, MIT.)" attribution at first use, matching the policy already applied in the `dataeng-sql` build.
