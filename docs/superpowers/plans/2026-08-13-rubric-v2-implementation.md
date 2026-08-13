# Rubric v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the saturated four-dimension 0–2 rubric with a 0–3 rubric whose top level demands second-order content, and prove on already-paid-for data that it no longer saturates — before spending on a campaign.

**Architecture:** The rubric text changes, the judge's JSON schema changes with it, and every analysis instrument becomes version-agnostic so it can still read the v1 campaign it was built for. The saturation threshold is committed before any v2 number exists. Both calibration gates are re-run against the new 0–12 scale before the judge's v2 scores are trusted at all.

**Tech Stack:** bash, `jq`, `awk`, the Claude CLI as judge. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-13-rubric-v2-design.md` — read it before starting any task.

## Global Constraints

- **The v1 campaign data is evidence and never changes.** `tests/quality-uplift/results/full/` is read-only for every task here. Its `judgments.jsonl` carries v1 keys (`mechanism`, `actionable`, `specific`, `tradeoff`) and must stay readable by every instrument after this delivery.
- **Instruments become version-agnostic, not v2-only.** Derive dimension names from the data — a judgment row's `with` object carries them as keys — rather than hardcoding either version's list. An instrument that can only read v2 destroys the reproducibility of three committed v1 analyses.
- **Every instrument change carries a reproduction guard**: after the change, re-run it against the v1 data and confirm the output is **byte-identical** to the committed run file. If it is not, the change altered a historical result and must be fixed before proceeding — not accepted with a note.
- **The judge's schema keeps `additionalProperties: false`.** A score object carrying a key outside the rubric's dimensions means the judge did not answer the rubric it was given, and the schema is what makes that impossible rather than merely detectable.
- **Blinding is structural and must not weaken.** The judge receives the rubric and both answers on stdin, with no Read/Glob/Grep/Bash, a fresh cwd outside the repo, and the suite plugin disabled (`judge-pairs.sh:42-52`). No task may give the judge filesystem access or run it from inside `tests/quality-uplift/`.
- **One writer per run directory.** `judge-pairs.sh:25-28` enforces this with an atomic `mkdir` because two concurrent judging runs once both appended to the same `judgments.jsonl`. Do not weaken it, and never judge into an existing directory.
- **A run directory is `judge-pairs.sh`'s input as well as its output.** It judges whatever `*.with.rep*.txt` / `*.without.rep*.txt` files it finds in `-o` (`judge-pairs.sh:69`). Pointed at an empty directory it writes an empty `judgments.jsonl` and **exits 0** — a silent no-op that reads as success. Every task that judges must therefore (a) copy the answer files in first, and (b) assert the seeded file count *before* judging and the row count *after*. Neither number may be inferred from the exit code.
- **Record the judge model that actually served the run.** `judge-pairs.sh:11` defaults to the alias `sonnet`, which is not a pinned ID: `claude-sonnet-5` and `claude-sonnet-4-6` differ materially (adaptive thinking on by default, different tokenizer, `effort` default `high`). An alias that moves between the calibration run and the re-judge changes the instrument mid-measurement with nothing in the record. Every task that judges writes the resolved model ID into the run directory as `model.txt`.
- **The pre-registered threshold is fixed before any v2 number exists** and is never amended afterwards. Task 2 commits it; Task 6 applies it.
- **Standing constraint from spec §6, carried forward:** any analysis that computes a **correlation** over this campaign's data must pre-register how it handles case clustering (7 cases × 3 reps), which inflates every correlation calculated over it. **No task in this plan computes a correlation** — the saturation gate reports means, standard deviations and percentages — so nothing here is bound by it. It is recorded because the constraint outlives this delivery and neither prior diagnostic declared it.
- Spanish for specs, plans and write-ups; English for code and identifiers.
- Commit per task. Conventional commits, no AI attribution. `tests/gates/pre-commit-gates.sh` runs on commit.

---

## File Structure

| File | Responsibility |
|---|---|
| `tests/quality-uplift/rubric.md` | The v2 rubric text: four dimensions, 0–3, max 12 |
| `tests/quality-uplift/judge-pairs.sh` | JSON schema updated to the v2 dimension names |
| `tests/quality-uplift/analyze.sh` | Dimension names derived from data, not hardcoded |
| `tests/quality-uplift/experiments/rubric-headroom.sh` | Same, plus a configurable per-dimension maximum |
| `tests/quality-uplift/experiments/README.md` | The pre-registered saturation threshold, then its verdict |
| `tests/quality-uplift/README.md` | Re-declared calibration thresholds for the 0–12 scale |
| `tests/quality-uplift/results/calib-v2/`, `calib-len-v2/`, `full-v2-judgments/` | New run directories; the v1 ones are untouched |

---

### Task 1: The v2 rubric text

**Files:**
- Modify: `tests/quality-uplift/rubric.md`

**Interfaces:**
- Produces: the four v2 dimension names — `mechanism`, `actionable`, `assumptions`, `tradeoff` — which Task 3's schema and Task 6's analysis both depend on. `specific` is gone.

- [ ] **Step 1: Rewrite the rubric**

Replace the four dimension definitions. Keep everything else in the file — the opening line, the `more_useful` instruction and all three closing rules — exactly as it stands.

```markdown
You are evaluating two answers to the same question from a data engineer.
Score each answer on four dimensions, 0 to 3 each.

