# Streaming Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write `streaming-data-engineering` — the eighth domain skill of the `dataforge` suite — close the three forward-pointers that already declare toward it, and prove by measurement that it routes.

**Architecture:** Same shape as the seven delivered domain skills: a `SKILL.md` router with overview / when-to-use / quick reference / common mistakes, and six `references/` files of roughly 1.6k–3.5k words each. Content is organised around one frame — streaming is processing an unbounded dataset, and time, order and completeness are the whole problem. Every claim is verified against a primary source before it is written, and the delivered skill is measured against the triggering harness before it is considered done.

**Tech Stack:** Markdown skill files; `claude plugin validate` for manifest and frontmatter; `tests/triggering/` (`run-matrix.sh`, `rescore.sh`) for behavioural measurement.

**Spec:** `docs/superpowers/specs/2026-08-07-streaming-skill-design.md` — read it before starting any task.

## Global Constraints

- All skill artifacts are in **English**, including reference files. Specs and plans are in Spanish, matching this repo's split.
- Frontmatter must stay **≤ 1024 characters** total, and must parse as YAML. A `: ` inside an unquoted scalar breaks parsing and the skill loads with every field silently dropped. Run `claude plugin validate .` after any frontmatter edit.
- **Never name a skill that does not exist.** `iac-cloud-data-engineering` does not exist yet; refer to the domain, not the skill name, and say it has no skill in this suite. This suite has already shipped a phantom-invocation bug from exactly this.
- Description patterns, all three measured in this repo, not stylistic preference:
  - jargon-free triggers alongside technical ones — real diagnostic prompts do not use domain vocabulary;
  - boundaries as conditionals on an observable predicate, not prohibitions;
  - the co-invocation clause verbatim: `Still applies when a general debugging or design skill also fits — that one supplies the method, this one the streaming-domain knowledge.`
- Reference files: 1.6k–3.5k words. Cross-links must resolve **from the linking file's own directory**, which means the depth differs by where the link lives:
  - from `SKILL.md` to its own references: `[text](references/file.md)`
  - from `SKILL.md` to another skill: `[text](../other-skill/references/file.md)`
  - from a file inside `references/` to another skill: `[text](../../other-skill/references/file.md)` — two levels, because you climb out of `references/` first
  Verify every link by resolving it, never by eye. An earlier draft of this plan wrote the two-level case with one level in fourteen places.
- **Anchored links must have their anchor checked too.** The obvious grep, `grep -oE '\]\([^)]+\.md\)'`, silently skips any link carrying a `#fragment` — it matched nothing in a file where all ten links were anchored. Use this instead, from the directory holding the file:

```bash
bad=0
for f in *.md; do
  while read -r l; do
    [ -z "$l" ] && continue
    path="${l%%#*}"; frag="${l#*#}"
    t=$(realpath -m "$path" 2>/dev/null)
    [ -f "$t" ] || { echo "BROKEN FILE   $f -> $l"; bad=1; continue; }
    [ "$frag" = "$l" ] && continue
    grep -oE '^#{1,6} .*' "$t" | sed 's/^#* //' | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^a-z0-9 -]//g; s/ /-/g' | grep -qx "$frag" \
      || echo "BROKEN ANCHOR $f -> $l"
  done < <(grep -ohE '\]\([^)]+\)' "$f" | sed 's/^](//; s/)$//' | grep '\.md')
done
```

  The trap this catches: a heading containing an em-dash slugifies to a **double** hyphen, because the dash is stripped and its two surrounding spaces both become hyphens. `## Retention vs. compaction — and the sentence` becomes `retention-vs-compaction--and-the-sentence`. Writing one hyphen there produces a link that resolves to the file but lands at the top of it, not the section.
- Every reference file linked from `SKILL.md` must exist, and every file under `references/` must be linked from `SKILL.md`.
- Research verification docs go to `docs/superpowers/research/2026-08-07-<topic>-verification.md`, matching the 28 already there.
- Commit per task. Conventional commits, no AI attribution.

---

## File Structure

| File | Responsibility |
|---|---|
| `docs/superpowers/research/2026-08-07-*.md` | Seven verification passes; each records claim, source, verdict |
| `skills/streaming-data-engineering/references/unbounded-data-and-when-not-to-stream.md` | Bounded vs unbounded, batch as a special case, the latency/cost trade, and when NOT to stream |
| `.../references/the-log-and-partitioning.md` | Topic, partition, offset, key, consumer groups, acks/ISR, retention vs compaction |
| `.../references/event-time-windows-and-watermarks.md` | Three times, window types, watermarks, late data, triggers, what/where/when/how |
| `.../references/state-and-delivery-guarantees.md` | State, checkpointing, the three semantics, end-to-end exactly-once |
| `.../references/stream-processing-patterns.md` | Bounded stream-stream join, stream-table/KTable, CDC as a stream, dedup |
| `.../references/streaming-architecture-and-engines.md` | Lambda vs Kappa, replay, engine selection, consumer lag and backpressure |
| `.../SKILL.md` | Router: overview, when-to-use, quick reference, common mistakes |
| `skills/{spark,modeling,quality,pipelines,data-engineering}/SKILL.md` | Boundary edits: close forward-pointers, cede Kappa, restore streaming to the orchestrator |
| `tests/triggering/matrix*.tsv` | New cases; D6 and A8 change ground truth |

