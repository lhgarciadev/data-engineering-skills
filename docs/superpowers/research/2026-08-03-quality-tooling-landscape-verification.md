# Research: panorama de herramientas de calidad de datos — Great Expectations, dbt tests/dbt-expectations, Soda, Monte Carlo, Anomalo, Pandera, Confluent Schema Registry

**Fecha:** 2026-08-03
**Alcance:** verificación de la Capa 4 ("Herramientas del ecosistema") de un draft para el futuro skill `quality-data-engineering` — 7 claims sobre: (1) si "data docs" sigue siendo terminología vigente de Great Expectations 1.x; (2) si `dbt-expectations` sigue sin mantenimiento activo (re-verificación fresca de una nota ya existente en el suite); (3) qué es SodaCL exactamente y si la distinción Soda Core/Cloud/Agent sigue vigente; (4) si Monte Carlo es efectivamente la fuente que acuñó "data observability" (marcado explícitamente como claim de vendor); (5) posicionamiento básico de Anomalo; (6) soporte real de backends de Pandera (pandas/Spark) cruzado contra una nota ya existente en `python-data-engineering`; (7) confirmación superficial de que Confluent Schema Registry impone compatibilidad de esquemas en Kafka. Todo verificado por fetch directo contra documentación oficial (`docs.greatexpectations.io`, `docs.soda.io`, `pandera.readthedocs.io`, `docs.confluent.io`, sitios oficiales de Monte Carlo/Anomalo, y `gh api` contra los repos oficiales de GitHub) — no reseñas de terceros, salvo donde se marca explícitamente.

---

## 1. Great Expectations — "Data Docs" sigue vigente en GX 1.x

**VEREDICTO: correcto, sin cambios.** "Data Docs" sigue siendo el término y la feature actual, confirmado por fetch directo a la documentación "core" (no versión legacy) de GX 1.x.

Cita textual exacta de la página de configuración de Data Docs:

> "Data Docs translate Expectations, Validation Results, and other metadata into human-readable documentation that is saved as static web pages."

