# Research: almacenes NoSQL de serving — modos de capacidad, unidad de throughput, escalado, distribución multirregión y dónde traza cada proveedor la frontera del modelado (Cosmos DB / Bigtable / DynamoDB)

**Fecha:** 2026-08-08 (serie de entrega). **Fecha real de consulta de todas las páginas: 2026-08-12.** Todo nombre de producto, de modo y de unidad queda sellado con esa fecha de comprobación.

**Alcance:** verificación de las 5 claims que la skill `iac-cloud-data-engineering` necesita antes de nombrar un almacén NoSQL más allá de DynamoDB en el arquetipo 4 (`references/platform-archetypes.md`, "NoSQL serving store"). Hoy esa sección enuncia que `scaling granularity` "es el modo de capacidad" y exige declarar "la unidad junto con el modo que la expone, de la propia página del proveedor, para el tier que realmente se compra" — pero no nombra ningún producto salvo DynamoDB, y lo nombra solo por vía de la skill de modelado.

**Páginas consultadas** (todas el 2026-08-12):

Azure Cosmos DB
- `https://learn.microsoft.com/en-us/azure/cosmos-db/request-units`
- `https://learn.microsoft.com/en-us/azure/cosmos-db/throughput-serverless`
- `https://learn.microsoft.com/en-us/azure/cosmos-db/provision-throughput-autoscale`
- `https://learn.microsoft.com/en-us/azure/cosmos-db/distribute-data-globally`
- `https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/modeling-data`

Google Cloud Bigtable
- `https://cloud.google.com/bigtable/docs/instances-clusters-nodes`
- `https://cloud.google.com/bigtable/docs/autoscaling`
- `https://cloud.google.com/bigtable/docs/replication-overview`
- `https://cloud.google.com/bigtable/docs/data-boost-overview`
- `https://cloud.google.com/bigtable/docs/schema-design`
- `https://cloud.google.com/bigtable/pricing`

Amazon DynamoDB
- `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/capacity-mode.html`
- `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/on-demand-capacity-mode.html`
- `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/provisioned-capacity-mode.html`
- `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html`
- `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-general-nosql-design.html`

**Nota de método**: todas las páginas se descargaron con `curl -A "Mozilla/5.0 …"` y se convirtieron a texto plano con un script Python de stripping de HTML; los archivos quedaron en un directorio scratchpad local de la sesión y cada cita es grepeable en ellos. No hubo ningún 403 y no fue necesario `WebSearch` en esta ronda. **No se usó el MCP de Microsoft Learn como fuente citable**; las citas de Cosmos DB provienen del HTML servido por `learn.microsoft.com`.

**Nota sobre elisión de cifras**: por la regla no-numbers del repo, ninguna cifra se reproduce. Esto afecta especialmente a este documento porque las tres documentaciones definen sus unidades **por equivalencia con un tamaño de ítem** (`one read capacity unit … for an item up to X KB`). En esas citas el tamaño se elide como `[…]` y la definición de la unidad se conserva íntegra, porque la unidad es el objeto de las claims 1 y 3. Los incrementos de provisión de RU/s, los importes por hora y los multiplicadores de nodo también se eliden. **Los identificadores de edición y de modo — `Enterprise`, `Enterprise Plus`, `MREC`, `MRSC` — no son cifras** y se conservan: son nombres de tier, y el arquetipo 4 exige nombrar el tier. Se conserva igualmente, dentro de citas verbatim de Google, el **suelo semántico "al menos uno"** (`"Each cluster has at least 1 node"`, `"instances that have only 1 cluster don't use replication"`): elidirlo destruiría la afirmación, que es exactamente que el suelo no es cero. No es precio, cuota, límite, tipo de instancia ni tamaño de nodo, y no es una cantidad calculada por este documento.

---

## 1. Azure Cosmos DB: sus modos de capacidad y el nombre de su unidad de throughput

**VEREDICTO GLOBAL: CORRECTED.** La unidad es SUPPORTED verbatim y sin ambigüedad. **El recuento de modos no lo es**: dos páginas vigentes de Microsoft, consultadas el mismo día, dicen cosas distintas — una dice **tres modos**, otra dice **dos capacity modes**. El skill debe reproducir la distinción real que subyace, no elegir un número.

