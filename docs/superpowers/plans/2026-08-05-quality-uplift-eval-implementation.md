# Quality-Uplift Eval Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a harness that measures whether an answer produced with a `dataforge` skill beats the same question answered without it, scored blind against a domain rubric, and produce a per-skill uplift table cross-referenced with each skill's token cost.

**Architecture:** Three bash stages over the same ablation the triggering harness already validated. `generate-answers.sh` produces answers in both arms and gates the with-arm on the expected skill actually having fired. `judge-pairs.sh` presents each pair blind to a different model and collects rubric scores as validated JSON. `analyze.sh` computes per-skill deltas plus the two integrity checks that decide whether the run is usable at all: score-vs-length correlation and inter-rep judge agreement.

**Tech Stack:** bash, `jq`, `claude` CLI (`-p`, `--output-format stream-json`, `--json-schema`, `--settings`, `--strict-mcp-config`).

**Spec:** `docs/superpowers/specs/2026-08-05-quality-uplift-eval-design.md` — read it before starting any task.

## Global Constraints

- Answer model: `opus`. Judge model: `sonnet`. Never the same model for both — self-preference.
- Every `claude` invocation must end with `</dev/null` unless stdin is deliberately being used as input. `claude -p` merges piped stdin into the prompt.
- Every answer-generating probe runs from a fresh `mktemp -d` outside this repo. The working directory leaks into session context.
- Every `claude` invocation passes `--strict-mcp-config` (zero MCP servers) and runs serially, waiting for ≥1200 MB of `MemAvailable`. This is a 6 GB WSL2 box that has OOM'd mid-campaign.
- The with-arm and without-arm differ by exactly one variable: `--settings '{"enabledPlugins":{"dataforge@skills-dir":false}}'` on the without-arm only.
- n=3 per arm per case. Single samples lie; this is established in `tests/triggering/README.md`.
- `results/` and `*.log` are gitignored. Commit digests under `baselines/`.
- Rubric dimension keys in code and JSON: `mechanism`, `actionable`, `specific`, `tradeoff`. Integers 0–2.

---

## File Structure

| File | Responsibility |
|---|---|
| `tests/quality-uplift/cases.tsv` | 7 cases: ID, SKILL, PROMPT |
| `tests/quality-uplift/rubric.md` | Judge instructions + rubric. Fed verbatim into the judge prompt. |
| `tests/quality-uplift/generate-answers.sh` | Both arms, n reps, validity gate, per-answer metadata |
| `tests/quality-uplift/check-generate.sh` | Acceptance check for the above: outputs, gate, ablation, leaks |
| `tests/quality-uplift/judge-pairs.sh` | Blind pairwise judging, fixed order schedule, JSON out |
| `tests/quality-uplift/analyze.sh` | Per-skill deltas, length correlation, judge agreement |
| `tests/quality-uplift/README.md` | Methodology, how to run, what invalidates a run |
| `tests/quality-uplift/.gitignore` | `results/`, `*.log` |
| `tests/quality-uplift/baselines/` | Committed digests |

---

### Task 1: Case set, rubric, and directory scaffold

**Files:**
- Create: `tests/quality-uplift/cases.tsv`
- Create: `tests/quality-uplift/rubric.md`
- Create: `tests/quality-uplift/.gitignore`

**Interfaces:**
- Produces: `cases.tsv` with tab-separated columns `ID`, `SKILL`, `PROMPT` and a header row. `rubric.md`, read verbatim by `judge-pairs.sh` in Task 3.

- [ ] **Step 1: Write the case file**

Prompts are copied verbatim from `tests/triggering/matrix.tsv` and `matrix-adversarial.tsv` so no new variables enter. Tab-separated, one header row.

```
ID	SKILL	PROMPT
P1	python-data-engineering	Mi pipeline de ETL en Python se come toda la RAM cuando proceso un CSV de 40GB. ¿Cómo lo arreglo?
P2	sql-data-engineering	This Postgres query with three window functions takes 8 minutes. Help me optimize it.
A4	spark-data-engineering	Tengo un job que procesa una tabla de 2 mil millones de filas en un clúster. Arranca rápido, y al final se queda pegado horas en una sola tarea mientras el resto ya terminó.
P4	modeling-data-engineering	Tengo una fact table de ventas y no sé si declarar el grano a nivel de línea de pedido o de pedido completo. ¿Cómo lo decido?
A2	pipelines-architecture-data-engineering	Relancé el proceso de ayer y ahora hay registros duplicados. ¿Qué hice mal?
A1	quality-data-engineering	Los números del reporte de ventas no cuadran con el sistema origen y nadie se dio cuenta hasta que el cliente reclamó. ¿Cómo evito que vuelva a pasar?
P7	project-structure-data-engineering	Voy a arrancar un paquete nuevo de ingesta en Python. ¿Poetry o uv, y cómo organizo las carpetas?
```

