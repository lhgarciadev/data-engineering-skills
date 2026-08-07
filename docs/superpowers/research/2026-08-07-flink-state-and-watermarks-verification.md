# Research: Apache Flink checkpointing, watermarks, RocksDB state backend, allowed lateness

**Fecha:** 2026-08-07
**Alcance:** verificación de 4 claims del Paso 4 del plan de implementación de la skill de streaming. Fuente primaria: documentación oficial de Apache Flink, versión **stable = v2.3.0** (confirmado en el propio HTML de cada página, campo de versión visible en el navbar de la doc: "v2.3.0"). URLs bajo `https://nightlies.apache.org/flink/flink-docs-stable/...` (el alias "stable" apunta a la última versión GA en el momento de la consulta).

**Nota de método**: todas las citas se verificaron descargando el HTML con `curl -A "Mozilla/5.0"` y extrayendo texto plano con un script Python (`re.sub('<[^>]+>','',...)` + `html.unescape`), para poder grep directamente contra el texto íntegro de cada página en vez de depender solo del resumen de un fetcher basado en LLM (ver nota de método del Pase 3: el fetcher tuvo al menos un falso negativo en ese pase).

---

## 1. El checkpointing usa snapshots distribuidos con barreras que fluyen por el dataflow, basado en Chandy-Lamport

**VEREDICTO: SUPPORTED**, verbatim.

> "Flink uses a variant of the Chandy-Lamport algorithm known as asynchronous barrier snapshotting. When a task manager is instructed by the checkpoint coordinator (part of the job manager) to begin a checkpoint, it has all of the sources record their offsets and insert numbered checkpoint barriers into their streams. These barriers flow through the job graph, indicating the part of the stream before and after each checkpoint.
>
> Checkpoint n will contain the state of each operator that resulted from having consumed every event before checkpoint barrier n, and none of the events after it. As each operator in the job graph receives one of these barriers, it records its state. Operators with two input streams (such as a CoProcessFunction) perform barrier alignment so that the snapshot will reflect the state resulting from consuming events from both input streams up to (but not past) both barriers."

Fuente: `https://nightlies.apache.org/flink/flink-docs-stable/docs/learn-flink/fault_tolerance/`, sección "How does State Snapshotting Work?", Flink v2.3.0, verbatim (verificado por descarga directa con `curl`, no solo vía resumen del fetcher).

Nota adicional verbatim sobre no bloquear el procesamiento durante el snapshot:

> "Flink's state backends use a copy-on-write mechanism to allow stream processing to continue unimpeded while older versions of the state are being asynchronously snapshotted. Only when the snapshots have been durably persisted will these older versions of the state be garbage collected."

Fuente: misma página, verbatim.

---

## 2. Los watermarks fluyen con el stream y aseveran que no se esperan más eventos con timestamp por debajo del watermark

**VEREDICTO: SUPPORTED**, verbatim, prácticamente palabra por palabra contra la claim del brief.

> "The mechanism in Flink to measure progress in event time is watermarks. Watermarks flow as part of the data stream and carry a timestamp t. A Watermark(t) declares that event time has reached time t in that stream, meaning that there should be no more elements from the stream with a timestamp t' <= t (i.e. events with timestamps older or equal to the watermark)."

Fuente: `https://nightlies.apache.org/flink/flink-docs-stable/docs/concepts/time/`, sección sobre progreso de event time, Flink v2.3.0, verbatim.

**Nota de precisión**: la aserción es "no more elements... with timestamp t' <= t" — es decir, incluye eventos con timestamp *igual* al watermark, no solo estrictamente menor. Si el skill formula esto como "no further events *below* the watermark", debe aclarar que el propio watermark también queda cubierto (`<=`, no `<`).

---

## 3. Los state backends incluyen una opción de RocksDB embebido para estado más grande que la memoria

**VEREDICTO: SUPPORTED**, verbatim.

> "The EmbeddedRocksDBStateBackend holds in-flight data in a RocksDB database that is (per default) stored in the TaskManager local data directories... The EmbeddedRocksDBStateBackend always performs asynchronous snapshots."

> "The EmbeddedRocksDBStateBackend is encouraged for: Jobs with very large state, long windows, large key/value states. All high-availability setups... Note that the amount of state that you can keep is only limited by the amount of disk space available. This allows keeping very large state, compared to the HashMapStateBackend that keeps state in memory."

Fuente: `https://nightlies.apache.org/flink/flink-docs-stable/docs/ops/state/state_backends/`, sección "The EmbeddedRocksDBStateBackend", Flink v2.3.0, verbatim. Confirma exactamente la claim: RocksDB es la opción "embedded" (corre embebido dentro del proceso TaskManager, no como servicio externo) y su límite de tamaño de estado es el disco, no la memoria — a diferencia de `HashMapStateBackend`, que mantiene el estado como objetos Java en heap.

---

## 4. "Allowed lateness" permite que una ventana emita un resultado actualizado después de que pase el watermark

**VEREDICTO: SUPPORTED**, verbatim, incluyendo el comportamiento por defecto (0 = drop) que contrasta con la claim.

