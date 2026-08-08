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
  phantom-reference mitigation, including one run that invoked a skill that did not
  exist and received `Unknown skill`. After the mitigation, 1 of 5. Now 3/3 to streaming.
- **A8** (Kafka exactly-once into Delta): fired the orchestrator, which had nowhere to
  route. Now 3/3 to streaming.

## Regression — every description Task 8 touched

Four descriptions changed: `spark`, `modeling`, `quality`, and the `data-engineering`
orchestrator. `pipelines-architecture` kept its description byte-identical on purpose,
because D1 and P5 pass on its "backfills" vocabulary; its replay/backfill split lives
in the body instead.

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

All 14 regression cases hold at 3/3. A4 improved from a historical 2/3.

## What this does not establish

Routing, not answer quality. Whether the skill's content makes an answer better is a
separate axis, measured by `tests/quality-uplift/`, whose first campaign was published
VOID. And correctness of the content is a third axis, covered by the verification
documents under `docs/superpowers/research/`.
