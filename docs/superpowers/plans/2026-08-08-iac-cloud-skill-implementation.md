# IaC/Cloud Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write `iac-cloud-data-engineering` — the ninth and final domain skill of the `dataforge` suite — close the ten forward-pointers that already declare toward it, and prove by measurement that it routes without breaking the eight skills that now point at it.

**Architecture:** Same shape as the eight delivered domain skills: a `SKILL.md` router with overview / when-to-use / quick reference / common mistakes, and six `references/` files of roughly 1.6k–3.5k words each. Content is organised around one frame — data infrastructure is *stateful* infrastructure, and every selection, sizing and security decision is downstream of the fact that you cannot destroy and recreate the thing that holds the data. Every claim is verified against a primary source before it is written, and the delivered skill is measured against the triggering harness before it is considered done.

**Tech Stack:** Markdown skill files; `claude plugin validate` for manifest and frontmatter; `tests/triggering/` (`run-matrix.sh`, `rescore.sh`) for behavioural measurement.

**Spec:** `docs/superpowers/specs/2026-08-08-iac-cloud-skill-design.md` — read it before starting any task.

## Global Constraints

- All skill artifacts are in **English**, including reference files. Specs and plans are in Spanish, matching this repo's split.
- Frontmatter must stay **≤ 1024 characters** total, and must parse as YAML. A `: ` inside an unquoted scalar breaks parsing and the skill loads with every field silently dropped. Run `claude plugin validate .` after any frontmatter edit.
- **The suite is complete after this delivery.** No skill may say a domain "has no skill in this suite yet". Every such phrase is a defect after Task 8 — see Task 8 Step 1 for the enumeration that proves none survive. The inverse of the phantom-skill rule still holds: never name a skill that does not exist.
- **THE NO-NUMBERS RULE (spec §3).** This skill names cloud services. It must never state a price, a service limit, a quota, an instance type, a node size, or a maximum partition/shard count. Cost is taught as a **shape** — per-hour provisioned, per-request, per-GB-scanned, per-GB-stored, egress — never as a figure. A number in a reference file is a delivery-blocking defect, because it is the claim that rots fastest and cannot be kept sourced. Every content task carries a grep for this.
  **The rule is the prose above; the grep is only an instrument for it.** Billing *units* are required — `per GB / per month` is a shape and must survive verbatim where a source states it; only *amounts* are forbidden. Version identifiers (`2026-02-01`) are not amounts either, and are required for traceability. If the grep flags a legitimate unit, fix the grep, never the sentence. It was narrowed once already for exactly this: an earlier form matched the bare string `per month` and forced a reference file to rephrase a vendor's literal meter name.
- **THE SERVICE-NAME RULE (spec §5).** Every named service is a claim and needs a verdict. The streaming delivery's most expensive finding was that six different writers shipped a true-sounding engine claim with no verdict behind it, and two were false. This skill is nothing but service names, so the exposure is worse. Every content task and every review prompt must grep the research corpus for each service named and delete or verify anything without a verdict.
- Description patterns, all three measured in this repo, not stylistic preference:
  - jargon-free triggers alongside technical ones — real diagnostic prompts do not use domain vocabulary;
  - boundaries as conditionals on an observable predicate, not prohibitions;
  - the co-invocation clause verbatim: `Still applies when a general debugging or design skill also fits — that one supplies the method, this one the infrastructure-domain knowledge.`
- Reference files: 1.6k–3.5k words. Cross-links must resolve **from the linking file's own directory**, which means the depth differs by where the link lives:
  - from `SKILL.md` to its own references: `[text](references/file.md)`
  - from `SKILL.md` to another skill: `[text](../other-skill/references/file.md)`
  - from a file inside `references/` to another skill: `[text](../../other-skill/references/file.md)` — two levels, because you climb out of `references/` first
  Verify every link by resolving it, never by eye. An earlier plan in this repo wrote the two-level case with one level in fourteen places.
- **Anchored links must have their anchor checked too.** The obvious grep, `grep -oE '\]\([^)]+\.md\)'`, silently skips any link carrying a `#fragment`. Use this instead, from the directory holding the file:

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

  The trap this catches: a heading containing an em-dash slugifies to a **double** hyphen, because the dash is stripped and its two surrounding spaces both become hyphens. `## Cost as a shape — not a number` becomes `cost-as-a-shape--not-a-number`. Writing one hyphen there produces a link that resolves to the file but lands at the top of it, not the section.
- Every reference file linked from `SKILL.md` must exist, and every file under `references/` must be linked from `SKILL.md`.
- Research verification docs go to `docs/superpowers/research/2026-08-08-<topic>-verification.md`, matching the 35 already there.
- Commit per task. Conventional commits, no AI attribution.

---

## File Structure

