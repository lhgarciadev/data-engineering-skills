#!/usr/bin/env bash
# Tests whether the four-dimension rubric has enough dynamic range to measure uplift.
#
# Read-only. Reads results/full/judgments.jsonl; writes nothing under results/full/.
#
# The question: dimension-length-decomposition.sh reported with-arm dimension means of
# 1.98, 1.92, 1.97 and 1.49 against a per-dimension maximum of 2 (7.37 of 8 total), and
# flagged — post-hoc, not acted on — that scores packed that close to the ceiling leave a
# correlation little variance to work with. This instrument asks that question directly:
# is the with-arm saturated against the rubric's ceiling, such that any uplift a skill
# produces beyond "competent" is unmeasurable?
#
# This does NOT re-run the void verdict, does NOT measure uplift, and does NOT establish
# that the rubric caused anything. It is descriptive statistics on the same n=42 answers
# across 7 cases already on disk. See experiments/README.md for the reading rule this
# instrument's numbers are read against, fixed before the numbers existed.
#
# Usage: ./rubric-headroom.sh [-d RESULTS_DIR]

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

echo "# Rubric headroom"
echo
echo "Source: $RESULTS_DIR"
echo "Judgments: $(wc -l < "$JUDGMENTS") rows"
echo

# ---------------------------------------------------------------------------
# Guard: duplicate (id, rep, judge_rep) slots — same guard as
# dimension-length-decomposition.sh, for the same reason: more than one writer
# touched judgments.jsonl in this suite's history, and a duplicate would silently
# bias every mean and count below.
# ---------------------------------------------------------------------------
DUPES=$(jq -r '[.id, (.rep|tostring), (.judge_rep|tostring)] | join("/")' "$JUDGMENTS" \
        | sort | uniq -d)
if [ -n "$DUPES" ]; then
  echo "STOP — duplicate (id, rep, judge_rep) slots:"
  echo "$DUPES" | sed 's/^/    /'
  exit 1
fi
echo "Duplicate slots: none"
echo

# ---------------------------------------------------------------------------
# The reading rule — fixed before any number below is computed.
# ---------------------------------------------------------------------------
cat <<'RULE'
## Reading rule (fixed before computation)

Saturation is CONFIRMED if both hold:
  - on at least two of the four dimensions, >= 50% of with-arm answers score the
    maximum (2); AND
  - the mean observed total uplift (with - without) is >= 60% of the mean maximum
    detectable uplift (8 - without_total, per case-rep).

Saturation is REFUTED if neither holds.

Anything else is PARTIAL.
RULE
echo

# ---------------------------------------------------------------------------
# Build one row per answer (42 rows: 21 case-reps x 2 arms). Each judgment row
# already carries both arms' scores (it is a pairwise comparison), so unlike
# dimension-length-decomposition.sh no .meta join is needed here — bytes are not
# part of this question. Averaging across judge reps first matches how the
# existing instruments treat a judgment: see analyze.sh:170-177.
# ---------------------------------------------------------------------------
ROWS=$(mktemp) || exit 1
trap 'rm -f "$ROWS"' EXIT
jq -s -r '
  group_by([.id,.rep])[] as $g
  | ($g[0].id) as $id | ($g[0].rep) as $rep
  | ["with","without"][] as $arm
  | ($g | map(.[$arm].mechanism) | add/length) as $m
  | ($g | map(.[$arm].actionable) | add/length) as $a
  | ($g | map(.[$arm].specific) | add/length) as $s
  | ($g | map(.[$arm].tradeoff) | add/length) as $t
  | [$arm, $id, ($rep|tostring), $m, $a, $s, $t, ($m+$a+$s+$t)] | @tsv
' "$JUDGMENTS" > "$ROWS"

echo "Answers joined: $(wc -l < "$ROWS") (expected 42 for the full campaign: 21 case-reps x 2 arms)"
echo

