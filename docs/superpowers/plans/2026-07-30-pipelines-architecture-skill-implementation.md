# Pipelines Architecture Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the `pipelines-architecture-data-engineering` domain skill (`SKILL.md` + 8 reference files), add a new `external-api-integration.md` reference file (+ `SKILL.md` update) to the existing `python-data-engineering` skill to close the API-consumption gap and resolve the suite spec's §7.7 scope fork, and validate both with fresh-agent discoverability/correctness scenarios.

**Architecture:** Same shape as `python-data-engineering`/`sql-data-engineering`/`spark-data-engineering` — a `SKILL.md` with overview/when-to-use/quick-reference/common-mistakes, and one reference file per heavy topic under `references/`. Content is the verified, corrected version of the user's three drafts (orchestration fundamentals, Airflow-specific DAG patterns, API consumption/serving), split across two skills per the scope-fork resolution in the design spec.

**Tech Stack:** Markdown, Python/Airflow DAG code examples, git.

## Global Constraints

- Content in English; code examples in Python (Airflow DAG syntax for orchestration examples, `requests`/`aiohttp` for the API file) — per `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §3.
- `SKILL.md` frontmatter limited to `name` + `description` — no Claude-specific fields.
- New skill identifier is `pipelines-architecture-data-engineering` (matches folder name, carries the suite-wide `-data-engineering` suffix per the 2026-07-30 naming scheme).
- Version baseline: **Apache Airflow 3.x** (current stable docs resolve to 3.3.0). Where 2.x diverges in ways that still matter in production, name the version explicitly rather than presenting one version's behavior as universal: `Dataset`→`Asset` rename (3.0, AIP-74; `Dataset` is now a deprecated alias), `SubDagOperator` **removed** (not deprecated) in 3.0, `sla`/`sla_miss_callback` **removed** in 3.0 → replaced by Deadline Alerts (experimental as of 3.1), task state `shutdown` deprecated in 2.7.2 and removed in 3.0.0, `SqlSensor`/`ExternalTaskSensor` moved from core to provider packages in 3.x, `catchup_by_default` is already `False` in current Airflow.
- API scope-fork resolution (design spec §2.1, confirmed with Leonardo 2026-07-30 — team has no real serving-API use case yet): API *consumption* → `python-data-engineering/references/external-api-integration.md` (this plan, Task 10-11). API *serving-layer decision* (not implementation) → `pipelines-architecture-data-engineering/references/serving-pipeline-output.md` (this plan, Task 8). API *implementation* (FastAPI, REST/GraphQL/gRPC, endpoint code) → explicitly out of scope, not written anywhere.
- Does not cover: task-level idempotent code (→ `python-data-engineering`, already exists), Structured Streaming/CDC (→ future `streaming-data-engineering`), Spark cluster infrastructure (→ future `iac-cloud-data-engineering`), dimensional modeling (→ future `modeling-data-engineering`).
- Every correction below traces to a specific research file under `docs/superpowers/research/2026-07-30-*.md` — cite the mechanism/version, don't restate as if self-evident.

---

## File Structure

**Create, in `data-engineering-skills/skills/pipelines-architecture-data-engineering/`:**
- `SKILL.md` — overview, when to use, quick reference table (17 rows across 8 reference files + 1 cross-skill link), common mistakes table (citing every reference file).
- `references/orchestration-fundamentals.md` — why an orchestrator exists, the DAG mental model, task design (atomic/idempotent/stateless), separating orchestration from execution, pointers not data.
- `references/idempotency-and-backfills.md` — structural idempotency (window-parameterized tasks, partition overwrite), determinism, backfills (precondition, concurrency control, isolation, late-arriving data, `catchup`).
- `references/scheduling-and-dependencies.md` — time-based vs. data-aware (Asset) scheduling, intra-DAG vs. inter-DAG dependencies, task granularity.
- `references/orchestrator-selection-and-topology.md` — Airflow vs. Dagster vs. Prefect, deployment topology, managed vs. self-hosted, dependency isolation.
- `references/airflow-trigger-rules-and-branching.md` — task states, the full trigger-rule catalog, branching operators, the join-after-branch trap.
- `references/airflow-sensors-and-dynamic-mapping.md` — sensors (poke vs. reschedule vs. deferrable), fan-out/fan-in, Dynamic Task Mapping.
- `references/airflow-structure-and-reliability.md` — TaskFlow API, TaskGroups (and why SubDAGs are gone), setup/teardown, DAG factories, pools, reliability config, the top-level-code antipattern.
- `references/serving-pipeline-output.md` — serving layer vs. warehouse OLAP, freshness/SLA trade-off, when not to build an API. Explicitly notes what's excluded and why.

**Create/modify, in `data-engineering-skills/skills/python-data-engineering/`:**
- `references/external-api-integration.md` — new file: HTTP fundamentals, auth, pagination, rate limiting/resilience, incremental extraction from APIs, concurrency, contract/observability, push vs. pull.
- `SKILL.md` — modify: add one quick-reference row and three common-mistakes rows pointing to the new file.

Each reference file is its own task. Both `SKILL.md` files come after their reference files, since their quick-reference tables name every file. Validation is a final task against both assembled skills.

---

### Task 1: `references/orchestration-fundamentals.md`

**Files:**
- Create: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/orchestration-fundamentals.md`

**Interfaces:**
- Produces: the file `orchestration-fundamentals.md`, linked from `SKILL.md` (Task 9).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/orchestration-fundamentals.md`:

````markdown
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
    path = f"s3://raw/orders/{ds}/"
    write_to_s3(fetch_all_rows(), path)
    return path                      # small, stable metadata
```
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/pipelines-architecture-data-engineering/references/orchestration-fundamentals.md`
Expected: `5`.

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/references/orchestration-fundamentals.md
git commit -m "feat(pipelines-architecture): add orchestration fundamentals reference"
```

---

### Task 2: `references/idempotency-and-backfills.md`

**Files:**
- Create: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/idempotency-and-backfills.md`

**Interfaces:**
- Consumes: task-granularity/idempotency vocabulary established in `orchestration-fundamentals.md` (Task 1).
- Produces: the file `idempotency-and-backfills.md`, linked from `SKILL.md` (Task 9) and cross-referenced by `airflow-structure-and-reliability.md` (Task 7, Pools section).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/idempotency-and-backfills.md`:

````markdown
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
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/pipelines-architecture-data-engineering/references/idempotency-and-backfills.md`
Expected: `9`.

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/references/idempotency-and-backfills.md
git commit -m "feat(pipelines-architecture): add idempotency and backfills reference"
```

