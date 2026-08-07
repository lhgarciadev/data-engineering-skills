# Research: exactly-once end-to-end — requisitos, transacciones de Kafka, y el hedge "effectively-once"

**Fecha:** 2026-08-07
**Alcance:** verificación de 3 claims del Paso 3 del plan de implementación de la skill de streaming.

**Fuentes primarias consultadas:**
- Documentación oficial de Apache Kafka, versión **4.3** (misma versión que el Pase 2), sección "Design" → "Message Delivery Semantics" (`https://kafka.apache.org/43/design/design/`), descargada con `curl` y extraída a texto plano con Python (`re.sub` + `html.unescape`) para permitir cita verbatim.
- Documentación oficial de Apache Flink, versión **stable = 2.3.0** al momento de este research (confirmado directamente en el HTML de la página, campo de versión visible en el navbar: "v2.3.0"): páginas `Learn Flink → Fault Tolerance` (`https://nightlies.apache.org/flink/flink-docs-stable/docs/learn-flink/fault_tolerance/`) y `Connectors → Fault Tolerance Guarantees` (`https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/datastream/guarantees/`), ambas descargadas con `curl` y extraídas a texto plano.
- Flink Blog: *"An Overview of End-to-End Exactly-Once Processing in Apache Flink (with Apache Kafka, too!)"* (28 de febrero de 2018), `https://flink.apache.org/2018/02/28/...` — publicado en el blog oficial del proyecto (data Artisans / Piotr Nowojski y Mike Winters, contribuido al blog de Apache Flink), descargado con `curl`. Se trata con la misma autoridad que la documentación porque es contenido oficial del proyecto, aunque es más antiguo (2018) — se señala explícitamente dónde esta fuente pudo quedar desactualizada respecto de la doc actual.

**Nota de método**: todas las citas de este documento se verificaron contra HTML descargado directamente con `curl` y limpiado con un script propio, no contra resúmenes de un fetcher LLM — esto fue necesario porque el fetcher, al probarlo primero, reportó "no encontrado" para dos de las tres claims cuando en realidad el texto sí estaba presente en el HTML (falso negativo del resumen). Queda registrado como advertencia metodológica para las siguientes pasadas: cuando el fetcher reporta "no encontrado", conviene descargar el HTML crudo antes de marcar la claim como UNSUPPORTED.

---

## 1. Exactly-once end-to-end requiere fuente replayable + estado con checkpoint + sink idempotente/transaccional — y falla en el más débil de los tres

**VEREDICTO: SUPPORTED en sus tres componentes individuales, verificados por separado contra la fuente primaria; la frase exacta "fails at the weakest of the three" no aparece literalmente en ninguna fuente consultada — es una síntesis razonable de la estructura documentada, no una cita. Se marca así explícitamente para que el skill no la presente entre comillas.**

### 1.1 Componente 1 — fuente que puede rebobinar/reproducir (replayable)

> "Given that Flink recovers from faults by rewinding and replaying the source data streams, when the ideal situation is described as exactly once this does not mean that every event will be processed exactly once. Instead, it means that every event will affect the state being managed by Flink exactly once."

Fuente: Flink docs v2.3.0, "Learn Flink → Fault Tolerance", verbatim.

Y, sobre el requisito formal de que la fuente participe en el mecanismo de snapshot:

> "Flink can guarantee exactly-once state updates to user-defined state only when the source participates in the snapshotting mechanism."

Fuente: Flink docs v2.3.0, "Connectors → Fault Tolerance Guarantees", verbatim. La misma página incluye una tabla de garantías por conector de fuente: Apache Kafka = "exactly once", Google PubSub = "at least once", Sockets = "at most once" — es decir, **la garantía end-to-end depende explícitamente de qué conector de fuente se use**, lo cual es la base documental real detrás de la idea de "falla en el eslabón más débil".

### 1.2 Componente 2 — estado con checkpoint

Ya cubierto en detalle en el Pase 4 de este research (checkpointing y barreras). Aquí solo se cita el vínculo directo con exactly-once:

