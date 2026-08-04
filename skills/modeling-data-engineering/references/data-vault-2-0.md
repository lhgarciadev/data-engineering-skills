# Data Vault 2.0

Data Vault is Dan Linstedt's answer to a specific pain Kimball and Inmon don't optimize for: many source systems, all changing shape over time, under real audit/regulatory pressure, where a schema change in one source shouldn't force a redesign of everything downstream. [modeling-methodologies.md](modeling-methodologies.md) covers the positioning question (when to reach for Data Vault vs. Inmon vs. Kimball, and how the three coexist by layer). This file is the modeling depth behind it — the actual shape of a Data Vault model, sourced directly from Linstedt & Olschimke's *Building a Scalable Data Warehouse with Data Vault 2.0*, cross-checked against Hans Hultgren's *Data Vault Modeling Guide* where the two sources usefully disagree.

## Hub, Link, and Satellite: the three core structures

Every Data Vault model reduces to three entity types, and Linstedt & Olschimke's own summary states what each one is *for*, not just what it contains:

> "the hub separates the business keys from the rest of the model; the link stores relationships between business keys (and/or hubs); and satellites store the context (the attributes of a business key or relationship)." (Ch. 4.2)

**Hub** — a unique list of business keys and nothing else. "Hubs are defined using a unique list of business keys and provide a soft-integration point of raw data that is not altered from the source system" (Ch. 4.3). A hub's required attributes are exactly four: hash key, business key(s), load date, record source (an optional last-seen date can be added) — there is no descriptive data in a hub, full stop. If you find yourself adding a status flag or a name column to a hub, that column belongs in a satellite instead.

**Link** — a many-to-many relationship between two or more hubs, modeling "transactions, associations, hierarchies, and redefinitions of business terms" (Ch. 4.4). Data Vault links are *always* many-to-many, regardless of the real-world cardinality, deliberately: "In the Data Vault model, only many-to-many relationships exist due to the use of link entities... By doing so, the Data Vault model tries to reduce the re-engineering effort down to zero" (Ch. 4.4.1). The payoff is concrete: if a business rule changes from "one carrier per airport" to "many carriers per airport," a traditional 3NF foreign-key model requires a schema redesign; a Data Vault link already supports it, so nothing downstream has to change.

**Satellite** — the only structure that carries descriptive attributes and history. "Satellites store all data that describes a business object, relationship, or transaction. They add context at a given time or over a time period to hubs and links" (Ch. 4.5). A satellite is always attached to exactly one hub or link, keyed by the parent's hash key plus the timestamp of the change — "satellites are never dependent on more than one parent table... They also can't be parents to any other table (no snow flaking)" (Ch. 4.5). This is where all the SCD-style history lives; hubs and links carry none of it.

A minimal physical shape, illustrating the three roles rather than any specific vendor's DDL:

```sql
-- Hub: business key only, no descriptive data
CREATE TABLE hub_customer (
    customer_hash_key CHAR(32) PRIMARY KEY,  -- MD5 of the business key
    customer_business_key VARCHAR(50) NOT NULL,
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(50) NOT NULL
);

-- Link: many-to-many, hash keys of the hubs it connects, never end-dated
CREATE TABLE link_customer_order (
    link_hash_key CHAR(32) PRIMARY KEY,  -- MD5 of both business keys
    customer_hash_key CHAR(32) NOT NULL REFERENCES hub_customer,
    order_hash_key CHAR(32) NOT NULL REFERENCES hub_order,
    load_date TIMESTAMP NOT NULL,
    record_source VARCHAR(50) NOT NULL
);

-- Satellite: descriptive attributes and history
CREATE TABLE sat_customer_details (
    customer_hash_key CHAR(32) NOT NULL REFERENCES hub_customer,
    load_date TIMESTAMP NOT NULL,
    load_end_date TIMESTAMP,  -- the one attribute ever UPDATEd
    hash_diff CHAR(32) NOT NULL,
    email VARCHAR(255),
    address VARCHAR(255),
    record_source VARCHAR(50) NOT NULL,
    PRIMARY KEY (customer_hash_key, load_date)
);
```

