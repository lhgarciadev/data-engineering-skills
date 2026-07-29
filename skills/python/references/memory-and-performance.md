# Memory and Performance

## Profile before optimizing

Say this first, mean it: measure before assuming where the bottleneck is. `cProfile` for CPU, `memory_profiler` for memory, or just timing sections — optimizing blind is a red flag, not a shortcut.

## Chunked processing

When the data doesn't fit in RAM, don't load it whole:

```python
import pandas as pd

total = 0
for chunk in pd.read_csv("huge.csv", chunksize=100_000):
    total += chunk["amount"].sum()   # process 100k rows at a time
```

## dtype tuning

A large share of pandas memory problems are solved by fixing dtypes: `category` for repeated strings (country, status), `int32`/`float32` when the value range allows it, and downcasting generally. Effect size depends heavily on cardinality — `category` alone can cut low-cardinality string columns 90%+; numeric downcasting alone is typically ~60-70%; combined, a DataFrame commonly drops 60-80% in size, sometimes more. Don't treat that range as a fixed guarantee — check cardinality first.

## `__slots__`

If you're instantiating millions of objects of one class, `__slots__` removes the per-instance `__dict__`, cutting memory and attribute-access time substantially:

```python
class Event:
    __slots__ = ("id", "ts", "amount")
    def __init__(self, id, ts, amount):
        self.id, self.ts, self.amount = id, ts, amount
```

## Vectorization

Never iterate a DataFrame row-by-row (`iterrows()` is extremely slow). Use vectorized NumPy/pandas operations, which run in C over the whole array — vectorized code is commonly 100x faster than the equivalent loop, often much more. The C-level kernels behind these operations release the GIL (see [concurrency-and-the-gil.md](concurrency-and-the-gil.md)), which is a separate benefit from the raw compiled-loop speedup.

## Beyond pandas: PyArrow, Polars, DuckDB

These aren't niche mentions anymore — for "pandas doesn't scale" moments they're the default answer, not an exotic one:

- **PyArrow**: columnar in-memory format, the interchange layer between pandas, Parquet, and Spark. pandas can use it as a backend for more memory-efficient string/columnar storage.
- **Polars**: a DataFrame library with a **lazy API** — `pl.scan_parquet(...)` builds a query plan (projection/predicate pushdown, streaming execution for data larger than RAM) that only executes on `.collect()`, similar in spirit to Spark's lazy DAGs. Commonly 3-11x faster than pandas on large data, with a stricter, more predictable API.
- **DuckDB**: an embedded OLAP engine — SQL directly against Parquet/Arrow/CSV files, no server to run. Often the fastest option for large scans and joins, and a natural fit when the transformation is more naturally expressed in SQL than in DataFrame calls.

Rule of thumb: reach for Polars when you want a DataFrame API with real query optimization and larger-than-RAM streaming; reach for DuckDB when the job is fundamentally a SQL query over files; stay in pandas when the data comfortably fits in memory and the ecosystem/interop (existing code, plotting, ML libraries) matters more than raw throughput.

## Common mistakes

| Mistake | Fix |
|---|---|
| `df.iterrows()` or `df.itertuples()` for a transformation | Vectorize with NumPy/pandas operations directly on columns |
| Loading a file fully into memory before checking its size | Use `chunksize` (pandas) or a lazy scan (`pl.scan_parquet`, DuckDB) when size is uncertain |
| Leaving default dtypes (`object` for strings, `int64`/`float64` everywhere) on a large DataFrame | Check cardinality and value ranges, then apply `category`/downcasting |
| Reaching for Spark/a cluster when the data fits in a laptop's RAM | Try Polars or DuckDB first — often as fast, with none of the cluster overhead |
| Optimizing memory/speed without profiling first | Run `cProfile`/`memory_profiler` and confirm where time/memory actually goes |