- mechanism: does it identify the actual cause, rather than restating the symptom?
  0 = restates the symptom. 1 = gestures at a plausible cause. 2 = names the
  specific mechanism and why it produces this symptom. 3 = also names the
  observation that would distinguish this cause from the next most likely one.
- actionable: is there a concrete next step the engineer can execute?
  0 = none. 1 = a direction without specifics. 2 = a specific step, with the
  command, setting, or code shape needed. 3 = also says how you would know it
  worked — what to measure or observe afterwards.
- assumptions: does it say what it is taking for granted?
  0 = assumes silently, states nothing. 1 = acknowledges uncertainty vaguely
  ("depending on your setup"). 2 = names at least one concrete assumption the
  answer rests on. 3 = also says how the answer changes if that assumption
  does not hold.
- tradeoff: does it state the cost or risk of what it proposes?
  0 = no. 1 = mentions a caveat vaguely. 2 = names a concrete cost, limit, or
  failure mode of its own recommendation. 3 = also names the condition under
  which that cost outweighs the benefit.
```

The three closing rules stay byte-identical, including `Length is not quality.`

- [ ] **Step 2: Verify what changed and what did not**

```bash
cd tests/quality-uplift
grep -c "0 to 3 each" rubric.md
grep -c "specific:" rubric.md
grep -c "assumptions:" rubric.md
grep -c "Length is not quality" rubric.md
git diff --stat rubric.md
```
Expected: `1`, `0`, `1`, `1`. The diff touches only the dimension block.

- [ ] **Step 3: Commit**

```bash
git add tests/quality-uplift/rubric.md
git commit -m "feat(quality-uplift): rubric v2 con cuatro dimensiones de 0 a 3

El nivel 3 exige contenido de segundo orden que una respuesta competente no
produce sola. 'specific' se reemplaza por 'assumptions': medir la ausencia de
un defecto no tiene techo."
```

---

### Task 2: Pre-register the saturation threshold

**Files:**
- Modify: `tests/quality-uplift/experiments/README.md`

**Interfaces:**
- Produces: the threshold Task 6 is judged against and may not amend.

This is committed **before any v2 score exists anywhere**. A threshold written after seeing results is not a pre-registration regardless of what it claims, and git's history is what makes the ordering checkable by a third party.

- [ ] **Step 1: Append the section**

```markdown
## Rubric v2 — saturation gate

**Question.** The v1 rubric saturated: three of four dimensions had ≥85% of
with-arm answers at the maximum, with standard deviations of 0.071, 0.142 and
0.203. The v2 rubric raises what the top score costs. **Does it actually leave
room, or does it saturate too?**

Answered by re-judging the 42 answers already on disk in `results/full/` — no
answer generation, so the cost is judge calls only.

### Threshold — registered 2026-08-13, before any v2 score existed

The v2 **passes** if, on the with-arm:

- **no** dimension has ≥50% of answers at the maximum (3); **and**
- **all four** dimensions have SD ≥ 0.4.

The v2 **fails** if either condition is unmet.

0.4 is a deliberately lax floor: `tradeoff`, the only v1 dimension that
discriminated, had SD 0.647, and requiring all four to match the best would be a
harder bar than the problem needs.