### 1.1 La unidad — VEREDICTO PARCIAL: SUPPORTED

> "Azure Cosmos DB normalizes the cost of all database operations using Request Units (or RUs, for short) and measures cost based on throughput (Request Units per second, RU/s)."
>
> "A request unit is a performance currency that abstracts the system resources such as processing (CPU), input/output operations per second (IOPS), and memory that are required to perform the database operations supported by Azure Cosmos DB. Whether the database operation is a write, point read, or query, operations are always measured in RUs. For example, reading a single item by its ID and partition key uses […] request unit. The item should be about […] in size. This estimated size is true for any API you use with Azure Cosmos DB."

Fuente: `https://learn.microsoft.com/en-us/azure/cosmos-db/request-units`, verbatim; la equivalencia numérica se elide.

Dos rasgos que el skill debe conservar porque no se repiten en los otros dos productos: la unidad es **una sola para lecturas y escrituras** ("operations are always measured in RUs"), y es **observable por operación**:

> "To manage and plan capacity, Azure Cosmos DB ensures that the number of RUs for a given database operation over a given dataset is deterministic. You can examine the response header to track the number of RUs consumed by any database operation."

Fuente: misma página, verbatim.

### 1.2 El recuento de modos — VEREDICTO PARCIAL: CORRECTED

La página de Request Units enumera **tres**:

> "The type of Azure Cosmos DB account you're using determines the way consumed RUs get charged. There are three modes in which you can create an account:
> - **Provisioned throughput mode**: In this mode, you assign the number of RUs for your application on a per-second basis in increments of […] RUs per second. … You're billed hourly based on the number of RUs per second provisioned.
> - **Serverless mode**: In this mode, you don't have to assign any throughput when creating resources in your Azure Cosmos DB account. At the end of your billing period, you get billed for the number of Request Units consumed by your database operations.
> - **Autoscale mode**: In this mode, you can automatically and instantly scale the throughput (RU/s) of your database or container based on its usage."

Fuente: misma página, verbatim; los incrementos se eliden.

La página de elección entre modos enumera **dos**, y coloca autoscale **dentro** de provisioned:

> "Azure Cosmos DB is available in two different capacity modes: provisioned throughput and serverless. You can perform the exact same database operations in both modes, but the way you get billed for these operations is radically different."
>
> "For each of your containers, you configure some amount of provisioned throughput expressed in Request Units per second (RU/s). Every second, this quantity of Request Units is available for your database operations. **Provisioned throughput can be updated manually or adjusted automatically with autoscale.**"

Fuente: `https://learn.microsoft.com/en-us/azure/cosmos-db/throughput-serverless`, verbatim.

Y la página dedicada usa el término compuesto que resuelve la tensión — **autoscale provisioned throughput**:

> "Azure Cosmos DB lets you configure standard (manual) or autoscale throughput for databases and containers. Autoscale adjusts throughput (RU/s) to match your workload, ensuring high performance and cost efficiency."
>
> "Autoscale provisioned throughput is ideal for mission-critical workloads with variable or unpredictable traffic patterns, and that require service level agreements (SLAs) for high performance and scale."

Fuente: `https://learn.microsoft.com/en-us/azure/cosmos-db/provision-throughput-autoscale`, verbatim.

**Lectura correcta, marcada como inferencia**: la formulación que concilia las páginas es *los capacity modes son `provisioned throughput` y `serverless`; dentro de `provisioned`, los RU/s se fijan en modo `standard (manual)` o `autoscale`*. Microsoft **no** enuncia esa jerarquía en ninguna sola frase; se sigue de leer las tres páginas juntas. El skill debe presentarla como lectura, no como cita, y **no debe afirmar un recuento de modos de capacidad en Cosmos DB**, porque cualquier recuento contradice a alguna de las páginas vigentes del proveedor.

### 1.3 La restricción de serverless que decide arquitecturas

En la tabla "Detailed comparison", la fila `Geo-distribution` tiene estas dos celdas, verbatim — la primera para *Provisioned throughput*, la segunda para *Serverless*:

> "Available (unlimited number of Azure regions)"
>
> "Unavailable (serverless accounts can only run in a single Azure region)"

Fuente: `https://learn.microsoft.com/en-us/azure/cosmos-db/throughput-serverless`, verbatim; la atribución de cada celda a su columna es lectura de la tabla, no texto corrido del proveedor.