---

### Task 3: `references/scheduling-and-dependencies.md`

**Files:**
- Create: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/scheduling-and-dependencies.md`

**Interfaces:**
- Produces: the file `scheduling-and-dependencies.md`, linked from `SKILL.md` (Task 9); its sensor summary forward-references `airflow-sensors-and-dynamic-mapping.md` (Task 6) by filename.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/scheduling-and-dependencies.md`:

````markdown
# Scheduling and Dependencies

## Time-based vs. data-aware scheduling

Beyond cron-style schedules (hourly, daily), a senior distinguishes time-based triggers from event/data-driven triggers: running *when an upstream dataset is actually ready*, not at a fixed hour hoping it already is.

Airflow's mechanism for this is currently called an **Asset** — not "Dataset." The feature launched as "Datasets" in Airflow 2.4.0 (the "That Data Aware Release"), and was renamed to **Asset** in Airflow 3.0 under AIP-74 ("Introducing Data Assets") — the rename touches the database schema, the REST API, and the UI, not just the Python import path. `airflow.datasets.Dataset` still exists as a deprecated alias (`airflow.sdk.Asset` is the replacement), scheduled for removal in a future release. Teach "Asset" as the current term; mention "Dataset" only as the pre-3.0 name you'll still see in older code and tutorials.

```python
from airflow.sdk import Asset, dag, task

orders_asset = Asset("s3://bucket/orders/")

# Producer DAG marks the asset it materializes
@task(outlets=[orders_asset])
def load_orders():
    ...

# Consumer DAG schedules off the asset instead of a fixed time
@dag(schedule=[orders_asset])
def refresh_orders_dashboard():
    ...
```

Dagster centers this model from the start — you think in assets (the data products you produce) and their dependencies, and the orchestrator understands the lineage.

## Sensors, briefly

A sensor waits for an external condition — a file landing in S3, a partition being ready — before letting the DAG proceed. It's the classic fallback for cross-pipeline dependencies when the upstream system doesn't emit an event you can hook an Asset to. The risk (consuming a worker slot for the entire wait) and its mitigations get their own deep dive in `airflow-sensors-and-dynamic-mapping.md` — here, just know sensors exist as the fallback when data-aware scheduling isn't available.

## Two kinds of dependency — don't conflate them

- **Intra-DAG dependencies**: the order between tasks in the *same* pipeline (`extract >> validate >> load`). Trivial — this is just DAG structure.
- **Inter-DAG / cross-pipeline dependencies**: pipeline B needs pipeline A's *current run* to have finished. This is where the interesting design decision lives.

The classic failure mode is scheduling B a fixed time after A — "run B an hour after A" — which is fragile: if A runs late, B silently processes stale data. The senior fix is to trigger B from A's actual output being ready — an Asset-driven trigger, or, with caveats, a sensor watching for the specific condition. Note on sourcing: "fixed-offset scheduling is fragile" is the engineering reasoning behind this guidance, not a claim lifted from Airflow's or Astronomer's own docs — Astronomer's own cross-DAG-dependencies documentation doesn't frame scheduling offsets in these terms. Present it as engineering judgment, which it is, not as a documented vendor position.

## Task granularity — the judgment call, not a rule

If a DAG has 400 hyper-fine tasks, scheduling overhead dominates; if it has 3 monster tasks, you lose retry and observability granularity. The right grain is fine enough to retry and observe usefully, coarse enough that overhead doesn't drown it out. This is a design judgment call — no orchestrator's official docs prescribe a specific granularity — but it isn't contradicted by any of them either; it's the same trade-off every orchestrator's best-practices guidance gestures at without giving a number.
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/pipelines-architecture-data-engineering/references/scheduling-and-dependencies.md`
Expected: `4`.

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/references/scheduling-and-dependencies.md
git commit -m "feat(pipelines-architecture): add scheduling and dependencies reference"
```

---

### Task 4: `references/orchestrator-selection-and-topology.md`

**Files:**
- Create: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md`

**Interfaces:**
- Produces: the file `orchestrator-selection-and-topology.md`, linked from `SKILL.md` (Task 9).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md`:

````markdown
# Choosing and Deploying an Orchestrator

## Airflow vs. Dagster vs. Prefect

This isn't about having a favorite — it's about naming the decision axes and trade-offs.

**Airflow.** The de facto standard: an enormous ecosystem, a provider for nearly every system you'll integrate with, huge community and maturity — most likely what's already running at a large client. Its mental model is task-centric: you define tasks and their order. Classic downsides, partly mitigated across 2.x/3.x: historically awkward local testing, clunky data-passing between tasks (XCom), and — until data-aware scheduling matured — a scheduling model that made backfills easy to get wrong. If the environment is "large org, many systems, team that already knows it," Airflow is the safe bet.

**Dagster.** The asset-centric challenger: instead of thinking in tasks, you think in the **data assets** you produce — a table, a model, a dataset — and their dependencies; the orchestrator understands the lineage. Advantages: strong local dev/testing, I/O type-checking between steps, native and explicit partitions/backfills (see `idempotency-and-backfills.md`), and data-centric observability — what's fresh, what's stale. Fits teams that want data quality and lineage as first-class citizens, with a modern dev workflow. The axis: Airflow orchestrates *tasks*, Dagster orchestrates *assets*.

**Prefect.** The most Pythonic and lightweight option: you turn Python functions into flows via decorators, with minimal ceremony, DAGs that can be dynamic and defined at runtime, and a gentle learning curve. Good for teams that want flexibility and speed without Airflow's operational weight. The axis: less infrastructure, more "it's just Python."

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

## Managed vs. self-hosted

Managed offerings — Amazon MWAA, Google's managed Airflow service (documented under "Cloud Composer," with GCP's docs migrating toward the generic name "Managed Service for Apache Airflow"), Astronomer, Dagster+ (the current brand for what used to be called "Dagster Cloud"), and Prefect Cloud — take scheduler/DB/HA operations off your plate in exchange for cost and some flexibility. The senior framing: "do I want my team operating Airflow, or paying someone else to, so we can focus on the pipelines themselves?" For most teams, managed wins.

## Dependency isolation

The real problem with hundreds of DAGs on one orchestrator: task A needs `pandas 1.x`, task B needs `pandas 2.x`. The fix is per-task isolation — KubernetesExecutor with per-task images, or operators that run inside isolated containers/environments. This dependency-hell-between-pipelines problem is a genuine senior concern, not a hypothetical.

## The topology principle

