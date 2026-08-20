# Production Patterns

Everything else in this skill is "knows Python." This is "knows how to engineer with it" — the difference that actually shows up at senior level.

## Testing

Don't ship a pipeline without tests. With `pytest`: fixtures to set up test data, `unittest.mock` to fake the source/API/DB so tests don't depend on external services, and tests of transformation logic against edge cases (nulls, duplicates, malformed schemas). This is exactly what the dependency-injection pattern in [oop-for-pipelines.md](oop-for-pipelines.md) exists to enable.

```python
def test_keep_valid_drops_malformed_rows():
    rows = [["a", "1", "x"], ["bad"], ["b", "2", "y"]]
    assert len(list(keep_valid(rows))) == 2
```

For transformation logic with many edge cases, consider `hypothesis` for property-based testing (generate inputs, assert invariants) alongside example-based `pytest` tests — it tends to surface edge cases (empty inputs, extreme values, unusual duplicates) that hand-written test cases miss.

## Deciding whether to write the extractor at all

Everything below assumes a prior call: that this extraction is yours to write. That is a **build-vs-buy** decision with three options — hand-written, which is what this file teaches; a declarative EL library embedded in your own code, where dlt is the current Python exponent alongside the Singer/Meltano ecosystem named later in this file; or a managed connector service such as Airbyte or Fivetran.

