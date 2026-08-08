# Serving Pipeline Output: The Delivery Decision

This file is architectural reasoning and design judgment, not a set of vendor-documented facts — treat it the way you'd treat the cold/warm-cache benchmarking guidance in `spark-data-engineering`: real engineering wisdom, not something cited verbatim from a single vendor's docs.

## The problem: your warehouse is the wrong tool for point lookups

Your analytical warehouse (Snowflake, BigQuery, Redshift) is columnar and OLAP: excellent at scanning millions of rows and aggregating, poor at the pattern an API needs — "give me customer 12345's record in 20 milliseconds." A low-latency, high-concurrency point lookup against an OLAP engine is slow and expensive, because you pay for bytes scanned on every request.

The fix is a **serving layer**, separate from the warehouse: the pipeline precomputes the result and materializes it into a store built for lookup-by-key — Postgres, DynamoDB, Redis, or Elasticsearch, depending on the access pattern — and whatever reads that data reads from there, not from the warehouse. The batch or streaming pipeline writes the serving store; nothing downstream reads the warehouse directly for low-latency access. This separates the compute plane (heavy, periodic) from the serving plane (light, always-on, low-latency) — the same control-plane/data-plane split from `orchestrator-selection-and-topology.md`, one layer further downstream.

## The freshness/latency trade-off

If you materialize the serving store on an hourly batch, reads are millisecond-fast but the data can be up to an hour stale. If a consumer needs sub-second freshness, the serving store needs to be updated by streaming — a topic feeding it directly — instead of batch. Name this trade-off explicitly and tie it to the actual business requirement; don't default to "real-time" as a starting assumption, since it's the expensive option.

## SLA and decoupling

A live-serving layer carries an availability/latency SLA that the batch pipeline feeding it does not. That's exactly why they're separated: if the pipeline fails, the serving layer keeps answering from the last good snapshot instead of going down with it. That decoupling is deliberate design, not an accident of architecture.

## When NOT to build an API — the strongest signal of maturity

If the consumer is another data process that needs the *whole* dataset, a paginated API is close to the worst mechanism available — slow, expensive, fragile. Better options: a **bulk export** to files (Parquet on S3), a **native warehouse share** (Snowflake data sharing, shared Iceberg tables), or a **Kafka stream**. An API earns its place for point lookups, low latency, and external or application consumers — for moving large datasets between data systems, it's almost never the right answer. Knowing when to say "an API is the wrong pattern here, let's use a share or export instead" is one of the strongest signals of seniority in this whole topic.

## What this file deliberately does not cover

Building or operating the API service itself — framework choice, REST vs. GraphQL vs. gRPC, endpoint implementation, request/response contracts, versioning, API-level auth — is out of scope for this skill and for the suite as a whole right now. It's general backend engineering, not something specific to data engineering, and there's no confirmed real use case driving it yet (see `docs/superpowers/specs/2026-07-30-pipelines-architecture-skill-design.md` §2.1 for the full reasoning). If you build one, everything above still applies to how it should be fed — the implementation itself just isn't taught here.

Hosting and infrastructure for a serving API, if one gets built, belongs to the IaC/cloud domain, which has no skill in this suite yet — reason about it directly rather than looking for one to load. Contract and schema versioning for that API follows the same principles `quality-data-engineering` teaches for any data contract — see its `data-contracts-and-schema-compatibility.md`.

For how to structure the package itself once this decision is made — directory layout, packaging, where a data contract lives — see `project-structure-data-engineering`.
