# Research: Servicios gestionados de streaming — unidad de escalado, modo serverless, superficie de protocolo Kafka y alcance del ordenamiento (MSK, Kinesis Data Streams, Event Hubs, Pub/Sub)

**Fecha:** 2026-08-08
**Alcance:** verificación de las 4 claims del Paso 3 del plan de implementación de la skill de streaming (bloque de servicios gestionados / IaC-cloud). Cuatro servicios por claim: **AWS MSK**, **AWS Kinesis Data Streams**, **Azure Event Hubs** y **GCP Pub/Sub**. Cada claim numerada lleva sub-veredicto por servicio más un veredicto global.

**Páginas oficiales consultadas** (todas el 2026-08-08):

- `https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html`
- `https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html`
- `https://docs.aws.amazon.com/streams/latest/dev/key-concepts.html`
- `https://docs.aws.amazon.com/streams/latest/dev/how-do-i-size-a-stream.html`
- `https://docs.aws.amazon.com/streams/latest/dev/developing-producers-with-sdk.html`
- `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-about` (`ms.date` 2026-02, sin fecha de revisión visible en el cuerpo)
- `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-scalability` (`ms.date: 2026-02-05`, `updated_at: 2026-02-06`)
- `https://learn.microsoft.com/en-us/azure/event-hubs/azure-event-hubs-apache-kafka-overview` (`ms.date: 2026-02-05`, `updated_at: 2026-02-06`)
- `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-dedicated-overview` (`ms.date: 2025-07-28`, `updated_at: 2026-07-24`)
- `https://learn.microsoft.com/en-us/azure/event-hubs/compare-tiers`
- `https://docs.cloud.google.com/pubsub/docs/overview`
- `https://docs.cloud.google.com/pubsub/docs/ordering`
- `https://docs.cloud.google.com/pubsub/docs/choose-pubsub-kafka`
- `https://docs.cloud.google.com/pubsub/docs/migrating-from-kafka-to-pubsub`
- `https://docs.cloud.google.com/pubsub/docs/connect_kafka`
- `https://docs.cloud.google.com/managed-service-for-apache-kafka/docs/overview`
- `https://kafka.apache.org/intro` (fuente primaria de semántica de ordenamiento para MSK, que declara ejecutar Apache Kafka open source)

**Nota de método**: se usaron tres mecanismos de fetch y todos funcionaron, pero con caveats que conviene registrar.

1. `WebFetch` (fetcher basado en LLM) funcionó para AWS, Azure y Google. **Ningún sitio devolvió 403 en esta ronda** — a diferencia de la verificación de Debezium del 2026-08-07, no hizo falta el workaround por bloqueo de user-agent.
2. `cloud.google.com` responde **301 hacia `docs.cloud.google.com`**; `WebFetch` no sigue redirecciones cross-host y devuelve la URL de destino para reintentar. Todas las URLs de Google en este documento son las de `docs.cloud.google.com` ya resueltas.
3. Como `WebFetch` devuelve texto convertido y resumido por un modelo, **toda cita de este documento fue re-verificada por `grep` contra el HTML crudo descargado con `curl -A "Mozilla/5.0"`** y convertido a texto plano. Los ficheros están en `…/scratchpad/raw/` con prefijo `stream-` (pares `.html` + `.txt`). Ninguna cita de abajo entró al documento sin aparecer literalmente en el `.txt` correspondiente.
4. **Excepción de método**: `https://kafka.apache.org/documentation/` (y sus variantes versionadas `/41/documentation.html`, `/40/documentation.html`) devuelven un *shell* de ~20 KB cargado por JavaScript; el texto de la sección *Design → Guarantees* no es accesible por `curl`. Se sustituyó por `https://kafka.apache.org/intro`, que **sí** entrega HTML estático y contiene una afirmación equivalente y suficiente sobre ordenamiento por partición. Se registra el cambio de página para que el revisor no busque la cita donde no está.
5. Para Microsoft se usó además el MCP de Microsoft Learn (`microsoft_docs_search` / `microsoft_docs_fetch`) para localizar `compare-tiers` y `event-hubs-about`; ambas páginas fueron después descargadas por `curl` y verificadas por `grep` igual que el resto.

**Nota sobre cifras**: por la regla de "sin números" de la skill, **toda cifra concreta dentro de las citas verbatim fue elidida con `[…]`**. La elisión es siempre una supresión, nunca una sustitución: el texto restante es literal. Cuando una claim solo podía sostenerse citando una cifra, se marca así explícitamente.

---

## 1. La unidad de escalado que cada servicio expone al usuario, con el término del propio proveedor

**VEREDICTO GLOBAL: SUPPORTED**

La claim, tal como la enuncia el brief —*"The scaling unit each exposes to the user — broker count, shard, throughput unit, or none — named with the vendor's own term"*— queda confirmada: los cuatro sub-veredictos son SUPPORTED y cada unidad se documenta con el término literal del proveedor. El brief no hace ninguna afirmación de encuadre sobre Event Hubs ni sobre ningún otro servicio, así que no hay nada que corregir.

**Ampliación (hallazgo adicional, no corrección):** la unidad expuesta no es una propiedad fija del servicio sino del *modo o tier* contratado, y esto ocurre en tres de los cuatro servicios, no solo en Event Hubs. En MSK la unidad depende del *cluster type* (Provisioned expone brokers, Serverless no expone ninguna); en Kinesis depende del *capacity mode* (Provisioned expone shards, On-demand no); en Event Hubs hay **tres** unidades distintas repartidas en cuatro tiers (TU/PU/CU). El único servicio que **nunca** expone una unidad, en ningún modo, es Pub/Sub. La skill debe enunciar la unidad siempre junto al modo o tier que la hace visible; decir "Kinesis se escala por shards" sin más es incompleto. Detalle abajo.

### 1.1 AWS MSK — **VEREDICTO: SUPPORTED**. Término del proveedor: *broker nodes*, y solo en MSK Provisioned.

