# Judging Diagnostic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Determine what produces the `r = 0.61` correlation between answer bytes and rubric total that voids the quality-uplift campaign, by decomposing the correlation across the rubric's four dimensions on data that has already been paid for.

**Architecture:** One read-only bash instrument in the style of `experiments/length-causality.sh`. It joins the 42 `.meta` files (which carry byte counts) to the 63 rows of `judgments.jsonl` (which carry per-dimension scores), and reports Pearson `r` between bytes and each dimension separately, per arm and pooled. The reading rule is committed to git **before** the instrument exists, so the pre-registration is verifiable by timestamp rather than by assertion.

**Tech Stack:** bash, `jq`, `awk`. No new dependencies. Zero probe cost — nothing is generated or judged.

**Spec:** `docs/superpowers/specs/2026-08-13-judging-diagnostic-design.md` — read it before starting any task.

## Global Constraints

- **Read-only.** The instrument must never write to `tests/quality-uplift/results/full/`. It reads `.meta` and `judgments.jsonl` and writes only under `experiments/results/`. A campaign's raw data is evidence; an instrument that can modify it is not trustworthy.
- **Use `judgments.jsonl`, never `judgments.contaminated-2runs.jsonl`.** Both live in `results/full/` with similar names. The contaminated file is a recorded defect, kept deliberately.
- **Match `analyze.sh`'s computation exactly** (`analyze.sh:170-189`). Each answer contributes **one** point: its byte count paired with the **mean** of its scores across judge reps. Pearson is then computed over those points. Deviating from this makes the reproduction guard meaningless, because a different number would no longer be evidence of a bad join.
- **Pearson formula, copied verbatim from `analyze.sh:179-182`:**
  ```awk
  function pear(n,sx,sy,sxy,sxx,syy,  num,den) {
    num=n*sxy-sx*sy; den=sqrt((n*sxx-sx*sx)*(n*syy-sy*sy));
    return (den==0) ? 0 : num/den;
  }
  ```
- **`.meta` is tab-separated with bytes in field 5**, per `analyze.sh:103`: `id, arm, rep, chain, bytes, tokens, cost, attempts`. A meta whose field 5 is not an integer is counted as bad and skipped, never guessed at.
- **Report `n` with every correlation.** A correlation without its sample size is not a finding.
- **Report per arm and pooled, always.** `analyze.sh:164-168` states why: a high pooled `r` is produced both by a judge that rewards length and by a with-arm that is simply longer *and* better, and only the per-arm decomposition separates them.
- **"No resuelve" is a valid outcome.** The instrument and its write-up must be able to report that the pattern does not discriminate. The failure mode this exercise exists to avoid is declaring a diagnosis that the data does not support.
- Spanish for the spec, plan and results write-up; English for code comments and identifiers, matching this repo's split.
- Commit per task. Conventional commits, no AI attribution. `tests/gates/pre-commit-gates.sh` runs on commit.

---

## File Structure

| File | Responsibility |
|---|---|
| `tests/quality-uplift/experiments/README.md` | Gains a pre-registration section (Task 1) and a results section (Task 4) |
| `tests/quality-uplift/experiments/dimension-length-decomposition.sh` | The instrument: join, guards, per-dimension Pearson |
| `tests/quality-uplift/experiments/results/dld/` | Raw output of the run |

---

### Task 1: Pre-register the reading rule

**Files:**
- Modify: `tests/quality-uplift/experiments/README.md`

**Interfaces:**
- Produces: the committed reading rule that Task 4 must be judged against. Task 4 may not modify it.

This task exists to be committed **before** the instrument can produce a number. That ordering is the whole point: a rule written after seeing results is not a pre-registration regardless of what it claims. Git's history is what makes it checkable.

- [ ] **Step 1: Append the pre-registration section**

Add to `tests/quality-uplift/experiments/README.md`, after the existing `length-causality.sh` section:

```markdown
## `dimension-length-decomposition.sh`

**Question.** `length-causality.sh` left the mechanism behind `r = 0.61` unresolved: it
refuted "judge length-bias" without establishing the opposite. This instrument asks a
question that experiment could not: **does the correlation live in all four rubric
dimensions, or only in the three that require adding content?**

**Hypothesis under test — coverage additivity.** The rubric asks for four distinct content
elements. An answer containing all four is mechanically longer than one containing two,
because covering four things costs words. Under this hypothesis `r = 0.61` is neither judge
bias nor noise; it is length acting as a proxy for how many elements are present.

**Why this discriminates where the previous experiment did not.** The two hypotheses
predict **opposite signs for the same dimension**, `specific`:

- If the judge rewards length, all four dimensions correlate positively with bytes,
  `specific` included — a judge that pays for volume has no reason to penalise it.
- If the rubric is coverage-additive, `mechanism`, `actionable` and `tradeoff` correlate
  positively because they are content you add, while `specific` stays flat or goes
  negative: a longer answer has more room for generic filler, and `specific` penalises
  exactly that.

### Reading rule — registered 2026-08-13, before the instrument was written

| Observed | Reading |
|---|---|
| All four dimensions correlate positively with bytes, `specific` included | Supports judge length-bias |
| `mechanism`/`actionable`/`tradeoff` positive, `specific` flat or negative | Supports coverage additivity |
| Mixed, or inconsistent between arms | **Does not resolve.** Report as such |

"Flat" is defined here, before any number exists: `|r| < 0.2` for `specific`. A value
between 0.2 and the other dimensions' correlations falls in the third row, not the second.

**"Does not resolve" is a legitimate outcome of this experiment.** The failure would be
declaring resolved what is not, which is the defect this suite exists to catch.
```

- [ ] **Step 2: Verify the section landed and the file still reads cleanly**

```bash
grep -n "Reading rule — registered" tests/quality-uplift/experiments/README.md
grep -c "dimension-length-decomposition" tests/quality-uplift/experiments/README.md
```
Expected: the heading line prints; the count is at least 1.

- [ ] **Step 3: Commit — this commit must precede any result**

```bash
git add tests/quality-uplift/experiments/README.md
git commit -m "docs(quality-uplift): pre-registrar la regla de lectura del diagnostico

Se commitea antes de que el instrumento exista para que la pre-registracion
sea verificable por timestamp de git y no por afirmacion."
```

---

### Task 2: The instrument, with the reproduction guard

**Files:**
- Create: `tests/quality-uplift/experiments/dimension-length-decomposition.sh`

**Interfaces:**
- Consumes: the pre-registered rule from Task 1 (as the standard its output will be read against).
- Produces: an executable that prints a report to stdout. Task 4 runs it and records the output.

The reproduction guard is written and verified **first**, before any per-dimension work. If the instrument cannot reproduce the published pooled `r = 0.61` for the rubric total, its join is wrong and every per-dimension number it prints is noise with a decimal point.

- [ ] **Step 1: Write the script**

Create `tests/quality-uplift/experiments/dimension-length-decomposition.sh`:

