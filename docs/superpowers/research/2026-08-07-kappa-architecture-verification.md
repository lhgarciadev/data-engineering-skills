# Research: arquitectura Kappa — la propuesta original de Jay Kreps vs. la simplificación posterior

**Fecha:** 2026-08-07
**Alcance:** verificación de 3 claims del Paso 7 del plan de implementación de la skill de streaming. Fuente primaria: Jay Kreps, *"Questioning the Lambda Architecture"*, O'Reilly Radar, publicado el **2 de julio de 2014** (fecha de publicación confirmada en los metadatos de la página: `Published Time: 2014-07-02`). URL: `https://www.oreilly.com/radar/questioning-the-lambda-architecture/`.

**Nota de método**: tanto `curl` directo como el fetcher basado en LLM tuvieron problemas de acceso a `oreilly.com` (curl recibió 403; el fetcher sí devolvió contenido, pero dado el riesgo de que un resumen de LLM parafrasee o incluso invente texto, se verificó de forma independiente usando un servicio de renderizado de texto de terceros (`r.jina.ai`, que convierte la página a Markdown limpio sin ejecutar JavaScript del lado del bloqueo de bots) para obtener el **artículo completo en texto plano** y hacer grep directo. Todas las citas de este documento están confirmadas contra ese texto completo descargado — no contra el resumen del fetcher únicamente, aunque en los casos comprobados ambos coincidieron palabra por palabra.

---

## 1. La propuesta de Kappa: un único pipeline de streaming donde el reprocesamiento se hace reproduciendo el log desde un offset, en vez de una capa batch separada

**VEREDICTO: SUPPORTED**, verbatim, incluyendo la receta exacta de 4 pasos que Kreps describe.

> "So, how can we do the reprocessing directly from our stream processing job? My preferred approach is actually stupidly simple:
> 1. Use Kafka or some other system that will let you retain the full log of the data you want to be able to reprocess and that allows for multiple subscribers. For example, if you want to reprocess up to 30 days of data, set your retention in Kafka to 30 days.
> 2. When you want to do the reprocessing, start a second instance of your stream processing job that starts processing from the beginning of the retained data, but direct this output data to a new output table.
> 3. When the second job has caught up, switch the application to read from the new table.
> 4. Stop the old version of the job, and delete the old output table."

Fuente: Kreps, "Questioning the Lambda Architecture" (2014-07-02), sección "An alternative", verbatim (confirmado por descarga independiente vía renderizador de texto, coincide palabra por palabra con la primera extracción vía fetcher).

Sobre el mecanismo de reproducir el log desde un offset específicamente:

> "A stream processor consuming this data just maintains an 'offset,' which is the log entry number for the last record it has processed on each of these partitions. So, changing the consumer's position to go back and reprocess data is as simple as restarting the job with a different offset."

Fuente: misma página, verbatim. **Esto conecta directamente con el Pase 2 de este research** (offset por partición, replayable) — la propuesta de Kappa depende exactamente del mecanismo de offsets de Kafka verificado en ese pase.

Y sobre el nombre "Kappa" mismo — Kreps lo acuña él mismo en este artículo, con un tono deliberadamente informal/tentativo:

> "Maybe we could call this the Kappa Architecture, though it may be too simple of an idea to merit a Greek letter."

Fuente: misma página, verbatim. El nombre no fue impuesto por la comunidad después — el propio Kreps lo propone en el artículo, aunque restándole importancia ("too simple of an idea to merit a Greek letter").

---

## 2. El costo declarado de Lambda es mantener dos rutas de código que deben producir el mismo resultado

**VEREDICTO: SUPPORTED**, verbatim.

> "The problem with the Lambda Architecture is that maintaining code that needs to produce the same result in two complex distributed systems is exactly as painful as it seems like it would be. I don't think this problem is fixable."

Fuente: misma página, sección "And the bad…", verbatim.

Corroboración adicional sobre el consenso de la comunidad respecto a esta complejidad operativa:

> "Programming in distributed frameworks like Storm and Hadoop is complex. Inevitably, code ends up being specifically engineered toward the framework it runs on. The resulting operational complexity of systems implementing the Lambda Architecture is the one thing that seems to be universally agreed on by everyone doing it."

Fuente: misma página, mismo párrafo, verbatim.

---

## 3. ¿"Reemplaza la capa batch por completo" es la claim original de Kreps, o una simplificación posterior?

**VEREDICTO: CORREGIDO. Es una simplificación posterior. El artículo original nunca usa la palabra "replace" en ningún lugar del texto (se buscó explícitamente y no aparece), y en dos lugares distintos Kreps hedgea explícitamente en la dirección contraria: dice directamente que los datos SÍ pueden seguir yendo a HDFS/batch, y presenta su propuesta como "una alternativa" a considerar en ciertos casos, no como un reemplazo universal.**

### 3.1 Kreps explícitamente preserva un lugar para HDFS/batch — solo saca el reprocesamiento de ahí

> "Note that this doesn't mean your data can't go to HDFS; it just means that you don't run your reprocessing there. Kafka has good integration with Hadoop, so mirroring any Kafka topic into HDFS is easy. It is often useful for the output or even intermediate streams from a stream processing job to be available in Hadoop for analysis in tools like Hive or for use as input for other, offline data processing flows."

Fuente: misma página, verbatim. Esta es la cita central para esta claim: la propuesta de Kappa no elimina HDFS o el procesamiento batch de la arquitectura — solo elimina la necesidad de que el **reprocesamiento** específicamente pase por un sistema batch separado. Los datos siguen pudiendo fluir a Hadoop para otros usos (análisis, Hive, otros pipelines offline).

### 3.2 El cierre del artículo: "considérese como una alternativa", no como un reemplazo universal

> "The real advantage isn't about efficiency at all, but rather about allowing people to develop, test, debug, and operate their systems on top of a single processing framework. So, **in cases where simplicity is important, consider this approach as an alternative to the Lambda Architecture.**"

Fuente: misma página, párrafo de cierre, verbatim (énfasis añadido). El propio Kreps enmarca su propuesta como condicional ("en casos donde la simplicidad importa") y como "una alternativa a considerar", no como una sustitución categórica y universal de la arquitectura Lambda o de los sistemas batch en general.

### 3.3 Ausencia total de la palabra "replace"

Se buscó la palabra "replace" en el texto íntegro del artículo (extraído completo, no solo un resumen) y **no aparece ninguna vez**. La formulación "Kappa replaces the batch layer entirely" que suele repetirse en fuentes secundarias es, por tanto, una simplificación posterior de lo que Kreps realmente escribió — el artículo original es más matizado: elimina la necesidad de un sistema batch *separado y sincronizado* específicamente para el trabajo de *reprocesamiento*, sin negar que HDFS/batch sigan teniendo un lugar útil para otros fines en la misma arquitectura.

**Implicación para el skill**: al presentar la arquitectura Kappa, no escribir "reemplaza la capa batch por completo" como si fuera la propuesta original de Kreps. La formulación correcta es: *Kappa elimina la necesidad de un sistema batch separado y sincronizado específicamente para el reprocesamiento — reprocesar es simplemente volver a correr el mismo pipeline de streaming desde un offset anterior — pero el propio Kreps aclara que los datos pueden seguir fluyendo a sistemas batch para otros fines, y presenta la idea como una alternativa a considerar cuando la simplicidad importa, no como un reemplazo universal de Lambda o del procesamiento batch en general.*

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Kappa: un único pipeline de streaming, reprocesamiento vía replay del log desde un offset | **SUPPORTED** — verbatim, receta de 4 pasos citada completa; el nombre "Kappa" lo acuña el propio Kreps en este artículo |
| 2 | Costo declarado de Lambda: mantener dos rutas de código con el mismo resultado | **SUPPORTED** — verbatim |
| 3 | "Reemplaza la capa batch por completo": ¿claim original o simplificación posterior? | **CORREGIDO** — es una simplificación posterior; el artículo nunca usa la palabra "replace", preserva explícitamente un rol para HDFS/batch, y presenta la propuesta como "una alternativa" condicional, no un reemplazo universal |

## Implicación para el skill

- El skill puede citar con total confianza la receta de 4 pasos y el costo de Lambda (dos rutas de código) — son citas literales y no ambiguas.
- El skill **no debe** escribir "Kappa reemplaza la capa batch" atribuido a Kreps. Debe usar la formulación matizada de §3.3, y puede señalar explícitamente que esta es una corrección respecto a la simplificación habitual — es información útil para quien use el skill para entender el debate histórico Lambda-vs-Kappa con precisión.