> "**Broker nodes** — When creating an Amazon MSK cluster, you specify how many broker nodes you want Amazon MSK to create in each Availability Zone. The minimum is one broker per Availability Zone. Each Availability Zone has its own virtual private cloud (VPC) subnet.
>
> Amazon MSK Provisioned offers two broker types: Amazon MSK Standard brokers and Amazon MSK Express brokers. In MSK Serverless, MSK manages the broker nodes used to handle your traffic and you only provision your Kafka server resources at a cluster level."

Fuente: `https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html`, sección "What is Amazon MSK?", verbatim.

Dos matices que la fuente hace explícitos y el skill debe conservar:

- La unidad no es solo el *conteo* de brokers, sino conteo **más tipo de broker** ("two broker types"). El tipo concreto y su dimensionamiento son datos numéricos/de instancia que el skill no debe enunciar.
- En MSK Serverless **el usuario no expone brokers**: la propia página dice que ahí "MSK manages the broker nodes".

### 1.2 AWS Kinesis Data Streams — **VEREDICTO: SUPPORTED**. Término del proveedor: *shard*.

> "A *shard* is a uniquely identified sequence of data records in a stream. A stream is composed of one or more shards, each of which provides a fixed unit of capacity. Each shard can support up to […]. The data capacity of your stream is a function of the number of shards that you specify for the stream. The total capacity of the stream is the sum of the capacities of its shards."

Fuente: `https://docs.aws.amazon.com/streams/latest/dev/key-concepts.html`, entrada "Shard", verbatim con cifras elididas (`[…]` sustituye a la enumeración de transacciones por segundo, MB/s y registros por segundo del original).

Y la dependencia del modo:

> "With the **provisioned** mode, you must specify the number of shards for the data stream. The total capacity of a data stream is the sum of the capacities of its shards. You can increase or decrease the number of shards in a data stream as needed and you are charged for the number of shards at an hourly rate."

Fuente: misma página, entrada "Capacity Mode", verbatim.

**Lo importante para el skill**: el shard es la unidad **solo en modo provisioned**. En on-demand el usuario no la fija — ver claim 2.

### 1.3 Azure Event Hubs — **VEREDICTO: SUPPORTED**, y la dependencia de tier es real y de tres unidades distintas, no dos.

La página de escalabilidad abre nombrando solo dos:

> "There are two factors that influence scaling with Event Hubs.
>
> - Throughput units (standard tier) or processing units (premium tier)
> - Partitions"

Fuente: `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-scalability`, verbatim.

> "Throughput units control the throughput capacity of event hubs. Throughput units are prepurchased units of capacity."

Fuente: misma página, sección "Throughput units", verbatim.

> "The resources in a Premium tier are isolated at the CPU and memory level so that each tenant workload runs in isolation. This resource container is called a **Processing Unit** (PU). You can purchase […] processing Units for each Event Hubs Premium namespace."

Fuente: misma página, sección "Processing units", verbatim con la enumeración de valores comprables elidida.

Más abajo, la **misma página** amplía a tres unidades e incorpora el tier dedicated:

> "It depends on the number of pricing units (throughput units (TUs) for the standard tier, processing units (PUs) for the premium tier, and capacity units (CUs) for the dedicated tier) for the namespace or the dedicated cluster."

Fuente: misma página, sección "Number of partitions", verbatim.

Confirmado en la página del tier dedicado:

> "Dedicated clusters are provisioned and billed by capacity units (CUs), which is a preallocated amount of CPU and memory resources."

Fuente: `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-dedicated-overview`, sección "Capacity units", verbatim.

**Hedge registrado**: hay una inconsistencia interna en la propia documentación de Microsoft. El encabezado de `event-hubs-scalability` dice "throughput units (standard tier) or processing units (premium tier)" — omite Basic y Dedicated. La tabla de `compare-tiers` muestra que el tier **Basic también se dimensiona en TUs** (la fila "Maximum TUs or PUs or CUs" da un valor en TUs para Basic y para Standard, y en PUs/CUs para Premium/Dedicated). El skill no debe repetir el encuadre de dos unidades: **son tres unidades sobre cuatro tiers** (Basic y Standard → TU, Premium → PU, Dedicated → CU).

**Segundo matiz crítico**: en Event Hubs la partición **no** es la unidad de capacidad, a diferencia del shard de Kinesis. La fuente lo separa explícitamente:

> "A partition is a data organization mechanism that enables parallel publishing and consumption. While it supports parallel processing and scaling, total capacity remains limited by the namespace's scaling allocation. Balance scaling units (throughput units for the standard tier, processing units for the premium tier, or capacity units for the dedicated tier) and partitions to achieve optimal scale."

Fuente: `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-scalability`, verbatim.

### 1.4 GCP Pub/Sub — **VEREDICTO: SUPPORTED**. No expone ninguna unidad de escalado; el proveedor niega explícitamente tener particiones.

> "Pub/Sub does not have partitions, and consumers instead read from a topic that autoscales according to demand. You configure each Kafka topic with the number of partitions that you require to handle the expected consumer load. Pub/Sub scales automatically based on demand."

Fuente: `https://docs.cloud.google.com/pubsub/docs/migrating-from-kafka-to-pubsub`, verbatim.

> "Pub/Sub dynamically adjusts capacity for individual topics and subscriptions. Publishers and subscribers can scale independently, not only across different topics and subscriptions, but also within the same ones."

Fuente: `https://docs.cloud.google.com/pubsub/docs/choose-pubsub-kafka`, verbatim.

La página de overview lo plantea como decisión de diseño, no como ausencia accidental de la feature:

> "By contrast, other horizontally scalable messaging systems use partitions for horizontal scaling. This forces subscribers to process messages in each partition in order and limits the number of concurrent clients to the number of partitions."

Fuente: `https://docs.cloud.google.com/pubsub/docs/overview`, verbatim.

**Contraste necesario**: el otro producto de streaming de Google, *Managed Service for Apache Kafka*, **sí** expone una unidad, y no es el broker:

> "To size or scale a Managed Service for Apache Kafka cluster, you need only set the total vCPU count and RAM size for the cluster. Management of brokers, including storage, is fully automated."

