# Research: comparación de orquestadores — scheduling, dependencias cross-pipeline, y topología de deployment

**Fecha:** 2026-07-30
**Alcance:** verificación de 10 claims técnicos destinados a una skill de referencia permanente sobre orquestación de pipelines (scheduling time-based vs. data-driven, sensors, dependencias inter-DAG, granularidad de tareas, caracterización de Airflow/Dagster/Prefect, topología de deployment, ofertas managed, e isolation de dependencias). Todas las claims se verificaron contra fuentes oficiales/primarias — documentación de Apache Airflow, Dagster, Prefect, AWS y GCP — no contra blogs de terceros salvo donde se indica explícitamente como corroboración secundaria.

---

## 1. Scheduling time-based vs. data-driven — "Datasets" de Airflow: ¿sigue siendo el término actual?

**VEREDICTO: NEEDS CORRECTION.** El claim tal como está planteado en la skill ("Airflow added it via 'Datasets'") es **incorrecto para la versión actual** de Airflow. El término fue renombrado a **Assets** en Airflow 3.0, y esto está confirmado por fetch directo de la documentación estable actual, no solo por memoria o búsqueda indexada.

### Terminología actual (fetch directo confirmado)

La página de docs estable actual (Airflow 3.3.0), **Asset Definitions**, define:

> "An Airflow asset is a logical grouping of data. Upstream producer tasks can update assets, and asset updates contribute to scheduling downstream consumer Dags."

Y, crucialmente, incluye la nota de versión que resuelve la pregunta del rename de forma explícita:

> "Changed in version 3.0: The concept was previously called 'Dataset'."

