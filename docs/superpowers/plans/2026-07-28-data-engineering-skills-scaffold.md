# Data Engineering Skills — Scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `data-engineering-skills` repo with its multi-runtime scaffold, migrate the existing `python` skill into it, and ship a working, validated `data-engineering` orchestrator skill.

**Architecture:** A plain `skills/` folder (SKILL.md + reference files per skill, no runtime-specific frontmatter) distributed via symlink into each runtime's personal skills path, with an optional `.claude-plugin/plugin.json` for Claude Code's marketplace flow. The orchestrator skill fans out to per-domain subagents for cross-domain tasks, falling back to sequential analysis where parallel dispatch isn't available.

**Tech Stack:** Markdown (SKILL.md, agentskills.io-style frontmatter), git, GitHub (`gh` CLI), JSON (optional plugin manifest).

## Global Constraints

- Skill content in English; code examples in the language most relevant to the topic (per `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §3).
- Content is agnostic/generalist — no institution-specific vocabulary or infra (spec §1).
- `SKILL.md` frontmatter is limited to `name` + `description` — no Claude-specific fields (e.g. `allowed-tools`) — so every skill stays portable across Claude Code, Codex CLI, Gemini CLI, Copilot CLI (spec §2).
- Skill folder/identifier names are lowercase-hyphen (spec §3, §6).
- The orchestrator's dispatch instructions are written in runtime-neutral language with an explicit sequential fallback — never hard-code a Claude-only tool name (spec §5).
- Out of scope for this plan: authoring the 7 remaining domain skills (`sql`, `spark`, `data-modeling`, `pipelines-architecture`, `streaming`, `data-quality`, `iac-cloud`) — each is its own future plan, one per skill, per spec §4/§7.

---

## File Structure

**In `legacy-team-repo` (this repo):**
- Modify: `.claude/skills/python-data-engineering/` — commit as-is (Task 1), then remove once migration is confirmed (Task 7).

**In the new `data-engineering-skills` repo:**
```
data-engineering-skills/
  README.md                       # Task 3 — install instructions per runtime
  .claude-plugin/
    plugin.json                   # Task 3 — optional Claude plugin manifest
  skills/
    python/                       # Task 4 — migrated from python-data-engineering
      SKILL.md
      references/
        iterators-and-generators.md
        decorators-and-context-managers.md
        oop-for-pipelines.md
        concurrency-and-the-gil.md
        memory-and-performance.md
        data-validation.md
        production-patterns.md
    data-engineering/              # Task 5 — orchestrator
      SKILL.md
```

---

### Task 1: Commit the existing `python-data-engineering` skill as a backup

**Owner:** Claude (inline, this repo).

**Files:**
- Modify (stage untracked): `legacy-team-repo/.claude/skills/python-data-engineering/**`

**Interfaces:**
- Produces: a commit hash in `legacy-team-repo` that protects the already-built skill content before it's touched by the migration in Task 4.

- [ ] **Step 1: Confirm the folder is still untracked and unchanged**

Run: `git status --short .claude/skills/`
Expected: `?? .claude/skills/python-data-engineering/` (nothing else under that path)

- [ ] **Step 2: Commit it as a backup**

```bash
git add .claude/skills/python-data-engineering/
git commit -m "$(cat <<'EOF'
Add python-data-engineering skill as backup before repo migration

Temporary: this folder moves to the data-engineering-skills repo per
docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md
and will be removed from here once that migration is confirmed working.
EOF
)"
```

- [ ] **Step 3: Verify the commit landed**

Run: `git log --oneline -1 -- .claude/skills/python-data-engineering/`
Expected: shows the commit from Step 2.

---

### Task 2: Create and clone the `data-engineering-skills` repo

**Owner:** Leonardo (manual — GitHub account/org ownership is his call, per his own request to create it himself).

**Interfaces:**
- Produces: a local clone path (e.g. `~/dev/data-engineering-skills`) that every later task uses as its working directory. Report this path back before Task 3 starts if it differs from `~/dev/data-engineering-skills`.

- [ ] **Step 1: Create the repo**

```bash
gh repo create <owner>/data-engineering-skills --private --clone
```

Replace `<owner>` with your personal GitHub account or the team's org — whichever should hold this for team-wide access. `--clone` clones it to `./data-engineering-skills` in your current directory; move/clone it into `~/dev/data-engineering-skills` to match the sibling convention of your other project repos.

- [ ] **Step 2: Confirm the clone is empty and ready**

Run: `cd ~/dev/data-engineering-skills && git status`
Expected: `On branch main` (or `master`), `No commits yet` or similar — an empty, initialized repo.

- [ ] **Step 3: Report the path**

Tell Claude the local path if it's not `~/dev/data-engineering-skills`, so Task 3 targets the right directory.

---

### Task 3: Scaffold the repo — README and optional plugin manifest

**Owner:** Claude (inline, in the new repo once Task 2's path is confirmed).

**Files:**
- Create: `data-engineering-skills/README.md`
- Create: `data-engineering-skills/.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: the local clone path from Task 2.
- Produces: `data-engineering-skills/skills/` directory (empty, ready for Tasks 4-5 to populate).

- [ ] **Step 1: Create the skills directory**

Run: `mkdir -p data-engineering-skills/skills`

- [ ] **Step 2: Write the README**

Create `data-engineering-skills/README.md`:

```markdown
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
```

- [ ] **Step 3: Write the optional Claude plugin manifest**

Create `data-engineering-skills/.claude-plugin/plugin.json`:

```json
{
  "name": "data-engineering",
  "version": "0.1.0",
  "description": "Agnostic, generalist reference skills for data engineering: Python, SQL, Spark, data modeling, pipeline architecture, streaming, data quality, and IaC/cloud, plus a cross-domain orchestrator.",
  "skills": "./skills/"
}
```

- [ ] **Step 4: Verify the manifest is valid JSON**

Run: `python3 -m json.tool data-engineering-skills/.claude-plugin/plugin.json`
Expected: pretty-printed JSON, no error.

- [ ] **Step 5: Commit**

```bash
cd data-engineering-skills
git add README.md .claude-plugin/plugin.json
git commit -m "Scaffold repo: README with install instructions, optional Claude plugin manifest"
```

---

### Task 4: Migrate `python-data-engineering` into `skills/python/`

**Files:**
- Create: `data-engineering-skills/skills/python/SKILL.md` (copied + renamed from `legacy-team-repo/.claude/skills/python-data-engineering/SKILL.md`)
- Create: `data-engineering-skills/skills/python/references/*.md` (copied verbatim, 7 files)

**Interfaces:**
- Consumes: `legacy-team-repo/.claude/skills/python-data-engineering/` (committed in Task 1).
- Produces: `skills/python/` — the first domain skill Task 5's orchestrator and Task 6's validation will reference.

- [ ] **Step 1: Copy the skill folder**

```bash
cp -R <ruta-al-repo-de-origen>/.claude/skills/python-data-engineering \
      data-engineering-skills/skills/python
```

- [ ] **Step 2: Rename the identifier in the frontmatter**

In `data-engineering-skills/skills/python/SKILL.md`, change the first frontmatter line from:

```yaml
name: python-data-engineering
```

to:

```yaml
name: python
```

Leave the `description` field and the rest of the body untouched — the content doesn't self-reference the old name.

- [ ] **Step 3: Verify nothing else references the old name**

Run: `grep -rn "python-data-engineering" data-engineering-skills/skills/python/`
Expected: no output (only the renamed frontmatter line existed, and it's now fixed).

- [ ] **Step 4: Verify the 7 reference files copied intact**

Run: `diff -rq <ruta-al-repo-de-origen>/.claude/skills/python-data-engineering/references data-engineering-skills/skills/python/references`
Expected: no output (identical).

- [ ] **Step 5: Commit**

```bash
cd data-engineering-skills
git add skills/python/
git commit -m "Migrate python-data-engineering skill as skills/python"
```

---

### Task 5: Write the `data-engineering` orchestrator skill

**Files:**
- Create: `data-engineering-skills/skills/data-engineering/SKILL.md`

**Interfaces:**
- Consumes: the domain skill list (currently just `python`; the other 7 are referenced by name for when they exist — see spec §4).
- Produces: `skills/data-engineering/` — what Task 6 validates.

- [ ] **Step 1: Write the orchestrator SKILL.md**

Create `data-engineering-skills/skills/data-engineering/SKILL.md`:

```markdown
---
name: data-engineering
description: Use when a data engineering task spans more than one domain — designing or reviewing an end-to-end pipeline, evaluating a full data platform, or any request that touches two or more of python, sql, spark, data-modeling, pipelines-architecture, streaming, data-quality, or iac-cloud at once. For a single-domain task (e.g. "review this PySpark job", "optimize this SQL query"), use that domain's skill directly instead — this orchestrator adds no value there.
---

# Data Engineering (Orchestrator)

## Overview

Entry point for data engineering tasks that cross domain boundaries. Identifies which domain skills apply, dispatches one subagent per domain to analyze independently, then synthesizes — surfacing the cross-domain interactions a single-lens analysis would miss.

## When to use

- A request explicitly spans multiple domains ("design this pipeline end-to-end: Kafka → PySpark → warehouse, with data quality checks, deployed via Terraform")
- Reviewing a full data solution rather than one component
- Not for single-domain tasks — let that domain's own skill trigger directly (`python`, `sql`, `spark`, `data-modeling`, `pipelines-architecture`, `streaming`, `data-quality`, `iac-cloud`)

## Process

1. **Identify relevant domains.** Read the request and list which of the 8 domain skills apply. If only one applies, stop and use that skill directly instead of continuing here.
2. **Dispatch one subagent per relevant domain, in parallel when your environment supports it.** Each subagent's prompt must: name the specific domain skill to read first, quote the slice of the original request relevant to that domain, and ask for a focused analysis from that lens only — not a full solution. If your environment does not support parallel or background subagent dispatch, perform each domain's analysis in sequence within this session instead of skipping any.
3. **Synthesize.** Combine the per-domain analyses into one answer. Do not just concatenate them — explicitly call out interactions between domains that no single analysis would see (a partition scheme in `spark` that conflicts with a clustering key decision in `sql`; a Terraform-provisioned resource in `iac-cloud` that a `streaming` consumer assumes already exists). If a domain you identified in step 1 has no installed skill yet in your environment, say so explicitly in the synthesis instead of silently presenting the analysis as complete.

## What this skill does not do

- Does not execute code changes, open PRs, or run any build/deploy step — this suite is reference and design guidance, not an execution pipeline.
- Does not replace the domain skills — it routes to them and combines their output.

## Common mistakes

| Mistake | Fix |
|---|---|
| Triggering this for a single-domain question | Use that domain's skill directly — this adds dispatch overhead for no benefit |
| Dispatching subagents with the full original request instead of a domain-scoped slice | Each subagent should get only the piece relevant to its domain, plus the domain skill name to read |
| Concatenating subagent outputs without synthesis | Explicitly name cross-domain interactions — that's the reason this skill exists instead of just reading multiple skills serially |
| Presenting the synthesis as complete when a relevant domain's skill isn't installed yet | Name the gap explicitly — this suite ships incrementally, so this will happen often at first |
```

- [ ] **Step 2: Commit**

```bash
cd data-engineering-skills
git add skills/data-engineering/
git commit -m "Add data-engineering orchestrator skill"
```

---

### Task 6: Validate the orchestrator

**Owner:** Claude, using the `Agent` tool to run fresh-context scenarios (same method used to validate `python` during its own build).

**Interfaces:**
- Consumes: `skills/python/` (Task 4) and `skills/data-engineering/` (Task 5), symlinked into a live Claude Code environment so a fresh agent can discover them.

Two scenarios — both must pass before Task 7 removes the backup.

- [x] **Step 1: Symlink both skills for testing**

```bash
ln -sf "$(pwd)/data-engineering-skills/skills/python" ~/.claude/skills/python
ln -sf "$(pwd)/data-engineering-skills/skills/data-engineering" ~/.claude/skills/data-engineering
```

Confirmed 2026-07-28: both symlinks present and resolving correctly.

- [x] **Step 2: Run the single-domain bypass scenario**

Dispatch a fresh `general-purpose` agent with this prompt:

> "You have a list of available skills — check it. Then answer: 'Review this function for GIL/concurrency issues: it downloads 200 files over HTTP using `multiprocessing.Pool`.' After answering, report which skill(s) you invoked."

Expected: the agent invokes `python` directly and does **not** invoke `data-engineering` — this is a single-domain question, so the orchestrator should not fire.

**Result (2026-07-28): PASS.** Agent invoked `python` only (cited `concurrency-and-the-gil.md`), correctly diagnosed the `multiprocessing.Pool` choice as wrong tool for an I/O-bound workload, and did not invoke `data-engineering`.

- [x] **Step 3: Run the multi-domain, partial-coverage scenario**

Dispatch a fresh `general-purpose` agent with this prompt:

> "You have a list of available skills — check it. Then answer: 'Design an end-to-end pipeline: a PySpark job transforms data and writes it to a warehouse table, deployed via Terraform on Azure.' Invoke whichever skill(s) apply before answering. After answering, report which skill(s) you invoked and, separately, whether any relevant domain had no skill installed."

Expected: the agent invokes `data-engineering`, identifies `python`, `spark`, and `iac-cloud` as relevant domains, uses `python`'s actual content for the Python-side concerns, and **explicitly states that `spark` and `iac-cloud` have no installed skill yet** rather than fabricating coverage for them.

**Result (2026-07-28): PASS.** Agent invoked `data-engineering`, identified `python`, `spark`, `data-modeling`, `pipelines-architecture`, and `iac-cloud` as relevant, used `python`'s actual reference content for the PySpark job's code design, and explicitly named `spark`, `data-modeling`, `pipelines-architecture`, and `iac-cloud` as not installed rather than fabricating coverage — meets and exceeds the expected outcome.

- [x] **Step 4: Record the result**

If either scenario fails (orchestrator fires on a single-domain question, or silently fabricates coverage for a missing domain), fix the relevant `description` or `Process` wording in `skills/data-engineering/SKILL.md` and re-run only the failing scenario. Do not proceed to Task 7 until both pass.

Both scenarios passed on the first run — no `SKILL.md` changes needed.

---

### Task 7: Remove the backup from `legacy-team-repo`

**Owner:** Claude (inline, this repo) — only after Task 6 passes.

**Files:**
- Delete: `legacy-team-repo/.claude/skills/python-data-engineering/`

- [x] **Step 1: Confirm the new repo has the migrated skill committed**

Run (in `data-engineering-skills`): `git log --oneline -1 -- skills/python/`
Expected: shows Task 4's commit.

**Result (2026-07-28):** confirmed — `3887b94 Migrate python-data-engineering skill as skills/python`.

- [x] **Step 2: Remove the backup from this repo**

```bash
cd <ruta-al-repo-de-origen>
git rm -r .claude/skills/python-data-engineering/
git commit -m "Remove python-data-engineering: migrated to data-engineering-skills repo"
```

**Result (2026-07-28): no-op — nothing to remove.** Checked `legacy-team-repo`: `.claude/skills/python-data-engineering/` doesn't exist there (not tracked, not untracked, no commit in its history touches that path). Task 1's backup commit — which this task assumed as a precondition — never actually landed in that repo; the skill's original content only exists as of Task 4's commit here. Since the folder is already absent, there's nothing left to delete.

- [x] **Step 3: Verify**

Run: `git status --short .claude/skills/`
Expected: no output.

**Result (2026-07-28):** confirmed — no output for that path (only an unrelated untracked file elsewhere in the repo).

---

## Addendum (2026-07-29): `plugin.json` renamed after this plan shipped

Task 3 Step 3 created `.claude-plugin/plugin.json` with `"name": "data-engineering"` — the embedded content in that step still shows that original value, left as-is as a historical record of what the task actually produced at the time. That name was later renamed to `data-engineering-suite` (see `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md`, Estado line and §2) to stop the orchestrator skill — also named `data-engineering` — from being invoked as `data-engineering:data-engineering` when installed through the Claude Code plugin flow. The orchestrator skill's own identifier (`skills/data-engineering/`) did not change at that point. The live file on disk carries the renamed value.

**Second addendum, same day:** every skill identifier in this suite was then prefixed with `dataeng-` (the orchestrator became `dataeng`, dropping the redundant suffix). Task 4's `python` and Task 5's `data-engineering` throughout this plan are the pre-rename names — the live folders are now `skills/dataeng-python/` and `skills/dataeng/`. See the suite spec's Estado line for the rationale (generic identifiers in a flat, shared `~/.claude/skills/`/`~/.agents/skills/` namespace are a symlink collision waiting to happen). Task 6's two discoverability scenarios were re-run fresh under the new names/descriptions after symlinking `dataeng` and `dataeng-python` — both still PASS, no regressions from the rename.

**Third addendum, 2026-07-30:** the naming scheme flipped again — from the shared `dataeng-` prefix to a domain-first `-data-engineering` suffix, alongside renaming the plugin manifest from `data-engineering-suite` to `dataforge`. Task 4's `python`/`dataeng-python` and Task 5's `data-engineering`/`dataeng` throughout this plan and the two addenda above are all superseded names — the live folders are now `skills/python-data-engineering/` and `skills/data-engineering/`, and the live plugin name is `dataforge`. See the suite spec's Estado line for the full chronology and the reasoning (the earlier plugin-name collision concern no longer applies once the plugin is `dataforge`, distinct from the orchestrator's `data-engineering`). No task content was rewritten — this is a pure identifier rename, not a behavior change.

**Fourth addendum, 2026-07-30:** a suite-wide coverage audit found Task 4's `production-patterns.md` covered idempotent upsert writes but not incremental extraction (how a pipeline identifies which rows are new/changed since the last run) or the option of a full pull for small sources — closed in the same pass as a joint effort with `sql-data-engineering` (see that skill's own plan addendum). A new section, "Incremental extraction: tracking what's new", was added covering where watermark state persists between runs (control table, orchestrator-native state — with the Airflow XCom-vs-Variable distinction corrected, Dagster sensor cursors, Prefect Variables — or a checkpoint file), researched against primary sources: `docs/superpowers/research/2026-07-30-incremental-extraction-watermark-verification.md`. `SKILL.md`'s quick-reference and common-mistakes tables updated to match; self-reviewed against `writing-great-skills`.

## Self-Review Notes

- **Spec coverage**: Task 1 ↔ spec §7 item 2; Task 2-3 ↔ item 1; Task 4 ↔ items 2/6; Task 5 ↔ item 4; Task 6 ↔ item 5; Task 7 closes out item 2's deferred removal. Item 6 (7 remaining domain skills) is explicitly out of scope (see Global Constraints) — each gets its own future plan.
- **No placeholders**: every task's content (README, plugin.json, orchestrator SKILL.md) is the actual file content, not a description of what to write.
- **Type/name consistency**: the skill identifier `python` (not `python-data-engineering`) is used consistently from Task 4 onward, including inside Task 6's test prompts and Task 5's orchestrator skill list.