| File | Responsibility |
|---|---|
| `docs/superpowers/research/2026-08-08-*.md` | Seven verification passes; each records claim, source, verdict |
| `skills/iac-cloud-data-engineering/references/statefulness-and-the-one-way-door.md` | The frame: stateful vs cattle, the reversibility ladder, migration cost as a selection input, data gravity and egress |
| `.../references/choosing-a-managed-service.md` | The axes; managed vs self-managed; serverless vs provisioned; the MSK/Kinesis worked comparison; the Spark-on-K8s slice |
| `.../references/sizing-and-the-cost-model.md` | Cost as shape crossed against workload shape; sizing from the bottleneck resource |
| `.../references/identity-network-and-encryption.md` | Service vs user identity, least privilege on data stores, private endpoints, encryption, secrets |
| `.../references/iac-for-stateful-resources.md` | Destroy protection, what does not belong in IaC, drift on autoscaling, environment parity, state as a secret |
| `.../references/platform-archetypes.md` | Five archetypes absorbing the ten pointers; domain-decides vs here-decides for each |
| `.../SKILL.md` | Router: overview, when-to-use, quick reference, common mistakes |
| `skills/{spark,modeling,streaming,data-engineering}/SKILL.md` | Ten pointer edits across four skills |
| `skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md` | The tenth pointer |
| `tests/triggering/matrix*.tsv`, `baselines/2026-08-08-iac-routing.md` | Behavioural measurement |

---

### Task 1: Research verification

**Files:**
- Create: `docs/superpowers/research/2026-08-08-terraform-lifecycle-and-state-verification.md`
- Create: `docs/superpowers/research/2026-08-08-cost-model-shapes-verification.md`
- Create: `docs/superpowers/research/2026-08-08-managed-streaming-services-verification.md`
- Create: `docs/superpowers/research/2026-08-08-managed-spark-compute-verification.md`
- Create: `docs/superpowers/research/2026-08-08-workload-identity-verification.md`
- Create: `docs/superpowers/research/2026-08-08-encryption-at-rest-verification.md`
- Create: `docs/superpowers/research/2026-08-08-iac-tooling-drift-verification.md`

**Interfaces:**
- Produces: seven verification docs. Every later task cites the relevant one and must not state a claim that its verification marked UNSUPPORTED or CORRECTED.

This task is the "write the failing test first" of a content skill: the claim is verified against the source **before** any reference file asserts it. A claim that cannot be sourced does not get written. Record every claim as SUPPORTED / CORRECTED / UNSUPPORTED with a quotation or citation and the date checked.

- [ ] **Step 1: Verify the Terraform lifecycle and state claims**

Source: HashiCorp Terraform documentation (`lifecycle` meta-argument; sensitive data in state). Claims:

1. `prevent_destroy = true` causes an error at plan time when the resource would be destroyed.
2. Whether it also blocks a **replacement** (destroy-and-recreate triggered by a forces-new-resource attribute change), or only an explicit destroy. Record the documented behaviour exactly — the skill's central practical advice depends on this distinction.
3. What bypasses it — specifically, whether removing the resource block from configuration entirely still errors.
4. Terraform state can contain sensitive values in plain text, including for resources whose attributes are marked sensitive.
5. `create_before_destroy` and why it is the wrong tool for a stateful data resource.

Claim 2 is the one to be most careful with. "It stops you destroying the warehouse" is the popular simplification and the reference file must state whatever the documentation actually says, not the simplification.

- [ ] **Step 2: Verify the cost-model shapes**

Sources: vendor pricing *model* documentation (not price lists) for BigQuery, Snowflake, Athena, Redshift Serverless, S3/GCS/ADLS. Claims — each about the **shape** of the charge only, never the amount:

1. BigQuery's on-demand model charges by bytes scanned, and a capacity/slot model exists as an alternative.
2. Snowflake bills compute by credit against warehouse uptime with per-second granularity after a minimum, and auto-suspend is the lever.
3. Athena's on-demand model charges by data scanned, which is why file format and partitioning move the bill.
4. Object storage charges separately for storage, requests, and egress — and egress is the one that produces lock-in.
5. Whether "serverless" in each product name means per-request billing or merely managed capacity. These differ by product and the skill must not generalise.

**Record the shape and the units, never a figure.** If a source only states shape alongside a price, quote the shape and drop the number.

- [ ] **Step 3: Verify the managed streaming services**

Sources: AWS MSK, AWS Kinesis Data Streams, Azure Event Hubs, GCP Pub/Sub documentation. Claims:

1. The scaling unit each exposes to the user — broker count, shard, throughput unit, or none — named with the vendor's own term.
2. Which of them offer a serverless or on-demand capacity mode, and what the vendor calls it.
3. Which present a Kafka-compatible protocol surface and which present a proprietary API. This is the coupling axis and it must be sourced, not assumed.
4. Whether ordering is scoped per shard/partition in each, matching what `streaming-data-engineering` already teaches for Kafka.

- [ ] **Step 4: Verify the managed Spark and compute services**

Sources: AWS EMR and EMR Serverless, AWS Glue, GCP Dataproc and Dataproc Serverless, Databricks, Microsoft Fabric / Azure Synapse documentation. Claims:

1. Each service's current product name, verified as still in use — not inferred from memory.
2. Which offer a serverless variant, using the vendor's term.
3. **Drift candidate:** the current status of Azure Synapse Analytics relative to Microsoft Fabric. Record what the documentation says today about which is the forward path, and the date checked. `sql-data-engineering` already names both, so a change here has a blast radius beyond this skill.

- [ ] **Step 5: Verify the workload identity claims**

Sources: AWS IAM roles documentation, Azure managed identities documentation, GCP service accounts / Workload Identity documentation. Claims:

1. The correct current term in each provider for an identity a workload assumes without a stored credential.
2. That the pattern's purpose is eliminating long-lived static credentials, stated in the vendor's own words.
3. Whether each provider's mechanism works for compute outside that provider, which is the axis that matters for a hybrid pipeline.

