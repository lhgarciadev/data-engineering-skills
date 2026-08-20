# Pre-commit gates

Six checks that used to be human discipline. Four of them had each already let a
defect reach a commit at least once before this directory existed. The other two
are preventive and marked as such below.

| Gate | What it catches | Where it failed before |
|---|---|---|
| Local username leak | `/home/<user>/`, `/Users/<user>/`, and the sanitised `-home-<user>-dev-` form that appears inside scratchpad paths | Twice in implementation plans, and in two research docs that had already been pushed |
| Phantom skill reference | a `*-data-engineering` name with no matching directory under `skills/` | The phantom-invocation bug: a body naming a skill nobody could load |
| Stale "no skill yet" claim | text asserting a data-engineering domain has no skill in the suite | The README still said 8 of 9 after the suite closed at 9/9 |
| Reference file over 3500 words | any `skills/*/references/*.md` file exceeding the 3500-word ceiling | `event-time-windows-and-watermarks.md` shipped at 3503 words, past the 1600-3500 band its own delivery declared |
| Chain extractor drift | the three copies of the `jq` filter that defines "the skill fired" no longer agree, checked whenever one of the three scripts is staged | Nowhere yet — preventive. The three agreed when the gate landed; what earned it is that this filter is the operational definition of the measurement, so a divergence makes the two harnesses disagree about what they measured with nothing to reveal it |
| Frontmatter over the 1024-byte cap | any `skills/*/SKILL.md` whose frontmatter block, counted in bytes, exceeds 1024 | Nowhere yet — this is the one gate here that is preventive. Every skill delivery since 2026-08-07 checked the cap by hand, and it held; what earned the gate is that `pipelines-architecture` sits at 1021 bytes and `streaming` at 1015, so the next added clause breaks discovery in silence |

The first run of this script found three live defects, all three of them
already public. That is the argument for the directory.

**On bytes rather than characters, for the frontmatter gate.** The metric is
the whole block between the `---` markers measured with `wc -c`, the same
command the skill implementation plans have specified since 2026-08-07. It is
the conservative reading and the difference is not academic: these descriptions
are written with em dashes, which cost three bytes each, so a character count
reads several dozen bytes lower than the cap actually sees. Measuring the
description text alone — rather than the whole block — reads lower still, and
is the mistake to avoid when re-checking headroom by hand.

## Why only the ceiling is gated, not the floor

Three of the nine skills (`modeling`, `streaming`, `iac-cloud`) declared a
1600-3500 word band for their reference files. The other six were written at
a much smaller scale — 33 of their reference files sit between 352 and 1537
words, and none of that is a defect: they were never written to that band.
A floor check would flag those files wrongly, over and over, and a gate that
cries wolf is a gate people learn to skip. So gate 4 checks the ceiling only:
no reference file should exceed 3500 words regardless of which skill wrote
it, because past that point it stops being readable in one sitting. The
floor stays a per-skill design decision, deliberately left ungated. If you
are tempted to "complete" the band by adding a floor check, don't — that
reintroduces exactly the false positives this decision exists to avoid.

## Running it

```bash
tests/gates/pre-commit-gates.sh          # what is staged right now
tests/gates/pre-commit-gates.sh --all    # audit the whole tree
```

Exit 0 is clean. Exit 1 names the gate, the file and the line.

## Wiring it up

The script is versioned; the wiring is local, because `.claude/` and `.git/`
are both untracked here.

**Git commits from a terminal** — one command, and it survives every future
clone-and-reinstall because it delegates rather than copies:

```bash
printf '#!/usr/bin/env bash\nexec "$(git rev-parse --show-toplevel)/tests/gates/pre-commit-gates.sh"\n' \
  > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

**Commits made by Claude Code** — add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "cmd=$(jq -r '.tool_input.command // \"\"'); case \"$cmd\" in *\"git commit\"*) ;; *) exit 0 ;; esac; root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0; [ -x \"$root/tests/gates/pre-commit-gates.sh\" ] || exit 0; out=$(\"$root/tests/gates/pre-commit-gates.sh\" 2>&1) && exit 0; printf \"%s\" \"$out\" | jq -Rs \"{hookSpecificOutput:{hookEventName:\\\"PreToolUse\\\",permissionDecision:\\\"deny\\\",permissionDecisionReason:.}}\"",
            "timeout": 30,
            "statusMessage": "Verificando compuertas pre-commit"
          }
        ]
      }
    ]
  }
}
```

Two things in that command look like clutter and are not. An earlier version of
this block had both bugs, and both fail silently — the hook stays quiet, and quiet
reads exactly like "nothing to report".

- **The path is resolved through `git rev-parse`, not written relative.** A hook
  command inherits whatever working directory the caller happens to have. From
  anywhere but the repo root, a relative `tests/gates/pre-commit-gates.sh` is
  `not found` — and a gate that cannot find itself blocks nothing.
- **The `git commit` filter lives inside the command, not in an `if` field.**
  Command hooks take `type`, `command`, `timeout` and `statusMessage`; an `if`
  key is not part of the schema, so it is ignored rather than rejected and the
  hook fires on *every* Bash call. The payload arrives on stdin, so the filter
  reads `.tool_input.command` and exits 0 early when it is not a commit.

After installing it, prove it denies — a hook that is silent on a real violation
is indistinguishable from one that is working:

```bash
CMD=$(jq -re '.hooks.PreToolUse[]|select(.matcher=="Bash")|.hooks[]|select(.type=="command")|.command' .claude/settings.json)
printf 'ruta: /home/probando/dev/cosa\n' > docs/leak-probe.md && git add docs/leak-probe.md
echo '{"tool_input":{"command":"git commit -m x"}}' | bash -c "$CMD" | jq -r '.hookSpecificOutput.permissionDecision'
git rm -q --cached docs/leak-probe.md && rm -f docs/leak-probe.md
```

Expected: `deny`. Anything else — including no output — means the hook is not
wired, whatever the JSON looks like.

## Deliberately skipping a gate

```bash
git commit --no-verify
```

Worth doing occasionally — a gate that can never be overridden gets disabled
wholesale the first time it is wrong. Worth noticing every time, because all
three of these fire on things that were shipped by someone who was sure they
had checked.

## Adding a gate

A check earns a place here when it has caught a real defect **and** the defect
class is invisible to reading. Both halves matter: a gate for something a
reviewer would have spotted anyway is noise, and noise is how a gate becomes
something people learn to scroll past.

The frontmatter and chain-extractor gates satisfy the second half and not the
first, which is why both are labelled preventive in the table. A gate may be
added on the strength of the invisibility half alone when the property it guards
cannot be judged by eye and one ordinary edit is enough to break it — state
which half is missing rather than implying both are met.

And test the gate against the failure it claims to catch, not only against the
current tree. The chain-extractor gate shipped its first version comparing only
behaviour on a fixture, and a real mutation of the filter passed it, because the
fixture never exercised the branch the mutation changed. That version reported
agreement it had not established. The published version compares the filter text
as well, and tolerates reformatting by normalising whitespace.

Before adding one, run it in `--all` mode against the current tree. If it
reports anything that is not a genuine defect, tighten it until it does not —
the first version of the phantom-skill gate read the `t` of a `\t` escape as
part of a skill name, and the first version of the stale-claim gate flagged
dated plans that quote the phrase in order to forbid it.