Separate the control plane from the data plane. The orchestrator — scheduler, workers, metadata — coordinates; heavy compute happens *outside* it, in the Spark cluster, in the warehouse, in a service, triggered by the task. An Airflow worker shouldn't be crunching a 100 GB DataFrame; it should be triggering and monitoring the Spark job that does. Conflating those planes — doing heavy work inside the worker — is the most common topology antipattern, and the one a senior interviewer is watching for.
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md`
Expected: `6`.

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md
git commit -m "feat(pipelines-architecture): add orchestrator selection and topology reference"
```

---

### Task 5: `references/airflow-trigger-rules-and-branching.md`

**Files:**
- Create: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-trigger-rules-and-branching.md`

**Interfaces:**
- Produces: the file `airflow-trigger-rules-and-branching.md`, linked from `SKILL.md` (Task 9).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-trigger-rules-and-branching.md`:

````markdown
# Airflow Task States, Trigger Rules, and Branching

Nearly every "why didn't my task run" bug reduces to one primitive: task state, and how each task reacts to its parents' states via its `trigger_rule`. Master that and the rest of this file follows directly.

## Task states

A task ends in one of several states — `success`, `failed`, `skipped`, `upstream_failed`, among others. If you've seen `shutdown` mentioned as a task state, drop it: it was marked deprecated in **2.7.2** (kept in the codebase for backward compatibility, with a `# TODO: Remove in Airflow 3.0` comment) but stayed present through the rest of the 2.x series, and was only actually removed in **3.0.0** — so it isn't part of the current state machine. A newer addition worth knowing about is `awaiting_input`, added in 3.3.0 for Human-in-the-Loop tasks — a different feature, not something to dig into here.

## Trigger rules

Each task decides whether to run based on its parents' states — that decision is `trigger_rule`, and its default is `all_success`: a task only runs if every parent succeeded. That default causes most "why did my task get skipped" surprises, including the branching trap below.

Airflow's official catalog has **13** trigger rules total. The six below are the ones worth having at your fingertips — don't present them as the whole list:

| Trigger rule | Runs when |
|---|---|
| `all_success` (default) | All parents succeeded |
| `all_done` | All parents finished, regardless of outcome — the cleanup pattern: a task that tears down an ephemeral cluster or releases a resource needs `all_done` so it runs even if the job failed |
| `none_failed` | No parent failed (skips are OK) |
| `none_failed_min_one_success` | No parent failed AND at least one succeeded (not just skips) — the join-after-branch pattern below |
| `one_success` / `one_failed` | Runs as soon as *one* parent reaches that state, without waiting for the rest — `one_failed` is the alert/fallback-path pattern |
| `always` | Runs no matter what |

The remaining six — `all_failed`, `all_skipped`, `one_done`, `all_done_min_one_success`, `all_done_setup_success`, and `none_skipped` — cover narrower cases; check Airflow's trigger-rule reference when one of the six above doesn't fit.

One rename worth knowing if you read older code or tutorials: `none_failed_min_one_success` was called `none_failed_or_skipped` before **Airflow 2.2.0** — the old name is fully gone as of 3.0.

Closing point: almost no "task skipped unexpectedly" bug is a code bug — it's a mis-chosen trigger rule. Naming the right trigger rule for a convergence or cleanup node is a direct signal of hands-on DAG experience.

## Branching

The pattern for the DAG to choose a path at runtime. Three operators:

**`@task.branch`** (and the older `BranchPythonOperator`) — runs logic and returns the `task_id` (or list of them) of the branch to follow; branches not chosen end up `skipped`. The canonical data case: deciding full vs. incremental load, or routing based on a condition in the data.

```python
from airflow.sdk import task

@task.branch
def choose_load_strategy(**context):
    if is_first_run(context["data_interval_start"]):
        return "full_load"
    return "incremental_load"
```

**`ShortCircuitOperator`** — if the condition is false, skips everything downstream. A guard clause: "if there's no new data, don't continue."

**`LatestOnlyOperator`** — skips downstream tasks on runs that aren't the most recent one — i.e., during a backfill. The pattern for things you don't want re-triggered historically (a live notification, refreshing a live dashboard) while backfilling everything else.

## The join-after-branch trap

The single most-asked question on this topic, and it's a trap Airflow's own documentation walks through explicitly — not just production folklore. When branches reconverge at a join task, that join carries the default `all_success`. One of its parent branches ended up `skipped` — and `all_success` treats a skip as "not satisfied," so the join *also* gets skipped, silently. Airflow's own docs use exactly this shape (a `join` task downstream of `branch_a`/`follow_branch_a`) to teach the fix: give the join `trigger_rule="none_failed_min_one_success"`.

```python
from airflow.providers.standard.operators.empty import EmptyOperator

join = EmptyOperator(
    task_id="consolidate",
    trigger_rule="none_failed_min_one_success",
)
[full_load, incremental_load] >> join
```

Naming this before anyone asks — "watch out, the join after a branch needs its trigger rule changed or it'll skip" — is one of the cleanest signals that you've actually built DAGs, because it's the kind of thing you only know from having been bitten by it.
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-trigger-rules-and-branching.md`
Expected: `4`.

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-trigger-rules-and-branching.md
git commit -m "feat(pipelines-architecture): add Airflow trigger rules and branching reference"
```

---

### Task 6: `references/airflow-sensors-and-dynamic-mapping.md`

**Files:**
- Create: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-sensors-and-dynamic-mapping.md`

**Interfaces:**
- Consumes: the Asset-based scheduling alternative introduced in `scheduling-and-dependencies.md` (Task 3).
- Produces: the file `airflow-sensors-and-dynamic-mapping.md`, linked from `SKILL.md` (Task 9).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-sensors-and-dynamic-mapping.md`:

````markdown
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
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-sensors-and-dynamic-mapping.md`
Expected: `5`.

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-sensors-and-dynamic-mapping.md
git commit -m "feat(pipelines-architecture): add Airflow sensors and dynamic mapping reference"
```

---

### Task 7: `references/airflow-structure-and-reliability.md`

**Files:**
- Create: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-structure-and-reliability.md`

**Interfaces:**
- Consumes: Pools/`max_active_runs` concepts introduced in `idempotency-and-backfills.md` (Task 2, backfill concurrency control).
- Produces: the file `airflow-structure-and-reliability.md`, linked from `SKILL.md` (Task 9).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-structure-and-reliability.md`:

````markdown
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
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-structure-and-reliability.md`
Expected: `6`.

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-structure-and-reliability.md
git commit -m "feat(pipelines-architecture): add Airflow structure and reliability reference"
```

