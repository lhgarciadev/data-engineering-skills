# Research: posicionamiento Inmon vs. Kimball vs. Data Vault para el futuro skill `modeling-data-engineering`

**Fecha:** 2026-08-04
**Alcance:** verificación de 5 bloques de claims sobre el **posicionamiento** (no la mecánica interna) de las tres metodologías de arquitectura de data warehouse que alimentarán `modeling-methodologies.md` (Capa 4 del borrador, ver `docs/superpowers/specs/2026-08-04-modeling-skill-design.md` §1): (1) si "top-down, EDW normalizado en 3NF primero, luego data marts" es una caracterización fiel de la metodología de **Inmon en sus propias palabras** (no filtrada por autores del campo Kimball); (2) si "bottom-up, data marts dimensionales primero, unidos por dimensiones conformadas (el bus)" es una caracterización fiel de **Kimball en sus propias palabras**, incluyendo el trade-off que el propio Kimball reconoce; (3) si el posicionamiento de alto nivel de Data Vault (auditabilidad, agilidad, muchas fuentes cambiantes, hubs/links/satellites, insert-only, carga paralela, absorción de cambios de esquema sin rediseño) coincide con el propio encuadre de Linstedt en su libro; (4) si el propio libro de Linstedt confirma que Data Vault típicamente **alimenta** marts dimensionales estilo Kimball para consumo, en vez de ser en sí mismo capa de consumo; (5) si el criterio de decisión "depende de número/volatilidad de fuentes, auditoría/regulación, velocidad, madurez del equipo — no de dogma" es una síntesis defendible.

