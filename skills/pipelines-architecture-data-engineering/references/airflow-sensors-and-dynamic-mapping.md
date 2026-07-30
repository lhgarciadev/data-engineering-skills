# Sensors and Dynamic Parallelism

## Sensors, done right

A sensor is a task that waits for a condition before letting the DAG proceed: a file in S3 (`S3KeySensor`), a ready partition, a row in a table (`SqlSensor`), or another DAG's task finishing (`ExternalTaskSensor`). It's the classic mechanism for cross-pipeline dependencies when the source doesn't emit an event you can hook an Asset to.

None of these ship in Airflow core anymore. `S3KeySensor` lives in `apache-airflow-providers-amazon`. `SqlSensor` moved to `apache-airflow-providers-common-sql` back in **Airflow 2.4.0** — its core import path stopped working from that release onward, well before Airflow 3.0 shipped. `ExternalTaskSensor` moved to `apache-airflow-providers-standard` as part of Airflow 3.0's core-to-provider split — its core import path worked throughout the entire 2.x line and only broke at the 3.0 boundary. The two sensors didn't move on the same timeline; install the matching provider for whichever Airflow version you're actually on.

## The antipattern that sinks clusters: poke mode

By default a sensor runs in `poke` mode, and that means it occupies a worker slot for the *entire* wait, checking every N seconds. With 30 sensors waiting and 32 slots, only 2 slots are left for real work — the sensors eat capacity and the DAG stalls waiting on itself. This is the sensor deadlock, and it gets asked about directly.

Two fixes, in order of quality:

- **`mode="reschedule"`** — the sensor releases the slot between checks and re-queues; it doesn't hold capacity while it sleeps. The minimum you should do for any wait longer than a few seconds.
- **Deferrable operators + the `triggerer` process (async)** — the modern evolution. The task "defers" to a dedicated async event loop and fully frees the worker; thousands of concurrent waits cost almost nothing. This is the senior answer to "how do you wait for something without wasting resources."

Worth mentioning alongside these: `timeout` (so a sensor doesn't wait forever), `soft_fail=True` (marks the task `skipped` instead of `failed` when the timeout hits — for optional paths), and `poke_interval` with `exponential_backoff`.

`ExternalTaskSensor`'s date-alignment trap: by default it waits for the external task on the *same* logical date, so if the two DAGs run on different schedules you need `execution_delta` or `execution_date_fn` — these parameter names are current, unchanged from 2.x even as the surrounding docstrings shifted their language toward "logical date" phrasing. Skip them and you'll wait for a run that doesn't exist.

## Prefer not to use sensors when you can avoid them

A sensor is polling — asking repeatedly — with all the fragility and waste that implies. The stronger pattern is data-aware scheduling: the consumer DAG fires when the producer materializes the Asset (see `scheduling-and-dependencies.md`), with no waiting or polling at all. Decoupling by data instead of polling by time is the senior move; a sensor is the fallback for when the source doesn't emit that event.

## Fan-out/fan-in: static parallelism

"Fan-out/fan-in" (the "diamond") is descriptive shorthand — not Airflow's own vocabulary — for a task opening several parallel branches (process 12 regions at once) with a convergence task aggregating the results afterward. It's the basic parallelism pattern, and it falls straight out of the DAG: independent branches run in parallel with no manual orchestration.

```python
extract() >> [process_region_a(), process_region_b(), process_region_c()] >> merge()
```

## Dynamic Task Mapping: the senior upgrade

Introduced in **Airflow 2.3.0**. The problem with classic fan-out is that the number of branches had to be known when the DAG file was parsed. Often you don't know it until runtime: "process one file for each of the N that showed up today," and N changes daily. Dynamic Task Mapping generates the parallel tasks from data produced by an earlier task:

```python
from airflow.sdk import task

@task
def list_files():
    return discover_todays_files()   # returns N paths, N unknown until now

@task
def process(path):
    ...

process.expand(path=list_files())   # one task per file, materialized at runtime
```

Knowing the difference between "static parallelism, known at parse time" and "dynamic mapping, dependent on runtime data" — and knowing that before 2.3 this required ugly workarounds — shows you're tracking the tool's real evolution, not a several-versions-old mental model of it.
