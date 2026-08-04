# Modeling Skill Implementation Plan

**Goal:** Write the `modeling-data-engineering` skill (`SKILL.md` + 6 reference files) for the `data-engineering-skills` repo, cross-link it from the 5 bordering skills that already carry forward-pointers or overlapping content, close the pre-existing forward-pointer in `pipelines-architecture-data-engineering/references/idempotency-and-backfills.md`, and validate it with a `writing-great-skills` self-review + a discoverability check.

**Architecture:** Same shape as every other skill in the suite — a `SKILL.md` with overview/when-to-use/quick-reference/common-mistakes, and one reference file per heavy topic under `references/`. Content is distilled from a user-supplied draft (7 conceptual layers: OLTP/OLAP, Kimball dimensional modeling, grain, dimensions/SCD, methodologies, modern lakehouse modeling, modeling for access patterns), independently verified against primary sources across 6 parallel research passes. See `docs/superpowers/specs/2026-08-04-modeling-skill-design.md` for full scope/boundary rationale.

**Research backing (read before writing any task below):**
- `docs/superpowers/research/2026-08-04-kimball-star-schema-grain-verification.md`
- `docs/superpowers/research/2026-08-04-scd-dimension-patterns-verification.md`
- `docs/superpowers/research/2026-08-04-inmon-kimball-datavault-methodologies-verification.md`
- `docs/superpowers/research/2026-08-04-data-vault-2-0-verification.md`
- `docs/superpowers/research/2026-08-04-modern-lakehouse-obt-verification.md`
- `docs/superpowers/research/2026-08-04-modeling-access-patterns-verification.md`

**Tech Stack:** Markdown; SQL/pseudo-DDL only where it clarifies a structure (e.g. a hub/satellite table shape) — do not restate the SCD Type 2 `UPDATE`+`INSERT` SQL block that already lives in `sql-data-engineering`.

## Global Constraints

