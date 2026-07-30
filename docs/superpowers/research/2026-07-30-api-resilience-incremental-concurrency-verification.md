# Research: resiliencia en consumo de APIs para ingesta de datos — rate limiting, retry, extracción incremental, concurrencia, push vs. pull

**Fecha:** 2026-07-30
**Alcance:** verificación de 12 claims puntuales destinadas al material de referencia del skill `python-data-engineering` sobre consumo resiliente de APIs. Cada claim se contrastó contra fuente oficial/primaria — RFCs (IETF/RFC-Editor), documentación de vendor (AWS, Microsoft, Stripe, GitHub, Shopify, Salesforce, Airbyte, Fivetran, Databricks), documentación del propio lenguaje (Python `docs.python.org`), y la librería (`aiohttp`) — más el post canónico de AWS Architecture Blog exigido explícitamente para la claim 3. No se escribió contenido en los archivos del skill — solo este research file. Donde el fetch directo devolvía contenido truncado o vacío (RFC de gran tamaño vía WebFetch, blog de AWS con mucho HTML/CSS), se recurrió a `curl` + limpieza de HTML en este mismo entorno para obtener el texto verbatim en vez de depender de un resumen — esto se marca explícitamente en cada sección como "fetch directo (curl)".

---

## 1. `429 Too Many Requests` + `Retry-After` (RFC 9110 / RFC 6585)

**Veredicto: VERIFICADO, con una corrección de precisión sobre la relación entre las dos RFCs y sobre la frecuencia "almost always".**

**`Retry-After` — definición exacta, RFC 9110 §10.2.3** (fetch directo vía `curl` sobre el texto plano oficial, `rfc-editor.org/rfc/rfc9110.txt`, verbatim carácter por carácter):

> "Servers send the "Retry-After" header field to indicate how long the user agent ought to wait before making a follow-up request. When sent with a 503 (Service Unavailable) response, Retry-After indicates how long the service is expected to be unavailable to the client. When sent with any 3xx (Redirection) response, Retry-After indicates the minimum time that the user agent is asked to wait before issuing the redirected request.
>
> The Retry-After field value can be either an HTTP-date or a number of seconds to delay after receiving the response.
>
> Retry-After = HTTP-date / delay-seconds
>
> A delay-seconds value is a non-negative decimal integer, representing time in seconds.
>
> delay-seconds = 1\*DIGIT
>
> Two examples of its use are
>
> Retry-After: Fri, 31 Dec 1999 23:59:59 GMT
> Retry-After: 120
>
> In the latter example, the delay is 2 minutes."