---

### Task 8: `references/serving-pipeline-output.md`

**Files:**
- Create: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`

**Interfaces:**
- Consumes: the control-plane/data-plane framing from `orchestrator-selection-and-topology.md` (Task 4).
- Produces: the file `serving-pipeline-output.md`, linked from `SKILL.md` (Task 9). Implements the design spec's §2.1 scope-fork resolution for the API-serving conceptual layer.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`:

````markdown
# Serving Pipeline Output: The Delivery Decision

This file is architectural reasoning and design judgment, not a set of vendor-documented facts — treat it the way you'd treat the cold/warm-cache benchmarking guidance in `spark-data-engineering`: real engineering wisdom, not something cited verbatim from a single vendor's docs.

## The problem: your warehouse is the wrong tool for point lookups

Your analytical warehouse (Snowflake, BigQuery, Redshift) is columnar and OLAP: excellent at scanning millions of rows and aggregating, poor at the pattern an API needs — "give me customer 12345's record in 20 milliseconds." A low-latency, high-concurrency point lookup against an OLAP engine is slow and expensive, because you pay for bytes scanned on every request.

The fix is a **serving layer**, separate from the warehouse: the pipeline precomputes the result and materializes it into a store built for lookup-by-key — Postgres, DynamoDB, Redis, or Elasticsearch, depending on the access pattern — and whatever reads that data reads from there, not from the warehouse. The batch or streaming pipeline writes the serving store; nothing downstream reads the warehouse directly for low-latency access. This separates the compute plane (heavy, periodic) from the serving plane (light, always-on, low-latency) — the same control-plane/data-plane split from `orchestrator-selection-and-topology.md`, one layer further downstream.

## The freshness/latency trade-off

If you materialize the serving store on an hourly batch, reads are millisecond-fast but the data can be up to an hour stale. If a consumer needs sub-second freshness, the serving store needs to be updated by streaming — a topic feeding it directly — instead of batch. Name this trade-off explicitly and tie it to the actual business requirement; don't default to "real-time" as a starting assumption, since it's the expensive option.

## SLA and decoupling

A live-serving layer carries an availability/latency SLA that the batch pipeline feeding it does not. That's exactly why they're separated: if the pipeline fails, the serving layer keeps answering from the last good snapshot instead of going down with it. That decoupling is deliberate design, not an accident of architecture.

## When NOT to build an API — the strongest signal of maturity

If the consumer is another data process that needs the *whole* dataset, a paginated API is close to the worst mechanism available — slow, expensive, fragile. Better options: a **bulk export** to files (Parquet on S3), a **native warehouse share** (Snowflake data sharing, shared Iceberg tables), or a **Kafka stream**. An API earns its place for point lookups, low latency, and external or application consumers — for moving large datasets between data systems, it's almost never the right answer. Knowing when to say "an API is the wrong pattern here, let's use a share or export instead" is one of the strongest signals of seniority in this whole topic.

## What this file deliberately does not cover

Building or operating the API service itself — framework choice, REST vs. GraphQL vs. gRPC, endpoint implementation, request/response contracts, versioning, API-level auth — is out of scope for this skill and for the suite as a whole right now. It's general backend engineering, not something specific to data engineering, and there's no confirmed real use case driving it yet (see `docs/superpowers/specs/2026-07-30-pipelines-architecture-skill-design.md` §2.1 for the full reasoning). If you build one, everything above still applies to how it should be fed — the implementation itself just isn't taught here.

Hosting and infrastructure for a serving API, if one gets built, belongs in `iac-cloud-data-engineering` once that skill exists. Contract and schema versioning for that API belongs in `quality-data-engineering` once that skill exists. Neither has content yet.
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`
Expected: `5`.

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md
git commit -m "feat(pipelines-architecture): add serving pipeline output reference"
```

---

### Task 9: `SKILL.md` (`pipelines-architecture-data-engineering`)

**Files:**
- Create: `data-engineering-skills/skills/pipelines-architecture-data-engineering/SKILL.md`

**Interfaces:**
- Consumes: filenames and section content from Tasks 1-8, and `python-data-engineering/references/external-api-integration.md` (Task 10, cross-skill link).
- Produces: the skill's entry point, discoverable by name `pipelines-architecture-data-engineering`.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/pipelines-architecture-data-engineering/SKILL.md`:

````markdown
---
name: pipelines-architecture-data-engineering
description: Pipeline orchestration architecture and DAG design guidance — orchestrator choice (Airflow, Dagster, Prefect), DAG design and task granularity, structural idempotency and backfills, data-aware scheduling and cross-pipeline dependencies, deployment topology (scheduler HA, executors, managed vs self-hosted), and Airflow-specific patterns (trigger rules, branching, sensors, dynamic task mapping, TaskGroups, pools). Use when designing or reviewing a pipeline's orchestration layer, choosing an orchestrator, diagnosing a broken backfill or a DAG that skips or hangs unexpectedly, or deciding how a pipeline should serve its output downstream. Does not cover writing idempotent code inside a task (see python-data-engineering) or building/hosting an API service (see references/serving-pipeline-output.md).
---

# Pipeline Orchestration Architecture

## Overview

Senior-level judgment calls for the orchestration layer of a data pipeline — which pattern or orchestrator to reach for and why, not operator syntax. The orchestrator coordinates; it doesn't compute. Its value is dependency management, scheduling, retries, observability, and backfills — and all of that only works if tasks are idempotent, deterministic, and parameterized by their data window. Read the relevant file(s) before proposing a design or reviewing a DAG; don't rely on the table below alone.

## When to use

