# Research: build-vs-buy para la E y la L de un pipeline — verificación de dlt como opción intermedia

**Fecha:** 2026-08-20

**Alcance:** esto **no** es una verificación de claims existentes en la suite; es la evaluación de una **decisión de arquitectura que hoy la suite no nombra**: cuando alguien va a escribir un extractor, la suite le enseña a escribirlo a mano (`skills/python-data-engineering/references/external-api-integration.md`, `skills/python-data-engineering/references/production-patterns.md`) y nunca le plantea que hay tres opciones en la categoría — (1) extractor a mano, (2) librería EL declarativa embebida en tu propio código, (3) servicio de conectores gestionado. Se verificó contra **dlt 1.30.0** (última versión en PyPI al 2026-08-20, publicada 2026-08-11), leyendo la documentación oficial fijada al tag `1.30.0` del repo `dlt-hub/dlt` (los `.md` fuente de `docs/website/docs/**`, obtenidos por fetch directo de `raw.githubusercontent.com`, no del sitio renderizado), el `LICENSE.txt` del repo, los metadatos de los paquetes `dlt` y `dlthub` en PyPI, y la página de precios de dlthub.com. Además de la doc, dos claims de API se verificaron **en el código fuente** al mismo tag (`dlt/extract/incremental/__init__.py`, `dlt/pipeline/configuration.py`). Para las otras dos opciones de la categoría se usó documentación oficial de Airbyte (`docs.airbyte.com` y el markdown fuente en `airbytehq/airbyte`), Fivetran (`fivetran.com/docs` y `fivetran.com/pricing`), Meltano (`docs.meltano.com`, `sdk.meltano.com`), el spec de Singer (`singer-io/getting-started` más la API de GitHub para el estado de mantenimiento), y — para los ejes de decisión de la categoría — la doc oficial de Databricks Lakeflow Connect y de Azure Data Explorer publicada en Microsoft Learn. **No se editó ningún archivo de skills — solo este research file.**

**Sesgo declarado por adelantado:** el encargo pedía ejes de decisión, no un ganador. Las dos conclusiones que este documento defiende son: (1) dlt **refuerza** lo que la suite ya enseña sobre estado incremental — no lo contradice, y de hecho enuncia la invariante que a la skill le falta; y (2) el eje que decide **no** es "usá una librería" ni "escribilo a mano" sino una pregunta binaria y verificable — *¿existe un conector de primer nivel, mantenido por el proveedor, para esta fuente exacta?* — que es la única regla de decisión que dos fuentes primarias independientes publican con la misma forma (§F).

---

## A. ¿Qué te saca de encima exactamente la opción 2 (librería EL embebida)?

dlt divide `pipeline.run()` en **tres fases discretas**, y ese corte es lo que define qué asume como propio. Cita textual del explainer oficial:

> "1. Extract - Fully extracts the data from your source to your hard drive. […] 2. Normalize - Inspects and normalizes your data and computes a schema compatible with your destination. […] 3. Load - Runs schema migrations if necessary on your destination and loads your data into the destination."

