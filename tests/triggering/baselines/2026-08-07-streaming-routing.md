# 2026-08-07 — streaming-data-engineering delivery routing

Model: opus. 3 reps per case. Scored with `rescore.sh` (chain-aware); the live
verdict from `run-matrix.sh` reads position 1 only and reported 16/19 for the same
data — do not cite it.

**19 of 19 PASS, 0 FLAKY.**

## The five cases this delivery had to satisfy

| case | verdict | position | what it proves |
|---|---|---|---|
| P9 | 3/3 | 1,1,1 | the plain positive routes without chaining |
| D8 | 3/3 | 1,1,1 | a prompt naming Spark still routes to streaming — the boundary edited into `spark-data-engineering` works in the hard direction |
| A13 | 3/3 | 2,2,2 | a prompt with no streaming vocabulary at all routes, and opens `event-time-windows-and-watermarks.md` |
| D6 | 3/3 | 2,2,2 | `spark`'s Structured Streaming boundary finally has somewhere to point |
| A8 | 3/3 | 1,1,1 | the case tagged `gap-streaming` is no longer a gap |

### Ground truth changed for D6 and A8, and why

Both expected `NONE` before this delivery, because no streaming skill existed.
That changed because the world changed, decided before the run — not because a
measurement disagreed with them. Their pre-streaming behaviour:

- **D6** (Spark Structured Streaming, backpressure): fired `spark` 4 of 5 before the
  phantom-reference mitigation, plus a fifth run that invoked a skill that did not exist,
  received `Unknown skill`, and never reached `spark` at all — the two sets are disjoint,
  as recorded in `GREEN-crowd-out.md`. After the mitigation, 1 of 5. Now 3/3 to streaming.
- **A8** (Kafka exactly-once into Delta): fired the orchestrator, which had nowhere to
  route. Now 3/3 to streaming.

## Regression — every description Task 8 touched

Four descriptions changed: `spark`, `modeling`, `quality`, and the `data-engineering`
orchestrator. `pipelines-architecture` kept its description byte-identical on purpose;
its replay/backfill split lives in the body instead.

**What that decision was and was not measured against.** D1 (dbt folder layering) and
P5 (Airflow vs Dagster) both hold at 3/3, but neither sits anywhere near the boundary
this delivery put at risk — they are orchestrator-choice and project-layout prompts, not
reprocessing prompts. The case actually at risk is **A2** (`matrix-adversarial.tsv`:
*"Relancé el proceso de ayer y ahora hay registros duplicados"*, EXPECTED
`pipelines-architecture-data-engineering`), because streaming's new description contains
"or when replaying a stream produced duplicates" — a near-verbatim lexical collision with
`pipelines-architecture`'s own "a rerun that produced duplicate rows", now competing from
a brand-new description, on a case already recorded FLAKY 4/5 in `GREEN-crowd-out.md`.
**A2 was not run in this campaign.** Neither was any `EXPECTED=NONE` case. Leaving
`pipelines-architecture`'s description untouched was still the right call — an unchanged
description is the smaller risk — but the 19/19 above does not test it.

| case | expected | hits | positions |
|---|---|---|---|
| A1 | quality-data-engineering | 3/3 | 1,1,1 |
| A10 | data-engineering | 3/3 | 1,1,1 |
| A13 | streaming-data-engineering | 3/3 | 2,2,2 |
| A3 | modeling-data-engineering | 3/3 | 1,1,1 |
| A4 | spark-data-engineering | 3/3 | 1,1,1 |
| A5 | spark-data-engineering|sql-data-engineering | 3/3 | 1,1,1 |
| A7 | modeling-data-engineering|pipelines-architecture-data-engineering | 3/3 | 1,1,1 |
| A8 | streaming-data-engineering | 3/3 | 1,1,1 |
| D1 | pipelines-architecture-data-engineering | 3/3 | 1,1,1 |
| D2 | quality-data-engineering|project-structure-data-engineering | 3/3 | 1,1,1 |
| D6 | streaming-data-engineering | 3/3 | 2,2,2 |
| D7 | modeling-data-engineering | 3/3 | 1,1,1 |
| D8 | streaming-data-engineering | 3/3 | 1,1,1 |
| P3 | spark-data-engineering | 3/3 | 1,1,1 |
| P4 | modeling-data-engineering | 3/3 | 1,1,1 |
| P5 | pipelines-architecture-data-engineering | 3/3 | 1,1,1 |
| P6 | quality-data-engineering | 3/3 | 1,1,1 |
| P8 | data-engineering | 3/3 | 2,2,2 |
| P9 | streaming-data-engineering | 3/3 | 1,1,1 |

All 14 regression cases hold at 3/3.

## What this does not establish

**A2 was not measured.** It is the case whose expected destination
(`pipelines-architecture`) now competes lexically with streaming's new description over
"replay produced duplicates", and it was already FLAKY 4/5 before this delivery. Nothing
in the 19 cases above covers it. Until A2 is re-run at the same rep count, the claim
"adding streaming cost `pipelines-architecture` nothing" is unsupported for the one
prompt where it was most likely to cost something.

**No `EXPECTED=NONE` case was measured.** Every case above expects a skill to fire. The
suite's *quietness* after adding a ninth description — that a prompt which should route
nowhere still routes nowhere — is therefore unverified for this delivery. That axis has
its own history: D6 and A8 both used to be `EXPECTED=NONE` cases, and the phantom-skill
incident was found on exactly that axis.

Both gaps are being closed in a separate run owned by the controller; this document will
be appended, not rewritten, when that result lands.

Routing, not answer quality. Whether the skill's content makes an answer better is a
separate axis, measured by `tests/quality-uplift/`, whose first campaign was published
VOID. And correctness of the content is a third axis, covered by the verification
documents under `docs/superpowers/research/`.
