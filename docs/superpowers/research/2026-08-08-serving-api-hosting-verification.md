# Research: hosting de una API de servicio — nombres de producto vigentes, unidad de escalado, escalado a cero, forma de facturación y arranque en frío (AWS / Azure / GCP)

**Fecha:** 2026-08-08 (serie de entrega). **Fecha real de consulta de todas las páginas: 2026-08-12.** Esta área tiene la deriva de nombres más rápida de las tres verificadas de hoy — un producto de AWS está cerrado a clientes nuevos y hay dos primitivas nuevas en el catálogo. Todo nombre de producto queda sellado con la fecha de comprobación.

**Alcance:** verificación de las 5 claims que la skill `iac-cloud-data-engineering` necesita antes de nombrar producto alguno en el arquetipo 5 (`references/platform-archetypes.md`, "Serving-API hosting"). Hoy esa sección describe el arquetipo por sus ejes —`throughput shape`, `operational burden`, `ecosystem fit`— y no nombra ningún producto de hosting.

**Páginas consultadas** (todas el 2026-08-12):

AWS
- `https://docs.aws.amazon.com/lambda/latest/dg/welcome.html`
- `https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html`
- `https://docs.aws.amazon.com/lambda/latest/dg/provisioned-concurrency.html`
- `https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html`
- `https://aws.amazon.com/lambda/pricing/`
- `https://docs.aws.amazon.com/apprunner/latest/dg/what-is-apprunner.html`
- `https://docs.aws.amazon.com/apprunner/latest/dg/manage-autoscaling.html`
- `https://docs.aws.amazon.com/apprunner/latest/dg/apprunner-availability-change.html`
- `https://aws.amazon.com/apprunner/pricing/`
- `https://docs.aws.amazon.com/AmazonECS/latest/developerguide/express-service-overview.html`

Azure
- `https://learn.microsoft.com/en-us/azure/container-apps/overview`
- `https://learn.microsoft.com/en-us/azure/container-apps/scale-app`
- `https://learn.microsoft.com/en-us/azure/container-apps/billing`
- `https://learn.microsoft.com/en-us/azure/container-apps/cold-start`
- `https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale`
- `https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan`

Google Cloud
- `https://cloud.google.com/run/docs/overview/what-is-cloud-run`
- `https://cloud.google.com/run/docs/about-instance-autoscaling`
- `https://cloud.google.com/run/docs/configuring/min-instances`
- `https://cloud.google.com/run/pricing`

**Nota de método**: todas las páginas se descargaron con `curl -A "Mozilla/5.0 …"` y se convirtieron a texto plano con un script Python de stripping de HTML; los archivos quedaron en un directorio scratchpad local de la sesión y cada cita es grepeable en ellos. No hubo ningún 403.

Se usó `WebSearch` **dos veces, solo como descubrimiento**, y en ambos casos la cita final se tomó de la página oficial descargada por `curl`, no del resumen del buscador:
1. Para localizar la ruta de la documentación de **Amazon ECS Express Mode**: los candidatos obvios (`…/developerguide/express-mode.html`, `…/ecs-express-mode.html`) devuelven `200` **redirigiendo al índice de la guía**, no a la página. La ruta real es `express-service-overview.html`.
2. Para localizar la página de arranque en frío de Azure Container Apps, que no está enlazada desde `overview` ni desde `scale-app`.

**No se usó el MCP de Microsoft Learn como fuente citable.** Todas las citas de Azure provienen del HTML servido por `learn.microsoft.com`.

**Nota sobre elisión de cifras**: por la regla no-numbers del repo, ninguna cifra de este documento se reproduce: ni límites de concurrencia, ni conteos máximos de instancias/réplicas, ni tamaños de memoria, ni latencias, ni grants gratuitos, ni períodos mínimos de facturación. Donde una cita del proveedor contenía una cifra junto a la unidad, la cifra se elide como `[…]` y la unidad se conserva, porque la unidad es exactamente el objeto de las claims 2 y 4. Las **fechas** y los **identificadores de plan/producto** no son cifras y se conservan. Se conservan también, dentro de citas verbatim, dos casos que no son magnitudes: el **suelo semántico "al menos una"** (`"set the minimum number of replicas to 1 or higher"`, Microsoft) — elidirlo destruiría el significado de la frase, que es precisamente que basta con una réplica — y la **hora de un ejemplo ilustrativo** del propio proveedor (`"a job at 9am"`). Ninguno de los dos es precio, cuota, límite, tipo de instancia ni tamaño de nodo, y ninguno es una cantidad calculada por este documento.

---

## 1. Nombres de producto vigentes para hosting de contenedor y de función dirigido por petición

**VEREDICTO GLOBAL: CORRECTED**, y la corrección es de deriva: el mapa mental habitual —*Lambda / App Runner*, *Functions / Container Apps*, *Cloud Run functions / Cloud Run*— **ya no describe el catálogo de AWS al 2026-08-12**.