---

### Task 1: Research verification

**Files:**
- Create: `docs/superpowers/research/2026-08-07-dataflow-model-verification.md`
- Create: `docs/superpowers/research/2026-08-07-kafka-log-semantics-verification.md`
- Create: `docs/superpowers/research/2026-08-07-exactly-once-end-to-end-verification.md`
- Create: `docs/superpowers/research/2026-08-07-flink-state-and-watermarks-verification.md`
- Create: `docs/superpowers/research/2026-08-07-spark-structured-streaming-verification.md`
- Create: `docs/superpowers/research/2026-08-07-cdc-debezium-verification.md`
- Create: `docs/superpowers/research/2026-08-07-kappa-architecture-verification.md`

**Interfaces:**
- Produces: seven verification docs. Every later task cites the relevant one and must not state a claim that its verification marked unsupported or corrected.

This task is the "write the failing test first" of a content skill: the claim is verified against the source **before** any reference file asserts it. A claim that cannot be sourced does not get written.

- [ ] **Step 1: Verify the Dataflow model claims**

Source: the Dataflow Model paper (VLDB 2015) and the Streaming 101/102 articles. Claims to check, each recorded as SUPPORTED / CORRECTED / UNSUPPORTED with a quotation or citation:

1. Batch is a special case of streaming over bounded data, and a unified engine treats it that way.
2. The four questions are *what* is computed, *where* in event time, *when* results are emitted, *how* refinements relate.
3. Windowing and triggering are separable concerns.

- [ ] **Step 2: Verify the Kafka log semantics claims**

Source: Apache Kafka documentation. Claims:

1. Ordering is guaranteed **within** a partition, not across partitions of a topic.
2. Messages with the same key go to the same partition under the default partitioner.
3. `acks=0`, `acks=1`, `acks=all` mean fire-and-forget, leader-acknowledged, all in-sync-replicas-acknowledged; `acks=all` is the durability/latency trade.
4. Log compaction retains at least the last value per key, and is a different retention mode from time/size.
5. A consumer group rebalance redistributes partitions when a member joins or leaves.
6. An offset is per-partition and committing it is what makes consumption resumable and replayable.

Record the exact semantics of compaction — "retains only the last message per key" is the common simplification, and the documented behaviour is more precise about tombstones and the active segment. Write down whichever the source states.

- [ ] **Step 3: Verify the end-to-end exactly-once claim**

Sources: Kafka transactions documentation, Flink fault-tolerance documentation. Claims:

1. Exactly-once requires a replayable source, checkpointed state, and an idempotent or transactional sink — and fails at the weakest of the three.
2. Kafka transactions provide atomic writes across partitions plus offset commits.
3. Engines describe this as "effectively-once" or "exactly-once state semantics" rather than a guarantee that a message is physically delivered once.

Point 3 matters: if the sources hedge the term, the skill must hedge it the same way.

- [ ] **Step 4: Verify the Flink state and watermark claims**

Source: Apache Flink documentation. Claims:

1. Checkpointing uses distributed snapshots with barriers flowing through the dataflow, based on Chandy-Lamport.
2. Watermarks flow with the stream and assert that no further events with a timestamp below the watermark are expected.
3. State backends include an embedded RocksDB option for state larger than memory.
4. Allowed lateness lets a window emit an updated result after the watermark passes.

- [ ] **Step 5: Verify the Spark Structured Streaming claims — two drift candidates**

Source: current Apache Spark Structured Streaming documentation. Claims:

1. The default execution model is micro-batch.
2. **Drift candidate:** the status of Continuous Processing — experimental, stable, or deprecated in the current version. Record the version checked and the exact status wording.
3. **Drift candidate:** what `withWatermark` actually does to late data, and how that depends on **output mode** (append, update, complete). The common simplification is "late data is dropped"; record what the documentation states per mode.
4. Which stream-stream join types are supported and what watermark/time-bound they require.

Both drift candidates were flagged in the spec because they are the kind of claim that ages badly. If either differs from the spec's framing, the reference file follows the source and the spec is amended.

- [ ] **Step 6: Verify the CDC claims**

Source: Debezium documentation. Claims:

1. CDC reads the database transaction log (WAL, binlog) rather than polling tables.
2. Each committed change is emitted as an event, carrying the operation type.
3. The initial snapshot plus subsequent log streaming is the standard flow.
4. Delivery is at-least-once by default, so a consumer must deduplicate.

Point 4 is the link to the sink-idempotency material and must be sourced, not assumed.

