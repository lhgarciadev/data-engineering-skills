# Research: Cómputo Spark gestionado en las nubes — nombres de producto vigentes, variantes "serverless" y el estado real de Azure Synapse frente a Microsoft Fabric

**Fecha:** 2026-08-08
**Alcance:** verificación de 3 claims del Paso 4 del plan de implementación de la skill de IaC/cloud. Se verifica, contra documentación oficial de cada proveedor consultada el **2026-08-08**: (1) el nombre de producto **vigente hoy** de cada servicio de Spark gestionado, (2) cuáles ofrecen una variante *serverless* y con qué término exacto lo llama el proveedor, y (3) —el punto de mayor riesgo de deriva— el estado documentado **hoy** de Azure Synapse Analytics frente a Microsoft Fabric.

**Páginas consultadas (todas recuperadas el 2026-08-08):**

AWS
- `https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-what-is-emr.html`
- `https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/emr-serverless.html`
- `https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html`
- `https://docs.aws.amazon.com/glue/latest/dg/author-job-glue.html`
- `https://docs.aws.amazon.com/glue/latest/dg/etl-jobs-section.html`
- `https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming.html`
- `https://docs.aws.amazon.com/glue/latest/dg/worker-types.html`

Google Cloud
- `https://docs.cloud.google.com/managed-spark/docs/concepts/clusters-overview` (destino final de la redirección desde `https://cloud.google.com/dataproc/docs/concepts/overview`)
- `https://docs.cloud.google.com/managed-spark/docs/serverless-overview` (destino final de la redirección desde `https://cloud.google.com/dataproc-serverless/docs/overview`)
- `https://docs.cloud.google.com/managed-spark/docs/release-notes`

Databricks
- `https://docs.databricks.com/aws/en/introduction/` (sello "Last updated on Jul 28, 2026")
- `https://docs.databricks.com/aws/en/compute/` (sello "Last updated on Jul 10, 2026")
- `https://docs.databricks.com/aws/en/compute/serverless/` (sello "Last updated on Jul 30, 2026")

Microsoft
- `https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-what-is`
- `https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-faq`
- `https://learn.microsoft.com/en-us/azure/synapse-analytics/spark/apache-spark-overview`
- `https://learn.microsoft.com/en-us/azure/synapse-analytics/sql/overview-features`
- `https://learn.microsoft.com/en-us/fabric/fundamentals/microsoft-fabric-overview`
- `https://learn.microsoft.com/en-us/fabric/data-engineering/spark-compute`
- `https://learn.microsoft.com/en-us/fabric/data-engineering/comparison-between-fabric-and-azure-synapse-spark`
- `https://learn.microsoft.com/en-us/fabric/data-engineering/synapse-to-fabric-spark-migration-assistant`
- `https://learn.microsoft.com/en-us/fabric/real-time-intelligence/migrate-synapse-data-explorer`

---

## Nota de método

**Qué funcionó y qué no:**

1. **No hubo ningún 403 en este pase.** `curl -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"` recuperó con HTTP 200 todas las páginas de AWS, Google Cloud, Databricks y Microsoft Learn. El HTML se convirtió a texto plano con un script Python (eliminación de `<script>`/`<style>`, desescape de entidades) y **cada página se guardó en el directorio de fuentes crudas con prefijo `spark-`**, de modo que toda cita `>` de este documento es verificable con `grep` sobre esos archivos.

2. **Redirección silenciosa en Google Cloud — señal de renombre.** Al pedir las URLs históricas `cloud.google.com/dataproc/docs/concepts/overview` y `cloud.google.com/dataproc-serverless/docs/overview`, `curl -L` terminó en `docs.cloud.google.com/managed-spark/docs/...`. Esa redirección, y no la memoria, es la que puso sobre la mesa el renombre que se documenta en la claim 1.

3. **Advertencia importante sobre las herramientas MCP de Microsoft Learn: su índice de búsqueda puede devolver contenido que ya no existe en vivo.** `microsoft_docs_search` devolvió un fragmento atribuido a `https://learn.microsoft.com/fabric/data-factory/frequently-asked-questions` que contenía la frase "ADF and Synapse pipelines remain fully supported, and there are no plans for deprecation". Al verificar esa URL en vivo (tanto con `microsoft_docs_fetch` como con `curl -L`), **la página redirige a `https://learn.microsoft.com/en-us/fabric/data-factory/data-factory-overview` y la frase NO aparece en el contenido servido hoy**. Por esa razón **esa frase no se usa como evidencia en este documento**, aunque sea la cita que un resumen apresurado habría tomado como prueba de que "Microsoft dice que no hay planes de deprecación". Es exactamente el modo de fallo que este pase existe para prevenir.

4. **Consecuencia procedimental:** toda cita de Microsoft incluida abajo fue re-verificada con `curl` contra la URL en vivo antes de escribirse. Las páginas MCP se usaron solo para *descubrir* candidatos, nunca como fuente final de una cita.

5. **Regla de no-números aplicada.** Este documento no registra precios, cuotas, límites de servicio, tipos de instancia ni tamaños de nodo. Donde una cita textual contenía cifras (tamaños de worker, vCPU, memoria, segundos de arranque, número de conectores), **la cifra se elidió como `[…]`** y se indica en prosa. Solo se registra que la unidad de facturación/dimensionamiento **existe** y **cómo la llama el proveedor**.