Fuente: `https://docs.cloud.google.com/managed-service-for-apache-kafka/docs/overview`, verbatim. Es decir: vCPU + RAM agregados de clúster, no conteo de brokers como en MSK. El skill no debe decir "en GCP se escala por brokers".

---

## 2. Cuáles ofrecen un modo serverless / on-demand y cómo lo llama exactamente el proveedor

**VEREDICTO GLOBAL: CORRECTED**

La corrección está en Kinesis: el nombre "on-demand" a secas ya no es el nombre completo del modo en la documentación actual, y la propia documentación de AWS se contradice entre páginas.

### 2.1 AWS MSK — **VEREDICTO: SUPPORTED**. Nombre exacto: **MSK Serverless**, y es un *cluster type*, no un modo de facturación.

> "MSK Serverless is a cluster type for Amazon MSK that makes it possible for you to run Apache Kafka without having to manage and scale cluster capacity. It automatically provisions and scales capacity while managing the partitions in your topic, so you can stream data without thinking about right-sizing or scaling clusters. MSK Serverless offers a throughput-based pricing model, so you pay only for what you use. Consider using a serverless cluster if your applications need on-demand streaming capacity that scales up and down automatically."

Fuente: `https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html`, verbatim.

Un detalle operativo que la fuente marca como restricción dura y que el skill debe mencionar si habla de MSK Serverless:

> "MSK Serverless requires IAM access control for all clusters. Apache Kafka access control lists (ACLs) are not supported."

Fuente: misma página, verbatim.

### 2.2 AWS Kinesis Data Streams — **VEREDICTO: CORRECTED**. No es "on-demand"; hoy son **tres** modos, dos de ellos on-demand.

La página de referencia de modos enumera tres:

> "A mode determines how the capacity of a data stream is managed and how you're charged for the usage of your data stream. In Amazon Kinesis Data Streams, you can choose **On-demand Standard**, **On-demand Advantage**, and **provisioned** as the mode for your data streams."

> "**On-demand Standard** - Data streams with an on-demand mode require no capacity planning and automatically scale to handle gigabytes of write and read throughput per minute. With the on-demand mode, Kinesis Data Streams automatically manages the shards in order to provide the necessary throughput."

> "**On-demand Advantage** - An account-level mode that enables more capabilities and provides a simpler pricing structure for on-demand streams. In this mode, you can proactively warm a stream's write throughput capacity at any time, or trigger a scale-down if a transient data burst has caused the stream to scale significantly beyond its warm capacity."

Fuente: `https://docs.aws.amazon.com/streams/latest/dev/how-do-i-size-a-stream.html`, sección "What are the different modes in Kinesis Data Streams?", verbatim (se elidió de la cita de *On-demand Advantage* la frase final sobre porcentajes de descuento de precio).

**La simplificación popular vs. lo que dice la fuente — ambas registradas.** La página de conceptos, en el mismo conjunto documental, sigue afirmando que hay solo dos modos:

> "Currently, in Kinesis Data Streams, you can choose between an **on-demand** mode and a **provisioned** mode for your data streams."

Fuente: `https://docs.aws.amazon.com/streams/latest/dev/key-concepts.html`, entrada "Capacity Mode", verbatim.

Es decir: **la documentación de AWS se contradice a sí misma** en el nivel de granularidad. `key-concepts.html` (dos modos) está desactualizada respecto a `how-do-i-size-a-stream.html` (tres modos, con *On-demand Advantage* como setting a nivel de cuenta y no de stream). El skill debe decir "modo on-demand" como familia, y **no** afirmar que existan exactamente dos modos.

Matiz adicional que sí importa conceptualmente (y no requiere cifras): en on-demand el shard **sigue existiendo** como mecanismo interno, solo que gestionado por el servicio; sigue habiendo hot-shard por clave de partición desbalanceada.

> "With the on-demand mode (same as with the provisioned capacity mode), you must specify a partition key with each record to write data into your data stream. Kinesis Data Streams uses your partition keys to distribute data across shards."

> "In the on-demand mode, Kinesis Data Streams splits the shards evenly when it detects an increase in traffic. However, it does not detect and isolate hash keys that are driving a higher portion of incoming traffic to a particular shard. If you are using highly uneven partition keys you may continue to receive write exceptions. For such use cases, we recommend that you use the provisioned capacity mode that supports granular shard splits."

Fuente: misma página, sección "Handle read and write throughput exceptions", verbatim.

### 2.3 Azure Event Hubs — **VEREDICTO: SUPPORTED** (en el sentido de que **no ofrece** un modo serverless/on-demand nombrado).

Ninguna de las páginas consultadas documenta un tier o modo llamado "serverless" o "on-demand" para Event Hubs. Los tiers documentados son Basic, Standard, Premium y Dedicated:

> "The following table shows the list of features that are available (or not available) in a specific tier of Azure Event Hubs. Feature Basic Standard Premium Dedicated"

Fuente: `https://learn.microsoft.com/en-us/azure/event-hubs/compare-tiers`, verbatim (encabezado de la tabla de features).

La capacidad se **precompra**, que es el opuesto conceptual de on-demand:

> "Throughput units are prepurchased units of capacity."

Fuente: `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-scalability`, verbatim.

Lo más cercano a autoscaling es **Auto-inflate**, y Microsoft es preciso en que solo escala *hacia arriba* las TUs, no en que elimine la unidad:

> "The **Auto-inflate** feature of Event Hubs automatically scales up by increasing the number of throughput units to meet usage needs."

Fuente: misma página, verbatim.

**Hedge registrado**: la página de marketing/overview usa vocabulario que *suena* serverless sin nombrar un modo serverless:

> "**Zero infrastructure management**: Fully managed service with automatic patching, scaling, and monitoring. No clusters to provision or maintain."

> "**Flexible pricing**: Choose from consumption-based or dedicated capacity models. Scale from megabytes to terabytes based on demand."

Fuente: `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-about`, sección "Why choose Azure Event Hubs?", verbatim.

El skill **no** debe traducir "consumption-based" ni "zero infrastructure management" como "Event Hubs tiene un modo serverless": no existe tal producto nombrado, y el usuario sigue eligiendo y pagando TUs/PUs/CUs.