- [ ] **Step 7: Verify the Kappa architecture claim**

Source: Jay Kreps' original article on questioning the Lambda architecture, plus any current secondary description. Claims:

1. Kappa's proposal is a single stream pipeline where reprocessing is done by replaying the log from an offset, replacing the separate batch layer.
2. Lambda's stated cost is maintaining two code paths that must produce the same result.
3. Whether "replaces the batch layer entirely" is the original claim or a later simplification.

- [ ] **Step 8: Commit**

```bash
git add docs/superpowers/research/2026-08-07-*.md
git commit -m "docs(streaming): verificar afirmaciones de streaming contra fuentes primarias"
```

---

### Task 2: `unbounded-data-and-when-not-to-stream.md`

**Files:**
- Create: `skills/streaming-data-engineering/references/unbounded-data-and-when-not-to-stream.md`

**Interfaces:**
- Consumes: `2026-08-07-dataflow-model-verification.md` from Task 1.
- Produces: the framing every other reference assumes — unbounded data, and the decline criterion. Later files may say "as covered in `unbounded-data-and-when-not-to-stream.md`" rather than restating it.

- [ ] **Step 1: Write the file**

Cover, in this order:

1. **The real distinction is bounded vs unbounded**, not fast vs slow. Batch processes a bounded set — the day's file, Tuesday's partition. Streaming processes a set with no defined end.
2. **Batch as a special case of streaming**, per the Dataflow verification. Explain why that framing is more useful than "two separate technologies": it explains why the same primitives — windows, aggregations — apply to both.
3. **The trade that decides which to use**: latency against cost, completeness and simplicity. Streaming buys seconds-level latency with an always-on system, harder correctness reasoning, and higher operational cost. Batch is cheaper, simpler and easier to reason about, at the cost of latency.
4. **When NOT to stream.** For anything latency-tolerant — daily reports, analytics read in the morning, loads that can wait an hour — batch is the correct default. Streaming earns its place only when low latency is a real business requirement: fraud detection, alerting, live personalisation. Defaulting to streaming without a latency requirement is the same error as defaulting to One Big Table.
5. **A worked decision**, showing the question to ask first: what is the actual latency requirement, and does event-time correctness matter. Include a concrete example where the answer is "a 15-minute batch meets the SLA at a fraction of the cost".

Cross-link the OBT default-avoidance in `../../modeling-data-engineering/references/modern-lakehouse-modeling.md` and the freshness/latency trade in `../../pipelines-architecture-data-engineering/references/serving-pipeline-output.md`.

- [ ] **Step 2: Verify size, links and sourcing**

```bash
cd skills/streaming-data-engineering/references
wc -w unbounded-data-and-when-not-to-stream.md
grep -oE '\]\([^)]+\.md\)' unbounded-data-and-when-not-to-stream.md | sed 's/^](//; s/)$//' | while read -r l; do [ -f "$(realpath -m "$l")" ] && echo "OK $l" || echo "BROKEN $l"; done
grep -c "iac-cloud-data-engineering\|streaming-data-engineering\b" unbounded-data-and-when-not-to-stream.md
```
Expected: word count between 1600 and 3500; every link `OK`; zero self-references by skill name and zero references to the non-existent iac-cloud skill.

- [ ] **Step 3: Commit**

```bash
git add skills/streaming-data-engineering/references/unbounded-data-and-when-not-to-stream.md
git commit -m "docs(streaming): add unbounded-data framing and the criterion for not streaming"
```

---

### Task 3: `the-log-and-partitioning.md`

**Files:**
- Create: `skills/streaming-data-engineering/references/the-log-and-partitioning.md`

**Interfaces:**
- Consumes: `2026-08-07-kafka-log-semantics-verification.md` from Task 1.
- Produces: the log substrate that `state-and-delivery-guarantees.md` and `streaming-architecture-and-engines.md` both depend on — replayability and compaction specifically.

- [ ] **Step 1: Write the file**

Cover:

1. **The append-only log** as the central abstraction, and its identity with the event log in `../../modeling-data-engineering/references/modeling-for-access-patterns.md`: an immutable ordered record of facts, where current state is a derived projection.
2. **Topic, partition, offset.** The partition as the atom of **two** things: parallelism and order. State the ordering guarantee exactly as the verification recorded it — order holds within a partition, never across a topic. Say plainly that a whole class of streaming bugs is assuming a total order Kafka never promised.
3. **Partition key as a design decision.** Same key routes to the same partition, which is how per-entity ordering is obtained. A hot key produces skew — the same skew as in `../../spark-data-engineering/references/joins-and-skew.md`, now at ingest.
4. **Consumer groups and rebalance**, including why a rebalance is an operational fragility worth knowing about.
5. **Durability: `acks` and ISR**, with the trade stated per the verification. This lives here rather than in an infrastructure skill because it is chosen in producer configuration, as a correctness and durability decision.
6. **Retention vs compaction**, with compaction described exactly as the source states it. Then the point that matters: a compacted topic *is* a table — the current state per key, materialised from a stream of changes. That is the stream-table duality made concrete, and `stream-processing-patterns.md` builds the KTable on it.
7. **Replayability** as the property that enables everything downstream: recovery, reprocessing, and the Kappa argument.

