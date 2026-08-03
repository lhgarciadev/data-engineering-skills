# Especificación de Diseño: Skill `quality-data-engineering`
## Sexta skill de dominio de la suite `data-engineering-skills`

**Fecha:** 2026-08-03
**Responsable:** Leonardo H. García Díaz
**Estado:** En diseño — investigación completa (cross-check de `wshobson/agents` + 6 investigaciones en paralelo contra fuentes primarias). Pendiente transición a `superpowers:writing-plans`.

---

## 1. Contexto y objetivo

Sexta de las skills de dominio en entregarse (tras `python-data-engineering`, `sql-data-engineering`, `spark-data-engineering`, `pipelines-architecture-data-engineering` y `project-structure-data-engineering`), y la 8va en el orden de enumeración de `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §4. Su alcance ya estaba anotado en esa tabla: *"Dimensiones de calidad de datos, frameworks de gobierno de datos (Great Expectations a nivel organizacional), monitoreo/alertas de DQ"*, con frontera explícita ya fijada contra `python-data-engineering` (*"Qué librería usar para validar un dataframe puntual (Pydantic vs Pandera) — eso ya está en `python-data-engineering`"*) y una frontera de entrada desde `modeling-data-engineering` (*"Validación de esquema en tiempo de ejecución — eso es `quality-data-engineering`"*).

**Insumo**: un borrador de contenido de Leonardo (formato entrevista técnica senior, de fundamentos a nivel senior), estructurado en 7 capas — dimensiones de calidad, validación en el pipeline, políticas ante fallo, contratos de datos, herramientas del ecosistema, observabilidad de datos, y calidad como cultura/sistema. El encuadre central del borrador ("un pipeline no se juzga por si corre, sino por si los datos que produce son confiables"; "la calidad de datos es la disciplina de hacer ruidosos los fallos silenciosos") se mantiene como hilo conductor del `SKILL.md`.

**Nota de anonimización**: el borrador original cita, por nombre, el rubro de una entrevista técnica real de una empresa específica como ejemplo de qué se espera de una respuesta senior. Siguiendo la práctica ya establecida en este repo (ver rondas anteriores de la suite), esa referencia se generaliza en todo artefacto de este proceso — spec, plan y contenido final — a "un rubro de entrevista técnica senior"; ningún nombre de empresa real se registra en ningún documento de la suite.

**Verificación**: cross-check de `wshobson/agents`' `data-quality-frameworks` (secundaria, MIT — ver `docs/superpowers/research/2026-08-03-quality-wshobson-agents-review.md`) seguido de 6 investigaciones en paralelo contra fuentes primarias oficiales, una por bloque temático del borrador. Registro completo:
- `docs/superpowers/research/2026-08-03-quality-dimensions-and-validation-verification.md`
- `docs/superpowers/research/2026-08-03-quality-failure-policies-verification.md`
- `docs/superpowers/research/2026-08-03-data-contracts-and-schema-compatibility-verification.md`
- `docs/superpowers/research/2026-08-03-quality-tooling-landscape-verification.md`
- `docs/superpowers/research/2026-08-03-data-observability-verification.md`
- `docs/superpowers/research/2026-08-03-quality-culture-and-cicd-verification.md`

## 2. Alcance y fronteras

Reafirma la frontera ya fijada en la spec de la suite (§4): dimensiones de calidad, frameworks de validación a nivel organizacional, contratos de datos, políticas de respuesta ante fallos, observabilidad de datos (distinta de testing), y calidad como cultura/gobierno. No cubre qué librería usar para validar un dataframe puntual (Pydantic vs. Pandera — ya en `python-data-engineering`), ni implementación/hosting de servicios.

### 2.1 Resolución de scope forks y fronteras con skills existentes

El borrador toca, directa o indirectamente, territorio ya cubierto por 4 skills shippeadas. Cada solapamiento se resuelve explícitamente aquí, con cross-link en vez de duplicación:

| Tema del borrador | Ya cubierto en | Resolución |
|---|---|---|
| Pydantic vs. Pandera vs. Great Expectations — cuál usar para validar un dataframe/payload puntual | `python-data-engineering/references/data-validation.md` | No se duplica esa tabla de decisión. Esta skill cross-linkea hacia allá y profundiza el ángulo que esa comparación no cubre: la **mecánica operativa** de GX a nivel organizacional (Expectation Suites, Checkpoints, Actions — ver `failure-response-policies.md`) y el patrón fail-fast de Pydantic en el borde de ingesta desde el ángulo de "por qué fallar rápido", no "qué librería elegir". |
| Los 4 tests genéricos de dbt (`unique`/`not_null`/`accepted_values`/`relationships`) como "data-quality checks expresados como aserciones SQL" | `sql-data-engineering/references/query-optimization-and-production.md` (línea ~74) | No se reabre esa síntesis. Esta skill (`quality-dimensions-and-validation.md`) confirma el detalle de cada test con cita exacta y agrega lo que esa mención de pasada no cubre: severidad/umbrales/`store_failures` (`failure-response-policies.md`). |
| Medallion (bronze/silver/gold) vs. staging/intermediate/marts de dbt | `pipelines-architecture-data-engineering/references/dbt-project-architecture.md` | No se reabre esa comparación. Esta skill se limita al ángulo nuevo que aporta: dónde se valida dentro de esa progresión (raw permisivo → validación estricta en la transición a curada), citando esa referencia para la comparación de capas. |
| `dbt-expectations` sin mantenimiento activo | `pipelines-architecture-data-engineering/references/dbt-project-architecture.md` (línea ~56) | La nota ya existente se **actualiza** con evidencia más fresca y contundente encontrada en esta ronda (README declara "no longer actively supported"; último release sep-2024, último commit dic-2024, >19 meses de inactividad — confirmado por `gh api` contra el repo real, no solo el texto del aviso). Ver §4.3. Esta skill cross-linkea hacia esa nota en vez de duplicarla. |
| Lineage como argumento de selección de orquestador (Dagster asset-centric) | `pipelines-architecture-data-engineering/references/orchestrator-selection-and-topology.md` (línea ~9) | No se duplica esa comparación Airflow-vs-Dagster. Esta skill (`data-observability-and-lineage.md`) cubre lineage desde el ángulo de calidad/observabilidad (impact analysis dentro de un proyecto dbt, OpenLineage como estándar de interoperabilidad) — capas complementarias: Dagster = lineage de orquestación; dbt = lineage de transformación declarada. |
| "Servir el último snapshot bueno" ante un fallo | `pipelines-architecture-data-engineering/references/serving-pipeline-output.md` | Ver fork dedicado abajo — el fallback arquitectónico se queda ahí; esta skill cubre el gate de calidad que decide *no promover*. |
| Contrato/versionado de esquema de una API expuesta por un pipeline (forward-pointer explícito de `serving-pipeline-output.md`: *"Contract and schema versioning for that API belongs in `quality-data-engineering` once that skill exists"*) | — (forward-pointer sin contenido hasta ahora) | **Se cierra aquí, a nivel de principio, no de implementación.** `data-contracts-and-schema-compatibility.md` cubre el concepto general de contrato de datos versionado + compatibilidad (Data Contract Spec, Schema Registry, evolución de esquema) — el mismo principio aplica conceptualmente a un contrato de API. No se agrega contenido específico de OpenAPI (seguiría siendo implementación de API, fuera de alcance de la suite por decisión ya tomada en `pipelines-architecture`, spec §2.1); el lector de `serving-pipeline-output.md` tiene ahora dónde aterrizar el concepto de "contrato versionado" que esa skill ya menciona de pasada. |
| Captura de cambios en el origen (CDC — Debezium, WAL/binlog, Kafka Connect) | Fuera de alcance de toda la suite hoy; asignado a `streaming-data-engineering` (futura), spec de la suite §7.8 | Sin cambios. El bloque de Confluent Schema Registry de esta skill cubre solo el ángulo de **contrato/compatibilidad de esquema** (registro, modos, rechazo), no captura/producción de eventos — cero solapamiento de contenido con lo que `streaming-data-engineering` cubrirá. |
| Late-arriving dimensions / integridad relacional a nivel de modelo dimensional | `modeling-data-engineering` (futura) | Forward-pointer sin contenido hoy — se resuelve cuando esa skill se escriba. |
| Hosting/infraestructura de un Schema Registry, una plataforma de observabilidad self-hosted, o el Soda Agent | `iac-cloud-data-engineering` (futura) | Forward-pointer sin contenido hoy. |

#### Fork: "Circuit breaker de datos" — combina dos patrones de fuentes distintas, se separa en dos mitades

El borrador (Capa 6) describe un "circuit breaker de datos" con dos ingredientes: (a) no promover datos malos a la capa de consumo, y (b) servir el último snapshot bueno en su lugar. La investigación (`2026-08-03-quality-culture-and-cicd-verification.md` §3) encontró que estos dos ingredientes vienen de **fuentes distintas** y no deben presentarse como una sola cita:

| Ingrediente | Fuente real | Destino |
|---|---|---|
| El gate de calidad: bloquear/no promover cuando un chequeo crítico falla | Patrón real y con nombre propio en ingeniería de datos desde 2018 (Uttamchandani/Strata Data Conference NY, Andrew Jones, ingeniería de Ibotta) — préstamo consciente del patrón de arquitectura de software original (Fowler/Nygard, *Release It!*, sobre llamadas remotas). Las fuentes de datos describen **bloqueo/vacío** ("data will be missing in the reports", "halt the process"), no fallback automático. | Esta skill, `quality-culture-and-governance.md` — con atribución dual (origen en software + adopción con nombre propio en datos) y la corrección explícita del matiz "bloqueo, no snapshot viejo". |
| El fallback: seguir sirviendo el último dato bueno mientras el pipeline está roto | Ya documentado en `pipelines-architecture-data-engineering/references/serving-pipeline-output.md` ("if the pipeline fails, the serving layer keeps answering from the last good snapshot instead of going down with it") — pero como consecuencia de la **arquitectura desacoplada** (batch pipeline separado del serving store) ante un fallo de pipeline, no como una decisión de calidad. | No se duplica. Cross-link explícito: esta skill cubre *cuándo y por qué* se dispara el bloqueo (el chequeo, el umbral, quién decide); `serving-pipeline-output.md` sigue siendo dueño del *cómo* arquitectónico de que el consumidor no se caiga. |

Si el contenido final combina ambos (bloquear + fallback automático), debe decir explícitamente que es una combinación de dos patrones documentados por separado, no una única fuente que ya los una.

#### Fork: terminología SLA vs. SLO

Dehghani (Data Mesh, fuente primaria de "data as a product") usa **SLO**, no SLA, con "timeliness, error rates" como ejemplos — ni "SLA", ni "freshness", ni "completeness", ni "availability" aparecen en su artículo original (verificado por búsqueda textual completa). El borrador usa "SLA" con la tríada frescura/completitud/disponibilidad. Resolución: al citar a Dehghani directamente, usar **SLO**, con sus palabras exactas. Al hablar de la tríada frescura/completitud/disponibilidad, presentarla como síntesis pedagógica razonable (frescura y completitud sí están bien respaldadas — Monte Carlo las nombra como dimensiones propias, DataHub liga "operational SLA-s" a sus assertions de Freshness —, disponibilidad es la más débil de las tres en la evidencia recolectada), **no** como si una única fuente ya las agrupara así. El mecanismo técnico concreto de SLA/SLO de un dataset se ancla al bloque `servicelevels` de la Data Contract Specification (`data-contracts-and-schema-compatibility.md`, con sus 7 sub-objetos reales, incluidos `freshness` y `availability` con esos nombres exactos) — `quality-culture-and-governance.md` cross-linkea hacia allá para el mecanismo, en vez de re-derivarlo.

### 2.2 Alcance de versión / herramientas citadas

Sin pin de versión único (a diferencia de Airflow en `pipelines-architecture`), pero cada herramienta se cita contra su estado verificado al 2026-08-03: Great Expectations **1.19.1** (API post-migración V0→V1, agosto 2024 — Checkpoints vía `gx.Checkpoint(...)` + `context.checkpoints.add()`, nunca la sintaxis dict/YAML pre-2024), Apache Avro **1.12.0** (especificación de schema resolution), Soda **4.19.0** (Data Contracts + Data Observability como pilares de producto vigente — SodaCL es ahora documentación "v3"/legacy), `dbt-expectations` **0.10.4** (último release, sep-2024 — sin mantenimiento activo). dbt y Confluent Schema Registry se citan contra su documentación vigente sin pin de versión específico (mecanismos estables: `severity`/`error_if`/`warn_if`/`store_failures`, los 7 modos de compatibilidad).

## 3. Fuentes

- Borrador original de Leonardo (7 capas, formato entrevista técnica) — anonimizado (ver §1), traducido y corregido, no adoptado verbatim (contenido final en inglés, convención ya fijada en la spec de la suite §3).
- `wshobson/agents` (MIT), `plugins/data-engineering/skills/data-quality-frameworks/` — revisado con atribución, no adoptado literal. Dos errores factuales encontrados y verificados (API de Great Expectations obsoleta/inconsistente consigo misma; esquema raíz de contrato de datos inventado, mezcla `apiVersion`/`kind` de Kubernetes con `schema`/`properties` de JSON Schema, ninguno real en la Data Contract Specification). Ver `docs/superpowers/research/2026-08-03-quality-wshobson-agents-review.md`.
- Verificación directa contra documentación oficial: `docs.getdbt.com`, `docs.greatexpectations.io` + código fuente real (`github.com/great-expectations/great_expectations`, tag `1.19.1`), `docs.pydantic.dev`/`pydantic.dev`, `docs.databricks.com` + blog oficial de Delta Lake, ISO/IEC 25012 (vía portales especializados, texto oficial de pago) y el whitepaper de DAMA UK (2013, fetch directo del PDF), `docs.aws.amazon.com` (Glue Data Quality), `github.com/datacontract/datacontract-specification` (README + JSON Schema + ejemplo real) y `datacontract/datacontract-cli`/`datacontract-action`, `docs.confluent.io` (Schema Registry), `avro.apache.org` (spec 1.12.0), `docs.soda.io` + `github.com/sodadata/soda-core`, `montecarlo.ai`/`docs.getmontecarlo.com` (marcado explícitamente como vendor en todo momento), `openlineage.io` (estándar LF AI & Data), `sre.google` (SRE Book/Workbook, y el reporte "Incident Metrics in SRE"), `pandera.readthedocs.io`, `martinfowler.com` (artículo original de Dehghani sobre Data Mesh, y el bliki de CircuitBreaker), y una investigación de corroboración (charla de Strata 2018, blogs de Andrew Jones e ingeniería de Ibotta) para el uso real de "circuit breaker" en datos.

## 4. Estructura de archivos

```
skills/quality-data-engineering/
  SKILL.md
  references/
    quality-dimensions-and-validation.md
    failure-response-policies.md
    data-contracts-and-schema-compatibility.md
    data-observability-and-lineage.md
    quality-culture-and-governance.md
