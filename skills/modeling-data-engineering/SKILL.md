---
name: modeling-data-engineering
description: Data modeling guidance — dimensional modeling (star/snowflake schemas, grain, additivity, fact tables), Slowly Changing Dimensions and other dimension patterns (conformed, bridge, junk, role-playing, degenerate, late-arriving), modeling methodology choice (Inmon vs. Kimball vs. Data Vault), Data Vault 2.0 (hubs/links/satellites, hash keys), modern lakehouse modeling (medallion, One Big Table), and modeling for access patterns (NoSQL single-table design, event/stream, bitemporal). Use when designing a warehouse schema, declaring the grain of a fact table, choosing an SCD type, deciding between a star schema and a wide denormalized table, or modeling a NoSQL serving store or an event stream. Not for SQL implementing SCD Type 2 (see sql-data-engineering), runtime schema validation (see quality-data-engineering), CDC/log-based change capture (see streaming-data-engineering), or NoSQL infrastructure and hosting, which has no skill in this suite yet.
---

# Modeling Data Engineering

## Overview

The atom of data modeling is the grain — what one row of a table actually represents — and every other decision in this skill (which dimensions and facts belong on a row, which SCD type to use, whether a shape is even dimensional at all) follows from getting that declaration right first. The thread running through every reference file here: a model is justified by how its data is queried and how it changes over time, never by dogma or elegance for its own sake. The same information can legitimately need a normalized OLTP shape, a dimensional warehouse shape, an auditable Data Vault shape, or a denormalized NoSQL shape — depending entirely on who's reading it and how.

## When to use

- Designing a warehouse schema for a new business process — declaring its grain, its dimensions, its facts
- Choosing between a star schema and a snowflake schema, or between a star schema and One Big Table
- Deciding which Slowly Changing Dimension type an attribute needs, or handling a dimension/fact that arrives out of order
- Evaluating Inmon vs. Kimball vs. Data Vault for a new warehouse initiative
- Modeling hubs, links, and satellites for a Data Vault implementation
- Modeling a NoSQL serving store (e.g. DynamoDB single-table design), an event stream, or a bitemporal history
- Not for the SQL that implements SCD Type 2 — see `sql-data-engineering`
- Not for runtime schema validation — see `quality-data-engineering`
- Not for CDC/log-based change capture mechanics — see `streaming-data-engineering`
- Not for NoSQL infrastructure or hosting decisions — an IaC/cloud skill is planned but does not exist yet

## Quick reference