- [ ] **Step 2: Verify size, links and claim fidelity**

```bash
cd skills/streaming-data-engineering/references
wc -w the-log-and-partitioning.md
grep -oE '\]\([^)]+\.md\)' the-log-and-partitioning.md | sed 's/^](//; s/)$//' | while read -r l; do [ -f "$(realpath -m "$l")" ] && echo "OK $l" || echo "BROKEN $l"; done
```
Expected: 1600–3500 words, all links `OK`.

Then re-read the compaction and `acks` paragraphs against `docs/superpowers/research/2026-08-07-kafka-log-semantics-verification.md` and confirm the wording matches what the source stated rather than the common simplification. Note the check in the commit body if the two differed.

- [ ] **Step 3: Commit**

```bash
git add skills/streaming-data-engineering/references/the-log-and-partitioning.md
git commit -m "docs(streaming): add the log, partitioning and durability semantics"
```

---

### Task 4: `event-time-windows-and-watermarks.md`

**Files:**
- Create: `skills/streaming-data-engineering/references/event-time-windows-and-watermarks.md`

**Interfaces:**
- Consumes: `2026-08-07-dataflow-model-verification.md`, `2026-08-07-flink-state-and-watermarks-verification.md`, and the `withWatermark`/output-mode findings from `2026-08-07-spark-structured-streaming-verification.md`.
- Produces: the watermark concept that `state-and-delivery-guarantees.md` and `stream-processing-patterns.md` both rely on for bounding state.

This is the largest file and the conceptual core. Aim at the upper end of the range.

- [ ] **Step 1: Write the file**

Cover:

1. **Three times** — event, processing, ingestion — and that they do not coincide.
2. **Skew between event time and processing time is the normal condition**, not an anomaly: a phone with no signal, a rebalance, network congestion. Events arrive out of order and late.
3. **Why event-time is almost always what you want**: counting by processing time makes the result depend on your system's speed rather than reality, and the same input replayed gives a different answer. Event-time is correct and reproducible; the cost is waiting and handling stragglers.
4. Link this to late-arriving facts in `../../modeling-data-engineering/references/scd-and-dimension-patterns.md` and to the watermark-plus-lookback pattern in `../../pipelines-architecture-data-engineering/references/idempotency-and-backfills.md`: both are the batch-shaped version of the same problem.
5. **Window types** — tumbling, sliding/hopping, session — with what each is for. Note that session windows are the sessionisation that `../../sql-data-engineering/references/engineering-query-patterns.md` builds with `LAG` and a running sum, here native to the engine.
6. **The watermark** as an estimate of completeness, derived from the maximum event time seen minus a tolerance. State the guarantee exactly as the Flink verification recorded it.
7. **The watermark trade**, which is the senior question of the topic: aggressive closes early, lower latency, drops more late data; conservative waits, more complete, higher latency and more retained state. There is no universal answer — it is calibrated against the business requirement.
8. **What happens to data later than the watermark**: drop, allowed lateness with an updated result, or a side output. Connect the side output to the quarantine pattern in `../../quality-data-engineering/references/failure-response-policies.md`.
9. **Spark's behaviour specifically**, per the verification: what `withWatermark` does and how late data is treated **per output mode**. Do not repeat the "late data is simply dropped" simplification if the source contradicts it.
10. **Triggers and the what/where/when/how frame**, as the model that ties the file together.

- [ ] **Step 2: Verify size, links, and the two drift candidates**

```bash
cd skills/streaming-data-engineering/references
wc -w event-time-windows-and-watermarks.md
grep -oE '\]\([^)]+\.md\)' event-time-windows-and-watermarks.md | sed 's/^](//; s/)$//' | while read -r l; do [ -f "$(realpath -m "$l")" ] && echo "OK $l" || echo "BROKEN $l"; done
grep -n "output mode\|append\|update\|complete" event-time-windows-and-watermarks.md | head
```
Expected: 2500–3500 words, all links `OK`, and the late-data section explicitly distinguishing output modes rather than making a single blanket statement.

- [ ] **Step 3: Commit**

```bash
git add skills/streaming-data-engineering/references/event-time-windows-and-watermarks.md
git commit -m "docs(streaming): add event time, windows and watermarks"
```

---

### Task 5: `state-and-delivery-guarantees.md`

**Files:**
- Create: `skills/streaming-data-engineering/references/state-and-delivery-guarantees.md`

**Interfaces:**
- Consumes: `2026-08-07-exactly-once-end-to-end-verification.md` and `2026-08-07-flink-state-and-watermarks-verification.md`.
- Produces: the end-to-end exactly-once argument that `stream-processing-patterns.md` cites for sink idempotency.

