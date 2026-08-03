# Quality Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the `quality-data-engineering` skill (`SKILL.md` + 5 reference files) for the `data-engineering-skills` repo, cross-link it from the 4 bordering skills that already carry forward-pointers or overlapping content, and validate it with a fresh-agent discoverability scenario.

**Architecture:** Same shape as every other skill in the suite — a `SKILL.md` with overview/when-to-use/quick-reference/common-mistakes, and one reference file per heavy topic under `references/`. Content is distilled from a user-supplied draft (7 conceptual layers: dimensions, pipeline validation, failure-response policies, data contracts, tooling, observability, culture), independently verified against primary sources across 6 parallel research passes, with a secondary cross-check of `wshobson/agents`' `data-quality-frameworks` skill (two factual errors found there, not adopted).

**Tech Stack:** Markdown, YAML (dbt, Data Contract Specification, Confluent), Python (Great Expectations, Pydantic).

## Global Constraints

- Content in English; code examples in the language of the tool shown — YAML for dbt/Data Contract Specification/Confluent Schema Registry/AWS Glue, Python for Great Expectations/Pydantic (per `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §3).
- `SKILL.md` frontmatter limited to `name` + `description` — no Claude-specific fields (suite spec §2).
- Skill identifier is `quality-data-engineering` (matches folder name).
- **The source draft's reference to a specific real company's technical-interview rubric is generalized to "a senior technical interview rubric" everywhere — no real company name appears anywhere in this plan or the skill content it produces** (design spec §1).
- **Do not adopt `wshobson/agents`' `data-quality-frameworks` example code.** Its Great Expectations examples mix pre-2024 (V0) and current (1.x) API styles inconsistently; its data contract example uses a fabricated root schema (`apiVersion`/`kind`, neither real). Its dbt test syntax is fine to use as a style reference only because this plan re-verified the same syntax independently against `docs.getdbt.com` — see `docs/superpowers/research/2026-08-03-quality-wshobson-agents-review.md`.
- **Terminology discipline, from the design spec's forks (§2.1):** present the 7 quality dimensions as synthesized industry vocabulary (DAMA UK + dbt), never as one certified standard; use "SLO" (not "SLA") when citing Zhamak Dehghani/Data Mesh directly; describe "quarantine" only as the verified mechanism (a boolean flag column + explicit separation), never as automatic row removal; describe "circuit breaker" with dual attribution (software origin + data-engineering adoption) and never claim the data-domain sources describe a last-good-snapshot fallback — that fallback belongs to `serving-pipeline-output.md`'s architecture, cross-link to it instead of restating it.
- **Cross-link, don't duplicate:** `python-data-engineering/references/data-validation.md` (Pydantic vs. Pandera vs. Great Expectations — which tool to reach for), `sql-data-engineering/references/query-optimization-and-production.md` (the 4 dbt generic tests as SQL assertions — baseline mention only), `pipelines-architecture-data-engineering/references/dbt-project-architecture.md` (medallion vs. staging/intermediate/marts; `dbt_expectations` maintenance status), `pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md` (Dagster's asset-level lineage as an orchestrator-selection argument), `pipelines-architecture-data-engineering/references/serving-pipeline-output.md` (the last-good-snapshot fallback as a consequence of decoupled architecture).
- Does not cover: which library to reach for to validate a single dataframe/payload (→ `python-data-engineering`), CDC/log-based change capture (→ future `streaming-data-engineering`), API implementation/hosting (out of scope for the whole suite — see `pipelines-architecture-data-engineering` spec §2.1), hosting/infra for a Schema Registry or observability platform (→ future `iac-cloud-data-engineering`), late-arriving dimensions / dimensional-model integrity (→ future `modeling-data-engineering`).

---

## File Structure

**Create, in `data-engineering-skills/skills/quality-data-engineering/`:**
- `SKILL.md` — overview, when to use, quick reference table, common mistakes table.
- `references/quality-dimensions-and-validation.md` — the dimensions vocabulary, types of checks, ingestion-boundary validation, schema-on-read/write and medallion.
- `references/failure-response-policies.md` — fail/quarantine/drop/repair, dbt thresholds, quarantine in three real systems, Great Expectations Actions, asymmetric cost of error.
- `references/data-contracts-and-schema-compatibility.md` — the Data Contract Specification, Confluent Schema Registry compatibility modes, Avro schema evolution, CI/CD enforcement.
- `references/data-observability-and-lineage.md` — testing vs. observability, the five pillars, OpenLineage, dbt lineage, MTTD/MTTR, anomaly detection, the observability vendor landscape.
- `references/quality-culture-and-governance.md` — data as a product, ownership/SLOs, shift-left, Slim CI, circuit breakers.

**Modify, elsewhere in the repo:**
- `skills/python-data-engineering/references/data-validation.md` — extend the Great Expectations bullet with a pointer to this skill's operational depth.
- `skills/sql-data-engineering/references/query-optimization-and-production.md` — extend the dbt generic-tests sentence with a pointer to this skill's severity/threshold/quarantine layer.
- `skills/pipelines-architecture-data-engineering/references/dbt-project-architecture.md` — refresh the `dbt_expectations` maintenance note with 2026-08-03 evidence, and add a pointer to this skill.
- `skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md` — resolve its own forward-pointer now that this skill exists.

Each reference file stands alone as its own task — a reviewer could approve `failure-response-policies.md` while rejecting `data-observability-and-lineage.md`. `SKILL.md` comes after all five, since its quick-reference table names all of them. Cross-link updates come after this skill exists, since they link into it. A `writing-great-skills` self-review and discoverability validation close out the plan.

---

### Task 1: `references/quality-dimensions-and-validation.md`

**Files:**
- Create: `data-engineering-skills/skills/quality-data-engineering/references/quality-dimensions-and-validation.md`

**Interfaces:**
- Produces: the file `quality-dimensions-and-validation.md`, linked from `SKILL.md` (Task 6).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/quality-data-engineering/references/quality-dimensions-and-validation.md`:

```markdown
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

\`\`\`yaml
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
\`\`\`

Freshness is checked the same way, against a source's `loaded_at_field` compared to a threshold:

\`\`\`yaml
sources:
  - name: raw_jaffle_shop
    tables:
      - name: orders
        loaded_at_field: _etl_loaded_at
        freshness:
          warn_after: {count: 12, period: hour}
          error_after: {count: 24, period: hour}
\`\`\`

Volume/count checks (a load with 10 rows when it always brings 10,000 is a failure even though every row is individually valid) aren't part of dbt-core — `equal_rowcount` and `fewer_rows_than` live in the `dbt-utils` package, so they only exist in a project that installs it.

A useful mental ordering is schema → null/completeness → uniqueness → range/domain → referential integrity → freshness → volume, roughly from cheapest to most expensive to compute (a `not_null` scan vs. a `relationships` join vs. a volume check that may need to compare against historical partitions). That ordering is a teaching heuristic for this skill, not something dbt itself publishes or ranks.

## Validating at the ingestion boundary

Fail fast at the point of entry — validate a payload the moment it enters your system, before a malformed record has a chance to propagate three layers downstream where it's much more expensive to trace back.

\`\`\`python
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
\`\`\`

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
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/quality-data-engineering/references/quality-dimensions-and-validation.md`
Expected: `5` (the seven dimensions, types of checks, ingestion boundary, schema-on-write/read + medallion, common mistakes).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/quality-data-engineering/references/quality-dimensions-and-validation.md
git commit -m "Add quality-data-engineering skill: dimensions and validation"
```

---

### Task 2: `references/failure-response-policies.md`

**Files:**
- Create: `data-engineering-skills/skills/quality-data-engineering/references/failure-response-policies.md`

**Interfaces:**
- Produces: the file `failure-response-policies.md`, linked from `SKILL.md` (Task 6).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/quality-data-engineering/references/failure-response-policies.md`:

```markdown
# Failure Response Policies

Detecting a quality problem is half the job. The other half — where the real judgment lives — is deciding what happens to the pipeline and the bad records once you've detected it.

## The spectrum of responses

- **Fail/abort** — stop the whole pipeline. Right when the risk of letting bad data through outweighs the cost of a delay (financial figures, a primary-key violation).
- **Quarantine** — let good records through, divert bad ones somewhere inspectable, without silently dropping them.
- **Drop with alert** — discard the bad records but log metrics and notify someone. Acceptable when a small amount of garbage is tolerable and latency matters more.
- **Default/repair** — fill in or correct the value (a `COALESCE` to a default, imputation). The riskiest option: it masks the problem rather than surfacing it, and should only be used with an explicit, documented reason.

## Thresholds, not absolutes

Rarely is the right answer "zero bad rows or abort." dbt's own test configuration is built around exactly this idea — a tolerable threshold, not a binary pass/fail:

\`\`\`yaml
models:
  - name: orders
    columns:
      - name: customer_id
        tests:
          - not_null:
              config:
                severity: error
                error_if: ">10"
                warn_if: ">1"
\`\`\`

`severity` is `error` (the default) or `warn`. With `severity: error`, dbt checks `error_if` first (default `!=0`) and only falls through to `warn_if` if that passes. With `severity: warn`, `error_if` is skipped entirely.

The number `error_if`/`warn_if` compares against is controlled by `fail_calc`, whose **default is `count(*)`** — an absolute row count, not a percentage. A threshold phrased as "abort past 5% failing rows" needs an explicit `fail_calc` expression that computes that percentage; writing `error_if: ">5"` on its own compares against a raw failing-row count, not 5% of anything.

## Quarantine: mark, don't silently drop

None of the three systems below — dbt, AWS Glue Data Quality, Databricks — quarantine data with a single automatic click. All three use the same underlying skeleton: compute a boolean flag per row, then separate based on that flag.

dbt's version stores the failing rows from a test, for inspection:

\`\`\`yaml
data_tests:
  +store_failures: true
  +store_failures_as: table   # or `view`, or `ephemeral` (default — nothing persisted)
\`\`\`

Failures land in a table/view named after the test, in the `{schema}_dbt_test__audit` schema by default. This is evidence of *what* failed, not necessarily rows already stripped out of the model itself — the model still builds normally unless it filters on that condition itself.

AWS Glue Data Quality's `EvaluateDataQuality` transform adds a `DataQualityEvaluationResult` column ("Passed"/"Failed") to every row, and the pipeline filters explicitly:

\`\`\`python
rowLevelOutcomes_df = rowLevelOutcomes.toDF()
passed = rowLevelOutcomes_df.filter(
    rowLevelOutcomes_df.DataQualityEvaluationResult == "Passed"
)
\`\`\`

Databricks' Lakeflow Declarative Pipelines document the same pattern under the name "Quarantine invalid records" — an `is_quarantined` boolean, computed from the negation of the validity rules, on a temporary table partitioned by that column, with two downstream views filtering on it:

\`\`\`python
from pyspark import pipelines as dp
from pyspark.sql.functions import expr

rules = {"valid_customer_id": "(customer_id IS NOT NULL)"}
quarantine_rules = "NOT({0})".format(" AND ".join(rules.values()))

@dp.table(temporary=True, partition_cols=["is_quarantined"])
@dp.expect_all(rules)
def orders_quarantine():
    return spark.readStream.table("raw_orders").withColumn(
        "is_quarantined", expr(quarantine_rules)
    )

@dp.view
def valid_orders():
    return spark.read.table("orders_quarantine").filter("is_quarantined=false")

@dp.view
def invalid_orders():
    return spark.read.table("orders_quarantine").filter("is_quarantined=true")
\`\`\`

## Drop with alert

Great Expectations' current Checkpoint API (1.x) offers 7 reactive Actions, each notifying a channel when validation fails — most take a `notify_on` parameter you can pin to `"failure"`:

\`\`\`python
import great_expectations as gx
from great_expectations.checkpoint import SlackNotificationAction, UpdateDataDocsAction

action_list = [
    SlackNotificationAction(
        name="alert_on_failed_expectations",
        slack_token="${validation_slack_webhook}",
        slack_channel="${validation_slack_channel}",
        notify_on="failure",
        show_failed_expectations=True,
    ),
    UpdateDataDocsAction(name="update_all_data_docs"),
]
checkpoint = gx.Checkpoint(
    name="orders_checkpoint",
    validation_definitions=[validation_definition],
    actions=action_list,
)
context.checkpoints.add(checkpoint)
\`\`\`

The other five are `EmailAction`, `PagerdutyAlertAction`, `MicrosoftTeamsNotificationAction`, `OpsgenieAlertAction`, and `SNSNotificationAction`, plus `APINotificationAction` for a custom webhook. If you've seen `StoreValidationResultAction` referenced elsewhere, it no longer exists in the current API — it was part of the pre-2024 (V0) Checkpoint API and was removed, not just deprecated.

## Choosing a policy: the asymmetric cost of being wrong

The right policy for a given check depends on which mistake costs more: aborting unnecessarily and delaying a delivery, or letting a doubtful record through. This is an application of a general decision-theory idea — cost-sensitive classification, the same asymmetry that shows up in Neyman-Pearson hypothesis testing — applied to a data-quality decision, not a framework specific to data engineering. A dashboard fed by a nightly batch can usually tolerate a warn-and-quarantine policy; a table feeding financial reporting usually can't.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Writing `error_if: ">5"` expecting it to mean "5% of rows" | `fail_calc` defaults to `count(*)` — an absolute count, not a percentage | Write an explicit `fail_calc` expression that computes the percentage, or phrase the threshold as an absolute count |
| Assuming `store_failures` removes bad rows from the model | It stores a copy of what failed, in an audit table — the model itself still builds with all rows unless it filters on the condition itself | Read `store_failures` as "evidence," not "cleanup"; filter explicitly if the model needs to exclude bad rows |
| Expecting a one-click "quarantine table" feature from any vendor | AWS Glue, Databricks, and dbt all quarantine via a flag column plus explicit filtering — none does it automatically | Plan for writing the flag + filter logic yourself, in whichever of these three systems you're using |
| Using `StoreValidationResultAction` from an old Great Expectations example | Removed from the current (1.x) API, not just deprecated | Use the 7 current Actions (`UpdateDataDocsAction`, `SlackNotificationAction`, `EmailAction`, `PagerdutyAlertAction`, `MicrosoftTeamsNotificationAction`, `OpsgenieAlertAction`, `SNSNotificationAction`, `APINotificationAction`) |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/quality-data-engineering/references/failure-response-policies.md`
Expected: `6` (spectrum, thresholds, quarantine, drop-with-alert, asymmetric cost, common mistakes).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/quality-data-engineering/references/failure-response-policies.md
git commit -m "Add quality-data-engineering skill: failure response policies"
```

---

### Task 3: `references/data-contracts-and-schema-compatibility.md`

**Files:**
- Create: `data-engineering-skills/skills/quality-data-engineering/references/data-contracts-and-schema-compatibility.md`

**Interfaces:**
- Produces: the file `data-contracts-and-schema-compatibility.md`, linked from `SKILL.md` (Task 6).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/quality-data-engineering/references/data-contracts-and-schema-compatibility.md`:

```markdown
# Data Contracts and Schema Compatibility

Most quality incidents don't start in your pipeline — they start upstream, when a producer changes a field, renames a column, or changes a type without warning. A data contract shifts responsibility for catching that onto the producer, before it ships: an explicit, versioned agreement about what a dataset looks like, checked automatically in the producer's own CI/CD.

## The Data Contract Specification

The open [Data Contract Specification](https://github.com/datacontract/datacontract-specification) is the concrete, documented shape of this idea. Its root fields are `dataContractSpecification` (the spec version, e.g. `1.2.1`), `id`, `info`, `servers`, `terms`, `models`, `definitions`, and `servicelevels` — no `apiVersion`/`kind` (a Kubernetes convention, not part of this spec — a mistake that shows up in some third-party summaries of this format).

Structural constraints and quality checks are two separate blocks, not one. `required`, `unique`, `primaryKey`, `type`, and `references` live directly on each field:

\`\`\`yaml
models:
  orders:
    fields:
      order_id:
        type: string
        required: true
        unique: true
        primaryKey: true
      customer_id:
        type: string
        required: true
        references: customers.customer_id
\`\`\`

`quality` is a separate object, with four variants selected by `type`/`engine` — free text (a natural-language description, "usable as a prompt for an AI engine to check"), a raw SQL check compared against a threshold, a predefined agnostic metric aligned with ODCS 3.1 (`nullValues`, `missingValues`, `invalidValues`, `duplicateValues`, `rowCount`), or a delegated check to an external engine — currently `soda` or `great-expectations`:

\`\`\`yaml
models:
  orders:
    fields:
      order_id:
        quality:
          - type: custom
            engine: great-expectations
            implementation:
              expectation_type: expect_column_values_to_be_unique
\`\`\`

`servicelevels` (all-lowercase, one word) has seven documented sub-objects with concrete fields — not an abstract "SLA":

\`\`\`yaml
servicelevels:
  availability:
    description: The server is available during support hours
    percentage: 99.9%
  freshness:
    description: The age of the youngest row in the table
    threshold: 25h
    timestampField: orders.order_timestamp
  latency:
    description: Time from source event to availability for consumers
    threshold: 25h
    sourceTimestampField: orders.order_timestamp
    processedTimestampField: orders.processed_timestamp
\`\`\`

(The other four — `retention`, `frequency`, `support`, `backup` — cover how long data is kept, how often it updates, when support is reachable, and backup/recovery targets.)

## Enforcing compatibility: Confluent Schema Registry

For streaming data specifically, Confluent Schema Registry enforces compatibility between schema versions before a producer is allowed to register a new one. Seven compatibility modes control exactly what kind of change is allowed:

| Mode | Protects | Add optional field | Remove optional field | Add required field | Widen a scalar type |
|---|---|---|---|---|---|
| `BACKWARD` (default) | New-schema consumers can still read data written with the previous schema | ✔ | ✔ | | |
| `FORWARD` | Old-schema consumers can still read data written with the new schema | ✔ | ✔ | ✔ | ✔ |
| `FULL` | Both directions, against the immediately previous schema only | ✔ | ✔ | | |
| `*_TRANSITIVE` variants | Same guarantee, checked against *every* previous version, not just the last one | | | | |
| `NONE` | Nothing — compatibility checks disabled | — | — | — | — |

Widening or narrowing a scalar type is **not** compatible under `FULL` — it's one-directional (`FORWARD` for widening, `BACKWARD` for narrowing), which contradicts the common assumption that widening a type is always safe on both sides.

This isn't a soft warning: registering an incompatible schema against `POST /subjects/{subject}/versions` returns `409 Conflict`, and since producers auto-register new schemas by default (`auto.register.schemas`), an incompatible change fails the produce call itself, not just a lint step.

## Avro schema evolution rules

Apache Avro's own "Schema Resolution" rules are more specific than "add fields, don't remove or change them":

- Adding a field to the **reader**'s schema is safe **only if that field has a `default`** — without one, Avro signals an error rather than guessing a value.
- Removing a field that the **writer** had is **always safe** — the writer's value for it is simply ignored, regardless of whether it had a default.
- Changing a field's type is safe only within a closed list of promotions: `int`→`long`/`float`/`double`, `long`→`float`/`double`, `float`→`double`, and `string`↔`bytes`. Anything outside that list is an error.
- Renaming a field behaves like removing the old name and adding a new one — unsafe by the two rules above — unless the schema declares an explicit `aliases` entry mapping the old name to the new one.

## Enforcing contracts in CI/CD

Two first-party tools implement "producer CI fails before a breaking change ships" for real, in two different ecosystems — not one universal standard:

- **Confluent Schema Registry Maven Plugin**, goal `test-compatibility` (and, from Confluent Platform 7.2.0, `test-local-compatibility` for faster local feedback before CI) — checks a schema on disk against what's registered.
- **Data Contract CLI**, via its official `datacontract-action` GitHub Action:

\`\`\`yaml
- name: Data Contract Tests
  uses: datacontract/datacontract-action@main
  with:
    location: datacontract.yaml
    server: all
    junit-test-report: TEST-datacontract.xml
\`\`\`

The Data Contract Specification itself doesn't define its own compatibility modes — any backward/forward-compatibility guarantee comes from the schema technology the contract references (Avro, Protobuf, JSON Schema) or from the CI tool's own change classification, not from the contract document's format.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Writing a data contract with `apiVersion`/`kind` fields | Not part of the real Data Contract Specification — a Kubernetes convention mistakenly carried over from an unverified example | Use the real root fields: `dataContractSpecification`, `id`, `info`, `servers`, `models`, `servicelevels` |
| Putting `required`/`unique` checks inside the `quality` block | Those are structural Field Object attributes, evaluated separately from `quality` | Declare `required`/`unique`/`primaryKey` directly on the field; reserve `quality` for text/SQL/library/custom-engine checks |
| Assuming widening a scalar type is always safe on both sides | Confluent's own compatibility table shows widening is one-directional (`FORWARD` only), not compatible under `FULL` | Check the specific compatibility mode's table before assuming a type change is safe |
| Assuming any field addition is a safe Avro change | Only safe if the new field has a `default` — without one, Avro signals an error | Always give a new field a `default` if older data needs to keep reading under the new schema |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/quality-data-engineering/references/data-contracts-and-schema-compatibility.md`
Expected: `5` (the Data Contract Specification, Confluent compatibility, Avro evolution, CI/CD enforcement, common mistakes).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/quality-data-engineering/references/data-contracts-and-schema-compatibility.md
git commit -m "Add quality-data-engineering skill: data contracts and schema compatibility"
```

---

### Task 4: `references/data-observability-and-lineage.md`

**Files:**
- Create: `data-engineering-skills/skills/quality-data-engineering/references/data-observability-and-lineage.md`

**Interfaces:**
- Produces: the file `data-observability-and-lineage.md`, linked from `SKILL.md` (Task 6).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/quality-data-engineering/references/data-observability-and-lineage.md`:

```markdown
# Data Observability and Lineage

## Testing vs. observability

Testing validates what you already know might go wrong — you write an expectation for a rule you anticipated. Observability is for what you *didn't* anticipate: an anomaly, a slow degradation, a pattern no explicit assertion covers. You cannot write a test for every way data can go wrong; observability is what fills that gap. A mature pipeline has both — tests are deterministic and known in advance, observability is statistical and emergent.

## The five pillars (and whose framework they are)

"Freshness, Volume, Distribution, Schema, Lineage" is the framework Monte Carlo's co-founder Barr Moses introduced in a 2020 company blog post ("Introducing the 5 Pillars of Data Observability"). It's worth knowing by name because it dominates industry conversation about observability — Databricks' own glossary reproduces the same five terms almost verbatim, without attributing them — but it's vendor marketing, not a neutral standard, and should be presented as such:

- **Freshness** — is the data up to date? Are there gaps in when it last updated?
- **Distribution** — field-level health: null rates, values outside their expected shape.
- **Volume** — row/file counts, an indicator of completeness.
- **Schema** — has the structure changed (a new column, a changed type)?
- **Lineage** — the map that ties the other four together: what feeds what.

## Lineage: OpenLineage and dbt's own DAG

Unlike the five pillars, lineage has a genuinely neutral open standard behind it: [OpenLineage](https://openlineage.io), governed by the Linux Foundation AI & Data — "OpenLineage can never belong to a company... it belongs to us all," per its own foundation announcement. It models three entities — **Job** (a process that consumes/produces datasets), **Run** (one timed occurrence of a job), **Dataset** — emitted as events (`RunEvent`, `DatasetEvent`, `JobEvent`) as a pipeline executes.

dbt builds and visualizes a real lineage graph of its own, derived directly from `ref()`/`source()` calls — visible locally via `dbt docs generate && dbt docs serve` (dbt Core, no dbt Cloud required), or through the "Catalog" feature in dbt Cloud. This is lineage at the level of *declared transformation* — useful for impact analysis inside a dbt project ("if I change this column, which downstream models break?"). It's a different, complementary layer from the orchestration-level lineage [orchestrator-selection-and-topology.md](../../pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md) already covers for Dagster's asset model — that file owns the orchestrator-selection angle; this one owns the quality/impact-analysis angle.

## Anomaly detection: learned patterns, not fixed thresholds

Instead of a fixed, hand-maintained threshold, observability tooling learns what "normal" looks like — seasonality, trend — and alerts on deviation from that. Monte Carlo's own product documentation describes the mechanism at a reasonable level of concreteness (vendor-sourced, cited here as one real implementation, not a universal algorithm): an ensemble of models, chosen per data series based on its observed pattern, retrained on a rolling window of recent data, with a sensitivity setting that widens or narrows the alert threshold. Describe the concept with confidence; don't claim a specific algorithm (ARIMA, Prophet, or otherwise) unless you've verified that specific vendor uses it.

## MTTD and MTTR

Mean Time to Detect and Mean Time to Resolve are not data-native terms — they come from systems/site reliability engineering. The Google SRE Book states it plainly: "Reliability is a function of mean time to failure (MTTF) and mean time to repair (MTTR)," in the context of service reliability, not datasets. Their formal application to *data* quality specifically is, as far as this skill's research could verify, something only vendors in the data-observability space do — worth naming as the metric that ties detection and resolution together, but worth being honest about its lineage.

One nuance the data-observability marketing around MTTR rarely mentions: Google itself, in a separate report ("Incident Metrics in SRE"), argues that MTTR and similar mean-based statistics are "poorly suited for decision making or trend analysis" in production incident contexts — a caution worth carrying into how heavily a team leans on a single MTTR trend line as *the* data-quality health metric.

## The observability vendor landscape

| Vendor | What it actually is today | Category |
|---|---|---|
| **Soda** | Repositioned as of its 4.x line: "Data Contracts" (YAML checks, its current primary language) *and* "Data Observability" as two separate pillars of the same product. SodaCL (the older YAML check language) is now documented as "v3"/legacy. | Both validation and observability — not a pure-observability tool |
| **Monte Carlo** | Observability platform; originated the "5 pillars" framing (see above) | Observability |
| **Anomalo** | Table-availability, late-data, and completeness checks plus unsupervised-ML anomaly detection, configured through a no-code UI | Observability, with rules-based checks alongside the ML |

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Citing "the 5 pillars" as an industry standard | It's Monte Carlo's own marketing framing, even though other vendors reproduce it without attribution | Name it as Monte Carlo's framework when using it pedagogically |
| Treating dbt's lineage graph and an orchestrator's asset lineage as the same thing | One is declared transformation dependencies inside a dbt project; the other is runtime orchestration dependencies across any asset type | Use dbt's DAG for impact analysis inside a dbt project; use the orchestrator's asset graph for cross-pipeline dependencies |
| Presenting MTTD/MTTR as data-engineering-native metrics | They're imported from SRE/systems reliability, and their application to data quality specifically is vendor territory, not a neutral standard | Attribute the origin, and don't lean on MTTR alone as a trend metric without the caveat above |
| Assuming Soda is "just an observability tool" | Its current (4.x) product spans both data-contract validation and observability as separate pillars | Check which Soda pillar (Contracts vs. Observability) a given feature actually belongs to before comparing it to a pure-play tool like Monte Carlo |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/quality-data-engineering/references/data-observability-and-lineage.md`
Expected: `7` (testing vs. observability, five pillars, lineage, anomaly detection, MTTD/MTTR, vendor landscape, common mistakes).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/quality-data-engineering/references/data-observability-and-lineage.md
git commit -m "Add quality-data-engineering skill: observability and lineage"
```

---

### Task 5: `references/quality-culture-and-governance.md`

**Files:**
- Create: `data-engineering-skills/skills/quality-data-engineering/references/quality-culture-and-governance.md`

**Interfaces:**
- Produces: the file `quality-culture-and-governance.md`, linked from `SKILL.md` (Task 6).

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/quality-data-engineering/references/quality-culture-and-governance.md`:

```markdown
# Quality Culture and Governance

Tooling detects problems. Without clear ownership, agreed-upon service levels, and a producer that's actually accountable, the best observability setup just generates alerts nobody acts on. This file is the layer above the mechanics.

## Data as a product

Zhamak Dehghani's 2019 article that introduced Data Mesh ("How to Move Beyond a Monolithic Data Lake to a Distributed Data Mesh," martinfowler.com) names six qualities a domain's data product should have, under the heading "Domain data as a product": **Discoverable**, **Addressable**, **Trustworthy and truthful**, **Self-describing semantics and syntax**, **Inter-operable and governed by global standards**, **Secure and governed by a global access control**. Treat a dataset as a product with these guarantees, not as a by-product of whatever pipeline happens to produce it.

## Ownership and SLOs

Dehghani's article uses **SLO** (Service Level Objective), not SLA — "Each domain dataset must establish Service Level Objectives for the quality of the data it provides: timeliness, error rates, etc." A commonly taught triad — freshness, completeness, availability — is a reasonable synthesis for teaching purposes, not something one single source formalizes exactly that way: freshness and completeness both have real backing as named dimensions (Monte Carlo documents both explicitly), availability is the weakest of the three in the evidence for a data-specific SLA/SLO, closer to a borrowed analogy from classic infrastructure uptime SLAs. For the concrete, field-level mechanism behind an actual SLA, see [data-contracts-and-schema-compatibility.md](data-contracts-and-schema-compatibility.md)'s `servicelevels` block — this file covers the cultural "why," that one covers the technical "how."

## Shift-left

Push quality toward the source instead of catching it at the end: a contract with the producer (see [data-contracts-and-schema-compatibility.md](data-contracts-and-schema-compatibility.md)), validation at the ingestion boundary (see [quality-dimensions-and-validation.md](quality-dimensions-and-validation.md)), and tests that run before code merges rather than after it ships.

## Quality gates in CI/CD

dbt's own documented mechanism for this is called **Slim CI** — running only the models a pull request actually touched, plus their downstream dependents, compared against the last successful production run:

\`\`\`bash
dbt build --select state:modified+ --defer --state path/to/prod/artifacts
\`\`\`

`state:modified` (or `state:modified+` to include downstream dependents) selects changed nodes by comparing the current project against a comparison manifest; `--defer` lets unmodified downstream models resolve against production instead of rebuilding them; `--state` points at the artifacts to compare against. This is the concrete implementation of "quality tests run in the pipeline before code ships," not a generic description of "run tests in CI."

## Circuit breakers

The circuit breaker pattern started in software architecture, not data — Michael Nygard's *Release It!*, popularized further by Martin Fowler: wrap a remote call, trip after repeated failures, and stop attempting the call at all until it recovers. Data engineering borrowed the name and the idea, with its own lineage: Sandeep Uttamchandani's 2018 Strata Data Conference talk "Circuit breakers to safeguard for garbage in, garbage out" is the earliest traceable use, followed by data-contracts practitioner Andrew Jones and Ibotta's engineering blog, both using the term explicitly for the same idea — stop a pipeline from promoting data that fails a quality/integrity check.

One correction worth making explicitly: the data-domain sources describe **blocking**, not a fallback to old data. Uttamchandani's own description: the result is that "data will be missing in the reports for time-periods of low quality" — not that an old snapshot fills the gap. Ibotta's post describes the pipeline halting the table-build process outright. If a pipeline should keep serving the last good result while blocked rather than going dark, that's the decoupled-architecture pattern [serving-pipeline-output.md](../../pipelines-architecture-data-engineering/references/serving-pipeline-output.md) already documents — a genuinely separate idea from a different source, not something the "circuit breaker" sources themselves describe. Combining both (block the promotion *and* keep serving a stale-but-valid snapshot) is a deliberate combination of two patterns, not one thing a single source already ties together — say so explicitly if you present them combined.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Citing Dehghani's principle as "SLA," not "SLO" | Her article uses SLO throughout and never uses the word SLA | Use "SLO" when citing Data Mesh directly; reserve "SLA" for a contractual/external commitment |
| Describing "circuit breaker" as automatically serving a last-good snapshot | The data-domain sources that coined this usage describe blocking/missing data, not an automatic fallback | Attribute the fallback behavior to `serving-pipeline-output.md`'s decoupled-architecture pattern instead |
| Running the full dbt test suite on every CI run regardless of what changed | Slower feedback, and defeats the point of Slim CI's targeted rebuild | Use `state:modified+` with `--defer`/`--state` against the last successful production run |
| Treating "freshness/completeness/availability" as one source's formal SLA definition | No single primary source ties exactly those three together that way — it's a teaching synthesis | Present it as synthesis, and note availability is the weakest-evidenced of the three |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "^## " data-engineering-skills/skills/quality-data-engineering/references/quality-culture-and-governance.md`
Expected: `6` (data as a product, ownership and SLOs, shift-left, quality gates in CI/CD, circuit breakers, common mistakes).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/quality-data-engineering/references/quality-culture-and-governance.md
git commit -m "Add quality-data-engineering skill: culture and governance"
```

---

### Task 6: `SKILL.md`

**Files:**
- Create: `data-engineering-skills/skills/quality-data-engineering/SKILL.md`

**Interfaces:**
- Consumes: the exact filenames of all 5 reference files from Tasks 1-5.
- Produces: `skills/quality-data-engineering/SKILL.md` — completes the skill, what Tasks 8-9 review and validate.

- [ ] **Step 1: Create the file**

Create `data-engineering-skills/skills/quality-data-engineering/SKILL.md`:

```markdown
---
name: quality-data-engineering
description: Data quality guidance — dimensions and validation checks, failure-response policies (fail/quarantine/drop/repair), data contracts and schema compatibility, data observability (freshness/volume/distribution/schema/lineage), and quality as culture (ownership, shift-left, CI/CD gates, circuit breakers). Use when designing quality checks for a pipeline, deciding what to do when a check fails, writing or reviewing a data contract, setting up alerting for schema/volume/freshness anomalies, or arguing for organization-wide data quality governance. Not for choosing which library validates a single dataframe or payload (see python-data-engineering), CDC/change-data-capture (see streaming-data-engineering), or implementing/hosting an API (out of scope for the whole suite).
---

# Quality Data Engineering

## Overview

A pipeline that finishes green isn't the same thing as a pipeline whose output is trustworthy — the bugs that matter most fail silently. This skill covers making those failures loud, at every layer: what to check, where to check it, what to do when a check fails, how producers and consumers agree on a contract, how to catch what you didn't think to test for, and how to make quality an operational property of the system rather than a task someone does by hand.

## When to use

- Deciding what quality checks a pipeline needs, and where in the pipeline to run them
- Choosing what happens when a check fails — abort, quarantine, drop-with-alert, or repair
- Writing or reviewing a data contract, or deciding what compatibility guarantee a schema change needs
- Setting up alerting for freshness, volume, schema, or distribution anomalies
- Arguing for (or scoping) organization-wide data quality governance — Great Expectations, Soda, Monte Carlo
- Explaining the difference between data testing and data observability
- Not for choosing which library validates one dataframe or payload — see `python-data-engineering`
- Not for CDC/log-based change capture — see `streaming-data-engineering`
- Not for implementing or hosting an API service — out of scope for the whole suite until a confirmed real use case exists

## Quick reference

| Concern | Reach for | Reference |
|---|---|---|
| Naming quality dimensions in a review or design doc | Completeness, uniqueness, validity, accuracy, consistency, timeliness, referential integrity — as industry vocabulary, not a single standard | [quality-dimensions-and-validation.md](references/quality-dimensions-and-validation.md) |
| Deciding what to check, and in what order | Schema → null/completeness → uniqueness → range/domain → referential integrity → freshness → volume | [quality-dimensions-and-validation.md](references/quality-dimensions-and-validation.md) |
| Validating a payload at the ingestion boundary | Fail fast with a clear, localized error | [quality-dimensions-and-validation.md](references/quality-dimensions-and-validation.md) |
| Deciding where in a medallion/lakehouse layout to enforce validation | Raw layer permissive, strict enforcement in the transition to the curated layer | [quality-dimensions-and-validation.md](references/quality-dimensions-and-validation.md) |
| Deciding what happens when a check fails | Fail/abort, quarantine, drop-with-alert, or repair — chosen by the asymmetric cost of being wrong | [failure-response-policies.md](references/failure-response-policies.md) |
| Setting a tolerable threshold instead of zero-tolerance | dbt's `severity`/`error_if`/`warn_if`/`fail_calc` | [failure-response-policies.md](references/failure-response-policies.md) |
| Quarantining bad rows without silently dropping them | A boolean flag column + explicit separation (dbt `store_failures`, AWS Glue Data Quality, Databricks Lakeflow) | [failure-response-policies.md](references/failure-response-policies.md) |
| Alerting only on failure, not on every run | Great Expectations Actions with `notify_on="failure"` | [failure-response-policies.md](references/failure-response-policies.md) |
| Writing a data contract | The Data Contract Specification's `models`/`quality`/`servicelevels` blocks | [data-contracts-and-schema-compatibility.md](references/data-contracts-and-schema-compatibility.md) |
| Deciding what schema change is safe to ship | Confluent Schema Registry's 7 compatibility modes, or Avro's schema-resolution rules directly | [data-contracts-and-schema-compatibility.md](references/data-contracts-and-schema-compatibility.md) |
| Blocking a producer's CI on a breaking schema change | Confluent Schema Registry Maven Plugin, or Data Contract CLI's `datacontract-action` | [data-contracts-and-schema-compatibility.md](references/data-contracts-and-schema-compatibility.md) |
| Explaining testing vs. observability | Testing = known rules you wrote; observability = anomalies you didn't anticipate | [data-observability-and-lineage.md](references/data-observability-and-lineage.md) |
| Structuring an observability pitch or dashboard | Freshness, Volume, Distribution, Schema, Lineage (Monte Carlo's framing — cite it as such) | [data-observability-and-lineage.md](references/data-observability-and-lineage.md) |
| Talking about lineage without depending on one vendor | OpenLineage (Linux Foundation AI & Data) | [data-observability-and-lineage.md](references/data-observability-and-lineage.md) |
| Comparing Soda, Monte Carlo, Anomalo | Soda now spans contracts *and* observability; Monte Carlo and Anomalo are observability-only | [data-observability-and-lineage.md](references/data-observability-and-lineage.md) |
| Arguing for dataset ownership and service levels | Data as a product (Dehghani/Data Mesh), SLOs | [quality-culture-and-governance.md](references/quality-culture-and-governance.md) |
| Running only the tests a PR actually affects | dbt Slim CI, `state:modified+` with `--defer`/`--state` | [quality-culture-and-governance.md](references/quality-culture-and-governance.md) |
| Blocking bad data from reaching consumers | A data-domain circuit breaker — with the fallback-to-last-good-snapshot half cross-linked, not restated | [quality-culture-and-governance.md](references/quality-culture-and-governance.md) |
| Choosing which validation library for one dataframe/payload | Pydantic vs. Pandera vs. Great Expectations | [python-data-engineering/data-validation.md](../python-data-engineering/references/data-validation.md) |

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Presenting the 7 quality dimensions as one certified standard | Even DAMA UK's own whitepaper disclaims universal agreement | Present as synthesized industry vocabulary; see [quality-dimensions-and-validation.md](references/quality-dimensions-and-validation.md) |
| Writing `error_if: ">5"` and expecting "5%" | `fail_calc` defaults to an absolute row count, not a percentage | Use an explicit percentage `fail_calc`, or phrase the threshold as a count; see [failure-response-policies.md](references/failure-response-policies.md) |
| Assuming "quarantine" means bad rows disappear from the model automatically | Every real implementation (dbt, AWS Glue, Databricks) is a flag column plus explicit filtering | Plan for writing the flag + filter yourself; see [failure-response-policies.md](references/failure-response-policies.md) |
| Writing a data contract with `apiVersion`/`kind` fields | Not part of the real Data Contract Specification — a Kubernetes convention mistakenly carried over | Use the real root fields: `dataContractSpecification`, `id`, `info`, `servers`, `models`, `servicelevels`; see [data-contracts-and-schema-compatibility.md](references/data-contracts-and-schema-compatibility.md) |
| Assuming widening a scalar type is always safe on both sides | Confluent's own compatibility table shows widening is one-directional (`FORWARD` only), not compatible under `FULL` | Check the specific compatibility mode's table before assuming a type change is safe; see [data-contracts-and-schema-compatibility.md](references/data-contracts-and-schema-compatibility.md) |
| Citing "the 5 pillars of data observability" as a neutral standard | It's Monte Carlo's own marketing framework | Attribute it explicitly; see [data-observability-and-lineage.md](references/data-observability-and-lineage.md) |
| Saying "SLA" when citing Zhamak Dehghani/Data Mesh directly | Her article uses "SLO" throughout, never "SLA" | Use "SLO" for that citation specifically; see [quality-culture-and-governance.md](references/quality-culture-and-governance.md) |
| Describing a data "circuit breaker" as serving the last good snapshot | The data-domain sources describe blocking/missing data, not an automatic fallback | Cross-link the fallback behavior to `serving-pipeline-output.md` instead of claiming one source covers both; see [quality-culture-and-governance.md](references/quality-culture-and-governance.md) |
```

- [ ] **Step 2: Verify the file**

Run: `grep -c "](references/" data-engineering-skills/skills/quality-data-engineering/SKILL.md`
Expected: `26` (18 quick-reference rows + 8 common-mistakes rows, each linking into one of this skill's own 5 reference files; the quick-reference table's Pydantic/Pandera/Great Expectations row links out to `python-data-engineering` instead and is not counted here).

Run: `for f in data-engineering-skills/skills/quality-data-engineering/references/*.md; do grep -q "$(basename "$f")" data-engineering-skills/skills/quality-data-engineering/SKILL.md || echo "MISSING LINK: $f"; done`
Expected: no output (all 5 reference files are linked from `SKILL.md`).

- [ ] **Step 3: Commit**

```bash
cd data-engineering-skills
git add skills/quality-data-engineering/SKILL.md
git commit -m "Add quality-data-engineering skill: SKILL.md"
```

---

### Task 7: Cross-link from and to bordering skills

**Files:**
- Modify: `data-engineering-skills/skills/python-data-engineering/references/data-validation.md`
- Modify: `data-engineering-skills/skills/sql-data-engineering/references/query-optimization-and-production.md`
- Modify: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/dbt-project-architecture.md`
- Modify: `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`

**Interfaces:**
- Consumes: `skills/quality-data-engineering/` (Tasks 1-6) must already exist — these edits link into it.

- [ ] **Step 1: Extend the Great Expectations bullet in `python-data-engineering/data-validation.md`**

In `data-engineering-skills/skills/python-data-engineering/references/data-validation.md`, find this line:

```
- **Great Expectations** is a heavier, org-wide data-quality and documentation platform (expectation suites, data docs, validation checkpoints across many datasets/teams). Usually overkill for validating a single pipeline's output — reach for it when the requirement is organization-wide data quality governance, not a single job's correctness.
```

Replace it with:

```
- **Great Expectations** is a heavier, org-wide data-quality and documentation platform (expectation suites, data docs, validation checkpoints across many datasets/teams). Usually overkill for validating a single pipeline's output — reach for it when the requirement is organization-wide data quality governance, not a single job's correctness. Once that requirement is real, `quality-data-engineering` covers Great Expectations' operational mechanics (Checkpoints, Actions) and how it fits into a broader policy of thresholds and quarantine — this file only tells you when to reach for it.
```

- [ ] **Step 2: Extend the dbt generic-tests sentence in `sql-data-engineering/query-optimization-and-production.md`**

In `data-engineering-skills/skills/sql-data-engineering/references/query-optimization-and-production.md`, find this line (near the end of the dbt paragraph):

```
dbt's generic tests (`unique`, `not_null`, `accepted_values`, `relationships`) are data-quality checks expressed directly as SQL assertions rather than a separate framework.
```

Replace it with:

```
dbt's generic tests (`unique`, `not_null`, `accepted_values`, `relationships`) are data-quality checks expressed directly as SQL assertions rather than a separate framework. Severity, custom thresholds, and quarantining failed rows for inspection — `severity`/`error_if`/`warn_if`/`store_failures` — go beyond what's SQL-specific here; see `quality-data-engineering` for that policy layer.
```

- [ ] **Step 3: Refresh the `dbt_expectations` note in `pipelines-architecture-data-engineering/dbt-project-architecture.md`**

In `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/dbt-project-architecture.md`, find this line:

```
`packages.yml` + `dbt deps` pulls in reusable dbt projects (models, macros, tests) — most commonly `dbt-utils` (dbt Labs-maintained: generic tests, introspection macros, SQL generators like `date_spine`). If you reach for `dbt_expectations` (a community package inspired by Great Expectations) for GE-style tests, know that its own README states it's no longer actively maintained — functional and widely used, but check before betting new work on it.
```

Replace it with:

```
`packages.yml` + `dbt deps` pulls in reusable dbt projects (models, macros, tests) — most commonly `dbt-utils` (dbt Labs-maintained: generic tests, introspection macros, SQL generators like `date_spine`). If you reach for `dbt_expectations` (a community package inspired by Great Expectations) for GE-style tests, know that its own README states it's no longer actively maintained — confirmed 2026-08-03: last release `0.10.4` (September 2024), last commit December 2024, over 19 months without new code. Functional and widely used, but check before betting new work on it. For the broader policy layer around dbt's own tests — severity, thresholds, quarantining failed rows — see `quality-data-engineering`.
```

- [ ] **Step 4: Resolve the forward-pointer in `pipelines-architecture-data-engineering/serving-pipeline-output.md`**

In `data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`, find this line:

```
Hosting and infrastructure for a serving API, if one gets built, belongs in `iac-cloud-data-engineering` once that skill exists. Contract and schema versioning for that API belongs in `quality-data-engineering` once that skill exists. Neither has content yet.
```

Replace it with:

```
Hosting and infrastructure for a serving API, if one gets built, belongs in `iac-cloud-data-engineering` once that skill exists — no content yet. Contract and schema versioning for that API follows the same principles `quality-data-engineering` teaches for any data contract — see its `data-contracts-and-schema-compatibility.md`.
```

- [ ] **Step 5: Verify the edits**

Run: `grep -c "quality-data-engineering" data-engineering-skills/skills/python-data-engineering/references/data-validation.md data-engineering-skills/skills/sql-data-engineering/references/query-optimization-and-production.md data-engineering-skills/skills/pipelines-architecture-data-engineering/references/dbt-project-architecture.md data-engineering-skills/skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`
Expected: `1` for each of the 4 files.

- [ ] **Step 6: Commit**

```bash
cd data-engineering-skills
git add skills/python-data-engineering/references/data-validation.md skills/sql-data-engineering/references/query-optimization-and-production.md skills/pipelines-architecture-data-engineering/references/dbt-project-architecture.md skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md
git commit -m "Cross-link quality-data-engineering from bordering skills"
```

---

### Task 8: `writing-great-skills` self-review

**Files:**
- Modify: any file under `data-engineering-skills/skills/quality-data-engineering/`, only if the review finds an issue.

**Interfaces:**
- Consumes: the completed skill from Tasks 1-6.

- [ ] **Step 1: Run the review**

Read `writing-great-skills` directly at `.agents/skills/writing-great-skills/SKILL.md` (repo-local — this skill has `disable-model-invocation: true` and cannot be fired via the Skill tool) and apply it as a checklist against `data-engineering-skills/skills/quality-data-engineering/`. At minimum, check:
- `SKILL.md`'s `description` leads with an identity clause ("Data quality guidance — ...") rather than starting with "Use when...".
- Every reference file (`quality-dimensions-and-validation.md`, `failure-response-policies.md`, `data-contracts-and-schema-compatibility.md`, `data-observability-and-lineage.md`, `quality-culture-and-governance.md`) is cited from at least one row of `SKILL.md`'s quick-reference or common-mistakes table (Task 6's Step 2 already checks this mechanically — this step is the qualitative read).
- No content is duplicated across the 5 reference files, or duplicated with content that already lives in `python-data-engineering/references/data-validation.md`, `sql-data-engineering/references/query-optimization-and-production.md`, or `pipelines-architecture-data-engineering/references/{dbt-project-architecture,orchestrator-selection-and-topology,serving-pipeline-output}.md`.
- No placeholder text ("TBD", "TODO", etc.) anywhere in the 6 files.
- No real company name from the source draft's interview-rubric reference appears anywhere (Global Constraints).

- [ ] **Step 2: Fix any issues found**

Edit the affected file(s) directly.

- [ ] **Step 3: Commit fixes, if any**

```bash
cd data-engineering-skills
git add skills/quality-data-engineering/
git commit -m "Fix quality-data-engineering: writing-great-skills self-review"
```

Skip this step entirely if Step 1 found nothing to fix — don't create an empty commit.

---

### Task 9: Validate the `quality-data-engineering` skill

**Owner:** Claude, using the `Agent` tool to run a fresh-context discoverability scenario (same method used to validate the previous 5 domain skills).

**Interfaces:**
- Consumes: `skills/quality-data-engineering/` (Tasks 1-8), symlinked into a live Claude Code environment so a fresh agent can discover it.

- [ ] **Step 1: Symlink the skill for testing**

```bash
ln -sf "$(pwd)/data-engineering-skills/skills/quality-data-engineering" ~/.claude/skills/quality-data-engineering
```

- [ ] **Step 2: Run the discoverability scenario**

Dispatch a fresh `general-purpose` agent with this prompt:

> "You have a list of available skills — check it. Then answer: 'A dbt model that feeds our finance dashboard just had 15% of its rows come through with a NULL `customer_id`, and the pipeline finished green. What should have caught this before it shipped, and what should happen to the pipeline the next time it happens?' After answering, report which skill(s) you invoked."

Expected: the agent invokes `quality-data-engineering`, names a `not_null` test with a severity/threshold configuration (or a similar concrete dbt-test-based answer) for catching it, and gives a clear recommendation on failure policy (e.g., abort or quarantine-with-alert given this feeds a finance dashboard) rather than a vague "add more validation."

- [ ] **Step 3: Record the result**

If the scenario fails (skill doesn't fire, or the answer is vague/wrong), fix the relevant wording in `SKILL.md`'s description or quick-reference table, and re-run this step only.

---

## Self-Review Notes

- **Spec coverage**: Task 1 ↔ design spec §4.1; Task 2 ↔ §4.2; Task 3 ↔ §4.3; Task 4 ↔ §4.4; Task 5 ↔ §4.5; Task 6 ties them together per §4's file-structure diagram and §4.6's common-mistakes aggregation; Task 7 ↔ the cross-link obligations from spec §2.1's fork-resolution table (all 4 files named there are covered); Task 8 mirrors the `writing-great-skills` self-review step used in every prior skill round; Task 9 mirrors the discoverability validation already run for the 5 shipped domain skills.
- **No placeholders**: every task's Step 1 is the actual final file content (English, anonymized per Global Constraints), not a description of what to write.
- **Type/name consistency**: the five reference filenames (`quality-dimensions-and-validation.md`, `failure-response-policies.md`, `data-contracts-and-schema-compatibility.md`, `data-observability-and-lineage.md`, `quality-culture-and-governance.md`) are identical across Tasks 1-6's Interfaces sections and `SKILL.md`'s links. Cross-links between the 5 files (e.g. `quality-dimensions-and-validation.md` → `python-data-engineering/data-validation.md`; `quality-culture-and-governance.md` → `data-contracts-and-schema-compatibility.md` and → `serving-pipeline-output.md`) use consistent relative paths, verified against the actual directory depth (`skills/quality-data-engineering/references/*.md` is two levels below `skills/`, matching the `../../` pattern already used by other skills' cross-links).
- **Confidentiality check**: re-read against Global Constraints' anonymization rule — no real company name from the source interview-rubric reference appears anywhere in this plan.
- **Fact-verification traceability**: every non-obvious technical claim in Tasks 1-5 traces back to one of the 6 dated research files under `docs/superpowers/research/2026-08-03-*-verification.md` or the `wshobson/agents` review — see design spec §4 for the mapping from file to research doc, section by section.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-03-quality-skill-implementation.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
