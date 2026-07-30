# Concurrency and the GIL

This is where most candidates and most pipelines go wrong, and where a precise answer instantly signals seniority.

## The GIL, precisely

The Global Interpreter Lock lets only one thread execute Python bytecode at a time. Consequence: threads don't speed up CPU-bound pure-Python work. But — the part people get wrong — **a thread releases the GIL while it's blocked on I/O** (network, disk), and NumPy/pandas' compiled C/Cython inner loops *also* release it during array-wide numeric computation. The accurate framing is "many operations release it, not all" — pure-Python-level glue code (object-dtype columns, `.apply()` with a Python callable, per-element indexing logic) still runs under the GIL even inside a "pandas" call.

So the split is:

- **I/O-bound** (calling 100 APIs, reading many files): use `threading` or, better, `asyncio`. Threads overlap during I/O waits.
- **CPU-bound** (heavy computation in pure Python loops): use `multiprocessing`. Each process has its own interpreter and its own GIL, giving real CPU parallelism.

```python
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor

# I/O-bound: download 500 files → threads
with ThreadPoolExecutor(max_workers=20) as ex:
    results = list(ex.map(download, urls))

# CPU-bound: heavy pure-Python transform → processes
with ProcessPoolExecutor() as ex:
    results = list(ex.map(heavy_compute, batches))
```

`asyncio` is more efficient than threads for *massive* concurrent I/O because it doesn't pay the OS cost of spinning up thousands of threads — one thread, an event loop, and coroutines (`async`/`await`). It's the right fit for "call thousands of endpoints."

## The senior answer

"In practice, in data engineering I rarely fight the GIL directly, because the heavy computation doesn't live in pure-Python loops. It lives in NumPy/pandas (which drop to C and release the GIL for those operations), in Spark (distributed parallelism), or I push it down to the warehouse as SQL. The GIL mainly matters for knowing that I/O-bound orchestration goes with async/threads and pure-Python CPU-bound work goes with processes." That "I don't compute in Python, I delegate to the engine" framing is the actual senior data-engineer instinct. For what "distributed parallelism" actually means once you've delegated to Spark — lazy evaluation, shuffle, and the executor/driver split — see the `spark-data-engineering` skill's [execution-model.md](../../spark-data-engineering/references/execution-model.md).

## Free-threaded Python — current status, don't overstate it

PEP 703 defines a no-GIL build. Python 3.13 ships it as an official but **experimental**, opt-in build variant (`python3.13t`), with real single-thread overhead (~35-40% in 3.13). PEP 779 promotes it in **Python 3.14** to "officially supported" (still opt-in, overhead down to ~5-10%), but it is **not the default build** and has no committed timeline for becoming one — the main blocker is the C-extension ecosystem catching up (a non-aware C extension silently re-enables the GIL with a warning). Treat it as "real and improving fast, but not something to write pipeline code assuming is on by default" rather than "the GIL is basically gone now."

## Common mistakes

| Mistake | Fix |
|---|---|
| Reaching for `multiprocessing` on an I/O-bound pipeline (API calls, file downloads) | Use `threading`/`asyncio` — processes pay startup cost for zero benefit here |
| Expecting `threading` to speed up a pure-Python CPU-heavy loop | Use `multiprocessing`, or push the computation into NumPy/pandas/SQL where the GIL doesn't apply |
| Assuming "pandas releases the GIL" as a blanket statement | Only the compiled numeric kernels do; `.apply()` with a Python function and object-dtype columns still serialize under the GIL |
| Assuming free-threaded Python removes the need for this decision today | It's opt-in and still maturing — design for the GIL being present by default |