- Content in English (suite convention, per `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §3).
- `SKILL.md` frontmatter limited to `name` + `description` — no Claude-specific fields.
- Skill identifier is `modeling-data-engineering` (matches folder name).
- **Mandatory corrections from the 6 research passes — do not restate the source draft's original phrasing where a research pass found it imprecise:**
  1. Not "one join away" — Kimball's own text calls it a "halo of dimension tables" surrounding the fact table (star join). Use that phrasing.
  2. Snowflake-schema rationale is **proportional size**, not "storage is cheap now": dimensions are geometrically smaller than facts, so normalizing them barely changes total database size. Kimball's stance hardened over time (1997: conditionally allowed; 2013 3rd edition: avoid outright) — state as a stance that hardened, not a static rule.
  3. 1NF/2NF/3NF formal definitions are **Codd's**, not Kimball's — cite Codd (1971) for the definitions; cite Kimball only for the OLTP-vs-OLAP motivation for why analytics denormalizes.
  4. Not "grow without bound"/"long and narrow" as Kimball's exact words — his own phrasing is "deep... but narrow." Use that.
  5. Semi-additive handling: "counts and averages" is a verbatim Kimball technique; "last value as of a point in time" is a real, commonly-taught alternative but has **no verbatim Kimball citation found** — present it as standard practice, not as a Kimball quote.
  6. **SCD Type 6**: the "1+2+3" framing is genuine Kimball Group content (Design Tip #152, authored by Margy Ross), but Kimball Group's own text attributes the "Type 6" moniker to **an unnamed HP engineer in 2000**, not to Ralph Kimball. Do not attribute coinage to Kimball, and do not use the name "Bob Jarka" anywhere — that attribution was searched for and found unconfirmed.
  7. **Late-arriving facts**: sourced directly from Kimball's own Design Tip #57, "Early Arriving Facts" (2004) — it names both patterns symmetrically in one place: a **late-arriving fact** (delayed vs. its own business date — must look up the dimension row that was effective *at the fact's business date*, not the current one) is distinct from an **early-arriving fact**/**late-arriving dimension** (fact arrives before its dimension context exists — needs an inferred-member placeholder). Cover both, named correctly, in `scd-and-dimension-patterns.md` — this is what closes the forward-pointer described below.
  8. **Data Vault insert-only nuance** (do not overclaim): **Links** are strictly never end-dated — true append-only. **Satellites** perform one `UPDATE` (closing the prior row's `LoadEndDate`) — mechanically the same operation as SCD Type 2's end-dating — and Linstedt/Olschimke's own book states this update "is not required from a logical modeling perspective," i.e. it's a performance optimization layered on top of a logically-pure append-only model, not a fundamentally different technique from SCD Type 2. State this precisely; do not present Data Vault as categorically stricter than SCD Type 2 on this specific point.
  9. Hash keys (not sequence keys) are **the specific Data Vault 2.0 innovation** vs. Data Vault 1.0 — cite the rationale (independent computation eliminates lookup-cache dependency, enabling parallel loading) and the honest trade-off the book itself admits (hash joins can be slower than integer joins).
  10. PIT tables and Bridge tables **in the Data Vault context** (query-performance structures pre-joining satellite snapshots / hub-link paths) are a **different concept** from the Kimball "bridge table" (many-to-many fact-dimension bridge, e.g. patient with multiple diagnoses) covered in `scd-and-dimension-patterns.md` — name both, mark them explicitly as distinct concepts that happen to share a name.
  11. Data Vault → Kimball hand-off: strongly confirmed — Linstedt/Olschimke's own Chapter 14 uses Kimball's own vocabulary ("Loading Type 1 Dimensions," "Loading Type 2 Dimensions," "Fact Tables") to describe populating the dimensional Information Mart from the Vault. Cite this directly in `modeling-methodologies.md` and/or `data-vault-2-0.md`.
  12. Medallion "gold" layer = home of dimensional modeling is **verbatim-confirmed** from Databricks' own docs: "The gold layer is where you'll model your data for reporting and analytics using a dimensional model." Use this exact framing, but do not blur it with dbt's own staging/intermediate/marts vocabulary — see cross-link discipline below.
  13. OBT tradeoffs: storage explosion is the best-sourced claim (a real benchmark: 29.8GB → 60.2GB). The other three tradeoffs (fixed-pattern speed, SCD-update cost, ML-feature-table framing) are consistent practitioner consensus, not sharp institutional citations — present them as industry-consensus judgment, not as quotes from an authority.
  14. Columnar-storage-cost argument for modern denormalization: **no single sharp citation exists** — present as reasonable industry synthesis (Kimball Group's own Design Tip #175 doesn't state it directly), not as a citable fact.
  15. DynamoDB single-table design: confirmed against AWS's own Developer Guide, not just a community pattern — the "antithesis of normalization, dictated by the read pattern" framing is close to a paraphrase of AWS's own words; cite the Developer Guide, not just blog posts.
  16. Stream-table duality: cite **kafka.apache.org** directly (the strongest of the candidate sources — the exact term appears verbatim there), not only Confluent's blog.
  17. Event sourcing: cite Martin Fowler's own page directly, including his own "draft since 2005" caveat if quoting him.
  18. Bitemporal modeling: cite the Jensen & Snodgrass paper (TimeCenter TR-17, 1997) for the valid-time/transaction-time definitions — Snodgrass co-authored it himself.

- **Cross-link, don't duplicate:**
  - `sql-data-engineering/references/engineering-query-patterns.md` (lines ~135-183) — SCD Type 2 SQL mechanics (`UPDATE`+`INSERT`). This skill covers the conceptual decision (which SCD type, why) and cross-links there for the implementation.
  - `pipelines-architecture-data-engineering/references/dbt-project-architecture.md` (lines 22-30) — the standing guardrail that "medallion" is not dbt's own vocabulary (dbt uses staging/intermediate/marts). `modern-lakehouse-modeling.md` must respect this: describe medallion generically, cite Databricks directly for it, and never present it as dbt terminology.
  - `quality-data-engineering/references/quality-culture-and-governance.md` — Data Mesh's data-as-a-product framing (Dehghani's 6 qualities, "SLO" not "SLA"). `modeling-for-access-patterns.md`'s data-mesh mention must be brief, cross-link there, and add only the modeling-specific angle (each domain models and owns its own data products).
  - `quality-data-engineering/references/data-contracts-and-schema-compatibility.md` — Confluent Schema Registry's 7 compatibility modes. The event-modeling section notes that event schemas version via a schema registry, without re-explaining the modes.
  - `spark-data-engineering/references/joins-and-skew.md` (line 24) — broadcast join mechanics for small dimension tables. Mention as the reason star-schema joins are fast; don't re-explain the mechanism.
  - `sql-data-engineering/references/window-functions.md` / `engineering-query-patterns.md` — the `ROW_NUMBER`/CTE dedup pattern. Mention only as an example of a stream→table projection; don't re-explain.

- **Does not cover** (explicit exclusions, matching the design spec §2.3): CDC log-based capture mechanics (Debezium, WAL/binlog — deferred to the future `streaming-data-engineering`, per the suite spec's already-closed CDC finding), runtime schema validation (`quality-data-engineering`), function/class-level code (`python-data-engineering`), NoSQL infrastructure/hosting (future `iac-cloud-data-engineering`).

- **Forward-pointer to close:** `pipelines-architecture-data-engineering/references/idempotency-and-backfills.md` lines 46-48 currently reads (plain prose, no link): *"Backfilling is also the mechanism for absorbing late-arriving data: reprocessing the affected window once delayed data shows up, which connects directly to the late-arriving-fact patterns covered in dimensional modeling."* Once `scd-and-dimension-patterns.md` exists (with its late-arriving-facts section per constraint #7 above), update that sentence into a real hyperlink to it — same treatment as the `serving-pipeline-output.md` forward-pointer resolved when `quality-data-engineering` shipped.

---

## File Structure

**Create, in `data-engineering-skills/skills/modeling-data-engineering/`:**
- `SKILL.md`
- `references/star-schema-and-grain.md`
- `references/scd-and-dimension-patterns.md`
- `references/modeling-methodologies.md`
- `references/data-vault-2-0.md`
- `references/modern-lakehouse-modeling.md`
- `references/modeling-for-access-patterns.md`

**Modify, elsewhere in the repo:**
- `skills/pipelines-architecture-data-engineering/references/idempotency-and-backfills.md` — resolve the forward-pointer (see above).
- `skills/sql-data-engineering/SKILL.md` and/or `references/engineering-query-patterns.md` — add a pointer to this skill's conceptual SCD coverage, mirroring how other skills cross-link both ways.
- `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` — update the suite's Estado line (7/9 delivered).
- `README.md` — update skill count/table.

Each reference file stands alone as its own task. `SKILL.md` comes after all six, since its quick-reference table names all of them. Cross-link updates come last, since they link into this skill. A `writing-great-skills` self-review and discoverability validation close out the plan.

---

### Task 1: `references/star-schema-and-grain.md`

**Source:** `docs/superpowers/research/2026-08-04-kimball-star-schema-grain-verification.md`. Apply global constraints #1-5.

**Content requirements:**
- OLTP (normalized, 1NF/2NF/3NF per Codd) vs. OLAP (denormalized) — the write-integrity vs. read-performance trade framed as a deliberate choice, not "breaking the rules."
- Fact tables (measurable events, numeric measures + FKs, deep but narrow, grow continuously) vs. dimension tables (descriptive context, wide, shallow).
- Star schema: fact table surrounded by a "halo" of dimension tables (star join) — why that shape makes queries fast (shallow joins, broadcast-joinable dimensions — cross-link `spark-data-engineering/joins-and-skew.md`), intuitive, and BI-friendly.
- Snowflake schema and why Kimball's own guidance moved from "conditionally allowed" (1997) to "avoid" (2013) — the proportional-size argument, not a storage-cost argument.
- The four-step Kimball design process: choose the business process → declare the grain → identify dimensions → identify facts.
- Grain: declare it at the most atomic level possible — rationale (aggregate later from atomic detail; can't recover detail from an aggregate). Connect to the SQL fan-out bug (`sql-data-engineering/joins.md`'s grain-mismatch framing) as the practical cost of getting grain wrong.
- Additivity: additive (sums across all dimensions), semi-additive (sums across some but not time — account balance/inventory, use average or last-value), non-additive (ratios/percentages/unit prices — recomputed, never summed).
- Three fact table types: transaction fact (one row per event), periodic snapshot (one row per entity per period), accumulating snapshot (one row per process instance, updated as it passes milestones — the one fact-table type where rows get `UPDATE`d).
- Common mistakes table.

- [ ] **Step 1:** Write the file per the content requirements above, grounded in the cited research file, applying corrections #1-5.
- [ ] **Step 2:** Verify: `grep -c "^## " skills/modeling-data-engineering/references/star-schema-and-grain.md` returns a sensible section count (expect 6-8).
- [ ] **Step 3:** Commit: `git add skills/modeling-data-engineering/references/star-schema-and-grain.md && git commit -m "Add modeling-data-engineering skill: star schema and grain"`

---

### Task 2: `references/scd-and-dimension-patterns.md`

**Source:** `docs/superpowers/research/2026-08-04-scd-dimension-patterns-verification.md`. Apply global constraint #6, #7.

**Content requirements:**
- Surrogate keys: the three reasons (decoupling from source-system keys / integrating multiple sources, integer-join performance — flagged per Kimball's own 1998 admission this reason is "strongly suspected but never proven," and enabling SCD Type 2).
- SCD Types 0, 1, 2, 3, 4 with Kimball's own definitions; Type 2's SQL mechanics are NOT restated here — cross-link `sql-data-engineering/engineering-query-patterns.md` for that.
- SCD Type 6 — the "1+2+3" framing (Design Tip #152, Margy Ross) with the correct, careful attribution (moniker from an unnamed HP engineer in 2000, not Kimball).
- **Late-arriving dimensions** (inferred-member placeholder row, backfilled when real data arrives) **and late-arriving facts** (must look up the dimension row effective at the fact's own business date, per Design Tip #57) — named symmetrically and distinctly, per global constraint #7. This section is what resolves the `idempotency-and-backfills.md` forward-pointer.
- Conformed dimensions and the bus matrix (business processes as rows, conformed dimensions as columns; enables drill-across).
- Degenerate dimension, junk dimension, role-playing dimension, bridge table (many-to-many fact-dimension, e.g. patient/diagnoses — note this is Kimball's own example, not a third-party analogy) — flag explicitly that "bridge table" here is a *different* concept from the Data Vault PIT/Bridge tables covered in `data-vault-2-0.md` (global constraint #10).
- Common mistakes table (include the SCD Type 6 attribution and the late-arriving-fact-vs-dimension distinction as entries).

- [ ] **Step 1:** Write the file per the content requirements, grounded in the cited research file.
- [ ] **Step 2:** Verify: `grep -c "^## " skills/modeling-data-engineering/references/scd-and-dimension-patterns.md` returns a sensible section count.
- [ ] **Step 3:** Commit: `git add skills/modeling-data-engineering/references/scd-and-dimension-patterns.md && git commit -m "Add modeling-data-engineering skill: SCD and dimension patterns"`

---

### Task 3: `references/modeling-methodologies.md`

**Source:** `docs/superpowers/research/2026-08-04-inmon-kimball-datavault-methodologies-verification.md`. Apply global constraint #11.

**Content requirements:**
- Inmon: top-down, normalized (3NF) enterprise data warehouse first (Corporate Information Factory), departmental marts derived from it — cite his own stated goal ("the single version of the truth") and his own acknowledgment that it's slower but yields integrated data.
- Kimball: bottom-up, dimensional data marts directly around business processes, connected by conformed dimensions (the bus) — cite his own term "stovepipe data marts" for the governance-failure risk of doing this badly.
- Data Vault (positional summary only — full depth lives in `data-vault-2-0.md`): third model for auditability/agility/many changing sources — hubs/links/satellites, note the Foreword of Linstedt & Olschimke's book was written by Bill Inmon himself, corroborating shared goals.
- The decision framework: number/volatility of sources, audit/regulatory requirements, speed-to-value, team maturity — not dogma. Note Inmon's own observation that Kimball's approach converges toward something like his own CIF over time.
- Explicitly state, with citation: Data Vault is rarely the consumption layer — Linstedt/Olschimke's own Chapter 14 describes loading a dimensional Information Mart *from* the Vault, using Kimball's own vocabulary ("Type 1 Dimensions," "Type 2 Dimensions," "Fact Tables") — the three methodologies coexist by layer in modern practice (an auditable integration layer feeding dimensional marts for consumption), not as competing dogmas.
- Common mistakes table.

- [ ] **Step 1:** Write the file per the content requirements, grounded in the cited research file.
- [ ] **Step 2:** Verify: `grep -c "^## " skills/modeling-data-engineering/references/modeling-methodologies.md` returns a sensible section count.
- [ ] **Step 3:** Commit: `git add skills/modeling-data-engineering/references/modeling-methodologies.md && git commit -m "Add modeling-data-engineering skill: modeling methodologies"`

---

### Task 4: `references/data-vault-2-0.md`

**Source:** `docs/superpowers/research/2026-08-04-data-vault-2-0-verification.md`, grounded in the two canonical books at `docs/superpowers/books/` (`building_a_scalable_data_warehouse_with_data_vault.md`, `data-vault-modeling-guide.md`). This is the **emphasis file** — the deepest and most detailed of the six, matching the depth Kimball receives across Tasks 1-2. Apply global constraints #8, #9, #10, #11.

**Content requirements:**
- Hub (business keys only, no descriptive data), Link (many-to-many relationships, never end-dated, no context), Satellite (the only structure carrying descriptive attributes and history) — Linstedt's own Ch.4.2 definitions, cited directly.
- Hash keys vs. sequence keys as the specific Data Vault 2.0 innovation over 1.0 — the rationale (independent computation, no lookup-cache dependency) and the honest admitted trade-off (hash joins can be slower than integer joins).
- Insert-only/auditability nuance, precisely: Links are strictly append-only; Satellites perform one `UPDATE` to close `LoadEndDate` — mechanically the same operation as SCD Type 2 — and the book itself says this update isn't required from a logical-modeling perspective. State plainly that this is a performance optimization on a logically pure append-only model, not a fundamentally different technique from SCD Type 2.
- Parallel loadability: hash keys remove the need to look up a parent's warehouse-generated key before inserting a child, enabling hubs/links to load independently and in parallel — tie this to the book's own title ("Scalable").
- Raw Vault vs. Business Vault: as-loaded structures vs. a layer with business rules/calculations applied on top.
- PIT (Point-in-Time) tables and Bridge tables in the Data Vault context: query-performance-only, system-generated structures — PIT pre-joins satellite snapshots for one hub/link, Bridge pre-joins hash keys across multiple hubs/links — explicitly distinct from the Kimball "bridge table" in `scd-and-dimension-patterns.md`.
- Data Vault feeding a Kimball-style dimensional Information Mart for consumption: cite Ch.14's own use of Kimball's dimensional vocabulary directly — this is Linstedt's own framing, closing the loop with `modeling-methodologies.md`.
- Common mistakes table (include the insert-only nuance and the PIT/Bridge naming collision as entries).

- [ ] **Step 1:** Write the file per the content requirements, grounded in the cited research file and the two source books' exact chapter/section citations.
- [ ] **Step 2:** Verify: `grep -c "^## " skills/modeling-data-engineering/references/data-vault-2-0.md` returns a sensible section count (expect this to be the longest file — 8+ sections acceptable).
- [ ] **Step 3:** Commit: `git add skills/modeling-data-engineering/references/data-vault-2-0.md && git commit -m "Add modeling-data-engineering skill: Data Vault 2.0"`

---

### Task 5: `references/modern-lakehouse-modeling.md`

**Source:** `docs/superpowers/research/2026-08-04-modern-lakehouse-obt-verification.md`. Apply global constraints #12, #13, #14, and the medallion-is-not-dbt cross-link discipline.

**Content requirements:**
- Columnar storage/compute cost trend enabling more aggressive denormalization than when Kimball's principles were written — presented explicitly as reasonable industry synthesis, not a single sharp citation (constraint #14). The underlying vocabulary (facts, dimensions, grain, SCD) hasn't changed — only the cost calculus has.
- Medallion architecture (bronze/silver/gold), cited directly against Databricks' own docs — bronze/silver defined briefly, gold as the layer where dimensional modeling lives (verbatim per constraint #12). Explicit note: this is Databricks/lakehouse vocabulary, **not** dbt's own — cross-link `pipelines-architecture-data-engineering/dbt-project-architecture.md` for dbt's staging/intermediate/marts terms, never conflate the two.
- dbt modeling-as-code: brief mention only (already covered in depth elsewhere) — the new angle this file adds is that dbt's tests + version control + CI/CD turn the dimensional model itself into a testable, versioned artifact, not a one-time design decision.
- The One Big Table (OBT) trade-off: real named pattern — fast/simple for a fixed, known query pattern (a specific dashboard, ML feature table); costly to update (SCD becomes rewriting many rows) and inflexible to new access patterns; storage explosion (cite the real benchmark: 29.8GB → 60.2GB). Present the update-cost and ML-feature-table framing as practitioner consensus, per constraint #13 — flag the caveat that Databricks' own Feature Store docs actually recommend joining multiple feature tables, not one wide OBT.
- The judgment call: star schema for flexible/evolving analytical workloads; OBT for a fixed, known access pattern — a deliberate choice, not a lazy default.
- Common mistakes table (include presenting medallion as dbt's own vocabulary as an entry, reinforcing the existing guardrail).

- [ ] **Step 1:** Write the file per the content requirements, grounded in the cited research file.
- [ ] **Step 2:** Verify: `grep -c "^## " skills/modeling-data-engineering/references/modern-lakehouse-modeling.md` returns a sensible section count.
- [ ] **Step 3:** Commit: `git add skills/modeling-data-engineering/references/modern-lakehouse-modeling.md && git commit -m "Add modeling-data-engineering skill: modern lakehouse modeling"`

---

### Task 6: `references/modeling-for-access-patterns.md`

**Source:** `docs/superpowers/research/2026-08-04-modeling-access-patterns-verification.md`. Apply global constraints #15, #16, #17, #18, and the CDC-exclusion + Data Mesh cross-link discipline.

**Content requirements:**
- The governing principle: model for the access pattern (how it's queried, by whom, at what latency), not just for the entity — the same information can need three different shapes for three different consumers (normalized OLTP, dimensional warehouse, denormalized serving store).
- DynamoDB single-table design: cite AWS's own Developer Guide directly — model around the application's known access patterns, denormalize aggressively, composite keys (partition key + sort key), no server-side joins. Frame explicitly as the antithesis of relational normalization, correct specifically because the access pattern (point lookup, high concurrency, millisecond latency) demands it.
- Event modeling and stream-table duality: cite kafka.apache.org directly for the term itself (a stream of change events and a table of current state are two convertible views of the same data). Mention the `ROW_NUMBER`/CTE dedup pattern only as an example of a stream→table projection, cross-linking `sql-data-engineering` rather than re-explaining it. **Do not teach CDC capture mechanics** (Debezium/WAL/binlog) — that's out of scope, deferred to the future `streaming-data-engineering` skill; if mentioned at all, it's a one-line deferred cross-link, matching the treatment already used elsewhere in the suite.
- Event sourcing: cite Martin Fowler's own page directly — events as the source of truth (append-only log), current state as a derived projection.
- Bitemporal modeling: cite the Jensen & Snodgrass paper directly for valid time (when a fact was true in the real world) vs. transaction/system time (when it was recorded) — the practical payoff ("what did we believe was true, as of a given point in time") for audit/regulatory/restatement scenarios. Note the connection to late-arriving facts (`scd-and-dimension-patterns.md`) as a related but distinct concept.
- Data mesh and domains: brief — each domain models and owns its own data products; cross-link `quality-data-engineering/quality-culture-and-governance.md` for the Dehghani/data-as-a-product/SLO framing rather than repeating it.
- Common mistakes table.

- [ ] **Step 1:** Write the file per the content requirements, grounded in the cited research file.
- [ ] **Step 2:** Verify: `grep -c "^## " skills/modeling-data-engineering/references/modeling-for-access-patterns.md` returns a sensible section count.
- [ ] **Step 3:** Commit: `git add skills/modeling-data-engineering/references/modeling-for-access-patterns.md && git commit -m "Add modeling-data-engineering skill: modeling for access patterns"`

---

### Task 7: `SKILL.md`

**Depends on:** Tasks 1-6 (its quick-reference table names all six files).

**Content requirements:** Overview (grain as the "atom" of modeling, access patterns as the governing justification — same framing thread as the source draft), "when to use" bullets, a quick-reference table (one row per major decision: choosing star vs. snowflake, declaring grain, picking an SCD type, choosing a methodology, modeling a Data Vault hub/link/satellite, deciding OBT vs. star, modeling a NoSQL serving store, etc. — one row per reference file at minimum), a common-mistakes table pulling the highest-signal entries from each reference file (the SCD Type 6 attribution and the Data Vault insert-only nuance should both appear here, since those are the two corrections most likely to be gotten wrong). Description field should front-load "modeling" as the leading word and list the skill's branches (dimensional modeling, Data Vault, methodology choice, modern lakehouse/OBT, NoSQL/streaming/bitemporal modeling) per `writing-great-skills` guidance on descriptions.

- [ ] **Step 1:** Write `SKILL.md`.
- [ ] **Step 2:** Verify every reference file is linked at least once from `SKILL.md`: `for f in skills/modeling-data-engineering/references/*.md; do grep -q "$(basename "$f")" skills/modeling-data-engineering/SKILL.md || echo "MISSING: $f"; done` — expect no output.
- [ ] **Step 3:** Commit: `git add skills/modeling-data-engineering/SKILL.md && git commit -m "Add modeling-data-engineering skill: SKILL.md"`

---

### Task 8: Cross-links, suite bookkeeping, and self-review

**Depends on:** Task 7.

- [ ] **Step 1:** Update `skills/pipelines-architecture-data-engineering/references/idempotency-and-backfills.md` (lines 46-48) — turn the plain-prose "late-arriving-fact patterns covered in dimensional modeling" into a real hyperlink to `scd-and-dimension-patterns.md`'s late-arriving-facts section.
- [ ] **Step 2:** Add an outbound cross-link from `sql-data-engineering` (SKILL.md and/or `engineering-query-patterns.md`'s SCD Type 2 section) pointing to this skill's conceptual coverage (which SCD type to choose, why), mirroring the reciprocal-link pattern used for the Airflow/Dagster/Prefect cross-link closed earlier today.
- [ ] **Step 3:** Update `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` Estado line: 7/9 delivered, 2 remaining (`streaming-data-engineering`, `iac-cloud-data-engineering`).
- [ ] **Step 4:** Update `README.md`'s skill table and count.
- [ ] **Step 5:** Update this skill's own design spec (`docs/superpowers/specs/2026-08-04-modeling-skill-design.md`) Estado line to "Implementado y shippeado."
- [ ] **Step 6:** Self-review the full skill against `writing-great-skills` (`.agents/skills/writing-great-skills/SKILL.md`) — check for duplication, no-ops, sediment, sprawl per its Failure Modes section; fix anything found.
- [ ] **Step 7:** Discoverability validation — same lightweight process used for prior skills: a fresh-context read of `SKILL.md` alone (no reference files) should make an agent pick the right reference file for each of: "design a schema for an e-commerce order pipeline," "should I use SCD Type 1 or Type 2 here," "our team is evaluating Data Vault vs. Kimball," "model a DynamoDB table for this API." Fix any miss.
- [ ] **Step 8:** Commit remaining changes: `git add -A && git commit -m "Cross-link modeling-data-engineering skill and close suite bookkeeping"`
