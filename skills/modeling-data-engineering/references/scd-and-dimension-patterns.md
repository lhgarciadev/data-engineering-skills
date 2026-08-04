# SCD and Dimension Patterns

A dimension table describes the world at query time, but the world doesn't hold still — a customer moves, a product gets reclassified, a sales territory gets renamed. Slowly Changing Dimension (SCD) techniques are Kimball Group's own numbered vocabulary for deciding what happens to history when that underlying attribute changes. None of it works without a structural prerequisite — the surrogate key — so that's where this file starts, before working through which SCD type to reach for, what to do when a dimension or a fact shows up out of order, and the handful of special-purpose dimension shapes (conformed, degenerate, junk, role-playing, bridge) that round out the vocabulary. The `UPDATE`+`INSERT` SQL for implementing Type 2 already lives in [sql-data-engineering's engineering-query-patterns.md](../../sql-data-engineering/references/engineering-query-patterns.md) — this file covers the conceptual decision (which type, why), not the mechanics.

## Surrogate keys: three reasons, one honestly unproven

Ralph Kimball's own rule, stated flatly:

> "Every join between dimension tables and fact tables in a data warehouse environment should be based on surrogate keys, not natural keys."
> — Ralph Kimball, ["Surrogate Keys"](https://www.kimballgroup.com/1998/05/surrogate-keys/), Kimball Group, 1998

Three reasons justify it, and they carry different weight.

**Decoupling from the source system, and integrating multiple sources.** A warehouse's keys need to survive changes production makes for its own reasons: "As the data warehouse manager, you need to keep your keys independent from the production keys. Production has different priorities from you." Kimball's own example is a company merger: "Your company has just made an acquisition, and you need to merge more than a million new customers into the master customer list. You will now need to extract from two production systems, but the newly acquired production system has nasty customer keys that don't look remotely like the others." The 2013 whitepaper restates the same reason more formally: natural keys "may be created by more than one source system, and these natural keys may be incompatible or poorly administered."

**Integer-join performance — flagged with Kimball's own honesty about it.** This is the reason most often repeated as settled fact, but Kimball never claimed to have measured it:

> "The final reason I can think of for surrogate keys is one that I strongly suspect but have never proven. Replacing big, ugly natural keys and composite keys with beautiful, tight integer surrogate keys is bound to improve join performance. The storage requirements are reduced, and the index lookups would seem to be simpler. I would be interested in hearing from anyone who has harvested a performance boost by replacing big ugly fat keys with anonymous integer keys."

Treat it the way Kimball himself did: a reasonable, widely-accepted expectation, not a benchmarked claim to cite as fact.

**Enabling SCD Type 2.** Tracking history means a single natural key must be able to map to more than one dimension row over time — a natural key alone can't do that:

> "Usually, when the data warehouse administrator encounters a changed description in a dimension record such as product or customer, the correct response is to issue a new dimension record. But to do this, the data warehouse must have a more general key structure. Hence the need for a surrogate key."

This third reason is the load-bearing one for everything that follows: without a surrogate key, none of the SCD types below that add rows (Type 2, Type 4, Type 6) are possible at all. Worth noting: Kimball's own 1998 article already anticipates the placeholder/inferred-member pattern covered later in this file, describing a special surrogate key for "the customer identification has not taken place yet" — the same problem the late-arriving-dimension pattern solves.

## SCD Types 0-4: Kimball's core techniques

All five are defined verbatim in Kimball Group's [*Kimball Dimensional Modeling Techniques*](https://www.kimballgroup.com/wp-content/uploads/2013/08/2013.09-Kimball-Dimensional-Modeling-Techniques11.pdf) whitepaper (pp. 11-12):

| Type | Kimball Group's definition |
|---|---|
| **0 — Retain Original** | "The dimension attribute value never changes, so facts are always grouped by this original value... appropriate for any attribute labeled 'original,' such as a customer's original credit score or a durable identifier. It also applies to most attributes in a date dimension." |
| **1 — Overwrite** | "The old attribute value in the dimension row is overwritten with the new value; type 1 attributes always reflects the most recent assignment, and therefore this technique destroys history." |
| **2 — Add New Row** | "Add[s] a new row in the dimension with the updated attribute values. This requires generalizing the primary key of the dimension beyond the natural or durable key... A minimum of three additional columns should be added to the dimension row with type 2 changes: 1) row effective date or date/time stamp; 2) row expiration date or date/time stamp; and 3) current row indicator." |
| **3 — Add New Attribute** | "Add[s] a new attribute in the dimension to preserve the old attribute value; the new value overwrites the main attribute as in a type 1 change. This kind of type 3 change is sometimes called an alternate reality." |
| **4 — Mini-Dimension** | "Used when a group of attributes in a dimension rapidly changes and is split off to a mini-dimension. This situation is sometimes called a rapidly changing monster dimension... The type 4 mini-dimension requires its own unique primary key; the primary keys of both the base dimension and mini-dimension are captured in the associated fact tables." |

A few things worth being precise about:

- **Type 2** is the workhorse the rest of the family builds on (Types 4, 5, 6, 7 all extend it), but "workhorse" is a fair characterization, not Kimball's own wording. Its mechanics — close the current row, insert a new one under a fresh surrogate key — are exactly the `UPDATE`+`INSERT` pattern in [engineering-query-patterns.md](../../sql-data-engineering/references/engineering-query-patterns.md); don't re-derive that SQL here.
- **Type 3**'s "limited to one change of history" isn't Kimball's verbatim phrase — it's the direct, correct consequence of the mechanic he describes (one extra column holds exactly one prior value), so present it as an inference from the definition, not a quote.
- **Type 4** splits off attributes that change fast and independently of the rest of the dimension (e.g. a customer's current promotion segment) into their own mini-dimension, referenced by its own key from the fact table alongside the base dimension's key.

## SCD Type 6: the "1+2+3" hybrid, and who actually named it

Kimball Group's 2013 whitepaper defines Type 6 with no origin story attached:

> "Slowly changing dimension type 6 also delivers both historical and current dimension attribute values. Type 6 builds on the type 2 technique by also embedding current type 1 versions of the same attributes in the dimension row so that fact rows can be filtered or grouped by either the type 2 attribute value in effect when the measurement occurred or the attribute's current value. In this case, the type 1 attribute is systematically overwritten on all rows associated with a particular durable key whenever the attribute is updated."

The "1+2+3" framing — and the honest attribution behind it — comes from a different piece of genuine Kimball Group content: [Design Tip #152](https://www.kimballgroup.com/2013/02/design-tip-152-slowly-changing-dimension-types-0-4-5-6-7/), written by Margy Ross (Kimball Group's president and co-author of *The Data Warehouse Toolkit*), in February 2013:

> "Type 6 builds on the type 2 technique by also embedding current attributes in the dimension so that fact rows can be filtered or grouped by either the type 2 value in effect when the measurement occurred or the attribute's current value. **The type 6 moniker was suggested by an HP engineer in 2000** because it's a type 2 row with a type 3 column that's overwritten as a type 1; both 2 + 3 + 1 and 2 x 3 x 1 equal 6."

Get this attribution exactly right — it's a common point of confusion: **the "1+2+3=6" mnemonic is genuine Kimball Group material**, published under Margy Ross's byline, so it's fair to cite Kimball Group for it. But **Kimball Group does not claim to have coined the "Type 6" name itself** — its own text says the moniker was suggested by an unnamed HP engineer in 2000, well before Kimball Group formalized and numbered it in the third edition of *The Data Warehouse Toolkit* (2013). Don't attribute the coinage to Ralph Kimball, and don't attach any more specific name to that HP engineer — no name for that person has been confirmed in Kimball Group's own material or anywhere else. (Type 6 isn't alone in this numbered-mnemonic family: the same Design Tip names Type 5 as "4 + 1 equals 5," a mini-dimension key embedded and overwritten as type 1 — mentioned here only so Type 6 isn't mistaken for the only hybrid in Kimball's numbering.)

## Late-arriving dimensions and facts

Data doesn't always arrive in the order it happened. Kimball names two distinct, symmetric problems this causes — one where the dimension is missing, one where the fact is stale — and conflating them is a real, easy-to-make mistake.

**Late-arriving dimensions** happen when a fact shows up before the dimension context that describes it exists yet. The 2013 whitepaper's own example is a real-time inventory event referencing a customer the warehouse hasn't loaded yet:

> "Sometimes the facts from an operational business process arrive minutes, hours, days, or weeks before the associated dimension context... In these cases, special dimension rows are created with the unresolved natural keys as attributes. Of course, these dimension rows must contain generic unknown values for most of the descriptive columns; presumably the proper dimensional context will follow from the source at a later time. When this dimensional context is eventually supplied, the placeholder dimension rows are updated with type 1 overwrites."

Kimball's own [Design Tip #57](http://www.kimballgroup.com/wp-content/uploads/2012/05/DT57EarlyArriving.pdf) ("Early Arriving Facts," 2004) describes this identical scenario from the fact's point of view, and names the mechanism the same way: "An early arriving fact takes place when the activity measurement arrives at the data warehouse without its full context... we assign a new Customer surrogate key with a set of dummy attribute values in a new Customer dimension record. We then return to this dummy dimension record at a later time and make Type 1 (overwrite) changes to its attributes when we get more complete information on the new Customer." This inferred-member (or placeholder) row, backfilled later via a plain Type 1 overwrite, is the same pattern whether you call the fact "early" or the dimension "late" — it's the dimension side of one shared phenomenon.

**Late-arriving facts** are a genuinely different problem: the fact record itself is delayed relative to its own business date, and by the time it shows up, the Type 2 dimension it references has already moved on to a newer version. The whitepaper's definition:

> "A fact row is late arriving if the most current dimensional context for new fact rows does not match the incoming row. This happens when the fact row is delayed. In this case, the relevant dimensions must be searched to find the dimension keys that were effective when the late arriving measurement event occurred."

Design Tip #57 — the same article, since Kimball treats both patterns together — is explicit that this is a retroactive lookup problem, not an overwrite problem:

> "For several years, we have been aware of special modifications to these procedures to deal with Late Arriving Facts, namely fact records that come into the warehouse very much delayed. This is a messy situation because we have to search back in history within the data warehouse to decide how to assign the right dimension keys that were in effect when the activity occurred at the right point in the past."

This is exactly where SCD Type 2 pays off: "the right dimension keys that were in effect" only means something because a Type 2 dimension carries multiple time-bounded versions per natural key (effective date, expiration date, current-row indicator — see the table above). Loading a late-arriving fact means joining it to the dimension row whose effective/expiration window contains the fact's own business date, never the row flagged as current. The `UPDATE`+`INSERT` mechanics that produce those effective-dated rows in the first place are in [engineering-query-patterns.md](../../sql-data-engineering/references/engineering-query-patterns.md); this section is the modeling reason that lookup has to be date-bounded rather than a join on the current row.

This late-arriving-fact pattern is also what [`pipelines-architecture-data-engineering`'s idempotency-and-backfills.md](../../pipelines-architecture-data-engineering/references/idempotency-and-backfills.md) points to when it notes that backfilling a window is "the mechanism for absorbing late-arriving data": reprocessing that window only produces the right numbers if the reprocessing logic looks up the dimension row that was effective at the time, per this section — not the dimension's current state at backfill time.

## Conformed dimensions and the bus matrix

A dimension is **conformed** when it's shared, identically, across multiple fact tables:

> "Dimension tables conform when attributes in separate dimension tables have the same column names and domain contents. Information from separate fact tables can be combined in a single report by using conformed dimension attributes that are associated with each fact table... This is the essence of integration in an enterprise DW/BI system."

That shared shape is what makes **drill-across** possible — comparing metrics from two different business processes (e.g. orders and shipments) in one report, by aligning them on a dimension both share:

> "Drilling across simply means making separate queries against two or more fact tables where the row headers of each query consist of identical conformed attributes. The answer sets from the two queries are aligned by performing a sort-merge operation on the common dimension attribute row headers."

The **enterprise data warehouse bus matrix** is the planning tool that keeps conformed dimensions consistent as an organization builds out multiple business processes incrementally, rather than all at once:

> "The rows of the matrix are business processes and the columns are dimensions. The shaded cells of the matrix indicate whether a dimension is associated with a given business process. The design team scans each row to test whether a candidate dimension is well-defined for the business process and also scans each column to see where a dimension should be conformed across multiple business processes."

In practice: build the matrix before building tables. Each new business process becomes a row; each dimension it needs either reuses an existing conformed column or forces a conversation about whether it should.

## Degenerate, junk, and role-playing dimensions

Three shapes solve three narrow, recurring modeling problems that don't fit a normal dimension table.

**Degenerate dimension** — a dimension key with no dimension table behind it, living directly in the fact table. Kimball's own example is an invoice number:

> "Sometimes a dimension is defined that has no content except for its primary key. For example, when an invoice has multiple line items, the line item fact rows inherit all the descriptive dimension foreign keys of the invoice, and the invoice is left with no unique content. But the invoice number remains a valid dimension key for fact tables at the line item level. This degenerate dimension is placed in the fact table with the explicit acknowledgment that there is no associated dimension table."

**Junk dimension** — a grab-bag of low-cardinality flags and indicators, combined into one dimension so they don't clutter the schema with a separate tiny table each:

> "Transactional business processes typically produce a number of miscellaneous, low-cardinality flags and indicators. Rather than making separate dimensions for each flag and attribute, you can create a single junk dimension combining them together... it does not need to be the Cartesian product of all the attributes' possible values, but should only contain the combination of values that actually occur in the source data."

**Role-playing dimension** — one physical dimension table, referenced multiple times from the same fact table, each reference representing a distinct logical role:

> "A single physical dimension can be referenced multiple times in a fact table, with each reference linking to a logically distinct role for the dimension. For instance, a fact table can have several dates, each of which is represented by a foreign key to the date dimension. It is essential that each foreign key refers to a separate view of the date dimension so that the references are independent."

Kimball's own example here is generic ("several dates"), not the specific `order_date`/`ship_date`/`delivery_date` trio commonly used to teach this — that trio is a standard, apt pedagogical example, but attribute it as convention, not as Kimball's verbatim wording. Each role gets its own view with uniquely aliased column names, so a query joining all three doesn't collide on `date_key` or `full_date`.

## Bridge tables: a name Data Vault also uses, for something else

A **bridge table** resolves a genuinely multivalued dimension — one where a single fact row legitimately connects to more than one dimension member at once. Kimball's own example:

> "In a classic dimensional schema, each dimension attached to a fact table has a single value consistent with the fact table's grain. But there are a number of situations in which a dimension is legitimately multivalued. For example, a patient receiving a healthcare treatment may have multiple simultaneous diagnoses. In these cases, the multivalued dimension must be attached to the fact table through a group dimension key to a bridge table with one row for each simultaneous diagnosis in a group."

Bridge tables can also intersect with SCD Type 2: when the underlying relationship itself changes over time (Kimball's example is a many-to-many between bank accounts and customers), the bridge table needs its own effective/expiration timestamps, and a query has to constrain it to one point in time to get a consistent snapshot — the same time-bounded-lookup discipline as the late-arriving-facts section above.

**Naming collision to know about:** this is a completely different concept from the "PIT" and "Bridge" tables in Data Vault modeling. Data Vault's Bridge tables (and PIT tables) are query-performance structures that pre-join hash keys or satellite snapshots for reporting — a physical optimization layer, not a way to model a many-to-many relationship. That coverage lives in a sibling file, `data-vault-2-0.md`, not here — the two "bridge table" names refer to unrelated structures that happen to share a name; don't conflate them.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Citing "integer joins are faster" as a Kimball-proven fact | Kimball's own 1998 article calls this reason something he "strongly suspect[s] but ha[s] never proven" | Present it as a reasonable, widely-held expectation, not a benchmarked claim |
| Restating the SCD Type 2 `UPDATE`+`INSERT` SQL in a modeling discussion | Duplicates content already maintained in `sql-data-engineering` | Cross-link [engineering-query-patterns.md](../../sql-data-engineering/references/engineering-query-patterns.md) instead of re-deriving the SQL |
| Attributing the "Type 6" name (or the "1+2+3=6" mnemonic's coinage) to Ralph Kimball | Kimball Group's own Design Tip #152 says the moniker "was suggested by an HP engineer in 2000" — Kimball Group formalized it later, in 2013 | Credit the HP engineer (unnamed) for the name; credit Margy Ross/Kimball Group only for documenting and numbering it |
| Naming a specific person as the SCD Type 6 originator | Kimball Group's own material identifies only "an HP engineer" with no name — no source confirms any specific individual | Attribute the moniker to "an unnamed HP engineer, 2000" and go no further than what Kimball Group itself states |
| Treating "late-arriving fact" and "late-arriving dimension" as the same problem | One needs a retroactive Type 2 lookup (fact is stale); the other needs a placeholder row (dimension doesn't exist yet) — the fixes are opposite | Name them separately: late-arriving dimension = inferred-member placeholder + later Type 1 overwrite; late-arriving fact = search Type 2 history for the row effective at the fact's business date |
| Joining a late-arriving fact to the dimension's *current* row | Silently attributes a historical event to today's dimension attributes, corrupting historical reporting | Join on the Type 2 row whose effective/expiration window contains the fact's own business date |
| Assuming "bridge table" means the same thing in Kimball and Data Vault contexts | Kimball's bridge table resolves a many-to-many fact-dimension relationship; Data Vault's is a query-performance pre-join structure | Name both explicitly and don't conflate them — see `data-vault-2-0.md` for the Data Vault meaning |
| Forgetting a natural key can map to multiple dimension rows once Type 2 is in play | Joining fact tables on the natural key instead of the surrogate key silently double-counts or picks the wrong version | Always join fact-to-dimension on the surrogate key, never the natural/business key |
