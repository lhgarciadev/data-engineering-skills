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
