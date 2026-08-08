# Statefulness and the One-Way Door

Every other file in this skill assumes the frame this one builds: **data infrastructure is stateful infrastructure**. The thing you are provisioning is not a replaceable copy of a template — it is the only place the accumulated history lives. Get that wrong and every downstream decision, from which managed service to adopt to how you write the infrastructure code, gets reasoned about on the wrong axis: as a sizing problem, when it is a reversibility problem.

## Cattle, pets, and the case the analogy was never written for

The dominant metaphor in cloud operations is cattle versus pets. A pet is a named machine you nurse back to health; cattle are interchangeable instances you replace without ceremony when one misbehaves. The whole discipline that grew around it — immutable infrastructure, blue/green deploys, autoscaling groups, "if it's broken, terminate it and let the group replace it" — is excellent advice, and it works because of a property that is usually left unstated: **an application server holds nothing that isn't recoverable from somewhere else.** Its configuration is in a repository, its code is in an artifact store, its session state is in a cache it doesn't own. Destroy it and you have lost a few minutes of provisioning time.

Now apply the same move to a warehouse holding several years of transactional history, a topic whose retention window is the only copy of the last day of events, an object store whose prefixes are the raw landing zone every reprocessing run reads from, or the state backend that records what the infrastructure code believes exists. In every one of those, **the thing of value is the accumulated state, and it is not recoverable from the configuration that created it.** The Terraform that provisions a warehouse describes an empty warehouse. Re-running it perfectly gives you an empty warehouse.

That is where the analogy stops applying, and it stops applying quietly. Most cloud guidance you will read — including a great deal of good guidance — was written for the cattle case and never states the assumption, so it reads as universal. "Just recreate it" is sound advice for a load balancer and a data-loss event for a bucket with history. Treat every piece of generic cloud advice as carrying an unwritten precondition: *this resource holds nothing.* When it does hold something, the advice needs re-deriving, not applying.

Two clarifications, because the line is not "does it store bytes":

- **Statefulness is about irreplaceability, not persistence.** A read replica persists bytes and is still cattle — it is rebuildable from a source you control. A landing bucket that receives from a third party you cannot ask to resend is stateful even if each individual object is small.
- **The resource identity can be stateful even when the storage isn't.** A topic name, a bucket name, a catalog identifier, a schema-of-record — these are the addresses your consumers hard-coded. Changing one is a migration for everyone downstream, whether or not a byte moved.

## The reversibility ladder

The practical consequence of statefulness is that decisions in this domain are not equally undoable, and the differences are large enough to be the primary ordering principle for the design. Rank every decision on how expensive it is to reverse. Ordered from cheapest to most expensive to undo:

1. **Compute engine and cluster shape.** Node type, worker count, provisioned versus serverless, even which query engine runs the job. Compute holds nothing between runs, so reversing means pointing a different engine at the same data and re-running. Real work, bounded work.
2. **Orchestrator and scheduling layer.** Migrating DAGs between orchestrators is mechanical and tedious rather than risky — the pipelines are code you own, and the runs they produced are already in storage.
3. **File format and compression.** Reversing means rewriting every byte of the corpus: reading it all, transcoding it, writing it all back, and cutting consumers over. The cost scales with everything you have ever stored, and it grows every day.
4. **Table format and catalog.** More expensive than file format, because engines and access-control policies bind to the catalog, not just to the files. The catalog is the name through which everything resolves, and re-pointing it is a coordinated change across every reader. [`modern-lakehouse-modeling.md`](../../modeling-data-engineering/references/modern-lakehouse-modeling.md) covers what the layering above the format is doing and why the dimensional model lives at the top of it; this skill's concern is only that the format and catalog choice sit near the bottom of the ladder.
5. **The storage service holding the history.** Near-irreversible, and for an arithmetic reason developed in the next-but-one section: leaving means paying to move every byte you have accumulated, and that quantity only ever grows.
6. **The schema-of-record your consumers coupled to.** Also near-irreversible, but for a different reason — you do not control the other end. Every dashboard, downstream job, notebook and external partner that reads a column has made your schema part of their code. [`data-contracts-and-schema-compatibility.md`](../../quality-data-engineering/references/data-contracts-and-schema-compatibility.md) covers what compatibility actually means here and how to make the coupling explicit; the point for this file is that a rung you cannot unilaterally change belongs at the bottom of the ladder, not the top.