```bash
#!/usr/bin/env bash
# Decomposes the bytes-vs-score correlation across the rubric's four dimensions.
#
# Read-only. Reads a campaign's .meta files and judgments.jsonl; writes nothing
# under results/full/.
#
# The question: does the correlation live in all four dimensions, or only in the
# three that require adding content? The two competing hypotheses predict opposite
# signs for `specific`. See experiments/README.md for the pre-registered rule.
#
# Usage: ./dimension-length-decomposition.sh [-d RESULTS_DIR]

set -uo pipefail
cd "$(dirname "$0")" || exit 1

RESULTS_DIR="../results/full"
while getopts "d:" opt; do
  case "$opt" in
    d) RESULTS_DIR="$OPTARG" ;;
    *) echo "usage: $0 [-d RESULTS_DIR]" >&2; exit 2 ;;
  esac
done

JUDGMENTS="$RESULTS_DIR/judgments.jsonl"

# Guard: the contaminated file lives beside the real one under a similar name.
case "$JUDGMENTS" in
  *contaminated*) echo "REFUSING: $JUDGMENTS is a recorded contaminated file" >&2; exit 1 ;;
esac
[ -f "$JUDGMENTS" ] || { echo "missing: $JUDGMENTS" >&2; exit 1; }

echo "# Dimension-length decomposition"
echo
echo "Source: $RESULTS_DIR"
echo "Judgments: $(wc -l < "$JUDGMENTS") rows"
echo

# ---------------------------------------------------------------------------
# Guard: duplicate (id, rep, judge_rep) slots.
# More than one writer touched judgments.jsonl in this suite's history, and which
# competing row survived per slot is an artefact of write order. A duplicate stops
# the analysis rather than silently biasing a correlation.
# ---------------------------------------------------------------------------
DUPES=$(jq -r '[.id, (.rep|tostring), (.judge_rep|tostring)] | join("/")' "$JUDGMENTS" \
        | sort | uniq -d)
if [ -n "$DUPES" ]; then
  echo "STOP — duplicate (id, rep, judge_rep) slots:"
  echo "$DUPES" | sed 's/^/    /'
  exit 1
fi
echo "Duplicate slots: none"

# ---------------------------------------------------------------------------
# Load .meta -> id, arm, rep, bytes. Field 5 is bytes (analyze.sh:103).
# A meta whose byte field is not an integer is counted, never guessed at.
# ---------------------------------------------------------------------------
METAS=$(mktemp) || exit 1
trap 'rm -f "$METAS" "$ROWS"' EXIT
bad_meta=0
for m in "$RESULTS_DIR"/*.meta; do
  [ -f "$m" ] || continue
  IFS=$'\t' read -r m_id m_arm m_rep _m_chain m_bytes _rest < "$m"
  [[ "$m_bytes" =~ ^[0-9]+$ ]] || { bad_meta=$((bad_meta + 1)); continue; }
  printf '%s\t%s\t%s\t%s\n' "$m_id" "$m_arm" "$m_rep" "$m_bytes" >> "$METAS"
done
echo "Metas read: $(wc -l < "$METAS")   malformed: $bad_meta"
echo

# ---------------------------------------------------------------------------
# Join: one row per answer, carrying its bytes and the MEAN of each dimension
# across judge reps. Averaging first matches analyze.sh:170-177 — deviating from
# it would make the reproduction guard below meaningless.
# ---------------------------------------------------------------------------
ROWS=$(mktemp) || exit 1
while IFS=$'\t' read -r id arm rep bytes; do
  [ -n "$id" ] || continue
  vals=$(jq -r --arg id "$id" --arg rep "$rep" --arg arm "$arm" '
           select(.id==$id and .rep==($rep|tonumber))
           | (if $arm=="with" then .with else .without end)
           | [.mechanism, .actionable, .specific, .tradeoff,
              (.mechanism+.actionable+.specific+.tradeoff)] | @tsv' \
         "$JUDGMENTS" 2>/dev/null \
         | awk -F'\t' '{for(i=1;i<=5;i++) s[i]+=$i; n++}
                       END{if(n>0){printf "%s", s[1]/n; for(i=2;i<=5;i++) printf "\t%s", s[i]/n}}')
  [ -n "$vals" ] && printf '%s\t%s\t%s\n' "$arm" "$bytes" "$vals" >> "$ROWS"
done < "$METAS"

echo "Answers joined: $(wc -l < "$ROWS") (expected 42 for the full campaign)"

# Guard: a judgment row whose (id, rep) has no matching .meta contributes to no
# correlation and would vanish silently. Report the consumed count against the file's.
CONSUMED=$(jq -r '[.id, (.rep|tostring)] | join("/")' "$JUDGMENTS" | sort -u | while read -r k; do
  jid="${k%%/*}"; jrep="${k##*/}"
  cut -f1,3 "$METAS" | sort -u | grep -qx "$jid	$jrep" && echo "$k"
done | wc -l)
TOTAL_SLOTS=$(jq -r '[.id, (.rep|tostring)] | join("/")' "$JUDGMENTS" | sort -u | wc -l)
echo "Judgment (id,rep) slots matched to a meta: $CONSUMED of $TOTAL_SLOTS"
[ "$CONSUMED" -eq "$TOTAL_SLOTS" ] || echo "WARNING: some judgment rows matched no .meta and were dropped"
echo

# ---------------------------------------------------------------------------
# Pearson, per arm and pooled, for each dimension and the total.
# Formula copied verbatim from analyze.sh:179-182.
# ---------------------------------------------------------------------------
awk -F'\t' '
  function pear(n,sx,sy,sxy,sxx,syy,  num,den) {
    num=n*sxy-sx*sy; den=sqrt((n*sxx-sx*sx)*(n*syy-sy*sy));
    return (den==0) ? 0 : num/den;
  }
  {
    arm=$1; x=$2;
    for (c=1; c<=5; c++) {
      y=$(c+2);
      for (k=1; k<=2; k++) {
        a = (k==1) ? arm : "pooled";
        key=a SUBSEP c;
        N[key]++; SX[key]+=x; SY[key]+=y; SXY[key]+=x*y; SXX[key]+=x*x; SYY[key]+=y*y;
      }
    }
  }
  END {
    split("mechanism actionable specific tradeoff TOTAL", name, " ");
    split("with without pooled", arms, " ");
    printf "%-12s %-10s %6s %8s %10s %10s\n", "dimension", "arm", "n", "r", "mean bytes", "mean score";
    for (c=1; c<=5; c++) {
      for (ai=1; ai<=3; ai++) {
        a=arms[ai]; key=a SUBSEP c;
        if (N[key] < 3) { printf "%-12s %-10s %6d  too few paired samples\n", name[c], a, N[key]; continue }
        printf "%-12s %-10s %6d %8.2f %10d %10.2f\n", name[c], a, N[key],
               pear(N[key],SX[key],SY[key],SXY[key],SXX[key],SYY[key]),
               SX[key]/N[key], SY[key]/N[key];
      }
    }
  }' "$ROWS"
```

