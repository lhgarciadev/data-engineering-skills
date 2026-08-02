# dbt Project Architecture

## Two DAGs, not one

dbt builds its own dependency graph from `ref()` and `source()` calls in your models — a model that does `select * from {{ ref('stg_orders') }}` creates an edge in dbt's internal DAG, and `dbt run`/`dbt build` executes models in that resolved order. This DAG is separate from, and nested inside, whatever pipeline orchestrator (Airflow, Dagster, Prefect) invokes it: from the orchestrator's perspective, `dbt build` is usually one task (or a handful of tasks split by selector — see below), and everything happening between the models is invisible to it. Don't try to replicate dbt's model dependencies as separate orchestrator tasks — that duplicates a graph dbt already resolves for you and doubles the places a dependency can go stale.

`ref()` also has a second job beyond dependency tracking: it interpolates the target schema/database into the compiled SQL, so the same model compiles to different fully-qualified names in dev vs. prod without editing the model itself. A model with a hardcoded `FROM schema.table` instead of `{{ ref('table') }}` breaks both — dbt can't see the dependency, and the query can't follow you between environments.

## Project structure

Every dbt project needs a `dbt_project.yml` — it's how dbt recognizes a directory as a dbt project. Of its fields, only `name` is unconditionally required; `profile` is required for local/CLI use but doesn't apply inside dbt Cloud; `version`/`config-version` have been optional since dbt 1.5.

Standard folders, each with a purpose dbt enforces or assumes by convention:

- **`models/`** — your `.sql`/`.py` models, sources, and tests.
- **`seeds/`** — small, versioned CSVs dbt loads as tables (`dbt seed`) — mapping tables, not a data-loading mechanism. dbt's own docs are explicit that seeds are the wrong tool for loading source-system data: "dbt is designed to operate on data in the warehouse, not as a data-loading tool." Use a real EL/ingestion tool for that instead.
- **`snapshots/`** — Type-2 SCD capture over mutable source tables. Cannot share a folder with `models/`.
- **`macros/`** — reusable Jinja, dbt's equivalent of functions. Also cannot share a folder with `models/`.
- **`tests/`** — singular tests (a `.sql` file whose query returns failing rows) and generic tests (parameterized, referenced by name in YAML — the four built-ins are `unique`, `not_null`, `accepted_values`, `relationships`).
- **`analyses/`** — versioned SQL that compiles but never runs or materializes; for ad hoc analysis you still want under version control, not for anything downstream depends on.

## The layering convention — and why it isn't "medallion"

dbt Labs' own published guidance ("How we structure our dbt projects") organizes `models/` into three layers: **staging**, **intermediate**, **marts**. This is dbt's real, documented vocabulary — not an approximation:

- **Staging** — one model per source table (`stg_[source]__[entity]s.sql`), 1:1 with the source, renaming/light casting only. No joins, no aggregation. Materialize as `view`.
- **Intermediate** — joins, pivots, grain changes, and other business logic that would clutter a mart if left inline. Organized by business area, not by source system. Not meant to be queried directly by end users.
- **Marts** — the consumption layer, named by entity in plain business language (`customers`, `orders`), organized by department once there are enough of them to need subfolders.

**"Medallion" (bronze/silver/gold) is not dbt's vocabulary.** It's a Databricks/lakehouse term some teams map onto dbt's three layers by analogy — reasonable, but don't present it as dbt's own terminology or cite it as if dbt Labs uses it; their published guidance uses staging/intermediate/marts exclusively. If your team already thinks in medallion terms (coming from a lakehouse background), the mapping is roughly bronze≈staging, silver≈intermediate, gold≈marts — but say explicitly that's a bridge you're drawing, not what dbt calls it.

dbt Labs is also explicit that this guidance is a starting point, not mandatory syntax: "the important thing is not to follow this style guide; it's to make your style guide and follow it." Treat staging/intermediate/marts as the strong default, not a rule dbt enforces.

## Materialization: three places to configure it, least to most specific

1. **`dbt_project.yml`**, per folder, using the `+` prefix — sets a default for everything under that path (e.g. all of `staging/` materializes as `view`).
2. **A model's `.yml` properties file**, under `config:`.
3. **`{{ config(materialized='table') }}`** inside the model's own `.sql` — the most specific, wins over the other two.

