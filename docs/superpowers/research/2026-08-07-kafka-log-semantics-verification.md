# Research: Apache Kafka log semantics — ordering, partitioning, acks, compaction, rebalance, offsets

**Fecha:** 2026-08-07
**Alcance:** verificación de 6 claims del Paso 2 del plan de implementación de la skill de streaming. Fuente primaria: documentación oficial de Apache Kafka, versión **4.3** (la más reciente al momento de este research — Kafka 4.3.0 se publicó en mayo de 2026, 4.3.1 el 25 de junio de 2026 según el blog oficial de releases). URLs versionadas bajo `https://kafka.apache.org/43/...`.

**Nota de método**: el sitio de Kafka fue reestructurado (Hugo) y `kafka.apache.org/documentation/` es hoy una página de redirección por JavaScript sin contenido estático — no sirve como fuente citable directamente. Se localizaron las páginas reales vía `sitemap.xml` del sitio y se descargaron con `curl` (no vía el fetcher basado en LLM, para evitar parafraseo): `design/design/`, `getting-started/introduction/`, `configuration/producer-configs/`, `implementation/log/`, `javadoc/.../KafkaConsumer.html`. El HTML se limpió de tags con un script Python (`re.sub('<[^>]+>','',...)` + `html.unescape`) y se hizo grep directo contra el texto plano — permite verificación verbatim, no resumen de un intermediario.

---

## 1. Ordering se garantiza dentro de una partición, no entre particiones de un topic

**VEREDICTO: SUPPORTED, con un matiz de versión importante que el skill debe conocer.**

### 1.1 Lo que dice la documentación actual (4.3)

> "When a new event is published to a topic, it is actually appended to one of the topic's partitions. Events with the same event key (e.g., a customer or vehicle ID) are written to the same partition, and Kafka guarantees that any consumer of a given topic-partition will always read that partition's events in exactly the same order as they were written."

Fuente: `https://kafka.apache.org/43/getting-started/introduction/`, sección "Main Concepts and Terminology", verbatim (extraído con `curl` + strip de tags).

Esta cita confirma la mitad positiva de la claim (orden garantizado dentro de una partición), pero **no incluye, en esta versión ni en la página `design/design/` de la misma versión, la negación explícita** ("no garantizado entre particiones"). Se revisaron ambas páginas de forma completa (texto extraído íntegro) y no aparece la frase.

### 1.2 La negación explícita SÍ existe, pero en documentación histórica (Kafka 0.8.2, 2015)

> "Kafka only provides a total order over messages within a partition, not between different partitions in a topic. Per-partition ordering combined with the ability to partition data by key is sufficient for most applications. However, if you require a total order over messages this can be achieved with a topic that has only one partition, though this will mean only one consumer process."

Fuente: `https://kafka.apache.org/082/getting-started/introduction/`, verbatim (confirmado con `curl` directo sobre esa URL versionada, que sigue en línea como archivo histórico).

**Implicación para el skill**: la claim es correcta y sigue siendo verdadera en la versión actual (el modelo de partición no ha cambiado desde 2015), pero **la cita textual con la negación explícita solo se pudo verificar contra la documentación de la versión 0.8.2**, no contra la 4.3 vigente — el texto de la doc actual quedó reformulado y solo afirma la parte positiva. El skill puede seguir afirmando la claim completa (orden garantizado dentro de partición, no garantizado entre particiones), pero si cita textualmente la frase "not between different partitions in a topic", debe atribuirla a la documentación histórica (0.8.2), no a la vigente — o preferir la formulación propia sin comillas, apoyada en la cita positiva de la 4.3.

---

## 2. Mensajes con la misma key van a la misma partición bajo el particionador por defecto

**VEREDICTO: SUPPORTED**, verbatim contra la documentación de diseño 4.3.

