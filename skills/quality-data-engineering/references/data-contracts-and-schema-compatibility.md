# Data Contracts and Schema Compatibility

Most quality incidents don't start in your pipeline — they start upstream, when a producer changes a field, renames a column, or changes a type without warning. A data contract shifts responsibility for catching that onto the producer, before it ships: an explicit, versioned agreement about what a dataset looks like, checked automatically in the producer's own CI/CD.

## The Data Contract Specification

The open [Data Contract Specification](https://github.com/datacontract/datacontract-specification) is the concrete, documented shape of this idea. Its root fields are `dataContractSpecification` (the spec version, e.g. `1.2.1`), `id`, `info`, `servers`, `terms`, `models`, `definitions`, and `servicelevels` — no `apiVersion`/`kind` (a Kubernetes convention, not part of this spec — a mistake that shows up in some third-party summaries of this format).

Structural constraints and quality checks are two separate blocks, not one. `required`, `unique`, `primaryKey`, `type`, and `references` live directly on each field:

```yaml
models:
  orders:
    fields:
      order_id:
        type: string
        required: true
        unique: true
        primaryKey: true
      customer_id:
        type: string
        required: true
        references: customers.customer_id
```

`quality` is a separate object, with four variants selected by `type`/`engine` — free text (a natural-language description, "usable as a prompt for an AI engine to check"), a raw SQL check compared against a threshold, a predefined agnostic metric aligned with ODCS 3.1 (`nullValues`, `missingValues`, `invalidValues`, `duplicateValues`, `rowCount`), or a delegated check to an external engine — currently `soda` or `great-expectations`:

```yaml
models:
  orders:
    fields:
      order_id:
        quality:
          - type: custom
            engine: great-expectations
            implementation:
              expectation_type: expect_column_values_to_be_unique
```

`servicelevels` (all-lowercase, one word) has seven documented sub-objects with concrete fields — not an abstract "SLA":

```yaml
servicelevels:
  availability:
    description: The server is available during support hours
    percentage: 99.9%
  freshness:
    description: The age of the youngest row in the table
    threshold: 25h
    timestampField: orders.order_timestamp
  latency:
    description: Time from source event to availability for consumers
    threshold: 25h
    sourceTimestampField: orders.order_timestamp
    processedTimestampField: orders.processed_timestamp
```

(The other four — `retention`, `frequency`, `support`, `backup` — cover how long data is kept, how often it updates, when support is reachable, and backup/recovery targets.)

## Enforcing compatibility: Confluent Schema Registry

For streaming data specifically, Confluent Schema Registry enforces compatibility between schema versions before a producer is allowed to register a new one. Seven compatibility modes control exactly what kind of change is allowed:

| Mode | Protects | Add optional field | Remove optional field | Add required field | Widen a scalar type |
|---|---|---|---|---|---|
| `BACKWARD` (default) | New-schema consumers can still read data written with the previous schema | ✔ | ✔ | | |
| `FORWARD` | Old-schema consumers can still read data written with the new schema | ✔ | ✔ | ✔ | ✔ |
| `FULL` | Both directions, against the immediately previous schema only | ✔ | ✔ | | |
| `*_TRANSITIVE` variants | Same guarantee, checked against *every* previous version, not just the last one | same as base mode | same as base mode | same as base mode | same as base mode |
| `NONE` | Nothing — compatibility checks disabled | — | — | — | — |

Widening or narrowing a scalar type is **not** compatible under `FULL` — it's one-directional (`FORWARD` for widening, `BACKWARD` for narrowing), which contradicts the common assumption that widening a type is always safe on both sides.

This isn't a soft warning: registering an incompatible schema against `POST /subjects/{subject}/versions` returns `409 Conflict`, and since producers auto-register new schemas by default (`auto.register.schemas`), an incompatible change fails the produce call itself, not just a lint step.

## Avro schema evolution rules

Apache Avro's own "Schema Resolution" rules are more specific than "add fields, don't remove or change them":

- Adding a field to the **reader**'s schema is safe **only if that field has a `default`** — without one, Avro signals an error rather than guessing a value.
- Removing a field that the **writer** had is **always safe** — the writer's value for it is simply ignored, regardless of whether it had a default.
- Changing a field's type is safe only within a closed list of promotions: `int`→`long`/`float`/`double`, `long`→`float`/`double`, `float`→`double`, and `string`↔`bytes`. Anything outside that list is an error.
- Renaming a field behaves like removing the old name and adding a new one — unsafe by the two rules above — unless the schema declares an explicit `aliases` entry mapping the old name to the new one.

## Enforcing contracts in CI/CD

Two first-party tools implement "producer CI fails before a breaking change ships" for real, in two different ecosystems — not one universal standard:

- **Confluent Schema Registry Maven Plugin**, goal `test-compatibility` (and, from Confluent Platform 7.2.0, `test-local-compatibility` for faster local feedback before CI) — checks a schema on disk against what's registered.
- **Data Contract CLI**, via its official `datacontract-action` GitHub Action:

```yaml
- name: Data Contract Tests
  uses: datacontract/datacontract-action@main
  with:
    location: datacontract.yaml
    server: all
    junit-test-report: TEST-datacontract.xml
```

The Data Contract Specification itself doesn't define its own compatibility modes — any backward/forward-compatibility guarantee comes from the schema technology the contract references (Avro, Protobuf, JSON Schema) or from the CI tool's own change classification, not from the contract document's format.

A third enforcement point sits in neither place: the ingestion library. dlt's `schema_contract` applies the same four-way decision this suite frames as fail/quarantine/drop/repair, per schema entity — `tables`, `columns`, `data_type` — through the modes `freeze` (raise, load nothing), `discard_row`, `discard_value`, and `evolve` (accept). Two properties decide how much weight it can carry. **The default is `evolve` on all three entities**, so out of the box every change is accepted. And a table the library has not created yet counts as new, which forces the column mode to `evolve` for that run regardless of what you configured. Ingestion-time enforcement is real and worth having, but it fires after the producer already shipped the change — it complements producer-side CI rather than replacing it, and it is the only one of the three that cannot fail a build.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Writing a data contract with `apiVersion`/`kind` fields | Not part of the real Data Contract Specification — a Kubernetes convention mistakenly carried over from an unverified example | Use the real root fields: `dataContractSpecification`, `id`, `info`, `servers`, `models`, `servicelevels` |
| Putting `required`/`unique` checks inside the `quality` block | Those are structural Field Object attributes, evaluated separately from `quality` | Declare `required`/`unique`/`primaryKey` directly on the field; reserve `quality` for text/SQL/library/custom-engine checks |
| Assuming widening a scalar type is always safe on both sides | Confluent's own compatibility table shows widening is one-directional (`FORWARD` only), not compatible under `FULL` | Check the specific compatibility mode's table before assuming a type change is safe |
| Assuming any field addition is a safe Avro change | Only safe if the new field has a `default` — without one, Avro signals an error | Always give a new field a `default` if older data needs to keep reading under the new schema |