Default with nothing configured is `view`. The valid types are `view`, `table`, `incremental`, `ephemeral`, and `materialized_view` — with real per-warehouse gaps worth knowing (Snowflake doesn't support `materialized_view`, it has Dynamic Tables instead; Python models can only be `table` or `incremental`, never `view`/`ephemeral`). The mechanics of `incremental` itself — `unique_key`, merge vs. delete+insert strategy by adapter, `--full-refresh` — are SQL-level concerns covered in `sql-data-engineering`, not repeated here.

## Environments: two files, split for a reason

`dbt_project.yml` lives in the repo, version-controlled. `profiles.yml` lives outside it — `~/.dbt/profiles.yml` by default — specifically so credentials never enter version control. A profile defines one or more **targets** (commonly `dev`/`prod`), and `--target` picks which one a run uses; the target's properties (`target.name`, `target.schema`, `target.type`) are available inside models via Jinja.

Two gotchas worth knowing before you hit them: there is no `DBT_TARGET` environment variable — switching targets is a CLI flag (`--target`) in dbt Core, not an env var, so don't design a deploy script around one that doesn't exist. And dbt Cloud has its own, separate environment model (Development/Deployment environments configured in the platform UI) that reuses the word "profile" for a different, platform-managed concept — don't assume `profiles.yml`/`--target` documentation applies there.

## Selecting a subset of the DAG — and what it means for orchestration granularity

`dbt run --select` (and `dbt build --select`) can target a model, its ancestors, its descendants, or both: `+my_model` (upstream), `my_model+` (downstream), `+my_model+` (both), or by `tag:` (`tag:nightly`). Tags are set in a model's `config()`, its `.yml` properties, or inherited from `dbt_project.yml` via `+tags` at the folder level.

This is the real lever for an orchestration decision: run the whole project as one `dbt build` task and let dbt's internal DAG handle ordering, or split it into several orchestrator tasks selecting different slices (e.g., a `tag:hourly` task and a separate `tag:daily` task). Finer-grained task splitting buys independent retry/scheduling per slice at the cost of the orchestrator now needing to know about dbt's internal structure — the same granularity trade-off as any other task-splitting decision, just expressed through dbt's selector syntax instead of separate scripts.

## Packages, briefly

`packages.yml` + `dbt deps` pulls in reusable dbt projects (models, macros, tests) — most commonly `dbt-utils` (dbt Labs-maintained: generic tests, introspection macros, SQL generators like `date_spine`). If you reach for `dbt_expectations` (a community package inspired by Great Expectations) for GE-style tests, know that its own README states it's no longer actively maintained — functional and widely used, but check before betting new work on it.

## Version note

This reflects dbt Core 1.x ("Core release tracks") — the stable, actively-supported line most production dbt projects run today. dbt announced dbt Core 2.0 / dbt Fusion (a Rust engine) in 2026; it's real and in active development, but still alpha and explicitly optional to adopt ("you don't have to move to v2.x today, tomorrow, or ever," per dbt Labs). Everything above still applies under Fusion — dbt's own docs state it "shares the same dbt language and project structure" as Core 1.x.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Hardcoding a schema/table name instead of `ref()`/`source()` | Breaks dbt's dependency graph (wrong run order, or a silent miss) and breaks environment portability (dev vs. prod) in one move | Always use `ref()`/`source()` — never a raw `FROM schema.table` |
| Loading source-system data into the warehouse via seeds | Seeds aren't a data-loading mechanism; large/frequent loads this way are slow and outside what dbt is designed for | Use a real EL/ingestion tool; reserve seeds for small static mapping data |
| Presenting "medallion" as dbt's own terminology | Misattributes a Databricks/lakehouse term to dbt Labs, confuses readers checking dbt's actual docs | Use staging/intermediate/marts as dbt's documented vocabulary; frame medallion as an optional community analogy if you use it at all |
| Assuming a `DBT_TARGET` environment variable exists | It doesn't — a deploy script built around it silently fails to switch environments | Use the `--target` CLI flag (dbt Core) or the platform's environment config (dbt Cloud) |
| Recreating dbt's model dependency graph as separate orchestrator tasks | Duplicates a graph dbt already resolves; two places for a dependency to drift out of sync | Let one `dbt build` task (or a few, split by `--select`/tag) own the model-level DAG; the orchestrator only sequences around it |
