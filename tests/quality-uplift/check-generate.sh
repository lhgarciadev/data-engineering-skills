#!/usr/bin/env bash
# Acceptance check for generate-answers.sh. Asserts on observable outputs only.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
RUN="results/acceptance"
fail=0
note() { printf '%s %s\n' "$1" "$2"; [[ "$1" == "FAIL" ]] && fail=1; return 0; }

rm -rf "$RUN"
./generate-answers.sh -c P4 -r 1 -o "$RUN" >/dev/null 2>&1

[[ -s "$RUN/P4.with.rep1.txt" ]] \
  && note PASS "with-arm answer is non-empty" \
  || note FAIL "with-arm answer missing or empty"

[[ -s "$RUN/P4.without.rep1.txt" ]] \
  && note PASS "without-arm answer is non-empty" \
  || note FAIL "without-arm answer missing or empty"

if [[ -f "$RUN/P4.with.rep1.meta" ]]; then
  IFS=$'\t' read -r _id _arm _rep chain bytes _t _c _a < "$RUN/P4.with.rep1.meta"
  [[ ",$chain," == *",modeling-data-engineering,"* ]] \
    && note PASS "validity gate accepted: expected skill in chain ($chain)" \
    || note FAIL "expected skill not in chain ($chain)"
  [[ "$bytes" -gt 200 ]] \
    && note PASS "answer length recorded ($bytes bytes)" \
    || note FAIL "answer length implausible ($bytes)"
else
  note FAIL "with-arm meta missing"
fi

cut -f4 "$RUN/P4.without.rep1.meta" 2>/dev/null | grep -q "data-engineering" \
  && note FAIL "without-arm loaded a suite skill — ablation broken" \
  || note PASS "without-arm loaded no suite skill"

grep -l "qprobe-\|cases.tsv\|EXPECTED" "$RUN"/*.txt >/dev/null 2>&1 \
  && note FAIL "scaffolding leaked into an answer" \
  || note PASS "no scaffolding leak"

exit $fail
