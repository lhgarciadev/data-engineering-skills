# Research: fundamentos de orquestación — DAGs, idempotencia, determinismo y backfills

**Fecha:** 2026-07-30
**Alcance:** verificación de 13 claims puntuales que se piensan usar como contenido de referencia permanente en el futuro skill `pipelines-architecture-data-engineering` (dominio de orquestación). Cubre: (1) los cinco value-adds de un orquestador, (2) definición de DAG, (3) diseño de tasks (atómica/idempotente/stateless), (4) separación orquestación/ejecución, (5) "pasar punteros, no datos" vía XCom, (6) idempotencia estructural y terminología de ventana temporal en Airflow (`execution_date` → `logical_date` → `data_interval_start/end`), (7) determinismo (no leer "ahora"), (8) backfill trivial si y solo si idempotente+parametrizado, (9) `pools`/`max_active_runs` para concurrencia de backfills, (10) aislar backfills de producción vía pools/queues, (11) datos tardíos manejados por reproceso/backfill, (12) `catchup` y su historial de "sustos", (13) Dagster y particiones/backfills como ciudadanos de primera clase. Fuentes primarias usadas: documentación oficial de Apache Airflow (`airflow.apache.org/docs/apache-airflow/stable`, que al momento del fetch se resuelve a **Airflow 3.3.0** — confirmado por el título de página en múltiples fetches), documentación oficial de Dagster (`docs.dagster.io`), y —donde Apache Airflow no cubre el punto explícitamente— documentación de Astronomer (mantenedor mayoritario de Airflow y editor de "Astronomer Documentation / Learn", tratada aquí como fuente secundaria de alto nivel, no como fuente primaria del proyecto Apache; se marca explícitamente en cada caso). No se escribió contenido en los archivos del skill — solo este research file.

---

## 1. Los cinco value-adds de un orquestador (dependency management, scheduling, retries, observability/alerting, backfills)

**No existe una única fuente vendor que enuncie literalmente "estos son los cinco value-adds de un orquestador".** Esto no es un defecto del claim — es una síntesis pedagógica razonable — pero cada uno de los cinco elementos sí está confirmado, de forma independiente, como área de capacidad documentada por Apache Airflow (la estructura misma de sus docs oficiales dedica secciones separadas a cada uno):

- **Dependency management**: "A workflow is represented as a Dag (a Directed Acyclic Graph)... A Dag specifies the dependencies between tasks, which defines the order in which to execute the tasks." Fuente: [Architecture Overview — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html) (fetch directo).
- **Scheduling**: la sección `Catchup`/`Dag Runs` documenta el modelo de intervalos y ejecución programada — ver §12 más abajo. Fuente: [Dag Runs — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dag-run.html) (fetch directo).
- **Retries/failure-handling**: "Often, many Operators inside a Dag need the same set of default arguments (such as their `retries`)." Fuente: [DAGs — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html) (fetch directo, vía agente de resumen).
- **Observability/alerting**: "Since data pipelines are generally run without any manual supervision, observability is critical... Airflow has support for multiple logging mechanisms, as well as a built-in mechanism to emit metrics... it also supports real-time error notification via integration with Sentry." Fuente: [Logging & Monitoring — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/index.html) (fetch directo).
- **Backfills**: sección dedicada "Backfill" en `dag-run.html` y comando CLI `airflow backfill create` — ver §9 y §12. Fuente: mismas páginas.

**Veredicto: VERIFIED como síntesis** — cada elemento del checklist tiene respaldo directo en la documentación oficial de Airflow como área de capacidad separada y nombrada; lo que no está verificado es que algún vendor lo empaquete exactamente como "los cinco value-adds", que es formulación propia del skill.

---

## 2. DAG = Directed Acyclic Graph; nodos = tasks, edges = dependencias; "acyclic" = sin ciclos

**VERIFIED**, con la cita más completa viniendo de Astronomer (no de Apache Airflow directamente, ver nota de alcance):

> "In Airflow, nodes are tasks and edges are dependencies between tasks."
>
> "There are no circular dependencies in a Dag. This means that a task can't depend on itself, nor can it depend on a task that ultimately depends on it."