Terminology accuracy is the whole point of this pass. Using the wrong provider's term for the right concept is the exact class of error this repo has already shipped once.

- [ ] **Step 6: Verify the encryption claims**

Sources: AWS KMS, Azure Key Vault / customer-managed keys, GCP Cloud KMS documentation, plus the default-encryption statement for at least one major object store. Claims:

1. What "encrypted at rest by default" covers, and what it does not — specifically whether it protects against an over-permissioned reader, which is the misconception worth correcting.
2. The correct term per provider for a customer-managed key (CMK, CMEK, or otherwise).
3. That key access is governed by its own policy surface, separate from the data store's.

- [ ] **Step 7: Verify the IaC tooling drift**

Sources: HashiCorp licensing announcement and the OpenTofu project's documentation. Claims:

1. **Drift candidate:** Terraform's current licence, and whether it is still open source under the OSI definition. This changed, and a skill that is agnostic by design must not silently assume otherwise.
2. That OpenTofu exists as a fork and what its compatibility claim with Terraform is.
3. Whether Pulumi and CDK belong in the same category for the purposes of this skill's advice, or whether the advice is tool-independent.

The output of this pass decides how the skill names the tool throughout. If the advice is genuinely tool-independent, the skill says so once and stops re-litigating it.

- [ ] **Step 8: Commit**

```bash
git add docs/superpowers/research/2026-08-08-*.md
git commit -m "docs(iac-cloud): verificar afirmaciones de cloud e IaC contra fuentes primarias"
```

---

### Task 2: `statefulness-and-the-one-way-door.md`

**Files:**
- Create: `skills/iac-cloud-data-engineering/references/statefulness-and-the-one-way-door.md`

**Interfaces:**
- Consumes: `2026-08-08-terraform-lifecycle-and-state-verification.md` and `2026-08-08-cost-model-shapes-verification.md` from Task 1.
- Produces: the frame every other reference assumes. Later files may say "as covered in `statefulness-and-the-one-way-door.md`" rather than restating it.

- [ ] **Step 1: Write the file**

Cover, in this order:

1. **The distinction that makes this a data-engineering problem.** Application infrastructure is cattle: a web server is replaced without ceremony because it holds nothing. A warehouse, a topic with retention, a state backend, a bucket with history are not replaceable, because the thing of value *is* the accumulated state. Say plainly that most cloud advice is written for the cattle case and quietly stops applying here.
2. **The reversibility ladder**, as the practical consequence. Cheap to undo: compute engine, orchestrator, node type. Expensive: file format, table format, catalog. Near-irreversible: the storage service holding years of history, and the schema-of-record consumers have coupled to. Order the ladder explicitly and say that decisions are made top-down in *reversibility*, not top-down in the architecture diagram.
3. **Migration cost is a selection criterion, not a consequence.** The question "how would we leave this?" is asked *before* adoption, not after. Give the concrete form: what is the export path, what does it cost, and does the data leave in an open format or a proprietary one.
4. **Data gravity and egress as the mechanism of lock-in.** Per the cost-model verification, egress is a separate charge from storage and request. Lock-in is not a vendor conspiracy; it is arithmetic — the cost of moving the data exceeds the savings of moving it, and it grows monotonically with the data. This is the file's most useful single idea.
5. **What this means for the IaC workflow**, briefly, pointing forward rather than duplicating: destroy-and-recreate is not available, so the practice differs — see `iac-for-stateful-resources.md`.

Cross-link the table-format and lakehouse material in `../../modeling-data-engineering/references/modern-lakehouse-modeling.md`, and the schema-compatibility material in `../../quality-data-engineering/references/data-contracts-and-schema-compatibility.md` for the "consumers coupled to the schema" rung of the ladder.

- [ ] **Step 2: Verify size, links, numbers and sourcing**

```bash
cd skills/iac-cloud-data-engineering/references
wc -w statefulness-and-the-one-way-door.md
grep -nE '\$[0-9]|[0-9]+ *(GB|TB|vCPU|cores|nodes|shards|partitions|ms|USD)/|[0-9][0-9.,]* *per month|[0-9]+ *%' statefulness-and-the-one-way-door.md
```
Expected: word count between 1600 and 3500; the numbers grep returns **nothing** (the no-numbers rule); then run the anchored-link checker from Global Constraints and expect zero BROKEN lines.

- [ ] **Step 3: Commit**

```bash
git add skills/iac-cloud-data-engineering/references/statefulness-and-the-one-way-door.md
git commit -m "docs(iac-cloud): add the statefulness frame and the reversibility ladder"
```

---

### Task 3: `choosing-a-managed-service.md`

**Files:**
- Create: `skills/iac-cloud-data-engineering/references/choosing-a-managed-service.md`

**Interfaces:**
- Consumes: `2026-08-08-managed-streaming-services-verification.md` and `2026-08-08-managed-spark-compute-verification.md` from Task 1; the reversibility ladder from Task 2.
- Produces: the six axes, by name. `platform-archetypes.md` applies them per archetype and must use the same six names.

- [ ] **Step 1: Write the file**

