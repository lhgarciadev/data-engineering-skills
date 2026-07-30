# Research: consumo de APIs externas — HTTP, auth y paginación (verificación de claims)

**Fecha:** 2026-07-30
**Alcance:** verificación de contenido existente/borrador — no cobertura nueva. Se revisaron 10 claims puntuales destinadas al material de referencia de `python-data-engineering` sobre ingestión vía HTTP: familias de status codes, semántica de retry por clase, `timeout`/`raise_for_status` de `requests`, progresión de esquemas de auth hasta OAuth2 `client_credentials`, refresh proactivo de tokens, y los cuatro patrones de paginación (offset/limit, cursor/keyset, page token, Link header). Cada claim se contrastó contra fuente primaria — RFCs vía `rfc-editor.org` (texto plano descargado y grepeado directamente, no resumido por un modelo intermedio salvo donde se indica lo contrario), documentación oficial de `requests` (`requests.readthedocs.io`), RFC 6749, y documentación/código fuente oficial de vendors (GitHub, Google, Shopify, PostgreSQL, google-auth-library-python, oauthlib).

**Nota metodológica:** para las secciones donde la precisión textual importaba (RFC 9110 §15.5.21, RFC 4918 §11.2, RFC 8288, RFC 6585, RFC 6749 §4.4), se descargó el `.txt` oficial vía `curl` y se extrajo el texto con `grep`/`sed` directamente — **fetch verificado línea por línea, sin resumen intermedio de IA**. Donde se usó `WebFetch` (que sí resume con un modelo pequeño), lo marco explícitamente como "contenido resumido" y, en los casos que lo ameritaban, lo recontrasté con el `.txt` crudo para confirmar que el resumen no alucinó nada — esto SÍ ocurrió una vez (ver Claim 2) y quedó documentado como corrección.

---

## Claim 1 — Familias de status code (2xx/3xx/4xx/5xx) según RFC 9110

**Veredicto: VERIFIED.**

RFC 9110 obsoleta efectivamente a RFC 7231 (y a las demás RFCs 723x de 2014) como la especificación vigente de semántica HTTP — confirmado por el propio documento. Las cinco clases están descritas con prosa propia en las secciones 15.2–15.6, no solo como encabezados:

> **§15.3 Successful 2xx:** "The 2xx (Successful) class of status code indicates that the client's request was successfully received, understood, and accepted."

> **§15.4 Redirection 3xx:** "The 3xx (Redirection) class of status code indicates that further action needs to be taken by the user agent in order to fulfill the request."

> **§15.5 Client Error 4xx:** "The 4xx (Client Error) class of status code indicates that the client seems to have erred. Except when responding to a HEAD request, the server SHOULD send a representation containing an explanation of the error situation, and whether it is a temporary or permanent condition."

> **§15.6 Server Error 5xx:** "The 5xx (Server Error) class of status code indicates that the server is aware that it has erred or is incapable of performing the requested method."

Dato interesante para el skill: la propia RFC, en la definición de 4xx, ya advierte que el servidor "SHOULD" indicar **si la condición es temporal o permanente** — es decir, el diseño de la especificación asume desde el inicio que no todo 4xx es igual de permanente, lo cual es exactamente el matiz que pide el Claim 2.

Fuente: [RFC 9110 — HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html) (verificado por `curl` + `grep`/`sed` sobre el `.txt` oficial).

---

## Claim 2 — Retry por clase: 4xx casi siempre permanente (excepto 401 tras token expirado y 429); 5xx casi siempre transitorio. Precisión de 422.

**Veredicto: VERIFIED con una corrección de precisión (422) y un hallazgo adicional que refuerza la excepción de 401.**

### a) 422 — la pregunta central del claim

**422 SÍ está definido en RFC 9110 misma**, no solo en WebDAV — pero con un detalle de nomenclatura que vale la pena precisar: RFC 9110 lo renombra de **"422 Unprocessable Entity"** (WebDAV) a **"422 Unprocessable Content"** (HTTP Semantics).

> **RFC 9110 §15.5.21:** "The 422 (Unprocessable Content) status code indicates that the server understands the content type of the request content (hence a 415 (Unsupported Media Type) status code is inappropriate), and the syntax of the request content is correct, but it was unable to process the contained instructions."