> "Flink's fault tolerance mechanism recovers programs in the presence of failures and continues to execute them... Flink can guarantee exactly-once state updates to user-defined state only when the source participates in the snapshotting mechanism."

Fuente: misma página, verbatim.

### 1.3 Componente 3 — sink idempotente o transaccional

La tabla de sinks de la misma página, verbatim:

> "To guarantee end-to-end exactly-once record delivery (in addition to exactly-once state semantics), the data sink needs to take part in the checkpointing mechanism."

Y en la tabla misma: "Kafka producer — at least once / exactly once — exactly once with transactional producers (v 0.11+)"; "Cassandra sink — at least once / exactly once — exactly once only for idempotent updates". Ambas notas están en el texto verbatim de la tabla.

Fuente: Flink docs v2.3.0, "Connectors → Fault Tolerance Guarantees", verbatim.

### 1.4 Sobre "falla en el más débil de los tres"

Esta frase exacta no se encontró en ninguna de las tres fuentes primarias consultadas (se buscó "weakest" literalmente en las dos páginas de Flink y no aparece). Lo que sí está documentado, y de lo que la frase es una síntesis razonable, es: (a) el doc separa explícitamente las garantías de fuente y de sink en dos tablas independientes; (b) declara que la garantía end-to-end "in addition to" requiere que *ambos* lados participen; (c) la tabla de fuentes muestra que algunos conectores (Sockets, Google PubSub) no ofrecen exactly-once, en cuyo caso ninguna configuración del sink puede recuperar esa garantía perdida. **El skill puede seguir afirmando la idea ("la garantía end-to-end es tan fuerte como su componente más débil"), pero como explicación propia, no como cita de Flink.**

---

## 2. Las transacciones de Kafka dan escrituras atómicas entre particiones más el commit de offsets

**VEREDICTO: SUPPORTED**, verbatim en ambas mitades.

### 2.1 Escrituras atómicas entre particiones/topics

> "Also beginning with 0.11.0.0, the producer supports the ability to send messages atomically to multiple topic partitions using transactions, so that either all messages are successfully written or none of them are."

Fuente: `https://kafka.apache.org/43/design/design/`, sección "Message Delivery Semantics", verbatim.

### 2.2 El commit de offsets como parte de la misma transacción (patrón read-process-write)

> "So what about exactly-once semantics? When consuming from a Kafka topic and producing to another topic (as in a Kafka Streams application), we can leverage the new transactional producer capabilities in 0.11.0.0 that were mentioned above. The consumer's position is stored as a message in an internal topic, so we can write the offset to Kafka in the same transaction as the output topics receiving the processed data. If the transaction is aborted, the consumer's stored position will revert to its old value (although the consumer has to refetch the committed offset because it does not automatically rewind) and the produced data on the output topics will not be visible to other consumers, depending on their 'isolation level'."

Fuente: misma página, mismo párrafo, verbatim, inmediatamente después de la cita 2.1. **Esta es la cita más completa de todo este research para la claim 2**: confirma explícitamente que el offset se escribe "en la misma transacción" que los datos de salida — exactamente la claim del brief.

Nota adicional verbatim sobre isolation levels (relevante para el skill si describe visibilidad de datos transaccionales): "In the default 'read_uncommitted' isolation level, all messages are visible to consumers even if they were part of an aborted transaction, but in 'read_committed' isolation level, the consumer will only return messages from transactions which were committed."

---

## 3. Los motores describen esto como "effectively-once" o "exactly-once state semantics", no como una garantía de entrega física de un solo mensaje

**VEREDICTO: dos sub-veredictos, para que no se pierdan al leer solo la etiqueta.**

- **Sustancia — SUPPORTED**: los motores efectivamente hedgean el término "exactly-once" en vez de prometer una entrega física de un solo mensaje. Esto está confirmado con cita verbatim tanto en Flink como en Kafka (ver §3.1–3.2).
- **Terminología — CORREGIDO**: la palabra literal **"effectively-once" NO aparece en ninguna fuente primaria consultada** (se buscó explícitamente en el texto extraído de ambas páginas de Flink y no está) y **no debe escribirse en el skill como cita de Flink o Kafka**. La formulación verificada y correcta es **"exactly-once state semantics"** (Flink, verbatim) más la advertencia de Kafka de "leer la letra pequeña" ante cualquier claim de exactly-once (ver §3.3).

