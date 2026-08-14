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

# Two different leaks, two different checks.
#
# (a) A *filename* leak: the harness's own paths reaching the model.
#
# The previous version of this block also grepped for `EXPECTED`, a column that
# exists in tests/triggering/matrix.tsv and NOT in cases.tsv — so that third
# pattern could never match a quality-uplift answer. It cost nothing and caught
# nothing, which is the worst combination: the check reported PASS either way.
grep -l "qprobe-\|cases.tsv" "$RUN"/*.txt >/dev/null 2>&1 \
  && note FAIL "harness filenames leaked into an answer" \
  || note PASS "no filename leak"

# (b) A *content* leak: another case's prompt reaching the model, which is what
# happens when the whole TSV goes down stdin instead of one row. A filename
# never appears in that failure — only the other rows' text does — so (a) is
# blind to it, and this is the leak the check was written to catch.
#
# Self is excluded on purpose: an answer legitimately echoes its own question,
# so matching against its own prompt would fire on every well-behaved run. Only
# a *foreign* prompt is evidence. The signature is the prompt's first 40
# characters; all 7 are distinct at that length (verify with:
# `tail -n +2 cases.tsv | cut -f3 | cut -c1-40 | sort -u | wc -l`).
leak=""
for f in "$RUN"/*.txt; do
  [[ -f "$f" ]] || continue
  own="$(basename "$f")"; own="${own%%.*}"
  while IFS=$'\t' read -r id _skill prompt; do
    [[ "$id" == "ID" || "$id" == "$own" || -z "$prompt" ]] && continue
    sig="$(printf '%s' "$prompt" | cut -c1-40)"
    grep -qF -- "$sig" "$f" 2>/dev/null && leak="$leak $(basename "$f")<-$id"
  done < cases.tsv
done
[[ -n "$leak" ]] \
  && note FAIL "another case's prompt leaked into an answer:$leak" \
  || note PASS "no cross-case content leak"

exit $fail
