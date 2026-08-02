# Research: revisión de `wshobson/agents`' `dbt-transformation-patterns` (MIT) — insumo secundario para la brecha de arquitectura de proyecto dbt en `pipelines-architecture-data-engineering`

**Fecha:** 2026-08-02
**Alcance:** uno de tres agentes de investigación en paralelo para cerrar la brecha, ya identificada, de que `pipelines-architecture-data-engineering` hoy solo menciona dbt de forma ilustrativa ("el orquestador invoca cómputo externo") sin cubrir la arquitectura de proyecto de dbt propiamente (medallion, naming conventions, DAG de modelos, `dbt_project.yml`) — brecha ya anotada explícitamente en `docs/superpowers/specs/2026-07-28-sql-skill-design.md` §2 al decidir que ese contenido no pertenece a `sql-data-engineering`. Los otros dos agentes investigan en paralelo la documentación oficial de dbt (docs.getdbt.com) sobre estructura de proyecto y sobre naming/entornos/packages, directamente como fuente primaria. Este documento cubre solo la fuente secundaria de terceros: `plugins/data-engineering/skills/dbt-transformation-patterns/` de `wshobson/agents` — mismo tratamiento metodológico que ya recibió `spark-optimization` (`2026-07-29-spark-claims-verification.md` §7) y `airflow-dag-patterns` (nota 2026-07-30 en `docs/superpowers/plans/2026-07-30-pipelines-architecture-skill-implementation.md`, línea ~1086): revisar con atribución, no adoptar verbatim, y re-verificar cualquier claim técnico contra la documentación oficial de dbt en vez de confiar en la fuente a ojo.

**Método:** contenido obtenido vía `gh api repos/wshobson/agents/contents/.../SKILL.md --jq '.content' | base64 -d` (y lo mismo para `references/details.md`) — no WebFetch, para tener el texto exacto sin resumen intermedio. Los claims técnicos de dbt se verificaron por `curl` directo contra `docs.getdbt.com` (HTML crudo parseado con Python/regex, no vía WebFetch — el resumen de WebFetch sobre la tabla de soporte de `incremental_strategy` resultó ambiguo/potencialmente incorrecto al mapear checkmarks a columnas, así que se descartó como fuente de verificación y se usó el HTML crudo en su lugar).

---

## 1. Resumen fiel del contenido

La skill son dos archivos: `SKILL.md` (114 líneas, navegación + quick start) y `references/details.md` (447 líneas, 7 "patterns" + comandos). No tiene más reference files — a diferencia de `spark-optimization`, que sí traía varios.

### 1.1 `SKILL.md`

- **Frontmatter**: `name: dbt-transformation-patterns`, `description` genérica ("Master dbt... with model organization, testing, documentation, and incremental strategies"). Sin número de versión de dbt en ningún lado del frontmatter ni del cuerpo.
- **Model Layers (Medallion Architecture)**: `sources/ → staging/ → intermediate/ → marts/`, con una línea de propósito por capa.
- **Naming Conventions** (tabla): `stg_` (staging), `int_` (intermediate), `dim_`/`fct_` (marts) — con ejemplos (`stg_stripe__payments`, `int_payments_pivoted`, `dim_customers`, `fct_orders`).
- **Quick Start**: un `dbt_project.yml` completo (paths, `vars`, config de materialización por carpeta: `staging` → `view`, `intermediate` → `ephemeral`, `marts` → `table`, con `+schema` por capa) y un árbol de directorios de ejemplo (`models/staging/stripe/...`, `models/intermediate/finance/int_payments_pivoted.sql`, `models/marts/core/...`, `models/marts/finance/fct_revenue.sql`).
- Remite a `references/details.md` para los patterns detallados.
- **Best Practices** (Do's/Don'ts): usar staging siempre, testear agresivamente, documentar todo, incremental para tablas >1M filas, versionar en Git / no saltarse staging, no hardcodear fechas (usar `{{ var('start_date') }}`), no repetir lógica (macros), no testear en prod, no ignorar freshness.