- [ ] **Step 2: Make it executable and run it**

```bash
chmod +x tests/quality-uplift/experiments/dimension-length-decomposition.sh
tests/quality-uplift/experiments/dimension-length-decomposition.sh
```
Expected: `Duplicate slots: none`; `Metas read: 42   malformed: 0`; `Answers joined: 42`; `Judgment (id,rep) slots matched to a meta: 21 of 21` with no WARNING line; and a table with 15 rows (5 measures × 3 arms).

The slot count is 21, not 42 or 63: a judgment row scores **both** arms of one `(id, rep)` pair, so 7 cases × 3 reps = 21 slots, each contributing one `with` answer and one `without` answer. If a WARNING prints, some judgments matched no `.meta` and the correlations were computed over less data than the file implies — resolve that before reading any number.

- [ ] **Step 3: THE REPRODUCTION GUARD — verify the TOTAL pooled r matches the published 0.61**

```bash
tests/quality-uplift/experiments/dimension-length-decomposition.sh | grep -E "^TOTAL +pooled"
```
Expected: `r` reads `0.61`.

**If it does not match, stop.** Do not proceed to Task 3, do not interpret any dimension number, and do not adjust the instrument until it produces the expected value — that would be fitting the tool to the answer. Report the discrepancy: it means either the join is wrong, or the published figure was computed differently, and both are findings that must be resolved before anything downstream is trustworthy.

- [ ] **Step 4: Confirm read-only behaviour**

```bash
git status --short tests/quality-uplift/results/
```
Expected: empty. The instrument must not have modified any campaign data.

- [ ] **Step 5: Commit**

```bash
git add tests/quality-uplift/experiments/dimension-length-decomposition.sh
git commit -m "test(quality-uplift): instrumento de descomposicion por dimension

Reproduce el r=0.61 publicado del total como guarda de join antes de
reportar cualquier numero por dimension."
```

---

### Task 3: Save the raw run

**Files:**
- Create: `tests/quality-uplift/experiments/results/dld/run.txt`

**Interfaces:**
- Consumes: the instrument from Task 2.
- Produces: the raw output Task 4 reads its verdict from. Keeping it means the reading can be re-derived or overturned, which is this directory's stated purpose.

- [ ] **Step 1: Run and save**

```bash
mkdir -p tests/quality-uplift/experiments/results/dld
tests/quality-uplift/experiments/dimension-length-decomposition.sh \
  > tests/quality-uplift/experiments/results/dld/run.txt 2>&1
cat tests/quality-uplift/experiments/results/dld/run.txt
```

