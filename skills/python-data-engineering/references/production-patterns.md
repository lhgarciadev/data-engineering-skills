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

## Idempotency and safe reruns

Write pipelines that can run twice without duplicating or corrupting data. The pattern every major orchestrator (Airflow, Dagster, Prefect) converges on is the same: **overwrite-or-merge by partition/key, never blind append.** Re-running the task for the same logical partition should produce the same end state, not a duplicate. Concretely:

- Write with upsert/merge keyed by a natural or partition key, not `INSERT`/append.
- Use checkpoints so a failed run resumes instead of restarting from scratch.
- Design backfills around reprocessing a specific partition, not "run the whole thing again and hope."

Dagster's partitioned assets (backfill by partition) are the clearest embodiment of this; Airflow relies on `catchup`/backfill plus disciplined idempotent task design; Prefect adds retries with cache-key short-circuiting on top of the same idea. When an interviewer asks "what happens if the job fails halfway and you rerun it?" — this is the answer.

## Incremental extraction: tracking what's new

Idempotent upserts above solve the *write* side of a safe rerun — once you have the changed rows, applying them twice is harmless. They don't solve a different problem: how does the pipeline know *which* rows to pull on this run in the first place? That's the watermark (a.k.a. high-water-mark, or "cursor" in ELT-tool vocabulary) pattern — track the last-seen value of an ever-increasing column (usually `updated_at`, sometimes a monotonic ID/version) from the previous run, and pull only rows past it. The query mechanics live in [sql's engineering-query-patterns.md](../../sql-data-engineering/references/engineering-query-patterns.md); this section is about where that state lives in the pipeline itself, since getting *that* wrong is what actually causes silent data loss.

**Where the watermark is persisted between runs matters more than the query that uses it** — three real patterns, not interchangeable:

- **A dedicated control table**, external to the orchestrator — the most portable choice, and the only one that survives an orchestrator migration.
- **Orchestrator-native state**, but pick the mechanism actually meant for cross-run persistence. Airflow's `XCom` is for passing data *between tasks within one DAG run* — it's not designed to persist a value across separate runs; use an Airflow `Variable` for that instead. Dagster's sensor `cursor` (`context.cursor` / `update_cursor()`) is the mechanism actually built for this — it's tracked by the Dagster daemon across evaluations specifically to avoid duplicate work. Prefect's `Variable` serves the same role for flows.
- **A checkpoint file**, the pattern the Singer/Meltano ELT ecosystem is built on: each run emits a `STATE` message to stdout, redirected to a file (`tap | target | tail -n 1 > state.json`), and the next run reads it back in. Simple, but it's now an artifact you have to manage and back up yourself.

Picking the wrong one is the actual failure mode: state stored in something that doesn't outlive the run (a local variable, a task-only XCom) silently resets to "extract everything" or "extract nothing" on the next run, and neither failure looks like an error — it looks like a pipeline that ran successfully.

**Two pitfalls worth designing around deliberately:**

- **Boundary handling.** Whether the watermark filter is exclusive-lower (`>`) or inclusive-lower (`>=`) is a real trade-off, not a rounding error — see the SQL reference for the exact mechanics. Pick one on purpose and know which failure mode you've accepted: silently-skipped rows, or duplicates that need downstream dedup.
- **A slow transaction committing after the watermark was already captured** is a real risk when polling a live OLTP source directly — the row's `updated_at` can be earlier than the watermark that was just recorded, so it never gets pulled by either this run or the next one. This is a known risk of timestamp-based polling generally, not something any specific tool guarantees you're protected from — if the source can have long-running transactions, budget for it (a small overlap/lookback window on the filter, re-processing the last few minutes of each pull, is the common mitigation) rather than assuming the watermark query is exact.

**Prefer a real monotonic sequence over an application timestamp when the source offers one.** A plain auto-increment primary key only ever catches new inserts — it says nothing about a row that was updated after its initial insert, which a watermark on `updated_at` would catch and an ID-based one would silently miss. Where the source exposes a genuine change-sequence (SQL Server/Azure SQL's Change Tracking is the clearest example, versioning inserts *and* updates), that's more robust than either — but most sources don't expose one, so `updated_at` polling remains the common case, pitfalls included.

None of this is needed for small or infrequently-updated sources — a full pull every run is trivially idempotent (there's no state to track, nothing to get out of sync) and often not meaningfully slower than maintaining watermark logic. See [sql's engineering-query-patterns.md](../../sql-data-engineering/references/engineering-query-patterns.md) for the full-load-vs-incremental trade-off in more depth.

## Error handling with a strategy

Not `try/except: pass`. Distinguish:

- **Retryable** errors (transient network blip, rate limit) → retry with backoff (see [decorators-and-context-managers.md](decorators-and-context-managers.md)).
- **Non-retryable** errors (malformed record, schema violation) → log it with context and route it to a dead-letter queue/table so one bad record doesn't halt the whole batch.
- **Structured logging**, not `print` — JSON logs with context (record id, batch id, stage) so failures are queryable, not just visible. `structlog` is the common choice for pipeline/service code (fast JSON output, integrates cleanly with OpenTelemetry); plain stdlib `logging` plus a JSON formatter is the safer default for a reusable library.
- Fail loudly when a failure genuinely should stop the pipeline (e.g., the sink is unreachable) — don't swallow everything just to keep the job "green."

## Configuration and hygiene

- Nothing hardcoded: externalize config via environment variables, config files, or `pydantic-settings`.
- Type hints on every signature, checked in CI. In practice teams run both **Pyright** (fast local/editor feedback) and **mypy** (better plugin support for things like SQLAlchemy/ORM-heavy code) — Pyright locally, one or both in CI. Type hints catch schema/shape bugs before the job runs, not just document intent.
- Packaging: `uv` + `pyproject.toml` is the current default for dependency/environment management (single lockfile, notably faster than Poetry); Poetry remains reasonable for publishing a library to PyPI.

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
| Storing a watermark in Airflow `XCom` expecting it to persist across DAG runs | XCom is scoped to one DAG run — the next run starts as if no watermark exists | Use an Airflow `Variable` (or an external control table) for state that must outlive a single run |
| Assuming a full pull every run is always "the unsophisticated option" | For small/infrequently-updated sources it's simpler and trivially idempotent — no state to lose sync with | Reserve watermark/incremental logic for sources where a full pull is actually too slow |
| Testing only the "happy path" | Add edge cases: nulls, duplicates, malformed schemas, empty batches |
| Hardcoded connection strings/paths in code | Externalize via env vars / config files / `pydantic-settings` |
| No type hints on transformation functions | Add them and check with Pyright/mypy in CI — catches shape bugs pre-runtime |