**Advertencia de honestidad** (mismo criterio aplicado en §3.3 para Kinesis): en ninguna de las páginas consultadas Microsoft afirma explícitamente "Event Hubs does not offer a serverless tier". El veredicto SUPPORTED sobre un **negativo** se apoya en evidencia positiva —la tabla de tiers enumera exactamente Basic/Standard/Premium/Dedicated y ninguno se llama serverless; la capacidad es *"prepurchased units of capacity"*, que es el opuesto conceptual de on-demand; y Auto-inflate *"scales up by increasing the number of throughput units"*, es decir sigue habiendo unidad— más la ausencia total del término como nombre de modo en la documentación de producto. Es suficiente para el skill, pero el skill debe formularlo como "**Event Hubs no documenta ningún modo llamado serverless; su capacidad se precompra en TU/PU/CU**", no como "Microsoft declara que Event Hubs no es serverless".

### 2.4 GCP Pub/Sub — **VEREDICTO: SUPPORTED**. Google usa literalmente la palabra "serverless" como descriptor del servicio.

> "Pub/Sub is a wholly managed, serverless, and globally distributed service that uses Google Cloud infrastructure. It automatically scales to handle your workload, so you don't need to worry about managing infrastructure."

Fuente: `https://docs.cloud.google.com/pubsub/docs/choose-pubsub-kafka`, sección "Operational simplicity of Pub/Sub", verbatim.

**Hedge registrado**: "serverless" aquí es un adjetivo del servicio entero, **no el nombre de un modo de capacidad opcional**. No hay un "Pub/Sub Serverless mode" que se pueda contrastar con un "Pub/Sub Provisioned mode" — Pub/Sub no tiene el otro lado. Esto es asimétrico respecto a MSK (donde Serverless es un *cluster type* alternativo a Provisioned) y a Kinesis (donde on-demand es un *mode* alternativo a provisioned). El skill debe respetar la asimetría: en AWS es una **elección**, en GCP es la **naturaleza del producto**.

---

## 3. Cuáles presentan superficie de protocolo Kafka y cuáles una API propietaria — el eje de acoplamiento

**VEREDICTO GLOBAL: CORRECTED**

Sub-veredictos: MSK SUPPORTED, Event Hubs SUPPORTED (con hedges importantes en la terminología y limitaciones documentadas), Kinesis SUPPORTED (con la advertencia de que parte de la evidencia es negativa), Pub/Sub **CORRECTED** — Google sí documenta hoy una oferta Kafka, pero es un **producto distinto**, no un endpoint de Pub/Sub.

### 3.1 AWS MSK — **VEREDICTO: SUPPORTED**. No es "compatible con Kafka": *es* Kafka.

> "Amazon Managed Streaming for Apache Kafka (Amazon MSK) is a fully managed service that enables you to build and run applications that use Apache Kafka to process streaming data. Amazon MSK provides the control-plane operations, such as those for creating, updating, and deleting clusters. It lets you use Apache Kafka data-plane operations, such as those for producing and consuming data. **It runs open-source versions of Apache Kafka.** This means existing applications, tooling, and plugins from partners and the Apache Kafka community are supported without requiring changes to application code."

Fuente: `https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html`, verbatim (negrita añadida por mí; el original no la lleva).

Para MSK Serverless AWS baja un escalón el registro y sí usa "compatible":

> "MSK Serverless is fully compatible with Apache Kafka, so you can use any compatible client applications to produce and consume data."

Fuente: `https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html`, verbatim.

**Hedge registrado**: AWS distingue "runs open-source versions of Apache Kafka" (MSK Provisioned) de "fully compatible with Apache Kafka" (MSK Serverless). Son formulaciones distintas y el skill no debe aplanarlas a una sola.

### 3.2 Azure Event Hubs — **VEREDICTO: SUPPORTED**, y aquí es donde la terminología del proveedor **debe** citarse sin suavizar, porque Microsoft usa al menos cinco formulaciones distintas.

Formulación 1 — *endpoint*:

> "Azure Event Hubs provides an Apache Kafka endpoint on an event hub, which enables users to connect to the event hub using the Kafka protocol. You can often use an event hub's Kafka endpoint from your applications without any code changes. You modify only the configuration, that is, update the connection string in configurations to point to the Kafka endpoint exposed by your event hub instead of pointing to a Kafka cluster."

Fuente: `https://learn.microsoft.com/en-us/azure/event-hubs/azure-event-hubs-apache-kafka-overview`, sección "Overview", verbatim. Nótese el hedge de Microsoft: "**often** use ... without **any** code changes", no "siempre".

Formulación 2 — *implements the same protocol*:

> "As a cloud service, Event Hubs uses a single stable virtual IP address as the endpoint, so clients don't need to know about the brokers or machines within a cluster. Even though Event Hubs implements the same protocol, this difference means that all Kafka traffic for all partitions is predictably routed through this one endpoint rather than requiring firewall access for all brokers of a cluster."

Fuente: misma página, sección "Key differences between Apache Kafka and Azure Event Hubs", verbatim.

Formulación 3 — *built-in Apache Kafka compatibility*:

> "As a native Azure service with built-in Apache Kafka compatibility, Event Hubs enables you to run existing Kafka workloads without code changes or cluster management overhead."

Fuente: `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-about`, verbatim.

Formulación 4 — *multi-protocol engine que soporta nativamente*:

> "Event Hubs is a multi-protocol event streaming engine that natively supports Apache Kafka, AMQP 1.0, and HTTPS. You can bring Kafka workloads to Event Hubs without code changes, cluster management, or third-party Kafka services."

Fuente: misma página, sección "Apache Kafka compatibility", verbatim.

Formulación 5 — tabla de atributos:

> "| **Protocols supported** | Apache Kafka, AMQP 1.0, HTTPS |"

Fuente: misma página, tabla "At a glance", verbatim.

**Limitaciones que Microsoft declara explícitamente** (todas de `azure-event-hubs-apache-kafka-overview`, verbatim):

> "This feature is supported only in the \*\*standard, premium, and **dedicated** tiers.
> Event Hubs for Apache Kafka Ecosystems support Apache Kafka version 1.0 and later."