Confirmado en la página de distribución global:

> "Note: Serverless accounts for Azure Cosmos DB can only run in a single Azure region."

Fuente: `https://learn.microsoft.com/en-us/azure/cosmos-db/distribute-data-globally`, verbatim.

Es decir: en Cosmos DB, **elegir serverless renuncia a la multirregión**. Eso es un cruce entre la claim 1 y la claim 4, y es exactamente el tipo de acoplamiento que el arquetipo 4 pide declarar junto al tier.

---

## 2. Google Bigtable: su unidad de escalado, y si existe un modo serverless o de autoescalado

**VEREDICTO GLOBAL: CORRECTED.** La unidad es SUPPORTED. El autoescalado existe y es SUPPORTED. **"Serverless" es la parte que hay que corregir**: existe un producto llamado serverless dentro de Bigtable, pero Google declara expresamente que **no sirve para el camino de serving** y que **requiere nodos provisionados de todos modos**.

### 2.1 La unidad es el *node*, dentro de *cluster*, dentro de *instance* — VEREDICTO PARCIAL: SUPPORTED

> "To use Bigtable, you create instances, which contain clusters that your applications can connect to. Each cluster contains nodes, the compute units that manage your data and perform maintenance tasks."
>
> "A Bigtable instance is a container for your data. Instances have one or more clusters, located in different zones. **Each cluster has at least 1 node.**"
>
> "Each cluster in an instance has 1 or more nodes, which are compute resources that Bigtable uses to manage your data. The compute capacity and performance of a node depend on the instance edition."

Fuente: `https://cloud.google.com/bigtable/docs/instances-clusters-nodes`, verbatim.

Y la unidad de facturación correspondiente es **por nodo y por hora**, en la propia tabla de precios: el encabezado de la tabla es `Hourly` con columnas `Price per hour`, y la nota al pie de la tabla dice literalmente:

> "* Prices reflect the cost per node"

Fuente: `https://cloud.google.com/bigtable/pricing`, verbatim; los importes y los multiplicadores de memoria se eliden.

### 2.2 Autoescalado: sí, y Google lo recomienda — VEREDICTO PARCIAL: SUPPORTED

> "In most cases, you should enable autoscaling for a cluster, so that Bigtable adds and removes nodes as needed to handle the cluster's workloads."

Fuente: `https://cloud.google.com/bigtable/docs/instances-clusters-nodes`, verbatim.

> "Autoscaling is the process of automatically scaling, or changing the size of, a cluster by adding or removing nodes. When you enable autoscaling, Bigtable automatically adjusts the size of your cluster for you."
>
> "Bigtable autoscaling determines the number of nodes required, based on the following dimensions: CPU utilization target / Storage utilization target / Minimum number of nodes / Maximum number of nodes. Each scaling dimension generates a recommended node count, and Bigtable automatically uses the highest one."

Fuente: `https://cloud.google.com/bigtable/docs/autoscaling`, verbatim.

**Y el suelo, que es la respuesta a "¿escala a cero?":**

> "**Minimum number of nodes** — The lowest number of nodes that Bigtable will scale the cluster down to. … **This value must be greater than zero** and can't be lower than […]% of the value you set for the maximum number of nodes."

Fuente: misma página, verbatim; el porcentaje se elide. Bigtable **no** escala a cero, y Google lo enuncia como restricción de configuración, no como matiz.

### 2.3 "Serverless": existe, se llama Data Boost, y NO es para serving — VEREDICTO PARCIAL: CORRECTED

> "Data Boost is a serverless compute service designed to run high-throughput read jobs on your Bigtable data without impacting the performance of the clusters that handle your application traffic. It lets you send large read jobs and queries using serverless compute while your core application continues using cluster nodes for compute. Serverless compute SKUs and billing rates are separate from the SKUs and rates for provisioned nodes. You can't send write or delete requests with Data Boost."

Fuente: `https://cloud.google.com/bigtable/docs/data-boost-overview`, verbatim.

La negación explícita, que es la cita decisiva de esta sección:

> "**Latency-sensitive workloads** - Data Boost is optimized for throughput, so read latency is slower when you use Data Boost than when you read using clusters and nodes. For this reason, **Data Boost is not suitable for application serving workloads.**"

