# RED baseline — chain-aware

State BEFORE the description edits. Scored with rescore.sh: the expected skill
counts if it fires anywhere in the invocation chain.

The superpowers SessionStart hook mandates a process skill first
("systematic-debugging first, THEN domain skills"), so the correct shape here is
often 'superpowers:X > dataforge:Y'. Scoring position 1 only — as an earlier
version of this harness did — marks that correct chaining as a failure and
manufactures a crowd-out finding that is not there.

## Opus, 3 reps per case (the model in daily use)

ID  EXPECTED                                      HITS  VERDICT  POSITIONS  CHAINS
A2  pipelines-architecture-data-engineering       0/3   FAIL     x,x,x      superpowers:systematic-debugging superpowers:systematic-debugging superpowers:systematic-debugging
A4  spark-data-engineering                        3/3   PASS     1,2,1      spark-data-engineering>superpowers:systematic-debugging superpowers:systematic-debugging>spark-data-engineering spark-data-engineering
A6  python-data-engineering|sql-data-engineering  1/3   FLAKY    2,x,x      superpowers:systematic-debugging>sql-data-engineering superpowers:systematic-debugging superpowers:systematic-debugging
P8  data-engineering                              3/3   PASS     2,2,2      superpowers:brainstorming>data-engineering superpowers:brainstorming>data-engineering superpowers:brainstorming>data-engineering

Genuine gaps: A2 never reached a domain skill; A6 reached one in 1 of 3.
A4 and P8 were already correct — they chain at position 1 or 2.

## Haiku, 5 reps per case

ID    HITS     VERDICT  POSITIONS
A1    0/5      FAIL     x,x,x,x,x
A10   0/5      FAIL     x,x,x,x,x
A2    0/5      FAIL     x,x,x,x,x
A4    0/5      FAIL     x,x,x,x,x
A6    0/5      FAIL     x,x,x,x,x
D1    0/5      FAIL     x,x,x,x,x
D2    0/5      FAIL     x,x,x,x,x
D3    5/5      PASS     1,1,1,1,1
D4    0/5      FAIL     x,x,x,x,x
D5    0/5      FAIL     x,x,x,x,x
D6    5/5      PASS     -,-,-,-,-
D7    5/5      PASS     1,1,1,1,1
P1    3/5      FLAKY    1,1,x,1,x
P2    0/5      FAIL     x,x,x,x,x
P3    1/5      FLAKY    x,x,1,x,x
P4    5/5      PASS     1,1,1,1,1
P6    4/5      FLAKY    1,1,x,1,1
P8    0/5      FAIL     x,x,x,x,x

Haiku barely chains: it mostly fires nothing. Its failures are model capability,
not description quality — 6 of its 11 failures pass cleanly on sonnet.
