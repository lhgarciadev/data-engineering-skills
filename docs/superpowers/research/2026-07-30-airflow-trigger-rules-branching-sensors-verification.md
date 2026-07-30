# Research: task-state model, trigger rules, branching, sensors y deferrable operators en Apache Airflow

**Fecha:** 2026-07-30
**Alcance:** verificación de 13 claims técnicas sobre Airflow (task-state model, trigger rules, operadores de branching, sensors y el par deferrable-operator/triggerer) contra la documentación OFICIAL de Apache Airflow — `https://airflow.apache.org/docs/apache-airflow/stable/` y, para providers, `https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/`, `https://airflow.apache.org/docs/apache-airflow-providers-standard/stable/` y `https://airflow.apache.org/docs/apache-airflow-providers-common-sql/stable/`. No se escribió contenido en ningún skill del suite — solo este research file.

**Nota de corrección posterior (2026-07-30, revisión de cierre):** este documento describe más abajo el retiro de `shutdown` como "removido en 2.7.2". Una verificación de seguimiento encontró que esa formulación es imprecisa: `shutdown` fue **deprecado** en 2.7.2 (marcado como estado no usado, pero dejado en el código con un comentario `# TODO: Remove in Airflow 3.0`) y solo fue **removido** de verdad en **3.0.0**. El contenido shippeado del skill (`skills/pipelines-architecture-data-engineering/references/airflow-trigger-rules-and-branching.md`) ya refleja la versión corregida (deprecado en 2.7.2, removido en 3.0.0). Los hallazgos originales de este documento se dejan intactos más abajo como registro histórico de la verificación.

**Hallazgo estructural que atraviesa todo el documento:** la documentación "stable" actual corresponde a **Apache Airflow 3.3.0** (confirmado por fetch directo de `index.html`, campo "Version: 3.3.0" en el selector de versión de la página). Airflow 3.x movió una cantidad significativa de superficie pública — `ExternalTaskSensor`, `SqlSensor`, `LatestOnlyOperator`, `ShortCircuitOperator`, `BranchPythonOperator`, `BaseSensorOperator` — fuera del paquete núcleo `airflow.*` hacia el paquete provider `apache-airflow-providers-standard` (o, para `SqlSensor`, `apache-airflow-providers-common-sql`) y hacia el nuevo **Task SDK** (`airflow.sdk.*`). Esto afecta directamente varias de las claims que asumían ubicaciones "core Airflow" — se marca explícitamente en cada caso.

---

## 1. Estados de tarea y trigger rules (claims 1–3)

### Claim 1 — Catálogo de `TaskInstanceState`

**VERIFIED, con una corrección de contenido.**

La lista canónica de estados, confirmada por fetch directo de la página de conceptos de Tasks (Airflow 3.3.0):

> "`none`: The Task has not yet been queued for execution (its dependencies are not yet met)
> `scheduled`: The scheduler has determined the Task's dependencies are met and it should run
> `queued`: The task has been assigned to an Executor and is awaiting a worker
> `running`: The task is running on a worker (or on a local/synchronous executor)
> `success`: The task finished running without errors
> `restarting`: The task was externally requested to restart when it was running
> `failed`: The task had an error during execution and failed to run
> `skipped`: The task was skipped due to branching, LatestOnly, or similar
> `upstream_failed`: An upstream task failed and the Trigger Rule says we needed it
> `up_for_retry`: The task failed, but has retry attempts left and will be rescheduled
> `up_for_reschedule`: The task is a Sensor that is in `reschedule` mode
> `deferred`: The task has been deferred to a trigger
> `awaiting_input`: The task is a Human-in-the-loop task waiting for a human response
> `removed`: The task has vanished from the Dag since the run started"

Fuente: [Tasks — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/tasks.html). **Fetch directo confirmado** (WebFetch sobre la URL, con verificación cruzada leyendo el código fuente).

Esto se corroboró además contra el enum fuente real, `TaskInstanceState`, obtenido por fetch directo del archivo crudo en GitHub (rama `main`, ruta `airflow-core/src/airflow/utils/state.py`):

```python
class TaskInstanceState(str, Enum):
    REMOVED = TerminalTIState.REMOVED
    SCHEDULED = IntermediateTIState.SCHEDULED
    QUEUED = IntermediateTIState.QUEUED
    RUNNING = "running"
    SUCCESS = TerminalTIState.SUCCESS
    RESTARTING = IntermediateTIState.RESTARTING
    FAILED = TerminalTIState.FAILED
    UP_FOR_RETRY = IntermediateTIState.UP_FOR_RETRY
    UP_FOR_RESCHEDULE = IntermediateTIState.UP_FOR_RESCHEDULE
    UPSTREAM_FAILED = TerminalTIState.UPSTREAM_FAILED
    SKIPPED = TerminalTIState.SKIPPED
    DEFERRED = IntermediateTIState.DEFERRED
    AWAITING_INPUT = IntermediateTIState.AWAITING_INPUT
```

Fuente: `https://raw.githubusercontent.com/apache/airflow/main/airflow-core/src/airflow/utils/state.py`. **Fetch directo confirmado** (archivo fuente crudo, no resumen).

**La corrección:** la claim original incluye `shutdown` como uno de los estados "entre otros". **`shutdown` NO existe hoy como `TaskInstanceState`** — ni en el enum fuente ni en la página de conceptos de Tasks de la versión 3.3.0. Sin embargo, sí existió como estado documentado y real en versiones 2.x: la página de Tasks de **Airflow 2.7.0** (fetch directo del archivo de docs versionado, `apache-airflow/2.7.0/core-concepts/tasks.html`) lo lista explícitamente:

> "`shutdown`: The task was externally requested to shut down when it was running"

Y el propio `RELEASE_NOTES.rst` oficial del repo (fetch directo del archivo crudo en GitHub) confirma su eliminación, en la sección Misc/Internal de **Airflow 2.7.2**:

> "Refactor: remove unused state - SHUTDOWN (#33746, #34063, #33893)"

