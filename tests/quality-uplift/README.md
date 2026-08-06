# Quality-uplift eval

Behavioral test for **skill value**, not skill discovery. Research verification (under
`docs/superpowers/research/`) checks whether a skill's *content* is true. The triggering
matrix (`tests/triggering/`) checks whether the right skill *fires*. Neither answers the
question that decides whether the suite earns its place: **is the answer better with the
skill than without it?**

Full design rationale: `docs/superpowers/specs/2026-08-05-quality-uplift-eval-design.md`.
Implementation plan: `docs/superpowers/plans/2026-08-05-quality-uplift-eval-implementation.md`.

## What this measures, and what it does not

**Measures:** apparent usefulness of the answer to a senior data engineer, judged blind
against a four-dimension rubric (mechanism, actionable, specific, tradeoff — see
`rubric.md`), by an LLM judge (`sonnet`) that never sees which arm produced which answer.

**Does not measure:**

- **Factual correctness.** An LLM judge measures perceived usefulness, not truth. A
  fluent, well-organized, *wrong* answer can still score high. Correctness stays covered
  by the research verifications under `docs/superpowers/research/`. The two axes are
  complementary — neither substitutes for the other, and a high uplift number here says
  nothing about whether the skill's claims hold up against primary sources.
- **Transfer fidelity.** Whether the answer repeats concepts the skill's own docs state.
  That metric would be circular: it rewards a skill for saying what it says, even where
  saying it adds nothing.
- **Routing.** Already covered by `tests/triggering/`. This eval *assumes* correct
  routing and enforces it as a validity condition on the with-arm (below), not as a
  result to report.

A number in `baselines/` answers "did a senior engineer-judge find the with-arm answer
more useful, on this one prompt, on this one day, against this model version" — nothing
broader. Treat it as one data point, not a certification.

## Contamination guards

Same three guards validated in `tests/triggering/`, carried over because the failure
modes are identical:

1. **`stdin` is `/dev/null`.** `claude -p` also reads stdin; without the redirect a
   probe launched from a `while read` loop over `cases.tsv` inherits the open file and
   the remaining rows leak into the prompt.
2. **Each probe runs from a fresh `mktemp -d` outside the repo.** Claude Code injects the
   cwd and its contents into session context; running from inside this repo would let a
   probe see the skill sources it is being tested against.
3. **No MCP servers, memory-gated serial execution.** `--strict-mcp-config` keeps the
   session minimal; `generate-answers.sh` waits for ≥1200 MB of `MemAvailable` before
   every probe. This is a 6 GB WSL2 box that has OOM'd mid-campaign before under
   concurrency — do not raise concurrency to speed this up.

A fourth guard specific to this eval, not present in triggering: **the judge is blind**.
It receives the two answers labeled only `A`/`B`, is never told a skill or ablation is
involved, and scores under a fixed rubric. `judge-pairs.sh` maps `A`/`B` back to
`with`/`without` only after scoring, so nothing about the judge's prompt could bias it
toward the arm rather than the content.

**5. Exactly one writer per results directory, verified before starting a stage.**
During the 2026-08-05 campaign, `judge-pairs.sh` was started a second time against the
same `results/full/` while the first invocation was still running. Both processes
appended to the same `judgments.jsonl` concurrently, producing 62 duplicate
`(id, rep, judge_rep)` rows out of 125 total lines for what should have been 63 —
harmless in isolation (each row was a real judge call) but fatal to the "Judge
agreement" section, which depends on exactly one row per order-schedule slot. See
`baselines/2026-08-05-uplift.md` for the full incident and how the contaminated file
was preserved rather than silently deduplicated. Before starting `generate-answers.sh`
or `judge-pairs.sh` against a run directory, confirm nothing is already writing to it:

```bash
ps -eo pid,cmd | grep -E "generate-answers\.sh|judge-pairs\.sh" | grep -v grep
```

Do not use `pgrep -f` for this check — `pgrep -f` matches against the full command
line, including of the very shell invoking the check, and reports a false positive on
itself.

## The two calibration gates

Before spending anything on a real campaign, the judge itself has to be shown to work.
Both gates live in `results/calib/` and `results/calib-len/` and must be re-verified —
by reading the actual `judgments.jsonl`, not by re-running the gate and trusting a
summary — before any campaign is judged credible:

- **Discrimination gate** (`results/calib/`): given one deliberately specific answer and
  one deliberately generic one, does the judge pick the specific one, consistently, with
  a real score gap? Passing bar: 3/3 judge reps prefer the specific answer, with scores
  that actually separate them (observed: 8 vs 0/1/0 on the 0–8 scale).
