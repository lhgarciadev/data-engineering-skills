# Research: formas del modelo de costo en la nube — bytes escaneados vs. capacidad, créditos por tiempo de warehouse, separación storage/requests/egress, y qué significa "serverless" en cada producto

**Fecha:** 2026-08-08
**Alcance:** verificación de las 5 claims del **Paso 2** del plan de implementación de la skill de IaC/cloud. Todas las claims son sobre la **FORMA** del cargo (la unidad de facturación), nunca sobre el monto. Fuentes primarias: documentación de **modelo** de precios de los proveedores.

Páginas consultadas (todas el 2026-08-08):

- `https://cloud.google.com/bigquery/docs/pricing`
- `https://cloud.google.com/bigquery/docs/editions-intro`
- `https://cloud.google.com/bigquery/docs/best-practices-costs`
- `https://docs.snowflake.com/en/user-guide/cost-understanding-compute`
- `https://docs.snowflake.com/en/user-guide/warehouses-overview`
- `https://docs.aws.amazon.com/athena/latest/ug/performance-tuning-data-optimization-techniques.html`
- `https://docs.aws.amazon.com/athena/latest/ug/what-is.html`
- `https://docs.aws.amazon.com/athena/latest/ug/capacity-management.html`
- `https://aws.amazon.com/athena/pricing/`
- `https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-billing.html`
- `https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-billing-on-demand.html`
- `https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-capacity.html`
- `https://aws.amazon.com/s3/pricing/`
- `https://cloud.google.com/storage/pricing`
- `https://learn.microsoft.com/en-us/azure/storage/common/storage-plan-manage-costs`

---

**Nota de método**

- **Ruta primaria: `curl -A "Mozilla/5.0 …"` + extractor HTML→texto local.** Se usó como ruta principal para las 15 páginas, no por bloqueo sino por **auditabilidad**: cada página quedó persistida como texto plano en el directorio de fuentes crudas (`raw/cost-*.txt`), de modo que cualquier revisor pueda hacer `grep` de cada cita de este documento contra el texto realmente descargado. Ninguna cita de este documento proviene de memoria.
- **Ruta de contraste: WebFetch (fetcher basado en LLM).** Se probó explícitamente contra `docs.snowflake.com` y `aws.amazon.com/athena/pricing/`. **Ambas funcionaron, sin 403.** Es decir: en esta pasada NO hubo bloqueo por user-agent en ningún dominio (contrario a lo ocurrido con `debezium.io` en la pasada de CDC del 2026-08-07). El workaround documentado del repo no fue necesario aquí, aunque se usó `curl` de todas formas por la razón de auditoría descrita arriba.
- **Limitación técnica observada:** en `https://aws.amazon.com/athena/pricing/` la tabla principal de precios de SQL vive dentro de pestañas renderizadas por JavaScript, que el extractor de texto no despliega. Esto **no afecta a este documento**, porque lo que aquí se necesita es la FORMA del cargo, no la tabla de tarifas; la forma se verificó contra la documentación técnica de Athena (`docs.aws.amazon.com`), que sí se descarga completa.

**Nota sobre la regla de no-números (crítica para leer las citas de este documento)**

Este documento alimenta una skill que **nunca** debe enunciar un precio, un límite de servicio, una cuota, un tipo de instancia ni un tamaño de nodo. En consecuencia:

- Se **conservan las UNIDADES de facturación** (`per TiB`, `per slot-hour`, `per-second`, `RPU-hours`, `per GB / per month`, `per transaction`, `credits`), porque la unidad ES la forma del cargo y es exactamente lo que la skill debe enseñar.
- Se **eliden los MONTOS**: tarifas, umbrales de capa gratuita, cuotas, número de slots/DPU/RPU concurrentes, memoria por unidad de cómputo y la **duración concreta de los mínimos de facturación**.
- Cada elisión aparece dentro de la cita como `[…]` y se anuncia en prosa. **En ningún caso se alteró silenciosamente el texto citado.**
- Consecuencia práctica: donde la fuente dice "mínimo de N segundos", este documento cita "mínimo de `[…]`" y la skill debe decir "facturación por segundo **con un mínimo**", sin nombrar el mínimo. La existencia del mínimo es forma; su duración es número.

---

## 1. El modelo on-demand de BigQuery cobra por bytes escaneados/procesados, y existe un modelo de capacidad/slots como alternativa