### 1.2 `references/details.md` — 7 patterns + comandos

1. **Source Definitions** (`_stripe__sources.yml`): `version: 2`, `freshness` (`warn_after`/`error_after`), tests `unique`/`not_null`/`relationships` a nivel de columna de source.
2. **Staging Models**: modelo 1:1 con la fuente (`stg_stripe__customers.sql`, renombrado de columnas, sin lógica de negocio) y un segundo ejemplo incremental (`stg_stripe__payments.sql`) con `materialized='incremental'`, `unique_key='payment_id'`, `on_schema_change='append_new_columns'`, filtro `is_incremental()` contra `_fivetran_synced`.
3. **Intermediate Models**: `int_payments_pivoted_to_customer.sql`, joins/agregaciones de negocio sobre modelos de staging vía `ref()`.
4. **Mart Models**: `dim_customers.sql` (surrogate key vía `dbt_utils.generate_surrogate_key`, tiering condicional) y `fct_orders.sql` (incremental, `unique_key='order_id'`, `incremental_strategy='merge'`).
5. **Testing and Documentation**: `_core__models.yml` con tests genéricos (`unique`, `not_null`, `accepted_values`, `relationships`) y tests de paquete `dbt_utils` (`dbt_utils.expression_is_true`, `dbt_utils.recency`).
6. **Macros and DRY Code**: `cents_to_dollars`, `generate_schema_name` (macro estándar de override de esquema — coincide casi textual con el ejemplo oficial de dbt para custom schemas), `limit_data_in_dev` (limitar volumen en `target.name == 'dev'`).
7. **Incremental Strategies**: tres bloques de config comentados — `delete+insert` etiquetado como *"(default for most warehouses)"*, `merge` etiquetado *"(best for late-arriving data)"* con `merge_update_columns`, e `insert_overwrite` con `partition_by`.
8. **dbt Commands**: `dbt run`/`--select`/`+model`/`model+`/`--full-refresh`, `dbt test`, `dbt build`, `dbt docs generate`/`serve`, `dbt compile`, `dbt debug`, `dbt ls --select tag:critical`.

No hay ninguna mención a dbt Cloud (ni UI, ni jobs, ni IDE) en todo el contenido — a diferencia de lo que se podría esperar como vector de vejez, esta fuente es 100% dbt-core/CLI. Tampoco declara un número de versión de dbt-core en ningún punto.

---

## 2. Vejez/errores encontrados, con evidencia

### 2.1 Error factual: "delete+insert (default for most warehouses)" — INCORRECTO

`references/details.md`, Pattern 7, etiqueta el bloque `delete+insert` como *"(default for most warehouses)"*. Verificado directo contra `docs.getdbt.com` (páginas de configuración por adaptador, `curl` crudo, no resumen de agente):