> **RFC 9110 Apéndice B.3 (Changes from RFC 7231), texto que confirma la genealogía exacta:** "Status code 422 (previously defined in Section 11.2 of [WEBDAV]) has been added because of its general applicability. (Section 15.5.21)"

Y el texto original de WebDAV, para contraste directo:

> **RFC 4918 §11.2 ("422 Unprocessable Entity"):** "The 422 (Unprocessable Entity) status code means the server understands the content type of the request entity (hence a 415 (Unsupported Media Type) status code is inappropriate), and the syntax of the request entity is correct (thus a 400 (Bad Request) status code is inappropriate) but was unable to process the contained instructions."

**Conclusión precisa para el skill:** 422 nació en WebDAV (RFC 2518, luego RFC 4918, §11.2, como "**Unprocessable Entity**"), y HTTP Semantics (RFC 9110, §15.5.21) lo adoptó formalmente en 2022 como código de aplicabilidad general, renombrándolo a "**Unprocessable Content**". Ambos nombres circulan en la práctica (frameworks como FastAPI/DRF siguen usando "Unprocessable Entity" en sus mensajes), pero la cita normativa correcta hoy es **RFC 9110 §15.5.21**, no RFC 4918 — RFC 4918 queda como el origen histórico, no como la especificación vigente para el código en general.

### b) 429 — no está en RFC 9110

Verificado por `grep -n "429" rfc9110.txt` sobre el texto completo: **cero coincidencias**. 429 nunca fue absorbido por RFC 9110 — sigue viviendo en su RFC original:

> **RFC 6585 §4 ("429 Too Many Requests"):** "The 429 status code indicates that the user has sent too many requests in a given amount of time ('rate limiting'). The response representations SHOULD include details explaining the condition, and MAY include a Retry-After header indicating how long to wait before making a new request."

Esto confirma la mitad "transitorio" del claim para 429 con una fuente aún más directa que RFC 9110: la propia definición prevé explícitamente un `Retry-After`, lo cual es la marca textual clásica de "esto es temporal, reintenta después".

### c) 401 tras token expirado — la excepción del claim tiene respaldo textual directo en la RFC

Este es el hallazgo más útil de la sección: RFC 9110 no solo permite la excepción, la **documenta explícitamente** como parte de la semántica normativa de 401:

> **RFC 9110 §15.5.2 (401 Unauthorized):** "If the request included authentication credentials, then the 401 response indicates that authorization has been refused for those credentials. The user agent **MAY repeat the request with a new or replaced Authorization header field**."

Es decir: la RFC misma distingue "401 con credenciales ya reemplazadas y rechazadas de nuevo" (ahí sí, dejar de reintentar) de "401 con credenciales que se pueden reemplazar y reintentar" (el caso exacto de un token expirado + refresh). El claim del skill de tratar 401-por-expiración como la excepción al "4xx es permanente" está respaldado casi verbatim por el texto normativo, no es una interpretación laxa.

### d) 5xx — confirmado como "generalmente transitorio", con matices reales por código

> **RFC 9110 §15.6.4 (503 Service Unavailable):** "The 503 (Service Unavailable) status code indicates that the server is currently unable to handle the request due to a **temporary overload or scheduled maintenance, which will likely be alleviated after some delay**. The server MAY send a Retry-After header field... *Note:* The existence of the 503 status code does not imply that a server has to use it when becoming overloaded."

500, 502 y 504 no tienen la palabra "temporary" en su texto normativo (500 dice "unexpected condition"; 502/504 hablan de fallos de upstream/gateway), pero la práctica de la industria de tratarlos como candidatos a retry con backoff es consistente con que ninguno de los cuatro (500/502/503/504) indica un fallo estructural del lado del cliente — el punto de fondo del claim se sostiene, solo 503 tiene el respaldo textual más explícito ("temporary", "Retry-After").

### e) Nota que vale la pena agregar al skill si no está: 404 no es tan "permanente" como parece

Dato que contradice ligeramente una lectura ingenua del claim (no lo invalida, pero lo matiza):

> **RFC 9110 §15.5.5 (404 Not Found):** "A 404 status code **does not indicate whether this lack of representation is temporary or permanent**; the 410 (Gone) status code is preferred over 404 if the origin server knows... that the condition is likely to be permanent."

