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

All 19 regression cases hold at 3/3.

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

## Appendix — the two gaps this campaign did not cover, measured separately

The whole-branch review flagged that the 19 cases above measured the ones most
likely to pass: A2, whose prompt lexically collides with the new description, and
every `EXPECTED=NONE` case, so the suite's quietness after adding a skill was
unverified. Both were run afterwards, on opus, and are recorded here rather than
left as an open claim.

### The negatives — clean

| case | hits | verdict |
|---|---|---|
| N1 | 3/3 | PASS |
| N2 | 3/3 | PASS |
| N3 | 3/3 | PASS |
| N4 | 3/3 | PASS |

Adding a skill did not make the suite noisier. N1–N4 stay silent 3/3.

### A2 — the collision hypothesis is refuted

**Streaming never fired on A2.** Across ten reps run today, the only skills invoked
were `superpowers:systematic-debugging` (6) and `pipelines-architecture-data-engineering`
(5). The new description does not capture the prompt, so the lexical collision
between "replaying a stream produced duplicates" and "relancé el proceso y ahora hay
registros duplicados" did not cost pipelines the case.

What the reps do show is that A2 is unstable, and was already:

| when | reps | reached pipelines |
|---|---|---|
| before streaming existed (opus) | 5 | 4 — recorded FLAKY |
| today (opus) | 10 | 5 |

That is not a regression this branch can be charged with. `pipelines-architecture`'s
description is byte-identical to what it was before this delivery — verified, not
assumed — so the stimulus A2 responds to did not change. The honest reading is that
A2 is a genuinely flaky case, the earlier 4/5 was the lucky end of that instability,
and ten reps place it near half.

It remains the weakest case in the suite and deserves attention on its own terms —
a body-level fix or a re-worded case, not a description edit, since the descriptions
are what the 19/19 above was measured against.
