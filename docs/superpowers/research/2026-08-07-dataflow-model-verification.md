# Research: Dataflow Model claims — batch/streaming unification, the four questions, windowing vs. triggering

**Fecha:** 2026-08-07
**Alcance:** verificación de 3 claims del Paso 1 del plan de implementación de la skill de streaming (`docs/superpowers/sdd/2026-08-07-streaming-skill-implementation/task-1-brief.md`): (1) batch como caso especial de streaming sobre datos acotados, y un motor unificado que lo trata así; (2) las cuatro preguntas (what/where/when/how); (3) windowing y triggering como conceptos separables.

**Fuentes primarias consultadas:**
- Akidau, T. et al., *"The Dataflow Model: A Practical Approach to Balancing Correctness, Latency, and Cost in Massive-Scale, Unbounded, Out-of-Order Data Processing"*, Proceedings of the VLDB Endowment, Vol. 8, No. 12 (agosto 2015), pp. 1792–1803. PDF oficial descargado de `https://www.vldb.org/pvldb/vol8/p1792-Akidau.pdf` (365591 bytes) y extraído a texto con `pdftotext -layout` para permitir cita verbatim y grep contra el texto completo. Versión fija (no cambia: es un paper publicado en 2015, sin revisiones posteriores).
- Akidau, T., *"Streaming 101: The world beyond batch"*, O'Reilly Radar, 2015. URL: `https://www.oreilly.com/radar/the-world-beyond-batch-streaming-101/`. Consultado vía fetch directo el 2026-08-07 (no se pudo verificar fecha exacta de última edición del artículo; el contenido coincide con el que luego se expandió en el libro *Streaming Systems*, 2018).
- Akidau, T., *"Streaming 102: The world beyond batch"*, O'Reilly Radar, 2015. URL: `https://www.oreilly.com/radar/the-world-beyond-batch-streaming-102/`. Consultado vía fetch directo el 2026-08-07.

**Nota de método**: los dos artículos de O'Reilly fueron leídos mediante la herramienta de fetch web (no se pudo verificar independientemente con `curl` porque el sitio bloqueó la descarga directa sin JavaScript — intento registrado, resultado: página vacía). El paper VLDB sí se verificó de forma independiente: se descargó el PDF con `curl` y se extrajo con `pdftotext -layout`, permitiendo grep directo contra el texto íntegro del paper. Donde el paper y los artículos coinciden, se prioriza la cita del paper porque fue verificada de forma más robusta.

---

## 1. "Batch es un caso especial de streaming sobre datos acotados, y un motor unificado lo trata así"

**VEREDICTO: CORREGIDO.** El paper no formula la relación como "batch is a special case of streaming" — de hecho, evita esa formulación de forma explícita y encuadra la relación en sentido inverso: el streaming bien diseñado puede procesar datos acotados (bounded), y los sistemas batch históricamente ya procesan datos no acotados (unbounded) en corridas repetidas. La postura del paper es que el modelo hace la distinción **irrelevante**, no que uno sea un subconjunto formal del otro.

### 1.1 Lo que el paper dice literalmente (Sección 1.1, "Unbounded/Bounded vs Streaming/Batch")

> "When describing infinite/finite data sets, we prefer the terms unbounded/bounded over streaming/batch, because the latter terms carry with them an implication of the use of a specific type of execution engine. In reality, unbounded datasets have been processed using repeated runs of batch systems since their conception, and well-designed streaming systems are perfectly capable of processing bounded data. From the perspective of the model, the distinction of streaming or batch is largely irrelevant, and we thus reserve those terms exclusively for describing runtime execution engines."

Fuente: Akidau et al. 2015, p. 1794 (Sección 1.1), extraído verbatim del PDF oficial de VLDB.

### 1.2 La formulación de unificación real: "abstrae la distinción", no "batch es un subconjunto"

> "It abstracts away the distinction of batch vs. micro-batch vs. streaming, allowing pipeline builders a more fluid choice between them, while shielding them from the system-specific constructs that inevitably creep into models targeted at a single underlying system."

Fuente: Akidau et al. 2015, p. 1802 (Conclusiones), verbatim del PDF.

Y en la introducción, sobre el objetivo del modelo:

> "Separates the logical notion of data processing from the underlying physical implementation, allowing the choice of batch, micro-batch, or streaming engine to become one of simply correctness, latency, and cost."

Fuente: Akidau et al. 2015, p. 1793 (Sección 1, lista de contribuciones), verbatim del PDF.

### 1.3 Streaming 101: el motor unificado es descrito como superconjunto de batch, no batch como subconjunto de streaming

> "I would argue that well-designed streaming systems actually provide a strict superset of batch functionality."

Fuente: Akidau, "Streaming 101", O'Reilly Radar (fetch directo, 2026-08-07).

Este es el enunciado más cercano a la claim original, pero la dirección es la opuesta a como suele parafrasearse: el artículo dice que **streaming es un superconjunto de batch**, no que "batch sea un caso especial de streaming". Son formulaciones equivalentes en términos matemáticos (superconjunto A de B ⟺ B es un subconjunto/caso especial de A), pero el artículo nunca usa las palabras "special case" para describir la relación batch/streaming, y por tanto esa frase exacta no debe citarse como si fuera del propio Akidau.

