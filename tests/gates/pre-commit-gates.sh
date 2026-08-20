#!/usr/bin/env bash
# Pre-commit gates for the dataforge skills suite.
#
# Six checks. Most have already let a defect reach a commit at least once; the
# rest guard a quantity nobody can judge by eye. They ran as human discipline
# until now; this script is what stops them depending on someone remembering.
#
# Exit 0 = clean. Exit 1 = at least one gate failed (and says which).
#
# Scoped to STAGED content, so it judges what is about to be committed rather
# than whatever happens to be lying in the working tree.
#
# Usage:
#   tests/gates/pre-commit-gates.sh            # check staged changes
#   tests/gates/pre-commit-gates.sh --all      # audit the whole tree instead

set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

MODE="${1:-staged}"
FAILED=0

if [ "$MODE" = "--all" ]; then
  FILES=$(git ls-files '*.md' '*.sh' '*.json' '*.tsv')
else
  FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(md|sh|json|tsv)$' || true)
fi

[ -z "$FILES" ] && exit 0

fail() { echo "GATE FAILED — $1"; FAILED=1; }

# ---------------------------------------------------------------------------
# Gate 1: the local username leaking into a public repo.
#
# Two shapes, because the first version of this gate only knew the first one
# and missed two research docs that had already been pushed:
#   /home/<user>/... or /Users/<user>/...   — a literal path
#   -home-<user>-dev-...                    — the sanitised form tooling emits
#                                             inside /tmp scratchpad paths
# ---------------------------------------------------------------------------
HOME_HITS=$(echo "$FILES" | while read -r f; do
  case "$f" in tests/gates/*) continue ;; esac
  [ -f "$f" ] || continue
  grep -Hn -E '(/home/[a-z0-9_.-]+/|/Users/[A-Za-z0-9_.-]+/|-home-[a-z0-9_.-]+-dev-)' "$f" 2>/dev/null
done)
if [ -n "$HOME_HITS" ]; then
  fail "el usuario local se filtra en un repo publico. Usa \$(git rev-parse --show-toplevel) o rutas relativas."
  echo "$HOME_HITS" | sed 's/^/    /'
fi

# ---------------------------------------------------------------------------
# Gate 2: references to skills that do not exist — the phantom-skill bug.
#
# The name must be preceded by a real delimiter. Without that guard this fired
# on `printf 'GATE\tspark-data-engineering'`, reading the `t` of the tab escape
# as part of the name.
# ---------------------------------------------------------------------------
PHANTOMS=$(echo "$FILES" | while read -r f; do
  case "$f" in tests/gates/*) continue ;; esac
  [ -f "$f" ] || continue
  grep -ohE '(^|[ `"'"'"'(/:,])[a-z0-9]+(-[a-z0-9]+)*-data-engineering\b' "$f" 2>/dev/null \
    | sed -E 's/^[ `"'"'"'(/:,]//'
done | sort -u | while read -r name; do
  [ -d "skills/$name" ] || echo "$name"
done)
if [ -n "$PHANTOMS" ]; then
  fail "referencias a skills que no existen bajo skills/."
  echo "$PHANTOMS" | sed 's/^/    /'
fi

# ---------------------------------------------------------------------------
# Gate 3: claims that a data-engineering domain has no skill.
#
# True until 2026-08-08; false afterwards, because the suite closed at 9/9.
# Specs and plans are exempt: they are dated records of what was true when they
# were written, and several of them quote the phrase in order to forbid it.
# Everything a reader can act on — skills, README, docs outside those two
# directories — is in scope.
# ---------------------------------------------------------------------------
DEAD=$(echo "$FILES" | while read -r f; do
  case "$f" in
    tests/gates/*|docs/superpowers/plans/*|docs/superpowers/specs/*) continue ;;
  esac
  [ -f "$f" ] || continue
  grep -Hn -iE 'no skill in this suite|has no skill yet|is planned but does not exist|IaC/cloud skill is planned' "$f" 2>/dev/null
done)
if [ -n "$DEAD" ]; then
  fail "afirma que un dominio no tiene skill. La suite esta completa en 9/9."
  echo "$DEAD" | sed 's/^/    /'
fi


# ---------------------------------------------------------------------------
# Gate 4: a reference file over the 3500-word ceiling.
#
# Three of the nine skills (modeling, streaming, iac-cloud) declared a
# 1600-3500 word band for their reference files; the other six were written
# at a smaller scale and are not held to any band — see tests/gates/README.md
# for why the floor is deliberately not gated here. Only the ceiling is
# universal: past 3500 words a reference file stops being readable in one
# sitting, regardless of which skill wrote it.
# ---------------------------------------------------------------------------
OVERLONG=$(echo "$FILES" | while read -r f; do
  case "$f" in skills/*/references/*.md) ;; *) continue ;; esac
  [ -f "$f" ] || continue
  count=$(wc -w < "$f" | tr -d ' ')
  [ "$count" -gt 3500 ] && echo "$f: $count words"
done)
if [ -n "$OVERLONG" ]; then
  fail "un archivo de referencia supera las 3500 palabras."
  echo "$OVERLONG" | sed 's/^/    /'
fi

# ---------------------------------------------------------------------------
# Gate 5: a SKILL.md frontmatter over the 1024-byte cap.
#
# Past the cap the frontmatter stops loading and skill discovery breaks in the
# shape every other gate here exists for: nothing errors, the skill simply
# never fires. Nothing checked this until now, and the slack is thin — when
# this gate landed, pipelines-architecture measured 1021 bytes and streaming
# 1015, three and nine bytes under.
#
# The metric is the whole frontmatter block between the `---` markers counted
# in BYTES, which is what the skill implementation plans have specified since
# 2026-08-07. Bytes rather than characters is the conservative reading and the
# difference is real here: the em dashes these descriptions are written with
# cost three bytes each.
# ---------------------------------------------------------------------------
FRONTMATTER=$(echo "$FILES" | while read -r f; do
  case "$f" in skills/*/SKILL.md) ;; *) continue ;; esac
  [ -f "$f" ] || continue
  n=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f" | wc -c | tr -d ' ')
  [ "$n" -gt 1024 ] && echo "$f: $n bytes (cap 1024, se pasa por $((n - 1024)))"
done)
if [ -n "$FRONTMATTER" ]; then
  fail "un frontmatter de SKILL.md supera el cap de 1024 bytes. Recorta el inventario de cobertura de la description, nunca los triggers ni la clausula de limites."
  echo "$FRONTMATTER" | sed 's/^/    /'
fi

# ---------------------------------------------------------------------------
# Gate 6: the three copies of the chain extractor must still agree.
#
# Fires only when one of the three scripts that carry it is staged, which is
# exactly the moment the drift would be introduced. The check itself lives in
# chain-extractor-agreement.sh — it compares the filter text and its behaviour
# on a fixture, and its header explains why one of those two is not enough.
# ---------------------------------------------------------------------------
if echo "$FILES" | grep -qE '^(tests/triggering/(run-matrix|rescore)\.sh|tests/quality-uplift/generate-answers\.sh)$'; then
  if ! AGREE_OUT=$(tests/gates/chain-extractor-agreement.sh 2>&1); then
    fail "las tres copias del extractor de cadena no coinciden. Cambialas las tres en el mismo commit, o extrae tests/lib/probe.sh."
    echo "$AGREE_OUT" | sed 's/^/    /'
  fi
fi

if [ "$FAILED" -ne 0 ]; then
  echo
  echo "Para saltear deliberadamente: git commit --no-verify"
  exit 1
fi
exit 0