---

## 1. Nombre de producto vigente de cada servicio, verificado contra doc en vivo

**VEREDICTO GLOBAL: CORRECTED** — cinco de los siete nombres se confirman verbatim, pero **Google Cloud renombró el producto dos veces** y ni "Dataproc" ni "Dataproc Serverless" ni "Google Cloud Serverless for Apache Spark" son el nombre vigente hoy. El plan asumía que la pregunta abierta era "Dataproc Serverless vs. Serverless for Apache Spark"; la respuesta correcta es que **ambos nombres están superados**.

### 1.1 Amazon EMR — **SUPPORTED**

> "Amazon EMR, which was previously called Amazon Elastic MapReduce, is a managed cluster platform that simplifies running big data frameworks, such as Apache Hadoop and Apache Spark , on AWS to process and analyze vast amounts of data."

Fuente: `https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-what-is-emr.html` (consultada 2026-08-08), verbatim. Nótese que la propia página **registra el renombre histórico** ("previously called Amazon Elastic MapReduce"): el nombre vigente es **Amazon EMR**.

### 1.2 Amazon EMR Serverless — **SUPPORTED**

> "Amazon EMR Serverless is a deployment option for Amazon EMR that provides a serverless runtime environment. This simplifies the operation of analytics applications that use the latest open-source frameworks, such as Apache Spark and Apache Hive."

Fuente: `https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/emr-serverless.html` (consultada 2026-08-08), verbatim.

**Matiz que el skill debe preservar:** AWS **no** presenta EMR Serverless como un producto separado, sino como *"a deployment option for Amazon EMR"*. Escribir "EMR y EMR Serverless son dos servicios" contradice la formulación del proveedor.

### 1.3 AWS Glue — **SUPPORTED**, con precisión sobre cómo AWS nombra hoy su oferta Spark

El servicio se sigue llamando **AWS Glue**:

> "AWS Glue is a serverless data integration service that makes it easy for analytics users to discover, prepare, move, and integrate data from multiple sources."

Fuente: `https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html` (consultada 2026-08-08), verbatim.

Y el nombre que AWS usa **hoy** para la oferta Spark dentro de Glue es **"AWS Glue for Spark"**, no "Glue ETL" ni "Glue Spark jobs" a secas:

> "Working with Spark jobs in AWS Glue
> Provides information on AWS Glue for Spark ETL jobs.
> Topics
> Using job parameters in AWS Glue jobs
> AWS Glue Spark and PySpark jobs
> AWS Glue worker types
> Streaming ETL jobs in AWS Glue"

Fuente: `https://docs.aws.amazon.com/glue/latest/dg/etl-jobs-section.html` (consultada 2026-08-08), verbatim.

Corroborado en la sección de programación:

> "Programming Spark scripts
> [...] Topics
> Tutorial: Writing an AWS Glue for Spark script
> Program AWS Glue ETL scripts in PySpark
> Programming AWS Glue ETL scripts in Scala
> Features and optimizations for programming AWS Glue for Spark ETL scripts"

Fuente: `https://docs.aws.amazon.com/glue/latest/dg/aws-glue-programming.html` (consultada 2026-08-08), verbatim.

**Observación colateral (no es una claim de este pase, se registra por transparencia):** la tabla de contenidos de `what-is-glue.html` incluye una entrada titulada **"AWS Glue for Ray end of support"**. Es decir, el motor Ray de Glue está en fin de soporte, mientras que Glue for Spark no lo está. Si el skill llegara a mencionar "Glue soporta Spark y Ray", esa formulación ya está desactualizada.

### 1.4 Google Cloud — **CORRECTED** (el hallazgo principal de esta claim)

Las URLs históricas de Dataproc redirigen a un producto con **nombre nuevo**, y la doc lo declara explícitamente en un banner presente en todas las páginas del producto:

> ""Managed Service for Apache Spark" is the new name for the product formerly known as "Dataproc on Compute Engine" (cluster deployment) and "Google Cloud Serverless for Apache Spark" (serverless deployment)."

Fuente: banner global en `https://docs.cloud.google.com/managed-spark/docs/serverless-overview` y en `https://docs.cloud.google.com/managed-spark/docs/concepts/clusters-overview` (consultadas 2026-08-08), verbatim.

Los dos modos de despliegue se nombran así en sus páginas respectivas:

> "Managed Service for Apache Spark on clusters lets you take advantage of open source data tools for batch processing, querying, streaming, and machine learning."

Fuente: `https://docs.cloud.google.com/managed-spark/docs/concepts/clusters-overview` (consultada 2026-08-08), verbatim. Sello de la página: "Last updated 2026-07-29 UTC".

> "Managed Service for Apache Spark serverless lets you run Spark workloads without requiring you to provision and manage your own cluster. There are two ways to run Managed Service for Apache Spark workloads: batch workloads and interactive sessions."

Fuente: `https://docs.cloud.google.com/managed-spark/docs/serverless-overview` (consultada 2026-08-08), verbatim. Sello de la página: "Last updated 2026-07-29 UTC".