**VEREDICTO: SUPPORTED**, verbatim, con la terminología vigente de Google: los dos modelos se llaman hoy **"On-demand pricing (per TiB)"** y **"Capacity pricing (per slot-hour)"**, y el segundo se apoya en **BigQuery editions**.

### 1.1 Los dos modelos de cómputo, nombrados por el proveedor

> "BigQuery offers a choice of two compute pricing models for running queries:
>
> - On-demand pricing (per TiB). With this pricing model, you are charged for the number of bytes processed by each query. The first […] of query data processed per month is free.
>
> - Capacity pricing (per slot-hour). With this pricing model, you are charged for compute capacity used to run queries, measured in slots (virtual CPUs) over time. This model takes advantage of BigQuery editions . You can use the BigQuery autoscaler or purchase slot commitments, which are dedicated capacity that is always available for your workloads, at a lower price."

Fuente: `https://cloud.google.com/bigquery/docs/pricing`, sección "Compute pricing models", verbatim. **Elisión:** se eliminó el umbral de la capa gratuita mensual (`[…]`) conforme a la regla de no-números. Nótese que `per TiB` y `per slot-hour` se conservan porque son **unidades**, no montos.

### 1.2 El on-demand es el modo por defecto y se paga por datos escaneados

> "By default, queries are billed using the on-demand (per TiB) pricing model, where you pay for the data scanned by your queries."

Fuente: `https://cloud.google.com/bigquery/docs/pricing`, sección "On-demand compute pricing", verbatim, sin elisiones.

### 1.3 Lo que mueve los bytes procesados: columnas seleccionadas, particionado y clustering

> "BigQuery uses a columnar data structure . You're charged according to the total data processed in the columns you select, and the total data per column is calculated based on the types of data in the column."

> "Partitioning and clustering your tables can help reduce the amount of data processed by queries. As a best practice, use partitioning and clustering whenever possible."

> "When you run a query, you're charged according to the data processed in the columns you select, even if you set an explicit LIMIT on the results."

> "You aren't charged for queries that return an error or for queries that retrieve results from the cache ."

Fuente: `https://cloud.google.com/bigquery/docs/pricing`, sección "Note the following regarding on-demand (per TiB) query charges", verbatim, sin elisiones.

**Matiz que el skill debe preservar:** el `LIMIT` **no** reduce el cargo. Es la simplificación popular más peligrosa de este modelo y la fuente la desmiente de forma explícita.

### 1.4 El modelo de capacidad: qué se compra exactamente

> "BigQuery offers a capacity-based compute pricing model for customers who need additional capacity or prefer a predictable cost for query workloads rather than the on-demand price (per TiB of data processed). The capacity compute model offers pay-as-you-go pricing (with autoscaling) and optional one year and three year commitments that provide discounted prices. You pay for query processing capacity, measured in slots (virtual CPUs) over time."

Fuente: `https://cloud.google.com/bigquery/docs/pricing`, sección "Capacity compute pricing", verbatim, sin elisiones.

Y sobre la granularidad temporal de esa capacidad:

> "BigQuery slot capacity: […] is billed per second with a […] minimum duration by default. You can opt in to BigQuery fluid scaling at the reservation level for per-second billing with no minimum duration."

Fuente: `https://cloud.google.com/bigquery/docs/pricing`, lista "BigQuery slot capacity", verbatim. **Elisiones:** el primer `[…]` omite otros ítems de la lista no relevantes a esta claim; el segundo omite la **duración concreta del mínimo** conforme a la regla de no-números.

**Hedge registrado:** el mínimo de facturación de capacidad en BigQuery **no es incondicional** — la propia fuente ofrece un modo (`BigQuery fluid scaling`, opt-in a nivel de reserva) en el que **no hay mínimo**. La skill no debe escribir "BigQuery siempre factura capacidad con un mínimo".

---

## 2. Snowflake factura cómputo con créditos contra el tiempo encendido del warehouse, con granularidad por segundo tras un mínimo, y auto-suspend es la palanca

**VEREDICTO: SUPPORTED**, verbatim, en sus tres partes: (a) el cargo es por **tiempo encendido**, no por trabajo hecho; (b) la granularidad es **por segundo con un mínimo cada vez que el warehouse arranca**; (c) **auto-suspend** es el mecanismo que el propio proveedor presenta como la palanca.

### 2.1 El cargo es por tiempo de ejecución del warehouse, no por consultas

> "Snowflake credits are used to pay for the processing time used by each virtual warehouse. Snowflake credits are charged based on the number of virtual warehouses you use, how long they run, and their size."