- [ ] **Step 2: Write the rubric**

This text is fed verbatim into the judge prompt. It must never mention skills, plugins, or that two conditions exist.

```markdown
You are evaluating two answers to the same question from a data engineer.
Score each answer on four dimensions, 0 to 2 each.

- mechanism: does it identify the actual cause, rather than restating the symptom?
  0 = restates the symptom. 1 = gestures at a plausible cause. 2 = names the
  specific mechanism and why it produces this symptom.
- actionable: is there a concrete next step the engineer can execute?
  0 = none. 1 = a direction without specifics. 2 = a specific step, with the
  command, setting, or code shape needed.
- specific: does it avoid generic filler?
  0 = mostly generic advice that would fit any problem. 1 = mixed.
  2 = every recommendation is particular to this problem.
- tradeoff: does it state the cost or risk of what it proposes?
  0 = no. 1 = mentions a caveat vaguely. 2 = names a concrete cost, limit, or
  failure mode of its own recommendation.

Then state which answer is more useful to a senior data engineer: "A", "B", or "tie".

Rules:
- Length is not quality. A shorter answer that names the mechanism beats a longer
  one that lists possibilities. Do not reward volume, formatting, or headings.
- Both answers were produced under identical conditions. Ignore any mention of
  missing files, unavailable code, or filesystem paths — neither answer had access
  to the engineer's actual code.
- Judge only the two answers in front of you. Do not speculate about their origin.
```

- [ ] **Step 3: Write the gitignore**

```
results/
*.log
```

- [ ] **Step 4: Verify the case file parses and is complete**

Run:
```bash
cd tests/quality-uplift
awk -F'\t' 'NR>1{n++; if (NF!=3) print "BAD FIELD COUNT line "NR} END{print n" cases"}' cases.tsv
cut -f2 cases.tsv | tail -n +2 | sort > /tmp/eval-skills.txt
ls ../../skills | sort > /tmp/repo-skills.txt
comm -23 /tmp/eval-skills.txt /tmp/repo-skills.txt
```
Expected: `7 cases`, no `BAD FIELD COUNT` lines, and empty `comm` output — every SKILL value names a directory that exists under `skills/`.

- [ ] **Step 5: Commit**

```bash
git add tests/quality-uplift/cases.tsv tests/quality-uplift/rubric.md tests/quality-uplift/.gitignore
git commit -m "test(quality-uplift): add case set and judging rubric"
```

---

### Task 2: Answer generation with a validity gate

**Files:**
- Create: `tests/quality-uplift/generate-answers.sh`

**Interfaces:**
- Consumes: `cases.tsv` from Task 1.
- Produces, for each case/arm/rep, in `results/<run>/`:
  - `<ID>.<arm>.rep<N>.txt` — the answer text only
  - `<ID>.<arm>.rep<N>.meta` — one tab-separated line: `ID`, `arm`, `rep`, `chain` (comma-joined skill names or `NONE`), `chars`, `output_tokens`, `cost_usd`, `attempts`
  - `discards.tsv` — one line per rejected sample: `ID`, `arm`, `rep`, `attempt`, `chain`.
    The last field is the observed chain when the sample was rejected for routing, or the
    literal `EMPTY` when it was rejected for producing no answer text.

  Task 3 reads the `.txt` files. Task 4 reads the `.meta` and `discards.tsv` files.

- [ ] **Step 1: Write the acceptance check**

The deliverable here is a script, so the failing test is an acceptance check that
asserts on its observable outputs. Write it first, at
`tests/quality-uplift/check-generate.sh`:

```bash
#!/usr/bin/env bash
# Acceptance check for generate-answers.sh. Asserts on observable outputs only.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
RUN="results/acceptance"
fail=0
note() { printf '%s %s\n' "$1" "$2"; [[ "$1" == "FAIL" ]] && fail=1; }

rm -rf "$RUN"
./generate-answers.sh -c P4 -r 1 -o "$RUN" >/dev/null 2>&1

[[ -s "$RUN/P4.with.rep1.txt" ]] \
  && note PASS "with-arm answer is non-empty" \
  || note FAIL "with-arm answer missing or empty"

[[ -s "$RUN/P4.without.rep1.txt" ]] \
  && note PASS "without-arm answer is non-empty" \
  || note FAIL "without-arm answer missing or empty"

if [[ -f "$RUN/P4.with.rep1.meta" ]]; then
  IFS=$'\t' read -r _id _arm _rep chain chars _t _c _a < "$RUN/P4.with.rep1.meta"
  [[ ",$chain," == *",modeling-data-engineering,"* ]] \
    && note PASS "validity gate accepted: expected skill in chain ($chain)" \
    || note FAIL "expected skill not in chain ($chain)"
  [[ "$chars" -gt 200 ]] \
    && note PASS "answer length recorded ($chars chars)" \
    || note FAIL "answer length implausible ($chars)"
else
  note FAIL "with-arm meta missing"
fi

cut -f4 "$RUN/P4.without.rep1.meta" 2>/dev/null | grep -q "data-engineering" \
  && note FAIL "without-arm loaded a suite skill — ablation broken" \
  || note PASS "without-arm loaded no suite skill"

grep -l "qprobe-\|cases.tsv\|EXPECTED" "$RUN"/*.txt >/dev/null 2>&1 \
  && note FAIL "scaffolding leaked into an answer" \
  || note PASS "no scaffolding leak"

exit $fail
```

- [ ] **Step 2: Run the acceptance check and watch it fail**

Run: `cd tests/quality-uplift && chmod +x check-generate.sh && ./check-generate.sh`
Expected: exits non-zero with `FAIL` lines — `generate-answers.sh` does not exist yet,
so no answers, no meta files.

- [ ] **Step 3: Write the script**

