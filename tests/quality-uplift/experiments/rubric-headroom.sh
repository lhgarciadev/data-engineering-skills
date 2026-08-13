#!/usr/bin/env bash
# Tests whether the rubric has enough dynamic range to measure uplift.
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
# Version-agnostic: dimension names come from the data (a v1 campaign carries
# mechanism/actionable/specific/tradeoff; a v2 campaign carries assumptions in place of
# specific), and the per-dimension maximum comes from -x (default 2, matching the
# committed v1 campaign) rather than a literal baked into this script. Every "8" that
# used to appear below was DIM_COUNT * MAX by coincidence, not by definition — v1 has 4
# dimensions at max 2; a v2 run passing -x 3 has the same 4 dimensions at max 3, giving a
# per-answer ceiling of 12, not 8. Running v2-shaped data through the default -x 2 would
# silently under-declare the ceiling: a dimension scored 2 (not the v2 maximum) would
# register as "at the maximum" and every headroom figure below would be wrong with total
# confidence. The guard below aborts rather than let that happen quietly.
#
# Usage: ./rubric-headroom.sh [-d RESULTS_DIR] [-x MAX]

set -uo pipefail
cd "$(dirname "$0")" || exit 1

RESULTS_DIR="../results/full"
MAX=2
while getopts "d:x:" opt; do
  case "$opt" in
    d) RESULTS_DIR="$OPTARG" ;;
    x) MAX="$OPTARG" ;;
    *) echo "usage: $0 [-d RESULTS_DIR] [-x MAX]" >&2; exit 2 ;;
  esac
done

JUDGMENTS="$RESULTS_DIR/judgments.jsonl"

# Guard: the contaminated file lives beside the real one under a similar name.
case "$JUDGMENTS" in
  *contaminated*) echo "REFUSING: $JUDGMENTS is a recorded contaminated file" >&2; exit 1 ;;
esac
[ -f "$JUDGMENTS" ] || { echo "missing: $JUDGMENTS" >&2; exit 1; }

# The dimension names come from the data, not from this script — see analyze.sh for the
# same derivation and why it matters.
DIMS_JSON="$(jq -c '[.with | keys_unsorted] | first' "$JUDGMENTS" 2>/dev/null | head -1)"
[[ "$DIMS_JSON" =~ ^\[.*\]$ ]] || DIMS_JSON='[]'
DIM_COUNT="$(echo "$DIMS_JSON" | jq 'length')"
[[ "$DIM_COUNT" =~ ^[0-9]+$ ]] || DIM_COUNT=0
DIM_NAMES="$(echo "$DIMS_JSON" | jq -r 'join(" ")')"
MAX_TOTAL=$((DIM_COUNT * MAX))

# Guard: the declared per-dimension maximum (-x, default 2) must not be lower than what
# the data actually contains. Under-declaring it is not a warning-level mistake — every
# "count@max" and "maximum detectable uplift" figure below would be computed against the
# wrong ceiling and printed with the same confidence as a correct run. Abort instead.
OBSERVED_MAX="$(jq -s --argjson dims "$DIMS_JSON" '
  [.[] | (.with, .without) | [.[$dims[]]] | .[]] | max' "$JUDGMENTS" 2>/dev/null)"