> "Warehouses are only billed for credit usage while running. When a warehouse is suspended, it does not use any credits."

Fuente: `https://docs.snowflake.com/en/user-guide/cost-understanding-compute`, sección "Virtual warehouse credit usage", verbatim, sin elisiones.

### 2.2 La forma exacta: por segundo, con un mínimo que se reinicia en cada arranque

> "The credit numbers shown above are for a full hour of usage; however, credits are billed per-second, with a […] minimum:
>
> - Each time a warehouse is started or resumed , the warehouse is billed for […] worth of usage based on the hourly rate shown above.
>
> - After […], all subsequent billing is per-second as long as the warehouse runs continuously.
>
> - Suspending and then resuming a warehouse within the first minute results in multiple charges because the […] minimum starts over each time a warehouse is resumed."

Fuente: `https://docs.snowflake.com/en/user-guide/cost-understanding-compute`, sección "Virtual warehouse credit usage", verbatim. **Elisiones:** cada `[…]` sustituye la **duración concreta del mínimo de facturación** conforme a la regla de no-números; también se omitió un bullet sobre resize que menciona créditos/hora por tamaño de warehouse.

Corroborado de forma independiente en la página de warehouses:

> "note that Snowflake utilizes per-second billing (with a […] minimum each time the warehouse starts) so warehouses are billed only for the credits they actually consume."

Fuente: `https://docs.snowflake.com/en/user-guide/warehouses-overview`, sección "Impact on credit usage and billing", verbatim, con la misma elisión.

**Consecuencia operativa que la fuente enuncia y la skill debe conservar:** suspender y reanudar dentro de la ventana del mínimo produce **cargos múltiples**, porque el mínimo se reinicia en cada resume. Es decir, "auto-suspend agresivo" no es monotónicamente mejor — es exactamente el punto donde la simplificación popular ("pon el auto-suspend lo más bajo posible") se rompe.

### 2.3 Auto-suspend como palanca, en palabras del proveedor

> "By default, auto-suspend is enabled. Snowflake automatically suspends the warehouse if it is inactive for the specified period of time."

> "These properties can be used to simplify and automate your monitoring and usage of warehouses to match your workload. Auto-suspend ensures that you don't leave a warehouse running (and consuming credits) when there are no incoming queries. Similarly, auto-resume ensures that the warehouse starts up again as soon as it is needed."

Fuente: `https://docs.snowflake.com/en/user-guide/warehouses-overview`, sección "Auto-suspension and auto-resumption", verbatim, sin elisiones.

**Hedge registrado (multi-cluster):**

> "Auto-suspend only occurs when the minimum number of clusters is running and there is no activity for the specified period of time."

Fuente: misma página, verbatim. En un multi-cluster warehouse el auto-suspend no actúa cluster por cluster.

### 2.4 Contraste interno de Snowflake: "serverless" ahí significa otra cosa

Relevante también para la claim 5. La propia documentación de Snowflake **opone** su cómputo serverless al warehouse gestionado por el usuario, en términos de forma del cargo:

> "Serverless credit usage is the result of features relying on compute resources provided by Snowflake rather than user-managed virtual warehouses. These compute resources are automatically resized and scaled up or down by Snowflake as required for each workload.
>
> For these serverless features, which usually require continuous and/or maintenance operations, this model is more efficient, allowing Snowflake to charge based on the time spent using the resources. In contrast, user-managed virtual warehouses consume credits while running, regardless of whether they are performing any work, which may cause them to be overutilized or sit idle."

Fuente: `https://docs.snowflake.com/en/user-guide/cost-understanding-compute`, sección "Serverless credit usage", verbatim, sin elisiones.

Nótese que incluso en el modo "serverless" de Snowflake la unidad sigue siendo **tiempo de cómputo** (`compute-hours`, calculadas por segundo), no "por consulta".

---

## 3. El modelo on-demand de Athena cobra por datos escaneados, y por eso el formato de archivo y el particionado mueven la factura

**VEREDICTO: SUPPORTED**, verbatim. AWS hace la conexión compresión/columnar/particionado ↔ costo **de forma explícita y en sus propias palabras**, no es una inferencia del repo.

### 3.1 La unidad de cargo

> "Amazon Athena is a serverless, interactive analytics service built on open-source frameworks that enables you to analyze petabytes of data where it lives. With Athena, you can use SQL or Apache Spark and there is no infrastructure to set up or manage. Pricing is simple: you pay based on data processed or compute used."