| Proveedor | Hosting de función | Hosting de contenedor dirigido por petición | Comprobado |
|---|---|---|---|
| AWS | **AWS Lambda**, con **dos primitivas**: *Lambda Functions* y *Lambda MicroVMs* | **Amazon ECS Express Mode** (recomendación vigente de AWS). **AWS App Runner: cerrado a clientes nuevos** | 2026-08-12 |
| Azure | **Azure Functions**, plan recomendado **Flex Consumption** | **Azure Container Apps** | 2026-08-12 |
| Google Cloud | **Cloud Run functions** (dentro de Cloud Run) | **Cloud Run**, recurso *service* | 2026-08-12 |

### 1.1 AWS — Lambda tiene hoy dos primitivas de cómputo. VEREDICTO PARCIAL: SUPPORTED

> "AWS Lambda is a serverless compute service. With Lambda, you can run code without provisioning or managing servers. Lambda automatically manages the underlying infrastructure – including server maintenance, capacity provisioning, scaling, and patching – so you can focus on your application logic."
>
> "Lambda provides two compute primitives, each designed for different workload patterns:
> - **Lambda Functions** – Run code in response to events or API calls without managing servers. …
> - **Lambda MicroVMs** – Isolated compute environments with near-instant startup and state retention for up to […] hours. …"

Fuente: `https://docs.aws.amazon.com/lambda/latest/dg/welcome.html`, verbatim; la duración de retención de estado se elide por la regla no-numbers.

**Dato de deriva**: escribir "Lambda es funciones" es hoy una simplificación que la propia página de bienvenida contradice. El skill, si nombra Lambda, debe decir *Lambda Functions* cuando se refiere a la primitiva dirigida por petición.

### 1.2 AWS — App Runner está cerrado a clientes nuevos. VEREDICTO PARCIAL: CORRECTED

Aviso presente en **todas** las páginas de la guía de App Runner consultadas, incluida la de bienvenida:

> "AWS App Runner is no longer open to new customers. Existing customers can continue to use the service as normal."

Fuente: `https://docs.aws.amazon.com/apprunner/latest/dg/what-is-apprunner.html`, verbatim.

Y la declaración completa, con la recomendación de sustitución nombrada por AWS:

> "After careful consideration, we decided to close AWS App Runner to new customers. Existing AWS App Runner customers can continue to use the service as normal, including creating new resources and services. AWS continues to invest in security and availability for AWS App Runner, but we do not plan to introduce new features."
>
> "We recommend that customers explore Amazon Elastic Container Service (Amazon ECS) Express Mode when migrating from AWS App Runner. Amazon ECS Express Mode preserves App Runner's operating simplicity while providing access to the broader Amazon ECS feature set. With a single API call, you provide a container image and two IAM roles, and Amazon ECS provisions a complete application stack in your AWS account, including an ECS service on Fargate, an Application Load Balancer, auto scaling, and networking. There is no additional charge for using Amazon ECS Express Mode. You pay only for the underlying AWS resources created to run your application."

Fuente: `https://docs.aws.amazon.com/apprunner/latest/dg/apprunner-availability-change.html`, verbatim. Comprobado 2026-08-12.

**Consecuencia directa para el skill**: nombrar App Runner como opción para trabajo nuevo sería un error de hecho, no de estilo. Nombrarlo *como origen de migración* sí es correcto.

### 1.3 AWS — el sustituto nombrado, en palabras de AWS. VEREDICTO PARCIAL: SUPPORTED

> "An Amazon ECS Express Mode service reduces the complexity of deploying containerized applications by providing sensible defaults and automating the configuration of supporting AWS services. Instead of managing configuration parameters across multiple services, an Express Mode service requires only three things to get started: A container image / A task execution role / An infrastructure role"
>
> "Amazon ECS Express Mode orchestrates and configures all necessary infrastructure: a Fargate-based ECS service with a unique accessible URL, load balancer with SSL/TLS, auto scaling policies, monitoring, and networking components."
>
> "Amazon ECS Express Mode services support either public or private HTTPS applications and automatically scale based on utilization or traffic."

Fuente: `https://docs.aws.amazon.com/AmazonECS/latest/developerguide/express-service-overview.html`, verbatim.

### 1.4 Azure — VEREDICTO PARCIAL: SUPPORTED

> "Azure Container Apps is a serverless platform for running containerized applications without managing the underlying infrastructure. Instead of configuring servers, orchestrating containers, and handling deployment details yourself, let Container Apps provide the up-to-date resources that keep your applications stable, secure, and scalable."

Fuente: `https://learn.microsoft.com/en-us/azure/container-apps/overview`, verbatim. La misma página lista "Deploying API endpoints" como primer uso común.

Del lado de funciones, Microsoft nombra un plan recomendado explícito:

> "Flex Consumption is a Linux-based Azure Functions hosting plan that builds on the Consumption pay for what you use serverless billing model. It gives you more flexibility and customizability by introducing private networking, instance memory size selection, and fast or large scale-out features while still using a serverless model. **Flex Consumption is the recommended serverless hosting plan for Azure Functions.**"