1. **The six axes**, which are the durable content — name them exactly and keep the names stable across the skill: *operational burden*, *scaling granularity*, *coupling*, *throughput shape*, *failure and recovery model*, *ecosystem fit*.
2. **Managed vs self-managed as a transfer of work, not a saving.** Managed moves the work from your on-call rota to your bill and to a support ticket queue; it does not delete it. Name what you give up: version pinning, tuning knobs, and the ability to fix an incident yourself.
3. **Serverless vs provisioned, and what question decides it.** The deciding question is the *throughput shape*: steady load favours provisioned, spiky or unpredictable load favours per-request. Per the cost-model verification, "serverless" does not mean per-request billing in every product — say so, and say that the product name is not the answer, the billing shape is.
4. **The worked comparison `streaming-data-engineering` cedes here:** MSK vs Kinesis vs self-managed Kafka, with the Azure and GCP equivalents mapped in a table. One row per axis. Use only the scaling-unit terms and capacity modes the Task 1 verification confirmed, and state the coupling axis honestly — Kafka-protocol compatibility versus a proprietary API is the difference that decides how expensive leaving is.
5. **The Kubernetes slice that survives (spec §2.4).** Spark-on-K8s is a *compute* decision and gets asked the same six questions; a stateful data store on a container orchestrator inherits every problem in `statefulness-and-the-one-way-door.md`. Do not teach Kubernetes itself — say explicitly that container orchestration is platform engineering and outside this skill.

Cross-link `../../streaming-data-engineering/references/the-log-and-partitioning.md` for what stays a streaming decision, and `../../spark-data-engineering/SKILL.md` for job-level tuning.

- [ ] **Step 2: Verify size, links, numbers and service names**

```bash
cd skills/iac-cloud-data-engineering/references
wc -w choosing-a-managed-service.md
grep -nE '\$[0-9]|[0-9]+ *(GB|TB|vCPU|cores|nodes|shards|partitions|ms|USD)/|[0-9][0-9.,]* *per month|[0-9]+ *%' choosing-a-managed-service.md
for s in MSK Kinesis "Event Hubs" "Pub/Sub" EMR Glue Dataproc Databricks Fabric Synapse; do
  grep -qi "$s" choosing-a-managed-service.md && \
  { grep -rqi "$s" ../../../docs/superpowers/research/2026-08-08-*.md && echo "VERDICT OK  $s" || echo "NO VERDICT  $s"; }
done
```
Expected: word count 1600–3500; numbers grep returns nothing; every service named prints `VERDICT OK`. A `NO VERDICT` line means either verify it in Task 1's docs or delete the mention — do not leave it.

- [ ] **Step 3: Commit**

```bash
git add skills/iac-cloud-data-engineering/references/choosing-a-managed-service.md
git commit -m "docs(iac-cloud): add the six selection axes and the managed-service comparison"
```

---

### Task 4: `sizing-and-the-cost-model.md`

**Files:**
- Create: `skills/iac-cloud-data-engineering/references/sizing-and-the-cost-model.md`

**Interfaces:**
- Consumes: `2026-08-08-cost-model-shapes-verification.md` from Task 1; the *throughput shape* axis named in Task 3.
- Produces: the three workload shapes by name — *steady*, *spiky*, *exploratory* — reused by `platform-archetypes.md`.

- [ ] **Step 1: Write the file**

1. **Cost as a shape.** The five shapes, per the verification: per-hour provisioned, per-request, per-GB-scanned, per-GB-stored, egress. State up front and once that this file gives no figures, and why: prices change faster than any document can track, and the shape is what survives.
2. **The three workload shapes** — steady, spiky, exploratory — and the cross-product with the cost shapes as a table. The useful cell: exploratory analytics on a per-GB-scanned model is where bills explode, because the cost is driven by analyst behaviour rather than by data volume.
3. **Why per-GB-scanned makes `SELECT *` an architecture decision.** This is the strongest cross-domain link in the skill: partitioning and clustering stop being query-tuning and become the cost-control lever. Link `../../sql-data-engineering/references/engineering-query-patterns.md` and the partitioning material in `../../modeling-data-engineering/`.
4. **Sizing from the bottleneck resource, not from data volume.** Ask which resource saturates first — memory, network, IO, or a concurrency limit. "The dataset is large" does not by itself imply a node size. Tie the memory case back to `../../spark-data-engineering/SKILL.md`.
5. **Provisioning for the peak, and when not to.** The trade between idle capacity and cold-start latency, with auto-suspend and idle timeouts as the lever the cost verification confirmed. State the failure mode of over-provisioning as steady invisible waste and of under-provisioning as visible queuing.

- [ ] **Step 2: Verify size, links, numbers and service names**

```bash
cd skills/iac-cloud-data-engineering/references
wc -w sizing-and-the-cost-model.md
grep -nE '\$[0-9]|[0-9]+ *(GB|TB|vCPU|cores|nodes|shards|partitions|ms|USD)/|[0-9][0-9.,]* *per month|[0-9]+ *%' sizing-and-the-cost-model.md
```
Expected: 1600–3500 words; numbers grep returns nothing — this file is the highest-risk one for the no-numbers rule, since it is about cost; then the anchored-link checker with zero BROKEN lines.

- [ ] **Step 3: Commit**

```bash
git add skills/iac-cloud-data-engineering/references/sizing-and-the-cost-model.md
git commit -m "docs(iac-cloud): add cost as shape crossed against workload shape"
```

---

### Task 5: `identity-network-and-encryption.md`

**Files:**
- Create: `skills/iac-cloud-data-engineering/references/identity-network-and-encryption.md`

**Interfaces:**
- Consumes: `2026-08-08-workload-identity-verification.md` and `2026-08-08-encryption-at-rest-verification.md` from Task 1.
- Produces: the service-identity framing that `iac-for-stateful-resources.md` assumes when it covers secrets.