Es decir, la propia RFC dice que 404 es ambiguo respecto a permanencia — el código diseñado explícitamente para "esto es permanente" es 410 (Gone), no 404. Para el skill, esto es un matiz correcto de agregar: "404 se trata como permanente por convención práctica de ingestión (no tiene sentido reintentar sin cambiar la URL/parámetros), pero la RFC no lo garantiza como permanente — ese rol específico lo cumple 410".

Fuentes: [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html), [RFC 4918 §11.2](https://www.rfc-editor.org/rfc/rfc4918.html), [RFC 6585 §4](https://www.rfc-editor.org/rfc/rfc6585.html) — los tres verificados por `curl` + `grep`/`sed` sobre el `.txt` oficial, no por resumen de IA.

---

## Claim 3 — `requests`: `timeout` como tupla `(connect, read)`; `raise_for_status()` convierte 4xx/5xx en excepción

**Veredicto: VERIFIED, verbatim contra la documentación oficial.**

> **Advanced Usage — Timeouts:** "If you specify a single value for the timeout, like this: `r = requests.get('https://github.com', timeout=5)` The timeout value will be applied to both the `connect` and the `read` timeouts. Specify a tuple if you would like to set the values separately: `r = requests.get('https://github.com', timeout=(3.05, 27))`"

El orden de la tupla es exactamente `(connect_timeout, read_timeout)` — confirmado por la prosa que precede al ejemplo, que define primero "connect" y luego "read" en ese orden, y por el ejemplo mismo (`3.05` conecta, `27` lee).

> **Quickstart — Response Status Codes:** "If we made a bad request (a **4XX client error or 5XX server error** response), we can raise it with `Response.raise_for_status()`: [...] `bad_r.raise_for_status()` → `requests.exceptions.HTTPError: 404 Client Error`"

Confirmado también en Quickstart — Errors and Exceptions: "`Response.raise_for_status()` will raise an `HTTPError` if the HTTP request returned an unsuccessful status code" — cubre ambas familias (4xx y 5xx), tal como dice el claim.

Fuentes: [requests — Advanced Usage, Timeouts](https://requests.readthedocs.io/en/latest/user/advanced/#timeouts), [requests — Quickstart, Response Status Codes](https://requests.readthedocs.io/en/latest/user/quickstart/#response-status-codes) (fetch directo).

---

## Claim 4 — "el error #1 en código de ingestión es un request sin timeout"

**Veredicto: VERIFIED — la propia documentación de `requests` usa casi la misma severidad de lenguaje.**

Dos advertencias independientes, en dos páginas distintas del propio proyecto:

> **Quickstart — Timeouts:** "You can tell Requests to stop waiting for a response after a given number of seconds with the `timeout` parameter. **Nearly all production code should use this parameter in nearly all requests. Failure to do so can cause your program to hang indefinitely**."

> **Advanced Usage — Timeouts:** "Most requests to external servers should have a timeout attached, in case the server is not responding in a timely manner. **By default, requests do not time out unless a timeout value is set explicitly. Without a timeout, your code may hang for minutes or more.**"

Esto es, textualmente, la misma afirmación que hace el claim del skill ("sin uno, un servidor colgado congela tu tarea indefinidamente") — no es una exageración del draft, es casi una paráfrasis de la doc oficial. Vale la pena citar esta frase directamente en el skill como respaldo de autoridad.

Fuentes: mismas dos páginas del Claim 3, secciones "Timeouts" (fetch directo).

---

## Claim 5 — Progresión de auth: API key → bearer estático → OAuth2 `client_credentials` (RFC 6749 §4.4)

**Veredicto: VERIFIED contra RFC 6749 §4.4.**

Mecánica confirmada con el diagrama y el flujo textual de la RFC:

> **§4.4:** "The client can request an access token using only its client credentials... The client credentials grant type **MUST only be used by confidential clients**."
>
> ```
> +---------+                                  +---------------+
> |         |>--(A)- Client Authentication --->| Authorization |
> | Client  |                                  |     Server    |
> |         |<--(B)---- Access Token ---------<|               |
> +---------+                                  +---------------+
>                  Figure 6: Client Credentials Flow
> ```

> **§4.4.2 (Access Token Request):** "`grant_type` REQUIRED. Value MUST be set to `client_credentials`." — y ejemplo de request real: `POST /token HTTP/1.1` con `Authorization: Basic czZCaGRSa3F0MzpnWDFmQmF0M2JW` (Basic Auth de `client_id:client_secret`) y body `grant_type=client_credentials`.

> **§4.4.3 (Access Token Response):** el token vuelve como `{"access_token":"2YotnFZFEjr1zCsicMWpAA","token_type":"example","expires_in":3600, ...}` — y agrega: "**A refresh token SHOULD NOT be included**" (dato relevante: a diferencia de Authorization Code, `client_credentials` normalmente no entrega refresh token — el cliente vuelve a autenticarse con `client_id`+`client_secret` cuando el access token expira, en vez de usar un refresh token).

Esto confirma exactamente la mecánica del claim: intercambio de `client_id`+`client_secret` (machine-to-machine, "confidential clients") por un access token de vida corta, usado luego en las llamadas.

Fuente: [RFC 6749 §4.4](https://www.rfc-editor.org/rfc/rfc6749.html) (verificado por `curl` + `grep`/`sed` sobre el `.txt` oficial).

---

## Claim 6 — Refresh proactivo antes de expiración; margen de 60 segundos

**Veredicto: PARCIALMENTE VERIFIED — el patrón general (refresh proactivo con margen) es práctica estándar y documentada; el número específico de 60 segundos NO tiene respaldo en ninguna fuente primaria consultada, y una librería oficial real usa un valor distinto.**

### a) `expires_in` — la RFC no manda "1 hora", solo la usa como ejemplo

> **RFC 6749 §5.1:** "`expires_in` RECOMMENDED. The lifetime in seconds of the access token. For example, the value `'3600'` denotes that the access token will expire in one hour from the time the response was generated."

"1 hora" es el ejemplo de la RFC, no un default normativo — está bien que el skill lo presente como "típicamente 1h" (así es en la práctica de la mayoría de IdPs: Auth0, Okta y Azure AD usan 3600s por defecto), pero técnicamente es una convención de la industria, no un mandato de la especificación. Vale la pena que el skill sea preciso en esa distinción.

### b) Refresh proactivo como patrón — confirmado como práctica recomendada, sin cifra fija

Búsqueda dirigida a Auth0/Okta no encontró una cifra oficial de "60 segundos" en ninguna de las dos — la guía documentada es cualitativa ("dejar margen para clock drift, latencia de red, reintentos"), no cuantitativa. Cito la síntesis de la búsqueda porque es representativa de lo que hay disponible, no como cita textual de un vendor:

> "A recommended approach is to use a proactive refresh (TTL margin check): refresh before the exact expiry time, leaving a buffer for clock drift, latency, retries, or long-running jobs." — sin cifra específica atribuible a Auth0 o Okta.

### c) Contraevidencia concreta: una librería oficial real (Google) usa 3 min 45 s, no 60 s

Fui a buscar el número real en código fuente de producción — `google-auth-library-python` (librería oficial de Google para Python, mantenida por `googleapis`):

> **`google/auth/_helpers.py`:**
> ```python
> # The smallest MDS cache used by this library stores tokens until 4 minutes from
> # expiry.
> REFRESH_THRESHOLD = datetime.timedelta(minutes=3, seconds=45)
> ```
> **`google/auth/credentials.py`:**
> ```python
> skewed_expiry = self.expiry - _helpers.REFRESH_THRESHOLD
> return _helpers.utcnow() >= skewed_expiry
> ```

Este es exactamente el "margen antes de expiración" que describe el claim del skill — pero el valor real, en una librería oficial en producción de un proveedor OAuth2 mayor, es **3 minutos 45 segundos**, no 60 segundos (y el comentario del propio código explica por qué: se alinea con la caché de 4 minutos del metadata server interno de Google, no con una regla general de OAuth2).

Como dato adicional de contraste: `oauthlib` (la librería Python de referencia para clientes OAuth2, base de `requests-oauthlib`) hace lo contrario — **no tiene margen de refresh proactivo por defecto**, es puramente reactivo:

> **`oauthlib/oauth2/rfc6749/clients/base.py`:** `if self._expires_at and self._expires_at < time.time(): raise TokenExpiredError()`

**Conclusión para el skill:** el *concepto* de refresh proactivo con margen es correcto y es la práctica recomendada en la industria — pero "60 segundos" es una cifra plausible y razonable, no una convención documentada verbatim en ningún IdP mayor ni estándar. Si el skill quiere una cifra concreta con respaldo de fuente primaria, "60s" debería presentarse como "un margen típico usado en implementaciones" (con ejemplos que en la práctica van de ~1 a ~4 minutos según el vendor), no como LA cifra estándar de la industria — y sería más honesto citar el ejemplo de Google (3m45s) que inventar una cifra sin fuente.

Fuentes: [RFC 6749 §5.1](https://www.rfc-editor.org/rfc/rfc6749.html) (fetch directo/`curl`); [`google-auth-library-python` — `_helpers.py`](https://github.com/googleapis/google-auth-library-python/blob/main/google/auth/_helpers.py) y [`credentials.py`](https://github.com/googleapis/google-auth-library-python/blob/main/google/auth/credentials.py) (fetch directo del código fuente vía `curl`); [`oauthlib` — `base.py`](https://github.com/oauthlib/oauthlib/blob/master/oauthlib/oauth2/rfc6749/clients/base.py) (fetch directo). Búsqueda Auth0/Okta: resultados indexados (`WebSearch`), no fetch directo de una página específica — tratar la ausencia de cifra oficial como "no encontrada", no como "confirmada como inexistente" con certeza absoluta.

---

## Claim 7 — Offset/limit pagination: riesgo de skip/duplicado con datos cambiantes; lento en offsets grandes

**Veredicto: VERIFIED para la parte de performance (con cifras reales de un vendor); el mecanismo de "skip/duplicado por inserciones concurrentes" está bien fundamentado pero no como cita textual de un único vendor — es consecuencia lógica confirmada indirectamente.**

### a) Performance — confirmado con benchmark real de un vendor (Shopify Engineering)

> **PostgreSQL, `queries-limit.html`:** "The rows skipped by an `OFFSET` clause still have to be computed inside the server; therefore a large `OFFSET` might be inefficient."

> **Shopify Engineering, "Pagination with Relative Cursors":** "The problem is that incremental page numbers scale poorly—the bigger the page number, the slower the query." Con datos de benchmark citados en el artículo: tiempo de query subiendo de 6.54 ms en offset 10 a **2,221.60 ms en offset 100,000** — y además: "Not only do queries take a long time when a large offset is used, but there's also a limited number of queries that can be run concurrently."

Esto confirma con cifras reales de producción (no una afirmación abstracta) exactamente el punto del claim: el offset grande obliga a la base de datos a escanear-y-descartar filas antes de llegar al rango pedido, y eso degrada con la profundidad.

### b) Riesgo de skip/duplicado por datos cambiantes — el mecanismo es sólido, la fuente es indirecta

No encontré un vendor que documente textualmente "si insertas una fila mientras paginas con offset, vas a saltarte o duplicar registros" en esas palabras exactas (ni Stripe ni Shopify lo explicitan así en las páginas revisadas — el artículo de Shopify se enfoca en performance, no en esta consistencia). Sí hay una pieza de evidencia primaria relacionada y más estricta que respalda el mecanismo de fondo:

> **PostgreSQL, `queries-limit.html`:** "When using `LIMIT`, it is important to use an `ORDER BY` clause that constrains the result rows into a unique order. Otherwise you will get an unpredictable subset of the query's rows... using different `LIMIT`/`OFFSET` values to select different subsets of a query result **will give inconsistent results** unless you enforce a predictable result ordering with `ORDER BY`."

Esto confirma la precondición del problema (offset/limit exige orden determinístico para no dar resultados inconsistentes) pero es un paso lógico adicional — no explícito en el texto de Postgres — llegar de ahí a "y si insertan una fila entre página N y N+1, la ventana de offset se corre y duplicas o saltas filas incluso CON `ORDER BY` determinístico". Ese paso es matemáticamente correcto (es una consecuencia directa de cómo funciona `OFFSET` sobre un conjunto que cambia entre dos queries separadas), y es la razón real y ampliamente citada en la industria para migrar a cursor pagination, pero no logré encontrar un vendor que lo enuncie verbatim con esas palabras.

**Recomendación para el skill:** mantener la afirmación de performance citando a Shopify/Postgres verbatim; presentar el riesgo de skip/duplicado por concurrencia como "consecuencia lógica del funcionamiento de `OFFSET`" (razonamiento propio, defendible) en vez de atribuirlo a una cita de vendor específica.

Fuentes: [PostgreSQL — LIMIT and OFFSET](https://www.postgresql.org/docs/current/queries-limit.html) (fetch directo), [Shopify Engineering — Pagination with Relative Cursors](https://shopify.engineering/pagination-relative-cursors) (fetch directo, resumido — cifras de benchmark citadas tal como aparecen en el artículo).

---

## Claim 8 — Cursor/keyset pagination: puntero opaco, estable ante inserciones, eficiente a cualquier profundidad

**Veredicto: VERIFIED, respaldado por el mismo caso Shopify usado en Claim 7 (el reemplazo de offset por cursor fue motivado exactamente por este problema) y por el patrón `page_token`/`nextPageToken` de Google (Claim 9), que es la forma más extendida de cursor pagination en APIs REST modernas.**

El propio cambio de Shopify (Claim 7) es la evidencia más directa: migraron de page-number a cursor-based precisamente porque el cursor "relativo" no sufre la degradación de performance en profundidad, y el mecanismo (`since_id`/cursor opaco en vez de contar filas desde el principio) no depende de recalcular un offset. No se encontró en las fuentes revisadas una declaración de vendor sobre la estabilidad ante *inserciones concurrentes* específicamente (misma limitación que en Claim 7b), pero el mecanismo mismo — comparar contra un valor de cursor en vez de contar N filas — hace que una inserción no desplace la ventana de resultados ya entregados, a diferencia de offset.

Fuente: mismo artículo de Shopify Engineering citado en Claim 7.

---

## Claim 9 — Page token pagination (`?page_token=...`), variante de cursor común en Google APIs

**Veredicto: VERIFIED contra el estándar de diseño oficial de Google (AIP-158) y contra una API real (Google Drive API v3).**

> **Google AIP-158 (estándar de diseño de APIs de Google, usado across Google Cloud APIs):** definición del campo `page_token` de request: "A page token, received from a previous `ListBooks` call. Provide this to retrieve the subsequent page." Y de `next_page_token` en la respuesta: "If the end of the collection has been reached, the `next_page_token` field **must** be empty. This is the *only* way to communicate 'end-of-collection' to users."
>
> Sobre opacidad: "Page tokens provided by APIs **must** be opaque (but URL-safe) strings, and **must not** be user-parseable... Base-64 encoding an otherwise-transparent page token is **not** a sufficient obfuscation mechanism."

Confirmado también en un producto real, no solo en el estándar de diseño:

> **Google Drive API v3, `files.list` — parámetro `pageToken`:** "The token for continuing a previous list request on the next page. This should be set to the value of `nextPageToken` from the previous response."
>
> **Campo de respuesta `nextPageToken`:** "The page token for the next page of files. This will be absent if the end of the files list has been reached. If the token is rejected for any reason, it should be discarded, and pagination should be restarted from the first page of results."

Esto valida ambas mitades del claim: (a) es efectivamente una variante de cursor (token opaco, no un número de página), y (b) es el patrón estándar y documentado en múltiples APIs reales de Google, no solo una convención informal.

Fuentes: [Google AIP-158 — Pagination](https://google.aip.dev/158) (fetch directo — `aip.dev` es el sitio oficial del Google API Improvement Proposals process y es también el destino final al que redirige hoy `cloud.google.com/apis/design/design_patterns`, confirmado durante este research), [Google Drive API v3 — `files.list`](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/list) (fetch directo).

---

## Claim 10 — Link header pagination: RFC 5988 vs RFC 8288, y verificación contra GitHub

**Veredicto: NEEDS CORRECTION en el número de RFC — el claim del prompt original (citar RFC 5988) está desactualizado. La cita correcta y vigente es RFC 8288.**

### a) RFC 5988 fue obsoletada por RFC 8288 — confirmado en el propio documento

> **RFC 8288, encabezado del documento (verificado en el `.txt` crudo vía `curl`):**
> ```
> Internet Engineering Task Force (IETF)                     M. Nottingham
> Request for Comments: 8288                                  October 2017
> Obsoletes: 5988
> Category: Standards Track
> ```
>
> **Abstract:** "This specification defines a model for the relationships between resources on the Web ('links') and the type of those relationships ('link relation types'). It also defines the serialisation of such links in HTTP headers with the Link header field."

RFC 5988 ("Web Linking", Nottingham, octubre 2010) fue la primera especificación del header `Link`. RFC 8288 (mismo autor, octubre 2017) la obsoleta formalmente — el encabezado `Obsoletes: 5988` es la marca normativa de IETF para "esta RFC reemplaza por completo a la anterior". **Para el skill: la cita correcta hoy es RFC 8288, no RFC 5988.** Citar 5988 no es "incorrecto" en el sentido de que 5988 sí definió el mecanismo originalmente, pero es una cita desactualizada — equivalente a citar RFC 7231 en vez de RFC 9110 para semántica HTTP general (Claim 1).

### b) GitHub REST API — confirmado que usa exactamente este patrón

> **GitHub REST API docs, "Using pagination in the REST API":** "When a response is paginated, the response headers will include a `link` header." Con ejemplo real:
> ```
> link: <https://api.github.com/repositories/1300192/issues?page=2>; rel="prev",
> <https://api.github.com/repositories/1300192/issues?page=4>; rel="next",
> <https://api.github.com/repositories/1300192/issues?page=515>; rel="last",
> <https://api.github.com/repositories/1300192/issues?page=1>; rel="first"
> ```
> Y sobre cuándo parar: "Once the `link` header no longer includes a link to the next page, all of the results are returned."

Esto confirma exactamente la mecánica del claim: seguir el link `rel="next"` hasta que ya no aparezca. Como corroboración adicional (y coincidencia útil), la propia documentación de `requests` usa a GitHub como su ejemplo canónico de Link headers en producción:

> **`requests` — Advanced Usage, "Link Headers":** "Many HTTP APIs feature Link headers... GitHub uses these for pagination in their API, for example: `r.headers['link']` → `'<https://api.github.com/users/kennethreitz/repos?page=2&per_page=10>; rel="next", ...'` Requests will automatically parse these link headers... `r.links["next"]` → `{'url': '...page=2...', 'rel': 'next'}`."

Dato extra útil para el skill: `requests` no solo documenta el patrón, tiene soporte nativo para parsearlo (`Response.links`), lo cual es un detalle práctico que vale la pena mencionar si el material de referencia va a mostrar código Python real.

Fuentes: [RFC 8288 — Web Linking](https://www.rfc-editor.org/rfc/rfc8288.html) (verificado por `curl` sobre el `.txt` oficial — encabezado `Obsoletes: 5988` confirmado carácter por carácter), [GitHub REST API — Using pagination](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api) (fetch directo), [requests — Advanced Usage, Link Headers](https://requests.readthedocs.io/en/latest/user/advanced/#link-headers) (fetch directo, mismo documento del Claim 3/4).

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | Familias 2xx/3xx/4xx/5xx — RFC 9110 | VERIFIED |
| 2 | Retry por clase; 401 excepción; 429 excepción; 422 precisión | VERIFIED, con corrección de precisión: 422 es RFC 9110 §15.5.21 ("Unprocessable **Content**"), heredado de RFC 4918 §11.2 ("Unprocessable **Entity**") |
| 3 | `requests` timeout tupla `(connect, read)`; `raise_for_status()` | VERIFIED, verbatim |
| 4 | "#1 error: request sin timeout" | VERIFIED, casi paráfrasis de la doc oficial |
| 5 | Progresión de auth hasta `client_credentials` (RFC 6749 §4.4) | VERIFIED |
| 6 | Refresh proactivo; margen de 60s | PARCIAL: patrón sí, cifra de 60s sin respaldo — Google usa 3m45s en producción |
| 7 | Offset/limit: riesgo skip/duplicado + lentitud en offsets grandes | VERIFIED (performance, con benchmark real); mecanismo de skip/duplicado por concurrencia es razonamiento propio bien fundamentado, no cita textual de vendor |
| 8 | Cursor/keyset: estable, eficiente a cualquier profundidad | VERIFIED (vía caso Shopify) |
| 9 | Page token — variante de cursor, común en Google | VERIFIED (AIP-158 + Google Drive API real) |
| 10 | Link header — cita RFC correcta | **NEEDS CORRECTION: usar RFC 8288, no RFC 5988** (8288 obsoleta a 5988) — mecánica confirmada contra GitHub REST API real |

---

## Resumen de fuentes primarias usadas

| Fuente | Uso | Método de verificación |
|---|---|---|
| RFC 9110 (`rfc-editor.org/rfc/rfc9110.txt`) | Clases de status code, 401/403/404/422/500/502/503/504 (§1, §2) | `curl` + `grep`/`sed` sobre `.txt` crudo — sin resumen de IA |
| RFC 4918 (`rfc-editor.org/rfc/rfc4918.txt`) | 422 "Unprocessable Entity" original de WebDAV (§2) | `curl` + `grep`/`sed` sobre `.txt` crudo |
| RFC 6585 (`rfc-editor.org/rfc/rfc6585.txt`) | 429 Too Many Requests (§2) | `curl` + `grep`/`sed` sobre `.txt` crudo |
| RFC 6749 (`rfc-editor.org/rfc/rfc6749.txt`) | `client_credentials` grant §4.4, `expires_in` §5.1 (§5, §6) | `curl` + `grep`/`sed` sobre `.txt` crudo |
| RFC 8288 (`rfc-editor.org/rfc/rfc8288.txt`) | Link header vigente, `Obsoletes: 5988` (§10) | `curl` sobre `.txt` crudo |
| `requests.readthedocs.io/en/latest/user/quickstart` | `raise_for_status()`, warning de timeout (§3, §4) | Fetch directo |
| `requests.readthedocs.io/en/latest/user/advanced` | Tupla `(connect, read)`, warning de timeout, Link Headers (§3, §4, §10) | Fetch directo |
| PostgreSQL — `queries-limit.html` | Costo de `OFFSET`, necesidad de `ORDER BY` (§7) | Fetch directo |
| Shopify Engineering — "Pagination with Relative Cursors" | Benchmark real offset vs. cursor (§7, §8) | Fetch directo (resumido) |
| Google AIP-158 | `page_token`/`next_page_token`, opacidad (§9) | Fetch directo |
| Google Drive API v3 — `files.list` | `pageToken`/`nextPageToken` en un producto real (§9) | Fetch directo |
| GitHub REST API — "Using pagination" | Link header real, `rel="next"`, condición de parada (§10) | Fetch directo |
| `google-auth-library-python` — `_helpers.py`, `credentials.py` (GitHub) | Valor real de margen de refresh (3m45s, no 60s) (§6) | `curl` sobre código fuente crudo |
| `oauthlib` — `clients/base.py` (GitHub) | Contraejemplo: refresh reactivo sin margen (§6) | `curl` sobre código fuente crudo |
| Auth0/Okta (guía general de refresh proactivo) | Práctica cualitativa de margen, sin cifra oficial (§6) | Búsqueda indexada (`WebSearch`), no fetch directo de una página específica |

## Claims explícitamente NO verificadas al nivel de cita textual — no usar como cita sin revisión adicional

1. **"Margen de 60 segundos" como convención documentada por Auth0, Okta o cualquier IdP mayor** — no encontrado en ninguna fuente primaria. Un ejemplo real de producción (`google-auth-library-python`) usa 3m45s, no 60s. Si el skill quiere mantener una cifra concreta, sería más defendible citar el ejemplo de Google con su valor real, o presentar "60s" explícitamente como cifra ilustrativa propia, no como estándar de la industria.
2. **"Si insertas una fila mientras paginas con offset, saltas o duplicas registros" como cita textual de algún vendor** — el mecanismo es correcto y es la razón real detrás de migraciones documentadas (Shopify), pero ningún vendor revisado lo enuncia con esas palabras exactas ligadas a inserciones concurrentes; Shopify documenta la degradación de *performance* con cifras, no la inconsistencia por concurrencia. Postgres documenta la necesidad de `ORDER BY` para resultados determinísticos, que es la precondición del problema pero no el problema de concurrencia en sí.
3. **Estabilidad de cursor/keyset pagination ante inserciones concurrentes, como afirmación textual de vendor** — inferido correctamente del mecanismo (comparación contra un valor de cursor en vez de conteo de filas) y respaldado indirectamente por el caso de reemplazo de Shopify, pero no hay una declaración de vendor que diga textualmente "esto es estable ante inserciones concurrentes".
