# Especificación de Diseño: Skill `pipelines-architecture-data-engineering`
## Cuarta skill de dominio de la suite `data-engineering-skills`

**Fecha:** 2026-07-30
**Responsable:** Leonardo H. García Díaz
**Estado:** Implementado y shippeado (2026-07-30) — ver `docs/superpowers/plans/2026-07-30-pipelines-architecture-skill-implementation.md` para el registro de ejecución (14 tareas + Task 14 agregada mid-project + revisión final de rama con fix wave).

---

## 1. Contexto y objetivo

Cuarta de las skills de dominio definidas en `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` (§4) en entregarse, después de `python-data-engineering`, `sql-data-engineering` y `spark-data-engineering`. Cubre orquestación de pipelines — el pilar que faltaba de arquitectura de pipelines, junto con las APIs (ver §2.1, resuelto en esta misma spec).

Insumo: tres borradores de contenido aportados por el usuario (formato entrevista técnica senior, de fundamentos a nivel senior), verificados contra documentación oficial — Apache Airflow, Dagster, Prefect, AWS/GCP (MWAA/Cloud Composer), RFCs HTTP (9110, 6585, 8288, 6749), y documentación de proveedores (Stripe, GitHub, Shopify, AWS Architecture Blog) — vía 6 investigaciones en paralelo. Registro completo: los 6 archivos `docs/superpowers/research/2026-07-30-{orchestration-fundamentals-dag-idempotency-backfills,orchestrator-comparison-scheduling-topology,airflow-trigger-rules-branching-sensors,airflow-taskflow-dynamic-mapping-reliability,api-consumption-auth-pagination,api-resilience-incremental-concurrency}-verification.md`.

## 2. Alcance y fronteras

Reafirma la frontera ya fijada en la spec de la suite (§4): elección y patrones de orquestador (Airflow/Dagster/Prefect), diseño de DAGs, backfills, dependency management, topología de despliegue. No cubre el código idempotente dentro de una tarea (eso ya está en `python-data-engineering`).

### 2.1 Resolución del scope fork con la 9na skill "APIs" (§7.7 de la spec de la suite)

El tercer borrador del usuario cubre consumo y construcción de APIs — exactamente el contenido que la spec de la suite (§7.7, §8) marcó como pendiente de resolver aquí. Decisión tomada con Leonardo (2026-07-30), confirmando que el equipo **no** tiene todavía un caso real de construir/operar una API de serving (solo evaluando):

| Contenido del borrador 3 | Destino | Razón |
|---|---|---|
| Parte A — consumo de APIs externas (auth, paginación, rate-limiting/backoff+jitter, extracción incremental por watermark, concurrencia, contrato/observabilidad, push vs pull) | `python-data-engineering`, nuevo reference file `external-api-integration.md` | Es código de tarea, no arquitectura de pipeline — mismo principio que ya separa "código idempotente" (python) de "diseño del DAG" (esta skill). Cierra además un gap real: la nota previa de memoria/spec que decía "ya cubierto, no es gap" resultó imprecisa — lo único que existía era un decorator de retry genérico sin jitter, sin manejo de 429, sin OAuth2, sin paginación (ver research `api-consumption-auth-pagination` y `api-resilience-incremental-concurrency`). |
| Parte B — capa conceptual (serving layer vs. warehouse OLAP para point-lookups, tradeoff de frescura/SLA, decisión API vs. stream vs. export vs. share, "data-as-a-product") | Esta skill, `references/serving-pipeline-output.md` | Es una decisión arquitectónica de cómo el pipeline entrega su salida — mismo nivel que elegir orquestador, no implementación. |
| Parte B — capa de implementación (FastAPI, REST vs. GraphQL vs. gRPC, versionado de endpoint, seguridad de API) | **Fuera de alcance de la suite, por ahora** | Ingeniería de backend general, no específica de ingeniería de datos, y sin uso real confirmado por el equipo — mismo criterio que ya rige el patrón *targeted coverage* de la suite: se sube de nivel solo con uso real confirmado, no especulativo. |
| Hosting/infraestructura del servicio API, si se llega a construir | Pointer hacia `iac-cloud-data-engineering` (ya tiene Docker/Compose en su alcance) | Se resuelve cuando esa skill se escriba — no hay contenido que escribir hoy. |
| Contrato/versionado de esquema de la API (OpenAPI) | Pointer hacia `quality-data-engineering` | Se resuelve cuando esa skill se escriba. |