> "[Kafka] gives the user control over this assignment by allowing them to semantically partition data ... the interface for semantic partitioning by allowing the user to specify a key to partition by and using this to hash to a partition (there is also an option to override the partition function if need be). For example if the key chosen was a user id then all data for a given user would be sent to the same partition."

Fuente: `https://kafka.apache.org/43/design/design/`, sección "The Producer", verbatim.

Corroborado en la página de introducción (4.3): "Events with the same event key (e.g., a customer or vehicle ID) are written to the same partition" (ver cita en §1.1). Nótese que el mecanismo descrito es **hash de la key**, no una asignación arbitraria — esto es lo que el skill debe describir como "comportamiento del particionador por defecto" (`DefaultPartitioner`/`UniformStickyPartitioner` en versiones recientes usan hashing de la key cuando esta está presente; si la key es `null`, el comportamiento es distinto — round-robin/sticky — pero esto no estaba dentro del alcance de la claim exacta y no se verificó en esta pasada).

---

## 3. `acks=0`, `acks=1`, `acks=all`: fire-and-forget, ack del líder, ack de todas las réplicas in-sync; `acks=all` es el trade de durabilidad/latencia

**VEREDICTO: SUPPORTED**, verbatim contra la configuración oficial del productor.

> "The number of acknowledgments the producer requires the leader to have received before considering a request complete. This controls the durability of records that are sent. The following settings are allowed:
> - `acks=0` If set to zero then the producer will not wait for any acknowledgment from the server at all. The record will be immediately added to the socket buffer and considered sent. No guarantee can be made that the server has received the record in this case, and the `retries` configuration will not take effect (as the client won't generally know of any failures). The offset given back for each record will always be set to `-1`.
> - `acks=1` This will mean the leader will write the record to its local log but will respond without awaiting full acknowledgement from all followers. In this case should the leader fail immediately after acknowledging the record but before the followers have replicated it then the record will be lost.
> - `acks=all` This means the leader will wait for the full set of in-sync replicas to acknowledge the record. This guarantees that the record will not be lost as long as at least one in-sync replica remains alive. This is the strongest available guarantee. This is equivalent to the `acks=-1` setting."

Fuente: `https://kafka.apache.org/43/configuration/producer-configs/`, descripción del parámetro `acks`, verbatim.

Sobre el trade de latencia/durabilidad y la precisión de qué significa "acks=all" respecto a las réplicas asignadas (no todas las réplicas asignadas, sino solo las in-sync en ese momento):

> "Note that 'acknowledgement by all replicas' does not guarantee that the full set of assigned replicas have received the message. By default, when acks=all, acknowledgement happens as soon as all the current in-sync replicas have received the message. For example, if a topic is configured with only two replicas and one fails (i.e., only one in sync replica remains), then writes that specify acks=all will succeed. However, these writes could be lost if the remaining replica also fails. Although this ensures maximum availability of the partition, this behavior may be undesirable to some users who prefer durability over availability."

Fuente: `https://kafka.apache.org/43/design/design/`, sección "Availability and Durability Guarantees", verbatim. **Este matiz es importante para el skill**: `acks=all` no significa "todas las réplicas físicamente asignadas al topic", sino "todas las réplicas actualmente in-sync" — si el conjunto ISR se reduce (por fallos), la garantía se reduce con él. El propio doc reconoce esto como una fuente de tensión entre disponibilidad y durabilidad, y ofrece configuraciones (`min.insync.replicas`) para forzar mayor durabilidad a cambio de disponibilidad — mencionado en el doc justo después de esta cita, no reproducido aquí en extenso pero disponible en la misma sección.

---

## 4. Log compaction retiene al menos el último valor por key; es un modo de retención distinto de tiempo/tamaño — precisión sobre tombstones y segmento activo

**VEREDICTO: SUPPORTED**, con la precisión exacta que el brief pedía (no solo "retiene solo el último valor por key" como simplificación).

### 4.1 La garantía formal, verbatim

> "Log compaction guarantees the following: Any consumer that stays caught-up to within the head of the log will see every message that is written; these messages will have sequential offsets... Ordering of messages is always maintained. Compaction will never re-order messages, just remove some. The offset for a message never changes. It is the permanent identifier for a position in the log. Any consumer progressing from the start of the log will see at least the final state of all records in the order they were written. Additionally, all delete markers for deleted records will be seen, provided the consumer reaches the head of the log in a time period less than the topic's `delete.retention.ms` setting (the default is 24 hours). In other words: since the removal of delete markers happens concurrently with reads, it is possible for a consumer to miss delete markers if it lags by more than `delete.retention.ms`."

Fuente: `https://kafka.apache.org/43/design/design/`, sección "What guarantees does log compaction provide?", verbatim.

**Nota de precisión clave**: la garantía formal no es "el log siempre tiene exactamente un mensaje por key". Es "un consumidor que procesa desde el inicio del log verá **al menos** el estado final de cada key" — la palabra "at least" está en el texto oficial. Esto es importante porque, en la práctica, puede haber más de un mensaje con la misma key en el log en un momento dado (en la parte "head" no compactada todavía) — la compactación no es instantánea, sino que ocurre en el "tail" con un retraso configurable (`min.compaction.lag.ms` / `max.compaction.lag.ms`).

### 4.2 Modelo head/tail — el "segmento activo" nunca se compacta

> "The head of the log is identical to a traditional Kafka log. It has dense, sequential offsets and retains all messages. Log compaction adds an option for handling the tail of the log."

Fuente: `https://kafka.apache.org/43/design/design/`, sección "Log Compaction Basics", verbatim.

Sobre el segmento activo específicamente (el que está siendo escrito actualmente):

> "If not set, all log segments are eligible for compaction except for the last segment, i.e. the one currently being written to. The active segment will not be compacted even if all of its messages are older than the minimum compaction time lag."

Fuente: misma página, sección de configuración de `min.compaction.lag.ms`, verbatim. **Esto confirma exactamente el punto del brief**: el segmento activo (el que está recibiendo escrituras) nunca es candidato a compactación, independientemente de la antigüedad de sus mensajes.

### 4.3 Tombstones — comportamiento exacto

> "Compaction also allows for deletes. A message with a key and a null payload will be treated as a delete from the log. Such a record is sometimes referred to as a tombstone. This delete marker will cause any prior message with that key to be removed (as would any new message with that key), but delete markers are special in that they will themselves be cleaned out of the log after a period of time to free up space."

Fuente: misma página, verbatim. Los tombstones no son permanentes: se limpian después de `delete.retention.ms` (default 24 horas), como se confirma en la cita de §4.1.

### 4.4 La simplificación común vs. el comportamiento documentado

La simplificación habitual — "log compaction retiene solo el último valor por key" — **omite tres matices que sí están en la fuente primaria y que el skill debe preservar**:
1. La garantía es "at least the final state", no "exactly one record" — puede haber duplicados temporales en el head no compactado.
2. Los tombstones (delete markers) no son permanentes: se eliminan tras `delete.retention.ms`, y un consumidor lento puede perderlos.
3. El segmento activo nunca se compacta, sin importar la antigüedad de sus mensajes — la compactación solo opera sobre el "tail".

---

## 5. Un rebalanceo de consumer group redistribuye particiones cuando un miembro se une o se retira

**VEREDICTO: SUPPORTED**, verbatim contra el Javadoc oficial de `KafkaConsumer` (parte de la documentación pública del API, versión 4.3).

> "Membership in a consumer group is maintained dynamically: if a process fails, the partitions assigned to it will be reassigned to other consumers in the same group. Similarly, if a new consumer joins the group, partitions will be moved from existing consumers to the new one. This is known as rebalancing the group and is discussed in more detail below. Group rebalancing is also used when new partitions are added to one of the subscribed topics or when a new topic matching a subscribed regex is created."

Fuente: `https://kafka.apache.org/43/javadoc/org/apache/kafka/clients/consumer/KafkaConsumer.html`, sección de clase "Consumer Groups and Topic Subscriptions", verbatim (verificado descargando el HTML directamente con `curl` y extrayendo texto con Python, no solo vía el resumen del fetcher).

Contexto adicional verbatim de la misma sección, sobre el mecanismo de asignación:

> "Kafka will deliver each message in the subscribed topics to one process in each consumer group. This is achieved by balancing the partitions between all members in the consumer group so that each partition is assigned to exactly one consumer in the group. So if there is a topic with four partitions, and a consumer group with two processes, each process would consume from two partitions."

**Nota**: esta claim se verificó contra el Javadoc del API (parte oficial de la documentación de Kafka publicada bajo el mismo dominio `kafka.apache.org/43/`), no contra la página de "Introduction" del sitio de docs, que en la versión 4.3 no incluye esta explicación (se intentó y no se encontró ahí). También existe una página dedicada `https://kafka.apache.org/43/operations/consumer-rebalance-protocol/` sobre el nuevo protocolo de rebalanceo (KIP-848, introducido en Kafka 4.0), pero esa página cubre detalles de implementación/upgrade del protocolo, no la definición conceptual de qué es un rebalanceo — por eso se usó el Javadoc como fuente de la definición conceptual.

---

## 6. Un offset es por partición, y confirmarlo (commit) es lo que hace la consumición resumible y replayable

**VEREDICTO: SUPPORTED**, verbatim en ambas mitades de la claim.

### 6.1 El offset es por partición

> "Our topic is divided into a set of totally ordered partitions, each of which is consumed by exactly one consumer within each subscribing consumer group at any given time. This means that the position of a consumer in each partition is just a single integer, the offset of the next message to consume."

Fuente: `https://kafka.apache.org/43/design/design/`, sección "Consumer Position", verbatim.

### 6.2 Confirmar el offset (commit) hace la consumición resumible

> "There are actually two notions of position relevant to the user of the consumer: The position of the consumer gives the offset of the next record that will be given out... The committed position is the last offset that has been stored securely. Should the process fail and restart, this is the offset that the consumer will recover to. The consumer can either automatically commit offsets periodically; or it can choose to control this committed position manually by calling one of the commit APIs (e.g. `commitSync` and `commitAsync`)."

Fuente: `https://kafka.apache.org/43/javadoc/org/apache/kafka/clients/consumer/KafkaConsumer.html`, verbatim (verificado por descarga directa, no por resumen del fetcher).

### 6.3 El offset también hace la consumición replayable (rewind), no solo resumible

> "A consumer can deliberately _rewind_ back to an old offset and re-consume data. This violates the common contract of a queue, but turns out to be an essential feature for many consumers."

Fuente: `https://kafka.apache.org/43/design/design/`, sección "Consumer Position", verbatim. Esto confirma la mitad de la claim sobre "replayable" — no solo "resumable tras fallo" (que ya cubre la cita §6.2), sino también la capacidad deliberada de retroceder el offset y reprocesar datos ya consumidos, que es el mecanismo exacto que habilita el patrón Kappa (Pase 7 de este research) y la recuperación en pipelines exactly-once (Pase 3).

---

## 7. Comportamiento del particionador por defecto cuando no hay key (registro con key nula)

**VEREDICTO: SUPPORTED**, verbatim contra la configuración oficial del productor. Agregado en fix round 1 de la revisión de `the-log-and-partitioning.md`, porque la claim original ("round-robin, o 'sticky' en implementaciones actuales") no estaba cubierta por el alcance original de este research (ver nota en §2, línea 40: el comportamiento sin key fue marcado explícitamente como no verificado en esa pasada).

> "partitioner.class Determines which partition to send a record to when records are produced. Available options are: If not set, the default partitioning logic is used. This strategy send records to a partition until at least batch.size bytes is produced to the partition. It works with the strategy: If no partition is specified but a key is present, choose a partition based on a hash of the key. If no partition or key is present, choose the sticky partition that changes when at least batch.size bytes are produced to the partition. org.apache.kafka.clients.producer.RoundRobinPartitioner: A partitioning strategy where each record in a series of consecutive records is sent to a different partition, regardless of whether the 'key' is provided or not, until partitions run out and the process starts over again. Note: There's a known issue that will cause uneven distribution when a new batch is created. See KAFKA-9965 for more detail."

Fuente: `https://kafka.apache.org/43/configuration/producer-configs/`, descripción del parámetro `partitioner.class`, verbatim (verificado con `curl` directo + strip de tags, mismo método que el resto de este research).

**Precisión que la claim original no tenía**: el comportamiento **por defecto** para un registro sin key no es round-robin — es **sticky**: el particionador por defecto envía registros a una misma partición hasta que se producen al menos `batch.size` bytes hacia esa partición, y solo entonces cambia de partición "pegajosa". Round-robin (`RoundRobinPartitioner`) es una clase de particionador *distinta y no default* que debe configurarse explícitamente, y la propia documentación advierte que tiene un problema conocido (KAFKA-9965) que causa distribución desigual cuando se crea un nuevo batch. El skill debe describir el comportamiento sin key como "sticky por defecto", no como "round-robin (o sticky)" — esas dos palabras no son sinónimos intercambiables ni opciones equivalentes, son el default y una alternativa no-default con una advertencia de bug adjunta.

---

## 8. Kafka Streams es una librería cliente embebida en la aplicación JVM, no un clúster separado, y procesa registro por registro

**VEREDICTO: SUPPORTED**, verbatim. Agregado durante la redacción de `streaming-architecture-and-engines.md` (Paso 7 del plan), porque la comparación de motores de ese archivo describe a Kafka Streams como "una librería JVM, no un clúster" y esa caracterización no tenía verdict propio en el research existente — cae directamente en la categoría de minucia de motor que el plan exige verificar antes de escribirse.

> "Kafka Streams is a client library for processing and analyzing data stored in Kafka... Designed as a simple and lightweight client library, which can be easily embedded in any Java application and integrated with any existing packaging, deployment and operational tools that users have for their streaming applications. Has no external dependencies on systems other than Apache Kafka itself as the internal messaging layer... Employs one-record-at-a-time processing to achieve millisecond processing latency, and supports event-time based windowing operations with out-of-order arrival of records."

Fuente: `https://kafka.apache.org/43/streams/core-concepts/`, sección "Core Concepts", verbatim (descargado con `curl -A "Mozilla/5.0"` y extraído con el mismo script de strip de tags usado en el resto de este research).

**Confirma exactamente la claim**: Kafka Streams no es un sistema con su propio clúster de coordinación — es una librería que se enlaza dentro de la aplicación Java/JVM del propio usuario, sin más dependencia externa que el propio clúster de Kafka al que ya se conecta como cliente. El escalado se logra corriendo más instancias de la aplicación, no aprovisionando un clúster de proceso separado (a diferencia de Flink o Spark, que sí tienen su propio plano de ejecución distribuido). El procesamiento es explícitamente "one-record-at-a-time", no por micro-batches.

---

## 9. El estado de Kafka Streams se mantiene en "state stores" locales, embebidos por tarea, con tolerancia a fallos

**VEREDICTO: SUPPORTED**, verbatim, incluyendo la frase exacta "local state stores". Agregado en fix round 1 de la revisión de `streaming-architecture-and-engines.md` (Paso 7), tras un finding de que el archivo mencionaba "local state stores" de Kafka Streams sin verdict propio — la misma página ya descargada para el claim 8 de este research cubre esto directamente, no requirió una fuente nueva.

> "Kafka Streams provides so-called state stores, which can be used by stream processing applications to store and query data. This is an important capability when implementing stateful operations. Every task in Kafka Streams embeds one or more state stores that can be accessed via APIs to store and query data required for processing. These state stores can either be a persistent key-value store, an in-memory hashmap, or another convenient data structure. Kafka Streams offers fault-tolerance and automatic recovery for local state stores."

Fuente: `https://kafka.apache.org/43/streams/core-concepts/`, sección "States", verbatim (misma página y método de descarga que el claim 8).

**Confirma exactamente la claim**: la propia documentación usa la frase literal "local state stores" al describir la tolerancia a fallos, y precisa que cada *task* de Kafka Streams "embeds" (embebe) uno o más state stores — es decir, el estado vive local a la instancia de la aplicación que lo procesa, no en un almacén externo centralizado, con recuperación automática a cargo del propio framework.

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Orden garantizado dentro de partición, no entre particiones | **SUPPORTED**, con matiz de versión: la negación explícita solo se verificó verbatim contra docs históricas (0.8.2); la 4.3 vigente solo afirma la parte positiva en las páginas revisadas |
| 2 | Misma key → misma partición (particionador por defecto) | **SUPPORTED** — verbatim, mecanismo es hash de la key |
| 3 | `acks=0/1/all` y `acks=all` como trade de durabilidad/latencia | **SUPPORTED** — verbatim; matiz: "all" = todas las réplicas *in-sync actuales*, no todas las asignadas |
| 4 | Log compaction retiene al menos el último valor por key (no "exactamente uno"); tombstones y segmento activo | **SUPPORTED**, con la precisión completa (at least, no exactly; tombstones expiran; segmento activo nunca se compacta) — la simplificación común omite estos tres matices |
| 5 | Rebalanceo redistribuye particiones al unirse/salir un miembro | **SUPPORTED** — verbatim, fuente: Javadoc de `KafkaConsumer` |
| 6 | Offset es por partición; commit habilita resumable y replayable | **SUPPORTED** — verbatim en ambas mitades |
| 7 | Sin key, el particionador por defecto es sticky (no round-robin) | **SUPPORTED** — verbatim, fuente: `producer-configs` 4.3; round-robin es una clase distinta y no-default, con bug conocido documentado |
| 8 | Kafka Streams es una librería cliente embebida en la JVM del usuario (no un clúster separado), con procesamiento one-record-at-a-time | **SUPPORTED** — verbatim, fuente: `streams/core-concepts` 4.3 |
| 9 | El estado de Kafka Streams vive en "local state stores" embebidos por tarea, con tolerancia a fallos | **SUPPORTED** — verbatim, incluyendo la frase literal "local state stores"; fuente: `streams/core-concepts` 4.3, sección "States" |

## Implicación para el skill

- Al citar la negación "no ordenado entre particiones", usar formulación propia (no entre comillas) apoyada en la cita positiva de la doc 4.3, salvo que se quiera citar explícitamente la doc histórica 0.8.2 con su fecha.
- Sobre compaction: nunca escribir "retiene exactamente el último valor por key" como si fuera literal de la fuente — la fuente dice "at least the final state" y documenta un mecanismo de tombstones con expiración y un segmento activo exento. Usar la cita completa de §4.1–4.3.
- Sobre `acks=all`: siempre calificar como "todas las réplicas in-sync en ese momento", nunca "todas las réplicas del topic" — son conjuntos distintos si el ISR se ha reducido.
- Sobre el comportamiento sin key: describirlo como "sticky por defecto", nunca como "round-robin (o sticky)" — round-robin no es el default y no es intercambiable con sticky.
- Claim 8 (añadida durante la redacción del Paso 7): el skill puede describir Kafka Streams como "librería cliente JVM embebida en la aplicación, no un clúster separado" con total confianza — es la cita textual de la propia página de conceptos de Kafka Streams, no una inferencia.
- Claim 9 (añadida en fix round 1, tras finding de la revisión): el skill puede usar la frase "local state stores" para Kafka Streams con total confianza — es la frase literal de la doc, no una paráfrasis del research.
