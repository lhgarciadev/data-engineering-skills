# Data Contracts

## A minimal contract file, versioned with the code

A data contract is a small, structured file that states what a data product is, who owns it, and who/what depends on it — living in the same repo and the same pull requests as the code that produces the data, instead of in a wiki that drifts out of sync the first time nobody remembers to update it.

```yaml
# datacontract/my_ingestion_package.yaml
service_id: my_ingestion_package
version: "1.0"
governance:
  product_name: "Human-readable name of what this produces"
  domain: sales
  subdomain: orders
  consumers: []              # who reads this output — fill in as they're onboarded
  expected_inputs: []        # upstream sources this depends on
  expected_outputs: []       # tables/topics/files this produces
data_models: []               # schema references, once they're stable enough to pin
```

## Why it's worth it even mostly empty

A contract that starts with most fields as empty lists is still worth creating, for two reasons: the file's existence is itself a commitment ("this data product has an owner and a documented shape, ask here first"), and it gives every future addition — a new consumer, a new upstream dependency — an obvious place to land instead of a wiki page nobody remembers exists.

**The failure mode to avoid**: a contract file created once and never revisited. An empty `consumers: []` six months after three teams started depending on this data product is worse than not having the file — it actively tells a reader "nobody consumes this" when the opposite is true. Update it in the same pull request that adds a consumer or a new upstream dependency, the same discipline as updating a test alongside the code it covers.

## What belongs here vs. elsewhere

- **Ownership and dependency metadata** (this file): who owns it, who consumes it, what it depends on.
- **The actual schema** (in code, not here): keep column-level types and descriptions next to the transformation code that produces them — a `schemas/` directory with `source_schema.py`/`target_schema.py`, see `package-layout.md`. Reference the schema from the contract once it's stable, don't duplicate it field-by-field in YAML.
- **The architectural decision of how this data is served** (warehouse table, API, stream, export): [pipelines-architecture-data-engineering's serving-pipeline-output.md](../../pipelines-architecture-data-engineering/references/serving-pipeline-output.md), not this file.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Creating the contract file once and never updating it | An empty `consumers: []` months after three teams depend on the data actively misleads a reader | Update it in the same PR that adds a consumer or upstream dependency |
| Duplicating the full column schema inside the contract YAML | Two places to keep in sync; they drift the first time one is updated without the other | Keep the schema in code, reference it from the contract once stable |
| Treating the contract as a substitute for the serving-layer decision | The contract records *what* the data is, not *how* it should be delivered | See `pipelines-architecture-data-engineering`'s `serving-pipeline-output.md` for that decision |
