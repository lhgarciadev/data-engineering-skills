#!/usr/bin/env bash
# Triggering matrix runner for the dataforge skill suite.
#
# Measures which skill a fresh Claude Code session actually invokes for a given
# prompt, using objective tool-call evidence from the stream-json event log
# rather than the model's self-report.
#
# Arms:
#   with    - suite enabled (as installed)
#   without - suite disabled via a session-scoped enabledPlugins override,
#             leaving every other customization untouched
#
# Usage: ./run-matrix.sh [-m MODEL] [-a with|without] [-o OUTDIR] [-j JOBS] [-c CASE_ID]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MATRIX="$SCRIPT_DIR/matrix.tsv"
PLUGIN_ID="dataforge@skills-dir"

MODEL="haiku"
ARM="with"
OUTDIR=""
JOBS=1
ONLY_CASE=""
SUITE="base"
REPS=1
MIN_AVAIL_MB=1200

while getopts "m:a:o:j:c:f:r:" opt; do
  case "$opt" in
    m) MODEL="$OPTARG" ;;
    a) ARM="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;
    j) JOBS="$OPTARG" ;;
    c) ONLY_CASE="$OPTARG" ;;
    f) MATRIX="$OPTARG"; SUITE="$(basename "${OPTARG%.tsv}")" ;;
    r) REPS="$OPTARG" ;;
    *) echo "unknown option" >&2; exit 64 ;;
  esac
done

# This box is a 6 GB WSL2 instance that also hosts VS Code Server. Each probe is a
# ~500 MB node process, and running several at once has OOM'd the VM mid-run
# before. Default to serial, and never launch a probe without headroom.
await_memory() {
  local avail
  for _ in $(seq 1 120); do
    avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
    (( avail >= MIN_AVAIL_MB )) && return 0
    echo "  waiting for memory: ${avail}MB < ${MIN_AVAIL_MB}MB" >&2
    sleep 10
  done
  echo "  WARNING: proceeding with low memory (${avail}MB)" >&2
}

[[ -n "$OUTDIR" ]] || OUTDIR="$SCRIPT_DIR/results/$SUITE-$MODEL-$ARM"
mkdir -p "$OUTDIR"

# The without-arm disables only the suite. Every other plugin, CLAUDE.md, and
# hook stays in place so the arms differ by exactly one variable.
settings_args=()
if [[ "$ARM" == "without" ]]; then
  settings_args=(--settings "{\"enabledPlugins\":{\"$PLUGIN_ID\":false}}")
fi

probe_once() {
  local id="$1" prompt="$2" rep="$3"
  local log="$OUTDIR/$id.rep$rep.jsonl"

  await_memory

  # Each probe runs from an empty directory outside this repo. Claude Code
  # injects the working directory and its contents into session context, so a
  # probe launched from inside the repo sees the matrix file and the skill
  # sources and answers about the test instead of the prompt.
  local sandbox
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/dfprobe-$id-XXXXXX")"

  # stdin MUST be /dev/null. `claude -p` merges piped stdin into the prompt, and
  # this function runs inside a `while read ... < matrix.tsv` loop, so without
  # this every probe also received the remaining rows of the matrix — including
  # the EXPECTED column — and answered about the test instead of the prompt.
  #
  # --strict-mcp-config with no --mcp-config starts zero MCP servers: the probes
  # do not need them, they cost ~250 MB each, and dropping them keeps this VM
  # inside its memory budget. Applied to both arms, so it is not a confound.
  ( cd "$sandbox" && timeout 600 claude \
      --model "$MODEL" \
      --output-format stream-json --verbose \
      --strict-mcp-config \
      --disallowedTools "Bash" "Write" "Edit" "Task" \
      "${settings_args[@]}" \
      -p "$prompt" ) >"$log" 2>&1 </dev/null

  rmdir "$sandbox" 2>/dev/null || rm -rf "$sandbox"

  # Every skill the session invoked, in call order.
  local fired
  fired=$(jq -r 'select(.type=="assistant") | .message.content[]?
                 | select(.type=="tool_use" and .name=="Skill")
                 | .input.skill' "$log" 2>/dev/null \
          | sed 's/^dataforge://' | paste -sd, -)
  [[ -n "$fired" ]] || fired="NONE"
  echo "$fired"
}

run_case() {
  local id="$1" category="$2" expected="$3" prompt="$4"
  local hits=0 firsts=() k fired first

  for (( k=1; k<=REPS; k++ )); do
    fired="$(probe_once "$id" "$prompt" "$k")"
    first="${fired%%,*}"
    firsts+=("$first")
    if [[ "$expected" == "NONE" ]]; then
      [[ "$first" == "NONE" ]] && hits=$((hits+1))
    elif [[ "|$expected|" == *"|$first|"* ]]; then
      hits=$((hits+1))
    fi
    printf '  %-4s rep%-2s fired=%s\n' "$id" "$k" "$first" >&2
  done

  # Reference files opened across all reps, for routing depth.
  local refs
  refs=$(jq -r 'select(.type=="assistant") | .message.content[]?
                | select(.type=="tool_use" and .name=="Read")
                | .input.file_path' "$OUTDIR/$id".rep*.jsonl 2>/dev/null \
         | grep -o '[^/]*/references/[^/]*\.md' | sort -u | paste -sd, -)
  [[ -n "$refs" ]] || refs="-"

  # Distribution across reps: converged routing looks like one label repeated.
  local dist
  dist=$(printf '%s\n' "${firsts[@]}" | sort | uniq -c | sort -rn \
         | awk '{printf "%sx%s ",$1,$2}')

  local verdict="FAIL"
  (( hits == REPS )) && verdict="PASS"
  (( hits > 0 && hits < REPS )) && verdict="FLAKY"

  printf '%s\t%s\t%s\t%s/%s\t%s\t%s\t%s\n' \
    "$id" "$category" "$expected" "$hits" "$REPS" "$verdict" "${dist% }" "$refs" \
    >"$OUTDIR/$id.result"
  printf '  %-4s %-14s %-6s %s/%s  %s\n' \
    "$id" "$category" "$verdict" "$hits" "$REPS" "${dist% }" >&2
}

echo "arm=$ARM model=$MODEL out=$OUTDIR" >&2

running=0
while IFS=$'\t' read -r id category expected prompt; do
  [[ "$id" == "ID" ]] && continue
  [[ -z "${id// }" ]] && continue
  [[ -n "$ONLY_CASE" && "$id" != "$ONLY_CASE" ]] && continue

  run_case "$id" "$category" "$expected" "$prompt" &
  running=$((running + 1))
  if (( running >= JOBS )); then wait -n 2>/dev/null || wait; running=$((running - 1)); fi
done < "$MATRIX"
wait

{
  printf 'ID\tCATEGORY\tEXPECTED\tHITS\tVERDICT\tDISTRIBUTION\tREFS\n'
  cat "$OUTDIR"/*.result 2>/dev/null | sort
} > "$OUTDIR/summary.tsv"

pass=$(grep -c $'\tPASS\t' "$OUTDIR/summary.tsv" || true)
flaky=$(grep -c $'\tFLAKY\t' "$OUTDIR/summary.tsv" || true)
total=$(( $(wc -l < "$OUTDIR/summary.tsv") - 1 ))
echo "" >&2
echo "=== $ARM / $MODEL / ${REPS} reps : $pass PASS, $flaky FLAKY, of $total cases ===" >&2
column -t -s $'\t' "$OUTDIR/summary.tsv"
