# Research: modelado para patrones de acceso — DynamoDB single-table design, dualidad stream-tabla, event sourcing y modelado bitemporal

**Fecha:** 2026-08-04
**Alcance:** verificación de 5 bloques de claims para el reference file `modeling-for-access-patterns.md` (Capa 6 — "señal senior") del futuro skill `modeling-data-engineering` (7ma de 9 en el suite `data-engineering-skills`): (1) si la guía de single-table design en DynamoDB (modelar alrededor de los patrones de acceso, no de las relaciones entre entidades; desnormalización agresiva; claves compuestas PK/SK; sin joins server-side; GSI para flexibilidad) es guía **propia y oficial de AWS**, no solo un patrón de comunidad; (2) si el framing "esto es la antítesis de la normalización relacional, y es correcto ahí porque el patrón de acceso lo exige — el modelo del serving store lo dicta el patrón de lectura, no la estructura de entidades" es fiel al razonamiento propio de AWS; (3) la "dualidad stream-tabla" (un stream de eventos de cambio y una tabla de estado actual son dos vistas de los mismos datos, convertibles entre sí) contra una fuente primaria creíble (Apache Kafka/Confluent, Kleppmann, o ksqlDB); (4) event sourcing (eventos como fuente de verdad, append-only, estado actual como proyección derivada) contra la propia escritura de Martin Fowler; (5) modelado bitemporal — el eje **valid time** vs. **transaction time** — contra Snodgrass, la autoridad académica de referencia en bases de datos temporales.

**Nota de scope respetada**: este research no toca ni Data Mesh/data-as-a-product (ya cubierto en profundidad por `quality-data-engineering/references/quality-culture-and-governance.md`) ni la mecánica de captura CDC log-based (Debezium, WAL/binlog — diferida explícitamente a la futura `streaming-data-engineering`, spec de suite §8). Ambos guardrails ya estaban fijados en `docs/superpowers/specs/2026-08-04-modeling-skill-design.md` §2.1 antes de iniciar esta investigación y no forman parte de los claims a verificar aquí.

---

## 1. DynamoDB single-table design — ¿es esta guía oficial y propia de AWS?

**VEREDICTO: sí, confirmado contra la Developer Guide oficial de AWS (`docs.aws.amazon.com`), no solo contra patrones de comunidad. La guía oficial de AWS dice explícitamente: identificar los patrones de acceso ANTES de diseñar el esquema, mantener el mínimo de tablas posible, usar claves primarias compuestas (partition key + sort key) y GSIs para dar flexibilidad de consulta adicional, y elimina los `JOIN` explícitamente como objetivo de diseño. El nombrado genérico "PK"/"SK" sí aparece en contenido oficial de AWS, pero a nivel de blog (AWS Compute Blog), no en la Developer Guide, que prefiere nombres de atributo descriptivos — matiz que se marca abajo.**

### 1.1 "Diseña primero los patrones de acceso, no el esquema" — Developer Guide oficial

> "By contrast, you shouldn't start designing your schema for DynamoDB until you know the questions it will need to answer. Understanding the business problems and the application use cases up front is essential."

> "The first step in designing your DynamoDB application is to identify the specific query patterns that the system must satisfy."

> "You should maintain as few tables as possible in a DynamoDB application. Having fewer tables keeps things more scalable, requires less permissions management, and reduces overhead for your DynamoDB application."

Fuente: [docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-general-nosql-design.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-general-nosql-design.html) — "NoSQL design for DynamoDB" (fetch directo). Esta es la página raíz de la Developer Guide sobre diseño NoSQL, no un blog de terceros.

Contraste explícito con RDBMS, en la misma página:

> "In RDBMS, you design for flexibility without worrying about implementation details or performance. Query optimization generally doesn't affect schema design, but normalization is important."
>
> "In DynamoDB, you design your schema specifically to make the most common and important queries as fast and as inexpensive as possible."

### 1.2 Eliminación de `JOIN` como objetivo explícito de diseño — la cita más fuerte de este bloque