Fuente: [Configure Data Docs — docs.greatexpectations.io/docs/core/configure_project_settings/configure_data_docs](https://docs.greatexpectations.io/docs/core/configure_project_settings/configure_data_docs/) (fetch directo, ruta `core/` = documentación GX 1.x vigente, no `docs/0.18/` legacy).

**Qué es exactamente**: un sitio HTML estático, auto-generado a partir de las Expectation Suites y los Validation Results cada vez que corre una validación — funciona como un reporte de calidad de datos que se mantiene actualizado automáticamente. GX permite configurar múltiples "Data Docs sites" con distinto alcance/hosting. La página no muestra ningún aviso de deprecación; es presentada como capacidad activa y soportada dentro del flujo estándar de GX 1.x (crear Expectation Suite → Validation Definition → Checkpoint → Data Docs se actualiza).

**Nota de honestidad epistémica**: la página consultada muestra un selector de versión con "1.19.1" al momento del fetch — no se hizo una verificación dedicada de changelog para confirmar que ese es el número de versión exacto vigente hoy (2026-08-03); se reporta como observación del fetch, no como claim verificado con la misma rigurosidad que el resto. Esto es consistente con y complementa la verificación ya hecha en `2026-08-03-quality-wshobson-agents-review.md` §2.1 sobre la API de Checkpoints post-V1 (agosto 2024) — ambas confirman que la fuente de referencia debe ser la ruta `docs/core/` de `docs.greatexpectations.io`, nunca `docs/0.18/` ni versiones anteriores a la migración V0→V1.

---

## 2. `dbt-expectations` — re-verificación fresca del estado de mantenimiento

**VEREDICTO: se confirma la nota ya existente en `dbt-project-architecture.md` línea ~56 — sigue sin mantenimiento activo, con evidencia más fuerte hoy que hace un año.**

Cita textual, primera línea del README actual (fetch directo vía `gh api repos/calogica/dbt-expectations/contents/README.md`, no una copia cacheada):

> "## Note: This package is no longer actively supported."

Fuente: [README.md — github.com/calogica/dbt-expectations](https://github.com/calogica/dbt-expectations/blob/main/README.md) (fetch directo del contenido vía GitHub API, 2026-08-03).

**Evidencia adicional de estado real del repo** (no solo el aviso textual):

| Señal | Valor | Fuente |
|---|---|---|
| Último release publicado | `0.10.4`, 2024-09-10 | `gh api repos/calogica/dbt-expectations/releases` |
| Último commit real a `main` | 2024-12-16 | `gh api repos/calogica/dbt-expectations/commits` |
| Repo archivado (`archived`) | `false` — sigue técnicamente activo/no congelado por GitHub, pero sin actividad de código | `gh api repos/calogica/dbt-expectations` |
| Versión mínima de dbt requerida declarada en README | `dbt 1.7.x` o superior | README, sección "Install" |
| Soporte de warehouses declarado en README | Postgres, Snowflake, BigQuery, DuckDB, Spark (**marcado "experimental"** en el propio README), Trino | README, sección "This package supports" |

Es decir: al momento de este research (2026-08-03), han pasado **más de 19 meses desde el último commit real** — la nota existente en el suite ("su propio README declara que ya no está activamente mantenido") queda confirmada con evidencia fresca y más contundente (no solo el texto del aviso, sino ausencia de commits desde dic. 2024). No se encontró ningún anuncio de un fork mantenido activamente que lo reemplace de forma oficial — no se investigó exhaustivamente ese punto porque estaba fuera del alcance pedido.

---

## 3. Soda — SodaCL, y la distinción Core/Cloud/Agent (hallazgo importante: el producto se reposicionó)

Este es el bloque con el hallazgo más relevante del research: **Soda cambió su posicionamiento de producto de forma sustancial**, y la documentación que describe SodaCL como el lenguaje central hoy vive bajo una sección explícitamente marcada como legacy ("v3"). Si el skill futuro presenta SodaCL como *el* lenguaje actual de Soda sin matizar esto, estaría describiendo el producto anterior, no el vigente.

### 3.1 Qué es SodaCL — vigente pero ahora es "v3" (legacy), no la doc principal

Cita textual exacta de la página de overview de SodaCL v3:

> "**Soda Checks Language (SodaCL)** is a YAML-based, domain-specific language for data reliability."

Ejemplo real citado textual, tomado de la misma página:

```yaml
checks for dim_customer:
  - row_count between 10 and 1000
  - missing_count(birth_date) = 0
  - invalid_percent(phone) < 1 %:
      valid format: phone number
  - invalid_count(number_cars_owned) = 0:
      valid min: 1
      valid max: 6
  - duplicate_count(phone) = 0
```

Fuente: [Soda v3 — SodaCL overview](https://docs.soda.io/soda-documentation/soda-v3/soda-cl-overview) (fetch directo). **Nota importante**: la URL corta `docs.soda.io/soda-cl/soda-cl-overview.html` (la que aparece en resultados de búsqueda y en contenido de terceros) devuelve **404** al momento de este research — la doc se movió/reorganizó bajo el prefijo `soda-documentation/soda-v3/`, señal adicional de que esta sección ya no es la superficie principal de la documentación.

### 3.2 El producto actual (2026-08-03) ya no gira en torno a SodaCL como eje único — es "Soda 4.0" con Data Contracts + Data Observability como pilares separados

El sitio oficial `soda.io` y la documentación no-versionada de `docs.soda.io` (la que responde por defecto, sin prefijo `soda-v3/`) presentan **Soda 4.0**, estructurado en tres pilares explícitos: **Data Contracts**, **Data Observability**, y **Root Cause Analytics** — con "Data Contracts" (no SodaCL) como el lenguaje de checks principal hoy.

El lenguaje de contratos v4 sigue siendo YAML declarativo, con checks reconociblemente emparentados con SodaCL (`missing`, `invalid`, `valid_values`, `threshold`) pero bajo una estructura distinta (`dataset:` + `checks:` + `columns:`). Ejemplo real citado textual de la referencia de Contract Language v4:

```yaml
dataset: datasource/db/schema/dataset

checks:
  - schema:
  - row_count:

columns:
  - name: id
    checks:
      - missing:
  - name: name
    checks:
      - missing:
          threshold:
            metric: percent
            must_be_less_than: 10
  - name: size
    checks:
      - invalid:
          valid_values: ['S', 'M', 'L']
```

Fuente: [Contract Language reference — docs.soda.io/reference/contract-language-reference](https://docs.soda.io/reference/contract-language-reference) (fetch directo).

Confirmación cruzada desde el repo oficial en GitHub (`sodadata/soda-core`, `gh api` directo, 2026-08-03): la descripción del repo ya no dice "SodaCL" sino **"Data Contracts engine for the modern data stack"**, y el README abre con:

> "Soda Core is a data quality and data contract verification engine. It lets you define data quality contracts in YAML and automatically validate both schema and data across your data stack."

El propio README distingue explícitamente **v4 vigente** (`pip install soda-postgres`) de **v3 legacy** (`pip install soda-core-postgres~=3.5.0`, con su propio README y docs separados en `docs.soda.io/soda-v3`). Último release visto vía API: `v4.19.0`, publicado 2026-07-28 — es decir, **producto activamente versionado la semana previa a este research**, evidencia de que v4/Data Contracts es la línea de desarrollo real, no solo marketing.

Fuente: [github.com/sodadata/soda-core](https://github.com/sodadata/soda-core) (README y metadata vía `gh api`, fetch directo 2026-08-03).

### 3.3 Distinción Core / Cloud / Agent — sigue vigente, con nombres actualizados

La separación conceptual que el draft implica (self-hosted open-source vs. producto gestionado) **sigue siendo real**, aunque los nombres exactos son ahora:

- **Soda Core** — librería Python + CLI open-source (`soda-{data source}`, ej. `soda-postgres`), instalable vía PyPI público, ejecuta contratos localmente o embebida en pipelines (Airflow, Dagster, Prefect, etc.). Cita del README: "These operations can be executed locally during development, embedded programmatically within your data pipelines ..., or executed remotely when connected to Soda Cloud."
- **Soda Cloud** — SaaS en `cloud.soda.io`, para gestión centralizada, dashboards, y el pilar de "Data Observability" (anomaly detection, monitoreo de miles de tablas).
- **Soda Agent** — sigue existiendo como término oficial de producto: infraestructura de ejecución, disponible como **self-hosted** (desplegado vía Helm en un cluster Kubernetes propio) o **Soda-hosted** ("Soda-hosted Runner"/"Soda-hosted agent", infraestructura gestionada por Soda). Fuente: [docs.soda.io/deployment-options/soda-agent](https://docs.soda.io/deployment-options/soda-agent) y confirmación cruzada en [docs.soda.io/quickstart](https://docs.soda.io/quickstart) (fetch directo).

**Matiz importante para el skill**: el draft clasifica a Soda junto con Monte Carlo y Anomalo bajo "observabilidad de datos (categoría distinta de validación)". Eso es una simplificación excesiva a la luz de esta verificación — **Soda hoy se posiciona a sí mismo abarcando ambas categorías a la vez**: "Data Contracts" (que es, en esencia, validación/testing declarativo, la misma familia que GX o dbt tests) **y** "Data Observability" como pilar separado dentro del mismo producto. Si el skill quiere mantener la distinción conceptual testing-vs-observabilidad (que es una distinción real y útil, no cuestionada aquí), debe aclarar que Soda es un caso donde el mismo vendor ofrece herramientas de ambas categorías bajo una sola marca, no un ejemplo puro de "solo observabilidad" como sí lo es Monte Carlo.

---

## 4. Monte Carlo — ¿de verdad popularizaron "data observability"? (contenido de vendor, marcado explícitamente)

**⚠️ Todo lo que sigue es contenido de vendor — la propia empresa afirmando haber acuñado el término que la beneficia comercialmente. No es un estándar neutral (no viene de un cuerpo normativo, una universidad, ni una publicación académica independiente) y se presenta aquí solo porque el draft lo cita como un hecho — el veredicto es que sí existe una fuente primaria oficial que hace esa afirmación explícitamente, pero su naturaleza es autopromocional.**

Cita textual directa, atribuida a Barr Moses (cofundadora y CEO de Monte Carlo), en el blog oficial de la compañía:

> "I coined the term data observability in 2019."

Fuente: [What is Data Observability? — montecarlo.ai/blog-what-is-data-observability](https://montecarlo.ai/blog-what-is-data-observability/) (fetch directo). La misma página referencia el artículo original de 2019 en Medium ("What is data observability? Hint: it's not just data for DevOps"), también firmado por Barr Moses, como el origen citado del término.

**Nota sobre el dominio**: la URL antigua `montecarlodata.com/blog-what-is-data-observability/` hace un **redirect 301 permanente** hacia `montecarlo.ai` — es decir, el dominio oficial de la compañía cambió (rebrand a `montecarlo.ai`); cualquier cita nueva en el skill debería usar el dominio actual, no `montecarlodata.com`.

**Qué se puede afirmar con evidencia, y qué no**:
- ✅ Verificado: Monte Carlo (la empresa, vía su CEO) **reclama públicamente** haber acuñado el término en 2019, en su propio canal oficial.
- ❌ No verificado en este research: no se buscó de forma exhaustiva evidencia independiente/neutral (ej. un paper académico anterior a 2019 que ya usara el término, o una atribución de un tercero no afiliado) que corrobore o contradiga la afirmación de originalidad. Dado que es un claim de autoría/prioridad histórica, tratarlo en el skill como "Monte Carlo se autoproclama origen del término, ampliamente aceptado por la industria" es más preciso que presentarlo como un hecho objetivo sin matiz.

---

## 5. Anomalo — posicionamiento básico confirmado

Verificación superficial, según lo pedido (no se buscó la misma profundidad que en los puntos anteriores). Según el sitio oficial (`anomalo.com`, overview de producto):

- Es una **plataforma de monitoreo de calidad de datos** con checks de disponibilidad de tabla, datos tardíos (late data), completitud, y **detección de anomalías basada en machine learning no supervisado** (unsupervised ML) además de reglas/umbrales definidos por el usuario vía UI no-code.
- Combina monitoreo "rules-based", "metrics-oriented" y "AI-powered" sobre datos estructurados y semiestructurados.

Fuente: [anomalo.com/product-overview](https://www.anomalo.com/product-overview/) y [anomalo.com/platform](https://www.anomalo.com/platform/) (vía búsqueda con snippets del sitio oficial — no se hizo fetch directo completo de cada página, consistente con la profundidad pedida para este punto).

**Encaja con el draft**: la caracterización "detectan anomalías automáticamente" es correcta para Anomalo específicamente (a diferencia de Soda, donde ese pilar es una de tres patas, no el producto entero).

---

## 6. Pandera — soporte real de backends (pandas + Spark confirmado, y más)

**VEREDICTO: el draft es correcto ("Pandera para DataFrames — pandas/Spark") y, de hecho, subestima el alcance real** — Pandera soporta más backends que solo esos dos.

Backends confirmados en la documentación oficial actual (`pandera.readthedocs.io/en/stable/supported_libraries.html`, fetch directo):

- **pandas** — "This is the original dataframe library supported by pandera."
- **PySpark SQL** (nativo, `pyspark.sql.DataFrame`) — vía el módulo dedicado `pandera.pyspark`.
- **PySpark Pandas** ("the pandas-like interface exposed by pyspark", antes conocido como Koalas) — soportado vía el mismo backend de pandas.
- **Polars**, **Ibis** — backends propios adicionales.
- **Dask**, **Modin**, **GeoPandas** — construidos sobre el backend de pandas ("apply schemas to Dask dataframe partitions", etc.).
- Backend unificado basado en **Narwhals** (desde Pandera 0.32.0) para Polars/Ibis/PySpark SQL.

**Confirmación específica del soporte nativo de Spark**, con ejemplo real citado de la doc oficial (`pandera.readthedocs.io/en/stable/pyspark_sql.html`):

> "You can use pandera to validate `pyspark.sql.DataFrame` objects directly."

```python
import pandera.pyspark as pa
import pyspark.sql.types as T
from pandera.pyspark import DataFrameModel

class PanderaSchema(DataFrameModel):
    id: T.IntegerType() = pa.Field(gt=5)
    product_name: T.StringType() = pa.Field(str_startswith="B")
    price: T.DecimalType(20, 5) = pa.Field()
    description: T.ArrayType(T.StringType()) = pa.Field()
    meta: T.MapType(T.StringType(), T.StringType()) = pa.Field()

df_out = PanderaSchema.validate(check_obj=df)
```

Instalación requerida: `pip install 'pandera[pyspark]'` (extra dedicado, no viene por defecto con `pandera` base).

Fuentes: [Supported DataFrame Libraries](https://pandera.readthedocs.io/en/stable/supported_libraries.html), [Data Validation with Pyspark SQL](https://pandera.readthedocs.io/en/stable/pyspark_sql.html) — ambas fetch directo.

### Cruce contra la nota existente en `python-data-engineering/references/data-validation.md`

La nota ya existente en el suite dice: *"the same schema definition works across pandas, Polars, Dask, and PySpark"*. Esto **no queda contradicho** por esta verificación — es correcto en el nivel conceptual (un mismo *concepto* de schema de Pandera aplica a todos esos backends). Un matiz que vale la pena que el skill nuevo incorpore si entra en más detalle de sintaxis: para PySpark nativo (`pandera.pyspark`), la declaración de columnas usa **tipos nativos de Spark** (`T.IntegerType()`, `T.StringType()`, etc., de `pyspark.sql.types`) en vez de tipos Python/pandas — es decir, la *API* de definición de schema cambia ligeramente por backend (import distinto, tipos distintos), aunque el *modelo mental* (`DataFrameSchema`/`DataFrameModel` + `Field`/`Check`) sí es el mismo en todos. No es una contradicción de la nota existente, pero si el skill muestra código Pandera+Spark literal, debe usar `pandera.pyspark`, no el mismo bloque de `pandera.pandas` mostrado para el caso pandas.

---

## 7. Confluent Schema Registry — confirmación superficial de la categorización

Verificado solo a nivel de "qué hace", según lo pedido (el detalle de los modos de compatibilidad exactos —BACKWARD/FORWARD/FULL/transitivos— lo cubre otro research en paralelo).

Cita textual oficial:

> "[Schema Registry provides] a centralized repository for managing and validating schemas for topic message data, and for serialization and deserialization of the data over the network." Y específicamente sobre compatibilidad: "Compatibility checking of schemas between producers and consumers to ensure that message data can be consumed by different applications and systems without resulting in errors or data loss due to message formatting."

Fuente: [Schema Registry Overview — docs.confluent.io/platform/current/schema-registry](https://docs.confluent.io/platform/current/schema-registry/index.html) (fetch directo).

**Veredicto**: la caracterización del draft — "para streaming, impone compatibilidad de esquemas en Kafka" — es correcta a este nivel de generalidad. Confirmado sin profundizar en los modos de compatibilidad específicos, como se pidió.

---

## Tabla resumen — herramienta → categoría → qué hace (verificado)

| Herramienta | Categoría real (verificada) | Qué hace, según fuente oficial |
|---|---|---|
| **Great Expectations** | Validación declarativa + documentación de calidad | Expectativas declarativas (objetos `gx.expectations.X(...)` en GX 1.x) ejecutadas vía Checkpoints; genera **Data Docs** — sitio HTML estático, auto-actualizado, con expectation suites + resultados de validación. Vigente, sin deprecar. |
| **dbt tests** (genéricos/singulares) | Validación integrada al pipeline de transformación | 4 tests genéricos built-in (`unique`, `not_null`, `accepted_values`, `relationships`, declarados en YAML) + tests singulares (`.sql` en `tests/`) ejecutados con `dbt test`/`dbt build`. |
| **dbt-expectations** | Paquete community de tests estilo GE para dbt | Extiende dbt con tests inspirados en GE. **Confirmado hoy (2026-08-03): sigue sin mantenimiento activo** — README lo declara explícitamente, último release sep-2024, último commit dic-2024 (>19 meses de inactividad de código). |
| **Soda** | **Ambas** — Data Contracts (testing/validación) **y** Data Observability, como pilares separados del mismo producto (Soda 4.0, vigente) | SodaCL (YAML, ahora doc "v3"/legacy) fue el lenguaje de checks original; hoy el lenguaje principal es **Contract Language** (YAML, v4). Soda Core = librería/CLI open-source; Soda Cloud = SaaS gestionado; Soda Agent = infraestructura de ejecución (self-hosted vía Helm/K8s o Soda-hosted). |
| **Monte Carlo** | Observabilidad de datos (posicionamiento propio) | Plataforma de observabilidad. ⚠️ **Claim de vendor, no neutral**: su CEO/cofundadora declara públicamente haber acuñado "data observability" en 2019 en el blog oficial de la empresa. |
| **Anomalo** | Observabilidad / monitoreo de calidad con ML | Monitoreo con reglas + umbrales + ML no supervisado para detección automática de anomalías; UI no-code; checks de disponibilidad, datos tardíos, completitud. |
| **Pandera** | Validación de esquemas de DataFrames | Backend original: pandas. Soporta también Polars, Dask, Modin, GeoPandas, Ibis, y **PySpark nativo** (`pandera.pyspark`, `pip install 'pandera[pyspark]'`, tipos `pyspark.sql.types`) + PySpark Pandas. El draft ("pandas/Spark") es correcto y subestima el alcance real. |
| **Confluent Schema Registry** | Governance de esquemas para streaming | Repositorio centralizado que valida esquemas y aplica *compatibility checking* entre productores y consumidores de Kafka — confirmado a nivel de categorización; modos exactos fuera de alcance aquí. |

---

## Notas de honestidad epistémica — resumen

- **GX**: versión "1.19.1" observada en el selector de la página consultada, no verificada contra un changelog dedicado — reportada como observación, no como claim con el mismo nivel de confianza que el resto.
- **dbt-expectations**: no se investigó si existe un fork activamente mantenido que lo reemplace — fuera del alcance pedido.
- **Soda**: es el hallazgo más significativo del research — el producto se reposicionó de SodaCL (ahora "v3"/legacy) a Data Contracts (v4, lanzamiento activo, último release una semana antes de este research). Cualquier contenido del skill que muestre solo SodaCL sin mencionar Data Contracts estaría describiendo la generación anterior del producto.
- **Monte Carlo**: el claim de haber acuñado "data observability" es un claim de autoría verificado como *declarado por la propia empresa*, no verificado de forma independiente/neutral — marcado explícitamente como contenido de vendor, tal como pidió el encargo.
- **Anomalo**: verificación deliberadamente superficial, según alcance pedido — no se hizo fetch directo de cada página, solo snippets de búsqueda del sitio oficial.
- **Confluent Schema Registry**: verificación deliberadamente superficial, según alcance pedido — no se investigaron los modos de compatibilidad (BACKWARD/FORWARD/FULL/transitivos), delegado a otro research en paralelo.
