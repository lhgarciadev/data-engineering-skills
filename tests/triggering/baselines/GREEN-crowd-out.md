# GREEN verification — chain-aware

State AFTER the description edits, with valid YAML frontmatter (an earlier run of
this same verification was discarded: a ': ' inside the unquoted description scalar
broke YAML parsing, so the frontmatter load state was unknown). Model: opus.

## Targets, 5 reps

ID    HITS     VERDICT  POSITIONS    CHAINS
A2    4/5      FLAKY    2,2,x,2,2    superpowers:systematic-debugging>pipelines-architecture-data-engineeri
A6    5/5      PASS     2,1,1,2,2    superpowers:systematic-debugging>python-data-engineering python-data-e

RED was A2 0/3, A6 1/3. Both now reach the domain skill, mostly at position 2,
chained after superpowers:systematic-debugging as that hook mandates.

## Regressions, 3 reps

ID    HITS     VERDICT  POSITIONS    CHAINS
D1    3/3      PASS     1,1,1        pipelines-architecture-data-engineering pipelines-architecture-data-en
D4    3/3      PASS     1,1,1        python-data-engineering python-data-engineering python-data-engineerin
D5    2/3      FLAKY    1,1,x        python-data-engineering python-data-engineering pipelines-architecture
P1    3/3      PASS     1,1,1        python-data-engineering python-data-engineering python-data-engineerin
P5    3/3      PASS     1,1,1        pipelines-architecture-data-engineering pipelines-architecture-data-en

## Watch item

D5 (idempotent S3 write inside a task) is 2/3, with one rep routing to
pipelines-architecture and stopping there. The trigger added to that skill —
'a rerun that produced duplicate rows' — is idempotency-adjacent and may have
blurred the python/pipelines boundary it is supposed to respect. Not a clean
comparison (pre-edit D5 was 3/3 on sonnet, this is opus), so re-run D5 with more
reps on both models before acting.

## Frontmatter cap trim, opus, 3 reps

modeling-data-engineering went 1132 -> 997 characters by dropping
coverage-inventory prose. Regression check, including the boundary clause that
was shortened (D3 must still route SCD Type 2 SQL to sql-data-engineering):

ID    HITS     VERDICT  POSITIONS    CHAINS
D3    3/3      PASS     1,1,1        sql-data-engineering sql-data-engineering sql-data-engineeri
D7    3/3      PASS     1,1,1        modeling-data-engineering modeling-data-engineering modeling
P4    3/3      PASS     1,1,1        modeling-data-engineering modeling-data-engineering modeling

## Phantom-skill mitigation, opus, verified fb8e9c2

Eleven cross-references in SKILL.md files, plus one in a reference file, pointed
at streaming-data-engineering and iac-cloud-data-engineering, which do not exist.
With 5 reps on D6 (Spark Structured Streaming) one probe in five invoked the
missing skill and received Unknown skill. The references were reworded to state
the skill does not exist and to say what to do instead.

### Target: D6, 5 reps

```
before  systematic-debugging > spark            x4
        systematic-debugging > streaming (ERR)  x1
after   systematic-debugging > spark            x1
        systematic-debugging                    x4
```

0/5 -> 4/5 against EXPECTED=NONE. Zero phantom invocations across all 29 probes.

Unanticipated second effect: spark's boundary now binds. It was crossed 4 of 5
times and is now crossed 1 of 5. A pointer to something that does not exist
invites a lookup; an instruction to answer directly closes the question. Same
shape as the earlier finding that conditionals bind where prohibitions do not.

### Regression: 12 cases across the 4 edited descriptions, 2 reps

ID    HITS     VERDICT  POSITIONS
A1    2/2      PASS     1,1
A10   2/2      PASS     1,1
A3    2/2      PASS     1,1
A4    2/2      PASS     1,1
A5    2/2      PASS     1,1
A7    2/2      PASS     1,1
D2    2/2      PASS     1,1
D7    2/2      PASS     1,1
P3    2/2      PASS     1,1
P4    2/2      PASS     1,1
P6    2/2      PASS     1,1
P8    2/2      PASS     2,2

12/12 PASS. No collateral damage to spark, modeling, quality, or the orchestrator.
