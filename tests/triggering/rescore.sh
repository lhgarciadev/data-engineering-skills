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
#
# Exits non-zero when it cannot score what it was pointed at, rather than
# printing a table of FAILs that look like findings. Three such cases:
#   - no expectation resolved for a case (a matrix argument was omitted)
#   - no expectations parsed at all
#   - the rep count on disk disagrees with what the run was instructed to
#     produce (see run-reps below)

set -uo pipefail

DIR="${1:?usage: rescore.sh <results-dir> <matrix.tsv>...}"; shift
[[ -d "$DIR" ]] || { echo "rescore: no such results dir: $DIR" >&2; exit 2; }

declare -A EXPECTED
N_EXPECTED=0
for m in "$@"; do
  [[ -f "$m" ]] || { echo "rescore: no such matrix: $m" >&2; exit 2; }
  while IFS=$'\t' read -r id _cat exp _prompt; do
    [[ "$id" == "ID" || -z "${id// }" ]] && continue
    EXPECTED["$id"]="$exp"
    N_EXPECTED=$((N_EXPECTED+1))
  done < "$m"
done
# Counted while parsing on purpose: `${#EXPECTED[@]}` on an empty associative
# array trips `set -u`, and that error does not stop the script — it degrades
# into the NOEXPECT path instead of refusing to score. Same defect shape this
# harness exists to catch.
if (( N_EXPECTED == 0 )); then
  echo "rescore: no expectations parsed from $# matrix argument(s) — nothing can be scored" >&2
  exit 2
fi

# The expected rep count comes from what the run was INSTRUCTED to produce, not
# from what survived on disk. run-matrix.sh writes run-reps before its first
# probe; without it a stale .rep*.jsonl from a longer earlier run inflates the
# denominator and manufactures a FLAKY verdict out of a complete run.
EXPECTED_REPS=""
if [[ -f "$DIR/run-reps" ]]; then
  EXPECTED_REPS="$(tr -dc '0-9' < "$DIR/run-reps")"
fi

UNRESOLVED=0 MISCOUNTED=0

printf 'ID\tEXPECTED\tHITS\tVERDICT\tPOSITIONS\tCHAINS\n'
for id in $(ls "$DIR" | sed -n 's/^\([A-Z][0-9]*\)\.rep[0-9]*\.jsonl$/\1/p' | sort -u); do
  exp="${EXPECTED[$id]:-}"
  hits=0 reps=0 positions=() chains=()
  for f in "$DIR/$id".rep*.jsonl; do
    [[ -f "$f" ]] || continue
    reps=$((reps+1))
    chain=$(jq -r 'select(.type=="assistant") | .message.content[]?
                   | select(.type=="tool_use" and .name=="Skill") | .input.skill' \
            "$f" 2>/dev/null | sed 's/^dataforge://')
    [[ -n "$chain" ]] || chain="NONE"
    chains+=("$(echo "$chain" | paste -sd'>' -)")

    [[ -n "$exp" ]] || { positions+=(?); continue; }

    # One rule for both shapes of expectation. "No domain skill fired" is
    # normalised to the token NONE and then matched like any other alternative,
    # so a bare NONE and an alternation containing NONE score identically —
    # scoring them apart is what misgraded A11.
    domain_chain="$(grep -v '^superpowers:' <<<"$chain" | grep -v '^NONE$' || true)"
    if [[ -z "$domain_chain" ]]; then
      if [[ "|$exp|" == *"|NONE|"* ]]; then hits=$((hits+1)); positions+=(-); else positions+=(x); fi
      continue
    fi

    pos=0 found=0 n=0
    while IFS= read -r s; do
      n=$((n+1))
      if [[ "|$exp|" == *"|$s|"* ]]; then pos=$n; found=1; break; fi
    done <<<"$chain"
    if (( found )); then hits=$((hits+1)); positions+=("$pos"); else positions+=(x); fi
  done

  if [[ -z "$exp" ]]; then
    verdict="NOEXPECT"; UNRESOLVED=$((UNRESOLVED+1)); exp="?"
  elif [[ -n "$EXPECTED_REPS" ]] && (( reps != EXPECTED_REPS )); then
    verdict="REPMISMATCH"; MISCOUNTED=$((MISCOUNTED+1))
  else
    verdict="FAIL"
    (( hits == reps && reps > 0 )) && verdict="PASS"
    (( hits > 0 && hits < reps )) && verdict="FLAKY"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$id" "$exp" "$hits/$reps" "$verdict" \
    "$(IFS=,; echo "${positions[*]}")" "$(IFS=' '; echo "${chains[*]}")"
done

rc=0
if (( UNRESOLVED > 0 )); then
  echo "rescore: $UNRESOLVED case(s) had no expectation — pass every matrix that defines them (verdict NOEXPECT, not FAIL)" >&2
  rc=1
fi
if (( MISCOUNTED > 0 )); then
  echo "rescore: $MISCOUNTED case(s) have a rep count other than the $EXPECTED_REPS this run was instructed to produce — stale or missing .rep*.jsonl (verdict REPMISMATCH)" >&2
  rc=1
fi
if [[ -z "$EXPECTED_REPS" ]]; then
  echo "rescore: NOTE — $DIR has no run-reps file, so the denominator came from the files on disk. A uniformly stale or missing rep is invisible in that mode." >&2
fi
exit $rc