**Cadena de renombres, reconstruida desde las notas de versión del propio producto** (`https://docs.cloud.google.com/managed-spark/docs/release-notes`, consultada 2026-08-08):

- La entrada fechada **July 04, 2025** ya usa el primer renombre: *"Serverless for Apache Spark (formerly known as Dataproc Serverless for Spark) now supports OS Login organization policy."* (verbatim). En esa misma fecha las entradas de clúster todavía dicen "Dataproc on Compute Engine".
- La mención más antigua de "Managed Service for Apache Spark" en el archivo de notas de versión recuperado corresponde a la entrada fechada **January 24, 2026**; a partir de ahí las entradas usan sistemáticamente la fórmula *"Managed Service for Apache Spark (formerly Dataproc on Compute Engine)"* (verbatim, p. ej. en las entradas de mayo y junio de 2026).

**La simplificación popular vs. lo que dice la fuente:** la simplificación popular (y la que asume el plan) es "GCP = Dataproc, y su versión serverless es Dataproc Serverless". Hoy la fuente dice que el producto es **Managed Service for Apache Spark**, con dos despliegues: **"on clusters"** y **"serverless"**. El nombre "Dataproc" sobrevive únicamente como **identificador técnico heredado** —versiones de imagen (`3.5-dataproc-28`), propiedades de clúster (`dataproc:pypi.repository`), nombres de recursos como Dataproc Metastore— y en la fórmula "(formerly ...)". Ambas cosas deben registrarse: el nombre comercial cambió, el prefijo técnico no.

### 1.5 Databricks — **SUPPORTED**

> "Databricks is a unified, open analytics platform for building, deploying, sharing, and maintaining enterprise-grade data, analytics, and AI solutions at scale. The Databricks Data Intelligence Platform integrates with cloud storage and security in your cloud account, and manages and deploys cloud infrastructure for you."

Fuente: `https://docs.databricks.com/aws/en/introduction/` (consultada 2026-08-08; sello de la página "Last updated on Jul 28, 2026"), verbatim.

Databricks **no** nombra su cómputo Spark como un sub-producto con marca propia; lo llama simplemente "Databricks compute", clasificado en tres familias:

> "Databricks compute refers to the selection of computing resources available on Databricks to run your data engineering, data science, and analytics workloads. Choose from serverless compute for on-demand scaling, classic compute for customizable resources, or SQL warehouses for optimized analytics."

Fuente: `https://docs.databricks.com/aws/en/compute/` (consultada 2026-08-08; sello "Last updated on Jul 10, 2026"), verbatim.

### 1.6 Microsoft Fabric — **SUPPORTED**

El nombre del producto es **Microsoft Fabric**, y la oferta Spark **no** tiene un nombre de producto propio: es una carga de trabajo dentro de Fabric, referida como "Fabric Data Engineering":

> "Fabric Data Engineering and Data Science run on a fully managed Apache Spark compute platform. Starter pools provide fast session startup, typically in […], with no manual setup. Custom Spark pools let you tune node size, scaling behavior, and other compute settings for your workload."

Fuente: `https://learn.microsoft.com/en-us/fabric/data-engineering/spark-compute` (consultada 2026-08-08), verbatim salvo la cifra de tiempo de arranque, elidida como `[…]` por la regla de no-números.

### 1.7 Azure Synapse Analytics — **SUPPORTED** (el nombre sigue vigente; su *estado* es la claim 3)

> "Azure Synapse is an enterprise analytics service that accelerates time to insight across data warehouses and big data systems. Azure Synapse brings together the best of SQL technologies used in enterprise data warehousing, Spark technologies used for big data, Data Explorer for log and time series analytics, Pipelines for data integration and ETL/ELT, and deep integration with other Azure services such as Power BI, CosmosDB, and AzureML."

Fuente: `https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-what-is` (consultada 2026-08-08), verbatim.

Y el nombre de su motor Spark:

> "Apache Spark is a parallel processing framework that supports in-memory processing to boost the performance of big data analytic applications. Apache Spark in Azure Synapse Analytics is one of Microsoft's implementations of Apache Spark in the cloud."

Fuente: `https://learn.microsoft.com/en-us/azure/synapse-analytics/spark/apache-spark-overview` (consultada 2026-08-08), verbatim.

---

## 2. Cuáles ofrecen variante *serverless*, con el término del proveedor

**VEREDICTO GLOBAL: CORRECTED** — no todos los proveedores tienen una "variante serverless" en el mismo sentido. En **tres de los seis** casos la palabra "serverless" es **parte de un nombre de producto o de una descripción de marketing**, no la designación de un modelo de facturación distinto; y en **uno** (Fabric) el proveedor **no usa la palabra "serverless" en absoluto** para su cómputo Spark. Presentar una tabla uniforme "servicio → tiene serverless: sí/no" sería falso a la letra de las fuentes.

**Nota de alcance:** este pase verifica **la terminología**, no el modelo de cobro. La pregunta de facturación (qué se factura, por qué unidad, si hay coste en reposo) es del **Paso 2** y no se resuelve aquí. Donde abajo se dice "es nombre de producto, no modelo de facturación", eso es precisamente el traspaso a ese otro paso.

