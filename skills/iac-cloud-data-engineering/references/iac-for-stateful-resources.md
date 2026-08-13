# Infrastructure Code for Resources That Hold State

[`statefulness-and-the-one-way-door.md`](statefulness-and-the-one-way-door.md) establishes the frame: the default infrastructure-as-code loop assumes a repair mechanism — if convergence goes wrong, destroy and recreate — and that mechanism is unavailable for the resource holding the history. This file is the delta, not a tutorial. Everything below exists because statefulness changes the practice.

## Naming the tool, once

The licence position, because older material is stale in a specific way:

- **Terraform is under Business Source License 1.1**, SPDX `BUSL-1.1`, with `Licensed Work: Terraform Version 1.6.0 or later`. **BUSL-1.1 is not an OSI-approved licence**, and the OSI has written that licences "like BUSL that delay availability of full software freedom won't be approved". HashiCorp's own word for it is **"source-available"** — it does not say "not open source", and putting that in its mouth is a sourcing error. The file also sets `Change License: MPL 2.0` and `Change Date: Four years from the date the Licensed Work is published`.
- **Writing "HashiCorp's BUSL" is itself out of date.** The `LICENSE` commit of 2026-03-11 replaced `HashiCorp, Inc.` with `International Business Machines Corporation (IBM)` as the named `Licensor`. For brevity, write `BUSL-1.1` and name no company.
- **OpenTofu is a fork** under **MPL 2.0**, which *is* OSI-approved, under Linux Foundation stewardship. Use the project's documentation wording rather than its home page: the docs say OpenTofu "aims to maintain compatibility with Terraform configurations" and that "most Terraform code will work without modification", and the one published boundary is state — "OpenTofu will work with existing state files up to those created with Terraform versions 1.5.x." Quote the boundary whenever you quote the compatibility.

**Is the advice tool-independent?** Mostly, and the exception is the one this file cares about. The declarative desired-state model, the plan-before-apply discipline, and the existence of an opt-in destroy-protection mechanism all generalise — `terraform plan` ≈ `pulumi preview` ≈ `cdk diff`; `prevent_destroy` ≈ Pulumi's `protect` ≈ CDK's `RemovalPolicy` over CloudFormation's `DeletionPolicy`. What does **not** generalise is the state file as an artefact *you* host: it applies to Terraform/OpenTofu, and with a vocabulary translation to Pulumi ("state" in a "backend", snapshotted as a "checkpoint"); it does not apply to AWS CDK, where no such artefact exists and the source of truth is the CloudFormation stack, service-side, with AWS owning its durability and locking.

Everything below is written for `Terraform/OpenTofu` — same HCL, same state model, same `lifecycle` meta-arguments — with equivalents named where they diverge. The licence question does not come up again.

## Destroy protection, as the documentation states it

The reference page defines `prevent_destroy` against the *plan*, not a command:

> "When prevent_destroy is set to true, Terraform rejects plans that would destroy the infrastructure object associated with the resource and returns an error. The argument must be present in the configuration."

The error text confirms which condition is evaluated — "the plan calls for this resource to be destroyed" — so this is not a lock on `terraform destroy`. It fires in any operation that produces such a plan, which is why the escape it suggests narrows the plan's scope.

**It covers replacement, and that is the effect you will actually meet.** A replacement is a destroy plus a create: the same page lists among Terraform's default operations "Destroys and re-creates resources whose arguments have changed but that Terraform cannot update in-place because of remote API limitations", and a plan containing that destruction is one the rule rejects. The recommended-use paragraph admits the consequence in the same breath as the purpose:

> "Use this rule as protection against accidentally replacing objects that may be costly to reproduce, such as database instances, storage, or other stateful resources. Enabling prevent_destroy, however, makes certain configuration changes impossible to apply and prevents the terraform destroy command from operating once such objects are created. Use prevent_destroy sparingly."

Be honest about provenance: the reference page never writes "prevent_destroy blocks replacements". It implies it twice — "accidentally replacing", and "makes certain configuration changes impossible to apply" — and the explicit statement lives on a tutorial page visibly older than the reference pages. So the dominant production symptom is not someone stopped from destroying a warehouse; it is **a plan failing outright for a resource nobody asked to destroy**, because an attribute change forced recreation.

### The part that inverts the popular story

> "This rule doesn't prevent Terraform from destroying a resource if you remove its configuration."

And the mechanism, from the same page's section on state:

> "Except for create_before_destroy, Terraform does not explicitly record a resource's lifecycle rule to state. As a result, Terraform destroys the actual infrastructure during an apply operation if you remove the resource's configuration, even if prevent_destroy is enabled."