- [ ] **Step 1: Write the file**

Cover:

1. **Stateful vs stateless**, and why state is the hard part: in batch it dies with the job, in streaming it is long-lived, must survive failures, and cannot grow without bound over an infinite stream — hence windows and TTLs.
2. **State backends**, including the embedded-RocksDB option per the Flink verification.
3. **Checkpointing** as fault tolerance for state: distributed snapshots with barriers, restore, and resume from the corresponding source offset. Make explicit that this is why the replayable log of `the-log-and-partitioning.md` is a precondition — without rewinding the source there is no consistent recovery.
4. **The three delivery semantics**, at-most-once, at-least-once, exactly-once, with at-least-once identified as the common default and the same guarantee webhooks give in `../../python-data-engineering/references/external-api-integration.md`.
5. **What exactly-once actually means**, using the verification's wording including any hedging the sources use. The thesis: it is not a switch, it is an end-to-end property requiring a replayable source, checkpointed state, and an idempotent or transactional sink, and it breaks at the weakest link — usually the sink. If the sink is an external API with no idempotency key, or a blind append, there is no end-to-end exactly-once no matter what the engine promises.
6. **How the sink achieves it**: transactional two-phase commit, or idempotency by key — the same `MERGE`/upsert and `ROW_NUMBER` dedup taught in `../../sql-data-engineering/references/engineering-query-patterns.md`, which remains that skill's material.
7. Close the idempotency thread explicitly: it starts in `../../python-data-engineering/references/production-patterns.md`, passes through partition overwrite in `../../pipelines-architecture-data-engineering/references/idempotency-and-backfills.md`, and here becomes the central correctness condition.

- [ ] **Step 2: Verify size, links and hedging fidelity**

```bash
cd skills/streaming-data-engineering/references
wc -w state-and-delivery-guarantees.md
grep -oE '\]\([^)]+\.md\)' state-and-delivery-guarantees.md | sed 's/^](//; s/)$//' | while read -r l; do [ -f "$(realpath -m "$l")" ] && echo "OK $l" || echo "BROKEN $l"; done
grep -n "effectively-once" state-and-delivery-guarantees.md
grep -n "exactly-once state semantics\|exactly-once" state-and-delivery-guarantees.md | head
```
Expected: 1600–3500 words, all links `OK`, **zero** hits for `effectively-once`, and the exactly-once discussion hedged the way the sources hedge it.

The `effectively-once` check is inverted deliberately. Task 1's verification found that term is **not** used in current Flink or Kafka documentation, so writing it would be attributing a hedge to sources that do not make it. Use `exactly-once state semantics` where a distinction between engine-internal state and end-to-end delivery is needed.

- [ ] **Step 3: Commit**

```bash
git add skills/streaming-data-engineering/references/state-and-delivery-guarantees.md
git commit -m "docs(streaming): add state, checkpointing and end-to-end delivery semantics"
```

---

### Task 6: `stream-processing-patterns.md`

**Files:**
- Create: `skills/streaming-data-engineering/references/stream-processing-patterns.md`

**Interfaces:**
- Consumes: `2026-08-07-cdc-debezium-verification.md`, plus the stream-stream join findings from `2026-08-07-spark-structured-streaming-verification.md`.
- Produces: the CDC material that closes the forward-pointers from `modeling` and `quality` in Task 8.

- [ ] **Step 1: Write the file**

Cover:

1. **Stateless vs stateful transformations**, with per-event schema validation named as the edge validation that `../../quality-data-engineering/references/data-contracts-and-schema-compatibility.md` governs as a contract.
2. **Stream-stream join must be time-bounded.** Matching an event from A against one from B would require retaining all of both — infinite state. A window bound is what makes the state finite. State the supported join types and required bounds per the Spark verification.
3. **Stream-table join** as the workhorse: enriching an event stream with reference data. The KTable as a compacted topic materialised as current state per key, built on `the-log-and-partitioning.md`. This is a dimensional lookup in real time, and if the dimension is an SCD Type 2, enrichment is as-of the event time — the as-of history from `../../modeling-data-engineering/references/scd-and-dimension-patterns.md`, live.
4. **CDC as a stream**, per the verification: reading the transaction log rather than polling, one event per committed change, snapshot then stream, and at-least-once delivery meaning the consumer must dedupe. Say explicitly that this closes the pointer from `modeling` and `quality`, and that the SQL that projects a change stream into a current-state table stays in `../../sql-data-engineering/references/engineering-query-patterns.md`.
5. **Deduplication with state and watermark**: keys seen within a bounded window, which is why the watermark bounds it. This is the defence against at-least-once from `state-and-delivery-guarantees.md`.
6. **How this is expressed** — Kafka Streams, ksqlDB, Flink SQL, Spark Structured Streaming with SQL — and the observation that a windowed aggregation over a stream is written almost the same as over a warehouse table, which is the unification from `unbounded-data-and-when-not-to-stream.md`.
7. Close with the unifying idea: a streaming table is a materialised view that keeps itself current. Stream-table join, KTable, projected CDC and compacted topic are the same idea — the stream is the change record, the table is its current state, and they convert into each other.