```bash
#!/usr/bin/env bash
# Generate answers for the quality-uplift eval in both arms.
#
# with-arm samples are only accepted when the case's expected skill actually
# fired, checked across the whole invocation chain. A sample where it never
# fired is not a measurement of the skill; it is noise, and averaging it in
# would understate the very thing being measured.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASES="${CASES:-$SCRIPT_DIR/cases.tsv}"   # overridable so the gate test can inject a fixture
PLUGIN_ID="dataforge@skills-dir"
ANSWER_MODEL="opus"
REPS=3
MAX_ATTEMPTS=3
MIN_AVAIL_MB=1200
RUN=""

while getopts "r:m:n:o:c:" opt; do
  case "$opt" in
    r) REPS="$OPTARG" ;;
    m) ANSWER_MODEL="$OPTARG" ;;
    n) MAX_ATTEMPTS="$OPTARG" ;;
    o) RUN="$OPTARG" ;;
    c) ONLY_CASE="${OPTARG}" ;;
    *) echo "unknown option" >&2; exit 64 ;;
  esac
done
ONLY_CASE="${ONLY_CASE:-}"
[[ -n "$RUN" ]] || RUN="$SCRIPT_DIR/results/run"
mkdir -p "$RUN"
: > "$RUN/discards.tsv"

await_memory() {
  local avail
  for _ in $(seq 1 120); do
    avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
    (( avail >= MIN_AVAIL_MB )) && return 0
    echo "  waiting for memory: ${avail}MB" >&2
    sleep 10
  done
}

# Runs one probe. Echoes: <chain>\t<chars>\t<out_tokens>\t<cost>
# Writes the answer text to $4.
probe() {
  local prompt="$1" arm="$2" tag="$3" out_txt="$4"
  local log="$RUN/$tag.jsonl" sandbox
  local settings_args=()
  [[ "$arm" == "without" ]] && \
    settings_args=(--settings "{\"enabledPlugins\":{\"$PLUGIN_ID\":false}}")

  await_memory
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/qprobe-XXXXXX")"
  ( cd "$sandbox" && timeout 900 claude \
      --model "$ANSWER_MODEL" \
      --output-format stream-json --verbose \
      --strict-mcp-config \
      --disallowedTools "Bash" "Write" "Edit" "Task" \
      "${settings_args[@]}" \
      -p "$prompt" ) >"$log" 2>&1 </dev/null
  rm -rf "$sandbox"

  jq -r 'select(.type=="result") | .result // ""' "$log" > "$out_txt" 2>/dev/null

  local chain chars toks cost
  chain=$(jq -r 'select(.type=="assistant") | .message.content[]?
                 | select(.type=="tool_use" and .name=="Skill") | .input.skill' \
          "$log" 2>/dev/null | sed 's/^dataforge://' | paste -sd, -)
  [[ -n "$chain" ]] || chain="NONE"
  chars=$(wc -c < "$out_txt" | tr -d ' ')
  toks=$(jq -r 'select(.type=="result") | .usage.output_tokens // 0' "$log" 2>/dev/null | head -1)
  cost=$(jq -r 'select(.type=="result") | .total_cost_usd // 0' "$log" 2>/dev/null | head -1)
  printf '%s\t%s\t%s\t%s\n' "$chain" "$chars" "$toks" "$cost"
}

while IFS=$'\t' read -r id skill prompt; do
  [[ "$id" == "ID" || -z "${id// }" ]] && continue
  [[ -n "$ONLY_CASE" && "$id" != "$ONLY_CASE" ]] && continue

  for arm in with without; do
    for (( rep=1; rep<=REPS; rep++ )); do
      tag="$id.$arm.rep$rep"
      accepted=0
      for (( att=1; att<=MAX_ATTEMPTS; att++ )); do
        read -r chain chars toks cost < <(probe "$prompt" "$arm" "$tag" "$RUN/$tag.txt")

        # Non-emptiness floor, both arms. An empty answer is an infrastructure
        # failure, not a measurement: a timeout kill or a log with no result
        # event leaves a 0-byte file that would otherwise be written up as a
        # well-formed sample and averaged in as if it were a real answer.
        if [[ ! -s "$RUN/$tag.txt" ]]; then
          printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$arm" "$rep" "$att" "EMPTY" \
            >> "$RUN/discards.tsv"
          echo "  discard $tag attempt $att: empty answer" >&2
          continue
        fi

        # The without-arm has no ROUTING gate: its natural behaviour, including a
        # superpowers process skill answering instead, is the counterfactual, and
        # rejecting a sample for not loading a skill would destroy it.
        if [[ "$arm" == "without" ]]; then accepted=1; break; fi

        if [[ ",$chain," == *",$skill,"* ]]; then accepted=1; break; fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$arm" "$rep" "$att" "$chain" \
          >> "$RUN/discards.tsv"
        echo "  discard $tag attempt $att: $skill never fired (chain=$chain)" >&2
      done

      if (( accepted )); then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$id" "$arm" "$rep" "$chain" "$chars" "$toks" "$cost" "$att" \
          > "$RUN/$tag.meta"
        echo "  ok $tag chain=$chain chars=$chars" >&2
      else
        rm -f "$RUN/$tag.txt"
        echo "  UNMEASURABLE $tag after $MAX_ATTEMPTS attempts" >&2
      fi
    done
  done
done < "$CASES"

echo "run=$RUN" >&2
ls "$RUN"/*.meta 2>/dev/null | wc -l | xargs -I{} echo "accepted samples: {}" >&2
```

- [ ] **Step 4: Run the acceptance check and watch it pass**

```bash
cd tests/quality-uplift && chmod +x generate-answers.sh
./check-generate.sh; echo "exit=$?"
```
Expected: every line `PASS`, `exit=0`. This one run covers the answer extraction, the
validity gate accepting, the length metadata, the ablation holding in the without-arm,
and the absence of scaffolding leaks.

If the with-arm assertion fails because `modeling-data-engineering` did not fire, that is
a real routing miss, not a harness bug — re-run once. P4 is 5/5 in
`tests/triggering/baselines/GREEN-crowd-out.md`, so a repeated miss means something
changed in the suite and must be reported, not worked around.

- [ ] **Step 5: Produce the smoke run that Task 3 and Task 4 consume**

```bash
cd tests/quality-uplift
./generate-answers.sh -c P4 -r 1 -o results/smoke
```
Expected: two `ok` lines, and four files — `P4.{with,without}.rep1.{txt,meta}`.

- [ ] **Step 6: Verify the validity gate rejects, not just accepts**

