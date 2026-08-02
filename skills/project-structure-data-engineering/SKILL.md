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
| Setting up linting and formatting | `ruff`, replacing flake8 + isort + black | [packaging-and-tooling.md](references/packaging-and-tooling.md) |
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
