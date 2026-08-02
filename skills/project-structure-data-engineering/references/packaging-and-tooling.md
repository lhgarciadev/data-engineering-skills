# Packaging and Tooling

## Poetry or uv — pick one, don't mix

Both solve the same core problem (dependency resolution, a lockfile, a virtual environment) through a single `pyproject.toml`. The practical difference that matters day to day:

- **Poetry** has been the default in most existing data engineering codebases for several years; if the team's other packages already use Poetry, matching that is worth more than a marginal speed gain.
- **uv** (Astral) is a from-scratch, Rust-based resolver and installer — meaningfully faster on install/resolve, and adds Python-version management (`uv python install`) and project scaffolding (`uv init`) that Poetry doesn't attempt. Worth adopting for new packages when there's no existing Poetry convention to match.

Whichever is chosen, commit to it for the whole package: a repo with both a `poetry.lock` and a `uv.lock`, or commands from both tools in different scripts, creates two sources of truth for resolved dependency versions — CI might install one, a teammate's machine the other, and they silently drift apart.

```bash
# uv — common commands
uv init .                    # scaffold pyproject.toml in the current directory
uv add requests              # add a runtime dependency, updates pyproject.toml + uv.lock
uv add --dev pytest ruff     # add a dev-only dependency group
uv sync                      # install exactly what the lockfile specifies
uv run pytest                # run a command inside the project's environment, no manual activation
```

*(Adapted from `wshobson/agents`'s `uv-package-manager` and `python-project-structure` skills, MIT-licensed — commands verified directly against uv's own documented behavior.)*

## Pin Python to the exact deployment runtime, not a floor

`requires-python = ">=3.10"` says "3.10 or newer" — correct for a library meant to run anywhere, wrong for a package meant to run inside one specific managed runtime (a serverless ETL runtime, a specific container base image) that only ships one Python version. If the target runtime is Python 3.10.x specifically, pin the ceiling too:

```toml
[project]
requires-python = ">=3.10,<3.11"
```

This turns a runtime mismatch (code written against 3.11-only syntax, deployed to a 3.10 runtime) into a local `pip install`/`uv sync` failure instead of a cryptic failure after deployment. Check the target runtime's documented Python version whenever it's upgraded — a pin that's never revisited becomes a silent blocker to adopting a newer runtime later.

## Minimal `pyproject.toml` shape

```toml
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
```

If the repo ships more than one package (a transform job and a separate report/export job, for example), list all of them in `[tool.coverage.run] source` — a `source` list copied from a single-package template and never revisited after a second package is added is a real, observed way coverage silently stops meaning anything for that second package.

## Private or shared dependencies

A shared library used by more than one job package (see `package-layout.md`'s "thin job over a shared library" pattern) is usually not published to a public index. Declare it in `dependencies` like any other package, then pin its actual source by tag, not by branch, so a job's dependency doesn't shift underneath it when the shared library changes:

```toml
[project]
dependencies = [
    "boto3",
    "shared-etl-library",
]

[tool.uv.sources]
shared-etl-library = { git = "https://github.com/your-org/shared-etl-library", tag = "v1.2.0" }
```

Bump the tag deliberately, as its own commit, when the job is ready to take a new version of the shared library — not implicitly by tracking a branch.

## Linting and formatting

`ruff` covers linting and formatting in one fast tool, replacing the older flake8 + isort + black combination:

```toml
[tool.ruff]
line-length = 120
target-version = "py310"   # match requires-python above

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "UP"]
```

*(Adapted from `wshobson/agents`'s `python-code-style` skill, MIT-licensed.)*

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Committing both a `poetry.lock` and a `uv.lock` in the same package | Two sources of truth for resolved versions; CI and a teammate's machine can silently drift apart | Pick one tool for the whole package and remove the other lockfile |
| `requires-python = ">=3.10"` for a package meant to run on one specific 3.10.x runtime | Code can pass locally on 3.11+ syntax and fail only after deployment | Pin the ceiling too: `>=3.10,<3.11`, matching the actual runtime |
| `[tool.coverage.run] source` listing only one package when the repo ships several | A whole second package becomes invisible to the coverage report, with no error | List every package the repo ships; re-check this when a package is added |
| Pinning a shared private dependency to a branch instead of a tag | The dependency can change under a job without a corresponding commit in that job's history | Pin by tag; bump it deliberately as its own commit |
