# Research: observabilidad de datos — los "5 pilares" (Monte Carlo), OpenLineage, lineage en dbt, MTTD/MTTR y detección de anomalías

**Fecha:** 2026-08-03
**Alcance:** verificación de 5 bloques de claims de la CAPA 5 ("Observabilidad de datos") del draft para el futuro skill `quality-data-engineering`: (1) origen exacto, término literal y naturaleza de vendor de "los 5 pilares de la observabilidad de datos"; (2) OpenLineage como estándar abierto y neutral para hablar de lineage, alternativa al framing de vendor; (3) si dbt genera un grafo de lineage real (verificado contra `docs.getdbt.com`, cruzado con `skills/pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md` para no duplicar ni contradecir lo ya dicho sobre Dagster); (4) origen real de MTTD/MTTR (¿nacen en SRE/operaciones de TI, no en el mundo de datos?) y si existe una fuente neutral que los aplique formalmente a calidad de datos; (5) mecánica de detección de anomalías basada en patrones aprendidos vs. umbrales fijos, con fuente técnica real si existe. Todo verificado por fetch directo contra fuentes primarias — `montecarlo.ai` (antes `montecarlodata.com`), `docs.getmontecarlo.com`, `openlineage.io`, `docs.getdbt.com`, `sre.google`, `atlassian.com`, `pagerduty.com` — marcando explícitamente cada vez que una fuente es de vendor/marketing y no un estándar neutral.

---

## 1. "Los 5 pilares de la observabilidad de datos" — origen, términos exactos, y por qué es contenido de vendor

**VEREDICTO: el claim del draft es correcto en los 5 nombres, pero debe presentarse explícitamente como marco de marketing de un vendor (Monte Carlo), no como estándar neutral — y así lo confirma la propia evidencia, incluyendo cómo terceros lo citan sin atribución.**

### Fuente primaria del término

El post original que acuña el término, del propio Monte Carlo (nota: el dominio corporativo migró de `montecarlodata.com` a `montecarlo.ai` — el fetch a la URL antigua redirige 301 a la nueva):

> "Incident Prevention For Data Teams: Introducing The 5 Pillars Of Data Observability"