Con esto, la 9na skill "APIs para Ingeniería de Datos" queda descartada como propuesta: las dos mitades con hogar claro lo tienen, y la mitad sin hogar claro se excluye explícitamente en vez de quedar pendiente. Si el equipo confirma más adelante un caso de uso real construyendo/operando APIs de serving, ese contenido se evalúa entonces contra este mismo criterio (uso real confirmado), no antes.

### 2.2 Alcance de versión

**Apache Airflow 3.x como línea base** (`docs.airflow.apache.org/docs/apache-airflow/stable/` resuelve a **3.3.0** al momento de esta verificación), con notas explícitas de 2.x donde diverge de forma significativa y sigue siendo relevante por adopción real en producción — mismo criterio ya usado en `spark-data-engineering` (nombrar la versión explícitamente en vez de generalizar "Airflow reciente"). Las divergencias 2.x→3.x que **cambian contenido, no solo redacción** (detalle completo en §4):

- `Dataset` → renombrado a `Asset` (Airflow 3.0, AIP-74); `Dataset` queda como alias deprecado.
- `SubDagOperator` → **removido** (no solo deprecado) en 3.0, reemplazado por TaskGroups/Assets/Data Aware Scheduling.
- `sla`/`sla_miss_callback` → **removido** en 3.0, reemplazado por Deadline Alerts (experimental aún en 3.1).
- Estado de tarea `shutdown` → deprecado en 2.7.2, removido recién en 3.0.0 (existió deprecado durante el resto de la serie 2.x; ya no existe en 3.x).
- `SqlSensor` y `ExternalTaskSensor` → movidos de `airflow.*` core a paquetes provider (`apache-airflow-providers-common-sql`, `apache-airflow-providers-standard`) en 3.x.
- `catchup_by_default` → ya es `False` en Airflow actual; el comportamiento "catchup on por defecto" es histórico (1.x), no vigente.

## 3. Fuentes

- Tres borradores originales del usuario — traducidos y corregidos, no adoptados verbatim (contenido final en inglés, convención ya fijada en la spec de la suite §3).
- Verificación directa contra documentación oficial: Apache Airflow (`airflow.apache.org/docs/apache-airflow/stable/`, release notes, AIPs 15/34/39/74/83), Dagster (`docs.dagster.io`), Prefect (`docs.prefect.io`), AWS (MWAA, AWS Architecture Blog), GCP (Cloud Composer), RFC 9110 (HTTP Semantics), RFC 6585 (429), RFC 8288 (Web Linking, obsoleta RFC 5988), RFC 6749 (OAuth2), RFC 4918 (WebDAV, origen de 422), y documentación de proveedores (`requests`, `aiohttp`, Stripe, GitHub, Shopify Engineering).
- No se usó `wshobson/agents` para este dominio — su `airflow-dag-patterns` es solo-Airflow, no agnóstico de orquestador como exige el alcance de esta skill (ya anotado como riesgo en la spec de la suite §4); el borrador del usuario ya cubre Airflow a la profundidad necesaria sin ese insumo.

## 4. Estructura de archivos

```
skills/pipelines-architecture-data-engineering/
  SKILL.md
  references/
    orchestration-fundamentals.md
    idempotency-and-backfills.md
    scheduling-and-dependencies.md
    orchestrator-selection-and-topology.md
    airflow-trigger-rules-and-branching.md
    airflow-sensors-and-dynamic-mapping.md
    airflow-structure-and-reliability.md
    serving-pipeline-output.md
```