- [ ] **Step 1: Write the file**

1. **Service identity vs user identity, which is the distinction that breaks pipelines.** A pipeline has nobody sitting in front of it: no MFA prompt, no session, no browser. Use the correct current term per provider from the verification, and state the pattern's purpose in the vendor's own framing — eliminating long-lived static credentials.
2. **Least privilege on a data store, where the interesting permission is bulk read.** Most access-control writing focuses on write and delete. For data platforms the exfiltration surface is a broad read grant, and it is the permission most likely to be handed out casually. Distinguish the permission to read a table from the permission to read the bucket underneath it — a grant at the storage layer can silently bypass the warehouse's own controls.
3. **Network placement.** Public endpoint versus private connectivity, and why a data store on a public endpoint is a different risk class than an application on one: the blast radius is the whole history, not one request. Keep this provider-neutral in the axis and name the private-connectivity feature per provider only where the verification confirmed the term.
4. **Encryption, and the misconception worth correcting.** Per the verification, "encrypted at rest by default" does not protect against an over-permissioned reader — it protects against physical media compromise. Say so directly; it is the most common false sense of security in this domain. Then customer-managed keys, using each provider's correct term, and the fact that key access is a separate policy surface from data access.
5. **Secrets for pipelines**, and the pointer forward: the Terraform state file itself can hold secrets in plain text — covered in `iac-for-stateful-resources.md`.

Cross-link `../../quality-data-engineering/references/data-contracts-and-schema-compatibility.md` where access boundaries and contract boundaries coincide.

- [ ] **Step 2: Verify size, links, numbers and terminology**

```bash
cd skills/iac-cloud-data-engineering/references
wc -w identity-network-and-encryption.md
grep -nE '\$[0-9]|[0-9]+ *(GB|TB|vCPU|cores|nodes|shards|partitions|ms|USD)/|[0-9][0-9.,]* *per month|[0-9]+ *%' identity-network-and-encryption.md
grep -noE "CMK|CMEK|BYOK|managed identit(y|ies)|service account|IAM role|Workload Identity" identity-network-and-encryption.md
```
Expected: 1600–3500 words; numbers grep returns nothing; every term in the third grep must appear in `2026-08-08-workload-identity-verification.md` or `2026-08-08-encryption-at-rest-verification.md` attached to the same provider. Using one provider's term for another's mechanism is a delivery-blocking defect.

- [ ] **Step 3: Commit**

```bash
git add skills/iac-cloud-data-engineering/references/identity-network-and-encryption.md
git commit -m "docs(iac-cloud): add service identity, access surface and encryption boundaries"
```

---

### Task 6: `iac-for-stateful-resources.md`

**Files:**
- Create: `skills/iac-cloud-data-engineering/references/iac-for-stateful-resources.md`

**Interfaces:**
- Consumes: `2026-08-08-terraform-lifecycle-and-state-verification.md` and `2026-08-08-iac-tooling-drift-verification.md` from Task 1; the frame from Task 2.
- Produces: the DDL boundary that `platform-archetypes.md` applies per archetype.

- [ ] **Step 1: Write the file**

This is the **only** IaC-practice file, and it earns its place solely where statefulness changes the practice. Do not write a Terraform tutorial — spec §2.5 forbids it, and the reasoning is that the base model already does that well, so a repeat buys no uplift.

1. **Open with the tool-naming decision** from the tooling-drift verification: state Terraform's current licence position and OpenTofu's existence once, say whether the advice is tool-independent, and then stop re-litigating it.
2. **Destroy protection, stated exactly as the documentation states it** — per the verification, including whether it covers replacement as well as explicit destroy, and what bypasses it. Do not write the popular simplification. Then the point that matters: protection is a guard rail, not a backup, and the resource that needs it is the one holding state.
3. **What does NOT belong in IaC (spec §2.4).** The managed resource is the *warehouse*, not the tables inside it. Table and schema DDL belongs to migrations or dbt. Give the reason concretely: with DDL in Terraform, an accidental destroy becomes a data-loss event instead of a re-provisioning event. Link `../../pipelines-architecture-data-engineering/references/dbt-project-architecture.md` for where DDL does belong.
4. **Drift on resources that legitimately change themselves.** Autoscaling means the live infrastructure diverges from the declared node count *by design*. Naively reconciling drift here fights the autoscaler; the fix is declaring the policy rather than the instantaneous value. This is the file's most practically useful section — it is a problem application infrastructure mostly does not have.
5. **Environment parity when you cannot clone production.** Staging can mirror the *shape* of prod infrastructure but not its data, so infrastructure that behaves correctly in staging can fail on prod's volume and cardinality. Say what to do instead: match the shape, accept the divergence, and test volume-sensitive behaviour elsewhere.
6. **State as a secret.** Per the verification, state can contain sensitive values in plain text. The remote backend therefore needs the same access treatment as a data store, which loops back to Task 5.

- [ ] **Step 2: Verify size, links, numbers and the DDL boundary**

```bash
cd skills/iac-cloud-data-engineering/references
wc -w iac-for-stateful-resources.md
grep -nE '\$[0-9]|[0-9]+ *(GB|TB|vCPU|cores|nodes|shards|partitions|ms|USD)/|[0-9][0-9.,]* *per month|[0-9]+ *%' iac-for-stateful-resources.md
grep -c "prevent_destroy" iac-for-stateful-resources.md
```
Expected: 1600–3500 words; numbers grep returns nothing; `prevent_destroy` appears and its described behaviour matches the Task 1 verdict verbatim — re-read the verification doc and compare, do not rely on memory.