The tutorial adds the variant people actually type: "does not prevent Terraform from destroying the resource if you comment out or remove the configuration."

Read that carefully, because it inverts the reassuring version. The rule does not live in state; it lives only in the configuration. Delete the resource block — or comment it out while debugging — and the protection leaves with the block, in the same change that schedules the destruction. The rule never gets a chance to object.

**So protection is a guard rail, not a backup, and not a governance control.** It stops a hand slipping while the block is present; it stops nothing a reviewer would have had to catch anyway. It is one of three controls on a resource that holds state, never the only one: **change review on the infrastructure files**, treating a removed or commented-out block for a stateful resource as a blocking finding, because at plan time that diff is indistinguishable from an intentional decommission; **provider-side deletion protection**, set on the object by the provider rather than the infrastructure tool, so deleting the configuration is not sufficient; and **permissions**, so the identity running apply cannot delete resources that hold data.

When the intent genuinely is "stop managing this without destroying it", the documented route is not to delete the block. It is the `removed` block with `lifecycle { destroy = false }` — "Setting destroy to true removes the resource from state and destroys it" — preferred over `terraform state rm` because it "lets you preview the results of the operation, which makes it a safer way to remove resources."

### `create_before_destroy` is not the tool for this

It reorders; it does not cancel. The documentation instructs Terraform "to create a replacement resource before destroying the current resource", and requires that constraints "must be accommodated for both a new and an old object to exist concurrently". It also propagates to dependencies and is recorded to state, so it cannot be overridden back to false there.

The old object is still destroyed. **The accumulated state does not travel to the replacement** — that inference is this skill's, not HashiCorp's, and no official page says `create_before_destroy` is wrong for data resources. What the documentation says is that it is a remedy for *downtime*, that the sentence naming "database instances, storage, or other stateful resources" sits in the `prevent_destroy` paragraph rather than this one, and that you must "understand the constraints for each resource type" first — which for a data resource means asking what happens to the bytes, a question it does not answer for you.

### The same idea in the other tools

Pulumi's `protect` is a hard rejection — "A protected resource cannot be deleted directly, and it will be an error to do a Pulumi deployment which tries to delete a protected resource for any reason" — propagating from a component to its children, with an escape that is exactly the flag someone adds to unblock CI: `--ignore-protect`. On AWS CDK the mechanism is `RemovalPolicy` over CloudFormation's `DeletionPolicy`, and **the default is not universal**: CDK documents `RETAIN` as the default for constructs that maintain persistent data, while CloudFormation documents: "If a resource has no DeletionPolicy attribute, CloudFormation deletes the resource by default." Verify the concrete construct's default.

## The managed resource is the warehouse, not the tables inside it

Draw the boundary explicitly, because it is the one that most often gets drawn by accident:

- **Infrastructure code owns the container and its perimeter.** The warehouse, database, cluster, bucket, topic, catalog registration; their network placement, identity bindings, keys and protection flags. Provisioned once, changed rarely.
- **Migrations, or the transformation layer, own everything addressed by a table name.** Schemas, tables, views, columns, grants written against them.

The reason is not tidiness. **With table and schema DDL in the infrastructure tool, an accidental destroy stops being a re-provisioning event and becomes a data-loss event.** Re-running the configuration that created an empty warehouse gives you an empty warehouse — recoverable, annoying, bounded. Re-running one that also declared every table in it gives you empty tables where the history used to be, and the plan that did it looked like ordinary reconciliation. In the reversibility ladder's terms, putting a reversible operation and a near-irreversible one behind the same `apply` gives the cheap decision the blast radius of the expensive one.

A second reason bites earlier: the two change at different rates and want different review. A schema change ships with the code that reads it and needs whoever owns the model; a warehouse's network placement changes rarely and needs whoever owns the perimeter. Fusing them means every column addition drags an infrastructure plan through review, and every infrastructure change carries the ability to drop a table.

Where DDL does belong is [`dbt-project-architecture.md`](../../pipelines-architecture-data-engineering/references/dbt-project-architecture.md) — the transformation tool emits the DDL as part of running, which is why the `table` materialization is documented as a model "rebuilt as a table on each run, via a `create table as` statement". The object's existence is an output of the transformation, not a declaration in a tool that also holds the power to destroy its container.

The one honest grey area is the database or schema *object*, plausibly either. Pick a side per platform, write it down, and make sure the resource that can cascade a delete into contained objects carries both a protection rule and provider-side deletion protection. [`platform-archetypes.md`](platform-archetypes.md) applies this boundary archetype by archetype.