### 2.1 Amazon EMR — **SUPPORTED**. Término del proveedor: **"EMR Serverless"**, presentado como *deployment option*

> "Amazon EMR Serverless is a deployment option for Amazon EMR that provides a serverless runtime environment."

Fuente: `https://docs.aws.amazon.com/emr/latest/EMR-Serverless-UserGuide/emr-serverless.html` (consultada 2026-08-08), verbatim.

**Hedge registrado:** aunque se llame "serverless", la doc **sí expone unidades de cómputo al usuario** —las llama **"workers"**— y permite anular su tamaño:

> "An EMR Serverless application internally uses workers to execute your workloads. The default sizes of these workers are based on your application type and Amazon EMR release version. When you schedule a job run, override these sizes."

Fuente: misma página, verbatim. **No se registran tamaños** (regla de no-números): lo relevante para el skill es que la unidad se llama **"worker"** y que es configurable, no cuánto mide.

Además existe una función explícita de capacidad caliente, que el proveedor llama **"pre-initialized capacity"**:

> "EMR Serverless provides a pre-initialized capacity feature that keeps workers initialized and ready to respond in seconds. This capacity effectively creates a warm pool of workers for an application."

Fuente: misma página, verbatim. Esto tiene implicación de coste — cuestión del Paso 2, no de éste.

### 2.2 AWS Glue — **SUPPORTED** con matiz fuerte: "serverless" **no es una variante**, es la descripción del servicio entero

> "AWS Glue is a serverless data integration service..."

Fuente: `https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html` (consultada 2026-08-08), verbatim.

> "With AWS Glue Studio, you can visually compose data transformation workflows and seamlessly run them on AWS Glue's Apache Spark-based serverless ETL engine."

Fuente: `https://docs.aws.amazon.com/glue/latest/dg/author-job-glue.html` (consultada 2026-08-08), verbatim.

**Hedge registrado, y es importante:** Glue se autodenomina "serverless", pero la propia doc obliga al usuario a elegir un **"worker type"** y expone una unidad de cómputo llamada **DPU**:

> "AWS Glue provides multiple worker types to accommodate different workload requirements, from small streaming jobs to large-scale, memory-intensive data processing tasks."

> "Data Processing Units (DPUs) — The resources available on AWS Glue workers are measured in DPUs. A DPU is a relative measure of processing power that consists of […] vCPUs of compute capacity and […] of memory."

Fuente: `https://docs.aws.amazon.com/glue/latest/dg/worker-types.html` (consultada 2026-08-08), verbatim salvo las cifras de vCPU y memoria, elididas como `[…]`. También existen **"M-DPUs"** (Memory-Optimized DPUs) para los worker types de tipo R. Se registra únicamente **que las unidades se llaman DPU y M-DPU**, nunca su magnitud ni el número de DPUs de cada worker type.

Es decir: **"serverless" en Glue significa "no administras un clúster", no "no eliges tamaño de cómputo"**. El skill no debe usar Glue como ejemplo de "serverless puro".

### 2.3 Google Cloud — **SUPPORTED**, pero el término hoy es **parte del nombre del producto**

El término vigente ya no es "Dataproc Serverless" ni "Google Cloud Serverless for Apache Spark", sino **"Managed Service for Apache Spark serverless"** — es decir, un **modo de despliegue nombrado** dentro del producto renombrado:

> "Managed Service for Apache Spark serverless lets you run Spark workloads without requiring you to provision and manage your own cluster."

Fuente: `https://docs.cloud.google.com/managed-spark/docs/serverless-overview` (consultada 2026-08-08), verbatim.

Y el propio banner del producto lo tipifica explícitamente como *deployment*:

> ""Managed Service for Apache Spark" is the new name for the product formerly known as "Dataproc on Compute Engine" (cluster deployment) and "Google Cloud Serverless for Apache Spark" (serverless deployment)."

Fuente: banner global del producto (consultado 2026-08-08), verbatim.

**Hedge registrado:** la doc afirma que se cobra solo por tiempo de ejecución del workload — *"Charges apply only to the time when the workload is executing"* (verbatim, misma página). Eso es una afirmación de **facturación**, y su verificación corresponde al Paso 2; aquí solo se deja constancia de que la fuente la hace.

### 2.4 Databricks — **SUPPORTED**. Es el caso más limpio: "serverless compute" **es** una variante contrapuesta a "classic compute"

> "Choose from serverless compute for on-demand scaling, classic compute for customizable resources, or SQL warehouses for optimized analytics."

Fuente: `https://docs.databricks.com/aws/en/compute/` (consultada 2026-08-08), verbatim.

> "Serverless compute is a Databricks-managed service that allows users to quickly connect to on-demand computing resources for notebooks, workflows, and Lakeflow pipelines. When you choose to use serverless compute, you can run workloads without provisioning any compute resources in your cloud account. Instead, Databricks automatically allocates and manages the necessary compute resources."

Fuente: `https://docs.databricks.com/aws/en/compute/serverless/` (consultada 2026-08-08; sello "Last updated on Jul 30, 2026"), verbatim.

**Hedges registrados, ambos relevantes para el skill:**

