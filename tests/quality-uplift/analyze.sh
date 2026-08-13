#!/usr/bin/env bash
# Report per-skill uplift plus the checks that decide whether the run is usable.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Per-dimension maximum, overridable because the rubric scale is a property of
# the rubric, not of this script. Defaults to 2 (the v1 and v2 rubric's own
# per-dimension max) so a plain `analyze.sh <run-dir>` behaves exactly as
# before for both.
MAX=2
while getopts "x:" opt; do
  case "$opt" in
    x) MAX="$OPTARG" ;;
    *) echo "unknown option" >&2; exit 64 ;;
  esac
done
shift $((OPTIND - 1))
RUN="${1:?usage: analyze.sh [-x max-per-dim] <run-dir>}"
CASES="${CASES:-$SCRIPT_DIR/cases.tsv}"

# The dimension names come from the data, not from this script. A v1 campaign
# carries mechanism/actionable/specific/tradeoff; a v2 campaign carries
# assumptions in place of specific. Hardcoding either one makes this script
# unable to read the other, and the v1 campaign is a committed historical
# record. Derived from the raw file (not the sanitized one below) because the
# schema check that builds the sanitized file needs these names first.
DIMS_JSON="$(jq -c '[.with | keys_unsorted] | first' "$RUN/judgments.jsonl" 2>/dev/null | head -1)"
[[ "$DIMS_JSON" =~ ^\[.*\]$ ]] || DIMS_JSON='[]'

# The per-answer maximum the header reports is DIM_COUNT * MAX, not a literal
# 8: hardcoding 8 was correct only by coincidence, because v1 happens to carry
# 4 dimensions at a max of 2 each. v2 still carries 4 dimensions, but a report
# that states its own ceiling should compute it, not assume it.
DIM_COUNT="$(echo "$DIMS_JSON" | jq 'length')"
[[ "$DIM_COUNT" =~ ^[0-9]+$ ]] || DIM_COUNT=0
MAX_TOTAL=$((DIM_COUNT * MAX))

# Sanitize the judgment stream ONCE, up front, and report what was rejected.
#
# Every section below reads JUDGMENTS, not the raw file. Reading the raw file
# with `jq -s ... 2>/dev/null` means a single malformed line aborts the slurp and
# every judgment after it disappears — while the per-skill table still prints a
# confident average over the partial data, and the agreement section renders
# blank. A report whose job is to say when the numbers cannot be trusted must not
# have a silent truncation path of its own.
# The check is schema completeness, not just parseability. A line that parses but
# lacks `.with` makes `.with|add` yield null: the coherence section renders blank
# and the case's whole row disappears from the uplift table — while a
# parseability-only validator counts zero rejections and vouches for the data.
JUDGMENT_SCHEMA='
  def scores_ok:
    type == "object"
    and (($dims - keys) | length == 0)
    and ([.[$dims[]]] | all(type == "number"));
  has("id") and has("rep") and has("judge_rep") and has("more_useful")
  and (.with | scores_ok) and (.without | scores_ok)
'
# Duplicate slots are rejected in the same pass, and counted separately.
#
# Two concurrent judge writers appending to one judgments.jsonl is not a
# hypothetical: it happened during the 2026-08-05 campaign and produced 125 lines
# over 63 distinct (id, rep, judge_rep) slots. Every line was individually
# well-formed, so a schema-only validator counts zero rejections and the report
# then prints a full uplift table — with deltas shifted by up to 0.9 — plus a
# six-verdict agreement line for a three-slot schedule, and certifies the input
# clean. First row per slot wins; the extras are counted, not merged, because
# choosing between two competing rows for one slot is a data-selection decision
# this report has no business making silently.
JUDGMENTS="$RUN/.judgments.valid.jsonl"
malformed=0
dup_rows=0
declare -A seen_slot=()
: > "$JUDGMENTS"
if [[ -f "$RUN/judgments.jsonl" ]]; then
  while IFS= read -r line; do
    [[ -z "${line// }" ]] && continue
    # One jq call yields both the verdict and the slot key: empty output means
    # the line failed the schema above.
    slot="$(printf '%s\n' "$line" \
            | jq -r --argjson dims "$DIMS_JSON" \
              "if ($JUDGMENT_SCHEMA) then \"\(.id)|\(.rep)|\(.judge_rep)\" else empty end" \
              2>/dev/null)"
    if [[ -z "$slot" ]]; then
      malformed=$((malformed + 1))
    elif [[ -n "${seen_slot[$slot]:-}" ]]; then
      dup_rows=$((dup_rows + 1))
    else
      seen_slot[$slot]=1
      printf '%s\n' "$line" >> "$JUDGMENTS"
    fi
  done < "$RUN/judgments.jsonl"
fi