> "By default, late elements are dropped when the watermark is past the end of the window. However, Flink allows to specify a maximum allowed lateness for window operators. Allowed lateness specifies by how much time elements can be late before they are dropped, and its default value is 0. Elements that arrive after the watermark has passed the end of the window but before it passes the end of the window plus the allowed lateness, are still added to the window. Depending on the trigger used, a late but not dropped element may cause the window to fire again. This is the case for the EventTimeTrigger. In order to make this work, Flink keeps the state of windows until their allowed lateness expires."

Fuente: `https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/datastream/operators/windows/`, sección "Allowed Lateness", Flink v2.3.0, verbatim.

**Confirma exactamente la claim**: con `allowedLateness > 0`, un elemento tardío que llega dentro de la ventana de gracia puede hacer que el trigger (p. ej. `EventTimeTrigger`) dispare de nuevo — es decir, la ventana emite un resultado actualizado (un "late firing") después de que el watermark ya pasó el final de la ventana. Sin `allowedLateness` (el valor por defecto es 0), el elemento tardío simplemente se descarta.

---

## 5. `HashMapStateBackend` es el backend por defecto de Flink y no serializa en operación normal (a diferencia de `EmbeddedRocksDBStateBackend`)

**VEREDICTO: SUPPORTED**, verbatim en ambas mitades. Verificación añadida en la ronda de corrección 1 de la revisión de `state-and-delivery-guarantees.md`, tras un finding de que el archivo afirmaba esto sin veredicto de respaldo.

**Fuente:** `https://nightlies.apache.org/flink/flink-docs-stable/docs/ops/state/state_backends/`, Flink docs v2.3.0 (versión confirmada en la propia página), descargada y consultada directamente.

Sobre el default:

> "If nothing else is configured, the system will use the HashMapStateBackend."

Fuente: sección "Available State Backends", verbatim.

Sobre la ausencia de serialización en operación normal:

> "The HashMapStateBackend holds data internally as objects on the Java heap."

Fuente: sección "The HashMapStateBackend", verbatim.

Y, por contraste directo, la propia página confirma la ausencia de serialización en `HashMapStateBackend` al describir qué es distinto en RocksDB:

> "Unlike storing java objects in `HashMapStateBackend`, data is stored as serialized byte arrays..."

> "...the maximum throughput that can be achieved will be lower with this state backend [RocksDB]."

Fuente: sección "The EmbeddedRocksDBStateBackend", verbatim (ambas citas).

**Confirma exactamente la claim**: `HashMapStateBackend` es el backend usado cuando no se configura nada explícitamente, y mantiene el estado como objetos Java en heap sin (de)serialización en el camino normal de lectura/escritura — la propia página lo señala por contraste al explicar que RocksDB, a diferencia de `HashMapStateBackend`, sí serializa cada acceso, y que por eso su throughput máximo es menor. No requirió corrección.

---

## 6. En modo STREAMING, Flink procesa registros continuamente a través del pipeline en vez de dividir el trabajo en etapas discretas — a diferencia de su propio modo BATCH

**VEREDICTO: SUPPORTED**, verbatim. Agregado durante la redacción de `streaming-architecture-and-engines.md` (Paso 7 del plan), para dar verdict propio a la caracterización de Flink como motor "event-at-a-time" usada en la comparación de motores de ese archivo — no cubierta por los claims 1–5 de este research, que se centran en checkpointing/watermarks/state backends, no en el modelo de ejecución en sí.

> "In STREAMING execution mode, all tasks need to be online/running all the time. This allows Flink to immediately process new records through the whole pipeline, which we need for continuous and low-latency stream processing... Network shuffles are pipelined, meaning that records are immediately sent to downstream tasks, with some buffering on the network layer. Again, this is required because when processing a continuous stream of data there are no natural points (in time) where data could be materialized between tasks (or pipelines of tasks). This contrasts with BATCH execution mode where intermediate results can be materialized, as explained below."

Y sobre el modo BATCH, por contraste directo en la misma página:

> "In BATCH execution mode, the tasks of a job can be separated into stages that can be executed one after another. We can do this because the input is bounded and Flink can therefore fully process one stage of the pipeline before moving on to the next... Instead of sending records immediately to downstream tasks, as explained above for STREAMING mode, processing in stages requires Flink to materialize intermediate results of tasks to some non-ephemeral storage."

Fuente: `https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/datastream/execution_mode/`, secciones "STREAMING Execution Mode" y "BATCH Execution Mode", Flink v2.3.0 (misma versión "stable" que el resto de este research), verbatim (descargado con `curl -A "Mozilla/5.0"` y extraído con el mismo script de strip de tags).

**Confirma exactamente la claim**: el propio Flink documenta, por contraste con su propio modo BATCH, que su modo STREAMING envía cada registro inmediatamente al siguiente operador ("immediately sent to downstream tasks") porque no hay puntos naturales para materializar resultados intermedios en un stream continuo — es decir, procesamiento continuo registro por registro, no por lotes discretos. Esto es lo que sostiene la caracterización de Flink como motor "event-at-a-time" en la comparación con el motor de micro-batch de Spark (ver research de Spark, claim 1).