(la corrupción de asteriscos `\*\*standard` está en el original renderizado; se transcribe tal cual para no adulterar la cita — la lectura es "standard, premium, and dedicated tiers". El tier **Basic queda fuera**.)

> "Kafka Streams is currently in public preview in Premium and Dedicated tier."

> "Kafka Transactions is currently in public preview in Premium and Dedicated tier."

> "Kafka compression for Event Hubs is currently supported only in Premium and Dedicated tiers." — y sobre el algoritmo: "Azure Event Hubs currently supports `gzip` compression."

> "Generated shared access signature tokens aren't supported when using the Event Hubs for Apache Kafka endpoint."

Y la válvula de escape que el propio Microsoft documenta, que es la admisión más honesta de que la superficie no es completa:

> "If you need specific features of Apache Kafka that aren't available through the Event Hubs for Apache Kafka interface or if your implementation pattern exceeds the Event Hubs quotas, you can also run a native Apache Kafka cluster in Azure HDInsight."

Fuente: misma página, verbatim.

Finalmente, la diferencia arquitectónica que importa para el eje de acoplamiento:

> "While Apache Kafka is software you typically need to install and operate, Event Hubs is a fully managed, cloud-native service. There are no servers, disks, or networks to manage and monitor and no brokers to consider or configure, ever."

Fuente: misma página, verbatim.

**Síntesis del hedge**: Event Hubs expone el **protocolo** de Kafka sobre una implementación que no es Kafka. Microsoft nunca dice "Event Hubs is Apache Kafka" ni "runs Apache Kafka" — dice *endpoint*, *implements the same protocol*, *compatibility*, *natively supports*. El skill debe usar "endpoint / superficie de protocolo Kafka", no "es Kafka gestionado".

### 3.3 AWS Kinesis Data Streams — **VEREDICTO: SUPPORTED**, con la advertencia metodológica de que parte de la evidencia es negativa.

La superficie documentada de escritura y lectura es enteramente de AWS:

> "You can use Kinesis Data Streams `PutRecord` and `PutRecords` APIs to write data into your data streams in any mode. To retrieve data, all three modes support default consumers that use the `GetRecords` API and Enhanced Fan-Out (EFO) consumers that use the `SubscribeToShard` API."

Fuente: `https://docs.aws.amazon.com/streams/latest/dev/how-do-i-size-a-stream.html`, verbatim.

> "There are two different operations in the Kinesis Data Streams API that add data to a stream, `PutRecords` and `PutRecord`."

Fuente: `https://docs.aws.amazon.com/streams/latest/dev/developing-producers-with-sdk.html`, verbatim.

Y el vocabulario es propio de Kinesis, sin correspondencia con Kafka: *shard*, *sequence number*, *data record*, *Kinesis Client Library*, *enhanced fan-out*.

**Advertencia de honestidad**: en ninguna de las páginas consultadas AWS afirma explícitamente "Kinesis Data Streams does not support the Apache Kafka protocol". La conclusión de "API propietaria" se apoya en evidencia positiva (la API documentada es de AWS: `PutRecord`/`PutRecords`/`GetRecords`/`SubscribeToShard`) más ausencia total de cualquier mención a Kafka en la documentación de Kinesis Data Streams. Eso es suficiente para el skill, pero el skill debe formularlo como "la API documentada de Kinesis es propietaria de AWS", no como "AWS declara que Kinesis no habla Kafka".

### 3.4 GCP Pub/Sub — **VEREDICTO: CORRECTED**.

**Parte SUPPORTED**: Pub/Sub tiene API propietaria.

> "APIs. Pub/Sub uses standard gRPC and REST service API technologies along with client libraries for several languages."

Fuente: `https://docs.cloud.google.com/pubsub/docs/overview`, verbatim.

**Parte CORRECTED**: la simplificación popular "Google no tiene oferta Kafka" es falsa hoy, pero la lectura opuesta ("Pub/Sub es compatible con Kafka") también lo es. Lo que Google documenta son **dos cosas separadas, ninguna de las cuales es un endpoint Kafka sobre Pub/Sub**:

**(a) Un producto gestionado de Kafka distinto de Pub/Sub:**

> "Managed Service for Apache Kafka is a Google Cloud service that helps you run secure, scalable open source Apache Kafka clusters."

Fuente: `https://docs.cloud.google.com/managed-service-for-apache-kafka/docs/overview`, verbatim.

Y el argumento de portabilidad que Google mismo usa para contrastar los dos productos:

> "While Pub/Sub's autoscaling and global data distribution make it easier to operate, Apache Kafka APIs are much more broadly adopted. If you plan to use independent messaging systems in different on-premises or cloud-provider environments, Managed Service for Apache Kafka can give you a more consistent experience across your applications. This is because you can standardize on Kafka and use the same API to communicate with the Kafka service in each environment."

Fuente: `https://docs.cloud.google.com/pubsub/docs/choose-pubsub-kafka`, sección "Portability of Managed Service for Apache Kafka", verbatim. **Esta es la cita central del eje de acoplamiento del skill, y viene del propio vendor.**

**(b) Un conector, no un protocolo:**

> "This document describes how to integrate Apache Kafka and Pub/Sub by using the Pub/Sub Group Kafka Connector."

Fuente: `https://docs.cloud.google.com/pubsub/docs/connect_kafka`, verbatim.

> "The Pub/Sub Kafka connector lets you migrate your Kafka infrastructure to Pub/Sub in phases. You can configure the Pub/Sub connector to forward all messages on specific topics from Kafka to Pub/Sub."

Fuente: `https://docs.cloud.google.com/pubsub/docs/migrating-from-kafka-to-pubsub`, verbatim.

**Conclusión precisa para el skill**: Pub/Sub **no** expone superficie de protocolo Kafka. Google ofrece Kafka en GCP a través de un producto separado (*Managed Service for Apache Kafka*), y ofrece puentes Kafka↔Pub/Sub mediante un **connector** de Kafka Connect. Decir "GCP no tiene Kafka" es incorrecto; decir "Pub/Sub es Kafka-compatible" también.

