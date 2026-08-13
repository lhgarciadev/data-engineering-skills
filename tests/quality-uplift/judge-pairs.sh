#!/usr/bin/env bash
# Judge with/without answer pairs blind, three reps per pair.
#
# Order schedule per pair: rep1 with-first, rep2 without-first, rep3 with-first.
# Two orders across three reps detects position bias while leaving no pair
# scored under a single order only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="dataforge@skills-dir"
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

# One writer per run directory, enforced here rather than by an operator check.
# `mkdir` on an existing directory fails atomically, so two concurrent judging
# runs cannot both proceed — during the 2026-08-05 campaign they did, and both
# appended to the same judgments.jsonl.
mkdir "$RUN/.lock" 2>/dev/null || {
  echo "refusing to start: $RUN/.lock exists — another writer holds this run directory" >&2
  echo "(if no writer is running, remove it: rmdir $RUN/.lock)" >&2
  exit 69; }
trap 'rmdir "$RUN/.lock" 2>/dev/null' EXIT

SCHEMA='{"type":"object","properties":{
"a":{"type":"object","properties":{"mechanism":{"type":"integer"},"actionable":{"type":"integer"},"assumptions":{"type":"integer"},"tradeoff":{"type":"integer"}},"required":["mechanism","actionable","assumptions","tradeoff"],"additionalProperties":false},
"b":{"type":"object","properties":{"mechanism":{"type":"integer"},"actionable":{"type":"integer"},"assumptions":{"type":"integer"},"tradeoff":{"type":"integer"}},"required":["mechanism","actionable","assumptions","tradeoff"],"additionalProperties":false},
"more_useful":{"type":"string","enum":["A","B","tie"]},
"reason":{"type":"string"}},
"required":["a","b","more_useful","reason"]}'

# Blinding is structural, not just a matter of what the prompt says.
#
# The rubric and both answers arrive on stdin — the one deliberate stdin use in
# either harness — so the judge needs nothing from the filesystem. It therefore
# gets nothing: no Read/Glob/Grep/Bash, a fresh cwd outside the repo, and the
# suite plugin disabled. Run from the operator's cwd with those tools, a judge
# sitting in tests/quality-uplift could read cases.tsv (which names the expected
# skill per case), the answer logs, or the `with`/`without` filenames under
# results/ — and could load the very skills it is scoring. No judge session log
# is kept, so "it probably didn't look" is not verifiable after the fact; the
# only defence that can be audited is the one in the invocation.
judge_once() {
  local a_file="$1" b_file="$2" sandbox
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/qjudge-XXXXXX")"
  { cat "$SCRIPT_DIR/rubric.md"
    echo; echo "=== ANSWER A ==="; echo; cat "$a_file"
    echo; echo "=== ANSWER B ==="; echo; cat "$b_file"
  } | ( cd "$sandbox" && timeout 600 claude --model "$JUDGE_MODEL" --strict-mcp-config \
        --disallowedTools "Bash" "Read" "Write" "Edit" "Task" "Glob" "Grep" \
        --settings "{\"enabledPlugins\":{\"$PLUGIN_ID\":false}}" \
        --json-schema "$SCHEMA" \
        -p "Score both answers per the rubric above and return only the JSON object." \
        2>/dev/null )
  rm -rf "$sandbox"
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
    [[ -n "$raw" ]] || { echo "  judge empty $id rep$rep jr$jr" >&2
                         printf '%s\t%s\t%s\tempty reply\n' "$id" "$rep" "$jr" \
                           >> "$RUN/judge-failures.tsv"; continue; }

    # Map the blind A/B labels back to arms.
    #
    # The jq result is captured and checked rather than appended straight to the
    # file. A judge reply that is truncated but non-empty — a timeout mid-JSON —
    # passes the emptiness check above and then parses to nothing. Without this
    # guard the row vanishes from judgments.jsonl while the success line below
    # still prints, and the analysis cannot tell a lost row from a legitimate
    # skip. `set -uo pipefail` has no -e, so the failure would not stop the loop.
    row="$(echo "$raw" | jq -c --arg id "$id" --arg rep "$rep" --arg jr "$jr" --arg first "$first" '
      if $first == "with"
      then {id:$id, rep:($rep|tonumber), judge_rep:($jr|tonumber), first:$first,
            with:.a, without:.b,
            more_useful:(if .more_useful=="A" then "with" elif .more_useful=="B" then "without" else "tie" end),
            reason:.reason}
      else {id:$id, rep:($rep|tonumber), judge_rep:($jr|tonumber), first:$first,
            with:.b, without:.a,
            more_useful:(if .more_useful=="B" then "with" elif .more_useful=="A" then "without" else "tie" end),
            reason:.reason}
      end')" || row=""

    if [[ -z "$row" ]]; then
      printf '%s\t%s\t%s\tunparseable reply\n' "$id" "$rep" "$jr" \
        >> "$RUN/judge-failures.tsv"
      echo "  judge unparseable $id rep$rep jr$jr — recorded, row dropped" >&2
      continue
    fi

    printf '%s\n' "$row" >> "$RUN/judgments.jsonl"
    echo "  judged $id rep$rep jr$jr first=$first" >&2
  done
done

wc -l < "$RUN/judgments.jsonl" | xargs -I{} echo "judgments: {}" >&2
if [[ -s "$RUN/judge-failures.tsv" ]]; then
  wc -l < "$RUN/judge-failures.tsv" | xargs -I{} echo "judge failures: {}" >&2
fi