Force a rejection by asking for a skill the case can never trigger:
```bash
cd tests/quality-uplift
printf 'ID\tSKILL\tPROMPT\n' > /tmp/gate-test.tsv
printf 'GATE\tspark-data-engineering\t¿Poetry o uv para un paquete nuevo?\n' >> /tmp/gate-test.tsv
CASES=/tmp/gate-test.tsv ./generate-answers.sh -c GATE -r 1 -n 1 -o results/gate 2>&1 | grep -E "discard|UNMEASURABLE"
```
Expected: a `discard` line and an `UNMEASURABLE` line, and `results/gate/GATE.with.rep1.meta` must not exist.

This step is the one that matters most in this task. A gate that only ever accepts is not
a gate, and an eval that silently averages in samples where the skill never fired would
understate exactly what it is trying to measure.

- [ ] **Step 7: Commit**

```bash
git add tests/quality-uplift/generate-answers.sh tests/quality-uplift/check-generate.sh
git commit -m "test(quality-uplift): generate answers in both arms with a validity gate"
```

---

### Task 3: Blind pairwise judging

**Files:**
- Create: `tests/quality-uplift/judge-pairs.sh`

**Interfaces:**
- Consumes: `<ID>.with.rep<N>.txt` and `<ID>.without.rep<N>.txt` from Task 2; `rubric.md` from Task 1.
- Produces: `judgments.jsonl` in the run directory. One object per judging rep:
  `{id, rep, judge_rep, first ("with"|"without"), with: {mechanism, actionable, specific, tradeoff}, without: {...}, more_useful ("with"|"without"|"tie"), reason}`
  `rep` is the answer-sample number; `judge_rep` is which of the three judging
  passes produced this row. The `A`/`B` labels the judge sees are mapped back to
  arms before writing. Task 4 reads this file.

- [ ] **Step 1: Write the script**

Answers are passed on stdin, not interpolated into the prompt: they are long, contain quotes and newlines, and `claude -p` merges stdin into the prompt anyway.

```bash
#!/usr/bin/env bash
# Judge with/without answer pairs blind, three reps per pair.
#
# Order schedule per pair: rep1 with-first, rep2 without-first, rep3 with-first.
# Two orders across three reps detects position bias while leaving no pair
# scored under a single order only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JUDGE_MODEL="sonnet"
JUDGE_REPS=3
RUN=""

while getopts "o:m:r:" opt; do
  case "$opt" in
    o) RUN="$OPTARG" ;;
    m) JUDGE_MODEL="$OPTARG" ;;
    r) JUDGE_REPS="$OPTARG" ;;
    *) echo "unknown option" >&2; exit 64 ;;
  esac
done
[[ -n "$RUN" ]] || { echo "usage: judge-pairs.sh -o <run-dir>" >&2; exit 64; }

SCHEMA='{"type":"object","properties":{
"a":{"type":"object","properties":{"mechanism":{"type":"integer"},"actionable":{"type":"integer"},"specific":{"type":"integer"},"tradeoff":{"type":"integer"}},"required":["mechanism","actionable","specific","tradeoff"]},
"b":{"type":"object","properties":{"mechanism":{"type":"integer"},"actionable":{"type":"integer"},"specific":{"type":"integer"},"tradeoff":{"type":"integer"}},"required":["mechanism","actionable","specific","tradeoff"]},
"more_useful":{"type":"string","enum":["A","B","tie"]},
"reason":{"type":"string"}},
"required":["a","b","more_useful","reason"]}'

judge_once() {
  local a_file="$1" b_file="$2"
  { cat "$SCRIPT_DIR/rubric.md"
    echo; echo "=== ANSWER A ==="; echo; cat "$a_file"
    echo; echo "=== ANSWER B ==="; echo; cat "$b_file"
  } | timeout 600 claude --model "$JUDGE_MODEL" --strict-mcp-config \
        --json-schema "$SCHEMA" \
        -p "Score both answers per the rubric above and return only the JSON object." \
        2>/dev/null
}

: > "$RUN/judgments.jsonl"
for with_txt in "$RUN"/*.with.rep*.txt; do
  [[ -f "$with_txt" ]] || continue
  base="$(basename "$with_txt")"; id="${base%%.*}"; rep="${base##*.rep}"; rep="${rep%.txt}"
  without_txt="$RUN/$id.without.rep$rep.txt"
  [[ -f "$without_txt" ]] || { echo "  skip $id rep$rep: no without-arm answer" >&2; continue; }

  for (( jr=1; jr<=JUDGE_REPS; jr++ )); do
    if (( jr == 2 )); then first="without"; a="$without_txt"; b="$with_txt"
    else first="with"; a="$with_txt"; b="$without_txt"; fi

    raw="$(judge_once "$a" "$b")"
    [[ -n "$raw" ]] || { echo "  judge failed $id rep$rep jr$jr" >&2; continue; }

    # Map the blind A/B labels back to arms.
    echo "$raw" | jq -c --arg id "$id" --arg rep "$rep" --arg jr "$jr" --arg first "$first" '
      if $first == "with"
      then {id:$id, rep:($rep|tonumber), judge_rep:($jr|tonumber), first:$first,
            with:.a, without:.b,
            more_useful:(if .more_useful=="A" then "with" elif .more_useful=="B" then "without" else "tie" end),
            reason:.reason}
      else {id:$id, rep:($rep|tonumber), judge_rep:($jr|tonumber), first:$first,
            with:.b, without:.a,
            more_useful:(if .more_useful=="B" then "with" elif .more_useful=="A" then "without" else "tie" end),
            reason:.reason}
      end' >> "$RUN/judgments.jsonl"
    echo "  judged $id rep$rep jr$jr first=$first" >&2
  done
done

wc -l < "$RUN/judgments.jsonl" | xargs -I{} echo "judgments: {}" >&2
```