- [ ] **Step 2: Verify size and links**

```bash
cd skills/streaming-data-engineering/references
wc -w stream-processing-patterns.md
grep -oE '\]\([^)]+\.md\)' stream-processing-patterns.md | sed 's/^](//; s/)$//' | while read -r l; do [ -f "$(realpath -m "$l")" ] && echo "OK $l" || echo "BROKEN $l"; done
```
Expected: 1600–3500 words, all links `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/streaming-data-engineering/references/stream-processing-patterns.md
git commit -m "docs(streaming): add join, enrichment, CDC and dedup patterns"
```

---

### Task 7: `streaming-architecture-and-engines.md`

**Files:**
- Create: `skills/streaming-data-engineering/references/streaming-architecture-and-engines.md`

**Interfaces:**
- Consumes: `2026-08-07-kappa-architecture-verification.md` and the engine findings from Tasks 1's Flink and Spark passes.
- Produces: the Kappa/replay material that Task 8 hands `pipelines-architecture-data-engineering` a pointer to.

- [ ] **Step 1: Write the file**

Cover:

1. **Lambda**: batch layer plus speed layer plus serving layer, and its real cost — two code paths and two logics that must agree. State the original claim per the verification rather than the caricature.
2. **Kappa**: one streaming pipeline, reprocessing by replaying the log from an offset. Say explicitly what the verification found about whether "replaces the batch layer entirely" is the original claim or a later simplification.
3. **Replay is the streaming form of backfill.** This is the boundary the spec settled: replay over a log lives here, partition backfill stays in `../../pipelines-architecture-data-engineering/references/idempotency-and-backfills.md`. Link there and describe the relationship rather than re-teaching partition backfill.
4. **Engine selection** across Kafka Streams (a JVM library, not a cluster), Flink (event-at-a-time, strong event-time and large state), Spark Structured Streaming (micro-batch, unified with an existing Spark batch estate — state the Continuous Processing status per the verification, including the version checked), and Beam (the portable model the What/Where/When/How frame comes from). Decision axes: latency tolerance, state and event-time complexity, existing ecosystem, and what the team can actually operate.
5. **Operations**: consumer lag as the vital sign, backpressure, and partitions as the ceiling on consumer-group parallelism. Schema evolution governed by a registry with backward compatibility, pointing at `../../quality-data-engineering/references/data-contracts-and-schema-compatibility.md` as the owner of the contract material.
6. Close by pointing back at `unbounded-data-and-when-not-to-stream.md`: the architecture choice only arises once streaming has been justified at all.

- [ ] **Step 2: Verify size, links and the Continuous Processing claim**

```bash
cd skills/streaming-data-engineering/references
wc -w streaming-architecture-and-engines.md
grep -oE '\]\([^)]+\.md\)' streaming-architecture-and-engines.md | sed 's/^](//; s/)$//' | while read -r l; do [ -f "$(realpath -m "$l")" ] && echo "OK $l" || echo "BROKEN $l"; done
grep -n "ontinuous" streaming-architecture-and-engines.md
```
Expected: 1600–3500 words, all links `OK`, and the Continuous Processing sentence naming the Spark version it was checked against.

- [ ] **Step 3: Commit**

```bash
git add skills/streaming-data-engineering/references/streaming-architecture-and-engines.md
git commit -m "docs(streaming): add Lambda vs Kappa, engine selection and operations"
```

---

### Task 8: `SKILL.md` and the boundary edits

**Files:**
- Create: `skills/streaming-data-engineering/SKILL.md`
- Modify: `skills/spark-data-engineering/SKILL.md` — forward-pointer and description boundary
- Modify: `skills/modeling-data-engineering/SKILL.md` — forward-pointer and description boundary
- Modify: `skills/quality-data-engineering/SKILL.md` — forward-pointer and description boundary
- Modify: `skills/pipelines-architecture-data-engineering/SKILL.md` — cede Kappa/replay, keep partition backfill
- Modify: `skills/data-engineering/SKILL.md` — restore streaming to the domain list, description and body

**Interfaces:**
- Consumes: all six reference files from Tasks 2–7.
- Produces: the descriptions Task 9 measures.

- [ ] **Step 1: Write `SKILL.md`**

Structure matches the other seven domain skills: `## Overview`, `## When to use`, `## Quick reference`, `## Common mistakes`.

Frontmatter description — this exact text, which applies all three measured patterns and must be checked against the 1024 cap:

```
description: Streaming and unbounded-data guidance — the append-only log and partitioning (topics, offsets, partition keys, consumer groups, acks/ISR, retention vs compaction), event time versus processing time, windows and watermarks, state and checkpointing, delivery semantics and end-to-end exactly-once, bounded stream-stream and stream-table joins, CDC as a stream, and Lambda versus Kappa with replay. Use when designing or reviewing a streaming pipeline, choosing between streaming and batch, picking a partition key, reasoning about late or out-of-order events, diagnosing a consumer falling behind, or when replaying a stream produced duplicates. Still applies when a general debugging or design skill also fits — that one supplies the method, this one the streaming-domain knowledge. Not for cluster provisioning, sizing or managed-service choice, which is decided in infrastructure code and has no skill in this suite yet, or for Spark tuning unrelated to streaming (see spark-data-engineering).
```

Note the jargon-free triggers deliberately included alongside the technical ones — "a consumer falling behind", "replaying a stream produced duplicates", "late or out-of-order events". The measured lesson is that real diagnostic prompts do not use domain vocabulary.

`## Overview` states the unbounded-data frame in two or three sentences. `## When to use` gives concrete triggers and the boundaries. `## Quick reference` is a table mapping a situation to the reference file that covers it — one row per reference file, all six linked. `## Common mistakes` covers at minimum: defaulting to streaming without a latency requirement; assuming total order across partitions; treating exactly-once as an engine switch; and an unbounded stream-stream join.

- [ ] **Step 2: Verify the frontmatter parses and fits**

```bash
cd /home/leonardo-garcia/dev/data-engineering-skills
awk '/^---$/{c++; next} c==1{print} c==2{exit}' skills/streaming-data-engineering/SKILL.md | wc -c
claude plugin validate .
```
Expected: character count ≤ 1024, and `Validation passed`. If it exceeds the cap, cut from the coverage inventory at the start of the description, never from the triggers or the boundary clause — the inventory is the part the body already carries.

- [ ] **Step 3: Close the three forward-pointers**

In `spark-data-engineering/SKILL.md`, the line currently reading `- Not for Structured Streaming (watermarks, exactly-once semantics) — a streaming skill is planned for this suite but does not exist yet, so answer directly rather than looking for one` becomes a real pointer to `streaming-data-engineering`. Make the same change in `modeling-data-engineering/SKILL.md` and `quality-data-engineering/SKILL.md` for their CDC lines, and in the frontmatter descriptions of all three where they currently say the skill does not exist.

Also update `modeling-data-engineering/references/modeling-for-access-patterns.md` and `sql-data-engineering/references/engineering-query-patterns.md`, which both defer CDC to a future skill.

- [ ] **Step 4: Cede Kappa in `pipelines-architecture-data-engineering`**

Add a boundary line to its body stating that replay over a log belongs to `streaming-data-engineering`, while partition backfill stays. Its description keeps "structural idempotency and backfills" — the split is between backfilling partitions and replaying a log, and only the body needs to say so. Do not remove backfill from its description; that would break cases D1 and P5, both currently passing.

- [ ] **Step 5: Restore streaming to the orchestrator**

In `data-engineering/SKILL.md`, add `streaming-data-engineering` back to the domain list in both the description and the body, and remove the sentence saying streaming has no skill yet. Leave the IaC/cloud caveat in place — that skill still does not exist.

- [ ] **Step 6: Verify no dangling names and everything links**

```bash
cd /home/leonardo-garcia/dev/data-engineering-skills
grep -rn "iac-cloud-data-engineering" skills/ | grep -v "no skill\|does not exist\|not exist yet\|in scope for the suite"
grep -rn "a streaming skill is planned\|streaming skill.*does not exist" skills/
bad=0; for d in skills/*/; do while read -r l; do [ -z "$l" ] && continue; t=$(cd "$d" && realpath -m "$l"); [ -f "$t" ] || { echo "BROKEN $d -> $l"; bad=1; }; done < <(grep -oE '\]\([^)]+\.md\)' "$d/SKILL.md" | sed 's/^](//; s/)$//'); done; [ $bad -eq 0 ] && echo "links OK"
for d in skills/*/; do n=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$d/SKILL.md" | wc -c); [ "$n" -gt 1024 ] && echo "OVER $d $n"; done; echo "cap checked"
claude plugin validate .
```
Expected: the first grep returns nothing bare — every remaining `iac-cloud` mention is qualified as non-existent; the second returns nothing at all, since no skill should still claim streaming is unwritten; `links OK`; no `OVER` lines; `Validation passed`.

- [ ] **Step 7: Verify the suite loads with nine skills**

```bash
cd /tmp && claude --model haiku -p "List the exact names of every skill available to you containing 'data-engineering', one per line, nothing else. Do not use tools."
```
Expected: nine names including `dataforge:streaming-data-engineering`.

- [ ] **Step 8: Commit**

```bash
cd /home/leonardo-garcia/dev/data-engineering-skills
git add skills/
git commit -m "feat(streaming): add streaming-data-engineering and close its forward-pointers"
```

