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
| Testing only the "happy path" | Add edge cases: nulls, duplicates, malformed schemas, empty batches |
| Hardcoded connection strings/paths in code | Externalize via env vars / config files / `pydantic-settings` |
| No type hints on transformation functions | Add them and check with Pyright/mypy in CI — catches shape bugs pre-runtime |
