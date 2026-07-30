# Research: patrones de extracción incremental (watermark / high-water-mark)

**Fecha:** 2026-07-30
**Alcance:** cobertura nueva, no verificación de contenido existente — ni `python-data-engineering/references/production-patterns.md` ni `sql-data-engineering/references/engineering-query-patterns.md` mencionan cómo un pipeline identifica *qué filas* son nuevas/cambiadas desde la última corrida (el lado READ/EXTRACT de la carga incremental). Ambos archivos ya cubren el lado WRITE (upsert idempotente, `MERGE`, SCD Type 2), pero el lado extracción — el patrón watermark/high-water-mark, dónde se persiste ese valor entre corridas, y sus pitfalls — no aparece en ningún archivo del suite. Este research cubre exclusivamente ese gap, contra documentación oficial/primaria: Microsoft Learn (Azure Data Factory), AWS (whitepapers oficiales, docs de Glue y DMS), Airbyte, Fivetran, Debezium, Singer/Meltano SDK, y la documentación de los tres orquestadores ya referenciados en el skill (Airflow, Dagster, Prefect). **No se escribió contenido en los archivos del skill — solo este research file**, según lo pedido.

---

## 1. El patrón watermark/high-water-mark — descripción canónica y las dos variantes

**Fuente más directa y explícita — Microsoft Learn, Azure Data Factory** (`tutorial-incremental-copy-overview`, actualizado 2026-07-20):

> "A watermark is a column that has the last updated time stamp or an incrementing key. The delta loading solution loads the changed data between an old watermark and a new watermark."