- [ ] **Step 2: Calibration test — does the judge discriminate at all?**

Build a pair where the winner is unambiguous. If the judge cannot call this, no result from it is trustworthy.

```bash
cd tests/quality-uplift && chmod +x judge-pairs.sh
mkdir -p results/calib
cat > results/calib/CAL.with.rep1.txt <<'EOF'
One task running far longer than the rest is almost always key skew: one join
key holds a disproportionate share of rows, so a single partition does most of
the work. Confirm it in the Spark UI — look at the task duration distribution
for the stage, and at max vs median shuffle read bytes.

If the smaller side fits in executor memory, use a broadcast join and the shuffle
disappears. If not, salt the skewed key: add a random suffix over N buckets on
both sides, join, then aggregate away the salt. On Spark 3.x,
spark.sql.adaptive.skewJoin.enabled handles the common case automatically.

Cost: salting multiplies the small side by N and adds a second aggregation, so it
trades a bounded amount of extra shuffle for removing the straggler. Do not salt
before confirming skew — if the cause is a slow UDF, salting adds work and fixes
nothing.
EOF
cat > results/calib/CAL.without.rep1.txt <<'EOF'
This sounds like a performance problem. There are several things you could look
at. First, check your cluster configuration and make sure the resources are
sized appropriately for the workload. You may also want to review your code for
any inefficiencies, and consider whether caching would help.

It is also worth checking the logs for errors or warnings, and monitoring
resource utilisation while the job runs. Tuning the number of partitions can
sometimes help as well. If the problem persists, consider consulting the Spark
documentation or upgrading to a newer version.
EOF
./judge-pairs.sh -o results/calib -r 3
jq -c '{judge_rep, first, more_useful, with_total:(.with|add), without_total:(.without|add)}' results/calib/judgments.jsonl
```
Expected: `more_useful` is `"with"` in all 3 reps, and `with_total` exceeds `without_total` in all 3. If not, stop — the judge or rubric is broken and no campaign should run.

- [ ] **Step 3: Calibration test — is the judge length-biased?**

Same generic answer as before, but padded to be much longer than the good one. The `with`/`without` filenames are deliberately inverted here so the *bad* answer occupies the `with` slot: this checks the judge, not the arms.

```bash
cd tests/quality-uplift
mkdir -p results/calib-len
cp results/calib/CAL.with.rep1.txt results/calib-len/CAL.without.rep1.txt
{ cat results/calib/CAL.without.rep1.txt
  echo; echo "## Additional considerations"; echo
  for i in 1 2 3 4 5 6; do
    echo "### Area $i"
    echo "Review this area carefully and apply standard best practices. Ensure"
    echo "monitoring is in place and revisit the configuration periodically."
    echo
  done
} > results/calib-len/CAL.with.rep1.txt
wc -c results/calib-len/CAL.*.rep1.txt
./judge-pairs.sh -o results/calib-len -r 3
jq -c '{more_useful, with_total:(.with|add), without_total:(.without|add)}' results/calib-len/judgments.jsonl
```
Expected: `more_useful` is `"without"` in all 3 reps — the shorter, specific answer wins despite being roughly half the length. If the padded answer wins any rep, record it: the judge is length-biased and §6.2 of the spec requires the judging design be reworked before the campaign counts.

