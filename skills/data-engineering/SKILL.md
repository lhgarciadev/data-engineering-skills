---
name: data-engineering
description: Cross-domain router for data engineering tasks that span more than one domain — designing or reviewing an end-to-end pipeline, evaluating a full data platform, or any request that touches two or more of python, sql, spark, data-modeling, pipelines-architecture, streaming, data-quality, or iac-cloud at once. For a single-domain task (e.g. "review this PySpark job", "optimize this SQL query"), use that domain's skill directly instead — this orchestrator adds no value there.
---

# Data Engineering (Orchestrator)

## Overview

Entry point for data engineering tasks that cross domain boundaries. Identifies which domain skills apply, dispatches one subagent per domain to analyze independently, then synthesizes — surfacing the cross-domain interactions a single-lens analysis would miss.

## When to use

- A request explicitly spans multiple domains ("design this pipeline end-to-end: Kafka → PySpark → warehouse, with data quality checks, deployed via Terraform")
- Reviewing a full data solution rather than one component
- Not for single-domain tasks — let that domain's own skill trigger directly (`python`, `sql`, `spark`, `data-modeling`, `pipelines-architecture`, `streaming`, `data-quality`, `iac-cloud`)

## Process

1. **Identify relevant domains.** Read the request and list which of the 8 domain skills apply. If only one applies, stop and use that skill directly instead of continuing here.
2. **Dispatch one subagent per relevant domain, in parallel when your environment supports it.** Each subagent's prompt must: name the specific domain skill to read first, quote the slice of the original request relevant to that domain, and ask for a focused analysis from that lens only — not a full solution. If your environment does not support parallel or background subagent dispatch, perform each domain's analysis in sequence within this session instead of skipping any.
3. **Synthesize.** Combine the per-domain analyses into one answer. Do not just concatenate them — explicitly call out interactions between domains that no single analysis would see (a partition scheme in `spark` that conflicts with a clustering key decision in `sql`; a Terraform-provisioned resource in `iac-cloud` that a `streaming` consumer assumes already exists). If a domain you identified in step 1 has no installed skill yet in your environment, say so explicitly in the synthesis instead of silently presenting the analysis as complete.

## What this skill does not do

- Does not execute code changes, open PRs, or run any build/deploy step — this suite is reference and design guidance, not an execution pipeline.
- Does not replace the domain skills — it routes to them and combines their output.

## Common mistakes

| Mistake | Fix |
|---|---|
| Triggering this for a single-domain question | Use that domain's skill directly — this adds dispatch overhead for no benefit |
| Dispatching subagents with the full original request instead of a domain-scoped slice | Each subagent should get only the piece relevant to its domain, plus the domain skill name to read |
| Concatenating subagent outputs without synthesis | Explicitly name cross-domain interactions — that's the reason this skill exists instead of just reading multiple skills serially |
| Presenting the synthesis as complete when a relevant domain's skill isn't installed yet | Name the gap explicitly — this suite ships incrementally, so this will happen often at first |