Fuente: `https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan`, verbatim (énfasis en el original de Microsoft, que lo marca como frase de recomendación).

### 1.5 Google Cloud — VEREDICTO PARCIAL: SUPPORTED

> "Cloud Run is a fully managed application platform for running your code, function, or container on top of Google's highly scalable infrastructure."

Fuente: `https://cloud.google.com/run/docs/overview/what-is-cloud-run`, verbatim.

Y los tres tipos de recurso, con la definición del que corresponde a este arquetipo:

> "**Service** — Responds to HTTP requests sent to a unique and stable endpoint, using stateless instances that autoscale based on a variety of key metrics, also responds to events and functions."
>
> "**Job** — Executes parallelizable tasks that are executed manually, or on a schedule, and run to completion."
>
> "**Worker pool** — Handles always-on background workloads such as pull-based workloads, for example, Kafka consumers, Pub/Sub pull queues, or RabbitMQ consumers."

Fuente: misma página, sección "Services, jobs, and worker pools: three ways to run your code", verbatim.

**Nota de nomenclatura relevante para el skill**: en Google, *function* y *container* no son productos distintos sino formas de desplegar en **el mismo** producto. Escribir "Cloud Functions vs. Cloud Run" ya no describe el catálogo; la página de overview enlaza "From Cloud Run functions (1st gen)" como ruta de migración.

---

## 2. La unidad de escalado que cada uno expone al usuario, con el término del proveedor

**VEREDICTO GLOBAL: SUPPORTED.** Los términos son distintos entre productos y ninguno es intercambiable.

| Producto | Unidad de escalado, término del proveedor | Qué gobierna el escalado |
|---|---|---|
| AWS Lambda Functions | **concurrency** (número de peticiones en vuelo); el recurso subyacente es la **execution environment** | peticiones concurrentes |
| Amazon ECS Express Mode | tarea de un **ECS service on Fargate** con *auto scaling policies* | "utilization or traffic" |
| Azure Container Apps | **replica** | reglas KEDA (HTTP, eventos, CPU/memoria) |
| Azure Functions (Flex Consumption) | **instance**, con **per-instance concurrency** | concurrencia configurada + eventos entrantes |
| Cloud Run (service) | **instance**, con **maximum concurrent requests per instance** | utilización de CPU y concurrencia de peticiones |

### 2.1 AWS Lambda — la unidad es *concurrency*, no "instancia"

> "Concurrency is the number of in-flight requests that your AWS Lambda function is handling at the same time. For each concurrent request, Lambda provisions a separate instance of your execution environment. As your functions receive more requests, Lambda automatically handles scaling the number of execution environments until you reach your account's concurrency limit."

Fuente: `https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html`, verbatim.

Los controles con nombre propio, que el skill no debe confundir entre sí:

> "**Reserved concurrency** – This sets both the maximum and minimum number of concurrent instances allocated to your function. When a function has reserved concurrency, no other function can use that concurrency. … Configuring reserved concurrency for a function incurs no additional charges."
>
> "**Provisioned concurrency** – This is the number of pre-initialized execution environments allocated to your function. … Configuring provisioned concurrency incurs additional charges to your AWS account."

Fuente: `https://docs.aws.amazon.com/lambda/latest/dg/provisioned-concurrency.html`, verbatim. *Reserved* es un límite y es gratis; *provisioned* es capacidad caliente y cuesta. Confundirlos es el error clásico del área.

### 2.2 Azure Container Apps — la unidad es la *replica*

> "Azure Container Apps manages automatic horizontal scaling through a set of declarative scaling rules. As a container app revision scales out, the platform creates new instances of the revision on demand. These instances are known as replicas."
>
> "To support this scaling behavior, Azure Container Apps uses KEDA (Kubernetes Event-driven Autoscaling). KEDA supports scaling against a variety of metrics like HTTP requests, queue messages, CPU and memory load, and event sources like Azure Service Bus, Azure Event Hubs, Apache Kafka, and Redis."

Fuente: `https://learn.microsoft.com/en-us/azure/container-apps/scale-app`, verbatim.

> "Limits define the minimum and maximum possible number of replicas per revision as your container app scales."

Fuente: misma página, verbatim.

### 2.3 Azure Functions — la unidad es la *instance*, con concurrencia por instancia

> "In the Flex Consumption plan, function instances dynamically scale out (up to […]) based on configured per-instance concurrency, incoming events, and per-function workloads for optimal efficiency."

Fuente: `https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale`, verbatim; el techo se elide.

> "Concurrency refers to the number of parallel executions of a function on an instance of your app. You can set a maximum number of concurrent executions that each instance handles at any given time. Concurrency directly affects how your app scales. At lower concurrency levels, you need more instances to handle the event-driven demand for a function."

Fuente: `https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan`, verbatim.

### 2.4 Cloud Run — la unidad es la *instance*, con los mecanismos de autoscaler nombrados

