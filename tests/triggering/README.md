# Triggering matrix

Behavioral tests for skill **discovery and routing**. Research verification (under
`docs/superpowers/research/`) checks whether a skill's *content* is true. This suite
checks something different and independent: whether the right skill actually **fires**
for a realistic prompt, and whether a sibling skill hijacks it.

A skill can be factually impeccable and still be useless if its `description` never wins
the match.

## What is measured

Objective tool-call evidence, not the model's self-report. Each case runs a fresh
headless session and the runner parses the `stream-json` event log for
`tool_use` events named `Skill`, recording every skill invoked in call order. `Read`
calls under `references/` are recorded too, so routing depth is visible.

Self-reported answers ("which skill would you use?") are not accepted as evidence —
models confabulate about their own context.

### Score the chain, not the first call

**`rescore.sh` is the authoritative verdict.** A domain skill counts if it fires
*anywhere* in the invocation chain; `POSITIONS` records where.

`run-matrix.sh` prints a live verdict while it runs, but that one looks only at the
first skill invoked. Do not report it. The superpowers `SessionStart` hook mandates a
process skill first — verbatim: *"Fix this bug → systematic-debugging first, then domain
skills"* — so a correct session in this environment routinely looks like

```
superpowers:systematic-debugging  ->  dataforge:pipelines-architecture-data-engineering
```

Scoring position 1 marks that as a failure. Doing so manufactured a "superpowers crowds
out the suite" finding across four cases; re-scoring the same saved logs chain-aware
showed two of the four had been routing correctly all along, at position 2. Trust
`rescore.sh`.

Because every probe's raw event log is kept, re-scoring never requires re-running.

## Two contamination traps the runner guards against

Both were found the hard way — they silently invalidated a full run before being caught.

**1. `claude -p` also reads stdin.** A prompt passed with `-p` is *merged* with whatever
arrives on stdin. Because `run_case` is called from a `while read ... < matrix.tsv` loop,
the probe inherited the open matrix file as stdin and received the remaining rows —
including the `EXPECTED` column — appended to its prompt. Probes then answered *about the
test matrix* instead of the prompt. Every `claude` call must be `</dev/null`.

Verify with: `echo TOKEN | claude -p "did your input contain TOKEN?"` → answers `YES`.

**2. Working directory leaks into context.** Claude Code injects the cwd and its contents
into session context, so a probe launched from inside this repo can see the skill sources
and the matrix. Each probe runs from a fresh empty `mktemp -d` outside the repo.

## Arms

| Arm | How | Purpose |
|---|---|---|
| `with` | suite enabled as installed | does the right skill fire? |
| `without` | `--settings '{"enabledPlugins":{"dataforge@skills-dir":false}}'` | baseline; also reveals whether another plugin hijacks the prompt |

The `without` arm disables **only** this suite. Every other plugin, `CLAUDE.md`, and hook
stays in place, so the two arms differ by exactly one variable. Validated: the arm
override yields `DATAFORGE=0 / SUPERPOWERS=14`.

## Case categories

| Category | Question it answers |
|---|---|
| `positive` | does the intended skill fire for its own core task? |
| `discriminator` | on a known scope overlap, which sibling wins? |
| `negative` | does the suite stay quiet when it should? |

Discriminators are the valuable cases. They target overlaps the descriptions explicitly
disclaim — dbt layout (pipelines vs project-structure), data contracts (quality vs
project-structure), SCD2 SQL (sql vs modeling), dataframe validation library (python vs
quality), in-task idempotency (python vs pipelines).

Prompts are deliberately a mix of Spanish and English, because the descriptions are
written in English and are used against Spanish prompts in practice.

`EXPECTED` accepts alternatives separated by `|` for cases where more than one skill is a
defensible answer.

## Running

```bash
./run-matrix.sh -m haiku -a with -r 5              # full matrix, 5 reps, suite enabled
./run-matrix.sh -m haiku -a without -r 5           # baseline arm
./run-matrix.sh -f matrix-adversarial.tsv -m opus -r 5
./run-matrix.sh -m opus -a with -c D2 -r 5         # one case
```

Then score:

```bash
./rescore.sh results/base-opus-with matrix.tsv matrix-adversarial.tsv
```

Results land in `results/<suite>-<model>-<arm>/`: a `.jsonl` event log per rep. Both
`results/` and `*.log` are gitignored — they are 12 MB per full campaign and fully
regenerable. Commit the digests under `baselines/` instead.

To run a subset, filter the source matrices into a temp file rather than committing
derived case files:

```bash
{ head -1 matrix.tsv; grep -E '^(P1|D4|D5)\b' matrix.tsv; } > /tmp/subset.tsv
./run-matrix.sh -f /tmp/subset.tsv -m opus -r 5
```

## Reps are not optional

Single samples lie. `-r 1` produced a 19/19 that collapsed to 10/19 once the
contamination was fixed, and individual cases resolve to three different destinations
across five reps. Verdicts: `PASS` = all reps hit, `FLAKY` = some, `FAIL` = none.
**`FLAKY` is a finding, not noise** — a description that binds converges on one shape.

## Model choice

Default is the weakest available model. Routing is a description-matching task, so a weak
model is the **stricter** test of description clarity. But a weak-model failure is not
evidence of a description problem: 6 of haiku's 11 failures passed cleanly on sonnet.
Always re-run failures on a stronger model — and on the model actually in daily use —
before concluding anything about the wording.

## Resource limits

Each probe is a ~500 MB node process. On a 6 GB WSL2 box that also runs VS Code Server,
running several at once has OOM'd the VM mid-campaign. The runner defaults to `-j 1`,
waits for ≥1200 MB of headroom before each probe, and starts zero MCP servers.
Raise `-j` only where memory is genuinely available.

## Note on `claude plugin eval`

Claude Code ships a first-class eval runner (`claude plugin eval`) with a built-in
`--ablation with-without` arm, which would replace this script. It is gated behind early
access and currently exits with `plugin eval is currently in early access` without running.
When it opens up, port these cases to `evals/**/case.yaml` and retire this runner.