if [[ "$OBSERVED_MAX" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] \
   && awk -v o="$OBSERVED_MAX" -v m="$MAX" 'BEGIN { exit !(o > m) }'; then
  echo "STOP — observed max score $OBSERVED_MAX exceeds declared per-dimension maximum -x $MAX; rerun with the correct -x" >&2
  exit 1
fi

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
# The reading rule — fixed before any number below is computed. $MAX and
# $MAX_TOTAL default to 2 and 8, so this renders byte-identical to the
# committed v1 text unless -x changes the scale.
# ---------------------------------------------------------------------------
cat <<RULE
## Reading rule (fixed before computation)

Saturation is CONFIRMED if both hold:
  - on at least two of the four dimensions, >= 50% of with-arm answers score the
    maximum ($MAX); AND
  - the mean observed total uplift (with - without) is >= 60% of the mean maximum
    detectable uplift ($MAX_TOTAL - without_total, per case-rep).

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
#
# Columns: arm, id, rep, one per dimension (in data order), total.
# ---------------------------------------------------------------------------
ROWS=$(mktemp) || exit 1
trap 'rm -f "$ROWS"' EXIT
jq -s -r --argjson dims "$DIMS_JSON" '
  group_by([.id,.rep])[] as $g
  | ($g[0].id) as $id | ($g[0].rep) as $rep
  | ["with","without"][] as $arm
  | ($dims | map(. as $d | ($g | map(.[$arm][$d]) | add/length))) as $vals
  | ([$arm, $id, ($rep|tostring)] + ($vals|map(tostring)) + [($vals|add|tostring)]) | @tsv
' "$JUDGMENTS" > "$ROWS"

echo "Answers joined: $(wc -l < "$ROWS") (expected 42 for the full campaign: 21 case-reps x 2 arms)"
echo

# ---------------------------------------------------------------------------
# Section 1 + 2: per-dimension distribution, mean and population SD, per arm.
# A per-answer score equal to the maximum (or any other integer) requires all judge
# reps to have agreed on that value after averaging — a partial score (thirds, from
# a split among the three judge reps) falls in none of the integer buckets, so the
# buckets need not sum to n. That is reported explicitly rather than forced to add up.
#
# Buckets are the maximum plus every integer below it down to 0, so the bucket count
# tracks -x: at the default max of 2 this is exactly the v1 {2,1,0} layout (and the
# max==2 branch below reproduces that layout's exact formatting byte for byte); at
# -x 3 it becomes {3,2,1,0}.
# ---------------------------------------------------------------------------
echo "## Per-dimension distribution, mean, SD (n=21 per arm)"
echo
awk -F'\t' -v max="$MAX" -v dimcount="$DIM_COUNT" -v dimnames="$DIM_NAMES" '
  function iseq(x,v) { d = x-v; if (d<0) d=-d; return d < 1e-6 }
  function join_counts(key, top,    b,s) {
    s = ""
    for (b = top; b >= 0; b--) s = s (s=="" ? "" : "/") (CNT[key,b]+0)
    return s
  }
  function join_pcts(key, top, n,    b,s) {
    s = ""
    for (b = top; b >= 0; b--) s = s (s=="" ? "" : "/") sprintf("%.1f%%", 100*(CNT[key,b]+0)/n)
    return s
  }
  BEGIN { split(dimnames, name, " ") }
  {
    arm=$1;
    for (i=1;i<=dimcount;i++) {
      c=3+i; v=$c; key=arm SUBSEP i;
      N[key]++; SUM[key]+=v; SUMSQ[key]+=v*v;
      for (b=0; b<=max; b++) { if (iseq(v,b)) { CNT[key,b]++; break } }
    }
  }
  END {
    split("with without", arms, " ");
    if (max == 2) {
      printf "%-12s %-8s %6s %8s %8s %10s %8s %10s %8s\n", \
        "dimension", "arm", "n", "mean", "sd", "count@2", "pct@2", "count@1/@0", "pct@1/@0";
    } else {
      hdr_sub = ""
      for (b = max-1; b >= 0; b--) hdr_sub = hdr_sub (hdr_sub=="" ? "@" b : "/@" b)
      printf "%-12s %-8s %6s %8s %8s %10s %8s %14s %13s\n", \
        "dimension", "arm", "n", "mean", "sd", ("count@" max), ("pct@" max), ("count" hdr_sub), ("pct" hdr_sub);
    }
    for (ai=1; ai<=2; ai++) {
      a=arms[ai];
      for (i=1;i<=dimcount;i++) {
        key=a SUBSEP i; n=N[key]; mean=SUM[key]/n;
        var=(SUMSQ[key]/n) - (mean*mean); if (var<0) var=0; sd=sqrt(var);
        cmax=CNT[key,max]+0;
        if (max == 2) {
          c1=CNT[key,1]+0; c0=CNT[key,0]+0;
          printf "%-12s %-8s %6d %8.3f %8.3f %10d %7.1f%% %5d/%-4d %6.1f%%/%.1f%%\n", \
            name[i], a, n, mean, sd, cmax, 100*cmax/n, c1, c0, 100*c1/n, 100*c0/n;
        } else {
          cnt_str = join_counts(key, max-1);
          pct_str = join_pcts(key, max-1, n);
          printf "%-12s %-8s %6d %8.3f %8.3f %10d %7.1f%% %14s %13s\n", \
            name[i], a, n, mean, sd, cmax, 100*cmax/n, cnt_str, pct_str;
        }
      }
    }
  }
' "$ROWS"
echo

# ---------------------------------------------------------------------------
# Section 3: total distribution per arm — count/pct scoring the maximum
# (DIM_COUNT * MAX, not a literal 8), and the full distribution of totals.
# ---------------------------------------------------------------------------
echo "## Total distribution per arm (max = $MAX_TOTAL)"
echo
awk -F'\t' -v tcol="$((4 + DIM_COUNT))" -v max_total="$MAX_TOTAL" '
  function iseq(x,v) { d = x-v; if (d<0) d=-d; return d < 1e-6 }
  { arm=$1; t=$(tcol); N[arm]++; SUM[arm]+=t; SUMSQ[arm]+=t*t; if (iseq(t,max_total)) C8[arm]++;
    key=arm SUBSEP sprintf("%.6f",t); CNT[key]++; if (!(arm SUBSEP t in seen)) { seen[arm SUBSEP t]=1 }
  }
  END {
    split("with without", arms, " ");
    for (ai=1; ai<=2; ai++) {
      a=arms[ai]; n=N[a]; mean=SUM[a]/n; var=(SUMSQ[a]/n)-(mean*mean); if (var<0) var=0;
      c8=C8[a]+0;
      printf "%-8s n=%d  mean total=%.3f  sd=%.3f  count@%d=%d (%.1f%%)\n", a, n, mean, sqrt(var), max_total, c8, 100*c8/n;
    }
  }
' "$ROWS"
echo
echo "Distribution of totals (sorted, one value per answer):"
echo "  with:    $(awk -F'\t' -v tcol="$((4 + DIM_COUNT))" '$1=="with"{printf "%.3f ", $(tcol)}' "$ROWS" | tr ' ' '\n' | sort -n | tr '\n' ' ')"
echo "  without: $(awk -F'\t' -v tcol="$((4 + DIM_COUNT))" '$1=="without"{printf "%.3f ", $(tcol)}' "$ROWS" | tr ' ' '\n' | sort -n | tr '\n' ' ')"
echo

# ---------------------------------------------------------------------------
# Section 4: mean observed uplift vs mean maximum detectable uplift.
# Paired by (id, rep): with_total - without_total, and MAX_TOTAL - without_total
# (not a literal 8).
# ---------------------------------------------------------------------------
echo "## Uplift vs headroom (paired by case-rep, n=21)"
echo
awk -F'\t' -v tcol="$((4 + DIM_COUNT))" -v max_total="$MAX_TOTAL" '
  { key=$2 SUBSEP $3; TOTAL[$1 SUBSEP key]=$(tcol) }
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
          uplift=w-o; maxdet=max_total-o;
          SUM_UP+=uplift; SUM_MAX+=maxdet;
        }
      }
    }
    mean_up=SUM_UP/n; mean_max=SUM_MAX/n; ratio=mean_up/mean_max;
    printf "pairs matched: %d (expected 21)\n", n;
    printf "mean observed uplift (with - without):        %.4f\n", mean_up;
    printf "mean maximum detectable uplift (%d - without):  %.4f\n", max_total, mean_max;
    printf "ratio (mean uplift / mean max detectable):     %.4f  (%.1f%%)\n", ratio, 100*ratio;
  }
' "$ROWS"
