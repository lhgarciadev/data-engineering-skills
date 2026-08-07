# Unbounded Data, and When Not to Stream

Every other file in this skill assumes the frame this one builds: streaming is not a faster batch. It is a different relationship with the *end* of the data. Get that relationship wrong and every downstream decision — windowing, watermarks, delivery semantics — gets reasoned about on the wrong axis.

## The real distinction is bounded vs unbounded, not fast vs slow

A batch job processes a set with a defined end: Tuesday's partition, the file that landed at 2 a.m., the rows where `event_date = '2026-08-06'`. The job knows, by construction, when it has seen everything it is going to see. It runs, finishes, and the output is complete.

A streaming job processes a set with no defined end. Events keep arriving for as long as the business keeps operating — there is no `WHERE` clause that captures "all of it," because "all of it" doesn't exist yet and never will while the source stays live. The job doesn't finish; it runs continuously and periodically decides what a "complete enough" answer looks like at any given moment.

That's the distinction that matters: **bounded vs unbounded**, not "batch is slow, streaming is fast." Latency is a consequence of the choice, not the choice itself. A batch job can run every five minutes and look almost real-time from a dashboard's perspective; a streaming job can be misconfigured to buffer for twenty minutes and look slower than the batch job it was meant to replace. Speed is a tuning knob on both sides. Boundedness is not — it's a property of the data source, and it decides which whole category of problem you're solving: a query against a set you can already see in full, or a continuously updated approximation of a set you'll never see in full.

## What the model says about batch and streaming — not the popular paraphrase

A common shorthand for this topic is "batch is a special case of streaming." It's a tidy sentence, and it's not what the paper that unified this area actually argues.

Akidau et al.'s "The Dataflow Model" (VLDB 2015) is explicit that it avoids exactly that framing. On bounded and unbounded data versus the streaming/batch label:

> "When describing infinite/finite data sets, we prefer the terms unbounded/bounded over streaming/batch, because the latter terms carry with them an implication of the use of a specific type of execution engine. In reality, unbounded datasets have been processed using repeated runs of batch systems since their conception, and well-designed streaming systems are perfectly capable of processing bounded data. From the perspective of the model, the distinction of streaming or batch is largely irrelevant, and we thus reserve those terms exclusively for describing runtime execution engines." (Akidau et al. 2015, p. 1794)

Two things fall out of that. First, "streaming" and "batch" describe *engines*, not the shape of the data. Batch engines have run unbounded workloads for decades — that's what a nightly job that never gets decommissioned is. Second, and this is the part worth sitting with: the paper isn't saying either category subsumes the other. It's saying the distinction stops mattering once you have a model — windows, triggers, watermarks — that describes bounded and unbounded data with the same primitives. The paper states its own goal this way:

> "Separates the logical notion of data processing from the underlying physical implementation, allowing the choice of batch, micro-batch, or streaming engine to become one of simply correctness, latency, and cost." (Akidau et al. 2015, p. 1793)

That's the actual unification: not a subset relationship, but a shared vocabulary that makes engine choice a tuning decision instead of a rewrite. This is also why the same operations — grouping, windowing, aggregating — apply whether the input is a fixed file or a live topic; the model was built so that "how much of the data is here right now" doesn't change what operations mean, only how often results get emitted.

If you want a directional claim instead of "irrelevant," the closest one on record comes from a different source — Akidau's own blog post, not the peer-reviewed paper — and it points the *other* way from the popular paraphrase: "well-designed streaming systems actually provide a strict superset of batch functionality" (Akidau, "Streaming 101," O'Reilly Radar, 2015). Superset of A over B is the mirror of "B is a special case of A" — so if you insist on a subset relationship at all, the sourced version has streaming as the superset and batch as the special case, not the reverse. But treat that as one author's blog-post framing, not the paper's own position; the paper's actual position is the "largely irrelevant" line above, and that's the one to carry forward. The practical takeaway for this skill is simpler than either framing: don't reach for streaming because it sounds architecturally superior. It isn't a promotion from batch. It's a different tool with a different cost profile, covered next.

## The trade that decides: latency against cost, completeness, and reasoning difficulty

If boundedness is the technical distinction, the trade that actually decides which one to build is economic and cognitive, not technical.

**Streaming buys latency.** A well-run streaming pipeline can turn an event into a materialized result in single-digit seconds, sometimes less. That's the entire product it's selling, and for the handful of cases that need it — fraud scoring at swipe time, an alert that has to fire before the outage gets worse, a personalization signal that has to reflect what a user clicked ten seconds ago — nothing else gets there.

