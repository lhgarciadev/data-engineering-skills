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
