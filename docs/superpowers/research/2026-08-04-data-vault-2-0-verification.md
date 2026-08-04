# Research: Data Vault / Data Vault 2.0 — verificación contra las fuentes primarias del método (Linstedt/Olschimke y Hultgren)

**Fecha:** 2026-08-04
**Alcance:** verificación en profundidad (pase de énfasis, R4 de la spec de `modeling-data-engineering`) de los 8 bloques de claims sobre Data Vault 2.0 que sustentarán el reference file dedicado `data-vault-2-0.md`: (1) definiciones verbatim de Hub/Link/Satélite, (2) hash keys vs. sequence keys y su justificación de escalabilidad, (3) Raw Vault vs. Business Vault, (4) carga insert-only/append-only como base de la auditabilidad y su comparación honesta con Kimball SCD Tipo 2, (5) carga paralela habilitada por las hash keys, (6) Point-in-Time (PIT) y Bridge tables en el contexto específico de Data Vault (no el bridge table de Kimball), (7) si el propio Linstedt describe Data Vault como capa de integración que alimenta marts dimensionales estilo Kimball, (8) dimensiones temporales en el Cap. 14.

**Fuentes, en orden de autoridad:**
1. **Fuente primaria máxima**: `docs/superpowers/books/building_a_scalable_data_warehouse_with_data_vault.md` — *Building a Scalable Data Warehouse with Data Vault 2.0*, Daniel Linstedt (creador del método) & Michael Olschimke (19.497 líneas; edición Morgan Kaufmann/Elsevier). Leído directamente con el Read tool, localizando rangos exactos de línea con grep antes de leer, cubriendo Cap. 1.3, 2.2, 3 (brevemente), 4 completo, 5 (parcial, aplicado a los puntos pedidos), 6.1–6.2, 11.2, y 14 completo.
2. **Segunda autoridad reconocida, usada como cross-check**: `docs/superpowers/books/data-vault-modeling-guide.md` — *Data Vault Modeling Guide*, Hans Hultgren (Genesee Academy, 2012). Leído completo (1070 líneas, con abundante ruido de cabecera/pie de página de la conversión PDF→Markdown, pero el texto en sí es legible).
3. **Fuente secundaria/pedagógica, NUNCA usada para respaldar una afirmación no ya confirmada por (1) o (2)**: `docs/superpowers/books/data_vault_modelling.md` — tesis de grado, Helsinki Metropolia, 2014. Se usa puntualmente en los puntos 4 y 5 (prácticas de carga) como cross-check de claridad pedagógica, marcado explícitamente cada vez que aparece.

**Nota de honestidad general sobre la fuente (1)**: es una conversión Markdown de un libro con figuras, tablas y código T-SQL/SSIS extensos. Varias tablas y figuras se renderizan solo como su título (p. ej. "Table 11.2", "FIGURE 6.2") sin el contenido tabular real — se marca explícitamente cada vez que una cita depende de texto corrido y no de una tabla/figura perdida en la conversión. El texto prosa está intacto y es citable con confianza.

---

## 1. Hub, Link y Satélite — definiciones verbatim de Linstedt (Cap. 4.2–4.5)

**VEREDICTO: CONFIRMADO. Las tres definiciones del borrador coinciden exactamente con la formulación propia de Linstedt/Olschimke en el Cap. 4, con cita textual disponible para las tres.**

Cita de síntesis, Cap. 4.2 (línea 3951 y ss.):

> "the model is based on three basic entity types, which are derived from the natural model described in the previous section. These entity types are hubs, links, and satellites. Each entity type serves a specific purpose: **the hub separates the business keys from the rest of the model; the link stores relationships between business keys (and/or hubs); and satellites store the context (the attributes of a business key or relationship)**."

### 1.1. Hub (Cap. 4.2.1 y 4.3)

> "the airports are the hubs. They are the central elements in the network. In the Data Vault, the business keys are central and are therefore located in the hubs." (4.2.1)

> "Hubs are defined using a unique list of business keys and provide a soft-integration point of raw data that is not altered from the source system, but is supposed to have the same semantic meaning." (4.3, línea 4037)

Estructura obligatoria del Hub (4.3.2): Hash key, Business key(s), Load date, Record source; opcional: Last seen date. **El Hub no contiene información descriptiva, solo la clave de negocio y su metadata técnica** — confirmado explícitamente ("As with all Data Vault hubs, the hub contains no other information, such as the flight date. This type of information is stored in satellites", línea 4338).

### 1.2. Link (Cap. 4.2.2 y 4.4)

> "The link entity type is responsible for modeling transactions, associations, hierarchies, and redefinitions of business terms... A link connects business keys; therefore links are modeled between hubs." (4.4, línea 4349)

Punto importante y preciso del propio texto: los links **no** llevan fechas de vigencia ni contexto — eso es tarea exclusiva de las satélites (ver §4 más abajo, es también la base de la respuesta al ítem 4):

> "it is important that links not be end-dated and contain no other time or context information, except a Load Date attribute for technical and informative reasons." (línea 4358)