Mismo formato que las skills ya entregadas: overview, when to use, tabla de quick reference y tabla de common mistakes en `SKILL.md`; un archivo de reference por tema pesado. Contenido en inglés, ejemplos de código en Python (DAGs de Airflow, el orquestador de referencia para ejemplos concretos — mismo criterio que "PySpark para Spark").

### 4.1 `orchestration-fundamentals.md` — borrador 1, Capa 0-1

Por qué existe un orquestador (5 valores: dependency management, scheduling, retries/failure handling, observability/alerting, backfills); el DAG como modelo mental (nodos=tareas, aristas=dependencias, acíclico); principio de diseño de tarea (atómica, idempotente, sin estado); separar orquestación de ejecución; pasar punteros no datos (antipatrón de XCom con datos grandes).

**Verificado sin correcciones de fondo** (`orchestration-fundamentals-dag-idempotency-backfills-verification.md`, claims 1-5) — incluye la guía documentada de XCom sobre "small amounts of data".

### 4.2 `idempotency-and-backfills.md` — borrador 1, Capa 2-3

Idempotencia estructural (ventana temporal por corrida, overwrite de partición no append), determinismo (no `datetime.now()` dentro de la tarea), backfills (definición, precondición idempotencia+determinismo, control de concurrencia, aislamiento de producción, datos tardíos).

