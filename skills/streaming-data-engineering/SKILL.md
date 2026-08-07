---
name: streaming-data-engineering
description: Streaming and unbounded-data guidance — the append-only log and partitioning (topics, offsets, partition keys, acks/ISR, retention vs compaction), event time versus processing time, windows and watermarks, state and checkpointing, delivery semantics and exactly-once, bounded stream-stream and stream-table joins, CDC as a stream, and Lambda versus Kappa with replay. Use when designing or reviewing a streaming pipeline, choosing between streaming and batch, picking a partition key, reasoning about late or out-of-order events, diagnosing a consumer falling behind, or when replaying a stream produced duplicates. Still applies when a general debugging or design skill also fits — that one supplies the method, this one the streaming-domain knowledge. Not for cluster provisioning, sizing or managed-service choice, which is decided in infrastructure code and has no skill in this suite yet, or for Spark tuning unrelated to streaming (see spark-data-engineering).
---

# Streaming Data Engineering

## Overview

Streaming is not a faster batch — it's a different relationship with the *end* of the data: a batch job processes a set with a defined end, a streaming job processes one that never finishes and periodically decides what a "complete enough" answer looks like right now. That single distinction — bounded vs. unbounded, not fast vs. slow — is what every other decision in this skill (windowing, watermarks, delivery semantics, join design) is downstream of, and it's why the first question in any streaming design is always the latency requirement, not the engine.

## When to use

- Designing or reviewing a streaming pipeline, or deciding whether a workload should stream at all instead of running on a schedule
- Choosing between streaming and batch for a stated (or unstated) latency requirement
- Picking a partition key, or diagnosing skew caused by one
- Reasoning about events that arrive late or out of order, or setting a watermark delay
- A consumer group is falling behind, rebalancing too often, or a rebalance is producing duplicate processing
- Evaluating whether a pipeline's "exactly-once" claim actually holds end to end
- Designing a stream-stream or stream-table join, or treating CDC as a change stream
- Choosing between Lambda and Kappa, or between Kafka Streams, Flink, Spark Structured Streaming, and Beam
- Not for cluster provisioning, sizing, or managed-service choice — that's infrastructure code, and has no skill in this suite yet
- Not for Spark tuning unrelated to streaming (shuffle, joins, memory, AQE) — see `spark-data-engineering`
- Not for partition-level batch backfill mechanics — see `pipelines-architecture-data-engineering`

## Quick reference

| Situation | Reach for | Reference |
|---|---|---|
| Deciding whether a workload should stream at all | Bounded vs. unbounded framing; ask for the actual latency number before naming an architecture | [unbounded-data-and-when-not-to-stream.md](references/unbounded-data-and-when-not-to-stream.md) |
| Choosing or auditing a partition key; reasoning about ordering, `acks`, retention vs. compaction | The partition as the unit of ordering and parallelism; Kafka's per-partition (not per-topic) ordering guarantee | [the-log-and-partitioning.md](references/the-log-and-partitioning.md) |
| Events arriving late or out of order; setting a window or watermark delay | Event time vs. processing time; a watermark as a completeness estimate, not a fact | [event-time-windows-and-watermarks.md](references/event-time-windows-and-watermarks.md) |
| A crash needs recovering from; an "exactly-once" claim needs checking | Checkpointing and state backends; the three-link chain (source, state, sink) exactly-once actually requires | [state-and-delivery-guarantees.md](references/state-and-delivery-guarantees.md) |
| Joining two streams, enriching a stream against reference data, or treating CDC as a stream | Time-bounded stream-stream joins; stream-table joins as a materialized-view lookup; CDC as a typed, ordered change log | [stream-processing-patterns.md](references/stream-processing-patterns.md) |
| Choosing an engine, or deciding between Lambda and Kappa | Kappa's actual scope (removes the second reprocessing path, not batch as a category); the four-engine trade-offs; consumer lag as the vital sign | [streaming-architecture-and-engines.md](references/streaming-architecture-and-engines.md) |

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Defaulting to streaming without a stated latency requirement | Streaming is a deliberate trade of cost, operational burden, and reasoning difficulty for latency — not a strictly better version of batch | Ask for the actual number before naming an architecture; see [unbounded-data-and-when-not-to-stream.md](references/unbounded-data-and-when-not-to-stream.md) |
| Assuming order holds across a whole topic, not just within one partition | Kafka's ordering guarantee is scoped to a single partition; two different partitions carry no relative ordering promise at all | Key records that must stay ordered relative to each other onto the same partition, or design consumers to tolerate cross-partition interleaving; see [the-log-and-partitioning.md](references/the-log-and-partitioning.md) |
| Treating "exactly-once" as a single processing-framework setting | An engine's checkpointing only guarantees exactly-once *state* semantics; end-to-end delivery also needs a replayable source and a cooperating (idempotent or transactional) sink | Check all three links — source, state, sink — before calling a pipeline exactly-once; see [state-and-delivery-guarantees.md](references/state-and-delivery-guarantees.md) |
| Joining two streams with no watermark or time bound on either side | The join buffer has to retain every unmatched event from both sides indefinitely — infinite state on an unbounded input | Bound the join with a watermark and time constraint on at least the side the join type requires; see [stream-processing-patterns.md](references/stream-processing-patterns.md) |
| Reading `acks=all` as "every replica acknowledged" | It means every replica in the *current* in-sync set acknowledged, which can be smaller than the full replica set if followers have failed | Pair `acks=all` with `min.insync.replicas` if the durability floor must not erode as the ISR shrinks; see [the-log-and-partitioning.md](references/the-log-and-partitioning.md) |
| Treating "Kappa replaces the batch layer entirely" as the original claim | The word "replace" never appears in Kreps' article, which explicitly preserves batch/HDFS for other uses and frames Kappa as an alternative, not a categorical substitute | Cite the corrected scope: Kappa removes the second code path needed for *reprocessing*, not batch processing as a category; see [streaming-architecture-and-engines.md](references/streaming-architecture-and-engines.md) |