```

Mismo formato que el resto de la suite: overview, when to use, tabla de quick reference y tabla de common mistakes en `SKILL.md`; un archivo de reference por tema pesado. Contenido en inglés, ejemplos de código en YAML/SQL/Python según la herramienta citada (dbt en YAML/SQL, Great Expectations y Pandera en Python).

### 4.1 `quality-dimensions-and-validation.md` — borrador Capas 0-1

Dimensiones de calidad, tipos de chequeo, validación en el borde de ingesta, schema-on-read/write, medallion.

**Contenido y correcciones a incorporar** (`2026-08-03-quality-dimensions-and-validation-verification.md`):
- **No presentar las 7 dimensiones como si vinieran de un único estándar universal.** No existe: ISO/IEC 25012 no nombra "unicidad" ni "integridad referencial" como características propias; el whitepaper de DAMA UK (2013) sí define 6 de las 7 con cita textual, pero él mismo declara por escrito *"even amongst data quality professionals the key data quality dimensions are not universally agreed"* — usar esa cita como la nota de honestidad epistémica del propio skill. Las 6 de DAMA UK, con sus definiciones citadas: Completeness, Uniqueness, Timeliness, Validity, Accuracy, Consistency. **Integridad referencial** se presenta como séptima categoría añadida por utilidad de ingeniería, anclada al test `relationships` de dbt (que sí la llama "referential integrity" textualmente), no como dimensión ISO/DAMA.
- Tipos de chequeo con los 4 tests genéricos de dbt (`unique`, `not_null`, `accepted_values`, `relationships`) — sintaxis y semántica citadas exactas. Aclarar que chequeos de volumen (`equal_rowcount`, `fewer_rows_than`) requieren el paquete `dbt-utils`, no vienen en dbt-core. El orden "de más barato a más caro" se presenta como heurística pedagógica de este skill, no como clasificación oficial de dbt (no existe tal página en `docs.getdbt.com`).
- Validación fail-fast con Pydantic: `ValidationError` recolecta **todos** los errores del payload y lanza una sola excepción — no para en el primer campo. `FailFast` (Pydantic v2.8+) es una anotación aparte, específica de listas/secuencias, no el comportamiento general. Cross-link a `python-data-engineering/references/data-validation.md`, sin reabrir esa comparación.
- Schema-on-write confirmado verbatim contra Databricks (*"The data warehouse itself is schema-on-write and atomic"*); schema-on-read es término estándar de industria pero sin cita verbatim confirmada en esta pasada — usarlo igual, sin atribuirlo como frase textual de Databricks.
- Medallion: raw/bronze con mínima validación → "Schema enforcement" y "Data quality checks and enforcement" explícitos en la transición a silver — confirmado con fuerza contra la doc oficial de medallion architecture y el blog de Delta Lake sobre schema enforcement. Cross-link a `pipelines-architecture-data-engineering/references/dbt-project-architecture.md` para la comparación medallion-vs-dbt-layering ya resuelta ahí.

### 4.2 `failure-response-policies.md` — borrador Capa 2

Espectro fail/quarantine/drop/repair, umbrales tolerables, coste asimétrico del error.

**Contenido y correcciones a incorporar** (`2026-08-03-quality-failure-policies-verification.md`):
- Umbrales — mecanismo real de dbt: `severity: error|warn` (default `error`), `error_if`/`warn_if` (default `!=0`), evaluados contra `fail_calc` (**default `count(*)`** — conteo absoluto de filas, no porcentaje). Corrección al ejemplo del borrador ("si más del 5% de las filas fallan..."): mostrarlo con un `fail_calc` custom porcentual explícito, o usar un umbral en conteo absoluto fiel al mecanismo default — no presentar `error_if: ">5"` como si automáticamente significara 5%.
- Cuarentena — mecanismo real de dbt: `store_failures`/`store_failures_as` (`ephemeral`/`table`/`view`), guarda las filas que fallaron en una tabla/vista en `{schema}_dbt_test__audit`. Matiz: es evidencia de fallas, no necesariamente saca las filas malas del modelo productivo salvo que el modelo mismo las filtre.
- Cuarentena en vendors mayores — confirmado con código real en dos: **AWS Glue Data Quality** (cita oficial *"quarantine and fix them"*; implementación real vía columna `DataQualityEvaluationResult` + filtrado manual del DataFrame, no una tabla de cuarentena automática) y **Databricks Lakeflow/DLT** (sección oficial "Quarantine invalid records" — columna booleana `is_quarantined` + tabla temporal particionada por esa columna + vistas `valid_trips_data`/`invalid_trips_data`, código Python y SQL citado verbatim). Mismo esqueleto estructural en los tres (dbt/AWS/Databricks): columna-flag + separación explícita, no una feature de un clic.
- Drop-con-alerta — Great Expectations 1.x, 7 Actions reales y vigentes (verificadas contra el código fuente en el tag `1.19.1`, no solo la doc): `UpdateDataDocsAction`, `SlackNotificationAction`, `EmailAction`, `PagerdutyAlertAction`, `MicrosoftTeamsNotificationAction`, `OpsgenieAlertAction`, `SNSNotificationAction`, `APINotificationAction` — todas (salvo las dos primeras) condicionables vía `notify_on="failure"`. `StoreValidationResultAction` (aparecía en el research de `wshobson/agents`) está confirmada como **eliminada** de la API actual — cero coincidencias en el repo actual, no solo desactualizada.
- Coste asimétrico del error — presentar explícitamente como aplicación de un principio general de teoría de decisión/estadística (Neyman-Pearson, clasificación cost-sensitive), no como framework nativo de data engineering — no se encontró fuente primaria de ingeniería de datos que lo formalice así.

### 4.3 `data-contracts-and-schema-compatibility.md` — borrador Capa 3

Qué es un contrato de datos, la Data Contract Specification, compatibilidad de esquemas (Confluent Schema Registry, Avro), CI/CD del productor.

**Contenido y correcciones a incorporar** (`2026-08-03-data-contracts-and-schema-compatibility-verification.md`, más `2026-08-03-quality-wshobson-agents-review.md` §2.2 para los root fields):
- Root fields reales de la Data Contract Specification: `dataContractSpecification`, `id`, `info`, `servers`, `terms`, `models`, `definitions`, `servicelevels` — **no** `apiVersion`/`kind` (no existen en la spec; son convención Kubernetes que `wshobson/agents` usa por error).
- **Separar esquema/restricciones estructurales de "calidad"**: `required`/`unique`/`primaryKey`/`type`/`references` son atributos de primera clase del Field Object (`models.<nombre>.fields.<campo>`), evaluados estructuralmente — no viven dentro del bloque `quality`. El bloque `quality` es un objeto aparte con 4 variantes: `text` (lenguaje natural), `sql` (query custom contra un umbral), `library`/métricas agnósticas alineadas a ODCS 3.1 (`nullValues`, `missingValues`, `invalidValues`, `duplicateValues`, `rowCount`), y `custom` con `engine: soda` o `engine: great-expectations` (ejemplos YAML reales citados en el research). El borrador mezcla ambas capas bajo "garantías de calidad" — corregir.
- `servicelevels` (clave exacta, todo minúscula) — 7 sub-objetos reales con campos concretos: `availability` (`percentage`), `retention` (`period`), `latency` (`threshold`, `sourceTimestampField`, `processedTimestampField`), `freshness` (`threshold`, `timestampField`), `frequency` (`type`, `interval`/`cron`), `support`, `backup` (`recoveryTime`/`recoveryPoint`). Usar `freshness.threshold` y `availability.percentage` como ejemplos concretos citables, no "SLA de frescura y disponibilidad" en abstracto.
- Confluent Schema Registry — los 7 modos exactos (`BACKWARD`, `BACKWARD_TRANSITIVE`, `FORWARD`, `FORWARD_TRANSITIVE`, `FULL`, `FULL_TRANSITIVE`, `NONE`) con la tabla de qué cambio permite cada uno (agregar/quitar campo opcional vs. requerido, ensanchar/angostar tipo — nota: ensanchar/angostar tipo **no** es compatible en `FULL`, solo en un lado). El registro **rechaza** (HTTP `409 Conflict — Incompatible schema` en `POST /subjects/.../versions`), no es una advertencia; el auto-registro por defecto del serializer (`auto.register.schemas`) es lo que hace que esto bloquee al productor en la práctica.
- Evolución de esquema Avro (spec 1.12.0, sección "Schema Resolution", citas verbatim) — más precisa que "agregar sí, quitar no": agregar un campo es seguro **si y solo si tiene `default`**; quitar un campo **siempre** es seguro (el valor simplemente se ignora); cambiar tipo solo dentro de una lista cerrada de promociones (`int`→`long`/`float`/`double`, `long`→`float`/`double`, `float`→`double`, `string`↔`bytes`); renombrar requiere `aliases` explícitos o se comporta como quitar+agregar.
- CI/CD del productor — dos implementaciones de referencia reales y de primera parte, no un estándar único: **Confluent Schema Registry Maven Plugin** (goal `test-compatibility`, más `test-local-compatibility` desde Confluent Platform 7.2.0) y **Data Contract CLI + GitHub Action oficial `datacontract-action`** (reporte JUnit XML, falla el build si el contrato es incompatible). La propia Data Contract Specification no define sus propios modos de compatibilidad — los hereda de la tecnología de esquema subyacente o de la herramienta de CI elegida.
- Cierre del forward-pointer de `serving-pipeline-output.md` sobre contrato/versionado de esquema de API — ver §2.1.

### 4.4 `data-observability-and-lineage.md` — borrador Capa 5 (+ el ángulo de observabilidad de la Capa 4)

Testing vs. observabilidad, los 5 pilares, OpenLineage, lineage en dbt, MTTD/MTTR, detección de anomalías, panorama Soda/Monte Carlo/Anomalo.

**Contenido y correcciones a incorporar** (`2026-08-03-data-observability-verification.md`, `2026-08-03-quality-tooling-landscape-verification.md` §3-5):
- Los 5 pilares (Freshness, Distribution, Volume, Schema, Lineage) — términos exactos confirmados contra el post original de Monte Carlo (Barr Moses, 2020, ahora en `montecarlo.ai`). **Marcar explícitamente como marco de vendor/marketing**, no estándar neutral — Databricks reproduce el mismo marco en su glosario sin atribuir a Monte Carlo, señal de que se volvió vocabulario de industria de origen no neutral.
- **OpenLineage** (`openlineage.io`, gobernado por LF AI & Data — vendor-neutral por diseño, confirmado por cita del anuncio de incorporación a la fundación) como base neutral complementaria para hablar de lineage: modelo Job/Run/Dataset, eventos `RunEvent`/`DatasetEvent`/`JobEvent`.
- Lineage en dbt — confirmado: DAG real desde `ref()`/`source()`, visible en `dbt docs` (Core, local, sin depender de dbt Cloud) y en "Catalog" (dbt Cloud, vía Discovery API). Presentar como lineage de **transformación declarada** (impact analysis dentro de un proyecto dbt), complementario — no duplicado — del lineage de **orquestación** que `orchestrator-selection-and-topology.md` ya atribuye a Dagster.
- MTTD/MTTR — origen confirmado en SRE (cita textual del Google SRE Book: *"Reliability is a function of mean time to failure (MTTF) and mean time to repair (MTTR)"*), no nacieron en el mundo de datos. Su aplicación formal a "calidad de datos" específicamente solo se encontró en fuentes de vendor — decirlo explícitamente. Matiz adicional (no está en el borrador): el propio Google publicó un reporte ("Incident Metrics in SRE") cuestionando la validez estadística de MTTR para *trend analysis* — vale la pena incluirlo como matiz senior.
- Detección de anomalías — descripción conceptual (aprender patrones vs. umbral fijo) respaldada por documentación técnica real de Monte Carlo (ensamble de modelos, ventana móvil de reentrenamiento, ajuste de sensibilidad) — vendor, marcado como tal; no sobre-especificar el algoritmo exacto.
- Panorama de vendors — **Soda se reposicionó**: SodaCL (YAML) es ahora documentación "v3"/legacy; el producto vigente (Soda 4.0, `soda-core` v4.19.0, release activo la semana previa a esta investigación) gira en torno a "Data Contracts" (lenguaje de checks principal hoy) **y** "Data Observability" como pilares separados del mismo producto — no encaja en la categoría "solo observabilidad" que le da el borrador. Monte Carlo (observabilidad pura, vendor) y Anomalo (checks + ML no supervisado, UI no-code) sí encajan como estaban descritos.

### 4.5 `quality-culture-and-governance.md` — borrador Capa 6

Data as a product, shift-left, calidad en CI/CD, circuit breakers, ownership/SLA.

**Contenido y correcciones a incorporar** (`2026-08-03-quality-culture-and-cicd-verification.md`):
- "Data as a product" — cita textual de Zhamak Dehghani (martinfowler.com, 2019, *"How to Move Beyond a Monolithic Data Lake to a Distributed Data Mesh"*), bajo el heading exacto "Domain data as a product", con las seis cualidades tal como ella las nombra: Discoverable, Addressable, Trustworthy and truthful, Self-describing semantics and syntax, Inter-operable and governed by global standards, Secure and governed by a global access control.
- SLO vs. SLA — ver fork en §2.1. Usar "SLO" al citar a Dehghani directamente.
- Calidad en CI/CD — **Slim CI** (término oficial de `docs.getdbt.com`, no descripción genérica) + selector `state:modified`/`state:modified+` + flags `--defer`/`--state`, comparado contra "the last successful run of any job in your Production environment". Sintaxis exacta: `dbt build --select state:modified+ --defer --state path/to/prod/artifacts`.
- Circuit breaker de datos — ver fork dedicado en §2.1. Atribución dual (Fowler/Nygard como origen de software; Uttamchandani/Strata 2018 → Andrew Jones → ingeniería de Ibotta como adopción con nombre propio en datos), y corrección explícita del matiz bloqueo-vs-snapshot.
- Ownership/SLA de un dataset — presentar la tríada frescura/completitud/disponibilidad como síntesis pedagógica (no de una única fuente), ligada al "por qué" de Data Mesh (ownership por dominio) y a las dimensiones con respaldo real de Monte Carlo/DataHub para frescura y completitud; marcar disponibilidad como la más débil de las tres en la evidencia recolectada.

### 4.6 `SKILL.md`

Overview (el encuadre "fallos silenciosos → fallos ruidosos" del borrador), when to use, tabla de quick reference (una fila por archivo de referencia + una fila cross-link hacia `python-data-engineering/data-validation.md`), tabla de common mistakes construida directamente de las correcciones de §4.1-4.5 (ej.: presentar las 7 dimensiones como estándar único; asumir que `error_if` opera en porcentaje por defecto; confundir cuarentena con remoción automática de filas; usar `apiVersion`/`kind` en un contrato de datos; citar los 5 pilares sin atribuir a Monte Carlo; usar "SLA" en vez de "SLO" al citar a Dehghani; asumir que "circuit breaker de datos" implica servir el último snapshot bueno).

## 5. Fuera de alcance (de esta fase)

- CDC / captura de cambios en el origen (Debezium, WAL/binlog, Kafka Connect) — asignado a `streaming-data-engineering` (futura), sin cambios.
- Implementación/hosting de servicios de API (OpenAPI en profundidad) — ya excluido de la suite (`pipelines-architecture-data-engineering`, spec §2.1); el forward-pointer de contrato/versionado se cierra a nivel de principio, no de implementación (ver §2.1).
- Hosting/infraestructura de un Schema Registry, plataforma de observabilidad self-hosted, o Soda Agent — pointer hacia `iac-cloud-data-engineering` (futura), sin contenido hoy.
- Late-arriving dimensions / integridad relacional a nivel de modelo dimensional — pointer hacia `modeling-data-engineering` (futura), sin contenido hoy.
- ODCS (Open Data Contract Standard) como especificación en sí, más allá de la alineación de métricas ya citada; reglas de evolución específicas de Protobuf/JSON Schema con el mismo nivel de detalle que Avro — no investigado en esta ronda, requeriría verificación dedicada si se necesita en el futuro.

## 6. Próximos pasos

Transición a `superpowers:writing-plans` para el plan de implementación: redacción completa de `SKILL.md` + los 5 reference files, contenido final en inglés con todas las correcciones de §4 incorporadas y el borrador anonimizado (ver §1), más la actualización de la nota existente sobre `dbt-expectations` en `pipelines-architecture-data-engineering/references/dbt-project-architecture.md` (línea ~56) con la evidencia más fresca encontrada en esta ronda (§2.1). Sigue el mismo proceso ya usado en las 5 skills anteriores: `superpowers:subagent-driven-development` (haiku implementadores, sonnet revisores por tarea, opus para el review final), autorevisión `writing-great-skills` como tarea propia antes de la validación de discoverability, y review final de rama completa antes de cerrar.
