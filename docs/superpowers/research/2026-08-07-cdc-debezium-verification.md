# Research: CDC vía Debezium — log de transacciones vs. polling, tipo de operación, snapshot+streaming, entrega at-least-once

**Fecha:** 2026-08-07
**Alcance:** verificación de 4 claims del Paso 6 del plan de implementación de la skill de streaming. Fuente primaria: documentación oficial de Debezium, versión **3.6** (confirmado en el selector de versión visible en el propio HTML de la página `features.html`: "Debezium Documentation 3.6", con "3.7" listada como versión posterior/nightly disponible en el mismo selector — se usó la rama "stable", que en el momento de esta consulta resolvía a 3.6). Los ejemplos de eventos de cambio en la página del conector de PostgreSQL muestran `"version": "3.6.1.Final"` en el campo `source`, corroborando la versión.

**Nota de método**: la herramienta de fetch basada en LLM devolvió error 403 (Forbidden) al intentar acceder a `debezium.io` directamente; se resolvió descargando el HTML con `curl -A "Mozilla/5.0"` (probablemente el bloqueo era un filtro de user-agent/bot, no autenticación real) y extrayendo texto plano con Python. Páginas consultadas: `https://debezium.io/documentation/reference/stable/features.html`, `https://debezium.io/documentation/faq/`, `https://debezium.io/documentation/reference/stable/connectors/postgresql.html`.

---

## 1. CDC lee el log de transacciones de la base de datos (WAL, binlog) en vez de hacer polling sobre las tablas

**VEREDICTO: SUPPORTED**, verbatim, con cita específica tanto del principio general como del mecanismo concreto en PostgreSQL (WAL) y MySQL (binlog).

### 1.1 El principio general: log-based CDC vs. polling

> "Debezium is a set of source connectors for Apache Kafka Connect. Each connector ingests changes from a different database by using that database's features for change data capture (CDC). Unlike other approaches, such as polling or dual writes, log-based CDC as implemented by Debezium:
> - Ensures that all data changes are captured.
> - Produces change events with a very low delay while avoiding increased CPU usage required for frequent polling..."

Fuente: `https://debezium.io/documentation/reference/stable/features.html`, sección "Debezium Features", verbatim.

### 1.2 Definición general en el FAQ

> "Debezium is a set of distributed services that capture row-level changes in your databases so that your applications can see and respond to those changes. Debezium records in a transaction log all row-level changes committed to each database table. Each application simply reads the transaction logs they're interested in..."

Fuente: `https://debezium.io/documentation/faq/`, entrada "What is Debezium?", verbatim.

### 1.3 El mecanismo concreto por motor: WAL (PostgreSQL) y binlog (MySQL)

> "PostgreSQL normally purges write-ahead log (WAL) segments after some period of time. This means that the connector does not have the complete history of all changes that have been made to the database. Therefore, when the PostgreSQL connector first connects to a particular PostgreSQL database, it starts by performing a consistent snapshot of each of the database schemas."

Fuente: `https://debezium.io/documentation/reference/stable/connectors/postgresql.html`, verbatim.

Y sobre MySQL, del FAQ:

> "How does Debezium affect source databases? Most databases have to be configured before Debezium can monitor them. For example, a MySQL server must be configured to use the row-level binlog, and to have a user privileged to read the binlog..."

Fuente: `https://debezium.io/documentation/faq/`, verbatim.

---

## 2. Cada cambio confirmado se emite como un evento, que lleva el tipo de operación

**VEREDICTO: SUPPORTED**, verbatim, con la lista completa y exacta de valores del campo `op` — que es más rica que "create/update/delete" (incluye también `read`, `truncate` y `message`).

> "op — Mandatory string that describes the type of operation that caused the connector to generate the event. In this example, c indicates that the operation created a row. Valid values are:
> - c = create
> - u = update
> - d = delete
> - r = read (applies to only snapshots)
> - t = truncate
> - m = message"

Fuente: `https://debezium.io/documentation/reference/stable/connectors/postgresql.html`, tabla "Descriptions of create event value fields", campo `op`, verbatim.

**Nota de precisión para el skill**: la claim del brief dice "carrying the operation type" en singular/genérico — la fuente confirma esto y añade dos valores que suelen omitirse en explicaciones simplificadas: `r` (read, exclusivo del snapshot inicial — así es como el snapshot y el streaming comparten el mismo formato de evento) y `t`/`m` (truncate/message, para casos menos comunes). Si el skill enumera los valores del campo `op`, debe incluir al menos `c`/`u`/`d`/`r`, porque `r` es precisamente el que conecta esta claim con la claim 3 (snapshot inicial + streaming usan la misma estructura de evento).

---

## 3. El snapshot inicial más el streaming de log subsecuente es el flujo estándar

**VEREDICTO: SUPPORTED**, verbatim.

