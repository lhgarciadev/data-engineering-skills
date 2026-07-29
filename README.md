# data-engineering-skills

Agnostic, generalist reference skills for data engineering — Python, SQL, Spark, data modeling, pipeline architecture, streaming, data quality, and IaC/cloud — plus an orchestrator that fans out to the relevant domain(s) for cross-cutting tasks. Works across Claude Code, Codex CLI, Gemini CLI, and GitHub Copilot CLI.

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

Claude Code users who prefer the plugin/marketplace flow instead of manual symlinks can install via `.claude-plugin/plugin.json` — see Claude Code's plugin docs for adding a local/git marketplace source.

## Skills

| Skill | Covers |
|---|---|
| `data-engineering` | Orchestrator — routes cross-domain tasks to the relevant skill(s) below |
| `python` | Generators/streaming, decorators, context managers, OOP for pipelines, GIL/concurrency, memory/performance, validation, production patterns |

More domain skills (`sql`, `spark`, `data-modeling`, `pipelines-architecture`, `streaming`, `data-quality`, `iac-cloud`) ship incrementally — see `docs/` for the design spec.

## Updating

Since skills are symlinked, `git pull` in this repo updates them everywhere instantly — no reinstall needed.
