# Research: fundamentos Kimball de modelado dimensional — star schema, grano, aditividad y tipos de tabla de hechos

**Fecha:** 2026-08-04
**Alcance:** verificación de 8 bloques de claims del borrador de `star-schema-and-grain.md` (primer reference file de la futura skill `modeling-data-engineering`, R1 del plan de verificación en `docs/superpowers/specs/2026-08-04-modeling-skill-design.md` §4): (1) normalización OLTP (1FN/2FN/3FN) vs. desnormalización OLAP como tensión de fondo; (2) definiciones de tabla de hechos y tabla de dimensión; (3) star schema como definición propia de Kimball; (4) snowflake schema y la postura de Kimball Group frente a él; (5) el proceso de diseño en cuatro pasos; (6) el grano al nivel más atómico posible; (7) aditividad de los hechos (aditivo/semi-aditivo/no aditivo); (8) los tres tipos de tabla de hechos. Fuentes primarias: **The Data Warehouse Toolkit, 3rd Edition** (Kimball & Ross, Wiley, 2013) — consultado en PDF completo y legible (mirror de Internet Archive, `ia801609.us.archive.org/.../The Data Warehouse Toolkit - Kimball.pdf`), leído directamente página por página (Capítulo 1, "Data Warehousing, Business Intelligence, and Dimensional Modeling Primer", pp. 2–17; Capítulo 2, "Kimball Dimensional Modeling Techniques Overview", pp. 37–51) — y artículos/glosario de `kimballgroup.com` (fetch directo), que en varios casos reproducen el texto del libro casi palabra por palabra, lo cual se señala explícitamente como corroboración cruzada. Para las definiciones formales de 1FN/2FN/3FN (que no son un aporte de Kimball sino de teoría relacional clásica) se usó a E. F. Codd como fuente primaria: *"A Relational Model of Data for Large Shared Data Banks"* (1970) y *"Further Normalization of the Data Base Relational Model"* (IBM Research Report RJ909, 1971, vía mirror de texto completo).

---

## 1. OLTP (1FN/2FN/3FN) vs. desnormalización OLAP como tensión de fondo

**VEREDICTO: confirmado, pero con una distinción importante que el borrador debe hacer explícita — las definiciones formales de 1FN/2FN/3FN no son "material Kimball", son teoría relacional de Codd; y el propio Kimball Group, cuando sí usa los términos "segunda/tercera forma normal", lo hace de forma informal y no estrictamente coddiana (incluso lo admite por escrito). La tensión OLTP-vs-OLAP en sí SÍ está sostenida en las propias palabras de Kimball, con cita textual del libro.**

### 1.1 Las definiciones formales de 1FN/2FN/3FN — fuente correcta es Codd, no Kimball

Codd definió 2FN y 3FN en su paper de 1971 (Sección 2.5 y 3.3 respectivamente):

> "A relation R is in **second normal form** if it is in first normal form and every non-prime attribute of R is **fully dependent** on each candidate key of R."
>
> "A relation R is in **third normal form** if it is in second normal form and every non-prime attribute of R is **non-transitively dependent** on each candidate key of R."

