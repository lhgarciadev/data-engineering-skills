# Structure, Reuse, and Reliability

## TaskFlow API

The modern authoring style, introduced in **Airflow 2.0**: decorate Python functions with `@task` and Airflow wires the dependencies and passes XCom automatically through the return value, instead of the old `PythonOperator` plus manual `xcom_push`/`xcom_pull` ceremony. Cleaner, more testable, less boilerplate. Knowing both styles exist — classic operators and TaskFlow — and when each fits, signals you're current.

```python
from airflow.sdk import dag, task
from datetime import datetime

@dag(schedule="@daily", start_date=datetime(2026, 1, 1), catchup=False)
def ingestion_pipeline():
    @task
    def extract():
        return "s3://bucket/raw/2026-07-30/"

    @task
    def load(path: str):
        ...

    load(extract())

ingestion_pipeline()
```

## TaskGroups — and why SubDAGs are gone

For grouping tasks logically and visually (an "ingestion" section, a "transform" section), use **TaskGroups**. SubDAGs weren't just deprecated — they were **removed in Airflow 3.0**; Airflow's own migration notes list them under "Replaced by TaskGroups, Assets, and Data Aware Scheduling," and `SubDagOperator` no longer resolves in the current stable API reference at all. The reasoning behind the removal is accurately documented, not folklore: a SubDAG ran inside a single pool/concurrency slot, which could deadlock itself waiting on its own children. If you're maintaining a 2.x codebase you may still encounter one; on 3.x it's simply gone. Saying "SubDAGs, because they're deprecated" is dated — saying "TaskGroups, because SubDAGs were removed over the deadlock risk" is current.

```python
from airflow.sdk import task_group

@task_group
def ingestion():
    extract()
    validate()
```

## Setup/Teardown tasks

Introduced in **Airflow 2.7.0** — an elegant pattern for ephemeral resources: the setup task provisions something (a cluster, a temp schema), the teardown destroys it — and the teardown runs even if the intermediate work failed (built-in `all_done`-like semantics, via the dedicated `ALL_DONE_SETUP_SUCCESS` trigger rule), and the teardown's own failure doesn't fail the DAG by default (`on_failure_fail_dagrun` controls that). The right pattern for "spin up EMR, process, tear it down no matter what."

```python
cluster = create_cluster()
process_data(cluster)
cluster.as_teardown(setups=create_cluster)
```

## Dynamic DAG generation (the factory pattern)

When you have 50 nearly-identical pipelines (one ingestion per source table), you don't write 50 files — you write a template that generates DAGs from configuration (a YAML per source). This cuts duplication and makes maintenance uniform. The senior caveat: this generator code runs on *every* parse (see the antipattern below), so it must be lightweight and deterministic — Airflow's own Best Practices guide connects this exact point directly to the top-level-code warning.

## Pools and reliability configuration

**Pools** are the resource-protection pattern: a pool caps how many tasks hit a shared, finite resource at once. Give the pool `api_externa` 5 slots, and even if the DAG wants to fire 200 calls in parallel, only 5 run at a time. This is the mechanism that makes a large backfill safe against the systems it depends on — the concurrency control promised in `idempotency-and-backfills.md`, made concrete.

Task-level reliability config: `retries`, `retry_delay`, `retry_exponential_backoff` (accepts a float multiplier too, not just a boolean), `execution_timeout` (kills a hung task before it blocks everything). `max_active_runs` is a **DAG-level** setting, not a task-level one — it prevents overlapping runs from stepping on each other's data. `priority_weight` rounds out the set.

For observability: `on_failure_callback` fires alerts (Slack/PagerDuty) on failure — unchanged and current. The `sla`/`sla_miss_callback` mechanism you may have read about is **removed in Airflow 3.0**, replaced by **Deadline Alerts**, which are still **experimental as of 3.1**. Don't present `sla` as a universally current mechanism without checking the major version — name both explicitly: `sla_miss_callback` on 2.x, Deadline Alerts (experimental) on 3.x.

## The most dangerous topology antipattern: top-level code

Everything written outside a task — in the module's top level — executes on *every DAG parse*, which happens on every scheduler heartbeat (every few seconds), not just when the DAG actually runs. Put an API call, a heavy query, or `pandas.read_csv` there, and you hammer that system thousands of times a day and slow down the entire scheduler. Airflow's own Best Practices page uses almost this exact example:

> an `expensive_api_call()` executed each time the DAG file is parsed

The rule: the top level only defines structure; all I/O and all compute go inside a task. This is one of the errors a senior interviewer actively probes for, and it connects straight back to the governing principle of the whole topic — the orchestrator coordinates, it doesn't compute.
