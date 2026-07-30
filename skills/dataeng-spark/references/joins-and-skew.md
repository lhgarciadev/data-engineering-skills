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

The failure mode runs in both directions. Leave the threshold too low and a dimension table that's genuinely small (say, 40MB) falls back to a full shuffle for no reason — you pay the shuffle cost for a join that didn't need it. Push the threshold up carelessly, or hint `broadcast()` on a table that turns out to be large, and every executor tries to hold a full copy in memory at once; that's a broadcast-timeout error or an executor OOM, not a performance win. Broadcast is for dimension tables and lookup tables — tens to low hundreds of MB, not GB — not for anything that could grow past that.

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
