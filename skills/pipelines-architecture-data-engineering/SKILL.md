---
name: pipelines-architecture-data-engineering
description: Pipeline orchestration and DAG design — orchestrator choice (Airflow, Dagster, Prefect), task granularity, idempotency and backfills, data-aware scheduling, deployment topology, dbt project architecture (staging/intermediate/marts layering, materializations, environments), and Airflow patterns (trigger rules, branching, sensors, dynamic task mapping, pools). Use when designing or reviewing a pipeline's orchestration layer, choosing an orchestrator, structuring a dbt project, diagnosing a broken backfill, a DAG that skips or hangs, or a rerun that produced duplicate rows, or how a pipeline serves its output. Still applies when a general debugging or design skill also fits — that one supplies the method, this one the pipeline-domain knowledge. Not for idempotent code inside a task (see python-data-engineering), dbt's SQL-level incremental mechanics (see sql-data-engineering), or hosting an API service (see references/serving-pipeline-output.md).
---

# Pipeline Orchestration Architecture

## Overview

Senior-level judgment calls for the orchestration layer of a data pipeline — which pattern or orchestrator to reach for and why, not operator syntax. The orchestrator coordinates; it doesn't compute. Its value is dependency management, scheduling, retries, observability, and backfills — and all of that only works if tasks are idempotent, deterministic, and parameterized by their data window. Read the relevant file(s) before proposing a design or reviewing a DAG; don't rely on the table below alone. Airflow 3.x (current stable = 3.3.0) is the version baseline throughout; 2.x divergences are named explicitly wherever they still matter in production.

## When to use

- Designing or reviewing a pipeline's DAG structure, task boundaries, or dependency graph
- Choosing an orchestrator (Airflow, Dagster, Prefect) or its deployment topology
- A backfill duplicated data, is stuck, or risks overwhelming a downstream system
- A DAG task skips unexpectedly, hangs, or a sensor is eating worker capacity
- Deciding how a pipeline should trigger downstream work, or how another pipeline should trigger off it
- Deciding how a pipeline's output should reach its consumers (API, stream, export, share)
- Structuring a dbt project, deciding its model layering, or figuring out how dbt's model DAG fits inside the pipeline orchestrator's own DAG
- Not for writing the idempotent code inside a single task (see `python-data-engineering`), dbt's SQL-level incremental mechanics (see `sql-data-engineering`), building/hosting an API service (see [serving-pipeline-output.md](references/serving-pipeline-output.md)), or replaying a log from an earlier offset to reprocess history (see `streaming-data-engineering`) — this skill's backfill mechanics cover partition-level batch reprocessing only, not stream replay

## Quick reference