Es decir: `shutdown` fue un `TaskInstanceState` real y documentado hasta 2.7.0/2.7.1, y se retiró como "estado no usado" en el release 2.7.2 (2023-10-12). La claim, tal como está escrita, describe una versión desactualizada de Airflow — es exacta para ~2.3–2.7.1, no para la 3.3.0 actual.

Bono no pedido pero relevante para quien mantenga el skill: `awaiting_input` es una incorporación reciente. El propio `RELEASE_NOTES.rst` (fetch directo) lo registra en la sección de **Airflow 3.3.0**:

> "Add `awaiting_input` task state for Human-in-the-Loop, running off the triggerer (#68028)"

mientras que la funcionalidad Human-in-the-Loop en sí se introdujo antes, en **Airflow 3.1.0** (2025-09-25), inicialmente representada con el estado `deferred` genérico:

> "Airflow 3.1 introduces Human-in-the-Loop (HITL) functionality that enables workflows to pause and wait for human decision-making... HITL tasks pause execution in a `deferred` state while waiting for human input via the Airflow UI."

Fuente: [Release Notes — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/release_notes.html) / `RELEASE_NOTES.rst` crudo. **Fetch directo confirmado** (archivo descargado y `grep`eado línea por línea, no resumen de búsqueda).

### Claim 2 — Default `all_success`

**VERIFIED.**

> "By default, Airflow will wait for all upstream (direct parents) tasks for a task to be successful before it runs that task. However, this is just the default behaviour, and you can control it using the `trigger_rule` argument to a Task."

