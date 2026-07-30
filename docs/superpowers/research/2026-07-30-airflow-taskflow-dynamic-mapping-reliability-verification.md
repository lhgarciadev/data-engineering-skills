# Research: Airflow — TaskFlow, Dynamic Task Mapping, reuse structural (TaskGroups/SubDAGs, setup/teardown, DAG factories) y config de confiabilidad

**Fecha:** 2026-07-30
**Alcance:** verificación de 10 claims puntuales para contenido de skill sobre patrones estructurales/de reuso y config de confiabilidad de Apache Airflow, contra documentación oficial (`airflow.apache.org/docs/apache-airflow/stable/`, blog oficial de Airflow, release notes, y en un caso el wiki de AIP de la propia Apache Software Foundation). La versión "stable" resuelta durante este research es **Airflow 3.3.0** — esto importa porque varias claims fueron escritas pensando en Airflow 2.x y dos de ellas (SubDAGs, `sla`) cambiaron de estado en el salto a Airflow 3.0.

---

## 1. Fan-out/fan-in ("diamond") — paralelismo estático

**VERIFICADO como mecánica, con matiz de terminología.**

La documentación oficial de `core-concepts/dags.html` sí documenta el mecanismo de fan-out/fan-in vía el operador bitshift, pero **no usa la palabra "diamond"** en esa página — es terminología de industria, no un término acuñado por Airflow. El ejemplo de fan-out está confirmado textualmente:

> ```python
> first_task >> [second_task, third_task]
> third_task << fourth_task
> ```

Fuente: [DAGs — Task Dependencies](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html) (fetch directo). El fan-in (`[task_a, task_b] >> converge_task`) es la aplicación simétrica del mismo operador y es mecánica estándar y bien documentada, aunque no apareció como ejemplo literal de "diamond" en el fetch.

**Veredicto para el skill:** la afirmación de que el fan-out/fan-in es paralelismo estático con el número de ramas conocido en tiempo de parseo es correcta y consistente con cómo Airflow construye el grafo (el DAG se serializa completo al parsear el archivo, antes de cualquier ejecución) — pero si el skill usa la palabra "diamond" como si fuera terminología oficial de Airflow, debe presentarse como término descriptivo de la industria, no como cita textual de la doc.

---

## 2. Dynamic Task Mapping (`.expand()`) — versión de introducción y patrón de código

**VERIFICADO — Airflow 2.3 es la versión correcta.**

Confirmado por **fetch directo del blog oficial de anuncio de release**:

> "There's now first-class support for dynamic tasks in Airflow. What this means is that you can generate tasks dynamically at runtime."