**Fuentes primarias usadas:**
- Bill Inmon, artículo propio ["A Tale of Two Architectures — Kimball vs Inmon"](https://williaminmon.substack.com/p/a-tale-of-two-architectures-kimball), en su substack personal `williaminmon.substack.com` (confirmado como su publicación personal — bylines "by William Inmon", ver [About](https://williaminmon.substack.com/about) y su [Wikipedia](https://en.wikipedia.org/wiki/Bill_Inmon)). Fetch directo, citas verificadas en dos pasadas independientes con las mismas frases exactas.
- Kimball Group, tres páginas propias de `kimballgroup.com` (fetch directo): ["Enterprise Data Warehouse Bus Architecture"](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/kimball-data-warehouse-bus-architecture/), ["Conformed Dimension"](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/conformed-dimension/), y el artículo original ["The Matrix" (1999)](https://www.kimballgroup.com/1999/12/the-matrix/).
- `docs/superpowers/books/building_a_scalable_data_warehouse_with_data_vault.md` (Linstedt & Olschimke, *Building a Scalable Data Warehouse with Data Vault 2.0*) — leído directamente (no vía research de terceros) en: Foreword (escrito por **Bill Inmon**, no por Linstedt), §1.2 ("The Enterprise Data Warehouse Environment"), §1.3 ("Introduction to Data Vault 2.0"), §1.4.1/§1.4.2 (arquitecturas de dos y tres capas), Capítulo 2 completo ("Scalable Data Warehouse Architecture"), §4.1/4.2 (vocabulario de hubs/links/satellites), §4.5.2 (carga paralela), Capítulo 7 (introducción, "Dimensional Modeling"), Capítulo 14 (introducción, "Loading the Dimensional Information Mart").
- Fuentes secundarias (blogs, arXiv preprints) usadas **solo** para el punto 5, marcadas explícitamente como tal, nunca como respaldo de un claim técnico duro.

---

## 1. Inmon — top-down, EDW normalizado en 3NF primero, luego data marts dimensionales derivados

**VEREDICTO: la caracterización del borrador es fiel a las propias palabras de Inmon, confirmada con cita textual directa de su propio artículo (no de un intermediario del campo Kimball) y corroborada de forma independiente por el libro de Linstedt/Olschimke (que no es un autor "del bando Kimball"). Con un matiz importante que el propio Inmon añade: él mismo reconoce que el enfoque de Kimball, en sus etapas posteriores, termina convergiendo hacia la misma arquitectura integrada — la diferencia central no es el destino final, sino el orden y la velocidad para llegar a él.**

### 1.1. La definición propia de Inmon y el "single version of the truth"

De su propio artículo (`williaminmon.substack.com`, cita verificada en dos fetches independientes con el mismo texto exacto):

> "With the corporate information factory, there was a definitive source of data to which the corporation could turn – the 'single version of the truth'."

> "Data that comes from applications must be recast into a corporate form and structure. That is how the 'single version of the truth' is created."

Esto confirma el núcleo del claim: el objetivo explícito y propio de Inmon es una fuente única e integrada, construida **antes** de que los datos lleguen a los marts departamentales — exactamente lo que el borrador describe como "EDW normalizado como fuente única de verdad para toda la empresa".

### 1.2. El trade-off en palabras del propio Inmon: integración a cambio de velocidad

> "As such, building a data warehouse for the corporate information factory is not an easy or a fast thing to do. But the result is integrated data"

Esta es la cita más importante del bloque 1: **el propio Inmon admite por escrito que su enfoque es lento y difícil, y presenta la integración de los datos como la contrapartida que justifica ese costo** — coincide exactamente con lo que el borrador pide verificar ("integración/consistencia primero, a costa de tiempo-de-valor más lento").

### 1.3. Corroboración independiente: el libro de Linstedt/Olschimke describe la arquitectura de Inmon en los mismos términos, sin ser un autor Kimball

El Capítulo 1, §1.4.2 ("Typical Three-Layer Architecture") de `building_a_scalable_data_warehouse_with_data_vault.md` (líneas 940-963), bajo la figura titulada explícitamente **"The Inmon Data Warehouse"**, describe:

> "This architecture has been introduced by Inmon and introduces an atomic data warehouse, often a normalized operational data store (ODS) between the staging area and the dimensional model. [...] The data warehouse, however, holds raw data modeled in a third-normal form. It integrates all data of the enterprise, but is still based on physical tables from the source systems. [...] On top of the normalized view of the business data, there is a dimensional model. Business users can access and analyze the data using subject-oriented data marts [...] it is much easier to create new data marts from the data available in the operational data store because the data is already cleaned and integrated."

Esto es una fuente independiente (Linstedt no es del "bando Kimball" — de hecho, Inmon escribió el Foreword del mismo libro) que confirma, con las mismas palabras que el borrador usa, la secuencia top-down: **3NF/ODS primero → data marts dimensionales derivados después**, precisamente porque los datos ya están limpios e integrados en el EDW.

### 1.4. El matiz que el borrador NO debe perder: el propio Inmon dice que Kimball converge hacia lo mismo

Verificado explícitamente (no es una caricatura al revés): el mismo artículo de Inmon reconoce que el "Kimball Stage 1" (marts simples) evoluciona con el tiempo hacia dimensiones conformadas ("Stage 2"), luego hacia MDM ("Stage 3") y finalmente hacia una arquitectura hub-and-spoke ("Stage 4") que, en palabras textuales de Inmon:

> "Compare the predicted Kimball Stage 4 hub and spoke architecture with the corporate information factory architecture that was published by Inmon a decade earlier and it is seen that they in fact are the same."

Y sobre la pérdida de la ventaja de velocidad en esa evolución:

> "in the predicted Kimball Stage 4 with the need for true enterprise development and the creation of the 'golden record', building the Kimball Stage 4 environment is no longer speedy."

**Esto no invalida el claim 1** — la caracterización "Inmon = top-down, 3NF EDW primero" sigue siendo exacta para lo que Inmon mismo llama su propia arquitectura. Pero es honesto que el skill mencione que el propio Inmon no ve la disyuntiva como permanente: para él, cualquier arquitectura Kimball que madure lo suficiente termina pareciéndose a la suya. Es un dato con autoridad (viene del propio Inmon) que enriquece el claim 5 (ver más abajo) sin contradecir el claim 1.

---

## 2. Kimball — bottom-up, data marts dimensionales conectados por dimensiones conformadas (el "bus")

**VEREDICTO: caracterización confirmada de forma directa contra tres páginas propias de kimballgroup.com. El trade-off (riesgo de inconsistencia si las dimensiones conformadas no se gobiernan) también está confirmado con cita textual, incluyendo el término propio de Kimball para ese riesgo: "stovepipe data marts".**

### 2.1. Bottom-up + bus architecture, en palabras de Kimball Group

De la página oficial ["Enterprise Data Warehouse Bus Architecture"](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/kimball-data-warehouse-bus-architecture/):

> "The technology- and database-independent bus architecture allows for incremental data warehouse and business intelligence (DW/BI) development."

> "It's the architectural blueprint providing the top-down strategic perspective to ensure data in the DW/BI environment can be integrated across the enterprise, while agile bottom-up delivery occurs by focusing on a single business process at a time."

Esta última cita es clave: el propio Kimball Group describe su método como **entrega incremental por proceso de negocio** ("bottom-up delivery... focusing on a single business process at a time"), exactamente como caracteriza el borrador — sin que esto sea una síntesis de un tercero.

### 2.2. Dimensiones conformadas, definición propia

De la página oficial ["Conformed Dimension"](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/conformed-dimension/):

> "Dimension tables conform when attributes in separate dimension tables have the same column names and domain contents."

> "Conformed dimensions, defined once in collaboration with the business's data governance representatives, are reused across fact tables."

### 2.3. El trade-off propio de Kimball: sin gobierno de las dimensiones conformadas, aparecen los "stovepipes"

Del artículo original de Kimball ["The Matrix" (1999, kimballgroup.com)](https://www.kimballgroup.com/1999/12/the-matrix/):

> "Conformed dimensions are the basis for distributed data warehouses, and using conformed dimensions is the way to avoid stovepipe data marts."

> "An obvious source of stovepipe data marts is the reckless use of incompatible weeks and months across the data marts."

Esta es la confirmación exacta del segundo trade-off pedido: **el propio Kimball nombra el riesgo** (data marts "stovepipe" — silos con definiciones incompatibles de las mismas dimensiones) como la consecuencia directa de construir marts bottom-up sin gobernar la conformidad de las dimensiones. El borrador no lo dice como una crítica ajena — es el propio vocabulario de Kimball ("stovepipe") para el fracaso de su propio método si no se gobierna.

---

## 3. Data Vault (Linstedt) — auditabilidad, agilidad, muchas fuentes cambiantes, hubs/links/satellites, insert-only, carga paralela, absorción de cambios sin rediseño

**VEREDICTO: el posicionamiento de alto nivel del borrador coincide, punto por punto, con el propio encuadre de Linstedt (y del Foreword escrito por Inmon) en los capítulos pedidos. Único matiz de honestidad: el término literal "insert-only"/"append-only" no aparece como frase textual en este libro (0 coincidencias al buscarlo) — pero el mecanismo que describe (satélites que solo agregan filas nuevas, nunca actualizan) sí está documentado de forma explícita y repetida, así que la sustancia del claim es correcta aunque la frase exacta no sea una cita del libro.**

### 3.1. Por qué existe Data Vault: auditabilidad y compliance, en las propias palabras del Foreword (escrito por Bill Inmon)

El Foreword del libro (líneas 197-230) — nótese que **quien lo escribe es Inmon, no Linstedt** — describe el origen de Data Vault así:

> "Daniel used the term common foundational modeling architecture to describe a model based on three simple entities, focusing on business keys, their relationships and descriptive information for both. [...] It allowed to source all kinds of data, regardless its structure, in a fully auditable manner. This was a core requirement of government agencies at the time. And due to Enron and a host of other corporate failures, Basel, and SOX compliance auditability was pushed to the forefront of the industry."

> "Not only that, the model was able to evolve on changing data structures. It was also easy to extend by adding more and more source systems."

Esto confirma, en las palabras de la persona detrás de la otra metodología comparada, exactamente los tres pilares del claim: auditabilidad/compliance, evolución ante cambios de estructura, y facilidad de extensión ante más fuentes.

### 3.2. En palabras de Linstedt mismo (§1.2.4, "Single Version of Facts")

> "The lead author of this book was one of the first people in the data warehousing industry to promote this idea, especially due to compliance issues. Eventually, it led to the invention of Data Vault and is a key principle in Data Vault 2.0 modeling and is implemented in the Raw Data Vault."

### 3.3. Hubs/links/satellites — definición textual exacta (§4.2, línea ~3954)

> "the hub separates the business keys from the rest of the model; the link stores relationships between business keys (and/or hubs); and satellites store the context (the attributes of a business key or relationship)."

Coincide exactamente con la formulación del borrador: hubs = claves de negocio, links = relaciones, satellites = atributos descriptivos + historia.

La misma sección (§4.2) enumera las características de negocio que el modelo busca soportar, incluyendo explícitamente **agilidad** y **auditabilidad**:

> "The ability to react to rapidly changing business requirements, also known as agility. [...] The need for transparency and accountability, at least to the auditor of the firm."

### 3.4. Absorción de cambios de esquema sin rediseño — demostrado con un ejemplo concreto, no solo afirmado

El Capítulo 2, §2.2.2 (líneas ~1330-1385) usa un ejemplo extenso (el cambio de formato del número de matrícula de aeronaves de EE.UU. en 1948) para mostrar qué pasa cuando cambia la estructura de la fuente. La conclusión textual:

> "But the real advantage of separating hard and soft rules becomes clear when thinking about the ETL jobs that need to be adapted to fit the new categorization: none. The ETL jobs that load the historic data remain unchanged [...] Nothing needs to be changed, except the information mart (and its loading routines)."

Esto es una demostración directa (no una afirmación de marketing) del claim "absorbe cambios de esquema de las fuentes sin rediseño": el mecanismo (cerrar el satellite viejo, abrir uno nuevo) hace que **cero** jobs de ETL existentes se modifiquen.

### 3.5. Carga paralela — confirmado textualmente (§4.5.2.1, línea ~4705)

> "It maximizes load parallelism because there is no competition (at the I/O or database level) for the target resource (the satellite). [...] It allows the designer to add new data sources without changing existing satellite entities."

### 3.6. Matiz de honestidad sobre "insert-only"

Se buscó explícitamente "insert-only" y "append-only" como frases literales en las 19.497 líneas del libro: **cero coincidencias**. Lo que sí está documentado repetidamente es la sustancia del claim: los satellites son "delta driven" (solo se inserta una fila nueva cuando hay un cambio, comparable a un Type II de dimensional modeling — línea ~4681), y para el caso del "record tracking satellite" el libro dice explícitamente "records are never updated [...] Instead of updating the records on each load cycle, a new entry is inserted every time" (línea ~5600). El comportamiento insert-only está descrito y demostrado con mecánica concreta; simplemente no es una etiqueta/slogan que el libro use con esas palabras exactas en los capítulos revisados. El skill puede seguir usando "insert-only"/"append-only" como caracterización correcta del mecanismo, pero no debería citarlo como frase textual de Linstedt.

---

## 4. Data Vault "rara vez es capa de consumo" — alimenta marts dimensionales estilo Kimball para consumo

**VEREDICTO: confirmado de forma directa y explícita por el propio libro de Linstedt, en las introducciones exactas de los Capítulos 7 y 14 que la tarea pidió revisar. Esta es la cita más contundente de todo el research: el propio creador de Data Vault dice, en el primer párrafo del capítulo dedicado a modelado dimensional, que el acceso directo a Data Vault está limitado a usuarios avanzados y que la mayoría de usuarios de negocio consume la información vía marts dimensionales.**

### 4.1. Capítulo 7 ("Dimensional Modeling"), introducción — cita directa

> "The best application for Data Vault 2.0 modeling is in the enterprise data warehouse layer. It has been specifically developed for this purpose and is the optimal choice when an extensible, functionally oriented model is required that allows history tracking and auditability [...] However, most business users are not familiar with Data Vault 2.0 modeling. In many cases, end-users need proper training first, in order to directly access the Raw Data Vault or the Business Vault [...] Therefore, direct access to the enterprise data warehouse layer is limited to power users [...] Most end-users will use an information mart to access prepared information that they can directly use for their job at hand."

> "Data Vault modeling is not a replacement for dimensional modeling, which is an industry standard for defining the data mart (the layer used to present the data to the end-user)."

> "[...] dimensional modeling [...] is the optimal choice for modeling the information marts, which serve as front-end layers."

### 4.2. Capítulo 14 ("Loading the Dimensional Information Mart"), introducción — confirma el flujo Data Vault → mart dimensional

> "Once the raw data has been loaded from the operational source systems into the Raw Data Vault, the next step is to process the raw data and load the results from this processing into the information marts. This chapter covers both steps."

> "The Business Vault serves as an intermediate between the Raw Data Vault and information marts."

**Esto confirma sin ambigüedad el claim 4**: la propia arquitectura de referencia del libro (ya vista también en el Capítulo 2, §2.2: staging → Data Vault (EDW layer) → information marts como star schemas) tiene a Data Vault en la capa de integración/auditoría, no en la capa de consumo — el consumo de negocio ocurre en marts dimensionales (star schemas, "the relational version of a dimensional model", Capítulo 7 §7.1) construidos **a partir de** Data Vault. El título mismo del Capítulo 14 ("Loading the Dimensional *Information Mart*" desde Data Vault) es, en sí, evidencia de que el propio Linstedt diseñó el libro asumiendo ese flujo.

---

## 5. "La elección depende de número/volatilidad de fuentes, auditoría/regulación, velocidad, madurez del equipo — no de dogma"

**VEREDICTO: síntesis razonable y defendible, consistente con lo que las tres fuentes primarias dicen sobre sí mismas — pero es una síntesis del autor del borrador, no una fórmula de decisión de 4 factores que ninguna de las tres fuentes primarias enuncie como tal en un único lugar. Cada factor individual sí tiene respaldo directo en al menos una fuente primaria; la combinación de los cuatro en un solo criterio es una construcción razonable, no una cita.**

### 5.1. Respaldo por factor, en las propias fuentes primarias ya citadas

- **Velocidad / madurez del equipo**: el propio Inmon admite que su enfoque "is not an easy or a fast thing to do" (§1.2), y que la ventaja de velocidad de Kimball se erosiona según el enfoque madura hacia integración total (§1.4, "no longer speedy"). El propio Kimball Group presenta su bus architecture explícitamente como la opción para "incremental development" y entrega "bottom-up... focusing on a single business process at a time" (§2.1) — es decir, velocidad es el argumento propio de Kimball, no una etiqueta externa.
- **Auditoría/regulación**: confirmado como motivación explícita y original de Data Vault tanto por Linstedt (§1.2.4, §4.2) como por el propio Inmon en el Foreword del libro de Linstedt (Basel, SOX, Enron — §3.1 de este research).
- **Número/volatilidad de fuentes**: confirmado por el ejemplo textual completo del Capítulo 2 (§2.2.2) sobre el cambio de formato de fuente sin rediseño de ETL, y por la cita de §4.5.2.1 sobre agregar fuentes nuevas sin cambiar satellites existentes.
- **Dogma vs. pragmatismo**: el propio Inmon, en su artículo más reciente, es quien explícitamente desdramatiza la disyuntiva al mostrar que las arquitecturas convergen con el tiempo — un dato que va en la misma dirección que "no es cuestión de dogma", viniendo de una de las dos partes históricamente más asociadas con la "guerra religiosa" Inmon-vs-Kimball.

### 5.2. Lo que no se pudo confirmar contra fuente primaria

No se encontró, en ninguna de las tres fuentes primarias, un pasaje único que enuncie los cuatro factores juntos como un framework de decisión formal. Búsquedas adicionales en fuentes secundarias (blogs de práctica, comparativas y un par de preprints de arXiv sobre Inmon/Kimball/Data Vault) muestran que la industria sí converge informalmente en factores muy similares (estabilidad del negocio y tiempo/costo disponible para Inmon, "quick win" para Kimball, número de fuentes/M&A/presión regulatoria para Data Vault) — pero estas son fuentes secundarias de calidad variable (posts de blog, no instituciones), citadas aquí **solo como corroboración de que la síntesis no es una invención aislada**, nunca como respaldo de un claim técnico duro. El skill debe presentar el punto 5 explícitamente como marco de decisión propio, razonado a partir de lo que cada metodología dice de sí misma — no como cita de una autoridad única.

---

## Resumen de acciones para el contenido del skill

1. **Inmon puede citarse con su propia voz**, no solo vía comparaciones de terceros: usar las citas de `williaminmon.substack.com` (single version of the truth / "not an easy or a fast thing to do, but the result is integrated data") como ancla del claim top-down/3NF-primero y de su trade-off.
2. **Añadir el matiz de convergencia** que el propio Inmon reconoce (Kimball Stage 4 ≈ CIF) como nota de profundidad senior — refuerza el mensaje "no es dogma" del punto 5 con autoridad del propio Inmon, no como opinión del autor del skill.
3. **Kimball puede citarse con cita textual de kimballgroup.com**, incluyendo el término propio "stovepipe data marts" como la palabra exacta de Kimball para el riesgo de inconsistencia sin gobierno — más fuerte que parafrasearlo.
4. **Data Vault: usar el Foreword de Inmon dentro del libro de Linstedt** como una de las citas más valiosas del research — es la persona "del otro bando" corroborando el propósito auditable/ágil de Data Vault, no Linstedt hablando de sí mismo.
5. **El claim de "Data Vault rara vez es capa de consumo" es el hallazgo más sólido de todo este research** — está confirmado con cita textual directa y sin ambigüedad en las introducciones de los Capítulos 7 y 14 del propio libro de Linstedt. Usar sin reservas, citando capítulo y frase exacta.
6. **No presentar "insert-only" como cita textual de Linstedt** — es una caracterización correcta del mecanismo (documentado con ejemplos concretos: delta-driven satellites, "records are never updated"), pero la frase exacta no aparece en el libro revisado.
7. **El framework de decisión de 4 factores (punto 5) debe presentarse como síntesis del skill**, no como cita — cada factor individual tiene respaldo en al menos una fuente primaria, pero la combinación es una construcción razonada, no una fórmula de ninguna de las tres fuentes.

## Nota de honestidad epistémica general

Dos matices quedan explícitamente marcados y no deben mezclarse con el resto: (a) la cita de Inmon proviene de un artículo reciente de su substack personal, no de sus libros clásicos (*Building the Data Warehouse*) — es primaria y confiable en cuanto a autoría, pero es una reformulación posterior (probablemente 2024-2026) de ideas que él desarrolló décadas antes, así que si el skill necesita citar su obra fundacional de los años 90 con precisión bibliográfica exacta, requeriría una verificación adicional contra esa fuente específica; (b) el punto 5 (framework de decisión) es, por diseño, una síntesis y se marca como tal — no se encontró ni se esperaba encontrar una fuente única que lo enuncie como framework formal.