Los links de Data Vault son siempre estructuras many-to-many (independientemente de la cardinalidad real de negocio), justificado explícitamente por agilidad ante cambios de reglas de negocio (4.4.1, línea 4430): "In the Data Vault model, only many-to-many relationships exist due to the use of link entities... By doing so, the Data Vault model tries to reduce the re-engineering effort down to zero."

### 1.3. Satélite (Cap. 4.2.3 y 4.5)

> "Satellites store all data that describes a business object, relationship, or transaction. They add context at a given time or over a time period to hubs and links." (4.5, línea 4617)

> "A satellite is attached to only one hub or link. Therefore, it is identified by the parent's hash key and the timestamp of the change." (línea 4621)

Confirmación explícita de que la satélite es la única estructura que guarda historia (esto es clave para el ítem 4):

> "Note that satellites are never dependent on more than one parent table... They also can't be parents to any other table (no snow flaking). For this reason, they don't introduce their own hash keys." (línea 4656)

**Cruce con Hultgren (Data Vault Modeling Guide, cross-check)**: la formulación de Hultgren es consistente palabra por palabra en el fondo, aunque con lenguaje distinto y — hallazgo relevante — con la terminología de Data Vault **1.0** en vez de 2.0:

> "The Hub represents a Core Business Concept such as Customer, Vendor, Sale or Product... The Hub consists of the business key only, **with a warehouse machine sequence id**, a load date/time stamp and a record source." (Hultgren, sección "The Data Vault Fundamentals")

> "A Link represents a natural business relationships between business keys... The Link consists of the sequence ids from the Hubs and Links that it is relating only, with a warehouse machine sequence id, a load date/time stamp and a record source." (misma sección)

> "The Satellite contains the descriptive information (context) for a business key... The Satellite is keyed by the sequence id from the Hub or Link to which it is attached plus the date/time stamp to form a two part key." (misma sección)

**Nota de honestidad explícita sobre esta diferencia**: se hizo `grep -i 'hash'` sobre el archivo completo de Hultgren y **no hay ni una sola ocurrencia de la palabra "hash" en todo el documento**. Hultgren (2012) describe consistentemente el patrón con "warehouse machine sequence id" como clave sustituta, no con hash keys. Esto es exactamente lo que el ítem 2 de este research pide contrastar: la guía de Hultgren, publicada un año antes de que Linstedt formalizara "Data Vault 2.0" con su innovación de hash keys (ver §2), documenta el patrón "clásico"/1.0 de sequence-id. Conceptualmente el modelo Hub/Link/Satélite es idéntico entre ambas fuentes — la diferencia está exactamente en el mecanismo de clave sustituta, que es el tema del siguiente punto. No se trata de una contradicción entre autoridades sino de una foto tomada en dos momentos distintos de la evolución del método; el skill debe presentar el hash key como la innovación específica de **2.0** (que Hultgren, a la fecha de esa guía, no reflejaba aún), no como parte de la definición atemporal de Hub/Link/Satélite.

**Cruce con la tesis (fuente secundaria, usada aquí solo como confirmación de claridad, no como fuente nueva)**: la tesis de Metropolia también usa terminología "surrogate key"/sequence-based en su capítulo de carga (Cap. 4.1–4.3, ver §5), consistente con Hultgren y con las referencias que cita (Data Vault Loading Specification v1.2, 2010) — refuerza que ambas fuentes secundarias documentan la era pre-hash-key del método, mientras que el libro de Linstedt/Olschimke (2015, "Data Vault 2.0" en el propio título) es la fuente que explícitamente introduce y justifica el reemplazo por hash keys.

---

## 2. Hash keys vs. sequence keys — la innovación específica de Data Vault 2.0

**VEREDICTO: CONFIRMADO con gran detalle. El Cap. 11.2 ("Hashing in the Data Warehouse") es exactamente la sección que argumenta, con la propia voz de Linstedt/Olschimke, por qué los sequence numbers son un cuello de botella y por qué el hash key lo resuelve. El Cap. 14.7 confirma el mismo razonamiento aplicado específicamente al Information Mart.**

### 2.1. Por qué los sequence numbers son un problema (Cap. 11.2, línea 11814 y ss.)

Cita completa de la lista de problemas (esta es la argumentación central del "Scalable" del título del libro):

> "There are multiple drawbacks with sequence numbers: **Dependencies in the loading processes**: in order to load a destination, every dependency has to be loaded first... **Waiting on caches for parent lookups**... this causes a bottleneck in the loading processes. This can be alleviated or removed by switching the model to Data Vault 2.0 Hash Keys – eliminating the need for lookup caching altogether. **Dependencies on serial algorithms**: sequence numbers... need to be synchronized in order to prevent two sequence numbers with the same value. In Big Data environments, the required synchronization can become a problem... **Scalability issues**: sequence numbers are easy to use but are limited when it comes to scalability... With Big Data, many times the loading processes need to be run in parallel. Sequence generators, when 'partitioned' so they can run in parallel... can hit the upper limits of the sequence number faster."

Y la conclusión explícita:

> "Due to these drawbacks and limitations, **hash keys are used as primary keys in the Data Vault 2.0 model, thus replacing sequence numbers as surrogate keys**... **because hash keys are calculated independently in loading processes, there are no lookups into other Data Vault 2.0 entities required in order to get the surrogate key of a business key**. In general, a lookup into another table requires I/O performance... On the other hand, computing a hash key only requires CPU performance, which is often favored over I/O performance because of better parallelization and better resource consumption in general." (líneas 11868–11879)

Esto es la respuesta directa y en primera persona del propio libro al ítem 2: el hash key no es solo "otra forma de generar una PK" — su razón de ser explícita es eliminar la dependencia de un lookup contra otra tabla (la del generador de sequence/la tabla padre) antes de poder insertar, lo cual es precisamente lo que habilita la carga paralela e independiente (ver también §5).

### 2.2. La definición del Hash Key en el Hub (Cap. 4.3.2.1, línea 4208)

> "Querying the final Data Vault model requires many more joins than in a traditional data warehouse. Therefore, we have to prepare the Data Vault model to increase the processing speed of the joins while the model is being created. This is when the hash key comes into play: **the key, which is based on the business key, becomes the primary key of the hub entity and is used as a foreign key to reference entities such as links and satellites**."

> "Note that **the hash key replaces the sequence number from the Data Vault 1.0 standard**. The sequence number was replaced by the hash key in order to support linking to other data sources, such as NoSQL databases. In addition, it is cross-platform compatible and can be regenerated (the same business key will always provide the same hash key, if no errors are made in the hash value calculation)." (línea 4231)

Esta cita es notable: confirma explícitamente, con las palabras del propio Linstedt/Olschimke, que **el hash key es la diferencia formal entre Data Vault 1.0 y 2.0** en el plano del modelado (no solo metodología/arquitectura como en el Cap. 1.3) — el borrador puede citar esto con total seguridad como "la innovación específica de 2.0".

### 2.3. Confirmación en el Information Mart (Cap. 14.7, línea 17592)

> "The advantage of using hash keys in the information mart is the ease of use when sourcing the data... Using hash keys in the data warehouse, including in the dimensional model, is future-proof for all requirements regarding the volume, variety and velocity of data and thus **the recommended approach for building information marts and multidimensional databases**. We truly believe that you should only deviate from this recommendation if you really need to." (línea 17609–17614)

El propio libro reconoce el trade-off (no lo esconde): "Joining data based on hash keys might be slower compared to integer-based sequence numbers, but the advantages outweigh the disadvantages." (línea 4236, Cap. 4.3.2.1). El skill puede y debe usar esta frase textual para dar la comparación honesta costo/beneficio en vez de presentar el hash key como estrictamente superior sin matices.

### 2.4. Función hash recomendada

MD5 es la práctica recomendada ("Hash keys should be either calculated using MD5 (the recommended practice) or any other hash algorithm, such as SHA-1", 4.3.2.1), con discusión extensa de riesgo de colisión en 11.2.3.1 (a 5,06 × 10⁹ registros el riesgo de colisión con MD5 llega al 50%; con SHA-1, 1,42 × 10²⁴ registros) — detalle que confirma que el riesgo de colisión es reconocido y cuantificado por el propio libro, no ignorado.

---

## 3. Raw Vault vs. Business Vault

**VEREDICTO: CONFIRMADO, con cita textual completa de la distinción en Cap. 2.2.7 y desarrollo aplicado en Cap. 14.1.**

### 3.1. Definición arquitectónica (Cap. 2.2.7, línea 1494)

> "The Business Vault is a sparsely modeled data warehouse based on Data Vault design principles, but **houses business-rule changed data. In other words, the data within a Business Vault has already been changed by business rules**. In most cases, the Business Vault is an intermediate layer between the Raw Data Vault and the information marts and eases the creation of the end-user structures."

Diferencia crítica de auditabilidad, explícita:

> "While the Business Vault is modeled after Data Vault 2.0 design principles, **it doesn't have the same requirements regarding the auditability of the source data. Instead, it is possible to drop and regenerate the Business Vault from the Raw Data Vault at any time**." (línea 1510)

El término que usa el libro para la capa "cruda" es consistentemente **"Raw Data Vault"** (no la forma corta "Raw Vault" que a veces circula en la comunidad DV) — confirmado en al menos 15 ocurrencias verificadas con grep a lo largo del libro (p. ej. líneas 614, 1470, 1502, 1583, 2455). Nota de precisión para el skill: si se usa "Raw Vault" como sinónimo abreviado, aclarar que el término exacto del libro es "Raw Data Vault".

### 3.2. Aplicación en Cap. 14.1 ("Using the Business Vault as an Intermediate to the Information Mart")

> "The Business Vault serves as an intermediate between the Raw Data Vault and information marts. By doing so, it stores intermediate results from processed (soft) business rules that are stored for reusability." (línea 16686)

El mecanismo concreto es la **computed satellite** (14.1.1): una satélite —a menudo implementada como vista SQL virtual— que aplica una regla de negocio (soft rule) sobre datos ya existentes en el Raw Data Vault, y cuyo `RecordSource` se cambia al identificador de la regla de negocio en vez del sistema origen, precisamente para señalar que el dato ya no es "crudo": "Because the computed satellite has changed the data to some extent, the record source is not the original source system anymore." (línea 16708).