# Expected judgments per case, derived from the data rather than hardcoded:
# distinct answer reps × distinct judging passes. A case that lands fewer than
# this was averaged over less data than the table implies.
EXPECTED_N="$(jq -s '(map(.rep)|unique|length) * (map(.judge_rep)|unique|length)' \
              "$JUDGMENTS" 2>/dev/null)"
[[ "$EXPECTED_N" =~ ^[0-9]+$ ]] || EXPECTED_N=0

# Score objects carrying keys beyond the four rubric dimensions are counted and
# reported. Totals sum the four named dimensions explicitly rather than `add`,
# which would sum whatever numeric keys the object happens to have: a judge reply
# repeating a dimension under a misspelled key (observed once in the 2026-08-05
# campaign, `tradeeoff` alongside `tradeoff`) scored 10 on a scale documented as
# max 8. The count is still reported, because an extra key means the judge did
# not answer the rubric it was given — that is worth seeing even once the
# arithmetic can no longer be distorted by it, and it is a voiding condition.
#
# Note this changes what re-running against the 2026-08-05 campaign prints: that
# digest's table was produced when totals used `add`. See its amendment 4.
extra_keys="$(jq -s --argjson dims "$DIMS_JSON" '
  [ .[] | select((((.with|keys) - $dims)|length) > 0 or (((.without|keys) - $dims)|length) > 0) ]
  | length' "$JUDGMENTS" 2>/dev/null)"
[[ "$extra_keys" =~ ^[0-9]+$ ]] || extra_keys=0

# Validate .meta shape ONCE, here, in the main shell.
#
# A .meta with the wrong field count shifts a different column into `bytes` and
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
  IFS=$'\t' read -r m_id m_arm m_rep _m_chain m_bytes _m_toks _m_cost _m_att < "$m"
  [[ "$m_bytes" =~ ^[0-9]+$ ]] || { bad_meta=$((bad_meta + 1)); continue; }
  printf '%s\t%s\t%s\t%s\n' "$m_id" "$m_arm" "$m_rep" "$m_bytes" >> "$METAS"
done

echo "# Quality-uplift report"
echo
echo "Run: \`$RUN\`.  Primary metric: rubric delta (with − without), max $MAX_TOTAL per answer."
echo

echo "## Uplift per skill"
echo
echo "\`judgments\` is rows counted against the $EXPECTED_N expected per case"
echo "(distinct reps × distinct judging passes, derived from the data). Anything"
echo "other than the expected count means that row averages a different amount of"
echo "data than the others."
echo
printf '| case | skill | with | without | delta | prefers with | judgments |\n'
printf '|---|---|---|---|---|---|---|\n'
count_mismatch=0
while IFS=$'\t' read -r id skill _prompt; do
  [[ "$id" == "ID" || -z "${id// }" ]] && continue
  row="$(jq -r --arg id "$id" '
    select(.id==$id)' "$JUDGMENTS" 2>/dev/null \
  | jq -s -r --arg id "$id" --arg skill "$skill" --argjson exp "$EXPECTED_N" --argjson dims "$DIMS_JSON" '
      if length==0 then "| \($id) | \($skill) | – | – | – | not measurable | 0/\($exp) |"
      else
        (map(.with|[.[$dims[]]]|add)|add/length) as $w |
        (map(.without|[.[$dims[]]]|add)|add/length) as $o |
        (map(select(.more_useful=="with"))|length) as $pw |
        (if length == $exp then "" else " COUNT-MISMATCH" end) as $flag |
        "| \($id) | \($skill) | \($w*10|round/10) | \($o*10|round/10) | \(($w-$o)*10|round/10) | \($pw)/\(length) | \(length)/\($exp)\($flag) |"
      end')"
  printf '%s\n' "$row"
  # Only a partial count is flagged here. A case with zero rows already says "not
  # measurable" in the row itself, and flagging it again would fire on every run
  # analyzed against a cases file it does not belong to.
  [[ "$row" == *COUNT-MISMATCH* ]] && count_mismatch=1
done < "$CASES"
echo
if (( dup_rows > 0 )); then
  echo "WARNING: $dup_rows duplicate (id,rep,judge_rep) rows were rejected before this"
  echo "table was computed. Which of the competing rows survived per slot is an artifact"
  echo "of write order, so every number above is arbitrary to that degree. This table is"
  echo "not a measurement — see the malformed-input section at the end."
  echo
fi
if (( count_mismatch )); then
  echo "WARNING: a case above has a judgment count other than the expected $EXPECTED_N."
  echo "Its averages are computed over a different number of rows than the rest of the"
  echo "table, so the deltas are not comparable across rows. Check judge-failures.tsv"
  echo "and the duplicate/malformed counts at the end of this report before reading"
  echo "any delta."
  echo
