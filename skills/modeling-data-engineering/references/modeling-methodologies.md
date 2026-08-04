# Modeling Methodologies

Inmon, Kimball, and Data Vault answer the same question — how do you get from raw source systems to a data warehouse business users trust? — with three different orderings of two steps: **integrate** (reconcile conflicting sources into one consistent shape) and **present** (shape data for how it's queried). Each methodology picks a different point to do the integration step, and that choice is what actually distinguishes them — not vocabulary, not tooling, and not which one is "modern." Treat this as an architectural trade-off, not a camp to join.

## Inmon: top-down, the Corporate Information Factory

Bill Inmon's approach builds an enterprise data warehouse (EDW) first — an atomic, normalized (3NF) store that integrates data across the whole organization — and derives departmental data marts from it afterward. This is the **Corporate Information Factory (CIF)**: one integrated, normalized layer as the enterprise's system of record, with dimensional marts as downstream views built on top of it once the hard integration work is done.

Inmon states the goal in his own words, in a retrospective piece on his personal Substack comparing the two architectures:

> "With the corporate information factory, there was a definitive source of data to which the corporation could turn – the 'single version of the truth'."

> "Data that comes from applications must be recast into a corporate form and structure. That is how the 'single version of the truth' is created."

He's equally direct about the cost of building that single version first — this isn't a claim made on his behalf, it's his own admission:

> "As such, building a data warehouse for the corporate information factory is not an easy or a fast thing to do. But the result is integrated data."

— Bill Inmon, ["A Tale of Two Architectures — Kimball vs Inmon"](https://williaminmon.substack.com/p/a-tale-of-two-architectures-kimball), williaminmon.substack.com

That's the honest trade Inmon's own approach makes: slower time-to-value, in exchange for data that's reconciled and consistent across the enterprise before anyone builds a report on top of it. (Linstedt & Olschimke's own Data Vault book independently describes this same architecture — under a figure they title "The Inmon Data Warehouse" — as a normalized 3NF layer businesses build data marts from "because the data is already cleaned and integrated," corroboration from an author who isn't arguing Inmon's side of the debate.)

## Kimball: bottom-up, the dimensional bus

Ralph Kimball's approach starts from the other end: build dimensional data marts directly around individual business processes (orders, shipments, claims), and connect them across the enterprise with **conformed dimensions** — dimension tables shared, with identical structure and content, across multiple fact tables. Kimball Group's own description of this is the **bus architecture**:

> "The technology- and database-independent bus architecture allows for incremental data warehouse and business intelligence (DW/BI) development."

> "It's the architectural blueprint providing the top-down strategic perspective to ensure data in the DW/BI environment can be integrated across the enterprise, while agile bottom-up delivery occurs by focusing on a single business process at a time."

— Kimball Group, ["Enterprise Data Warehouse Bus Architecture"](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/kimball-data-warehouse-bus-architecture/)

And their own definition of the mechanism that makes cross-mart integration possible without an upfront enterprise-wide model:

> "Dimension tables conform when attributes in separate dimension tables have the same column names and domain contents."

— Kimball Group, ["Conformed Dimension"](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/conformed-dimension/)

The bus matrix (business processes as rows, conformed dimensions as columns) that operationalizes this is covered in [scd-and-dimension-patterns.md](scd-and-dimension-patterns.md); this file only needs the positioning point, not the mechanics.

Kimball names the failure mode of doing this without governance, in his own vocabulary, in the article that introduced the bus matrix:

> "Conformed dimensions are the basis for distributed data warehouses, and using conformed dimensions is the way to avoid stovepipe data marts."

> "An obvious source of stovepipe data marts is the reckless use of incompatible weeks and months across the data marts."

— Ralph Kimball, ["The Matrix"](https://www.kimballgroup.com/1999/12/the-matrix/) (1999), kimballgroup.com

**Stovepipe data marts** — Kimball's own term, not a Kimball-approach critique invented by Inmon's camp — is what you get when marts are built bottom-up without conformed dimensions actually being governed: each mart defines "customer" or "week" its own way, and nothing rolls up cleanly across them. Bottom-up speed and cross-enterprise consistency are in tension; conformed dimensions, actively governed, are the only thing resolving that tension.

## Data Vault: a third model, briefly

Data Vault (Dan Linstedt) is a third answer, purpose-built for auditability, agility under changing requirements, and integrating many volatile source systems without a redesign each time one changes shape. It decomposes the model into **hubs** (business keys), **links** (relationships between business keys), and **satellites** (descriptive attributes and history) — named here only for positioning; the modeling mechanics, hash keys, insert-only nuance, and Raw/Business Vault split are covered in depth in [data-vault-2-0.md](data-vault-2-0.md).

One corroboration worth flagging explicitly: the Foreword to Linstedt & Olschimke's *Building a Scalable Data Warehouse with Data Vault 2.0* was written by Bill Inmon himself — not Linstedt describing his own work. Inmon frames Data Vault's origin in terms that line up with his own CIF goals:

> "Daniel used the term common foundational modeling architecture to describe a model based on three simple entities, focusing on business keys, their relationships and descriptive information for both. [...] It allowed to source all kinds of data, regardless its structure, in a fully auditable manner. This was a core requirement of government agencies at the time. And due to Enron and a host of other corporate failures, Basel, and SOX compliance auditability was pushed to the forefront of the industry."

— Bill Inmon, Foreword to Linstedt & Olschimke, *Building a Scalable Data Warehouse with Data Vault 2.0*

That's the person most associated with the *other* top-down methodology endorsing Data Vault's goals in his own voice — a signal that "auditable, integrated data as the foundation" is a shared value across Inmon and Data Vault, even where the internal modeling mechanics differ sharply from both Inmon's 3NF EDW and Kimball's dimensional marts.

## Choosing among the three: a decision framework, not dogma

None of the three is universally "correct." What should actually drive the choice:

- **Number and volatility of sources.** Many source systems, or systems whose structure changes often, favor Data Vault — its hub/link/satellite split is designed so a source's schema change is absorbed by closing one satellite and opening another, without touching existing ETL jobs or other satellites.
- **Audit and regulatory requirements.** Where every value must be traceable to its source system and load time (financial services, government, anything under SOX/Basel-style compliance), Data Vault's insert-only history and full lineage are purpose-built for that; Inmon's integrated EDW gives you a defensible single version of the truth too, at the cost of upfront speed.
- **Speed-to-value.** Kimball's bottom-up delivery gets a working, query-ready mart in front of business users fast, one business process at a time — the explicit reason Kimball Group calls it "agile bottom-up delivery."
- **Team maturity and governance discipline.** Kimball's speed only stays an advantage if conformed dimensions are actually governed; without that discipline, speed produces stovepipe marts, not an integrated warehouse.

This four-factor list isn't a formula any single one of the three camps states as such in one place — each factor has direct backing in what one methodology says about itself (see above), but the combination is a reasoned synthesis for decision-making, not a citation from Inmon, Kimball, or Linstedt.

Worth knowing before treating this as a permanent three-way fork: Inmon himself argues the destinations converge. He traces Kimball-style environments maturing over time — simple marts, then conformed dimensions, then master data management, then a hub-and-spoke architecture — and concludes:

> "Compare the predicted Kimball Stage 4 hub and spoke architecture with the corporate information factory architecture that was published by Inmon a decade earlier and it is seen that they in fact are the same."

He also notes what that maturity costs Kimball's speed advantage:

> "in the predicted Kimball Stage 4 with the need for true enterprise development and the creation of the 'golden record', building the Kimball Stage 4 environment is no longer speedy."

— Bill Inmon, ["A Tale of Two Architectures — Kimball vs Inmon"](https://williaminmon.substack.com/p/a-tale-of-two-architectures-kimball)

That's a claim with real authority behind it (from the person most identified with the top-down side), and it should temper how dogmatically this decision gets framed: the disagreement is mostly about sequencing and speed, not about the destination.

## The three methodologies coexist by layer in modern practice

The strongest, most concrete finding here: Data Vault is rarely the layer business users query directly, and Linstedt's own book says so plainly, in the introduction to the chapter on dimensional modeling:

> "The best application for Data Vault 2.0 modeling is in the enterprise data warehouse layer. [...] However, most business users are not familiar with Data Vault 2.0 modeling. [...] Most end-users will use an information mart to access prepared information that they can directly use for their job at hand."

> "Data Vault modeling is not a replacement for dimensional modeling, which is an industry standard for defining the data mart (the layer used to present the data to the end-user)."

— Linstedt & Olschimke, *Building a Scalable Data Warehouse with Data Vault 2.0*, Ch. 7 ("Dimensional Modeling")

Chapter 14, titled "Loading the Dimensional Information Mart," describes the actual hand-off — and does it using Kimball's own dimensional vocabulary, not Data Vault vocabulary, to describe what's being built on top of the Vault:

> "Once the raw data has been loaded from the operational source systems into the Raw Data Vault, the next step is to process the raw data and load the results from this processing into the information marts."

Its own section headings name the target structures directly: **14.2.1 Loading Type 1 Dimensions**, **14.2.2 Loading Type 2 Dimensions**, **14.2.3 Loading Fact Tables** — the exact terms Kimball's dimensional modeling uses (see [scd-and-dimension-patterns.md](scd-and-dimension-patterns.md) for what Type 1/Type 2 mean), applied to loading a mart *from* the Vault, not competing against it.

Put together, this is the practical shape modern data platforms converge on, regardless of which methodology's name gets attached to the whole stack: an auditable, insert-heavy integration layer (Data Vault, or an Inmon-style normalized EDW) reconciles and stores raw history from volatile sources, and a dimensional layer (Kimball's star schemas) sits on top of it for consumption. The three methodologies aren't competing end states to pick once — they're roles that coexist by layer, and a real warehouse can use more than one of them at the same time without contradiction.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Treating Inmon vs. Kimball as "normalized vs. denormalized, pick a side forever" | Both authors describe layered architectures; Inmon's own writing says mature Kimball environments converge toward something like his CIF | Frame the choice as sequencing and speed, not a permanent architectural religion |
| Citing "single version of the truth" or "stovepipe data marts" as generic industry jargon | Both are each author's own specific term for their own approach's goal/failure mode, verifiable in their own writing | Attribute "single version of the truth" to Inmon and "stovepipe data marts" to Kimball by name when citing them |
| Presenting Data Vault as a competitor to Kimball's dimensional marts for the same layer | Linstedt's own book states Data Vault modeling "is not a replacement for dimensional modeling" and describes marts as the end-user-facing layer built from the Vault | Position Data Vault as the integration/auditability layer feeding dimensional marts, per Ch. 7 and Ch. 14 |
| Assuming the Data Vault → mart hand-off uses Data Vault-specific vocabulary | Ch. 14's own section headings are "Loading Type 1 Dimensions," "Loading Type 2 Dimensions," "Loading Fact Tables" — Kimball's terms | Cite Ch. 14 directly when describing that hand-off; don't invent Data Vault-specific loading terminology that isn't in the source |
| Applying the four-factor decision framework (sources, audit needs, speed, maturity) as if it's a formal citation from one of the three authors | It's a reasoned synthesis across what each methodology says about itself, not a single-source formula | Present it as a decision framework, explicitly not a quote from Inmon, Kimball, or Linstedt |
| Skipping straight to Data Vault's hub/link/satellite mechanics in this file | That depth belongs to a dedicated file and would duplicate it | Use [data-vault-2-0.md](data-vault-2-0.md) for hub/link/satellite, hash keys, and insert-only mechanics |
