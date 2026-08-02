# Package Layout for Ingestion and Transformation

## The four-layer structure

For a package that extracts, transforms, and loads data (a scheduled batch job, an Airflow-triggered task, a Spark job), lay code out by what it does, not by technical type:

```
my_ingestion_package/
├── config/            # job identity: domain, subdomain, static parameters
│   └── __init__.py
├── extract/           # contract with the source(s): where data comes from, what shape it arrives in
│   └── __init__.py
├── transform/         # the package's actual business logic — the only layer genuinely unique to this job
│   └── __init__.py
├── load/              # where the transformed data goes, or a thin wrapper around a shared loader (see below)
│   └── __init__.py
└── my_ingestion_package.py   # entrypoint: wires the layers together, nothing else
tests/
├── test_extract.py
├── test_transform.py
└── test_load.py
```

Put `tests/` at the repo root, as a sibling of `my_ingestion_package/` — not nested inside the importable package — so pytest's `testpaths = ["tests"]` (see `packaging-and-tooling.md`) resolves it correctly from the project root. Mirror it to the source layout: one test file per module at minimum (`test_extract.py` for `extract/`), and a matching subdirectory once a layer itself splits into multiple files (`transform/business_rules.py` → `tests/transform/test_business_rules.py`) — not a single `tests/test_main.py` exercising everything through the entrypoint and nothing else.

**Why layer by responsibility, not by file type.** A `utils.py`/`helpers.py` file with unrelated functions is a magnet for unrelated growth, hard to test in isolation, and gives a reviewer no signal about what actually changed. `extract/`, `transform/`, and `load/` each answer one question — where does it come from, what do we do to it, where does it go — so a diff to `transform/` alone tells a reviewer exactly what changed about the job's behavior.

The entrypoint script should do one thing: call each layer in order, then commit/return. If the entrypoint contains business logic — a conditional based on data content, a calculation, a filter — that logic has leaked out of `transform/` and belongs back inside it.

## Where the orchestrator's DAG file lives

If the same repo also holds the orchestrator's DAG source file for this job (common in a monorepo that keeps ingestion code and its scheduling together), keep it in its own top-level directory, a sibling of the job package — not nested inside it:

```
my_ingestion_package/          # the job itself — see above
├── config/
├── extract/
├── transform/
├── load/
└── my_ingestion_package.py
airflow/
└── dags/
    └── my_ingestion_package_dag.py   # imports and schedules the job — no business logic
tests/
```

Two things worth being deliberate about:

- **The repo-level folder name is a CI/deployment convention, not something the orchestrator itself requires.** Airflow reads DAGs from whatever its own `dags_folder` is configured to (`[core] dags_folder` in `airflow.cfg`, or the `AIRFLOW__CORE__DAGS_FOLDER` environment variable — default `$AIRFLOW_HOME/dags`) — it has no opinion about what your source repo calls the directory your CI pipeline syncs from. `airflow/dags/` is a common, readable convention, not a hard requirement.
- **The DAG file itself should stay as thin as the job's own entrypoint.** It imports the job, wires task dependencies, and sets schedule/retries/alerting — the same "wiring only, no business logic" discipline as the entrypoint script above. If a DAG file starts branching on data content or doing real work inside a task callable, that logic belongs in the job package's `transform/`, not the DAG.

For the DAG's own internal design — task granularity, trigger rules, idempotent backfills, dynamic task mapping — as opposed to where its file lives, see `pipelines-architecture-data-engineering`.

## Pattern: thin job over a shared library

Extract/load mechanics repeat almost verbatim across many similar jobs on the same team: reading a specific source format, writing to a specific destination format, adding standard metadata columns. Duplicating that mechanics into every job package is how ten near-identical copies of loader code end up drifting out of sync.

Split it instead:

- **A separately versioned, shared library** owns the mechanics — how to read the source format, how to write to the destination format, cross-cutting concerns like metadata columns or logging setup. Ship it as its own package, pulled in as a pinned dependency (a git tag, or a private package index).
- **The job package** owns only what's actually unique to this job: its identity (domain, subdomain, table names), the shape of its specific source, and its transformation logic.

```python
# my_ingestion_package.py — the entrypoint stays this thin
from shared_etl_library.extract import Catalog, RawSource
from shared_etl_library.load import save_to_warehouse

from my_ingestion_package.config import build_job_config
from my_ingestion_package.transform import apply_business_rules


def main(job_config):
    source = RawSource(catalog=Catalog(job_config), config=job_config)
    raw_df = source.read()
    if raw_df.count() == 0:
        return  # nothing to process this run — a normal outcome, not an error
    final_df = apply_business_rules(raw_df, job_config)
    save_to_warehouse(final_df, job_config)
```