- [ ] **Step 3: Commit**

```bash
git add skills/iac-cloud-data-engineering/references/iac-for-stateful-resources.md
git commit -m "docs(iac-cloud): add IaC practice for resources that hold state"
```

---

### Task 7: `platform-archetypes.md`

**Files:**
- Create: `skills/iac-cloud-data-engineering/references/platform-archetypes.md`

**Interfaces:**
- Consumes: the six axes from Task 3, the three workload shapes from Task 4, and all seven verification docs.
- Produces: the destination every one of the ten pointers lands on. Task 8's edits link here.

This file is the load-bearing one for the delivery: it is what the other eight skills are pointing at.

- [ ] **Step 1: Write the file**

Five archetypes, each with the **same three-part structure** — what the domain skill decides, what is decided here, and the archetype's one-way door:

1. **Streaming platform** — `streaming-data-engineering` decides partition key, ordering, consumer groups, `acks`; here decides the service, its scaling unit, and the protocol-coupling question. One-way door: a proprietary API means the client code, not just the infrastructure, is what you would have to rewrite.
2. **Distributed compute (Spark and friends)** — `spark-data-engineering` decides shuffle, joins, memory, AQE; here decides cluster shape, node type, autoscaling policy, and serverless-vs-provisioned. One-way door: mostly none, and say so — compute is the cheapest rung on the reversibility ladder, which is exactly why it should not be agonised over first.
3. **Warehouse / lakehouse** — `modeling-data-engineering` decides grain, schema and table design; `sql-data-engineering` decides the queries; here decides the platform, its billing shape, and the storage/compute separation. One-way door: the highest in the skill — proprietary table storage plus years of history plus coupled consumers.
4. **NoSQL serving store** — `modeling-data-engineering` decides single-table design and access patterns; here decides hosting, capacity mode, and replication. One-way door: the access-pattern-shaped data model does not port to a different store's model.
5. **Serving API hosting** — `pipelines-architecture-data-engineering` decides whether to serve via API at all and what the contract is; here decides where it runs and how it scales. One-way door: low. Explicitly absorb the sentence from that skill's `serving-pipeline-output.md:27`.

For each archetype, apply the six axes by name and the workload shapes by name — this file is where the vocabulary from Tasks 3 and 4 proves it was worth naming.

Cross-link, with two-level paths since this file lives in `references/`: `../../streaming-data-engineering/references/the-log-and-partitioning.md`, `../../spark-data-engineering/SKILL.md`, `../../modeling-data-engineering/references/modeling-for-access-patterns.md`, `../../pipelines-architecture-data-engineering/references/serving-pipeline-output.md`.

- [ ] **Step 2: Verify size, links, numbers, service names and reciprocity**

```bash
cd skills/iac-cloud-data-engineering/references
wc -w platform-archetypes.md
grep -nE '\$[0-9]|[0-9]+ *(GB|TB|vCPU|cores|nodes|shards|partitions|ms|USD)/|[0-9][0-9.,]* *per month|[0-9]+ *%' platform-archetypes.md
grep -oE '\]\(\.\./\.\./[^)]+\)' platform-archetypes.md | sed 's/^](//; s/)$//' | while read -r l; do [ -f "$(realpath -m "$l")" ] && echo "OK $l" || echo "BROKEN $l"; done
```
Expected: 1600–3500 words; numbers grep returns nothing; every cross-skill link `OK` and every one of them two levels deep. Then confirm all five archetypes are present and each one names a domain skill it defers to — an archetype with no reciprocal boundary is an invasion.

- [ ] **Step 3: Commit**

```bash
git add skills/iac-cloud-data-engineering/references/platform-archetypes.md
git commit -m "docs(iac-cloud): add the five platform archetypes that absorb the forward-pointers"
```

---

### Task 8: `SKILL.md` and the ten boundary edits

**Files:**
- Create: `skills/iac-cloud-data-engineering/SKILL.md`
- Modify: `skills/spark-data-engineering/SKILL.md:3` and `:21`
- Modify: `skills/modeling-data-engineering/SKILL.md:3` and `:23`
- Modify: `skills/streaming-data-engineering/SKILL.md:3` and `:22`
- Modify: `skills/data-engineering/SKILL.md:3`, `:16` and `:22`
- Modify: `skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md:27`

**Interfaces:**
- Consumes: all six reference files from Tasks 2–7.
- Produces: the routable skill and the closed boundaries that Task 9 measures.

- [ ] **Step 1: Re-enumerate the pointers with two independent patterns before editing**

The spec's table says ten. Do not trust it — the first enumeration during design said six, because a single grep pattern missed two differently-worded lines. Confirm independently:

```bash
cd /home/leonardo-garcia/dev/data-engineering-skills
echo "--- pattern A: the domain ---"
grep -rniE "iac|infrastructure as code|terraform" --include="*.md" skills/ | grep -viE "dbt-project|serving-pipeline"
echo "--- pattern B: the absence ---"
grep -rniE "no skill|does not exist|doesn't exist|not exist yet|suite yet|is planned" --include="*.md" skills/
```
Expected: the union, after excluding `data-engineering/SKILL.md:14` and `:36` (both verified as keepers in spec §2.2), is exactly the ten rows in the spec's table. **If the count is not ten, stop and reconcile before editing anything** — a missed pointer ships a dead reference to a skill that now exists, which is the mirror image of the phantom-skill bug.