Esto confirma exactamente el formato que pide la claim — HTTP-date o delay-seconds (entero no negativo en segundos) — palabra por palabra contra el spec. Fuente: [RFC 9110, §10.2.3 Retry-After](https://www.rfc-editor.org/rfc/rfc9110.html#section-10.2.3).

**Corrección 1 — la relación entre las dos RFCs no es "folded into".** El propio texto de RFC 9110 lista explícitamente qué RFCs obsoleta en su encabezado:

> "Obsoletes: 2818, 7230, 7231, 7232, 7233, 7235, 7538, 7615, 7694" — **RFC 6585 no está en esa lista.**

Y más adelante, RFC 9110 se refiere a RFC 6585 como una extensión externa todavía vigente, no como contenido absorbido:

> "Additional status codes related to capacity limits have been defined by extensions to HTTP [RFC6585]."

Fuente: mismo documento, encabezado y §17.2 (verificado por `curl` + `grep` sobre el texto completo — cero coincidencias de la cadena "429" en las ~10.000 líneas de RFC 9110, confirmando que el código de estado en sí ni siquiera aparece mencionado por número en el documento). El texto correcto para el skill sería algo como: *"429 Too Many Requests (definido por RFC 6585; RFC 9110 — la especificación vigente de HTTP Semantics — no lo obsoleta ni lo redefine, solo lo referencia como la extensión que define códigos de estado de límite de capacidad)"*.

**Corrección 2 — "almost always" no está respaldado por el spec.** RFC 6585 §4, que sí define 429 (fetch directo vía `curl`, verbatim):

> "The response representations SHOULD include details explaining the condition, and **MAY include a Retry-After header** indicating how long to wait before making a new request."

`MAY` — opcional por spec, no obligatorio. La regla de oro de "respetar `Retry-After` en vez de inventar tu propia espera" sigue siendo válida y correcta cuando el header está presente, pero el skill no debería decir que "casi siempre" viene — el spec explícitamente lo deja opcional, y por lo tanto un pipeline resiliente necesita un fallback (backoff exponencial propio) para cuando el 429 llega sin ese header. Corroboración práctica de esta ambigüedad — GitHub REST API, en su propia documentación de rate limits, condiciona la instrucción a que el header esté presente:

> "If the `retry-after` response header is present, you should not retry your request until after that many seconds has elapsed."

Fuente: [Rate limits for the REST API — GitHub Docs](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) (fetch directo). El "if present" de GitHub es la misma cautela que el "MAY" del RFC — ningún proveedor ni el spec garantizan el header en todo 429.

**Ejemplo textual de RFC 6585** (fetch directo vía `curl`, confirma que la propia RFC que define 429 ya muestra `Retry-After` como ejemplo de uso conjunto):

```
HTTP/1.1 429 Too Many Requests
Content-Type: text/html
Retry-After: 3600
```

---

## 2. Rate limiting proactivo del lado cliente — token bucket

**Veredicto: VERIFICADO.** Token bucket no es un concepto inventado ni solo académico — es el algoritmo que AWS documenta explícitamente como el mecanismo real de throttling de API Gateway (fetch directo):

> "API Gateway throttles requests to your API using the token bucket algorithm, where a token counts for a request... In the token bucket algorithm, a burst can allow pre-defined overrun of those limits... You can specify a *throttling rate*, which is the rate, in requests per second, that tokens are added to the token bucket. You can also specify a *throttling burst*, which is the capacity of the token bucket."

Fuente: [Throttle requests to your REST APIs — Amazon API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html). Esto confirma que "token bucket" no es solo terminología de libro de texto de redes — es el algoritmo nombrado y documentado por un vendor mayor como mecanismo de producción, con los dos parámetros exactos que la claim implica (tasa de repuesto de tokens = rate, tamaño del bucket = burst). Un cliente que implementa rate limiting proactivo (en vez de solo reaccionar a 429) está replicando del lado suyo el mismo algoritmo que el servidor usa del lado suyo — es una descripción precisa.

---

## 3. Exponential backoff + jitter — cita canónica AWS Architecture Blog

**Veredicto: VERIFICADO contra la fuente exacta pedida por la tarea, con dos precisiones de exactitud sobre la redacción.**

**URL exacta:** https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/ — "Exponential Backoff And Jitter", por Marc Brooker (AWS), publicado el 04 MAR 2015, con nota de actualización de mayo 2023. Confirmado por fetch directo del HTML vía `curl` (no por resumen de búsqueda) y limpieza manual de CSS/JS embebido para extraer el texto real del artículo — el fetch inicial vía la herramienta de WebFetch estaba parafraseando sobre HTML sin limpiar, así que se repitió con `curl` + parser propio para obtener las citas verbatim.

**Cita central sobre el problema (clusters/ráfagas sincronizadas de reintentos):**

> "The problem also stands out: there are still clusters of calls. Instead of reducing the number of clients competing in every round, we've just introduced times when no client is competing."

**Cita central sobre la solución (jitter, no solo backoff):**

> "The solution isn't to remove backoff. It's to add jitter. Initially, jitter may appear to be a counter-intuitive idea: trying to improve the performance of a system by adding randomness."

**Cita sobre el resultado medido:**

> "In the case with 100 contending clients, we've reduced our call count by more than half."

**Cita sobre el veredicto final del propio Marc Brooker/AWS — este es el respaldo más fuerte para "debe considerarse estándar":**

> "The return on implementation complexity of using jittered backoff is huge, and it should be considered a standard approach for remote clients."

**Fórmula "Full Jitter"** (verbatim, tal como aparece en el artículo):

> `sleep = random(0, min(cap, base * 2 ** attempt))`

**Nota de actualización de mayo 2023, que confirma adopción real en producción por AWS, no solo teoría de blog:**

> "Most AWS SDKs now support exponential backoff and jitter as part of their retry behavior when using standard or adaptive modes."

**Precisión 1 — "thundering herd" no es una frase del post.** Se hizo `grep` sobre el texto completo extraído del HTML (no solo sobre el resumen) buscando "thundering", "lockstep", "lock-step", "stampede", "synchroni" — **cero coincidencias**. El fenómeno que describe el artículo es exactamente el mismo que "thundering herd" describe en la industria (clientes que colisionan en ráfagas sincronizadas), pero esa terminología específica es un término de la industria/sistemas operativos (originado en el contexto de `accept()` con múltiples procesos/threads esperando una conexión) que el artículo de AWS no usa. Si el skill cita textualmente "thundering herd" como si fuera la frase de AWS, sería una atribución incorrecta — hay que presentarlo como el término estándar de la industria para el fenómeno que AWS sí describe y sí resuelve con el mismo mecanismo.

**Precisión 2 — el escenario concreto del post es contención de escritura OCC/DynamoDB, no genéricamente 5xx/timeout/429 de una API HTTP.** El artículo completo enmarca el problema como *optimistic concurrency control* (OCC) sobre escrituras condicionales de DynamoDB — "N clientes" compitiendo por actualizar la misma fila de base de datos, no clientes reintentando tras una falla transitoria de red/servidor. El mecanismo (exponential backoff con cap + jitter, fórmula Full Jitter) generaliza directamente al caso de reintentos por 5xx/timeout/429 — y de hecho es exactamente lo que implementan los SDKs de AWS para ese propósito, según la nota de actualización citada arriba — pero el ejemplo textual original del post no es ese escenario específico. Vale la pena que el skill sea preciso: la técnica es la misma y el post es la fuente canónica de la técnica, pero el "thousand clients that failed simultaneously" del claim es una generalización razonable del caso OCC descrito, no una cita textual de ese escenario exacto.

---

## 4. Circuit breaker

**Veredicto: VERIFICADO contra dos fuentes primarias independientes — Fowler (originador) y Microsoft Azure Architecture Center (vendor).**

**Martin Fowler, bliki** (fetch directo):

> "You wrap a protected function call in a circuit breaker object, which monitors for failures. Once the failures reach a certain threshold, the circuit breaker trips, and all further calls to the circuit breaker return with an error, without the protected call being made at all."

Fuente: [CircuitBreaker — martinfowler.com](https://martinfowler.com/bliki/CircuitBreaker.html).

**Microsoft Learn, Azure Architecture Center — versión con la máquina de estados completa** (fetch directo, texto completo confirmado):

> "You can implement the proxy as a state machine that includes the following states... **Closed:** The request from the application is routed to the operation. The proxy maintains a count of the number of recent failures. If the call to the operation is unsuccessful, the proxy increments this count. If the number of recent failures exceeds a specified threshold within a given time period, the proxy is placed into the **Open** state and starts a time-out timer... **Open:** The request from the application fails immediately and an exception is returned to the application... **Half-Open:** A limited number of requests from the application are allowed to pass through and invoke the operation. If these requests are successful, the circuit breaker assumes that the fault that caused the failure is fixed, and the circuit breaker switches to the **Closed** state."

Esta misma página de Microsoft menciona explícitamente 429/503 como las respuestas que típicamente disparan el patrón: *"A service can return HTTP 429 (too many requests) if it's throttling the client or HTTP 503 (service unavailable) if the service isn't available."* Fuente: [Circuit Breaker pattern — Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker). Ambas fuentes confirman exactamente la descripción de la claim: N fallos consecutivos → abrir el circuito → dejar de intentar por un tiempo, en vez de seguir golpeando un servicio caído.

---

## 5. Idempotency keys para POST — Stripe

**Veredicto: VERIFICADO.** Fetch directo de la documentación oficial de Stripe:

> "Idempotency keys allow you to safely retry requests without accidentally performing the same operation twice. When a connection error occurs, you can repeat the request without risk of creating a second object or performing the update twice."

Mecánica exacta — header `Idempotency-Key`, generación recomendada por UUID v4:

```
curl https://api.stripe.com/v1/customers \
  -u sk_test_...: \
  -H "Idempotency-Key: KG5LxwFBepaKHyUD" \
  -d description="My First Test Customer..."
```

Comportamiento de almacenamiento — las keys expiran a las 24 horas, y Stripe cachea la respuesta completa (incluyendo errores) del primer request para devolverla en reintentos con la misma key:

> "Keys are automatically removed after they're at least 24 hours old... Stripe saves the resulting status code and body of the first request for any given idempotency key, regardless of whether it succeeds or fails."

Fuente: [Idempotent Requests — Stripe API Reference](https://docs.stripe.com/api/idempotent_requests). Esto confirma exactamente el mecanismo que pide la claim, con el matiz adicional (no pedido explícitamente pero relevante para el skill) de que Stripe valida que los parámetros del reintento coincidan con los del request original antes de servir la respuesta cacheada.

---

## 6. Extracción incremental con margen de lookback/overlap

**Veredicto: VERIFICADO como patrón de vendor real — Airbyte lo documenta explícitamente con ese nombre.** Fetch directo:

> "The 'Lookback window' specifies a duration that is subtracted from the last cutoff date before starting to sync."

Razón documentada — exactamente el escenario de datos que llegan tarde/se actualizan después de su creación:

> Algunas APIs modifican registros existentes después de su creación pero solo permiten filtrar por fecha de creación, no de modificación. El lookback window permite recapturar esas actualizaciones tardías resincronizando desde un punto anterior al cutoff previo, en vez de perderse los cambios o tener que resincronizar todo el histórico.

Formato — duración ISO 8601 (ejemplo dado: `P2D` = 2 días), restada del cutoff anterior. Fuente: [Incremental Sync — Connector Builder, Airbyte Docs](https://docs.airbyte.com/platform/connector-development/connector-builder-ui/incremental-sync). Esta misma fuente y cita ya había sido verificada por fetch directo en el research previo del repo (`2026-07-30-incremental-extraction-watermark-verification.md`, §3a) — se reconfirma aquí de forma independiente para esta tarea.

**Precisión — la deduplicación vía `ROW_NUMBER()` es una técnica de implementación genérica, no una prescripción textual del vendor.** Airbyte documenta el *problema* (duplicados garantizados por el margen) y su *propia* solución (modo de sync "Incremental | Append + Deduped", que deduplica por clave primaria aguas abajo dentro de la plataforma) — pero no prescribe `ROW_NUMBER()` como técnica SQL específica. Si el skill menciona `ROW_NUMBER()` como ejemplo de cómo deduplicar, es una recomendación de implementación razonable y estándar en SQL, no una cita de Airbyte — debería presentarse así, sin atribuirla al vendor.

---

## 7. Full-refresh como reconciliación necesaria — límite de la incremental con deletes

**Veredicto: VERIFICADO — limitación real y documentada de forma independiente por dos vendors distintos, no fabricada.**

**Fivetran** (fetch directo, página de troubleshooting del conector PostgreSQL):

> "If you are using Query-Based incremental sync method with the Capture Deletes toggle turned off, this mechanism does not allow Fivetran to recognize deleted rows at all."

Workarounds documentados por el propio Fivetran: re-sincronizar la tabla individualmente, o re-sincronizar el conector completo (con la advertencia explícita de que esto último "may slow down the updates and cause significant processing overhead"). Fuente: [PostgreSQL Connector Not Capturing Deletes — Fivetran Docs](https://fivetran.com/docs/connectors/databases/postgresql/troubleshooting/connectors-not-capturing-deletes).

**Airbyte** (fetch directo, independiente de Fivetran):

> "The source you're syncing from does not sync record deletions/removals, and you wish to mirror the source stream, which would include removing deleted records" — este es el escenario explícito en el que Airbyte recomienda un "Refresh Sync" (que reinicia el cursor y vuelve a traer todo el histórico) precisamente para poder detectar y eliminar registros que ya no existen en el origen.

Fuente: [Refreshes — Airbyte Docs](https://docs.airbyte.com/platform/operator-guides/refreshes). Dos vendors de ELT mayores, de forma independiente, confirman la misma limitación estructural: la sincronización incremental por diseño solo ve inserts/updates (filas que siguen existiendo y tienen un timestamp/cursor mayor); un delete no deja rastro que un filtro `WHERE updated_at > watermark` pueda capturar, así que se necesita un mecanismo aparte (full refresh, capture-deletes basado en CDC, o un flag de soft-delete en origen).

---

## 8. Concurrencia I/O-bound: threads/async ayudan, procesos no son necesarios

**Veredicto: VERIFICADO contra la documentación oficial de Python.**

**`asyncio`** (fetch directo):

> "asyncio is often a perfect fit for IO-bound and high-level structured network code."

**`concurrent.futures`** (fetch directo) — el propio valor por defecto de `ThreadPoolExecutor` está justificado explícitamente por el caso I/O-bound:

> "If _max_workers_ is `None` or not given, it will default to the number of processors on the machine, multiplied by `5`, assuming that `ThreadPoolExecutor` is often used to overlap I/O instead of CPU work and the number of workers should be higher than the number of workers for `ProcessPoolExecutor`."

Y, en el otro extremo, la razón por la que `ProcessPoolExecutor` sí es necesario para CPU-bound — porque evita el GIL, cosa que threads/async no logran:

> "`ProcessPoolExecutor` uses the `multiprocessing` module, which allows it to side-step the Global Interpreter Lock"

Fuentes: [asyncio — Asynchronous I/O](https://docs.python.org/3/library/asyncio.html), [concurrent.futures — Launching parallel tasks](https://docs.python.org/3/library/concurrent.futures.html). Esto confirma con precisión la lógica de la claim: el GIL impide paralelismo real de CPU con threads, pero no es un obstáculo para I/O-bound (donde el tiempo se gasta esperando la red, con el GIL liberado durante esa espera) — por eso threads/`asyncio` bastan para ingesta de APIs, y `multiprocessing`/`ProcessPoolExecutor` solo se justifica cuando hay trabajo de CPU pesado (parseo/transformación intensiva), no por la llamada HTTP en sí.

---

## 9. `asyncio` + `aiohttp` con `Semaphore`, y reutilización de `ClientSession`

**Veredicto: PARCIALMENTE VERIFICADO — la reutilización de `ClientSession` sí es práctica oficialmente documentada por `aiohttp`; el uso de `asyncio.Semaphore` para acotar concurrencia es una técnica estándar de Python pero NO es algo que la documentación de `aiohttp` enseñe o recomiende explícitamente — hay que corregir la atribución.**

**Reutilización de `ClientSession` — sí, textual y enfático en la documentación oficial de `aiohttp`** (fetch directo):

> "Don't create a session per request. Most likely you need a session per application which performs all requests together."

Y, más fuerte todavía, en la misma página:

> "A session contains a connection pool inside. Connection reusage and keep-alive (both are on by default) may speed up total performance." — con advertencia explícita de que crear una sesión por request es "**a very bad idea**".

Fuente: [Client Quickstart — aiohttp docs](https://docs.aiohttp.org/en/stable/client_quickstart.html). Esta parte de la claim queda 100% verificada tal como está redactada.

**`asyncio.Semaphore` — no aparece en ningún lugar de la documentación oficial de `aiohttp` revisada.** Se hizo fetch directo de las tres páginas más relevantes — `client_quickstart.html`, `client_reference.html` y `client_advanced.html` — y ninguna menciona `Semaphore` ni `asyncio.Semaphore` como técnica de limitación de concurrencia. Lo que `aiohttp` sí documenta como su propio mecanismo para acotar conexiones simultáneas es el parámetro `limit` de `TCPConnector`:

> "To limit amount of simultaneously opened connections you can pass _limit_ parameter to _connector_: `conn = aiohttp.TCPConnector(limit=30)`" (default: 100 conexiones simultáneas totales; `limit_per_host` para acotar por host, default 0 = sin límite).

Fuente: [Client Advanced Usage — aiohttp docs](https://docs.aiohttp.org/en/stable/client_advanced.html), sección "Limiting connection pool size".

`asyncio.Semaphore`, en cambio, sí está documentado — pero por Python, no por `aiohttp` — como el primitivo estándar exactamente para este propósito (acotar cuántas corrutinas acceden concurrentemente a un recurso, el patrón típico en un `asyncio.gather` con fan-out):

> "A semaphore manages an internal counter which is decremented by each `acquire()` call and incremented by each `release()` call. The counter can never go below zero; when `acquire()` finds that it is zero, it blocks... The preferred way to use a Semaphore is an `async with` statement."

Fuente: [asyncio — Synchronization Primitives](https://docs.python.org/3/library/asyncio-sync.html) (fetch directo).

**Corrección para el skill:** combinar `asyncio.Semaphore` (para acotar cuántas requests están en vuelo simultáneamente dentro de un `gather`) con una `ClientSession` reutilizada (para pooling/keep-alive a nivel de conexión TCP) es una combinación real, común y sensata en código de producción con `aiohttp` — pero el skill no debería presentar el `Semaphore` como "la forma documentada por `aiohttp`" de limitar concurrencia. Debería atribuirse correctamente: `Semaphore` es un primitivo de `asyncio` (stdlib), y el mecanismo nativo de `aiohttp` para el mismo problema a nivel de conexión es `TCPConnector(limit=...)`. Ambos resuelven capas distintas del mismo problema (número de corrutinas en vuelo vs. número de conexiones TCP abiertas) y en la práctica se usan juntos, pero solo uno de los dos está "documentado por `aiohttp`" en sentido estricto.

---

## 10. Validación de schema en la frontera de ingesta — zona raw as-is, transformar después

**Veredicto: VERIFICADO como sanity check — consistente con la guía mainstream de arquitectura medallion/ELT.** Fetch directo de Databricks:

> "The table structures in this layer correspond to the source system table structures 'as-is,' along with any additional metadata columns."

Justificación explícita — exactamente la razón que da la claim (poder reprocesar sin volver a golpear el origen si la lógica de parseo tenía un bug):

> "The focus in this layer is quick Change Data Capture and the ability to provide an historical archive of source (cold storage), data lineage, auditability, **reprocess[ing] if needed without rereading the data from the source system**."

Fuente: [Medallion Architecture — Databricks Glossary](https://www.databricks.com/glossary/medallion-architecture). No hay nada en esta fuente ni en la práctica mainstream de ingeniería de datos que contradiga la idea de aterrizar el payload crudo (validado solo estructuralmente con Pydantic/`jsonschema` para no romper el escritor, no transformado semánticamente) antes de aplicar lógica de negocio en una capa posterior — es exactamente el patrón Bronze→Silver que este glosario describe.

---

## 11. Webhooks — at-least-once, duplicados, firma

**Veredicto: VERIFICADO contra Stripe (fuente citada directamente, fetch directo, cita inequívoca).**

> "Webhook endpoints might occasionally receive the same event more than once. You can guard against duplicated event receipts by logging the event IDs you've processed, and then not processing already-logged events.
>
> In some cases, two separate Event objects are generated and sent. To identify these duplicates, use the ID of the object in `data.object` along with the `event.type`."

Sobre validación de firma — también explícito y enfático:

> "Without verification, an attacker could send fake webhook events to your endpoint to trigger actions like fulfilling orders, granting account access, or modifying records. Always verify that webhook events originate from Stripe before acting on them... We recommend using our official libraries to verify signatures. You perform the verification by providing the event payload, the `Stripe-Signature` header, and the endpoint's secret."

Fuente: [Webhooks — Stripe Docs](https://docs.stripe.com/webhooks). Esto confirma exactamente los tres elementos de la claim para el caso de Stripe: (a) duplicados son un comportamiento reconocido y explícito, no un edge case teórico; (b) la mitigación recomendada por el propio vendor es idempotencia vía log de `event IDs` ya procesados; (c) validación de firma es obligatoria antes de actuar sobre el payload.

**Nota sobre GitHub como fuente alternativa — confianza más baja, no se usa como cita principal.** Se intentó verificar la misma semántica de "at-least-once/duplicados" directamente contra dos páginas oficiales de GitHub (`best-practices-for-using-webhooks` y `validating-webhook-deliveries`) — **ninguna de las dos, en el fetch directo, contiene lenguaje explícito sobre entregas duplicadas o redelivery**; solo cubren validación de firma (header `X-Hub-Signature-256`) y tiempos de respuesta (2XX en menos de 10s, procesamiento asíncrono recomendado). Una búsqueda indexada previa había sugerido que GitHub documenta esto vía el header `X-GitHub-Delivery`, pero **no se pudo confirmar esa afirmación específica por fetch directo de línea** — se descarta como cita de GitHub y se deja Stripe como la única fuente citada para esta claim, tal como permite la instrucción original ("cite one directly").

---

## 12. Bulk export como tercera vía para volúmenes grandes

**Veredicto: VERIFICADO — patrón real, documentado explícitamente por al menos dos vendors mayores con el mismo tradeoff (más rápido/barato que paginar).**

**Shopify Bulk Operations (GraphQL Admin API)** (fetch directo):

> "Instead of manually paginating results and managing a client-side throttle, you can instead run a bulk query operation."
>
> "With the GraphQL Admin API, you can use bulk operations to asynchronously fetch data in bulk. The API is designed to reduce complexity when dealing with pagination of large volumes of data."
>
> "Since you're only making low-cost requests for creating operations, polling their status, or canceling them, bulk operations are a very efficient way to query data compared to standard pagination queries."

Fuente: [Perform bulk operations with the GraphQL Admin API — Shopify Docs](https://shopify.dev/docs/api/usage/bulk-operations/queries). El formato de salida es JSONL, procesado como job asíncrono (se crea la operación, se hace polling del estado, se descarga el archivo resultante) — exactamente el patrón "bulk export a archivo" que describe la claim, no streaming request-por-página.

**Salesforce Bulk API — segunda fuente independiente, con umbral numérico explícito** (fetch directo):

> "Any data operation that includes more than 2,000 records is a good candidate for Bulk API 2.0 to successfully prepare, execute, and manage an _asynchronous_ workflow."
>
> "Jobs with fewer than 2,000 records should involve 'bulkified' _synchronous_ calls in REST (for example, Composite) or SOAP."

Fuente: [Bulk API and Bulk API 2.0 — Salesforce Developer Docs](https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/asynch_api_intro.htm). Dos vendors de dominios distintos (e-commerce, CRM) documentan de forma independiente el mismo patrón arquitectónico: por debajo de cierto volumen, la API síncrona/paginada estándar es más simple; por encima, un mecanismo de bulk export asíncrono a archivo es la vía recomendada explícitamente por el propio proveedor — confirma que no es un patrón inventado, es una categoría de API real y ampliamente ofrecida.

---

## Resumen de verificación por claim

| # | Claim | Veredicto | Confianza |
|---|---|---|---|
| 1 | 429 + `Retry-After` | VERIFICADO, con corrección: RFC 9110 no "absorbe" RFC 6585 (no está en su lista de `Obsoletes`); `Retry-After` es `MAY`, no garantizado | Fetch directo (curl) — RFC 9110, RFC 6585, GitHub rate limits |
| 2 | Token bucket | VERIFICADO | Fetch directo — AWS API Gateway docs |
| 3 | Exponential backoff + jitter (AWS blog) | VERIFICADO, con precisión: "thundering herd" no es la frase del post; el ejemplo original es OCC/DynamoDB, no 5xx/timeout genérico | Fetch directo (curl, texto completo del artículo) — AWS Architecture Blog |
| 4 | Circuit breaker | VERIFICADO | Fetch directo — Fowler + Microsoft Azure Architecture Center |
| 5 | Idempotency keys (Stripe) | VERIFICADO | Fetch directo — Stripe API Reference |
| 6 | Lookback/overlap margin | VERIFICADO (vendor: Airbyte); dedupe `ROW_NUMBER()` es técnica genérica, no cita del vendor | Fetch directo — Airbyte Connector Builder docs |
| 7 | Full-refresh por límite de deletes en incremental | VERIFICADO | Fetch directo — Fivetran + Airbyte, independientes |
| 8 | I/O-bound: threads/async bastan, no procesos | VERIFICADO | Fetch directo — Python `asyncio` + `concurrent.futures` docs |
| 9 | `aiohttp` + `Semaphore` + `ClientSession` reuse | PARCIAL: `ClientSession` reuse sí documentado por `aiohttp`; `Semaphore` es de `asyncio` (stdlib), no de `aiohttp` — corregir atribución | Fetch directo — aiohttp docs (3 páginas) + Python asyncio-sync docs |
| 10 | Raw zone as-is + transformar después | VERIFICADO (sanity check) | Fetch directo — Databricks medallion architecture |
| 11 | Webhooks at-least-once, duplicados, firma | VERIFICADO (Stripe); GitHub descartado como cita — no confirmado por fetch directo | Fetch directo — Stripe webhooks docs |
| 12 | Bulk export como tercera vía | VERIFICADO | Fetch directo — Shopify Bulk Operations + Salesforce Bulk API |

## Correcciones concretas a aplicar si este contenido llega al skill

1. **Claim 1:** no decir "(RFC 6585, later folded into RFC 9110)" — RFC 9110 no obsoleta RFC 6585. Decir en su lugar que RFC 6585 define 429 y sigue vigente como extensión referenciada, no absorbida, por RFC 9110. Tampoco decir que `Retry-After` "almost always" viene con un 429 — el spec lo deja en `MAY`; el golden rule de respetarlo aplica cuando está presente, pero el pipeline necesita backoff propio como fallback.
2. **Claim 3:** si se cita "thundering herd" en el skill, presentarlo como término estándar de la industria para el fenómeno — no como una frase textual del post de AWS (no aparece en el artículo).
3. **Claim 9:** no atribuir `asyncio.Semaphore` a la documentación de `aiohttp`. Es un primitivo de `asyncio` (stdlib) de uso común junto con `aiohttp`; lo que `aiohttp` sí documenta como su propio mecanismo de límite de concurrencia es `TCPConnector(limit=...)`.
4. **Claim 6:** si se menciona `ROW_NUMBER()` como técnica de deduplicación, presentarla como implementación SQL estándar, no como recomendación textual de Airbyte (que resuelve el mismo problema con su propio modo de sync, no con esa función).
5. **Claim 11:** usar Stripe como única cita primaria para "at-least-once" — la caracterización específica de GitHub sobre duplicados no se pudo confirmar por fetch directo en este research.

## Fuentes primarias usadas (todas por fetch directo salvo donde se indica)

| Fuente | Uso | Método |
|---|---|---|
| RFC 9110, `rfc-editor.org/rfc/rfc9110.txt` | §10.2.3 Retry-After, lista `Obsoletes`, ausencia de "429" en el texto | `curl` + extracción de sección, texto completo grep-eado |
| RFC 6585, `rfc-editor.org/rfc/rfc6585.txt` | §4, definición de 429, `Retry-After` como `MAY` | `curl` + extracción de sección |
| GitHub REST API — Rate limits | Corroboración práctica de "if present" | Fetch directo |
| AWS API Gateway Developer Guide — throttling | Token bucket | Fetch directo |
| AWS Architecture Blog — "Exponential Backoff And Jitter" (Marc Brooker) | Cita canónica claim 3 | `curl` + limpieza HTML, texto completo del artículo |
| Martin Fowler — CircuitBreaker bliki | Definición canónica circuit breaker | Fetch directo |
| Microsoft Learn — Circuit Breaker pattern, Azure Architecture Center | Máquina de estados closed/open/half-open, mención 429/503 | Fetch directo |
| Stripe — Idempotent Requests | Idempotency-Key | Fetch directo |
| Stripe — Webhooks | At-least-once, duplicados, firma | Fetch directo |
| Airbyte — Connector Builder, Incremental Sync (Lookback window) | Margen de overlap | Fetch directo |
| Airbyte — Refreshes | Limitación de deletes en incremental | Fetch directo |
| Fivetran — PostgreSQL connector troubleshooting (Capture Deletes) | Limitación de deletes en incremental | Fetch directo |
| Python docs — `asyncio` | I/O-bound fit | Fetch directo |
| Python docs — `concurrent.futures` | Thread vs Process, GIL | Fetch directo |
| Python docs — `asyncio` Synchronization Primitives | `Semaphore` | Fetch directo |
| aiohttp docs — Client Quickstart | Reutilización de `ClientSession` | Fetch directo |
| aiohttp docs — Client Reference / Client Advanced Usage | `TCPConnector(limit=...)`, ausencia de `Semaphore` en la doc oficial | Fetch directo (3 páginas revisadas) |
| Databricks — Medallion Architecture glossary | Raw/Bronze as-is | Fetch directo |
| Shopify Dev — Bulk Operations (GraphQL Admin API) | Bulk export vs paginación | Fetch directo |
| Salesforce Developer Docs — Bulk API and Bulk API 2.0 | Bulk export, umbral de 2000 registros | Fetch directo |
| GitHub Docs — Best practices for using webhooks / Validating webhook deliveries | Firma, respuesta 2XX; duplicados NO confirmado | Fetch directo (descartado para la claim de duplicados) |
