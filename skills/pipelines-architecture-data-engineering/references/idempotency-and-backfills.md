# Idempotency and Backfills: The Structural Layer

`python-data-engineering` already covers *how* to write idempotent code inside a task — upsert-by-key, partition overwrite. This file covers a different layer: how the *design of the DAG itself*, independent of what's inside any single task, makes reprocessing safe.

## Structural idempotency: the window-parameterized task

Core principle: each DAG run is tied to a time window — its data interval — and a task should only touch the data belonging to that window. The run "for July 15th" processes exclusively July 15th's partition, and writes it with a partition **overwrite**, not an append. Consequence: re-running July 15th produces exactly the same state, with no duplication. This is what makes backfills and retries trivial instead of terrifying.

## Two terms that aren't interchangeable: `logical_date` vs. `data_interval`

Airflow separates two concepts that look similar but aren't. `logical_date` identifies *which run this is* — its identity, historically called `execution_date`. `data_interval_start`/`data_interval_end` identify *which window of data this run is responsible for*. These aren't synonyms: since Airflow 2.2 they're modeled as genuinely separate concepts, and Airflow 3.0 (AIP-83) widened the gap further — `logical_date` is now nullable, though the `(dag_id, logical_date)` uniqueness constraint itself is still enforced for non-null values: an early AIP-83 draft proposed removing it, but that was reverted before 3.0 shipped, specifically because it broke backfill semantics (ambiguity over whether re-running a date creates a new run or clears/reruns existing ones). Only NULL logical dates — asset-triggered or manually-triggered runs without one — can repeat, since SQL uniqueness constraints don't restrict multiple NULLs. When you parameterize a task by "its window," what you inject is `data_interval_start`/`data_interval_end` — not `logical_date`.

## Determinism

A task should never read "now" (`datetime.now()`) or "the last 100 rows" — it should receive its window as a parameter (the data interval Airflow injects) and be a pure function of that window.

```python
# Wrong: reprocessing yesterday with today's date gives a different result
@task
def extract():
    cutoff = datetime.now()
    return fetch_rows(since=cutoff - timedelta(days=1))

# Correct: the task is a pure function of its injected window
@task
def extract(data_interval_start, data_interval_end):
    return fetch_rows(start=data_interval_start, end=data_interval_end)
```

And on the write side: overwrite-by-partition, not append. Append is the #1 source of duplicates on reprocessing.

## Backfills

A backfill runs the pipeline over past dates — because you launched it today but need two years of history, or you found a bug and must reprocess an already-loaded month.

Core claim: **a backfill is trivial if — and only if — every run is idempotent and parameterized by its window.** If your tasks meet that bar, backfilling is just asking the orchestrator to run the DAG over a date range; each run reprocesses its own partition and overwrites, with no duplication and no cross-contamination. If tasks don't meet that bar — `now()` calls, append-only writes — a backfill duplicates data or produces results that don't match the original run, and turns into a manual nightmare.

## Concurrency and load control

Backfilling two years can launch hundreds of runs that saturate the warehouse or blow straight through the source API's rate limit. Bound the backfill's parallelism: Airflow's Pools and `max_active_runs` (a DAG-level setting, not a task-level one) exist for exactly this.

## Isolating backfills from production

This is genuinely first-class in **Dagster**: it reserves a `dagster/backfill` tag, with an explicit `tag_concurrency_limits` example in `dagster.yaml`, so a backfill run is capped separately from live runs on the same shared resource. **Airflow has no equivalent documented pattern** — a direct check of Airflow's own Pools documentation turns up zero mentions of "backfill." In Airflow, isolating a backfill from production is something you build yourself, by combining generic primitives — a dedicated pool, a separate Celery queue, `--max-active-runs` on the backfill CLI command — not a recipe Airflow ships. Attribute this per orchestrator; don't present it as a universal Airflow feature.

## Late-arriving data

Backfilling is also the mechanism for absorbing late-arriving data: reprocessing the affected window once delayed data shows up, which connects directly to the late-arriving-fact patterns covered in dimensional modeling.

## The `catchup` "scare" — corrected for current Airflow

Older folklore (and some still-open community issues, e.g. GitHub #19461, #25615) warns about accidentally triggering a storm of runs through Airflow's `catchup` mechanism, which schedules every missed interval between a DAG's `start_date` and now when `catchup=True`. The mechanism is real, but "accidentally leaving catchup on" misdescribes current Airflow: `catchup_by_default` is **already `False`** in Airflow's current configuration defaults. The two real triggers today are: legacy code that sets `catchup=True` explicitly, or resuming a DAG that's been paused for a long time — Airflow's own docs call out the second case directly. Historically (Airflow 1.10.1's docs confirm this), catchup-like behavior genuinely *was* the scheduler's default — that framing holds as a "this used to be the trap" story, just not as a description of what ships today.

## Dagster's partitions/backfills model

Dagster was built with a more explicit model from the start: partitions and backfills are first-class citizens of its API, not an emergent property of re-running a DAG over a date range.
