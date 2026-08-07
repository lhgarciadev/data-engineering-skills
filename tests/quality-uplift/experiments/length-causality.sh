#!/usr/bin/env bash
# Does the rubric reward length itself, or substance that happens to be longer?
#
# The 2026-08-05 campaign was voided at pooled r=0.61 between answer bytes and
# rubric total, and the correlation survives within each arm (with 0.594,
# without 0.651) and outside the score ceiling (r=0.534 over the 32 answers
# below 8.0). Correlation alone cannot say which of these is true:
#
#   (a) the judge rewards verbosity, so the delta is an artifact — fix the judge
#   (b) the rubric measures coverage, which genuinely scales with length, so the
#       correlation is signal and the primary metric is what needs rethinking
#
# This holds content constant and varies only length. Each sampled answer is
# compressed — every technical claim and recommendation preserved, prose cut —
# and both versions are scored under the same rubric, one answer at a time with
# no comparison. If compression barely moves the score, the rubric is measuring
# substance and (b) holds. If compressed versions score materially lower, the
# rubric is paying for words and (a) holds.
#
# Scoring is single-answer here deliberately: the campaign judged pairwise, and
# a pairwise judge shown a long and a short answer has a second reason to prefer
# the longer one. Removing the comparison isolates the rubric itself.
#
# Usage: ./length-causality.sh [-n SAMPLES] [-m MODEL] [-o OUTDIR]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPLIFT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_SRC="$UPLIFT_DIR/results/full"
# Compressor and judge are separate on purpose. The first run of this experiment
# used one model for both, which lets the compressor cut toward what that same
# model happens to reward — biasing the result toward "compression is harmless".
# Keep them different unless you are deliberately measuring that confound.
JUDGE_MODEL="sonnet"
COMPRESS_MODEL="opus"
SAMPLES=6
OUT="$SCRIPT_DIR/results/length-causality"

while getopts "n:m:c:o:" opt; do
  case "$opt" in
    n) SAMPLES="$OPTARG" ;;
    m) JUDGE_MODEL="$OPTARG" ;;
    c) COMPRESS_MODEL="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    *) echo "unknown option" >&2; exit 64 ;;
  esac
done
[[ "$JUDGE_MODEL" == "$COMPRESS_MODEL" ]] && \
  echo "WARNING: compressor and judge are the same model — result is confounded" >&2

mkdir -p "$OUT"
mkdir "$OUT/.lock" 2>/dev/null || { echo "refusing to start: $OUT/.lock exists" >&2; exit 69; }
trap 'rmdir "$OUT/.lock" 2>/dev/null' EXIT

MIN_AVAIL_MB=1200
await_memory() {
  local avail
  for _ in $(seq 1 120); do
    avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
    (( avail >= MIN_AVAIL_MB )) && return 0
    echo "  waiting for memory: ${avail}MB" >&2
    sleep 10
  done
  echo "  WARNING: proceeding with low memory (${avail}MB)" >&2
}

SCORE_SCHEMA='{"type":"object","properties":{
"mechanism":{"type":"integer"},"actionable":{"type":"integer"},
"specific":{"type":"integer"},"tradeoff":{"type":"integer"}},
"required":["mechanism","actionable","specific","tradeoff"],
"additionalProperties":false}'

# One claude call, sandboxed and tool-less, answer on stdin. Same blinding the
# campaign's judge now gets: no cwd in this repo, no read tools, suite disabled.
call() {
  local model="$1" prompt="$2" schema="${3:-}" sandbox out
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/lcx-XXXXXX")"
  local args=(--model "$model" --strict-mcp-config
              --disallowedTools "Bash" "Read" "Write" "Edit" "Task" "Glob" "Grep"
              --settings '{"enabledPlugins":{"dataforge@skills-dir":false}}')
  [[ -n "$schema" ]] && args+=(--json-schema "$schema")
  await_memory
  out="$(cd "$sandbox" && timeout 600 claude "${args[@]}" -p "$prompt" 2>/dev/null)"
  rm -rf "$sandbox"
  printf '%s' "$out"
}