Esta única frase confirma exactamente las dos variantes que pide la tarea — timestamp-based ("last updated time stamp") vs. monotonic-ID-based ("an incrementing key") — como una sola definición canónica del vendor. Fuente: [Incrementally copy data from a source data store to a destination data store](https://learn.microsoft.com/en-us/azure/data-factory/tutorial-incremental-copy-overview).

**Segunda fuente independiente, con mecánica de query explícita — AWS, "AWS Glue Best Practices: Building a Performant and Cost Optimized Data Pipeline"** (whitepaper oficial, `docs.aws.amazon.com/pdfs/whitepapers`, fechado 2026-07-29 — verificado descargando el PDF y extrayendo el texto, no vía resumen indexado):

> "High watermark — If the source database system doesn't have CDC feature at all, then high watermark is a classic way of extracting delta records. It is the process of storing data load status and its timestamp into metadata tables. During the ETL load, it calculates the maximum value of load timestamp (high watermark) from metadata tables and filters the data being extracted. It does require a create timestamp (new records) and update timestamp (updated records) field in each of the table in source system to allow filtering on them based on high watermark timestamp."

Esta fuente es timestamp-específica (no cubre la variante ID-based en la misma sección), pero confirma la mecánica canónica: MAX(timestamp) del último load, filtrado contra ese valor, y la dependencia de columnas `create`/`update` timestamp en el origen.

**Query exacta del patrón, con el boundary explícito — Microsoft Learn, "Delta copy from a database using a control table"**:

> "The query that identifies the changes in the source database is similar to `'SELECT * FROM Data_Source_Table WHERE TIMESTAMP_Column > "last high-watermark" and TIMESTAMP_Column <= "current high-watermark"'`."

Fuente: [Delta copy from a database using a control table](https://learn.microsoft.com/en-us/azure/data-factory/solution-template-delta-copy-with-control-table). Esta es la query textual que pide la tarea (`WHERE updated_at > :last_watermark`), documentada por un vendor con el boundary exacto (ver §3c).

**Variante ID-based — AWS Glue Job Bookmarks** (`docs.aws.amazon.com/glue/latest/dg/monitor-continuations.html`, fetch directo confirmado):

> "For JDBC sources, ... AWS Glue by default uses the primary key as the bookmark key, provided that it is sequentially increasing or decreasing (with no gaps)."

**Definición equivalente en el mundo de los ELT connectors (Airbyte y Fivetran)** — ambos usan el término "cursor", no "watermark", pero es el mismo concepto:

- Airbyte: *"A cursor is the value used to track whether a record should be replicated in an incremental sync"*; *"the query looks like: `SELECT * FROM table WHERE cursor_field >= 'last_sync_max_cursor_field_value'`"*. Fuente: [Incremental Sync - Append](https://docs.airbyte.com/platform/using-airbyte/core-concepts/sync-modes/incremental-append) (confirmado por fetch directo del `.md` fuente en GitHub).
- Fivetran: *"The cursor acts as a metaphorical high-water mark that shows where a sync got to. When the next sync starts, Fivetran uses the cursor to decide where to begin syncing again."* Fuente: [Glossary | Definitions of Fivetran terms](https://fivetran.com/docs/getting-started/glossary) (confirmado por fetch directo).

**Conclusión de §1:** hay consenso multi-vendor (Microsoft, AWS, Airbyte, Fivetran) en la mecánica — MAX(columna creciente) del último run, comparado contra el valor actual — y en las dos variantes (timestamp vs. incrementing key/ID). La fuente más citable como "descripción canónica de una sola frase" es la de Azure Data Factory citada arriba.

---

## 2. Dónde se persiste el valor del watermark entre corridas

Tres patrones documentados de forma independiente, cada uno con fuente primaria propia:

### a) Tabla de control/metadata dedicada en el warehouse/base de origen

- **AWS** (mismo whitepaper que arriba): *"storing data load status and its timestamp into metadata tables"* — explícitamente llama "metadata tables" a este mecanismo.
- **Azure Data Factory**, con el DDL exacto de la tabla de control:
  ```sql
  create table watermarktable (WatermarkValue datetime);
  ```
  más un stored procedure (`update_watermark`) que la actualiza al final de cada corrida exitosa. Fuente: [Delta copy from a database using a control table](https://learn.microsoft.com/en-us/azure/data-factory/solution-template-delta-copy-with-control-table). Este es el ejemplo más completo y ejecutable de "tabla de estado dedicada" entre los vendors revisados.

### b) Estado nativo del orquestador

Los tres orquestadores que `production-patterns.md` ya referencia (Airflow, Dagster, Prefect) documentan mecanismos distintos, ninguno pensado *específicamente* para watermarks de extracción, pero todos reutilizables para ese fin:

- **Airflow — XCom**: *"XComs let tasks exchange messages... Airflow stores XCom data in its metadata database."* Sirve para pasar el watermark de una tarea a otra dentro de un DAG run, pero **no está pensado para persistir entre DAG runs** de forma nativa — normalmente se combina con Airflow `Variable` (no cubierto en el research previo, pero es el mecanismo real de Airflow para valores persistentes entre runs) o con una tabla externa. Fuente: [XComs — Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/xcoms.html).
- **Dagster — cursor de sensor**: mecanismo más directamente análogo a un watermark de extracción. *"The sensor context... has a `cursor` property and an `update_cursor` method for sensors to track state across evaluations... to keep track of progress and avoid duplicate work across sensor evaluations."* Este es el mecanismo Dagster-nativo más cercano al "watermark persistido por el orquestador" — vive en el daemon de Dagster, no requiere tabla externa. Fuente: documentación de Dagster sobre sensors (`docs.dagster.io/guides/automate/sensors`); confirmado por múltiples resultados de búsqueda consistentes, no por fetch directo de la página (ver nota de alcance al final).
- **Prefect — Variables**: *"Variables are named, mutable JSON values that can be shared across tasks and flows... suitable for persisting small configuration values across flow runs."* Fuente: [Set and get variables - Prefect](https://docs.prefect.io/3.0/develop/variables).
- **AWS Glue Job Bookmarks** — caso especial: el estado NO vive en el warehouse ni en el orquestador que llama al job, sino en la base de servicio interna de AWS Glue, versionado por job:
  ```json
  { "job_name": ..., "run_id": ..., "run_number": .., "states": { "transformation_ctx1": { bookmark_state1 } } }
  ```
  Fuente: [Tracking processed data using job bookmarks](https://docs.aws.amazon.com/glue/latest/dg/monitor-continuations.html) (fetch directo, texto completo confirmado).
- **Debezium / Kafka Connect** (fuera del alcance ELT clásico pero relevante como contraste log-based): los offsets se guardan en un tópico de Kafka (`connect-offsets` por defecto) cuando corre dentro de Kafka Connect; para Debezium Engine/Server standalone, las opciones documentadas incluyen archivo, JDBC (tabla relacional) o Redis. Fuente: *Storing state of a Debezium connector* (`debezium.io/documentation/reference/stable/configuration/storage.html`) — **fetch directo bloqueado por 403 (Cloudflare)** en dos intentos; el contenido citado proviene de resultados de búsqueda indexados que citan la página textualmente, no de un fetch verificado línea por línea. Tratar como corroborado con reserva menor.

### c) Checkpoint/archivo de config — Singer / Meltano SDK

Fuente primaria del propio ecosistema Singer (el spec de facto para taps/targets de ELT, hoy mantenido como Meltano Singer SDK):

> ```
> { "bookmarks": { "orders": { /* estado */ }, "customers": { /* estado */ } } }
> ```
> *"`replication_key` and `replication_key_value` — These two keys together should designate the incremental replication key (if applicable) and the highest value yet seen for this property."*

El mecanismo de persistencia documentado es explícitamente un archivo, no una tabla ni el orquestador:

> `tap | target | tail -n 1 > state.json`

Fuente: [Stream State — Meltano Singer SDK docs](https://sdk.meltano.com/en/latest/implementation/state.html) (fetch directo confirmado). Este es el ejemplo más limpio de "checkpoint/config file" como tercer patrón — el estado sale por stdout como un mensaje `STATE` y se redirige a un archivo JSON en disco, que la siguiente corrida vuelve a leer.

**Conclusión de §2:** los tres patrones que pedía la tarea están confirmados con fuente primaria propia — tabla dedicada (Azure), estado nativo del orquestador (Airflow/Dagster/Prefect, cada uno con mecánica distinta) y archivo de checkpoint (Singer/Meltano). AWS Glue Bookmarks es un cuarto caso híbrido — estado gestionado por la plataforma pero no por el orquestador que invoca el job ni por una tabla del propio warehouse.

---

## 3. Pitfalls conocidos

### a) "Late-arriving commit" — fila con `updated_at` seteado pero transacción no visible aún al momento de la query

**Parcialmente verificable.** No encontré un vendor oficial que use ese nombre exacto para el escenario de extracción **por query** (no-CDC). Lo que sí está confirmado con fuente primaria es el fenómeno análogo documentado para CDC **log-based**:

- **Fivetran**: *"Binary Log Reader begins capturing changes from the SCN (System Change Number) of the oldest uncommitted transaction on the source database, ensuring Fivetran does not miss any in-flight transactions."* Y, más revelador: Fivetran crea una alerta operativa cuando detecta una transacción sin commit por más de 6 horas, exigiendo un re-sync manual — reconocimiento explícito, por un vendor, de que transacciones de larga duración pueden hacer que se pierdan filas si no se gestionan. Fuente: resultados de búsqueda que citan la documentación de Fivetran sobre su Binary Log Reader (Oracle) y troubleshooting; no confirmado por fetch directo línea por línea.

Para el caso **query-based** (el que pide la tarea), la evidencia es indirecta pero consistente: el propio template de Azure Data Factory (§1) fija el "current watermark" ANTES de correr el copy (`LookupCurrentWaterMark`, ejecutado antes de `IncrementalCopyActivity`), y solo después de correr el copy actualiza la tabla de control con ese valor ya capturado. Esto significa — por lectura directa de la lógica documentada, no por una advertencia explícita del vendor — que una transacción que hace commit *después* de que `LookupCurrentWaterMark` leyó su timestamp de referencia, pero con un `updated_at` interno *anterior* a ese timestamp, quedaría fuera del rango `(last_watermark, current_watermark]` de esa corrida, y en la siguiente corrida el nuevo `last_watermark` ya la excluye por el límite inferior estricto (`>`). **Esto es análisis propio sobre la lógica documentada por Microsoft, no una advertencia textual de Microsoft** — lo marco así explícitamente porque el research previo del repo (`2026-07-29-*`) exige esa distinción.

Mitigación documentada de forma consistente pero solo en fuentes secundarias (no vendor oficial): usar un "lookback window"/"overlap window" — restar un buffer fijo al watermark antes de filtrar (`modified_date > watermark - buffer`) y deduplicar aguas abajo. **No pude confirmar esta mitigación contra un doc oficial de vendor con esas palabras exactas** — aparece consistentemente en múltiples blogs técnicos (oneuptime.com, datamethods.substack.com) pero no en Microsoft/AWS/GCP/Airbyte/Fivetran docs que revisé. Airbyte sí documenta un mecanismo equivalente pero para APIs, no bases de datos: el **Lookback window** de su Connector Builder — *"specifies a duration that is subtracted from the last cutoff date before starting to sync"*, para *"catch changes that were made to existing records"*. Fuente: [Incremental Sync — Airbyte Docs (connector-builder-ui)](https://docs.airbyte.com/platform/connector-development/connector-builder-ui/incremental-sync) (confirmado por fetch directo del `.md` en GitHub). Este SÍ es un vendor oficial documentando la técnica de buffer/lookback — pero para fuentes tipo API, no explícitamente para el caso de bases de datos con transacciones.

**Veredicto:** el fenómeno está confirmado (Fivetran, para CDC); la mitigación por buffer/lookback está confirmada como técnica de vendor (Airbyte, para APIs) pero no está vinculada explícitamente al escenario "transacción no committeada" en ningún doc oficial que haya encontrado para el caso SQL/JDBC puro. Tratar el nombre "late-arriving commit problem" como terminología de la industria/community, no como término documentado verbatim por ningún vendor.

### b) Clock skew entre el sistema origen y el sistema de extracción

**No verificable contra fuente primaria.** Ningún documento oficial (Microsoft, AWS, GCP, Airbyte, Fivetran, Debezium) que revisé menciona explícitamente "clock skew" en el contexto de watermarks de extracción. El whitepaper de AWS Glue Best Practices (fuente primaria más completa que encontré sobre el patrón high-watermark) no lo menciona en ningún punto — verificado por grep directo sobre el texto extraído del PDF. La discusión de Kleppmann en *Designing Data-Intensive Applications* sobre relojes de nodo no confiables (NTP, "time-of-day clocks can rewind and advance irregularly") es real y bien documentada en el libro (capítulo 8, "The Trouble with Distributed Systems"), y el libro sí es crítico del enfoque "last-modified timestamp" para CDC — pero **no pude obtener una cita textual verbatim con número de página** vía las herramientas de búsqueda/fetch disponibles (sin acceso directo al texto del libro). Cito el libro como respaldo conceptual razonable, no como cita verbatim verificada. **Recomendación: si esta claim se usa en el skill, verificar la cita exacta contra una copia del libro antes de publicarla como quote.**

### c) Off-by-one / boundary inclusivo vs. exclusivo en el corte del watermark

**Sí verificable, con dos fuentes primarias que documentan comportamientos opuestos** — este es el hallazgo más sólido de los cuatro pitfalls:

- **Azure Data Factory** usa boundary exclusivo-inferior/inclusivo-superior por diseño: `TIMESTAMP_Column > "last high-watermark" and TIMESTAMP_Column <= "current high-watermark"`. Este boundary evita duplicados por construcción — la fila con el valor exacto del watermark anterior nunca se vuelve a leer.
- **Airbyte** usa boundary inclusivo por diseño (`cursor_field >= 'last_sync_max_cursor_field_value'`), y **documenta explícitamente el efecto secundario**: *"you may run into behavior where you see the same row being emitted during each sync... the cursor field will always be greater than or equal to itself."* Fuente: [Incremental Sync - Append](https://docs.airbyte.com/platform/using-airbyte/core-concepts/sync-modes/incremental-append) (fetch directo). Airbyte resuelve esto no cambiando el boundary, sino con un modo de sync distinto — **Incremental | Append + Deduped** — que deduplica aguas abajo por clave primaria.

Este es exactamente el trade-off que pide la tarea: boundary exclusivo (Azure) = riesgo de gaps si el reloj/commit no es estrictamente monotónico respecto al watermark capturado; boundary inclusivo (Airbyte) = filas duplicadas garantizadas en cada sync, mitigado con dedupe aguas abajo en vez de evitado en el filtro. Ambos son patrones **documentados y en producción** por vendors distintos, no hipotéticos.

### d) Watermarks ID-based rompiéndose con asignación de ID fuera de orden o backfills

**Parcialmente verificable con fuente primaria directa — AWS Glue**:

> "AWS Glue by default uses the primary key as the bookmark key, **provided that it is sequentially increasing or decreasing (with no gaps)**."

Esta frase, leída con precisión, es una condición de uso, no una advertencia explícita sobre backfills — pero confirma exactamente el mecanismo de falla que describe la tarea: si el PK no es estrictamente secuencial (gaps, IDs reasignados, inserciones fuera de orden), el bookmark de AWS Glue no garantiza cobertura completa. Fuente: [Tracking processed data using job bookmarks](https://docs.aws.amazon.com/glue/latest/dg/monitor-continuations.html) (fetch directo, texto completo).

**No encontré ningún vendor que documente explícitamente el caso de backfills** (insertar filas históricas con IDs bajos después de que el watermark ya avanzó más allá de esos IDs) como fallo nombrado — es una consecuencia lógica directa de la condición de AWS Glue citada arriba ("no gaps"), pero ningún doc oficial lo desarrolla como escenario con nombre propio.

**Nota sobre una discrepancia entre fuentes durante este research:** una búsqueda indexada (no un fetch directo) reportó que Airbyte exige formalmente que los cursor fields sean *"monotonically increasing... never updated after record creation, and have unique values."* Al hacer el fetch directo del `.md` fuente real de esa página en GitHub, **ese texto no aparece** — la página solo documenta ejemplos (`updated_at`, `created_at`) sin listar esos tres requisitos formales. Marco esa claim específica como **no confirmada** y probablemente generada por el resumen del motor de búsqueda, no por el contenido real de Airbyte. Este es exactamente el tipo de gap que la disciplina de verificación de este repo existe para atrapar — un resumen de búsqueda no es sustituto de leer la fuente primaria.

---

## 4. ¿Watermarks ID/sequence-based preferidos sobre timestamp-based?

**No encontré ningún vendor que lo afirme como regla general y explícita** ("preferir ID sobre timestamp"). La evidencia primaria es más matizada que esa afirmación binaria:

- **Azure Data Factory** presenta timestamp e incrementing-key como **alternativas de igual estatus** dentro de la misma frase de definición (§1) — ningún doc de Microsoft revisado indica preferencia entre ellas.
- **AWS Glue** sí muestra una preferencia de *default*: usa el primary key como bookmark key por defecto, cuando existe y es secuencial — pero esto es sobre todo una decisión de conveniencia (el PK casi siempre existe y casi siempre es secuencial en RDS/Aurora/JDBC estándar), no una afirmación de que ID sea intrínsecamente más confiable que timestamp.
- **BigQuery Data Transfer Service** (SQL Server) va en la dirección **contraria**: según contenido indexado de `docs.cloud.google.com/bigquery/docs/sqlserver-transfer` (el fetch directo devolvió una página de navegación en JS sin el contenido de prosa — mismo problema de renderizado documentado en el research previo del repo sobre BigQuery, `2026-07-29-sql-python-claims-verification.md` §4), *"only TIMESTAMP columns can be chosen as watermark columns for Microsoft SQL Server"* — es decir, GCP **restringe** esa integración a timestamp, no a ID. Esta claim específica queda en el mismo nivel de confianza que el precedente ya aceptado en el repo para contenido de BigQuery: corroborado por contenido indexado, no por cita textual verificada línea por línea.
- La razón real por la que la industria se mueve hacia mecanismos monotónicos **no es "ID en vez de timestamp"** sino **"número de secuencia/versión en vez de timestamp de aplicación"** — y esos números de secuencia no siempre son el primary key de negocio. El ejemplo más claro y mejor documentado es **SQL Server/Azure SQL Change Tracking** (`SYS_CHANGE_VERSION`), que Microsoft ofrece explícitamente como alternativa cuando el timestamp no alcanza: *"in some cases, there's no explicit way to identify the delta data from the last time that you processed the data. You can use the change tracking technology... to identify the delta data."* Fuente: [Incrementally copy data by using change tracking](https://learn.microsoft.com/en-us/azure/data-factory/tutorial-incremental-copy-change-tracking-feature-portal) (fetch directo). `SYS_CHANGE_VERSION` es monotónico *y* se actualiza en updates — a diferencia de un PK autoincremental puro, que solo sirve para detectar inserts nuevos, nunca updates a filas existentes. Esta distinción — "ID/PK" vs. "número de secuencia/versión monotónico" — es la que realmente importa, y ningún vendor la colapsa en una sola recomendación "ID > timestamp".
- Debezium / CDC log-based (LSN de Postgres, binlog position de MySQL, SCN de Oracle) es el ejemplo más extremo de "número de secuencia monotónico, no timestamp, no PK de negocio" — y es la alternativa que tanto Airbyte como el whitepaper de AWS recomiendan explícitamente por encima del polling por timestamp cuando está disponible (§1, §3a).

**Conclusión de §4:** la guía autorizada no dice "prefiere ID sobre timestamp" en esos términos. Dice, de forma consistente entre AWS/Microsoft/Airbyte: cuando el origen ofrece un mecanismo de secuencia/versión monotónico nativo (change tracking, log de transacciones, CDC), es preferible a un timestamp de aplicación — precisamente porque el timestamp depende de que la aplicación lo mantenga correctamente y de la visibilidad de la transacción (§3a), mientras que un número de secuencia del motor de base de datos no. Pero un primary key autoincremental simple no es ese mecanismo — solo cubre inserts. Esta es una afirmación más precisa y defendible que "ID-based es preferido", y es la que debería llegar al skill si se documenta este punto.

---

## Resumen de fuentes primarias usadas (verificadas por fetch directo salvo donde se indica lo contrario)

| Fuente | Uso | Método de verificación |
|---|---|---|
| Microsoft Learn — Azure Data Factory, `tutorial-incremental-copy-overview` | Definición canónica watermark (§1) | Fetch directo |
| Microsoft Learn — `solution-template-delta-copy-with-control-table` | Tabla de control, query con boundary exacto (§1, §2a, §3c) | Fetch directo |
| Microsoft Learn — `tutorial-incremental-copy-change-tracking-feature-portal` | Alternativa ID/version-based (§4) | Fetch directo |
| AWS Whitepaper — "AWS Glue Best Practices: Building a Performant and Cost Optimized Data Pipeline" | Definición high watermark + metadata tables (§1, §2a) | PDF descargado y extraído con `pdftotext`, texto completo revisado |
| AWS — `docs.aws.amazon.com/glue/latest/dg/monitor-continuations.html` (Job Bookmarks) | Persistencia de estado, requisito de PK secuencial (§2b, §3d) | Fetch directo |
| Airbyte — `incremental-append.md` (GitHub raw) | Cursor field, pitfall de boundary inclusivo, recomendación de CDC (§1, §3c) | Fetch directo del `.md` fuente |
| Airbyte — `connector-builder-ui/incremental-sync.md` (GitHub raw) | Lookback window (§3a) | Fetch directo del `.md` fuente |
| Fivetran — `getting-started/glossary` | Definición cursor/high-water mark (§1) | Fetch directo |
| Meltano Singer SDK — `implementation/state.html` | Checkpoint/archivo de estado (§2c) | Fetch directo |
| Airflow — `core-concepts/xcoms.html` | Estado nativo del orquestador (§2b) | Contenido indexado (resumen de búsqueda), no fetch línea por línea |
| Dagster — docs de sensors (`docs.dagster.io/guides/automate/sensors`) | Cursor de sensor (§2b) | Contenido indexado, no fetch línea por línea |
| Prefect — `docs.prefect.io/3.0/develop/variables` | Variables como estado persistente (§2b) | Contenido indexado, no fetch línea por línea |
| Debezium — `configuration/storage.html` | Offsets en Kafka Connect (§2b) | Fetch bloqueado (403 Cloudflare, 2 intentos); contenido indexado únicamente |
| BigQuery Data Transfer Service — `sqlserver-transfer` | Restricción a TIMESTAMP-only (§4) | Fetch devolvió shell JS sin contenido; contenido indexado únicamente (mismo problema ya documentado en `2026-07-29-sql-python-claims-verification.md` §4 para BigQuery) |
| Kleppmann, *Designing Data-Intensive Applications* | Respaldo conceptual de por qué timestamps/relojes no son confiables para CDC (§3b) | **No verificado** — sin cita textual ni número de página confirmados |

## Claims explícitamente NO verificadas — no usar como cita textual sin revisión adicional

1. **"Clock skew" como término documentado por algún vendor** para watermarks de extracción — no encontrado en ningún doc oficial revisado (§3b).
2. **"Late-arriving commit problem"** como nombre documentado verbatim por algún vendor para extracción query-based (no-CDC) — el fenómeno está confirmado (Fivetran, para CDC), el nombre no (§3a).
3. **Cita textual con página de Kleppmann/DDIA** sobre relojes no confiables aplicados a CDC — el libro sí cubre el tema, pero no logré obtener la cita exacta ni el número de página vía las herramientas disponibles (§3b).
4. **El requisito formal de Airbyte de que los cursor fields sean "monotonically increasing, never updated after creation, unique"** — apareció en un resumen de búsqueda pero **no está en el `.md` fuente real** verificado por fetch directo (§3d). Tratar como no confirmado / posible alucinación del resumen de búsqueda.
5. **Mitigación por "lookback/overlap window" aplicada específicamente a bases de datos con transacciones** (no solo APIs) — el patrón está bien documentado por vendors para APIs (Airbyte) pero para el caso JDBC/base de datos solo lo confirman fuentes secundarias (blogs), no un vendor oficial con esas palabras.