- [ ] **Step 2: Verify the saved run is complete**

```bash
grep -c "^" tests/quality-uplift/experiments/results/dld/run.txt
grep -E "^(mechanism|actionable|specific|tradeoff|TOTAL)" \
  tests/quality-uplift/experiments/results/dld/run.txt | wc -l
```
Expected: the second count is 15 — five measures across three arms. A smaller number means an arm fell below the three-sample floor and the table is incomplete.

- [ ] **Step 3: Commit**

```bash
git add tests/quality-uplift/experiments/results/dld/run.txt
git commit -m "test(quality-uplift): guardar la corrida cruda de la descomposicion"
```

---

### Task 4: Read the result against the pre-registered rule

**Files:**
- Modify: `tests/quality-uplift/experiments/README.md`
- Modify: `tests/quality-uplift/README.md` (only if the diagnosis resolves — see Step 3)

**Interfaces:**
- Consumes: the raw run from Task 3 and the reading rule committed in Task 1.

**Do not modify the Task 1 reading rule.** It is the standard being applied. If it turns out to have been badly specified, say so in the write-up and leave it as written — an amended rule is not a pre-registered one.

- [ ] **Step 1: Apply the rule, mechanically, before writing prose**

Read the three `specific` rows and the other dimensions' rows from `results/dld/run.txt` and place the result in exactly one row of the pre-registered table:

- all four positive, `specific` included → **judge length-bias**
- `mechanism`/`actionable`/`tradeoff` positive and `|r| < 0.2` for `specific` → **coverage additivity**
- anything else, including disagreement between the `with` and `without` arms → **does not resolve**

Write down which row applies and the numbers that put it there, before writing any explanation of why.

- [ ] **Step 2: Write the result section**

Append to `tests/quality-uplift/experiments/README.md`, under the pre-registration:

- The verdict, naming which row of the rule applies.
- The full table of 15 correlations.
- The caveats that stand, stated as limits and not as hedges: it is **observational** — even a clean split makes one hypothesis more plausible and does not prove causation; `n = 42` answers across 7 cases; it does not measure uplift; and it does not verify the `P2.with.rep3` explanation from spec §3.1, which remains a conjecture about one case.
- If the verdict is "does not resolve", say what would resolve it and stop there. Do not offer a preferred hypothesis as a consolation reading.

- [ ] **Step 3: Update the void-threshold rationale ONLY if the diagnosis resolved**

`tests/quality-uplift/README.md:159-165` currently states that what a high `r` means is unresolved, and forbids citing "judge length-bias" as the established cause.

- If the diagnosis **resolved**, replace that paragraph with what was established, cite this experiment, and keep the threshold in place — a resolved mechanism changes the explanation, not the bar.
- If it **did not resolve**, change nothing there. The existing text is still accurate, and rewriting it on the strength of an inconclusive run is the exact error `experiments/README.md` already warns about: replacing one unverified diagnosis with another.

- [ ] **Step 4: Verify no unsupported claim entered either README**

```bash
grep -n "judge length-bias\|sesgo de longitud" tests/quality-uplift/README.md \
  tests/quality-uplift/experiments/README.md
```
Expected: every hit is either a statement that the label is unsupported, or — only if Step 3 applied — a claim backed by this run's numbers. A bare assertion of the cause is a defect.

- [ ] **Step 5: Commit**

```bash
git add tests/quality-uplift/README.md tests/quality-uplift/experiments/README.md
git commit -m "docs(quality-uplift): registrar el veredicto de la descomposicion por dimension"
```

---

## What invalidates this diagnostic

- The instrument failing to reproduce the published pooled `r = 0.61` for the rubric total, and being adjusted until it does.
- Any edit to the Task 1 reading rule after Task 3 has produced numbers.
- A verdict of "resolved" on a pattern that the pre-registered rule places in the third row.
- Citing this run as establishing causation. It is observational, and the write-up must say so in those words.
- Reading it as a measurement of uplift. It measures what produces a correlation, not whether any skill improves an answer.
- Any modification to `tests/quality-uplift/results/full/`. That data is the evidence; an instrument that writes to it invalidates itself.
