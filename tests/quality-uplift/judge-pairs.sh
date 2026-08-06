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