1. "Serverless" en Databricks es **versionless**, lo que el skill no debe omitir porque tiene consecuencias de reproducibilidad:

> "Serverless compute is a versionless product, which means that Databricks automatically upgrades the serverless compute runtime to support enhancements and upgrades to the platform. All users get the same updates, rolled out over a short period of time."

Fuente: misma página, verbatim.

2. "Serverless compute" **no cubre todo lo serverless de Databricks**; la doc distingue explícitamente entre el serverless compute para notebooks/jobs/pipelines y otras funciones que corren sobre "serverless infrastructure" con su propia configuración:

> "Serverless compute is available by default in most workspaces and does not require enablement. Workspaces that have Unity Catalog enabled automatically have access to serverless compute. Other Databricks features, such as serverless SQL warehouses, model serving, and AI features, use serverless infrastructure independently and have their own configuration paths."

Fuente: misma página, verbatim. La unidad de consumo que la doc nombra es la **DBU** (mencionada en el FAQ de la misma página: *"How do I analyze DBU usage for a specific workload?"*, verbatim). Se registra el nombre de la unidad, no su magnitud ni su precio.

### 2.5 Microsoft Fabric — **UNSUPPORTED** para la palabra "serverless": el proveedor **no la usa** para su cómputo Spark

La página de cómputo Spark de Fabric describe la plataforma como **"fully managed"**, no como "serverless":

> "Fabric Data Engineering and Data Science run on a fully managed Apache Spark compute platform. Starter pools provide fast session startup, typically in […], with no manual setup. Custom Spark pools let you tune node size, scaling behavior, and other compute settings for your workload."

Fuente: `https://learn.microsoft.com/en-us/fabric/data-engineering/spark-compute` (consultada 2026-08-08), verbatim con la cifra de arranque elidida.

El dimensionamiento en Fabric está atado a una unidad que el proveedor llama **"capacity unit"**, y a una unidad de cómputo Spark llamada **"Spark vCore"**:

> "The size and number of nodes you can have in your custom Spark pool depends on your Fabric capacity. Capacity is a measure of how much computing power you can use."

Fuente: misma página, verbatim. La doc define además una equivalencia numérica entre "Spark vCores" y "capacity unit", y un "burst multiplier"; **esas cifras se omiten deliberadamente aquí** por la regla de no-números. Lo que el skill puede decir es que **las unidades se llaman "capacity unit" y "Spark vCore"** y que el paralelismo máximo está acotado por la capacidad contratada, nunca cuánto vale cada una.

**Conclusión de sub-veredicto:** afirmar "Fabric tiene una variante serverless" es **UNSUPPORTED**: ningún texto de la doc de cómputo Spark de Fabric usa esa palabra. Fabric es SaaS con capacidad reservada, que es un modelo distinto.

### 2.6 Azure Synapse Analytics — **CORRECTED**: usa "serverless" en dos sentidos incompatibles entre sí

**Sentido 1 (legítimo, es un modelo de consumo real):** el *serverless SQL pool*.

> "Synapse SQL offers both serverless and dedicated resource models. For predictable performance and cost, create dedicated SQL pools to reserve processing power for data stored in SQL tables. For unplanned or bursty workloads, use the always-available, serverless SQL endpoint."

Fuente: `https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-what-is` (consultada 2026-08-08), verbatim. Corroborado en la tabla de features:

> "Scaling — Dedicated: Yes. Serverless: Serverless SQL pool automatically scales depending on the workload."
> "Pause/resume — Dedicated: Yes. Serverless: Serverless SQL pool automatically deactivated when it is not used and activated when needed. User action is not required."

Fuente: `https://learn.microsoft.com/en-us/azure/synapse-analytics/sql/overview-features` (consultada 2026-08-08), verbatim.

**Sentido 2 (marketing, y aquí está la corrección):** Microsoft también llama "serverless" al **pool de Spark**, que sin embargo se dimensiona por nodos.

> "Azure Synapse makes it easy to create and configure a serverless Apache Spark pool in Azure."

Fuente: `https://learn.microsoft.com/en-us/azure/synapse-analytics/spark/apache-spark-overview` (consultada 2026-08-08), verbatim.

Ese mismo documento describe, unas líneas más abajo, un recurso que se apaga tras un tiempo de inactividad configurable y cuyos nodos se cuentan explícitamente ("Spark instances start in approximately […] for fewer than […] nodes"; cifras elididas). Y la comparación oficial Fabric-vs-Synapse tabula para Synapse Spark un "Custom pool", "Adjustable node sizes", "Node size family" y "Minimum node configuration" — es decir, **un recurso dimensionado por nodo**.

Fuente: `https://learn.microsoft.com/en-us/fabric/data-engineering/comparison-between-fabric-and-azure-synapse-spark` (consultada 2026-08-08).

**Simplificación popular vs. fuente:** la lectura popular de "serverless Apache Spark pool" es "Synapse Spark es serverless igual que EMR Serverless". La fuente no sostiene eso: en Synapse, "serverless" aplicado a Spark significa "no gestionas la infraestructura del clúster", mientras que "serverless" aplicado a SQL sí designa un modelo de consumo sin recurso reservado. El skill debe distinguirlos o no usar la palabra para el Spark de Synapse.