That latency is not free. It costs you, concretely:

- **An always-on system.** A batch job that fails at 2 a.m. gets retried at 2:05 or waits for the next scheduled run; nobody notices for hours. A streaming job that fails is down *now*, and every second it's down is a second of unprocessed events piling up somewhere, waiting to be replayed once it's back — assuming the source retains them long enough. There's no "off" state that isn't an incident.
- **Harder correctness reasoning.** Batch correctness is bounded and mostly synchronous to reason about: the input set is fixed, so "did we process everything" has a yes/no answer once the job exits. Streaming correctness has to account for events arriving out of order, arriving late, arriving twice, and a result that was already emitted needing to be revised once more data shows up. None of that is exotic — it's the entire reason windowing, watermarks, and delivery semantics exist as topics — but it means every streaming pipeline is reasoning about a moving target that a batch pipeline never has to face.
- **Higher operational cost.** A streaming cluster (or managed service) is provisioned to run continuously, sized for its steady-state load plus headroom for spikes, and it costs money every hour whether or not there's meaningful volume flowing through it at 3 a.m. A batch job costs compute for the minutes it runs and nothing the rest of the day.

**Batch buys the opposite.** It's cheaper because compute is transient. It's simpler because the input is a closed, inspectable set — you can `SELECT COUNT(*)` it, rerun it, diff two runs of it, and reason about it the way you reason about any deterministic function of a fixed input. And it's easier to operate because failure has slack: a failed batch run is a problem you have hours to fix, not one that's actively getting worse while you fix it.

None of this makes batch inferior. It makes batch the cheaper, simpler, easier-to-reason-about default that gives up something specific — latency — in exchange. Whether that's a good trade depends entirely on whether anything downstream actually needs the latency batch gives up. Which is the question the next section makes the reader answer before reaching for a streaming platform.

## When NOT to stream

This is the decision that should happen before any engine gets chosen, and it's the one most commonly skipped.

For anything latency-tolerant, batch is the correct default — not the fallback option, the *correct* one:

- Daily and weekly reports read by humans the next morning.
- Analytics dashboards refreshed on a schedule that a person checks a few times a day.
- Loads that feed a model retrain, a monthly reconciliation, or any downstream process that itself runs on a schedule and therefore can't consume fresher data any faster than it already does.
- Anything where the consumer's own review or decision cadence is measured in hours, not seconds — there's no latency requirement to satisfy because nothing on the other end is waiting in real time.

Streaming earns its place only when low latency is an actual, named business requirement, not an assumed one: fraud detection that has to block a transaction before it clears, operational alerting that has to fire while there's still time to act, live personalization that has to reflect the last few seconds of behavior, or a monitoring signal feeding an automated response system. In each of those, the value of the answer decays measurably with delay — a fraud flag raised after the charge settles isn't a fraud flag, it's a postmortem note.

Defaulting to streaming without a latency requirement to justify it is the same category of error as defaulting to One Big Table without a fixed, known access pattern to justify it: reaching for the pattern that removes a design step — joins in one case, latency engineering in the other — instead of doing the analysis that tells you whether you actually need what it costs you. [`modern-lakehouse-modeling.md`](../../modeling-data-engineering/references/modern-lakehouse-modeling.md) makes the OBT version of this argument explicit: OBT is a deliberate trade for a stable, already-known query pattern, and reaching for it "because joins feel inconvenient" is the lazy-default version of a choice that should be earned. Streaming needs the same discipline: it's a deliberate trade for a real latency requirement, and reaching for it because "real-time" sounds like the more sophisticated answer is the same laziness wearing different clothes.

The reader who has internalized this file should be able to say, to a stakeholder who asked for "real-time" by reflex: *this does not need streaming; a 15-minute batch meets the SLA at a fraction of the cost and complexity.* That sentence should be defensible on all four axes at once — latency (the SLA is minutes, not seconds, so a scheduled job clears it with room to spare), cost (transient compute beats an always-on cluster provisioned for a load that arrives in bursts), operational burden (a failed batch run is a ticket, not an incident), and reasoning difficulty (a bounded run over a known partition is trivial to test, rerun, and audit compared to a live pipeline that has to reason about lateness and revision). Declining streaming for a stated, defensible reason is not caution — it's the senior call in this entire topic, and the rest of this skill exists to teach the mechanics for the cases where the answer genuinely is the other way.

## A worked decision

Start every "should this stream" conversation with one question, asked before any technology gets named: **what is the actual latency requirement, and does event-time correctness matter?**

