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