> "The objective of the relational data model is to reduce the duplication of data (through normalization) to support referential integrity and reduce data anomalies."
>
> "Eliminating the need for `JOINs` is at the heart of NoSQL data modeling. This is why we built DynamoDB to support Amazon.com, and why DynamoDB can deliver consistent performance at any scale."
>
> "DynamoDB is built to minimize both constraints by eliminating `JOINs` (and encouraging denormalization of data) and optimizing the database architecture to fully answer an application query with a single request to an item. These qualities enable DynamoDB to provide single-digit, millisecond performance at any scale. This is because the runtime complexity for DynamoDB operations is constant, regardless of data size, for common access patterns."

Fuente: [docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-relational-modeling.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-relational-modeling.html) — "Best practices for modeling relational data in DynamoDB", sección "How DynamoDB eliminates the need for JOIN operations" (fetch directo). **Esta es, textualmente, AWS explicando por qué su propio motor renuncia a JOINs y a la normalización — no una interpretación de comunidad.**

### 1.3 Composite primary key (partition key + sort key) y GSI — terminología exacta confirmada

> "**Partition key and sort key** – Referred to as a *composite primary key*, this type of key is composed of two attributes. The first attribute is the *partition key*, and the second attribute is the *sort key*."
>
> "Global secondary index – An index with a partition key and sort key that can be different from those on the table. The primary key values in global secondary indexes don't need to be unique."

Fuente: [docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html) — "Core components of Amazon DynamoDB" (fetch directo).

Uso de GSI para dar flexibilidad de acceso, con lenguaje explícito de "patrones de consulta distintos":

> "**Use global secondary indexes.** By creating specific global secondary indexes, you can enable different queries than your main table can support, and that are still fast and relatively inexpensive."

Misma fuente que 1.1 (`bp-general-nosql-design.html`). Confirmado también el patrón de "GSI overloading" (reutilizar un mismo GSI para varios tipos de consulta con una clave compuesta tipo `TypeTarget`) en [bp-adjacency-graphs.html](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-adjacency-graphs.html) ("Best practices for managing many-to-many relationships in DynamoDB tables").

### 1.4 Nomenclatura genérica "PK"/"SK" — confirmada, pero a nivel de blog oficial, no de Developer Guide

La Developer Guide (1.3) usa nombres de atributo descriptivos (`PersonID`, `Artist`, `SongTitle`) para explicar el concepto, no literalmente "PK"/"SK". El nombrado genérico sí aparece verbatim en:

Fuente: [aws.amazon.com/blogs/compute/creating-a-single-table-design-with-amazon-dynamodb](https://aws.amazon.com/blogs/compute/creating-a-single-table-design-with-amazon-dynamodb/) — autor James Beswick (AWS Compute Blog, contenido oficial de AWS pero de categoría blog, no Developer Guide) — usa literalmente los atributos `PK` y `SK` en los ejemplos de single-table design, junto con `LSI`/`GSI` como abreviaturas estándar.

**Nota de honestidad epistémica**: no se logró un fetch directo de las charlas de re:Invent de Rick Houlihan (DAT401 2018 / DAT403 2019), que son ampliamente citadas como el origen del término de comunidad "single-table design" y el lugar donde AWS lo popularizó por primera vez de forma pública y extensa. Se confirmó por búsqueda que existen y son oficiales de AWS re:Invent (Rick Houlihan, entonces Principal Technologist de NoSQL en AWS), pero esta pasada no incluye una cita textual verificada de la transcripción — el veredicto de 1.1–1.3 no depende de esas charlas, se sostiene solo con la Developer Guide.

---

## 2. El framing "antítesis de la normalización relacional... dictado por el patrón de lectura, no por la estructura de entidades"

**VEREDICTO: caracterización fiel y precisa del razonamiento propio de AWS — no es una interpretación de comunidad forzada sobre AWS, es prácticamente parafraseo de lo que AWS mismo escribe.**

La cita de §1.2 ya lo confirma de forma directa: AWS define el objetivo del modelo relacional como reducir duplicación de datos vía normalización ("to support referential integrity and reduce data anomalies"), y define el objetivo de DynamoDB como lo opuesto — eliminar JOINs y aceptar (fomentar) la desnormalización, precisamente para lograr "single-digit, millisecond performance at any scale" con complejidad de runtime constante "for common access patterns". Es decir, en las propias palabras de AWS:

- Normalización relacional → optimiza para *flexibilidad de consulta futura desconocida* ("you design for flexibility without worrying about implementation details").
- Single-table DynamoDB → optimiza para *los patrones de acceso ya conocidos*, aceptando el costo de duplicación a cambio de latencia constante y baja ("you design your schema specifically to make the most common and important queries as fast and as inexpensive as possible").

El claim del borrador — "el serving store's model is dictated by the read pattern, not the entity structure" — es exactamente lo que dice AWS al decir que se diseña la partición/orden físico de los datos ("Data shape... a NoSQL database organizes data so that its shape in the database corresponds with what will be queried") en vez de modelar entidades primero. Esta frase de la Developer Guide es prácticamente una paráfrasis directa del claim:

> "**Data shape**: Instead of reshaping data when a query is processed (as an RDBMS system does), a NoSQL database organizes data so that its shape in the database corresponds with what will be queried. This is a key factor in increasing speed and scalability."

Fuente: misma página que §1.1, sección "Approaching NoSQL design".

**Conclusión**: no hay necesidad de matizar ni corregir este framing para el skill — es fiel al razonamiento oficial de AWS, con cita directa disponible para respaldarlo.

---

## 3. Dualidad stream-tabla ("stream-table duality")

**VEREDICTO: confirmado contra la mejor fuente primaria posible de las candidatas sugeridas — la documentación OFICIAL de Apache Kafka (`kafka.apache.org`), no solo Confluent. El término exacto "stream-table duality" se usa verbatim, con la definición precisa de convertibilidad bidireccional que pide el claim.**

> "The **stream-table duality** describes the close relationship between streams and tables."
>
> "A stream can be considered a changelog of a table, where each data record in the stream captures a state change of the table."
>
> "A stream is thus a table in disguise, and it can be easily turned into a 'real' table by replaying the changelog from beginning to end to reconstruct the table."
>
> "A table can be considered a snapshot, at a point in time, of the latest value for each key in a stream."
>
> "A table is thus a stream in disguise, and it can be easily turned into a 'real' stream by iterating over each key-value entry in the table."

Fuente: [kafka.apache.org/41/streams/core-concepts/](https://kafka.apache.org/41/streams/core-concepts/) — documentación oficial de Kafka Streams, publicada en el propio dominio `kafka.apache.org` (fetch directo). **Esta es la fuente de más alta autoridad posible para este claim: es la documentación del propio proyecto Apache Kafka, con el término exacto pedido ("stream-table duality") usado verbatim y con la mecánica de conversión bidireccional (stream→tabla vía replay del changelog; tabla→stream vía iteración sobre las entradas) descrita explícitamente.**

Corroboración adicional (mismo texto, casi palabra por palabra) en la documentación de Confluent Platform, que mantiene una versión espejo de esta página de conceptos de Kafka Streams:

Fuente: [docs.confluent.io/platform/current/streams/concepts.html](https://docs.confluent.io/platform/current/streams/concepts.html) — "Kafka Streams Basics for Confluent Platform" (fetch directo). Confirma también: "The stream-table duality is such an important concept for stream processing applications in practice that Kafka Streams models it explicitly through the KStream and KTable abstractions" — el ángulo de que esta dualidad no es solo teórica, está modelada en la propia API.

**Nota de honestidad epistémica**: el blog de Confluent "Streams and Tables: Two Sides of the Same Coin" ([confluent.io/blog/streams-tables-two-sides-same-coin](https://www.confluent.io/blog/streams-tables-two-sides-same-coin/)) fue también fetcheado, pero el pase de extracción devolvió únicamente una cita de un paper académico (Sax & Wang, sobre el "Dual Streaming Model") citado dentro del blog, no la explicación propia y original del blog — no se usa como cita en este research porque no se pudo aislar el texto propio del autor del blog con confianza; se prefiere la doc oficial de Kafka/Confluent citada arriba, que sí da una definición limpia y verbatim. No se verificó Kleppmann/*Designing Data-Intensive Applications* en esta pasada (no se tuvo acceso al texto del libro) — no fue necesario porque la fuente de Kafka ya cumple el estándar de fuente primaria pedido con el término exacto.

---

## 4. Event sourcing (Martin Fowler)

**VEREDICTO: confirmado verbatim contra la propia escritura de Martin Fowler en `martinfowler.com`. Su propia definición coincide con el claim: eventos como registro autoritativo (cuando así se diseña) y el estado de aplicación como algo completamente derivable/cacheable a partir del log — más matices importantes sobre el estatus de "borrador" del artículo y advertencias explícitas del propio Fowler sobre complejidad.**

> "Capture all changes to an application state as a sequence of events."

Definición de apertura, fuente: [martinfowler.com/eaaDev/EventSourcing.html](https://martinfowler.com/eaaDev/EventSourcing.html) (fetch directo).

Sobre cuál es la fuente de verdad y la relación evento↔estado derivado — la cita clave para el claim:

> "The official system of record can either be the event logs or the current application state."
>
> "Since an application state is purely derivable from the event log, you can cache it anywhere you like."

Es decir: Fowler mismo enmarca explícitamente que, en Event Sourcing, el log de eventos puede ser (y en la variante estricta del patrón, es) el sistema de registro oficial ("official system of record"), y que el estado actual es "purely derivable" del log — coincide exactamente con el lenguaje del claim de "proyección derivada" que pide el borrador, aunque Fowler no usa literalmente la palabra "projection" en este artículo (usa "derivable"/"cache" — se marca esta diferencia de fraseo exacto, el concepto es el mismo).

**Estatus del artículo — relevante para cómo citarlo**: el artículo es parte de su serie "Further Enterprise Application Architecture" (eaaDev), fechado **12 de diciembre de 2005**, y el propio Fowler advierte que quedó en estado de borrador permanente:

> Fowler nota explícitamente que el material "is very much in draft form" y que no ha tenido tiempo de volver a corregirlo o actualizarlo.

**Advertencias propias de Fowler sobre complejidad** (útiles para el skill, si quiere matizar cuándo NO usar el patrón):

> "Packaging up every change to an application as an event is an interface style that not everyone is comfortable with, and many find to be awkward."

Y, sobre la lógica temporal que se vuelve compleja al mezclar Event Sourcing con sistemas externos: "this stuff can get very messy, don't go down this path unless you really need to" (paráfrasis cercana del tono de advertencia del artículo, confirmar contra el texto completo si el skill cita esta frase literalmente — se marca aquí como parafraseada, no confirmada carácter por carácter, a diferencia de las tres citas en bloque anteriores que sí son verbatim).

---

## 5. Modelado bitemporal — valid time vs. transaction time (Snodgrass)

**VEREDICTO: confirmado contra un paper co-escrito por el propio Richard T. Snodgrass — la máxima autoridad académica en bases de datos temporales — con definiciones textuales exactas de "valid time" y "transaction time", y con el ejemplo de la sección BCDM del mismo paper que ilustra directamente la pregunta práctica "qué creíamos que era verdad, a una fecha dada" que pide el claim.**

### 5.1 Fuente y por qué es de la más alta calidad posible

Fuente: Christian S. Jensen y Richard T. Snodgrass, **"Temporal Data Management"**, TimeCenter Technical Report TR-17, 9 de junio de 1997 — [timecenter.cs.aau.dk/wp-content/uploads/2022/12/TR-17.pdf](https://timecenter.cs.aau.dk/wp-content/uploads/2022/12/TR-17.pdf) (fetch directo del PDF, leído página por página con el parser de PDF — no es un resumen de terceros). TimeCenter es el centro de investigación conjunto Aalborg University / University of Arizona co-dirigido por los propios Jensen y Snodgrass — este documento es tan primario como puede ser sin acceder al libro de pago de Snodgrass.

### 5.2 Definiciones textuales exactas

> "Most importantly, the valid time of a fact is the collected times—possibly spanning the past, present, and future—when the fact is true in the mini-world [7]. Valid time thus captures the time-varying states of the mini-world. By definition, all facts have a valid time."

> "Next, the transaction time of a database fact is the time when the fact is current in the database. Unlike valid time, transaction time may be associated with any database entity, not only with facts... Transaction time captures the time-varying states of the database, and applications with demands for accountability or traceability rely on databases that record transaction time."

Fuente: mismo documento, Sección 2 ("Ontological Foundations"), p. 1.

**Esto confirma exactamente los dos términos del claim** — "valid time" (cuándo el hecho era verdadero en la realidad modelada) y "transaction time" (cuándo el hecho fue registrado/estuvo vigente en el sistema) — como terminología propia de Snodgrass (co-autor de este paper), no una paráfrasis de un blog. La frase "applications with demands for accountability or traceability rely on databases that record transaction time" es, textualmente, la justificación de auditoría/trazabilidad que pide verificar el claim.

### 5.3 Bitemporal — confirmado, con el ejemplo que ilustra la pregunta "qué creíamos que era verdad, a fecha X"

El mismo paper introduce el **Bitemporal Conceptual Data Model (BCDM)** en la Sección 3, con un ejemplo de alquiler de videos (`CheckedOut`) que muestra exactamente el caso de uso práctico que pide el claim — reconstruir qué se creía verdad en una fecha pasada del sistema:

> "The timestamp of the second tuple is explained as follows. On the 5th, it is believed that customer C102 has checked out tape T1245. Then, on the 6th, the rental period is believed to include the 5th and 6th. On the 7th, the rental period extends to also include the 7th. From then on, the rental period remains fixed."

> "The idea behind the BCDM is to retain the simplicity of the relational model while also allowing for the capture of the temporal aspects of the facts stored in a database."

Fuente: mismo documento, Sección 3 ("Temporal Data Models"), p. 2. **Este ejemplo es evidencia directa y no inferida** de que el modelo bitemporal permite reconstruir, para cualquier punto pasado del transaction time, cuál era la creencia vigente sobre el valid time del hecho — exactamente el caso de uso de auditoría/regulatorio que el claim pide verificar.

### 5.4 Corroboración cruzada — el libro de Snodgrass usa el mismo vocabulario (fuente secundaria, marcada como tal)

Como corroboración adicional (no como fuente primaria por sí sola, porque se accedió vía un mirror de terceros, no el PDF original de Snodgrass/Morgan Kaufmann):

> "valid-time tables model changes in reality" / "transaction-time tables model changes in the database" / "Valid-time support and transaction-time support in concert result in a bitemporal table"

Fuente: mirror de *Developing Time-Oriented Database Applications in SQL* (Snodgrass, Morgan Kaufmann, 1999) vía [vdoc.pub/documents/developing-time-oriented-database-applications-in-sql-338o87oc6lv0](https://vdoc.pub/documents/developing-time-oriented-database-applications-in-sql-338o87oc6lv0). Coincide exactamente con la terminología del paper TR-17 — dos documentos independientes del mismo autor, mismo vocabulario, lo cual refuerza la conclusión sin depender de una sola fuente.

**Nota de honestidad epistémica**: se intentó (dos veces) el fetch directo del PDF oficial del libro alojado en el propio sitio de Snodgrass ([www2.cs.arizona.edu/~rts/tdbbook.pdf](https://www2.cs.arizona.edu/~rts/tdbbook.pdf)) — falló ambas veces por error de certificado/conexión (`unable to verify the first certificate`, `ECONNRESET`), no por ausencia de contenido. También se intentó el fetch directo de "A Consensus Glossary of Temporal Database Concepts" (Jensen et al., ACM SIGMOD Record) vía `dl.acm.org` — bloqueado con 403 (paywall de ACM Digital Library). Ninguno de los dos huecos afecta el veredicto: el paper TR-17 (alojado en el propio TimeCenter, co-autoría directa de Snodgrass, leído íntegramente vía parser de PDF, no resumen) ya cumple el estándar de fuente primaria pedido, y el mirror del libro corrobora sin contradecir.

---

## Resumen de acciones para el contenido del skill

1. **DynamoDB single-table design**: citar la Developer Guide oficial (`bp-general-nosql-design.html`, `bp-relational-modeling.html`, `HowItWorks.CoreComponents.html`) como la fuente de más alto rango — es guía propia de AWS, no patrón de comunidad. La cita más fuerte para el skill es la de §1.2: "Eliminating the need for JOINs is at the heart of NoSQL data modeling... single-digit, millisecond performance at any scale."
2. **El framing "antítesis de la normalización, dictado por el patrón de lectura"** puede usarse sin matizar — está respaldado casi palabra por palabra por AWS mismo (comparación normalización-para-flexibilidad vs. desnormalización-para-latencia-constante).
3. **"PK"/"SK" como nomenclatura genérica**: si el skill usa esos nombres literales, aclarar que vienen de contenido oficial de AWS a nivel de **blog** (AWS Compute Blog, James Beswick), no de la Developer Guide, que prefiere nombres de atributo descriptivos — matiz menor pero real.
4. **Dualidad stream-tabla**: usar la cita de `kafka.apache.org/41/streams/core-concepts/` — es la fuente de más alta autoridad posible (documentación oficial del propio proyecto Apache Kafka) y usa el término exacto "stream-table duality" verbatim, con la mecánica bidireccional de conversión (replay de changelog → tabla; iteración sobre tabla → stream) que pide el claim. Recordar el guardrail de scope: esta sección debe quedarse en conceptos de modelado (esquemas de eventos, dualidad, proyecciones), sin enseñar mecánica de captura CDC (Debezium, WAL/binlog) — eso está diferido a la futura `streaming-data-engineering`.
5. **Event sourcing**: citar a Fowler directamente (`martinfowler.com/eaaDev/EventSourcing.html`), incluyendo su propia advertencia de que el artículo quedó en estado de borrador permanente desde 2005 — es honesto citarlo así, no como "estándar actualizado". La frase "an application state is purely derivable from the event log, you can cache it anywhere you like" es la mejor cita textual para el ángulo "estado = proyección derivada".
6. **Modelado bitemporal**: usar el paper Jensen & Snodgrass (TimeCenter TR-17, 1997) como cita principal — es coautoría directa de Snodgrass, con definiciones exactas de valid time/transaction time y un ejemplo (BCDM, alquiler de videos) que ilustra literalmente la pregunta "qué creíamos que era verdad, a una fecha dada". El libro de Snodgrass (vía mirror) corrobora sin contradecir.

**Nota de honestidad epistémica general**: dos huecos quedaron marcados y no resueltos en esta pasada — (a) las charlas de re:Invent de Rick Houlihan sobre single-table design (DAT401/DAT403), ampliamente citadas como el origen de comunidad del término, no se fetchearon en transcripción — el veredicto del bloque 1 no depende de ellas; (b) el PDF oficial del libro de Snodgrass (sitio de Arizona) y el "Consensus Glossary" de Jensen et al. en ACM DL no fueron accesibles en esta pasada (error de certificado y paywall respectivamente) — el paper TR-17 (mismo autor, acceso directo y completo) cubre el mismo terreno sin ese hueco afectar la conclusión. Todos los demás claims (1, 2, 3, 4) están confirmados con cita verbatim contra fuente primaria de la más alta categoría disponible (documentación oficial de vendor o escritura propia de la autoridad nombrada), sin necesidad de recurrir a síntesis de blog como respaldo principal.