**"The v2 failed" is a legitimate outcome.** A redesign that still saturates is
one that did not work, and the point of running this on already-paid-for data is
to learn that before funding a campaign rather than after.
```

- [ ] **Step 2: Verify it landed and no v2 score exists yet**

```bash
grep -n "registered 2026-08-13, before any v2 score" tests/quality-uplift/experiments/README.md
ls tests/quality-uplift/results/ | grep -c "v2" || echo "0 v2 result dirs — ordering holds"
```
Expected: the heading prints; no `v2` result directory exists.

- [ ] **Step 3: Commit**

```bash
git add tests/quality-uplift/experiments/README.md
git commit -m "docs(quality-uplift): pre-registrar el umbral de no-saturacion del v2

Se commitea antes de que exista un solo puntaje v2, para que la
pre-registracion sea verificable por timestamp de git."
```

---

### Task 3: Version-agnostic judging and analysis

**Files:**
- Modify: `tests/quality-uplift/judge-pairs.sh:36-37`
- Modify: `tests/quality-uplift/analyze.sh`

**Interfaces:**
- Consumes: the v2 dimension names from Task 1.
- Produces: an `analyze.sh` that reads either version's `judgments.jsonl` correctly.

- [ ] **Step 1: Update the judge's schema to the v2 dimensions**

In `judge-pairs.sh`, both the `a` and `b` objects list the four dimension names twice each — in `properties` and in `required`. Replace `specific` with `assumptions` in all four places. Keep `"additionalProperties":false` exactly as it is.

- [ ] **Step 2: Make `analyze.sh` derive the dimension names from the data**

`analyze.sh` hardcodes the four names in eight places — the totals, the extra-key check and the per-dimension reporting. Replace the hardcoded list with one derived from the file being analysed:

```bash
# The dimension names come from the data, not from this script. A v1 campaign
# carries mechanism/actionable/specific/tradeoff; a v2 campaign carries
# assumptions in place of specific. Hardcoding either one makes this script
# unable to read the other, and the v1 campaign is a committed historical record.
DIMS_JSON=$(jq -c '[.with | keys_unsorted] | first' "$JUDGMENTS" | head -1)
DIMS=$(echo "$DIMS_JSON" | jq -r '.[]')
DIM_COUNT=$(echo "$DIMS" | wc -l)
```

Use `$DIMS` wherever the four names were listed, and sum the total over exactly those keys. The extra-key check compares each row's keys against `$DIMS_JSON` rather than a literal list — so a judge inventing a dimension is still caught, against whichever rubric was actually in play.

- [ ] **Step 3: THE REPRODUCTION GUARD — v1 analysis must be unchanged**

```bash
cd tests/quality-uplift
./analyze.sh results/full > /tmp/v1-after.txt 2>&1
git stash && ./analyze.sh results/full > /tmp/v1-before.txt 2>&1 && git stash pop
diff /tmp/v1-before.txt /tmp/v1-after.txt && echo IDENTICAL
```
Expected: `IDENTICAL`.

**If it differs, stop.** The change altered a committed historical analysis. Fix the derivation until v1 reproduces exactly; do not accept a diff with an explanation. A tool that silently rewrites past results is worse than one that cannot read them.

- [ ] **Step 4: Commit**

```bash
git add tests/quality-uplift/judge-pairs.sh tests/quality-uplift/analyze.sh
git commit -m "feat(quality-uplift): esquema v2 y analisis agnostico de version

Los nombres de dimension salen de los datos, no del script, para que el
analisis del v1 siga siendo reproducible byte a byte."
```

---

### Task 4: Version-agnostic headroom instrument

**Files:**
- Modify: `tests/quality-uplift/experiments/rubric-headroom.sh`

**Interfaces:**
- Consumes: the derivation pattern from Task 3.
- Produces: the instrument Task 6 runs against v2 data.

`rubric-headroom.sh` hardcodes both the dimension names and the per-dimension maximum of 2. Both must come from the data, because the v2 maximum is 3 and a saturation check that measures against the wrong ceiling reports nonsense with confidence.

- [ ] **Step 1: Derive names and maximum**

Take dimension names from the data as in Task 3. Take the per-dimension maximum from a new `-x MAX` flag defaulting to **2**, so the committed v1 run reproduces without arguments and the v2 run passes `-x 3`. Report the maximum in the output header so a reader can tell which scale a run used.

- [ ] **Step 2: THE REPRODUCTION GUARD — the committed v1 run must be unchanged**

```bash
cd tests/quality-uplift/experiments
diff <(./rubric-headroom.sh 2>&1) results/headroom/run.txt && echo IDENTICAL
```
Expected: `IDENTICAL`. The default `-x 2` and the derived names must give exactly the committed output.

**If it differs, stop and fix the instrument** — the v1 headroom result is what the whole v2 redesign rests on, and an instrument that no longer reproduces it invalidates the premise.

- [ ] **Step 3: Commit**

```bash
git add tests/quality-uplift/experiments/rubric-headroom.sh
git commit -m "feat(quality-uplift): headroom agnostico de version y de escala