- [ ] **Step 4: Commit**

```bash
git add tests/quality-uplift/judge-pairs.sh
git commit -m "test(quality-uplift): add blind pairwise judging with calibration tests"
```

---

### Task 4: Analysis and integrity checks

**Files:**
- Create: `tests/quality-uplift/analyze.sh`

**Interfaces:**
- Consumes: `judgments.jsonl` and `*.meta` from the run directory.
- Produces: a markdown report on stdout with five sections — per-skill uplift, score-vs-length correlation, judge agreement, judge coherence, and discard rate.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Report per-skill uplift plus the checks that decide whether the run is usable.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="${1:?usage: analyze.sh <run-dir>}"
CASES="$SCRIPT_DIR/cases.tsv"

echo "# Quality-uplift report"
echo
echo "Run: \`$RUN\`.  Primary metric: rubric delta (with − without), max 8 per answer."
echo

echo "## Uplift per skill"
echo
printf '| case | skill | with | without | delta | prefers with |\n'
printf '|---|---|---|---|---|---|\n'
while IFS=$'\t' read -r id skill _prompt; do
  [[ "$id" == "ID" || -z "${id// }" ]] && continue
  jq -r --arg id "$id" --arg skill "$skill" '
    select(.id==$id)' "$RUN/judgments.jsonl" 2>/dev/null \
  | jq -s -r --arg id "$id" --arg skill "$skill" '
      if length==0 then "| \($id) | \($skill) | – | – | – | not measurable |"
      else
        (map(.with|add)|add/length) as $w |
        (map(.without|add)|add/length) as $o |
        (map(select(.more_useful=="with"))|length) as $pw |
        "| \($id) | \($skill) | \($w*10|round/10) | \($o*10|round/10) | \(($w-$o)*10|round/10) | \($pw)/\(length) |"
      end'
done < "$CASES"
echo