Fuente: `https://aws.amazon.com/athena/pricing/`, verbatim, sin elisiones. (Esta cita se validó por doble vía: extractor local y WebFetch, con resultado idéntico.)

### 3.2 La conexión explícita compresión → costo

> "Athena supports a wide range of compression formats. Querying compressed data is faster and also cheaper because you pay for the number of bytes scanned before decompression."

Fuente: `https://docs.aws.amazon.com/athena/latest/ug/performance-tuning-data-optimization-techniques.html`, sección "Compress data", verbatim, sin elisiones.

**Esta es la cita más importante de la claim 3.** AWS enuncia el mecanismo completo en una sola frase: se cobra por bytes escaneados **antes** de descomprimir, por eso comprimir abarata.

### 3.3 La conexión explícita particionado → volumen escaneado

> "Partitioning divides your table into parts and keeps the related data together based on properties such as date, country, or region. Partition keys act as virtual columns. You define partition keys at table creation and use them for filtering your queries. When you filter on partition key columns, only data from matching partitions is read."

> "Having too many partition keys can result in fragmented datasets with too many files and files that are too small. Conversely, having too few partition keys, or no partitioning at all, leads to queries that scan more data than necessary."

Fuente: misma página, secciones "Partition your data" y "Pick partition keys that will support your queries", verbatim, sin elisiones.

**Hedge registrado:** el particionado **no** es monotónicamente bueno. La fuente advierte que particionar de más fragmenta el dataset en demasiados archivos pequeños. La skill no debe escribir "particiona siempre lo más fino posible".

### 3.4 La conexión explícita formato columnar → datos leídos

> "Columnar file formats like Parquet and ORC are designed for distributed analytics workloads. They organize data by column instead of by row. Organizing data in columnar format offers the following advantages:
>
> - Only the columns needed for the query are loaded
>
> - The overall amount of data that needs to be loaded is reduced
>
> - Column values are stored together, so data can be compressed efficiently
>
> - Files can contain metadata that allow the engine to skip loading unneeded data"

Fuente: misma página, sección "Use columnar file formats", verbatim, sin elisiones.

Y el propio ejemplo de la página de precios de AWS encadena los dos efectos:

> "If you compress your file and also convert it to a columnar format like Apache Parquet, achieving […] compression, you would still end up with […] of data on S3. But, in this case, because Parquet is columnar, Athena can read only the column that is relevant for the query being run. Because the query in question only references a single column, Athena reads only that column and can avoid reading […] of the file."

Fuente: `https://aws.amazon.com/athena/pricing/`, sección "Pricing examples — Example 1", verbatim. **Elisiones:** se eliminaron el ratio de compresión, el tamaño del dataset y la fracción del archivo omitida, todas cifras del ejemplo tarifado, conforme a la regla de no-números. El encadenamiento causal (comprimir reduce bytes → columnar permite leer solo la columna referenciada → menos bytes escaneados → menos costo) queda íntegro sin las cifras.

**Hedge registrado (contra-indicación de columnar):**

> "When using columnar file formats, make sure that your files aren't too small. As noted in Avoid having too many files , datasets with many small files cause performance issues. This is particularly true with columnar file formats. For small files, the overhead of the columnar file format outweighs the benefits."

Fuente: `https://docs.aws.amazon.com/athena/latest/ug/performance-tuning-data-optimization-techniques.html`, verbatim, sin elisiones.

---

## 4. El almacenamiento de objetos cobra por separado almacenamiento, peticiones y egreso — y el egreso es el que produce lock-in

**VEREDICTO: CORRECTED.** La claim se parte en dos y solo una mitad es afirmación del proveedor.

- **La separación de cargos: SUPPORTED**, verificada en los tres proveedores (S3, GCS y Azure Blob/ADLS). **Pero la claim la enuncia como "three-way separation" y ningún proveedor usa esa taxonomía de tres.** S3 enumera **seis** componentes de costo; GCS enumera **tres**, pero con nombres distintos y con "peticiones" metidas dentro de otro componente; Azure enumera una lista larga de *meters*. La forma real es "**almacenamiento, peticiones y transferencia son cargos separados, entre otros**", no "el costo se descompone en exactamente tres".
- **El framing de lock-in: UNSUPPORTED como afirmación del proveedor.** Ningún documento consultado dice ni insinúa "lock-in" a propósito del egreso. Es **razonamiento propio del repo** y debe etiquetarse como tal.

### 4.1 Amazon S3 — el proveedor enumera SEIS componentes, no tres

