# Orchestration Fundamentals: Why a Scheduler Isn't Enough

The orchestrator doesn't do the heavy lifting — Spark, the warehouse, the source APIs do that. The orchestrator decides what runs, when, in what order, and what happens when something fails. It's the nervous system, not the muscles. Confusing those two roles — putting heavy business logic inside the orchestrator — is one of the antipatterns a senior interviewer catches instantly, and it's the thread that ties every file in this skill together.

## Why an orchestrator exists

A real pipeline isn't a script — it's dozens of steps with dependencies (extract from an API → land raw → validate → transform → load to the warehouse → refresh a dbt model → fire a report), running on different schedules, failing in different ways, and needing retries, alerts, and resumption without duplicating work. `cron` with chained scripts gives you none of that: it doesn't know about dependencies, doesn't retry with any judgment, doesn't tell you *why* step 7 failed last night, and doesn't let you reprocess just last Tuesday.

An orchestrator earns its place by providing five things — a senior should be able to name all five without prompting:

1. **Dependency management**
2. **Scheduling**
3. **Retries and failure handling**
4. **Observability and alerting**
5. **Backfills**

If you open an answer by explaining what problem this solves, before naming Airflow, you already sound senior.

## The DAG as the mental model

The central concept is the **DAG** — Directed Acyclic Graph: tasks are nodes, dependencies are directed edges, and "acyclic" means there are no cycles — A can't depend on something that (transitively) depends on A, or the pipeline would never finish. This model is what lets the orchestrator know what can run in parallel (independent branches) and what has to wait (anything downstream of a dependency).

## Tasks vs. the work inside a task

The most important, most-asked design distinction: a task should be the **atomic, idempotent, and stateless** unit of work.

- **Fine-grained** — but not *too* fine (task granularity is its own trade-off, covered in `scheduling-and-dependencies.md`) — so a failure only forces a retry of a small amount of work, not the whole pipeline.
- **Idempotent** — the concept already covered at the code level in `python-data-engineering` — so a retry doesn't duplicate.
- **Stateless** — so the orchestrator can run it on any worker.

When an interviewer asks "how do you split a pipeline into tasks," this is the answer.

## Separate orchestration from execution

The DAG's code defines *what* runs and *in what order* — it shouldn't contain the heavy transformation inline. A task *invokes* the work (triggers a Spark job, runs a dbt model, calls your ingestion function), but the actual compute lives outside the orchestrator. This keeps the orchestrator lightweight and keeps the work independently testable.

## Pass pointers, not data

Between tasks, don't move large DataFrames — pass references: an S3 path, a partition ID. Heavy state lives in storage (S3, the warehouse), not in the orchestrator.

In Airflow specifically, putting large data in XCom is a classic antipattern. Airflow's own documentation is explicit about XCom's intended size:

> "They can have any serializable value..., but they are only designed for small amounts of data; do not use them to pass around large values, like dataframes."
> — [XComs — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/xcoms.html)

XCom is for small metadata — a path, a watermark, a row count — not a DataFrame.

```python
# Antipattern: shoving a full result set through XCom
@task
def extract():
    return fetch_all_rows()          # could be millions of rows -> bloats the metadata DB

# Correct: land the data, pass a pointer
@task
def extract():
    path = f"s3://raw/orders/{ds}/"  # ds: Airflow's injected logical-date template variable
    write_to_s3(fetch_all_rows(), path)
    return path                      # small, stable metadata
```
