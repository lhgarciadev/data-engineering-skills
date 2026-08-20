#!/usr/bin/env bash
# The three copies of the chain extractor must agree on what "the skill fired" means.
#
# `run-matrix.sh`, `rescore.sh` and `quality-uplift/generate-answers.sh` each carry their
# own copy of the jq filter that reads a probe log and returns the skills a session
# invoked. That filter IS the operational definition of the measurement, so if the copies
# drift the two harnesses disagree about what they measured — silently, and in a way no
# verdict would reveal.
#
# The backlog proposed extracting a shared `tests/lib/probe.sh`. This checks agreement
# instead, which costs one file rather than an edit to three call sites (one of them in a
# harness nobody re-runs) and, unlike a refactor, can itself be demonstrated failing.
# Extraction stays available the day there is a third reason to touch all three.
#
# Two checks, because one is not enough. The first version of this gate compared only
# BEHAVIOUR on a fixture, and a mutation of `.input.skill` into
# `.input.skill? // .input.name` passed it: the fixture always populates `skill`, so the
# fallback never fires and both copies emit the same thing. A gate that cannot see the
# difference reports agreement — the defect family this directory exists for. So:
#
#   1. The filter TEXT must be identical across the three, whitespace-normalised. These
#      are meant to be copies of one definition, so sameness is the real invariant, and
#      it holds regardless of what any fixture happens to exercise. Reformatting passes.
#   2. The filter BEHAVIOUR on a fixture must match, which is what makes a failure
#      readable instead of just a diff.
#
# Requires jq and python3 (python3 only to lift the filter out of each script).
# Exit 0 = the three agree. Exit 1 = they do not, and it says how.

set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

SCRIPTS=(
  tests/triggering/run-matrix.sh
  tests/triggering/rescore.sh
  tests/quality-uplift/generate-answers.sh
)

for f in "${SCRIPTS[@]}"; do
  [ -f "$f" ] || { echo "chain-extractor: falta $f"; exit 2; }
done
command -v jq >/dev/null || { echo "chain-extractor: jq no esta instalado"; exit 2; }

FIX="$(mktemp -d "${TMPDIR:-/tmp}/chainfix-XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

# A chain with: a process skill, a dataforge-prefixed domain skill, a bare-named skill,
# and a non-Skill tool_use that every copy must filter out.
cat > "$FIX/probe.jsonl" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"superpowers:brainstorming"}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/x/references/y.md"}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"dataforge:modeling-data-engineering"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","content":"ignorame"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"research"}}]}}
JSONL

# Lift the jq program that mentions name=="Skill" out of a script. Single-quoted jq
# programs only, which is what all three use.
lift_filter() {
  python3 - "$1" <<'PY'
import io, re, sys
src = io.open(sys.argv[1], encoding="utf-8").read()
progs = re.findall(r"jq -r '(.*?)'", src, re.S)
hits = [p for p in progs if 'name=="Skill"' in p]
if len(hits) != 1:
    sys.stderr.write("expected exactly one Skill filter, found %d\n" % len(hits))
    sys.exit(3)
print(hits[0])
PY
}

# Collapse every run of whitespace so a line-break move is not a finding.
normalise() { tr '\n' ' ' | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'; }

FAILED=0
declare -a OUTS=() PROGS=()
for f in "${SCRIPTS[@]}"; do
  prog="$(lift_filter "$f")" || { echo "chain-extractor: no pude extraer el filtro de $f"; exit 2; }
  PROGS+=("$(printf '%s' "$prog" | normalise)")
  out="$(jq -r "$prog" "$FIX/probe.jsonl" 2>/dev/null | sed 's/^dataforge://' | paste -sd, -)"
  OUTS+=("$out")
  printf '  %-46s %s\n' "$(basename "$f")" "$out"
  # The dataforge: strip is part of the definition, not presentation: without it the same
  # skill reads as two different names depending on which copy measured it.
  grep -q "s/\^dataforge://" "$f" || {
    echo "chain-extractor: $f no normaliza el prefijo dataforge:"
    FAILED=1
  }
done

for i in 1 2; do
  if [ "${PROGS[$i]}" != "${PROGS[0]}" ]; then
    echo "chain-extractor: el filtro de ${SCRIPTS[$i]} no es el mismo que el de ${SCRIPTS[0]}"
    echo "    ${SCRIPTS[0]}: ${PROGS[0]}"
    echo "    ${SCRIPTS[$i]}: ${PROGS[$i]}"
    FAILED=1
  fi
  if [ "${OUTS[$i]}" != "${OUTS[0]}" ]; then
    echo "chain-extractor: ${SCRIPTS[$i]} mide distinto que ${SCRIPTS[0]} sobre el fixture"
    echo "    ${SCRIPTS[0]}: ${OUTS[0]}"
    echo "    ${SCRIPTS[$i]}: ${OUTS[$i]}"
    FAILED=1
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo
  echo "Las tres copias definen la medicion. Si una cambia a proposito, cambialas las tres"
  echo "en el mismo commit — o extrae tests/lib/probe.sh y dejalas de duplicar."
  exit 1
fi
echo "chain-extractor: las tres copias coinciden"
exit 0
