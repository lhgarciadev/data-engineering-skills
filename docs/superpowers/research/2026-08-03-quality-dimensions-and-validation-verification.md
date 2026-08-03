# Research: las 7 dimensiones de calidad de datos y la validación en el pipeline (esquema, tests de dbt, Pydantic fail-fast, schema-on-read/write y medallion)

**Fecha:** 2026-08-03
**Alcance:** verificación de 4 bloques de claims para el futuro skill `quality-data-engineering` (6ta de 9 en el suite `data-engineering-skills`): (1) si existe un marco/estándar autoritativo que defina exactamente las 7 dimensiones de calidad del borrador (completitud, unicidad, validez, exactitud, consistencia, integridad referencial, frescura), y si "integridad referencial" se trata como dimensión separada en fuentes serias; (2) los tipos de chequeo de dbt (`unique`, `not_null`, `accepted_values`, `relationships`) y su configuración de severidad/umbrales, sin duplicar el detalle de políticas de fallo que cubre otro agente en paralelo; (3) el patrón "fail fast en el borde de ingesta" con Pydantic contra `docs.pydantic.dev`; (4) schema-on-read vs. schema-on-write y la afirmación de que el patrón medallion aterriza raw permisivo → validación estricta en la transición a curada, contra documentación oficial de Databricks/Delta Lake. Fuentes: ISO/IEC 25012 (vía portales especializados, el texto completo del estándar es de pago), el whitepaper de DAMA UK (fetch directo del PDF, mirror de terceros pero documento original de DAMA UK Working Group), `docs.getdbt.com` (fetch directo), `docs.pydantic.dev`/`pydantic.dev` (fetch directo, dominio migrado), `docs.databricks.com` y el blog oficial de Databricks/Delta Lake (fetch directo).

---

## 1. Las 7 dimensiones de calidad — ¿existe un estándar único que las nombre así?

**VEREDICTO: no existe un estándar único y universal que defina exactamente estas 7 dimensiones con estos 7 nombres. Hay dos fuentes serias que se acercan — ISO/IEC 25012 y el whitepaper de DAMA UK — pero ninguna de las dos coincide exactamente con el borrador, y la propia fuente DAMA UK admite explícitamente que no hay consenso en la industria.**

### 1.1 ISO/IEC 25012 — el estándar formal, pero no coincide con el vocabulario del borrador

