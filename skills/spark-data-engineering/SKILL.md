---
name: spark-data-engineering
description: Spark and PySpark architecture, tuning, and code-review guidance — lazy evaluation and the execution model (DAG, Catalyst), shuffle and partitioning (repartition vs coalesce), joins and data skew (broadcast, AQE skew-join, salting, bucketing), caching and file formats (persist, checkpoint, Parquet pushdown), Adaptive Query Execution, executor/driver memory, and PySpark-specific concerns (UDF overhead, pandas UDFs/Arrow, collect()/toPandas() memory risk). Use when designing, reviewing, or optimizing a Spark or PySpark job, or diagnosing why one is slow, skewed, or running out of memory. Does not cover Structured Streaming (see streaming-data-engineering) or Spark cluster deployment and infrastructure (see iac-cloud-data-engineering).
---

# Spark for Data Engineering

## Overview

Senior-level judgment calls for designing, reviewing, and tuning Spark and PySpark jobs — which construct to reach for, which failure mode it prevents, and where Spark's actual behavior diverges from common assumptions. Each reference file pairs a concept with the failure mode it exists to prevent, and calls out the specific Spark version where behavior changed rather than gesturing at "recent Spark." Read the relevant file(s) before designing or reviewing a job; don't rely on the table below alone.

## When to use

- Designing or reviewing a Spark or PySpark job, batch or otherwise
- Confirming a workload actually needs a cluster, before designing or tuning a job for it — see the gate below
- A job is slow and the cause isn't obvious — shuffle, skew, spilling, or a misleading benchmark
- Choosing between `repartition` and `coalesce`, or deciding whether/how to broadcast a join
- Diagnosing or fixing data skew in a join or an aggregation
- Deciding whether to cache, persist, or checkpoint a DataFrame
- A PySpark UDF is slow, or `.collect()`/`.toPandas()` is risking driver OOM
- Not for Structured Streaming (watermarks, exactly-once semantics) — see `streaming-data-engineering`
- Not for cluster deployment or infrastructure decisions (Terraform, Docker, cluster sizing) — see `iac-cloud-data-engineering`

## Before tuning: does this workload need a cluster?

Distribution is never free — it is a **cluster tax** charged on every job: JVM startup,
task scheduling, serialization, and shuffle traffic over the network. A cluster earns that
tax back when the data genuinely exceeds one machine. Below that line the same
transformation finishes faster on a single node, with none of the tax and none of the
tuning surface the rest of this skill exists to manage.

The line sits past "fits in RAM", but not as far past it as the two usual single-node
engines are given credit for, and they differ. DuckDB spills blocking operators
(`GROUP BY`, `JOIN`, `ORDER BY`, windowing) to disk by default, so it takes inputs beyond
memory without being asked. Polars runs its **in-memory** engine unless you pass
`.collect(engine="streaming")`, and even then peak memory is reduced rather than
guaranteed bounded. Size against memory unless you have measured otherwise. Two checks
decide it:

- Does the data fit inside one machine's envelope — memory for Polars, memory plus spill
  space for DuckDB?
- Is the job a scan, filter, aggregation, or join — the shape a single-node engine
  expresses directly?

Two yeses mean the cluster is optional, and reaching for it spends throughput instead of
buying it. Run these checks before raising executor memory or partition counts: those
levers reduce the cluster tax, they never remove it. For the selection rule between
pandas, Polars, and DuckDB once the single-node answer is the right one, see
[memory-and-performance.md](../python-data-engineering/references/memory-and-performance.md)
in `python-data-engineering`.

## Quick reference

| Concern | Reach for | Reference |
|---|---|---|
| A job seems to do nothing until `.count()`/`.write()` runs | Lazy evaluation — transformations only extend the plan | [execution-model.md](references/execution-model.md) |
| A DataFrame job outperforms an equivalent RDD job for no obvious reason | Catalyst optimizes the DataFrame/SQL logical plan; RDDs never go through it | [execution-model.md](references/execution-model.md) |
| Deciding whether a transformation will trigger a shuffle | Narrow vs. wide dependency | [execution-model.md](references/execution-model.md) |
| A job is slow and shuffle is suspected | Shuffle costs disk I/O, serialization, and network I/O — all three | [shuffle-and-partitioning.md](references/shuffle-and-partitioning.md) |
| Reducing partition count before a write | `coalesce` — no full shuffle | [shuffle-and-partitioning.md](references/shuffle-and-partitioning.md) |
| Rebalancing skewed partitions or raising parallelism | `repartition` — full shuffle; round-robin for `repartition(n)` (no key, can't skew), hash-based for the column-based form (can skew on a dominant key value) | [shuffle-and-partitioning.md](references/shuffle-and-partitioning.md) |
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