> "Pay only for what you use. There is no minimum charge. Amazon S3 cost components are storage pricing, request and data retrieval pricing, data transfer and transfer acceleration pricing, data management and insights feature pricing, replication pricing, and transform and query feature pricing."

Fuente: `https://aws.amazon.com/s3/pricing/`, verbatim, sin elisiones.

Los tres que interesan a la claim, en detalle:

> "You pay for requests made against your S3 buckets and objects. S3 request costs are based on the request type, and are charged on the quantity of requests as listed in the table below. When you use the Amazon S3 console to browse your storage, you incur charges for GET, LIST, and other requests that are made to facilitate browsing."

Fuente: misma página, sección de requests, verbatim, sin elisiones.

> "You pay for all bandwidth into and out of Amazon S3, except for the following:
>
> - Data transferred out to the internet for the first […] per month, aggregated across all AWS Services and Regions (except China and GovCloud)
>
> - Data transferred in from the internet.
>
> - Data transferred between S3 buckets in the same AWS Region.
>
> - Data transferred from an Amazon S3 bucket to any AWS service(s) within the same AWS Region as the S3 bucket (including to a different account in the same AWS Region).
>
> - Data transferred out to Amazon CloudFront (CloudFront)."

Fuente: misma página, sección "Data transfer", verbatim. **Elisión:** el umbral gratuito mensual de salida a internet, conforme a la regla de no-números.

**Esta lista es la evidencia dura de la asimetría que la skill necesita:** la entrada desde internet es gratuita y la salida a internet no lo es; el tráfico **dentro de la misma región** hacia otros servicios AWS tampoco se cobra. La forma es "entrar es gratis, quedarse dentro es gratis, salir cuesta". El proveedor la describe; no la interpreta.

### 4.2 Google Cloud Storage — TRES componentes, pero con otros nombres y otro reparto

> "Cloud Storage pricing is based on the following components:
>
> - Data storage : the amount of data stored in your buckets. Storage rates vary depending on the storage class of your data and location of your buckets.
>
> - Data processing : the processing done by Cloud Storage, which includes operations charges, any applicable retrieval fees, and inter-region replication.
>
> - Network usage : the amount of data read from or moved between your buckets."

Fuente: `https://cloud.google.com/storage/pricing`, verbatim, sin elisiones.

**Hedge crítico registrado:** GCS **no** tiene un componente llamado "requests". Los cargos por operación viven dentro de **"Data processing"**, junto con las *retrieval fees* y la replicación inter-región. Un mapeo ingenuo "storage/requests/egress" pierde exactamente esa agrupación.

Sobre la dirección del tráfico:

> "Outbound data transfer represents data sent from Cloud Storage in HTTP responses. Data or metadata read from a Cloud Storage bucket are examples of data transfer. Inbound data transfer represents data sent to Cloud Storage in HTTP requests. Data or metadata written to a Cloud Storage bucket are examples of inbound data transfer."

> "General network usage applies for any data read from your Cloud Storage bucket that does not fall into one of the above categories or the Always Free usage limits . For example, general network usage applies when data moves from a Cloud Storage bucket to the Internet."

Fuente: misma página, sección "Network usage", verbatim, sin elisiones. La tabla de tarifas de red lista explícitamente `Inbound data transfer | Free` (se cita la **forma**: la entrada no se cobra; no se citan las tarifas de salida).

### 4.3 Azure Blob Storage / ADLS — la separación está confirmada, en forma de *meters* con unidades explícitas

> "When you create or use Blob Storage resources, you're charged for the following meters:
>
> Data storage — Per GB / per month
> Index — Per GB / per month
> Operations — Per transaction
> Data transfer — Per GB
> Data retrieval — Per GB
> […]"

Fuente: `https://learn.microsoft.com/en-us/azure/storage/common/storage-plan-manage-costs`, sección "How you're charged for Azure Blob Storage", verbatim (tabla aplanada a texto). **Elisión:** se omitieron los *meters* de features opcionales (blob index tags, change feed, SFTP, inventory, encryption scopes, query acceleration, point-in-time restore), no relevantes a esta claim. **No se elidió ninguna cifra aquí, porque no hay ninguna**: `Per GB / per month`, `Per transaction` y `Per GB` son unidades, no montos — y son exactamente el tipo de dato que la skill sí puede enunciar.

> "At the end of your billing cycle, the charges for each meter are summed. Your bill or invoice shows a section for all Azure Blob Storage costs. There's a separate line item for each meter."