> "By default, each Cloud Run revision is automatically scaled to the number of instances needed to handle incoming requests, events, or CPU utilization."
>
> "Cloud Run autoscaler evaluates the following metrics periodically to determine the number of instances needed to serve traffic:
> - **CPU and concurrency utilization**: Cloud Run adjusts instance counts to keep average CPU and concurrency within target thresholds.
> - **Instance limits**: Cloud Run bounds the number of instances between the maximum and minimum limits you configure."
>
> "Cloud Run has two autoscaling mechanisms, metrics-based scaling and on-demand scaling to determine the number of instances needed to serve traffic."

Fuente: `https://cloud.google.com/run/docs/about-instance-autoscaling`, verbatim.

### 2.5 Amazon ECS Express Mode — **UNSUPPORTED en esta ronda**

La página de overview consultada dice que el servicio "automatically scale based on utilization or traffic" y que Express Mode crea "auto scaling policies", pero **no nombra la unidad de escalado** ni describe la política. Este documento **no** infiere "tarea de Fargate" como término del proveedor: es lo que se deduce de "a Fargate-based ECS service", pero AWS no lo enuncia como unidad de escalado en esta página. La claim 2 para ECS Express Mode queda **UNSUPPORTED** y requiere consultar `express-service-work.html` y `express-service-best-practices.html` en una ronda posterior.

---

## 3. Si cada uno escala a cero, citado del proveedor

**VEREDICTO GLOBAL: CORRECTED.** Ninguna de las tres nubes da un sí liso. Dos de los tres enunciados vendedores llevan **hedge explícito del propio proveedor**, y el hedge es exactamente el caso que un equipo de datos suele encontrarse.

| Producto | ¿Escala a cero? | Hedge del proveedor |
|---|---|---|
| Cloud Run (service) | **Sí, por defecto** | Con `instance-based billing`, escalar **desde** cero solo lo dispara una petición |
| Azure Container Apps | **"Most applications can scale to zero"** | "Applications that scale on CPU or memory load can't scale to zero" |
| Azure Functions (Flex Consumption) | **Sí** | "Improved cold start even when scaled to zero" |
| AWS Lambda Functions | no enunciado como "scale to zero" en las páginas consultadas | — |
| AWS App Runner | **No**: el default documentado es un *provisioned container instance* | — |
| Amazon ECS Express Mode | **UNSUPPORTED** — no enunciado en la página consultada | — |

### 3.1 Cloud Run — VEREDICTO PARCIAL: SUPPORTED

> "When a revision does not receive any traffic, by default, it is scaled to zero instances. You can change this default to specify an instance to be kept idle or 'warm' using the minimum instances setting."

Fuente: `https://cloud.google.com/run/docs/about-instance-autoscaling`, verbatim.

El hedge de Google, que el skill debe conservar porque afecta a cualquier servicio que haga trabajo fuera de la petición:

> "**Scaling from zero.** Scaling from zero can only be triggered by a request, so a service that is not processing requests cannot scale from zero. For these workloads, you can either set minimum instances > 0, or include a 'wake-up request' in your design to restart processing after scaling to zero."

Fuente: misma página, sección "Instance-based billing and autoscaling", verbatim.

### 3.2 Azure Container Apps — VEREDICTO PARCIAL: SUPPORTED **con el hedge en la misma frase**

> "Autoscale your apps based on any KEDA-supported scale trigger. Most applications can scale to zero ¹."
>
> "¹ Applications that scale on CPU or memory load can't scale to zero."

Fuente: `https://learn.microsoft.com/en-us/azure/container-apps/overview`, verbatim, incluida la nota al pie. Microsoft pone la excepción como llamada numerada en la misma línea del beneficio; reproducir el beneficio sin la nota sería tergiversar la fuente.

Y la contrapartida operativa, que Microsoft advierte del lado del escalado:

> "If you want to ensure that an instance of your revision is always running, set the minimum number of replicas to 1 or higher."

Fuente: `https://learn.microsoft.com/en-us/azure/container-apps/scale-app`, verbatim.

### 3.3 Azure Functions — VEREDICTO PARCIAL: SUPPORTED

De la tabla "Cold start behavior" comparativa de planes:

> "**Flex Consumption plan** — Improved cold start even when scaled to zero. Supports always ready instances to further reduce the delay when provisioning new instances."
>
> "**Consumption plan** — Apps can scale to zero when idle, meaning some requests might have more latencies at startup."
>
> "**Container Apps** — Depends on the minimum number of replicas: • When set to zero: apps can scale to zero when idle and some requests might have more latencies at startup. • When set to one or more: the host process runs continuously, which means that cold start isn't an issue."

Fuente: `https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale`, sección "Cold start behavior", verbatim.

### 3.4 AWS — VEREDICTO PARCIAL: CORRECTED para App Runner, UNSUPPORTED para el resto

App Runner **no** escala a cero: su modelo define un suelo de instancias provisionadas.