This only pays off once the same mechanics are reused by more than one or two jobs — for a single one-off job, the shared library is premature abstraction. Introduce it when a second or third job needs the same extract/load mechanics, not before.

## Pattern: Strategy for local/cloud parity

A job that only runs correctly inside its cloud runtime (a managed Spark context, a specific catalog service) is hard to iterate on — every check of real logic requires a deployment. Give the layer that talks to the environment two interchangeable implementations behind one shared contract, and pick between them once, at the entrypoint:

```python
from abc import ABC, abstractmethod


class CatalogReader(ABC):
    @abstractmethod
    def read_table(self, database: str, table: str):
        ...


class ProductionCatalog(CatalogReader):
    """Reads through the real managed catalog service."""

    def read_table(self, database: str, table: str):
        ...  # real cloud client call


class LocalDevCatalog(CatalogReader):
    """Reads the same tables through a local/dev-reachable path — real data, local execution."""

    def read_table(self, database: str, table: str):
        ...  # e.g. a local query engine against the same underlying storage


def build_catalog(is_local: bool) -> CatalogReader:
    return LocalDevCatalog() if is_local else ProductionCatalog()
```

The key property: both implementations satisfy the same contract, so nothing downstream of `catalog.read_table(...)` needs to know or care which one is active. This differs from mocking the catalog away in tests — `LocalDevCatalog` still talks to real data, just through a path a developer's machine can reach. Reserve mocks for the actual test suite; use this pattern so a human can run the job locally against real data while developing.

## The stale existence-check trap

If a layer checks "does this table already exist" more than once for the same table within a single job run, don't cache that answer for the rest of the process unless the cache is invalidated the instant this run creates or writes the table:

```python
from functools import cache

# risky: cached for the whole process — functools.cache keys on every argument (including catalog), and holds a strong reference to it for the process lifetime
@cache
def table_exists(catalog, database: str, table: str) -> bool:
    return catalog.exists(database, table)
```

If some other code path creates `database.table` later in the *same* run — a second loader writing to a table this one just created, or the same check called again after a write — this function keeps returning the stale "doesn't exist" answer, and whatever called it tries to create the table again. The bug is confusing to debug because the check looks correct in isolation; the problem is that its answer went stale mid-run. Track what this run itself has created, and let that override the cache:

```python
_created_this_run = set()

def table_exists(catalog, database: str, table: str) -> bool:
    if (database, table) in _created_this_run:
        return True
    return catalog.exists(database, table)

def mark_created(database: str, table: str) -> None:
    _created_this_run.add((database, table))
```

## Exposing this package's output via an API

If this package's transformed output needs to be served via an API rather than (or in addition to) landing in a warehouse table, first work through the architectural decision — is an API actually the right serving mechanism here, versus warehouse access, a stream, or a bulk export — in [pipelines-architecture-data-engineering's serving-pipeline-output.md](../../pipelines-architecture-data-engineering/references/serving-pipeline-output.md). That decision is orthogonal to this file.

Once the decision is "yes, build an API," structure the service itself with routers grouped by domain and dependency injection for shared resources (a database session, a catalog client) — see FastAPI's ["Bigger Applications - Multiple Files"](https://fastapi.tiangolo.com/tutorial/bigger-applications/) guide. This skill and the rest of the suite intentionally stop at that pointer: API implementation depth (endpoint versioning, auth schemes, REST vs. GraphQL vs. gRPC) is out of scope for the suite until there's a confirmed real use case building one.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| A `utils.py`/`helpers.py` grab-bag instead of `extract`/`transform`/`load` | Hard to test in isolation, no signal in a diff about what actually changed | Layer by responsibility — see above |
| Business logic living in the entrypoint script | Untestable without running the whole job; hidden from anyone reading `transform/` | Keep the entrypoint to wiring only; move logic into `transform/` |
| Copying extract/load mechanics into every new job package | Ten near-identical copies drift out of sync over time | Extract a shared, versioned library once a second job needs the same mechanics |
| Caching a table-existence check for the whole process | A table created earlier in the same run still reads as "doesn't exist," causing a duplicate-create attempt | Track what this run has created and let it override the cache |