| Concern | Reach for | Reference |
|---|---|---|
| Deciding what one fact-table row represents | Declare the grain first, at the most atomic level the source data allows — before naming a single dimension or fact | [star-schema-and-grain.md](references/star-schema-and-grain.md) |
| Choosing star vs. snowflake schema | Star (a "halo" of dimension tables) by default; snowflake's storage saving is proportionally tiny since dimensions are geometrically smaller than facts | [star-schema-and-grain.md](references/star-schema-and-grain.md) |
| Summing a metric across dimensions | Additive (any dimension), semi-additive (all but time — use counts/averages), non-additive (never — recompute from components) | [star-schema-and-grain.md](references/star-schema-and-grain.md) |
| Picking a fact table shape | Transaction (one row per event), periodic snapshot (one row per entity per period), or accumulating snapshot (one row per process instance, updated across milestones) | [star-schema-and-grain.md](references/star-schema-and-grain.md) |
| Preserving or discarding dimension history on change | SCD Type 0 (never), 1 (overwrite), 2 (version — the workhorse), 3 (one extra column), 4 (mini-dimension), 6 (2+3+1 hybrid) | [scd-and-dimension-patterns.md](references/scd-and-dimension-patterns.md) |
| A fact or dimension arrives out of order | Late-arriving dimension → inferred-member placeholder row; late-arriving fact → look up the SCD Type 2 row effective at the fact's own business date | [scd-and-dimension-patterns.md](references/scd-and-dimension-patterns.md) |
| Sharing a dimension across multiple fact tables | Conformed dimensions + the enterprise bus matrix (processes × dimensions) | [scd-and-dimension-patterns.md](references/scd-and-dimension-patterns.md) |
| A dimension key with no attributes, a grab-bag of flags, a dimension used in several roles, or a genuine many-to-many | Degenerate, junk, role-playing, or bridge dimension, respectively | [scd-and-dimension-patterns.md](references/scd-and-dimension-patterns.md) |
| Choosing a warehouse methodology | Inmon (top-down 3NF EDW first), Kimball (bottom-up dimensional bus), or Data Vault (auditable, many volatile sources) — by source volatility, audit needs, speed-to-value, and team maturity, not dogma | [modeling-methodologies.md](references/modeling-methodologies.md) |
| Modeling a Data Vault hub, link, or satellite | Hub = business keys only; link = many-to-many, never end-dated; satellite = attributes + history | [data-vault-2-0.md](references/data-vault-2-0.md) |
| Choosing a Data Vault primary key | Hash key (2.0), not a sequence number (1.0) — eliminates parent-lookup dependency, enabling parallel loading | [data-vault-2-0.md](references/data-vault-2-0.md) |
| Answering "what did this hub/link look like on date X" cheaply | A Data Vault Point-in-Time or Bridge table (a different concept from Kimball's bridge table) | [data-vault-2-0.md](references/data-vault-2-0.md) |
| Deciding where dimensional modeling sits in a lakehouse | The gold layer of medallion (bronze/silver/gold) — Databricks' own vocabulary, not dbt's | [modern-lakehouse-modeling.md](references/modern-lakehouse-modeling.md) |
| Choosing between a star schema and One Big Table | Star for evolving/unknown query patterns; OBT for one fixed, already-known pattern — a deliberate trade, not a lazy default | [modern-lakehouse-modeling.md](references/modern-lakehouse-modeling.md) |
| Modeling a low-latency NoSQL serving store | DynamoDB single-table design — denormalize around known access patterns, composite partition+sort keys, no server-side joins | [modeling-for-access-patterns.md](references/modeling-for-access-patterns.md) |
| Modeling an event stream vs. its current-state table | Stream-table duality — a changelog and a table are two convertible views of the same data | [modeling-for-access-patterns.md](references/modeling-for-access-patterns.md) |
| Answering "what did we believe was true as of date X" across a table's full history | Bitemporal modeling — valid time vs. transaction time as two independent axes | [modeling-for-access-patterns.md](references/modeling-for-access-patterns.md) |

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Declaring grain after picking dimensions and facts, or leaving it implicit | Every candidate dimension/fact has to be checked against the grain — deciding it last is how fan-out and mismatched joins ship to production | Declare the grain in one sentence, first; see [star-schema-and-grain.md](references/star-schema-and-grain.md) |
| Attributing the SCD "Type 6" name (or its "1+2+3=6" mnemonic's coinage) to Ralph Kimball | Kimball Group's own Design Tip #152 says the moniker "was suggested by an HP engineer in 2000" — Kimball Group only formalized and numbered it later | Credit the unnamed HP engineer for the name, Kimball Group only for documenting it; see [scd-and-dimension-patterns.md](references/scd-and-dimension-patterns.md) |
| Treating "late-arriving fact" and "late-arriving dimension" as the same problem | One needs a retroactive SCD Type 2 lookup at the fact's business date; the other needs a placeholder row — the fixes are opposite | Name them separately; see [scd-and-dimension-patterns.md](references/scd-and-dimension-patterns.md) |
| Claiming Data Vault never performs an `UPDATE`, unlike SCD Type 2 | The Satellite's `load_end_date` is explicitly updated — the book itself calls this optional, not required from a logical-modeling perspective; only the Link is genuinely never end-dated | State the nuance by structure, not as a blanket claim; see [data-vault-2-0.md](references/data-vault-2-0.md) |
| Presenting Data Vault as competing with Kimball's dimensional marts for the same layer | Linstedt's own book states Data Vault modeling "is not a replacement for dimensional modeling" and describes marts as the end-user-facing layer built from the Vault | Position Data Vault as the auditable integration layer feeding dimensional marts; see [modeling-methodologies.md](references/modeling-methodologies.md) |
| Presenting "medallion" (bronze/silver/gold) as dbt's own vocabulary | dbt Labs' published guidance uses staging/intermediate/marts and never uses "medallion" | Cite Databricks for medallion, cross-link `pipelines-architecture-data-engineering` for dbt's real terms; see [modern-lakehouse-modeling.md](references/modern-lakehouse-modeling.md) |
| Defaulting to One Big Table to avoid writing joins | Its storage and SCD-update costs are a deliberate trade for one fixed, known access pattern, not a shortcut | Default to star schema; reach for OBT only when the query pattern is genuinely fixed; see [modern-lakehouse-modeling.md](references/modern-lakehouse-modeling.md) |
| Normalizing a DynamoDB table like an OLTP schema | There's no server-side `JOIN` to fall back on — normalization reintroduces the multi-request cost DynamoDB exists to eliminate | Design the composite key around known query patterns first; see [modeling-for-access-patterns.md](references/modeling-for-access-patterns.md) |
| Teaching CDC capture mechanics (Debezium, WAL/binlog tailing) inside an event-modeling discussion | That's ingestion/streaming infrastructure, not modeling, and is out of scope for this skill | Stay at the modeling layer — event schemas, stream-table duality, projections; defer capture mechanics to `streaming-data-engineering`; see [modeling-for-access-patterns.md](references/modeling-for-access-patterns.md) |