The discipline that follows: **make decisions top-down in reversibility, not top-down in the architecture diagram.** The diagram invites you to start where the boxes are biggest and the drawing is most fun — the processing layer, the engine, the orchestration. That is precisely the top of this ladder, where you can afford to be wrong. Spend the design budget, the review time and the prototyping at the bottom rungs, where a mistake is a program rather than a ticket.

The bottom rungs are **one-way doors**: decisions you can technically reverse but will not, because the cost of reversing exceeds whatever the reversal would buy. The rest of this file is about pricing those doors before you walk through them.

## Migration cost is a selection criterion, not a consequence

Because the bottom rungs are one-way, the question *"how would we leave this?"* has to be asked **before** adoption, not discovered afterwards. Most teams ask it for the first time on the day they want to leave, which is the day the answer is worst and the leverage is zero.

Asked before adoption, it has a concrete three-part form:

- **What is the export path?** Is there a documented bulk export that produces files, or is the only route out reading through the query API a page at a time? "You can always query it out" is not an export path; it is a rewrite of your extraction layer under time pressure.
- **What does the exit cost, in shape?** Not a figure — a shape. Reading the corpus costs whatever the engine's read model charges (per-GB-scanned, or provisioned capacity per unit of time). Enumerating and fetching objects costs per-request. Moving the bytes out of the provider costs egress, charged per GB transferred. Rewriting into the new home costs compute time. Naming the four shapes is enough to know whether the exit is an afternoon or a quarter; the amounts belong on a spreadsheet with today's date on it, not in a design decision.
- **Does the data leave in an open format or a proprietary one?** This is the difference between an exit that produces files another engine can read directly and an exit that produces a dump you must re-ingest and re-model. An open table format on object storage keeps the door two-way for the *format* rung even when the *service* rung is one-way — the files stay readable by an engine you do not buy from the same vendor. That is the single highest-leverage thing you can do to keep the bottom of the ladder cheaper than it would otherwise be.

Note what this is not. It is not an argument for always choosing the most portable option. A proprietary service that fits the workload can be entirely the right call, and portability has a real price in features you decline to use. The failure mode is not walking through an expensive door — it is walking through it without pricing it, and then discovering the price at the moment you have the least room to negotiate. **A migration cost that was named, priced in shape, and accepted is a decision. The same cost discovered later is an incident.**

## Data gravity: egress is arithmetic, not conspiracy

The reason the storage rung sits near the bottom of the ladder is a billing shape, and it is worth stating precisely because the popular version of it is a story about vendor malice.

Object storage bills **storage, requests and data transfer as separate charges** — among others. Resist the temptation to say "the cost breaks into three parts," because no provider uses that taxonomy. Amazon S3's own pricing page enumerates a longer list of cost components than three. Google Cloud Storage names three, but they are not these three — operation charges live inside a broader "data processing" component alongside retrieval fees and inter-region replication. Azure Blob Storage bills a list of meters with a separate invoice line per meter, whose units are per-GB stored, per transaction and per GB transferred. What is common across the three is the *separation*, not the grouping.

Within the transfer charge there is a documented asymmetry, and it is the mechanism this whole file has been building toward. In the shape the providers publish:

- **Getting data in is not charged.** Inbound transfer from the internet is free.
- **Keeping data still is not charged as transfer.** Moving bytes to other services in the same region, or between buckets in the same region, is excluded from the transfer charge.
- **Getting data out is charged**, per GB, against the volume that leaves.

In, free. Sideways within the region, free. Out, metered. That is the shape.

Two honest qualifications. First, **the lock-in reading is ours, not the vendors'.** No provider pricing documentation connects egress charges to vendor lock-in; what the providers document is the asymmetry above. The inference that the asymmetry produces lock-in is this skill's reading of a published billing shape, and it should be presented that way rather than attributed to anyone's documentation. Second, **do not assume the egress charge appears in the same place on every bill.** Azure Blob Storage's own "data transfer" meter is documented as applying when copying data to another region; leaving the region is charged as platform network bandwidth rather than as a storage meter. The shape is comparable across providers; the invoice line is not.

