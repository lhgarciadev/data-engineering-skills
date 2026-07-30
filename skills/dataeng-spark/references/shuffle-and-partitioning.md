# Shuffle and Partitioning

Most non-trivial Spark jobs get slow for one of two reasons: a shuffle that didn't need to happen, or a shuffle that ran the way it had to but left data spread unevenly across the resulting partitions. Knowing what a shuffle actually costs — and what each partition-count API does and doesn't promise — is the difference between guessing at `.repartition(200)` and knowing what to fix.

## What shuffle is, and what it costs

Shuffle is Spark redistributing data across partitions — and usually across nodes — by key, so that rows the next stage needs to see together end up on the same partition. Any wide transformation triggers one: `groupBy`, a non-broadcast `join`, `distinct`, `repartition`, `orderBy`. For the detailed mechanics of data flow across stages, see [execution-model.md](execution-model.md).

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

The two variants of `repartition` use fundamentally different partitioning strategies, and conflating them is a common source of confusion:

- **Column-based overloads** (`repartition("col")`, `repartition(n, "col1", "col2")`) redistribute via **hash partitioning** on the given columns. Hash partitioning spreads *distinct key values* across partitions, not *rows*; if one key value dominates the dataset, every row for it lands in the same partition regardless of `n`. This is where skew happens. PySpark's docstring says repartition "hash partitions," and for the column-based case, that's accurate — but skew on a key is a skew problem, not something a bigger `n` will fix.
- **Columnless overload** (`repartition(n)`) is different in kind: Spark's internal implementation (Catalyst's `Repartition` logical plan node) uses **round-robin partitioning**, not hash partitioning. Round-robin has no concept of a key, so it can't skew on dominant values; it simply distributes rows sequentially across the `n` output partitions. This makes it evenly balanced by row count, but it also means there's no co-location of related rows by key for downstream operations.

PySpark's docstring says all `repartition` overloads are "hash partitioned," but this blanket statement is imprecise for the columnless case — its actual implementation is round-robin.

```python
# column-based: hash-partitions by customer_id; if one customer_id is 40% of the rows,
# that single output partition ends up ~40% of the data regardless of n
df.repartition(200, "customer_id")

# columnless: round-robin partitioning; rows land evenly across 200 partitions,
# but no key-based co-location for downstream joins or groupBys
df.repartition(200)
```

If you're using the column-based form and your key is actually skewed, that's a skew problem, not something `repartition` will fix by adding more partitions — see [joins-and-skew.md](joins-and-skew.md) for salting and other mitigations.

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