Fuente: E. F. Codd, *"Further Normalization of the Data Base Relational Model"*, IBM Research Report RJ909 (31 de agosto de 1971), §2.5 y §3.3 — texto completo vía [thaumatorium.com/articles/the-papers-of-ef-the-coddfather-codd/1971b-further-normalization-of-the-data-base-relational-model](https://thaumatorium.com/articles/the-papers-of-ef-the-coddfather-codd/1971b-further-normalization-of-the-data-base-relational-model/) (mirror de texto completo del paper original de Codd).

El mismo paper define "dependencia transitiva" formalmente (§3.1): C es transitivamente dependiente de A bajo R cuando R.A → R.B, R.B ↛ R.A, y R.B → R.C. Esto corresponde exactamente a la definición del borrador ("no dependencia transitiva"). La 1FN (valores atómicos, sin grupos repetitivos) proviene del paper fundacional de 1970, *"A Relational Model of Data for Large Shared Data Banks"*, donde Codd exige que los dominios de las relaciones sean "atómicos (no descomponibles)" — no se pudo verificar esta frase exacta contra un fetch directo del paper de 1970 en esta pasada (se confirmó vía fuentes secundarias que citan el paper), así que ese punto específico queda marcado como confirmado conceptualmente pero no verbatim contra el texto de 1970 mismo.

**Las tres definiciones del borrador (1FN: valores atómicos/sin grupos repetitivos; 2FN: sin dependencia parcial de una clave compuesta; 3FN: sin dependencia transitiva) son correctas** y coinciden con la fuente primaria de la teoría relacional.

### 1.2 La tensión OLTP vs. OLAP — sí es un argumento propio y explícito de Kimball, con cita textual del libro

> "Users of an operational system turn the wheels of the organization. They take orders, sign up new customers, monitor the status of operational activities, and log complaints. The operational systems are optimized to process transactions quickly... Users of a DW/BI system, on the other hand, watch the wheels of the organization turn to evaluate performance... These systems are optimized for high-performance queries."

Fuente: Kimball & Ross, *The Data Warehouse Toolkit*, 3rd ed., Cap. 1, "Different Worlds of Data Capture and Data Analysis", p. 2.

Y, sobre por qué las dimensiones se desnormalizan en vez de mantenerse en forma normal como en OLTP:

> "You should resist the perhaps habitual urge to normalize data by storing only the brand code in the product dimension and creating a separate brand lookup table... This normalization is called *snowflaking*. Instead of third normal form, dimension tables typically are highly denormalized with flattened many-to-one relationships within a single dimension table."

Fuente: mismo libro, Cap. 1, p. 15. Y en el Capítulo 2 (p. 47–48), bajo el encabezado "Denormalized Flattened Dimensions":

> "In general, dimensional designers must resist the normalization urges caused by years of operational database designs and instead denormalize the many-to-one fixed depth hierarchies into separate attributes on a flattened dimension row. Dimension denormalization supports dimensional modeling's twin objectives of simplicity and speed."

### 1.3 El matiz que el skill debe explicitar: el uso de "2FN/3FN" en material Kimball no siempre es riguroso

El artículo de Kimball Group *"Fact Tables and Dimension Tables"* (2003) describe el modelo dimensional así:

> "the fact table is in third normal form and the dimension tables are in second normal form, confusingly referred to as denormalized"

Fuente: [kimballgroup.com/2003/01/fact-tables-and-dimension-tables](https://www.kimballgroup.com/2003/01/fact-tables-and-dimension-tables/) (fetch directo). El propio artículo usa la palabra "confusingly" — es decir, **el propio Kimball Group reconoce que su uso de "segunda/tercera forma normal" en este contexto no es el uso técnico riguroso de Codd**, sino una forma abreviada de hablar de "cuánto se ha desnormalizado". El libro de texto (2013) no repite esta caracterización 2FN/3FN de las dimensiones; solo dice "instead of third normal form... denormalized" (p. 15), una formulación más simple y menos propensa a confusión.

**Implicación para el skill**: usar a Codd como fuente de las definiciones formales de 1FN/2FN/3FN (sección "OLTP" del capítulo), y usar las citas del libro de Kimball (Cap. 1 pp. 2, 15; Cap. 2 pp. 47–48) para la motivación/tensión OLTP-vs-OLAP — pero no atribuir a Kimball una definición rigurosa de 2FN/3FN, porque su propio material admite que su uso del término es informal.

---

## 2. Definiciones de tabla de hechos y tabla de dimensión

**VEREDICTO: confirmado en su totalidad, verbatim, contra el libro de texto (no solo contra el sitio web).**

### 2.1 Tabla de hechos: medidas numéricas + FK a dimensiones, angosta y profunda, crece sin límite

> "A fact table contains the numeric measures produced by an operational measurement event in the real world. At the lowest grain, a fact table row corresponds to a measurement event and vice versa... In addition to numeric measures, a fact table always contains foreign keys for each of its associated dimensions, as well as optional degenerate dimension keys and date/time stamps."

Fuente: Kimball & Ross, *The Data Warehouse Toolkit*, 3rd ed., Cap. 2, "Fact Table Structure", p. 41–42. Confirmado también verbatim en [kimballgroup.com/.../fact-table-structure](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/fact-table-structure/) — el sitio reproduce el libro casi palabra por palabra.

Sobre "angosta y profunda" (el borrador dice "long and narrow"; la fuente primaria dice literalmente "deep... but narrow"):

> "Fact tables tend to be deep in terms of the number of rows, but narrow in terms of the number of columns. Given their size, you should be judicious about fact table space utilization."

Fuente: mismo libro, Cap. 1, p. 12. **Nota de fraseo**: el borrador usa "long and narrow"; la fuente primaria usa "deep... but narrow" — mismo concepto (muchas filas, pocas columnas), fraseo ligeramente distinto. No se encontró la frase exacta "grow without bound" en el libro ni en los artículos de kimballgroup.com consultados, pero el concepto de crecimiento continuo está confirmado indirectamente: el libro habla de "an impractical exercise with a billion-row fact table" (p. 11) y de tablas de hechos que llegan a miles de millones de filas de forma rutinaria.

### 2.2 Tabla de dimensión: contexto descriptivo, atributos textuales, ancha y corta (pocas filas)

> "Dimension tables are integral companions to a fact table. The dimension tables contain the textual context associated with a business process measurement event. They describe the 'who, what, where, when, how, and why' associated with the event."
>
> "Dimension tables tend to have fewer rows than fact tables, but can be wide with many large text columns."

Fuente: mismo libro, Cap. 1, "Dimension Tables for Descriptive Context", p. 13. Y en el Capítulo 2:

> "Every dimension table has a single primary key column... Dimension tables are usually wide, flat denormalized tables with many low-cardinality text attributes."

Fuente: mismo libro, Cap. 2, "Dimension Table Structure", p. 46. **Esto confirma exactamente** la caracterización del borrador: hechos = angostos/profundos (muchas filas, pocas columnas); dimensiones = anchas/cortas (pocas filas, muchas columnas).

---

## 3. Star schema — ¿es esta la definición y terminología propias de Kimball?

**VEREDICTO: confirmado como concepto y terminología propios de Kimball, con un matiz de fraseo exacto — el libro no usa literalmente "one join away", usa una imagen más vívida ("rodeada por un halo de tablas de dimensión") que transmite exactamente la misma idea.**

> "Each business process is represented by a dimensional model that consists of a fact table containing the event's numeric measurements surrounded by a halo of dimension tables that contain the textual context that was true at the moment the event occurred. This characteristic star-like structure is often called a **star join**, a term dating back to the earliest days of relational databases."

Fuente: Kimball & Ross, *The Data Warehouse Toolkit*, 3rd ed., Cap. 1, "Facts and Dimensions Joined in a Star Schema", p. 16.

Corroboración en el glosario técnico del sitio:

> "Star schemas are dimensional structures deployed in a relational database management system (RDBMS). They characteristically consist of fact tables linked to associated dimension tables via primary/foreign key relationships."

Fuente: [kimballgroup.com/.../star-schema-olap-cube](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/star-schema-olap-cube/).

**Sobre "one join away" específicamente**: se buscó esta frase exacta (y variantes "single join away", "a join away from the fact table") en el libro (Cap. 1 y Cap. 2 completos) y en los ocho artículos de kimballgroup.com consultados directamente — **no aparece verbatim en ninguna de las fuentes primarias revisadas**. Es una paráfrasis muy extendida en fuentes secundarias que resume correctamente el diseño (cada dimensión se alcanza desde el fact table con un único join, precisamente porque Kimball desnormaliza/aplana las dimensiones para evitar snowflaking — ver §4), pero el skill no debería presentarla como cita literal de Kimball. **Recomendación**: usar la cita real del libro ("surrounded by a halo of dimension tables" / "star join") como la cita textual, y "cada dimensión es alcanzable con un único join" como explicación del skill, no como cita.

---

## 4. Snowflake schema — la postura de Kimball Group

**VEREDICTO: confirmado en su totalidad, con la cita exacta del libro sobre el argumento de storage — es la cita más fuerte de todo este research para este punto. Matiz: la postura de Kimball se endureció con el tiempo (en 1997 la permitía condicionalmente; en el libro de 2013 la postura es una recomendación de evitarla, sin condicionalidad).**

### 4.1 Definición y postura, con la cita exacta sobre almacenamiento

> "You should resist the perhaps habitual urge to normalize data by storing only the brand code in the product dimension and creating a separate brand lookup table, and likewise for the category description in a separate category lookup table. This normalization is called *snowflaking*. Instead of third normal form, dimension tables typically are highly denormalized with flattened many-to-one relationships within a single dimension table. **Because dimension tables typically are geometrically smaller than fact tables, improving storage efficiency by normalizing or snowflaking has virtually no impact on the overall database size. You should almost always trade off dimension table space for simplicity and accessibility.**"

Fuente: Kimball & Ross, *The Data Warehouse Toolkit*, 3rd ed., Cap. 1, p. 15 (énfasis añadido). Esta es exactamente la afirmación del borrador ("ahorro de storage que importa menos con los costos modernos de almacenamiento") — con una diferencia importante: **el libro no la enmarca como "los discos ahora son baratos"**, sino como "las dimensiones son geométricamente más pequeñas que los hechos, así que normalizarlas no cambia el tamaño total de la base de datos" — es un argumento de proporción relativa, no de costo de hardware por unidad. El skill debería usar el argumento real (proporción dimensión/hecho), no inventar un argumento de "el storage es barato hoy en día" que no es el que usa Kimball.

Corroboración adicional, casi con las mismas palabras, en el Capítulo 2 y en el artículo *"Fistful of Flaws"* (2003):

> "When a hierarchical relationship in a dimension table is normalized, low-cardinality attributes appear as secondary tables connected to the base dimension table by an attribute key... you should avoid snowflakes because it is difficult for business users to understand and navigate snowflakes. They can also negatively impact query performance."

Fuente: mismo libro, Cap. 2, "Snowflaked Dimensions", p. 50 — idéntico verbatim en [kimballgroup.com/.../snowflake-dimension](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/snowflake-dimension/).

> "Snowflaking may reduce the disk space needed for dimension tables, but the savings are usually insignificant when compared with the entire data warehouse and seldom offset the disadvantages in ease of use or query performance."

Fuente: [kimballgroup.com/2003/10/fistful-of-flaws](https://www.kimballgroup.com/2003/10/fistful-of-flaws/) (fetch directo).

### 4.2 Matiz histórico: la postura de 1997 era más condicional que la del libro de 2013

En el *Dimensional Modeling Manifesto* original (1997), Kimball es más permisivo:

> "I believe that this method [snowflaking] compromises cross-attribute browsing performance and may interfere with the legibility of the database." ... "I think that a designer can snowflake with a clear conscience if this technique improves user understandability and improves overall performance."

Fuente: [kimballgroup.com/1997/08/a-dimensional-modeling-manifesto](https://www.kimballgroup.com/1997/08/a-dimensional-modeling-manifesto/) (fetch directo). Esto contrasta con el libro de 2013 ("you should avoid snowflakes"), que no incluye esa condicionalidad explícita. **El skill puede presentar "desincentivado históricamente" como correcto, pero con precisión: la recomendación por defecto siempre fue desnormalizar, y con el tiempo la formulación se volvió menos condicional, no más.**

---

## 5. El proceso de diseño en cuatro pasos

**VEREDICTO: confirmado exactamente, secuencia y terminología idénticas, verbatim contra el libro de texto y contra el sitio.**

> "The four key decisions made during the design of a dimensional model include:
> 1. Select the business process.
> 2. Declare the grain.
> 3. Identify the dimensions.
> 4. Identify the facts."

Fuente: Kimball & Ross, *The Data Warehouse Toolkit*, 3rd ed., Cap. 2, "Four-Step Dimensional Design Process", p. 38 — idéntico verbatim en [kimballgroup.com/.../four-4-step-design-process](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/four-4-step-design-process/). La secuencia y la terminología exacta del borrador ("elegir el proceso de negocio → declarar el grano → identificar las dimensiones → identificar los hechos") coinciden palabra por palabra con la fuente primaria.

---

## 6. Grano: declarar al nivel más atómico posible

**VEREDICTO: confirmado exactamente, incluyendo la razón (el detalle atómico soporta preguntas impredecibles; no se puede recuperar detalle desde un agregado).**

> "Declaring the grain is the pivotal step in a dimensional design. The grain establishes exactly what a single fact table row represents. The grain declaration becomes a binding contract on the design. The grain must be declared before choosing dimensions or facts because every candidate dimension or fact must be consistent with the grain... *Atomic grain* refers to the lowest level at which data is captured by a given business process. **We strongly encourage you to start by focusing on atomic-grained data because it withstands the assault of unpredictable user queries; rolled-up summary grains are important for performance tuning, but they pre-suppose the business's common questions.**"

Fuente: Kimball & Ross, *The Data Warehouse Toolkit*, 3rd ed., Cap. 2, "Grain", p. 39 — idéntico verbatim en [kimballgroup.com/.../grain](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/grain/).

Corroboración adicional, con la afirmación explícita de que agregar es posible pero no al revés:

> "All grain definitions should start at the lowest, most atomic grain... Aggregated data, for example, store sales by product by month, can easily be derived from the atomic data, but necessarily must truncate or delete most of the dimensions... Aggregated data is NOT the place to start a design!"

Fuente: [kimballgroup.com/2007/07/keep-to-the-grain-in-dimensional-modeling](https://www.kimballgroup.com/2007/07/keep-to-the-grain-in-dimensional-modeling/) (fetch directo, Design Tip #92). Esto confirma exactamente la lógica del borrador: el dato atómico siempre puede agregarse hacia arriba; el dato agregado no puede "desagregarse" para recuperar el detalle perdido (las dimensiones truncadas no se pueden reconstruir).

---

## 7. Aditividad de los hechos (aditivo/semi-aditivo/no aditivo)

**VEREDICTO: confirmado en su totalidad, incluyendo la técnica exacta de agregación para hechos semi-aditivos ("counts and averages") y los ejemplos canónicos — balance de cuenta para semi-aditivo, precio unitario para no aditivo. Este punto quedó mejor verificado que lo previsto: se encontró la cita exacta en el propio libro (no solo en fuentes secundarias que lo citaban).**

> "The numeric measures in a fact table fall into three categories. The most flexible and useful facts are *fully additive*; additive measures can be summed across any of the dimensions associated with the fact table. *Semi-additive* measures can be summed across some dimensions, but not all; balance amounts are common semi-additive facts because they are additive across all dimensions except time. Finally, some measures are completely *non-additive*, such as ratios. A good approach for non-additive facts is, where possible, to store the fully additive components of the non-additive measure and sum these components into the final answer set before calculating the final non-additive fact."

Fuente: Kimball & Ross, *The Data Warehouse Toolkit*, 3rd ed., Cap. 2, "Additive, Semi-Additive, Non-Additive Facts", p. 42 — idéntico verbatim en [kimballgroup.com/.../additive-semi-additive-non-additive-fact](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/additive-semi-additive-non-additive-fact/).

Sobre la técnica de agregación para hechos semi-aditivos/no aditivos a través del tiempo (el punto del borrador que costó más encontrar verbatim — la mención en el glosario del sitio es breve y no la detalla, pero el Capítulo 1 del libro sí):

> "You will see that facts are sometimes semi-additive or even non-additive. Semi-additive facts, such as **account balances**, cannot be summed across the time dimension. Non-additive facts, such as **unit prices**, can never be added. **You are forced to use counts and averages** or are reduced to printing out the fact rows one at a time—an impractical exercise with a billion-row fact table."

Fuente: mismo libro, Cap. 1, p. 11. **Esto confirma exactamente los tres elementos del borrador**: (a) el balance de cuenta como ejemplo canónico de semi-aditivo, (b) el precio unitario como ejemplo canónico de no aditivo, y (c) que la técnica correcta para resumir estos hechos a través del tiempo es usar conteos/promedios, no `SUM`. El borrador menciona también "último valor" (last-value) como técnica alternativa para el caso de balance — esto no aparece en la cita anterior (que solo dice "counts and averages"); es una técnica ampliamente enseñada y consistente con el problema descrito, pero **no se encontró una cita verbatim de Kimball Group recomendando explícitamente "último valor"** en esta pasada de research. El skill puede seguir mencionando "promedio o último valor" como las dos técnicas de uso común, pero solo debería atribuir a Kimball textualmente la técnica de "promedios/conteos", no la de "último valor".

---

## 8. Los tres tipos de tabla de hechos

**VEREDICTO: confirmado en su totalidad y de forma muy precisa, incluyendo el detalle central de que accumulating snapshot es el único de los tres tipos donde las filas se actualizan (UPDATE) en vez de solo insertarse.**

### 8.1 Transaction fact table

> "A row in a *transaction fact table* corresponds to a measurement event at a point in space and time... These fact tables always contain a foreign key for each associated dimension, and optionally contain precise time stamps and degenerate dimension keys."

Fuente: Kimball & Ross, *The Data Warehouse Toolkit*, 3rd ed., Cap. 2, "Transaction Fact Tables", p. 43.

### 8.2 Periodic snapshot fact table

> "A row in a *periodic snapshot fact table* summarizes many measurement events occurring over a standard period, such as a day, a week, or a month. The grain is the period, not the individual transaction... These fact tables are uniformly dense in their foreign keys because even if no activity takes place during the period, a row is typically inserted in the fact table containing a zero or null for each fact."

Fuente: mismo libro, Cap. 2, "Periodic Snapshot Fact Tables", p. 43.

### 8.3 Accumulating snapshot fact table — el único tipo con UPDATE

> "A row in an *accumulating snapshot fact table* summarizes the measurement events occurring at predictable steps between the beginning and the end of a process. Pipeline or workflow processes, such as order fulfillment or claim processing, that have a defined start point, standard intermediate steps, and defined end point can be modeled with this type of fact table. There is a date foreign key in the fact table for each critical milestone in the process. An individual row in an accumulating snapshot fact table, corresponding for instance to a line on an order, is initially inserted when the order line is created. **As pipeline progress occurs, the accumulating fact table row is revisited and updated. This consistent updating of accumulating snapshot fact rows is unique among the three types of fact tables.**"

Fuente: mismo libro, Cap. 2, "Accumulating Snapshot Fact Tables", p. 44 (énfasis añadido) — idéntico verbatim en [kimballgroup.com/.../accumulating-snapshot-fact-table](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/accumulating-snapshot-fact-table/). **Esto confirma exactamente y sin matices** la afirmación central del borrador: de los tres tipos, el accumulating snapshot es el único donde las filas se modifican después de insertadas — el ejemplo del borrador (orden con fechas de creación/pago/envío/entrega que se van llenando) es exactamente el patrón "pipeline con hitos" que describe el libro.

---

## Resumen de acciones para el contenido del skill

1. **Separar con claridad, en la sección OLTP/OLAP, la fuente de las definiciones formales (Codd, teoría relacional) de la fuente de la motivación/tensión (Kimball, en sus propias palabras).** No presentar 1FN/2FN/3FN como si fueran "definiciones de Kimball" — citar a Codd (1971, RJ909) para 2FN/3FN, y usar la cita de Kimball (Cap. 1 pp. 2, 15) solo para el "por qué" de la tensión OLTP-vs-OLAP.
2. **Usar "deep... but narrow" y "wide... with fewer rows"** (fraseo real del libro) en vez de inventar "grow without bound" como si fuera cita textual — el concepto de crecimiento continuo se puede seguir enseñando, pero sin comillas falsas.
3. **La cita real del star schema es "surrounded by a halo of dimension tables" / "star join"** (Cap. 1, p. 16) — no "one join away" (frase no encontrada verbatim en ninguna fuente primaria). Usar la cita real; "un único join" puede quedar como explicación del skill, no como cita.
4. **El argumento de Kimball contra el snowflaking es de proporción relativa dimensión/hecho, no de "el storage es barato hoy"**: usar la cita exacta del libro (p. 15) — "dimension tables typically are geometrically smaller than fact tables... normalizing or snowflaking has virtually no impact on the overall database size." Mencionar también que la postura se volvió más categórica entre 1997 (permitía snowflaking condicionalmente) y 2013 (recomienda evitarlo sin condiciones).
5. **Los cuatro pasos, el grano atómico, la aditividad y los tres tipos de fact table quedaron confirmados palabra por palabra contra el libro de texto** — son los bloques más sólidos de todo este research, se pueden citar con total confianza usando las citas de este documento.
6. **Sobre "promedio o último valor" para hechos semi-aditivos**: solo "counts and averages" está confirmado verbatim contra el libro (Cap. 1, p. 11); "último valor" (last value) es una técnica real y ampliamente enseñada pero no se encontró como cita textual de Kimball Group en esta pasada — no atribuírsela como cita.

**Nota de honestidad epistémica general**: este research tuvo acceso poco común a una fuente primaria completa y legible — el PDF íntegro de *The Data Warehouse Toolkit*, 3rd edition — lo cual permitió verificar página por página (no solo contra resúmenes de terceros ni contra el sitio web) prácticamente todas las claims del borrador. Los dos puntos que quedan con una verificación más débil y están marcados como tales arriba son: (a) la definición exacta de 1FN en el paper original de Codd de 1970 (confirmada solo por fuentes secundarias que lo citan, no por fetch directo del paper); y (b) la técnica de "último valor" para hechos semi-aditivos a través del tiempo (real y de uso común, pero sin cita textual de Kimball Group encontrada). Ningún otro punto de los 8 solicitados quedó sin una cita verbatim de una fuente primaria directamente consultada.