Fuente: misma página, verbatim, sin elisiones. La separación no es solo conceptual: es una **línea de factura por meter**.

**Hedge crítico registrado en Azure:** el meter "Data transfer" de Blob Storage tiene una nota al pie que lo restringe, y la prosa distingue dos cargos distintos:

> "Any data that leaves the Azure region incurs either a data transfer or network bandwidth charge. The data transfer meter appears when an account is configured for geo-redundant storage."

Fuente: misma página, sección "Data transfer meter", verbatim, sin elisiones. La nota al pie de la tabla dice, sobre ese meter, "Applies only when copying data to another region."

Es decir: en Azure, el egreso a internet **no** aparece necesariamente como el meter "Data transfer" del servicio de almacenamiento, sino como cargo de **ancho de banda de red** de la plataforma. La skill no debe afirmar que los tres proveedores exponen el egreso en el mismo lugar de la factura.

### 4.4 La parte de "lock-in" — inferencia no atribuible al proveedor

**No se encontró ninguna afirmación de proveedor** que conecte el cargo por egreso con *vendor lock-in*, en ninguna de las páginas consultadas. La única aparición de la cadena "lock-in" en todo el material descargado es una frase de marketing de Google sobre compromisos de precio, no sobre transferencia de datos:

> "Pay only for what you use with no lock-in."

Fuente: `https://cloud.google.com/storage/pricing`, verbatim, sin elisiones. **Esto no sostiene la claim** — habla de ausencia de compromiso contractual, no del costo de sacar los datos.

Lo que los proveedores **sí** documentan, y de lo cual el razonamiento se deriva, es la asimetría verificada en 4.1 y 4.2: entrada gratuita, permanencia intra-región gratuita, salida cobrada por GB. La conclusión "por eso el egreso produce lock-in" es **inferencia propia del repo a partir de la asimetría documentada**, y la skill debe presentarla como tal — como razonamiento del autor sobre una forma verificada, no como algo que el proveedor afirme.

---

## 5. Qué significa "serverless" en el nombre de cada producto: ¿facturación POR PETICIÓN o simplemente CAPACIDAD GESTIONADA?

**VEREDICTO: CORRECTED.** La generalización "serverless = pagas por petición" es **falsa como regla**. Verificado el 2026-08-08, la etiqueta "serverless" en estos productos significa cosas distintas, y en al menos uno de ellos (Redshift Serverless) significa **inequívocamente capacidad-por-tiempo**, no por consulta. La skill **no debe generalizar**.

### 5.1 Athena — el caso más cercano a "por consulta", pero con un modelo de capacidad al lado

AWS usa literalmente la frase "por las consultas que ejecutas":

> "Athena SQL and Apache Spark on Amazon Athena are serverless, so there is no infrastructure to set up or manage, and you pay only for the queries you run."

Fuente: `https://docs.aws.amazon.com/athena/latest/ug/what-is.html`, verbatim, sin elisiones.

Y nombra su propio modelo por defecto con precisión quirúrgica:

> "You can use capacity reservations and per-query billing, based on data scanned, at the same time in the same account."

Fuente: `https://docs.aws.amazon.com/athena/latest/ug/capacity-management.html`, sección "Considerations and limitations", verbatim, sin elisiones.

**Este es el término del proveedor: `per-query billing, based on data scanned`.** No es "por petición" a secas: es por consulta *medida en datos escaneados*. Dos consultas idénticas en número cuestan distinto según cuántos bytes toquen. La skill debe usar la formulación completa.

Pero Athena **también** ofrece capacidad reservada, y ahí la forma cambia por completo:

> "Capacity is serverless and fully-managed by Athena and held for you as long as you need it."

> "Capacity is measured in Data Processing Units (DPUs). DPUs represent the serverless compute and memory resources used by Athena to access and process data on your behalf. One DPU typically provides […]. The number of DPUs that you hold influences the number of queries that you can run concurrently."

Fuente: `https://docs.aws.amazon.com/athena/latest/ug/capacity-management.html`, verbatim. **Elisión:** las vCPU y la memoria por DPU, conforme a la regla de no-números (es un tamaño de nodo).

**Nótese el verbo: `held for you as long as you need it`.** Capacidad retenida, facturada por DPU-hora. AWS llama "serverless" a ambos modelos.

### 5.2 BigQuery — "serverless" describe la ausencia de provisión, no la unidad de cargo

