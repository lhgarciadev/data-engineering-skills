---
name: python
description: Use when writing, reviewing, or making design decisions on Python data engineering code — ETL/ELT pipelines, batch jobs, dataframe transformations, or pipeline architecture. Covers generators and streaming, decorators and context managers for pipeline cross-cutting concerns, GIL-aware concurrency choice (threading vs multiprocessing vs asyncio), pandas/Polars/DuckDB memory and performance tradeoffs, dataframe and record validation, idempotent writes, and pipeline testing and error handling.
---

# Python for Data Engineering

## Overview

Senior-level judgment calls for Python data pipelines — which tool or pattern to reach for and why, not language syntax. Each reference file pairs a concept with the failure mode it exists to prevent. Read the relevant file(s) before proposing a design or reviewing pipeline code; don't rely on the table below alone.

## When to use

- Designing or reviewing an ETL/ELT pipeline, batch job, or dataframe transformation in Python
- Choosing between threading, multiprocessing, or asyncio for a pipeline stage
- A pipeline is slow or running out of memory and the cause isn't obvious
- Deciding pandas vs Polars vs DuckDB for a given data size or workload
- Validating a dataframe's schema/content, or a single record/API payload
- Writing retry logic, idempotent writes, or structured error handling for a pipeline
- Not for general Python questions unrelated to data workloads

## Quick reference

| Concern | Reach for | Reference |
|---|---|---|
| Streaming data that doesn't fit in memory | generators + `itertools` | [iterators-and-generators.md](references/iterators-and-generators.md) |
| Retry/timing/logging around a pipeline step | decorators | [decorators-and-context-managers.md](references/decorators-and-context-managers.md) |
| Guaranteed cleanup (connections, transactions) | context managers | [decorators-and-context-managers.md](references/decorators-and-context-managers.md) |
| Pluggable, testable sources/sinks | ABC + composition + dependency injection | [oop-for-pipelines.md](references/oop-for-pipelines.md) |
| Many API calls / file reads (I/O-bound) | threading or asyncio | [concurrency-and-the-gil.md](references/concurrency-and-the-gil.md) |
| Heavy pure-Python computation (CPU-bound) | multiprocessing | [concurrency-and-the-gil.md](references/concurrency-and-the-gil.md) |
| DataFrame too big or too slow | dtype tuning, chunking, Polars/DuckDB | [memory-and-performance.md](references/memory-and-performance.md) |
| Validating a dataframe's shape/content | Pandera | [data-validation.md](references/data-validation.md) |
| Validating a single record/API payload | Pydantic | [data-validation.md](references/data-validation.md) |
| Re-running a job safely after a partial failure | idempotent upsert-by-key | [production-patterns.md](references/production-patterns.md) |
| Pipeline testing, error handling, config, logging | — | [production-patterns.md](references/production-patterns.md) |

## Two traps everyone hits first

**Set operations beat nested loops.** "Find common elements between two large collections" — a nested loop is O(n·m); converting to `set` and intersecting is O(n+m):

```python
# O(n*m) — degrades badly as both grow
common = [x for x in list_a if x in list_b]
# O(n+m)
common = set(list_a) & set(list_b)
```

**Mutable default arguments are shared across calls**, because the default is evaluated once at function-definition time, not per call:

```python
def add(item, acc=[]):        # acc persists across every call — classic bug
    acc.append(item)
    return acc

def add(item, acc=None):      # correct
    acc = [] if acc is None else acc
    acc.append(item)
    return acc
```

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Materializing a full list when a generator would do | Blows up memory on large/unbounded inputs | Use `yield` / generator expressions; see [iterators-and-generators.md](references/iterators-and-generators.md) |
| `df.iterrows()` for row-wise logic | 100x+ slower than vectorized ops | Vectorize, or `.apply()` as a last resort; see [memory-and-performance.md](references/memory-and-performance.md) |
| Reaching for `multiprocessing` on an I/O-bound pipeline | Pays process-startup cost for zero benefit; threads/asyncio already overlap I/O waits | See [concurrency-and-the-gil.md](references/concurrency-and-the-gil.md) |
| Blind `append`-only writes on reruns | Duplicates data on retry/backfill | Upsert/merge by partition key; see [production-patterns.md](references/production-patterns.md) |
| `try/except: pass` around pipeline steps | Silently corrupts or drops data, hides root cause | Separate retryable vs non-retryable errors, log structured context, dead-letter the rest; see [production-patterns.md](references/production-patterns.md) |
| Optimizing before measuring | Fixes the wrong bottleneck | Profile first (`cProfile`, `memory_profiler`) — see [memory-and-performance.md](references/memory-and-performance.md) |