One cross-source honesty note: Hultgren's 2012 guide describes this exact same three-entity model, but keys everything with "a warehouse machine sequence id" — a `grep -i hash` across his whole guide turns up zero occurrences of the word "hash." That's not a contradiction between authorities; it's a snapshot from before Data Vault 2.0 formalized the hash key. Treat hub/link/satellite as the timeless part of the method, and the hash key (next section) as specifically the 2.0-era mechanism layered on top of it.

## Hash keys vs. sequence keys: the Data Vault 2.0-specific innovation

The hash key is *the* thing that changed between Data Vault 1.0 and 2.0 — not the hub/link/satellite shape above, which is unchanged. Linstedt & Olschimke say so directly: "the hash key replaces the sequence number from the Data Vault 1.0 standard" (Ch. 4.3.2.1).

Chapter 11.2, "Hashing in the Data Warehouse," is the book's own argument for why sequence numbers had to go, and it's worth citing at length because it's the strongest, most citable justification in the whole book — and it's the direct payoff of the word "Scalable" in the title:

> "There are multiple drawbacks with sequence numbers: **Dependencies in the loading processes**: in order to load a destination, every dependency has to be loaded first... **Waiting on caches for parent lookups**... this causes a bottleneck in the loading processes. This can be alleviated or removed by switching the model to Data Vault 2.0 Hash Keys – eliminating the need for lookup caching altogether. **Dependencies on serial algorithms**: sequence numbers... need to be synchronized in order to prevent two sequence numbers with the same value. In Big Data environments, the required synchronization can become a problem... **Scalability issues**: sequence numbers are easy to use but are limited when it comes to scalability." (Ch. 11.2)

And the resolution, stated as plainly as a modeling book gets:

> "Due to these drawbacks and limitations, hash keys are used as primary keys in the Data Vault 2.0 model, thus replacing sequence numbers as surrogate keys... because hash keys are calculated independently in loading processes, there are no lookups into other Data Vault 2.0 entities required in order to get the surrogate key of a business key. In general, a lookup into another table requires I/O performance... On the other hand, computing a hash key only requires CPU performance, which is often favored over I/O performance because of better parallelization." (Ch. 11.2)

The mechanism: a hash key is computed deterministically from the business key alone (MD5 is "the recommended practice", SHA-1 as an alternative — Ch. 4.3.2.1), with no dependency on any other table. A sequence key, by contrast, only exists after the parent row has been inserted and its generated ID looked up — which is exactly the dependency that forces hub-then-link-then-satellite load ordering under Data Vault 1.0.

The book does not oversell this — it states the trade-off honestly rather than hiding it: "Joining data based on hash keys might be slower compared to integer-based sequence numbers, but the advantages outweigh the disadvantages" (Ch. 4.3.2.1). Treat hash keys as a deliberate scalability trade (CPU-bound, parallelizable, no lookup dependency) against a real query-time cost (wider join keys than integers), not as a strictly-superior replacement with no downside.

## Insert-only and auditability: the precise comparison with SCD Type 2

Auditability is Data Vault's core promise, and the mechanism is: never update or modify satellite content. "Because the history of the data needs to be preserved, you are not allowed to update or modify the data in the satellite. The only exception to this rule is the Load End Date attribute of the previous version of the data" (Ch. 4.5.1).

That exception matters more than it looks. Chapter 4.5.3.3 spells it out: "The required load end date indicates the date and time when the satellite entry becomes invalid... **It is the only attribute that is updated in a satellite**. The update occurs once a new entry is loaded from the source system. While the new entry has a current load date, the last satellite entry that was valid just before the loading of the new entry is updated to reflect the new load end date." And then the book adds the sentence that changes the whole framing: "**It is not required from a logical modeling perspective.**" (Ch. 4.5.3.3)