Fuente: misma página, verbatim.

Y la dependencia de nodos provisionados, que cierra cualquier lectura de "Bigtable tiene un modo sin nodos":

> "Data Boost for Bigtable is an on-demand, serverless compute option. It's designed to isolate throughput-intensive read use cases like pipeline jobs and queries from your provisioned node compute resources. **To use Data Boost, you need at least one active Bigtable cluster with at least one provisioned node.**"
>
> "Bigtable Data Boost usage is measured in serverless processing units or SPUs. One SPU is equivalent to the processing power of approximately […] of a node."

Fuente: `https://cloud.google.com/bigtable/pricing`, sección "Data Boost serverless compute", verbatim; la fracción se elide.

Dos restricciones más que el skill debe conocer si menciona Data Boost:

> "Data Boost is available if you use the Enterprise or Enterprise Plus edition."
>
> "Note: Data Boost is not a covered service as defined in the Bigtable SLA."

Fuente: `https://cloud.google.com/bigtable/docs/data-boost-overview`, verbatim.

**Cómo debe decirlo el skill**: Bigtable tiene autoescalado por nodos con suelo mayor que cero, y una unidad serverless (**SPU**) que Google vende para trabajo analítico de lectura, con SKU separada, fuera del SLA y **explícitamente descartada para serving**. Esto encaja con lo que el arquetipo 4 ya afirma —que un analista escaneando un serving store es un antipatrón y que el arreglo es una copia en el arquetipo 3— y le da la cita del proveedor que le faltaba.

---

## 3. Amazon DynamoDB: on-demand frente a provisioned, y el nombre de su unidad de capacidad

**VEREDICTO GLOBAL: SUPPORTED**, con una precisión terminológica que el skill no puede omitir: **DynamoDB usa un nombre de unidad distinto en cada modo**, y no son intercambiables.

### 3.1 Los dos modos, con el default nombrado

> "This section provides an overview of the two throughput modes available for your DynamoDB table … A table's throughput mode determines how the capacity of a table is managed. Throughput mode also determines how you're charged for the read and write operations on your tables. In Amazon DynamoDB, you can choose between **on-demand mode** and **provisioned mode** for your tables to accommodate different workload requirements."
>
> "Amazon DynamoDB on-demand mode is a serverless throughput option that simplifies database management and automatically scales to support customers' most demanding applications. … DynamoDB on-demand offers **pay-per-request pricing** for read and write requests so that you only pay for what you use. For on-demand mode tables, you don't need to specify how much read and write throughput you expect your application to perform."
>
> "**On-demand mode is the default and recommended throughput option for most DynamoDB workloads.**"
>
> "In provisioned mode, you must specify the number of reads and writes per second that you require for your application. You'll be charged based on the hourly read and write capacity you have provisioned, not how much of that provisioned capacity you actually consumed. This helps you govern your DynamoDB use to stay at or below a defined request rate in order to obtain cost predictability."

Fuente: `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/capacity-mode.html`, verbatim.

**Dato de deriva sellado al 2026-08-12**: AWS declara on-demand como **default y recomendado**. Cualquier material que presente provisioned como el punto de partida está desactualizado contra esta página.

### 3.2 Las unidades — dos nombres, uno por modo

On-demand:

> "DynamoDB charges you for the reads and writes that your application performs on your tables in terms of **read request units** and **write request units**."
>
> "One read request unit represents one strongly consistent read operation per second, or two eventually consistent read operations per second, for an item up to […] in size."
>
> "One write request unit represents one write operation per second, for an item up to […] in size."

Fuente: `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/on-demand-capacity-mode.html`, verbatim; los tamaños de ítem se eliden.

Provisioned:

> "For provisioned mode tables, you specify throughput requirements in terms of **capacity units**. These units represent the amount of data your application needs to read or write per second. You can modify these settings later, if needed, or enable DynamoDB auto scaling to modify them automatically."
>
> "For an item up to […], one **read capacity unit (RCU)** represents one strongly consistent read operation per second, or two eventually consistent read operations per second."
>
> "A **write capacity unit (WCU)** represents one write per second for an item up to […]."

Fuente: `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/provisioned-capacity-mode.html`, verbatim; los tamaños de ítem se eliden.

