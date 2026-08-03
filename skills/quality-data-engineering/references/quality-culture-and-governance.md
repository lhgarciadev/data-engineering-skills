# Quality Culture and Governance

Tooling detects problems. Without clear ownership, agreed-upon service levels, and a producer that's actually accountable, the best observability setup just generates alerts nobody acts on. This file is the layer above the mechanics.

## Data as a product

Zhamak Dehghani's 2019 article that introduced Data Mesh ("How to Move Beyond a Monolithic Data Lake to a Distributed Data Mesh," martinfowler.com) names six qualities a domain's data product should have, under the heading "Domain data as a product": **Discoverable**, **Addressable**, **Trustworthy and truthful**, **Self-describing semantics and syntax**, **Inter-operable and governed by global standards**, **Secure and governed by a global access control**. Treat a dataset as a product with these guarantees, not as a by-product of whatever pipeline happens to produce it.

## Ownership and SLOs

Dehghani's article uses **SLO** (Service Level Objective), not SLA — "Each domain dataset must establish Service Level Objectives for the quality of the data it provides: timeliness, error rates, etc." A commonly taught triad — freshness, completeness, availability — is a reasonable synthesis for teaching purposes, not something one single source formalizes exactly that way: freshness and completeness both have real backing as named dimensions (Monte Carlo documents both explicitly), availability is the weakest of the three in the evidence for a data-specific SLA/SLO, closer to a borrowed analogy from classic infrastructure uptime SLAs. For the concrete, field-level mechanism behind that commitment, see [data-contracts-and-schema-compatibility.md](data-contracts-and-schema-compatibility.md)'s `servicelevels` block — this file covers the cultural "why," that one covers the technical "how."

## Shift-left

Push quality toward the source instead of catching it at the end: a contract with the producer (see [data-contracts-and-schema-compatibility.md](data-contracts-and-schema-compatibility.md)), validation at the ingestion boundary (see [quality-dimensions-and-validation.md](quality-dimensions-and-validation.md)), and tests that run before code merges rather than after it ships.

## Quality gates in CI/CD

dbt's own documented mechanism for this is called **Slim CI** — running only the models a pull request actually touched, plus their downstream dependents, compared against the last successful production run:

```bash
dbt build --select state:modified+ --defer --state path/to/prod/artifacts
```

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