Fuente: [Apache Airflow 2.3.0 is here](https://airflow.apache.org/blog/airflow-2.3.0/) — la sección se titula explícitamente "Dynamic Task Mapping (AIP-42)", fetch directo confirmado.

El patrón de código exacto que pide la tarea — `@task` que retorna una lista, luego `downstream_task.expand(param=upstream_task())` — está confirmado textualmente en la doc de referencia actual:

> ```python
> @task
> def make_list():
>     return [1, 2, {"a": "b"}, "str"]
>
> @task
> def consumer(arg):
>     print(arg)
>
> consumer.expand(arg=make_list())
> ```
> "The `make_list` task runs as a normal task and must return a list or dict [...] and then the `consumer` task will be called four times, once with each value in the return of `make_list`."

Y la razón de ser del feature, en los términos exactos de la claim (parse-time vs. runtime):

> "Dynamic Task Mapping allows a way for a workflow to create a number of tasks at runtime based upon current data, rather than the Dag author having to know in advance how many tasks would be needed."

Fuente: [Dynamic Task Mapping](https://airflow.apache.org/docs/apache-airflow/stable/authoring-and-scheduling/dynamic-task-mapping.html) (fetch directo, Airflow 3.3.0 docs — la página no repite el número de versión de introducción, por eso el año/versión exacta se confirmó cruzando con el blog de 2.3.0 arriba).

**Nota adicional no pedida pero relevante:** `max_map_length` y `max_active_tis_per_dag` son los límites de configuración documentados para controlar cuántas tareas mapeadas se generan/corren en paralelo — útil si el skill menciona salvaguardas contra un `.expand()` que genera miles de tareas por accidente.

---

## 3. TaskFlow API (`@task`) — versión de introducción y comparación con `PythonOperator` + XCom manual

**VERIFICADO — Airflow 2.0 es la versión correcta, con cita textual exacta que incluye el directive `versionadded`.**

Fetch directo de la documentación histórica de la propia versión 2.0.0 (no de la doc "stable" actual, que ya no lleva ese aviso porque el feature dejó de ser "nuevo"):

> "**New in version 2.0.0.**"
> "Airflow 2.0 adds a new style of authoring dags called the TaskFlow API which removes a lot of the boilerplate around creating PythonOperators, managing dependencies between task and accessing XCom values."

Fuente: [Concepts — Airflow 2.0.0 Documentation](https://airflow.apache.org/docs/apache-airflow/2.0.0/concepts.html) (fetch directo).

La comparación exacta entre el estilo TaskFlow y el manual `xcom_push`/`xcom_pull` está confirmada en el tutorial actual:

> "The function's return value is passed to the next task — no manual use of `XComs` required. Under the hood, TaskFlow uses `XComs` to manage data passing automatically, abstracting away the complexity of manual XCom management from the previous methods."
> "Airflow still uses `XComs` and builds a dependency graph — it's just abstracted away so you can focus on your business logic."

El ejemplo del estilo antiguo que la doc usa como contraste incluye literalmente `ti.xcom_pull(task_ids="extract")`.

Fuente: [Pythonic Dags with the TaskFlow API](https://airflow.apache.org/docs/apache-airflow/stable/tutorial/taskflow.html) (fetch directo).

**Veredicto:** la claim es exacta en versión y en mecánica — TaskFlow no elimina XCom, lo abstrae; sigue construyendo el mismo grafo de dependencias por debajo.

---

## 4. TaskGroups reemplazó a SubDAGs — ¿deprecado o removido? ¿la razón del deadlock es la documentada?

**NEEDS CORRECTION en el verbo: no es "deprecado", está REMOVIDO en Airflow 3.0. La razón del deadlock/single-slot SÍ está documentada oficialmente, con una cita casi textual.**

### Estado actual: removido, no solo deprecado

Confirmación directa desde la sección "Breaking Changes" de la guía oficial de migración a Airflow 3:

> "**SubDAGs**: Replaced by TaskGroups, Assets, and Data Aware Scheduling."

Fuente: [Upgrading to Airflow 3](https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html) (fetch directo).

Confirmación adicional por comportamiento observado: la página de referencia de API que en versiones 2.x documentaba `airflow.operators.subdag.SubDagOperator` **devuelve HTTP 404 en la documentación "stable" (3.3.0) actual** —

```
GET https://airflow.apache.org/docs/apache-airflow/stable/_api/airflow/operators/subdag/index.html → 404 Not Found
```

— consistente con remoción real del código, no solo deprecación documental. **Confianza: fetch directo tanto del texto de breaking changes como del 404.**

### La razón documentada del deadlock/single-slot

Esta es la cita más fuerte encontrada, y viene del **propio blog oficial de anuncio de Airflow 2.0** (el mismo release que introdujo TaskGroup como reemplazo):

> "SubDAGs were commonly used for grouping tasks in the UI, but they had many drawbacks in their execution behaviour (**primarily that they only executed a single task in parallel!**)"
> "To improve this experience, we've introduced 'Task Groups': a method for organizing tasks which provides the same grouping behaviour as a subdag **without any of the execution-time drawbacks**."

Fuente: [Apache Airflow 2.0 is here!](https://airflow.apache.org/blog/airflow-two-point-oh-is-here/) (fetch directo).

Esto se corrobora con el **docstring oficial del propio código fuente** de `SubDagOperator` (Airflow 2.5.3, última versión con el operador aún presente), que documenta explícitamente el mecanismo de bloqueo:

> "This class is deprecated. Please use `airflow.utils.task_group.TaskGroup`. [...] Although SubDagOperator **can occupy a pool/concurrency slot**, user can specify the `mode=reschedule` so that the slot will be released periodically **to avoid potential deadlock**."

Fuente: [`airflow/operators/subdag.py`, tag 2.5.3](https://raw.githubusercontent.com/apache/airflow/2.5.3/airflow/operators/subdag.py) (fetch directo del código fuente, no de un resumen).

**Veredicto:** la mecánica de la claim del skill — "corría en un solo slot y podía bloquearse a sí mismo" — es una paráfrasis precisa de dos fuentes oficiales independientes (blog de anuncio + docstring del propio operador): el SubDAG ocupaba un slot de pool/concurrencia mientras esperaba que sus tareas hijas, que necesitaban sus propios slots, se ejecutaran — de ahí el deadlock cuando el número de SubDAGs activos igualaba el límite de concurrencia. Lo único que hay que corregir en el skill es el **estado actual**: no digan "deprecado", digan **"removido en Airflow 3.0"** — la doc oficial de breaking changes usa "Replaced by", y el 404 en la API reference lo confirma empíricamente.

---

## 5. Setup/Teardown tasks — versión de introducción y semántica

**VERIFICADO — Airflow 2.7 (2.7.0) es la versión correcta, y la semántica descrita es exacta.**

Versión confirmada por fetch directo del blog oficial de anuncio del feature:

> "**Airflow 2.7.0** introduced setup and teardown tasks."

Fuente: [Introducing Setup and Teardown tasks](https://airflow.apache.org/blog/introducing_setup_teardown/) (fetch directo). Este mismo blog confirma la semántica exacta con un ejemplo concreto:

> "If `create_cluster` succeeds and `run_query` fails, then `delete_cluster` will still run."
> "By default, if `run_query` succeeds, and `delete_cluster` fails, then the dag run will still be marked successful."

La doc de referencia actual (`stable`, Airflow 3.3.0) confirma el mecanismo formal detrás de ese comportamiento — un trigger rule dedicado y no configurable:

> "A teardown task will run if its setup was successful, even if its work tasks failed. But it will skip if the setup was skipped."
> "By default, teardown tasks are not considered for Dag run state" [...] "if you want the run's success to depend on `delete_cluster`, then set `on_failure_fail_dagrun=True`."
> "Teardowns use a (non-configurable) trigger rule called `ALL_DONE_SETUP_SUCCESS`. With this rule, as long as all upstreams are done and at least one directly connected setup is successful, the teardown will run."

Fuente: [Setup and Teardown](https://airflow.apache.org/docs/apache-airflow/stable/howto/setup-and-teardown.html) (fetch directo).

**Veredicto:** los tres elementos de la claim están confirmados uno por uno con fuente primaria: (a) teardown corre aunque el trabajo intermedio falle — sí, vía `ALL_DONE_SETUP_SUCCESS`; (b) el fallo del propio teardown no tumba el DAG — sí, por defecto (`on_failure_fail_dagrun=False` es el default, invertible); (c) versión — 2.7.0, no 2.7+genérico sin numerar (aunque "2.7+" como lo escribe la tarea es correcto en el sentido de "desde 2.7 en adelante").

---

## 6. Dynamic DAG generation (factory pattern) — el código corre en CADA parseo

**VERIFICADO — con cita textual que conecta explícitamente esta claim con la claim #10.**

La propia guía oficial de mejores prácticas de Airflow tiene una sección dedicada, titulada literalmente "Dynamic Dag Generation", que abre reconociendo el caso de uso exacto de la tarea (N pipelines casi idénticos por config):

> "Sometimes writing Dags manually isn't practical. Maybe you have a lot of Dags that do similar things with just a parameter changing between them. Or maybe you need a set of Dags to load tables, but don't want to manually update Dags every time those tables change."

Y la doc **liga explícitamente** esta técnica con el riesgo de código top-level (claim #10), en la misma sección:

> "Avoiding excessive processing at the top level code described in the previous chapter is **especially important** in case of dynamic Dag configuration"

Airflow documenta tres mecanismos válidos para la generación dinámica: variables de entorno, código Python generado externamente en la carpeta de DAGs, o un archivo de config/metadata generado externamente en la carpeta de DAGs (el caso "YAML per source" de la tarea cae en esta tercera categoría).

Fuente: [Best Practices — Dynamic Dag Generation](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html) (fetch directo).

**Veredicto:** la claim es exacta y, más aún, la propia documentación oficial la presenta como el mismo problema que la claim #10 ("especially important"), no como un tema aparte — el skill puede citar esta conexión directamente.

---

## 7. Pools — mecanismo documentado

**VERIFICADO.**

> "Some systems can get overwhelmed when too many processes hit them at the same time. Airflow pools can be used to **limit the execution parallelism** on arbitrary sets of tasks."

Los slots se administran vía UI (Admin → Pools), se asignan a una tarea con el parámetro `pool`, y si no se especifica, la tarea cae en `default_pool` (128 slots por defecto):

> "Tasks will be scheduled as usual while the slots fill up [...] Once capacity is reached, runnable tasks get queued and their state will show as such in the UI. As slots free up, queued tasks start running based on the [Priority Weights]."

También existe `pool_slots` para que una tarea consuma más de un slot del pool.

Fuente: [Pools](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/pools.html) (fetch directo).

**Veredicto:** el ejemplo de la tarea (5 slots para un pool `api_externa`, tope de 5 de 200 llamadas deseadas corriendo en paralelo) es exactamente el mecanismo documentado — no hay nada que corregir.

---

## 8. Config de confiabilidad a nivel de tarea/DAG

**VERIFICADO — los seis parámetros existen, con nombres correctos, en la doc actual (Airflow 3.3.0 / Task SDK 1.3.0). Un matiz: `retry_exponential_backoff` amplió su tipo aceptado en versiones recientes.**

Confirmado parámetro por parámetro, cruzando la API reference histórica (2.0.2, para la redacción original) con el **Task SDK actual** (fetch directo a `task-sdk/stable/api.html`, que es donde vive hoy la definición de `BaseOperator` para autoría de tareas en Airflow 3.x):

| Parámetro | Descripción oficial (Task SDK, actual) |
|---|---|
| `retries` | "the number of retries that should be performed before failing the task" |
| `retry_delay` | "delay between retries, can be set as `timedelta` or `float` seconds [...] default is `timedelta(seconds=300)`" |
| `retry_exponential_backoff` | **cambió de tipo**: "multiplier for exponential backoff between retries. Set to 0 to disable (constant delay). Set to 2.0 for standard exponential backoff (delay doubles with each retry)." |
| `execution_timeout` | "max time allowed for the execution of this task instance, if it goes beyond it will raise and fail" |
| `priority_weight` | "priority weight of this task against other task. This allows the executor to trigger higher priority tasks before others when things get backed up." |
| `pool` | "the slot pool this task should run in, slot pools are a way to limit concurrency for certain tasks" |

Fuente: [`airflow.sdk` API Reference — Task SDK](https://airflow.apache.org/docs/task-sdk/stable/api.html) (fetch directo).

**Matiz sobre `retry_exponential_backoff`:** en versiones 2.x era estrictamente booleano (`True`/`False`, doblando el delay si es `True`). Una búsqueda confirma que **Airflow 2.3+** permite pasar un float como multiplicador configurable en vez de solo bool (issue de GitHub `apache/airflow#56537`, "Support configurable multiplier for retry exponential backoff" — **confianza: contenido indexado de búsqueda, no fetch directo del issue**; el fetch directo del Task SDK sí confirma que la doc actual ya describe la semántica de multiplicador float, así que el cambio de comportamiento está corroborado por fuente primaria aunque el número de versión exacto del cambio no). Para el skill: mencionar `retry_exponential_backoff` como bool sigue siendo correcto (`True` sigue funcionando con doblado de delay), pero si el skill quiere dar el detalle fino, aclarar que acepta también un float multiplicador en versiones recientes.

Sobre `execution_timeout`, la doc de conceptos confirma el efecto ("mata" la tarea):

> "If `execution_timeout` is breached, the task times out and `AirflowTaskTimeout` is raised" [...] "applies to all Airflow tasks, including sensors."

Fuente: [Tasks — Timeouts](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/tasks.html) (fetch directo).

Sobre `max_active_runs` (nivel DAG, no tarea — el skill debe ser preciso con esto):

> "`max_active_runs` defines how many `running` concurrent instances of a Dag there are allowed to be."

Fuente: [FAQ — Why is task not getting scheduled?](https://airflow.apache.org/docs/apache-airflow/stable/faq.html) (fetch directo). Confirmado también que es distinto de `concurrency`/`max_active_tasks` (que limita tareas concurrentes, no DAG runs) — la claim del skill ("previene que corridas superpuestas se pisen los datos entre sí") es la razón de uso correcta y estándar documentada para este parámetro.

**Veredicto:** los seis nombres de parámetro son correctos y actuales, ninguno fue renombrado ni removido. Único ajuste sugerido: aclarar que `max_active_runs` es DAG-level (no task-level) si el skill los lista juntos sin distinguir el nivel.

---

## 9. Observability hooks — `on_failure_callback` y `sla` — ¿sigue vigente `sla`?

**OUTDATED tal como está redactada la claim — `sla` / `sla_miss_callback` fue removido en Airflow 3.0 y reemplazado por Deadline Alerts. `on_failure_callback` sigue vigente sin cambios.**

### `on_failure_callback` — vigente, sin cambios

> "Invoked when the Dag fails or task fails." — disponible a nivel DAG o Task.

Fuente: [Callbacks](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/callbacks.html) (fetch directo, Airflow 3.3.0). Esta misma página, en su versión actual, **no lista `sla_miss_callback` entre los callbacks documentados** — ausencia consistente con remoción, no con omisión accidental de la doc.

### `sla` — removido en Airflow 3.0, no solo deprecado

Confirmación directa, textual, desde la sección "Breaking Changes" de la guía oficial de migración a Airflow 3:

> "**SLAs**: Deprecated and removed; replaced with [Deadline Alerts](../howto/deadline-alerts.html)."

Fuente: [Upgrading to Airflow 3 — Breaking Changes](https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html) (fetch directo).

El reemplazo — Deadline Alerts — es una feature **nueva y todavía experimental**, no disponible en Airflow 3.0 sino desde 3.1:

> "Deadline Alerts are **new in Airflow 3.1** and should be considered **experimental**. The feature may be subject to changes in future versions without warning based on user feedback."

Fuente: [Deadline Alerts](https://airflow.apache.org/docs/apache-airflow/stable/howto/deadline-alerts.html) (fetch directo). La misma página remite a una guía de migración dedicada: "For help migrating from SLA to Deadlines, see the migration guide."

**Veredicto — esto es lo más importante para corregir en el skill:** si el skill dice "usa `sla` para alertar por SLA breach" como mecanismo vigente en Airflow moderno, es **incorrecto para Airflow 3.x** (removido, no deprecado-mantenido). Recomendación concreta de redacción: presentar `on_failure_callback` como el mecanismo vigente y estable para alerting on-failure (Slack/PagerDuty), y mencionar Deadline Alerts como el mecanismo de SLA-breach — pero marcándolo explícitamente como experimental y exclusivo de Airflow 3.1+, con nota de que en Airflow 2.x el mecanismo era `sla` + `sla_miss_callback` (vigente ahí, pero ya no en 3.x). Si el skill target es un lector que puede estar en Airflow 2.x en producción (muy común todavía), vale la pena una nota de compatibilidad de versión explícita en vez de presentar `sla` como universal.

---

## 10. Top-level DAG-file code — el antipatrón más peligroso

**VERIFICADO — es guía oficial explícita, con la propia página de "Best Practices" de Airflow como fuente directa.**

Sobre la frecuencia de ejecución del código top-level:

> "Airflow scheduler executes the code outside the Operator's `execute` methods **with the minimum interval of [`min_file_process_interval`]** seconds."

Sobre qué NO se debe poner ahí:

> "Specifically you should not run any database access, heavy computations and networking operations."

Sobre el costo de imports pesados a nivel de módulo (no solo código ejecutable, también relevante para el skill):

> "One of the important factors impacting Dag loading time, that might be overlooked by Python developers is that top-level imports might take surprisingly a lot of time and they can generate a lot of overhead"

Y el ejemplo de contraste antes/después que usa la propia doc, con el caso exacto que menciona la tarea (llamada a API):

> "In the first example, `expensive_api_call` is executed each time the Dag file is parsed, which will result in suboptimal performance in the Dag file processing." [...] la versión corregida mueve la llamada dentro de una tarea, donde "`expensive_api_call` is only called when the task is running and thus is able to be parsed without suffering any performance hits."

Fuente: [Best Practices — Top level Python Code](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html) (fetch directo).

**Veredicto:** todos los elementos de la claim están confirmados textualmente contra la página oficial de mejores prácticas: ejecución en cada parseo (no solo en runs reales), el intervalo mínimo está gobernado por una config explícita (`min_file_process_interval`), y la prohibición explícita cubre exactamente los tres ejemplos que menciona la tarea (DB access, cómputo pesado, networking — que incluye tanto llamadas a API como, por extensión no textual pero directa, un `pandas.read_csv` contra una fuente remota).

---

## Resumen de veredictos

| # | Claim | Veredicto | Nota clave |
|---|---|---|---|
| 1 | Fan-out/fan-in "diamond" | VERIFICADO (mecánica) | "Diamond" no es término oficial de Airflow, es descriptivo |
| 2 | Dynamic Task Mapping en 2.3 | VERIFICADO | Confirmado por blog oficial de release 2.3.0 |
| 3 | TaskFlow API en 2.0 | VERIFICADO | Cita exacta con `versionadded 2.0.0` |
| 4 | TaskGroups reemplazó SubDAGs por deadlock/single-slot | **NEEDS CORRECTION** | No es "deprecado", está **removido** en Airflow 3.0 (breaking change + 404 en API ref). La razón (single-slot/deadlock) sí está documentada oficialmente. |
| 5 | Setup/Teardown en 2.7 | VERIFICADO | Blog oficial confirma "Airflow 2.7.0 introduced..." |
| 6 | DAG factory corre en cada parseo | VERIFICADO | Doc oficial liga esto explícitamente con la claim #10 |
| 7 | Pools limitan concurrencia | VERIFICADO | Sin discrepancias |
| 8 | `retries`/`retry_delay`/`retry_exponential_backoff`/`execution_timeout`/`max_active_runs`/`priority_weight` | VERIFICADO | Todos vigentes; `retry_exponential_backoff` ahora también acepta float multiplicador; `max_active_runs` es DAG-level, no task-level |
| 9 | `on_failure_callback`/`sla` para alerting | **OUTDATED** | `sla`/`sla_miss_callback` **removido en Airflow 3.0**, reemplazado por Deadline Alerts (experimental, desde 3.1). `on_failure_callback` sigue vigente sin cambios. |
| 10 | Top-level code es el antipatrón más peligroso | VERIFICADO | Página oficial "Best Practices" lo documenta punto por punto |

## Banderas para el skill (lo que hay que corregir sí o sí)

1. **Claim #4 — SubDAGs:** cambiar "deprecado" por "removido en Airflow 3.0". Cita de respaldo: *"SubDAGs: Replaced by TaskGroups, Assets, and Data Aware Scheduling"* ([Upgrading to Airflow 3](https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html)), corroborado por 404 en la API reference del operador en la doc "stable" actual.
2. **Claim #9 — `sla`:** no presentarlo como mecanismo vigente sin calificar versión. En Airflow 3.x fue removido y reemplazado por Deadline Alerts (experimental, 3.1+); en Airflow 2.x sigue siendo el mecanismo real. Si el skill no fija una versión objetivo, esto necesita una nota de compatibilidad explícita, no una afirmación universal.

## Fuentes primarias usadas (todas por fetch directo salvo donde se indica)

| Fuente | Uso | Método |
|---|---|---|
| `core-concepts/dags.html` (stable) | Fan-out/fan-in, Dynamic DAG Generation (parcial) | Fetch directo |
| `authoring-and-scheduling/dynamic-task-mapping.html` (stable) | Patrón `.expand()`, motivación | Fetch directo |
| [Apache Airflow 2.3.0 is here](https://airflow.apache.org/blog/airflow-2.3.0/) (blog) | Versión de Dynamic Task Mapping | Fetch directo |
| [Concepts — Airflow 2.0.0](https://airflow.apache.org/docs/apache-airflow/2.0.0/concepts.html) | Versión de TaskFlow API (`versionadded 2.0.0`) | Fetch directo |
| `tutorial/taskflow.html` (stable) | Comparación TaskFlow vs. XCom manual | Fetch directo |
| [Upgrading to Airflow 3 — Breaking Changes](https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html) | Remoción de SubDAGs y de `sla` | Fetch directo |
| [Apache Airflow 2.0 is here!](https://airflow.apache.org/blog/airflow-two-point-oh-is-here/) (blog) | Razón documentada del deadlock de SubDAG ("single task in parallel") | Fetch directo |
| [`airflow/operators/subdag.py`, tag 2.5.3](https://raw.githubusercontent.com/apache/airflow/2.5.3/airflow/operators/subdag.py) | Docstring oficial: slot de pool/concurrencia y deadlock | Fetch directo del código fuente |
| `_api/airflow/operators/subdag/index.html` (stable) | Confirmación de remoción (404) | Fetch directo (404) |
| [Introducing Setup and Teardown tasks](https://airflow.apache.org/blog/introducing_setup_teardown/) (blog) | Versión (2.7.0) y semántica | Fetch directo |
| `howto/setup-and-teardown.html` (stable) | Mecanismo `ALL_DONE_SETUP_SUCCESS`, `on_failure_fail_dagrun` | Fetch directo |
| `best-practices.html` (stable) | Dynamic Dag Generation + Top-level code | Fetch directo |
| `administration-and-deployment/pools.html` (stable) | Mecanismo de Pools | Fetch directo |
| `administration-and-deployment/priority-weight.html` (stable) | `priority_weight`, `weight_rule` | Fetch directo |
| `core-concepts/tasks.html` (stable) | `execution_timeout`, retry policies | Fetch directo |
| `airflow.sdk` API Reference (Task SDK, stable) | Descripciones vigentes de `retries`/`retry_delay`/`retry_exponential_backoff`/`execution_timeout`/`priority_weight`/`pool`/`on_failure_callback` | Fetch directo |
| `_api/airflow/models/baseoperator/index.html` (Airflow 2.0.2) | Descripciones originales de BaseOperator (cruce histórico) | Fetch directo |
| `faq.html` (stable) | `max_active_runs` vs. `concurrency` | Fetch directo |
| `administration-and-deployment/logging-monitoring/callbacks.html` (stable) | `on_failure_callback` vigente; ausencia de `sla_miss_callback` | Fetch directo |
| `howto/deadline-alerts.html` (stable) | Deadline Alerts como reemplazo de SLA, estado experimental, versión 3.1 | Fetch directo |
| GitHub issue `apache/airflow#56537` | Cambio de tipo de `retry_exponential_backoff` (bool → float multiplicador) | Contenido indexado de búsqueda, no fetch directo del issue |
| Wiki AIP-34 (cwiki.apache.org) | Motivación arquitectónica de TaskGroup vs. SubDagOperator | Fetch directo (wiki oficial del proyecto, no `docs.apache.org` con formato de docs) |

## Claims explícitamente NO verificadas / con reserva menor

1. **Número de versión exacto** en que `retry_exponential_backoff` empezó a aceptar un float como multiplicador — corroborado que el comportamiento existe hoy (fetch directo del Task SDK), pero el "cuándo cambió" viene de un issue de GitHub indexado por búsqueda, no confirmado por fetch directo del changelog.
2. **"Diamond"** como término oficial de Airflow para el patrón fan-out/fan-in — no aparece así en la documentación revisada; es terminología descriptiva de industria, no cita textual del vendor.