---

### Task 9: Behavioural measurement

**Files:**
- Modify: `tests/triggering/matrix.tsv` — new positive and discriminator cases; D6 ground truth
- Modify: `tests/triggering/matrix-adversarial.tsv` — new no-jargon case; A8 ground truth
- Create: `tests/triggering/baselines/2026-08-07-streaming-routing.md`

**Interfaces:**
- Consumes: the delivered skill and the edited descriptions from Task 8.

The skill is not delivered until it routes. This is the acceptance gate.

- [ ] **Step 1: Change the two ground truths that this skill invalidates**

`D6` in `matrix.tsv` currently expects `NONE` — Spark Structured Streaming with backpressure, which had nowhere to route. Its `EXPECTED` becomes `streaming-data-engineering`. `A8` in `matrix-adversarial.tsv` currently expects `NONE` — Kafka exactly-once into Delta. Its `EXPECTED` becomes `streaming-data-engineering`.

Both are recorded in `tests/triggering/baselines/` with their pre-streaming behaviour, and D6 is the case that proves the `spark` boundary finally works.

- [ ] **Step 2: Add new cases**

Append to `matrix.tsv` a positive and a discriminator, and to `matrix-adversarial.tsv` a jargon-free case. Tab-separated, matching the existing columns:

```
P9	positive	streaming-data-engineering	Necesito procesar eventos de Kafka y agregar por ventanas de 5 minutos. ¿Cómo manejo los que llegan tarde?
D8	discriminator	streaming-data-engineering	Mi job de Spark lee de Kafka y quiero exactly-once end-to-end hacia Delta. ¿Alcanza con el checkpoint?
```
```
A13	no-vocab	streaming-data-engineering	El tablero en vivo muestra menos ventas de las que hubo, y si lo miro una hora después el número cambió.
```

`D8` is the discriminator that matters: it names Spark, so it tests whether the new boundary sends it to streaming rather than to `spark-data-engineering`. `A13` describes a watermark/late-data problem with no streaming vocabulary at all.

- [ ] **Step 3: Run the affected cases with reps**

```bash
cd tests/triggering
{ head -1 matrix.tsv
  grep -E '^(D6|P9|D8|P3|P5|D1|P4|D7|P6|D2|P8)\b' matrix.tsv
  grep -E '^(A8|A13|A4|A5|A1|A3|A7|A10)\b' matrix-adversarial.tsv
} > /tmp/stream-cases.tsv
awk -F'\t' 'NR>1{n++} END{print n" cases (expect 19)"}' /tmp/stream-cases.tsv
./run-matrix.sh -f /tmp/stream-cases.tsv -m opus -a with -r 3 -j 1 -o results/streaming-delivery
./rescore.sh results/streaming-delivery matrix.tsv matrix-adversarial.tsv
```
Expected: the three new cases and `D6`/`A8` route to `streaming-data-engineering`; the regression cases for every description touched in Task 8 — `spark` (P3, A4, A5), `modeling` (P4, D7, A3, A7), `quality` (P6, D2, A1), `pipelines` (P5, D1), and the orchestrator (P8, A10) — hold their previous verdicts.

Score with `rescore.sh`, never the live verdict: the live one reads position 1 only, and a correct session here often chains a superpowers process skill first.

- [ ] **Step 4: If a case fails, fix the description and re-measure — do not lower the expectation**

A failing new case means the description does not reach that prompt. Adjust the description using the measured patterns, and re-run. A failing *regression* case means a Task 8 edit broke a neighbour, which is the more serious outcome and must be fixed before delivery.

Do not change a case's `EXPECTED` to match observed behaviour. That converts a measurement into a tautology.

This is not in tension with Step 1. There, `D6` and `A8` change because the world changed — a skill that did not exist now does, so what those prompts *should* reach is different, and the change is decided before any measurement is run. Here, the prohibition is against changing an expectation *after* seeing a result you did not like. The test is timing and reason: a ground truth may change because the domain changed, never because the run disagreed with it.

- [ ] **Step 5: Write the baseline digest**

Record in `tests/triggering/baselines/2026-08-07-streaming-routing.md`: the `rescore.sh` output verbatim, the two changed ground truths with their pre-streaming behaviour, and the regression set with its verdicts. State the model and rep count.

- [ ] **Step 6: Commit**

```bash
git add tests/triggering/
git commit -m "test(triggering): measure streaming routing and re-verify the touched boundaries"
```

---

## What invalidates this delivery

- Any claim in a reference file that its verification doc marked UNSUPPORTED, or that states the simplification where the source stated something more precise.
- A frontmatter over 1024 characters, or one that fails `claude plugin validate`.
- Any bare mention of a skill name that does not exist.
- A new case that does not route, or a regression case that changed verdict, with the expectation edited to match rather than the description fixed.
- Measurement at one rep. A 1-in-5 event is invisible at n=1, which this repo has already paid to learn.