**Distinción hard rules vs. soft rules (Cap. 2.2.1–2.2.2), que sustenta por qué existe la separación Raw/Business Vault**: las *hard business rules* son reglas técnicas de tipo de dato aplicadas al cargar el staging (nunca cambian el significado del dato); las *soft business rules* cambian el significado o el grano del dato y son las que se aplican en el Business Vault/Information Mart, deliberadamente lo más tarde posible en la arquitectura: "the goal of the Data Vault 2.0 architecture is to move complex business rules towards the end-user in order to ensure quick adaption to changes." (línea 1407). Este es el argumento explícito de por qué el Raw Vault se mantiene sin reglas de negocio: cualquier cambio de regla de negocio no debería obligar a re-cargar el histórico crudo.

---

## 4. Insert-only / append-only como base de la auditabilidad — comparación honesta con SCD Tipo 2 de Kimball

**VEREDICTO: CONFIRMADO CON UN MATIZ IMPORTANTE que hay que precisar en el skill — no es un patrón categóricamente distinto del SCD Tipo 2 en todos sus componentes. Hay que separar el caso del Link (insert-only puro, sin excepción) del caso de la Satélite (insert-only con una única excepción de actualización, estructuralmente análoga al `end_date`/`current_flag` de SCD2).**

### 4.1. La cita explícita de auditabilidad (Cap. 4.5.1, línea 4660)

> "Providing a historic view of the data is one function that data warehouse performs in a business. The Data Vault uses its satellites to store every change to the raw data... **Because the history of the data needs to be preserved, you are not allowed to update or modify the data in the satellite. The only exception to this rule is the Load End Date attribute of the previous version of the data**." (línea 4678)

> "Due to the Data Vault architecture, the data warehouse becomes the one and only place where historic data is stored. There is no historic data in the stage area of the data warehouse... Therefore, it is important to understand that the data warehouse is the system of record." (línea 4667)

Esta es la cita más directa de la rationale de auditabilidad pedida en el ítem 4: el mecanismo es "nunca se hace UPDATE/DELETE sobre el contenido descriptivo de una satélite, solo INSERT de nuevas filas cuando hay un cambio detectado" — confirmado verbatim.

### 4.2. El matiz — la excepción de Load End Date (Cap. 4.5.3.3, línea 4789)

> "The required load end date indicates the date and time when the satellite entry becomes invalid. **It is the only attribute that is updated in a satellite**. The update occurs once a new entry is loaded from the source system. While the new entry has a current load date, the last satellite entry that was valid just before the loading of the new entry is updated to reflect the new load end date... **It is not required from a logical modeling perspective**." (línea 4789–4797, énfasis añadido)

Esta última frase ("It is not required from a logical modeling perspective") es clave para responder con precisión el ítem 4: Linstedt/Olschimke reconocen explícitamente que el `Load End Date` es una **optimización física de performance** (para permitir un `BETWEEN` en vez de tener que calcular el "siguiente load date" con una subconsulta/window function cada vez), no un requisito lógico del modelo. Lógicamente, la satélite podría ser 100% append-only sin ninguna actualización jamás, derivando la vigencia de cada fila comparando su `LoadDate` contra el `MIN(LoadDate)` de las filas posteriores del mismo padre en tiempo de consulta.

### 4.3. Comparación honesta con SCD Tipo 2 de Kimball

Con esta evidencia, la respuesta precisa al ítem 4 es:

- **El patrón operacional real que ejecuta el ETL de una satélite** (INSERT de la fila nueva + UPDATE del `LoadEndDate` de la fila anterior) es **estructuralmente idéntico** al patrón de implementación estándar de SCD Tipo 2 en SQL (INSERT de la fila nueva + UPDATE del `end_date`/`current_flag` de la fila anterior, ya verificado y documentado en `sql-data-engineering/references/engineering-query-patterns.md` líneas 135-183 de este mismo repo). **No es una técnica distinta a nivel de ejecución SQL** — es la misma estrategia de "cerrar la versión anterior, abrir la nueva".
- La diferencia real y verificable no está en el mecanismo SQL sino en (a) el **alcance de la garantía**: en SCD2 de Kimball el `end_date` es parte constitutiva del modelo lógico de la dimensión (no se puede prescindir de él sin perder la semántica de vigencia); en Data Vault, el propio libro dice explícitamente que el `LoadEndDate` **no es un requisito lógico**, solo una optimización — el modelo lógico "puro" de Data Vault es, en efecto, append-only sin ninguna excepción, y el `LoadEndDate` es un atajo de performance que se le añade encima; y (b) el alcance del objeto: en Data Vault la garantía insert-only aplica también a la **relación** (el Link), cosa que SCD Tipo 2 de Kimball no separa como concepto independiente (una tabla de hechos de Kimball no "versiona" su clave foránea a una dimensión de la misma manera).
- **El Link es genuinamente más estricto que cualquier variante de SCD2**: el Cap. 4.4 (ya citado en §1.2) es explícito en que un Link **nunca** se fecha con fin de vigencia, bajo ninguna circunstancia: "it is important that links not be end-dated and contain no other time or context information, except a Load Date attribute" (línea 4358). Si una relación deja de existir, no se actualiza ni se borra el Link — se cierra la satélite de vigencia asociada (una *effectivity satellite*, Cap. 5.3.4) y el Link original permanece intacto para siempre. Esto sí es una diferencia real frente al patrón Kimball, donde no existe un concepto separado de "tabla de relación pura, nunca tocada" — la relación vive implícita en la clave foránea de la fila de hechos, que si se modela con SCD2 en la dimensión relacionada, sí cambia de valor a lo largo del tiempo.

