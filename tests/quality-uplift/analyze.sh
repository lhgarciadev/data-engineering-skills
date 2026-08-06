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
echo "Samples rejected — with-arm routing misses, plus empty answers in either arm:"
if [[ -s "$RUN/discards.tsv" ]]; then
  awk -F'\t' '{c[$1"\t"$5]++} END{for (k in c) {split(k,p,"\t"); printf "  %s (%s): %d\n", p[1], p[2], c[k]}}' \
    "$RUN/discards.tsv"
else
  echo "  none"
fi
echo

echo "## Judge failures"
echo
echo "Judgments dropped because the judge reply was empty or unparseable. A dropped"
echo "row means a case was averaged over fewer reps than the table implies."
if [[ -s "$RUN/judge-failures.tsv" ]]; then
  awk -F'\t' '{printf "  %s rep%s jr%s: %s\n", $1, $2, $3, $4}' "$RUN/judge-failures.tsv"
else
  echo "  none"
fi