- [ ] **Step 2: Write `SKILL.md`**

Structure, matching the eight delivered skills:

- **Frontmatter**: `name: iac-cloud-data-engineering`, and a description carrying — the domain enumeration (service selection, sizing, cost shape, identity/network/encryption, IaC for stateful resources, platform archetypes); jargon-free triggers alongside technical ones ("the warehouse bill tripled last month", "the pipeline can't reach the database", not only "choose between MSK and Kinesis"); the co-invocation clause verbatim from Global Constraints; and boundaries as conditionals pointing at the domain skills — partition keys to `streaming`, job tuning to `spark`, schema design to `modeling`, DAG design to `pipelines`. Keep it ≤ 1024 characters *including* the rest of the frontmatter.
- **Overview**: the statefulness frame in two or three sentences.
- **When to use**: the trigger list, plus `Not for` lines returning each neighbouring domain to its owner, plus the two scope exclusions — no Terraform syntax tutorial, no Kubernetes.
- **Quick reference**: a six-row table, one per reference file, each with a situation and what to reach for.
- **Common mistakes**: at least five rows. Include, because each is sourced from this delivery's verifications or the spec: putting table DDL in Terraform; reading "encrypted at rest" as protection against an over-permissioned reader; agonising over the compute engine (cheap to reverse) before the storage platform (expensive); fighting an autoscaler's legitimate drift; and choosing a service by product name rather than by billing shape.

- [ ] **Step 3: Make the ten edits**

Each edit replaces a statement that the domain has no skill with a pointer to the real one. Keep every edit minimal — replace the clause, do not rewrite the sentence around it, because four of the ten are descriptions and description changes are what Task 9 has to re-measure.

The four descriptions: `spark:3`, `modeling:3`, `streaming:3`, `data-engineering:3`. The orchestrator's also gains `iac-cloud-data-engineering` in its domain list, taking it from eight to nine.

The six body lines: `spark:21`, `modeling:23`, `streaming:22`, `data-engineering:16`, `data-engineering:22`, `pipelines/references/serving-pipeline-output.md:27`. For the last one, the replacement points at `../../iac-cloud-data-engineering/references/platform-archetypes.md` — two levels, because the file lives in `references/`.

Do **not** touch `data-engineering/SKILL.md:14` or `:36`.

- [ ] **Step 4: Validate the manifest, the links and the absence of dead phrases**

```bash
cd /home/leonardo-garcia/dev/data-engineering-skills
claude plugin validate .
awk '/^---$/{n++; next} n==1{c+=length($0)+1} END{print "frontmatter chars: "c}' skills/iac-cloud-data-engineering/SKILL.md
grep -rniE "no skill in this suite|does not exist yet|is planned but" --include="*.md" skills/
ls skills/iac-cloud-data-engineering/references/ | while read -r f; do grep -q "$f" skills/iac-cloud-data-engineering/SKILL.md && echo "LINKED $f" || echo "ORPHAN $f"; done
```
Expected: validate passes; frontmatter under 1024; the dead-phrase grep returns **nothing**; all six references print `LINKED`. Then run the anchored-link checker from Global Constraints in both `skills/iac-cloud-data-engineering/` and `skills/iac-cloud-data-engineering/references/`.

- [ ] **Step 5: Commit**

```bash
git add skills/
git commit -m "feat(iac-cloud): add the skill router and close the ten forward-pointers"
```

---

### Task 9: Behavioural measurement

**Files:**
- Modify: `tests/triggering/matrix.tsv` — new positive and discriminator cases
- Modify: `tests/triggering/matrix-adversarial.tsv` — A9 ground truth, new no-jargon and negative cases
- Create: `tests/triggering/baselines/2026-08-08-iac-routing.md`

**Interfaces:**
- Consumes: the delivered skill and the ten edits from Task 8.

The skill is not delivered until it routes. This is the acceptance gate. Read `tests/triggering/README.md` before running anything — it documents the traps that invalidated real runs.

- [ ] **Step 1: Change the ground truth this skill invalidates**

`A9` in `matrix-adversarial.tsv` is currently `gap-iac` expecting `NONE`; its prompt asks for Terraform for a Snowflake warehouse with roles and compute warehouses. Its `EXPECTED` becomes `iac-cloud-data-engineering`, and its `CATEGORY` becomes `positive`. This is the single case that validates the whole delivery.

The change is decided **now**, before any run, because the world changed — a skill that did not exist now does. That is categorically different from editing an expectation after seeing a result you did not like, which Step 5 forbids.

- [ ] **Step 2: Leave `A11` alone until the reps are in**

`A11` — "expose the warehouse as a REST API for the mobile app" — currently expects `NONE|pipelines-architecture-data-engineering`. The architectural decision to serve via API stays with `pipelines`; only the *hosting* moves here, so it is genuinely ambiguous whether `iac-cloud-data-engineering` belongs in its expected set.

Do **not** widen it now. Run it unchanged in Step 4 and decide with the reps in hand. If it routes to `iac-cloud` consistently across three reps, widening the set is a defensible ground-truth change and gets recorded as such in the digest with its rate; if it is split, leave it and note the split. Widening it up front would guarantee a pass and prove nothing.