---

## 4. Si el ordenamiento está acotado por shard/partición en cada uno

**VEREDICTO GLOBAL: CORRECTED**

Sub-veredictos: MSK SUPPORTED, Event Hubs SUPPORTED, Kinesis **CORRECTED** (la garantía de escritura no es simétrica con Kafka), Pub/Sub **CORRECTED** (el alcance no es una partición, y la propia documentación de Google se contradice entre páginas).

### 4.1 AWS MSK / Apache Kafka — **VEREDICTO: SUPPORTED**. Coincide con lo que la skill `streaming-data-engineering` ya enseña.

> "When a new event is published to a topic, it is actually appended to one of the topic's partitions. Events with the same event key (e.g., a customer or vehicle ID) are written to the same partition, and Kafka guarantees that any consumer of a given topic-partition will always read that partition's events in exactly the same order as they were written."

Fuente: `https://kafka.apache.org/intro`, sección "Main Concepts and Terminology", verbatim.

Esta fuente aplica a MSK porque AWS declara ejecutar el mismo software: "It runs open-source versions of Apache Kafka" (`what-is-msk.html`, ya citado en 3.1). No se encontró en la documentación de MSK una afirmación propia sobre ordenamiento; se registra esa ausencia explícitamente.

### 4.2 Azure Event Hubs — **VEREDICTO: SUPPORTED**. Ordenamiento por partición, con clave de partición como mecanismo de agrupación, igual que Kafka.

> "Specifying a partition key enables keeping related events together in the same partition and in the exact order in which they arrived. The partition key is some string that is derived from your application context and identifies the interrelationship of the events. A sequence of events identified by a partition key is a *stream*. A partition is a multiplexed log store for many such streams."

Fuente: `https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-scalability`, sección "Mapping of events to partitions", verbatim.

> "A partition can be thought of as a commit log."

Fuente: misma página, sección "Partitions", verbatim.

> "Maintaining a log that preserves the order of events requires that these events are being kept together in the underlying storage and its replicas and that results in a throughput ceiling for such a log."

Fuente: misma página, verbatim.

**Caveat operativo que el skill debe recoger** (aplica igual en Kafka, pero Microsoft lo dice de forma inusualmente directa):

> "For an event hub in a premium or dedicated tier, you can increase the partition count after its creation, but you can't decrease them. The distribution of streams across partitions will change when it's done as the mapping of partition keys to partitions changes, so you should try hard to avoid such changes if the relative order of events matters in your application."

Fuente: misma página, verbatim.

Y sobre la tensión entre ordenamiento y paralelismo:

> "If you need absolute order preservation across all events or only a handful of substreams, you might not be able to take advantage of many partitions."

Fuente: misma página, verbatim.

### 4.3 AWS Kinesis Data Streams — **VEREDICTO: CORRECTED**. El *routing* a shard sí es análogo a Kafka; la garantía de orden **de escritura** no lo es.

Lo que sí es equivalente a Kafka — enrutamiento determinista por clave:

> "A partition key is used to group data within the stream. A data record is assigned to a shard within the stream based on its partition key. Specifically, Kinesis Data Streams uses the partition key as input to a hash function that maps the partition key (and associated data) to a specific shard."

> "As a result of this hashing mechanism, all data records with the same partition key map to the same shard within the stream. However, if the number of partition keys exceeds the number of shards, some shards necessarily contain records with different partition keys."

Fuente: `https://docs.aws.amazon.com/streams/latest/dev/developing-producers-with-sdk.html`, verbatim.

Y del lado de lectura, el orden dentro del shard sí es total:

> "Whether or not you use `SequenceNumberForOrdering`, records that Kinesis Data Streams receives through a `GetRecords` call are strictly ordered by sequence number."

Fuente: misma página, verbatim.

**Aquí está la corrección.** En Kafka el broker asigna offsets crecientes por el mero hecho de hacer append a la partición. En Kinesis, el orden de escritura **no** está garantizado por defecto y requiere un parámetro explícito del productor:

> "When puts occur in quick succession, the returned sequence numbers are not guaranteed to increase because the put operations appear essentially as simultaneous to Kinesis Data Streams. To guarantee strictly increasing sequence numbers for the same partition key, use the `SequenceNumberForOrdering` parameter, as shown in the PutRecord example code sample."

> "The `SequenceNumberForOrdering` parameter ensures strictly increasing sequence numbers for the same partition key. `SequenceNumberForOrdering` does not provide ordering of records across multiple partition keys."

Fuente: misma página, verbatim.

Y ese parámetro **no existe** en la operación batch, que es la que AWS recomienda para throughput:

> "However, the `PutRecord` parameter `SequenceNumberForOrdering` is not included in a `PutRecords` call. The `PutRecords` operation attempts to process all records in the natural order of the request."

Fuente: misma página, verbatim. Nótese el hedge: "**attempts to** process ... in the natural order", no "guarantees".

**Implicación**: la afirmación plana "en Kinesis el ordenamiento es por shard, igual que en Kafka" es imprecisa. Lo correcto: *el alcance* del ordenamiento es el shard (igual que Kafka), pero *la garantía de escritura* es más débil — el orden estricto por clave requiere `PutRecord` con `SequenceNumberForOrdering` (serializando escrituras), y `PutRecords` solo "intenta" respetar el orden de la petición.

### 4.4 GCP Pub/Sub — **VEREDICTO: CORRECTED**. Este es el caso complicado y hay que citarlo exacto.

El alcance del ordenamiento es la **ordering key**, no una partición, porque Pub/Sub no tiene particiones (ver 1.4):

> "An *ordering key* is a string that identifies related messages that should be ordered. Examples of ordering keys include customer IDs or the primary key of a row in a database. An ordering key can be up to […] in length. To achieve message ordering, set the same ordering key on all related messages that should be received in order. In addition, you must publish all messages with the same ordering key in the same region."

Fuente: `https://docs.cloud.google.com/pubsub/docs/ordering`, sección "Overview of message ordering", verbatim con la longitud máxima elidida.

**La garantía en sí, palabra por palabra** — y aquí el hedge es el punto entero:

> "**Within-key ordering**: Messages published with the same ordering key are expected to be received in order. Assume that for ordering key A, you publish messages 1, 2, and 3. With ordering enabled, 1 is expected to be delivered before 2 and 2 is expected to be delivered before 3.
>
> **Across-key ordering**: Messages published with different ordering keys are not expected to be received in order. Assume you have ordering keys A and B. For ordering key A, messages 1 and 2 are published in order. For ordering key B, messages 3 and 4 are published in order. However, message 1 could arrive before or after message 4."

Fuente: misma página, verbatim.

**Hedge crítico registrado**: Google escribe "are **expected to be** received in order", no "are guaranteed to be received in order". Es una formulación deliberadamente más débil que la de Kafka ("Kafka **guarantees** that any consumer of a given topic-partition will always read that partition's events in exactly the same order"). El skill no debe presentar la garantía de Pub/Sub con el mismo verbo que la de Kafka.

Restricción de región, con asimetría publisher/subscriber:

> "To be delivered in order, the publisher client must publish the messages in the same region. However, subscribers can connect to any region and the ordering guarantee is still maintained."

Fuente: misma página, verbatim.

Clave vacía = sin orden:

> "Messages with an empty ordering key are not ordered."

Fuente: misma página, verbatim.

Costo del ordenamiento, en palabras de Google:

> "**Performance tradeoffs**: Ordered delivery does come with some tradeoffs. Compared with unordered delivery, ordered delivery decreases publish availability and increases end-to-end message delivery latency. In the ordered delivery case, failover requires coordination to ensure the messages are written to and read in the correct order."

Fuente: misma página, verbatim.

**La contradicción interna de Google, registrada tal cual.** La tabla comparativa de la guía de migración describe el ordenamiento de Pub/Sub como "dentro de topics", lo que contradice la página de ordering ("within-key"):

> "| Message ordering | Yes within partitions | Yes within topics |"

Fuente: `https://docs.cloud.google.com/pubsub/docs/migrating-from-kafka-to-pubsub`, tabla "Comparing features", verbatim (columna izquierda = Apache Kafka, columna derecha = Pub/Sub).

Mientras que la tabla de la guía de elección de producto sí lo dice bien:

> "| Ordered delivery | Offers ordering within keys. […] throughput per fine-grained ordering key | Offers ordering within partitions. Per-partition ordering up to throughput capacity of a partition. |"

Fuente: `https://docs.cloud.google.com/pubsub/docs/choose-pubsub-kafka`, tabla comparativa, verbatim con la cifra de throughput por clave elidida (columna izquierda = Pub/Sub, columna derecha = Managed Service for Apache Kafka).

**El skill debe seguir `pubsub/docs/ordering` y `choose-pubsub-kafka` ("within keys"), no la tabla de `migrating-from-kafka-to-pubsub` ("within topics"), que es imprecisa.** "Ordering within topics" leído literalmente implicaría un orden total por topic, que Pub/Sub explícitamente no da ("Across-key ordering: Messages published with different ordering keys are not expected to be received in order").

**Cardinalidad — la ventaja real de diseño**, que el skill debería mencionar porque es lo que hace la abstracción de Pub/Sub distinta y no solo peor:

> "ordering keys are expected to have a much higher cardinality than partitions"

Fuente: `https://docs.cloud.google.com/pubsub/docs/ordering`, verbatim.

Y el efecto de la redelivery sobre el orden, que hace de la deduplicación un requisito y no un adorno (coherente con lo hallado sobre Debezium el 2026-08-07):

> "Message redelivery: Pub/Sub delivers each message at least once"

Fuente: misma página, verbatim.

---

## Resumen de veredictos

| # | Claim | Sub-veredictos por servicio | Veredicto global |
|---|---|---|---|
| 1 | Unidad de escalado expuesta, con el término del proveedor | MSK **SUPPORTED** (*broker nodes*, solo Provisioned) · Kinesis **SUPPORTED** (*shard*, solo provisioned mode) · Event Hubs **SUPPORTED** (TU / PU / CU según tier — **tres** unidades sobre cuatro tiers, no dos) · Pub/Sub **SUPPORTED** (ninguna; "does not have partitions") | **SUPPORTED** — los cuatro términos son los del proveedor. *Ampliación, no corrección:* la unidad depende del modo/tier en tres de los cuatro servicios; MSK y Kinesis también dejan de exponer unidad en su modo serverless/on-demand |
| 2 | Modo serverless / on-demand y su nombre exacto | MSK **SUPPORTED** (*MSK Serverless*, un *cluster type*) · Kinesis **CORRECTED** (hoy son *On-demand Standard*, *On-demand Advantage* y *Provisioned*; la propia doc de AWS se contradice) · Event Hubs **SUPPORTED** (no existe modo serverless; capacidad *prepurchased*, lo más cercano es *Auto-inflate*) · Pub/Sub **SUPPORTED** ("wholly managed, serverless") | **CORRECTED** |
| 3 | Superficie Kafka vs. API propietaria (eje de acoplamiento) | MSK **SUPPORTED** ("runs open-source versions of Apache Kafka") · Event Hubs **SUPPORTED** con hedges (*Kafka endpoint* / *implements the same protocol* / *built-in compatibility*; solo standard/premium/dedicated; Streams y Transactions en public preview; compresión solo premium/dedicated y solo gzip) · Kinesis **SUPPORTED** (API AWS: `PutRecord`/`PutRecords`/`GetRecords`/`SubscribeToShard`; parte de la evidencia es negativa) · Pub/Sub **CORRECTED** (API propia gRPC/REST, **pero** Google documenta *Managed Service for Apache Kafka* como producto separado y un *Pub/Sub Group Kafka Connector*) | **CORRECTED** |
| 4 | Ordenamiento acotado por shard/partición | MSK **SUPPORTED** (Kafka garantiza orden por topic-partition) · Event Hubs **SUPPORTED** (partición como *commit log*, clave de partición preserva "the exact order in which they arrived") · Kinesis **CORRECTED** (alcance = shard, pero el orden de escritura requiere `SequenceNumberForOrdering`, ausente en `PutRecords`) · Pub/Sub **CORRECTED** (alcance = *ordering key*, no partición; el verbo es "are **expected to be** received in order", no "guaranteed"; restricción de región; contradicción documental entre páginas de Google) | **CORRECTED** |