**Conclusión honesta para el skill**: la afirmación "Data Vault es insert-only, más estricto que SCD2" es **parcialmente cierta y debe matizarse por estructura**: cierta y más estricta para el Link (nunca se toca, ni siquiera un `end_date`); una variante de framing —no una técnica distinta— para la Satélite, donde el mecanismo de ejecución (`UPDATE` del `end_date` de la fila previa) es el mismo que SCD2, con la diferencia de que Data Vault lo declara explícitamente opcional/no-lógico mientras que en Kimball es parte constitutiva del modelo. El skill no debería repetir sin matices la afirmación de "Data Vault nunca hace UPDATE" — el propio libro dice lo contrario para el caso concreto del `LoadEndDate`.

**Cruce con la tesis (Cap. 4.3, "Satellite Loading", fuente secundaria)**: confirma el mismo patrón en lenguaje más llano: "Using end-dating process can make the loading process fully restartable and scalable. The most current Satellite record that has not been end-dated will be end-dated during the run." — consistente con Linstedt/Olschimke, sin aportar matiz nuevo.

---

## 5. Carga paralela habilitada por el diseño de hash key

**VEREDICTO: CONFIRMADO, con cita explícita de Linstedt/Olschimke sobre el mecanismo de escalabilidad (el "Scalable" del título) y confirmación adicional en la tesis (fuente secundaria, lenguaje más directo sobre "loaded in parallel").**

### 5.1. La cita central ya extraída en §2.1 (Cap. 11.2)

> "because hash keys are calculated independently in loading processes, **there are no lookups into other Data Vault 2.0 entities required in order to get the surrogate key of a business key**." (línea 11874)

Esto es exactamente lo que el ítem 5 pide verificar: sin hash key, cargar un Link o una Satélite requiere primero resolver (lookup) el sequence number generado por el Hub padre — una dependencia de orden de carga. Con hash key, el Link o la Satélite puede calcular su propia clave de forma determinista a partir de la business key, sin ningún lookup contra la tabla padre, lo que permite cargar Hubs, Links y Satélites **en paralelo e independientemente entre sí** en el mismo ciclo de carga.

### 5.2. Confirmación específica en el contexto de splitting de satélites (Cap. 4.5.2.1, línea 4705)

> "It maximizes load parallelism because there is no competition (at the I/O or database level) for the target resource (the satellite). The data can be inserted into the satellite immediately without taking the arrival of data from other systems into account (which might try to insert their data immediately as well)."

### 5.3. Confirmación en el contexto de carga del Information Mart (Cap. 14.2.3, línea 17061)

> "Another approach to avoid the complex calculation is to retrieve the key from the dimension in the information mart. However, **this would add additional and unnecessary dependencies to the loading processes, which should be avoided in order to improve the parallelization of the loading processes** that load the information marts."

### 5.4. Cruce con la tesis (Cap. 4.1 y 4.2, "Hub Loading" y "Link Loading" — fuente secundaria, terminología DV 1.0/surrogate key pero mismo argumento)

> "In actual batch loading processes, **all the hubs can and should be loaded in parallel** so as to produce a highly scalable architecture with more data and more Hubs." (Cap. 4.1, Hub Loading)

> "Like Hub loading, **all Link loads can be run in parallel**." (Cap. 4.2, Link Loading)

Esta fuente secundaria confirma la misma conclusión con lenguaje más explícito y operacional ("should be loaded in parallel"), aunque describe el mecanismo con sequence-based surrogate keys en vez de hash keys — coherente con la nota de honestidad de §1.3: el principio de "cargar Hub/Link/Satélite en paralelo, sin dependencias de orden" es anterior e independiente de la introducción del hash key (ya estaba en Data Vault 1.0), pero el hash key es lo que **elimina la última dependencia real** (el lookup del sequence number del padre), llevando el paralelismo de "posible con cuidado" a "estructuralmente garantizado sin lookup". El skill debe distinguir estos dos niveles: paralelismo como principio arquitectónico de Data Vault (desde 1.0) vs. hash key como el mecanismo de 2.0 que lo hace posible sin ningún lookup entre tablas.

---

## 6. Point-in-Time (PIT) y Bridge tables en el contexto de Data Vault (Cap. 6.1–6.2)

**VEREDICTO: CONFIRMADO con precisión. Ambas estructuras son exactamente lo que el ítem 6 pide verificar — tablas de asistencia de consulta, generadas por el sistema, no auditables, cuyo único propósito es performance — y son conceptualmente distintas del "bridge table" de Kimball (many-to-many fact-dimension) que otra investigación paralela está verificando.**

### 6.1. Point-in-Time tables — el problema que resuelven (Cap. 6.1, línea 5718)

