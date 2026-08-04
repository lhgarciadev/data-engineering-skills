# Research: modelado moderno/lakehouse — cálculo de costos columnar, medallion architecture (Databricks), dbt modeling-as-code, y la trampa de One Big Table (OBT)

**Fecha:** 2026-08-04
**Alcance:** verificación de 5 bloques de claims para el reference file `modern-lakehouse-modeling.md` (Capa 5 del borrador) del futuro skill `modeling-data-engineering` (7ma skill de dominio de la suite): (1) si el storage/cómputo columnar barato cambió el cálculo de costos de la desnormalización frente a los supuestos originales de Kimball, sin alterar el vocabulario conceptual (grano, hechos, dimensiones, SCD); (2) definiciones textuales de Databricks para bronze/silver/gold, para confirmar que "gold" es la casa del modelado dimensional; (3) si dbt tests + control de versiones + CI/CD convierten el modelado dimensional en un artefacto testeable/versionado, verificado contra la filosofía propia de dbt Labs ("dbt Viewpoint"); (4) el patrón One Big Table (OBT) como patrón reconocido y sus 4 tradeoffs específicos (rápido para patrón fijo, feature table de ML/extracto de BI, costoso de actualizar por SCD, explosión de storage); (5) si el encuadre "star schema para flexibilidad, OBT para patrón fijo — decisión deliberada, no default perezoso" es defendible y no es un strawman. Fuentes: `kimballgroup.com` (fetch directo), `docs.databricks.com` (fetch directo), `docs.getdbt.com` (fetch directo), el benchmark oficial de Fivetran (fetch directo), un artículo semi-oficial de Databricks (Solutions Architects, publicado en el medium de su propio equipo), Brooklyn Data Co. (consultora reconocida en la comunidad dbt/analytics engineering) y varios blogs de práctica reconocidos en el espacio de data engineering — estos últimos marcados explícitamente como síntesis de industria, no como autoridad institucional.

**Guardrail ya establecido, confirmado antes de empezar**: se leyó directamente [`skills/pipelines-architecture-data-engineering/references/dbt-project-architecture.md`](../../../skills/pipelines-architecture-data-engineering/references/dbt-project-architecture.md), líneas 22-30. Cita textual: *"'Medallion' (bronze/silver/gold) is not dbt's vocabulary. It's a Databricks/lakehouse term some teams map onto dbt's three layers by analogy — reasonable, but don't present it as dbt's own terminology or cite it as if dbt Labs uses it; their published guidance uses staging/intermediate/marts exclusively."* Este research respeta ese guardrail: la sección 2 (medallion) se verifica **solo** contra Databricks, nunca contra dbt; la sección 3 (dbt modeling-as-code) usa exclusivamente staging/intermediate/marts como vocabulario de dbt, y medallion no se menciona ahí en absoluto.

---

## 1. Storage/cómputo columnar barato y el cálculo de costos de la desnormalización

**VEREDICTO: no existe una fuente única y afilada — ni siquiera del propio Kimball Group — que diga explícitamente "el storage columnar barato cambió el cálculo de costos de la desnormalización, no el concepto". Es consenso razonable de industria, apoyado por mecánica técnica bien documentada (compresión columnar), pero la conexión explícita con los supuestos originales de Kimball es síntesis, no cita directa. Hay que decirlo así en el skill.**

### 1.1 Kimball Group — el design tip más cercano no hace la conexión explícita

