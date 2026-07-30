# Airflow Task States, Trigger Rules, and Branching

Nearly every "why didn't my task run" bug reduces to one primitive: task state, and how each task reacts to its parents' states via its `trigger_rule`. Master that and the rest of this file follows directly.

## Task states

A task ends in one of several states — `success`, `failed`, `skipped`, `upstream_failed`, among others. If you've seen `shutdown` mentioned as a task state, drop it: it was marked deprecated in **2.7.2** (kept in the codebase for backward compatibility, with a `# TODO: Remove in Airflow 3.0` comment) but stayed present through the rest of the 2.x series, and was only actually removed in **3.0.0** — so it isn't part of the current state machine. A newer addition worth knowing about is `awaiting_input`, added in 3.3.0 for Human-in-the-Loop tasks — a different feature, not something to dig into here.

## Trigger rules

Each task decides whether to run based on its parents' states — that decision is `trigger_rule`, and its default is `all_success`: a task only runs if every parent succeeded. That default causes most "why did my task get skipped" surprises, including the branching trap below.

Airflow's official catalog has **13** trigger rules total. The seven below (across six rows — one row covers two rules) are the ones worth having at your fingertips — don't present them as the whole list:

| Trigger rule | Runs when |
|---|---|
| `all_success` (default) | All parents succeeded |
| `all_done` | All parents finished, regardless of outcome — the cleanup pattern: a task that tears down an ephemeral cluster or releases a resource needs `all_done` so it runs even if the job failed |
| `none_failed` | No parent failed (skips are OK) |
| `none_failed_min_one_success` | No parent failed AND at least one succeeded (not just skips) — the join-after-branch pattern below |
| `one_success` / `one_failed` | Runs as soon as *one* parent reaches that state, without waiting for the rest — `one_failed` is the alert/fallback-path pattern |
| `always` | Runs no matter what |

The remaining six — `all_failed`, `all_skipped`, `one_done`, `all_done_min_one_success`, `all_done_setup_success`, and `none_skipped` — cover narrower cases; check Airflow's trigger-rule reference when one of the seven above doesn't fit.

One rename worth knowing if you read older code or tutorials: `none_failed_min_one_success` was called `none_failed_or_skipped` before **Airflow 2.2.0** — the old name is fully gone as of 3.0.

Closing point: almost no "task skipped unexpectedly" bug is a code bug — it's a mis-chosen trigger rule. Naming the right trigger rule for a convergence or cleanup node is a direct signal of hands-on DAG experience.

## Branching

The pattern for the DAG to choose a path at runtime. Three operators:

**`@task.branch`** (and the older `BranchPythonOperator`) — runs logic and returns the `task_id` (or list of them) of the branch to follow; branches not chosen end up `skipped`. The canonical data case: deciding full vs. incremental load, or routing based on a condition in the data.

```python
from airflow.sdk import task

@task.branch
def choose_load_strategy(**context):
    if is_first_run(context["data_interval_start"]):
        return "full_load"
    return "incremental_load"
```

**`ShortCircuitOperator`** — if the condition is false, skips everything downstream. A guard clause: "if there's no new data, don't continue."

**`LatestOnlyOperator`** — skips downstream tasks on runs that aren't the most recent one — i.e., during a backfill. The pattern for things you don't want re-triggered historically (a live notification, refreshing a live dashboard) while backfilling everything else.

## The join-after-branch trap

The single most-asked question on this topic, and it's a trap Airflow's own documentation walks through explicitly — not just production folklore. When branches reconverge at a join task, that join carries the default `all_success`. One of its parent branches ended up `skipped` — and `all_success` treats a skip as "not satisfied," so the join *also* gets skipped, silently. Airflow's own docs use exactly this shape (a `join` task downstream of `branch_a`/`follow_branch_a`) to teach the fix: give the join `trigger_rule="none_failed_min_one_success"`.

```python
from airflow.providers.standard.operators.empty import EmptyOperator

join = EmptyOperator(
    task_id="consolidate",
    trigger_rule="none_failed_min_one_success",
)
[full_load, incremental_load] >> join
```

Naming this before anyone asks — "watch out, the join after a branch needs its trigger rule changed or it'll skip" — is one of the cleanest signals that you've actually built DAGs, because it's the kind of thing you only know from having been bitten by it.
