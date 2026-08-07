# Research: Spark Structured Streaming — micro-batch default, Continuous Processing status, watermark/late-data semantics por output mode, stream-stream joins

**Fecha:** 2026-08-07
**Alcance:** verificación de 4 claims del Paso 5 del plan de implementación de la skill de streaming, incluyendo **dos candidatos de drift explícitamente señalados en el brief**. Fuente primaria: documentación oficial de Apache Spark, versión **4.2.0** (`https://spark.apache.org/docs/latest/` resolvió a esta versión al momento de la consulta — confirmado en el propio contenido de la página de overview). Nota importante de estructura: **a partir de Spark 4.0.0, la antigua "Structured Streaming Programming Guide" (una sola página larga) se dividió en varias páginas más pequeñas** bajo `https://spark.apache.org/docs/latest/streaming/`; las páginas relevantes consultadas fueron `streaming/index.html` (overview), `streaming/apis-on-dataframes-and-datasets.html` (windowing, watermarking, joins), y `streaming/performance-tips.html` (Continuous Processing).

**Nota de método**: todas las páginas se descargaron con `curl -A "Mozilla/5.0"` y se extrajeron a texto plano con Python (`re.sub` + `html.unescape`) para grep directo — mismo método que los Pases 2–4, necesario para evitar los falsos negativos observados en el fetcher basado en LLM durante el Pase 3.

---

## 1. El modelo de ejecución por defecto es micro-batch

**VEREDICTO: SUPPORTED**, verbatim, contra la documentación vigente (4.2.0).

> "Internally, by default, Structured Streaming queries are processed using a micro-batch processing engine, which processes data streams as a series of small batch jobs thereby achieving end-to-end latencies as low as 100 milliseconds and exactly-once fault-tolerance guarantees."

Fuente: `https://spark.apache.org/docs/latest/streaming/index.html`, sección de overview, verbatim.

---

## 2. CANDIDATO DE DRIFT — Estado de Continuous Processing: ¿experimental, estable o deprecado en la versión actual?

**VEREDICTO: SUPPORTED tal como está escrito en la documentación vigente — sigue siendo EXPERIMENTAL, no estable, no deprecado. Pero con un hallazgo relevante: el texto de esta sección de la doc parece no haberse actualizado sustancialmente desde Spark 2.3/2.4, lo cual el skill debería señalar como una señal de posible abandono, no de estabilidad.**

### 2.1 La etiqueta explícita en la doc vigente (4.2.0)

> "Continuous Processing **[Experimental]**
>
> Continuous processing is a new, experimental streaming execution mode introduced in Spark 2.3 that enables low (~1 ms) end-to-end latency with at-least-once fault-tolerance guarantees. Compare this with the default micro-batch processing engine which can achieve exactly-once guarantees but achieve latencies of ~100ms at best."

Fuente: `https://spark.apache.org/docs/latest/streaming/performance-tips.html`, sección "Continuous Processing", verbatim, encabezado literal con la etiqueta "[Experimental]" justo debajo del título de la sección.

### 2.2 Por qué esto es un hallazgo de drift, no solo una confirmación

El texto de esta sección **sigue redactado en presente histórico respecto a Spark 2.3/2.4** en la documentación de la versión 4.2.0 (siete-más major versions después):

> "As of Spark 2.4, only the following type of queries are supported in the continuous processing mode."

Fuente: misma página, verbatim. Esta frase no se ha actualizado para reflejar ninguna versión posterior a 2.4 — ni para anunciar más soporte, ni para anunciar deprecación. La sección completa de "Continuous Processing" en la doc 4.2.0 es, en su contenido sustantivo, idéntica a como aparecía en las versiones 2.x/3.x consultadas en investigaciones previas sobre este tema (no se hizo diff línea por línea contra una versión histórica específica en esta pasada, pero las referencias internas del propio texto — "introduced in Spark 2.3", "As of Spark 2.4" — son la evidencia directa de que el contenido no se ha revisado).

**Implicación para el skill**: la claim correcta no es solo "Continuous Processing es experimental" (que es cierto, verbatim, y sigue siendo así en 4.2.0), sino que además **el proyecto no ha tocado esta funcionalidad ni su documentación en varios años** — nunca fue promovida a estable, nunca fue formalmente deprecada, simplemente quedó congelada. El skill debe presentar Continuous Processing como "experimental y aparentemente estancada" en vez de "una alternativa de baja latencia en desarrollo activo" — la segunda framing sería engañosa dado lo que la propia doc revela sobre su falta de mantenimiento.

