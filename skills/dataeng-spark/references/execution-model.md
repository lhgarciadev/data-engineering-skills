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