**Precisión terminológica que el skill debe respetar**: *request unit* (on-demand) y *capacity unit* (provisioned) son términos distintos de AWS para la misma cantidad de trabajo. Las abreviaturas **RCU/WCU están documentadas solo del lado provisioned**; la página de on-demand escribe los nombres completos y no abrevia. Y nótese la colisión con Azure: "request unit" en DynamoDB significa *una operación de un tamaño dado*, mientras que el "Request Unit" de Cosmos DB es una *moneda normalizada de coste* que cubre lectura, escritura y consulta con la misma escala. **Escribir "RU" sin proveedor delante es ambiguo entre dos productos**, y este documento no lo hace en ningún punto.

---

## 4. Cómo llama cada uno a la distribución multirregión, y si es configuración o producto aparte

**VEREDICTO GLOBAL: SUPPORTED.** En los tres es **configuración**, no un producto que se compre aparte. Los tres nombres son distintos y ninguno es traducible al otro.

| Producto | Nombre del proveedor | ¿Producto o configuración? | Unidad que se replica |
|---|---|---|---|
| Cosmos DB | **global distribution** / "regions associated with your account" | configuración de la **cuenta** | la cuenta y sus containers |
| Bigtable | **replication** | configuración de la **instance** (añadir clusters) | el cluster |
| DynamoDB | **global tables** | **feature** (palabra de AWS) sobre la tabla | la tabla, como *replica* |

### 4.1 Cosmos DB — configuración de cuenta, sin pausa ni redespliegue

> "Azure Cosmos DB is a globally distributed database system that allows you to read and write data from the local replicas of your database. Azure Cosmos DB transparently replicates the data to all the regions associated with your Azure Cosmos DB account."
>
> "With Azure Cosmos DB, you can add or remove the regions associated with your account at any time. Your application doesn't need to be paused or redeployed to add or remove a region."
>
> "Scale read-and-write throughput globally. You can enable every region to be writable and elastically scale reads and writes all around the world. **The throughput that your application configures on an Azure Cosmos DB database or a container is provisioned across all regions associated with your Azure Cosmos DB account.**"

Fuente: `https://learn.microsoft.com/en-us/azure/cosmos-db/distribute-data-globally`, verbatim.

**Esa última frase es la que tiene consecuencia de coste** y el skill debe llevarla al arquetipo 4: en Cosmos DB los RU/s se provisionan **en cada región asociada**, así que añadir una región multiplica el throughput provisionado. Es configuración, sí — y es configuración con efecto multiplicativo sobre el medidor.

### 4.2 Bigtable — replicación por clusters

> "Replication for Bigtable lets you increase the availability and durability of your data by copying it across multiple regions or multiple zones within the same region. You can also isolate workloads by routing different types of requests to different clusters."

Fuente: `https://cloud.google.com/bigtable/docs/replication-overview`, verbatim.

Y la mecánica, que es la que hace que en Bigtable la multirregión sea una decisión de **capacidad**, no solo de disponibilidad:

> "A table belongs to an instance, not to a cluster or node. **If you have an instance with more than one cluster, you are using replication.** This means you can't assign a table to an individual cluster or create unique garbage collection policies for each cluster in an instance. You also can't make each cluster store a different set of data in the same table."

Fuente: `https://cloud.google.com/bigtable/docs/instances-clusters-nodes`, sección "Instances", verbatim.

Y el disparador exacto, en la misma página:

> "Bigtable instances that have only 1 cluster don't use replication. If you add a second cluster to an instance, Bigtable automatically starts replicating your data by keeping separate copies of the data in each of the clusters' zones and synchronizing updates between the copies. You can choose which cluster your applications connect to, which makes it possible to isolate different types of traffic from one another."

Fuente: misma página, verbatim.

En Bigtable no existe un interruptor "multirregión": se añade un cluster, y un cluster tiene nodos con su propio medidor horario. **Marcado como inferencia**: que replicar duplique el gasto de nodos se sigue de combinar esta página con la de precios; Google no lo enuncia en una frase.

### 4.3 DynamoDB — AWS lo llama *feature*

> "Amazon DynamoDB global tables is a fully managed, multi-Region, and multi-active database **feature** that provides easy to use data replication and fast local read and write performance for globally scaled applications."
>
> "Global tables automatically replicate your DynamoDB table data across AWS Regions and optionally across AWS accounts without requiring you to build and maintain your own replication solution. … Any global table replica can serve reads and writes."
>
> "You can configure a global table using the AWS Management Console. Global tables use existing DynamoDB APIs to read and write data to your tables, so no application changes are required. You pay only for the resources you provision or use, with no upfront costs or commitments."