---

## 3. CANDIDATO DE DRIFT — Qué hace `withWatermark` con los datos tardíos, y su dependencia del output mode

**VEREDICTO: CORREGIDO. La simplificación común ("los datos tardíos simplemente se descartan") es inexacta en dos sentidos documentados explícitamente: (a) en modo Complete, el watermarking NO descarta nada — no aplica; (b) incluso en modo Append/Update, la documentación dice EXPLÍCITAMENTE que no hay garantía de que los datos más allá del watermark se descarten — solo hay garantía de lo contrario (que los datos dentro del umbral NO se descartan). Este es exactamente el tipo de drift que el brief pedía encontrar.**

### 3.1 El comportamiento depende del output mode — Complete mode no descarta nada vía watermark

> "It is important to note that the following conditions must be satisfied for the watermarking to clean the state in aggregation queries (as of Spark 2.1.1, subject to change in the future):
> - Output mode must be Append or Update. **Complete mode requires all aggregate data to be preserved, and hence cannot use watermarking to drop intermediate state.** See the Output Modes section for detailed explanation of the semantics of each output mode."

Fuente: `https://spark.apache.org/docs/latest/streaming/apis-on-dataframes-and-datasets.html`, sección "Conditions for watermarking to clean aggregation state", verbatim.

Esto por sí solo ya contradice la simplificación "los datos tardíos se descartan" como afirmación universal: **en modo Complete, no se descarta nada por watermarking**, porque el modo exige preservar todos los datos agregados.

### 3.2 En Append/Update mode, la garantía documentada es unidireccional — NO hay garantía de que lo que pasa el umbral se descarte

> "Semantic Guarantees of Aggregation with Watermarking:
> - A watermark delay (set with `withWatermark`) of '2 hours' guarantees that the engine will never drop any data that is less than 2 hours delayed. In other words, any data less than 2 hours behind (in terms of event-time) the latest data processed till then is guaranteed to be aggregated.
> - **However, the guarantee is strict only in one direction. Data delayed by more than 2 hours is not guaranteed to be dropped; it may or may not get aggregated. More delayed is the data, less likely is the engine going to process it.**"

Fuente: misma página, sección "Semantic Guarantees of Aggregation with Watermarking", verbatim (énfasis añadido). **Esta es la cita central de todo el hallazgo de drift**: la documentación oficial dice literalmente que los datos que exceden el watermark **no están garantizados a descartarse** — pueden o no ser agregados, dependiendo de detalles internos de timing. La simplificación "late data is dropped" invierte la única garantía formal que Spark realmente ofrece (que los datos *dentro* del umbral NO se pierden), y presenta como garantizado justamente lo que la doc dice explícitamente que no lo es.

### 3.3 El mecanismo real en Append/Update mode: se libera el *estado intermedio*, no necesariamente cada registro tardío

> "In this example, we are defining the watermark of the query on the value of the column 'timestamp', and also defining '10 minutes' as the threshold of how late is the data allowed to be. If this query is run in Update output mode..., the engine will keep updating counts of a window in the Result Table until the window is older than the watermark... when the watermark is updated to 12:11, the intermediate state for window (12:00 - 12:10) is cleared, and all subsequent data (e.g. (12:04, donkey)) is considered 'too late' and therefore ignored."

Y para Append mode específicamente:

> "the engine maintains intermediate counts for each window. However, the partial counts are not updated to the Result Table and not written to sink. The engine waits for '10 mins' for late date to be counted, then drops intermediate state of a window < watermark, and appends the final counts to the Result Table/sink."

Fuente: misma página, sección de ejemplo de watermarking, verbatim. **Precisión clave**: lo que se "descarta" (`drops`) formalmente es el **estado intermedio** de la ventana, no el registro individual per se — un registro tardío que llega después de que el estado de su ventana ya fue liberado queda "ignored" porque no hay estado con el que agregarlo, pero la garantía formal (§3.2) es sobre la probabilidad de que esto ocurra, no una certeza absoluta.

### 3.4 Resumen del comportamiento real por output mode (para uso directo del skill)