# Stratified sample across the byte range: alternate from the short and long
# ends so the set spans the distribution rather than clustering.
mapfile -t ORDERED < <(
  for m in "$RUN_SRC"/*.meta; do
    IFS=$'\t' read -r id arm rep _chain bytes _t _c _a < "$m"
    printf '%s\t%s.%s.rep%s\n' "$bytes" "$id" "$arm" "$rep"
  done | sort -n
)
n=${#ORDERED[@]}
picks=()
for (( i=0; i<SAMPLES; i++ )); do
  idx=$(( i * (n - 1) / (SAMPLES - 1) ))
  picks+=("${ORDERED[$idx]}")
done

RUBRIC="$(cat "$UPLIFT_DIR/rubric.md")"
: > "$OUT/scores.tsv"

for p in "${picks[@]}"; do
  bytes="${p%%$'\t'*}"; tag="${p##*$'\t'}"
  src="$RUN_SRC/$tag.txt"
  [[ -f "$src" ]] || { echo "  missing $src" >&2; continue; }

  compressed="$OUT/$tag.compressed.txt"
  if [[ ! -s "$compressed" ]]; then
    { echo "Rewrite the answer below as concisely as you can WITHOUT losing substance."
      echo "Every technical claim, mechanism, recommendation, command, setting and caveat"
      echo "must survive. Cut restatement, preamble, transitions, headings and hedging."
      echo "Do not add anything. Do not summarise — compress. Output only the rewrite."
      echo; echo "=== ANSWER ==="; echo; cat "$src"
    } | call "$COMPRESS_MODEL" "Compress the answer per the instructions above." > "$compressed"
  fi
  cbytes=$(wc -c < "$compressed" | tr -d ' ')

  for variant in original compressed; do
    file="$src"; [[ "$variant" == compressed ]] && file="$compressed"
    raw="$({ echo "$RUBRIC"
              echo; echo "Score the single answer below on the four dimensions."
              echo "There is no second answer to compare against."
              echo; echo "=== ANSWER ==="; echo; cat "$file"
            } | call "$JUDGE_MODEL" "Score the answer per the rubric. Return only the JSON object." "$SCORE_SCHEMA")"
    total=$(printf '%s' "$raw" | jq -r '(.mechanism+.actionable+.specific+.tradeoff)' 2>/dev/null)
    [[ "$total" =~ ^[0-9]+$ ]] || { echo "  score failed $tag/$variant" >&2; continue; }
    b="$bytes"; [[ "$variant" == compressed ]] && b="$cbytes"
    printf '%s\t%s\t%s\t%s\n' "$tag" "$variant" "$b" "$total" >> "$OUT/scores.tsv"
    echo "  $tag $variant ${b}b score=$total" >&2
  done
done

echo ""
echo "# Length causality"
echo
printf '| answer | orig bytes | orig score | compressed bytes | compressed score | delta |\n'
printf '|---|---|---|---|---|---|\n'
cut -f1 "$OUT/scores.tsv" | sort -u | while read -r tag; do
  ob=$(awk -F'\t' -v t="$tag" '$1==t && $2=="original"{print $3}' "$OUT/scores.tsv")
  os=$(awk -F'\t' -v t="$tag" '$1==t && $2=="original"{print $4}' "$OUT/scores.tsv")
  cb=$(awk -F'\t' -v t="$tag" '$1==t && $2=="compressed"{print $3}' "$OUT/scores.tsv")
  cs=$(awk -F'\t' -v t="$tag" '$1==t && $2=="compressed"{print $4}' "$OUT/scores.tsv")
  [[ -n "$os" && -n "$cs" ]] || continue
  printf '| %s | %s | %s | %s | %s | %s |\n' "$tag" "$ob" "$os" "$cb" "$cs" "$(( cs - os ))"
done
echo
awk -F'\t' '$2=="original"{o[$1]=$4; ob[$1]=$3} $2=="compressed"{c[$1]=$4; cb[$1]=$3}
  END{
    for (k in o) if (k in c) { n++; d+=c[k]-o[k]; shrink+=1-(cb[k]/ob[k]) }
    if (n==0) { print "  no paired scores"; exit }
    printf "  n=%d  mean compression %.0f%%  mean score change %+.2f\n", n, 100*shrink/n, d/n
    if (d/n <= -1.0) print "  READING: the rubric pays for length. Fix the judging protocol."
    else if (d/n >= -0.5) print "  READING: compression barely moves the score — the rubric measures substance,"
    else print "  READING: mixed. Neither reading is clean at this sample size."
    if (d/n > -1.0 && d/n < -0.5) print "  Treat as inconclusive and widen the sample before acting."
    if (d/n >= -0.5) print "  so the length correlation is signal, not judge bias, and the primary metric"
    if (d/n >= -0.5) print "  is what needs rethinking rather than the judge."
  }' "$OUT/scores.tsv"