Fuente: `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html`, verbatim; el énfasis en *feature* es de este documento, la palabra es de AWS.

Dos ejes de configuración con nombre propio, y una puerta de un solo sentido que el skill —cuyo eje central es la irreversibilidad— debe registrar:

> "When you create a global table, you can configure its consistency mode. Global tables support two consistency modes: multi-Region eventual consistency (MREC) and multi-Region strong consistency (MRSC)."
>
> "If you do not specify a consistency mode when creating a global table, the global table defaults to multi-Region eventual consistency (MREC). A global table cannot contain replicas configured with different consistency modes. **You cannot change a global table's consistency mode after creation.**"

Fuente: misma página, verbatim.

> "DynamoDB now supports two global tables models, each designed for different architectural patterns: **Same-account global tables** – All replicas are created and managed within a single AWS account. **Multi-account global tables** – Replicas are deployed across multiple AWS accounts while participating in a shared replication group."
>
> "Global tables configured for MRSC only support same-account configurations."

Fuente: misma página, verbatim. Comprobado 2026-08-12: el modelo multi-account es reciente y no aparece en material anterior.

---

## 5. Si cada proveedor encuadra su almacén como dirigido por patrones de acceso — y dónde traza la frontera

**VEREDICTO GLOBAL: SUPPORTED**, y la respuesta es más útil de lo que la claim esperaba: **los tres lo hacen, pero con grados muy distintos de prescripción**, y eso es exactamente lo que decide qué parte pertenece a `modeling-data-engineering` y qué parte a esta skill.

| Proveedor | ¿Encuadre por patrones de acceso? | Fuerza del enunciado |
|---|---|---|
| DynamoDB | **sí, como prerrequisito** | "you shouldn't start designing your schema … until you know the questions it will need to answer" |
| Bigtable | **sí, como Key Point** | "Design your schema for the queries that you plan to use" |
| Cosmos DB | **sí, pero más suave** | "design each item around the way your application reads and writes that data" |

### 5.1 DynamoDB — el enunciado más fuerte de los tres

> "In a NoSQL database such as DynamoDB, data can be queried efficiently in a limited number of ways, outside of which queries can be expensive and slow."
>
> "In DynamoDB, you design your schema specifically to make the most common and important queries as fast and as inexpensive as possible. Your data structures are tailored to the specific requirements of your business use cases."
>
> "NoSQL design requires a different mindset than RDBMS design. For an RDBMS, you can go ahead and create a normalized data model without thinking about access patterns. … **By contrast, you shouldn't start designing your schema for DynamoDB until you know the questions it will need to answer.** Understanding the business problems and the application use cases up front is essential."
>
> "You should maintain as few tables as possible in a DynamoDB application."

Fuente: `https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-general-nosql-design.html`, verbatim. Esta es la cita que `modeling-data-engineering` ya usa en `modeling-for-access-patterns.md`; queda confirmada como vigente al 2026-08-12.

### 5.2 Bigtable — "Key Point", literalmente

> "Designing a Bigtable schema is different from designing a schema for a relational database. A Bigtable schema is defined by application logic rather than by a schema definition object or file. You can add column families to a table when you create or update the table, but columns and row key patterns are defined by the data that you write to the table."
>
> "**Key Point: Design your schema for the queries that you plan to use.**"
>
> "In Bigtable, schema design is driven primarily by the queries, or read requests, that you plan to send to the table. Because reading a row range is the fastest way to read your Bigtable data, the recommendations on this page are designed to help you optimize for row range reads."

Fuente: `https://cloud.google.com/bigtable/docs/schema-design`, verbatim; "Key Point" es una etiqueta literal de la página de Google.

Y la conexión con la infraestructura, que es donde la frontera se vuelve porosa y el skill debe saberlo:

> "Because all tables in an instance are stored on the same tablets, a schema design that results in hotspots in one table can affect the latency of other tables in the same instance. Hotspots are caused by frequently accessing one part of the table in a short period of time."