A library of the second kind takes over normalizing nested data into relational tables, schema inference and destination migration, incremental state persistence, and keyed merge/upsert. It does not take over your source logic, pipeline-level retries (dlt's own docs: *"By default, `dlt` does not retry any of the pipeline steps"*), orchestration, the transformation layer, or the policy decision of what a schema change should do.

Four questions separate the three:

- **Does a maintained connector already exist for this exact source?** The most load-bearing question, and nearly binary. Vendor catalogues are tiered, and only the top tier carries a maintenance commitment — Airbyte documents archiving connectors it sees little usage of.
- **How many sources will you maintain?** One well-understood source rarely repays a framework; a dozen usually does.
- **Is nested-to-relational normalization a real problem here,** or is the payload already flat?
- **Who operates what you buy, and how is it billed** — runtime hours, modified rows, or your own time?

Check the licensing line before choosing the middle option: the dlt library is Apache-2.0, but its managed runtime, data-quality checks, transformation layer, and some of its sources and destinations — SQL Server Change Tracking among them, the mechanism recommended further down — are a separately licensed commercial product. "Open source library" and "the feature I need is open source" are different claims.

One caveat over all of it: every published ladder for this decision is written by someone selling one of the three options. The four questions survive that bias because they ask about your situation rather than asserting anything about a product.

## Idempotency and safe reruns

Write pipelines that can run twice without duplicating or corrupting data. The pattern every major orchestrator (Airflow, Dagster, Prefect) converges on is the same: **overwrite-or-merge by partition/key, never blind append.** Re-running the task for the same logical partition should produce the same end state, not a duplicate. Concretely:

- Write with upsert/merge keyed by a natural or partition key, not `INSERT`/append.
- Use checkpoints so a failed run resumes instead of restarting from scratch.
- Design backfills around reprocessing a specific partition, not "run the whole thing again and hope."

Dagster's partitioned assets (backfill by partition) are the clearest embodiment of this; Airflow relies on `catchup`/backfill plus disciplined idempotent task design; Prefect adds retries with cache-key short-circuiting on top of the same idea. When an interviewer asks "what happens if the job fails halfway and you rerun it?" — this is the answer.

This is the *task* side of idempotency — the code you write inside one task. For the complementary *DAG* side — how the orchestration layer itself (data intervals, partition-parameterized runs, backfill triggering) has to be designed so reprocessing is safe regardless of what's inside any single task — see the `pipelines-architecture-data-engineering` skill's [idempotency-and-backfills.md](../../pipelines-architecture-data-engineering/references/idempotency-and-backfills.md).

## Incremental extraction: tracking what's new

Idempotent upserts above solve the *write* side of a safe rerun — once you have the changed rows, applying them twice is harmless. They don't solve a different problem: how does the pipeline know *which* rows to pull on this run in the first place? That's the watermark (a.k.a. high-water-mark, or "cursor" in ELT-tool vocabulary) pattern — track the last-seen value of an ever-increasing column (usually `updated_at`, sometimes a monotonic ID/version) from the previous run, and pull only rows past it. The query mechanics live in [sql's engineering-query-patterns.md](../../sql-data-engineering/references/engineering-query-patterns.md); this section is about where that state lives in the pipeline itself, since getting *that* wrong is what actually causes silent data loss.

**Where the watermark is persisted between runs matters more than the query that uses it** — three real patterns, not interchangeable:

- **A dedicated control table**, external to the orchestrator — the most portable choice, and the only one that survives an orchestrator migration.
- **Orchestrator-native state**, but pick the mechanism actually meant for cross-run persistence. Airflow's `XCom` is for passing data *between tasks within one DAG run* — it's not designed to persist a value across separate runs; use an Airflow `Variable` for that instead. Dagster's sensor `cursor` (`context.cursor` / `update_cursor()`) is the mechanism actually built for this — it's tracked by the Dagster daemon across evaluations specifically to avoid duplicate work. Prefect's `Variable` serves the same role for flows.
- **A checkpoint file**, the pattern the Singer/Meltano ELT ecosystem is built on: each run emits a `STATE` message to stdout, redirected to a file (`tap | target | tail -n 1 > state.json`), and the next run reads it back in. Simple, but it's now an artifact you have to manage and back up yourself.
- **State the library owns for you**, if you took the buy side of the decision above: dlt keeps the cursor in a `_dlt_pipeline_state` table in the destination, committed with the data rather than beside it. Its docs state the property you actually want from any of these four — the state at the destination stays at the point the load package was created, so **incremental cursors are not advanced past data that did not load**. Build that same invariant into a hand-rolled control table: the watermark advances only after the rows it covers are committed. What this pattern adds is a new way to lose the state — it is keyed on pipeline name, destination and dataset, so renaming any of the three looks exactly like a first run.

Picking the wrong one is the actual failure mode: state stored in something that doesn't outlive the run (a local variable, a task-only XCom) silently resets to "extract everything" or "extract nothing" on the next run, and neither failure looks like an error — it looks like a pipeline that ran successfully.

**Two pitfalls worth designing around deliberately:**

- **Boundary handling, which is one decision with deduplication rather than two.** Whether the watermark filter is exclusive-lower (`>`) or inclusive-lower (`>=`) is a real trade-off, not a rounding error — see the SQL reference for the exact mechanics. What ties it to dedup is that the boundary decides whether you need dedup at all: exclusive-lower accepts silently-skipped rows and needs none, while inclusive-lower re-reads the boundary row and is only safe if something downstream removes the duplicate. dlt's incremental loader is worth copying on this point because it wires the pair together instead of leaving it to the caller — its default range is inclusive on the start and exclusive on the end, it deduplicates by primary key or content hash under that default, and it disables dedup outright the moment you ask for an exclusive lower bound, set an end value for a backfill, or apply a lookback lag. That last case is the one to notice: with a lag the dedup responsibility moves to the destination, which is the same trade the lookback mitigation below asks you to make. Choose the pair, and if you build it by hand, be explicit about which half is carrying the safety.
- **A slow transaction committing after the watermark was already captured** is a real risk when polling a live OLTP source directly — the row's `updated_at` can be earlier than the watermark that was just recorded, so it never gets pulled by either this run or the next one. This is a known risk of timestamp-based polling generally, not something any specific tool guarantees you're protected from — if the source can have long-running transactions, budget for it (a small overlap/lookback window on the filter, re-processing the last few minutes of each pull, is the common mitigation) rather than assuming the watermark query is exact.

**Prefer a real monotonic sequence over an application timestamp when the source offers one.** A plain auto-increment primary key only ever catches new inserts — it says nothing about a row that was updated after its initial insert, which a watermark on `updated_at` would catch and an ID-based one would silently miss. Where the source exposes a genuine change-sequence (SQL Server/Azure SQL's Change Tracking is the clearest example, versioning inserts *and* updates), that's more robust than either — but most sources don't expose one, so `updated_at` polling remains the common case, pitfalls included.

None of this is needed for small or infrequently-updated sources — a full pull every run is trivially idempotent (there's no state to track, nothing to get out of sync) and often not meaningfully slower than maintaining watermark logic. See [sql's engineering-query-patterns.md](../../sql-data-engineering/references/engineering-query-patterns.md) for the full-load-vs-incremental trade-off in more depth.

## Error handling with a strategy

Not `try/except: pass`. Distinguish:

- **Retryable** errors (transient network blip) → retry with backoff (see [decorators-and-context-managers.md](decorators-and-context-managers.md)); for rate limits (429) specifically, see [external-api-integration.md](external-api-integration.md) for `Retry-After` handling and jitter.
- **Non-retryable** errors (malformed record, schema violation) → log it with context and route it to a dead-letter queue/table so one bad record doesn't halt the whole batch.
- **Structured logging**, not `print` — JSON logs with context (record id, batch id, stage) so failures are queryable, not just visible. `structlog` is the common choice for pipeline/service code (fast JSON output, integrates cleanly with OpenTelemetry); plain stdlib `logging` plus a JSON formatter is the safer default for a reusable library.
- Fail loudly when a failure genuinely should stop the pipeline (e.g., the sink is unreachable) — don't swallow everything just to keep the job "green."

## Configuration and hygiene

- Nothing hardcoded: externalize config via environment variables, config files, or `pydantic-settings`.
- Type hints on every signature, checked in CI. In practice teams run both **Pyright** (fast local/editor feedback) and **mypy** (better plugin support for things like SQLAlchemy/ORM-heavy code) — Pyright locally, one or both in CI. Type hints catch schema/shape bugs before the job runs, not just document intent.
- Packaging: pick one tool (Poetry or `uv`) for the whole package and commit to it — see [project-structure-data-engineering](../../project-structure-data-engineering/references/packaging-and-tooling.md) for the tradeoff and `pyproject.toml` conventions.

```python
def transform(rows: list[dict], config: PipelineConfig) -> Iterator[dict]:
    ...
```

## Common mistakes

| Mistake | Fix |
|---|---|
| `try/except: pass` swallowing all errors in a batch | Split retryable vs non-retryable; dead-letter the latter instead of silently dropping it |
| `print()` for pipeline logging | Structured logging (`structlog` or stdlib + JSON formatter) with record/batch/stage context |
| Append-only writes with no rerun story | Upsert/merge by partition key; make reruns idempotent by design |
| Declaring a `merge` write disposition without declaring the key | dlt's merge job *"falls back to append"* when no merge keys are discovered, and a hand-rolled merge usually does the same — the rerun duplicates instead of failing. Declare the key and confirm the disposition took effect |
| Storing a watermark in Airflow `XCom` expecting it to persist across DAG runs | XCom is scoped to one DAG run, so the next run starts as if no watermark existed — use an Airflow `Variable`, or an external control table, for state that must outlive a single run |
| Renaming a pipeline, destination or dataset that the watermark state is keyed on | The next run finds no state and silently restarts from scratch — assert on startup that a watermark was actually found instead of defaulting to "everything" |
| Assuming a full pull every run is always "the unsophisticated option" | For small or infrequently-updated sources it's simpler and trivially idempotent, with no state to lose sync with — reserve watermark/incremental logic for sources where a full pull is genuinely too slow |
| Testing only the "happy path" | Add edge cases: nulls, duplicates, malformed schemas, empty batches |
| Hardcoded connection strings/paths in code | Externalize via env vars / config files / `pydantic-settings` |
| No type hints on transformation functions | Add them and check with Pyright/mypy in CI — catches shape bugs pre-runtime |