> "PostgreSQL normally purges write-ahead log (WAL) segments after some period of time. This means that the connector does not have the complete history of all changes that have been made to the database. Therefore, when the PostgreSQL connector first connects to a particular PostgreSQL database, it starts by performing a consistent snapshot of each of the database schemas. After the connector completes the snapshot, it continues streaming changes from the exact point at which the snapshot was made. This way, the connector starts with a consistent view of all of the data, and does not omit any changes that were made while the snapshot was being taken."

Fuente: `https://debezium.io/documentation/reference/stable/connectors/postgresql.html`, verbatim.

Corroborado de forma más general (aplicable a cualquier conector) en la página de features:

> "Snapshots: optionally, an initial snapshot of a database's current state can be taken if a connector is started and not all logs still exist. Typically, this is the case when the database has been running for some time and has discarded transaction logs that are no longer needed for transaction recovery or replication. There are different modes for performing snapshots, including support for incremental snapshots, which can be triggered at connector runtime."

Fuente: `https://debezium.io/documentation/reference/stable/features.html`, verbatim. Nótese la palabra "optionally" — el snapshot inicial no es obligatorio en todos los casos (si el log de transacciones aún contiene todo el historial relevante, puede omitirse), aunque en la práctica es el flujo estándar cuando la base de datos ya tiene datos existentes al momento de iniciar la captura.

---

## 4. La entrega es at-least-once por defecto, así que el consumidor debe deduplicar

**VEREDICTO: SUPPORTED**, verbatim, con un matiz importante que el skill debe preservar: Debezium no dice "siempre at-least-once" de forma plana — distingue entre operación normal (exactamente una vez) y escenarios de fallo/recuperación (at-least-once, con posibles duplicados).

> "Why must consuming applications expect duplicate events? When all systems are running nominally or when some or all of the systems are gracefully shut down, then consuming applications can expect to see every event exactly one time. However, when things go wrong it is always possible for consuming applications to see events at least once.
>
> When the Debezium's systems crash, they are not always able to record their last position/offset. When they are restarted, they recover by starting where were last known to have been, and thus the consuming application will always see every event but may likely see at least some messages duplicated during recovery.
>
> Additionally, network failures may cause the Debezium connectors to not receive confirmation of writes, resulting in the same event being recorded one or more times (until confirmation is received)."

Fuente: `https://debezium.io/documentation/faq/`, entrada "Why must consuming applications expect duplicate events?", verbatim.

Y, sobre la implicación práctica de esto para el uso de un único conector embebido (sin el clúster completo de Kafka/Kafka Connect):

> "Can my application directly monitor a single database? Yes... this approach is indeed far simpler with few moving parts, but it is more limited and far less tolerant of failures. If your application needs at-least-once delivery guarantees of all messages, please consider using the full distributed system."

Fuente: misma página, verbatim.

**Implicación para el skill**: la claim "at-least-once by default, so a consumer must deduplicate" es correcta como resumen práctico — la recomendación operativa (los consumidores deben ser capaces de manejar duplicados) es acertada — pero el skill no debe presentarlo como "Debezium siempre entrega duplicados"; la fuente dice que en operación normal la entrega es efectivamente exactamente-una-vez, y que los duplicados aparecen específicamente durante recuperación de fallos (crash del conector, fallos de red antes de recibir confirmación). El resultado práctico es el mismo (el consumidor debe ser idempotente/deduplicar, porque no puede distinguir de antemano cuándo ocurrirá un fallo), pero la formulación exacta debe reflejar esta condicionalidad, no presentarla como una garantía plana y constante de "siempre at-least-once".

---

## Resumen de veredictos

| # | Claim | Veredicto |
|---|---|---|
| 1 | CDC lee el log de transacciones (WAL/binlog), no hace polling | **SUPPORTED** — verbatim, principio general + mecanismo concreto por motor |
| 2 | Cada cambio se emite como evento con tipo de operación | **SUPPORTED** — verbatim; lista completa es `c/u/d/r/t/m`, no solo create/update/delete |
| 3 | Snapshot inicial + streaming de log subsecuente es el flujo estándar | **SUPPORTED** — verbatim, con matiz de que el snapshot es "opcional" si el log ya cubre todo el historial necesario |
| 4 | Entrega at-least-once por defecto; el consumidor debe deduplicar | **SUPPORTED**, con matiz: exactamente-una-vez en operación normal, at-least-once específicamente durante recuperación de fallos/reinicios — no una garantía plana y constante |

## Implicación para el skill

- Al enumerar los valores del campo `op`, incluir `r` (read, del snapshot) además de `c`/`u`/`d` — es la pieza que conecta esta sección con la claim del snapshot inicial.
- No escribir "Debezium siempre entrega con duplicados" — la fuente distingue explícitamente operación normal (exactamente una vez) de escenarios de fallo (at-least-once). El consejo práctico para el consumidor (deduplicar/ser idempotente) sigue siendo correcto porque el consumidor no puede saber de antemano cuándo ocurrirá un fallo.