Fuente: [montecarlo.ai/blog-introducing-the-5-pillars-of-data-observability](https://montecarlo.ai/blog-introducing-the-5-pillars-of-data-observability/) (fetch directo; página con actualización fechada 23 dic 2020; autora Barr Moses, cofundadora y CEO de Monte Carlo).

**Los 5 términos exactos, citas textuales de esa misma fuente:**

1. **Freshness** — "is my data up-to-date? What is its recency? Are there gaps in time when the data has not been updated?"
2. **Distribution** — "field-level health", incluye métricas como valores nulos y "abnormal representation of expected values".
3. **Volume** — "the amount of data in a file or database", indicador de completitud.
4. **Schema** — "a structure described in a formal language as supported by a database management system".
5. **Lineage** — descrito como el pilar que ayuda a "put all four of the preceding pillars together" para mapear el ecosistema de datos.

Es decir: **los 5 nombres del draft coinciden exactamente** — Freshness, Volume, Distribution, Schema, Lineage — con la fuente original de Monte Carlo (el orden en el post prioriza Freshness/Distribution/Volume/Schema/Lineage, pero son los mismos 5 términos, no hay variación de nombres).

### Es contenido de vendor — evidencia explícita, no solo inferencia

- La fuente es un blog corporativo de Monte Carlo, empresa que vende una plataforma comercial de "data observability". La autora es su CEO. No es un paper, ni un estándar de una fundación, ni una norma industrial (a diferencia de, p. ej., OpenLineage — ver §2).
- **Corroboración de que el marco se volvió terminología difundida sin atribución**: la página de glosario de Databricks (otro vendor, sin relación societaria con Monte Carlo) reproduce los mismos 5 pilares casi palabra por palabra pero **sin acreditar a Monte Carlo ni a Barr Moses** — cita textual: "The industry often describes observability using five pillars: Freshness... Volume... Distribution... Schema... Lineage...". Fuente: [databricks.com/glossary/data-observability](https://www.databricks.com/glossary/data-observability) (fetch directo). Esto confirma el patrón: el marco se convirtió en vocabulario de facto de la industria, pero su origen documentado y verificable es un post de marketing de un vendor específico, no un organismo neutral.

**Nota de honestidad epistémica**: no se encontró un estándar/framework equivalente publicado por una fundación neutral (tipo Linux Foundation, ISO, DAMA) que defina "pilares de observabilidad de datos" — a diferencia de lineage, donde sí existe una alternativa neutral real (OpenLineage, ver §2). Si el skill usa los 5 pilares como estructura pedagógica (es razonable, es el vocabulario que domina la conversación de la industria), debe decir explícitamente "marco popularizado por Monte Carlo (vendor)" — exactamente como ya lo redactó el draft — y no presentarlo como un estándar.

---

## 2. OpenLineage — estándar abierto real, neutral, alternativa a nombrar lineage sin depender de un vendor

**VEREDICTO: confirmado. OpenLineage es un estándar abierto de verdad — gobernado por la Linux Foundation (LF AI & Data), no por una empresa — y es una base neutral legítima para que el skill hable de lineage sin apoyarse únicamente en el framing de Monte Carlo.**

### Qué es, cita textual de la fuente oficial

> "An open framework for data lineage collection and analysis" (tagline de portada) y "an open platform for collection and analysis of data lineage" que provee "an open standard for lineage data collection, libraries for common languages, and integrations with data pipeline tools."

Fuente: [openlineage.io](https://openlineage.io/) (fetch directo).

### Qué modela exactamente — las 3 entidades del object model, citas textuales

- **Job**: "A process that consumes or produces Datasets." — identificado por un nombre único dentro de un namespace.
- **Run**: "An instance of a Job that represents one of its occurrences in time." — cada run tiene un `runId` único (UUID), lo que permite observar cómo cambia un job entre ejecuciones.
- **Dataset**: "An abstract representation of data" — identificado por un nombre único dentro del namespace de la fuente de datos, derivado de su ubicación física (ej. `db.host.database.schema.table`).

Fuente: [openlineage.io/docs/spec/object-model](https://openlineage.io/docs/spec/object-model/) (fetch directo). El modelo se extiende mediante **facets** — "atomic piece[s] of metadata" adjuntas a Job/Run/Dataset — y se emite como eventos (`RunEvent`, `DatasetEvent`, `JobEvent`) en tiempo real conforme un pipeline se ejecuta.

### Gobernanza — por qué sí es neutral, a diferencia de "los 5 pilares"

Cita textual del anuncio oficial de incorporación a la fundación:

> "The LF AI & Data Foundation provides a vendor-neutral governance structure that can help the project grow broad industry collaboration." Y: "Becoming a LF AI & Data project ensures that OpenLineage can never belong to a company, or even a group of developers; it belongs to us all."

Fuente: [openlineage.io/blog/joining-lfai](https://openlineage.io/blog/joining-lfai/) (fetch directo; fecha del anuncio: 22 de julio de 2021; Julien Le Dem —creador original de Apache Parquet— figura como Project Lead al momento del anuncio).

**Esto sí es la alternativa neutral que pidió la verificación**: mientras "los 5 pilares" es vocabulario de marketing de un vendor específico, OpenLineage es un estándar técnico real con especificación versionada, gobernanza de fundación, y múltiples integraciones de terceros (no solo de un proveedor) — legítimo para que el skill lo use como base neutral al hablar de lineage, complementando (no reemplazando) la mención de vendor.

### Nota relevante para el cruce con dbt (ver §3)

Existe una integración OpenLineage↔dbt, pero **no es nativa de `dbt-core`**: es un paquete separado del propio repo de OpenLineage (`openlineage-dbt`, wrapper `dbt-ol` que reemplaza al comando `dbt run`), que lee `manifest.json` y `run_results.json` después de una corrida y emite los eventos al backend de OpenLineage (ej. Marquez). Fuente: resultados de búsqueda sobre [github.com/OpenLineage/OpenLineage/tree/main/integration/dbt](https://github.com/OpenLineage/OpenLineage/tree/main/integration/dbt) — **no se hizo fetch directo del README de esta integración específica, esto queda como corroboración de búsqueda, no como cita textual verificada**. Dato adicional de búsqueda: hay un issue abierto en `dbt-labs/dbt-core` (`#11750`) pidiendo integración nativa de OpenLineage dentro de dbt-core — señal de que, al momento de este research, **dbt no habla OpenLineage de forma nativa**, es un integración externa.

---

## 3. Lineage en dbt — sí genera un grafo de lineage real, y cómo se relaciona con lo que ya dice el skill sobre Dagster

**VEREDICTO: confirmado. dbt sí construye y visualiza un grafo de lineage real, derivado directamente de las llamadas `ref()`/`source()` — es DAG de dependencias declaradas a nivel de transformación (build-time), lo cual complementa sin contradecir lo que `orchestrator-selection-and-topology.md` ya dice sobre Dagster.**

### Confirmación oficial — nombre actual del feature y qué muestra

Al momento de este research, el feature de exploración de linaje en `docs.getdbt.com` se llama **"Catalog"** (dbt Cloud/dbt Docs v2) — nota de honestidad epistémica: esta interfaz ha tenido más de un nombre a lo largo del tiempo (antes conocida como "dbt Explorer"), pero **la verificación fue contra la doc vigente al momento del fetch**, no contra el historial de renombres, que no se investigó en profundidad.

Citas textuales:

> "a visualization of your project's DAG that you can interact with"

> "With Catalog, you can view your project's resources (such as models, tests, and metrics), their lineage, and model consumption to gain a better understanding of its latest production state."

> "The nodes in the lineage graph represent the project's resources and the edges represent the relationships between the nodes."

Fuente: [docs.getdbt.com/docs/explore/explore-projects](https://docs.getdbt.com/docs/explore/explore-projects) (fetch directo).

### Cómo se construye el grafo — DAG serializado, generado desde el código

Cada llamada a `ref()`/`source()` en el SQL de un modelo codifica una arista de dependencia; dbt recolecta esas aristas en un DAG (grafo acíclico dirigido) que se serializa en `manifest.json`. Catalog consume esos metadatos vía la **Discovery API**, poblados automáticamente cuando un job corre `dbt build`/`dbt docs generate` en un entorno de producción o staging. Fuente: [docs.getdbt.com/docs/explore/explore-projects](https://docs.getdbt.com/docs/explore/explore-projects) (fetch directo, sección de "Discovery API" y "applied state").

También existe la visualización clásica de `dbt docs` (dbt Core, self-hosted, sin dbt Cloud): "From the dbt Docs page, click the green button in the bottom-right corner ... to expand a 'mini-map' of your DAG ... By clicking the 'Expand' button ... we can pivot the graph horizontally and view the full lineage for our model. This lineage is filterable using the `--select` and `--exclude` flags". Fuente: [docs.getdbt.com/docs/build/view-documentation](https://docs.getdbt.com/docs/build/view-documentation) (fetch directo). Es decir: el grafo de lineage en dbt **no depende de dbt Cloud** — `dbt docs generate && dbt docs serve` ya lo produce localmente en dbt Core puro.

### Cruce con `orchestrator-selection-and-topology.md` — complementa, no contradice

Se leyó primero el archivo indicado (`skills/pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md`, línea 9) antes de escribir esta sección, tal como pidió el encargo. Cita exacta de lo que ese archivo ya afirma sobre Dagster:

> "Dagster. The asset-centric challenger: instead of thinking in tasks, you think in the **data assets** you produce — a table, a model, a dataset — and their dependencies; the orchestrator understands the lineage. [...] data-centric observability — what's fresh, what's stale."

Esto es correcto y **no lo contradice nada de lo verificado aquí** — son dos capas distintas de lineage, complementarias:

- **Dagster**: lineage a nivel de **orquestación** — el grafo de *assets* que el orquestador ejecuta y programa, con conciencia de frescura/staleness en tiempo de ejecución, across cualquier tipo de asset (no solo SQL/dbt).
- **dbt (Catalog / `dbt docs`)**: lineage a nivel de **transformación declarada** — el DAG de modelos SQL/Python dentro de un proyecto dbt, derivado estáticamente de `ref()`/`source()`, típicamente el sub-grafo que corre *dentro* de una tarea del orquestador (dbt puede ser orquestado tanto por Airflow como por Dagster).
- **OpenLineage (§2)**: el estándar de **interoperabilidad** que permite que ambos tipos de lineage (el de un orquestador y el de dbt) se emitan en un formato común y se junten en una sola vista cross-herramienta — de hecho, tanto Dagster como dbt tienen integraciones (no nativas de dbt-core, ver nota en §2) que emiten eventos OpenLineage.

**Recomendación accionable para el futuro contenido del skill**: presentar el lineage de dbt como el ángulo de "calidad/observabilidad a nivel de modelo de transformación" (impact analysis dentro del proyecto dbt: "si cambio esta columna, ¿qué modelos aguas abajo se rompen"), y dejar que `pipelines-architecture-data-engineering` mantenga la propiedad del ángulo "lineage como argumento de selección de orquestador" (Dagster vs. Airflow) — sin duplicar esa comparación aquí.

---

## 4. MTTD / MTTR — origen real (SRE/operaciones de TI, más atrás incluso: ingeniería de confiabilidad/mantenibilidad), y su aplicación a calidad de datos

**VEREDICTO parcial: confirmado que MTTD/MTTR nacen fuera del mundo de datos (SRE y, antes aún, ingeniería de confiabilidad/mantenibilidad industrial) — pero NO se encontró una fuente neutral (no-vendor) que los formalice específicamente para "calidad de datos". La única formalización explícita para datos que se encontró es, de nuevo, de vendors de data observability.**

### Origen en SRE — confirmado con cita textual directa del Google SRE Book

> "Reliability is a function of mean time to failure (MTTF) and mean time to repair (MTTR)"

Fuente: [sre.google/sre-book/introduction](https://sre.google/sre-book/introduction/) (fetch directo, capítulo "Introduction", sección "Emergency Response"). Contexto: reliability de **sistemas/servicios de software**, no de datos.

MTTD (o "time to detect") también aparece en material oficial de Google SRE, en el **SRE Workbook** (el volumen práctico complementario al libro), en el capítulo de cultura de postmortems:

> "These charts show us trends like how many postmortems we have per month per organization, incident mean duration, time to detect, time to resolve, and blast radius."

Fuente: [sre.google/workbook/postmortem-culture](https://sre.google/workbook/postmortem-culture/) (fetch directo).

### Matiz importante que el draft no menciona — el propio Google cuestiona la validez estadística de MTTR

Hallazgo adicional relevante para la sección de observabilidad del skill, con honestidad epistémica: Google publicó un reporte propio, *"Incident Metrics in SRE"* (Štěpán Davidovič, Senior Staff SRE en Google), que usa simulación Monte Carlo (el método estadístico, no la empresa) para argumentar que:

> "these statistics are poorly suited for decision making or trend analysis in the context of production incidents"

— refiriéndose específicamente a MTTR y MTTM (mean time to mitigation) como métricas para medir mejoras de proceso a lo largo del tiempo, y proponiendo métricas alternativas. Fuente: [sre.google/resources/practices-and-processes/incident-metrics-in-sre](https://sre.google/resources/practices-and-processes/incident-metrics-in-sre/) (fetch directo). Esto es contexto de **incidentes de sistemas/servicios**, no de datos — pero es una fuente neutral (Google, no un vendor de observabilidad) que matiza la idea de "la métrica que corona todo": incluso en su ámbito de origen, MTTR es una métrica con limitaciones estadísticas conocidas y documentadas por quien la usa a gran escala. Vale la pena que el skill mencione esto como matiz senior, no solo presentar MTTD/MTTR sin crítica.

### Origen anterior a SRE — ingeniería de confiabilidad/mantenibilidad (no verificado por fetch directo, solo por búsqueda)

Búsqueda de corroboración (no fetch directo de un estándar primario) indica que MTTR es más antiguo que el movimiento DevOps/SRE: se remonta a estándares militares/aeroespaciales de mantenibilidad de mediados del siglo XX (p. ej. `MIL-STD-721`, ligado a MTBF/MTTR como métricas de hardware), y más tarde se incorporó a estándares industriales como ISO 14224 (petróleo/petroquímica). **Esto no se verificó contra el texto primario de esos estándares militares** — queda marcado explícitamente como corroboración de búsqueda, en el mismo espíritu que la nota sobre "medallion" en el research previo del repo. Para el skill, el punto accionable es más simple y sí está bien verificado: MTTD/MTTR son términos de reliability/operaciones de sistemas (SRE es la fuente más citable y ya verificada arriba), no términos que nacieron para describir calidad de datos.

### Aplicación formal a "calidad de datos" — solo encontrada en fuentes de vendor

No se encontró una fuente neutral (fundación, paper académico, DAMA/DMBOK, o documentación de un proveedor de infraestructura no especializado en "data observability") que defina o formalice MTTD/MTTR aplicados a calidad/pipelines de datos. Todo lo encontrado que hace esa conexión explícita proviene de vendors del espacio de "data observability" (Monte Carlo, Actian, Pantomath, StrongDM, entre otros blogs de marketing) — mismo patrón que en §1: es vocabulario de vendor trasplantado desde SRE al dominio de datos, no una formalización neutral. Ejemplo representativo (marcado explícitamente como vendor, no como cita verificada por fetch directo — se obtuvo por snippet de búsqueda, no fetch): la propia Monte Carlo enmarca su métrica de "data downtime" como función de MTTD + MTTR ("number of incidents × (time to detect + time to resolve)"), extendiendo directamente el vocabulario de SRE a datos.

**Conclusión accionable**: el draft puede seguir usando MTTD/MTTR como "la métrica que corona todo" — es razonable y es el vocabulario que domina la conversación de observabilidad de datos — pero el skill debe ser honesto en dos frentes: (1) son términos importados de SRE/operaciones de sistemas, no inventados para datos — verificado; (2) su aplicación formal a "calidad de datos" específicamente es, hasta donde este research pudo verificar, terreno de vendors, no de un estándar neutral — a diferencia de lineage, donde sí existe OpenLineage como ancla neutral.

---

## 5. Detección de anomalías basada en patrones aprendidos vs. umbrales fijos

**VEREDICTO: existe documentación técnica real (de vendor, marcada como tal) que describe el mecanismo con suficiente especificidad — reentrenamiento sobre ventana móvil, selección de modelo por serie, ajuste de sensibilidad. El draft puede citarlo como descripción conceptual razonable sin necesidad de inventar mecánica no verificada.**

### Fuente técnica — documentación de producto de Monte Carlo (vendor, marcado explícitamente)

Citas textuales de la documentación técnica de producto (no un blog de marketing, sino la doc de referencia del producto):

> "an ensemble of anomaly detection models, optimized for different cases and profiles of data" — "the best suited model is chosen based on patterns observed in that series of data."

Sobre reentrenamiento/estacionalidad:

> "Models are frequently retrained using a rolling window of recent data."

Sobre ajuste de sensibilidad (equivalente a mover el umbral de alerta sin volver a un umbral fijo manual):

> "Low sensitivity will widen the threshold, resulting in fewer alerts" (y sensibilidad alta produce umbrales más estrechos). También soporta un umbral manual como alternativa opcional al umbral generado por ML.

Fuente: [docs.getmontecarlo.com/docs/anomaly-detection-overview](https://docs.getmontecarlo.com/docs/anomaly-detection-overview) (fetch directo — **documentación de producto de un vendor**, no un paper ni un estándar).

### Lectura para el skill

El claim del draft ("en vez de umbrales fijos, la observabilidad aprende patrones normales —estacionalidad, tendencia— y alerta ante desviaciones") es una **descripción conceptual razonable y consistente** con cómo al menos un vendor serio documenta su propia mecánica (ensamble de modelos + ventana móvil de reentrenamiento + ajuste de sensibilidad en vez de umbral fijo manual). No se encontró un paper académico neutral que documente esta mecánica específica aplicada a series de tiempo de métricas de datos (freshness/volumen/distribución) — la búsqueda no arrojó ese tipo de fuente dentro del alcance de este research. **Recomendación**: el skill puede describir el concepto (aprendizaje de patrón normal vs. umbral fijo) con confianza, pero no debe sobre-especificar "el cómo" citando un algoritmo concreto (ej. "usa Prophet" o "usa un modelo ARIMA") como si fuera un hecho verificado — la doc de Monte Carlo describe la mecánica a alto nivel ("ensemble de modelos"), no el algoritmo exacto por debajo.

---

## Resumen de veredictos para contenido futuro del skill

| # | Claim del draft | Veredicto |
|---|---|---|
| 1 | "5 pilares" = Freshness, Volume, Distribution, Schema, Lineage, marco de Monte Carlo | **Confirmado, términos exactos correctos. Es vendor/marketing — decirlo explícitamente, y ya lo hace el draft.** |
| 2 | Lineage — falta una base neutral | **OpenLineage (openlineage.io, gobernado por LF AI & Data) es esa base neutral real — recomendado añadirlo al skill.** |
| 3 | dbt genera un grafo de lineage real | **Confirmado — DAG desde `ref()`/`source()`, visible en `dbt docs` (Core, local) y en Catalog (dbt Cloud). Complementa, no contradice, lo ya dicho sobre Dagster en `orchestrator-selection-and-topology.md`.** |
| 4 | MTTD/MTTR nacen en SRE/operaciones de TI, no en datos | **Confirmado contra Google SRE Book/Workbook. Aplicación formal a "calidad de datos" solo encontrada en fuentes de vendor — decirlo explícitamente. Matiz adicional: el propio Google (fuente neutral) cuestiona la validez estadística de MTTR para trend analysis.** |
| 5 | Detección de anomalías aprende patrones (vs. umbral fijo) | **Consistente con documentación técnica real de un vendor (Monte Carlo). Describir el concepto con confianza; no sobre-especificar el algoritmo exacto — no verificado a ese nivel de detalle.** |

**Nota de honestidad epistémica general**: las secciones marcadas como "corroboración de búsqueda" (el origen militar/industrial de MTTR en §4, y el detalle del wrapper `dbt-ol` en §2) no pasaron por fetch directo de su fuente primaria — quedan explícitamente diferenciadas de las citas que sí se verificaron por fetch directo contra la página fuente.