Now the arithmetic, which is what makes this the most useful single idea in the file. The cost of leaving scales with the volume you have accumulated. The benefit of leaving is a *rate* difference — some improvement per unit of storage or compute, per unit of time. History only accumulates: the corpus is larger every day, so the exit cost grows monotonically while the payback period stretches. **The day you most want to move is, by construction, the day it costs the most to move.** That is lock-in — not a clause in a contract, not a proprietary API, just a term in a subtraction that gets larger while the other term does not.

The same arithmetic, read forward instead of backward, is the practical lever: **data gravity means you move the compute to the data, not the data to the compute.** Because in-region traffic is not charged as egress and outbound traffic is, the placement of processing next to storage is a cost decision before it is a latency decision. A cross-region read path is not a one-time migration cost; it is a recurring charge on every run, for as long as the pipeline exists. The same is true of a cross-region replica kept for resilience: a disaster-recovery choice is also a transfer-cost choice, and the two need deciding together rather than in separate meetings.

And note the gravity you cannot compute. Egress is the part with a unit attached, which makes it the part people argue about. The heavier part is coupling: the consumers reading your schema, the access policies written against your catalog's identifiers, the scheduled jobs whose queries name your tables, the partners with your export format in their code. That mass has no meter, does not appear on any invoice, and is usually the thing that actually decides you are not going to move.

## What this means for the infrastructure-code workflow

The default infrastructure-as-code loop is: change the configuration, read the plan, let the tool converge reality onto it. That loop has an implicit repair mechanism — if convergence goes wrong, destroy and recreate. **For stateful resources that repair is not available**, and removing it changes the practice more than it changes the tooling. Four consequences, each owned by `iac-for-stateful-resources.md` rather than restated here:

- A plan proposing to **replace** a stateful resource is an incident to be read line by line, not a diff to be approved. Replacement is destruction plus creation, and the created object is empty.
- The destroy-protection rules the tooling offers are **narrower than their reputation**. At least one widely-recommended rule protects only while the resource block remains in the configuration — delete the block and the protection leaves with it, in the same change that triggers the destruction. Treat these rules as a guard against accident, never as a governance control.
- **Drift on a resource that scales itself is legitimate**, which makes drift detection on stateful infrastructure a different problem from drift detection on a load balancer that should never change on its own.
- **Environment parity cannot be achieved by cloning**, because the one thing you cannot clone into the lower environment is the data — and the data is what the production behaviour is made of.

Service selection under these constraints is `choosing-a-managed-service.md`; the billing shapes named above, crossed against workload shape, are `sizing-and-the-cost-model.md`.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Applying "cattle, not pets" to a data store | The metaphor's unstated precondition is that the resource holds nothing recoverable only from itself; a warehouse, a retained topic and a history bucket all violate it | Re-derive generic cloud advice against the question "what does this resource hold that the configuration cannot recreate?" before applying it |
| Ordering the design by the architecture diagram | The diagram's biggest boxes are the compute layer, which is the cheapest rung to reverse; the format, catalog, storage service and schema-of-record get decided last and by default | Order the design top-down in reversibility: settle the near-irreversible rungs first, with the most review |
| Asking "how would we leave this?" after adoption | Asked on the day you want to leave, the answer is at its worst and your leverage is zero | Ask it as a selection criterion: export path, exit cost in shape, and whether the data leaves in an open format |
| Quoting a provider as saying egress causes lock-in | The providers document the transfer asymmetry (in free, in-region free, out metered); none of them draws the lock-in conclusion, and attributing it to them is a sourcing error | State the asymmetry as documented shape and the lock-in reading as your own inference from it |
| Treating egress as a one-time migration cost | A cross-region read path or replica charges on every run, for as long as the pipeline exists — it is recurring, not one-off | Decide processing placement and replication topology together, as cost-shape decisions, and colocate compute with storage by default |
| Believing a destroy-protection flag makes the resource safe | The common rules protect only while the resource block is present in the configuration, so the change that deletes the block also deletes the protection | Pair the flag with controls outside the tool — change review on infrastructure files, provider-side deletion protection, and permissions |
