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

For grouping tasks logically and visually (an "ingestion" section, a "transform" section), use **TaskGroups**. SubDAGs weren't just deprecated — they were **removed in Airflow 3.0**; Airflow's own migration notes describe them as "Replaced by TaskGroups, Assets, and Data Aware Scheduling," and `SubDagOperator` no longer resolves in the current stable API reference at all. The reasoning behind the removal is accurately documented, not folklore: a SubDAG ran inside a single pool/concurrency slot, which could deadlock itself waiting on its own children. If you're maintaining a 2.x codebase you may still encounter one; on 3.x it's simply gone. Saying "SubDAGs, because they're deprecated" is dated — saying "TaskGroups, because SubDAGs were removed over the deadlock risk" is current.

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
work = process_data(cluster)
teardown = delete_cluster()
cluster >> work >> teardown.as_teardown(setups=cluster)
```

## Dynamic DAG generation (the factory pattern)

When you have 50 nearly-identical pipelines (one ingestion per source table), you don't write 50 files — you write a template that generates DAGs from configuration (a YAML per source). This cuts duplication and makes maintenance uniform. The senior caveat: this generator code runs on *every* parse (see the antipattern below), so it must be lightweight and deterministic — Airflow's own Best Practices guide connects this exact point directly to the top-level-code warning.

## Testing a DAG

Airflow's own Best Practices guide treats a DAG as production code, not a script that either runs or doesn't — and prescribes tests at increasing levels of rigor.

**DAG loader test** — the cheapest check: run `python your_dag_file.py` and confirm it exits without error. Catches missing dependencies, syntax errors, and import failures, no test framework required. Run it in an environment matching your scheduler's (same dependencies, env vars), so a pass here actually means something.

**Unit test for loading**, via `DagBag` — note the import path, which changed from the `airflow.models` location some older examples still show:

```python
import pytest
from airflow.dag_processing.dagbag import DagBag

@pytest.fixture()
def dagbag():
    return DagBag()

def test_dag_loaded(dagbag):
    dag = dagbag.get_dag(dag_id="hello_world")
    assert dagbag.import_errors == {}
    assert dag is not None
    assert len(dag.tasks) == 1
```

`dagbag.import_errors` catches the same failure class as the loader test, but across every DAG in the folder at once, in a normal CI run.

**Unit test a DAG's structure** — useful for a factory-generated DAG (the pattern just above), to assert the shape matches its config instead of eyeballing it:

```python
def assert_dag_dict_equal(source, dag):
    assert dag.task_dict.keys() == source.keys()
    for task_id, downstream_list in source.items():
        assert dag.has_task(task_id)
        task = dag.get_task(task_id)
        assert task.downstream_task_ids == set(downstream_list)
```

**Test a task's actual behavior** — the highest-rigor layer: run the DAG for real, against a single logical date, and assert on the result:

```python
import pendulum
from airflow.sdk import DAG, TaskInstanceState

def test_my_custom_operator_execute_no_trigger(dag):
    TEST_TASK_ID = "my_custom_operator_task"
    with DAG(
        dag_id="my_custom_operator_dag",
        schedule="@daily",
        start_date=pendulum.datetime(2021, 9, 13, tz="UTC"),
    ) as dag:
        MyCustomOperator(task_id=TEST_TASK_ID, prefix="s3://bucket/some/prefix")

    dagrun = dag.test()
    ti = dagrun.get_task_instance(task_id=TEST_TASK_ID)
    assert ti.state == TaskInstanceState.SUCCESS
```

`dag.test()` actually executes the DAG locally against a single run and returns a real `DagRun` you can inspect — closer to an integration test than a unit test, and the right tool when you need to know the task did the right thing, not just that the graph is shaped correctly.

One thing not to reach for: a `dag.test_cycle()` public method. It shows up in older community examples, but it isn't part of Airflow's current public API for user DAG tests — cycles are rejected when Airflow parses and bags the DAG, not something your test needs to assert separately — and Airflow's own current test-writing guidance doesn't feature a standalone cycle check at all.

## Pools and reliability configuration

**Pools** are the resource-protection pattern: a pool caps how many tasks hit a shared, finite resource at once. Give the pool `external_api` 5 slots, and even if the DAG wants to fire 200 calls in parallel, only 5 run at a time. This is the mechanism that makes a large backfill safe against the systems it depends on — the concurrency control promised in `idempotency-and-backfills.md`, made concrete.

Task-level reliability config: `retries`, `retry_delay`, `retry_exponential_backoff` (accepts a float multiplier too, not just a boolean), `execution_timeout` (kills a hung task before it blocks everything). `max_active_runs` is a **DAG-level** setting, not a task-level one — it prevents overlapping runs from stepping on each other's data. `priority_weight` rounds out the set.

For observability: `on_failure_callback` fires alerts (Slack/PagerDuty) on failure — unchanged and current. The `sla`/`sla_miss_callback` mechanism you may have read about is **removed in Airflow 3.0**, replaced by **Deadline Alerts**, which are still **experimental as of 3.1**. Don't present `sla` as a universally current mechanism without checking the major version — name both explicitly: `sla_miss_callback` on 2.x, Deadline Alerts (experimental) on 3.x.

## The most dangerous topology antipattern: top-level code

Everything written outside a task — in the module's top level — executes on *every DAG parse*, which happens on every scheduler heartbeat (every few seconds), not just when the DAG actually runs. Put an API call, a heavy query, or `pandas.read_csv` there, and you hammer that system thousands of times a day and slow down the entire scheduler. Airflow's own Best Practices page states this directly:

> `expensive_api_call` is executed each time the Dag file is parsed, which will result in suboptimal performance in the Dag file processing.

The rule: the top level only defines structure; all I/O and all compute go inside a task. This is one of the errors a senior interviewer actively probes for, and it connects straight back to the governing principle of the whole topic — the orchestrator coordinates, it doesn't compute.