El problema explícito: con múltiples satélites por hub/link (algo común cuando se integran varias fuentes), consultar "el estado del cliente en la fecha X" requiere OUTER JOINs con manejo complejo de rangos de tiempo:

> "querying the passenger state on a given date... becomes complicated: the query should return the customer data as it was active according to the data warehouse delta process on the selected date. It requires OUTER JOIN queries with complex time range handling involved to achieve this goal. With more than three satellites on a hub or link, this becomes complicated and also slow." (línea 5764)

La solución:

> "The better approach is to use equal-join queries for retrieving the data from the Raw Data Vault. To achieve this, a special entity type is used in Data Vault modeling: **point-in-time tables (PIT) and a set of ghost records in satellite tables attached to fixed primary keys**." (línea 5772)

> "a PIT table creates snapshots of data for dates specified by the data consumers upstream... For each of these combinations, the PIT table contains **the load dates and the corresponding hash keys from each satellite that corresponds best with the snapshot date**." (línea 5785)

Confirmación explícita de que es una estructura de performance, no auditable, y opcional (se agrega solo si hay un problema real de performance):

> "This entity is introduced to a Data Vault model whenever the query performance is too low for a given hub or link and surrounding satellites... Because the data in a PIT table is system-computed and is not originating from a source system, **the data is not to be audited. The purpose of this table is to provide performance only**." (línea 5775)

**Esto confirma exactamente la formulación del ítem 6**: PIT = pre-join de snapshots de satélites en puntos fijos de tiempo, para performance de consulta.

### 6.2. Bridge tables — mismo propósito, distinto alcance (Cap. 6.2, línea 5890)

> "There is another type of query assistant table in the Data Vault 2.0 standard: the bridge table. Similar to PIT tables, their purpose is to improve the performance of queries on the Raw Data Vault by reducing the number of required joins for the query. **They are also part of the Business Vault**, because the data in bridge tables are system generated and cannot be audited for this reason."

> "**Unlike PIT tables, which span across multiple satellites of a hub or link, a bridge table spans across multiple hubs and links**. By doing so, it is similar to a specialized link table... The bridge table acts as a higher-level fact-less fact table and contains hash keys from the hubs and links it spans." (línea 5897)

### 6.3. Comparación directa entre ambas (Cap. 6.2.2, línea 5955)

> "While PIT tables and bridge tables have the same purpose when they assist querying the Raw Data Vault, they have some differences. **PIT tables are on one single hub or link only. They are used to create a snapshot of satellite load dates**... **Bridge tables, on the other hand, are created from multiple hubs and links. They contain the hash keys from all hubs and links that they span**... Both entities have in common that they are system-generated entities that are not part of the core architecture. **System-generated fields make them nonauditable**."

Este es exactamente el resumen conceptual pedido por el ítem 6: PIT pre-une snapshots de satélites (un solo hub/link, historia de contexto); Bridge pre-une caminos de hub/link (múltiples hubs/links, sin contexto de satélite salvo agregados opcionales), y ambas son estructuras de performance sin obligación de auditabilidad — a diferencia del Raw Data Vault, que sí debe ser 100% auditable y reconstruible desde la fuente.

### 6.4. Cruce con Hultgren (sección "Hybrid Tables") — coincide en el fondo, mismo nombre distinto de agrupación

> "The Point In Time table (PIT) is a modified Satellite table that tracks the valid time slices of the satellites surrounding a particular Hub. This is populated to make the process of associating relative context/descriptive data together for reporting purposes."

> "The Bridge table is a modified Link stable [sic, 'table'] that flattens the relationship between Hubs including important related context/descriptive data (potentially also the business keys) into a single table for ease of access and performance."

> "In all cases, these and other constructs can coexist in the DV EDW provided however that they are always noted as 'sysgen' tables and utilized only for performance reasons."

Hultgren llama a ambas "Hybrid Tables" (un término propio de su guía, no usado por Linstedt/Olschimke, que las tratan bajo "Advanced Data Vault Modeling" sin agruparlas bajo ese nombre) y usa el término "sysgen" (system-generated) para la misma idea de "no auditable" que Linstedt/Olschimke expresan como "cannot be audited". Es la misma idea con dos vocabularios distintos — una diferencia de fraseo, no de sustancia, exactamente el tipo de cruce que se pidió documentar.

### 6.5. Distinción explícita frente al "bridge table" de Kimball

Ninguna de las dos fuentes primarias usa el bridge table de Data Vault para resolver relaciones many-to-many entre un hecho y una dimensión (el uso clásico de Kimball, p. ej. cuenta bancaria compartida por varios titulares). El bridge table de Data Vault resuelve un problema distinto: reducir el número de joins entre estructuras Data Vault (hub/link) para acelerar la construcción de un mart virtualizado. Comparten el nombre y la idea general de "tabla de pre-unión para simplificar consultas", pero operan sobre objetos distintos (hub/link de Data Vault vs. fact/dimension de Kimball) y resuelven problemas distintos (performance de virtualización vs. cardinalidad many-to-many real de negocio). El skill debe marcar esta distinción explícitamente para no confundir ambos "bridge table" bajo el mismo nombre.