Fuente: [Dags — Airflow Documentation, sección "Trigger Rules"](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html#trigger-rules). **Fetch directo confirmado** — se descargó el HTML crudo de la página vía `curl` y se extrajo el texto, en lugar de depender solo del resumen del summarizer de WebFetch, precisamente para poder citar de forma verbatim.

### Claim 3 — Catálogo completo de trigger rules

**VERIFIED con hallazgos adicionales importantes** (nombres extra en el catálogo actual, y confirmación de un rename histórico con versión pinneada).

Catálogo verbatim completo, tal como aparece HOY en la sección "Trigger Rules" de `core-concepts/dags.html` (Airflow 3.3.0):

> "`all_success` (default): All upstream tasks have succeeded
> `all_failed`: All upstream tasks are in a `failed` or `upstream_failed` state
> `all_done`: All upstream tasks are done with their execution
> `all_done_setup_success`: Like `all_done`, but if the task has upstream setup tasks, at least one of them must have succeeded. This is the default trigger rule for teardown tasks.
> `all_done_min_one_success`: All non-skipped upstream tasks are done with their execution and at least one upstream task has succeeded
> `all_skipped`: All upstream tasks are in a `skipped` state
> `one_failed`: At least one upstream task has failed (does not wait for all upstream tasks to be done)
> `one_success`: At least one upstream task has succeeded (does not wait for all upstream tasks to be done)
> `one_done`: At least one upstream task succeeded or failed
> `none_failed`: All upstream tasks have not `failed` or `upstream_failed` - that is, all upstream tasks have succeeded or been skipped
> `none_failed_min_one_success`: All upstream tasks have not `failed` or `upstream_failed`, and at least one upstream task has succeeded.
> `none_skipped`: No upstream task is in a `skipped` state - that is, all upstream tasks are in a `success`, `failed`, `upstream_failed`, or `removed` state
> `always`: No dependencies at all, run this task at any time"

Fuente: [Dags — Airflow Documentation, sección "Trigger Rules"](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html#trigger-rules). **Fetch directo confirmado** (HTML descargado con `curl`, texto extraído y citado verbatim).

Esto se corroboró de forma independiente contra el propio enum fuente `TriggerRule`, fetch directo del archivo crudo en GitHub (`airflow-core/src/airflow/task/trigger_rule.py`, rama `main`):

```python
class TriggerRule(str, Enum):
    ALL_SUCCESS = "all_success"
    ALL_FAILED = "all_failed"
    ALL_DONE = "all_done"
    ALL_DONE_MIN_ONE_SUCCESS = "all_done_min_one_success"
    ALL_DONE_SETUP_SUCCESS = "all_done_setup_success"
    ONE_SUCCESS = "one_success"
    ONE_FAILED = "one_failed"
    ONE_DONE = "one_done"
    NONE_FAILED = "none_failed"
    NONE_SKIPPED = "none_skipped"
    ALWAYS = "always"
    NONE_FAILED_MIN_ONE_SUCCESS = "none_failed_min_one_success"
    ALL_SKIPPED = "all_skipped"
```

**Verificación punto por punto de las 6 reglas que pide la tarea:**

- `all_success` (default): **VERIFIED**, semántica exacta.
- `all_done`: **VERIFIED** en semántica ("All upstream tasks are done with their execution"). La caracterización "usado para tareas de cleanup que deben correr incluso si el job falló" **es interpretación/uso común razonable, NO una frase textual de la página** — la doc no usa la palabra "cleanup" en esa entrada. Se marca la distinción explícitamente.
- `none_failed`: **VERIFIED**, semántica exacta ("no failed/upstream_failed, permite skips").
- `none_failed_min_one_success`: **VERIFIED**, semántica exacta — "no failed/upstream_failed, AND at least one upstream task has succeeded".
- `one_success` / `one_failed`: **VERIFIED**, ambos con la cláusula explícita "(does not wait for all upstream tasks to be done)" — confirma exactamente el comportamiento de disparo temprano que describe la claim.
- `always`: **VERIFIED**, "No dependencies at all, run this task at any time".

**Rename histórico — confirmado con versión exacta, algo más preciso que lo que pedía la tarea.** La tarea preguntaba si `none_failed_min_one_success` alguna vez se llamó `none_failed_or_skipped`. Se confirmó que sí, y se acotó la ventana exacta de versiones comparando snapshots de documentación archivada por versión (fetch directo de cada URL versionada, no de la doc "stable"):

- Airflow 2.1.4 (`apache-airflow/2.1.4/concepts/dags.html`, fetch directo): la regla se llama **`none_failed_or_skipped`**.
- Airflow 2.2.0 (`apache-airflow/2.2.0/concepts/dags.html`, fetch directo): la regla ya aparece como **`none_failed_min_one_success`**, sin rastro de `none_failed_or_skipped` en ese punto de la página.
- Airflow 2.3.0 y 2.7.0 (fetch directo de ambas): mismo nombre nuevo, confirmando que el rename es estable desde 2.2.0 en adelante.

Es decir: el rename ocurrió en **Airflow 2.2.0**. El nombre viejo `none_failed_or_skipped` sobrevivió como alias deprecado por varios años y fue **eliminado definitivamente en Airflow 3.0**, según la tabla oficial de "Removed Features" del `RELEASE_NOTES.rst` (fetch directo):

> "| `none_failed_or_skipped` rule | Use `none_failed_min_one_success` |"

La misma tabla confirma otro rename de trigger rule que ni la tarea ni la claim original mencionaban:

> "| `dummy` trigger rule | Use `always` |"

**Otras trigger rules del catálogo oficial que la lista de la tarea NO menciona** (respondiendo directamente a lo pedido — "list any OTHER trigger rules a senior engineer should know"):

- `all_failed`: "All upstream tasks are in a `failed` or `upstream_failed` state" — el opuesto exacto de `all_success`.
- `all_skipped`: "All upstream tasks are in a `skipped` state".
- `one_done`: "At least one upstream task succeeded or failed" — variante de `one_success`/`one_failed` que no distingue cuál de los dos. Confirmado por `RELEASE_NOTES.rst` (fetch directo) que se añadió en **Airflow 2.5.0**: "Add `one_done` trigger rule (#26146)".
- `all_done_min_one_success`: variante de `all_done` que exige al menos un éxito entre los no-skipped. Esta es una incorporación **muy reciente** — el `RELEASE_NOTES.rst` (fetch directo) la ubica en la sección "Significant Changes" de **Airflow 3.1.0** (2025-09-25): "New Trigger Rule: `ALL_DONE_MIN_ONE_SUCCESS`... at least one has succeeded, filling a gap between existing trigger rules for complex workflow patterns."
- `all_done_setup_success`: trigger rule por defecto de las tareas *teardown*, ligada a la feature de Setup/Teardown tasks (AIP-52), que el `RELEASE_NOTES.rst` ubica en **Airflow 2.7.0**. No se pudo confirmar con la misma certeza que el nombre literal `all_done_setup_success` existiera desde el día uno de 2.7.0 (vs. haberse afinado después) — se cita la introducción de la *feature* Setup/Teardown como ancla de versión, no el nombre exacto del enum en ese punto.

**Nota adicional confirmada, no pedida pero útil:** la doc actual explica cómo el estado `removed` interactúa con las trigger rules basadas en conteo — algo que ni la tarea ni las claims mencionaban:

> "For trigger rules, `removed` is a terminal state: it counts toward "done" for rules like `all_done`, `all_done_setup_success`, and `all_done_min_one_success`, but it does not count as `success`, `failed`, `upstream_failed`, or `skipped`."

Fuente para todo el bloque de rename e histórico: `https://airflow.apache.org/docs/apache-airflow/2.1.4/concepts/dags.html`, `https://airflow.apache.org/docs/apache-airflow/2.2.0/concepts/dags.html`, `https://airflow.apache.org/docs/apache-airflow/2.3.0/concepts/dags.html`, `https://airflow.apache.org/docs/apache-airflow/2.7.0/core-concepts/dags.html`, y `https://raw.githubusercontent.com/apache/airflow/main/RELEASE_NOTES.rst`. **Todas fetch directo** (HTML/RST crudo descargado y grepeado, no resúmenes de búsqueda).

**Conclusión de §1:** el modelo de estados y el catálogo de trigger rules de la claim original son sustancialmente correctos, pero **desactualizados en dos puntos concretos**: (a) `shutdown` ya no es un `TaskInstanceState` válido (fue removido en 2.7.2, tras haber existido desde al menos 2.3 hasta 2.7.1) — no debería listarse como estado "actual"; y (b) el catálogo de trigger rules de Airflow hoy tiene **13 reglas**, no las 6 mencionadas — con dos incorporaciones muy recientes (`all_done_min_one_success` en 3.1.0, `awaiting_input` como estado en 3.3.0) que un ingeniero senior debería conocer si trabaja con versiones actuales. El rename `none_failed_or_skipped` → `none_failed_min_one_success` es real, ocurrió en **Airflow 2.2.0**, y el nombre viejo fue eliminado por completo en **Airflow 3.0**.

---

## 2. Branching (claims 4–7)

### Claim 4 — `@task.branch` / `BranchPythonOperator`

**VERIFIED.**

> "The `@task.branch` decorator is much like `@task`, except that it expects the decorated function to return an ID to a task (or a list of IDs). The specified task is followed, while all other paths are skipped. It can also return `None` to skip all downstream tasks."

Y sobre la operator-based variant:

> "If you wish to implement your own operators with branching functionality, you can inherit from `BaseBranchOperator`, which behaves similarly to `@task.branch` decorator but expects you to provide an implementation of the method `choose_branch`... As with the callable for `@task.branch`, this method can return the ID of a downstream task, or a list of task IDs, which will be run, and all others will be skipped."

Con una nota explícita de preferencia actual:

> "The `@task.branch` decorator is recommended over directly instantiating `BranchPythonOperator` in a Dag. The latter should generally only be subclassed to implement a custom operator."

Fuente: [Dags — Airflow Documentation, sección "Branching"](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html#branching). **Fetch directo confirmado** (HTML crudo descargado y citado verbatim).

Nota de ubicación: `BranchPythonOperator` y el decorador `@task.branch` viven hoy en `apache-airflow-providers-standard` (confirmado por fetch directo de `https://airflow.apache.org/docs/apache-airflow-providers-standard/stable/_api/airflow/providers/standard/operators/python/index.html`), no en el paquete núcleo `airflow.operators.python` como en Airflow 1.x/2.x tempranas.

### Claim 5 — `ShortCircuitOperator`

**VERIFIED**, incluyendo el parámetro `ignore_downstream_trigger_rules` (sigue existiendo en la API actual).

> "Allows a pipeline to continue based on the result of a `python_callable`. The ShortCircuitOperator is derived from the PythonOperator and evaluates the result of a `python_callable`. If the returned result is False or a falsy value, the pipeline will be short-circuited. Downstream tasks will be marked with a state of 'skipped' based on the short-circuiting mode configured. If the returned result is True or a truthy value, downstream tasks proceed as normal and an `XCom` of the returned result is pushed."

Sobre `ignore_downstream_trigger_rules` (confirma exactamente el matiz que pedía la tarea):

> "If set to True, all downstream tasks from this operator task will be skipped. This is the default behavior. If set to False, the direct, downstream task(s) will be skipped but the `trigger_rule` defined for all other downstream tasks will be respected."

Fuente: [ShortCircuitOperator API reference — apache-airflow-providers-standard](https://airflow.apache.org/docs/apache-airflow-providers-standard/stable/_api/airflow/providers/standard/operators/python/index.html). **Confirmado por WebFetch directo sobre la página de API reference** (no HTML crudo en este caso puntual, pero fetch directo de la URL, no resumen de búsqueda indexado).

El "guard clause" es una analogía razonable del comportamiento (cortar el flujo temprano si la condición no se cumple) — no es terminología textual de Airflow, se marca como caracterización propia consistente con el comportamiento documentado.

### Claim 6 — `LatestOnlyOperator`

**VERIFIED**, con detalle extra sobre backfills confirmado directamente en el código fuente.

Desde la página de conceptos:

> "Airflow's Dag Runs are often run for a date that is not the same as the current date - for example, running one copy of a Dag for every day in the last month to backfill some data. There are situations, though, where you don't want to let some (or all) parts of a Dag run for a previous date; in this case, you can use the `LatestOnlyOperator`. This special Operator skips all tasks downstream of itself if you are not on the 'latest' Dag run (if the wall-clock time right now is between its `execution_time` and the next scheduled `execution_time`, and it was not an externally-triggered run)."

Fuente: [Dags — Airflow Documentation, sección "Latest Only"](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html#latest-only). **Fetch directo confirmado** (HTML crudo).

Confirmado también contra el docstring real de la clase, vía fetch directo del archivo fuente crudo en GitHub (`providers/standard/src/airflow/providers/standard/operators/latest_only.py`):

```python
class LatestOnlyOperator(BaseBranchOperator):
    """
    Skip tasks that are not running during the most recent schedule interval.

    If the task is run outside the latest schedule interval (i.e. run_type == DagRunType.MANUAL),
    all directly downstream tasks will be skipped.

    Note that downstream tasks are never skipped if the given DAG_Run is
    marked as externally triggered.
    """
```

Dato de arquitectura interesante que ni la claim ni la tarea pedían, pero que vale la pena que el skill sepa: `LatestOnlyOperator` está implementado como una subclase de `BaseBranchOperator` — es decir, técnicamente usa el mismo mecanismo de branching (claim 4) para decidir qué saltar, no un mecanismo aparte.

Fuente: `https://raw.githubusercontent.com/apache/airflow/main/providers/standard/src/airflow/providers/standard/operators/latest_only.py`. **Fetch directo confirmado** (archivo fuente crudo).

Nota de ubicación: `LatestOnlyOperator` vive hoy en `airflow.providers.standard.operators.latest_only` (paquete `apache-airflow-providers-standard`), no en un módulo núcleo `airflow.operators.latest_only`.

### Claim 7 — La trampa "join después de branch"

**VERIFIED de forma explícita y textual — Airflow documenta el problema Y la solución con nombres de tasks casi idénticos al ejemplo típico de la industria.**

> "It's important to be aware of the interaction between trigger rules and skipped tasks, especially tasks that are skipped as part of a branching operation. **You almost never want to use `all_success` or `all_failed` downstream of a branching operation.** Skipped tasks will cascade through trigger rules `all_success` and `all_failed`, and cause them to skip as well."

Con el ejemplo concreto, código incluido, que reproduce exactamente el patrón "branch → join":

> "`join` is downstream of `follow_branch_a` and `branch_false`. The `join` task will show up as skipped because its `trigger_rule` is set to `all_success` by default, and the skip caused by the branching operation cascades down to skip a task marked as `all_success`. By setting `trigger_rule` to `none_failed_min_one_success` in the `join` task, we can instead get the intended behaviour"

Fuente: [Dags — Airflow Documentation, sección "Trigger Rules"](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html#trigger-rules). **Fetch directo confirmado** (HTML crudo descargado, texto extraído y citado verbatim — incluye el bloque de código Python del ejemplo con los `task_id` `branch_a`, `follow_branch_a`, `branch_false`, `join`).

Esta NO es folklore de comunidad — es el ejemplo canónico de la propia documentación oficial de Airflow, con esas palabras.

**Conclusión de §2:** las cuatro claims de branching están verificadas contra la documentación oficial actual. La más importante para el skill — la trampa join-después-de-branch — está confirmada con cita textual directa de Airflow, no como interpretación de terceros: la propia doc usa el ejemplo `join` skipped por `all_success` y prescribe `none_failed_min_one_success` como fix, palabra por palabra igual a como se enseña en la industria. La única corrección de fondo es de ubicación de paquete: `BranchPythonOperator`, `@task.branch`, `ShortCircuitOperator` y `LatestOnlyOperator` viven hoy en `apache-airflow-providers-standard`, no en el núcleo `airflow.operators.*`.

---

## 3. Sensors — nombres de clase y modos (claims 8–10, 12)

### Claim 8 — Ubicaciones de clases de sensor

**NEEDS CORRECTION en dos de los tres sensores** — las ubicaciones "core Airflow" asumidas por la claim ya no son correctas en Airflow 3.x.

**`S3KeySensor`** — **VERIFIED**, sin sorpresas de ubicación (siempre fue provider):

> "Waits for one or multiple keys (a file-like instance on S3) to be present in a S3 bucket."

Módulo confirmado: `airflow.providers.amazon.aws.sensors.s3.S3KeySensor`, paquete `apache-airflow-providers-amazon`. Constructor (fetch directo):

```python
S3KeySensor(
    *, bucket_key, bucket_name=None, wildcard_match=False, check_fn=None,
    verify=None, deferrable=conf.getboolean('operators', 'default_deferrable', fallback=False),
    use_regex=False, metadata_keys=None, **kwargs,
)
```

Fuente: [S3KeySensor — apache-airflow-providers-amazon](https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/_api/airflow/providers/amazon/aws/sensors/s3/index.html). **Fetch directo confirmado.**

**`SqlSensor`** — **NEEDS CORRECTION.** La claim pregunta si sigue siendo "core Airflow"; **no lo es**. Vive en el paquete provider `apache-airflow-providers-common-sql`, módulo `airflow.providers.common.sql.sensors.sql`:

> "Run a SQL statement repeatedly until a criteria is met."

Fuente: [SqlSensor — apache-airflow-providers-common-sql](https://airflow.apache.org/docs/apache-airflow-providers-common-sql/stable/_api/airflow/providers/common/sql/sensors/sql/index.html). **Fetch directo confirmado.** No se pudo verificar en qué versión ocurrió esta migración específica desde el núcleo (los providers se separaron del monolito `apache-airflow` en distintos momentos según el AIP-21/provider split, pero no se encontró una fecha exacta para `SqlSensor` en concreto en la documentación revisada) — se marca como **no verificado el "cuándo"**, solo el "dónde actual".

**`ExternalTaskSensor`** — **NEEDS CORRECTION** de forma más marcada aún. Ya no vive en `airflow.sensors.external_task` (confirmado indirectamente: esa ruta de API reference en el núcleo hoy da **404**, `https://airflow.apache.org/docs/apache-airflow/stable/_api/airflow/sensors/index.html` también da 404, señal de que el namespace público `airflow.sensors.*` fue removido de la documentación del núcleo). Vive ahora en el paquete `apache-airflow-providers-standard`, módulo `airflow.providers.standard.sensors.external_task`. Ver detalle completo en §5, dado que esta es la claim de mayor prioridad.

**Conclusión de la claim 8:** de los tres sensores, solo `S3KeySensor` está donde la claim original asumía. `SqlSensor` y `ExternalTaskSensor` se movieron a paquetes provider — algo que cualquier ingeniero escribiendo `pip install` o `from airflow.sensors...` contra Airflow 3.x necesita saber, porque el import del núcleo simplemente no existe más.

### Claim 9 — modo `poke` por defecto

**VERIFIED**, con cita textual completa.

> "Because they are primarily idle, Sensors have two different modes of running so you can be a bit more efficient about using them: `poke` (default): The Sensor takes up a worker slot for its entire runtime `reschedule`: The Sensor takes up a worker slot only when it is checking, and sleeps for a set duration between checks."

Y en el bloque de parámetros comunes:

> "`mode` — Determines how the sensor occupies worker resources. `poke` (default): occupies a worker slot for the entire duration `reschedule`: releases the worker slot between checks"
>
> "`poke_interval` — Time in seconds between successive checks. In poke mode, the sensor sleeps between checks while occupying a worker slot. In reschedule mode, the task is deferred and rescheduled after this interval."

Fuente: [Sensors — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/sensors.html). **Fetch directo confirmado** (HTML crudo descargado y citado verbatim).

Sobre la caracterización "30 sensors / 32 slots deja 2 para trabajo real": no es una frase ni un ejemplo numérico que aparezca en la documentación de Airflow — es un ejemplo ilustrativo construido por quien redactó la claim. Es, sin embargo, **consistente** con lo documentado: si el modo `poke` "occupies a worker slot for the entire duration" y no lo libera entre chequeos, entonces N sensores en modo poke corriendo simultáneamente consumen N slots de worker de forma continua, dejando `total_slots - N` disponibles para cualquier otra tarea. La propia página de Deferrable Operators (ver §4) usa un ejemplo estructuralmente idéntico con números redondos (100 slots / 100 DAGs esperando) para ilustrar exactamente este problema de starvation, lo que refuerza que la caracterización es fiel al espíritu documentado, aunque los números concretos (30/32) sean de quien escribió la claim, no de Airflow.

### Claim 10 — `mode="reschedule"`

**VERIFIED**, misma fuente que la claim 9:

> "`reschedule`: The Sensor takes up a worker slot only when it is checking, and sleeps for a set duration between checks."
>
> "`reschedule`: releases the worker slot between checks"

Y el trade-off documentado explícitamente:

> "The poke and reschedule modes can be configured directly when you instantiate the sensor; generally, the trade-off between them is latency. Something that is checking every second should be in poke mode, while something that is checking every minute should be in reschedule mode."

Fuente: misma página, [Sensors — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/sensors.html). **Fetch directo confirmado.**

Diferencia operativa exacta: en `poke`, entre chequeos el proceso worker sigue vivo y ocupando el slot mientras duerme; en `reschedule`, la tarea literalmente se marca `up_for_reschedule` (ver claim 1) y libera el slot, para ser reencolada al pasar el `poke_interval` — no es un `sleep()` dentro del mismo proceso, es una liberación real de recurso.

### Claim 12 — Parámetros complementarios del sensor

**VERIFIED en su totalidad**, con cita textual verbatim del **Task SDK API reference**, que hoy es la fuente autoritativa para `BaseSensorOperator` (la página de conceptos remite explícitamente ahí):

> "As of the Task SDK refactor, `BaseSensorOperator` is implemented in the Task SDK... For the authoritative API reference, see the Task SDK documentation for `BaseSensorOperator`: `https://airflow.apache.org/docs/task-sdk/stable/api.html#airflow.sdk.BaseSensorOperator`"

- **`timeout`**: **VERIFIED**. "Maximum time in seconds the sensor is allowed to run before failing. This timeout is measured from the first execution attempt, not per poke."
- **`soft_fail`**: **VERIFIED**, comportamiento exacto que pide la claim. "If set to True, the sensor will be marked as SKIPPED instead of FAILED when the timeout is reached."
- **`poke_interval`**: **VERIFIED**. "Time in seconds between successive checks."
- **`exponential_backoff`**: **VERIFIED**. "If enabled, the time between checks increases exponentially up to `max_wait`. This is useful when polling external systems with unpredictable availability." Va acompañado de un parámetro relacionado no mencionado en la claim pero que un skill debería conocer: `max_wait` — "Upper bound (in seconds) for the delay between checks when exponential_backoff is enabled."

Fuente: [Sensors — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/sensors.html) y [Task SDK API — `airflow.sdk.BaseSensorOperator`](https://airflow.apache.org/docs/task-sdk/stable/api.html). **Fetch directo confirmado en ambas** (la primera vía HTML crudo descargado con `curl`; la segunda vía WebFetch directo sobre la URL del Task SDK).

Dato de versión: el `RELEASE_NOTES.rst` (fetch directo) ubica la incorporación de `max_wait`/`exponential_backoff` en `BaseSensorOperator` en **Airflow 2.5.0**: "Add max_wait for exponential_backoff in BaseSensor (#27597)".

**Conclusión de §3:** los comportamientos de `poke` vs. `reschedule`, y los cuatro parámetros complementarios (`timeout`, `soft_fail`, `poke_interval`, `exponential_backoff`), están **verificados palabra por palabra** contra la documentación oficial vigente. El hallazgo que exige actualizar el skill no es de comportamiento sino de **ubicación**: `SqlSensor` y `ExternalTaskSensor` migraron fuera del núcleo `airflow.sensors.*` hacia paquetes provider, y `BaseSensorOperator` en sí mismo ahora vive en el Task SDK (`airflow.sdk.BaseSensorOperator`), no en `airflow.sensors.base`.

---

## 4. Sensores deferrable y el triggerer (claim 11)

**VERIFIED en comportamiento; versión de introducción confirmada por evidencia indirecta pero sólida (no por una nota "New in version" explícita en la página actual).**

Texto completo, verbatim, de la página oficial (Airflow 3.3.0):

> "Standard Operators and Sensors take up a full worker slot for the entire time they are running, even if they are idle. For example, if you only have 100 worker slots available to run tasks, and you have 100 Dags waiting on a sensor that's currently running but idle, then you cannot run anything else - even though your entire Airflow cluster is essentially idle."
>
> "`reschedule` mode for sensors solves some of this, by allowing sensors to only run at fixed intervals, but it is inflexible and only allows using time as the reason to resume, not other criteria. This is where Deferrable Operators can be used."
>
> "When it has nothing to do but wait, an operator can suspend itself and free up the worker for other processes by deferring. When an operator defers, execution moves to the triggerer, where the trigger specified by the operator will run. The trigger can do the polling or waiting required by the operator. Then, when the trigger finishes polling or waiting, it sends a signal for the operator to resume its execution."
>
> "During the deferred phase of execution, since work has been offloaded to the triggerer, **the task no longer occupies a worker slot**, and you have more free workload capacity."
>
> "Triggers are small, asynchronous pieces of Python code designed to run in a single Python process. Because they are asynchronous, they can all co-exist efficiently in the triggerer Airflow component."

Fuente: [Deferrable Operators & Triggers — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/authoring-and-scheduling/deferring.html). **Fetch directo confirmado** (HTML crudo descargado y citado verbatim).

Detalle no pedido por la tarea pero relevante para el skill: Airflow 3.2 introdujo un mecanismo *adicional* y distinto — "async tasks" — que la propia doc distingue explícitamente de los deferrable operators:

> "Airflow 3.2 also supports Python-native async tasks that can perform concurrent I/O operations within a single worker slot. While deferred operators release the worker slot while waiting for an external event, async tasks keep the task process running and use a shared event loop to multiplex operations."

**Versión de introducción — Airflow 2.2:** la página actual **no** trae una nota "New in version" explícita. La evidencia de versión se construyó comparando snapshots de documentación archivada:

- `https://airflow.apache.org/docs/apache-airflow/2.1.4/concepts/deferring.html` → **HTTP 404** (fetch directo confirmado — la página no existe en esa versión).
- `https://airflow.apache.org/docs/apache-airflow/2.2.0/concepts/deferring.html` → **HTTP 200**, contenido real y completo (fetch directo confirmado), con el mismo argumento de fondo ya presente: "Standard Operators and Sensors take up a full worker slot for the entire time they are running, even if they are idle; for example, if you only have 100 worker slots available to run Tasks, and you have 100 DAGs waiting on a Sensor that's currently running but idle, then you cannot run anything else."

Esto confirma con alta confianza que **deferrable operators y el triggerer se introdujeron en Airflow 2.2.0**, tal como esperaba la claim, aunque la confirmación es por "la página aparece por primera vez en 2.2.0 y no existe en 2.1.4", no por una nota de changelog explícita dentro de esa misma página. No se encontró la entrada específica en `RELEASE_NOTES.rst` que anuncie la feature en 2.2.0 porque el archivo `RELEASE_NOTES.rst` de la rama `main` solo conserva historial desde **Airflow 2.5.0** en adelante — no cubre 2.2.0. Se marca esto explícitamente como límite de la fuente.

**Conclusión de §4:** el mecanismo (defer → libera el worker slot → el triggerer corre el trigger asíncrono → al completarse, el scheduler reencola la tarea) está confirmado palabra por palabra contra la documentación oficial vigente. La versión de introducción, **Airflow 2.2**, se confirma con alta confianza por comparación de existencia de páginas versionadas (404 en 2.1.4, contenido real en 2.2.0), no por una nota de changelog textual dentro de la página — se marca la diferencia de método explícitamente.

---

## 5. ExternalTaskSensor y el problema de alineación de fechas (claim 13 — máxima prioridad)

**VERIFIED — los parámetros NO fueron renombrados a terminología `logical_date`, pero la clase SÍ cambió de paquete.** Este es el hallazgo más importante del documento.

Firma completa del constructor, citada verbatim desde la página de API reference actual (fetch directo del HTML crudo, no resumen):

```
class airflow.providers.standard.sensors.external_task.ExternalTaskSensor(
    *,
    external_dag_id,
    external_task_id=None,
    external_task_ids=None,
    external_task_group_id=None,
    allowed_states=None,
    skipped_states=None,
    failed_states=None,
    execution_delta=None,
    execution_date_fn=None,
    check_existence=False,
    poll_interval=2.0,
    deferrable=conf.getboolean('operators', 'default_deferrable', fallback=False),
    **kwargs,
)
```

**Los parámetros de alineación de fecha SIGUEN llamándose `execution_delta` y `execution_date_fn`, verbatim, sin renombrar** — pero sus descripciones en la doc actual ya usan terminología `logical_date`/data-interval (AIP-39), no `execution_date`:

> "`execution_delta` (`datetime.timedelta | None`) – time difference with the previous execution to look at, the default is **the same logical date** as the current task or DAG. For yesterday, use [positive!] `datetime.timedelta(days=1)`. Either `execution_delta` or `execution_date_fn` can be passed to ExternalTaskSensor, but not both."
>
> "`execution_date_fn` (`collections.abc.Callable | None`) – function that receives the current execution's **logical date** as the first positional argument and optionally any number of keyword arguments available in the context dictionary, and returns **the desired logical dates** to query. Either `execution_delta` or `execution_date_fn` can be passed to ExternalTaskSensor, but not both."

Fuente: [ExternalTaskSensor — apache-airflow-providers-standard API reference](https://airflow.apache.org/docs/apache-airflow-providers-standard/stable/_api/airflow/providers/standard/sensors/external_task/index.html). **Fetch directo confirmado** — HTML crudo descargado vía `curl`, texto extraído y citado verbatim carácter por carácter (no vía resumen de WebFetch, precisamente por ser la claim de mayor prioridad).

El propio docstring de la clase confirma el mismo patrón — nombre de parámetro sin cambios, lenguaje interno migrado a "logical date":

> "Waits for a different DAG, task group, or task to complete for a specific logical date."

**Cambio real, y el que sí hay que corregir en el skill: el paquete.** `ExternalTaskSensor` **ya no vive en el núcleo** `airflow.sensors.external_task`. Evidencia:

- `https://airflow.apache.org/docs/apache-airflow/stable/_api/airflow/sensors/external_task/index.html` → **HTTP 404** (fetch directo confirmado).
- `https://airflow.apache.org/docs/apache-airflow/stable/_api/airflow/sensors/index.html` (índice del namespace `airflow.sensors` en el núcleo) → **HTTP 404** también (fetch directo confirmado) — el namespace público de sensors del núcleo fue removido por completo de la documentación de referencia.
- La página de conceptos de Sensors (núcleo) enlaza a `ExternalTaskSensor` apuntando explícitamente al paquete provider:

> "`ExternalTaskSensor` - Wait for a task in another DAG to complete" — con el link resuelto a `/docs/apache-airflow-providers-standard/stable/_api/airflow/providers/standard/sensors/external_task/index.html` y la etiqueta de versión "(in apache-airflow-providers-standard v1.15.0)".

Fuente: [Sensors — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/sensors.html). **Fetch directo confirmado.**

Dato adicional presente en la firma actual y ausente de versiones anteriores de esta clase, que vale la pena que el skill mencione: `deferrable=conf.getboolean('operators', 'default_deferrable', fallback=False)` — es decir, `ExternalTaskSensor` hoy soporta modo deferrable de forma nativa (conecta directamente con la claim 11), y hay un parámetro `check_existence` (bool, default `False`) para fallar rápido si el DAG/task externo ni siquiera existe, en vez de esperar hasta el timeout.

**Conclusión de §5 (la más importante del documento):** la migración de terminología `execution_date` → `logical_date` (AIP-39) **sí ocurrió**, pero se aplicó a la *documentación y semántica interna*, no a los *nombres de los parámetros públicos* de `ExternalTaskSensor` — `execution_delta` y `execution_date_fn` siguen siendo, verbatim, los nombres actuales en Airflow 3.3.0/`apache-airflow-providers-standard` stable. Quien actualice el skill puede seguir enseñando `execution_delta`/`execution_date_fn` como los parámetros correctos hoy — el error a corregir no es de nombre de parámetro sino de **import path**: la clase se movió de `airflow.sensors.external_task` (núcleo) a `airflow.providers.standard.sensors.external_task` (paquete `apache-airflow-providers-standard`), y el `import` de ejemplos escritos contra Airflow 2.x simplemente falla en Airflow 3.x.

---

## Resumen de fuentes primarias usadas

| Fuente | Uso | Método de verificación |
|---|---|---|
| [Tasks — Airflow Docs](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/tasks.html) | Catálogo `TaskInstanceState` actual (§1, claim 1) | Fetch directo (WebFetch) |
| `airflow-core/src/airflow/utils/state.py` (GitHub raw, rama `main`) | Enum fuente `TaskInstanceState`, `DagRunState` (§1) | Fetch directo del archivo crudo |
| [Dags — Airflow Docs, `core-concepts/dags.html`](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html) | Default trigger rule, catálogo completo de 13 trigger rules, sección Branching, ejemplo join-después-de-branch, LatestOnlyOperator (§1, §2) | Fetch directo — HTML crudo descargado con `curl`, texto extraído y citado verbatim |
| `airflow-core/src/airflow/task/trigger_rule.py` (GitHub raw, rama `main`) | Enum fuente `TriggerRule` (§1) | Fetch directo del archivo crudo |
| `apache-airflow/2.1.4/concepts/dags.html`, `2.2.0/concepts/dags.html`, `2.3.0/concepts/dags.html`, `2.7.0/core-concepts/tasks.html` y `core-concepts/dags.html` (docs versionadas archivadas) | Fecha exacta del rename `none_failed_or_skipped`→`none_failed_min_one_success` (2.2.0); confirmación de `shutdown` como estado real en 2.7.0 (§1) | Fetch directo de cada URL versionada |
| `RELEASE_NOTES.rst` (GitHub raw, rama `main`) | Eliminación de `shutdown` (2.7.2), adición de `one_done` (2.5.0), `all_done_min_one_success` (3.1.0), `awaiting_input`/HITL (3.1.0 y 3.3.0), `max_wait`/`exponential_backoff` (2.5.0), tabla de "Removed Features" de Airflow 3.0 (`none_failed_or_skipped`, `dummy` rule) (§1, §3) | Fetch directo del archivo crudo, descargado y `grep`eado línea por línea |
| [ShortCircuitOperator / BranchPythonOperator — apache-airflow-providers-standard](https://airflow.apache.org/docs/apache-airflow-providers-standard/stable/_api/airflow/providers/standard/operators/python/index.html) | Docstring y `ignore_downstream_trigger_rules` (§2, claim 5) | Fetch directo (WebFetch) |
| `providers/standard/src/airflow/providers/standard/operators/latest_only.py` (GitHub raw, rama `main`) | Docstring exacto de `LatestOnlyOperator`, confirmación de que hereda de `BaseBranchOperator` (§2, claim 6) | Fetch directo del archivo crudo |
| [S3KeySensor — apache-airflow-providers-amazon](https://airflow.apache.org/docs/apache-airflow-providers-amazon/stable/_api/airflow/providers/amazon/aws/sensors/s3/index.html) | Docstring, constructor, paquete (§3, claim 8) | Fetch directo (WebFetch) |
| [SqlSensor — apache-airflow-providers-common-sql](https://airflow.apache.org/docs/apache-airflow-providers-common-sql/stable/_api/airflow/providers/common/sql/sensors/sql/index.html) | Docstring, paquete/módulo actual (§3, claim 8) | Fetch directo (WebFetch) |
| [Sensors — Airflow Docs, `core-concepts/sensors.html`](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/sensors.html) | `mode` poke/reschedule, `timeout`, `soft_fail`, `poke_interval`, `exponential_backoff`, `max_wait`, enlaces a `ExternalTaskSensor`/`FileSensor` (§3, claims 9, 10, 12) | Fetch directo — HTML crudo descargado con `curl`, texto extraído y citado verbatim |
| [Task SDK API — `airflow.sdk.BaseSensorOperator`](https://airflow.apache.org/docs/task-sdk/stable/api.html) | Parámetros verbatim de `BaseSensorOperator` (`poke_interval`, `timeout`, `soft_fail`, `mode`, `exponential_backoff`, `max_wait`, `silent_fail`) (§3, claim 12) | Fetch directo (WebFetch) |
| [Deferrable Operators & Triggers — Airflow Docs](https://airflow.apache.org/docs/apache-airflow/stable/authoring-and-scheduling/deferring.html) | Mecánica de defer/triggerer, liberación de worker slot, distinción con async tasks de 3.2 (§4, claim 11) | Fetch directo — HTML crudo descargado con `curl`, texto extraído y citado verbatim |
| `apache-airflow/2.1.4/concepts/deferring.html` (404) y `2.2.0/concepts/deferring.html` (200, contenido real) | Acotar la versión de introducción de deferrable operators/triggerer a Airflow 2.2.0 (§4) | Fetch directo de ambas URLs versionadas |
| [ExternalTaskSensor — apache-airflow-providers-standard API reference](https://airflow.apache.org/docs/apache-airflow-providers-standard/stable/_api/airflow/providers/standard/sensors/external_task/index.html) | Firma completa del constructor, confirmación de que `execution_delta`/`execution_date_fn` NO fueron renombrados, terminología `logical_date` en las descripciones, `deferrable`/`check_existence` (§5, claim 13 — máxima prioridad) | Fetch directo — HTML crudo descargado con `curl`, texto extraído y citado verbatim carácter por carácter |
| `https://airflow.apache.org/docs/apache-airflow/stable/_api/airflow/sensors/external_task/index.html` y `.../sensors/index.html` | Confirmar (por 404) que el namespace `airflow.sensors.*` del núcleo ya no existe en la documentación de referencia (§3, §5) | Fetch directo (ambos devolvieron HTTP 404, confirmado) |
| [Airflow Documentation — index.html](https://airflow.apache.org/docs/apache-airflow/stable/index.html) | Confirmar que "stable" = Airflow 3.3.0 | Fetch directo (WebFetch) |

## Claims explícitamente NO verificadas — no usar como cita textual sin revisión adicional

1. **Versión exacta en la que `SqlSensor` migró del núcleo al paquete `apache-airflow-providers-common-sql`.** Se confirmó la ubicación *actual* por fetch directo, pero no se encontró en la documentación revisada una nota de changelog que fije el momento exacto de esa migración específica (§3, claim 8).
2. **Nota "New in version 2.2" textual dentro de la página de Deferrable Operators.** La versión 2.2.0 se infirió con alta confianza comparando la existencia de la página entre 2.1.4 (404) y 2.2.0 (200, contenido completo), no de una frase explícita de changelog dentro de la propia página vigente — el `RELEASE_NOTES.rst` disponible en el repo no cubre versiones anteriores a 2.5.0 (§4, claim 11).
3. **Que el nombre literal del enum `all_done_setup_success` existiera ya con esa grafía exacta desde el primer release de Airflow 2.7.0.** Se confirmó que la *feature* Setup/Teardown (AIP-52) se introdujo en 2.7.0 según `RELEASE_NOTES.rst`, pero no se verificó línea por línea que el trigger rule tuviera ese nombre exacto desde el día uno de esa versión, versus haberse afinado en un patch posterior (§1, claim 3).
4. **La caracterización numérica "30 sensores / 32 slots = 2 libres".** Es consistente con el comportamiento documentado de `poke` mode, pero no es un ejemplo ni una cifra que aparezca en ningún doc oficial de Airflow revisado — es una construcción didáctica de quien redactó la claim original, no una cita (§3, claim 9).
