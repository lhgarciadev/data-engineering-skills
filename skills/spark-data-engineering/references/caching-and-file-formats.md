# Caching and File Formats

Spark's laziness means a DataFrame is a recipe, not a result — every action re-walks the lineage from source to output. That's fine when a DataFrame is consumed once. It becomes expensive fast when the same DataFrame feeds multiple downstream actions, when its lineage itself grows long enough to be costly to plan, or when the storage format forces Spark to read more than the query actually needs. This file covers the tools for each: caching and checkpointing to control recomputation, and Parquet's pushdown/partitioning behavior to control how much gets read off disk in the first place.

## Caching and persisting reused DataFrames

Call `.cache()` or `.persist()` when a DataFrame feeds more than one action — otherwise Spark recomputes its entire lineage, from the original read, once per action.

```python
from pyspark.sql import functions as F

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

Reach for this when the lineage graph itself — not just the data — is the expensive part: many chained joins and aggregations produce a DAG that's costly for the driver to track and for the Catalyst optimizer to plan against on every subsequent action. Checkpointing resets that graph to a single read from the checkpoint files. Caching a DataFrame in the same situation still leaves the long lineage attached as a fallback.

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

Spark's `DataFrameWriter.partitionBy` guidance gives a concrete cardinality boundary: the number of distinct values in a partition column should typically stay under tens of thousands. Partitioning by something like `user_id` blows past that — millions of directories, each holding a handful of rows, dominated by file-open and listing overhead rather than actual scan work. Past that cardinality threshold, use `bucketBy` instead, which doesn't have the same ceiling — see [joins-and-skew.md](joins-and-skew.md) for how bucketing also eliminates join-time shuffle.

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
| Partitioning writes by a high-cardinality column (e.g. `user_id`) | Produces millions of tiny files - listing/open overhead dominates actual I/O | Keep partition columns under roughly tens of thousands of distinct values; use `bucketBy` beyond that (see [joins-and-skew.md](joins-and-skew.md) for bucket joins) |
| Using `countDistinct` when an approximate cardinality is good enough | Forces a full shuffle to get exactness nobody needed | Use `approx_count_distinct` with a tolerable `rsd` |