---

## 3. DRIFT CANDIDATE — Estado actual de Azure Synapse Analytics frente a Microsoft Fabric

**VEREDICTO: CORRECTED.**

La simplificación popular —y la que circula en blogs y en material de terceros— es *"Azure Synapse Analytics está deprecado / va a retirarse; Fabric lo reemplaza"*. **La documentación de Microsoft consultada el 2026-08-08 no dice eso.** Lo que dice es más matizado, y el matiz tiene consecuencias directas para el skill `sql-data-engineering`, que ya nombra ambos productos.

### 3.1 Qué dice la documentación HOY (2026-08-08)

**(a) La página "What is Azure Synapse Analytics?" describe el servicio en presente y NO contiene ningún aviso de retiro, deprecación ni mantenimiento.**

Verificación explícita: se descargó el HTML en vivo de `https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-what-is` con `curl` el 2026-08-08 y se buscaron las cadenas `retir`, `deprecat`, `end of support`, `no longer` y `Fabric` sobre el texto extraído. **La única coincidencia fue el aviso genérico de navegador ("This browser is no longer supported"); no hay ninguna mención de Fabric ni de retiro en esa página.** El texto sustantivo es el ya citado en §1.7:

> "Azure Synapse is an enterprise analytics service that accelerates time to insight across data warehouses and big data systems."

Fuente: `https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-what-is` (consultada 2026-08-08), verbatim.

**(b) La orientación oficial es "para lo nuevo, empieza en Fabric" — formulada como recomendación y ruta de actualización, NO como deprecación.** Este banner "Tip" aparece en las páginas de Synapse SQL:

> "Microsoft Fabric Data Warehouse is an enterprise scale relational warehouse on a data lake foundation, with a future-ready architecture, built-in AI, and new features. If you're new to data warehousing, start with Fabric Data Warehouse. Existing dedicated SQL pool workloads can upgrade to Fabric to access new capabilities across data science, real-time analytics, and reporting."

Fuente: `https://learn.microsoft.com/en-us/azure/synapse-analytics/sql/overview-features` (consultada 2026-08-08), verbatim. El mismo banner aparece en varias páginas de Synapse SQL. **Léase con precisión el hedge: dice "If you're new... start with Fabric" y "can upgrade" — condicional y voluntario. No dice "must migrate" ni fija fecha alguna.**

**(c) La propia documentación de Fabric sigue recomendando ACTIVAMENTE Azure Synapse Spark para casos concretos.** Este es el dato que más contradice la narrativa de "Synapse está muerto":

> "When to choose : Use Fabric Spark for unified analytics with OneLake storage, built-in CI/CD pipelines, and capacity-based scaling. Use Azure Synapse Spark when you need GPU-accelerated pools, external Hive Metastore, or JDBC connections."

Fuente: `https://learn.microsoft.com/en-us/fabric/data-engineering/comparison-between-fabric-and-azure-synapse-spark` (consultada 2026-08-08), verbatim.

La misma página lista como **"Key limitations in Fabric"** exactamente esas capacidades: *"External Hive Metastore: Not supported"*, *"GPU-accelerated pools: Not available"*, *".NET for Spark (C#): Not supported"* (verbatim). Es decir: Microsoft documenta que Fabric **todavía no cubre** funcionalidad que Synapse sí cubre.

**(d) Existe una ruta de migración oficial, y está en PREVIEW — no es un mandato.**

> "The Spark Synapse to Fabric Migration Assistant is currently in public preview."
> "Use the Spark Synapse to Fabric Spark Migration Assistant to migrate Spark workloads from Azure Synapse Analytics to Microsoft Fabric through a guided workflow."

Fuente: `https://learn.microsoft.com/en-us/fabric/data-engineering/synapse-to-fabric-spark-migration-assistant` (consultada 2026-08-08), verbatim.

**(e) SÍ hay retiros documentados, pero a nivel de COMPONENTE, no del servicio.** Dos casos concretos, ambos con lenguaje inequívoco:

Retiro con fecha declarada — Synapse Data Explorer (que estaba en Preview):

> "Azure Synapse Analytics Data Explorer (Preview) will be retired on October 7, 2025. After this date, workloads running on Synapse Data Explorer will be deleted, and the associated application data will be lost. We highly recommend migrating to Eventhouse in Microsoft Fabric."

Fuente: `https://learn.microsoft.com/en-us/fabric/real-time-intelligence/migrate-synapse-data-explorer` (consultada 2026-08-08), verbatim.

Fin de soporte para proyectos nuevos — Synapse Link for Cosmos DB:

> "Synapse Link for Cosmos DB is no longer supported for new projects. Don't use this feature.
> Please use Azure Cosmos DB Mirroring for Microsoft Fabric which is now GA. Mirroring provides the same zero-ETL benefits and is fully integrated with Microsoft Fabric."

Fuente: `https://learn.microsoft.com/en-us/azure/synapse-analytics/overview-faq` (consultada 2026-08-08), verbatim.

Nótese la asimetría con el resto del servicio: **cuando Microsoft retira algo, lo dice con esas palabras exactas ("will be retired on <fecha>", "no longer supported for new projects", "Don't use this feature"). Ese lenguaje NO aparece aplicado a Azure Synapse Analytics como servicio en ninguna página consultada.**

