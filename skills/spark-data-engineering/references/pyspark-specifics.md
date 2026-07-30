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