**Wording corregido para el skill**: no escribir "batch is a special case of streaming" como si fuera una cita. En su lugar, usar la formulación real de las fuentes primarias: *el modelo trata la distinción streaming/batch como una propiedad del motor de ejecución, no del modelo lógico — los datos acotados (bounded) son simplemente el caso donde la fuente de datos termina, y un motor de streaming bien diseñado los procesa igual de bien; el paper describe esto como que el modelo "abstrae la distinción de batch vs. micro-batch vs. streaming" y que "well-designed streaming systems actually provide a strict superset of batch functionality"*.

---

## 2. Las cuatro preguntas: what / where / when / how

**VEREDICTO: SUPPORTED**, verbatim contra el paper y contra Streaming 102.

### 2.1 El paper (Sección 1, lista de contribuciones)

> "Decomposes pipeline implementation across four related dimensions, providing clarity, composability, and flexibility:
> – What results are being computed.
> – Where in event time they are being computed.
> – When in processing time they are materialized.
> – How earlier results relate to later refinements."

Fuente: Akidau et al. 2015, p. 1793, verbatim del PDF (extraído con `pdftotext -layout`, conserva la lista con guiones tal como aparece en el original).

### 2.2 Streaming 102: la misma formulación, con la asignación explícita a mecanismos concretos

Según el fetch directo del artículo:

> "_What_ results are calculated? = transformations; _Where_ in event-time are results calculated? = windowing; _When_ in processing-time are results materialized? = watermarks + triggers; _How_ do refinements of results relate? = accumulation"

Fuente: Akidau, "Streaming 102", O'Reilly Radar (fetch directo, 2026-08-07). Esto confirma exactamente la claim del brief y añade la correspondencia (what→transformaciones, where→windowing, when→watermarks/triggers, how→acumulación) que el skill puede usar para explicar cada pregunta.

**Nota de precisión**: el paper usa "How earlier results relate to later refinements" (p. 1793); Streaming 102 lo resume como "How do refinements of results relate?" — son formulaciones equivalentes, ligeramente reformuladas entre el paper académico y el artículo de blog posterior. Usar la del paper como cita primaria; la de Streaming 102 es corroboración, no una fuente distinta.

---

## 3. Windowing y triggering son conceptos separables

**VEREDICTO: SUPPORTED**, con cita verbatim del paper que usa literalmente la palabra "complementary" y "different axis of time".

> "In a nutshell, triggers are a mechanism for stimulating the production of GroupByKeyAndWindow results in response to internal or external signals. They are complementary to the windowing model, in that they each affect system behaviour along a different axis of time:
> • Windowing determines where in event time data are grouped together for processing.
> • Triggering determines when in processing time the results of groupings are emitted as panes."

Fuente: Akidau et al. 2015, Sección 2.3 "Triggers & Incremental Processing", p. 1797, verbatim del PDF.

Esto confirma la claim de forma directa: el paper no dice literalmente "orthogonal" (se buscó esa palabra exacta en todo el texto extraído y no aparece), pero "complementary... along a different axis" transmite exactamente la misma idea de separabilidad — windowing resuelve el eje event-time (dónde se agrupan los datos), triggering resuelve el eje processing-time (cuándo se emiten los resultados de esos grupos). Son ejes independientes que pueden combinarse libremente (por ejemplo, ventanas fijas con triggers por watermark, o ventanas de sesión con triggers por conteo de elementos).

Corroboración adicional del propio fetch de Streaming 102 (fuente secundaria del mismo autor, posterior al paper): "the article treats these as distinct orthogonal concepts... windowing answers the *where* (event-time slicing) while triggers answer the *when* (processing-time materialization). They are presented as complementary but separate dimensions of the model." — aquí sí aparece la palabra "orthogonal", pero como caracterización del fetch/resumen, no como cita textual del artículo; para efectos del skill, usar "complementary... different axis of time" (la cita real del paper) en vez de "orthogonal" (no verificado como palabra literal de ninguna fuente primaria).

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Batch es caso especial de streaming sobre datos acotados; motor unificado lo trata así | **CORREGIDO** — el paper encuadra la relación como "la distinción es irrelevante para el modelo" y "streaming provee un superconjunto estricto de la funcionalidad de batch", no como "batch is a special case of streaming" (frase no encontrada verbatim en ninguna fuente primaria) |
| 2 | Las cuatro preguntas: what/where/when/how | **SUPPORTED** — verbatim del paper (p. 1793) y corroborado en Streaming 102 |
| 3 | Windowing y triggering son separables | **SUPPORTED** — verbatim del paper (p. 1797): "complementary... different axis of time" |

## Implicación para el skill

- No citar "batch is a special case of streaming" como frase de Akidau. Usar en su lugar la cita real del paper (Sección 1.1) sobre irrelevancia de la distinción desde la perspectiva del modelo, y la cita de Streaming 101 sobre "strict superset of batch functionality" — dejando claro que la dirección lógica es streaming ⊇ batch, y que la fuente que usa esa dirección es el artículo de blog, no el paper VLDB.
- Las cuatro preguntas y la separabilidad windowing/triggering pueden citarse con total confianza contra el texto íntegro del paper VLDB 2015, que fue verificado de forma robusta (descarga directa + extracción de texto completo, no solo resumen de un fetcher).
