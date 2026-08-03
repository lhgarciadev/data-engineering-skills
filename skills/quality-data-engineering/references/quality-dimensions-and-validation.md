# Quality Dimensions and Pipeline Validation

A pipeline can finish green, with zero errors, and still have silently corrupted its output — a `NOT IN` against a column that "usually" has no `NULL`s, a fan-out join that doubled the amounts, a join quietly downgraded to `INNER` that dropped rows nobody noticed. None of these raise an exception. Data quality is the discipline of turning failures like these from silent into loud, as early and as cheaply as possible.

## The seven "dimensions" — industry vocabulary, not a single certified standard

Data quality conversations lean on a set of named dimensions, but there is no single certified standard that defines them the same way everywhere. DAMA UK's 2013 whitepaper — the closest thing to an open-access primary source in this space — says so explicitly: "even amongst data quality professionals the key data quality dimensions are not universally agreed." Treat what follows as widely-used industry vocabulary, not a citation from one authoritative body.

Six of the seven below come from that DAMA UK whitepaper, with its own definitions:

| Dimension | Definition (DAMA UK) |
|---|---|
| Completeness | The proportion of stored data against the potential of "100% complete" |
| Uniqueness | No thing will be recorded more than once, based on how that thing is identified |
| Validity | Data conforms to the syntax (format, type, range) of its definition |
| Accuracy | The degree to which data correctly describes the "real world" object or event it represents |
| Consistency | The absence of difference when comparing two or more representations of a thing against a definition |
| Timeliness | The degree to which data represents reality from the required point in time |

The seventh, **referential integrity**, doesn't appear in DAMA UK's whitepaper at all — nor as a named characteristic in ISO/IEC 25012, the other formal reference point in this space. It earns its place here for a practical reason, not a standards one: it's exactly the check dbt's `relationships` test performs and names — "each `customer_id` in the `orders` model exists as an `id` in the `customers` table (also known as referential integrity)." Treat it as a seventh category added for engineering utility, anchored to that concrete test, not as a dimension any standards body names.

## Types of checks, from schema to volume

dbt ships four generic tests out of the box, each mapping to one or more dimensions above:

```yaml
# models/marts/core/_core__models.yml
models:
  - name: orders
    columns:
      - name: order_id
        tests:
          - not_null       # completeness
          - unique         # uniqueness
      - name: status
        tests:
          - accepted_values:   # validity / domain
              values: ['placed', 'shipped', 'completed', 'returned']
      - name: customer_id
        tests:
          - relationships:     # referential integrity
              to: ref('customers')
              field: customer_id
```

Freshness is checked the same way, against a source's `loaded_at_field` compared to a threshold:

```yaml
sources:
  - name: raw_jaffle_shop
    tables:
      - name: orders
        loaded_at_field: _etl_loaded_at
        freshness:
          warn_after: {count: 12, period: hour}
          error_after: {count: 24, period: hour}
```

Volume/count checks (a load with 10 rows when it always brings 10,000 is a failure even though every row is individually valid) aren't part of dbt-core — `equal_rowcount` and `fewer_rows_than` live in the `dbt-utils` package, so they only exist in a project that installs it.

A useful mental ordering is schema → null/completeness → uniqueness → range/domain → referential integrity → freshness → volume, roughly from cheapest to most expensive to compute (a `not_null` scan vs. a `relationships` join vs. a volume check that may need to compare against historical partitions). That ordering is a teaching heuristic for this skill, not something dbt itself publishes or ranks.

## Validating at the ingestion boundary

Fail fast at the point of entry — validate a payload the moment it enters your system, before a malformed record has a chance to propagate three layers downstream where it's much more expensive to trace back.

```python
from pydantic import BaseModel, ValidationError

class IncomingOrder(BaseModel):
    order_id: str
    customer_id: str
    amount: float
    status: str

try:
    order = IncomingOrder.model_validate(raw_payload)
except ValidationError as e:
    # one exception, carrying every field-level error found in this payload —
    # not just the first one Pydantic happened to hit
    log_and_quarantine(raw_payload, e.errors())
```

The nuance worth knowing: Pydantic's default behavior isn't "stop at the first bad field" — it collects every validation error in the payload and raises a single `ValidationError` carrying all of them. That's still fail-fast in the sense that matters here (the whole record fails at one controlled point, before it can propagate), just not first-error-and-stop at the field level. A separate `FailFast` annotation (Pydantic v2.8+) does implement stop-at-first-invalid-item, but it's scoped to validating a list/sequence of items, not the general record-validation path shown above — don't confuse the two.

Which library to reach for to validate a single dataframe or payload — Pydantic vs. Pandera vs. Great Expectations — is covered in [python-data-engineering's data-validation.md](../../python-data-engineering/references/data-validation.md), not here. This file only covers *why* validating at the boundary matters; that one covers *which tool*.

## Schema-on-write vs. schema-on-read, and where medallion fits

A warehouse is schema-on-write: it rejects data that doesn't match the target table's schema at write time. A data lake's raw zone is typically schema-on-read: it accepts data in whatever shape it arrives, and structure gets imposed only when something reads it later — flexible, but dangerous without a validation step somewhere downstream.

The medallion pattern resolves that tension by picking where validation happens, not whether it happens. Databricks' own medallion architecture documentation is explicit about this split: the bronze layer applies "minimal data validation," storing most fields loosely-typed to protect against unexpected schema changes; the transition into the silver layer is where "schema enforcement," "schema evolution," "data deduplication," and "data quality checks and enforcement" actually happen. Land permissively, validate strictly at the boundary into the layer people actually query. See [pipelines-architecture-data-engineering's dbt-project-architecture.md](../../pipelines-architecture-data-engineering/references/dbt-project-architecture.md) for how this medallion framing compares to dbt's own documented staging → intermediate → marts layering — this file only covers *where* validation sits in that progression, not the layering comparison itself.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Presenting the 7 dimensions as one universally agreed standard | Even DAMA UK's own whitepaper disclaims universal agreement — citing it as settled fact is citing something that doesn't exist | Present them as synthesized industry vocabulary, with referential integrity anchored to dbt's `relationships` test specifically |
| Treating a volume/row-count check as a dbt-core built-in | `equal_rowcount`/`fewer_rows_than` require the `dbt-utils` package — a project without it has no volume check at all despite "having dbt tests" | Confirm `dbt-utils` is installed before relying on volume checks |
| Assuming Pydantic stops at the first invalid field | It collects every error in the payload into one `ValidationError` by default — code that only reads the first error misses the rest | Iterate `e.errors()` for the full list; reach for `FailFast` only for sequence/list validation specifically |
| Citing "schema-on-read" as literal Databricks phrasing | Databricks documents the *behavior* (permissive bronze layer) without using that exact compound term on its medallion page | Use the term as standard industry vocabulary, not as a verbatim Databricks quote |