| Output mode | ¿Watermarking limpia estado? | ¿Datos tardíos se descartan? |
|---|---|---|
| **Complete** | No — el modo exige preservar todos los datos agregados; watermarking no puede usarse para esto | No aplica — no hay descarte por watermark |
| **Update** | Sí — libera estado de ventanas más viejas que el watermark | Datos dentro del delay: garantizado que no se pierden. Datos más allá del delay: **no garantizado que se descarten** (pueden o no agregarse) |
| **Append** | Sí — libera estado de ventana tras esperar el delay completo, y solo entonces emite el resultado final | Mismo principio que Update: la garantía formal es unidireccional |

---

## 4. Tipos de join stream-stream soportados y su requisito de watermark/límite temporal

**VEREDICTO: SUPPORTED**, verbatim, con la matriz de soporte completa de la doc oficial.

> "Inner Joins with optional Watermarking — Inner joins on any kind of columns along with any kind of join conditions are supported... To avoid unbounded state, you have to define additional join conditions [watermark + event-time constraint]..."
>
> "Outer Joins with Watermarking — While the watermark + event-time constraints is optional for inner joins, for outer joins **they must be specified**. This is because for generating the NULL results in outer join, the engine must know when an input row is not going to match with anything in the future."

Fuente: `https://spark.apache.org/docs/latest/streaming/apis-on-dataframes-and-datasets.html`, secciones "Inner Joins with optional Watermarking" y "Outer Joins with Watermarking", verbatim.

Matriz de soporte completa (stream-stream), verbatim de la tabla "Support matrix for joins in streaming queries":

| Join Type (Stream-Stream) | Soporte |
|---|---|
| Inner | "Supported, optionally specify watermark on both sides + time constraints for state cleanup" |
| Left Outer | "Conditionally supported, must specify watermark on right + time constraints for correct results, optionally specify watermark on left for all state cleanup" |
| Right Outer | "Conditionally supported, must specify watermark on left + time constraints for correct results, optionally specify watermark on right for all state cleanup" |
| Full Outer | "Conditionally supported, must specify watermark on one side + time constraints for correct results, optionally specify watermark on the other side for all state cleanup" |
| Left Semi | "Conditionally supported, must specify watermark on right + time constraints for correct results, optionally specify watermark on left for all state cleanup" |

Fuente: misma página, verbatim.

**Restricción adicional verbatim, relevante para el skill**: "As of Spark 2.4, you can use joins only when the query is in Append output mode. Other output modes are not yet supported." — igual que con Continuous Processing, esta cita conserva la referencia a "Spark 2.4" en la doc 4.2.0, sugiriendo que tampoco esta restricción se ha revisado recientemente; el skill debe presentarla como el estado documentado actual, sin asumir que cambiará.

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Modelo de ejecución por defecto es micro-batch | **SUPPORTED** — verbatim |
| 2 | **[Drift]** Estado de Continuous Processing | **SUPPORTED tal como escrito: sigue "[Experimental]" en 4.2.0** — con hallazgo adicional: el texto de la sección no se ha actualizado desde Spark 2.3/2.4, señal de estancamiento que el skill debe mencionar |
| 3 | **[Drift]** `withWatermark` y datos tardíos, por output mode | **CORREGIDO** — "los datos tardíos se descartan" es una simplificación incorrecta: en Complete mode no aplica descarte alguno; en Append/Update la propia doc dice que el descarte de datos fuera del umbral **no está garantizado** (solo está garantizado que los datos dentro del umbral NO se pierden) |
| 4 | Tipos de join stream-stream y su requisito de watermark | **SUPPORTED** — verbatim, matriz de soporte completa citada |

## Implicación para el skill

- **Nunca escribir "Structured Streaming drops late data" como afirmación universal.** Usar la formulación exacta: dentro del watermark delay, los datos están garantizados a no perderse; más allá del delay, la documentación dice explícitamente que no hay garantía de descarte (puede o no agregarse) — y en modo Complete no hay descarte por watermark en absoluto.
- Presentar Continuous Processing como "experimental, y sin cambios sustanciales documentados desde Spark 2.3/2.4" — no como una característica en desarrollo activo.
- La matriz de joins stream-stream puede citarse con confianza total: es una tabla oficial, verbatim, sin ambigüedad de interpretación.