> "**Min size** – The minimum number of instances that App Runner can provision for your service. The service always has at least this number of provisioned instances. Some of these instances actively handle traffic. The remainder of them are part of the cost-effective compute capacity reserve, which is ready to be quickly activated. You pay for the memory usage of all the provisioned instances. You pay for the CPU usage of only the active subset."

Fuente: `https://docs.aws.amazon.com/apprunner/latest/dg/manage-autoscaling.html`, verbatim.

Y la página de precios confirma que el suelo por defecto no es cero:

> "When your active container instances are idle, App Runner scales back to your provisioned container instances (the default is […] provisioned container instance)."

Fuente: `https://aws.amazon.com/apprunner/pricing/`, verbatim; la cifra se elide.

**Para Lambda Functions este documento marca UNSUPPORTED, no SUPPORTED.** Es sabido que Lambda no cobra cuando no hay invocaciones, y la claim 4 recoge la cita que lo sostiene desde el lado del precio. Pero **ninguna de las páginas de Lambda consultadas usa la expresión "scale to zero"** ni enuncia la propiedad. Marcar SUPPORTED sería marcar como citado algo que se deduce del modelo de facturación. Para **Amazon ECS Express Mode** la situación es más clara aún: la página consultada no dice nada al respecto y, dado que el stack incluye un Application Load Balancer, **no debe asumirse**.

---

## 4. La forma de facturación de cada uno: por petición, provisionada, o híbrida

**VEREDICTO GLOBAL: CORRECTED.** La taxonomía de tres casillas de la claim no encaja: **la mayoría de estos productos son híbridos**, y el eje que de verdad los separa no es "petición vs. provisionado" sino **qué se paga mientras el proceso está vivo pero no atiende**.

| Producto | Forma | Medidores nombrados por el proveedor |
|---|---|---|
| Lambda Functions | híbrida | **per request** + **execution duration** medida en **GB-seconds** |
| Lambda MicroVMs | provisionada | **per instance-second** |
| App Runner | híbrida con suelo | memoria de *provisioned container instances* + vCPU y memoria de *active container instances*, **por segundo** |
| ECS Express Mode | pasarela: sin medidor propio | "no additional charge"; se paga Fargate + ALB + CloudWatch + transferencia |
| Container Apps (Consumption) | híbrida | **vCPU-seconds** + **GiB-seconds** + **HTTP requests**, con tarifa *idle* reducida |
| Functions Flex Consumption | híbrida | **GB-seconds** de memoria en ejecución + **número de ejecuciones**; con *always ready*, además una **baseline** en GB-seconds |
| Cloud Run, request-based | por petición efectiva | CPU y memoria **solo** mientras arranca, atiende o se apaga; tarifa *idle* si hay min instances |
| Cloud Run, instance-based | provisionada | CPU y memoria durante **toda la vida** de la instancia |

### 4.1 AWS Lambda — VEREDICTO PARCIAL: SUPPORTED

> "AWS Lambda is a serverless compute service that charges you only for what you use. Lambda Functions are priced per request and execution duration. Lambda MicroVMs are priced per instance-second."
>
> "Lambda Functions are priced based on the number of requests served and the duration your code runs, measured in GB-seconds. You choose the memory allocated to your function and get proportional CPU and resources."

Fuente: `https://aws.amazon.com/lambda/pricing/`, verbatim.

### 4.2 AWS App Runner — VEREDICTO PARCIAL: SUPPORTED

> "When your application is deployed, you pay for the memory provisioned in each container instance. Keeping your container instance's memory provisioned when your application is idle ensures it can deliver consistently low millisecond latency."
>
> "When your application is processing requests, you switch from provisioned container instances to active container instances that consume both memory and compute resources. You pay for the compute and any additional memory consumed in excess of the memory allocated by your provisioned container instances."
>
> "All container instance processing is billed per second, rounded up to the next nearest second."

Fuente: `https://aws.amazon.com/apprunner/pricing/`, verbatim.

### 4.3 Amazon ECS Express Mode — VEREDICTO PARCIAL: SUPPORTED, y la forma es "ninguna propia"

> "There is no additional charge for using an Amazon ECS Express Mode service. You pay only for the underlying AWS resources that are created to run your application, including: Fargate compute resources / Application Load Balancer / CloudWatch logs and metrics / Data transfer charges"

Fuente: `https://docs.aws.amazon.com/AmazonECS/latest/developerguide/express-service-overview.html`, verbatim.

**Consecuencia que el skill debe explicitar**: Express Mode no tiene forma de coste propia — hereda la de Fargate más la de un balanceador. Un balanceador es un recurso con medidor horario, y por tanto **el suelo de coste de este arquetipo en AWS no es cero**, independientemente del tráfico. Esto está *marcado como inferencia*: AWS enumera los componentes facturables, no afirma que el suelo sea distinto de cero.

### 4.4 Azure Container Apps — VEREDICTO PARCIAL: SUPPORTED