---

## 7. ¿Describe Linstedt Data Vault como capa de integración que alimenta marts dimensionales estilo Kimball?

**VEREDICTO: CONFIRMADO DE FORMA MUY DIRECTA Y EXPLÍCITA — el Cap. 14 completo es, literalmente, un manual paso a paso de cómo cargar dimensiones Tipo 1, dimensiones Tipo 2 y tablas de hechos (terminología Kimball textual) desde el Raw/Business Data Vault. Esta es una de las confirmaciones más sólidas de todo este research.**

### 7.1. El Information Mart es explícitamente un star schema (Cap. 2.2.5, línea 1451)

> "the data in the information mart is subject oriented and can be in aggregated form, flat or wide, prepared for reporting, highly indexed, redundant and quality cleansed. **It often follows the star schema** and forms the basis for both relational reporting and multidimensional OLAP cubes."

### 7.2. El propio libro usa vocabulario Kimball textual — "Type 1 dimension" y "Type 2 dimension" (Cap. 14.2.1–14.2.2)

> "14.2.1. Loading Type 1 Dimensions — The first example creates and loads a Type 1 dimension, which provides no history of the dimension member but only the most current version of the descriptive data." (línea 16928)

> "14.2.2. Loading Type 2 Dimensions — Joining the data becomes a bigger problem when dealing with Type 2 dimensions. In this case, multiple if not all versions of the descriptive data from the satellites should be sourced into the target." (línea 16978)

> "14.2.3. Loading Fact Tables" (línea 17032)

**Esto responde directamente al ítem 7**: Linstedt/Olschimke no solo describen conceptualmente "un mart dimensional aguas abajo" — usan explícitamente la nomenclatura SCD Tipo 1/Tipo 2 de Kimball para describir cómo poblar las dimensiones del Information Mart a partir de hubs y satélites del Data Vault. El libro incluso remite explícitamente al libro de Kimball para la arquitectura de dos capas en el Cap. 1.4.1 (línea 911: "Kimball has introduced an often-used, two-layer architecture [24, p114]"), reconociendo a Kimball como referencia externa explícita, no solo implícita.

### 7.3. Confirmación adicional en Cap. 14.6 (Reference Data) — cita textual "star schemas"

> "By doing so, the descriptive data is added to the computed satellite by adding some of the attributes from the joined reference table to the view. **This approach is perfectly fine, especially for creating star schemas**." (línea 17575)

### 7.4. El mecanismo exacto Raw/Business Vault → Information Mart (Cap. 14.1, ya citado en §3.2)

> "The Business Vault serves as an intermediate between the Raw Data Vault and information marts." (línea 16686)

Y la arquitectura completa en tres capas descrita desde el Cap. 2.2 (línea 1238): "staging area, which collects the raw data... the enterprise data warehouse layer, modeled as a Data Vault 2.0 model; **and the information delivery layer, with information marts as star schemas and other structures**."

### 7.5. Conclusión para el skill

La afirmación "Data Vault feeds Kimball marts" **no es una interpretación externa ni una síntesis de terceros — es exactamente cómo el propio creador del método describe la arquitectura en su libro de referencia**, con vocabulario Kimball explícito (Type 1/Type 2 dimension) y referencia directa al trabajo de Kimball. El skill puede citar esto con máxima confianza como la posición del propio Linstedt, no como una interpretación de la skill. Esto también resuelve, del lado de Data Vault, la pregunta que otra investigación paralela está verificando sobre si "Data Vault alimenta marts Kimball" — la respuesta desde esta fuente primaria es sí, de forma explícita y detallada (un capítulo entero, el 14, dedicado a ello).

---

## 8. Dimensiones temporales en Data Vault (Cap. 14.4)

**VEREDICTO: CONFIRMADO. El libro distingue explícitamente entre la vigencia "técnica" (load date, cuándo el DW vio el cambio) y la vigencia "de negocio" (effectivity date, cuándo el cambio es válido según el negocio), y propone un PIT temporal como mecanismo para servir esta segunda perspectiva sin duplicar la discusión de modelado bitemporal que cubre otra investigación paralela.**

Cita central (línea 17486):

> "All of these joins were based on the load date to find the record in the dependent satellite that is current for a given snapshot date. The load date was used because it provides information about the technical validity of a record in the history of the data: which data was current at a given point in time, **from a technical perspective**. However, in some cases, business users don't want to analyze the data from a technical perspective. Instead, **they are interested in a temporal perspective that is based on the effectivity dates, defined by the business**."

Mecanismo concreto — el **temporal PIT**:

> "In order to create Type 2 dimensions that reflect the temporal perspective, a special form of a PIT table can be used... Notice that there is no difference in the structure between a standard PIT and a temporal PIT. However, **instead of prejoining the data based on load date, the effectivity date or any other descriptive date is used** when loading the temporal PIT table." (línea 17503)