Se fetcheó directamente [Design Tip #175 "There is No Database Magic"](https://www.kimballgroup.com/2015/06/design-tip-175-there-is-no-database-magic/) (Kimball Group, 2015) buscando específicamente si aborda el cambio de cálculo de costos:

> "These technologies offer substantial scalability and query performance improvements for analytic workloads compared to the standard RDBMSs." / "What they do not offer is magic. There is no magic!"

Este design tip habla de la elección de tecnología de base de datos (columnar, MPP, in-memory) para alojar el modelo dimensional, pero **no dice explícitamente** que estas tecnologías cambiaron el cálculo de costos que originalmente justificaba la desnormalización de Kimball (storage caro, joins costosos). El argumento de "there is no magic" es casi lo opuesto en espíritu: insiste en que la tecnología subyacente no exime del buen diseño dimensional — compatible con, pero no idéntico a, el claim del borrador.

No se encontró en `kimballgroup.com` ningún artículo, design tip o whitepaper que declare explícitamente el argumento "storage columnar barato → desnormalización más viable que cuando Kimball escribió sus principios originales". Se buscó específicamente con múltiples queries (columnar, in-memory, big data, aggregate tables, "no need to denormalize") sin encontrar ese enunciado preciso en una fuente de kimballgroup.com.

### 1.2 Voz de práctica reconocida — confirma el espíritu del claim, no es Kimball Group mismo

[Uli Bethke (Sonra), "Dimensional Modeling and Kimball Data Marts in the Age of Big Data and Hadoop"](https://sonra.io/dimensional-modeling-and-kimball-data-marts-in-the-age-of-big-data-and-hadoop/) — consultor de arquitectura de datos con trayectoria desde 2001, blog de una consultora de data engineering (no un estándar ni una publicación de Kimball Group):

> "With the advent of columnar storage formats for data analytics this is less of a concern nowadays."

> Conclusión del artículo: "We have to adapt them for new technologies and storage types but they still add value" — refiriéndose a los conceptos de Kimball (grano, hechos, dimensiones, SCD).

Esto confirma el **espíritu** exacto del claim del borrador — el vocabulario conceptual de Kimball sigue vigente, lo que cambia es la economía de almacenamiento/cómputo — pero es la síntesis de un practicante, no una declaración institucional de Kimball Group ni un análisis de un analista de mercado (Gartner/Forrester) citable.

### 1.3 El mecanismo técnico sí está bien documentado en una fuente de referencia — pero no conecta con Kimball

Martin Kleppmann, *Designing Data-Intensive Applications* (O'Reilly, ampliamente reconocido como referencia técnica en la industria), capítulo 3 ("Storage and Retrieval"), tiene secciones dedicadas a "Column-Oriented Storage" y "Column Compression" que explican el mecanismo técnico por el cual el storage columnar comprime datos repetidos de forma mucho más eficiente que un row-store — la base técnica real de por qué la desnormalización (que multiplica atributos de dimensión repetidos por fila de hecho) resulta hoy menos costosa en storage de lo que habría sido con las bases de datos relacionales de fila que existían cuando Kimball escribió sus principios originales en los años 90. Esta fuente confirma el **mecanismo**, no la conclusión específica sobre Kimball — el libro no discute a Kimball ni el modelado dimensional en este contexto.

### 1.4 Conclusión honesta para el skill

Este es exactamente el caso que el pedido de investigación anticipó como posible: **"reasonable industry consensus, no single sharp citation"**. Los tres elementos —(a) Kimball Group reconoce que la tecnología de base de datos ha cambiado sustancialmente sin ceder en el diseño dimensional, (b) voces de práctica reconocida afirman explícitamente que los conceptos de Kimball se adaptan pero no se abandonan, (c) el mecanismo técnico de compresión columnar está bien documentado en una referencia técnica seria— se combinan de forma coherente y no contradictoria, pero **ninguna fuente única hace el argumento completo de punta a punta**. El skill debe presentar esto como síntesis razonada, citando Kleppmann para el mecanismo técnico y a Bethke/Kimball Design Tip #175 como corroboración de espíritu — no como si existiera un artículo de Kimball Group que dijera literalmente la frase del borrador.

---

## 2. Medallion architecture (Databricks) — gold como casa del modelado dimensional

**VEREDICTO: confirmado directamente y de forma textual contra la documentación oficial de Databricks. La afirmación "gold = modelado dimensional" no es una inferencia — Databricks lo dice explícitamente con esas palabras.**

Fuente: [docs.databricks.com/aws/en/lakehouse/medallion](https://docs.databricks.com/aws/en/lakehouse/medallion) (fetch directo, documentación oficial).

| Capa | Cita textual de Databricks |
|---|---|
| Bronze | "The bronze layer contains raw, unvalidated data." / "Contains and maintains the raw state of the data source in its original formats." / "Minimal data validation is performed in the bronze layer." |
| Silver | "The silver layer represents validated, cleaned, and enriched versions of the data." |
| Gold | "The gold layer represents highly refined views of the data that drive downstream analytics, dashboards, ML, and applications." / **"The gold layer is where you'll model your data for reporting and analytics using a dimensional model by establishing relationships and defining measures."** / "The gold layer consists of aggregated data tailored for analytics and reporting." |

La cita en negrita es la que resuelve el claim: Databricks dice, con esas palabras, que el modelado dimensional ocurre en gold ("model your data... using a dimensional model"), y que gold es agregado/orientado a negocio ("aggregated data tailored for analytics and reporting"). Esto confirma exactamente y sin necesidad de inferencia lo que el reference file necesita afirmar: **Kimball (facts/dims/star schema) vive en la capa gold; bronze y silver son lo que la alimenta.**

Nota de alcance: por instrucción explícita del pedido, este research no reexplica bronze/silver en profundidad (ya cubierto para el ángulo dbt en `dbt-project-architecture.md`, y para el ángulo "raw permisivo → validación estricta" en el research previo `2026-08-03-quality-dimensions-and-validation-verification.md` §4.3) — solo se confirma el punto puntual de que gold es la casa del modelo dimensional, que es el único aporte nuevo que necesita este reference file.

---

## 3. dbt modeling-as-code — tests + control de versiones + CI/CD como artefacto testeable/versionado

**VEREDICTO: la mecánica de staging→intermediate→marts y los 4 tests genéricos ya están verificados en research previo y no se reabren aquí (por instrucción explícita). El claim nuevo — que esta combinación convierte el modelado dimensional en un artefacto testeable/versionado en vez de una decisión de diseño de una sola vez — es una extensión justa y defendible de la filosofía que dbt Labs declara textualmente sobre sí misma, aunque dbt Labs no usa las palabras "modelado dimensional" en su declaración de filosofía general.**

Fuente: ["The dbt Viewpoint"](https://docs.getdbt.com/community/resources/viewpoint) (fetch directo, docs.getdbt.com) — descrito por dbt Labs como *"the most foundational statement of the dbt project's goals"*.

Citas textuales relevantes:

> "Analytic code — whether it's Python, SQL, Java, or anything else — should be version controlled. Analysis changes as data and businesses evolve, and it's important to know who changed what, when."

> "Bad data can lead to bad analyses, and bad analyses can lead to bad decisions. Any code that generates data or analysis should be reviewed and tested."

> "The same techniques that software engineering teams use to collaborate on the rapid creation of quality applications can apply to analytics. We believe it's time to build an open set of tools and processes to make that happen."

> Sobre por qué el código analítico necesita este tratamiento: "Most of the cost involved in software development is in the maintenance phase. Because of this, software engineers write code with an eye towards maintainability. Analytic code, however, is often fragile."

**Por qué la extensión es defendible**: el "dbt Viewpoint" habla de "analytic code" en general — no distingue entre un modelo de staging, uno de marts, o específicamente un star schema. Pero esto no es una laguna: en dbt, un modelo de marts que implementa una tabla de hechos o dimensión **es** código analítico como cualquier otro — mismo mecanismo de `ref()`, mismos generic tests (`unique`, `not_null`, `relationships`, ya confirmados contra `docs.getdbt.com` en el research previo `2026-08-03-quality-dimensions-and-validation-verification.md` §2.1), mismo control de versiones, mismo pipeline de CI/CD. No hay ninguna afirmación de dbt Labs que trate el modelado dimensional como un caso especial exento de este tratamiento — al contrario, el propio ["How we structure our dbt projects"](https://docs.getdbt.com) (ya citado en `dbt-project-architecture.md`) presenta `marts/` (la capa donde vive el star schema en un proyecto dbt) como una capa más del mismo DAG testeado y versionado. Por tanto: **la conclusión del claim (dimensional modeling se vuelve testeable/versionado, no una decisión de una sola vez) es una aplicación fiel y sin distorsión de la filosofía general que dbt Labs declara textualmente sobre todo su código analítico** — no es una cita literal de dbt Labs usando esas palabras exactas, pero tampoco es una extrapolación forzada.

---

## 4. One Big Table (OBT) — patrón reconocido y sus 4 tradeoffs específicos

**VEREDICTO: OBT es un patrón real, nombrado y discutido por fuentes creíbles — incluyendo una fuente semi-oficial de Databricks y un benchmark cuantitativo de Fivetran. De los 4 tradeoffs pedidos, dos están fuertemente confirmados con datos concretos ((a) velocidad/patrón fijo, (d) explosión de storage — este último con números duros), y dos son consenso de práctica sólido pero sin una única fuente institucional que los cuantifique ((b) feature table de ML/extracto de BI, (c) costo de actualización tipo SCD). Ningún sub-claim resultó infundado, pero hay que ser honesto sobre cuáles son "confirmado con datos" vs. "consenso de práctica razonable".**

### 4.1 Que OBT es un patrón reconocido y nombrado — confirmado, con pluralidad de fuentes de distinto peso

- **Fivetran** (proveedor real de EL, benchmark propio), ["Star Schema vs. OBT for Data Warehouse Performance"](https://www.fivetran.com/blog/star-schema-vs-obt), autor Michael Kaminsky (Data Scientist en Fivetran) — benchmark cuantitativo real, no solo argumento.
- **Databricks** (semi-oficial): ["One Big Table vs. Dimensional Modeling on Databricks SQL"](https://medium.com/dbsql-sme-engineering/one-big-table-vs-dimensional-modeling-on-databricks-sql-755fc3ef5dfd), autoras Sepideh Jahangiri y Philip Laserstein, ambas Solutions Architects en Databricks, publicado en la publicación de Medium del propio equipo de ingeniería DBSQL de Databricks — no es `docs.databricks.com`, pero sí contenido de empleados de Databricks hablando en nombre de su rol técnico, con mayor peso que un blog externo.
- **Brooklyn Data Co.** (consultora real, partner reconocido de Snowflake/dbt/Fivetran), ["Our Hybrid Kimball & OBT Data Modeling Approach"](https://www.brooklyndata.co/ideas/2025/01/08/our-hybrid-kimball-and-obt-data-modeling-approach).
- Blogs de práctica reconocidos en el espacio de data engineering (marcados aquí explícitamente como tal, no como autoridad institucional): Simon Späti ([ssp.sh](https://www.ssp.sh/brain/one-big-table/), autor de un libro sobre patrones de data engineering), [ml4devs.com](https://www.ml4devs.com/what-is/one-big-table/), [dedp.online](https://www.dedp.online/part-2/4-ce/mv-obt-dbt-table-traditional-olap-dwa.html) ("Patterns of Data Engineering"), y Zach Wilson ([blog.dataexpert.io](https://blog.dataexpert.io/p/how-to-data-model-correctly-kimball), practicante reconocido con trayectoria en Airbnb/Facebook/Netflix, fundador de DataExpert.io).

OBT como término está claramente asentado en la industria — no es un neologismo inventado para el skill.

### 4.2 Los 4 sub-claims específicos, verificados uno por uno

| # | Sub-claim | Veredicto | Cita/evidencia |
|---|---|---|---|
| (a) | Simple/rápido para un patrón de consulta **conocido y fijo** | **Confirmado con fuente semi-oficial + práctica** | Databricks (semi-oficial): *"OBT works well for use cases where you only need to filter the table on 1–3 dimensions, and the rest of your analytics / apps are built on those filters."* dataarchitect.studio (blog de práctica, autoría no revelada): *"One Big Table is a fast answer to questions you already know."* |
| (b) | Usado comúnmente como **feature table de ML o extracto de BI** | **Consenso de práctica, no cita institucional dura** | ml4devs/ssp.sh (vía extracción, ambos blogs de práctica): *"the OBT model is the backbone of a Machine Learning (ML) Feature Store... feature vectors for ML models are inherently wide and denormalized"*; ssp.sh cita a un tercero (Jonathan Neo): *"I reserve OBT for tools that require a flat dataset (e.g. a CSV export, or a BI tool that does not support relationships)."* **Matiz importante**: se verificó la documentación oficial de Databricks Feature Store (`docs.databricks.com/aws/en/machine-learning/feature-store/concepts`) y **no** recomienda una única tabla ancha desnormalizada — describe múltiples feature tables unidas en tiempo de entrenamiento vía `FeatureLookup`. La equivalencia "feature table de ML = OBT" es una simplificación de práctica común (el vector de features final que ve el modelo sí es ancho/desnormalizado por naturaleza), no una afirmación de la plataforma de ML de Databricks sobre su propio feature store. El skill debe presentar esto como patrón de práctica extendido, no como cita de un estándar de ML. |
| (c) | Costoso de actualizar — cambio de atributo de dimensión obliga a reescribir muchas filas (**SCD se vuelve caro**) | **Consenso de práctica sólido y consistente entre fuentes independientes, sin cita institucional dura** | ssp.sh/ml4devs/dedp.online (extracción convergente entre 3 fuentes independientes): *"Changing dimensions (renaming of product, relocation of a customer) needs an update to many rows"* / *"Adding new dimensional attributes requires backfilling."* dataarchitect.studio: *"Handling slowly changing dimensions in a flattened table is clumsy — you lose the clean versioning that a separate dimension with validity dates gives you almost for free."* Ninguna fuente institucional (Databricks, Fivetran) cuantifica esto explícitamente, pero la convergencia entre múltiples blogs de práctica independientes, más el hecho lógico de que un atributo repetido en cada fila debe reescribirse en cada fila cuando cambia, hacen de este un claim sólido aunque sin una única fuente afilada. |
| (d) | **Explota en storage** por atributos de dimensión redundantes repetidos por fila de hecho | **Confirmado con datos duros** | Benchmark de Fivetran (fetch directo, cifras exactas del propio experimento): tabla de hechos normalizada `store_sales` = 29,778 MB; `one_big_table` desnormalizada = 60,250 MB — más del doble de storage para el mismo contenido informacional. Corroborado cualitativamente por Databricks (semi-oficial): *"if you need to prune files by more than one to two dimensions for ALL attributes you need in the table, OBT can quickly become inefficient"* y por Brooklyn Data: *"higher chance of data redundancy across different OBTs"*, con "cost implications" a medida que las OBT crecen. Este es el sub-claim mejor sustentado de los 4 — tiene números concretos de un benchmark real, no solo argumento. |

### 4.3 Honestidad epistémica sobre el bloque 4

Ningún sub-claim resultó infundado o falso. Pero hay una jerarquía clara de solidez que el skill debería reflejar: **(d) es el más fuerte (benchmark cuantitativo)**, **(a) tiene respaldo semi-oficial de Databricks**, y **(b) y (c) son consenso de práctica consistente entre múltiples fuentes independientes de blogs reconocidos, pero sin una fuente institucional que los cuantifique o los declare de forma oficial**. Ninguna fuente de Kimball Group aborda OBT directamente — es terminología post-2015 asociada al cloud/columnar, y Kimball Group no publicó nada al respecto en las búsquedas realizadas.

---

## 5. El encuadre "star schema para flexibilidad, OBT para patrón fijo — decisión deliberada, no default perezoso"

**VEREDICTO: encuadre defendible y no es un strawman. Múltiples fuentes independientes —incluida una semi-oficial de Databricks y una consultora real (Brooklyn Data)— describen la elección exactamente en estos términos: contextual, no jerárquica, sin presentar a ninguno de los dos patrones como estrictamente superior.**

- **dataarchitect.studio** (blog de práctica) hace la comparación más nítida encontrada: *"One Big Table is a fast answer to questions you already know."* frente a *"A star schema is a flexible foundation that answers questions you haven't thought of yet."* — exactamente el encuadre del borrador, sin exagerar las desventajas de ninguno de los dos lados.
- **Databricks** (semi-oficial) rehúsa explícitamente declarar un ganador: *"The decision between Dimensional Modeling and the One Big Table approaches requires a nuanced understanding"* — refuerza que la elección es contextual, no dogmática.
- **Brooklyn Data Co.** (consultora real) implementa este encuadre en producción, no solo lo argumenta: usan Kimball "before the reporting layer" para mantener flexibilidad aguas arriba, y OBT "as a reporting layer" aguas abajo para consumo específico — un caso real de "decisión deliberada para un patrón de acceso concreto", no un default.
- **Zach Wilson** (practicante reconocido, DataExpert.io) también enmarca la elección como dependiente de contexto (volumen de datos) en vez de una preferencia absoluta: *"If your data volume is small, Kimball will still be the better way."*

Ninguna de las fuentes revisadas exagera las desventajas de OBT (no lo tratan como un anti-patrón universal — de hecho Brooklyn Data identifica el anti-patrón real como el "OBT universal" que mezcla procesos de negocio distintos en una sola tabla, no OBT en sí) ni sobrevende los beneficios del star schema (nadie lo presenta como "siempre mejor"; se reconoce el costo de joins como la razón real de que OBT exista). El encuadre del borrador es, por tanto, una síntesis fiel de cómo la industria de práctica seria (no solo teoría) trata esta decisión — no un strawman contra OBT ni una idealización del star schema.

---

## Resumen de acciones para el contenido del skill

1. **Sección 1 (cálculo de costos columnar)**: presentar como síntesis razonada, no como cita única. Usar Kleppmann (DDIA) para el mecanismo técnico de compresión columnar, y el Design Tip #175 de Kimball Group + el artículo de Bethke/Sonra como corroboración de espíritu — siendo explícito en que ninguna fuente institucional hace el argumento completo con las palabras exactas del borrador.
2. **Sección 2 (medallion/gold)**: usar la cita textual de Databricks sin parafrasear de más — *"model your data... using a dimensional model"* en gold es una confirmación directa y fuerte, se puede citar con confianza. No reexplicar bronze/silver en profundidad (ya cubierto en otras referencias del suite).
3. **Sección 3 (dbt modeling-as-code)**: usar las citas del "dbt Viewpoint" tal como están arriba, siendo explícito en que dbt Labs no usa la frase "modelado dimensional" en su declaración de filosofía, pero que la extensión es fiel porque marts (donde vive el star schema en un proyecto dbt) recibe exactamente el mismo tratamiento de testing/versionado/CI-CD que cualquier otro modelo.
4. **Sección 4 (OBT)**: usar el benchmark de Fivetran (con las cifras exactas 29.778 MB → 60.250 MB) como la evidencia más fuerte para la explosión de storage. Usar el artículo semi-oficial de Databricks para el ángulo "patrón fijo/conocido". Marcar explícitamente el costo tipo-SCD y el uso como feature table de ML como consenso de práctica bien sustentado por convergencia entre fuentes independientes, pero sin pretender que hay una cita institucional única y afilada para esos dos ángulos — y aclarar que la documentación oficial de Databricks Feature Store en realidad recomienda múltiples feature tables unidas en el momento del entrenamiento, no necesariamente una única OBT.
5. **Sección 5 (encuadre deliberado vs. default perezoso)**: se puede usar con confianza — está corroborado por una fuente semi-oficial de Databricks, una consultora real con un caso de uso en producción, y un practicante reconocido, y ninguna fuente revisada lo contradice o lo presenta como strawman en ninguna dirección.
6. **Guardrail medallion-vs-dbt**: respetado en todo el documento — la sección 2 no menciona dbt en absoluto, y la sección 3 no menciona medallion en absoluto. Si el reference file final necesita puentear ambos conceptos, debe hacerlo con un cross-link explícito a `dbt-project-architecture.md` (líneas 22-30), nunca fusionando el vocabulario.

**Nota de honestidad epistémica general**: de los 5 bloques, el 2 (medallion/gold) es el más sólido — cita textual directa e inequívoca de la fuente primaria exacta que se pidió verificar. El 4(d) (explosión de storage) es el segundo más sólido — tiene números duros de un benchmark real. Los bloques 1, 3, y los sub-claims 4(b)/4(c) son honestos casos de "consenso de práctica razonable, sin una única fuente institucional afilada" — el pedido de investigación anticipó exactamente este resultado como posible y pidió decirlo con honestidad si ocurría; así se hace aquí.