- [ ] **Step 3: Add new cases**

Append to `matrix.tsv`:

```
P10	positive	iac-cloud-data-engineering	Vamos a montar la plataforma de datos en la nube. ¿Uso un warehouse serverless o uno con cluster aprovisionado?
D9	discriminator	iac-cloud-data-engineering	Necesito decidir entre MSK, Kinesis y Kafka autogestionado para el pipeline de eventos. ¿Cuál elijo?
D10	discriminator	spark-data-engineering	Mi job de Spark tarda demasiado en el shuffle y quiero saber si agrando el cluster o cambio el código.
```

Append to `matrix-adversarial.tsv`:

```
A14	no-vocab	iac-cloud-data-engineering	La factura del almacén de datos se triplicó el mes pasado y nadie sabe por qué.
A15	gap-ml	NONE	Necesito montar un feature store para servir features a un modelo en tiempo real durante el entrenamiento.
```

`D9` is the discriminator that matters most: it names a streaming concern but asks a selection question, so it tests the boundary `streaming` just ceded. `D10` is its mirror — it names a cluster but asks a tuning question, and must **not** route to `iac-cloud`; a boundary that only works in one direction is not a boundary. `A14` describes a cost-model problem with no infrastructure vocabulary at all. `A15` replaces the `gap-*` coverage that `A9` stops providing, since ML/feature-store infrastructure remains outside the suite.

- [ ] **Step 4: Run the full matrix with reps**

Full re-measure, per spec §6: a ninth entry changes the skill listing that every routing decision reads, so the perturbation is not confined to the four descriptions edited.

```bash
cd tests/triggering
awk -F'\t' 'NR>1{n++} END{print n" cases in matrix.tsv (expect 24)"}' matrix.tsv
awk -F'\t' 'NR>1{n++} END{print n" cases in matrix-adversarial.tsv (expect 15)"}' matrix-adversarial.tsv
./run-matrix.sh -m opus -a with -r 3 -j 1 -o results/iac-delivery
./rescore.sh results/iac-delivery matrix.tsv matrix-adversarial.tsv
```
Expected: 39 cases total. `A9`, `P10`, `D9` and `A14` route to `iac-cloud-data-engineering`; `D10` holds `spark-data-engineering`; `A15` holds `NONE`; and every pre-existing case holds its prior verdict, with the four edited descriptions — `spark` (P3, A4, A5, D10), `modeling` (P4, D7, A3, A7), `streaming` (P9, D6, D8, A8, A13) and the orchestrator (P8, A10) — under the closest watch.

Score with `rescore.sh`, never the live verdict: the live one reads position 1 only, and a correct session here often chains a superpowers process skill first. Scoring position 1 once manufactured a "systemic crowd-out" finding that did not exist.

Keep `-j 1`. This box is 6 GB WSL2 and has OOM'd mid-campaign; the run takes roughly an hour and must not be parallelised.

- [ ] **Step 5: If a case fails, fix the description and re-measure — do not lower the expectation**

A failing new case means the description does not reach that prompt: adjust it using the measured patterns from Global Constraints and re-run. A failing *regression* case means a Task 8 edit broke a neighbour, which is more serious and blocks delivery.

Do not change a case's `EXPECTED` to match observed behaviour. That converts a measurement into a tautology.

Known exception, not to be re-diagnosed: `A2` is FLAKY at ~50% over 10 reps and was already flaky before streaming shipped. If it fails here it is not evidence of a regression from this delivery. Any fix for it belongs in a body or in the case's wording, **never in a description** — the prior 19/19 was measured against those.

- [ ] **Step 6: Write the baseline digest**

Record in `tests/triggering/baselines/2026-08-08-iac-routing.md`: the `rescore.sh` output verbatim, `A9`'s changed ground truth with its pre-delivery behaviour, the five new cases with their verdicts, and the full regression set. State the model, the rep count, and the date. If any case was flaky, say so with its rate rather than rounding it to a pass — and state plainly that the row count is 39, so that the digest cannot later be read as covering a different set.

- [ ] **Step 7: Commit**

```bash
git add tests/triggering/
git commit -m "test(triggering): measure iac-cloud routing and re-verify all nine boundaries"
```

---

## What invalidates this delivery

- Any claim in a reference file that its verification doc marked UNSUPPORTED, or that states the popular simplification where the source stated something more precise — `prevent_destroy`'s scope and Spark's late-data behaviour are both precedents for this exact failure.
- **Any number in a reference file**: a price, a limit, a quota, an instance type, a node count. The no-numbers rule is not stylistic; it is what keeps the skill from rotting into wrongness.
- **Any named service with no verdict in the research corpus.** Six writers shipped one of these on the last delivery and two were factually wrong. This skill is almost entirely service names.
- A frontmatter over 1024 characters, or one that fails `claude plugin validate`.
- Any surviving phrase claiming a data-engineering domain has no skill in this suite. After this delivery the suite is 9/9 and every such sentence is false.
- A new case that does not route, or a regression case that changed verdict, with the expectation edited to match rather than the description fixed.
- Measurement at one rep, or scored from the live verdict rather than `rescore.sh`. Both are mistakes this repo has already paid for.
- A claim of measured *quality* uplift. The instrument is VOID at r=0.61 with the cause unresolved; this delivery's evidence is content verification and routing, and saying otherwise overstates it.