> "BigQuery is a serverless data analytics platform. You don't need to provision individual instances or virtual machines to use BigQuery. Instead, BigQuery automatically allocates computing resources as you need them. You can also reserve compute capacity ahead of time in the form of slots, which represent virtual CPUs. The pricing structure of BigQuery reflects this design."

Fuente: `https://cloud.google.com/bigquery/docs/pricing`, verbatim, sin elisiones.

**Éste es el texto decisivo de la claim 5.** Google define "serverless" por lo que el usuario **no** tiene que hacer (provisionar instancias o VMs) — no por cómo se cobra. Y en la misma frase admite el modelo de reserva de capacidad. La plataforma es "serverless" bajo **ambos** modelos de precio: el on-demand por bytes procesados (claim 1.1) y el de capacidad por slot-hora (claim 1.4). "Serverless" aquí es una afirmación sobre **operación**, no sobre **facturación**.

### 5.3 Redshift Serverless — el contraejemplo: capacidad-por-tiempo, NO por consulta

Qué es un RPU:

> "Amazon Redshift Serverless measures data warehouse capacity in Redshift Processing Units (RPUs). RPUs are resources used to handle workloads. One RPU provides […]."

Fuente: `https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-capacity.html`, verbatim. **Elisión:** la memoria por RPU, conforme a la regla de no-números.

Cómo se factura:

> "When queries run, you're billed according to the capacity used in a given duration, in RPU hours on a per-second basis. When no queries are running, you aren't billed for compute capacity. You are also charged for Redshift Managed Storage (RMS), based on the amount of data stored."

Fuente: `https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-billing-on-demand.html`, verbatim, sin elisiones.

> "You pay for the workloads you run in RPU-hours on a per-second basis, with a […] minimum charge."

Fuente: misma página, sección "Usage notes for determining usage and cost", verbatim. **Elisión:** la duración concreta del mínimo, conforme a la regla de no-números.

**La respuesta explícita a la pregunta de la claim:** un RPU es una **unidad de capacidad** (`measures data warehouse capacity`), y la facturación es **capacidad × duración** (`the capacity used in a given duration, in RPU hours on a per-second basis`), con un mínimo. **No es por consulta.** La palabra "query" aparece solo para delimitar *cuándo* corre el reloj (`When queries run` / `When no queries are running`), no como unidad de cobro. Dos consultas de igual duración sobre distinta capacidad cuestan distinto, y una sola consulta larga cuesta según el tiempo de capacidad que retenga.

Además, Redshift Serverless también admite compra anticipada:

> "You can purchase capacity for Amazon Redshift Serverless in two ways: You can purchase on-demand capacity – When you choose on-demand compute capacity, you pay for resources as you go. […] You can purchase reservations – A reservation provides a discount when you buy a preset amount of compute resources for a specific amount of time, for example for a year."

Fuente: `https://docs.aws.amazon.com/redshift/latest/mgmt/serverless-billing.html`, verbatim. **Elisión:** frases intermedias de recomendación de uso, no cifras.

### 5.4 El contraste, ordenado (verificado el 2026-08-08)

| Producto | ¿El proveedor lo llama "serverless"? | Unidad de cargo por defecto | ¿Existe modelo de capacidad? | ¿"Serverless" implica por-petición? |
|---|---|---|---|---|
| Athena SQL | Sí | `per-query billing, based on data scanned` (término de AWS) | Sí — Capacity Reservations en DPU-hora | **Parcialmente**: por consulta, pero medida en bytes escaneados |
| BigQuery | Sí — "serverless data analytics platform" | On-demand: bytes procesados (`per TiB`) | Sí — capacity pricing `per slot-hour` (editions) | **No**: "serverless" describe no provisionar, no cómo se cobra |
| Redshift Serverless | Sí, en el nombre del producto | `RPU-hours on a per-second basis` (capacidad × tiempo) | Sí — reservations, además del on-demand | **No**: es capacidad-tiempo, no por consulta |
| Snowflake (contraste) | Sí, para sus *serverless features* | `compute-hours` calculadas por segundo | Los warehouses gestionados por el usuario son el modelo base | **No**: sigue siendo tiempo de cómputo |