| Concern | Reach for | Reference |
|---|---|---|
| Why an orchestrator instead of cron + scripts | Dependency management, scheduling, retries, observability, backfills | [orchestration-fundamentals.md](references/orchestration-fundamentals.md) |
| How to size and design a task | Atomic, idempotent, stateless; pointers not data | [orchestration-fundamentals.md](references/orchestration-fundamentals.md) |
| Making a run safely re-runnable | Window-parameterized task + partition overwrite | [idempotency-and-backfills.md](references/idempotency-and-backfills.md) |
| Reprocessing history without duplicating or overwhelming a source | Backfill = idempotency + determinism + concurrency control | [idempotency-and-backfills.md](references/idempotency-and-backfills.md) |
| Triggering B when A's data is actually ready | Data-aware scheduling (Assets), not a fixed time offset | [scheduling-and-dependencies.md](references/scheduling-and-dependencies.md) |
| How fine or coarse to cut a DAG's tasks | Fine enough to retry usefully, coarse enough to avoid overhead | [scheduling-and-dependencies.md](references/scheduling-and-dependencies.md) |
| Airflow vs. Dagster vs. Prefect | Decision axes, not a favorite | [orchestrator-selection-and-topology.md](references/orchestrator-selection-and-topology.md) |
| Scheduler/executor/metadata-DB topology, managed vs. self-hosted | Control plane vs. data plane | [orchestrator-selection-and-topology.md](references/orchestrator-selection-and-topology.md) |
| A task got skipped and you don't know why | `trigger_rule`, especially after a branch | [airflow-trigger-rules-and-branching.md](references/airflow-trigger-rules-and-branching.md) |
| Routing a DAG down different paths at runtime | `@task.branch`, `ShortCircuitOperator`, `LatestOnlyOperator` | [airflow-trigger-rules-and-branching.md](references/airflow-trigger-rules-and-branching.md) |
| Waiting on an external file, table, or DAG | Sensors — `mode="reschedule"` or deferrable, not `poke` | [airflow-sensors-and-dynamic-mapping.md](references/airflow-sensors-and-dynamic-mapping.md) |
| Parallelizing over a number of items unknown until runtime | Dynamic Task Mapping (`.expand()`) | [airflow-sensors-and-dynamic-mapping.md](references/airflow-sensors-and-dynamic-mapping.md) |
| Modern DAG authoring style, reuse, ephemeral resources | TaskFlow API, TaskGroups, setup/teardown | [airflow-structure-and-reliability.md](references/airflow-structure-and-reliability.md) |
| Protecting a shared resource, or alerting on failure | Pools, retries, `on_failure_callback` | [airflow-structure-and-reliability.md](references/airflow-structure-and-reliability.md) |
| Serving a pipeline's output to a consumer | Serving layer vs. warehouse; API vs. stream vs. export vs. share | [serving-pipeline-output.md](references/serving-pipeline-output.md) |
| Structuring a new dbt project, or naming its model layers | staging → intermediate → marts (dbt's own vocabulary, not "medallion") | [dbt-project-architecture.md](references/dbt-project-architecture.md) |
| Deciding where a model's materialization is configured | `dbt_project.yml` (+folder default) → `.yml` properties → `config()` in the model, least to most specific | [dbt-project-architecture.md](references/dbt-project-architecture.md) |
| One `dbt build` task, or several split by selector? | `--select`/`+model`/`model+`/`tag:` — the orchestration-granularity lever for dbt's own DAG | [dbt-project-architecture.md](references/dbt-project-architecture.md) |
| Consuming an external API for ingestion | Auth, pagination, backoff/jitter, watermark | [python-data-engineering](../python-data-engineering/references/external-api-integration.md) |
| Testing a DAG before it ships | DAG loader test, DagBag import check, `dag.test()` | [airflow-structure-and-reliability.md](references/airflow-structure-and-reliability.md) |

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Heavy transformation logic written inline in the DAG file | Couples orchestration to compute, makes the DAG slow to parse and impossible to test in isolation | Task invokes external compute (Spark job, dbt model); orchestrator only sequences it. See [orchestration-fundamentals.md](references/orchestration-fundamentals.md) |
| Recreating dbt's model dependency graph as separate orchestrator tasks | Duplicates a graph dbt already resolves via `ref()`/`source()`; two places for a dependency to drift out of sync | Let one `dbt build` task (or a few, split by selector/tag) own the model-level DAG. See [dbt-project-architecture.md](references/dbt-project-architecture.md) |
| Presenting "medallion" (bronze/silver/gold) as dbt's own layering vocabulary | Misattributes a Databricks/lakehouse term to dbt Labs; dbt's own docs use staging/intermediate/marts exclusively | Use staging/intermediate/marts as dbt's documented terms; frame medallion as an optional community analogy at most. See [dbt-project-architecture.md](references/dbt-project-architecture.md) |
| Passing a large DataFrame between tasks via XCom | XCom is for small metadata; large payloads bloat the metadata DB and can crash the scheduler | Pass a pointer (S3 path, partition ID). See [orchestration-fundamentals.md](references/orchestration-fundamentals.md) |
| A task reads `datetime.now()` or "the last N rows" instead of its injected window | Reprocessing yesterday with today's date gives a different result — breaks backfills | Parameterize by `data_interval_start`/`data_interval_end`. See [idempotency-and-backfills.md](references/idempotency-and-backfills.md) |
| Backfilling years of history with unlimited parallelism | Saturates the warehouse or blows through the source API's rate limit | Bound concurrency with pools/`max_active_runs`. See [idempotency-and-backfills.md](references/idempotency-and-backfills.md) |
| Scheduling a downstream DAG a fixed time after the upstream one | If upstream runs late, downstream silently processes stale data | Trigger on the upstream Asset's materialization, not a clock offset. See [scheduling-and-dependencies.md](references/scheduling-and-dependencies.md) |
| Choosing an orchestrator by feature checklist instead of what the team can operate | Technically superior tooling nobody can run reliably underperforms the boring choice | Weigh team maturity and existing ops burden explicitly. See [orchestrator-selection-and-topology.md](references/orchestrator-selection-and-topology.md) |
| A join task after a branch left on the default `trigger_rule` | `all_success` treats a sibling branch's `skipped` state as failure — the join silently skips too | Set `trigger_rule="none_failed_min_one_success"` on the join. See [airflow-trigger-rules-and-branching.md](references/airflow-trigger-rules-and-branching.md) |
| Sensors left on the default `poke` mode at scale | Each sensor holds a worker slot for its entire wait — enough sensors and the DAG stalls waiting on itself | Use `mode="reschedule"` or a deferrable operator. See [airflow-sensors-and-dynamic-mapping.md](references/airflow-sensors-and-dynamic-mapping.md) |
| API call, DB query, or `pandas.read_csv` at the DAG file's top level | Runs on every scheduler parse (every few seconds), not just when the DAG executes — hammers the system and slows the whole scheduler | Move all I/O and compute inside a task. See [airflow-structure-and-reliability.md](references/airflow-structure-and-reliability.md) |
| Presenting `sla`/`sla_miss_callback` as current without checking the Airflow major version | Removed in Airflow 3.0, replaced by the still-experimental Deadline Alerts | Confirm the major version before recommending either mechanism. See [airflow-structure-and-reliability.md](references/airflow-structure-and-reliability.md) |
| Serving an API's read traffic directly from the analytical warehouse | OLAP engines are slow and expensive for millisecond point lookups | Materialize a serving store (Postgres/DynamoDB/Redis) from the pipeline. See [serving-pipeline-output.md](references/serving-pipeline-output.md) |
