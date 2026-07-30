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

Skew join handling is the well-documented skew optimization from the list above, and it deserves its own treatment rather than a paragraph here — see [joins-and-skew.md](joins-and-skew.md) for how AQE detects and splits skewed partitions.

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

## The senior framing

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