**La conclusión que la skill debe enunciar:** "serverless" en estos productos es, de forma consistente, una afirmación sobre **quién opera la infraestructura** (nadie provisiona nodos a mano), y de forma **inconsistente** una afirmación sobre la unidad de facturación. Preguntar "¿es serverless?" no responde "¿cómo me cobran?". Hay que leer la unidad en cada producto.

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | BigQuery on-demand cobra por bytes escaneados/procesados; existe un modelo de capacidad/slots como alternativa | **SUPPORTED** — verbatim; términos vigentes: "On-demand pricing (per TiB)" y "Capacity pricing (per slot-hour)" sobre BigQuery editions. Matices: `LIMIT` no reduce el cargo; el mínimo de facturación de capacidad es evitable vía fluid scaling |
| 2 | Snowflake factura créditos contra el uptime del warehouse, por segundo tras un mínimo; auto-suspend es la palanca | **SUPPORTED** — verbatim en las tres partes. Matiz: el mínimo **se reinicia en cada resume**, así que suspender demasiado agresivamente puede multiplicar cargos |
| 3 | Athena on-demand cobra por datos escaneados; por eso formato y particionado mueven la factura | **SUPPORTED** — verbatim; AWS enuncia la conexión él mismo ("you pay for the number of bytes scanned before decompression"). Matices: particionar de más fragmenta; columnar penaliza archivos pequeños |
| 4 | Storage cobra por separado almacenamiento, peticiones y egreso; el egreso produce lock-in | **CORRECTED** — la separación es real y está verificada en S3/GCS/Azure, pero **no es una taxonomía de tres**: S3 enumera seis componentes, GCS mete las operaciones dentro de "Data processing", Azure usa una lista de meters y su meter "Data transfer" ni siquiera es el egreso a internet. **La parte de "lock-in" es inferencia del repo, no afirmación de ningún proveedor** |
| 5 | Qué significa "serverless" en cada producto: ¿por petición o capacidad gestionada? | **CORRECTED** — no se puede generalizar. Athena = por consulta medida en bytes escaneados (+ reservas en DPU-hora); BigQuery = "serverless" describe no provisionar, con dos modelos de precio distintos; **Redshift Serverless = capacidad × tiempo en RPU-hours por segundo, NO por consulta** |

## Implicación para el skill

1. **Enseñar unidades, nunca montos.** Todas las claims verificadas se sostienen enteramente en unidades (`bytes procesados`, `slot-hour`, `créditos por tiempo de warehouse`, `bytes escaneados`, `RPU-hour`, `per GB/month`, `per transaction`, `per GB de salida`). Ninguna necesitó una cifra para quedar demostrada. Esto confirma que la regla de no-números es viable para este dominio, no una mutilación.
2. **Prohibir la frase "serverless significa que pagas por lo que usas" sin calificar.** Es la deriva más probable de esta skill. Redshift Serverless es el contraejemplo de una línea: se factura capacidad × tiempo. Escribir, en su lugar, "'serverless' significa que no provisionas nodos; **la unidad de cobro hay que leerla producto por producto**".
3. **Decir "por consulta, medido en bytes escaneados", no "por consulta".** Es el término literal de AWS (`per-query billing, based on data scanned`) y es la diferencia entre entender el modelo y no entenderlo: el número de consultas no predice la factura.
4. **Desmentir explícitamente el mito del `LIMIT`.** Google lo niega en su propia página de precios. Es un error frecuente y barato de corregir.
5. **No presentar auto-suspend como "cuanto más bajo, mejor".** La fuente dice que el mínimo de facturación se reinicia en cada resume; un auto-suspend demasiado agresivo sobre una carga intermitente puede aumentar el costo. Enseñar la palanca **con su contra-indicación**.
6. **No presentar el particionado ni el formato columnar como monótonamente buenos.** AWS documenta las dos contra-indicaciones (fragmentación por exceso de claves de partición; sobrecosto del formato columnar en archivos pequeños). Ambas deben viajar junto a la recomendación.
7. **Marcar el argumento de lock-in como razonamiento propio.** Lo verificado es la **asimetría** (entrada gratis, intra-región gratis, salida cobrada por GB). La conclusión de lock-in es del autor. La skill debe decir algo como "los proveedores documentan esta asimetría; la lectura de que produce lock-in es nuestra", y no atribuirla a AWS/Google/Microsoft.
8. **No afirmar que los tres proveedores facturan el egreso igual ni en el mismo sitio.** En Azure, el meter "Data transfer" de Blob Storage aplica al copiado inter-región; la salida de la región se cobra vía cargo de ancho de banda de red. Es una diferencia real de dónde aparece el cargo en la factura.
9. **No decir "el costo de object storage se divide en tres".** Ningún proveedor usa esa taxonomía. Decir "almacenamiento, peticiones y transferencia son **cargos separados** — entre otros — y cada proveedor los agrupa distinto".
