# data-engineering-skills

Agnostic, generalist reference skills for data engineering — Python, SQL, Spark, data modeling, pipeline architecture, streaming, data quality, IaC/cloud, and project/package structure — plus an orchestrator that fans out to the relevant domain(s) for cross-cutting tasks. Works across Claude Code, Codex CLI, Gemini CLI, and GitHub Copilot CLI.

## Install

Clone this repo, then symlink each skill folder into your runtime's personal skills directory:

```bash
git clone <this-repo-url> ~/data-engineering-skills
for skill in ~/data-engineering-skills/skills/*/; do
  name=$(basename "$skill")
  ln -s "$skill" ~/.claude/skills/"$name"   # Claude Code
  ln -s "$skill" ~/.agents/skills/"$name"   # Codex CLI, Gemini CLI, Copilot CLI (shared path)
done
```

Claude Code users who prefer the plugin/marketplace flow instead of manual symlinks can install the `dataforge` plugin via `.claude-plugin/plugin.json` — see Claude Code's plugin docs for adding a local/git marketplace source.

## Skills

| Skill | Covers |
|---|---|
| `data-engineering` | Orchestrator — routes cross-domain tasks to the relevant skill(s) below |
| `python-data-engineering` | Generators/streaming, decorators, context managers, OOP for pipelines, GIL/concurrency, memory/performance, validation, external API consumption, production patterns |
| `sql-data-engineering` | Query optimization, window functions, CTEs, joins, aggregation, execution plans, and indexing across major SQL engines |
| `spark-data-engineering` | Spark/PySpark execution model, shuffle and partitioning, joins and data skew, caching and file formats, Adaptive Query Execution, executor/driver memory, and PySpark-specific concerns |
| `pipelines-architecture-data-engineering` | Pipeline orchestration architecture — orchestrator choice (Airflow, Dagster, Prefect), DAG design and task granularity, idempotency and backfills, data-aware scheduling, deployment topology, dbt project architecture, and Airflow-specific patterns (trigger rules, branching, sensors, dynamic task mapping) |
| `project-structure-data-engineering` | Project/package layout for ingestion and exposition packages, Poetry vs `uv` and packaging conventions, and data contracts |
| `quality-data-engineering` | Quality dimensions and validation checks, failure-response policies (fail/quarantine/drop/repair), data contracts and schema compatibility, data observability (freshness/volume/distribution/schema/lineage), and quality as culture (ownership, shift-left, CI/CD gates, circuit breakers) |

6 of the 9 domain skills above are shipped; the remaining 3 (`modeling-data-engineering`, `streaming-data-engineering`, `iac-cloud-data-engineering`) ship incrementally — see `docs/` for the design specs.

Every domain skill's identifier ends in the `-data-engineering` suffix, leading with its domain word (the orchestrator is just `data-engineering`), so none of them collide with unrelated `python`/`sql`/etc. skills you may already have installed elsewhere — `~/.claude/skills/` and `~/.agents/skills/` are flat, shared namespaces. The plugin itself is named `dataforge` — kept distinct from the orchestrator's `data-engineering` so a marketplace install never doubles up as `dataforge:data-engineering` colliding with anything.

## Updating

Since skills are symlinked, `git pull` in this repo updates them everywhere instantly — no reinstall needed.
