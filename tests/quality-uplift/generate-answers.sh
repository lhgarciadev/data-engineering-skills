#!/usr/bin/env bash
# Generate answers for the quality-uplift eval in both arms.
#
# with-arm samples are only accepted when the case's expected skill actually
# fired, checked across the whole invocation chain. A sample where it never
# fired is not a measurement of the skill; it is noise, and averaging it in
# would understate the very thing being measured.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASES="${CASES:-$SCRIPT_DIR/cases.tsv}"   # overridable so the gate test can inject a fixture
PLUGIN_ID="dataforge@skills-dir"
ANSWER_MODEL="opus"
REPS=3
MAX_ATTEMPTS=3
MIN_AVAIL_MB=1200
RUN=""

while getopts "r:m:n:o:c:" opt; do
  case "$opt" in
    r) REPS="$OPTARG" ;;
    m) ANSWER_MODEL="$OPTARG" ;;
    n) MAX_ATTEMPTS="$OPTARG" ;;
    o) RUN="$OPTARG" ;;
    c) ONLY_CASE="${OPTARG}" ;;
    *) echo "unknown option" >&2; exit 64 ;;
  esac
done
ONLY_CASE="${ONLY_CASE:-}"
[[ -n "$RUN" ]] || RUN="$SCRIPT_DIR/results/run"
mkdir -p "$RUN"
: > "$RUN/discards.tsv"

await_memory() {
  local avail
  for _ in $(seq 1 120); do
    avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
    (( avail >= MIN_AVAIL_MB )) && return 0
    echo "  waiting for memory: ${avail}MB" >&2
    sleep 10
  done
}

# Runs one probe. Echoes: <chain>\t<chars>\t<out_tokens>\t<cost>
# Writes the answer text to $4.
probe() {
  local prompt="$1" arm="$2" tag="$3" out_txt="$4"
  local log="$RUN/$tag.jsonl" sandbox
  local settings_args=()
  [[ "$arm" == "without" ]] && \
    settings_args=(--settings "{\"enabledPlugins\":{\"$PLUGIN_ID\":false}}")

  await_memory
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/qprobe-XXXXXX")"
  ( cd "$sandbox" && timeout 900 claude \
      --model "$ANSWER_MODEL" \
      --output-format stream-json --verbose \
      --strict-mcp-config \
      --disallowedTools "Bash" "Write" "Edit" "Task" \
      "${settings_args[@]}" \
      -p "$prompt" ) >"$log" 2>&1 </dev/null
  rm -rf "$sandbox"

  jq -r 'select(.type=="result") | .result // ""' "$log" > "$out_txt" 2>/dev/null

  local chain chars toks cost
  chain=$(jq -r 'select(.type=="assistant") | .message.content[]?
                 | select(.type=="tool_use" and .name=="Skill") | .input.skill' \
          "$log" 2>/dev/null | sed 's/^dataforge://' | paste -sd, -)
  [[ -n "$chain" ]] || chain="NONE"
  chars=$(wc -c < "$out_txt" | tr -d ' ')
  toks=$(jq -r 'select(.type=="result") | .usage.output_tokens // 0' "$log" 2>/dev/null | head -1)
  cost=$(jq -r 'select(.type=="result") | .total_cost_usd // 0' "$log" 2>/dev/null | head -1)
  printf '%s\t%s\t%s\t%s\n' "$chain" "$chars" "$toks" "$cost"
}

while IFS=$'\t' read -r id skill prompt; do
  [[ "$id" == "ID" || -z "${id// }" ]] && continue
  [[ -n "$ONLY_CASE" && "$id" != "$ONLY_CASE" ]] && continue

  for arm in with without; do
    for (( rep=1; rep<=REPS; rep++ )); do
      tag="$id.$arm.rep$rep"
      accepted=0
      for (( att=1; att<=MAX_ATTEMPTS; att++ )); do
        read -r chain chars toks cost < <(probe "$prompt" "$arm" "$tag" "$RUN/$tag.txt")

        # Non-emptiness floor, both arms. An empty answer is an infrastructure
        # failure, not a measurement: a timeout kill or a log with no result
        # event leaves a 0-byte file that would otherwise be written up as a
        # well-formed sample and averaged in as if it were a real answer.
        if [[ ! -s "$RUN/$tag.txt" ]]; then
          printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$arm" "$rep" "$att" "EMPTY" \
            >> "$RUN/discards.tsv"
          echo "  discard $tag attempt $att: empty answer" >&2
          continue
        fi

        # The without-arm has no ROUTING gate: its natural behaviour, including a
        # superpowers process skill answering instead, is the counterfactual, and
        # rejecting a sample for not loading a skill would destroy it.
        if [[ "$arm" == "without" ]]; then accepted=1; break; fi

        if [[ ",$chain," == *",$skill,"* ]]; then accepted=1; break; fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$arm" "$rep" "$att" "$chain" \
          >> "$RUN/discards.tsv"
        echo "  discard $tag attempt $att: $skill never fired (chain=$chain)" >&2
      done

      if (( accepted )); then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$id" "$arm" "$rep" "$chain" "$chars" "$toks" "$cost" "$att" \
          > "$RUN/$tag.meta"
        echo "  ok $tag chain=$chain chars=$chars" >&2
      else
        rm -f "$RUN/$tag.txt"
        echo "  UNMEASURABLE $tag after $MAX_ATTEMPTS attempts" >&2
      fi
    done
  done
done < "$CASES"

echo "run=$RUN" >&2
ls "$RUN"/*.meta 2>/dev/null | wc -l | xargs -I{} echo "accepted samples: {}" >&2