## Drift, when the resource is supposed to change itself

The standard drift story: live state differs from declared state, therefore someone changed something out of band, therefore reconcile. Its unstated premise is that the declared value is the *only* legitimate source of the live value. On data infrastructure that premise is frequently false — a problem application infrastructure mostly does not have.

An autoscaled cluster's live worker count is set by the autoscaler, on purpose, in response to load — and a capacity mechanism can move it with nobody touching a console. Azure's Event Hubs documents that "the **Auto-inflate** feature of Event Hubs automatically scales up by increasing the number of throughput units to meet usage needs"; that is Event Hubs' documented behaviour, named as one concrete instance rather than as a claim about every provider's autoscaler. The consequence holds wherever a resource resizes itself: **the live infrastructure diverges from the declared value by design, and the divergence is correct.**

Naively reconciling that fights the mechanism you are paying for. The plan proposes setting the count back to the declared number; applying it pulls capacity from under a live workload, and if the remote API cannot change that attribute in place it proposes a replacement instead — the previous section's error, for a resource nobody asked to destroy.

The fix is to **declare the policy, not the instantaneous value**:

- **Declare the bounds and the policy object** — minimum, maximum, target signal, mode — and let the live count be an output of them. Same distinction as the `scaling granularity` axis in [`choosing-a-managed-service.md`](choosing-a-managed-service.md): the unit and the mode are yours to declare, the current number of units is not.
- **Where the API does not separate them**, do not declare what you do not intend to own. An attribute absent from the configuration cannot generate a spurious diff.
- **Where the tool insists on holding a value it does not own**, use its per-attribute exclusion mechanism — and treat that exclusion as a decision with an owner and a comment, because it blinds you to *real* drift on that attribute thereafter.

Then the second-order point, which is what makes drift detection useful rather than merely noisy: split the declaration into two classes and triage them differently. **Attributes that must never move on their own** — name and identifier, region, encryption key, public accessibility, deletion protection, retention, backup configuration — are a security or durability event when they drift, and should page someone. **Attributes that legitimately move** — capacity, worker counts, anything a scaling policy drives — are the system working. A report that mixes the two gets muted, and the muting takes the first class down with the second. That, not the autoscaler, is how the encryption setting someone changed by hand during an incident stays changed.

## Environment parity when you cannot clone production

Staging can mirror the **shape** of production infrastructure — resource types, identity model, network placement, file and table formats, catalog layout. It cannot mirror the **data**, which by the frame's own argument is exactly the part not recoverable from configuration. Parity is achievable on everything except the variable most production failures are made of.

That asymmetry decides what a green staging run is worth. It is real evidence that the configuration applies, the identity binding resolves, permissions are sufficient and the pipeline runs end to end. It is **no evidence at all** about anything sized: skew, cardinality, partition counts, shuffle spill, scan cost, timeouts, memory pressure, and the query plan the engine picks once the statistics look different — see [`joins-and-skew.md`](../../spark-data-engineering/references/joins-and-skew.md) for what those failures look like when they arrive. Infrastructure that behaves correctly at staging volume can fail on production volume, and that failure is not a regression: nothing changed except the input.

The tempting repair — copy production data down — trades one problem for a worse one. It moves the corpus into an environment with weaker access controls and looser review, where the bulk-read exposure in [`identity-and-network-access.md`](identity-and-network-access.md) applies with fewer guards, and the copy is a transfer with a meter on it and a standing storage charge behind it ([`sizing-and-the-cost-model.md`](sizing-and-the-cost-model.md)). A production-sized staging environment fails from the other direction: standing cost on the most expensive rung of the ladder, and still not production, having neither its history nor its cardinality.

What to do instead, in order:

1. **Match the shape and parameterise the size.** Same modules, same resource types, same policies; capacity as an input. The lower environment proves the *declaration* is right.
2. **Accept the divergence explicitly, in the code.** The parameter that differs should be named and visible, so nobody reads staging's success as a statement about production.
3. **Test volume-sensitive behaviour where the volume is.** A shadow run against production data writing to a throwaway destination, or a single production partition processed in isolation. An output location that is a parameter, and writes that are idempotent, are what make such a test safe.

## The state file is a data store you forgot you had

*Scope: this section applies to Terraform/OpenTofu and, with the vocabulary translation above, to Pulumi. It does not apply to AWS CDK, where no such artefact exists.*

