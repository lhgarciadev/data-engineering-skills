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