Y en la misma página FAQ, otro componente se declara GA en presente:

> "Azure Synapse Link for SQL is generally available for both SQL Server 2022 and Azure SQL Database."

Fuente: misma página, verbatim.

### 3.2 Lo que NO se pudo encontrar (declarado explícitamente)

**No se localizó ninguna página de documentación oficial de Microsoft que anuncie una fecha de retiro, una fase de mantenimiento o una deprecación de Azure Synapse Analytics como servicio.** Se buscó mediante `microsoft_docs_search` con cuatro formulaciones distintas (retiro/Fabric, "no longer accepting new workspaces", "no plans for deprecation", "what's new"), mediante `WebSearch`, y mediante inspección directa por `curl` de la página de overview y del FAQ. El resultado consistente es la ausencia de tal anuncio.

Esta ausencia se reporta como ausencia, no como prueba positiva de permanencia indefinida: **lo verificable es que hoy la documentación no declara retiro; lo no verificable es qué hará Microsoft después.**

### 3.3 Sobre la frase "there are no plans for deprecation"

Se declara con transparencia, porque es la trampa evidente de este pase: el índice de búsqueda de Microsoft Learn devolvió un fragmento con la frase *"ADF and Synapse pipelines remain fully supported, and there are no plans for deprecation"*, atribuido a `https://learn.microsoft.com/fabric/data-factory/frequently-asked-questions`. **Al comprobar esa URL en vivo el 2026-08-08, redirige (HTTP 200 tras redirección) a `https://learn.microsoft.com/en-us/fabric/data-factory/data-factory-overview`, y la frase no está presente en el contenido servido.** Por tanto:

- **no se usa esa frase como evidencia**;
- **el skill no debe escribir "Microsoft dice que no hay planes de deprecación"**, porque esa afirmación ya no es citable contra una página viva;
- lo que sí es citable es todo lo de §3.1.

### 3.4 Formulación exacta que el skill debe usar

Ni "Synapse está deprecado" ni "Synapse y Fabric son alternativas equivalentes". La formulación fiel a las fuentes de hoy es:

*Redacción propuesta para el skill, **no es una cita**: el bloque siguiente es texto redactado por esta verificación a partir de las fuentes citadas en §3.1–§3.3, no una transcripción de ninguna página. Las citas verbatim que lo sustentan están en esas secciones, cada una con su URL.*

> Azure Synapse Analytics sigue siendo un servicio disponible y documentado en presente; Microsoft no ha publicado una fecha de retiro para el servicio. La orientación oficial es que **el trabajo nuevo empiece en Microsoft Fabric** ("If you're new to data warehousing, start with Fabric Data Warehouse"), y existen asistentes de migración —algunos aún en preview— para llevar cargas de Synapse a Fabric. Al mismo tiempo, la propia documentación de Fabric sigue recomendando Azure Synapse Spark para capacidades que Fabric todavía no cubre. Componentes concretos de Synapse **sí** han sido retirados o cerrados a proyectos nuevos, con fecha y lenguaje explícitos; el servicio en su conjunto, no.

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| **1** | **Nombre de producto vigente de cada servicio, verificado en doc viva** | **CORRECTED** — 6 de 7 confirmados verbatim; Google Cloud renombró el producto y ni "Dataproc" ni "Dataproc Serverless" ni "Google Cloud Serverless for Apache Spark" son el nombre vigente |
| 1.1 | Amazon EMR | SUPPORTED — verbatim; la doc registra el renombre histórico desde "Amazon Elastic MapReduce" |
| 1.2 | Amazon EMR Serverless | SUPPORTED — verbatim; AWS lo llama *"a deployment option for Amazon EMR"*, no un servicio aparte |
| 1.3 | AWS Glue | SUPPORTED — verbatim; el nombre vigente de su oferta Spark es **"AWS Glue for Spark"**. Observación colateral: existe una página "AWS Glue for Ray end of support" |
| 1.4 | Google Cloud | **CORRECTED** — el nombre vigente es **"Managed Service for Apache Spark"**, con despliegues **"on clusters"** y **"serverless"**; "Dataproc" sobrevive solo como identificador técnico heredado |
| 1.5 | Databricks | SUPPORTED — verbatim; no hay marca separada para el cómputo Spark: "Databricks compute" |
| 1.6 | Microsoft Fabric | SUPPORTED — verbatim; el Spark de Fabric no tiene nombre de producto propio, es la carga "Fabric Data Engineering" |
| 1.7 | Azure Synapse Analytics | SUPPORTED — verbatim; el nombre sigue vigente (su *estado* es la claim 3) |
| **2** | **Variante serverless, con el término del proveedor** | **CORRECTED** — no es un sí/no uniforme: en tres casos "serverless" es nombre de producto o descripción de marketing, y en Fabric el proveedor no usa la palabra |
| 2.1 | Amazon EMR | SUPPORTED — "EMR Serverless", *deployment option*. Hedge: expone unidades llamadas **"workers"** (configurables) y **"pre-initialized capacity"** |
| 2.2 | AWS Glue | SUPPORTED con matiz — "serverless" describe **el servicio entero**, no una variante. Hedge: hay que elegir **"worker type"**, y la unidad se llama **DPU** / **M-DPU** |
| 2.3 | Google Cloud | SUPPORTED — término vigente **"Managed Service for Apache Spark serverless"**; el proveedor lo tipifica como *"serverless deployment"* |
| 2.4 | Databricks | SUPPORTED — caso más limpio: **"serverless compute"** vs **"classic compute"**. Hedges: es *versionless*; otras funciones usan "serverless infrastructure" por separado; unidad **DBU** |
| 2.5 | Microsoft Fabric | **UNSUPPORTED** — la doc de cómputo Spark de Fabric **no usa** la palabra "serverless"; dice **"fully managed"** y dimensiona por **"capacity unit"** / **"Spark vCore"** |
| 2.6 | Azure Synapse Analytics | **CORRECTED** — "serverless" designa un modelo de consumo real en **SQL pool**, pero es solo marketing en **"serverless Apache Spark pool"**, que se dimensiona por nodos |
| **3** | **Estado de Azure Synapse frente a Microsoft Fabric (DRIFT)** | **CORRECTED** — la doc de hoy **no** declara Synapse deprecado, en mantenimiento ni con fecha de retiro. Declara: Fabric como punto de partida recomendado para lo nuevo, asistentes de migración (algunos en preview), Synapse Spark aún recomendado para GPU/HMS externo/JDBC, y retiros **a nivel de componente** con fecha explícita |