Ninguna claim quedó UNSUPPORTED: todas las fuentes fueron alcanzables y todas las citas fueron verificadas contra HTML crudo. La única sustitución de fuente fue `kafka.apache.org/documentation/` → `kafka.apache.org/intro` por renderizado JS, documentada en la Nota de método.

---

## Implicación para el skill

**Sobre la unidad de escalado (claim 1):**

- Los cuatro términos del proveedor están confirmados y la skill puede usarlos tal cual. Lo que la skill debe añadir —hallazgo de esta verificación, no corrección de la claim— es que **la unidad de escalado depende del modo o tier elegido en tres de los cuatro servicios**; solo Pub/Sub nunca expone ninguna. Nombrar la unidad sin nombrar el modo que la hace visible ("Kinesis se escala por shards") es incompleto, y tratar la dependencia de tier como una rareza exclusiva de Event Hubs sería inexacto.
- Event Hubs se dimensiona en **tres** unidades sobre cuatro tiers (Basic y Standard → *throughput unit*; Premium → *processing unit*; Dedicated → *capacity unit*). El encabezado de la propia página de Microsoft que solo nombra dos está incompleto.
- Marcar la asimetría conceptual: en Kinesis el **shard es a la vez unidad de capacidad y unidad de ordenamiento**; en Event Hubs la **partición no es unidad de capacidad** (esa es la TU/PU/CU) sino solo de organización y paralelismo. Confundirlos lleva a dimensionar mal en Azure.
- Para Google, si se menciona *Managed Service for Apache Kafka*, la unidad es **vCPU + RAM agregados de clúster**, no conteo de brokers. No copiar el modelo de MSK.

**Sobre serverless / on-demand (claim 2):**

- No decir "Kinesis tiene dos modos". Decir "modo on-demand vs. provisioned" como familia, sin comprometerse con un conteo — la documentación de AWS actualmente lista tres y se contradice entre páginas.
- No decir que Event Hubs tiene modo serverless. Tiene *Auto-inflate*, que **solo escala hacia arriba** las TUs y no elimina la unidad. El lenguaje de marketing ("zero infrastructure management", "consumption-based") no es un nombre de producto.
- Respetar la asimetría: en AWS "serverless / on-demand" es una **elección** frente a una alternativa provisioned; en GCP es la **naturaleza** del producto (no hay Pub/Sub provisioned).

**Sobre el eje de acoplamiento (claim 3) — el punto que este documento existe para blindar:**

- Tres registros distintos, no dos: **(a) es Kafka** (MSK: "runs open-source versions of Apache Kafka"); **(b) habla el protocolo de Kafka sin ser Kafka** (Event Hubs: "provides an Apache Kafka endpoint", "implements the same protocol"); **(c) API propietaria** (Kinesis, Pub/Sub).
- Al describir Event Hubs, usar "endpoint / superficie de protocolo Kafka", nunca "es Kafka gestionado". Y si el skill afirma que se migra "sin cambios de código", debe replicar el hedge de Microsoft ("you can **often** use ... **without any code changes**") y mencionar que la cobertura es parcial: tier Basic excluido, Kafka Streams y Kafka Transactions en public preview y solo en Premium/Dedicated, compresión solo Premium/Dedicated y solo gzip, tokens SAS generados no soportados en el endpoint Kafka.
- **No escribir "GCP no tiene Kafka".** Google documenta *Managed Service for Apache Kafka* como producto separado, y su propia doc lo justifica exactamente por el eje de acoplamiento ("Apache Kafka APIs are much more broadly adopted ... you can standardize on Kafka and use the same API to communicate with the Kafka service in each environment"). Esa frase es el mejor soporte vendor-side que el skill puede citar para su tesis de portabilidad.
- **Tampoco escribir "Pub/Sub es Kafka-compatible".** El puente documentado es un *Kafka Connect connector*, no un protocolo.
- Para Kinesis, formular como "la API documentada es propietaria de AWS", no como "AWS declara que Kinesis no habla Kafka" — AWS no hace esa declaración negativa.

**Sobre el ordenamiento (claim 4):**

- MSK y Event Hubs encajan sin fricción con lo que `streaming-data-engineering` ya enseña para Kafka: orden total dentro de la partición, clave de partición como mecanismo de agrupación, y la advertencia de que cambiar el conteo de particiones re-mapea las claves y rompe el orden relativo.
- **Kinesis necesita una frase propia.** El alcance es el shard, pero la garantía de escritura es más débil que la de Kafka: `PutRecords` (la operación recomendada para throughput) solo "intenta" respetar el orden de la petición y no admite `SequenceNumberForOrdering`; el orden estricto por clave exige `PutRecord` serializado. Decir "igual que Kafka" sería un error.
- **Pub/Sub necesita dos frases propias.** Primera: el alcance es la *ordering key*, no una partición — y como las claves tienen cardinalidad mucho mayor que las particiones, esto es una ventaja de paralelismo, no solo una garantía más débil. Segunda: el verbo del vendor es "are **expected to be** received in order", más débil que el "guarantees" de Kafka, y hay una restricción de región del lado del publisher (no del subscriber). Añadir que activar el orden tiene costo declarado: "decreases publish availability and increases end-to-end message delivery latency".
- Ignorar la tabla de `migrating-from-kafka-to-pubsub` que dice "ordering ... Yes within topics": contradice a `pubsub/docs/ordering` y a `choose-pubsub-kafka`, y leída literalmente implicaría un orden total por topic que Pub/Sub explícitamente no ofrece.

**Sobre la regla de "sin números":** las cuatro claims son verificables sin citar una sola cifra. El único punto donde una cifra sería tentadora es el throughput por ordering key de Pub/Sub (para explicar por qué el ordenamiento limita el paralelismo por clave); se puede expresar cualitativamente — "el throughput de publicación está acotado por clave de ordenamiento" — sin dar el valor.
