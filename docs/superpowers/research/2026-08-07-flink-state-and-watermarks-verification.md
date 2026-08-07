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

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Checkpointing con snapshots distribuidos y barreras, basado en Chandy-Lamport | **SUPPORTED** — verbatim, cita explícita "Chandy-Lamport algorithm" |
| 2 | Watermarks aseveran que no se esperan más eventos con timestamp ≤ watermark | **SUPPORTED** — verbatim; nota: la comparación documentada es `<=`, no solo `<` |
| 3 | RocksDB embebido para estado mayor que memoria | **SUPPORTED** — verbatim; límite pasa a ser espacio en disco, no RAM |
| 4 | Allowed lateness permite emitir resultado actualizado tras pasar el watermark | **SUPPORTED** — verbatim, incluyendo que el default es 0 (drop) y que el disparo tardío depende del trigger (`EventTimeTrigger`) |

## Implicación para el skill

- Las cuatro claims de este pase quedaron confirmadas con cita textual exacta contra la documentación estable v2.3.0 de Flink, descargada y verificada de forma independiente (no solo vía resumen de fetcher). Ninguna requirió corrección.
- Si el skill cita la definición de watermark, preservar el `<=` (no simplificar a `<`) porque es el texto exacto de la fuente.
- Si el skill menciona "allowed lateness", aclarar que el comportamiento por defecto es 0 (drop inmediato) — el comportamiento de "permitir tardíos" es opt-in, no el default.