# ---------------------------------------------------------------------------
# Section 1 + 2: per-dimension distribution at 0/1/2, mean and population SD, per arm.
# A per-answer score equal to 2 (or 1, or 0) requires all judge reps to have agreed on
# that value after averaging — a partial score (thirds, from a 2/1/1-style split among
# the three judge reps) falls in none of the three buckets, so the three counts need not
# sum to n. That is reported explicitly rather than forced to add up.
# ---------------------------------------------------------------------------
echo "## Per-dimension distribution, mean, SD (n=21 per arm)"
echo
awk -F'\t' '
  function iseq(x,v) { d = x-v; if (d<0) d=-d; return d < 1e-6 }
  {
    arm=$1;
    split("4 5 6 7", cols, " ");
    split("mechanism actionable specific tradeoff", name, " ");
    for (i=1;i<=4;i++) {
      c=cols[i]; v=$c; key=arm SUBSEP i;
      N[key]++; SUM[key]+=v; SUMSQ[key]+=v*v;
      if (iseq(v,2)) C2[key]++;
      else if (iseq(v,1)) C1[key]++;
      else if (iseq(v,0)) C0[key]++;
    }
  }
  END {
    split("with without", arms, " ");
    printf "%-12s %-8s %6s %8s %8s %10s %8s %10s %8s\n", \
      "dimension", "arm", "n", "mean", "sd", "count@2", "pct@2", "count@1/@0", "pct@1/@0";
    for (ai=1; ai<=2; ai++) {
      a=arms[ai];
      for (i=1;i<=4;i++) {
        key=a SUBSEP i; n=N[key]; mean=SUM[key]/n;
        var=(SUMSQ[key]/n) - (mean*mean); if (var<0) var=0; sd=sqrt(var);
        c2=C2[key]+0; c1=C1[key]+0; c0=C0[key]+0;
        printf "%-12s %-8s %6d %8.3f %8.3f %10d %7.1f%% %5d/%-4d %6.1f%%/%.1f%%\n", \
          name[i], a, n, mean, sd, c2, 100*c2/n, c1, c0, 100*c1/n, 100*c0/n;
      }
    }
  }
' "$ROWS"
echo

# ---------------------------------------------------------------------------
# Section 3: total distribution per arm — count/pct scoring the maximum (8), and the
# full distribution of totals.
# ---------------------------------------------------------------------------
echo "## Total distribution per arm (max = 8)"
echo
awk -F'\t' '
  function iseq(x,v) { d = x-v; if (d<0) d=-d; return d < 1e-6 }
  { arm=$1; t=$8; N[arm]++; SUM[arm]+=t; SUMSQ[arm]+=t*t; if (iseq(t,8)) C8[arm]++;
    key=arm SUBSEP sprintf("%.6f",t); CNT[key]++; if (!(arm SUBSEP t in seen)) { seen[arm SUBSEP t]=1 }
  }
  END {
    split("with without", arms, " ");
    for (ai=1; ai<=2; ai++) {
      a=arms[ai]; n=N[a]; mean=SUM[a]/n; var=(SUMSQ[a]/n)-(mean*mean); if (var<0) var=0;
      c8=C8[a]+0;
      printf "%-8s n=%d  mean total=%.3f  sd=%.3f  count@8=%d (%.1f%%)\n", a, n, mean, sqrt(var), c8, 100*c8/n;
    }
  }
' "$ROWS"
echo
echo "Distribution of totals (sorted, one value per answer):"
echo "  with:    $(awk -F'\t' '$1=="with"{printf "%.3f ", $8}' "$ROWS" | tr ' ' '\n' | sort -n | tr '\n' ' ')"
echo "  without: $(awk -F'\t' '$1=="without"{printf "%.3f ", $8}' "$ROWS" | tr ' ' '\n' | sort -n | tr '\n' ' ')"
echo

# ---------------------------------------------------------------------------
# Section 4: mean observed uplift vs mean maximum detectable uplift.
# Paired by (id, rep): with_total - without_total, and 8 - without_total.
# ---------------------------------------------------------------------------
echo "## Uplift vs headroom (paired by case-rep, n=21)"
echo
awk -F'\t' '
  { key=$2 SUBSEP $3; TOTAL[$1 SUBSEP key]=$8 }
  END {
    n=0;
    for (k in TOTAL) {
      split(k, parts, SUBSEP);
      if (parts[1]=="with") {
        wkey="with" SUBSEP parts[2] SUBSEP parts[3];
        okey="without" SUBSEP parts[2] SUBSEP parts[3];
        if (okey in TOTAL) {
          n++;
          w=TOTAL[wkey]; o=TOTAL[okey];
          uplift=w-o; maxdet=8-o;
          SUM_UP+=uplift; SUM_MAX+=maxdet;
        }
      }
    }
    mean_up=SUM_UP/n; mean_max=SUM_MAX/n; ratio=mean_up/mean_max;
    printf "pairs matched: %d (expected 21)\n", n;
    printf "mean observed uplift (with - without):        %.4f\n", mean_up;
    printf "mean maximum detectable uplift (8 - without):  %.4f\n", mean_max;
    printf "ratio (mean uplift / mean max detectable):     %.4f  (%.1f%%)\n", ratio, 100*ratio;
  }
' "$ROWS"