- **Length-bias gate** (`results/calib-len/`): given the same specific/generic pair, but
  with the *generic* one padded to be the *longer* file, does the judge still pick the
  specific one? Passing bar: 3/3 judge reps still prefer the specific answer despite it
  being shorter (observed: specific answer wins 3/3 despite being 848 bytes against a
  1494-byte padded opponent).

**If either gate does not hold, the campaign is not run.** A judge that cannot tell a
specific answer from a generic one, or that can be bought with padding, produces numbers
that look authoritative and mean nothing — the failure would not be visible in the
uplift table itself, only in these two calibration runs.

## The validity gate on the with-arm

A with-arm sample is only accepted if the case's expected skill actually fired somewhere
in the invocation chain, checked the same chain-aware way `tests/triggering/rescore.sh`
checks it — not just as the first tool call. A sample where the skill never loaded is
not a measurement of the skill; it's noise, and averaging it in would understate the
very thing being measured. Up to 3 attempts per sample; a case that never gets 3 valid
with-arm samples is reported as **not measurable**, not filled in with an invalid one.

The without-arm has no such gate. Its natural behavior — including a superpowers process
skill answering instead of the suite — *is* the counterfactual being measured, and
rejecting a without-arm sample for not loading a suite skill would destroy the
measurement.

Both arms share a non-emptiness floor: a 0-byte answer (timeout kill, or a log with no
`result` event) is an infrastructure failure, not a real counterfactual, and is
discarded and retried under the same 3-attempt cap.

## What voids a campaign

State these plainly in every report of the numbers, not just here:

- Either calibration gate failing.
- Pearson r above 0.5 between answer length and rubric total (`analyze.sh`'s "Score vs
  length" section). If scores track verbosity, the delta is not measuring the skill.
- A case whose with-arm never passed the validity gate in 3 attempts — report as **not
  measurable**, never filled in.
- Fewer than 3 accepted samples per arm for a case.

`analyze.sh` also reports, and a digest must carry forward without editing:
judge-coherence failures (a row that scores one answer higher but prefers the other),
judge failures (empty/unparseable judge replies — a dropped row means a case averaged
over fewer reps than the table implies), discard counts by reason, and malformed-input
counts rejected by the report itself. None of these are footnotes; a non-zero count in
any of them changes how much the uplift table can be trusted.

## Reading uplift against cost

A delta alone doesn't say whether a skill earns its keep. Per spec §7.1, cross the
uplift against the skill's own on-invoke token cost (`claude plugin details
dataforge@skills-dir`) — a small delta at 3.7k tokens per invocation does not earn its
cost, even if it's technically positive.

## Running

```bash
cd tests/quality-uplift
nohup ./generate-answers.sh -r 3 -o results/full > full-answers.log 2>&1 &
# watch: grep -E "ok |discard|UNMEASURABLE" full-answers.log
# expect 42 `ok` lines, or fewer with matching UNMEASURABLE lines

nohup ./judge-pairs.sh -o results/full -r 3 > full-judge.log 2>&1 &
# expect 63 judgments

./analyze.sh results/full | tee baselines/<date>-uplift.md
```

~42 `opus` answer sessions plus ~63 `sonnet` judgments, serial by design, roughly 45
minutes and ~$16 at the per-answer cost observed while writing the eval plan. Do not
raise concurrency — see contamination guard 3, above.

`results/` is gitignored and fully regenerable; re-run the scripts to reproduce or
extend it. `baselines/` is the committed record — each file there is a single campaign's
`analyze.sh` output, verbatim, plus the hand-appended cost column. Never edit a
committed baseline's numbers after the fact; a re-run gets a new dated file, and the old
one stays as the record of what was true when it ran.

**The first campaign, `baselines/2026-08-05-uplift.md`, is void** — its score-vs-length
correlation was r = 0.61, above the 0.5 threshold below. Read that file for why, and do
not treat its per-skill delta table as a standing result. It is kept as the record of
what happened, not as evidence about the suite's uplift.

## Known deferred issues

- `generate-answers.sh` exits 2 under `pipefail` when zero samples are accepted for a
  run. That reads as a generic pipe error, not "zero valid samples" — check the
  `accepted samples:` count in the log rather than trusting the exit code alone.
- Case IDs containing a literal `.` would break the `${base%%.*}` parse in
  `judge-pairs.sh` (none of the current 7 case IDs do).
- An out-of-enum `more_useful` string from the judge falls through to `"tie"` rather
  than erroring.
