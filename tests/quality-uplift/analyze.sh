#!/usr/bin/env bash
# Report per-skill uplift plus the checks that decide whether the run is usable.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="${1:?usage: analyze.sh <run-dir>}"
CASES="${CASES:-$SCRIPT_DIR/cases.tsv}"

# Sanitize the judgment stream ONCE, up front, and report what was rejected.
#
# Every section below reads JUDGMENTS, not the raw file. Reading the raw file
# with `jq -s ... 2>/dev/null` means a single malformed line aborts the slurp and
# every judgment after it disappears — while the per-skill table still prints a
# confident average over the partial data, and the agreement section renders
# blank. A report whose job is to say when the numbers cannot be trusted must not
# have a silent truncation path of its own.
JUDGMENTS="$RUN/.judgments.valid.jsonl"
malformed=0
: > "$JUDGMENTS"
if [[ -f "$RUN/judgments.jsonl" ]]; then
  while IFS= read -r line; do
    [[ -z "${line// }" ]] && continue
    if printf '%s\n' "$line" | jq -e . >/dev/null 2>&1; then
      printf '%s\n' "$line" >> "$JUDGMENTS"
    else
      malformed=$((malformed + 1))
    fi
  done < "$RUN/judgments.jsonl"
fi

# Validate .meta shape ONCE, here, in the main shell.
#
# A .meta with the wrong field count shifts a different column into `chars` and
# feeds the correlation a confident number computed from the wrong data. This
# must not live inside the `{ ... } | awk` pipeline below: a brace group in a
# pipeline runs in a subshell, so a counter incremented there is lost when it
# ends, and the report would print zero rejections while having skipped rows.
METAS="$RUN/.metas.valid.tsv"
bad_meta=0
: > "$METAS"
for m in "$RUN"/*.meta; do
  [[ -f "$m" ]] || continue
  if [[ "$(awk -F'\t' 'NR==1{print NF}' "$m")" != "8" ]]; then
    bad_meta=$((bad_meta + 1)); continue
  fi
  IFS=$'\t' read -r m_id m_arm m_rep _m_chain m_chars _m_toks _m_cost _m_att < "$m"
  [[ "$m_chars" =~ ^[0-9]+$ ]] || { bad_meta=$((bad_meta + 1)); continue; }
  printf '%s\t%s\t%s\t%s\n' "$m_id" "$m_arm" "$m_rep" "$m_chars" >> "$METAS"
done

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
    select(.id==$id)' "$JUDGMENTS" 2>/dev/null \
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
{ while IFS=$'\t' read -r id arm rep chars; do
    [[ -n "$id" ]] || continue
    tot=$(jq -r --arg id "$id" --arg rep "$rep" --arg arm "$arm" '
            select(.id==$id and .rep==($rep|tonumber))
            | (if $arm=="with" then .with else .without end) | add' \
          "$JUDGMENTS" 2>/dev/null | jq -s 'if length==0 then empty else add/length end')
    [[ -n "$tot" ]] && printf '%s\t%s\n' "$chars" "$tot"
  done < "$METAS"; } | awk -F'\t' '
    BEGIN{n=0}
    {n++; sx+=$1; sy+=$2; sxy+=$1*$2; sxx+=$1*$1; syy+=$2*$2}
    END{
      if (n<3) {printf "  too few paired samples (n=%d)\n", n; exit}
      num=n*sxy-sx*sy; den=sqrt((n*sxx-sx*sx)*(n*syy-sy*sy));
      r = (den==0) ? 0 : num/den;
      printf "  n=%d  pearson r(chars, rubric total) = %.2f\n", n, r;
      if (r>0.5) print "  WARNING: scores track length. Rework judging before trusting deltas.";
    }'
echo

echo "## Judge agreement"
echo
echo "One line per answer sample. judge_rep 1 and 3 use the same presentation order,"
echo "2 is inverted: disagreement between 1 and 3 is judge noise, disagreement with 2"
echo "suggests position bias."
echo
# Group by (id, rep), not by id alone. `rep` is the answer sample and `judge_rep`
# the judging pass, so grouping by id alone zips several independent samples into
# one sequence that reads like a pattern and is not one. The fixtures only ever
# have rep=1, which hides this; a real campaign runs 3.
jq -s -r '
  group_by([.id, .rep]) | map({
    id: .[0].id,
    rep: .[0].rep,
    verdicts: (sort_by(.judge_rep) | map(.more_useful) | join(","))
  }) | .[] | "  \(.id) rep\(.rep): \(.verdicts)"' "$JUDGMENTS" 2>/dev/null
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
    end' "$JUDGMENTS" 2>/dev/null
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
  echo "  recorded by the judge: none"
fi
echo
echo "## Malformed input rejected by this report"
echo
echo "Input this script refused to parse. Non-zero here means the sections above"
echo "were computed over less data than the run produced, so read them accordingly."
printf '  unparseable judgments.jsonl lines: %d\n' "$malformed"
printf '  .meta files with a bad field count or non-numeric length: %d\n' "$bad_meta"
