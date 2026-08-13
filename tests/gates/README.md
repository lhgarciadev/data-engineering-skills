# Pre-commit gates

Four checks that used to be human discipline. Each of them had already let a
defect reach a commit at least once before this directory existed.

| Gate | What it catches | Where it failed before |
|---|---|---|
| Local username leak | `/home/<user>/`, `/Users/<user>/`, and the sanitised `-home-<user>-dev-` form that appears inside scratchpad paths | Twice in implementation plans, and in two research docs that had already been pushed |
| Phantom skill reference | a `*-data-engineering` name with no matching directory under `skills/` | The phantom-invocation bug: a body naming a skill nobody could load |
| Stale "no skill yet" claim | text asserting a data-engineering domain has no skill in the suite | The README still said 8 of 9 after the suite closed at 9/9 |
| Reference file over 3500 words | any `skills/*/references/*.md` file exceeding the 3500-word ceiling | `event-time-windows-and-watermarks.md` shipped at 3503 words, past the 1600-3500 band its own delivery declared |

The first run of this script found three live defects, all three of them
already public. That is the argument for the directory.

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
            "if": "Bash(git commit *)",
            "command": "out=$(tests/gates/pre-commit-gates.sh 2>&1); if [ -n \"$out\" ]; then printf \"%s\" \"$out\" | jq -Rs \"{hookSpecificOutput:{hookEventName:\\\"PreToolUse\\\",permissionDecision:\\\"deny\\\",permissionDecisionReason:.}}\"; fi",
            "timeout": 30,
            "statusMessage": "Verificando compuertas pre-commit"
          }
        ]
      }
    ]
  }
}
```

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

Before adding one, run it in `--all` mode against the current tree. If it
reports anything that is not a genuine defect, tighten it until it does not —
the first version of the phantom-skill gate read the `t` of a `\t` escape as
part of a skill name, and the first version of the stale-claim gate flagged
dated plans that quote the phrase in order to forbid it.