fi

echo "## Score vs length"
echo
echo "If the delta tracks verbosity, the result is void (spec §6.2). Length is bytes"
echo "(\`wc -c\`), not characters — the prompts are Spanish, so the two differ."
echo
echo "Pooled r alone cannot answer the question this check exists to ask. A high"
echo "pooled r is produced both by a judge that rewards length and by a with-arm that"
echo "is simply longer AND better; those demand opposite fixes. The per-arm r values"
echo "separate them: correlation that survives within each arm is judge length-bias,"
echo "because the arm label is constant there. Read all three lines, not the first."
echo
{ while IFS=$'\t' read -r id arm rep bytes; do
    [[ -n "$id" ]] || continue
    tot=$(jq -r --arg id "$id" --arg rep "$rep" --arg arm "$arm" --argjson dims "$DIMS_JSON" '
            select(.id==$id and .rep==($rep|tonumber))
            | (if $arm=="with" then .with else .without end)
            | ([.[$dims[]]]|add)' \
          "$JUDGMENTS" 2>/dev/null | jq -s 'if length==0 then empty else add/length end')
    [[ -n "$tot" ]] && printf '%s\t%s\t%s\n' "$arm" "$bytes" "$tot"
  done < "$METAS"; } | awk -F'\t' '
    function pear(n,sx,sy,sxy,sxx,syy,  num,den) {
      num=n*sxy-sx*sy; den=sqrt((n*sxx-sx*sx)*(n*syy-sy*sy));
      return (den==0) ? 0 : num/den;
    }
    function report(label,a,  rr) {
      if (N[a]<3) {printf "  %-8s too few paired samples (n=%d)\n", label, N[a]; return 0}
      rr=pear(N[a],SX[a],SY[a],SXY[a],SXX[a],SYY[a]);
      printf "  %-8s n=%d  pearson r(bytes, rubric total) = %.2f   (mean %d bytes, mean score %.2f)\n",
             label, N[a], rr, SX[a]/N[a], SY[a]/N[a];
      return rr;
    }
    {
      arm=$1;
      N["pooled"]++; SX["pooled"]+=$2; SY["pooled"]+=$3; SXY["pooled"]+=$2*$3; SXX["pooled"]+=$2*$2; SYY["pooled"]+=$3*$3;
      N[arm]++;      SX[arm]+=$2;      SY[arm]+=$3;      SXY[arm]+=$2*$3;      SXX[arm]+=$2*$2;      SYY[arm]+=$3*$3;
    }
    END{
      rp=report("pooled","pooled");
      rw=report("with","with");
      ro=report("without","without");
      if (N["pooled"]<3) exit;
      if (rp>0.5) print "  WARNING: scores track length. Rework judging before trusting deltas.";
      if (rw>0.5 || ro>0.5)
        print "  WARNING: the correlation holds WITHIN an arm, where the arm label is constant.\n" \
              "  That is judge length-bias, not the inter-arm length gap. Closing the gap\n" \
              "  between the arms would not fix it; the judging design has to change.";
      else if (rp>0.5)
        print "  NOTE: pooled r is high but neither arm is internally correlated — this is the\n" \
              "  inter-arm length gap, not judge length-bias within an arm.";
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
jq -s -r --argjson dims "$DIMS_JSON" '
  map(select(.more_useful != "tie"))
  | map(. + {wt:(.with|[.[$dims[]]]|add), ot:(.without|[.[$dims[]]]|add)})
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
echo "## Input this report would not take at face value"
echo
echo "The first two and the last were dropped, so a non-zero count means the sections"
echo "above were computed over less data than the run produced. The extra-key count is"
echo "different: those rows were scored, over the four named dimensions only, but a judge"
echo "that invents a dimension is not answering the rubric it was given, so any non-zero"
echo "value voids the campaign rather than merely trimming it."
printf '  unparseable judgments.jsonl lines: %d\n' "$malformed"
printf '  duplicate (id,rep,judge_rep) rows rejected: %d\n' "$dup_rows"
printf '  rows with score keys outside the four rubric dimensions (VOIDS the campaign): %d\n' "$extra_keys"
printf '  .meta files with a bad field count or non-numeric length: %d\n' "$bad_meta"
if (( dup_rows > 0 )); then
  echo
  echo "A non-zero duplicate count means more than one writer appended to"
  echo "judgments.jsonl — two concurrent judge runs, or a re-run into a directory that"
  echo "already held judgments. Only the first row per slot was used; every section"
  echo "above is computed over that deduplicated set, and which row won per slot was an"
  echo "arbitrary consequence of write order. Do not publish these numbers: re-judge"
  echo "into a clean directory (the scripts now take a lock, see README guard 5) and"
  echo "keep the contaminated file as evidence."
fi
