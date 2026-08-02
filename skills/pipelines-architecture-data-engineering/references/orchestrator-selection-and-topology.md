# Choosing and Deploying an Orchestrator

## Airflow vs. Dagster vs. Prefect

This isn't about having a favorite — it's about naming the decision axes and trade-offs.

**Airflow.** The de facto standard: an enormous ecosystem, a provider for nearly every system you'll integrate with, huge community and maturity — most likely what's already running at a large client. Its mental model is task-centric: you define tasks and their order. Classic downsides, partly mitigated across 2.x/3.x: historically awkward local testing, clunky data-passing between tasks (XCom), and — until data-aware scheduling matured — a scheduling model that made backfills easy to get wrong. If the environment is "large org, many systems, team that already knows it," Airflow is the safe bet.

**Dagster.** The asset-centric challenger: instead of thinking in tasks, you think in the **data assets** you produce — a table, a model, a dataset — and their dependencies; the orchestrator understands the lineage. Advantages: strong local dev/testing, I/O type-checking between steps, native and explicit partitions/backfills (see `idempotency-and-backfills.md`), and data-centric observability — what's fresh, what's stale. Fits teams that want data quality and lineage as first-class citizens, with a modern dev workflow. The axis: Airflow orchestrates *tasks*, Dagster orchestrates *assets*.

**Prefect.** The most Pythonic and lightweight option: you turn Python functions into flows via decorators, with minimal ceremony, DAGs that can be dynamic and defined at runtime, and a gentle learning curve. Good for teams that want flexibility and speed without Airflow's operational weight. The axis: less infrastructure, more "it's just Python."

One live wrinkle worth knowing as of this writing: Prefect announced acquiring Dagster Labs in July 2026, with the combined company operating under the Prefect name from August 2026 — Dagster and Dagster+ are stated to continue as products, but factor this consolidation into any long-term vendor bet between the two.

## The senior decision framework

Not a ranking — the axes: team maturity and size, ecosystem and integrations needed, whether the asset-based model adds real value (do you actually care about lineage and per-dataset freshness?), operational complexity you can sustain, and what the team already operates. The honest closer: for most organizations, "the orchestrator your team already knows and operates well" beats the technically superior option in the abstract — the cost of migrating and operating something new rarely pays for itself on elegance alone.

## Deployment topology

Where you find out whether someone has *operated* an orchestrator, not just written DAGs. Typical components, Airflow as the reference:

- **Scheduler** — the brain: parses DAGs, evaluates dependencies, queues ready tasks. The critical component — its failure halts everything. Airflow has supported multiple simultaneous active schedulers (HA) since **Airflow 2.0.0** (AIP-15).
- **Executor / Workers** — where tasks actually run. Executor choice is *the* topology decision:
  - *LocalExecutor* — everything on one machine; simple, for low volume.
  - *CeleryExecutor* — a fixed pool of workers behind a broker (Redis/RabbitMQ); scales horizontally. Note: the official Airflow Helm chart now supports scaling Celery workers to zero too, so "Celery workers are always on" is no longer an unqualified advantage of KubernetesExecutor over Celery — it's a deployment choice on both sides now.
  - *KubernetesExecutor* — each task is an ephemeral pod: full isolation (its own dependencies and resources), elastic scale-to-zero, no noisy neighbors. The cloud-native pattern, worth naming with its real trade-off — pod startup latency, plus the operational complexity of running Kubernetes.
- **Metadata database** — holds all state: what ran, when, with what result. Stateful, must be backed up; losing it is catastrophic.
- **Webserver/UI** — observability, logs, manual triggers, DAG visualization.

This is about the infrastructure components that run DAGs, not where DAG *source files* live in your repo before they reach the scheduler — see `project-structure-data-engineering` for that.

## Managed vs. self-hosted

Managed offerings — Amazon MWAA, Google's managed Airflow service (documented under "Cloud Composer," with GCP's docs migrating toward the generic name "Managed Service for Apache Airflow"), Astronomer, Dagster+ (the current brand for what used to be called "Dagster Cloud"), and Prefect Cloud — take scheduler/DB/HA operations off your plate in exchange for cost and some flexibility. The senior framing: "do I want my team operating Airflow, or paying someone else to, so we can focus on the pipelines themselves?" For most teams, managed wins.

## Dependency isolation

The real problem with hundreds of DAGs on one orchestrator: task A needs `pandas 1.x`, task B needs `pandas 2.x`. The fix is per-task isolation — KubernetesExecutor with per-task images, or operators that run inside isolated containers/environments. This dependency-hell-between-pipelines problem is a genuine senior concern, not a hypothetical.

## The topology principle

Separate the control plane from the data plane. The orchestrator — scheduler, workers, metadata — coordinates; heavy compute happens *outside* it, in the Spark cluster, in the warehouse, in a service, triggered by the task. An Airflow worker shouldn't be crunching a 100 GB DataFrame; it should be triggering and monitoring the Spark job that does. Conflating those planes — doing heavy work inside the worker — is the most common topology antipattern, and the one a senior interviewer is watching for.