Fuente: misma página, verbatim. **Aquí está la frontera real**: un error de row key no se queda en la tabla, degrada la instancia entera — es decir, un fallo de modelado se manifiesta como un problema de capacidad de infraestructura.

### 5.3 Cosmos DB — sí, pero el encuadre es de rendimiento y coste, no de prerrequisito

> "While schema-free databases, like Azure Cosmos DB, make it easy to store and query unstructured and semi-structured data, think about your data model to optimize performance, scalability, and cost. How is data stored? How does your application retrieve and query data? Is your application read-heavy or write-heavy?"
>
> "If you're migrating from PostgreSQL or another relational database, plan to reshape both your data model and your queries. In relational systems, queries often reconstruct business entities with JOINs across tables. **In Azure Cosmos DB, design each item around the way your application reads and writes that data.**"
>
> "Relational JOINs across tables typically require you to remodel data based on access patterns, using approaches such as embedding, references, or read-optimized projections."

Fuente: `https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/modeling-data`, verbatim.

**Hedge que se conserva**: Microsoft dice "think about your data model", no "no empieces hasta saber las preguntas". Y añade que Cosmos DB sí admite relaciones, con un límite:

> "You can create relationships between entities in document databases, not just in relational databases. In a document database, one item can include information that connects to data in other documents. Azure Cosmos DB isn't designed for complex relationships like those in relational databases, but simple links between items are possible and can be helpful."

Fuente: misma página, verbatim.

### 5.4 Dónde traza cada uno la frontera — respuesta directa a lo que pedía la claim

Los tres proveedores tratan el **modelado** (row key, item shape, partition key, número de tablas, embedding vs. referencia) como territorio propio de sus guías de *schema design* / *data modeling*, separadas de sus guías de *instances/clusters/nodes*, *capacity mode* y *throughput*. Esa separación editorial **coincide con la frontera que la suite ya declara**: el modelado pertenece a `modeling-data-engineering`; el modo de capacidad, la unidad, el escalado y la multirregión pertenecen a `iac-cloud-data-engineering`.

**Y hay un punto donde la frontera no cierra**, documentado por los tres con vocabulario distinto: el reparto del tráfico sobre la clave. Bigtable lo llama *hotspots* y advierte que contamina toda la instancia (citado arriba, `https://cloud.google.com/bigtable/docs/schema-design`). Cosmos DB lo llama *hot partitions* y lo trae al terreno del coste:

> "Dynamic scaling helps save costs if you often experience hot partitions or have multiple regions."

Fuente: `https://learn.microsoft.com/en-us/azure/cosmos-db/provision-throughput-autoscale`, verbatim.

DynamoDB lo trata bajo **"DynamoDB burst and adaptive capacity"**, listado como subtema de su página de modos de capacidad (`https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/capacity-mode.html`, índice de la sección, verbatim). **Marcado como inferencia**: ninguno de los tres enuncia "aquí termina el modelado y empieza la infraestructura". Lo que este documento sostiene es que las tres documentaciones colocan el desequilibrio de clave en sus páginas de **capacidad**, no en las de **esquema** — y por tanto ese es el tema del arquetipo 4 donde esta skill puede entrar sin invadir la de modelado.

---

## Resumen de veredictos

