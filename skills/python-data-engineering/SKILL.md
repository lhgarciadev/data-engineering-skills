---
name: python-data-engineering
description: Python data engineering guidance — writing, reviewing, or making design decisions on ETL/ELT pipelines, batch jobs, dataframe transformations, or pipeline architecture. Use when choosing a concurrency model, a dataframe library, or a validation approach, or when a pipeline is slow, leaking memory, or unsafe to rerun. Covers generators/streaming, decorators and context managers, GIL-aware concurrency, pandas/Polars/DuckDB tradeoffs, Pydantic/Pandera validation, idempotent writes, external API consumption (auth, pagination, rate limiting/backoff), and pipeline testing/error handling. Not for general Python questions unrelated to data workloads.
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
- Deciding how a pipeline tracks what's new since its last run, or whether it even needs to (full pull vs incremental)
- Calling an external API for ingestion — auth, pagination, rate limiting, retries
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
| Tracking which rows are new/changed since the last run | Watermark/cursor state — persisted outside a single DAG run | [production-patterns.md](references/production-patterns.md) |
| Pipeline testing, error handling, config, logging | — | [production-patterns.md](references/production-patterns.md) |
| Calling an external API for ingestion (auth, pagination, rate limits) | Timeout + backoff/jitter + cursor pagination | [external-api-integration.md](references/external-api-integration.md) |
| Laying out a new pipeline package's directory, or choosing Poetry vs `uv` | `config`/`extract`/`transform`/`load` layering, packaging conventions | [project-structure-data-engineering](../project-structure-data-engineering/references/package-layout.md) |

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
| Cleaning up a connection/transaction only in the "happy path" | A job that dies mid-run leaks the connection or leaves a transaction open | Put cleanup in `finally` (or after `yield` in `@contextmanager`); see [decorators-and-context-managers.md](references/decorators-and-context-managers.md) |
| Constructing a source/sink inside the function that uses it | Makes the pipeline untestable — no way to substitute a fake/mock | Inject it as a parameter (dependency injection); see [oop-for-pipelines.md](references/oop-for-pipelines.md) |
| `df.iterrows()` for row-wise logic | 100x+ slower than vectorized ops | Vectorize, or `.apply()` as a last resort; see [memory-and-performance.md](references/memory-and-performance.md) |
| Reaching for `multiprocessing` on an I/O-bound pipeline | Pays process-startup cost for zero benefit; threads/asyncio already overlap I/O waits | See [concurrency-and-the-gil.md](references/concurrency-and-the-gil.md) |
| Reaching for Great Expectations to validate a single pipeline's output | Org-wide governance overhead for a job that just needs a dataframe check | Use Pandera unless there's an actual org-wide data-quality requirement; see [data-validation.md](references/data-validation.md) |
| Blind `append`-only writes on reruns | Duplicates data on retry/backfill | Upsert/merge by partition key; see [production-patterns.md](references/production-patterns.md) |
| Storing extraction state (watermark) in Airflow XCom | XCom doesn't persist across DAG runs — silently resets each run | Use an Airflow `Variable` or an external control table instead; see [production-patterns.md](references/production-patterns.md) |
| `try/except: pass` around pipeline steps | Silently corrupts or drops data, hides root cause | Separate retryable vs non-retryable errors, log structured context, dead-letter the rest; see [production-patterns.md](references/production-patterns.md) |
| Optimizing before measuring | Fixes the wrong bottleneck | Profile first (`cProfile`, `memory_profiler`) — see [memory-and-performance.md](references/memory-and-performance.md) |
| Request to an external API without a timeout | Hangs the task indefinitely on a stalled server, blocking the whole DAG behind it | Always set `timeout=(connect, read)`; see [external-api-integration.md](references/external-api-integration.md) |
| Retrying a failed API call at a fixed interval | Synchronized retries from many clients create a thundering-herd spike right as the API recovers | Exponential backoff plus jitter; see [external-api-integration.md](references/external-api-integration.md) |
| Offset/limit pagination against a large, frequently-written API | Skips or duplicates rows as data shifts under the paging window, and gets slower at every page | Prefer cursor/keyset pagination when the API offers it; see [external-api-integration.md](references/external-api-integration.md) |
