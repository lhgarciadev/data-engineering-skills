# Modern Lakehouse Modeling

Kimball's dimensional vocabulary — grain, facts, dimensions, SCD — was written against 1990s hardware economics, when storage and joins were both expensive enough that avoiding redundancy mattered as much as query speed. Cloud columnar warehouses and lakehouses changed that economics without touching the vocabulary. This file covers what changed (the cost calculus, the platform layering, the storage-pattern debate) and points back to what didn't (the concepts themselves, defined in [star-schema-and-grain.md](star-schema-and-grain.md) and [scd-and-dimension-patterns.md](scd-and-dimension-patterns.md)).

## The cost calculus changed, not the vocabulary

Columnar storage compresses repeated values far more efficiently than the row-oriented RDBMSs available when Kimball wrote his original principles. Martin Kleppmann's *Designing Data-Intensive Applications* (O'Reilly), in its "Column-Oriented Storage" and "Column Compression" sections, explains the mechanism: a column-store groups values from the same column together, and a column made mostly of repeated values — exactly what a denormalized dimensional attribute becomes once it's repeated across many fact rows — compresses dramatically better than the equivalent row-store layout. That's the technical basis for why denormalization is cheaper in storage today than the same choice would have been on 1990s hardware.

No single institutional source states that conclusion end to end, though. Kimball Group's own [Design Tip #175, "There Is No Database Magic"](https://www.kimballgroup.com/2015/06/design-tip-175-there-is-no-database-magic/) (2015) acknowledges that columnar/MPP/in-memory technologies bring "substantial scalability and query performance improvements for analytic workloads compared to the standard RDBMSs" — but its actual point runs almost the opposite direction, as a warning against complacency: "What they do not offer is magic. There is no magic!" That's an argument that better hardware doesn't excuse undisciplined dimensional design, not a statement that the cost calculus shifted. Data architecture consultant Uli Bethke makes the connection this file needs more directly, but as a practitioner's synthesis, not an institutional standard: "With the advent of columnar storage formats for data analytics this is less of a concern nowadays," concluding that Kimball's concepts still "add value" but need adapting "for new technologies and storage types."

Treat this as reasonable industry synthesis, not a citable fact: the mechanism (Kleppmann) is solid, and the spirit is corroborated by both Kimball Group's own acknowledgment that the underlying technology changed and a recognized practitioner voice (Bethke) — but no source, including Kimball Group itself, has published the full argument as a single sharp claim. What hasn't changed is the vocabulary: grain, facts, dimensions, and SCD types mean exactly what they meant before; only how expensive it is to denormalize them changed.

## Medallion architecture: bronze, silver, gold

Databricks' own medallion architecture documentation defines three layers, moving from raw to business-ready:

| Layer | Databricks' own definition |
|---|---|
| Bronze | "Contains and maintains the raw state of the data source in its original formats," with minimal validation. |
| Silver | "Represents validated, cleaned, and enriched versions of the data." |
| Gold | "The gold layer is where you'll model your data for reporting and analytics using a dimensional model by establishing relationships and defining measures." |

That gold-layer quote is verbatim and unambiguous: Databricks itself names dimensional modeling — facts, dimensions, and the star schema covered in [star-schema-and-grain.md](star-schema-and-grain.md) — as gold's job. Bronze and silver exist to feed it clean, validated data; how validation is split across that progression (permissive at bronze, strict at the boundary into silver) is already covered in [quality-dimensions-and-validation.md](../../quality-data-engineering/references/quality-dimensions-and-validation.md)'s "Schema-on-write vs. schema-on-read, and where medallion fits" section — this file's only new addition is that gold, specifically, is where the dimensional model lives.

**Medallion is not dbt's vocabulary.** "Bronze/silver/gold" is a Databricks/lakehouse term, not dbt's own — see [dbt-project-architecture.md](../../pipelines-architecture-data-engineering/references/dbt-project-architecture.md)'s "The layering convention — and why it isn't 'medallion'" section for dbt's real vocabulary (staging, intermediate, marts) and why the two shouldn't be presented as one and the same terminology; this file only covers where dimensional modeling sits within medallion specifically, not the layering comparison itself.

## dbt: modeling as a testable, versioned artifact

