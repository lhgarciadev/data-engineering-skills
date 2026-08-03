# Failure Response Policies

Detecting a quality problem is half the job. The other half — where the real judgment lives — is deciding what happens to the pipeline and the bad records once you've detected it.

## The spectrum of responses

- **Fail/abort** — stop the whole pipeline. Right when the risk of letting bad data through outweighs the cost of a delay (financial figures, a primary-key violation).
- **Quarantine** — let good records through, divert bad ones somewhere inspectable, without silently dropping them.
- **Drop with alert** — discard the bad records but log metrics and notify someone. Acceptable when a small amount of garbage is tolerable and latency matters more.
- **Default/repair** — fill in or correct the value (a `COALESCE` to a default, imputation). The riskiest option: it masks the problem rather than surfacing it, and should only be used with an explicit, documented reason.

## Thresholds, not absolutes

Rarely is the right answer "zero bad rows or abort." dbt's own test configuration is built around exactly this idea — a tolerable threshold, not a binary pass/fail:

```yaml
models:
  - name: orders
    columns:
      - name: customer_id
        tests:
          - not_null:
              config:
                severity: error
                error_if: ">10"
                warn_if: ">1"
```

`severity` is `error` (the default) or `warn`. With `severity: error`, dbt checks `error_if` first (default `!=0`) and only falls through to `warn_if` if that passes. With `severity: warn`, `error_if` is skipped entirely.

The number `error_if`/`warn_if` compares against is controlled by `fail_calc`, whose **default is `count(*)`** — an absolute row count, not a percentage. A threshold phrased as "abort past 5% failing rows" needs an explicit `fail_calc` expression that computes that percentage; writing `error_if: ">5"` on its own compares against a raw failing-row count, not 5% of anything.

## Quarantine: mark, don't silently drop

None of the three systems below — dbt, AWS Glue Data Quality, Databricks — quarantine data with a single automatic click. All three use the same underlying skeleton: compute a boolean flag per row, then separate based on that flag.

dbt's version stores the failing rows from a test, for inspection:

```yaml
data_tests:
  +store_failures: true
  +store_failures_as: table   # or `view`, or `ephemeral` (default — nothing persisted)
```

Failures land in a table/view named after the test, in the `{schema}_dbt_test__audit` schema by default. This is evidence of *what* failed, not necessarily rows already stripped out of the model itself — the model still builds normally unless it filters on that condition itself.

AWS Glue Data Quality's `EvaluateDataQuality` transform adds a `DataQualityEvaluationResult` column ("Passed"/"Failed") to every row, and the pipeline filters explicitly:

```python
rowLevelOutcomes_df = rowLevelOutcomes.toDF()
passed = rowLevelOutcomes_df.filter(
    rowLevelOutcomes_df.DataQualityEvaluationResult == "Passed"
)
```

Databricks' Lakeflow Declarative Pipelines document the same pattern under the name "Quarantine invalid records" — an `is_quarantined` boolean, computed from the negation of the validity rules, on a temporary table partitioned by that column, with two downstream views filtering on it:

```python
from pyspark import pipelines as dp
from pyspark.sql.functions import expr

rules = {"valid_customer_id": "(customer_id IS NOT NULL)"}
quarantine_rules = "NOT({0})".format(" AND ".join(rules.values()))

@dp.table(temporary=True, partition_cols=["is_quarantined"])
@dp.expect_all(rules)
def orders_quarantine():
    return spark.readStream.table("raw_orders").withColumn(
        "is_quarantined", expr(quarantine_rules)
    )

@dp.view
def valid_orders():
    return spark.read.table("orders_quarantine").filter("is_quarantined=false")

@dp.view
def invalid_orders():
    return spark.read.table("orders_quarantine").filter("is_quarantined=true")
```

## Drop with alert

Great Expectations' current Checkpoint API (1.x) offers 7 reactive Actions, each notifying a channel when validation fails — most take a `notify_on` parameter you can pin to `"failure"`:

```python
import great_expectations as gx
from great_expectations.checkpoint import SlackNotificationAction, UpdateDataDocsAction

action_list = [
    SlackNotificationAction(
        name="alert_on_failed_expectations",
        slack_token="${validation_slack_webhook}",
        slack_channel="${validation_slack_channel}",
        notify_on="failure",
        show_failed_expectations=True,
    ),
    UpdateDataDocsAction(name="update_all_data_docs"),
]
checkpoint = gx.Checkpoint(
    name="orders_checkpoint",
    validation_definitions=[validation_definition],
    actions=action_list,
)
context.checkpoints.add(checkpoint)
```

The other five are `EmailAction`, `PagerdutyAlertAction`, `MicrosoftTeamsNotificationAction`, `OpsgenieAlertAction`, and `SNSNotificationAction`, plus `APINotificationAction` for a custom webhook. If you've seen `StoreValidationResultAction` referenced elsewhere, it no longer exists in the current API — it was part of the pre-2024 (V0) Checkpoint API and was removed, not just deprecated.

## Choosing a policy: the asymmetric cost of being wrong

The right policy for a given check depends on which mistake costs more: aborting unnecessarily and delaying a delivery, or letting a doubtful record through. This is an application of a general decision-theory idea — cost-sensitive classification, the same asymmetry that shows up in Neyman-Pearson hypothesis testing — applied to a data-quality decision, not a framework specific to data engineering. A dashboard fed by a nightly batch can usually tolerate a warn-and-quarantine policy; a table feeding financial reporting usually can't.

## Common mistakes

| Mistake | Why it hurts | Fix |
|---|---|---|
| Writing `error_if: ">5"` expecting it to mean "5% of rows" | `fail_calc` defaults to `count(*)` — an absolute count, not a percentage | Write an explicit `fail_calc` expression that computes the percentage, or phrase the threshold as an absolute count |
| Assuming `store_failures` removes bad rows from the model | It stores a copy of what failed, in an audit table — the model itself still builds with all rows unless it filters on the condition itself | Read `store_failures` as "evidence," not "cleanup"; filter explicitly if the model needs to exclude bad rows |
| Expecting a one-click "quarantine table" feature from any vendor | AWS Glue, Databricks, and dbt all quarantine via a flag column plus explicit filtering — none does it automatically | Plan for writing the flag + filter logic yourself, in whichever of these three systems you're using |
| Using `StoreValidationResultAction` from an old Great Expectations example | Removed from the current (1.x) API, not just deprecated | Use the 7 current Actions (`UpdateDataDocsAction`, `SlackNotificationAction`, `EmailAction`, `PagerdutyAlertAction`, `MicrosoftTeamsNotificationAction`, `OpsgenieAlertAction`, `SNSNotificationAction`, `APINotificationAction`) |