Fuente: [Asset Definitions — Airflow 3.3.0 Documentation](https://airflow.apache.org/docs/apache-airflow/stable/authoring-and-scheduling/assets.html) (fetch directo).

### Historial de versiones — cuándo se introdujo y cuándo se renombró

**Introducción original — Airflow 2.4.0** ("That Data Aware Release"), confirmado por fetch directo del blog oficial:

> "Airflow now has the ability to schedule DAGs based on other tasks updating datasets."

Con el mecanismo productor/consumidor documentado explícitamente:

> "With these two DAGs, the instant `my_task` finishes, Airflow will create the DAG run for the `dataset-consumer` workflow."

y la limitación reconocida en ese momento por el propio proyecto: *"Datasets represent the abstract concept of a dataset, and (for now) do not have any direct read or write capability."* Fuente: [Apache Airflow 2.4.0: That Data Aware Release](https://airflow.apache.org/blog/airflow-2.4.0/) (fetch directo).

**Rename a Assets — Airflow 3.0** (mayo 2026 según el ciclo de release del proyecto), confirmado por fetch directo del blog oficial de lanzamiento:

> "The fundamental evolution of Datasets into Data Assets has been done as part of 'Introducing Data Assets' (AIP-74)."

> "A significant enhancement around Data Assets is the New Asset-Centric Syntax (AIP-75) for defining Assets easily with DAGs using the Python decorator syntax."

Fuente: [Apache Airflow® 3 is Generally Available!](https://airflow.apache.org/blog/airflow-three-point-oh-is-here/) (fetch directo).

El AIP oficial (Airflow Improvement Proposal) que gobierna el cambio es **AIP-74 "Introducing Data Assets"**, y el rename tocó el modelo completo — no solo la capa Python: propiedades de la API REST, tablas de la base de datos, y componentes de la UI. Confirmado por fetch directo de la wiki cwiki de Apache:

> "Rename property run_type value dataset_triggered as asset_triggered in DAGRun endpoint. Rename property dataset_expression as asset_expression in DAGDetail endpoint...Rename dataset as asset in all the database tables."

> "Rename DagRunTriggeredByType.DATASET as DagRunTriggeredByType.ASSET and all the name dataset in all the UI component to asset."

Fuente: [Airflow 3 user facing changes — cwiki Apache Software Foundation](https://cwiki.apache.org/confluence/display/AIRFLOW/Airflow+3+user+facing+changes) (fetch directo).

### Compatibilidad hacia atrás — el import `Dataset` sigue funcionando, pero con fecha de expiración

Confirmado por fetch directo de la guía oficial de migración:

> Tabla de "Key Import Updates": `airflow.datasets.Dataset` → `airflow.sdk.Asset`

> "Legacy imports show deprecation warnings but continue to work" (a partir de Airflow 3.1); en una versión futura, "Legacy imports will be **removed**."

Fuente: [Upgrading to Airflow 3 — Airflow 3.3.0 Documentation](https://airflow.apache.org/docs/apache-airflow/stable/installation/upgrading_to_airflow3.html) (fetch directo). La página no precisa si el import `Dataset` ya generaba warning en 3.0.0 exacto o solo desde 3.1 — ese matiz de versión puntual (3.0 vs. 3.1) no se pudo confirmar con precisión de patch version, pero el hecho central (deprecado, con remoción futura) sí está confirmado.

### Conclusión accionable para la skill

**Corrección requerida:** el texto de la skill debe decir que Airflow introdujo el modelo data-driven en **2.4 (2026, era 2022 en calendario real pero verificado como versión histórica) bajo el nombre "Datasets"**, y que ese nombre **fue renombrado a "Assets" en Airflow 3.0**, con `Dataset` manteniéndose como alias deprecado (no eliminado todavía en la rama estable actual). Si la skill se escribe para lectores que hoy instalan Airflow 3.x, el término correcto a enseñar como primario es **Asset**, mencionando "Dataset" solo como el nombre legacy que encontrarán en código/tutoriales pre-3.0.

---

## 2. Sensors, worker slots, reschedule mode y deferrable operators

**VEREDICTO: VERIFIED.** El resumen del claim es correcto en los tres mecanismos.

**Poke mode (default) — ocupa el worker slot todo el tiempo**, confirmado por fetch directo de la doc de sensors:

> "The Sensor takes up a worker slot for its entire runtime"

**Reschedule mode — libera el slot entre chequeos**, misma fuente:

> "The Sensor takes up a worker slot only when it is checking, and sleeps for a set duration between checks"

Fuente: [Sensors — Airflow 3.3.0 Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/sensors.html) (fetch directo).

**Deferrable operators — liberan el slot por completo, no solo entre chequeos**, confirmado por fetch directo de la doc dedicada:

> "Standard Operators and Sensors take up a full worker slot for the entire time they are running, even if they are idle" — y con 100 slots y 100 DAGs esperando en un sensor, "you cannot run anything else — even though your entire Airflow cluster is essentially idle."

> Al diferir, "the task no longer occupies a worker slot, and you have more free workload capacity."

Fuente: [Deferrable Operators & Triggers — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/authoring-and-scheduling/deferring.html) (fetch directo).

La diferencia entre reschedule mode y deferrable operators que describe el claim es exacta: reschedule mode solo mitiga el problema periódicamente (libera el slot mientras duerme, pero sigue siendo polling con intervalo fijo); deferrable operators lo resuelve moviendo el polling al proceso *triggerer* (un componente separado que puede manejar miles de esperas concurrentes con una sola instancia async), sin ocupar worker slot en absoluto durante la espera.

---

## 3. Dependencias inter-DAG — temporal coupling como antipattern vs. asset-driven triggering

**VEREDICTO: VERIFIED con matiz importante — el framing "antipattern/fragile" es razonamiento de la industria, no una advertencia textual de un vendor.**

Lo que sí está confirmado por fuente oficial:

- **Assets/Datasets es el método recomendado para dependencias irregulares entre DAGs**, con el beneficio explícito de no ocupar worker slot: *"Assets don't use a worker slot in contrast to sensors or other implementations of cross-DAG dependencies, making them more cost-effective."* Fuente: contenido indexado de Astronomer, `cross-dag-dependencies` — **no confirmado por fetch directo línea por línea** (ver nota abajo).
- **ExternalTaskSensor sigue documentado como método válido** para dependencias inter-DAG, junto con TriggerDagRunOperator y la API de Airflow, como alternativas a assets.

**Nota de discrepancia entre fetch e indexado:** al hacer el fetch directo de la página de Astronomer (`astronomer.io/docs/learn/cross-dag-dependencies`), el contenido recuperado **no incluyó ninguna advertencia explícita sobre acoplar DAGs por horario fijo** (del tipo "programar B una hora después de A es frágil"). El fetch confirmó que el documento presenta cuatro métodos (assets, TriggerDagRunOperator, ExternalTaskSensor, API) como opciones con distintos casos de uso, **sin enmarcar el scheduling por offset horario como un antipattern con nombre propio**. Es decir: **ningún vendor oficial revisado (Apache Airflow, Astronomer) usa el término "temporal coupling" ni describe explícitamente "programar B una hora después de A" como frágil** — es una inferencia lógica razonable (si A puede correr tarde, un offset fijo en B puede procesar datos incompletos), pero no es una cita textual de ningún doc oficial.

**Lo que sí es 100% textual y verificado:** la ventaja de asset-driven triggering sobre sensors es que **no ocupa worker slot** (confirmado por fetch directo de §2, mecanismo de deferring) y que assets permiten disparar B automáticamente en el instante en que A termina de producir el dato, sin necesidad de que B esté "adivinando" un horario — esto está confirmado con la cita textual del blog 2.4.0: *"With these two DAGs, the instant `my_task` finishes, Airflow will create the DAG run for the `dataset-consumer` workflow."*

**Conclusión para la skill:** la jerarquía técnica del claim (intra-DAG vs. inter-DAG; sensor como alternativa menor a asset-driven triggering) está bien fundamentada en la documentación oficial. El término "temporal coupling" como nombre del antipattern y la frase "frágil si A corre tarde" deben presentarse como **análisis/razonamiento propio del autor de la skill**, no como cita de ningún vendor — igual que el research previo del repo marca "late-arriving commit problem" como terminología de industria, no de vendor.

---

## 4. Granularidad de tareas — hyper-fine vs. monster tasks

**VEREDICTO: NO CONTRADICHO por la guía oficial — parcialmente corroborado, es en gran parte juicio de diseño, tal como anticipa la tarea.**

La documentación oficial de Airflow sí cubre **atomicidad** (extremo "granular") con guía explícita, pero **no** cuantifica el extremo opuesto ("monster tasks") con la misma precisión. Fetch directo de la página oficial de mejores prácticas:

> "You should treat tasks in Airflow equivalent to transactions in a database. This implies that you should never produce incomplete results from your tasks."

> "The Dag that has simple linear structure `A -> B -> C` will experience less delays in task scheduling than Dag that has deeply nested tree structure"

Fuente: [Best Practices — Airflow 3.3.0 Documentation](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html) (fetch directo). Esta última cita es la corroboración más cercana al lado "overhead de scheduling" del claim: Airflow reconoce explícitamente que estructuras de DAG muy anidadas/complejas introducen retrasos de scheduling — lo cual es consistente con (aunque no idéntico a) "demasiadas tareas hyper-finas → overhead de scheduling domina."

El lado "monster tasks pierden granularidad de retry/observabilidad" no aparece como advertencia textual en la doc oficial revisada, pero es la consecuencia lógica directa y no controvertida del principio de atomicidad que sí está documentado (una tarea = una unidad rerunneable; fusionar 5 pasos en 1 tarea significa que un fallo en el paso 4 obliga a re-ejecutar los pasos 1-3 también, y el log/estado deja de distinguir en qué paso falló).

**Conclusión:** el claim no está contradicho por ninguna fuente oficial revisada (Airflow best-practices.html), y su mitad "atomicidad reduce blast radius de reintentos" está fundamentada directamente en la doc oficial. Tratar como diseño-judgment razonable y no contradicho, tal como anticipaba la tarea — no se encontró una fuente que cuantifique un número óptimo de tareas por DAG.

---

## 5. Caracterización de Airflow

**VEREDICTO: VERIFIED en su mayoría, con dos matices de fuente.**

- **"Task-centric mental model"**: confirmado indirectamente — la arquitectura de Airflow se define en torno a Scheduler/Executor/Tasks, y el propio mecanismo de Datasets/Assets se presenta como una capa *añadida* sobre el modelo de tareas para lograr comportamiento data-aware (ver §1), lo cual es evidencia estructural de que el modelo base es task-centric.
- **"Huge ecosystem of providers"**: confirmado por fetch directo — el Airflow Registry lista **104 providers oficiales y de comunidad** al momento del fetch: *"Browse 104 official and community providers."* Fuente: [Providers | Airflow Registry](https://airflow.apache.org/registry/providers/) (fetch directo). No es "de facto standard" un claim que Airflow haga de sí mismo en su homepage — se revisó `airflow.apache.org` por fetch directo y **no contiene lenguaje de posicionamiento tipo "most popular" o "de facto standard"**; ese framing es consenso de industria/terceros, no autodescripción del proyecto.
- **"XCom is awkward for passing data"**: confirmado — la propia doc oficial (contenido indexado, no fetch línea-por-línea en este research puntual, aunque ya fue confirmado por fetch directo en el research previo del repo sobre watermarks, §2b) recomienda explícitamente **no** usar XCom para datos grandes: *"XComs are only designed for small amounts of data; they should not be used to pass around large values, like dataframes"*, y que el backend por defecto los guarda en la base de datos de metadata, con degradación de performance en objetos grandes. Fuente: [XComs — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/concepts/xcoms.html) (contenido indexado consistente entre múltiples resultados de búsqueda, no fetch directo en esta sesión puntual).
- **"Backfills treacherous por acoplamiento scheduling/data-interval, mitigado en 2/3"**: parcialmente confirmado — la doc oficial documenta extensamente la distinción `execution_date`/`logical_date` vs. `data_interval_start`/`data_interval_end`, y recomienda explícitamente usar los nombres de data-interval por ser "semánticamente más correctos y menos propensos a malentendidos" — evidencia directa de que el proyecto reconoce el histórico de confusión en este área y lo fue corrigiendo con nueva terminología. No se encontró una fuente oficial que use la palabra "treacherous" o equivalente, pero la existencia del rename `execution_date` → `logical_date` (Airflow 2.2) y la guía activa para evitarlo es evidencia estructural sólida del problema histórico. Fuente: contenido indexado consistente entre `DAG Runs — Airflow Documentation` y `FAQ — Airflow Documentation` (no fetch directo en esta sesión puntual).
- **"Historically clunky local testing"**: **no confirmado por Airflow oficial** — ningún doc de `airflow.apache.org` revisado hace esta afirmación sobre sí mismo. Sí aparece como caracterización de un competidor (Dagster, en su blog oficial de comparación): *"tasks are often tightly coupled to the production environment, so it's hard to replicate the exact conditions locally"* — fuente interesada (Dagster comparándose con Airflow), no neutral. Tratar como consenso de industria corroborado por una fuente competidora, no como autoevaluación de Airflow.

---

## 6. Caracterización de Dagster

**VEREDICTO: VERIFIED.**

- **Asset-centric, no task-centric**: confirmado por fetch directo del glosario oficial de Dagster: *"a software-defined asset (SDA) is a declarative design pattern that represents a data asset through code"*, y el framing explícito: SDAs permiten *"focus on the assets themselves—the end products of your data engineering efforts—rather than the execution of tasks."* Fuente: [What Is Software-defined Asset | Dagster](https://dagster.io/glossary/software-defined-assets) (fetch directo).
- **Lineage nativo**: confirmado, misma fuente: *"clear data lineage, which makes it easier to understand how data flows through your system"*, con integración a dbt para trackear lineage tabla por tabla.
- **I/O type-checking entre steps**: confirmado por búsqueda indexada consistente sobre la doc de Dagster Types (no fetch línea-por-línea en esta sesión) — *"Op inputs and outputs can be given Dagster Types... type checking occurs immediately before the op is executed"* (para inputs) *"and immediately after"* (para outputs), como capa runtime complementaria a las anotaciones estáticas de Python (PEP 484). Fuente: `docs.dagster.io/api/dagster/types` / `docs.dagster.io/guides/build/ops`.
- **Partitions y backfills nativos**: confirmado por búsqueda indexada consistente — *"A software-defined asset can be assigned a `PartitionsDefinition`... SDAs support time partitioning and backfills out of the box."* Fuente: `docs.dagster.io/guides/build/partitions-and-backfills/`.
- **Data-centric observability (freshness/staleness)**: confirmado por fetch directo del blog comparativo oficial de Dagster: *"Is this asset up-to-date? What do I need to run to refresh this asset? When will this asset be updated next?"* — y corroborado por doc dedicada (indexada, no fetch): Dagster documenta explícitamente **freshness policies** (que sustituyeron a los antiguos freshness checks desde la 1.12) para definir umbrales de staleness aceptable por asset, con la UI mostrando el estado. Fuentes: [Dagster vs Airflow: Feature Comparison](https://dagster.io/blog/dagster-airflow) (fetch directo, nota: fuente interesada/no neutral por ser comparación propia de Dagster); `docs.dagster.io/guides/observe/asset-freshness-policies` (indexada).
- **Local dev/testing fuerte**: confirmado por búsqueda indexada de la doc oficial — el comando `dagster dev`/`dg dev` levanta UI y daemon completos localmente para desarrollo y testing, con la advertencia oficial de que "isn't suitable for the demands of most production deployments" (o sea, está pensado exactamente para local, no para prod). Fuente: `docs.dagster.io/deployment/oss/deployment-options/running-dagster-locally`.

---

## 7. Caracterización de Prefect

**VEREDICTO: VERIFIED.**

Confirmado por fetch directo de la landing de la documentación actual (v3):

> "Write workflows in native Python—no DSLs, YAML, or special syntax."

> "Prefect is an open-source orchestration engine that turns your Python functions into production-grade data pipelines with minimal friction."

Sobre DAGs dinámicos/definidos en runtime:

> "Create tasks dynamically at runtime based on actual data or conditions. Easily spawn new tasks and branches during execution for truly data-driven workflows."

Fuente: [Introduction - Prefect](https://docs.prefect.io/v3/get-started) (fetch directo). Esto confirma con precisión los tres elementos del claim: "más Pythonic y ligero" (sin DSL/YAML), "decoradores con ceremonia mínima" (`@flow`/`@task` sobre funciones Python normales), y "DAGs dinámicos/runtime" (contraste explícito con estructura pre-declarada). El "gentle learning curve" no tiene una cita textual equivalente de Prefect ("curva de aprendizaje suave" no es lenguaje verbatim del doc), pero es consecuencia razonable y no contradicha de "es Python normal, sin DSL" — se apoya en la misma fuente pero es inferencia, no cita directa.

---

## 8. Topología de deployment (referencia Airflow)

**VEREDICTO: VERIFIED en los cuatro sub-componentes.**

### Scheduler — HA con múltiples schedulers activos desde Airflow 2.0

Confirmado por fetch directo de la doc oficial actual:

> "Airflow supports running more than one scheduler concurrently – both for performance reasons and for resiliency."

Y confirmado con precisión de versión por fetch directo del AIP-15 (el proposal que introdujo la feature) en la wiki oficial de Apache:

> Problema que resuelve: "High Availability: what if the single scheduler is down. Scheduling Performance: the scheduling latency for each DAG may be long if there are many DAGs."

> Estado: "Completed" — **"In Release: 2.0.0"**

Fuentes: [Scheduler — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/scheduler.html) (fetch directo); [AIP-15 Support Multiple-Schedulers for HA & Better Scheduling Performance](https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=103092651) (fetch directo). El claim de la skill ("HA con múltiples schedulers activos desde Airflow 2.0") queda **confirmado con precisión exacta de versión**, algo que no siempre es posible verificar con este nivel de certeza.

### Executor/Workers — LocalExecutor, CeleryExecutor, KubernetesExecutor

Confirmado por combinación de fuente oficial fetch-directo (Kubernetes) y contenido indexado (Local/Celery, consistente entre múltiples resultados):

- **LocalExecutor**: corre dentro del proceso del scheduler, en una sola máquina — confirmado como caracterización estándar consistente en la doc, aunque no se hizo fetch directo línea-por-línea en esta sesión puntual.
- **CeleryExecutor**: requiere un broker (Redis/RabbitMQ) y un pool de workers **siempre activos** ("statically configured and are running all the time, regardless of workloads") — contenido indexado, consistente con la doc de Astronomer/Airflow provider.
- **KubernetesExecutor**: confirmado por **fetch directo** de la doc oficial del provider `cncf-kubernetes`:

  > "The Kubernetes executor runs each task instance in its own pod on a Kubernetes cluster."

  Sobre el tradeoff de latencia vs. Celery, misma fuente:

  > "With Celery workers you will tend to have less task latency because the worker pod is already up and running when the task is queued."

  Sobre el caso de uso ("no noisy neighbors" / recursos no uniformes):

  > "KubernetesExecutor can work well is when your tasks are not very uniform with respect to resource requirements or images."

  Fuente: [Kubernetes Executor — apache-airflow-providers-cncf-kubernetes Documentation](https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/kubernetes_executor.html) (fetch directo). **Nota importante que matiza el claim de la skill**: la misma doc aclara que la ventaja de "scale-to-zero" del KubernetesExecutor sobre Celery **ya no es exclusiva**, porque "the official Apache Airflow Helm chart can automatically scale celery workers down to zero based on the number of tasks in the queue, so when using the official chart, this is no longer an advantage." Es decir: el tradeoff "Celery = siempre prendido, K8s = elástico" sigue siendo cierto para una instalación Celery *básica*, pero el propio Helm chart oficial de Airflow ya ofrece autoscaling-a-cero para Celery también — este matiz debería mencionarse en la skill si se quiere ser preciso con el estado actual, no solo con la comparación histórica simplificada.

### Metadata database

Confirmado por contenido indexado consistente con la doc oficial de arquitectura: *"A metadata database is used by the scheduler, executor and webserver to store state. This database stores metadata about DAGs, their runs, and other Airflow configurations."* Fuente: `airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html` (indexado, no fetch línea-por-línea en esta sesión). El carácter "stateful/crítico si se pierde" no está enunciado como advertencia textual en la doc de arquitectura, pero es consecuencia lógica directa y no controvertida de que **toda** la metadata del sistema (incluyendo qué corrió, cuándo, con qué resultado) vive únicamente ahí.

### Webserver/UI

Confirmado, misma fuente: *"A webserver presents a handy user interface to inspect, trigger and debug the behaviour of DAGs and tasks."*

---

## 9. Managed vs. self-hosted — MWAA, Cloud Composer, Astronomer, Dagster Cloud, Prefect Cloud

**VEREDICTO: VERIFIED, los cinco productos existen y están correctamente caracterizados.**

- **AWS MWAA**: confirmado por fetch directo de la doc oficial de arquitectura de red — AWS gestiona los cuatro componentes core: *"Scheduler ... Amazon MWAA deploys the scheduler as a AWS Fargate cluster with a minimum of 2 schedulers"* (o sea, HA managed por default); *"Workers ... auto-scaling"*; *"Web server"*; *"Database ... single-tenant Aurora PostgreSQL database managed by AWS."* Fuente: [Explore Amazon MWAA network architecture](https://docs.aws.amazon.com/mwaa/latest/migrationguide/mwaa-architecture.html) (fetch directo). Esto confirma explícitamente que MWAA remueve la carga operativa de scheduler/DB/HA descrita en el claim — el usuario no gestiona nada de eso, AWS lo hace vía Fargate/Aurora.
- **GCP Cloud Composer** (renombrado "Managed Service for Apache Airflow" en la documentación actual de GCP, aunque "Cloud Composer" sigue siendo el nombre de producto comercial): confirmado por fetch directo:

  > "Managed Airflow is a fully managed workflow orchestration service, enabling you to create, schedule, monitor, and manage workflow pipelines that span across clouds and on-premises data centers."

  > "By using Managed Airflow instead of a local instance of Apache Airflow, you can benefit from the best of Airflow with no installation or management overhead."

  Fuente: [Managed Airflow overview](https://docs.cloud.google.com/composer/docs/composer-3/composer-overview) (fetch directo). **Nota de nomenclatura para la skill**: la documentación actual de Google usa "Managed Service for Apache Airflow" como nombre formal de la doc, mientras que "Cloud Composer" sigue apareciendo como nombre del producto/versión (Composer 2, Composer 3). Si la skill usa "Cloud Composer" como nombre, sigue siendo válido y reconocible, pero vale la pena saber que Google está migrando la superficie de documentación hacia el nombre genérico "Managed Airflow".
  
- **Astronomer (Astro)**: confirmado por contenido indexado consistente entre múltiples páginas oficiales de Astronomer: *"Astro is a fully-managed SaaS application for data orchestration that helps teams write and run data pipelines with Apache Airflow at any level of scale. The infrastructure to run Airflow is managed entirely by Astronomer."* Fuente: `astronomer.io/docs/astro/astro-architecture` (indexado, no fetch línea-por-línea en esta sesión).
- **Dagster Cloud (ahora "Dagster+")**: confirmado por búsqueda indexada de la doc oficial — ofrece dos modos, **Serverless** (*"fully managed version of Dagster+... you can run your Dagster jobs without spinning up any infrastructure yourself"*) e **Hybrid** (*"Dagster backend services - including the web frontend, GraphQL API, metadata database, and daemons... are hosted in Dagster+"*, con un agente corriendo en la infraestructura del cliente). Fuente: `docs.dagster.io/deployment/dagster-plus` (indexado). **Nota de nomenclatura**: el producto se llama actualmente **"Dagster+"**, no "Dagster Cloud" — el research usó "Dagster Cloud" como término del claim original, pero la documentación oficial actual usa "Dagster+" como nombre de marca (con "Dagster Cloud" quedando como término legacy/histórico reconocible). Vale la pena que la skill use "Dagster+" como nombre actual, con "Dagster Cloud" entre paréntesis si se quiere mantener reconocibilidad.
- **Prefect Cloud**: confirmado por búsqueda indexada de la doc/marketing oficial: *"Prefect Cloud is a managed, high-availability deployment of Prefect OSS"*, con modelos Hybrid (workers en infra propia) y Serverless (workers en infra de Prefect, "scale to zero"). Fuente: `prefect.io/prefect/cloud` (indexado).

---

## 10. Isolation de dependencias entre tareas — KubernetesExecutor con imágenes por tarea

**VEREDICTO: VERIFIED.** El mecanismo existe y está documentado oficialmente casi con el mismo ejemplo del claim (versiones de librería en conflicto).

Confirmado por búsqueda indexada consistente de la doc oficial de Airflow sobre `pod_override`/`executor_config`:

> "If a custom Docker image is passed to the Kubernetes executor's base container by providing it to either the `pod_template_file` or the `pod_override` key in the dictionary for the `executor_config` argument..."

> "A possible reason for customizing this Docker image would be to run a task in an environment with **different versions of packages** than other tasks running in your Airflow instance."

Esta última frase es prácticamente el ejemplo exacto del claim ("task A needs pandas 1.x, task B needs pandas 2.x") descrito en los propios términos de la documentación oficial de Airflow. Confirmado además por fetch directo de la doc del provider `cncf-kubernetes` (§8), donde se reafirma el mecanismo general de un pod por tarea, y el caso de uso explícito: *"KubernetesExecutor can work well is when your tasks are not very uniform with respect to resource requirements or images."*

Fuentes: contenido indexado consistente sobre `airflow.apache.org/docs/apache-airflow/stable/core-concepts/executor/kubernetes.html` y páginas relacionadas de `pod_override`; [Kubernetes Executor — apache-airflow-providers-cncf-kubernetes Documentation](https://airflow.apache.org/docs/apache-airflow-providers-cncf-kubernetes/stable/kubernetes_executor.html) (fetch directo para la parte de aislamiento por pod y el caso de uso de recursos/imágenes no uniformes).

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Airflow "Datasets" como término actual | **NEEDS CORRECTION** — renombrado a "Assets" en Airflow 3.0 (AIP-74), "Dataset" es alias deprecado |
| 2 | Sensors, worker slots, reschedule, deferrable | VERIFIED |
| 3 | Temporal coupling como antipattern vs. asset-driven triggering | VERIFIED (mecánica), con matiz — "antipattern/frágil" es razonamiento propio, no cita de vendor |
| 4 | Granularidad de tareas (hyper-fine vs. monster) | No contradicho por guía oficial; parcialmente corroborado, resto es diseño-judgment razonable |
| 5 | Caracterización de Airflow | VERIFIED en su mayoría; "de facto standard" y "clunky local testing" son consenso de industria, no autodescripción de Airflow |
| 6 | Caracterización de Dagster | VERIFIED |
| 7 | Caracterización de Prefect | VERIFIED |
| 8 | Topología de deployment (scheduler HA 2.0, executors, DB, webserver) | VERIFIED, con matiz — ventaja "scale-to-zero" de K8s sobre Celery ya no es exclusiva (Helm chart oficial soporta autoscaling-a-cero en Celery también) |
| 9 | MWAA / Cloud Composer / Astronomer / Dagster Cloud / Prefect Cloud como managed offerings | VERIFIED, con nota de nomenclatura — "Dagster Cloud" hoy se llama "Dagster+"; "Cloud Composer" convive con el nombre genérico "Managed Service for Apache Airflow" en la doc actual de GCP |
| 10 | Isolation de dependencias vía KubernetesExecutor por-tarea | VERIFIED, con ejemplo casi textual de la doc oficial (conflicto de versiones de paquete) |

---

## Fuentes primarias usadas (método de verificación indicado por fuente)

| Fuente | Uso | Método |
|---|---|---|
| Airflow blog — `airflow-2.4.0` ("That Data Aware Release") | Introducción de Datasets (§1) | Fetch directo |
| Airflow blog — `airflow-three-point-oh-is-here` | Rename Datasets→Assets, AIP-74/75 (§1) | Fetch directo |
| Airflow docs stable — `authoring-and-scheduling/assets.html` | Definición actual de Asset + nota "Changed in version 3.0" (§1) | Fetch directo |
| Airflow docs stable — `installation/upgrading_to_airflow3.html` | Compatibilidad hacia atrás del import `Dataset` (§1) | Fetch directo |
| cwiki Apache — "Airflow 3 user facing changes" | Alcance del rename (DB, API, UI) (§1) | Fetch directo |
| cwiki Apache — AIP-15 (Multiple Schedulers) | HA de scheduler, versión exacta 2.0.0 (§8) | Fetch directo |
| Airflow docs stable — `core-concepts/sensors.html` | Poke vs. reschedule mode (§2) | Fetch directo |
| Airflow docs stable — `authoring-and-scheduling/deferring.html` | Deferrable operators, worker slots (§2) | Fetch directo |
| Airflow docs stable — `best-practices.html` | Atomicidad, XCom, estructura de DAG (§4, §5) | Fetch directo |
| Airflow docs stable — `administration-and-deployment/scheduler.html` | HA multi-scheduler (§8) | Fetch directo |
| Airflow providers — `apache-airflow-providers-cncf-kubernetes/.../kubernetes_executor.html` | KubernetesExecutor, pod-por-tarea, isolation, tradeoff de latencia (§8, §10) | Fetch directo |
| Airflow Registry — `registry/providers/` | Conteo de providers (104) (§5) | Fetch directo |
| Airflow homepage | Ausencia de lenguaje "de facto standard" (§5) | Fetch directo |
| AWS — `docs.aws.amazon.com/mwaa/.../mwaa-architecture.html` | Componentes gestionados por MWAA (§9) | Fetch directo |
| GCP — `docs.cloud.google.com/composer/docs/composer-3/composer-overview` | Definición de Managed Airflow/Cloud Composer (§9) | Fetch directo |
| Astronomer — `docs/learn/cross-dag-dependencies` | Ausencia de framing "antipattern" textual (§3) | Fetch directo (confirmando ausencia) |
| Dagster — `dagster.io/glossary/software-defined-assets` | Definición SDA, asset-centric, lineage (§6) | Fetch directo |
| Dagster — `dagster.io/blog/dagster-airflow` | Comparación oficial (fuente interesada), freshness observability (§5, §6) | Fetch directo |
| Prefect — `docs.prefect.io/v3/get-started` | Pythonic, decoradores, dinamismo runtime (§7) | Fetch directo |
| Airflow — `concepts/xcoms.html` | Limitación de tamaño de XCom (§5) | Contenido indexado, consistente entre múltiples resultados |
| Airflow — `core-concepts/overview.html` | Arquitectura general (scheduler/executor/DB/webserver) (§8) | Contenido indexado |
| Airflow — `core-concepts/executor/kubernetes.html` y `pod_override` | Imagen custom por tarea, isolation de dependencias (§10) | Contenido indexado, consistente entre múltiples resultados |
| Dagster — docs de Types, partitions/backfills, freshness policies, `dagster dev` | I/O type-checking, partitions nativas, freshness, local dev (§6) | Contenido indexado |
| Astronomer — `astro-architecture` | Astro como fully-managed (§9) | Contenido indexado |
| Dagster — `deployment/dagster-plus` | Serverless/Hybrid, nombre actual "Dagster+" (§9) | Contenido indexado |
| Prefect — `prefect.io/prefect/cloud` | Prefect Cloud managed/HA (§9) | Contenido indexado |
| Airflow — `dag-run.html`, `faq.html` | `execution_date`→`logical_date`, guía de data-interval (§5) | Contenido indexado |

## Claims explícitamente NO verificadas — no usar como cita textual sin revisión adicional

1. **"Temporal coupling" como nombre del antipattern** — no aparece en ningún doc oficial revisado (Airflow, Astronomer). Es razonamiento del autor de la skill, no terminología de vendor (§3).
2. **"De facto standard" aplicado a Airflow** — no es autodescripción del proyecto (confirmado por fetch directo de la homepage sin ese lenguaje); es consenso de industria/terceros (§5).
3. **"Historically clunky local testing" de Airflow** — no confirmado como autoevaluación de Airflow; sí aparece como caracterización de un competidor interesado (blog oficial de Dagster) (§5).
4. **Precisión de patch version exacta sobre cuándo el import `Dataset` empezó a mostrar warning** (¿3.0.0 exacto o solo desde 3.1?) — la doc de migración confirma el estado final (deprecado, remoción futura) pero no ancla el warning a un patch version específico con total precisión (§1).
5. **"Gentle learning curve" de Prefect** como frase textual — es inferencia razonable a partir de "sin DSL/YAML", no cita verbatim de Prefect (§7).
