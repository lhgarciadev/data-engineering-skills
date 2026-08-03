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