Read that precisely, because it's easy to overclaim here. The load-end-date `UPDATE` is a performance optimization the book layers on top of a logically-pure append-only model — a satellite could, in principle, stay 100% insert-only forever and derive each row's validity at query time by comparing its load date against the next row's load date for the same parent. The book adds the `UPDATE` purely so queries can use a `BETWEEN` instead of a correlated subquery or window function every time.

That means, mechanically: **INSERT the new satellite row, UPDATE the prior row's `load_end_date`** is the exact same two-step pattern as Kimball SCD Type 2's standard implementation (close the old row, insert the new one — see [sql-data-engineering's engineering-query-patterns.md](../../sql-data-engineering/references/engineering-query-patterns.md) for that SQL). At the level of what SQL actually runs against the satellite, this is not a different technique from SCD Type 2. The real difference is in what's *constitutive* of the model: in Kimball, `end_date`/`is_current` is part of the dimension's logical definition — you can't drop it without losing the model's semantics. In Data Vault, the book states outright that the same column is optional scaffolding on top of an already-complete, purely-append model.

Where Data Vault genuinely is stricter — no hedging needed — is the **Link**. A link is never end-dated, under any circumstance: "it is important that links not be end-dated and contain no other time or context information, except a Load Date attribute for technical and informative reasons" (Ch. 4.4). If a relationship ends, the link row itself is untouched forever; the ending gets recorded in a separate effectivity satellite attached to it. Kimball's dimensional model has no equivalent concept of a standalone, permanently-immutable relationship table — a fact row's foreign key to a Type-2 dimension changes meaning as the dimension version changes, but there's no separate "link" object being kept append-only the way Data Vault keeps one.

**Net precision**: "Data Vault is insert-only, therefore stricter than SCD Type 2" is true for the Link, and only a framing difference — not a different technique — for the Satellite. Don't present the two structures as if they made the same guarantee; they don't.

## Parallel loadability: the payoff behind "Scalable"

The hash key's independence from any lookup is what makes hubs, links, and satellites loadable in parallel, and this is close to a literal explanation of the book's own subtitle. Splitting satellites by source system, the book notes, "maximizes load parallelism because there is no competition (at the I/O or database level) for the target resource (the satellite). The data can be inserted into the satellite immediately without taking the arrival of data from other systems into account" (Ch. 4.5.2.1).

The same reasoning shows up again when loading the Information Mart: retrieving a dimension's key from the mart itself instead of recomputing the hash "would add additional and unnecessary dependencies to the loading processes, which should be avoided in order to improve the parallelization of the loading processes" (Ch. 14.2.3).

Put together with the Ch. 11.2 argument from the previous section: without hash keys, loading a link or satellite requires first resolving (looking up) the sequence number generated when its parent hub row was inserted — an order-of-loading dependency. With hash keys, a link or satellite computes its own key deterministically from the business key it already has, with zero lookups against any other Data Vault table. That's what turns "hub, then link, then satellite, in that order" into "hub, link, and satellite, loaded independently, in parallel" — the scalability the book's title is naming.

## Raw Vault vs. Business Vault

The book's exact term for the "as-loaded" layer is **Raw Data Vault** (not the shorthand "Raw Vault" that circulates informally — worth using the precise term if you're citing the book directly). It holds data changed only by *hard* business rules — technical, type-level rules that never alter meaning — kept deliberately dumb so it never needs re-loading when a business rule changes: "the goal of the Data Vault 2.0 architecture is to move complex business rules towards the end-user in order to ensure quick adaption to changes" (Ch. 2.2.1–2.2.2).

The **Business Vault** is where *soft* business rules — the ones that do change meaning or grain — get applied, on top of the Raw Data Vault: "The Business Vault is a sparsely modeled data warehouse based on Data Vault design principles, but houses business-rule changed data... In most cases, the Business Vault is an intermediate layer between the Raw Data Vault and the information marts" (Ch. 2.2.7).

The auditability line is drawn exactly here, and it's the whole reason the two layers are kept separate: "it doesn't have the same requirements regarding the auditability of the source data. Instead, it is possible to drop and regenerate the Business Vault from the Raw Data Vault at any time" (Ch. 2.2.7). The mechanism is usually a **computed satellite** — often a SQL view over Raw Data Vault data, applying a soft rule, with its `RecordSource` deliberately changed away from the original source system to signal it's no longer raw (Ch. 14.1). Practically: if a business-rule change means recomputing history, that's a Business Vault rebuild, never a Raw Data Vault reload — the Raw Data Vault should never need to be touched once loaded.

## PIT and Bridge tables in the Data Vault context (not Kimball's bridge table)

With multiple satellites hanging off one hub or link — the normal case once you're integrating several source systems — answering "what did this customer look like on January 5th?" turns into an expensive query: "It requires OUTER JOIN queries with complex time range handling involved to achieve this goal. With more than three satellites on a hub or link, this becomes complicated and also slow" (Ch. 6.1).

**Point-in-Time (PIT) tables** solve this by pre-computing the answer for a fixed set of snapshot dates. A PIT table stores, for each hub/link hash key and snapshot date, "the load dates and the corresponding hash keys from each satellite that corresponds best with the snapshot date" (Ch. 6.1) — turning what would be an outer join with range logic into a cheap equi-join. Crucially, this is a performance-only structure, not part of the auditable warehouse: "Because the data in a PIT table is system-computed and is not originating from a source system, the data is not to be audited. The purpose of this table is to provide performance only" (Ch. 6.1).

**Bridge tables** solve a related but distinct problem: reducing joins *across* hubs and links rather than across satellites of one hub/link. "Unlike PIT tables, which span across multiple satellites of a hub or link, a bridge table spans across multiple hubs and links... The bridge table acts as a higher-level fact-less fact table and contains hash keys from the hubs and links it spans" (Ch. 6.2). The book's own side-by-side: "PIT tables are on one single hub or link only... Bridge tables, on the other hand, are created from multiple hubs and links... Both entities have in common that they are system-generated entities that are not part of the core architecture. System-generated fields make them nonauditable" (Ch. 6.2.2).

**Naming collision to flag explicitly**: this "bridge table" is *not* the Kimball bridge table covered in [scd-and-dimension-patterns.md](scd-and-dimension-patterns.md) (the many-to-many fact-to-dimension resolver, e.g. a patient with multiple diagnoses). They share a name and the general idea of "a pre-join table that simplifies downstream queries," but they operate on different objects and solve different problems: the Data Vault bridge table pre-joins hash keys across Data Vault hubs/links to speed up virtualized mart queries; the Kimball bridge table resolves a genuine many-to-many business relationship between a fact and a dimension. Don't let a reader conflate the two just because both files use the word "bridge."

## From Data Vault to a Kimball-style Information Mart

[modeling-methodologies.md](modeling-methodologies.md) already covers *why* Data Vault and Kimball coexist by layer (Ch. 7's "Data Vault modeling is not a replacement for dimensional modeling"). What belongs here is the mechanical *how* — the actual key hand-off from Vault structures into dimension and fact tables, which is Chapter 14's subject, and which uses Kimball's own vocabulary to describe it: section headings **14.2.1 Loading Type 1 Dimensions**, **14.2.2 Loading Type 2 Dimensions**, **14.2.3 Loading Fact Tables** (Ch. 14.2).

The mechanics differ meaningfully by dimension type. Loading a **Type 1 dimension** is close to free: "AirportCodeKey identifies the rows of the dimension table, which is the hash key from the Data Vault 2.0 model. Using the hash key instead of a sequence number improves the provision of dimension tables because the hash key is already available in the Data Vault 2.0 model" (Ch. 14.2.1) — truncate-and-reload, keyed directly on the hub's existing hash key, no recalculation. The book notes, from experience, that "the grain for dimension tables comes from a hub table in 80% of the cases" (Ch. 14.2.1).

Loading a **Type 2 dimension** is harder, because a dimension row now needs to represent one specific version of the data, not just the hub's business key: "the key column is not directly sourced from the hash key column in the Raw Data Vault hub table. Instead, it is a value that is calculated from the business key and a date" (Ch. 14.2.2) — typically sourced from a PIT table, which already carries the load-date-to-satellite-version mapping described above. Loading the fact table then reuses those same recalculated dimension keys, and the book explicitly warns against re-deriving them by looking the dimension key up from the mart itself, for the same parallel-loading reason covered above (Ch. 14.2.3).

The book states plainly, back in the architecture chapter, that the information mart "often follows the star schema and forms the basis for both relational reporting and multidimensional OLAP cubes" (Ch. 2.2.5) — and Chapter 1 explicitly credits Kimball as the source of the two-layer stage/warehouse architecture pattern the book builds on ("Kimball has introduced an often-used, two-layer architecture", Ch. 1.4.1). This isn't a synthesis this skill is layering on top of the sources — it's Linstedt describing his own architecture using Kimball's own terms, in his own book.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Claiming "Data Vault never does an `UPDATE`, unlike SCD Type 2" | The Satellite's `load_end_date` is explicitly updated, and the book itself calls this "not required from a logical modeling perspective" — a performance optimization on an append-only model, mechanically the same INSERT+UPDATE pattern as SCD Type 2 | State the nuance by structure: the Link is genuinely never end-dated; the Satellite's one `UPDATE` is optional scaffolding, not a categorically different technique from SCD Type 2 |
| Treating "PIT" and "Bridge" tables as the same concept as Kimball's bridge table | Data Vault's PIT/Bridge are system-generated, nonauditable, query-performance structures over hubs/links/satellites; Kimball's bridge table resolves a real many-to-many fact-to-dimension business relationship | Name both explicitly when either comes up, and cross-link [scd-and-dimension-patterns.md](scd-and-dimension-patterns.md) for the Kimball one |
| Presenting the hash key as just "a different way to generate a surrogate key" | Its entire rationale is eliminating the parent-lookup dependency that sequence numbers force — that's what enables parallel loading, not a stylistic preference | Cite the Ch. 11.2 lookup-elimination argument, and be honest about the trade-off the book itself admits: hash joins can be slower than integer joins |
| Assuming the Business Vault needs the same auditability guarantees as the Raw Data Vault | The book states the opposite: the Business Vault "doesn't have the same requirements regarding the auditability of the source data" and can be dropped/regenerated at any time | Keep soft business rules in the Business Vault, exactly so they can be rebuilt without touching Raw Data Vault history |
| Writing "Raw Vault" as if it's the book's own term | Linstedt & Olschimke consistently write "Raw Data Vault" | Use "Raw Data Vault" when citing the book directly; treat "Raw Vault" as an informal community shorthand |
| Presenting Data Vault as the layer end users query | Linstedt's own Ch. 7 says Data Vault modeling "is not a replacement for dimensional modeling" and most business users work through the information mart instead | Position Data Vault as the auditable integration layer feeding a Kimball-style mart — see [modeling-methodologies.md](modeling-methodologies.md) for the full positioning argument |
| Assuming Data Vault 1.0 and 2.0 are the same modeling notation with a rebrand | The hash key (replacing the sequence number) is the specific, named 2.0 change — confirmed by Hultgren's pre-2.0 guide never using the word "hash" at all | Cite the hash key specifically as the 1.0→2.0 delta when the distinction matters, not the hub/link/satellite shape (which is unchanged) |
