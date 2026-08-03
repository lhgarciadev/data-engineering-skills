# Research: políticas ante fallo de calidad — mecanismo real de dbt (severity/thresholds/store_failures), acciones de Checkpoint en Great Expectations, patrón de "cuarentena" en vendors, y el argumento de coste asimétrico

**Fecha:** 2026-08-03
**Alcance:** verificación de 4 bloques de claims para la Capa 2 del draft de `quality-data-engineering` ("qué hacer cuando la calidad falla: las políticas" — fail/abort, quarantine, drop-con-alerta, default/repair, umbrales no absolutos, coste asimétrico del error): (1) el mecanismo real de dbt para umbrales (`severity`, `error_if`/`warn_if`, `fail_calc`) y cuarentena-like behavior (`store_failures`/`store_failures_as`), verificado contra `docs.getdbt.com`; (2) las acciones concretas de reacción-ante-fallo que ofrece la API actual de Checkpoints de Great Expectations (1.x), verificado contra `docs.greatexpectations.io` **y** contra el código fuente real del paquete publicado en PyPI (`great_expectations==1.19.1`) en GitHub; (3) si algún vendor mayor (AWS Glue, Databricks) usa explícitamente el término "quarantine" en documentación oficial y cómo lo implementa; (4) si el argumento de "coste asimétrico del error" tiene una fuente primaria de ingeniería de datos, o si es una aplicación razonable de un principio de teoría de decisión/estadística general.

**Método:** fetch directo contra `docs.getdbt.com` y `docs.greatexpectations.io` vía WebFetch (igual método que `2026-08-02-dbt-project-structure-verification.md`); para Great Expectations, verificación adicional cruzada contra el **código fuente real** en `github.com/great-expectations/great_expectations`, en el tag de release `1.19.1` (confirmado como la versión actual publicada en PyPI al momento de este research — ver §2); búsquedas dedicadas (`gh api search/code`) sobre el propio repo de GX para confirmar ausencias, no solo para confirmar presencias.

---

## 1. dbt — `severity`, `error_if`/`warn_if`, `fail_calc` y `store_failures`/`store_failures_as`

### 1.1 `severity: warn | error` — valores, default y orden de evaluación

**Valores aceptados:** `error` o `warn`. **Default: `error`.**

Comportamiento verificado (orden de evaluación exacto):

- Con `severity: error` (default): dbt evalúa primero `error_if`; si se cumple → **error**. Si no se cumple, evalúa `warn_if`; si se cumple → **warn**; si no → pasa.
- Con `severity: warn`: dbt **ignora `error_if` por completo**, solo evalúa `warn_if`.

Sintaxis exacta (YAML):

```yaml
models:
  - name: large_table
    columns:
      - name: slightly_unreliable_column
        data_tests:
          - unique:
              config:
                severity: error
                error_if: ">1000"
                warn_if: ">10"
```