> "Billing for apps running in the Consumption plan consists of two types of charges:
> - **Resource consumption**: The amount of resources allocated to your container app on a per-second basis, billed in vCPU-seconds and GiB-seconds.
> - **HTTP requests**: The number of HTTP requests your container app receives."

Fuente: `https://learn.microsoft.com/en-us/azure/container-apps/billing`, verbatim. Es literalmente híbrida: consumo **y** peticiones.

> "The rate you pay for resource consumption depends on the state of your container app's revisions and replicas. By default, replicas are charged at an active rate. However, in certain conditions, a replica can enter an idle state. While in an idle state, resources are billed at a reduced rate."
>
> "**No replicas are running** — When a revision is scaled to zero replicas, no resource consumption charges are incurred."

Fuente: misma página, verbatim.

### 4.5 Azure Functions Flex Consumption — VEREDICTO PARCIAL: SUPPORTED

> "**On Demand** — When running in on demand mode, you are billed only for the amount of time your function code is executing on your available instances. In on demand mode, no minimum instance count is required. You're billed for:
> • The total amount of memory provisioned while each on demand instance is actively executing functions (in GB-seconds), minus a free grant of GB-s per month.
> • The total number of executions, minus a free grant (number) of executions per month."
>
> "**Always ready** — … When you have any always ready instances enabled, you're billed for:
> • The total amount of memory provisioned across all of your always ready instances, known as the baseline (in GB-seconds).
> • The total amount of memory provisioned during the time each always ready instance is actively executing functions (in GB-seconds).
> • The total number of executions.
> In always ready billing, there are no free grants."

Fuente: `https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan`, sección "Billing", verbatim y **sin elisiones**: la propia página de Microsoft escribe "a free grant of GB-s per month" y "a free grant (number) of executions" sin cifras, remitiendo a la página de precios.

### 4.6 Cloud Run — VEREDICTO PARCIAL: SUPPORTED, y es el único donde la forma se selecciona

> "**Billable instance time for services with Request-based billing** — By default, Cloud Run only charges for the CPU and memory allocated to an instance when: The instance is starting. / The instance is gracefully shutting down (handling the SIGTERM signal). / At least one request is being processed by the instance. …"
>
> "If you set a minimum number of instances, you are also billed at a different 'idle' rate when these instances are not processing requests."
>
> "**Billable instance time for services with Instance-based billing** — When you opt-into having Instance-based billing, you are billed for the entire lifetime any Cloud Run container instances: from the time the container is started to when it is terminated, with a minimum of […]."

Fuente: `https://cloud.google.com/run/pricing`, verbatim; el mínimo facturable se elide.

Y las unidades:

> "The following pricing tables use the GiB-second unit. A GiB-second means for example running a […] instance for […], or running a […] instance for […]. The same principle applies for the vCPU-second unit."

Fuente: misma página, verbatim con las cifras del ejemplo elididas.

> "Requests are only billed when they reach the container after successfully being authenticated, requests denied by IAM policy are not billed."

Fuente: misma página, verbatim.

---

## 5. Si el arranque en frío es comportamiento documentado, y cómo llama cada proveedor a su mitigación

**VEREDICTO GLOBAL: SUPPORTED**, con un hallazgo que cambia el consejo: **Azure Container Apps documenta el arranque en frío pero no vende ninguna función con nombre para mitigarlo.** Las mitigaciones que Microsoft lista allí son de ingeniería de imagen, no de plataforma.

| Producto | ¿Documentado? | Nombre de la mitigación, en palabras del proveedor |
|---|---|---|
| AWS Lambda | sí, explícito | **provisioned concurrency**; **Lambda SnapStart** |
| Azure Functions | sí, tabla dedicada | **always ready instances** (Flex Consumption y Premium); *prewarmed placeholder functions* en Consumption |
| Azure Container Apps | sí, página dedicada | **ninguna función con nombre**; `minReplicas` por encima de cero, tamaño de imagen, registro cercano, probes, "proactively wake your app" |
| Cloud Run | sí, en el autoscaler | **minimum instances** — "instances to be kept warm and ready to serve requests" |
| ECS Express Mode | **UNSUPPORTED** — no enunciado | — |

### 5.1 AWS Lambda — mitigaciones con nombre propio

> "Provisioned concurrency – This is the number of pre-initialized execution environments allocated to your function. These execution environments are ready to respond immediately to incoming function requests. Provisioned concurrency is useful for reducing cold start latencies for functions and designed to make functions available with […] millisecond response times."
>
> "A function using provisioned concurrency does not exhibit cold start behavior since the execution environment is prepared ahead of invocation. However, provisioned concurrency must be applied to a specific version or alias of a function, not the $LATEST version."

Fuente: `https://docs.aws.amazon.com/lambda/latest/dg/provisioned-concurrency.html`, verbatim; la magnitud de latencia se elide.

La segunda mitigación, con mecanismo distinto:

> "The largest contributor to startup latency (often referred to as cold start time) is the time that Lambda spends initializing the function, which includes loading the function's code, starting the runtime, and initializing the function code. With SnapStart, Lambda initializes your function when you publish a function version. Lambda takes a Firecracker MicroVM snapshot of the memory and disk state of the initialized execution environment, encrypts the snapshot, and intelligently caches it to optimize retrieval latency."
>
> "When you invoke the function version for the first time, and as the invocations scale up, Lambda resumes new execution environments from the cached snapshot instead of initializing them from scratch, improving startup latency."

Fuente: `https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html`, verbatim.

**Hedge de AWS que el skill debe conservar sin suavizar:**

> "SnapStart works best when used with function invocations at scale. Functions that are invoked infrequently might not experience the same performance improvements."

Fuente: misma página, verbatim. Es decir: la mitigación que suena ideal para una API de bajo tráfico es la que AWS advierte que sirve peor ahí.

### 5.2 Azure Functions — *always ready instances*

> "Flex Consumption includes an always ready feature that you can use to choose instances that are always running and assigned to each of your per-function scale groups or functions. Always ready is a great option for scenarios where you need to have a minimum number of instances always ready to handle requests. For example, it reduces your application's cold start latency. The default is […]."
>
> "Always ready instances are separate from on-demand instances: the maximum instance count limits only on-demand instances and doesn't apply to always ready instances."
>
> "Use always ready instances to pre-provision capacity for known bursts and to reduce cold starts, since they bypass the on-demand scale-out rate."

Fuente: `https://learn.microsoft.com/en-us/azure/azure-functions/flex-consumption-plan`, verbatim; el valor por defecto se elide.

Y para el plan Consumption clásico, Microsoft nombra otro mecanismo:

> "Apps can scale to zero when idle, meaning some requests might have more latencies at startup. The consumption plan does have some optimizations to help decrease cold start time, including pulling from prewarmed placeholder functions that already have the host and language processes running."

Fuente: `https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale`, verbatim.

### 5.3 Azure Container Apps — documentado, sin producto de mitigación

> "When your container app scales to zero during periods of inactivity, the next incoming request triggers a cold start. A cold-start is the time-consuming process of pulling your container image, provisioning resources, and starting your application code."
>
> "This delay impacts user experience, especially for applications that require rapid response times. Cold-starts are often most noticeable in scenarios involving large container images, complex application initialization, or ML/AI workloads."

Fuente: `https://learn.microsoft.com/en-us/azure/container-apps/cold-start`, verbatim.

Las mitigaciones que Microsoft lista en esa página son, literalmente, sus encabezados de sección: **"Optimize container image size"**, **"Avoid far away image registries"**, **"Manage large downloads"**, **"Implement custom liveness health probe or start listening early"**, **"Client-side accommodations"**, **"Application-side instrumentation"** y **"Proactively wake your app"**. Ninguna es una función de plataforma con nombre comercial. La última lo dice sin rodeos:

> "If the above recommendations don't provide the desired performance, wake your app ahead of any actual usage. For example, consider setting up a job at 9am to wake the application ahead of employees starting their work day. This approach could eliminate lengthy cold-starts while still allowing for scale-to-zero cost-savings whenever the app isn't in use."

Fuente: misma página, verbatim.

**Hallazgo, marcado como inferencia**: la única mitigación de plataforma disponible en ACA es fijar `minReplicas` por encima de cero (citado en §3.2), lo cual **renuncia al escalado a cero**. Microsoft no enuncia esa disyuntiva como tal; se sigue de combinar esta página con la de escalado, y el skill debe presentarla como razonamiento, no como cita.

### 5.4 Cloud Run — *minimum instances*

> "Since on-demand scaling responds in real time to sudden traffic changes, Cloud Run manages the trade-off between cold start latency (the time to start a new instance) and pending queue latency (the time a request waits for a slot to open on an existing instance)."

Fuente: `https://cloud.google.com/run/docs/about-instance-autoscaling`, verbatim.

> "If you need more control over your service's autoscaling behavior, you can set a minimum number of instances to avoid slow container start times and reduce service latency. … However, if your service requires reduced latency, especially when scaling from zero active instances, you can change this default behavior by specifying a minimum number of container instances to be kept warm and ready to serve requests."

Fuente: `https://cloud.google.com/run/docs/configuring/min-instances`, verbatim.

**Hedge de Google que el skill debe conservar:**

> "Minimum instances are a best-effort target to keep instances warm and ready. You might experience temporary drops below your configured minimum instances due to the following unmitigated risks, even if you configure […] or more instances"

Fuente: misma página, verbatim; el umbral se elide. *Best-effort target*, no garantía.

---

## Resumen de veredictos