---

---

## 7. La arquitectura de un clúster Flink consiste en un JobManager y uno o más TaskManagers

**VEREDICTO: SUPPORTED**, verbatim. Agregado en fix round 1 de la revisión de `streaming-architecture-and-engines.md` (Paso 7), tras un finding de que el archivo nombraba "JobManager plus TaskManagers" sin verdict propio — los claims 1–6 de este research cubren checkpointing, watermarks, state backends y el modo de ejecución, no la topología del clúster en sí.

> "The Flink runtime consists of two types of processes: a JobManager and one or more TaskManagers... TaskManagers connect to JobManagers, announcing themselves as available, and are assigned work."

> "The JobManager has a number of responsibilities related to coordinating the distributed execution of Flink Applications: it decides when to schedule the next task (or set of tasks), reacts to finished tasks or execution failures, coordinates checkpoints, and coordinates recovery on..."

> "The TaskManagers (also called workers) execute the tasks of a dataflow, and buffer and exchange the data streams. There must always be at least one TaskManager."

Fuente: `https://nightlies.apache.org/flink/flink-docs-stable/docs/concepts/flink-architecture/`, sección "Anatomy of a Flink Cluster", Flink v2.3.0 (versión confirmada en el HTML de la página, `og:url` resuelve a `flink-docs-release-2.3`), verbatim (descargado con `curl -A "Mozilla/5.0"` y extraído con el mismo script de strip de tags del resto de este research).

**Confirma exactamente la claim**: un clúster Flink corre como un proceso JobManager (coordina la ejecución distribuida, programa tareas, coordina checkpoints y recuperación) y uno o más procesos TaskManager (ejecutan las tareas del dataflow). Esto es lo que sostiene la caracterización de Flink en la comparación de motores como algo que requiere "running and operating its own dedicated cluster" — no es una descripción genérica de "un clúster", es la topología de dos tipos de proceso que la propia documentación de arquitectura de Flink nombra explícitamente.

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Checkpointing con snapshots distribuidos y barreras, basado en Chandy-Lamport | **SUPPORTED** — verbatim, cita explícita "Chandy-Lamport algorithm" |
| 2 | Watermarks aseveran que no se esperan más eventos con timestamp ≤ watermark | **SUPPORTED** — verbatim; nota: la comparación documentada es `<=`, no solo `<` |
| 3 | RocksDB embebido para estado mayor que memoria | **SUPPORTED** — verbatim; límite pasa a ser espacio en disco, no RAM |
| 4 | Allowed lateness permite emitir resultado actualizado tras pasar el watermark | **SUPPORTED** — verbatim, incluyendo que el default es 0 (drop) y que el disparo tardío depende del trigger (`EventTimeTrigger`) |
| 5 | `HashMapStateBackend` es el default y no serializa en operación normal, a diferencia de RocksDB | **SUPPORTED** — verbatim en ambas mitades (default + ausencia de serialización por contraste con RocksDB) |
| 6 | Modo STREAMING procesa registro por registro, continuo, sin etapas discretas — a diferencia del propio modo BATCH de Flink | **SUPPORTED** — verbatim, fuente: `dev/datastream/execution_mode` v2.3.0, contraste directo STREAMING vs. BATCH en la misma página |
| 7 | Un clúster Flink consiste en un JobManager y uno o más TaskManagers | **SUPPORTED** — verbatim, fuente: `concepts/flink-architecture` v2.3.0, sección "Anatomy of a Flink Cluster" |

## Implicación para el skill

- Las cuatro claims del pase original quedaron confirmadas con cita textual exacta contra la documentación estable v2.3.0 de Flink, descargada y verificada de forma independiente (no solo vía resumen de fetcher). Ninguna requirió corrección.
- Si el skill cita la definición de watermark, preservar el `<=` (no simplificar a `<`) porque es el texto exacto de la fuente.
- Si el skill menciona "allowed lateness", aclarar que el comportamiento por defecto es 0 (drop inmediato) — el comportamiento de "permitir tardíos" es opt-in, no el default.
- Claim 5 (añadida en la ronda de corrección): el skill puede afirmar con confianza que `HashMapStateBackend` es el default y que no serializa en operación normal — ambas mitades están verificadas verbatim contra la doc v2.3.0.
- Claim 6 (añadida durante la redacción del Paso 7): el skill puede describir Flink como un motor "event-at-a-time" apoyándose en el contraste textual STREAMING vs. BATCH de la página `execution_mode` — no es una etiqueta de marketing, es la propia documentación explicando por qué su modo streaming no puede materializar resultados intermedios entre etapas.
- Claim 7 (añadida en fix round 1, tras finding de la revisión): el skill puede nombrar "JobManager" y "TaskManagers" como los dos tipos de proceso que componen un clúster Flink con total confianza — es la cita textual de la propia página de arquitectura, no una generalización sobre "algún tipo de clúster".