---

## Implicación para el skill

**Sobre nombres (claim 1)**

- **No escribir "Dataproc" ni "Dataproc Serverless" como nombre actual.** Usar **"Managed Service for Apache Spark"** y sus dos despliegues, **"on clusters"** y **"serverless"**. Si el skill quiere ayudar al lector a reconocer material antiguo, citar la fórmula del proveedor: *"formerly Dataproc on Compute Engine"* / *"formerly Google Cloud Serverless for Apache Spark"*. Y advertir que el prefijo `dataproc` **sigue vivo** en versiones de imagen, propiedades de clúster y nombres de recursos, aunque el nombre comercial haya cambiado.
- **No presentar EMR y EMR Serverless como dos servicios.** AWS lo escribe como *"a deployment option for Amazon EMR"*.
- Si el skill nombra la oferta Spark de Glue, el término del proveedor es **"AWS Glue for Spark"**.
- **Este renombre tiene fecha de caducidad conocida.** Google renombró este producto **dos veces**, y las dos evidencias fechadas en sus propias notas de versión son la entrada del **04 de julio de 2025** (primer nombre nuevo ya en uso) y la del **24 de enero de 2026** (segundo nombre nuevo ya en uso); ver §1.4. Las fechas son lo sourced: son fechas de *entrada de release note en la que el nombre ya aparece*, no fechas del renombre en sí, así que no se deriva de ellas ningún intervalo. Cualquier nombre que el skill fije debe llevar la fecha de verificación adjunta.

**Sobre "serverless" (claim 2)**

- **No construir una tabla "servicio → serverless: sí/no".** Las fuentes no la sostienen. Lo que sí sostienen es una distinción de tres categorías: (a) variante *serverless* frente a variante clásica dentro del mismo producto (Databricks; Google Cloud); (b) *serverless* como descripción del servicio completo, que aun así te obliga a elegir tamaño de worker (AWS Glue; EMR Serverless en cierta medida); (c) SaaS con capacidad reservada, donde el proveedor **no usa la palabra** (Fabric).
- **No decir que Fabric tiene una variante serverless.** No hay texto que lo respalde.
- **No decir que "Synapse Spark es serverless" sin matizar.** Microsoft escribe "serverless Apache Spark pool", pero el recurso se dimensiona por nodos. Si el skill usa esa cita, debe registrar la tensión.
- El skill puede nombrar las unidades de cómputo/facturación —**DPU** y **M-DPU** (Glue), **worker** (EMR Serverless), **DBU** (Databricks), **capacity unit** y **Spark vCore** (Fabric)— **pero nunca sus magnitudes ni sus precios**. La pregunta de qué se cobra y cuándo pertenece al Paso 2.

**Sobre Synapse vs. Fabric (claim 3) — blast radius sobre `sql-data-engineering`**

- **Corregir cualquier frase del tipo "Synapse está deprecado" o "Synapse va a retirarse".** No hay documentación que lo respalde a 2026-08-08.
- **Corregir también la frase inversa**, "Synapse y Fabric son dos opciones equivalentes": la orientación oficial para trabajo nuevo es empezar en Fabric.
- Usar la formulación de §3.4. Es defendible con cuatro citas vivas y no fabrica una fecha que Microsoft no ha publicado.
- **Mantener las notas de Azure Synapse Analytics en `sql-data-engineering`**: el producto está vivo, documentado y —según la propia doc de Fabric— sigue siendo la elección recomendada para GPU, Hive Metastore externo y conexiones JDBC.
- Registrar en el skill la fecha de verificación (2026-08-08) junto a esta afirmación. Es el tipo de dato que cambia por anuncio corporativo, no por evolución técnica, y por tanto puede invalidarse de un día para otro sin ninguna señal en el código.