| # | Claim | AWS | Azure | GCP | Veredicto global |
|---|---|---|---|---|---|
| 1 | Nombres de producto vigentes | **CORRECTED** — *Lambda Functions* / *Lambda MicroVMs*; **App Runner cerrado a clientes nuevos**; sustituto nombrado por AWS: **Amazon ECS Express Mode** | **SUPPORTED** — *Azure Container Apps*; *Azure Functions* con **Flex Consumption** como plan serverless recomendado | **SUPPORTED** — *Cloud Run* (service / job / worker pool); *Cloud Run functions* dentro del mismo producto | **CORRECTED** |
| 2 | Unidad de escalado, término del proveedor | **SUPPORTED** para Lambda (*concurrency* / *execution environment*); **UNSUPPORTED** para ECS Express Mode | **SUPPORTED** — ACA: *replica*; Functions: *instance* + *per-instance concurrency* | **SUPPORTED** — *instance*, con *maximum concurrent requests per instance* | **SUPPORTED** (con una casilla UNSUPPORTED) |
| 3 | ¿Escala a cero? | **CORRECTED** — App Runner **no** (suelo de *provisioned container instances*); Lambda **UNSUPPORTED** (no enunciado); ECS Express Mode **UNSUPPORTED** | **SUPPORTED con hedge literal** — "Most applications can scale to zero¹", "¹ Applications that scale on CPU or memory load can't scale to zero" | **SUPPORTED** — "by default, it is scaled to zero instances", con el hedge de que salir de cero solo lo dispara una petición | **CORRECTED** |
| 4 | Forma de facturación | **SUPPORTED** — Lambda: *per request* + *duration* en GB-seconds; MicroVMs: *per instance-second*; App Runner: provisionada + activa, por segundo; ECS Express: **sin medidor propio**, se paga Fargate + ALB | **SUPPORTED** — ACA: vCPU-seconds + GiB-seconds + HTTP requests, con tarifa *idle*; Functions Flex: GB-seconds + ejecuciones, más *baseline* si hay always ready | **SUPPORTED** — dos formas seleccionables: *request-based* e *instance-based* | **CORRECTED** — la taxonomía de tres casillas no aplica: casi todos son híbridos |
| 5 | Arranque en frío y nombre de la mitigación | **SUPPORTED** — *provisioned concurrency* y *Lambda SnapStart*, con el hedge de que SnapStart rinde peor con invocación infrecuente; ECS Express **UNSUPPORTED** | **SUPPORTED** — Functions: *always ready instances* y *prewarmed placeholder functions*; **ACA: página dedicada, ninguna función de plataforma con nombre** | **SUPPORTED** — *minimum instances*, "kept warm and ready", declarado **best-effort target** | **SUPPORTED** |

## Implicación para el skill

1. **El arquetipo 5 ya puede nombrar producto**, con estas advertencias de deriva selladas al 2026-08-12: **no proponer AWS App Runner para trabajo nuevo** (cerrado a clientes nuevos), y **nombrar Amazon ECS Express Mode** como lo que AWS recomienda en su lugar. Nombrar *Lambda Functions*, no "Lambda", cuando se habla de la primitiva dirigida por petición.

2. **Reformular el eje `throughput shape` de ese arquetipo con la distinción que las fuentes sí sostienen.** No es "por petición vs. provisionado" —casi todos son híbridos— sino **qué se paga mientras el proceso está vivo y no atiende**: nada (Cloud Run request-based sin min instances; ACA con cero réplicas), una tarifa *idle* reducida (Cloud Run con min instances; ACA con réplicas mínimas), o el recurso completo (Cloud Run instance-based; App Runner; always ready de Functions).

3. **El "cuesta cero cuando está ocioso" tiene excepciones que hay que nombrar.** (a) ACA no escala a cero si la regla de escalado es CPU o memoria — nota al pie de Microsoft, no interpretación. (b) Un servicio Cloud Run que hace trabajo fuera de la petición no puede salir de cero solo. (c) En AWS, la ruta de contenedor recomendada incluye un Application Load Balancer, y un balanceador tiene medidor horario (inferencia declarada, ver §4.3).

4. **Al hablar de mitigación de arranque en frío, usar el nombre del proveedor y su hedge.** *provisioned concurrency* y *SnapStart* (AWS, con la advertencia de que SnapStart rinde peor precisamente con invocación infrecuente); *always ready instances* (Azure Functions); *minimum instances* (Cloud Run, declarado **best-effort target**, no garantía). **Para Azure Container Apps no existe un nombre que dar**: la mitigación de plataforma es renunciar al cero, y el resto son recomendaciones de ingeniería de imagen.

5. **No confundir *reserved concurrency* con *provisioned concurrency* en Lambda.** La primera es un límite y no cuesta; la segunda es capacidad caliente y sí. Es el error clásico de esta área y AWS lo distingue en la misma página.

6. **Lo que sigue siendo abstención**: la unidad de escalado de Amazon ECS Express Mode, si escala a cero, y si documenta arranque en frío. Son casillas UNSUPPORTED sobre el producto que AWS acaba de poner en el centro de este arquetipo. Hasta cerrarlas, el skill puede **nombrar** ECS Express Mode y citar su forma de coste, pero **no** puede describir su comportamiento de escalado.