### 3.1 Flink: "exactly-once state semantics" ≠ garantía de entrega física

> "To guarantee end-to-end exactly-once record delivery (in addition to exactly-once state semantics), the data sink needs to take part in the checkpointing mechanism."

Fuente: Flink docs v2.3.0, "Connectors → Fault Tolerance Guarantees", verbatim (ya citada en §1.3, repetida aquí porque es la cita clave del hedge).

Y la explicación más directa del hedge, ya citada en §1.1:

> "...when the ideal situation is described as exactly once this does not mean that every event will be processed exactly once. Instead, it means that every event will affect the state being managed by Flink exactly once."

Fuente: Flink docs v2.3.0, "Learn Flink → Fault Tolerance", verbatim. **Esta es la formulación más precisa y más citable para el skill**: "exactly once" en Flink se refiere al efecto sobre el estado, no a que cada evento sea entregado/procesado físicamente una sola vez — que es exactamente la distinción que el brief pedía preservar.

### 3.2 Kafka: advertencia explícita sobre leer "la letra pequeña" de las claims de exactly-once

> "Many systems claim to provide 'exactly-once' delivery semantics, but it is important to read the fine print, because sometimes these claims are misleading (i.e. they don't translate to the case where consumers or producers can fail, cases where there are multiple consumer processes, or cases where data written to disk can be lost)."

Fuente: `https://kafka.apache.org/43/design/design/`, sección "Message Delivery Semantics", verbatim. Es la propia documentación de Kafka advirtiendo sobre el uso indiscriminado del término — el equivalente funcional al hedge que el brief pedía verificar, aunque la palabra usada no es "effectively-once" sino una advertencia directa sobre "leer la letra pequeña".

### 3.3 Sobre "effectively-once" específicamente

Se buscó la palabra exacta "effectively" en el texto extraído de ambas páginas de Flink consultadas (`fault_tolerance` y `guarantees`) y no aparece. Sí aparece en fuentes secundarias (por ejemplo, resúmenes de terceros sobre Flink dicen "effectively exactly-once"), pero **no se pudo verificar como término usado por la documentación oficial vigente**. El skill debe usar "exactly-once state semantics" (Flink, verbatim) y la advertencia de Kafka sobre "leer la letra pequeña", no la palabra "effectively-once" atribuida a ninguna de las dos fuentes revisadas en esta pasada.

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Exactly-once requiere fuente replayable + estado con checkpoint + sink idempotente/transaccional; falla en el más débil | **SUPPORTED** en los tres componentes individuales (cada uno con cita verbatim); "falla en el más débil" es una síntesis del skill, no una cita — decirlo explícitamente |
| 2 | Transacciones de Kafka: escritura atómica entre particiones + commit de offsets | **SUPPORTED** — verbatim en ambas mitades, misma página y mismo párrafo |
| 3 | Los motores describen esto como "effectively-once" / "exactly-once state semantics", con hedge | Sustancia: **SUPPORTED**. Terminología: **CORREGIDO** — "effectively-once" **no aparece en ninguna fuente primaria** y no debe citarse; usar "exactly-once state semantics" (Flink, verbatim) + la advertencia de Kafka sobre "leer la letra pequeña" |

## Implicación para el skill

- No citar "fails at the weakest of the three" ni "effectively-once" entre comillas atribuidas a Kafka o Flink — son formulaciones del skill/secundarias, no citas.
- Usar la cita real de Flink sobre qué significa "exactly once" (afecta el estado, no necesariamente la entrega física) como la explicación central del hedge.
- Usar la cita real de Kafka ("read the fine print") para introducir la misma cautela desde el lado del productor/consumidor.
- La cita sobre transacciones de Kafka (offset + datos de salida en la misma transacción) es sólida y puede citarse con confianza total — es literal y completa.