"Real time" is the word that derails this question almost every time it's asked casually. Stakeholders say it to mean "current," "not stale," or "sooner than the thing we have now" — almost never "within milliseconds of the event occurring." Taking "real time" at face value and assuming millisecond latency is the single most common error in this decision: it skips straight to architecture before anyone has stated a number.

Walk through it with a concrete case: a retail analytics team wants "real-time inventory visibility" across stores, replacing a nightly batch reconciliation that currently runs at 1 a.m.

- **Ask for the number, not the adjective.** Push past "real-time" to an actual SLA. In this case, the honest answer, once someone states it, turns out to be: store managers check inventory dashboards a handful of times during their shift, and the business decision that depends on freshness — reordering stock, flagging a shortfall — happens on roughly a 15–30 minute cadence, not a per-transaction one. Nobody is making a decision between one inventory read and the next second's read.
- **Ask whether event-time correctness matters**, independent of latency. This is a separate axis: even if the SLA were tight, would out-of-order arrivals or late-arriving corrections change the *result*, not just its timing? For inventory counts, a sale recorded five minutes late still needs to land in the right store's daily total — but a bounded batch job that reruns over a window a few minutes wider than the expected delay handles that correctly without needing watermarks or a live engine at all. Event-time correctness is a real concern here, but it's a concern that a batch job's window size can absorb, not one that requires a streaming engine to solve.
- **Price both options against the actual requirement.** A 15-minute micro-batch — a scheduled job pulling incremental changes and upserting into the inventory table — clears the 15–30 minute SLA with margin, costs compute for a few minutes every 15, and is a job any engineer on the team can rerun and debug like any other pipeline. A streaming pipeline (Kafka topic per store, a stream processor doing the aggregation, a live-updated serving store) would also clear the SLA, but it adds an always-on cluster, a schema registry, watermark and late-data handling for a correctness need the batch window already covers, and an on-call burden for a requirement that was never actually sub-minute.

The answer here is unambiguous once the number is on the table: **a 15-minute batch meets the SLA at a fraction of the cost and complexity.** That's not a compromise — it's the correct engineering answer to the stated requirement, and it's only reachable because the question was asked before the architecture was chosen.

Contrast that with a fraud-detection case on the same retail platform: a stolen card should be blocked before the authorization completes, which is a latency budget measured in hundreds of milliseconds, decided by a payment processor's timeout, not by a human's dashboard-refresh habit. There, the same first question — what's the actual number — produces the opposite answer, and streaming is the only architecture that clears it. The method doesn't change between the two cases. Only the number does. That's the whole discipline: ask for the number before choosing the engine, and let the number decide.

This is also the same trade that shows up one layer downstream, once a result has been computed and needs to be served: materializing a lookup store on an hourly batch means reads are millisecond-fast but the data can be up to an hour stale, and only a real sub-second freshness requirement justifies feeding that store from a stream instead — see the freshness/latency trade-off in [`serving-pipeline-output.md`](../../pipelines-architecture-data-engineering/references/serving-pipeline-output.md), which makes the identical argument against defaulting to "real-time" at the serving layer. The question is the same question, asked again at a different point in the pipeline: what does the consumer actually need, and what does refusing to guess at "real-time" save you.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Treating "batch is a special case of streaming" as a quotable claim from the Dataflow paper | The paper explicitly declines that framing and calls the streaming/batch distinction "largely irrelevant" from the model's perspective (p. 1794) — the sentence is a later popularization, not the source | Cite the paper's actual position: a shared model makes engine choice a matter of correctness, latency, and cost, not a subset relationship |
| Assuming "real-time" means milliseconds | Stakeholders use "real-time" to mean "not stale," which is almost always a minutes-scale requirement, not a milliseconds one | Ask for the actual number and the actual decision cadence before naming an architecture |
| Choosing streaming because it sounds more advanced | Streaming is a deliberate trade of cost, operational burden, and reasoning difficulty for latency — not a strictly better version of batch | Default to batch; require a stated, decaying-value latency requirement before reaching for streaming |
| Skipping the event-time correctness question because latency is already tight | A tight SLA and correct handling of late/out-of-order events are separate problems; conflating them can lead to over-building (a full streaming engine) when a wider batch window would have solved the correctness half alone | Evaluate latency and event-time correctness as two separate axes, not one bundled decision |
| Building the streaming pipeline first and asking about the SLA later | Once the always-on system exists, sunk cost makes it much harder to admit a batch job would have sufficed | Ask "what is the actual latency requirement" before any engine gets chosen — the same discipline this file's worked decision walks through |