**Nota de honestidad y de no-duplicación**: el libro no usa el término "bitemporal" en ningún momento de este capítulo (no se encontró la palabra en el pasaje leído); describe el concepto de forma funcional (dos perspectivas de tiempo: técnica vs. de negocio) sin nombrarlo con el vocabulario académico de modelado bitemporal (transaction time vs. valid time). Es una confirmación de que Data Vault distingue las dos nociones de tiempo en la práctica (vía load date en la satélite estándar vs. effectivity date en la effectivity satellite, Cap. 5.3.4, y el temporal PIT del Cap. 14.4 como forma de servir ambas), pero el mapeo textual explícito a la terminología bitemporal formal (transaction-time/valid-time) queda fuera de lo que este libro dice literalmente — ese mapeo conceptual, si el skill lo necesita, debe resolverse con la investigación dedicada a modelado bitemporal, no citando este libro como si usara esos términos.

---

## Resumen de acciones para el contenido del skill (`data-vault-2-0.md`)

1. **Hub/Link/Satélite**: usar las citas verbatim de Cap. 4.2–4.5 de Linstedt/Olschimke como definición canónica. Mencionar que Hultgren (2012) describe el mismo modelo con sequence-id en vez de hash key — útil para explicar que el hash key es la innovación específica de la versión "2.0", no parte de la definición atemporal de las tres estructuras.
2. **Hash key vs. sequence key**: usar la lista de problemas de sequence numbers del Cap. 11.2 tal cual está citada — es la justificación más fuerte y más citable de todo este research, con la frase "Due to these drawbacks and limitations, hash keys are used as primary keys in the Data Vault 2.0 model, thus replacing sequence numbers" como cita ancla. No esconder el trade-off que el propio libro reconoce (joins con hash keys pueden ser más lentos que con enteros).
3. **Raw Vault vs. Business Vault**: usar el término exacto "Raw Data Vault" (no "Raw Vault") si se cita textualmente al libro. La distinción clave es auditabilidad: el Business Vault puede regenerarse desde el Raw Data Vault en cualquier momento y no tiene el mismo requisito de auditabilidad — cita textual disponible en §3.
4. **Insert-only y su comparación con SCD2**: este es el punto que más requiere matiz — no presentar "Data Vault nunca hace UPDATE" sin calificarlo. El Link es 100% insert-only sin excepción (confirmado). La Satélite hace un único UPDATE (el `LoadEndDate` de la fila anterior), que el propio libro dice que **no es un requisito lógico**, solo una optimización de performance — mecánicamente es el mismo patrón que un SCD Tipo 2 de Kimball (INSERT nuevo + UPDATE de la fila anterior). La diferencia real está en que Data Vault declara ese `end_date` opcional/no-lógico, mientras que en Kimball es parte constitutiva de la dimensión, y en que Data Vault extiende la garantía de "nunca se toca" también a la relación (el Link), cosa que Kimball no modela como un concepto separado.
5. **Carga paralela**: la cita del Cap. 11.2 ("no lookups into other Data Vault 2.0 entities required... eliminating the need for lookup caching altogether") es la justificación central de escalabilidad. El principio de paralelismo en sí (cargar Hub/Link/Satélite sin dependencias de orden) ya existía en Data Vault 1.0 según la tesis (fuente secundaria) — el hash key es lo que lo vuelve estructuralmente garantizado al eliminar el último lookup real (el del sequence number del padre).
6. **PIT y Bridge tables (contexto Data Vault)**: usar las definiciones de Cap. 6.1–6.2 tal cual — PIT pre-une snapshots de satélites de un solo hub/link; Bridge pre-une hash keys de múltiples hubs/links. Ambas son "sysgen"/no auditables, viven en el Business Vault, y existen únicamente por performance de virtualización. Marcar explícitamente la diferencia con el bridge table de Kimball (many-to-many fact-dimension) — comparten nombre e idea general, pero resuelven problemas distintos sobre objetos distintos.
7. **Data Vault alimentando marts Kimball**: esta es la confirmación más fuerte de todo el research — el propio Cap. 14 usa "Type 1 dimension"/"Type 2 dimension"/"Fact Tables" (vocabulario Kimball textual) para describir cómo poblar el Information Mart desde el Data Vault, y remite explícitamente al trabajo de Kimball en el Cap. 1.4.1. El skill puede citar esto con máxima confianza como la posición del propio Linstedt, no como una síntesis de terceros.
8. **Dimensiones temporales**: el libro distingue vigencia técnica (load date) de vigencia de negocio (effectivity date) y resuelve la segunda con un "temporal PIT" — pero no usa el vocabulario académico de "bitemporal" en este capítulo. No forzar esa palabra como cita del libro; el mapeo a terminología bitemporal formal debe hacerse en la sección de modelado bitemporal de la Capa 6, con su propia investigación dedicada.

**Nota de honestidad epistémica general**: la conversión Markdown del libro de Linstedt/Olschimke pierde el contenido real de varias tablas y figuras (quedan solo como su título, p. ej. Tablas 6.1–6.8, 11.2–11.6), aunque el texto en prosa alrededor de ellas —de donde salen todas las citas usadas en este research— está intacto y es fiable. Ningún veredicto de este research depende de una tabla o figura perdida; en los casos donde el argumento se apoyaba en una tabla (p. ej. 11.2.3.1, colisiones de hash), se usaron los números y conclusiones que sí están en el texto corrido, no en la tabla en sí.
