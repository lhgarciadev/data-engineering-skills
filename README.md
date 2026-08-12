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
| `modeling-data-engineering` | Dimensional modeling (star/snowflake schemas, grain, additivity, fact table types), SCD and dimension patterns (conformed, bridge, junk, role-playing, late-arriving), modeling methodology choice (Inmon vs. Kimball vs. Data Vault), Data Vault 2.0 (hubs/links/satellites, hash keys), modern lakehouse modeling (medallion, One Big Table), and modeling for access patterns (NoSQL single-table design, event/stream modeling, bitemporal modeling) |
| `streaming-data-engineering` | The append-only log and partitioning (topics, offsets, partition keys, acks/ISR, retention vs. compaction), event time vs. processing time, windows and watermarks, state and checkpointing, delivery semantics and exactly-once, stream-stream and stream-table joins, CDC as a stream, and Lambda vs. Kappa with replay |

| `iac-cloud-data-engineering` | Managed-service selection and the six axes that decide it, sizing and the cost shape (per-hour, per-request, per-GB-scanned, per-GB-stored, egress), service identity, network placement and encryption around a data store, infrastructure code for resources that hold state, and the five platform archetypes |

All 9 domain skills are shipped. See `docs/` for the design specs.

Every domain skill's identifier ends in the `-data-engineering` suffix, leading with its domain word (the orchestrator is just `data-engineering`), so none of them collide with unrelated `python`/`sql`/etc. skills you may already have installed elsewhere — `~/.claude/skills/` and `~/.agents/skills/` are flat, shared namespaces. The plugin itself is named `dataforge` — kept distinct from the orchestrator's `data-engineering` so a marketplace install never doubles up as `dataforge:data-engineering` colliding with anything.

## Updating

Since skills are symlinked, `git pull` in this repo updates them everywhere instantly — no reinstall needed.
