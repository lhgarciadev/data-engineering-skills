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

**Treat the shape, not just this instance.** A vendor publishing a numbered pillar framework for a data-quality-adjacent topic is a recurring move, and the second one is already in circulation: dlt ships its own *"five pillars of data quality"* — Structural Integrity, Semantic Validity, Uniqueness & Relations, Privacy & Governance, Operational Health — on a page whose opening line disqualifies the competition (*"The data quality lifecycle has rarely been achievable in a single tool due to the runtime constraints of traditional ETL vendors"*) and whose capability table marks several rows as available only in the paid product. Different five, different topic, same move. When you meet a numbered framework in this space, find out who published it and what they sell before repeating the number. Sourcing: `docs/superpowers/research/2026-08-20-el-build-vs-buy-and-dlt-verification.md`.

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
| Citing any vendor's numbered "pillars" framework as an industry standard | Monte Carlo's five observability pillars and dlt's five data-quality pillars are both marketing framings, and other vendors reproduce the first without attribution | Name the publisher, and check what they sell, before using the framework pedagogically |
| Treating dbt's lineage graph and an orchestrator's asset lineage as the same thing | One is declared transformation dependencies inside a dbt project; the other is runtime orchestration dependencies across any asset type | Use dbt's DAG for impact analysis inside a dbt project; use the orchestrator's asset graph for cross-pipeline dependencies |
| Presenting MTTD/MTTR as data-engineering-native metrics | They're imported from SRE/systems reliability, and their application to data quality specifically is vendor territory, not a neutral standard | Attribute the origin, and don't lean on MTTR alone as a trend metric without the caveat above |
| Assuming Soda is "just an observability tool" | Its current (4.x) product spans both data-contract validation and observability as separate pillars | Check which Soda pillar (Contracts vs. Observability) a given feature actually belongs to before comparing it to a pure-play tool like Monte Carlo |