Fuente: [`docs/website/docs/reference/explainers/how-dlt-works.md`](https://github.com/dlt-hub/dlt/blob/1.30.0/docs/website/docs/reference/explainers/how-dlt-works.md) (tag 1.30.0, fetch directo del `.md` fuente).

### Lo que dlt asume como propio, verificado uno por uno

| Responsabilidad | ¿La asume dlt? | Evidencia primaria |
|---|---|---|
| **Normalización de datos anidados a relacional** | Sí, y es la más difícil de replicar a mano | "the normalizer will detect one column `id` of type `int` in one table named `items`, it will furthermore detect a nested list in table items and unnest it into a child table named `items__nested`" (`how-dlt-works.md`). El nombre de tabla generado para 3 niveles de anidamiento es `org__inventory__details__specifications` (`schema-evolution.md`) |
| **Inferencia de esquema y tipos** | Sí | "dlt infers schemas and data types, normalizes the data, and handles nested data structures" (`intro.md`) |
| **Migración de esquema en el destino** | Sí | "dlt fully manages schema migrations on your destinations. You don't even need to know how to use SQL to update your schema." (`how-dlt-works.md`) |
| **Evolución de esquema** | Sí, con política por defecto **aditiva y nunca destructiva** (ver §C) | `schema-evolution.md`, `schema-contracts.md` |
| **Estado incremental entre corridas** | Sí, y lo persiste en el destino (ver §B) | `state.md`, `destination-tables.md` |
| **Carga idempotente por clave** | Sí, cuatro estrategias de `merge` (ver §C) | `merge-loading.md` |
| **Destinos** | Sí: al tag 1.30.0 la doc trae páginas de destino para `athena`, `bigquery`, `clickhouse`, `databricks`, `dremio`, `duckdb`, `ducklake`, `fabric`, `filesystem`, `huggingface`, `iceberg`/`delta`, `lance`/`lancedb`, `motherduck`, `mssql`, `postgres`, `qdrant`, `redshift`, `snowflake`, `sqlalchemy`, `synapse`, `weaviate`, más una interfaz de destino custom | listado de `docs/website/docs/dlt-ecosystem/destinations/` en el tag 1.30.0 |
| **Paginación y auth de REST APIs** | Sí, declarativamente, vía el core source `rest_api` | `intro.md` muestra `"paginator": {"type": "json_link", "next_url_path": "paging.next"}` y `"auth": {"token": dlt.secrets["your_api_token"]}` como configuración, no como código |
| **Reintentos de red en las llamadas HTTP** | Sí, si usás su wrapper | "dlt includes a request library replacement with built-in retries" (`reference/frequently-asked-questions.md`) |
| **Atomicidad del merge** | Sí, declarada: "All of this occurs within a single atomic transaction for the root and all nested tables" para la estrategia `delete-insert` (`merge-loading.md`) |

### Lo que te queda escribiendo igual

Esto es lo que la suite no debe dejar de enseñar, porque dlt no lo cubre:

1. **La lógica de la fuente misma.** Para una API no cubierta por `rest_api`, seguís escribiendo el generador: qué endpoints, en qué orden, qué campo es el cursor, cómo se compone la clave. El propio FAQ lo dice: *"In case you don't have the source required listed in the verified sources, you could create your own pipeline"* (`frequently-asked-questions.md`).
2. **Los reintentos del pipeline.** Textual: *"By default, `dlt` does not retry any of the pipeline steps. This is left to the included helpers"* (`running-in-production/running.md`) — el usuario tiene que envolver la corrida en `tenacity` o en los reintentos del orquestador.
3. **La orquestación y el scheduling** (ver §D).
4. **La T.** dlt cubre ETL liviano con `add_map()`/`@dlt.transformer` y ELT delegando a dbt/SQL/Python sobre el destino; las transformaciones de primera clase (`@dlt.hub.transformation`) son **producto pago** (ver §D y §E).
5. **La decisión de política.** dlt te da los modos (`evolve`/`freeze`/`discard_row`/`discard_value`); *elegir* cuál corresponde por entidad sigue siendo el judgment call que enseña `quality-data-engineering`.
6. **Las garantías de la fuente.** Nada en dlt arregla que un `updated_at` de aplicación no sea monotónico, ni que la API no exponga deletes.

**Acción:** agregar a `skills/python-data-engineering/SKILL.md`, en la tabla "Quick reference", una fila nueva antes de la de external-api-integration: `| Decidir si este extractor se escribe a mano, con una librería EL, o se compra | Cuenta de fuentes y quién debe dueñar la normalización/estado/merge | [production-patterns.md](references/production-patterns.md) |`. El contenido va en `production-patterns.md` (ver §G), y debe enunciar el corte así: *"A declarative EL library (dlt is the Python exponent) takes over normalization of nested data into relational tables, schema inference and destination migration, incremental state persistence, and keyed merge/upsert. It does not take over the source logic, pipeline-level retries, orchestration, the transformation layer, or the policy decision of what a schema change should do."*

---

## B. Estado incremental: ¿refuerza o contradice lo que `production-patterns.md` ya enseña?

Esta es la pregunta que más importa, porque `skills/python-data-engineering/references/production-patterns.md` línea 39 ya enseña la regla dura: *"state stored in something that doesn't outlive the run (a local variable, a task-only XCom) silently resets to 'extract everything' or 'extract nothing' on the next run, and neither failure looks like an error — it looks like a pipeline that ran successfully."*

**Veredicto: dlt REFUERZA esa regla, no la contradice — y de hecho la resuelve con el patrón que la skill lista tercero (checkpoint) más el que lista primero (tabla de control), combinados.**

### Dónde vive el estado, exactamente — dos lugares, no uno

1. **Local, en el working directory del pipeline.** *"Each pipeline that you create with `dlt` stores extracted files, load packages, inferred schemas, execution traces, and the pipeline state in a folder in the local filesystem. The default location for such folders is in the user's home directory: `~/.dlt/pipelines/<pipeline_name>`"* (`general-usage/pipeline.md`). Este solo no sobreviviría a un worker efímero.
2. **Remoto, en una tabla del propio destino.** *"`dlt` loads your state into the destination along with all other data, and when faced with a clean start, it will try to restore the state from the destination. […] The state is stored in the `_dlt_pipeline_state` table at the destination"* (`general-usage/state.md`). La tabla tiene columnas `version`, `engine_version`, `pipeline_name`, `state` (*"Serialized Python dictionary of pipeline state"*), `created_at`, `version_hash`, `_dlt_load_id`, `_dlt_id` (`general-usage/destination-tables.md`).

Ambos comportamientos están confirmados **en el código**, no solo en la prosa: `dlt/pipeline/configuration.py` en el tag 1.30.0 declara `restore_from_destination: bool = True` con el docstring *"Enables the `run` method of the `Pipeline` object to restore the pipeline state and schemas from the destination"*. El sync está prendido por defecto.

Es decir: **dlt implementa exactamente el patrón "tabla de control externa" que `production-patterns.md` llama "the most portable choice"** — con la diferencia de que la tabla vive en el mismo destino que los datos, no en un store aparte, y el commit del estado es atómico con el commit de los datos: *"The pipeline state is a Python dictionary that gets committed atomically with the data"* (`general-usage/incremental/advanced-state.md`).

### ¿Sobrevive a un rerun?

Sí, y con una garantía documentada más fuerte de lo que la skill hoy exige a nadie. Textual, sobre fallos en la fase de load:

> "Whichever you pick, until a package is fully loaded its load id is not added to the `_dlt_loads` table and the pipeline state at the destination stays at the point the package was created, so incremental cursors are not advanced past data that did not load."

Fuente: [`docs/website/docs/running-in-production/running.md`](https://github.com/dlt-hub/dlt/blob/1.30.0/docs/website/docs/running-in-production/running.md) (tag 1.30.0, fetch directo).

Eso es literalmente la mitigación del failure mode que la skill nombra: el watermark no avanza sobre filas que no se cargaron. La skill hoy no le pide esa propiedad a nadie de forma explícita, y debería.

**Pero la garantía no es total, y la propia doc lo dice:** *"Some jobs of a pending package may have already written to the destination and neither failing jobs nor aborting the package reverts that."* Un paquete puede quedar **parcialmente cargado** — dlt marca eso con un `WARNING` en el `PipelineStepFailed`, y da un comando para auditarlo (`dlt pipeline <name> load-package <load_id> row-counts`) y la regla de detección: *"If there are rows for the `load_id` but the package is not in `_dlt_loads`, the load did not finish and your data is inconsistent."*

### ¿Sobrevive a un backfill?

Sí, y el mecanismo es explícitamente **stateless por diseño**, lo cual es la propiedad que hace que backfill e incremental puedan coexistir:

> "Please note that when `end_date` is specified, `dlt` **will not modify the existing incremental state**. The backfill is **stateless** and: 1. You can run backfill and incremental load in parallel (i.e., in an Airflow DAG) in a single pipeline. 2. You can partition your backfill into several smaller chunks and run them in parallel as well."

Fuente: [`docs/website/docs/general-usage/incremental/cursor.md`](https://github.com/dlt-hub/dlt/blob/1.30.0/docs/website/docs/general-usage/incremental/cursor.md) (sección "Using `end_value` for backfill").

Los defaults de la API están confirmados en el código fuente además de en la doc: `dlt/extract/incremental/__init__.py` en el tag 1.30.0 declara la firma `Incremental(cursor_path=None, initial_value=None, last_value_func=max, primary_key=None, end_value=None, row_order=None, allow_external_schedulers=False, on_cursor_value_missing="raise", lag=None, range_start="closed", range_end="open")`.

Y el boundary está declarado, no implícito — esto habla directo al pitfall de "Boundary handling" de `production-patterns.md` línea 43: *"dlt's incremental filtering considers the ranges half-closed. `initial_value` is inclusive, `end_value` is exclusive […] This behaviour can be changed with the `range_start` (default `"closed"`) and `range_end` (default `"open"`) arguments."* Con `range_start="closed"` (default) dlt **deduplica** con un content hash o con el `primary_key`; con `range_start="open"` no deduplica porque no hace falta. También existe `lag` como ventana de atribución explícita, que es el "overlap/lookback window" que `external-api-integration.md` línea 118 ya recomienda: *"lag is the number of seconds added or subtracted from the last_value loaded"* (`general-usage/incremental/lag.md`).

### ¿Qué pasa cuando ese estado se pierde o se corrompe?

Aquí hay tres modos de fallo documentados, y son útiles para la skill **independientemente de si se adopta dlt**, porque son los mismos que tiene cualquier estado persistido:

1. **Se pierde el estado local:** se recupera del destino automáticamente ("when faced with a clean start, it will try to restore the state from the destination"). El sync se puede desactivar con `restore_from_destination=false`, y hacerlo en un worker efímero es el pie en el que se dispara uno solo.
2. **Se identifica el estado por tres cosas, y cambiar cualquiera lo pierde:** *"The remote state is identified by the pipeline name, the destination location (as given by the credentials), and the destination dataset. To reuse the same state, use the same pipeline name and destination."* La guía de troubleshooting lo pone como el chequeo #1: *"Make sure the `destination`, `pipeline_name`, and `dataset_name` are the same between pipeline runs"*, y el #2: *"Check if `dev_mode` is `False`"* (`general-usage/incremental/troubleshooting.md`). Un rename de dataset entre entornos = reset silencioso a "extraer todo". **Este es exactamente el failure mode que la skill ya nombra, con un disparador nuevo y concreto.**
3. **Se resetea a propósito:** `dlt pipeline <name> drop --state-paths <path>` resetea una ruta del estado sin tocar tablas ni datos; `dlt pipeline <name> sync` *"Drops the local state of the pipeline and resets all the schemas and restores it from destination"*; y *"If you drop the dataset the pipeline is loading to, this command results in a complete reset of the pipeline state."* (`reference/command-line-interface.md`).

**Límite honesto del mecanismo, declarado por la propia doc:** *"Do not use `dlt` state when it may grow to millions of elements. Do you plan to store modification timestamps of all your millions of user records? This is probably a bad idea!"* — la alternativa que propone es guardar el estado en DynamoDB/Redis (con la advertencia *"if the extract stage fails, you'll end up with an invalid state"*) o consultar los datos ya cargados como estado (`general-usage/state.md`).

**Acción:** en `skills/python-data-engineering/references/production-patterns.md`, sección "Incremental extraction: tracking what's new", agregar un cuarto bullet a la lista de tres patrones de persistencia del watermark: *"**State the library owns for you**, the pattern a declarative EL library implements: dlt persists the cursor in a `_dlt_pipeline_state` table in the destination itself, committed in the same transaction as the data, and its docs state the property you actually want from any of these four options outright — 'until a package is fully loaded its load id is not added to the `_dlt_loads` table and the pipeline state at the destination stays at the point the package was created, so incremental cursors are not advanced past data that did not load.' If you build the control table yourself, that is the invariant to build: the watermark advances only after the rows it covers are committed."* Y agregar una fila a "Common mistakes": `| Renaming the dataset/pipeline between environments when the watermark is keyed on it | The next run finds no state and restarts from scratch — dlt keys its remote state on pipeline name + destination + dataset, and any hand-rolled control table has the same exposure | Key the state on something that survives an environment rename, and assert on startup that a watermark was actually found instead of defaulting to "everything" |`

---

## C. Idempotencia y evolución de esquema

### Carga idempotente por clave: sí, con cuatro estrategias y garantías distintas

`write_disposition="merge"` con `primary_key` o `merge_key`. Las cuatro estrategias documentadas en [`general-usage/merge-loading.md`](https://github.com/dlt-hub/dlt/blob/1.30.0/docs/website/docs/general-usage/merge-loading.md):

| Estrategia | Qué garantiza | Caveat declarado |
|---|---|---|
| `delete-insert` (default) | *"loads data to a `staging` dataset, deduplicates the staging data if a `primary_key` is provided, deletes the data from the destination using `merge_key` and `primary_key`, and then inserts the new records. All of this occurs within a single atomic transaction for the root and all nested tables."* | Deduplicación arbitraria salvo que se declare el hint `dedup_sort` (`desc`/`asc`) |
| `scd2` | Mantiene ventanas de validez (`_dlt_valid_from`/`_dlt_valid_to`) automáticamente | *"We do not detect changes in nested tables (except new records) if the row hash of the corresponding parent row does not change"*; y no se puede usar `updated_at`/`version` como hash de fila |
| `upsert` | *"update a record if the key exists in the target table / insert a record if the key does not exist"*, vía `MERGE`/`UPDATE` | **Solo soportado en `athena`, `bigquery`, `databricks`, `mssql`, `postgres`, `snowflake`, y `filesystem` con delta/iceberg.** Requiere `primary_key` y *"expects this `primary_key` to be unique (`dlt` does not deduplicate)"* |
| `insert-only` | Inserta lo que falta, nunca actualiza — *"providing idempotent loads with better performance than `upsert`"* | Mismo subconjunto de destinos que `upsert` |

**El gotcha más importante para un code review, y está en la doc:** *"If you use the `merge` write disposition, but do not specify merge or primary keys, merge will fallback to `append`."* Un `write_disposition="merge"` sin claves no falla — degrada a append en silencio. Eso es exactamente la clase de fallo silencioso que la suite existe para atrapar.

Deletes: hay soporte, pero es opt-in vía el hint `hard_delete` sobre una columna de la fuente. No inventa deletes que la fuente no manda — que es coherente con lo que `external-api-integration.md` línea 120 ya advierte ("many APIs don't expose deletions").

### Un hallazgo lateral sobre el full load, que roza `sql-data-engineering`

`skills/sql-data-engineering/references/engineering-query-patterns.md` (sección "Full load (truncate-and-reload)") cubre muy bien la divergencia transaccional de `TRUNCATE` por motor, pero no el fallo a nivel *pipeline*. dlt documenta tres estrategias de `replace` y el trade-off exacto que falta:

- `truncate-and-insert` (**default**): *"the destination tables will be truncated at the beginning of the load, and the new data will be inserted consecutively but not within the same transaction. The downside of this strategy is that your tables will have no data for a while until the load is completed. You may end up with new data in some tables and no data in other tables if the load fails during the run."*
- `insert-from-staging`: *"will load all new data into staging tables away from your final destination tables and will then truncate and insert the new data in one transaction. It also maintains a consistent state between nested and root tables at all times."*
- `staging-optimized`: más rápido, *"at the cost of destination tables being dropped and recreated in some cases, which means that any views or other constraints you have placed on those tables will be dropped with the table."*

Fuente: [`docs/website/docs/general-usage/full-loading.md`](https://github.com/dlt-hub/dlt/blob/1.30.0/docs/website/docs/general-usage/full-loading.md). Es un buen ejemplo de vendor documentando que "truncate y luego insertar" tiene una ventana de tabla vacía si no se hace vía staging en una transacción. **Lo dejo fuera del alcance mínimo** (ver la sección de alcance) porque es un tema distinto del build-vs-buy, pero queda registrado como candidato para una futura edición de esa skill.

### Evolución de esquema: la política por defecto es aditiva y **nunca destructiva**

Verificado contra el caso de prueba que la propia doc corre (`general-usage/schema-evolution.md`), con cuatro cambios simultáneos en la fuente:

| Cambio en la fuente | Qué hace dlt por defecto |
|---|---|
| Columna agregada (`CEO`) | *"A new column named `ceo` is added to the 'org' table."* |
| Tipo cambiado (int → string) | *"A new column named `inventory_nr__v_text` is added"* — **columna variante**, no un cast destructivo |
| Columna borrada (`room`) | *"New data to column `room` is not loaded."* La columna **no se dropea** |
| Columna renombrada (`building` → `main_block`) | *"A new column `address__main_block` was added and now data will be loaded to that and stop loading in the column `address__building`."* Un rename se ve como borrado+agregado |

Y el default está enunciado formalmente en `general-usage/schema-contracts.md`: *"The default mode (**evolve**) works as follows: 1. New tables may always be created. 2. New columns may always be appended to the existing table. 3. Data that do not coerce to the existing data type of a particular column will be sent to a variant column created for this particular type."*

### ¿Choca o encaja con lo que `quality-data-engineering` enseña?

**Encaja en la mecánica; choca en el default.** Los tres ejes:

1. **La mecánica es la misma familia que Avro/Confluent.** `skills/quality-data-engineering/references/data-contracts-and-schema-compatibility.md` enseña que agregar una columna opcional es seguro en `BACKWARD`, y que **cambiar un tipo escalar no es compatible bajo `FULL`** — es unidireccional. El default de dlt es coherente con eso: no promociona el tipo, crea una columna variante nueva, lo que preserva la lectura de datos viejos y hace el cambio visible en lugar de invisible. Ese es un buen encaje, y vale citarlo como tal.
2. **El default es el opuesto del que enseña la skill.** La skill entera está construida sobre "el contrato bloquea al productor antes de que el cambio llegue" (`data-contracts-and-schema-compatibility.md`: *"checked automatically in the producer's own CI/CD"*, con un `409 Conflict` de Confluent como ejemplo de que "no es una advertencia blanda"). El default de dlt es `evolve` — **acepta todo cambio**. dlt tiene el equivalente al bloqueo (`freeze`, que *"will raise an exception if data is encountered that does not fit the existing schema, so no data will be loaded to the destination"*) más dos políticas intermedias que la skill de calidad ya tiene nombre para: `discard_row` es *drop-with-alert* a nivel fila y `discard_value` es *repair* a nivel valor, en el vocabulario de `failure-response-policies.md`. Pero hay que pedirlos.
3. **Hay un gotcha de enforcement que la skill de contratos debería conocer:** *"If you are loading to a table not created by dlt for the first time, dlt will not know about this table while enforcing schema contracts. This means that […] if you have `tables` set to `freeze`, dlt will raise an exception because it thinks you are creating a new table."* Y a la inversa, en tablas nuevas dlt **relaja el contrato una corrida**: *"For a single pipeline run, the column mode is changed (internally) to **evolve** and then reverted back to the original mode."* Un contrato `freeze` no protege la primera corrida de una tabla.

**Acción:** en `skills/quality-data-engineering/references/data-contracts-and-schema-compatibility.md`, agregar un párrafo corto al final de la sección "Enforcing contracts in CI/CD" (no una sección nueva): *"A third enforcement point exists that is neither a schema registry nor a CI check: the ingestion library itself. dlt's `schema_contract` takes the same four-way decision this suite frames elsewhere as fail/quarantine/drop/repair, and applies it per schema entity — `tables`, `columns`, `data_type` — with modes `evolve` (accept), `freeze` (raise, load nothing), `discard_row`, and `discard_value`. Two things are worth knowing before trusting it: the default is `evolve`, i.e. accept every change, and a table dlt has not created yet is treated as new, which internally relaxes the column mode to `evolve` for that one run. An ingestion-time contract is a real enforcement point, but it fires after the producer already shipped the change — it is a complement to producer-side CI, not a replacement."* Y agregar a "Common mistakes" de `skills/quality-data-engineering/SKILL.md`: `| Assuming an ingestion library's schema contract is enforced from the first load | dlt relaxes the column mode to evolve for a table it has not created yet, and cannot enforce a contract on a table created outside it | Enforce the contract from the second run on, or pre-create the schema; see data-contracts-and-schema-compatibility.md |`

Y en `skills/python-data-engineering/references/production-patterns.md`, "Common mistakes": `| Declaring a keyed merge without actually supplying the key | dlt's `merge` write disposition silently falls back to `append` when neither `primary_key` nor `merge_key` is set — the rerun duplicates and nothing errors | Assert the key is set; the same trap exists in any hand-rolled "upsert" whose key is a config value that can be empty |`

---

## D. Los límites honestos, según su propia doc

### Es EL — la T está mayormente afuera, y la parte buena está paga

> "`dlt` supports both Extract, Transform, Load (ETL) and Extract, Load, Transform (ELT) patterns. […] In ETL […] `dlt` offers built-in utilities like `add_map()` and custom processors via `@dlt.transformer`. In ELT, the data is loaded as-is in the destination. This raw data is transformed directly on the destination where more powerful compute is available."

Fuente: [`docs/website/docs/dlt-ecosystem/transformations/index.md`](https://github.com/dlt-hub/dlt/blob/1.30.0/docs/website/docs/dlt-ecosystem/transformations/index.md).

O sea: la T que trae la librería OSS es *"light processing such as adding columns, removing sensitive data, or type casting"*. Las transformaciones de primera clase con procesamiento incremental (`@dlt.hub.transformation`) están en el producto pago (ver §E).

### No trae orquestación

> "`dlt` runs anywhere Python runs. This provides a lot of flexibility for deployment options. Here, you will find deployment guides for popular orchestrators."

Fuente: [`docs/website/docs/walkthroughs/deploy-a-pipeline/index.md`](https://github.com/dlt-hub/dlt/blob/1.30.0/docs/website/docs/walkthroughs/deploy-a-pipeline/index.md). Las guías cubren Airflow/Composer, Dagster, Prefect, Kestra, Modal, Orchestra, GitHub Actions, Cloud Functions, Cloud Run. El scheduling gestionado (`dlthub deploy`) es producto pago.

Reforzando eso, dos consecuencias documentadas:
- **No hay reintentos a nivel pipeline por defecto:** *"By default, `dlt` does not retry any of the pipeline steps. This is left to the included helpers"* (`running-in-production/running.md`) — con helpers sobre `tenacity`. Si no lo envolvés, lo tiene que hacer el orquestador.
- **Para un backfill particionado hace falta un orquestador, y la doc lo pide:** *"For a robust backfill of this kind you probably want to use an orchestrator to make sure that each partition is loaded and loaded only once"* (`general-usage/incremental/cursor.md`).

Eso deja el límite entre esta decisión y `pipelines-architecture-data-engineering` **nítido**: la librería EL decide *cómo* se extrae, normaliza y carga; el orquestador decide *cuándo*, *con qué ventana*, *con qué concurrencia* y *qué se reintenta*. La decisión de build-vs-buy de la E y la L no toca nada de lo que enseña esa skill.

### Lo que la doc dice sobre escala — y es un límite real de arquitectura

La fase de extract **escribe todo a disco local antes de normalizar**: *"During the extract phase, dlt fully extracts the data from your sources to your hard drive into a new load package"* (`how-dlt-works.md`). Las consecuencias están documentadas:

- *"In case you extract a lot of data at once (i.e. backfill) or your runtime env has constrained local storage (i.e. cloud functions) you can keep your data on a bucket by using FUSE"* — con la advertencia de que *"`dlt` uses rename when saving files and 'committing' packages (folder rename). Those may be not supported on bucket filesystems"* (`reference/performance.md`).
- *"If your storage reaches its limit, you are likely running dlt in a cloud environment with restricted disk space. To prevent issues, mount an external cloud storage location and set the `DLT_DATA_DIR` environment variable"* (idem).
- *"To resume jobs after a failure, however, it's necessary to run the pipeline in its own virtual machine (VM). Ephemeral storage solutions like Cloud Run don't support job resumption."* (`reference/frequently-asked-questions.md`).

La escala se ataca con paralelismo intra-pipeline (extract/normalize/load), buffers configurables, rotación de archivos intermedios y descomposición de sources, todo en `reference/performance.md`. Pero **no hay compute distribuido**: es un proceso Python, y el techo es la máquina.

Pitfalls declarados que valen como advertencia operativa: *"Do not run pipelines with the same name and working dir in parallel on the same machine. dlt will not be able to manage state and temporary files properly if you do this."*

### ¿Dice la doc cuándo NO usarlo?

Casi. Lo más cerca de un "cuándo no" es formulado como un "cuándo sí", en la página que compara los dos productos: *"**dlt is a good fit if:** You want a lightweight, code-first ingestion library, are comfortable managing orchestration, scheduling, and operations yourself, or you need to deploy on-prem, on a VPS, or in any environment where managed cloud solution is not an option."* (`hub/getting-started/oss-and-dlthub.md`). Es **material de una página que vende el producto pago**, así que el "cuándo no" implícito ("si no querés operar orquestación y operaciones vos mismo") empuja a dltHub, no a un competidor. Hay que citarlo como lo que es. Un enunciado explícito del tipo "no uses dlt si…" **no existe en la doc oficial al tag 1.30.0** — verificado por grep sobre los `.md` descargados.

**Acción:** en `skills/python-data-engineering/references/production-patterns.md`, en el bloque de decisión propuesto en §A, cerrar con el límite: *"What the library does not buy you: the orchestration layer (dlt ships deploy guides for Airflow, Dagster, Prefect and GitHub Actions, not a scheduler), pipeline-level retries ('By default, `dlt` does not retry any of the pipeline steps'), or distributed compute — the extract phase writes the whole load package to local disk before normalizing, so a large backfill on an ephemeral runtime needs a mounted bucket (`DLT_DATA_DIR`) and, per dlt's own FAQ, cannot resume a failed job at all on ephemeral storage like Cloud Run."*

---

## E. Licenciamiento y modelo comercial

Esto es material duro de build-vs-buy, y es verificable con precisión.

### El paquete OSS

- **`dlt`: Apache-2.0.** Verificado en tres lugares independientes: `license_expression: Apache-2.0` en los metadatos de PyPI para 1.30.0 (publicada 2026-08-11); el clasificador `License :: OSI Approved :: Apache Software License`; y el `LICENSE.txt` del repo (texto de Apache 2.0 v2.0, enero 2004). La API de GitHub reporta `spdx_id: Apache-2.0` para `dlt-hub/dlt`.
- El titular del copyright es **ScaleVector GmbH** (así aparece en `docs/website/docs/hub/license.md`: *"Copyright 2026 ScaleVector, GmbH"*).
- La página de precios afirma *"dlt stays open source and Apache 2.0 licensed forever"* — es un compromiso de marketing, no una cláusula de la licencia; citarlo como tal.

### El producto pago

**dltHub** es un producto comercial separado, con una licencia que **no es open source**. Textual de `hub/getting-started/oss-and-dlthub.md`: *"**dltHub offers two products**: dlt (open source) and **dltHub** (commercial)"* / *"dlt is free and open source under Apache 2.0, dltHub is a paid product."*

El paquete `dlthub` en PyPI (versión 0.30.0) declara en su campo `license` una **EULA propietaria**, no una licencia OSI: *"This software package (the 'Software') is licensed solely under the dltHub Software End User License Agreement"*, con el texto canónico en `https://dlthub.com/docs/plus/EULA`. Su `summary` es literalmente *"dlthub is a commercial extension to dlt"*.

La licencia de los toolkits (`docs/website/docs/hub/license.md`) es **source-available con restricción de uso**, y las restricciones son concretas y relevantes para una decisión de arquitectura. Textual, sobre usos NO permitidos: *"Using toolkits and skills provided by dltHub to generate code or pipelines for deployment on a third-party runtime platform or orchestration service that is not part of dltHub Services."* Es decir: los toolkits de IA se pueden usar para generar pipelines **para correr en dltHub**, no para correr en tu Airflow. Eso es lock-in explícito de la licencia, no una inferencia.

### Qué está detrás del paywall, exactamente

De la tabla comparativa de `hub/getting-started/oss-and-dlthub.md` (columna `dlt` = —, columna `dltHub` = ✅):

- El AI Harness / AI Workbench
- **Data quality metrics & checks**
- Los pipelines de transformación (dltHub/dbt)
- El runtime gestionado (deploy, schedule, servir data apps, monitoreo)
- **Fuentes premium (MS SQL) y destinos premium (Iceberg, Delta, Snowflake + Iceberg/Open Catalog)**

**Este último punto es el hallazgo más incómodo para la suite, y hay que decirlo:** `skills/python-data-engineering/references/production-patterns.md` línea 46 recomienda explícitamente *"Where the source exposes a genuine change-sequence (SQL Server/Azure SQL's Change Tracking is the clearest example, versioning inserts and updates), that's more robust than either"*. En dlt, **la fuente de MS SQL Change Tracking es un componente pago**: la página `hub/ingestion/ms-sql.md` abre con *"Use of the dltHub platform and toolkits is subject to a commercial dltHub License"* y describe exactamente esa capacidad (*"syncing an MS SQL Server table using Change Tracking […] including inserts, updates, and deletes"*). El consejo de la skill es correcto y sigue siendo correcto; lo que cambia es que la ruta "librería" no te lo da gratis para ese motor.

### El modelo de precios, y por qué el eje importa

De [dlthub.com/pricing](https://dlthub.com/pricing) (fetch directo, 2026-08-20):

- **dlt:** *"Free / Apache 2.0"*, con *"Limited verified OSS connectors"* y *"AI help and community support"*.
- **dltHub:** *"From $1,190 / month"* (o *"From $11,900 / year"*, *"Save 17%"*), con *"500 credits / month included"* y un trial de 14 días con $30.
- **Enterprise:** *"Custom"*.

La unidad de facturación es el crédito, y **es tiempo de cómputo, no volumen de datos**: *"1 USD credit covers one hour of runtime at the standard rate, for both batch jobs (like data pipelines) and interactive jobs (like notebooks). You pay only for the hours your jobs actually run, never for idle infrastructure. Every sandbox dltHub spins up has at least 2 vCPUs and 4GB of memory."* El overage baja en tramos de $1.00 a $0.80 por crédito.

Ese es un eje de decisión de verdad, y es distinto del de un servicio de conectores gestionado: **dltHub cobra por horas de runtime; Fivetran cobra por filas activas modificadas.** Ver §F para la verificación del lado de Fivetran/Airbyte.

Advertencia operativa que la propia página declara y que vale para cualquiera que presupueste esto: *"Pipelines do not pause automatically today. At launch your admin team is alerted within 72 hours, when you reached 80% and 100% of included credits."*

**Acción:** en el bloque de decisión propuesto en §A (`production-patterns.md`), incluir la línea de licenciamiento sin nombres de precios (que envejecen mal): *"Check the licensing line before you pick the middle option: dlt the library is Apache-2.0, but its managed runtime, its data-quality checks, its transformation layer and some of its sources and destinations — MS SQL Change Tracking and Iceberg/Delta among them — are a separately licensed commercial product, and the toolkit license forbids using the paid AI tooling to generate pipelines for a third-party runtime. 'Open source library' and 'the feature you need is open source' are different claims."*

---

## F. Los ejes de la decisión de categoría: ¿hay guía de primera fuente, o solo marketing?

**Respuesta corta: hay guía de primera fuente, es utilizable, y toda ella viene de alguien que vende una de las tres opciones. No encontré ninguna fuente primaria neutral — ni un estándar, ni un cuerpo de la industria, ni una guía de arquitectura sin producto detrás — que enuncie los ejes. Eso hay que decirlo en la skill, no esconderlo.**

### La formulación más limpia de la escalera, y quién la escribe

La guía más explícita que encontré es de **Databricks**, en la doc oficial de Lakeflow Connect. Enuncia una regla de decisión en una frase:

> "Databricks recommends starting with the most managed layer. If it doesn't satisfy your requirements (for example, if it doesn't support your data source), drop down to the next layer."

Fuente: [What is Lakeflow Connect? — "Layers of the ETL stack"](https://learn.microsoft.com/azure/databricks/ingestion/overview) (Microsoft Learn, fetch directo).

Y define las capas de arriba hacia abajo: conectores *fully-managed* → conectores *standard*/customizables → conectores *community* (*"open-source, built and maintained by the community, and not backed by Databricks SLAs"*) → conectores *custom* que construís vos → **DIY**, donde la propia doc nombra las librerías del ecosistema:

> "DIY ingestion. Databricks provides a general compute platform. As a result, you can create your own ingestion connectors using any programming language supported by Databricks, like Python or Java. You can also import and use popular open source connector libraries like data load tool, Airbyte, and Debezium."

**Etiquetado honesto:** es material de un vendor que vende la capa *más* gestionada de su propia escalera, y la regla que publica es "empezá por la más gestionada". El sesgo va en la dirección que le conviene. Aun así es citable, por dos razones: (a) reconoce explícitamente las otras opciones, incluida dlt por nombre, y (b) su enunciado de *qué* te compra la capa gestionada es concreto y verificable, no un adjetivo.

### Qué te compra exactamente la capa gestionada, según quien la vende

> "Fully-managed connectors build on Lakeflow pipelines, offering even more automation for the most popular data sources. They extend Lakeflow pipelines functionality to also include source-specific authentication, CDC, edge case handling, **long-term API maintenance**, automated retries, automated schema evolution, and so on."

Fuente: idem. La lista es útil justamente porque es la lista de cosas que la suite hoy le enseña al lector a escribir a mano: auth por fuente, manejo de casos borde, reintentos, evolución de esquema. Y "long-term API maintenance" es el ítem que ninguna de las otras dos opciones te da: cuando la API de origen cambia, alguien más lo arregla.

### Y el riesgo del lado "comprar", documentado por quien vende

Esto es lo más valioso de toda la sección, porque es un vendor documentando la contra de su propio producto:

> "Databricks SaaS, database, and other fully-managed connectors depend on the accessibility, compatibility, and stability of the application, database, or external service they connect to. Databricks does not control these external services and, therefore, has limited (if any) influence over their changes, updates, and maintenance. If changes, disruptions, or circumstances related to an external service impede or render impractical the operation of a connector, **Databricks may discontinue or cease maintaining that connector**."

Fuente: [Managed connectors in Lakeflow Connect](https://learn.microsoft.com/azure/databricks/ingestion/lakeflow-connect/) (Microsoft Learn, fetch directo).

O sea: comprar el conector no elimina el riesgo de mantenimiento — lo transfiere, y el proveedor se reserva el derecho de devolvértelo. Ese es un eje de decisión real y no lo dice ningún blog: lo dice el vendor en su propia doc.

### Un segundo punto de datos, independiente, con la misma forma

**Azure Data Explorer** publica su decisión como árbol, y el nodo terminal es exactamente el mismo:

> "For data stored in other places, check the connectors overview to see if there's a dedicated connector that can fit your use case. If so, follow the guidance to use that connector. If not, write custom code using Kusto client libraries."

Fuente: [Azure Data Explorer data ingestion overview](https://learn.microsoft.com/azure/data-explorer/ingest-data-overview), texto accesible del diagrama "Continuous data ingestion" (fetch directo). En la tabla comparativa de la misma página, la fila de las Kusto client libraries lista como escenario más común *"Write your own code according to organizational needs"*.

Dos vendors distintos, de forma independiente, publican la **misma** regla de decisión: **conector prehecho si existe uno para tu fuente; código propio si no existe.** Ese es el eje sostenido con más peso de toda esta investigación, y notablemente **no** es "cuántas fuentes tenés" ni "qué tan senior es tu equipo" — es una pregunta binaria y verificable en cinco minutos: *¿existe un conector mantenido para esta fuente exacta?*

### El eje de costo, en resumen

El eje de costo no es "gratis vs. pago" — es **por qué unidad te cobran**, porque eso decide cómo escala el gasto con tu carga:

- **Extractor a mano:** costo = tiempo de ingeniería (construcción y, sobre todo, mantenimiento cuando la fuente cambia) + tu propio cómputo.
- **Librería embebida:** el paquete es gratis (Apache-2.0); el costo es tu cómputo y tu operación. Si subís al producto gestionado del mismo proveedor, el precio es por **horas de runtime** (§E).
- **Servicio gestionado de conectores:** por **volumen de cambio** (Fivetran) o por **filas/GB transferidos, o capacidad concurrente** (Airbyte) — detalle verificado más abajo.


### El mejor enunciado de "qué estás reimplementando a mano" — y es de Airbyte

Este es el hallazgo más útil de toda la sección para la suite, porque es un vendor enumerando exactamente el índice de `skills/python-data-engineering/references/external-api-integration.md`:

> "In building and maintaining hundreds of connectors at Airbyte, we've observed that whereas API source connectors constitute the overwhelming majority of connectors, they are also the most formulaic. API connector code almost always solves small variations of these problems:
> 1. Making requests to various endpoints under the same API URL […]
> 2. Authenticating using a common auth strategy such as Oauth or API keys
> 3. Pagination using one of the 4 ubiquitous pagination strategies: limit-offset, page-number, cursor pagination, and header link pagination
> 4. Gracefully handling rate limiting by implementing exponential backoff, fixed-time backoff, or variable-time backoff
> 5. Describing the schema of the data returned by the API, so that downstream warehouses can create normalized tables
> 6. Decoding the format of the data returned by the API (e.g JSON, XML, CSV, etc..) and handling compression (GZIP, BZIP, etc..)
> 7. Supporting incremental data exports by remembering what data was already synced, usually using date-based cursors"

Fuente: [Low-code CDK overview — Airbyte Docs](https://docs.airbyte.com/platform/connector-development/config-based/low-code-cdk-overview) (fetch directo).

Los puntos 2, 3, 4, 5 y 7 son, uno por uno, las secciones de `external-api-integration.md` (Authentication; Pagination — y las cuatro estrategias que Airbyte nombra son las mismas cuatro que enseña el archivo, incluido el Link header; Rate limiting and resilience; Contract and observability; Incremental extraction). **Eso valida el contenido de la suite y a la vez es el argumento más honesto de por qué existe la opción 2: lo que enseñamos a escribir es formulaico.** La conclusión que Airbyte saca de ahí ("significantly decrease development effort and bugs") es claim de vendor sin cuantificar; la enumeración no lo es.

### La escalera de Airbyte, con negativas explícitas

Airbyte publica una escalera de cinco escalones con preconditions verificables, no adjetivos: conector del catálogo → **Connector Builder** (no-code, *solo sources*, HTTP + JSON/JSONL) → **Low-Code CDK** (YAML) → **Python CDK** → imagen Docker propia (desaconsejada). Citas:

> "If you need a connector for a data source that has an HTTP API, in 99% cases you should use the [Connector Builder] to build a connector."
> "You should only build and deploy your own connector in code (using Python or Java CDKs or any other language) when Builder does not support your data source or destination."

Fuente: [Custom connectors — Airbyte Docs](https://docs.airbyte.com/integrations/custom-connectors). Y sobre el Python CDK, de su propia tabla de opciones: *"While this method provides the most flexibility to developers, it also requires the most code and maintenance."* ([Connector development](https://docs.airbyte.com/platform/connector-development/)).

**Etiquetado:** guía de ingeniería. Tiene precondiciones falsables y casos negativos explícitos (el Builder no hace destinations; solo HTTP + JSON).

### El único "cuándo NO" de Fivetran es "cuándo el conector prehecho no alcanza"

> "The Connector SDK service is a good fit for the following use cases:
> - Fivetran doesn't have a connector for your source or is unlikely to support it in the near future.
> - You are using private APIs, custom applications, unsupported file formats or those that require pre-processing.
> - You have sensitive data that needs filtering or anonymizing before entering the destination.
> - You don't want to introduce a third party into your data pipeline (for example, to host a custom function)."

Fuente: [Connector SDK — Fivetran Docs](https://fivetran.com/docs/connector-sdk).

**Y el costo de comprar, dicho por el vendedor, en una sola frase** — este es el mejor material de la sección para un eje de decisión:

> "2. One default, simple, predictable choice. Our industry is rife with unnecessary complexity. Fivetran is as easy as possible for as many users as possible. **We only provide advanced configuration to work around unavoidable system and environment complexity.**"

Fuente: [Product principles — Fivetran Docs](https://fivetran.com/docs/core-concepts/product-principles). Los ejemplos que la propia página da: *"All table and column names become lowercase by default"*, *"A single, standard schema for application connectors"*, *"A default sync frequency of every six hours"*. Es el vendedor declarando que la configurabilidad se retira **a propósito**. Si tu caso necesita control fino sobre el esquema de destino, la frecuencia o el naming, la opción 3 te lo niega por diseño, no por omisión.

### Meltano es el único que explica POR QUÉ el framework le gana al código a mano

> "**Why is Silver the maximum rating for connectors not based on the Meltano SDK?** Connectors that are not based on the Meltano SDK typically do not use all the features and performance optimizations available in the Singer specification and the SDK implementation thereof. Even if they have high usage, their quality and feature and data coverage are harder to assess, they will not benefit from future improvements to the Singer spec and SDK, and that they are significantly harder to maintain and contribute to."

Fuente: [Connectors — Meltano Docs](https://docs.meltano.com/contribute/connectors).

Tres mecanismos nombrados y falsables: cobertura de features/performance, evaluabilidad, y **herencia de mejoras futuras**. Ese tercero es el argumento estructural real de la opción 2 sobre la 1, y es el mismo que aplica a dlt: bumpear una dependencia te trae arreglos que no escribiste. **Etiquetado:** guía de ingeniería en página de vendor — Meltano es el autor del SDK, así que el rating también le conviene estructuralmente. La cifra *"developers tell us […] about 70% less code"* del README del SDK **no tiene metodología ni fuente y debe tratarse como claim sin respaldo**.

Y el costo de migración, documentado: *"When porting over an existing tap, most developers find it easier to start from a fresh repo than to incrementally change their existing one."* ([Porting guide — Meltano SDK](https://sdk.meltano.com/en/latest/guides/porting.html)). El framework no se adopta incrementalmente sobre un extractor a mano existente — eso es un eje de decisión de verdad: es más fácil elegir bien al principio que corregir después.

### El spec de Singer garantiza menos de lo que la gente cree, y está congelado

Lo que el spec garantiza, textual: un tap es *"an application that takes a configuration file and an optional state file as input and produces an ordered stream of record, state and schema messages as output […] **A Tap may be implemented in any programming language.**"* (Singer Specification, Version 0.3.0, [`docs/SPEC.md`](https://github.com/singer-io/getting-started/blob/master/docs/SPEC.md)). Es un contrato de mensajes por stdout más una convención de CLI. Garantiza **composabilidad** de taps y targets. No garantiza nada sobre calidad, auth, paginación, rate limiting ni reintentos — que es exactamente el hueco que llena el SDK, y exactamente por qué existe el rating "no-SDK tope Silver".

Estado de mantenimiento, con números en vez de adjetivos: el repo **no está archivado y no tiene aviso de deprecación**, pero registra commits por año sobre los últimos 100: *2018: 48, 2019: 13, 2020: 21, 2021: 15, 2022: 0, 2023: 0, 2024: 1, 2025: 2, 2026: 0*, con `pushed_at = 2025-08-08` (API de GitHub). El repo tampoco declara licencia (`license = null`). La conclusión defendible es "no deprecado pero efectivamente congelado", y la tutela de facto se movió a Meltano, cuya propia página del spec se describe como *"our attempt at simplifying the canonical specification into an easier to understand and follow format"*.

**Relevancia directa para la suite:** `skills/python-data-engineering/references/production-patterns.md` línea 37 llama a Singer/Meltano *"the pattern the Singer/Meltano ELT ecosystem is built on"*, en presente. Eso sigue siendo correcto (el ecosistema vive vía el Meltano SDK), pero si alguna vez se escribe algo que dependa de que el *spec* esté activo, hay que mirar estos números primero.

### El hallazgo negativo sobre dlt, y hay que decirlo

**dlt no enmarca su producto contra escribir tu propio código ni contra los servicios gestionados, en ninguna parte de su documentación.** Verificado por code search sobre `dlt-hub/dlt`: `"Fivetran"` → **0 resultados en todo el repositorio**; `"build vs buy"` → 0 resultados; `"why dlt"` → 1 resultado, únicamente en el `README.md`, es decir **no hay página "why dlt" en el sitio de docs**. Lo único citable es una frase del README: *"It's a **library, not a platform** — you `pip install` it into your existing code and keep your workflow and the other tools you already use. No black boxes: clean Pythonic interfaces, human-readable file formats, schemas you can inspect, no hidden side effects."*

Es copy de marketing, pero es el enunciado más limpio disponible de qué te compra la opción 2 frente a la 3. Y el vacío es informativo por sí mismo: si la skill quiere un eje "dlt vs. Fivetran", **ese eje no existe en fuente primaria de dlt** y habría que construirlo, lo cual es exactamente lo que este documento no debería hacer pasar por hallazgo.

### Los dos vendors gestionados afirman lo mismo sobre escribir a mano, y ninguno lo sustenta

- Airbyte: *"In-house data pipelines are brittle and costly to build and maintain."* ([docs.airbyte.com/platform/](https://docs.airbyte.com/platform/))
- Fivetran: *"Building a custom data pipeline from scratch is complicated. It's even harder to maintain."* ([Function connectors](https://fivetran.com/docs/connectors/functions))

**Etiquetado: copy de marketing, ambas.** Es la conclusión de la decisión de build-vs-buy afirmada sin argumento, en páginas que venden la alternativa. Que dos competidores digan la misma frase no la convierte en evidencia. **Esto es precisamente el tipo de eje que el encargo pedía marcar y descartar.**

### El eje de costo en detalle: qué desplaza cada opción, según doc oficial

Los tres modelos no se diferencian por "gratis vs. pago" sino por la unidad de facturación, y eso decide cómo escala el gasto con tu carga. Todo lo de abajo es doc oficial del propio vendor.

#### Fivetran: te cobran por volumen de CAMBIO, no por volumen almacenado

> "Your connection and activation usage is measured in Monthly Active Rows (MAR). MAR are unique identifiers, or primary keys, that we use to track transfers from your source system to your destination each month. These keys are counted separately for each account, destination, connection, table, activation, and activation sync. Once a row is active, it is only counted once per month - no matter how many updates are made that month."

> "We sync most connections using incremental updates where we only update the new, deleted, or updated rows each sync. **Thus, you only pay for a subset of the data in the source every month.** […] **If you opt to modify years-old historical records every sync, we re-import the complete source data that may cause a very high percentage of the tables to have MAR.**"

Fuente: [Usage-based pricing — Fivetran Docs](https://fivetran.com/docs/usage-based-pricing). El FAQ de precios lo cierra: usage incluye inserts y updates (deletes incluidos), y **excluye** *"Unchanged rows: Rows retrieved during scheduled re-syncs that haven't changed since the previous sync"* y *"Initial syncs: The initial bulk data load performed when setting up a connector"* ([fivetran.com/pricing](https://fivetran.com/pricing)).

Dos gotchas documentados que valen como advertencia de arquitectura:

> "Even if the connections sync the same data from the same source (with the same primary keys), they contribute separately to your MAR." — es decir, **staging y prod duplican la factura**.
> "**If a primary key is not available, we create a synthetic (hashed) primary key to ensure consistency.**" — una fuente sin clave natural termina facturada contra un hash de contenido, así que un cambio cosmético en una fila cuenta como fila activa.

#### Airbyte Cloud: créditos, con dos modelos distintos según la fuente

| Source Type | Billing Type | Price | Credit Equivalent |
|---|---|---|---|
| APIs | Rows | $15 per million rows | 6 credits |
| Databases | GB | $10 per GB | 4 credits |
| Files | GB | $10 per GB | 4 credits |
| Custom sources | Rows | $15 per million rows | 6 credits |

Fuente: [Manage credits — Airbyte Docs](https://docs.airbyte.com/platform/cloud/managing-airbyte-cloud/manage-credits) (tabla verbatim). Y una advertencia honesta del propio vendor que es oro para una skill:

> "For Databases and File sources, Airbyte measures the data volume observed by the Airbyte Platform during the sync […] **This is likely to be a larger representation of your data than you would see if you were to query your database directly**, and varies depending on how your database stores and compresses data."

Es decir: el GB que te facturan no es el GB de tu base. Además, en los planes por capacidad el scheduling sigue siendo tu problema: *"When all committed data workers are in use, newly triggered sync jobs are queued until capacity becomes available"*, y la remediación que la propia doc propone es *"Reschedule some connections so they run at different times"* / *"Stagger start times"* ([Manage data workers](https://docs.airbyte.com/platform/cloud/managing-airbyte-cloud/manage-data-workers)).

#### Airbyte self-managed (Core): qué corrés vos, exactamente

Cuatro obligaciones documentadas, y la cuarta es un hallazgo de seguridad:

1. **Un clúster de Kubernetes:** *"Airbyte is built to be deployed into a Kubernetes cluster. […] We highly recommend deploying Airbyte using Helm"* ([Deploying Airbyte](https://docs.airbyte.com/platform/deploying-airbyte/deploying-airbyte)).
2. **Tu propio Postgres de producción:** *"For production deployments, we recommend using a dedicated database instance for better reliability, and backups (such as AWS RDS or GCP Cloud SQL) instead of the default internal Postgres database"* ([Database](https://docs.airbyte.com/platform/deploying-airbyte/integrations/database)).
3. **Tu propio object storage** para estado y logs ([Storage](https://docs.airbyte.com/platform/deploying-airbyte/integrations/storage)).
4. **Tu propio secret manager — y el default es texto plano:** *"Airbyte's default behavior is to store connector secrets on your configured database. **This will be stored in plain-text and not encrypted.**"* ([Secrets](https://docs.airbyte.com/platform/deploying-airbyte/integrations/secrets)).

Mínimo de máquina: *"For best performance, run Airbyte on a machine with 4 or more CPUs and at least 8-GB of memory."* Y un riesgo de estrategia comercial, documentado por ellos mismos: *"Airbyte no longer sells Self-Managed Enterprise."* ([Enterprise setup](https://docs.airbyte.com/platform/enterprise-setup/)).

#### Lo que realmente dejás de dueñar cuando comprás — y no es todo

Este es el punto donde "comprar" se vuelve más chico de lo que suena. **Los tres proveedores tienen la misma estructura de tres niveles: nosotros lo mantenemos / la comunidad lo mantiene / lo mantenés vos** — y solo el primero es lo que la gente quiere decir con "comprar".

**Airbyte**, matriz de soporte por nivel ([Connector support levels](https://docs.airbyte.com/integrations/connector-support-levels)):
- `Airbyte` / `Enterprise`: mantenidos por Airbyte, *"production readiness: Guaranteed"*.
- `Marketplace`: *"Are not maintained by Airbyte. Are not covered by Airbyte support SLAs. […] **Might not be feature complete and may experience backward-incompatible, breaking changes with no notice.**"*
- `Custom`: *"You alone are responsible for their quality and production readiness."*

Y el riesgo del catálogo: *"From time to time, Airbyte removes a connector. This is typically due to low use and/or lack of maintenance from the Community. […] Archived connectors don't receive any further updates or support from the Airbyte team."*

**Fivetran**, el límite de responsabilidad dicho con una claridad inusual ([Connector SDK](https://fivetran.com/docs/connector-sdk)):

> "**Who is responsible if a connector breaks?** Connector SDK uses a shared responsibility model. **Fivetran owns the managed execution environment, scheduling, core delivery path, logging, and infrastructure. You own the connector code: the source API logic, state handling, and fixes when the source changes.**"

Contra lo que sí prometen para los conectores del catálogo: *"Each connector handles schema changes, API updates, and incremental syncs automatically — no data pipelines to maintain."* ([Connectors](https://fivetran.com/docs/connectors)).

**Conclusión del eje, y es el que debería llegar a la skill:** la pregunta no es "¿comprar o construir?" sino **"¿existe un conector de primer nivel, mantenido por el proveedor, para esta fuente exacta?"** Si sí, comprás mantenimiento real. Si la respuesta es "hay uno de la comunidad", comprás la plataforma pero seguís dueñando el riesgo del conector — y en ese escenario la comparación honesta es contra una librería embebida, no contra el conector gestionado que no tenés.

### Lo que NO encontré, y lo marco como tal

- **No verificable contra fuente primaria: una comparación neutral de las tres opciones, publicada por alguien que no vende ninguna.** No existe en el corpus revisado. Se buscó por code search sobre `dlt-hub/dlt`, `meltano/meltano`, `meltano/sdk`, `airbytehq/airbyte` y `singer-io/getting-started` por `"build vs buy"`, `"when not to use"`, `"Fivetran"` y `"Airbyte"`, más lectura directa de toda página candidata de "when to use" / "why X" / overview en cada árbol de docs. **Todo eje citable en esta sección lo escribe alguien que vende una de las tres opciones.** Esto es el hallazgo, no una omisión: la skill debe decirlo así.
- **No verificable contra fuente primaria:** cualquier eje del tipo "usá una librería si tenés entre N y M fuentes" o "escribí a mano si el equipo tiene X seniority". No aparece en ninguna doc oficial. Si la skill quiere dar un umbral, tiene que presentarlo como criterio propio, no como consenso documentado.
- **No verificable contra fuente primaria:** la posición de dlt frente a los servicios gestionados, más allá de la frase del README (ver arriba).
- **No verificable contra fuente primaria:** el rate card por millón de MAR de Fivetran por plan. La doc describe el *modelo* (curva decreciente, `usage × spend rate`, cargo base de $5 en el tramo 1 MAR–1M MAR) pero no publica una tabla de tarifa por tier.
- **No verificable contra fuente primaria desde el sitio de docs:** la matriz de features de Airbyte por plan (qué le falta a Core frente a Cloud). Las páginas se gatean con un flag `products:` en el frontmatter y la comparación vive en la página comercial, no en las docs.
- **Claim sin respaldo, no citar como dato:** el *"about 70% less code"* del README del Meltano SDK — atribuido solo a *"developers tell us"*, sin metodología ni muestra.
- **Cifras indicativas, no contractuales:** el consumo de data workers de Airbyte por tipo de sync (Database ~0.5, API ~0.2) — la propia página dice *"These values are not contractual and may change"*.

**Acción:** en el bloque de decisión de `skills/python-data-engineering/references/production-patterns.md` (§A y §G), redactar los ejes como preguntas verificables y **atribuir el sesgo cuando corresponda**. Fraseo propuesto: *"Three options, and the axis that actually decides is narrower than 'build vs buy': does a first-party-maintained connector exist for this exact source? Two vendors publish the same rule independently — Databricks ('start with the most managed layer; if it doesn't support your data source, drop down to the next layer') and Azure Data Explorer ('check the connectors overview to see if there's a dedicated connector... If not, write custom code'). Note who is talking: every axis available on this question is published by someone selling one of the three options, and both managed vendors assert hand-written pipelines are 'brittle and costly' without substantiating it. What is substantiated: Airbyte's own enumeration of the seven formulaic problems an API connector solves (auth, the four pagination strategies, backoff, schema description, format decoding, cursor-based incremental) is the honest case for the middle option — it is the table of contents of [external-api-integration.md](external-api-integration.md). And buying is narrower than it sounds: all three vendors run a three-tier catalogue — we maintain it / the community maintains it / you maintain it — and only the first tier is what 'buy' means. Airbyte documents that it archives low-use connectors; Fivetran documents a shared-responsibility model where 'you own the connector code... and fixes when the source changes'. Cost shape differs by option, and that is the second real axis: a managed connector service bills change volume (Fivetran's MAR counts inserts and updates, excludes unchanged rows and the initial sync — so a pipeline that rewrites history every run is the pathological case), a managed runtime bills compute hours, and a hand-written extractor bills your engineering time on the day the source changes."*

---

## G. ¿Esto cambia algún judgment call que la suite ya enseña, y quién es el dueño natural del seam?

### Sí, cambia tres — y ninguno es "usá dlt"

1. **`production-patterns.md` enseña que el estado tiene que sobrevivir al run, pero no enuncia la propiedad más fina que hace que eso sirva:** que el watermark no debe avanzar sobre filas que no se commitearon. dlt la enuncia textualmente (§B) y es una invariante que aplica igual si construís la tabla de control a mano. Ese es contenido nuevo, verificado, y **útil incluso si nunca se adopta dlt**.
2. **`production-patterns.md` línea 43 presenta el boundary handling (`>` vs `>=`) como un trade-off a elegir a conciencia, y no dice qué elige nadie.** Ahora hay un tercer punto de datos primario, junto a Azure Data Factory (exclusivo) y Airbyte (inclusivo) que ya están en investigaciones previas del repo: dlt usa rango semiabierto por defecto (`range_start="closed"`, `range_end="open"`) y **acopla el default inclusivo a una deduplicación automática** por content hash o `primary_key`, y desactiva la dedup cuando pasás `range_start="open"`. Eso convierte el trade-off de la skill en una regla más precisa: el boundary inclusivo no es aceptable *solo* si aceptás duplicados — es aceptable si tenés dedup, y la elección del boundary y la del mecanismo de dedup son una sola decisión, no dos.
3. **`quality-data-engineering` no reconoce el punto de enforcement de la ingesta.** Hoy la skill enseña dos lugares donde un contrato se hace cumplir: el schema registry (Confluent, `409 Conflict`) y el CI del productor (Maven plugin, Data Contract CLI). Falta el tercero: la librería de ingesta, que aplica la misma decisión de cuatro vías (fail/quarantine/drop/repair) por entidad de esquema. Es un complemento, no un reemplazo — dispara después de que el productor ya mandó el cambio — y eso hay que decirlo así.

**Un cuarto hallazgo, defensivo:** dlt publica su propio framework de **"The five pillars of data quality"** (Structural Integrity, Semantic Validity, Uniqueness & Relations, Privacy & Governance, Operational Health), en `docs/website/docs/general-usage/data-quality-lifecycle.md`, en una página cuyo primer párrafo dice *"The data quality lifecycle has rarely been achievable in a single tool due to the runtime constraints of traditional ETL vendors"* y cuya tabla marca varias filas como disponibles solo en el producto pago. `skills/quality-data-engineering/SKILL.md` ya tiene un "common mistake" para exactamente este patrón — *"Citing 'the 5 pillars of data observability' as a neutral standard | It's Monte Carlo's own marketing framework"*. Este es un segundo framework de cinco pilares, de otro vendor, sobre un tema adyacente. Vale extender ese mistake para que cubra la clase, no solo el caso de Monte Carlo.

### El dueño del seam: hipótesis **parcialmente refutada**

La hipótesis del encargo era `external-api-integration.md`, "porque es donde alguien aterriza justo cuando va a escribir el extractor". Es cierto que ahí aterriza — la fila de la Quick Reference de `skills/python-data-engineering/SKILL.md` que dice *"Calling an external API for ingestion (auth, pagination, rate limits)"* apunta ahí. Pero como **dueño del contenido** es el archivo equivocado, por dos razones que se leen directo del repo:

1. **Está scopeado a un solo tipo de fuente.** Su primera línea es *"APIs are the most commonly underestimated ingestion source"*. La decisión de build-vs-buy cubre APIs, bases de datos y almacenamiento de objetos por igual — y de hecho las dos capacidades donde la librería gana más (`sql_database` sobre 30+ motores vía SQLAlchemy, `filesystem` sobre S3/GCS/Azure) caen fuera de ese archivo.
2. **Las dos cosas que la librería te saca de encima ya viven en `production-patterns.md`, no en `external-api-integration.md`.** Ese archivo es el dueño de "Idempotency and safe reruns" (sección propia) y de "Incremental extraction: tracking what's new" — normalización aparte, esas dos son literalmente lo que la opción 2 asume como propio. Poner la decisión en otro archivo la separaría de las dos secciones contra las que se compara.

Además, el repo ya tiene un precedente exacto de cómo repartir esto: el watermark vive en `production-patterns.md`, y `external-api-integration.md` solo agrega el refinamiento específico de APIs (el lookback margin) con un cross-link de una línea — *"[production-patterns.md](production-patterns.md) already covers the watermark mechanism generally"*. La decisión de categoría debería seguir el mismo reparto.

**Veredicto:** el dueño del seam es **`skills/python-data-engineering/references/production-patterns.md`**; `external-api-integration.md` recibe un cross-link de una línea en el punto donde el lector aterriza. La hipótesis acertó el punto de entrada y erró el dueño.

**Acción:** el bloque de decisión (un solo bloque, prosa, sin ejemplos de código de dlt) se agrega a `skills/python-data-engineering/references/production-patterns.md` inmediatamente antes de la sección "Idempotency and safe reruns", porque es lo que se decide *antes* de escribir el upsert y el watermark. En `skills/python-data-engineering/references/external-api-integration.md`, agregar una sola línea al final del párrafo de apertura: *"Before writing any of this: the choice of writing the extractor at all is itself a decision — see [production-patterns.md](production-patterns.md) for when a declarative EL library or a managed connector service is the right call instead."* No duplicar contenido entre los dos archivos.

---

## Recomendación de alcance: qué es lo MÍNIMO que entra

La restricción declarada en el encargo se respeta sin objeción: **una librería no justifica una skill propia** porque la suite se organiza por dominio, no por librería. Y este repo viene de cortar over-engineering a propósito. Así que la propuesta es deliberadamente chica.

**Lo mínimo que entra (4 ediciones, ningún archivo nuevo, cero skills nuevas):**

1. **Un bloque de prosa de ~150 palabras en `skills/python-data-engineering/references/production-patterns.md`**, antes de "Idempotency and safe reruns", que enuncia los tres puntos de la categoría y los **ejes** de la decisión (no un ganador): cuántas fuentes vas a mantener, si tus fuentes tienen conector prehecho, si la normalización de datos anidados es un problema real en tu caso o no, quién opera lo que compres, y cómo se factura (horas de runtime vs. filas modificadas vs. tu propio tiempo). dlt se menciona **como el exponente en Python de la opción 2, en una cláusula**, junto a Singer/Meltano que el archivo ya nombra. No hay tour de features, no hay ejemplo de código.
2. **Un cuarto bullet en la lista de patrones de persistencia del watermark** de ese mismo archivo (§B), con la invariante "el watermark no avanza sobre filas que no se commitearon" — que es el hallazgo más valioso de toda esta investigación y es **independiente de dlt**.
3. **Dos filas nuevas en la tabla "Common mistakes"** de ese archivo: el rename de dataset/pipeline que resetea el estado en silencio (§B), y el `merge` sin clave que degrada a `append` en silencio (§C).
4. **Un párrafo al final de "Enforcing contracts in CI/CD"** en `skills/quality-data-engineering/references/data-contracts-and-schema-compatibility.md` nombrando la ingesta como tercer punto de enforcement, con el default `evolve` y el relajamiento en tablas nuevas como los dos caveats (§C).

Más dos ediciones de una línea que son cross-links, no contenido: la fila de Quick Reference en `skills/python-data-engineering/SKILL.md` (§A) y el cross-link en `external-api-integration.md` (§G).

**Lo que explícitamente NO entra, y por qué:**

- **Ninguna skill nueva, ningún archivo de referencia nuevo.** La decisión es un judgment call de dos párrafos, no un dominio.
- **Ningún ejemplo de código de dlt.** El contrato de la suite es *"which tool or pattern to reach for and why, not language syntax"*. Un `@dlt.resource` en la skill sería exactamente el fallo que este encargo pedía evitar.
- **Ninguna comparación tabla-por-tabla de dlt vs. Airbyte vs. Fivetran.** Envejece en meses, y buena parte de los ejes solo existen en material de vendor (§F). Los ejes que sí se documentan — cómo se factura, qué operás vos, qué pasa cuando no hay conector — se enuncian como preguntas a responder, no como un veredicto.
- **Ningún número de precio.** `$1,190/mes` y los tramos de crédito son correctos al 2026-08-20 y estarán mal el año que viene. Va la *forma* del costo (horas de runtime vs. filas modificadas vs. tu tiempo), no la cifra.
- **La ventana de tabla vacía del full load** (§C, las tres estrategias de `replace` de dlt). Es un hallazgo real y citable, pero pertenece a `sql-data-engineering/references/engineering-query-patterns.md` y a un tema distinto del build-vs-buy. Queda registrado aquí como candidato independiente, no como parte de este alcance.
- **Nada sobre el AI Harness / dltHub Context.** Es producto pago con una licencia que restringe el runtime de destino; no es una decisión de arquitectura de datos.

---

## Resumen de acciones

| § | Hallazgo | Archivo dueño | Edición |
|---|---|---|---|
| A | dlt asume normalización + inferencia/migración de esquema + estado incremental + merge por clave + destinos; no asume source logic, reintentos de pipeline, orquestación, la T, ni la política | `python-data-engineering/references/production-patterns.md` + `SKILL.md` | Bloque de decisión nuevo + 1 fila de Quick Reference |
| B | Refuerza la skill. Estado en `_dlt_pipeline_state` en el destino, commiteado atómicamente con los datos; el cursor no avanza sobre datos no cargados; se pierde si cambia pipeline name / destino / dataset | `python-data-engineering/references/production-patterns.md` | 4º bullet de persistencia + 1 fila de Common mistakes |
| C | Cuatro estrategias de merge (`upsert` solo en 7 destinos); `merge` sin clave degrada a `append` en silencio; evolución por defecto aditiva y no destructiva (`evolve`), con `freeze`/`discard_row`/`discard_value` como opt-in | `python-data-engineering/.../production-patterns.md` + `quality-data-engineering/.../data-contracts-and-schema-compatibility.md` | 1 fila de Common mistakes + 1 párrafo sobre el enforcement en la ingesta |
| D | Es EL; la T de primera clase es paga; no trae orquestación ni reintentos por defecto; extract escribe todo a disco local; sin resume en storage efímero; no hay enunciado oficial de "cuándo NO usarlo" | `python-data-engineering/references/production-patterns.md` | Cierre del bloque de decisión |
| E | `dlt` = Apache-2.0 (ScaleVector GmbH); dltHub = comercial, EULA propietaria, facturado por horas de runtime; data quality, transformaciones, runtime gestionado, MS SQL Change Tracking e Iceberg/Delta están detrás del paywall | `python-data-engineering/references/production-patterns.md` | Una línea de licenciamiento, sin cifras |
| F | Hay ejes de primera fuente y son usables, pero **todos** los escribe alguien que vende una de las tres opciones. El eje mejor sostenido (Databricks + Azure Data Explorer, independientes) es binario: ¿existe un conector mantenido para esta fuente exacta? La enumeración de Airbyte de los 7 problemas formulaicos de un conector de API es el índice de `external-api-integration.md`. "Comprar" es más chico de lo que suena: los tres proveedores tienen catálogos de tres niveles y solo el primero trae mantenimiento | `python-data-engineering/references/production-patterns.md` | Los ejes como preguntas verificables, con el sesgo de la fuente atribuido |
| G | Hipótesis parcialmente refutada: `external-api-integration.md` es el punto de entrada, `production-patterns.md` es el dueño. Además: dlt publica su propio "five pillars of data quality" — misma clase de framework de vendor que el de Monte Carlo que la skill ya marca | `quality-data-engineering/SKILL.md` | Extender el common mistake de los "5 pilares" para cubrir la clase, no solo Monte Carlo |

---

## Claims a re-chequear si esto se lee meses después

**Versionado y sensible al tiempo (lo más volátil primero):**

1. **Precios.** dltHub *"From $1,190 / month"*, 500 créditos incluidos, 1 crédito ≈ 1 hora de runtime, overage $1.00→$0.80. Airbyte Cloud: $10/mes con 4 créditos, $2.50/crédito, $15 por millón de filas (APIs), $10/GB (bases y archivos). Fivetran: cargo base de $5 por conexión en el tramo 1 MAR–1M MAR; techos del plan Free (500K MAR, 3.500 MAR de activation, 5.000 model runs). Todas verificadas al 2026-08-20; las páginas de precios cambian sin bump de versión.
2. **El corte de los Function connectors de Fivetran** (*"users who signed up on or after July 22, 2025, no longer have access"*) y que el Connector SDK sea hoy el único camino custom para cuentas nuevas.
3. **"Airbyte no longer sells Self-Managed Enterprise"** — confirmar que sigue vigente antes de construir un argumento sobre eso.
4. **El subconjunto de destinos que soporta la estrategia `upsert` de dlt** (hoy: athena, bigquery, databricks, mssql, postgres, snowflake, filesystem con delta/iceberg). Es la clase de lista que crece release a release.
5. **Qué está detrás del paywall de dltHub.** La división OSS/comercial de dlt es reciente y activa; que MS SQL Change Tracking e Iceberg/Delta sean premium hoy no garantiza que lo sigan siendo, ni al revés.
6. **La versión del spec de Singer (0.3.0)** y sus conteos de commits — confirmar que no aterrizó una revisión después del 2025-08-08.
7. **Rangos de soporte de Airbyte self-managed** (Postgres 13+, testeado hasta 17; mínimos de 4 CPU / 8 GB, o 2 CPU / 8 GB en low-resource mode).

**Verificado contra código, no solo prosa (más estable, pero atado a 1.30.0):** los defaults de `Incremental` (`range_start="closed"`, `range_end="open"`, `on_cursor_value_missing="raise"`, `last_value_func=max`) en `dlt/extract/incremental/__init__.py`, y `restore_from_destination: bool = True` en `dlt/pipeline/configuration.py`.

**Lo que NO quedó verificado contra fuente primaria, y no se debe escribir en ninguna skill como si lo estuviera:**

- Un enunciado oficial de dlt del tipo "no uses dlt si…" — **no existe** en la doc al tag 1.30.0 (verificado por grep sobre los `.md` descargados). El más cercano es un "cuándo sí" en una página que vende el producto pago.
- Cualquier posicionamiento de dlt contra Airbyte o Fivetran — **cero menciones de "Fivetran" en todo el repo `dlt-hub/dlt`**, cero resultados para "build vs buy", y no hay página "why dlt" en el sitio de docs.
- Un umbral cuantitativo (cantidad de fuentes, tamaño de equipo) que decida entre las tres opciones.
- Una comparación neutral de las tres opciones escrita por alguien que no venda ninguna.
- El *"70% less code"* del Meltano SDK.
