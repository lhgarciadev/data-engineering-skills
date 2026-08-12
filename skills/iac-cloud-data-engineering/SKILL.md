---
name: iac-cloud-data-engineering
description: Cloud infrastructure for data platforms — managed-service selection, sizing and the cost shape, identity, network placement and encryption around a data store, infrastructure code for resources that hold state, and the platform archetypes. Use when the warehouse bill tripled last month, when the pipeline can't reach the database, when a plan proposes to replace something that holds history, or when comparing MSK against Kinesis. Still applies when a general debugging or design skill also fits — that one supplies the method, this one the infrastructure-domain knowledge. If the question is a partition key, use streaming-data-engineering; if it is job tuning, spark-data-engineering; if it is schema design, modeling-data-engineering; if it is DAG design, pipelines-architecture-data-engineering.
---

# IaC and Cloud for Data Engineering

## Overview

**Data infrastructure is stateful infrastructure.** The resource you are provisioning is not a replaceable copy of a template — it is the only place the accumulated history lives, and the configuration that created it describes an empty version of it. Most cloud guidance carries an unwritten precondition that the resource holds nothing, so it needs re-deriving here rather than applying: decisions get ordered by the **reversibility ladder** — how expensive each one is to undo — instead of by the architecture diagram, which puts the cheapest rung in the biggest box.

## When to use

- The warehouse bill jumped and the data volume did not, or nobody can say which meter turned
- A pipeline can't reach a database or a bucket, or someone is asking where to keep a password
- Choosing between two managed services, between provisioned and consumption capacity, or between running something yourself and buying it managed
- A `terraform plan` (or `pulumi preview`, or `cdk diff`) proposes to replace a resource that holds history
- The drift report is noisy enough that nobody reads it any more
- Staging passed and production failed on the same code
- Sizing a cluster, a warehouse or an ingest tier, or deciding what auto-suspend should be set to
- Asking "how would we leave this vendor?", ideally before adoption rather than after
- Designing or reviewing a whole platform stack — streaming tier, distributed compute, warehouse/lakehouse, serving store, serving-API hosting
- Not for partition keys, ordering scope, `acks`, retention versus compaction, or a consumer falling behind — see `streaming-data-engineering`
- Not for job-level tuning (shuffle, skew, join strategy, caching, executor and driver memory) — see `spark-data-engineering`
- Not for grain, dimensional design, SCDs, or the access-pattern model a serving store's keys encode — see `modeling-data-engineering`
- Not for DAG design, orchestrator choice, backfills, or whether to serve output through an API at all — see `pipelines-architecture-data-engineering`
- Not for query optimization, pruning or pushdown as query work — see `sql-data-engineering`
- Not a Terraform syntax tutorial — this skill teaches only the delta statefulness makes to the infrastructure-code practice, not the language
- Not for container orchestration itself — scheduling, networking, autoscaling policy, cluster upgrades and the operator ecosystem are platform engineering, with their own depth

## Quick reference

| Situation | Reach for | Reference |
|---|---|---|
| Deciding how much review a decision deserves; someone proposes to "just recreate it"; pricing an exit | Data infrastructure as stateful infrastructure; the reversibility ladder; migration cost as a selection criterion; data gravity and the documented transfer asymmetry | [statefulness-and-the-one-way-door.md](references/statefulness-and-the-one-way-door.md) |
| Comparing managed services, or being told a product is "serverless" and therefore cheap | The six axes — `operational burden`, `scaling granularity`, `coupling`, `throughput shape`, `failure and recovery model`, `ecosystem fit` — plus the billing unit rather than the product name, and a worked streaming-ingest comparison | [choosing-a-managed-service.md](references/choosing-a-managed-service.md) |
| The bill moved without the data volume moving; choosing provisioned versus consumption; setting an idle timeout | The billing shapes in the units vendors print; the three workload shapes `steady`, `spiky`, `exploratory` crossed against them; sizing from the bottleneck resource rather than the dataset | [sizing-and-the-cost-model.md](references/sizing-and-the-cost-model.md) |
| A job can't authenticate; a credential is about to be stored somewhere; "it's encrypted at rest" is offered as the answer | Per-provider identity attached to compute and federation for compute outside it; bulk read as the interesting permission; network placement as an independent control; what default encryption does and does not buy; where key access is a second gate and where it is not | [identity-network-and-encryption.md](references/identity-network-and-encryption.md) |
| A plan proposes a replacement; the drift report is noise; staging proved nothing | What destroy protection is documented to do and where it stops; the container-versus-tables boundary; declaring the policy rather than the instantaneous value; parity without cloning the corpus; the state file as a data store | [iac-for-stateful-resources.md](references/iac-for-stateful-resources.md) |
| Designing or reviewing a whole stack, or an infrastructure decision and a domain decision are being mistaken for one another | Five recurring stacks, each with what the domain skill decides, the six axes and three workload shapes applied by name, and which rung of the ladder it sits on | [platform-archetypes.md](references/platform-archetypes.md) |

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Declaring table and schema DDL in the infrastructure tool | An accidental destroy stops being a re-provisioning event and becomes a data-loss event, and every column change drags an infrastructure plan through review | Infrastructure owns the container and its perimeter; migrations or the transformation layer own anything addressed by a table name; see [iac-for-stateful-resources.md](references/iac-for-stateful-resources.md) |
| Reading "encrypted at rest" as protection against an over-permissioned reader | The documented threat model is compromise of the physical medium; decryption is transparent to anyone already authorized, and excess permission is filed as an access-control failure | Audit read grants separately from encryption settings, at the engine layer and the storage layer both; see [identity-network-and-encryption.md](references/identity-network-and-encryption.md) |
| Spending the design budget on the compute engine | Compute is the most reversible rung of the ladder — reversing it means pointing a different engine at the same data and re-running — while the storage service, table format and schema-of-record are the least reversible and get decided by default | Order the design by reversibility, settling the least reversible decisions first, not by the architecture diagram; see [statefulness-and-the-one-way-door.md](references/statefulness-and-the-one-way-door.md) |
| Reconciling drift on a resource that scales itself | The live capacity is set by the scaling mechanism by design, so the plan proposes pulling capacity from a live workload or replacing the resource — and a report mixing that churn with identity and encryption changes gets muted wholesale | Declare the bounds and the policy object, not the instantaneous value, and triage drift in two classes; see [iac-for-stateful-resources.md](references/iac-for-stateful-resources.md) |
| Choosing a service by its product name rather than by its billing shape | The label names who operates the infrastructure and predicts nothing about the invoice — Amazon documents Redshift Serverless as billed "in RPU hours on a per-second basis" against capacity used | Name the meter — bytes scanned, capacity held over time, requests, throughput delivered — then decide it against your throughput shape; see [choosing-a-managed-service.md](references/choosing-a-managed-service.md) |
| Asking "how would we leave this?" only once you want to leave | The exit cost scales with everything accumulated so far and the benefit of leaving stays a rate, so the day you most want to move is the day it costs the most | Ask it as a selection criterion — export path, exit cost in shape, and whether the data leaves in an open format; see [statefulness-and-the-one-way-door.md](references/statefulness-and-the-one-way-door.md) |
| Naming a scaling unit without the mode or tier that exposes it | The unit belongs to the mode, not the product, so a unit quoted from the wrong tier sizes nothing | State unit and mode together, from the vendor's page for the tier you are buying; see [choosing-a-managed-service.md](references/choosing-a-managed-service.md) |