- Designing or reviewing a pipeline's DAG structure, task boundaries, or dependency graph
- Choosing an orchestrator (Airflow, Dagster, Prefect) or its deployment topology
- A backfill duplicated data, is stuck, or risks overwhelming a downstream system
- A DAG task skips unexpectedly, hangs, or a sensor is eating worker capacity
- Deciding how a pipeline should trigger downstream work, or how another pipeline should trigger off it
- Deciding how a pipeline's output should reach its consumers (API, stream, export, share)
- Not for writing the idempotent code inside a single task (see `python-data-engineering`) or building/hosting an API service (see [serving-pipeline-output.md](references/serving-pipeline-output.md))

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
| Consuming an external API for ingestion | Auth, pagination, backoff/jitter, watermark | [python-data-engineering](../python-data-engineering/references/external-api-integration.md) |

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Heavy transformation logic written inline in the DAG file | Couples orchestration to compute, makes the DAG slow to parse and impossible to test in isolation | Task invokes external compute (Spark job, dbt model); orchestrator only sequences it. See [orchestration-fundamentals.md](references/orchestration-fundamentals.md) |
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
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "](references/" data-engineering-skills/skills/pipelines-architecture-data-engineering/SKILL.md`
Expected: a number ≥ 20 (every quick-reference and common-mistakes row links into a reference file).

Run: `for f in data-engineering-skills/skills/pipelines-architecture-data-engineering/references/*.md; do grep -q "$(basename "$f")" data-engineering-skills/skills/pipelines-architecture-data-engineering/SKILL.md || echo "MISSING LINK: $f"; done`
Expected: no output (every one of the 8 reference files is linked from `SKILL.md`).

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/SKILL.md
git commit -m "feat(pipelines-architecture): add SKILL.md"
```

---

### Task 10: `python-data-engineering/references/external-api-integration.md`

**Files:**
- Create: `data-engineering-skills/skills/python-data-engineering/references/external-api-integration.md`

**Interfaces:**
- Consumes: the generator pattern from `iterators-and-generators.md`, the I/O-bound-vs-CPU-bound distinction from `concurrency-and-the-gil.md`, and the watermark pattern from `production-patterns.md` (all pre-existing files in `python-data-engineering`).
- Produces: the file `external-api-integration.md`, linked from `python-data-engineering/SKILL.md` (Task 11) and cross-referenced from `pipelines-architecture-data-engineering/SKILL.md` (Task 9, already written).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/python-data-engineering/references/external-api-integration.md`:

````markdown
# External API Integration: Consuming APIs for Ingestion

APIs are the most commonly underestimated ingestion source, because unlike a file in S3, there's a live, owned system on the other end — with quotas, latency, versions, and failures. The engineering here is in resilience and contract, not JSON parsing.

## HTTP fundamentals: acting on status code classes, not just codes

You're assumed to know HTTP methods and the broad status families — 2xx success, 3xx redirect, 4xx client error, 5xx server error (RFC 9110). The trap that separates levels isn't knowing the codes, it's **acting differently by class**: a 4xx (401 auth, 403 forbidden, 404 not found, 422 invalid payload, 429 rate limit) is almost always a *permanent* error that retrying won't fix — except 401 after a token expires, and 429. A 5xx (500, 502, 503, 504) is usually *transient* and worth retrying. RFC 9110 itself is explicit that retrying with fresh credentials is valid for a 401 (§15.5.2), and that 404 doesn't imply permanence the way some engineers assume — that's what 410 Gone is for.

One citation worth getting exactly right: **422** is commonly attributed to WebDAV (RFC 4918 §11.2, "422 Unprocessable Entity") — that's its historical origin, but RFC 9110 formally absorbed it as a general-purpose HTTP status code in §15.5.21, renaming it **"422 Unprocessable Content."** Cite RFC 9110 as the current normative source, RFC 4918 as the historical origin — both names circulate in practice.

```python
import requests

resp = requests.get(url, timeout=(3.05, 30))   # (connect, read) - ALWAYS set a timeout
resp.raise_for_status()                          # turns 4xx/5xx into an exception
data = resp.json()
```

The #1 error in ingestion code is a request **without a timeout**. `requests`' own docs warn about this directly: "Failure to do so can cause your program to hang indefinitely." Without one, a hung server freezes your task indefinitely and blocks the whole DAG behind it — this is the first thing to check in a code review.

## Authentication

The first thing that breaks an ingestion in production. Schemes, in order of complexity:

- **API key** (in an `Authorization` or `X-API-Key` header) — simple; the key lives in a secrets manager, never in code.
- **Static bearer token** — same, but the token can rotate.
- **OAuth2 client credentials** (RFC 6749 §4.4, the machine-to-machine flow you'll use most) — exchange `client_id` and `client_secret` for a short-lived access token, use that token on calls.

```python
import time

class TokenManager:
    def __init__(self, client_id, secret, token_url, refresh_margin_seconds=60):
        self._id, self._secret, self._url = client_id, secret, token_url
        self._margin = refresh_margin_seconds
        self._token, self._expires_at = None, 0

    def token(self):
        if self._token is None or time.time() > self._expires_at - self._margin:
            resp = requests.post(self._url, data={
                "grant_type": "client_credentials",
                "client_id": self._id, "client_secret": self._secret,
            }, timeout=10)
            resp.raise_for_status()
            body = resp.json()
            self._token = body["access_token"]
            self._expires_at = time.time() + body["expires_in"]
        return self._token
```

The senior detail is a **proactive refresh**: renew the token before it expires, don't wait to react to a 401. A margin before expiry avoids the race condition of sending a request with a token that expires mid-flight — but don't treat any specific number as a documented standard. No major OAuth2 provider's docs (Auth0, Okta) prescribe a fixed margin, and real client libraries land in different places — Google's own `google-auth-library-python`, for instance, uses `REFRESH_THRESHOLD = timedelta(minutes=3, seconds=45)`, not 60 seconds. Pick a margin that fits your token's actual `expires_in`, and make it configurable rather than hardcoding a number as if it were spec.

And the usual: credentials live in a secrets manager with rotation, never hardcoded or committed — the same red flag as hardcoded credentials anywhere else in a pipeline.

## Pagination

No serious API hands you millions of rows in one response. Three models, and picking the wrong one breaks ingestion silently:

- **Offset/limit** (`?offset=200&limit=100`) — simple, but risky: if rows are inserted while you paginate, you can skip or duplicate records, and it gets slow at large offsets because the database scans and discards rows before the offset. This isn't just theoretical — Shopify's own engineering team benchmarked it: **6.5ms at offset 10 vs. 2,221ms at offset 100,000**, on the same query shape.
- **Cursor/keyset** (`?after=<last_id>`) — the API hands you an opaque pointer to "where to continue." Stable against inserts, efficient at any depth. The model to prefer whenever the API offers it.
- **Page token** (`?page_token=...`) — a cursor variant, common on Google APIs.
- **Link header** (`Link: <...>; rel="next"`, per **RFC 8288**, "Web Linking" — RFC 8288 obsoletes the older RFC 5988, so cite 8288) — the API returns the next-page URL in the `Link` response header; follow `rel="next"` until it's absent. This is GitHub's documented pagination pattern.

```python
def paginate(session, url, params):
    while url:
        resp = session.get(url, params=params, timeout=30)
        resp.raise_for_status()
        body = resp.json()
        yield from body["items"]                  # emit row by row, constant memory
        url = body.get("next_cursor_url")         # None when exhausted
        params = None                              # the cursor already carries state
```

Prefer cursor/keyset whenever the API offers it; with offset, assume you can lose or duplicate rows and compensate with idempotent deduplication downstream. Paginate through a generator so you never materialize the whole dataset in memory — the same generator pattern from [iterators-and-generators.md](iterators-and-generators.md).

## Rate limiting and resilience

The highest concentration of senior signal in this whole topic, because it's where "works on my laptop" dies in production.

**429 and `Retry-After`.** An API limiting you to N requests per window returns **429 Too Many Requests** (RFC 6585 — a separate spec from RFC 9110, not folded into it). It's often, but not guaranteed, accompanied by a `Retry-After` header (RFC 9110) telling you how long to wait. The rule: respect the server's `Retry-After` when it's present, instead of inventing your own wait.

**Exponential backoff with jitter.** On transient errors (5xx, timeouts, 429), retry with growing delay — 1s, 2s, 4s, 8s — plus a random jitter component. Jitter matters and gets asked about directly: without it, a thousand clients that failed at the same moment retry in lockstep, hammering the API right as it's recovering. This is documented directly by AWS's own engineering team: ["Exponential Backoff And Jitter"](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/) (Marc Brooker, AWS Architecture Blog, 2015, updated 2023) — worth citing by name, though their concrete example is write contention on DynamoDB under optimistic concurrency control, not a generic retry storm; the mechanism generalizes to any retry-under-load scenario, which is exactly why AWS SDKs ship it as their default retry strategy.

```python
import time, random

TRANSIENT = {429, 500, 502, 503, 504}

def resilient_get(session, url, params=None, max_attempts=5):
    for attempt in range(max_attempts):
        try:
            resp = session.get(url, params=params, timeout=30)
            if resp.status_code in TRANSIENT:
                wait = int(resp.headers.get("Retry-After", 2 ** attempt))
                wait += random.uniform(0, 1)               # jitter
                if attempt == max_attempts - 1:
                    resp.raise_for_status()
                time.sleep(wait)
                continue
            resp.raise_for_status()                         # non-transient 4xx - fail now
            return resp
        except (requests.Timeout, requests.ConnectionError):
            if attempt == max_attempts - 1:
                raise
            time.sleep(2 ** attempt + random.uniform(0, 1))
```

**Circuit breaker.** After a run of consecutive failures (say, 20), stop hammering the API for a while instead of continuing to spend quota and time against something that's down — the standard circuit-breaker pattern (Fowler/Nygard). Naming it distinguishes someone who's operated ingestion at scale.

**Idempotency keys.** If a `POST` can be retried, send an idempotency key so the receiving server doesn't process the same request twice — the pattern Stripe's API documents directly for exactly this purpose.

Closing frame: assume every network call will eventually fail; the question isn't if, only when — and your code should treat that as the normal case, not the exceptional one. Backoff with jitter, respecting `Retry-After`, distinguishing transient from permanent, and a timeout, always.

## Incremental extraction: the watermark pattern, with a lookback margin

[production-patterns.md](production-patterns.md) already covers the watermark mechanism generally — persisting the last-seen value of a monotonic column and requesting only what's newer. Applied to APIs specifically, one refinement matters: don't request strictly `> watermark` — request `>= watermark - margin` (a few minutes earlier). Late-arriving data or clock skew between your system and the API's can otherwise leave gaps. The margin creates duplicates on purpose, deduplicated downstream with the `ROW_NUMBER` pattern from `sql-data-engineering`. Overlapping and deduplicating is safer than an exact cutoff that risks silently losing rows.

Two limits worth naming: incremental extraction captures changes, but many APIs don't expose deletions, so a periodic full-refresh reconciliation is still needed; and CDC/webhooks (see below) are the alternative to polling for watermarks in the first place.

## Concurrency for I/O-bound ingestion

Thousands of sequential API calls is unacceptably slow. Because ingestion is I/O-bound — the time is spent waiting on the network, not computing — this is exactly the case from [concurrency-and-the-gil.md](concurrency-and-the-gil.md) where threads or async help a lot and processes buy you nothing.

```python
import asyncio, aiohttp

async def fetch(session, url):
    async with session.get(url, timeout=aiohttp.ClientTimeout(total=30)) as resp:
        return await resp.json()

async def fetch_all(urls, limit=20):
    connector = aiohttp.TCPConnector(limit=limit)    # aiohttp's own concurrency cap
    async with aiohttp.ClientSession(connector=connector) as session:
        return await asyncio.gather(*(fetch(session, u) for u in urls))
```

Bound your concurrency — unlimited parallelism is as bad as none, because it saturates the API (cascading 429s) and your own memory. `aiohttp` documents `TCPConnector(limit=...)` as its own native way to cap concurrent connections; you'll also see `asyncio.Semaphore` used for the same purpose in real code — that's a general-purpose `asyncio` primitive from the standard library, not something `aiohttp` itself teaches, and it's useful when you need to bound concurrency around something other than a single `ClientSession` (a mixed set of calls, or rate-limiting logic that isn't purely connection-based). Either is valid; know which one you're actually reaching for and why. Reusing a single `Session`/`ClientSession` for connection pooling and keep-alive is the other cheap win worth calling out.

## Contract and observability

An external API changes without asking you. Validate the payload against a schema (Pydantic, `jsonschema`) at the ingestion boundary, so an upstream change fails loudly at one controlled point instead of silently corrupting tables three layers downstream. Land the raw payload as-is in a raw zone first, so you can reprocess if your parsing logic had a bug, and transform in a later layer — the same raw-then-transform split already used elsewhere in this pipeline.

Track metrics per run: rows ingested, latency, 429/5xx rate, quota consumed, watermark reached. Without this, a "successful" run that pulled 10 rows instead of the expected 10,000 looks identical to a real success. Tie alerts to those metrics and to SLAs.

## Push vs. pull: webhooks and bulk export

Polling — asking on a schedule — is simple but adds latency and wastes calls when nothing changed. **Webhooks** (the source calls you when something happens) give lower latency and less waste, but require exposing a receiver endpoint, handling the provider's own retries, deduplicating deliveries, and validating signatures. The deduplication requirement isn't optional: webhooks are typically **at-least-once** delivery. Stripe's own docs are explicit about this: "Webhook endpoints might occasionally receive the same event more than once... guard against duplicated event receipts by logging the event IDs." Design your receiver to be idempotent on the event ID from day one.

For large volumes, a third option often beats both: **bulk export** to a file (S3/GCS), usually cheaper and faster than paginating millions of rows over HTTP — several major APIs (Shopify's Bulk Operations, Salesforce's Bulk API among them) offer exactly this as the documented alternative to their paginated endpoints for large jobs.

Choose by pattern: polling for batch work that tolerates latency, webhooks/streaming for near-real-time, bulk export for moving a large dataset.
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/python-data-engineering/references/external-api-integration.md`
Expected: `8`.

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/python-data-engineering/references/external-api-integration.md
git commit -m "feat(python-data-engineering): add external API integration reference"
```

---

### Task 11: Update `python-data-engineering/SKILL.md`

**Files:**
- Modify: `data-engineering-skills/skills/python-data-engineering/SKILL.md`

**Interfaces:**
- Consumes: `external-api-integration.md` (Task 10).
- Produces: `SKILL.md`'s quick-reference and common-mistakes tables now cite the new file, satisfying the writing-great-skills requirement that every reference file be cited from the common-mistakes table.

- [ ] **Step 1: Add a quick-reference row**

In `data-engineering-skills/skills/python-data-engineering/SKILL.md`, find this row (the last row of the Quick reference table):

```markdown
| Pipeline testing, error handling, config, logging | — | [production-patterns.md](references/production-patterns.md) |
```

Replace it with (adds a new row immediately after):

```markdown
| Pipeline testing, error handling, config, logging | — | [production-patterns.md](references/production-patterns.md) |
| Calling an external API for ingestion (auth, pagination, rate limits) | Timeout + backoff/jitter + cursor pagination | [external-api-integration.md](references/external-api-integration.md) |
```

- [ ] **Step 2: Add common-mistakes rows**

In the same file, find this row (the last row of the Common mistakes table):

```markdown
| Optimizing before measuring | Fixes the wrong bottleneck | Profile first (`cProfile`, `memory_profiler`) — see [memory-and-performance.md](references/memory-and-performance.md) |
```

Replace it with (adds three new rows immediately after):

```markdown
| Optimizing before measuring | Fixes the wrong bottleneck | Profile first (`cProfile`, `memory_profiler`) — see [memory-and-performance.md](references/memory-and-performance.md) |
| Request to an external API without a timeout | Hangs the task indefinitely on a stalled server, blocking the whole DAG behind it | Always set `timeout=(connect, read)`; see [external-api-integration.md](references/external-api-integration.md) |
| Retrying a failed API call at a fixed interval | Synchronized retries from many clients create a thundering-herd spike right as the API recovers | Exponential backoff plus jitter; see [external-api-integration.md](references/external-api-integration.md) |
| Offset/limit pagination against a large, frequently-written API | Skips or duplicates rows as data shifts under the paging window, and gets slower at every page | Prefer cursor/keyset pagination when the API offers it; see [external-api-integration.md](references/external-api-integration.md) |
```

- [ ] **Step 3: Verify the file**

Run: `grep -c "external-api-integration.md" data-engineering-skills/skills/python-data-engineering/SKILL.md`
Expected: `4` (one quick-reference row + three common-mistakes rows).

- [ ] **Step 4: Commit**

```bash
git add data-engineering-skills/skills/python-data-engineering/SKILL.md
git commit -m "docs(python-data-engineering): link external API integration reference"
```

---

### Task 12: Review both skills against `writing-great-skills`

**Files:**
- Read only: all files created/modified in Tasks 1-11.

**Interfaces:**
- Consumes: the completed skill content from all prior tasks.

- [ ] **Step 1: Read the standard**

Read the `writing-great-skills` skill (via the Skill tool or its file in the plugin cache) to refresh the exact criteria before reviewing.

- [ ] **Step 2: Check both descriptions**

Confirm `pipelines-architecture-data-engineering/SKILL.md`'s `description` field leads with an identity clause ("Pipeline orchestration architecture and DAG design guidance — ...") rather than opening with "Use when...". Confirm `python-data-engineering/SKILL.md`'s existing description still accurately covers the skill after the addition (it does — "pipeline architecture" already includes API-consumption code, no change needed).

- [ ] **Step 3: Check common-mistakes coverage**

Run: `for f in data-engineering-skills/skills/pipelines-architecture-data-engineering/references/*.md; do grep -q "$(basename "$f")" data-engineering-skills/skills/pipelines-architecture-data-engineering/SKILL.md || echo "NOT CITED IN COMMON MISTAKES: $f"; done`
Expected: no output — confirms Task 9's common-mistakes table (not just quick-reference) cites every one of the 8 reference files. If any file is missing, add a row for it before proceeding.

- [ ] **Step 4: Check for duplication/sediment**

Skim all 9 new/modified files for redundant restatement of the same fact across files (e.g., the `Asset` rename should be taught once, in `scheduling-and-dependencies.md`, and referenced — not re-explained — elsewhere). Fix any found duplication by cutting the repeat and pointing to the canonical file instead.

- [ ] **Step 5: Commit any fixes**

```bash
git add -A
git commit -m "docs(pipelines-architecture,python-data-engineering): writing-great-skills self-review fixes"
```

(Skip this step if Steps 2-4 found nothing to fix.)

---

### Task 13: Validate both skills with fresh-agent scenarios

**Files:**
- None modified — validation only.

**Interfaces:**
- Consumes: the fully assembled `pipelines-architecture-data-engineering` and updated `python-data-engineering` skills.

- [ ] **Step 1: Symlink the skill for testing**

```bash
ln -sf "$(pwd)/data-engineering-skills/skills/pipelines-architecture-data-engineering" ~/.claude/skills/pipelines-architecture-data-engineering
```

Confirm `python-data-engineering`'s existing symlink already picks up the new reference file automatically (no new symlink needed there — it's the same skill directory).

- [ ] **Step 2: Run the join-after-branch + Asset-terminology scenario**

In a fresh Claude Code session (or fresh agent context), ask: *"I have an Airflow DAG that branches into `full_load` or `incremental_load` with `@task.branch`, then both branches feed into a `consolidate` task. The `consolidate` task keeps getting skipped even though one of the branches always succeeds. Also, how do I make a downstream DAG start only when this one's output table is actually ready, instead of just scheduling it an hour later?"*

Expected: the agent invokes `pipelines-architecture-data-engineering`, diagnoses the skip as the join-after-branch trigger-rule trap and prescribes `trigger_rule="none_failed_min_one_success"`, and answers the second part using **"Asset"** terminology (not "Dataset") for data-aware scheduling.

- [ ] **Step 3: Run the version-awareness scenario**

Ask: *"I want to get paged when my DAG misses its SLA — should I use `sla_miss_callback`?"*

Expected: the agent invokes `pipelines-architecture-data-engineering`, and does **not** answer with an unqualified "yes, use `sla_miss_callback`" — it asks or names the Airflow major version, explaining that `sla`/`sla_miss_callback` was removed in Airflow 3.0 in favor of the still-experimental Deadline Alerts, and that `sla_miss_callback` is only valid on 2.x.

- [ ] **Step 4: Run the API resilience scenario**

Ask: *"I'm writing a Python ingestion task that pages through a REST API with `?offset=`/`?limit=` and occasionally gets 429s. How should I handle that?"*

Expected: the agent invokes `python-data-engineering` (via `external-api-integration.md`), recommends switching to cursor/keyset pagination if the API supports it, and prescribes respecting `Retry-After` plus exponential backoff with jitter for the 429s — not a fixed retry interval, and not `asyncio.Semaphore` attributed to `aiohttp` as if `aiohttp` itself documents it.

---

### Task 14: Add "Testing a DAG" to `airflow-structure-and-reliability.md`

**Added 2026-07-30, after Task 10 shipped** — Leonardo asked whether `wshobson/agents`' `airflow-dag-patterns` skill was checked as a secondary source for this domain (per the suite spec's established per-skill process). It had only been excluded on the strength of the suite-wide spec's 2026-07-28 characterization, written before this skill's actual content existed — not re-checked against it. Re-checking now (fetched `SKILL.md` + `references/details.md` directly) found: most of its content already has an equivalent (often more rigorous) treatment in this skill's 8 shipped files, and its branching example independently corroborates the join-after-branch `trigger_rule` fix already in `airflow-trigger-rules-and-branching.md`. It also confirmed the exclusion decision was right for the reason already on record (Airflow-only, not orchestrator-agnostic, cheap-cheat-sheet style) — plus new evidence: it has zero Airflow 3.0 awareness and one internal inconsistency (a test asserts the deprecated `dag.schedule_interval` attribute while its own DAG definitions already use `schedule=`).

One real, undocumented gap surfaced: `wshobson`'s Pattern 6 (`test_dags.py`) covers testing a DAG via `DagBag` — a topic absent from every one of the 8 files shipped so far. Its specific code is NOT usable as-is (outdated 2.x import path, and a `dag.test_cycle()` method that doesn't exist in Airflow's current public API for user tests — confirmed by fetching Airflow's own current `best-practices.html` page and checking `apache/airflow`'s source directly, where `test_cycle` appears only inside Airflow's own internal test suite, never as a callable a user's test is meant to invoke). Verified, current-Airflow-3.x replacement content is below, sourced directly from Airflow's own "Testing a Dag" section of its Best Practices guide (fetched 2026-07-30) plus a source-code check of `task-sdk/src/airflow/sdk/definitions/dag.py` confirming `dag.test()` is real and current.

**Execute this task between Task 11 and Task 12** — Task 12 (writing-great-skills review) and Task 13 (discoverability validation) must see this addition already in place, since they assess the fully-assembled skill.

**Files:**
- Modify: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-structure-and-reliability.md`

**Interfaces:**
- Consumes: the "Dynamic DAG generation" section already in this file (Task 7) — the new section is inserted immediately after it, since DAG-factory output is exactly what structural DAG tests are for.
- Produces: an updated file with 7 `##` sections instead of 6; `SKILL.md`'s existing common-mistakes/quick-reference citations of this file remain valid (no rename), but Task 12's link-recount step must be re-run since the file changed after Task 9 shipped `SKILL.md`.

- [ ] **Step 1: Insert the new section**

In `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-structure-and-reliability.md`, find this text (the end of the "Dynamic DAG generation" section, immediately before the "Pools and reliability configuration" heading):

```markdown
When you have 50 nearly-identical pipelines (one ingestion per source table), you don't write 50 files — you write a template that generates DAGs from configuration (a YAML per source). This cuts duplication and makes maintenance uniform. The senior caveat: this generator code runs on *every* parse (see the antipattern below), so it must be lightweight and deterministic — Airflow's own Best Practices guide connects this exact point directly to the top-level-code warning.

## Pools and reliability configuration
```

Replace it with (inserts a new section between the two):

````markdown
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

One thing not to reach for: a `dag.test_cycle()` public method. It shows up in older community examples, but it isn't part of Airflow's current public API for user DAG tests — cycle-freedom is enforced by construction (a DAG is acyclic because you build it with `>>`/`<<`, not because you separately assert it), and Airflow's own current test-writing guidance doesn't feature a standalone cycle check at all.

## Pools and reliability configuration
````

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-structure-and-reliability.md`
Expected: `7` (was 6 before this task).

- [ ] **Step 3: Commit**

```bash
git add data-engineering-skills/skills/pipelines-architecture-data-engineering/references/airflow-structure-and-reliability.md
git commit -m "feat(pipelines-architecture): add DAG testing patterns to structure and reliability reference"
```

---

## Self-Review

**Spec coverage:** every section of `docs/superpowers/specs/2026-07-30-pipelines-architecture-skill-design.md` §4 maps to a task above — §4.1→Task 1, §4.2→Task 2, §4.3→Task 3, §4.4→Task 4, §4.5→Task 5, §4.6→Task 6, §4.7→Task 7, §4.8→Task 8, §4.9→Tasks 10-11. The SKILL.md tasks (9, 11) and the validation/review tasks (12, 13) are the implicit "close out the skill" steps every prior skill in this suite has used. No spec section lacks a task.

**Placeholder scan:** every task's Step 1 contains the full literal markdown content of the file it creates or the exact before/after text for a modification — no "TBD," no "add appropriate content," no "similar to Task N" shortcuts.

**Type/name consistency:** reference filenames match exactly across the design spec (§4), the File Structure section above, each task's own file, and both `SKILL.md` files' links — verified via Task 9 Step 2's and Task 12 Step 3's link-check commands. Cross-links between reference files (`orchestration-fundamentals`→none forward, `idempotency-and-backfills`→referenced by `airflow-structure-and-reliability`'s Pools section, `scheduling-and-dependencies`→`airflow-sensors-and-dynamic-mapping` for sensor detail, `orchestrator-selection-and-topology`→referenced by `serving-pipeline-output`'s control/data-plane framing, `external-api-integration.md`→`iterators-and-generators.md`/`concurrency-and-the-gil.md`/`production-patterns.md`) all resolve to filenames actually produced by this plan or already present in the repo.