| # | Claim | Cosmos DB | Bigtable | DynamoDB | Veredicto global |
|---|---|---|---|---|---|
| 1 | Modos de capacidad y unidad de throughput | **CORRECTED** — unidad **SUPPORTED** (*Request Unit*, RU/s, moneda única para lectura, escritura y consulta, observable en la cabecera de respuesta); **recuento de modos en conflicto entre dos páginas vigentes** ("three modes" vs. "two different capacity modes"); serverless no admite geo-distribución | n/a | n/a | **CORRECTED** |
| 2 | Unidad de escalado; ¿serverless o autoescalado? | n/a | **CORRECTED** — unidad = **node** dentro de cluster dentro de instance, facturado **por nodo y por hora**; autoescalado **SUPPORTED** y recomendado, con mínimo que "must be greater than zero"; el único "serverless" (**Data Boost**, medido en **SPU**) exige al menos un nodo provisionado, tiene SKU separada, está fuera del SLA y Google declara que "is not suitable for application serving workloads" | n/a | **CORRECTED** |
| 3 | On-demand vs. provisioned y nombre de la unidad | n/a | n/a | **SUPPORTED** — on-demand es "the default and recommended"; **read/write request units** en on-demand, **read/write capacity units (RCU/WCU)** en provisioned; abreviaturas documentadas solo del lado provisioned | **SUPPORTED** |
| 4 | Nombre de la multirregión; ¿configuración o producto? | **SUPPORTED** — *global distribution*, configuración de cuenta; el throughput se provisiona **en cada región asociada** | **SUPPORTED** — *replication*, configuración de instance vía clusters; más de un cluster **es** replicación | **SUPPORTED** — *global tables*, palabra de AWS: **feature**; modos MREC/MRSC, y **el modo de consistencia no se puede cambiar tras la creación** | **SUPPORTED** — configuración en los tres |
| 5 | ¿Encuadre por patrones de acceso? | **SUPPORTED con hedge** — "design each item around the way your application reads and writes that data"; admite relaciones simples, no complejas | **SUPPORTED** — "Key Point: Design your schema for the queries that you plan to use"; un hotspot degrada **toda la instancia** | **SUPPORTED, el más fuerte** — "you shouldn't start designing your schema for DynamoDB until you know the questions it will need to answer" | **SUPPORTED** |

## Implicación para el skill

1. **El arquetipo 4 ya puede nombrar los tres productos**, sellados al 2026-08-12, con su unidad y su modo juntos —que es lo que ese archivo ya exige— y sin mezclar vocabularios:
   - **Azure Cosmos DB** → capacity mode **provisioned throughput** (standard/manual o **autoscale**) o **serverless**; unidad **Request Unit (RU/s)**.
   - **Google Bigtable** → **cluster** con **nodes**, con **autoscaling** de suelo mayor que cero; unidad de factura **por nodo y por hora**.
   - **Amazon DynamoDB** → **on-demand** (default y recomendado por AWS) o **provisioned**; unidades **read/write request unit** y **read/write capacity unit (RCU/WCU)** respectivamente.

2. **Nunca escribir "RU" sin proveedor.** El *Request Unit* de Cosmos DB es una moneda normalizada de coste; el *read request unit* de DynamoDB es una operación de un tamaño dado. Son conceptos distintos con nombres casi idénticos, y es la trampa terminológica de este arquetipo.

3. **No afirmar un recuento de modos de capacidad en Cosmos DB.** Las páginas vigentes de Microsoft se contradicen entre sí. Usar la formulación jerárquica —*provisioned throughput* (standard o autoscale) frente a *serverless*— y marcarla como lectura conciliadora, no como cita.

4. **Corregir "Bigtable tiene un modo serverless".** Lo tiene, se llama **Data Boost**, se mide en **SPU**, exige nodos provisionados, queda fuera del SLA y Google dice que **no sirve para serving**. Es material para el arquetipo 3 (la copia analítica), no para el 4. Y refuerza con cita del proveedor lo que el arquetipo 4 ya decía sobre el `throughput shape` `exploratory`.

5. **Llevar tres consecuencias de coste al eje `scaling granularity`**, que el archivo hoy no puede sostener: (a) en Cosmos DB los RU/s se provisionan **en cada región asociada**, así que añadir una región multiplica el medidor; (b) en Cosmos DB **serverless renuncia a la multirregión**, es decir, el modo de capacidad y la topología están acoplados; (c) en Bigtable no hay interruptor de multirregión — hay un cluster más, con sus nodos y su medidor horario.

6. **Añadir a `statefulness-and-the-one-way-door.md` o a la tabla de errores comunes**: en DynamoDB global tables, **el modo de consistencia (MREC/MRSC) no se puede cambiar después de crear la tabla**, y MRSC solo admite configuración same-account. Es una puerta de un solo sentido literal, enunciada por el proveedor, sobre el recurso que guarda el estado.

7. **La frontera con `modeling-data-engineering` queda confirmada por la propia estructura editorial de los tres proveedores**, y con un único punto de contacto: el desequilibrio de clave. Los tres lo documentan en sus páginas de **capacidad** —*hotspots* (Bigtable), *hot partitions* (Cosmos DB), *burst and adaptive capacity* (DynamoDB)— y no en las de esquema. Ese es el punto de modelado que este archivo puede tocar, y debe tocarlo por el lado de la capacidad, no por el de la clave.