Fuente: [reference/resource-configs/severity](https://docs.getdbt.com/reference/resource-configs/severity) (fetch directo). Nota: esta única página de referencia documenta **las tres configs juntas** (`severity`, `error_if`, `warn_if`) — su título real es "severity, error_if, and warn_if"; no existen páginas separadas `reference/resource-configs/warn_if` o `.../error_if` (se intentó `warn_if` directamente y devolvió HTTP 404 — confirmado por fetch fallido, no por suposición).

### 1.2 `error_if`/`warn_if` — sobre qué número operan exactamente (hallazgo importante para el draft)

Defaults de `error_if`/`warn_if`: `!=0` (ambos). Las expresiones condicionales aceptan cualquier lógica de comparación SQL: `> 5`, `= 0`, `between 5 and 10`.

**Cita textual del FAQ oficial dedicado:**

> "You can use the `error_if` and `warn_if` configs to set custom failure thresholds in your tests."

Y ejemplo de uso citado en la misma familia de docs: "1 duplicate record can count as a warning, but 10 duplicate records should count as an error."

Fuentes: [faqs/Tests/custom-test-thresholds](https://docs.getdbt.com/faqs/Tests/custom-test-thresholds), [reference/resource-configs/severity](https://docs.getdbt.com/reference/resource-configs/severity).

**Punto que el draft debe matizar**: `error_if`/`warn_if` comparan contra el resultado de `fail_calc`, cuyo **default es `count(*)`** — es decir, por defecto operan sobre el **número absoluto de filas que fallan**, no sobre un porcentaje del total de filas evaluadas. Cita textual de la página de `fail_calc`:

> "Test queries are written to return a set of failing records... Most often, this is the count of rows returned by the test query: the default value of `fail_calc` is `count(*)`. But it can also be a custom calculation, whether an aggregate calculation or simply the name of a column to be selected from the test query."

Ejemplo de `fail_calc` personalizado que sí cita la doc (agregación, no conteo simple): `fail_calc: "sum(total_revenue) - sum(revenue_accounted_for)"`. La doc no publica ningún ejemplo con un cálculo de porcentaje/ratio — es técnicamente alcanzable (escribir un `fail_calc` que devuelva un porcentaje y comparar `error_if: "> 5"` contra ese porcentaje), pero **no es el comportamiento out-of-the-box**; requiere una expresión `fail_calc` custom.

Fuente: [reference/resource-configs/fail_calc](https://docs.getdbt.com/reference/resource-configs/fail_calc).

**Veredicto para el draft**: el ejemplo del draft — *"si más del 5% de las filas fallan validez, abort; si menos, cuarentena y alerta"** — es alcanzable con dbt, pero el mecanismo nativo (`error_if`/`warn_if` con default `fail_calc = count(*)`) opera sobre **conteo absoluto de filas fallidas**, no porcentaje, salvo que se escriba explícitamente un `fail_calc` que calcule el porcentaje. Si el skill va a mostrar este ejemplo con sintaxis real de dbt, debe o (a) usar un umbral en conteo absoluto (fiel al mecanismo default), o (b) mostrar explícitamente el `fail_calc` porcentual custom — no presentar `error_if: ">5"` como si automáticamente significara "5% de las filas" sin la config adicional.

### 1.3 `store_failures` / `store_failures_as` — ¿es una zona de cuarentena real?

**Cita textual de la definición** (`store_failures`):

> "The configured test(s) will store their failures when `dbt test --store-failures` is invoked. If you set this configuration as `false` but `store_failures_as` is configured, it will be overridden."

Comportamiento confirmado:
- Si `store_failures` es `true`, dbt **guarda todas las filas** (hasta el límite configurado por `limit`) que fallaron el test **en una tabla nueva nombrada según el test**.
- Ubicación por defecto: schema `{{ profile.schema }}_dbt_test__audit` (configurable vía `schema` config).
- Comportamiento de reemplazo: los resultados de un test **siempre reemplazan** las fallas anteriores del mismo test, incluso si en la corrida actual no hay fallas nuevas.
- Si no se especifica (`none`/omitido), usa el valor del flag `--store-failures` de la CLI. Si se especifica explícitamente `true`/`false`, eso tiene precedencia sobre el flag.

`store_failures_as` (config relacionada, tiene precedencia sobre `store_failures` si ambas están configuradas) acepta tres valores:
- `ephemeral` — nada se almacena en la base de datos (default).
- `table` — las fallas se almacenan como tabla.
- `view` — las fallas se almacenan como vista.

Sintaxis exacta (nivel proyecto, todas las capas):

```yaml
data_tests:
  +store_failures: true  # all tests
  <package_name>:
    +store_failures: false # tests in specific package
```

```yaml
data_tests:
  my_project:
    +store_failures_as: table
  my_subfolder_1:
    +store_failures_as: view
  my_subfolder_2:
    +store_failures_as: ephemeral
```

Y a nivel de test individual (generic o singular), incluyendo bloque `config()` en `.sql`.

**Cita textual adicional** (página `docs/build/data-tests`, sección de storing failures):

> "Normally, a data test query will calculate failures as part of its execution. If you set the optional `--store-failures` flag, the `store_failures`, or the `store_failures_as` configs, dbt will first save the results of a test query to a table in the database, and then query that table to calculate the number of failures." ... "This workflow allows you to query and examine failing records much more quickly in development."

Fuentes: [reference/resource-configs/store_failures](https://docs.getdbt.com/reference/resource-configs/store_failures), [reference/resource-configs/store_failures_as](https://docs.getdbt.com/reference/resource-configs/store_failures_as), [docs/build/data-tests](https://docs.getdbt.com/docs/build/data-tests), [reference/data-test-configs](https://docs.getdbt.com/reference/data-test-configs) (lista consolidada de configs de test: `fail_calc`, `limit`, `severity`, `error_if`, `warn_if`, `store_failures`, `where`, `sql_header`) — todas fetch directo.

**VEREDICTO CLAIM 1 (el más importante del research):**

- **`severity: warn|error` + `error_if`/`warn_if` = SÍ es exactamente el mecanismo real y documentado de "umbral tolerable, no perfección binaria"** que describe el draft. La cita del propio FAQ de dbt ("1 duplicate record can count as a warning, but 10 duplicate records should count as an error") es prácticamente el mismo ejemplo pedagógico que el draft usa, solo que en conteo absoluto en vez de porcentaje.
- **`store_failures`/`store_failures_as` = SÍ implementa el patrón de "cuarentena" descrito por el draft, con una precisión**: no desvía automáticamente las filas malas fuera del flujo principal del pipeline (dbt sigue construyendo el modelo normalmente con todas las filas, buenas y malas, salvo que el modelo mismo filtre); lo que hace es **crear una tabla/vista separada con las filas que fallaron el test**, para inspección y reprocesamiento posterior — que es exactamente la definición operativa de cuarentena del draft ("desviar los registros malos a una zona de cuarentena... dejar pasar los buenos... poder inspeccionar/reprocesar después"), con el matiz de que en dbt la "cuarentena" es del *resultado del test* (evidencia de qué falló), no necesariamente una tabla productiva ya limpia de esas filas — el draft no distingue esa diferencia y sería valioso que el skill sí lo haga.
- El draft describe correctamente el espíritu del mecanismo; la única corrección técnica necesaria es el matiz de **conteo absoluto vs. porcentaje** en `error_if`/`warn_if` (§1.2).

---

## 2. Great Expectations — acciones de Checkpoint para reaccionar ante un fallo (API 1.x)

**Punto de partida** (ya confirmado en research previo, no re-verificado aquí): la API actual de Checkpoints es `gx.Checkpoint(name=..., validation_definitions=[...], actions=[...])` + `context.checkpoints.add()` — ver `2026-08-03-quality-wshobson-agents-review.md` §2.1.

### 2.1 Lista completa y definitiva de Actions, verificada contra el código fuente real

Se verificó contra `docs.greatexpectations.io` (páginas de referencia de API) **y**, para obtener la lista completa y no solo ejemplos parciales de la doc, directamente contra el archivo fuente `great_expectations/checkpoint/actions.py` del repo oficial, en el tag `1.19.1` — confirmado como la versión actual publicada en PyPI (`pip index`/PyPI JSON API consultado el 2026-08-03: `"version": "1.19.1"`). El listado de clases (`grep -n "^class "` sobre el archivo en ese tag exacto) es:

```
class ActionContext
class ValidationActionRegistry
class MetaValidationAction(ModelMetaclass)
class ValidationAction(BaseModel, metaclass=MetaValidationAction)   # clase base
class DataDocsAction(ValidationAction)                              # clase base intermedia
class SlackNotificationAction(DataDocsAction)
class PagerdutyAlertAction(ValidationAction)
class MicrosoftTeamsNotificationAction(ValidationAction)
class OpsgenieAlertAction(ValidationAction)
class EmailAction(ValidationAction)
class UpdateDataDocsAction(DataDocsAction)
class SNSNotificationAction(ValidationAction)
class APINotificationAction(ValidationAction)
```

Fuente: [github.com/great-expectations/great_expectations, blob `1.19.1`, `great_expectations/checkpoint/actions.py`](https://github.com/great-expectations/great_expectations/blob/1.19.1/great_expectations/checkpoint/actions.py) (fetch directo del raw file, confirmado idéntico entre el tag `1.19.1` y la rama `develop`).

**Las 7 Actions concretas disponibles para reaccionar ante un fallo de Checkpoint, con su propósito citado textualmente del docstring fuente:**

| Action | Qué hace (cita textual del docstring) |
|---|---|
| `UpdateDataDocsAction` | "Notify the site builders of all data docs sites of a Data Context that a validation result should be added to the data docs." |
| `SlackNotificationAction` | "Sends a Slack notification to a given webhook." Parámetro `notify_on`: uno de `"all"`, `"failure"`, `"success"` (default `"all"` en el código fuente: `notify_on: NotifyOn = "all"`). |
| `EmailAction` | "Sends an email to a given list of email addresses." |
| `PagerdutyAlertAction` | "Sends a PagerDuty event." Parámetros: `api_key`, `routing_key`, `notify_on` (default `"failure"` según la doc de referencia), `severity` (uno de `"critical"`, `"error"`, `"warning"`, `"info"`). |
| `MicrosoftTeamsNotificationAction` | "Sends a Microsoft Teams notification to a given webhook." |
| `OpsgenieAlertAction` | "Sends an Opsgenie alert." |
| `SNSNotificationAction` | "Action that pushes validations results to an SNS topic with a subject of passed or failed." |
| `APINotificationAction` | (sin docstring en el código fuente; expone un parámetro `url` — action que envía el resultado de validación vía POST HTTP a una API custom). |

Todas (salvo `UpdateDataDocsAction` y `APINotificationAction`) exponen un parámetro `notify_on` con valores del tipo `Literal['all', 'success', 'failure', 'info', 'warning', 'critical']` — es decir, **sí se pueden condicionar para disparar solo ante fallo** (`notify_on="failure"`), confirmado en el código fuente y en la doc de `SlackNotificationAction`.

Ejemplo de sintaxis real (`docs/core/trigger_actions_based_on_results/create_a_checkpoint_with_actions/`, fetch directo):

```python
import great_expectations as gx
from great_expectations.checkpoint import (
    SlackNotificationAction,
    UpdateDataDocsAction,
)

action_list = [
    SlackNotificationAction(
        name="send_slack_notification_on_failed_expectations",
        slack_token="${validation_notification_slack_webhook}",
        slack_channel="${validation_notification_slack_channel}",
        notify_on="failure",
        show_failed_expectations=True,
    ),
    UpdateDataDocsAction(
        name="update_all_data_docs",
    ),
]
```

Fuentes: [docs/core/trigger_actions_based_on_results/create_a_checkpoint_with_actions](https://docs.greatexpectations.io/docs/core/trigger_actions_based_on_results/create_a_checkpoint_with_actions/), [docs/reference/api/checkpoint/microsoftteamsnotificationaction_class](https://docs.greatexpectations.io/docs/reference/api/checkpoint/microsoftteamsnotificationaction_class/), [docs/reference/api/checkpoint/pagerdutyalertaction_class](https://docs.greatexpectations.io/docs/reference/api/checkpoint/pagerdutyalertaction_class/), [docs/reference/api/checkpoint/updatedatadocsaction_class](https://docs.greatexpectations.io/docs/reference/api/checkpoint/updatedatadocsaction_class/), más el código fuente citado arriba.

### 2.2 `StoreValidationResultAction` — confirmado que **ya no existe** en la API 1.x actual

El research previo (`2026-08-03-quality-wshobson-agents-review.md`) dejó pendiente si `StoreValidationResultAction` seguía vigente. Se verificó específicamente aquí:

- La URL de documentación no-versionada (`docs.greatexpectations.io/docs/reference/api/checkpoint/storevalidationresultaction_class/`) **redirige/sirve contenido marcado explícitamente como de la versión 0.18.21**, con el banner: *"This is documentation for Great Expectations 0.18.21, which is no longer actively maintained. For up-to-date documentation, see the latest version (1.19.1)."* — es decir, esa página **no tiene una versión "current" propia**, solo existe archivada bajo la doc de 0.18.
- Búsqueda de código directa sobre el repo oficial (`gh api search/code -f q='StoreValidationResultAction repo:great-expectations/great_expectations'`) devuelve **`"total_count":0`** — cero coincidencias en todo el repositorio actual.
- La navegación "Previous/Next" en la página actual de `UpdateDataDocsAction` va de `SlackNotificationAction` → `UpdateDataDocsAction` → `ValidationAction` (orden alfabético), **sin `StoreValidationResultAction` en medio** (que alfabéticamente iría entre `SlackNotificationAction` y `UpdateDataDocsAction` si existiera).

**Veredicto**: `StoreValidationResultAction` (así como `StoreEvaluationParametersAction` y `StoreMetricsAction`, mencionadas en el mismo PR histórico de docs de GX) eran parte de la API V0 (pre-2024) y **fueron eliminadas** de la API 1.x — no aparecen en el código fuente actual ni en la documentación no-versionada. Esto confirma con evidencia directa (no solo ausencia de documentación) el hallazgo que el research anterior dejaba como sospecha.

### 2.3 VEREDICTO CLAIM 2

Las acciones de reacción-ante-fallo oficiales y vigentes en GX 1.x son: `UpdateDataDocsAction`, `SlackNotificationAction`, `EmailAction`, `PagerdutyAlertAction`, `MicrosoftTeamsNotificationAction`, `OpsgenieAlertAction`, `SNSNotificationAction`, `APINotificationAction` — 7 acciones "reactivas" concretas más la clase base `ValidationAction` para acciones custom. Todas (salvo `UpdateDataDocsAction`/`APINotificationAction`) soportan condicionamiento explícito `notify_on="failure"`. `StoreValidationResultAction` (mencionada en el pedido como pregunta abierta) **NO existe en la API actual** — confirmado por ausencia total en el código fuente del repo, no solo en la doc.

---

## 3. Vendors — ¿alguno usa "quarantine" oficialmente, y cómo lo implementa?

### 3.1 AWS Glue Data Quality — SÍ usa el término, de forma explícita pero como concepto/patrón manual, no como feature automática

Cita textual literal de la página de overview del producto (lista de "Benefits and key features"):

> "**Zero in on bad data** – AWS Glue Data Quality helps you identify the exact records that caused your quality scores to go down. Easily identify them, **quarantine and fix them**."

Fuente: [docs.aws.amazon.com/glue/latest/dg/glue-data-quality.html](https://docs.aws.amazon.com/glue/latest/dg/glue-data-quality.html) (fetch directo).

**Cómo se implementa técnicamente** (verificado con el tutorial oficial de notebooks, con código real, fetch directo): AWS Glue Data Quality **no crea automáticamente una tabla de cuarentena**. El mecanismo real es que la transformación `EvaluateDataQuality` produce una colección `rowLevelOutcomes`, un DataFrame con **cuatro columnas nuevas añadidas a cada fila del dataset original**:

- `DataQualityRulesPass` (array de reglas que pasaron)
- `DataQualityRulesFail` (array de reglas que fallaron)
- `DataQualityRulesSkip` (array de reglas saltadas)
- `DataQualityEvaluationResult` (`"Passed"` / `"Failed"` — resultado agregado a nivel de fila)

El desarrollador es quien **filtra manualmente** ese DataFrame (`rowLevelOutcomes_df.filter(rowLevelOutcomes_df.DataQualityEvaluationResult == "Passed")`) y escribe los subconjuntos a destinos separados. Ejemplo real citado del tutorial oficial:

```python
rowLevelOutcomes_df = rowLevelOutcomes.toDF()
rowLevelOutcomes_df_passed = rowLevelOutcomes_df.filter(
    rowLevelOutcomes_df.DataQualityEvaluationResult == "Passed"
)
rowLevelOutcomes_df.filter(
    rowLevelOutcomes_df.DataQualityEvaluationResult == "Failed"
).show(5, truncate=False)

# Write the Passed records to the destination.
glueContext.write_dynamic_frame.from_options(
       frame = rowLevelOutcomes_df_passed,
       connection_type = "s3",
       connection_options = {"path": "s3://glue-sample-target/output-dir/medicare_parquet"},
       format = "parquet")
```

Fuente: [docs.aws.amazon.com/glue/latest/dg/data-quality-gs-studio-notebooks.html](https://docs.aws.amazon.com/glue/latest/dg/data-quality-gs-studio-notebooks.html) (fetch directo, código reproducido verbatim).

**Matiz importante**: el mecanismo es un **flag/columna por fila** (`DataQualityEvaluationResult`), no una tabla de cuarentena separada automática. "Cuarentena" en AWS Glue es el nombre que AWS le da al *patrón* que tú construyes con esas columnas de resultado, no una feature de un clic.

### 3.2 Databricks (Lakeflow Declarative Pipelines / antes DLT) — SÍ usa el término, con un patrón documentado completo, código incluido

Databricks documenta una sección dedicada y titulada explícitamente **"Quarantine invalid records"**, dentro de su página oficial de patrones de expectations. Cita textual de la introducción del patrón:

> "This pattern combines expectations with temporary tables and views to track data quality metrics during pipeline updates and enable separate processing paths for valid and invalid records in downstream operations."

**Implementación exacta** (tres piezas, código Python real citado verbatim de la doc oficial):

1. Una columna booleana calculada, `is_quarantined`, que evalúa la negación de las reglas de validez.
2. Una tabla temporal **particionada por esa columna booleana** (`partition_cols=["is_quarantined"]`) que contiene *todas* las filas (buenas y malas), sin duplicar datos.
3. Dos vistas descendentes que filtran sobre esa partición: `valid_trips_data` (`is_quarantined=false`) y `invalid_trips_data` (`is_quarantined=true`).

```python
from pyspark import pipelines as dp
from pyspark.sql.functions import expr

rules = {
  "valid_pickup_zip": "(pickup_zip IS NOT NULL)",
  "valid_dropoff_zip": "(dropoff_zip IS NOT NULL)",
}
quarantine_rules = "NOT({0})".format(" AND ".join(rules.values()))

@dp.view
def raw_trips_data():
  return spark.readStream.table("samples.nyctaxi.trips")

@dp.table(
  temporary=True,
  partition_cols=["is_quarantined"],
)
@dp.expect_all(rules)
def trips_data_quarantine():
  return (
    spark.readStream.table("raw_trips_data").withColumn("is_quarantined", expr(quarantine_rules))
  )

@dp.view
def valid_trips_data():
  return spark.read.table("trips_data_quarantine").filter("is_quarantined=false")

@dp.view
def invalid_trips_data():
  return spark.read.table("trips_data_quarantine").filter("is_quarantined=true")
```

(La doc también incluye la versión SQL equivalente con `CREATE OR REFRESH TEMPORARY STREAMING TABLE ... PARTITIONED BY (is_quarantined)` — mismo patrón, sintaxis declarativa.)

Fuente: [docs.databricks.com/aws/en/dlt/expectation-patterns](https://docs.databricks.com/aws/en/dlt/expectation-patterns) (sección "Quarantine invalid records", fetch directo, código reproducido verbatim). Mismo contenido replicado en la versión Azure de la doc ([learn.microsoft.com/en-us/azure/databricks/ldp/expectations](https://learn.microsoft.com/en-us/azure/databricks/ldp/expectations), no fetcheada en detalle aquí — solo confirmada su existencia por búsqueda, dado que ya se verificó el contenido completo en la versión AWS/genérica).

### 3.3 VEREDICTO CLAIM 3

**Sí hay al menos dos vendors mayores que usan el término "quarantine" explícitamente y de forma oficial**: AWS Glue Data Quality y Databricks (Lakeflow Declarative Pipelines / DLT). No hace falta inventar ni forzar una fuente — ambos están confirmados por fetch directo con cita textual y código real.

**Diferencia relevante para el skill**: los dos vendors implementan "cuarentena" con el **mismo patrón estructural de fondo** — una columna/flag booleana que marca la fila como inválida, y luego separación (filtrado o escritura a destino distinto) basada en ese flag — **no** con una feature de "mover automáticamente las filas malas a otra tabla" de un clic. Esto es coherente con lo que dbt hace con `store_failures` (§1.3): ningún vendor de los tres provee "cuarentena" como una operación mágica de un solo flag sin código/config adicional; todos requieren que el pipeline explícitamente separe basándose en un resultado de evaluación (columna de flag en AWS Glue/Databricks, tabla de fallas separada en dbt). El draft puede citar esto como refuerzo: "cuarentena" es un patrón arquitectónico consistente entre herramientas (marca + separa), no una feature uniforme con la misma UX en todas.

---

## 4. El argumento de "coste asimétrico del error" — ¿fuente de ingeniería de datos, o principio general?

**Búsqueda realizada**: se buscó explícitamente una fuente primaria de ingeniería de datos (vendor serio, paper, o documentación oficial) que formalice "coste asimétrico del error" **aplicado específicamente a la elección de política de calidad de datos en pipelines**. No se encontró ninguna.

**Lo que sí se encontró, y es la genealogía real del concepto:**

- Es terminología estándar de **teoría de decisión estadística / clasificación con costos** (*cost-sensitive classification*): cuando el costo de un falso positivo (C₀₁) difiere del costo de un falso negativo (C₁₀), el umbral de decisión óptimo se calcula como `τ = C₀₁ / (C₀₁ + C₁₀)` — un resultado de teoría de decisión bayesiana, no específico de ningún dominio de datos.
- Su antecedente formal más citado es el **framework de Neyman-Pearson** (error Tipo I vs. Tipo II en contraste de hipótesis): el paradigma NP busca minimizar el error Tipo II mientras se controla el error Tipo I bajo un nivel deseado — la asimetría de costos entre "rechazar una hipótesis nula verdadera" y "no rechazar una falsa" es el mismo esqueleto conceptual que "abortar el pipeline innecesariamente" vs. "dejar pasar un dato malo".
- Ejemplos de aplicación real de este principio que sí aparecen en literatura seria son de **otros dominios** (detección de fraude, ensayos clínicos/aprobación de fármacos, clasificación de ML en producción) — no de ingeniería de datos/pipelines específicamente.

**Veredicto**: el argumento de "coste asimétrico" es **una aplicación razonable y bien fundamentada de un principio general de teoría de decisión/estadística** (Neyman-Pearson, clasificación cost-sensitive) — no una idea inventada ni forzada — pero **no existe, hasta donde este research pudo verificar, una fuente primaria de ingeniería de datos (vendor, paper, documentación oficial) que lo formalice específicamente para la elección de política de calidad de datos en pipelines**. Si el skill quiere usar este argumento (que es legítimo y potente pedagógicamente), debe presentarse explícitamente como una aplicación de un principio general de estadística/teoría de decisión al dominio de calidad de datos — no como algo que "la industria de data engineering ya formalizó así" citando una fuente que no existe. Es exactamente el tipo de honestidad epistémica que las reglas de este research piden no forzar.

---

## Resumen de acciones para el skill

1. **`severity`/`error_if`/`warn_if` es la cita perfecta para "umbrales, no absolutos"** — usar la sintaxis real (`severity: error`, `error_if: ">1000"`, `warn_if: ">10"`) y, si se usa el ejemplo del 5%, aclarar que requiere un `fail_calc` custom porcentual (el default es conteo absoluto de filas).
2. **`store_failures`/`store_failures_as` es la cita real para "cuarentena" en dbt** — con el matiz de que crea una tabla/vista de *evidencia de fallas* (`{schema}_dbt_test__audit`), no necesariamente reenruta las filas malas fuera del modelo productivo salvo que el modelo mismo las filtre.
3. **Great Expectations 1.x tiene 7 Actions reactivas reales** (`UpdateDataDocsAction`, `SlackNotificationAction`, `EmailAction`, `PagerdutyAlertAction`, `MicrosoftTeamsNotificationAction`, `OpsgenieAlertAction`, `SNSNotificationAction`, `APINotificationAction`) condicionables vía `notify_on="failure"` — útil para mostrar cómo se implementa "drop con alerta" de forma real con código verificado contra fuente. `StoreValidationResultAction` está confirmada como eliminada de la API actual (no solo desactualizada).
4. **"Cuarentena" como término oficial de vendor**: AWS Glue Data Quality y Databricks lo usan explícitamente — buen material para reforzar que Capa 2 del draft no es jerga inventada, sino vocabulario real de la industria. Ambos implementan el patrón vía columna-flag + separación, mismo esqueleto que dbt.
5. **Coste asimétrico**: presentar como principio general de teoría de decisión (Neyman-Pearson / cost-sensitive classification) aplicado al dominio, no como framework nativo de data engineering — no forzar una cita que no existe.

**Nota de honestidad epistémica**: no se investigó en profundidad la versión SQL declarativa completa del patrón de cuarentena de Databricks (solo se cita, no se verificó línea por línea contra la doc como se hizo con la versión Python) ni la documentación específica de Azure Databricks para ese mismo patrón (se asume idéntica por ser la misma plataforma, no se fetcheó por separado). Los defaults `notify_on="all"` (`SlackNotificationAction`) y `notify_on="failure"` (`PagerdutyAlertAction`) fueron confirmados directamente contra el código fuente (`1.19.1`): `notify_on: NotifyOn = "all"` y `notify_on: NotifyOn = "failure"` respectivamente — mismo nivel de rigor para ambos.
