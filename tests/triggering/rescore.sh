#!/usr/bin/env bash
# Re-score saved probe logs with chain-aware verdicts.
#
# The original verdict only looked at the FIRST skill a session invoked. That is
# the wrong rule in this environment: the superpowers SessionStart hook mandates
# a process skill first ("systematic-debugging first, THEN domain skills"), so a
# correct run often looks like
#   superpowers:systematic-debugging -> dataforge:<domain>
# and scoring position 1 marks that as a failure. A domain skill counts if it
# fires anywhere in the chain; POS records where.
#
# Reads results/<run>/<CASE>.rep<N>.jsonl plus the matrix that defines EXPECTED.
# Usage: ./rescore.sh <results-dir> <matrix.tsv> [<matrix.tsv> ...]

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DIR="${1:?usage: rescore.sh <results-dir> <matrix.tsv>...}"; shift
declare -A EXPECTED
for m in "$@"; do
  while IFS=$'\t' read -r id _cat exp _prompt; do
    [[ "$id" == "ID" || -z "${id// }" ]] && continue
    EXPECTED["$id"]="$exp"
  done < "$m"
done

printf 'ID\tEXPECTED\tHITS\tVERDICT\tPOSITIONS\tCHAINS\n'
for id in $(ls "$DIR" | sed -n 's/^\([A-Z][0-9]*\)\.rep[0-9]*\.jsonl$/\1/p' | sort -u); do
  exp="${EXPECTED[$id]:-?}"
  hits=0 reps=0 positions=() chains=()
  for f in "$DIR/$id".rep*.jsonl; do
    [[ -f "$f" ]] || continue
    reps=$((reps+1))
    chain=$(jq -r 'select(.type=="assistant") | .message.content[]?
                   | select(.type=="tool_use" and .name=="Skill") | .input.skill' \
            "$f" 2>/dev/null | sed 's/^dataforge://')
    [[ -n "$chain" ]] || chain="NONE"
    chains+=("$(echo "$chain" | paste -sd'>' -)")

    if [[ "$exp" == "NONE" ]]; then
      # A quiet run means no DOMAIN skill fired; process skills do not count.
      if ! grep -qv '^superpowers:' <<<"$chain" || [[ "$chain" == "NONE" ]]; then
        hits=$((hits+1)); positions+=(-)
      else
        positions+=(x)
      fi
      continue
    fi

    pos=0 found=0 n=0
    while IFS= read -r s; do
      n=$((n+1))
      if [[ "|$exp|" == *"|$s|"* ]]; then pos=$n; found=1; break; fi
    done <<<"$chain"
    if (( found )); then hits=$((hits+1)); positions+=("$pos"); else positions+=(x); fi
  done

  verdict="FAIL"
  (( hits == reps && reps > 0 )) && verdict="PASS"
  (( hits > 0 && hits < reps )) && verdict="FLAKY"

  printf '%s\t%s\t%s/%s\t%s\t%s\t%s\n' \
    "$id" "$exp" "$hits" "$reps" "$verdict" \
    "$(IFS=,; echo "${positions[*]}")" "$(IFS=' '; echo "${chains[*]}")"
done