- **Snowflake**: *"By default, dbt will use a merge statement on Snowflake to refresh incremental tables."* — fuente: [Snowflake configurations](https://docs.getdbt.com/reference/resource-configs/snowflake-configs), sección "Merge behavior (incremental models)".
- **BigQuery**: *"dbt uses a merge statement on BigQuery to refresh incremental tables. The incremental_strategy config can be set to one of the following values: merge (default) insert_overwrite microbatch"* — fuente: [BigQuery configurations](https://docs.getdbt.com/reference/resource-configs/bigquery-configs).
- **Redshift**: *"append (default when unique_key is not defined) merge delete+insert (default when unique_key is defined) microbatch. All of these strategies are inherited from dbt-postgres."* — fuente: [Redshift configurations](https://docs.getdbt.com/reference/resource-configs/redshift-configs).
- **Postgres**: idéntico texto — *"append (default when unique_key is not defined) ... delete+insert (default when unique_key is defined)"* — fuente: [Postgres configurations](https://docs.getdbt.com/reference/resource-configs/postgres-configs).

**Veredicto: el claim es falso tal como está escrito.** `delete+insert` no es el default de "la mayoría de los warehouses" — es el default *condicional* (solo cuando hay `unique_key`) en Postgres y Redshift únicamente; Snowflake y BigQuery, dos de los warehouses más usados con dbt, defaultean a `merge` sin condición. Esto es exactamente el tipo de imprecisión que ya se documentó en esta misma fuente de terceros para otro dominio (`airflow-dag-patterns`, nota 2026-07-30 en el plan de implementación de esta skill: contenido sin awareness de versión + inconsistencia interna) — refuerza que esta fuente necesita re-verificación puntual, no confianza a ojo. Nota adicional a favor de la suite: esto confirma, con evidencia directa, que la cobertura ya existente en `sql-data-engineering` ("`unique_key` → merge vs. delete+insert **según el adaptador**") es más precisa que la generalización de esta fuente — no hay nada que corregir en la suite a partir de este hallazgo, solo una razón más para no importar la formulación de wshobson tal cual si algún día se toca este tema en cualquier skill.

### 2.2 Inconsistencia interna: nombre de archivo no coincide entre `SKILL.md` y `references/details.md`

`SKILL.md` (árbol de directorios, "Quick Start") lista el modelo intermedio como:

```
intermediate/
    └── finance/
        └── int_payments_pivoted.sql
```

Pero el ejemplo real en `references/details.md` (Pattern 3) es:

```sql
-- models/intermediate/finance/int_payments_pivoted_to_customer.sql
```

Nombres distintos (`int_payments_pivoted.sql` vs. `int_payments_pivoted_to_customer.sql`) para lo que se presenta como el mismo modelo dentro del mismo skill. Es una inconsistencia interna menor — no invalida el patrón que ilustra (medallion + naming) — pero es la misma clase de descuido ya detectado en `airflow-dag-patterns` de esta misma fuente (ahí, un test que aserta el atributo deprecado `dag.schedule_interval` mientras las definiciones de DAG del propio skill ya usan `schedule=`). Patrón repetido: esta fuente no se corrige internamente entre sus propios archivos.

### 2.3 Ausencia total de versión de dbt — no bloqueante, pero digno de nota

Ni `SKILL.md` ni `references/details.md` mencionan una versión de dbt-core, dbt-utils, ni de ningún adaptador en ningún punto. A diferencia del caso de `airflow-dag-patterns` (donde la ausencia de versión sí llevaba a contenido activamente deprecado — `schedule_interval`), aquí no encontré ningún caso concreto de sintaxis deprecada por esta razón: `on_schema_change`, `merge_update_columns`, los operadores de grafo (`+model`/`model+`), `dbt build`, y la sintaxis de `config-version`/materializaciones usada siguen siendo válidas en el dbt-core/Fusion actual (confirmado contra `docs.getdbt.com/reference/dbt_project.yml`, fetch directo). Aun así, el patrón se repite: esta fuente nunca se ancla a una versión, así que cualquier adopción debe re-verificarse contra la documentación oficial en el momento de escribirla, no asumirse vigente por default — mismo criterio ya aplicado al resto de revisiones de `wshobson/agents` en esta suite.

---

## 3. Comparación contra lo que la suite ya cubre

Según el resumen aportado para esta tarea:

- **`sql-data-engineering`** ya cubre, verificado contra dbt: mecánica de modelos incrementales (`unique_key` → merge vs. delete+insert según adaptador), semántica de `dbt --full-refresh` (drop-and-recreate, necesario tras quitar una columna de un modelo), y tests genéricos de dbt como aserciones SQL. Todo esto es exactamente el terreno de los Patterns 5 y 7 de esta fuente — **sin aporte nuevo**, y con el error del §2.1 ya identificado en el propio wshobson que la cobertura actual de la suite no comete. La mención de `dbt run --full-refresh` en el listado de comandos (§1.2, punto 8) es consistente con lo ya cubierto, no lo contradice.
- **`pipelines-architecture-data-engineering`** solo menciona dbt ilustrativamente hoy ("el orquestador invoca cómputo externo") — esta es la brecha real. El contenido de esta fuente que cae en esa brecha (medallion, naming, `dbt_project.yml`, DAG de modelos vía `ref()`/`source()`) es justamente lo que corrobora — no descubre en solitario — lo que los otros dos agentes de investigación están sacando directo de docs.getdbt.com. Tratar esta fuente como corroboración secundaria de ese contenido, no como fuente primaria para redactarlo.

---

## 4. Recomendación: qué adoptar, qué no, y por qué

### Adoptar (con atribución, adaptado — no verbatim)

- **Capas medallion aplicadas a dbt** (`sources → staging → intermediate → marts`) y el principio de "staging 1:1 con la fuente, sin lógica de negocio; intermediate = joins/agregaciones; marts = tablas finales de consumo". Encaja exactamente en la brecha de arquitectura de proyecto — pero redactar con las convenciones oficiales de dbt como fuente primaria (los otros dos agentes las están sacando directo de docs.getdbt.com); esta fuente solo corrobora que el patrón es real y usado en la práctica.
- **Patrón de configuración de materialización por carpeta en `dbt_project.yml`** (`+materialized: view` en staging, `ephemeral` en intermediate, `table` en marts, `+schema` por capa) — es exactamente el tipo de decisión de arquitectura de proyecto (no de sintaxis SQL) que le falta a `pipelines-architecture-data-engineering` hoy. Adoptar el patrón, no el YAML literal.
- **El concepto de "DAG de modelos" de dbt como un DAG anidado dentro de una sola tarea del orquestador** — `ref()`/`source()` construyen un grafo de dependencias *dentro* de dbt, separado del DAG de Airflow/Dagster que lo invoca. Esta fuente no lo explica así explícitamente, pero sus propios ejemplos (staging → intermediate → marts encadenados vía `ref()`) son la ilustración perfecta del punto, y es un ángulo que la doc oficial de dbt no enmarca desde la perspectiva de "cómo encaja con el orquestador" — vale la pena como aporte de framing propio de esta skill, con los ejemplos de esta fuente como apoyo.
- **Selección de modelos por grafo** (`dbt run --select +fct_orders` / `fct_orders+`) como gancho hacia la decisión de granularidad de orquestación (¿una sola tarea `dbt build` completa, o Airflow orquestando selección fina de modelos?) — relevante para esta skill de forma que no lo es para `sql-data-engineering`.

**Nota de solapamiento**: naming conventions y estructura de carpetas también están siendo investigadas en paralelo, directo desde docs.getdbt.com, por otro agente — no duplicar la redacción; usar esta fuente solo como confirmación de que el patrón wshobson observa coincide con lo oficial, priorizando siempre la cita a docs.getdbt.com cuando ambas fuentes coincidan.

### No adoptar / fuera de alcance para `pipelines-architecture-data-engineering`

- **Incremental strategies (Pattern 7) y testing genérico/dbt_utils (Pattern 5)** — territorio ya cubierto en `sql-data-engineering` por decisión de frontera explícita en `2026-07-28-sql-skill-design.md` §2 ("dbt es, en esencia, otro orquestador especializado en la capa de transformación SQL — no arquitectura de proyecto"). Además, Pattern 7 trae el error del §2.1 — si alguna vez se decide reforzar este tema en `sql-data-engineering`, no importar la formulación "default for most warehouses" de esta fuente.
- **Macros y DRY code (Pattern 6)** — Jinja/macros de dbt no encajan limpio en `sql-data-engineering` (SQL declarativo, no templating) ni en `pipelines-architecture-data-engineering` (no es una decisión de arquitectura de orquestación). Mismo tipo de descarte que recibieron `database-design`/`data-validation-suite` en la ronda de `sql` — anotado como fuera de alcance de la suite tal como está definida hoy, no una omisión a corregir.
- **Comandos operativos puros** (`dbt docs serve`, `dbt debug`, `dbt compile`) — trivia de CLI, no arquitectura; no aportan a la decisión de diseño que esta skill existe para resolver.
- **Source freshness (`warn_after`/`error_after`)** — más cercano a monitoreo/calidad de datos (`quality-data-engineering`, fuera del alcance de esta tarea) que a arquitectura de orquestación; no se recomienda para esta skill.

---

## 5. Fuentes primarias usadas para verificar

| Fuente | Uso | Método |
|---|---|---|
| `wshobson/agents` — `plugins/data-engineering/skills/dbt-transformation-patterns/SKILL.md` | Contenido íntegro revisado (§1) | `gh api ... --jq '.content' \| base64 -d` |
| `wshobson/agents` — `.../dbt-transformation-patterns/references/details.md` | Contenido íntegro revisado (§1) | `gh api ... --jq '.content' \| base64 -d` |
| [Snowflake configurations](https://docs.getdbt.com/reference/resource-configs/snowflake-configs) | Default de `incremental_strategy` en Snowflake = `merge` (§2.1) | `curl` directo, HTML parseado |
| [BigQuery configurations](https://docs.getdbt.com/reference/resource-configs/bigquery-configs) | Default de `incremental_strategy` en BigQuery = `merge` (§2.1) | `curl` directo, HTML parseado |
| [Redshift configurations](https://docs.getdbt.com/reference/resource-configs/redshift-configs) | Default condicional (`append`/`delete+insert` según `unique_key`) (§2.1) | `curl` directo, HTML parseado |
| [Postgres configurations](https://docs.getdbt.com/reference/resource-configs/postgres-configs) | Default condicional, idéntico a Redshift (§2.1) | `curl` directo, HTML parseado |
| [About incremental strategy](https://docs.getdbt.com/docs/build/incremental-strategy) | Tabla de soporte de estrategias por adaptador (§2.1, contexto) | `curl` directo, HTML parseado — el resumen de WebFetch sobre esta misma página fue descartado por ambigüedad en el mapeo de la tabla |
| [`dbt_project.yml` reference](https://docs.getdbt.com/reference/dbt_project.yml) | Confirma que `config-version`, operadores de selección, etc. siguen vigentes (§2.3) | `curl` directo, HTML parseado |
| `docs/superpowers/plans/2026-07-30-pipelines-architecture-skill-implementation.md` (línea ~1086) | Precedente metodológico: re-chequeo de `airflow-dag-patterns`, mismo patrón de hallazgo (sin awareness de versión + inconsistencia interna) | Lectura directa del repo |
| `docs/superpowers/research/2026-07-29-spark-claims-verification.md` §7 | Precedente de formato: cómo esta suite ya documentó una revisión de `wshobson/agents` (adoptar con atribución vs. descartar por fuera de alcance) | Lectura directa del repo |
| `docs/superpowers/specs/2026-07-28-sql-skill-design.md` §2, §3 | Frontera ya fijada: arquitectura de proyecto dbt pertenece a `pipelines-architecture-data-engineering`, no a `sql-data-engineering` | Lectura directa del repo |

---

## 6. Conclusión

`dbt-transformation-patterns` de `wshobson/agents` **no es un candidato para adopción sustancial de contenido nuevo** en la brecha de arquitectura de proyecto dbt — su valor real es **corroborar** (con ejemplos concretos y realistas) que el patrón medallion + naming conventions + configuración de materialización por carpeta que la doc oficial de dbt describe en abstracto sí se usa así en la práctica. Dos hallazgos de calidad refuerzan tratarla como fuente secundaria a re-verificar, no a copiar: (1) el claim "delete+insert (default for most warehouses)" es **falso** — Snowflake y BigQuery defaultean a `merge`, verificado directo contra `docs.getdbt.com`; (2) una inconsistencia interna de nombre de archivo entre `SKILL.md` y `references/details.md` para el mismo modelo de ejemplo. Ambos hallazgos siguen el mismo patrón ya documentado en esta suite para `airflow-dag-patterns` de la misma fuente — contenido útil como corroboración práctica, pero que requiere verificación puntual contra la documentación oficial antes de convertirse en contenido del skill, nunca adopción a ojo.
