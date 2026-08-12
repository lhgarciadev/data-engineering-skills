# Pre-commit gates

Three checks that used to be human discipline. Each of them had already let a
defect reach a commit at least once before this directory existed.

| Gate | What it catches | Where it failed before |
|---|---|---|
| Local username leak | `/home/<user>/`, `/Users/<user>/`, and the sanitised `-home-<user>-dev-` form that appears inside scratchpad paths | Twice in implementation plans, and in two research docs that had already been pushed |
| Phantom skill reference | a `*-data-engineering` name with no matching directory under `skills/` | The phantom-invocation bug: a body naming a skill nobody could load |
| Stale "no skill yet" claim | text asserting a data-engineering domain has no skill in the suite | The README still said 8 of 9 after the suite closed at 9/9 |

The first run of this script found three live defects, all three of them
already public. That is the argument for the directory.

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