[`identity-and-network-access.md`](identity-and-network-access.md) ends by pointing here. The documentation is direct:

> "Terraform state and plan files contain detailed information about your infrastructure, including resource attributes and metadata that can contain sensitive values, such as initial database passwords or API tokens."

> "If you are developing with Terraform locally, Terraform stores your state in a plaintext file, which includes any secret values you defined in your configuration. Treat your state file as sensitive data by excluding it from Git workflows and following our recommendations to secure your state file."

**And marking a value sensitive does not take it out.** "Terraform stores values with the sensitive argument in both state and plan files, and anyone who can access those files can access your sensitive values." The same holds one layer down, for attributes a provider marks sensitive in its own schema: enabling that flag "will prevent the field's values from showing up in CLI output and in HCP Terraform. It will not encrypt or obscure the value in the state, however." `sensitive` is an **output-redaction rule**, not a storage rule.

What does keep a value out is a different mechanism: ephemeral values, "available at the run time of an operation, but Terraform omits them from state and plan files", and write-only arguments, which "let you securely pass temporary values to Terraform's managed resources during an operation without persisting those values to state or plan files" — with the documented requirement to "Use Terraform 1.11 or later to use a write-only argument on a managed resource". OpenTofu additionally documents encryption of state and plan files at rest — what OpenTofu documents, not a comparison.

The documentation's own recommendations, as a shape: store the state remotely, encrypt it at rest, use access controls to limit who can reach it, keep audit logs of access. Everything in [`identity-and-network-access.md`](identity-and-network-access.md) about bulk read on a data store applies to the bucket holding it — and that bucket usually carries the broadest read grant and the least review, because it does not look like a data store on any inventory.

One last twist closes the loop with the frame. **The state file is itself a stateful resource by this skill's definition**: it is not recoverable from the configuration that produced it. Losing it destroys no infrastructure, but it destroys the *mapping* between configuration and managed objects, after which the tool sees a world where nothing it declares exists — and proposes to create all of it. Recovery is importing resources one at a time. Version the backend, lock it, restrict it, and back it up as seriously as the warehouse it provisions.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Believing `prevent_destroy` survives deleting the resource block | The rule is not recorded to state, so removing or commenting out the block disarms it in the same change that schedules the destruction: Terraform "destroys the actual infrastructure during an apply operation if you remove the resource's configuration, even if prevent_destroy is enabled" | Pair it with change review on infrastructure files, provider-side deletion protection and permissions; to stop managing without destroying, use the `removed` block with `lifecycle { destroy = false }` |
| Reading `prevent_destroy` as an anti-`destroy` lock | Its dominant effect is the other one: a plan fails for a resource nobody asked to destroy, because an attribute change forced recreation — it "makes certain configuration changes impossible to apply" | Read it as a rejection of any plan that would destroy the object, and heed "Use prevent_destroy sparingly" |
| Reaching for `create_before_destroy` to protect data | It reorders rather than cancels: the old object is destroyed anyway, both must exist concurrently, and the accumulated state does not travel to the replacement (this skill's reading, not HashiCorp's) | Use it for downtime, as the documentation does; for a data resource, ask what happens to the bytes first |
| Assuming a retention default carries across tools | CDK documents `RETAIN` as the default for constructs holding persistent data, while CloudFormation documents that without a `DeletionPolicy` it "deletes the resource by default" | Verify the default on the concrete construct or resource type |
| Declaring table and schema DDL in the infrastructure tool | An accidental destroy stops being a re-provisioning event and becomes a data-loss event, and every column change drags an infrastructure plan through review | Infrastructure owns the container and its perimeter; migrations or the transformation layer own anything addressed by a table name |
| Reconciling drift on an autoscaled resource | The live count is set by the autoscaler by design; reconciling pulls capacity from a live workload or proposes a replacement — and a report mixing that churn with identity and encryption changes gets muted wholesale | Declare bounds and the policy object, not the instantaneous value; triage drift in two classes and page only on attributes that must never move |
| Reading a green staging run as evidence about production | Staging mirrors the shape but not the corpus, and the failures that matter — skew, cardinality, scan cost, spill — are made of volume | Match shape, parameterise size, name the divergence in code, and test volume-sensitive behaviour against production data on a controlled path |
| Treating `sensitive = true` as protection for a secret in state | It is output redaction: values are stored "in both state and plan files", and a provider's schema flag "will not encrypt or obscure the value in the state" | Use ephemeral values or write-only arguments for what must not persist; treat the backend as a data store — remote, encrypted, access-controlled, audited, out of Git |