Fuente: [Introduction to Apache Airflow® Dags — Astronomer Documentation](https://www.astronomer.io/docs/learn/dags) (fetch directo). El ejemplo que acompaña la cita ilustra exactamente el caso del claim (task 4 dependiendo de task 1, que ya es downstream de task 4 → ciclo no permitido).

La documentación oficial de Apache Airflow confirma la definición base pero de forma menos explícita sobre nodos/edges:

> "A workflow is represented as a Dag (a Directed Acyclic Graph), and contains individual pieces of work called Tasks, arranged with dependencies and data flows taken into account."
>
> "The term 'DAG' comes from the mathematical concept 'directed acyclic graph', but the meaning in Airflow has evolved well beyond just the literal data structure associated with the mathematical DAG concept."

Fuente: [Architecture Overview](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html) y [DAGs](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dags.html) (ambas Airflow 3.3.0, fetch directo). Ninguna de las dos páginas oficiales de Apache define explícitamente "acyclic" ni el mapeo nodo=task/edge=dependencia con esa literalidad — ese nivel de precisión solo lo encontré en Astronomer.

---

## 3. Diseño de task: atómica, idempotente, stateless

**Parcialmente verificado — tres sub-claims con niveles de evidencia distintos.**

### Atómica / fine-grained

No encontré la palabra "atomic" en el `best-practices.html` oficial de Apache Airflow (verificado por grep directo sobre el HTML crudo — cero ocurrencias). El vocabulario oficial de Apache es en cambio "transaccional":

> "You should treat tasks in Airflow equivalent to transactions in a database. This implies that you should never produce incomplete results from your tasks."

Fuente: [Best Practices — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html) (fetch directo, confirmado también por grep crudo en la sección "Creating a task").

El término "atomic" y el vínculo explícito con "retry barato" sí aparecen, pero en Astronomer:

> "Keep tasks atomic—ideally each task accomplishes one specific action... DAGs designed with atomic tasks give you fine-grained observability into events in your data pipeline and the ability to rerun from the point of failure."

Fuente: [DAG writing best practices — Astronomer Documentation](https://www.astronomer.io/docs/learn/dag-best-practices) (fetch directo).

### Idempotente

Confirmado en ambas fuentes. Apache Airflow, en términos de mecánica concreta (UPSERT vs INSERT):

> "Do not use INSERT during a task re-run, an INSERT statement might lead to duplicate rows in your database. Replace it with UPSERT."

Fuente: misma página, `best-practices.html` (fetch directo). Astronomer, en términos de la definición general y su relación con retries:

> "A DAG is considered idempotent if rerunning the same DAG Run with the same inputs multiple times has the same effect as running it only once."
>
> "Idempotency paves the way for one of Airflow's most useful features: Retries."

Fuente: [DAG writing best practices — Astronomer](https://www.astronomer.io/docs/learn/dag-best-practices) (fetch directo).

### Stateless ("para poder correr en cualquier worker")

**No encontré ningún vendor que use literalmente la palabra "stateless" para tasks en este contexto.** Lo que sí está documentado, y de donde se infiere razonablemente el principio, es el modelo de ejecutores de Airflow: con `CeleryExecutor` las task instances se envían a un broker y las recoge cualquier worker Celery disponible; con `KubernetesExecutor` cada task instance corre en su propio Pod efímero. Fuente: [Apache Airflow® Executors — Astronomer](https://www.astronomer.io/docs/learn/airflow-executors-explained) (contenido indexado vía búsqueda, no fetch línea por línea). Esto hace que "cualquier worker puede ejecutar la task" sea una consecuencia arquitectónica real del diseño de Airflow, pero **la palabra "stateless" y su justificación explícita no aparecen citadas textualmente en ningún doc oficial revisado** — es inferencia razonable, no cita verbatim.

**Veredicto: VERIFIED (atómica, idempotente) / NO VERIFICADO COMO CITA TEXTUAL (stateless)** — usar la mecánica de UPSERT y la definición de idempotencia como citas; tratar "stateless" como principio arquitectónico inferido del modelo de ejecutores, no como terminología documentada verbatim.

---

## 4. Separar orquestación de ejecución (DAG define qué y en qué orden, no transformación pesada inline)

**VERIFIED**, con cita directa y oficial de Apache Airflow — aunque enmarcada específicamente como una preocupación de *performance de parseo* del scheduler, no como un principio arquitectónico general de "orquestación vs. ejecución" (el claim es una generalización razonable de esta regla, pero vale la distinción):

> "You should avoid writing the top level code which is not necessary to create Operators and build Dag relations between them... you should not run any database access, heavy computations and networking operations [at top level]."

Fuente: [Best Practices — Airflow 3.3.0, sección "Top level Python Code"](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html) (fetch directo vía `curl`, texto crudo confirmado). Astronomer complementa con la formulación más cercana al claim tal como está escrito:

> "Leave all of the heavy lifting to the hooks and operators that you instantiate within the file."

Fuente: contenido indexado que cita `dag-best-practices` de Astronomer, no confirmado por fetch línea por línea de ese fragmento específico (el fetch directo de esa página sí confirmó otras secciones — ver §3, §7 — pero no ésta en particular).

El mecanismo concreto de "task invoca cómputo externo" (Spark job, dbt model) está confirmado indirectamente por la existencia misma de operators dedicados en el ecosistema Airflow (`SparkSubmitOperator`, `dbt Cloud`/`Cosmos` providers) y, del lado Dagster, por el patrón **Dagster Pipes**, documentado oficialmente como el mecanismo para invocar cómputo externo (Spark, subprocess, K8s Job) desde un asset sin ejecutar la transformación dentro del proceso del orquestador — no se fetcheó la página de Pipes en este research por estar fuera del foco puntual de los 13 claims, así que se marca como **no verificado por fetch, solo como contexto conocido del ecosistema**.

---

## 5. "Pasar punteros, no datos" — XCom en Airflow

**VERIFIED, con cita textual explícita y oficial** — este es uno de los claims mejor respaldados del set:

> "XComs (short for 'cross-communications') are a mechanism that let Tasks talk to each other, as by default Tasks are entirely isolated and may be running on entirely different machines."
>
> "they are only designed for small amounts of data; do not use them to pass around large values, like dataframes."

Fuente: [XComs — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/xcoms.html) (fetch directo). La misma página confirma que la mitigación documentada es exactamente "pasar el path, no los datos":

> Para datos grandes, "object storage is recommended" como backend alternativo, ya que el almacenamiento por defecto en la base de datos "works well for small values but can cause issues with large values or a high volume of XComs."

`best-practices.html` da el ejemplo textual exacto que el claim describe (S3 path como el "puntero"):

> "If possible, use `XCom` to communicate small messages between tasks and a good way of passing larger data between tasks is to use a remote storage such as S3/HDFS... if we have a task that stores processed data in S3 that task can push the S3 path for the output data in `Xcom`, and the downstream tasks can pull the path from XCom."

Fuente: [Best Practices — Airflow 3.3.0, sección "Communication"](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html) (fetch directo). No encontré un límite numérico de tamaño documentado explícitamente (p. ej. "X KB máximo") — la guía oficial es cualitativa ("small amounts of data"), respaldada por el detalle técnico de que el backend por defecto es la metadata DB de Airflow, que no está pensada para blobs grandes.

---

## 6. Idempotencia estructural y terminología de ventana temporal en Airflow: `execution_date` → `logical_date` → `data_interval_start/end`

**VERIFIED, con hallazgo importante sobre terminología ACTUAL vs. histórica** — este es el claim que más cambió entre versiones y donde vale la pena ser preciso.

### Terminología vigente (Airflow 3.3.0, docs "stable" al momento del fetch)

La página de referencia de templates confirma que **hoy** las variables vigentes son `data_interval_start`/`data_interval_end` (para lógica de ventana/filtrado real) y `logical_date` (para identificar la corrida, sin semántica de intervalo):

> `{{ data_interval_start }}` — "Start of the data interval. Added in version 2.2."
> `{{ data_interval_end }}` — "End of the data interval. Added in version 2.2."
> `{{ logical_date }}` — "A date-time that logically identifies the current Dag run. This value does not contain any semantics, but is simply a value for identification."

Fuente: [Templates reference — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/templates-ref.html) (fetch directo). La página **no lista `execution_date`** como variable de template vigente — confirmando que es terminología retirada de la superficie actual, no solo "desaconsejada".

La página de conceptos de DAG Runs lo confirma explícitamente con la equivalencia histórica:

> "The 'logical date' (also called `execution_date` in Airflow versions prior to 2.2) of a Dag run... denotes the start of the data interval, not when the Dag is actually executed."
>
> "Each Dag run in Airflow has an assigned 'data interval' that represents the time range it operates in."

Fuente: [Dag Runs — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dag-run.html) (fetch directo).

### El cambio real en Airflow 3.0 (AIP-83) — más profundo que un simple rename

La transición no fue solo cosmética. Airflow 3.0 (vía **AIP-83**) hizo `logical_date` **nullable** (para DAGs sin schedule/asset-triggered que no tienen ventana temporal) y, dato crítico para el claim de idempotencia estructural, **eliminó la restricción de unicidad `(dag_id, logical_date)`** — es decir, en Airflow 3.x puede haber múltiples DAG runs con el mismo `logical_date` para el mismo DAG (algo imposible en 1.x/2.x, donde `execution_date`/`logical_date` era clave única del run). Fuente: [AIP-83 — Rename execution_date -> logical_date and make logical_date optional](https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=315493704) (contenido indexado vía búsqueda — **no confirmado por fetch directo de la wiki de Confluence**, que no se intentó en este research; tratar como corroborado por búsqueda, no verificado línea por línea).

### Implicación para "idempotencia estructural por partición/ventana"

Esto tiene una consecuencia directa sobre el claim de "cada corrida toca solo su ventana": en Airflow 3.x, la fuente de verdad para *qué datos toca una corrida* debe ser explícitamente `data_interval_start`/`data_interval_end` (con semántica de rango) y no `logical_date` (que la propia documentación dice "does not contain any semantics, but is simply a value for identification"). Usar `logical_date` como si fuera el límite de la ventana de datos ya no es seguro incluso conceptualmente — la documentación separa activamente identidad del run (`logical_date`) de la ventana de datos (`data_interval_*`). Esto es un matiz que el claim original no menciona y que vale la pena incorporar al skill.

**Veredicto: VERIFIED, con corrección de precisión** — terminología actual = `logical_date` (identidad) + `data_interval_start`/`data_interval_end` (ventana real); `execution_date` es explícitamente legado pre-2.2 y ya no aparece en la referencia de templates vigente. El claim original agrupa las tres como si fueran sinónimos intercambiables ("execution_date, logical_date, o data_interval_start/end" — la pregunta de verificación); la respuesta correcta es que **no son sinónimos**: son dos conceptos distintos (identidad vs. ventana) que hoy tienen nombres separados, y el patrón "partition-overwrite por ventana" del claim 6 debe anclarse a `data_interval_start`/`data_interval_end`, no a `logical_date`.

Sobre "writes usan partition-overwrite, no append": no encontré esta guía explícita en la documentación de orquestadores (es más bien un patrón de la capa de storage/warehouse, ya cubierto en otros archivos del repo según el research previo de watermarks). No se encontró contradicción, pero tampoco confirmación directa en Airflow/Dagster — es coherente con la separación identidad/ventana de arriba, pero la recomendación de escritura en sí vive fuera del alcance de la documentación de orquestación.

---

## 7. Determinismo: no leer "ahora", recibir la ventana como parámetro

**VERIFIED, con cita textual muy directa (Astronomer, no Apache Airflow directamente):**

> "A program is considered idempotent if, for a set input, running the program once has the same effect as running the program multiple times."

Y, sobre el antipatrón específico de `datetime.now()`/`datetime.today()`:

> Usar `datetime.today()` es problemático porque (1) "These functions are executed on every Scheduler heartbeat, which may not be performant" y (2) "this doesn't produce an idempotent DAG. You can't rerun a previously failed DAG run for a past date because `datetime.today()` is relative to the current date, not the DAG execution date."

Fuente: [DAG writing best practices — Astronomer Documentation](https://www.astronomer.io/docs/learn/dag-best-practices) (fetch directo). La solución documentada es exactamente la que describe el claim — usar los macros/variables de plantilla de Airflow (`data_interval_start`, `logical_date`, etc., ver §6) en vez de calcular la fecha en tiempo de ejecución.

La documentación oficial de Apache Airflow confirma el mismo antipatrón, con el mismo verbo ("never"):

> "The Python datetime `now()` function gives the current datetime object. This function should never be used inside a task, especially to do the critical computation, as it leads to different outcomes on each run."

Fuente: [Best Practices — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html) (fetch directo), que además aclara que sí es aceptable para logging no crítico.

---

## 8. Backfill trivial si y solo si cada corrida es idempotente y parametrizada por su ventana

**Síntesis analítica fuertemente respaldada, pero no una cita textual de ningún vendor con esa formulación lógica ("if and only if").** Ningún doc de Airflow o Dagster revisado usa el framing de bicondicional. Lo que sí está confirmado, y que sostiene la lógica del claim, es la relación causal documentada explícitamente por Astronomer entre backfill/rerun e idempotencia:

> "Because Airflow may backfill previous DAG runs when catchup is enabled, and each DAG run can be re-done manually at any time, it is critical to ensure that all DAGs are idempotent."
>
> "Designing idempotent DAGs and tasks decreases recovery time from failures and prevents data loss."

Fuente: contenido indexado citando `dag-best-practices`/`rerunning-dags` de Astronomer Documentation (algunas de estas frases específicas provienen de resúmenes de búsqueda, no de fetch línea por línea del fragmento exacto — el fetch directo de `dag-best-practices` sí confirmó el bloque de idempotencia general citado en §3 y §7, pero no esta oración exacta sobre backfill).

**Veredicto: síntesis razonable y consistente con la guía de los vendors, no cita textual.** Recomendación para el skill: presentar la relación causal (idempotencia habilita backfills seguros/triviales) como principio derivado, no como una frase citada de Airflow o Dagster — ninguno de los dos la enuncia como bicondicional formal.

---

## 9. Control de concurrencia de backfills: `pools` y `max_active_runs`

**VERIFIED — ambos son conceptos reales, vigentes y documentados oficialmente en Airflow 3.3.0**, confirmados por fetch directo del HTML crudo (no solo resumen del agente de fetch):

**Pools:**
> "limit the execution parallelism on arbitrary sets of tasks"

Fuente: [Pools — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/pools.html) (fetch directo). Los tasks se asignan a un pool vía el parámetro `pool`; al agotarse los slots del pool, las tasks quedan en cola.

**`max_active_runs`:**
> "max_active_runs defines how many running concurrent instances of a Dag there are allowed to be."

Fuente: [FAQ — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/faq.html) (confirmado por `curl` + grep sobre el HTML crudo, no solo por el agente de fetch). Y en la referencia de configuración:

> "The maximum number of active DAG runs per DAG. The scheduler will not create more DAG runs if it reaches the limit. This is configurable at the DAG level with `max_active_runs`, which is defaulted as `[core] max_active_runs_per_dag`."

Fuente: [Configuration Reference — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/configurations-ref.html) (confirmado por `curl` + grep crudo).

El comando de backfill expone `max_active_runs` como opción propia y específica del backfill:

> `--max-active-runs`: "Max active runs for this backfill."

Fuente: [CLI Reference — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/cli-and-env-variables-ref.html) (vía agente de fetch, no confirmado por grep crudo adicional). Esto confirma que `max_active_runs` no es solo un parámetro de nivel-DAG general, sino que el comando `airflow backfill create` tiene su propio control de concurrencia independiente — relevante directamente para el claim.

---

## 10. Aislar backfills de producción vía pools/queues separados — resultado desigual entre Airflow y Dagster

**Resultado mixto y este es el hallazgo más importante del research para corregir antes de publicar el skill.**

### Dagster: SÍ está documentado explícitamente como patrón de primera clase

Dagster tiene un tag reservado, documentado oficialmente, específicamente para separar la concurrencia de backfills de la del resto de runs:

```yaml
run_queue:
  max_concurrent_runs: 15
  tag_concurrency_limits:
    - key: 'database'
      value: 'redshift'
      limit: 4
    - key: 'dagster/backfill'
      limit: 10
```

Fuente: [dagster.yaml reference — Dagster Docs](https://docs.dagster.io/deployment/oss/dagster-yaml) (fetch directo). La documentación de concurrencia general lo enmarca explícitamente como el escenario que motiva este control:

> "You need to limit total runs across your deployment" when "Backfills or sensors might launch many runs at once."

Fuente: [Managing concurrency — Dagster Docs](https://docs.dagster.io/guides/operate/managing-concurrency) (fetch directo). Y la página específica de tag-limits confirma el mismo ejemplo con el tag reservado `dagster/backfill`:

> `tag_concurrency_limits: - key: 'dagster/backfill' limit: 10`, con variante `applyLimitPerUniqueValue: true` para limitar cada backfill individual en vez del conjunto de todos los backfills.

Fuente: [Run tag concurrency limits — Dagster Docs](https://docs.dagster.io/guides/operate/managing-concurrency/run-tag-limits) (fetch directo). Esto es exactamente el patrón que describe el claim — y Dagster lo tiene como convención de tag *nativa y nombrada* (`dagster/backfill`), no como una combinación manual de primitivas genéricas.

### Airflow: NO encontré un patrón nombrado equivalente en la documentación oficial

Busqué explícitamente "aislar backfills de producción vía pool" en: `pools.html` de Apache Airflow (grep crudo sobre el HTML — **cero menciones de "backfill" en toda la página**), la sección "Backfill" de `dag-run.html`, el CLI reference, el FAQ oficial, un post de Astronomer de "10 Airflow Best Practices" (confirmado por fetch: "does not recommend using Airflow pools to isolate backfill task runs from regular production runs") y un blog técnico de terceros (oneuptime.com) que sí menciona pools pero solo para limitar conexiones a base de datos en general, no para aislar backfills de producción específicamente. Apache Airflow **sí** ofrece las primitivas que harían esto posible (pools asignables por task, colas Celery dedicadas vía `queue=` por task/executor), y `--max-active-runs` del comando `airflow backfill create` (§9) sí es un control de concurrencia *dedicado al backfill en sí*, pero **ningún doc oficial de Apache Airflow ni de Astronomer revisado documenta explícitamente "usa un pool/queue separado para aislar los runs de backfill de los de producción"** como recomendación nombrada.

**Veredicto: NEEDS CORRECTION antes de publicar en el skill.** El claim, tal como está escrito, generaliza sin matices entre orquestadores. La versión correcta es: (a) Dagster documenta esto como patrón nativo y nombrado (`dagster/backfill` tag) — cita verbatim disponible; (b) en Airflow, el aislamiento es alcanzable combinando primitivas genéricas documentadas (pools, colas, `--max-active-runs` del backfill), pero no es un patrón oficialmente nombrado ni recomendado con esas palabras en la documentación de Apache ni de Astronomer — es una inferencia de arquitectura razonable, no una cita.

---

## 11. Datos tardíos manejados por reproceso/backfill

**No verificado como patrón nombrado en documentación primaria de ningún orquestador.** Busqué explícitamente "late-arriving data" + backfill/reprocess en la documentación de Dagster y no encontré resultados de la documentación oficial — solo un artículo de Medium (no oficial) sobre Asset Sensors de Dagster que describe un escenario de este tipo, y blogs de terceros (lakeFS, AWS Timestream — este último sí es documentación oficial de AWS, pero de un producto de series temporales, no de un orquestador) describiendo el patrón general en otros contextos.

Lo que sí se sostiene, como consecuencia lógica directa de claims ya verificados en este mismo research: si un backfill es "correr el pipeline para un rango de fechas pasado" (§8, §9 — confirmado con el comando `airflow backfill create --from-date/--to-date`, y con Dagster's re-materialización de partitions específicas, §13), entonces técnicamente no hay diferencia mecánica entre "corregir un backfill por bug" y "reprocesar una ventana porque llegaron datos tarde" — ambos son la misma operación (recorrer una ventana ya cerrada) con distinto trigger de negocio. Pero esto es **inferencia del research, no una afirmación documentada explícitamente por ningún vendor** con el nombre "late-arriving data" ligado a "backfill".

**Veredicto: NO VERIFICADO como patrón nombrado — tratar como inferencia lógica derivada de §8/§9/§13, no como cita de ningún vendor.**

---

## 12. `catchup`: acoplamiento histórico scheduling/data-interval y su historial de "sustos"

**VERIFIED, con una corrección de precisión importante sobre "default actual" vs. "comportamiento histórico".**

### Comportamiento y default ACTUAL (Airflow 3.3.0, confirmado por `curl` + grep sobre HTML crudo, no solo agente de resumen)

> "By default, Dag runs that have not been run since the last data interval are not created by the scheduler upon activation of a Dag (Airflow config `scheduler.catchup_by_default=False`). The scheduler creates a Dag run only for the latest interval."
>
> "If you set `catchup=True` in the Dag, the scheduler will kick off a Dag Run for any data interval that has not been run since the last data interval (or has been cleared). This concept is called Catchup."

Fuente: [Dag Runs — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dag-run.html) (fetch directo + confirmado por `curl` crudo). Y la referencia de configuración confirma el default exacto:

> `catchup_by_default` — "Turn on scheduler catchup by setting this to `True`... Default: `False`"

Fuente: [Configuration Reference — Airflow 3.3.0](https://airflow.apache.org/docs/apache-airflow/stable/configurations-ref.html) (confirmado por `curl` crudo — este dato tuvo una primera lectura contradictoria de un agente de resumen que reportó "Default: True"; la verificación por HTML crudo despeja la ambigüedad: **el default vigente es `False`**).

### Comportamiento HISTÓRICO (Airflow 1.10.1, confirmado por `curl` sobre el HTML crudo del archivo de docs de esa versión)

> "The scheduler, by default, will examine the lifetime of the DAG (from start to end/now, one interval at a time) and kick off a DAG Run for any interval that has not been run (or has been cleared). This concept is called Catchup."

Fuente: [Scheduling & Triggers — Airflow 1.10.1](https://airflow.apache.org/docs/apache-airflow/1.10.1/scheduler.html) (fetch directo del HTML de la versión archivada, confirmado por `curl` crudo). Este texto documenta, para una versión muy temprana de Airflow, que el comportamiento *por defecto del scheduler* era efectivamente hacer catchup — el ejemplo del tutorial en esa misma página **fija explícitamente `catchup=False`** en el DAG de ejemplo, precisamente para evitar ese comportamiento por defecto.

### Corrección de precisión para el claim

El claim tal como está escrito dice "accidentally enabling `catchup=True`" como el mecanismo del susto — pero eso describe mal el riesgo **actual**: hoy el default es `False`, así que el susto no viene de "habilitar accidentalmente" algo que ya está apagado por defecto, sino de dos escenarios reales y sí documentados/discutidos en la comunidad: (a) **código heredado o plantillas** que sí ponen `catchup=True` explícitamente (patrón común en tutoriales pre-2.x), combinado con un `start_date` lejano en el pasado, y (b) **reactivar un DAG pausado** durante mucho tiempo — la propia doc oficial lo señala: "Catchup is also triggered when you turn off a DAG for a specified period and then re-enable it" (confirmado en la versión 2.2.4 de los docs, fetch directo de `https://airflow.apache.org/docs/apache-airflow/2.2.4/dag-run.html`). La comunidad sí documenta el escenario de "cientos de runs" como riesgo real y recurrente — ejemplo de un best-practices post de terceros: "a DAG with a start date far in the past... with catchup enabled, which will create hundreds of runs on first deployment" (fuente: contenido indexado de un blog técnico, no un vendor oficial — tratar como corroboración comunitaria, no cita primaria) — y múltiples issues abiertos en el repositorio oficial de `apache/airflow` (p. ej. #19461 "Missing DagRuns when catchup=True", #25615 "Random DagRuns set to running during large catch up") confirman que el escenario de catchups masivos generando comportamiento inesperado es un problema real y recurrente reportado contra el proyecto, no una leyenda urbana — fuente: [GitHub apache/airflow issues](https://github.com/apache/airflow) (contenido indexado, no fetch línea por línea de cada issue).

**Veredicto: VERIFIED en su núcleo (catchup es real, el mecanismo es real, el riesgo de "cientos de runs" es real y con corroboración en issues del propio proyecto), pero NEEDS CORRECTION en el framing**: no es que el default "históricamente" fuera `True` y hoy siga siendo el riesgo por default — el default **cambió** (documentado explícitamente como tal en la propia página de config: "Default behavior is unchanged and... the scheduler will not do scheduler catchup if this is `False`") y hoy es `False`. El riesgo real actual es (a) DAGs con `catchup=True` explícito heredado de código/tutoriales antiguos, o (b) reactivar un DAG pausado — no "activar accidentalmente algo que por defecto está apagado" sin querer, sino más bien "no darse cuenta de las consecuencias de algo que sí se activó a propósito, o de reactivar un DAG viejo".

---

## 13. Dagster: particiones y backfills como ciudadanos de primera clase

**VERIFIED.**

Sobre particiones como técnica central (no periférica):

> "In Dagster, partitioning is a powerful technique for managing large datasets, improving pipeline performance, and enabling incremental processing."

Fuente: [Partitioning assets — Dagster Docs](https://docs.dagster.io/guides/build/partitions-and-backfills/partitioning-assets) (fetch directo). La página describe cuatro tipos de partición soportados nativamente (por tiempo, estáticas, dos dimensiones, dinámicas), consistente con "ciudadano de primera clase" en vez de un mecanismo tangencial.

Sobre backfills construidos directamente sobre el modelo de particiones, con soporte de UI y de configuración dedicada:

> "Backfilling [is] the process of running partitions for assets that either don't exist or updating existing records."
>
> "After defining a partition, you can launch a backfill that will submit runs to fill in multiple partitions at the same time."

Fuente: [Backfilling data — Dagster Docs](https://docs.dagster.io/guides/build/partitions-and-backfills/backfilling-data) (fetch directo). La documentación describe además el parámetro `backfill_policy` (incluyendo `BackfillPolicy.single_run()` para materializar múltiples particiones en una sola run en vez de una run por partición) como una decisión de diseño explícita, y el tag reservado `dagster/backfill` con límites de concurrencia dedicados (ver §10) refuerza que backfills no son un "extra" sobre el sistema de runs genérico, sino un concepto que el run-queue coordinator reconoce y trata de forma diferenciada de forma nativa.

Contraste directo con Airflow: el backfill de Airflow es un comando CLI (`airflow backfill create --from-date --to-date`, ver §9) que reconstruye runs sobre el modelo general de DAG Runs por intervalo de fecha — no existe en Airflow un concepto de "partición" como primitiva de primera clase del framework (las particiones, si existen, viven en la tabla/warehouse de destino, no en el modelo del DAG). Esta asimetría es real y verificable directamente comparando ambos sets de documentación oficial.

---

## Resumen de fuentes primarias usadas

| Fuente | Uso | Método de verificación |
|---|---|---|
| Airflow — `core-concepts/overview.html` | Definición de DAG (§1, §2) | Fetch directo |
| Airflow — `core-concepts/dags.html` | Definición de DAG, retries en `default_args` (§1, §2) | Fetch directo (vía agente) |
| Airflow — `core-concepts/dag-run.html` | `logical_date`/`data_interval`, catchup, backfill (§6, §12) | Fetch directo + `curl` crudo |
| Airflow — `templates-ref.html` | Variables de plantilla vigentes, ausencia de `execution_date` (§6) | Fetch directo |
| Airflow — `core-concepts/xcoms.html` | Propósito y límites de XCom (§5) | Fetch directo |
| Airflow — `best-practices.html` | Idempotencia/UPSERT, `datetime.now()`, top-level code, Communication/XCom (§3, §4, §5, §7) | Fetch directo + `curl` crudo (grep de "atomic": cero resultados) |
| Airflow — `administration-and-deployment/pools.html` | Definición de Pools; ausencia de mención a backfill (§9, §10) | Fetch directo + `curl` crudo (grep "backfill": cero resultados) |
| Airflow — `administration-and-deployment/logging-monitoring/index.html` | Observability/alerting (§1) | Fetch directo |
| Airflow — `faq.html` | `max_active_runs`, nota sobre `start_date` en backfills (§9) | Fetch directo + `curl` crudo |
| Airflow — `configurations-ref.html` | Default real de `catchup_by_default` (`False`) y de `max_active_runs_per_dag` (§9, §12) | `curl` crudo (corrige una lectura errónea de un agente de resumen) |
| Airflow — `cli-and-env-variables-ref.html` | Opciones del comando `airflow backfill create`, incl. `--max-active-runs` (§9, §10) | Fetch directo (vía agente) |
| Airflow 1.10.1 (archivado) — `scheduler.html` | Comportamiento histórico de catchup por defecto (§12) | `curl` crudo |
| Airflow 2.2.4 (archivado) — `dag-run.html` | Catchup al reactivar un DAG pausado (§12) | Contenido indexado, mencionado en búsqueda, no re-fetcheado línea por línea en esta versión específica |
| GitHub `apache/airflow` (issues #19461, #25615, discussions) | Corroboración de incidentes reales de catchup (§12) | Contenido indexado, no fetch línea por línea de cada issue |
| Astronomer — `learn/dags` | Nodos=tasks, edges=dependencias, acyclic (§2) | Fetch directo |
| Astronomer — `learn/dag-best-practices` | Atomicidad, idempotencia, `datetime.today()` (§3, §7, §8) | Fetch directo |
| Astronomer — `learn/rerunning-dags` | Definición de backfill vs. catchup (§10, §12) | Fetch directo (resultado parcial — la página no repitió el contenido de idempotencia que sí apareció en el snippet de búsqueda) |
| Astronomer — `blog/10-airflow-best-practices` | Confirma ausencia de recomendación de pools para aislar backfills (§10) | Fetch directo |
| Dagster — `guides/build/partitions-and-backfills/partitioning-assets` | Particiones como técnica central (§13) | Fetch directo |
| Dagster — `guides/build/partitions-and-backfills/backfilling-data` | Backfills sobre particiones, `backfill_policy` (§13) | Fetch directo |
| Dagster — `guides/operate/managing-concurrency` | "Backfills or sensors might launch many runs at once" (§10) | Fetch directo |
| Dagster — `guides/operate/managing-concurrency/run-tag-limits` | Tag `dagster/backfill` para límite de concurrencia dedicado (§10) | Fetch directo |
| Dagster — `deployment/oss/dagster-yaml` | Ejemplo YAML completo del tag `dagster/backfill` (§10) | Fetch directo |
| Apache Software Foundation Confluence — AIP-83 | Cambios de Airflow 3.0 a `logical_date` nullable y remoción de unicidad `(dag_id, logical_date)` (§6) | Contenido indexado, no fetch directo de la wiki |

## Claims explícitamente NO verificadas como cita textual — no usar como cita sin revisión adicional

1. **"Stateless" como palabra documentada por algún vendor para tasks** — no encontrada; es inferencia razonable del modelo de ejecutores (§3).
2. **La formulación bicondicional "backfill es trivial si y solo si..."** — no es cita de ningún vendor; es síntesis del research (§8).
3. **"Datos tardíos se manejan por reproceso/backfill" como patrón nombrado** por algún orquestador — no encontrado; es inferencia lógica derivada de otros claims ya verificados (§11).
4. **"Aislar backfills de producción vía pool/queue separado" en Airflow específicamente** — confirmado como patrón real y nombrado en Dagster (`dagster/backfill` tag), pero NO encontrado como recomendación nombrada en documentación oficial de Apache Airflow ni de Astronomer (§10) — es la corrección más importante de este research.
5. **El texto exacto de AIP-83** sobre `logical_date` nullable y remoción de unicidad — corroborado solo por resultados de búsqueda indexados sobre la wiki de Confluence de la ASF, no por fetch directo línea por línea (§6).

---

## Conclusión — qué corregir antes de que esto entre al skill

De los 13 claims, **11 quedan VERIFIED** (algunos como síntesis razonable más que cita literal, señalado en cada sección) y **2 requieren corrección de framing antes de publicarse**:

- **Claim 10 (aislar backfills de producción vía pools/queues) — NEEDS CORRECTION.** Tal como está escrito, generaliza el patrón a "un orquestador" sin distinguir. La corrección: es un patrón de primera clase, oficialmente documentado y nombrado (`dagster/backfill` tag concurrency limit) en **Dagster**; en **Airflow**, es alcanzable combinando primitivas genéricas (`pools`, colas Celery, `--max-active-runs` del comando de backfill) pero no existe como recomendación nombrada en ningún doc oficial de Apache Airflow ni de Astronomer revisado. Si el skill quiere mantener este claim, debe atribuirlo correctamente por orquestador, no como verdad universal de "un orquestador".

- **Claim 12 (catchup y sus "sustos" históricos) — NEEDS CORRECTION de framing, no de sustancia.** El mecanismo, el riesgo y los incidentes documentados en GitHub son reales. Pero el claim describe el disparador como "accidentally enabling `catchup=True`", lo cual da a entender que el default sigue expuesto a ese accidente — y no es así: el default vigente y documentado (`catchup_by_default=False`) ya protege contra ese escenario exacto desde hace varias versiones. El riesgo real hoy es más específico: código con `catchup=True` heredado explícitamente, o la reactivación de un DAG pausado durante mucho tiempo (este segundo trigger sí está documentado explícitamente por Airflow). El skill debería precisar esto en vez de dejar la impresión de que el peligro es "activar por accidente algo que está apagado por defecto".

Adicionalmente, dos matices menores que vale la pena incorporar aunque no invalidan los claims: (a) en el claim 6, `logical_date` y `data_interval_start/end` **no son sinónimos intercambiables** — son dos conceptos separados (identidad del run vs. ventana de datos) desde Airflow 2.2, y la separación se volvió más estricta en Airflow 3.0/AIP-83 al hacer `logical_date` nullable y no-único; (b) en el claim 3, "stateless" es una inferencia arquitectónica razonable pero no una palabra que ningún vendor revisado use explícitamente para tasks — si el skill la usa, debe presentarla como principio derivado del modelo de ejecutores, no como cita.