echo "## Score vs length"
echo
echo "If the delta tracks verbosity, the result is void (spec §6.2)."
echo
{ for m in "$RUN"/*.meta; do
    [[ -f "$m" ]] || continue
    IFS=$'\t' read -r id arm rep _chain chars _toks _cost _att < "$m"
    tot=$(jq -r --arg id "$id" --arg rep "$rep" --arg arm "$arm" '
            select(.id==$id and .rep==($rep|tonumber))
            | (if $arm=="with" then .with else .without end) | add' \
          "$RUN/judgments.jsonl" 2>/dev/null | jq -s 'if length==0 then empty else add/length end')
    [[ -n "$tot" ]] && printf '%s\t%s\n' "$chars" "$tot"
  done; } | awk -F'\t' '
    {n++; sx+=$1; sy+=$2; sxy+=$1*$2; sxx+=$1*$1; syy+=$2*$2}
    END{
      if (n<3) {print "  too few paired samples (n="n")"; exit}
      num=n*sxy-sx*sy; den=sqrt((n*sxx-sx*sx)*(n*syy-sy*sy));
      r = (den==0) ? 0 : num/den;
      printf "  n=%d  pearson r(chars, rubric total) = %.2f\n", n, r;
      if (r>0.5) print "  WARNING: scores track length. Rework judging before trusting deltas.";
    }'
echo

echo "## Judge agreement"
echo
echo "Reps 1 and 3 use the same order; rep 2 is inverted. Disagreement between"
echo "1 and 3 is judge noise; disagreement with 2 suggests position bias."
echo
jq -s -r '
  group_by(.id) | map({
    id: .[0].id,
    verdicts: (sort_by(.judge_rep) | map(.more_useful) | join(","))
  }) | .[] | "  \(.id): \(.verdicts)"' "$RUN/judgments.jsonl" 2>/dev/null
echo

echo "## Judge coherence"
echo
echo "Spec §6.1: a row that scores one answer higher but prefers the other is"
echo "internally inconsistent, and that pair does not count."
echo
jq -s -r '
  map(select(.more_useful != "tie"))
  | map(. + {wt:(.with|add), ot:(.without|add)})
  | map(select((.more_useful=="with" and .wt < .ot) or
               (.more_useful=="without" and .ot < .wt)))
  | if length==0 then "  none — all rows coherent"
    else (map("  INCOHERENT \(.id) rep\(.rep) jr\(.judge_rep): prefers \(.more_useful) but scored \(.wt) vs \(.ot)") | join("\n"))
    end' "$RUN/judgments.jsonl" 2>/dev/null
echo

echo "## Discards"
echo
echo "with-arm samples rejected because the expected skill never fired:"
if [[ -s "$RUN/discards.tsv" ]]; then
  awk -F'\t' '{c[$1]++} END{for (k in c) printf "  %s: %d\n", k, c[k]}' "$RUN/discards.tsv"
else
  echo "  none"
fi
```

- [ ] **Step 2: Verify on the calibration fixture**

The calibration run has judgments but no `.meta` files, which exercises the empty-branch paths.

```bash
cd tests/quality-uplift && chmod +x analyze.sh
./analyze.sh results/calib
```
Expected: the report renders; `CAL` is absent from the per-skill table because it is not in `cases.tsv`; the length section prints `too few paired samples`; the agreement section shows `CAL: with,with,with`; coherence shows `none — all rows coherent`; discards shows `none`. No `jq` or `awk` errors.

- [ ] **Step 3: Verify on the smoke run from Task 2**

```bash
cd tests/quality-uplift
./judge-pairs.sh -o results/smoke -r 3
./analyze.sh results/smoke
```
Expected: `P4` has numeric with/without/delta values and a `prefers with` count out of 3; the other six cases show `not measurable`; discards renders.

- [ ] **Step 4: Commit**

```bash
git add tests/quality-uplift/analyze.sh
git commit -m "test(quality-uplift): add uplift analysis with length and agreement checks"
```

---

### Task 5: Full campaign, README, and digest

**Files:**
- Create: `tests/quality-uplift/README.md`
- Create: `tests/quality-uplift/baselines/2026-08-05-uplift.md`

**Interfaces:**
- Consumes: all three scripts.
- Produces: the committed digest and the methodology doc.

- [ ] **Step 1: Confirm both calibration gates passed**

Re-read the output of Task 3 Steps 2 and 3. If the judge failed either gate, stop and report instead of running the campaign — a campaign judged by a broken judge produces numbers that look authoritative and mean nothing.

- [ ] **Step 2: Run the campaign**

Roughly 42 answer sessions on opus plus 63 judgments on sonnet; expect ~45 minutes and ~$16 at the per-answer cost observed while writing this plan (`total_cost_usd` ≈ 0.33 for one opus answer). Serial by design.

```bash
cd tests/quality-uplift
nohup ./generate-answers.sh -r 3 -o results/full > full-answers.log 2>&1 &
```
Watch: `grep -E "ok |discard|UNMEASURABLE" full-answers.log`
Expected: 42 `ok` lines, or fewer with matching `UNMEASURABLE` lines.

- [ ] **Step 3: Judge and analyze**

```bash
cd tests/quality-uplift
nohup ./judge-pairs.sh -o results/full -r 3 > full-judge.log 2>&1 &
# when it finishes:
./analyze.sh results/full | tee baselines/2026-08-05-uplift.md
```
Expected: 63 judgments; the report shows a delta per skill.

- [ ] **Step 4: Add the cost column by hand**

Append each skill's on-invoke token cost from `claude plugin details dataforge@skills-dir` to the digest, so uplift reads against what it costs. Per spec §7.1, a small delta at 3.7k tokens per invocation does not earn its cost.

```bash
claude plugin details dataforge@skills-dir | sed -n '/Per-component/,$p'
```

- [ ] **Step 5: Write the README**

Cover: what this measures and what it does not (spec §2), the three contamination guards and why each exists, the two calibration gates and that a campaign is void if either fails, the validity gate on the with-arm, and the rule that `results/` is regenerable while `baselines/` is the committed record.

- [ ] **Step 6: Commit**

```bash
git add tests/quality-uplift/README.md tests/quality-uplift/baselines/2026-08-05-uplift.md
git commit -m "test(quality-uplift): record first uplift campaign and methodology"
```

---

## What invalidates this eval

State these plainly in the README, and in any report of the numbers:

- Either calibration gate failing (Task 3 Steps 2–3).
- Pearson r above 0.5 between answer length and rubric total.
- A case whose with-arm samples never passed the validity gate — report it as not measurable rather than filling it in.
- Fewer than 3 accepted samples per arm for a case.
