# Project Structure Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the `project-structure-data-engineering` skill (`SKILL.md` + 3 reference files) for the `data-engineering-skills` repo, wire in cross-links from the skills it borders, and validate it with a fresh-agent discoverability scenario.

**Architecture:** Same shape as every other skill in the suite — a `SKILL.md` with overview/when-to-use/quick-reference/common-mistakes, and one reference file per heavy topic under `references/`. Content is generic structural guidance distilled from real private repos a colleague shared (never named or otherwise identified anywhere in this plan or its output — see Global Constraints), plus FastAPI's own public "Bigger Applications" guide (pointer only) and `wshobson/agents`' `python-development` skills (adapted with attribution).

**Tech Stack:** Markdown, git.

## Global Constraints

- Content in English; code examples in Python/TOML/YAML as appropriate (per `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §3).
- `SKILL.md` frontmatter limited to `name` + `description` — no Claude-specific fields (suite spec §2).
- Skill identifier is `project-structure-data-engineering` (matches folder name).
- **No real company name, repo name, branch name, person alias, cloud account ID, or internal URL from the two private source repos may appear anywhere in this plan or in the skill content it produces.** Every pattern is presented generically, using placeholder names (`my_ingestion_package`, `shared_etl_library`, etc.) — see design spec §3 and project memory `feedback_anonymize_third_party_examples`.
- FastAPI is referenced as a one-paragraph pointer only, inside `package-layout.md` — no endpoint implementation, versioning, auth, or REST/GraphQL/gRPC comparison content (design spec §2; the suite-wide criterion, set in `pipelines-architecture-data-engineering`'s design spec §2.1, is that API implementation stays out of scope until a confirmed real use case exists).
- `wshobson/agents` content (`python-project-structure`, `python-packaging`, `uv-package-manager`, `python-code-style`) is adapted with attribution, not copied verbatim (design spec §3).
- Does not cover: code-level patterns inside a single module (→ `python-data-engineering`), the architectural decision of whether/how to serve data via an API (→ `pipelines-architecture-data-engineering`), Terraform job-registry patterns (→ future `iac-cloud-data-engineering`), schema/dimensional modeling (→ future `modeling-data-engineering`).

---

## File Structure

**Create, in `data-engineering-skills/skills/project-structure-data-engineering/`:**
- `SKILL.md` — overview, when to use, quick reference table, common mistakes table.
- `references/package-layout.md` — the four-layer structure, thin-job-over-shared-library, Strategy for local/cloud parity, the stale existence-check trap, exposing output via an API (pointer only).
- `references/packaging-and-tooling.md` — Poetry vs uv, pinning Python to the deployment runtime, minimal `pyproject.toml`, private/shared dependencies, linting/formatting.
- `references/data-contracts.md` — the contract file, why it's worth it even mostly empty, what belongs here vs. elsewhere.

**Modify, elsewhere in the repo:**
- `skills/python-data-engineering/SKILL.md` — add one quick-reference row pointing to this new skill.
- `skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md` — add one pointer sentence back to this new skill.
- `skills/data-engineering/SKILL.md` — add `project-structure-data-engineering` to the orchestrator's domain list (frontmatter description, "When to use", and Process step 1's count).

Each reference file stands alone as its own task — a reviewer could approve `data-contracts.md` while rejecting `package-layout.md`. `SKILL.md` comes after all three, since its quick-reference table names all of them. Cross-link updates come after this skill exists, since they link into it. A `writing-great-skills` self-review and discoverability validation close out the plan.

---

### Task 1: `references/package-layout.md`

**Files:**
- Create: `data-engineering-skills/skills/project-structure-data-engineering/references/package-layout.md`

**Interfaces:**
- Produces: the file `package-layout.md`, linked from `SKILL.md` (Task 4).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/project-structure-data-engineering/references/package-layout.md`:

```markdown
# Package Layout for Ingestion and Transformation

## The four-layer structure

For a package that extracts, transforms, and loads data (a scheduled batch job, an Airflow-triggered task, a Spark job), lay code out by what it does, not by technical type:

\`\`\`
my_ingestion_package/
├── config/            # job identity: domain, subdomain, static parameters
│   └── __init__.py
├── extract/           # contract with the source(s): where data comes from, what shape it arrives in
│   └── __init__.py
├── transform/         # the package's actual business logic — the only layer genuinely unique to this job
│   └── __init__.py
├── load/               # where the transformed data goes, or a thin wrapper around a shared loader (see below)
│   └── __init__.py
├── my_ingestion_package.py   # entrypoint: wires the layers together, nothing else
└── tests/
    ├── test_extract.py
    ├── test_transform.py
    └── test_load.py
\`\`\`

Mirror `tests/` to the source layout 1:1. When `transform/business_rules.py` exists, `tests/test_business_rules.py` should exist next to it — not a single `tests/test_main.py` exercising everything through the entrypoint and nothing else.

**Why layer by responsibility, not by file type.** A `utils.py`/`helpers.py` file with unrelated functions is a magnet for unrelated growth, hard to test in isolation, and gives a reviewer no signal about what actually changed. `extract/`, `transform/`, and `load/` each answer one question — where does it come from, what do we do to it, where does it go — so a diff to `transform/` alone tells a reviewer exactly what changed about the job's behavior.

The entrypoint script should do one thing: call each layer in order, then commit/return. If the entrypoint contains business logic — a conditional based on data content, a calculation, a filter — that logic has leaked out of `transform/` and belongs back inside it.

## Pattern: thin job over a shared library

Extract/load mechanics repeat almost verbatim across many similar jobs on the same team: reading a specific source format, writing to a specific destination format, adding standard metadata columns. Duplicating that mechanics into every job package is how ten near-identical copies of loader code end up drifting out of sync.

Split it instead:

- **A separately versioned, shared library** owns the mechanics — how to read the source format, how to write to the destination format, cross-cutting concerns like metadata columns or logging setup. Ship it as its own package, pulled in as a pinned dependency (a git tag, or a private package index).
- **The job package** owns only what's actually unique to this job: its identity (domain, subdomain, table names), the shape of its specific source, and its transformation logic.

\`\`\`python
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
\`\`\`

This only pays off once the same mechanics are reused by more than one or two jobs — for a single one-off job, the shared library is premature abstraction. Introduce it when a second or third job needs the same extract/load mechanics, not before.

## Pattern: Strategy for local/cloud parity

A job that only runs correctly inside its cloud runtime (a managed Spark context, a specific catalog service) is hard to iterate on — every check of real logic requires a deployment. Give the layer that talks to the environment two interchangeable implementations behind one shared contract, and pick between them once, at the entrypoint:

\`\`\`python
from abc import ABC, abstractmethod


class Catalog(ABC):
    @abstractmethod
    def read_table(self, database: str, table: str):
        ...


class ProductionCatalog(Catalog):
    """Reads through the real managed catalog service."""

    def read_table(self, database: str, table: str):
        ...  # real cloud client call


class LocalDevCatalog(Catalog):
    """Reads the same tables through a local/dev-reachable path — real data, local execution."""

    def read_table(self, database: str, table: str):
        ...  # e.g. a local query engine against the same underlying storage


def build_catalog(is_local: bool) -> Catalog:
    return LocalDevCatalog() if is_local else ProductionCatalog()
\`\`\`

The key property: both implementations satisfy the same contract, so nothing downstream of `catalog.read_table(...)` needs to know or care which one is active. This differs from mocking the catalog away in tests — `LocalDevCatalog` still talks to real data, just through a path a developer's machine can reach. Reserve mocks for the actual test suite; use this pattern so a human can run the job locally against real data while developing.

## The stale existence-check trap

If a layer checks "does this table already exist" more than once for the same table within a single job run, don't cache that answer for the rest of the process unless the cache is invalidated the instant this run creates or writes the table:

\`\`\`python
from functools import cache

# risky: cached for the whole process, keyed only on (database, table)
@cache
def table_exists(catalog, database: str, table: str) -> bool:
    return catalog.exists(database, table)
\`\`\`

If some other code path creates `database.table` later in the *same* run — a second loader writing to a table this one just created, or the same check called again after a write — this function keeps returning the stale "doesn't exist" answer, and whatever called it tries to create the table again. The bug is confusing to debug because the check looks correct in isolation; the problem is that its answer went stale mid-run. Track what this run itself has created, and let that override the cache:

\`\`\`python
_created_this_run = set()

def table_exists(catalog, database: str, table: str) -> bool:
    if (database, table) in _created_this_run:
        return True
    return catalog.exists(database, table)

def mark_created(database: str, table: str) -> None:
    _created_this_run.add((database, table))
\`\`\`

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
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/project-structure-data-engineering/references/package-layout.md`
Expected: `6` (four-layer structure, thin-job-over-shared-library, Strategy pattern, stale existence-check trap, exposing via API, common mistakes).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/project-structure-data-engineering/references/package-layout.md
git commit -m "Add project-structure-data-engineering skill: package layout"
```

---

### Task 2: `references/packaging-and-tooling.md`

**Files:**
- Create: `data-engineering-skills/skills/project-structure-data-engineering/references/packaging-and-tooling.md`

**Interfaces:**
- Produces: the file `packaging-and-tooling.md`, linked from `SKILL.md` (Task 4).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/project-structure-data-engineering/references/packaging-and-tooling.md`:

```markdown
# Packaging and Tooling

## Poetry or uv — pick one, don't mix

Both solve the same core problem (dependency resolution, a lockfile, a virtual environment) through a single `pyproject.toml`. The practical difference that matters day to day:

- **Poetry** has been the default in most existing data engineering codebases for several years; if the team's other packages already use Poetry, matching that is worth more than a marginal speed gain.
- **uv** (Astral) is a from-scratch, Rust-based resolver and installer — meaningfully faster on install/resolve, and adds Python-version management (`uv python install`) and project scaffolding (`uv init`) that Poetry doesn't attempt. Worth adopting for new packages when there's no existing Poetry convention to match.

Whichever is chosen, commit to it for the whole package: a repo with both a `poetry.lock` and a `uv.lock`, or commands from both tools in different scripts, creates two sources of truth for resolved dependency versions — CI might install one, a teammate's machine the other, and they silently drift apart.

\`\`\`bash
# uv — common commands
uv init .                    # scaffold pyproject.toml in the current directory
uv add requests              # add a runtime dependency, updates pyproject.toml + uv.lock
uv add --dev pytest ruff     # add a dev-only dependency group
uv sync                      # install exactly what the lockfile specifies
uv run pytest                # run a command inside the project's environment, no manual activation
\`\`\`

*(Adapted from `wshobson/agents`'s `uv-package-manager` and `python-project-structure` skills, MIT-licensed — commands verified directly against uv's own documented behavior.)*

## Pin Python to the exact deployment runtime, not a floor

`requires-python = ">=3.10"` says "3.10 or newer" — correct for a library meant to run anywhere, wrong for a package meant to run inside one specific managed runtime (a serverless ETL runtime, a specific container base image) that only ships one Python version. If the target runtime is Python 3.10.x specifically, pin the ceiling too:

\`\`\`toml
[project]
requires-python = ">=3.10,<3.11"
\`\`\`

This turns a runtime mismatch (code written against 3.11-only syntax, deployed to a 3.10 runtime) into a local `pip install`/`uv sync` failure instead of a cryptic failure after deployment. Check the target runtime's documented Python version whenever it's upgraded — a pin that's never revisited becomes a silent blocker to adopting a newer runtime later.

## Minimal `pyproject.toml` shape

\`\`\`toml
[project]
name = "my-ingestion-package"
version = "0.1.0"
description = "Short, real description — not left as a placeholder"
requires-python = ">=3.10,<3.11"
dependencies = [
    "boto3",
]

[dependency-groups]
dev = ["ruff", "pytest"]
test = ["pytest", "pytest-cov", "moto"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.coverage.run]
source = ["my_ingestion_package"]   # list every package this repo ships — see Common Mistakes below
omit = ["*/tests/*"]
\`\`\`

If the repo ships more than one package (a transform job and a separate report/export job, for example), list all of them in `[tool.coverage.run] source` — a `source` list copied from a single-package template and never revisited after a second package is added is a real, observed way coverage silently stops meaning anything for that second package.

## Private or shared dependencies

A shared library used by more than one job package (see `package-layout.md`'s "thin job over a shared library" pattern) is usually not published to a public index. Pin it by tag, not by branch, so a job's dependency doesn't shift underneath it when the shared library changes:

\`\`\`toml
[tool.uv.sources]
shared-etl-library = { git = "https://github.com/your-org/shared-etl-library", tag = "v1.2.0" }
\`\`\`

Bump the tag deliberately, as its own commit, when the job is ready to take a new version of the shared library — not implicitly by tracking a branch.

## Linting and formatting

`ruff` covers linting and formatting in one fast tool, replacing the older flake8 + isort + black combination:

\`\`\`toml
[tool.ruff]
line-length = 120
target-version = "py310"   # match requires-python above

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "UP"]
\`\`\`

*(Adapted from `wshobson/agents`'s `python-code-style` skill, MIT-licensed.)*

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Committing both a `poetry.lock` and a `uv.lock` in the same package | Two sources of truth for resolved versions; CI and a teammate's machine can silently drift apart | Pick one tool for the whole package and remove the other lockfile |
| `requires-python = ">=3.10"` for a package meant to run on one specific 3.10.x runtime | Code can pass locally on 3.11+ syntax and fail only after deployment | Pin the ceiling too: `>=3.10,<3.11`, matching the actual runtime |
| `[tool.coverage.run] source` listing only one package when the repo ships several | A whole second package becomes invisible to the coverage report, with no error | List every package the repo ships; re-check this when a package is added |
| Pinning a shared private dependency to a branch instead of a tag | The dependency can change under a job without a corresponding commit in that job's history | Pin by tag; bump it deliberately as its own commit |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/project-structure-data-engineering/references/packaging-and-tooling.md`
Expected: `6` (Poetry-or-uv, pin Python, minimal pyproject.toml, private/shared dependencies, linting/formatting, common mistakes).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/project-structure-data-engineering/references/packaging-and-tooling.md
git commit -m "Add project-structure-data-engineering skill: packaging and tooling"
```

---

### Task 3: `references/data-contracts.md`

**Files:**
- Create: `data-engineering-skills/skills/project-structure-data-engineering/references/data-contracts.md`

**Interfaces:**
- Produces: the file `data-contracts.md`, linked from `SKILL.md` (Task 4).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/project-structure-data-engineering/references/data-contracts.md`:

```markdown
# Data Contracts

## A minimal contract file, versioned with the code

A data contract is a small, structured file that states what a data product is, who owns it, and who/what depends on it — living in the same repo and the same pull requests as the code that produces the data, instead of in a wiki that drifts out of sync the first time nobody remembers to update it.

\`\`\`yaml
# datacontract/my_ingestion_package.yaml
service_id: my_ingestion_package
version: "1.0"
governance:
  product_name: "Human-readable name of what this produces"
  domain: sales
  subdomain: orders
  consumers: []              # who reads this output — fill in as they're onboarded
  expected_inputs: []        # upstream sources this depends on
  expected_outputs: []       # tables/topics/files this produces
data_models: []               # schema references, once they're stable enough to pin
\`\`\`

## Why it's worth it even mostly empty

A contract that starts with most fields as empty lists is still worth creating, for two reasons: the file's existence is itself a commitment ("this data product has an owner and a documented shape, ask here first"), and it gives every future addition — a new consumer, a new upstream dependency — an obvious place to land instead of a wiki page nobody remembers exists.

**The failure mode to avoid**: a contract file created once and never revisited. An empty `consumers: []` six months after three teams started depending on this data product is worse than not having the file — it actively tells a reader "nobody consumes this" when the opposite is true. Update it in the same pull request that adds a consumer or a new upstream dependency, the same discipline as updating a test alongside the code it covers.

## What belongs here vs. elsewhere

- **Ownership and dependency metadata** (this file): who owns it, who consumes it, what it depends on.
- **The actual schema** (in code, not here): keep column-level types and descriptions next to the transformation code that produces them — see `package-layout.md`. Reference the schema from the contract once it's stable, don't duplicate it field-by-field in YAML.
- **The architectural decision of how this data is served** (warehouse table, API, stream, export): [pipelines-architecture-data-engineering's serving-pipeline-output.md](../../pipelines-architecture-data-engineering/references/serving-pipeline-output.md), not this file.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Creating the contract file once and never updating it | An empty `consumers: []` months after three teams depend on the data actively misleads a reader | Update it in the same PR that adds a consumer or upstream dependency |
| Duplicating the full column schema inside the contract YAML | Two places to keep in sync; they drift the first time one is updated without the other | Keep the schema in code, reference it from the contract once stable |
| Treating the contract as a substitute for the serving-layer decision | The contract records *what* the data is, not *how* it should be delivered | See `pipelines-architecture-data-engineering`'s `serving-pipeline-output.md` for that decision |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/project-structure-data-engineering/references/data-contracts.md`
Expected: `4` (minimal contract file, why it's worth it, what belongs here vs. elsewhere, common mistakes).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/project-structure-data-engineering/references/data-contracts.md
git commit -m "Add project-structure-data-engineering skill: data contracts"
```

---

### Task 4: `SKILL.md`

**Files:**
- Create: `data-engineering-skills/skills/project-structure-data-engineering/SKILL.md`

**Interfaces:**
- Consumes: the exact filenames of all 3 reference files from Tasks 1-3.
- Produces: `skills/project-structure-data-engineering/SKILL.md` — completes the skill, what Tasks 6-7 review and validate.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/project-structure-data-engineering/SKILL.md`:

```markdown
---
name: project-structure-data-engineering
description: Project and package structure guidance for data engineering — how to lay out a new ingestion/transformation package, choose and configure a packaging tool, and version a data contract alongside the code. Use when starting a new data pipeline package, reorganizing one that's grown unclear, choosing between Poetry and uv, fixing a pyproject.toml that doesn't match the deployment runtime, or deciding what belongs in a data contract file. Not for code-level patterns inside a single module — generators, decorators, OOP, testing (see python-data-engineering) — or the architectural decision of whether to serve data via an API (see pipelines-architecture-data-engineering).
---

# Project Structure for Data Engineering

## Overview

How to lay out a new data engineering package — from its directory structure to its packaging — and where to draw the line before this turns into implementing an API service. Each reference file pairs a structural pattern with the failure mode it exists to prevent. Read the relevant file before scaffolding a new package or reorganizing an existing one; don't rely on the table below alone.

## When to use

- Starting a new ingestion/transformation package from scratch
- Reorganizing an existing pipeline package that's grown unclear
- Choosing between Poetry and uv, or fixing a `pyproject.toml` that doesn't match the deployment runtime
- Deciding what belongs in a data contract file, or whether to add one
- A package needs to expose its output via an API and you need to know where that decision and structure live
- Not for code-level patterns inside a single module (generators, decorators, OOP, testing) — see `python-data-engineering`
- Not for the architectural decision of whether to build an API at all, or how to serve output more generally — see `pipelines-architecture-data-engineering`

## Quick reference

| Concern | Reach for | Reference |
|---|---|---|
| Laying out a new ingestion/transformation package | `config`/`extract`/`transform`/`load` layers, tests mirrored 1:1 | [package-layout.md](references/package-layout.md) |
| Reusing ETL mechanics across many similar jobs | A thin job package over a shared, versioned library | [package-layout.md](references/package-layout.md) |
| Running the same job against production and a local/dev environment | Strategy pattern behind one entrypoint switch | [package-layout.md](references/package-layout.md) |
| A table-existence check returns a stale answer mid-run | Don't cache it for the whole process — track what this run created | [package-layout.md](references/package-layout.md) |
| Exposing this package's output via an API | Router-per-domain FastAPI structure (pointer only — see `pipelines-architecture-data-engineering` for the decision itself) | [package-layout.md](references/package-layout.md) |
| Choosing a packaging tool | Poetry or uv — pick one, don't mix | [packaging-and-tooling.md](references/packaging-and-tooling.md) |
| Pinning the Python version | Match the exact deployment runtime, not just a floor | [packaging-and-tooling.md](references/packaging-and-tooling.md) |
| A repo ships more than one package | List every package in `[tool.coverage.run] source` | [packaging-and-tooling.md](references/packaging-and-tooling.md) |
| Depending on a shared internal library | Pin by git tag, bump deliberately | [packaging-and-tooling.md](references/packaging-and-tooling.md) |
| Documenting what a data product actually contains | A minimal data contract YAML, versioned with the code | [data-contracts.md](references/data-contracts.md) |

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| A `utils.py`/`helpers.py` grab-bag instead of `extract`/`transform`/`load` | Hard to test in isolation, no signal in a diff about what actually changed | Layer by responsibility; see [package-layout.md](references/package-layout.md) |
| Caching a table-existence check for the whole process | A table created earlier in the same run still reads as "doesn't exist," causing a duplicate-create attempt | Track what this run has created and let it override the cache; see [package-layout.md](references/package-layout.md) |
| Committing both a `poetry.lock` and a `uv.lock` in the same package | Two sources of truth for resolved versions, silently drifting apart | Pick one tool for the whole package; see [packaging-and-tooling.md](references/packaging-and-tooling.md) |
| `requires-python = ">=3.10"` for a package meant to run on one specific 3.10.x runtime | Passes locally on newer syntax, fails only after deployment | Pin the ceiling to match the actual runtime; see [packaging-and-tooling.md](references/packaging-and-tooling.md) |
| `[tool.coverage.run] source` listing only one package when the repo ships several | A whole second package becomes invisible to coverage, with no error | List every package the repo ships; see [packaging-and-tooling.md](references/packaging-and-tooling.md) |
| A data contract file left with every field empty indefinitely | Looks documented but carries no information — actively misleading once real consumers exist | Update it in the same PR that adds a consumer or dependency; see [data-contracts.md](references/data-contracts.md) |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "](references/" data-engineering-skills/skills/project-structure-data-engineering/SKILL.md`
Expected: `16` (10 quick-reference rows + 6 common-mistakes rows, every one links into a reference file).

Run: `for f in data-engineering-skills/skills/project-structure-data-engineering/references/*.md; do grep -q "$(basename "$f")" data-engineering-skills/skills/project-structure-data-engineering/SKILL.md || echo "MISSING LINK: $f"; done`
Expected: no output (all 3 reference files are linked from `SKILL.md`).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/project-structure-data-engineering/SKILL.md
git commit -m "Add project-structure-data-engineering skill: SKILL.md"
```

---

### Task 5: Cross-link from bordering skills

**Files:**
- Modify: `data-engineering-skills/skills/python-data-engineering/SKILL.md`
- Modify: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`
- Modify: `data-engineering-skills/skills/data-engineering/SKILL.md`

**Interfaces:**
- Consumes: `skills/project-structure-data-engineering/` (Tasks 1-4) must already exist — these edits link into it.

- [ ] **Step 1: Add a quick-reference row to `python-data-engineering/SKILL.md`**

In `data-engineering-skills/skills/python-data-engineering/SKILL.md`, find this line (the last row of the Quick reference table):

```
| Calling an external API for ingestion (auth, pagination, rate limits) | Timeout + backoff/jitter + cursor pagination | [external-api-integration.md](references/external-api-integration.md) |
```

Replace it with:

```
| Calling an external API for ingestion (auth, pagination, rate limits) | Timeout + backoff/jitter + cursor pagination | [external-api-integration.md](references/external-api-integration.md) |
| Laying out a new pipeline package's directory, or choosing Poetry vs `uv` | `config`/`extract`/`transform`/`load` layering, packaging conventions | [project-structure-data-engineering](../../project-structure-data-engineering/references/package-layout.md) |
```

- [ ] **Step 2: Add a pointer sentence to `serving-pipeline-output.md`**

In `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`, find this line (the last line of the file):

```
Hosting and infrastructure for a serving API, if one gets built, belongs in `iac-cloud-data-engineering` once that skill exists. Contract and schema versioning for that API belongs in `quality-data-engineering` once that skill exists. Neither has content yet.
```

Replace it with:

```
Hosting and infrastructure for a serving API, if one gets built, belongs in `iac-cloud-data-engineering` once that skill exists. Contract and schema versioning for that API belongs in `quality-data-engineering` once that skill exists. Neither has content yet.

For how to structure the package itself once this decision is made — directory layout, packaging, where a data contract lives — see `project-structure-data-engineering`.
```

- [ ] **Step 3: Add the skill to the orchestrator's domain list**

In `data-engineering-skills/skills/data-engineering/SKILL.md`, find this frontmatter description line:

```
description: Cross-domain router for data engineering tasks that span more than one domain — designing or reviewing an end-to-end pipeline, evaluating a full data platform, or any request that touches two or more of python-data-engineering, sql-data-engineering, spark-data-engineering, modeling-data-engineering, pipelines-architecture-data-engineering, streaming-data-engineering, quality-data-engineering, or iac-cloud-data-engineering at once. For a single-domain task (e.g. "review this PySpark job", "optimize this SQL query"), use that domain's skill directly instead — this orchestrator adds no value there.
```

Replace it with:

```
description: Cross-domain router for data engineering tasks that span more than one domain — designing or reviewing an end-to-end pipeline, evaluating a full data platform, or any request that touches two or more of python-data-engineering, sql-data-engineering, spark-data-engineering, modeling-data-engineering, pipelines-architecture-data-engineering, streaming-data-engineering, quality-data-engineering, iac-cloud-data-engineering, or project-structure-data-engineering at once. For a single-domain task (e.g. "review this PySpark job", "optimize this SQL query"), use that domain's skill directly instead — this orchestrator adds no value there.
```

Then find this "When to use" bullet:

```
- Not for single-domain tasks — let that domain's own skill trigger directly (`python-data-engineering`, `sql-data-engineering`, `spark-data-engineering`, `modeling-data-engineering`, `pipelines-architecture-data-engineering`, `streaming-data-engineering`, `quality-data-engineering`, `iac-cloud-data-engineering`)
```

Replace it with:

```
- Not for single-domain tasks — let that domain's own skill trigger directly (`python-data-engineering`, `sql-data-engineering`, `spark-data-engineering`, `modeling-data-engineering`, `pipelines-architecture-data-engineering`, `streaming-data-engineering`, `quality-data-engineering`, `iac-cloud-data-engineering`, `project-structure-data-engineering`)
```

Then find this line in the Process section:

```
1. **Identify relevant domains.** Read the request and list which of the 8 domain skills apply. If only one applies, stop and use that skill directly instead of continuing here.
```

Replace it with:

```
1. **Identify relevant domains.** Read the request and list which of the 9 domain skills apply. If only one applies, stop and use that skill directly instead of continuing here.
```

- [ ] **Step 4: Verify the edits**

Run: `grep -c "project-structure-data-engineering" data-engineering-skills/skills/data-engineering/SKILL.md`
Expected: `3` (frontmatter description, "When to use" bullet, and no direct mention needed in Process beyond the count — if this returns `2`, the frontmatter or bullet edit was missed; check both).

Run: `grep -c "project-structure-data-engineering" data-engineering-skills/skills/python-data-engineering/SKILL.md data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`
Expected: `1` for each file.

- [ ] **Step 5: Commit**

```bash
cd data-engineering-skills
git add skills/python-data-engineering/SKILL.md skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md skills/data-engineering/SKILL.md
git commit -m "Cross-link project-structure-data-engineering from bordering skills"
```

---

### Task 6: `writing-great-skills` self-review

**Files:**
- Modify: any file under `data-engineering-skills/skills/project-structure-data-engineering/`, only if the review finds an issue.

**Interfaces:**
- Consumes: the completed skill from Tasks 1-4.

- [ ] **Step 1: Run the review**

Invoke the `writing-great-skills` skill (if installed) against `data-engineering-skills/skills/project-structure-data-engineering/`. At minimum, check:
- `SKILL.md`'s `description` leads with an identity clause ("Project and package structure guidance for data engineering — ...") rather than starting with "Use when...".
- Every reference file (`package-layout.md`, `packaging-and-tooling.md`, `data-contracts.md`) is cited from at least one row of `SKILL.md`'s quick-reference or common-mistakes table (Task 4's Step 2 already checks this mechanically — this step is the qualitative read).
- No content is duplicated across the 3 reference files, or duplicated with content that already lives in `python-data-engineering/references/production-patterns.md` or `pipelines-architecture-data-engineering/references/serving-pipeline-output.md`.
- No placeholder text ("TBD", "TODO", etc.) anywhere in the 4 files.

- [ ] **Step 2: Fix any issues found**

Edit the affected file(s) directly.

- [ ] **Step 3: Commit fixes, if any**

```bash
cd data-engineering-skills
git add skills/project-structure-data-engineering/
git commit -m "Fix project-structure-data-engineering: writing-great-skills self-review"
```

Skip this step entirely if Step 1 found nothing to fix — don't create an empty commit.

---

### Task 7: Validate the `project-structure-data-engineering` skill

**Owner:** Claude, using the `Agent` tool to run a fresh-context discoverability scenario (same method used to validate `python-data-engineering`, `sql-data-engineering`, and the `data-engineering` orchestrator).

**Interfaces:**
- Consumes: `skills/project-structure-data-engineering/` (Tasks 1-6), symlinked into a live Claude Code environment so a fresh agent can discover it.

- [ ] **Step 1: Symlink the skill for testing**

```bash
ln -sf "$(pwd)/data-engineering-skills/skills/project-structure-data-engineering" ~/.claude/skills/project-structure-data-engineering
```

- [ ] **Step 2: Run the discoverability scenario**

Dispatch a fresh `general-purpose` agent with this prompt:

> "You have a list of available skills — check it. Then answer: 'I'm starting a new Python package that pulls data from an external API daily and writes it to a warehouse table. How should I lay out the repo, and should I use Poetry or uv?' After answering, report which skill(s) you invoked."

Expected: the agent invokes `project-structure-data-engineering`, recommends a `config`/`extract`/`transform`/`load` layered structure with tests mirrored 1:1, and gives a clear Poetry-vs-uv recommendation (not a non-committal "either works").

- [ ] **Step 3: Record the result**

If the scenario fails (skill doesn't fire, or the answer is vague/wrong), fix the relevant wording in `SKILL.md`'s description or quick-reference table, and re-run this step only.

---

## Self-Review Notes

- **Spec coverage**: Task 1 ↔ design spec §4.1; Task 2 ↔ §4.2; Task 3 ↔ §4.3; Task 4 ties them together per §4's file-structure diagram, and includes the exposition pointer from §4.4 (embedded in Task 1's content) and the common-mistakes items from §4.5; Task 5 ↔ the cross-link obligations implied by spec §2's "cross-link, don't duplicate" boundaries; Task 6 mirrors the `writing-great-skills` self-review step used in prior skill rounds (project memory `project_suite_status`); Task 7 mirrors the discoverability validation already run for `python-data-engineering`, `sql-data-engineering`, and the orchestrator.
- **No placeholders**: every task's Step 1 is the actual final file content (English, anonymized per Global Constraints), not a description of what to write.
- **Type/name consistency**: the three reference filenames (`package-layout.md`, `packaging-and-tooling.md`, `data-contracts.md`) are identical across Tasks 1-4's Interfaces sections and SKILL.md's links. The placeholder package name `my_ingestion_package` and shared-library name `shared_etl_library` are used consistently across Task 1 and Task 2's code examples.
- **Confidentiality check**: re-read against Global Constraints' anonymization rule — no company name, repo name, branch name, person alias, cloud account ID, or internal URL appears anywhere in this plan.