Nombres de dimension desde los datos y maximo por dimension configurable.
El default reproduce la corrida v1 commiteada byte a byte."
```

---

### Task 5: Re-calibrate both gates against 0–12

**Files:**
- Create: `tests/quality-uplift/results/calib-v2/`, `tests/quality-uplift/results/calib-len-v2/`
- Modify: `tests/quality-uplift/README.md:110-130`

**Interfaces:**
- Consumes: the v2 rubric and schema from Tasks 1 and 3.
- Produces: the evidence that the judge works under v2, without which Task 6's numbers mean nothing.

The existing thresholds are calibrated against 0–8 — the discrimination gate observed **8 vs 0/1/0**. Both gates re-run against 0–12 and their bars are re-declared.

**This runs before Task 6 deliberately.** A judge that cannot tell a specific answer from a generic one under the new rubric, or that can be bought with padding, produces numbers that look authoritative and mean nothing — and that failure would not show in a saturation table, only here.

- [ ] **Step 1: Re-run the discrimination gate**

The fixture answers must be copied in first — `judge-pairs.sh` judges the `.txt` files it finds in the run directory, and against an empty one it writes nothing and exits 0.

```bash
cd tests/quality-uplift
mkdir -p results/calib-v2
cp results/calib/CAL.with.rep1.txt results/calib/CAL.without.rep1.txt results/calib-v2/
[ "$(ls results/calib-v2/*.txt | wc -l)" -eq 2 ] || { echo "FIXTURE MISSING — stop"; exit 1; }
./judge-pairs.sh -o results/calib-v2 -m sonnet -r 3
claude --model sonnet -p 'Reply with only your exact model ID.' 2>/dev/null > results/calib-v2/model.txt
wc -l < results/calib-v2/judgments.jsonl   # must be 3, not 0
jq -r '[.with, .without, .more_useful] | @json' results/calib-v2/judgments.jsonl
```
Expected: exactly **3 rows**, and 3/3 reps prefer the specific answer with a real score gap. Read the actual `judgments.jsonl`; do not trust a summary. **A row count of 0 is the silent-no-op failure, not a passing gate.**

- [ ] **Step 2: Re-run the length-bias gate**

```bash
mkdir -p results/calib-len-v2
cp results/calib-len/CAL.with.rep1.txt results/calib-len/CAL.without.rep1.txt results/calib-len-v2/
[ "$(ls results/calib-len-v2/*.txt | wc -l)" -eq 2 ] || { echo "FIXTURE MISSING — stop"; exit 1; }
./judge-pairs.sh -o results/calib-len-v2 -m sonnet -r 3
cp results/calib-v2/model.txt results/calib-len-v2/model.txt
wc -l < results/calib-len-v2/judgments.jsonl   # must be 3, not 0
jq -r '[.with, .without, .more_useful] | @json' results/calib-len-v2/judgments.jsonl
```
Expected: exactly **3 rows**, and 3/3 reps still prefer the specific answer despite it being the shorter file.

- [ ] **Step 3: If either gate fails, STOP and report**

Do not proceed to Task 6, and do not adjust the rubric to make a gate pass. A failing gate is a finding about the v2 rubric — most likely that a level-3 criterion is unjudgeable — and it is exactly what these gates exist to surface before money is spent.

- [ ] **Step 4: Re-declare the thresholds**

Update `tests/quality-uplift/README.md`'s two gate descriptions with the observed v2 numbers, replacing the 0–8 figures. Keep the reasoning paragraphs; only the scale and the observed values change.

- [ ] **Step 5: Commit**

```bash
git add tests/quality-uplift/results/calib-v2 tests/quality-uplift/results/calib-len-v2 tests/quality-uplift/README.md
git commit -m "test(quality-uplift): recalibrar ambas compuertas contra la escala 0-12"
```

---

### Task 6: Re-judge the 42 answers and apply the threshold

**Files:**
- Create: `tests/quality-uplift/results/full-v2-judgments/`
- Create: `tests/quality-uplift/experiments/results/headroom-v2/run.txt`
- Modify: `tests/quality-uplift/experiments/README.md`

**Interfaces:**
- Consumes: the threshold committed in Task 2, the instruments from Tasks 3 and 4, and the calibration evidence from Task 5.

**Do not modify Task 2's threshold.** It is the standard being applied. If it turns out to have been badly specified, say so in the write-up and leave it as written.

- [ ] **Step 1: Re-judge the existing answers under v2**

The 42 answers are **copied** out of `results/full/` into the new run directory — that is the read, and it is the only way `judge-pairs.sh` sees them. Copying out never writes to `results/full/`. Assert the seeded count before judging: against an empty directory the script writes nothing and exits 0.

```bash
cd tests/quality-uplift
mkdir -p results/full-v2-judgments
cp results/full/*.with.rep*.txt results/full/*.without.rep*.txt results/full-v2-judgments/
[ "$(ls results/full-v2-judgments/*.txt | wc -l)" -eq 42 ] || { echo "SEED WRONG — stop"; exit 1; }
./judge-pairs.sh -o results/full-v2-judgments -m sonnet -r 3
claude --model sonnet -p 'Reply with only your exact model ID.' 2>/dev/null > results/full-v2-judgments/model.txt
wc -l < results/full-v2-judgments/judgments.jsonl
```
Expected: 42 seeded answer files, then **63 rows** — 21 `(id, rep)` pairs × 3 judge reps. **No answers are generated.** A count of 0 rows means the seed failed, not that the gate passed.

- [ ] **Step 2: Confirm the campaign data was not touched**

```bash
git status --short tests/quality-uplift/results/full/
```
Expected: empty.

- [ ] **Step 3: Run the headroom instrument against the v2 judgments**

```bash
cd experiments
mkdir -p results/headroom-v2
./rubric-headroom.sh -d ../results/full-v2-judgments -x 3 \
  > results/headroom-v2/run.txt 2>&1
cat results/headroom-v2/run.txt
```

- [ ] **Step 4: Apply the pre-registered threshold, mechanically, before writing prose**

Read the with-arm rows. Write down, in this order: the `pct@3` for each of the four dimensions, the SD for each, and then whether **both** conditions hold — no dimension ≥50% at maximum, and all four SD ≥ 0.4. State PASS or FAIL and the numbers that produce it **before** writing any explanation.

- [ ] **Step 5: Write the result section**

Append to `tests/quality-uplift/experiments/README.md`, under the pre-registration: the verdict, the full per-dimension table for both arms, and the caveats stated as limits — it is descriptive statistics on the same 42 answers, it does not measure uplift, and a v2 that leaves room is not evidence that uplift exists.

If the verdict is FAIL, say which dimensions saturated and stop. Do not propose a v3 in the same breath; that is a separate design decision made with these numbers in hand.

- [ ] **Step 6: Commit**

```bash
git add tests/quality-uplift/results/full-v2-judgments tests/quality-uplift/experiments/results/headroom-v2 tests/quality-uplift/experiments/README.md
git commit -m "test(quality-uplift): re-juzgar bajo v2 y aplicar el umbral de no-saturacion"
```

---

## What invalidates this delivery

- Any instrument that stops reproducing its committed v1 output byte-for-byte, accepted with an explanation instead of fixed.
- Any write under `tests/quality-uplift/results/full/`. That data is the evidence.
- Editing Task 2's threshold after Task 6 has produced numbers.
- Declaring the v2 a pass on a pattern the pre-registered threshold places outside it.
- Proceeding to Task 6 with a failing calibration gate, or adjusting the rubric until a gate passes.
- Reading this delivery as evidence of uplift. It builds an instrument with room; what that instrument will show is a separate question.
- Weakening the judge's blinding, its `additionalProperties: false` schema, or the one-writer-per-directory guard.