ISO/IEC 25012:2008 ("Software engineering — Software product Quality Requirements and Evaluation (SQuaRE) — Data quality model") es un estándar de pago; el texto completo no es accesible de forma gratuita ([catálogo oficial ISO — iso.org/standard/35736.html](https://www.iso.org/standard/35736.html), abstract no accesible por fetch directo — bloqueado con 403). Lo que sigue viene de portales especializados que resumen/citan el estándar (no es el texto oficial verbatim, así que se marca explícitamente como fuente secundaria):

- [iso25000.com/en/iso-25000-standards/iso-25012](https://iso25000.com/index.php/en/iso-25000-standards/iso-25012) — portal dedicado específicamente a la familia ISO/IEC 25000 (SQuaRE).
- [quality.arc42.org/standards/iso-iec-25012](https://quality.arc42.org/standards/iso-iec-25012) — portal de modelos de calidad del proyecto arc42.

ISO/IEC 25012 define **15 características** repartidas en tres categorías: *inherentes*, *dependientes del sistema*, y *ambas*. Las inherentes son las más cercanas al vocabulario "de negocio" del borrador:

| Característica ISO 25012 | Definición citada |
|---|---|
| Accuracy | "The degree to which data has attributes that correctly represent the true value of the intended attribute of a concept or event in a specific context of use." |
| Completeness | "The degree to which subject data associated with an entity has values for all expected attributes and related entity instances in a specific context of use." |
| Consistency | "The degree to which data has attributes that are free from contradiction and are coherent with other data in a specific context of use." |
| Credibility | (inherente, no citada verbatim en esta pasada) |
| Currentness | (inherente, no citada verbatim en esta pasada) |

Las 10 restantes (dependientes del sistema o ambas: accessibility, compliance, confidentiality, efficiency, precision, traceability, understandability, availability, portability, recoverability) están confirmadas por nombre en al menos dos fuentes independientes, pero fuera del alcance de este research en cuanto a definiciones exactas.

**Hallazgo clave**: **ni "uniqueness" (unicidad) ni "referential integrity" (integridad referencial) aparecen como características nombradas en ISO/IEC 25012**, confirmado de forma consistente en las dos fuentes fetcheadas directamente. ISO 25012 trata la unicidad implícitamente bajo "Consistency" (ausencia de contradicción), no como dimensión propia — y no tiene ninguna característica dedicada a integridad referencial.

### 1.2 DAMA UK — el whitepaper "Six Primary Dimensions" (fuente primaria, fetch directo del PDF)

DAMA-DMBOK en sí (el libro de DAMA International) es una publicación de pago sin texto libre accesible. Sin embargo, **DAMA UK** (capítulo nacional de DAMA International) publicó en 2013 un whitepaper dedicado exactamente a este tema, con autoría de un working group nombrado explícitamente (Nicola Askham, Denise Cook, Martin Doyle, entre otros) y respaldo de DAMA UK — la fuente primaria/oficial más cercana a "DAMA" que existe en acceso abierto. El documento se obtuvo por fetch directo del PDF (mirror de `dqglobal.com`, ya que el sitio oficial de DAMA UK lo lista como contenido solo para miembros — mismo texto, mismo autor institucional, marcado aquí como corroboración, no como fuente única):

> "The term *data quality dimension* has been widely used for a number of years to describe the measure of the quality of data. However, **even amongst data quality professionals the key data quality dimensions are not universally agreed**. This state of affairs has led to much confusion within the data quality community..."

Fuente: DAMA UK Working Group, *"The Six Primary Dimensions for Data Quality Assessment: Defining Data Quality Dimensions"* (octubre 2013, Final Version), p.1 — [mirror PDF](https://www.dqglobal.com/wp-content/uploads/2013/11/DAMA-UK-DQ-Dimensions-White-Paper-R37.pdf).

**Esta es la cita más importante de todo este research**: la propia comunidad DAMA admite por escrito que no hay consenso universal — exactamente lo que se pidió verificar con honestidad si no se encontraba.

Las **seis dimensiones core** que DAMA UK sí define, con cita textual exacta:

| Dimensión DAMA UK | Definición citada |
|---|---|
| Completeness | "The proportion of stored data against the potential of '100% complete'" |
| Uniqueness | "No thing will be recorded more than once based upon how that thing is identified." |
| Timeliness | "The degree to which data represent reality from the required point in time." |
| Validity | "Data are valid if it conforms to the syntax (format, type, range) of its definition." |
| Accuracy | "The degree to which data correctly describes the 'real world' object or event being described." |
| Consistency | "The absence of difference, when comparing two or more representations of a thing against a definition." |

Fuente: mismo documento, pp. 7–13.

**Sobre "integridad referencial" — verificado explícitamente, no por ausencia de búsqueda**: se leyó el documento completo (17 páginas, incluida la sección "Other Data Quality Considerations" que cubre factores adicionales como usability, timing, flexibility, confidence, value, y el Glosario de dos páginas). **"Referential integrity" no aparece en ninguna parte del documento** — ni como dimensión, ni como sub-concepto, ni en el glosario. Esto es evidencia directa (no inferencia) de que, en la fuente DAMA UK, la integridad referencial **no se trata como dimensión de calidad de datos independiente**.

### 1.3 ¿Dónde "vive" entonces la integridad referencial?

No en un framework de dimensiones de calidad como ISO 25012 o DAMA UK — en ambas fuentes está ausente como concepto nombrado. Donde sí aparece nombrada explícitamente con ese término es en la documentación técnica de **dbt**, pero como *descripción de un tipo de test*, no como "dimensión" en el sentido DAMA/ISO:

> "each `customer_id` in the `orders` model exists as an `id` in the `customers` table (**also known as referential integrity**)"

Fuente: [docs.getdbt.com/docs/build/data-tests](https://docs.getdbt.com/docs/build/data-tests) (fetch directo) — descripción del test genérico `relationships`. Ver §2.

**Veredicto para el skill**: el borrador presenta 7 "dimensiones" tratándolas como si fueran un vocabulario unificado y estándar. La realidad verificada es más matizada — hay que decirlo así en el skill:
- **Completitud, Validez, Exactitud, Consistencia** — están en ambas fuentes serias revisadas (ISO 25012 y DAMA UK), con definiciones que coinciden conceptualmente entre sí.
- **Unicidad** — es dimensión propia en DAMA UK, pero en ISO 25012 no aparece como característica nombrada (queda subsumida en Consistency).
- **Frescura/Timeliness** — es dimensión propia en DAMA UK (con ese nombre exacto); en ISO 25012 el concepto más cercano es "Currentness" (no verificado en detalle en esta pasada, pero confirmado como característica nombrada por dos fuentes independientes).
- **Integridad referencial** — **no aparece como dimensión independiente en ninguna de las dos fuentes serias verificadas**. Es, en la práctica, un caso particular de "Consistency"/"Validity" aplicado a claves foráneas, y su tratamiento como chequeo técnico concreto (no como "dimensión") es exactamente cómo lo trata dbt (test `relationships`).

**Nota de honestidad epistémica**: no se encontró ninguna fuente única, oficial y de acceso abierto que enumere exactamente las 7 dimensiones del borrador con esos 7 nombres. El propio DAMA UK dice por escrito que no hay consenso universal. El skill debería presentar esto como "vocabulario de industria ampliamente usado, sintetizado de varias fuentes (ISO 25012, DAMA UK y práctica común de ingeniería)" — no como cita de un único estándar. Sí puede citar DAMA UK textualmente para 6 de las 7, y debe ser explícito en que "integridad referencial" se añade aquí como séptima categoría por utilidad práctica de ingeniería (es el chequeo real que hace dbt con `relationships`), no porque ISO o DAMA la nombren como dimensión séptima.

---

## 2. Tipos de chequeo en dbt — tests genéricos, severidad y frescura

**VEREDICTO: los 4 tests genéricos existen tal como los describe el borrador y están confirmados contra `docs.getdbt.com`. La configuración de severidad/umbral también existe y está confirmada. El orden "de más barato a más caro" NO es una clasificación que dbt publique — es un criterio de ingeniería razonable pero no está en la documentación oficial, y el skill no debería presentarlo como si lo estuviera.**

### 2.1 Los 4 tests genéricos built-in

> "Out of the box, dbt ships with four generic data tests already defined: `unique`, `not_null`, `accepted_values`, and `relationships`."

Fuente: [docs.getdbt.com/docs/build/data-tests](https://docs.getdbt.com/docs/build/data-tests) (fetch directo).

| Test | Qué valida (cita) |
|---|---|
| `unique` | "the `order_id` column in the `orders` model should be unique" |
| `not_null` | "the `order_id` column in the `orders` model should not contain null values" |
| `accepted_values` | "the `status` column in the `orders` model should be one of `'placed'`, `'shipped'`, `'completed'`, or `'returned'`" — esto cubre el ángulo "rango/dominio" del borrador |
| `relationships` | "each `customer_id` in the `orders` model exists as an `id` in the `customers` table (also known as referential integrity)" |

Este bloque es compatible con y no duplica lo ya establecido en [`sql-data-engineering/references/query-optimization-and-production.md`](../../../skills/sql-data-engineering/references/query-optimization-and-production.md) (línea ~74), que ya llama a estos 4 tests "data-quality checks expressed directly as SQL assertions" — este research confirma el detalle de cada uno, no reabre esa síntesis.

**Nota sobre "esquema" como capa de chequeo**: no es uno de los 4 generic tests — es una validación estructural distinta (tipos de columna, contrato de modelo). dbt la cubre por otro mecanismo (`data_type` en `columns`, o `contract: enforced` a nivel de modelo) — no verificado en profundidad en esta pasada porque el pedido lo agrupa dentro de "tipos de chequeo" sin pedir el detalle de `model contracts`; si el skill necesita esa mecánica exacta, requiere una verificación dedicada adicional.

### 2.2 Severidad y umbrales — confirmado, sin duplicar el detalle que cubre el agente en paralelo

> "The relevant configs are: `severity`: `error` or `warn` (default: `error`)" / "`error_if`: conditional expression (default: `!=0`)" / "`warn_if`: conditional expression (default: `!=0`)"

> "If `severity: error`, dbt will check the `error_if` condition first... If `severity: warn`, dbt will skip the `error_if` condition entirely and jump straight to the `warn_if` condition."

Fuente: [docs.getdbt.com/reference/resource-configs/severity](https://docs.getdbt.com/reference/resource-configs/severity) (fetch directo). Esto confirma que la mecánica de umbrales que el borrador menciona de pasada existe y está bien documentada — el detalle profundo de política de fallo queda, como se pidió, para el agente en paralelo.

### 2.3 Frescura — confirmado, mecánica exacta = `max(...)` contra umbral, tal como dice el borrador

> Query que dbt construye internamente: `select max(_etl_loaded_at) as max_loaded_at, convert_timezone('UTC', current_timestamp()) as calculated_at from raw.jaffle_shop.orders`

Configurado vía `freshness: { warn_after: {count, period}, error_after: {count, period} }` y `loaded_at_field`. Fuente: [docs.getdbt.com/docs/build/sources](https://docs.getdbt.com/docs/build/sources) (fetch directo). **Esto confirma literalmente** la afirmación del borrador de que la frescura se chequea como "`max(updated_at)` dentro de umbral".

### 2.4 Conteo/volumen — existe, pero NO es parte del dbt-core built-in (matiz que el borrador no hace)

`equal_rowcount` y `fewer_rows_than` son tests genéricos reales, pero viven en el paquete **`dbt-utils`** (mantenido por dbt Labs, distribuido vía dbt Hub, no incluido por defecto en dbt-core) — confirmado en el repositorio oficial [github.com/dbt-labs/dbt-utils](https://github.com/dbt-labs/dbt-utils/blob/main/macros/generic_tests/equal_rowcount.sql). El borrador da el ejemplo correcto conceptualmente ("una carga con 10 filas cuando siempre trae 10.000 es un fallo"), pero si el skill lo presenta como "test de dbt" sin aclarar que requiere instalar `dbt-utils`, sería impreciso — vale la pena que el skill haga esa distinción (4 tests core vs. paquete adicional).

### 2.5 El orden "de más barato a más caro" — no está en la documentación oficial de dbt

No se encontró ninguna página de `docs.getdbt.com` que ordene los tipos de chequeo por costo computacional. Es un criterio de ingeniería razonable (un `not_null`/`unique` es un scan de una tabla; un `relationships` es un join contra otra tabla; un chequeo de volumen día-contra-día puede requerir comparar particiones históricas) pero **es una síntesis del autor del borrador, no una clasificación que dbt publique**. El skill puede seguir usando este orden como heurística pedagógica, pero no debería atribuírselo a dbt como si fuera su propia documentación.

---

## 3. Pydantic — fail fast en el borde de ingesta

**VEREDICTO: el patrón descrito en el borrador es consistente con cómo Pydantic se documenta y usa realmente, con un matiz importante sobre qué significa "fail fast" en Pydantic — no es "para en el primer campo que falla", es "falla todo el payload de una vez, después de recolectar todos los errores".**

Nota de infraestructura: `docs.pydantic.dev` redirige (301) a `pydantic.dev/docs/validation/latest/...` — mismo contenido, dominio migrado; ambos fetch directo.

> "Untrusted data can be passed to a model and, after parsing and validation, Pydantic guarantees that the fields of the resultant model instance will conform to the field types defined on the model."

Fuente: [pydantic.dev/docs/validation/latest/concepts/models/](https://pydantic.dev/docs/validation/latest/concepts/models/) (fetch directo, vía redirect desde docs.pydantic.dev).

> "Pydantic will raise a `ValidationError` exception whenever it finds an error in the data it's validating."
>
> "A single exception will be raised regardless of the number of errors found, and that validation error will contain information about all of the errors and how they happened."

Misma fuente. **Este es el matiz relevante para el skill**: el comportamiento *default* de Pydantic no es "para en el primer error de campo" — es "recolecta todos los errores de campo del payload y lanza **una** excepción con todos ellos". Esto sigue siendo "fail fast" en el sentido que pide el borrador (falla todo el registro en un punto controlado, antes de que el dato corrupto se propague), pero no es "para en el primer campo" a nivel de un solo objeto.

Existe además una anotación literal llamada `FailFast` (desde Pydantic v2.8+), pero su alcance es más específico de lo que el nombre sugiere: aplica a **listas/secuencias de ítems**, y hace que la validación pare en el primer ítem inválido de la secuencia en vez de reportar todos los ítems fallidos — un trade-off explícito de visibilidad por rendimiento, no el mecanismo general de validación de un payload. No confundir este feature específico con el patrón general de "validar al leer, fallar con excepción clara" que sí es el comportamiento por defecto de cualquier `BaseModel`.

**Esto es compatible** con lo que ya establece [`python-data-engineering/references/data-validation.md`](../../../skills/python-data-engineering/references/data-validation.md): "Pydantic at ingestion boundaries (validate the payload/record as it enters your system)" y la tabla de "common mistakes" que dice explícitamente "Skipping validation at the ingestion boundary... Validate at the boundary with Pydantic — catching malformed input early gives a clear, localized error instead of a confusing downstream failure." Este research no reabre esa comparación Pydantic/Pandera/Great Expectations — solo confirma, con cita textual de `docs.pydantic.dev`, que el mecanismo de `ValidationError` respalda exactamente esa afirmación.

---

## 4. Schema-on-read vs. schema-on-write, y medallion

**VEREDICTO: ambos términos son terminología real usada por Databricks en su documentación oficial (confirmado verbatim para "schema-on-write"; "schema-on-read" es el término estándar de la industria pareado con él, pero no se pudo confirmar verbatim en la página específica de Databricks fetcheada — ver nota de honestidad abajo). La afirmación sobre medallion (bronze permisivo → validación estricta en la transición a silver) queda confirmada de forma directa y explícita contra la documentación oficial de Databricks sobre medallion architecture.**

### 4.1 Schema-on-write — confirmado verbatim en documentación oficial de Databricks

> "The data warehouse itself is schema-on-write and atomic."

Fuente: [docs.databricks.com — Data warehousing architecture](https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts) (fetch directo).

### 4.2 Schema-on-read — término estándar de industria, pero no confirmado verbatim en esta página específica

Se buscó explícitamente el término "schema-on-read" en la misma página y en el glosario de Databricks (`databricks.com/glossary/schema-on-read` devolvió 404). **No se logró una cita textual verbatim de "schema-on-read" desde una página de `docs.databricks.com` fetcheada directamente en esta pasada** — aunque el concepto que describe (aplicar estructura al leer, no al escribir) es exactamente lo que la página de Databricks describe para el bronze layer sin usar ese término exacto (ver 4.3). El término "schema-on-read" en sí es de uso extendido en la industria (aparece en Dremio, Cribl, y es el término histórico asociado a Hadoop/data lakes desde hace más de una década), pero para esta pasada específica de research se marca como **no confirmado verbatim contra una fuente Databricks de primera mano** — si el skill necesita citarlo como término oficial de Databricks textual, requiere una búsqueda dedicada adicional.

### 4.3 Medallion — bronze permisivo, silver con validación estricta: confirmado explícitamente

De la página oficial de arquitectura medallion de Databricks:

> Bronze: "Contains and maintains the raw state of the data source in its original formats." / "Minimal data validation is performed in the bronze layer" / "Databricks recommends storing most fields as string, VARIANT, or binary to protect against unexpected schema changes."
>
> Silver: "Data cleanup and validation are performed in silver layer." — con operaciones listadas explícitamente: "Schema enforcement," "Schema evolution," "Data deduplication," "Data quality checks and enforcement," "Handling of null and missing values."

Fuente: [docs.databricks.com/aws/en/lakehouse/medallion](https://docs.databricks.com/aws/en/lakehouse/medallion) (fetch directo).

**Esto confirma exactamente la afirmación del borrador**: raw/bronze acepta datos con mínima validación y tipado flexible (equivalente funcional a schema-on-read, aunque la página no use ese término exacto), y la transición a la capa siguiente (silver) es donde se aplica "schema enforcement" y "data quality checks and enforcement" de forma estricta — es decir, la transición raw→curada es el punto de validación estricta, tal como describe el borrador.

Corroboración adicional desde el blog oficial de Databricks sobre Delta Lake (motor de storage típico detrás de estas capas):

> "Schema enforcement, also known as schema validation, is a safeguard in Delta Lake that ensures data quality by rejecting writes to a table that do not match the table's schema."
>
> "Delta Lake uses schema validation _on write_, which means that all new writes to a table are checked for compatibility with the target table's schema at write time." / "If the schema is not compatible, Delta Lake cancels the transaction altogether (no data is written), and raises an exception."

Fuente: [Databricks blog — Diving Into Delta Lake: Schema Enforcement & Evolution](https://www.databricks.com/blog/2019/09/24/diving-into-delta-lake-schema-enforcement-evolution.html) (fetch directo, blog oficial de Databricks, no un tercero). Nota: el texto usa literalmente "schema validation *on write*", conceptualmente equivalente a "schema-on-write" pero no como un único término compuesto — se marca la diferencia de fraseo exacto por rigor.

### 4.4 Cruce con lo ya resuelto en el suite — no reabrir

[`pipelines-architecture-data-engineering/references/dbt-project-architecture.md`](../../../skills/pipelines-architecture-data-engineering/references/dbt-project-architecture.md) ya deja establecido, verificado contra `docs.getdbt.com` en el research previo (`2026-08-02-dbt-project-structure-verification.md`, §3), que **"medallion" (bronze/silver/gold) no es vocabulario propio de dbt** — es terminología de Databricks/lakehouse que algunos equipos mapean por analogía sobre staging/intermediate/marts. Este research (enfocado en Databricks, no en dbt) es consistente con ese hallazgo: aquí se confirma que medallion **sí** es vocabulario propio y documentado de Databricks — los dos research se complementan, no se contradicen. Si el skill `quality-data-engineering` menciona medallion en el contexto de "dónde validar", debe remitir a esa referencia ya existente para la comparación medallion-vs-dbt-layering, y limitarse aquí al ángulo de "raw permisivo → validación estricta en la transición", que es el ángulo nuevo que aporta este research.

---

## Resumen de acciones para el contenido del skill

1. **No presentar las 7 dimensiones como si vinieran de un único estándar universal.** Usar DAMA UK (whitepaper 2013, cita textual disponible arriba para 6 de las 7) como columna vertebral, marcar "integridad referencial" explícitamente como una séptima categoría añadida por utilidad de ingeniería — ausente tanto en ISO 25012 como en DAMA UK como dimensión nombrada — y anclarla en cambio al test `relationships` de dbt, que sí la llama "referential integrity" textualmente.
2. **Citar la frase de DAMA UK sobre falta de consenso** ("even amongst data quality professionals the key data quality dimensions are not universally agreed") como la nota de honestidad epistémica del propio skill — es una cita fuerte y con autoridad institucional, mejor que inventar una afirmación de consenso que no existe.
3. **Los 4 generic tests de dbt están confirmados uno por uno** con su sintaxis y semántica exactas — usarlos tal como están citados arriba. Aclarar que `equal_rowcount`/`fewer_rows_than` (chequeo de volumen) requieren el paquete `dbt-utils`, no vienen en dbt-core.
4. **No atribuir a dbt un orden oficial "barato→caro" de tests** — es heurística del skill, no de la documentación de dbt. Se puede seguir usando, pero sin cita falsa.
5. **Pydantic**: usar la cita de `ValidationError` y aclarar el matiz de "fail fast" — por defecto Pydantic recolecta todos los errores de un payload y lanza una sola excepción (no para en el primer campo); `FailFast` como anotación literal es un feature aparte, específico de secuencias/listas desde v2.8+.
6. **Schema-on-write está confirmado verbatim en Databricks; schema-on-read no se pudo confirmar verbatim en esta pasada** — usar el término igual (es estándar de industria y el concepto está descrito funcionalmente en la doc de bronze/silver de Databricks) pero no citarlo como frase textual de Databricks sin verificación adicional.
7. **Medallion raw-permisivo → validación-estricta-en-la-transición queda confirmado de forma directa y fuerte** contra la página oficial de medallion architecture y el blog de Delta Lake — este es el hallazgo más sólido de todo el bloque 4, se puede usar con confianza.

**Nota de honestidad epistémica general**: dos huecos quedaron explícitamente marcados y no resueltos en esta pasada — (a) el texto completo de ISO/IEC 25012 es de pago, así que su lista de 15 características se verificó vía dos portales especializados coincidentes, no contra el estándar mismo; (b) "schema-on-read" no se confirmó como cita textual de una página oficial de Databricks, solo como término de industria consistente con lo que Databricks describe funcionalmente. Ninguno de los dos huecos afecta los veredictos principales, pero un lector exigente debería poder distinguir "confirmado verbatim contra fuente primaria" de "confirmado conceptualmente, término de industria" — ambos casos están marcados como tal arriba, no mezclados.