dbt's staging/intermediate/marts mechanics, materialization, and DAG are already covered in [dbt-project-architecture.md](../../pipelines-architecture-data-engineering/references/dbt-project-architecture.md); its generic tests (`unique`, `not_null`, `accepted_values`, `relationships`) are covered in [quality-dimensions-and-validation.md](../../quality-data-engineering/references/quality-dimensions-and-validation.md). The angle this file adds: dbt's own foundational statement of intent, ["The dbt Viewpoint"](https://docs.getdbt.com/community/resources/viewpoint), argues that "analytic code... should be version controlled" and that "any code that generates data or analysis should be reviewed and tested" — treating analytics with the same rigor software engineering applies to production code. dbt Labs doesn't single out dimensional models in that statement, but nothing exempts them either: a marts model implementing a fact or dimension table runs through the identical `ref()` dependency graph, the same generic tests, the same version control, and the same CI pipeline as any other model. In practice, that turns the dimensional model from a one-time design decision made in a whiteboard session into a testable, versioned artifact — one that changes under change control and fails a build the moment a grain assumption or a relationship breaks.

## One Big Table (OBT): the trade-off

One Big Table (OBT) — a single wide, denormalized table joining in every attribute a query needs, in place of a fact table surrounded by a halo of dimension tables — is a real, named pattern discussed by Databricks' own Solutions Architects, Fivetran, and analytics-engineering consultancies like Brooklyn Data Co., not an invented strawman. It trades away the star schema's flexibility for speed against one, fixed, already-known query pattern: a specific dashboard, or the wide feature vector an ML model consumes. Databricks' own DBSQL Solutions Architects team frames the fit this way: "OBT works well for use cases where you only need to filter the table on 1–3 dimensions, and the rest of your analytics / apps are built on those filters."

Two of OBT's costs are well-evidenced, with hard numbers or semi-official sourcing:

- **Storage explosion** is the best-documented cost. Fivetran's own benchmark measured a normalized fact table at 29,778 MB against the same information denormalized into one big table at 60,250 MB — roughly double the storage (29.8GB → 60.2GB) for identical content, because dimension attributes that would live once per dimension row now repeat once per fact row.
- **Fixed-pattern speed** carries the semi-official Databricks backing quoted above.

Two more costs are consistent practitioner consensus across independent sources (ssp.sh, ml4devs.com, dedp.online, Brooklyn Data Co.) rather than a single sharp institutional citation — worth being explicit about that distinction rather than presenting them as if an authority stated them directly:

- **SCD updates become expensive.** Changing a denormalized attribute (a renamed product, a relocated customer) means rewriting every fact row that repeats it, instead of updating one dimension row — the same kind of update SCD Type 2 already performs on a dimension, but now multiplied across however many fact rows carry that attribute.
- **ML feature tables** are a commonly cited OBT use case — a wide, denormalized table is a natural shape for a feature vector. This needs a caveat, though: Databricks' own Feature Store documentation does *not* recommend a single wide OBT for feature serving — it describes joining multiple separate feature tables together at training time via `FeatureLookup`. Treat "OBT as feature table" as an extended practitioner pattern, not something Databricks' own ML platform actually recommends.

## Star schema vs. OBT: a deliberate choice

Neither pattern is categorically superior — the choice tracks the access pattern, not a preference. Databricks itself declines to declare a winner: "The decision between Dimensional Modeling and the One Big Table approaches requires a nuanced understanding." One practitioner framing captures the trade cleanly: OBT is "a fast answer to questions you already know," while a star schema is "a flexible foundation that answers questions you haven't thought of yet." Brooklyn Data Co. runs this in production rather than just arguing it — Kimball modeling upstream to preserve flexibility, with an OBT reporting layer downstream for a known, fixed consumption pattern.

Use that as the decision rule: star schema (or snowflake, per [star-schema-and-grain.md](star-schema-and-grain.md)) for analytical workloads whose questions keep changing; OBT for a single, stable, already-known access pattern where the storage and update costs above are an acceptable, deliberate trade. Reaching for OBT because joins feel inconvenient, without a fixed access pattern to justify it, is the lazy-default version of this choice — not the deliberate one it should be.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Presenting "medallion" (bronze/silver/gold) as dbt's own vocabulary | dbt Labs' published guidance uses staging/intermediate/marts and never uses "medallion" anywhere in its docs | Cite Databricks directly for medallion; cross-link [dbt-project-architecture.md](../../pipelines-architecture-data-engineering/references/dbt-project-architecture.md) for dbt's real terms, and never merge the two vocabularies |
| Citing the columnar-storage-cost argument for denormalization as a single Kimball Group claim | No institutional source, including Kimball Group's own Design Tip #175, states that exact argument end to end — the design tip's actual point is closer to a warning against complacency | Present it as industry synthesis (mechanism from Kleppmann, spirit from Kimball Group and practitioner sources), not a citable quote |
| Treating all four OBT tradeoffs as equally well-sourced | Storage explosion has a hard benchmark (29.8GB → 60.2GB) and fixed-pattern speed has semi-official Databricks backing; SCD-update cost and the ML-feature-table framing are practitioner consensus without a sharp institutional citation | Label each claim at the confidence level it actually has |
| Recommending OBT as a wide feature table because "ML uses OBT" | Databricks' own Feature Store docs describe joining multiple feature tables via `FeatureLookup` at training time, not serving from one wide table | Cite that caveat before recommending OBT for ML feature serving |
| Defaulting to OBT to avoid writing joins | OBT's storage and SCD-update costs are a deliberate trade for a fixed, known access pattern, not a shortcut | Default to star schema; reach for OBT only when the query pattern is genuinely fixed and known |