**Correcciones a incorporar:**
- `logical_date` y `data_interval_start`/`data_interval_end` **no son sinónimos intercambiables** — son conceptos separados (identidad de la corrida vs. ventana de datos) desde Airflow 2.2; Airflow 3.0 (AIP-83) amplió la separación: `logical_date` ahora es nullable y se removió la restricción de unicidad `(dag_id, logical_date)`. Explicar la distinción, no tratarlos como el mismo término.
- **Aislar backfills de producción vía pools/colas separadas**: verdadero y documentado explícitamente para **Dagster** (tag reservado `dagster/backfill` con ejemplo de `tag_concurrency_limits` en `dagster.yaml`) — pero **no hay patrón nombrado equivalente en la documentación oficial de Airflow o Astronomer** (verificado por grep del HTML crudo de la página de Pools, cero menciones de "backfill"). En Airflow esto se logra combinando primitivas genéricas (pools, colas de Celery, `--max-active-runs` del comando CLI de backfill), no es una receta documentada. Atribuir el patrón por orquestador, no como verdad universal.
- **El "susto" de `catchup`**: el mecanismo es real (issues de comunidad #19461, #25615), pero el framing en tiempo presente es impreciso — Airflow actual (3.3.0) ya trae `catchup_by_default=False` (verificado en el HTML crudo del config reference), así que no es "activarlo por accidente" en un sistema apagado por defecto. Los disparadores reales hoy son: (a) código legado con `catchup=True` explícito, o (b) reanudar un DAG pausado mucho tiempo (este segundo caso está documentado explícitamente por Airflow). El framing histórico (1.x, donde el comportamiento catchup-like sí era el default del scheduler, verificado contra docs archivadas de 1.10.1) sigue siendo válido — solo corregir el tiempo verbal/vigencia.
- Dagster — partitions y backfills como ciudadanos de primera clase: verificado.

### 4.3 `scheduling-and-dependencies.md` — borrador 1, Capa 4

Scheduling por tiempo vs. por evento/datos; sensores (resumen, detalle en 4.6); dependencias intra-DAG vs. inter-DAG/cross-pipeline; grano correcto de tarea.

**Corrección importante a incorporar (cambio de terminología, no solo redacción):** el mecanismo de scheduling data-aware de Airflow se llamó **"Datasets"** al introducirse en **Airflow 2.4.0** (confirmado vía el blog oficial "That Data Aware Release"), pero fue **renombrado a "Asset"** en **Airflow 3.0** bajo AIP-74 ("Introducing Data Assets") — el cambio toca el schema de la DB, la REST API y la UI, no solo la API de Python. `airflow.datasets.Dataset` sigue existiendo como alias deprecado (`airflow.sdk.Asset` es el reemplazo), con remoción planeada a futuro. Enseñar **"Asset" como término vigente**, mencionar "Dataset" solo como nombre legado/pre-3.0.

**Matiz a incorporar:** el framing "el acople temporal es el antipatrón clásico, frágil porque..." es razonamiento propio del contenido, no terminología ni framing textual de un vendor — se verificó directamente la doc de Astronomer sobre dependencias cross-DAG y **no** enmarca los offsets de horario fijo como frágiles en esos términos. Presentarlo explícitamente como criterio de ingeniería del propio contenido, no como cita de Airflow/Astronomer.

Grano correcto de tarea: juicio de diseño, no contradicho por documentación oficial — se mantiene, señalado como criterio de ingeniería, no como regla documentada por ningún vendor.

### 4.4 `orchestrator-selection-and-topology.md` — borrador 1, Capa 5-6

Airflow vs. Dagster vs. Prefect (ejes de decisión, no ranking); topología de despliegue (scheduler, executor/workers, metadata DB, webserver); managed vs. self-hosted; aislamiento de dependencias.

**Verificado, con matices menores a incorporar:**
- Caracterización de Airflow/Dagster/Prefect: verificada contra docs oficiales de los tres.
- Scheduler en HA desde **Airflow 2.0.0** (AIP-15) — verificado con versión precisa.
- Executor: LocalExecutor/CeleryExecutor/KubernetesExecutor — verificado, pero **matiz**: el Helm chart oficial de Airflow ahora soporta scale-to-zero también para CeleryExecutor, así que "Celery = siempre encendido" ya no es una ventaja no-cualificada de KubernetesExecutor — suavizar esa comparación.
- Managed vs. self-hosted: MWAA, Cloud Composer, Astronomer, Dagster Cloud, Prefect Cloud — verificados como productos reales. **Naming a actualizar**: "Dagster Cloud" ahora se marca como **"Dagster+"**; la documentación de GCP está migrando de "Cloud Composer" hacia "Managed Service for Apache Airflow" como nombre genérico — mencionar ambos nombres.
- Aislamiento de dependencias vía KubernetesExecutor/contenedores por tarea: verificado.

### 4.5 `airflow-trigger-rules-and-branching.md` — borrador 2, Capa 1-2

Estados de tarea, `trigger_rule` (default `all_success`), branching (`@task.branch`, `ShortCircuitOperator`, `LatestOnlyOperator`), la trampa del join tras un branch.

**Correcciones a incorporar:**
- **Estado `shutdown`**: no existe en Airflow actual (3.3.0) — fue marcado deprecado en **2.7.2** ("remove unused state - SHUTDOWN") pero permaneció presente durante el resto de la serie 2.x, y fue removido recién en **3.0.0**. No listarlo como estado vigente. Mencionar opcionalmente el nuevo estado `awaiting_input` (Human-in-the-Loop, 3.3.0) si aporta valor pedagógico, sin profundizar (fuera del foco del tema).
- **Catálogo de trigger rules incompleto**: el borrador nombra 6 (`all_success`, `all_done`, `none_failed`, `none_failed_min_one_success`, `one_success`/`one_failed`, `always`) — todos correctamente escritos y vigentes, pero el catálogo oficial tiene **13 en total**. Agregar los 6 que faltan (`all_failed`, `all_skipped`, `one_done`, `all_done_min_one_success`, `all_done_setup_success`, `none_skipped`) al menos en una tabla de referencia completa, sin perder el foco pedagógico en los 6 que "hay que tener en la punta de los dedos". El rename `none_failed_or_skipped` → `none_failed_min_one_success` está confirmado, pinneado a **Airflow 2.2.0**, nombre viejo removido por completo en 3.0.
- Branching (`@task.branch`/`BranchPythonOperator`, `ShortCircuitOperator`, `LatestOnlyOperator`): verificado.
- **Trampa del join tras un branch**: verificada como patrón **documentado oficialmente por Airflow**, no folklore — la doc oficial usa un ejemplo textual `join`/`branch_a`/`follow_branch_a` y prescribe explícitamente `none_failed_min_one_success`. Se puede citar como ejemplo oficial, no solo como sabiduría de producción.

### 4.6 `airflow-sensors-and-dynamic-mapping.md` — borrador 2, Capa 3-4

Sensores (`S3KeySensor`, `SqlSensor`, `ExternalTaskSensor`), modo poke vs. `reschedule` vs. deferrable/triggerer, `timeout`/`soft_fail`/`poke_interval`; fan-out/fan-in estático vs. mapeo dinámico (`.expand()`).

**Correcciones a incorporar:**
- **Ubicación de `SqlSensor` y `ExternalTaskSensor`**: ya no viven en `airflow.*` core en Airflow 3.x — se movieron a paquetes provider: `ExternalTaskSensor` → `apache-airflow-providers-standard`, `SqlSensor` → `apache-airflow-providers-common-sql`. (`S3KeySensor` ya estaba correctamente ubicado en `apache-airflow-providers-amazon` en el borrador — sin cambios ahí). Nombrar el paquete provider correcto junto a cada sensor.
- Modo poke (ocupa el slot todo el tiempo de espera) y el antipatrón de "sensor deadlock": verificado.
- `mode="reschedule"`: verificado.
- Deferrable operators + proceso `triggerer`: verificado.
- `timeout`/`soft_fail`/`poke_interval` con `exponential_backoff`: verificado.
- **`ExternalTaskSensor` — `execution_delta`/`execution_date_fn`**: verificado, **sin rename** — la doc estable actual sigue usando esos nombres de parámetro textualmente; solo el lenguaje de los docstrings migró a fraseo "logical date" (AIP-39). La ruptura real es la ruta de import (core → provider, ver arriba), no los nombres de parámetro.
- Fan-out/fan-in ("diamante"): mecánica verificada; "diamante" no es terminología oficial de Airflow — presentarlo como descriptivo/de industria, no como cita textual.
- Mapeo dinámico (`.expand()`): verificado, **Airflow 2.3.0** (confirmado vía el blog oficial "Apache Airflow 2.3.0 is here").

### 4.7 `airflow-structure-and-reliability.md` — borrador 2, Capa 5-6

TaskFlow API, TaskGroups (y por qué los SubDAGs desaparecieron), setup/teardown tasks, generación dinámica de DAGs (factory pattern), pools, confiabilidad (`retries`, `execution_timeout`, `max_active_runs`, callbacks), antipatrón de código en el nivel superior del DAG.

**Correcciones a incorporar:**
- TaskFlow API (`@task`): verificado, **Airflow 2.0.0** (directiva textual "New in version 2.0.0" en la doc).
- **TaskGroups reemplazaron SubDAGs**: corrección de precisión — los SubDAGs no están "deprecados", están **removidos** en Airflow 3.0 ("SubDAGs: Replaced by TaskGroups, Assets, and Data Aware Scheduling"; `SubDagOperator` da 404 en la referencia de API estable actual). El razonamiento de deadlock/slot-único sí está documentado con precisión (blog oficial de anuncio de 2.0 + docstring del propio operador). Decir "removidos", no "deprecados".
- Setup/Teardown: verificado, **Airflow 2.7.0**, semántica confirmada (`ALL_DONE_SETUP_SUCCESS`, `on_failure_fail_dagrun`).
- Generación dinámica de DAGs / código determinista en el nivel superior: verificado — la propia doc oficial de Best Practices conecta explícitamente ambos puntos.
- Pools: verificado.
- `retries`/`retry_delay`/`retry_exponential_backoff`/`execution_timeout`/`max_active_runs`/`priority_weight`: verificado, con dos matices — `retry_exponential_backoff` acepta también un multiplicador float, no solo booleano; `max_active_runs` es a nivel de **DAG**, no de tarea (aclarar el nivel).
- **`sla`/`sla_miss_callback`**: **removido en Airflow 3.0**, reemplazado por Deadline Alerts (aún **experimental en 3.1**). `on_failure_callback` sigue vigente sin cambios. Este contenido necesita una nota explícita de compatibilidad 2.x-vs-3.x en vez de presentar `sla` como vigente sin matiz — es el hallazgo más importante de este archivo.
- Antipatrón de código en el nivel superior: verificado verbatim contra la página oficial de Best Practices, incluyendo el ejemplo textual de `expensive_api_call` ejecutado en cada parseo.

### 4.8 `serving-pipeline-output.md` — borrador 3, Parte B (capa conceptual únicamente)

Serving layer vs. warehouse OLAP para point-lookups de baja latencia; tradeoff de frescura vs. latencia; SLA y desacople; cuándo NO construir una API (bulk export, share nativo del warehouse, stream). Ver §2.1 para qué queda explícitamente excluido (implementación) y por qué.

Este archivo es razonamiento arquitectónico/criterio de ingeniería, no un conjunto de claims verificables contra documentación de un vendor específico — mismo tratamiento que ya recibió el pitfall de benchmarking cold/warm cache en `spark-data-engineering` (sabiduría real de sistemas distribuidos, no documentada por un vendor único). No se dispachó verificación externa para esta sección; se presenta explícitamente como criterio de diseño, no como cita.

### 4.9 (fuera de esta skill, resuelto por el fork de §2.1) `python-data-engineering/references/external-api-integration.md`

Nuevo reference file para `python-data-engineering` — Parte A del borrador 3: fundamentos HTTP/timeouts, auth (API key, bearer, OAuth2 client credentials + refresh proactivo), paginación (offset/limit, cursor/keyset, page token, Link header), rate limiting/backoff+jitter/circuit breaker/idempotency keys, extracción incremental por watermark con lookback, concurrencia (`asyncio`+`aiohttp`), validación de esquema en el borde, push vs. pull/webhooks, bulk export.

**Correcciones a incorporar** (`api-consumption-auth-pagination-verification.md`, `api-resilience-incremental-concurrency-verification.md`):
- **422**: citar **RFC 9110 §15.5.21** ("422 Unprocessable Content") como cita normativa vigente; RFC 4918 §11.2 ("422 Unprocessable Entity", WebDAV) como origen histórico — RFC 9110 lo absorbió explícitamente como código de propósito general.
- **Link header**: citar **RFC 8288** ("Web Linking"), no RFC 5988 — 8288 obsoleta a 5988 explícitamente (`Obsoletes: 5988` en el propio texto de la RFC). El patrón de GitHub (`Link: ...; rel="next"`, seguir hasta que no haya `next`) está confirmado contra la doc oficial de GitHub.
- **429**: `Retry-After` es `MAY`, no garantizado — suavizar "casi siempre" a "puede incluir, y hay que respetarlo cuando está". Corregir la atribución: 429 es RFC 6585 y **no** está en la lista `Obsoletes` de RFC 9110 (9110 lo referencia como extensión externa aún vigente, no lo absorbe) — quitar el paréntesis "(RFC 6585, luego absorbido por RFC 9110)".
- **Margen de 60s antes de expirar el token OAuth2**: no tiene fuente estándar — ningún doc de Auth0/Okta especifica 60s, y `google-auth-library-python` usa `REFRESH_THRESHOLD = timedelta(minutes=3, seconds=45)`. Presentar el número como ilustrativo, no como estándar de industria, o reemplazarlo por un margen configurable sin fijar 60s como "la" cifra correcta.
- **Backoff + jitter (AWS)**: cita exacta confirmada — [Exponential Backoff And Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/) (Marc Brooker, AWS, 2015, actualizado 2023). La frase "thundering herd" no aparece en el post — es vocabulario de industria, no palabras textuales de AWS; presentarlo así. El ejemplo concreto de AWS es contención de escritura por optimistic concurrency control en DynamoDB, no genéricamente 5xx/timeout/429 — el mecanismo generaliza igual, pero no atribuir a AWS un ejemplo que no es el suyo.
- **`asyncio.Semaphore` con `aiohttp`**: corrección de atribución — `Semaphore` es una primitiva de la stdlib de Python (`asyncio`), **no** algo que `aiohttp` documente o enseñe (se revisaron sus tres páginas de doc principales, cero menciones). El mecanismo de límite de concurrencia que `aiohttp` sí documenta nativamente es `TCPConnector(limit=...)`. Presentar `Semaphore` como patrón Python de propósito general comúnmente combinado con `aiohttp`, y mencionar `TCPConnector(limit=...)` como la alternativa nativa de la librería.
- **Webhooks at-least-once**: cita confirmada de Stripe (`docs.stripe.com/webhooks`): *"Webhook endpoints might occasionally receive the same event more than once... guard against duplicated event receipts by logging the event IDs."* GitHub no confirmó la misma redacción por fetch directo — usar Stripe como cita, no GitHub.
- **Offset/limit lento a offsets grandes**: hay benchmark real citable — Shopify Engineering (6.5ms en offset 10 → 2,221ms en offset 100,000) — usarlo como cita concreta en vez de la afirmación genérica.
- Resto de claims (timeout de `requests`, `raise_for_status`, OAuth2 client_credentials/RFC 6749 §4.4, offset/cursor/page-token, circuit breaker, idempotency keys, incremental+lookback, I/O-bound→threads/async, validación de esquema en el borde, bulk export): verificados sin corrección.

Este archivo se planea e implementa junto con esta skill (mismo plan de implementación, ver §6), pero vive físicamente en `skills/python-data-engineering/references/`, y su `SKILL.md` (quick reference + common mistakes) se actualiza en consecuencia — mismo tratamiento que recibió el cierre de full-load/incremental-extraction el 2026-07-30.

## 5. Fuera de alcance (de esta fase)

- Construcción/operación de APIs de serving (FastAPI, REST vs. GraphQL vs. gRPC, versionado de endpoint, seguridad de API) — ver §2.1, excluido de la suite por ahora, no diferido a una futura skill.
- Hosting/infraestructura del servicio API — pointer hacia `iac-cloud-data-engineering`, sin contenido hoy.
- Contrato/versionado de esquema de API (OpenAPI) — pointer hacia `quality-data-engineering`, sin contenido hoy.
- CDC (captura de cambios en el origen, Debezium, log/WAL/binlog) — ya asignado a la futura `streaming-data-engineering` (spec de la suite §7.8, §8), sin cambios.
- Contenido Delta Lake/Iceberg/Hudi específico de Spark — fuera de alcance de esta skill, pertenece (si acaso) a `spark-data-engineering`, sin cambios respecto a lo ya anotado en su propia spec.

## 6. Próximos pasos

Transición a `superpowers:writing-plans` para el plan de implementación: redacción completa de `SKILL.md` + los 8 reference files de `pipelines-architecture-data-engineering`, más el nuevo `external-api-integration.md` de `python-data-engineering` (y la actualización de su `SKILL.md`), con el contenido final en inglés y todas las correcciones de §4 incorporadas, siguiendo el mismo proceso de validación liviana de discoverability ya usado con las 3 skills anteriores.
