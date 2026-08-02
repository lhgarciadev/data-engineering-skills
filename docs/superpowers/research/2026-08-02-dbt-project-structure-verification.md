# Research: estructura de proyectos dbt — `dbt_project.yml`, carpetas estándar, capas de modelado y materializaciones

**Fecha:** 2026-08-02
**Alcance:** verificación de 5 bloques de claims para contenido futuro (probablemente `pipelines-architecture-data-engineering` u otro skill del suite) sobre estructura y convenciones de proyectos dbt: (1) propósito y campos de `dbt_project.yml`; (2) carpetas estándar (`models/`, `seeds/`, `snapshots/`, `macros/`, `tests/`, `analyses/`); (3) la convención de capas que dbt Labs documenta oficialmente (staging → intermediate → marts) vs. terminología "medallion" (bronze/silver/gold); (4) materializaciones a nivel de configuración de proyecto (`view`/`table`/`incremental`/`ephemeral`/`materialized_view`) — solo el ángulo de dónde/cómo se declaran, sin mecánica SQL de incremental (eso ya vive en `sql-data-engineering`); (5) contexto de versión actual de dbt (dbt Core 1.x vs. dbt Fusion/dbt Core 2.0). Todo verificado por fetch directo contra `docs.getdbt.com` — sin blogs de terceros ni conocimiento previo sin verificar, salvo donde se marca explícitamente como búsqueda de corroboración (§3, medallion).

---

## 1. `dbt_project.yml` — propósito y campos

**Propósito**, cita textual de la página de referencia:

> "Every dbt project needs a `dbt_project.yml` file — this is how dbt knows a directory is a dbt project. It also contains important information that tells dbt how to operate your project."

Fuente: [dbt_project.yml — docs.getdbt.com/reference/dbt_project.yml](https://docs.getdbt.com/reference/dbt_project.yml) (fetch directo).

Confirmado también desde la página de overview de proyectos:

> "At a minimum, all a project needs is the `dbt_project.yml` project configuration file." Y: "By design, dbt enforces the top-level structure of a dbt project such as the `dbt_project.yml` file, the `models` directory, the `snapshots` directory, and so on."

Fuente: [About dbt projects — docs.getdbt.com/docs/build/projects](https://docs.getdbt.com/docs/build/projects) (fetch directo).

### Campos requeridos vs. opcionales (verificado campo por campo, no como lista global — la página de referencia principal no publica una tabla resumen de requerido/opcional)

| Campo | Estado | Fuente / cita |
|---|---|---|
| `name` | **Requerido**. Debe cumplir el regex `^[^\d\W]\w*$` — "Must be letters, digits and underscores only, and cannot start with a digit." Ejemplo inválido explícito: `name: jaffle-shop` (guiones no permitidos) → correcto `name: jaffle_shop`. | [project-configs/name](https://docs.getdbt.com/reference/project-configs/name) |
| `profile` | **Requerido para desarrollo local**, salvo que se pase `--profile` por línea de comandos (el flag sobreescribe el valor del YAML). **No aplica en dbt Cloud** ("This configuration is not applicable"). | [project-configs/profile](https://docs.getdbt.com/reference/project-configs/profile) |
| `version` (versión del proyecto, no de dbt) | **Opcional desde dbt v1.5**. Para dbt v1.4 o anterior era requerido "though it isn't currently used meaningfully by dbt." Si se usa, debe ser semver (`1.0.0`); default `None`. | [project-configs/version](https://docs.getdbt.com/reference/project-configs/version) |
| `config-version` | **Opcional desde dbt v1.5** (junto con `version`, misma nota de la página anterior: "both the `config-version: 2` ... and the top-level `version:` key ... are optional"). | [project-configs/version](https://docs.getdbt.com/reference/project-configs/version) |

**Nota de honestidad epistémica**: la página `reference/dbt_project.yml` en sí (el índice general) no declara explícitamente una lista de "required fields" — el veredicto de requerido/opcional para cada campo viene de la página de referencia específica de ese campo, citada arriba caso por caso.

### Declaración de estructura vía path-keys

La plantilla completa que muestra `reference/dbt_project.yml` incluye estas claves de path (sin valores default documentados en esa página específica — los defaults están en la página de referencia de cada clave, ver §2):

```yaml
name: string
config-version: 2
version: version
profile: profilename
model-paths: [directorypath]
seed-paths: [directorypath]
test-paths: [directorypath]
analysis-paths: [directorypath]
macro-paths: [directorypath]
snapshot-paths: [directorypath]
docs-paths: [directorypath]
asset-paths: [directorypath]
```

También aparecen `function-paths` y `osi-paths` en la plantilla actual — **no verificados en profundidad** en este research (fuera del alcance pedido; son configuraciones de UDFs y de "on-schema-change"/"observed schema inference" respectivamente, mencionadas solo en la plantilla, no investigadas página por página).

Fuente: [reference/dbt_project.yml](https://docs.getdbt.com/reference/dbt_project.yml) (fetch directo).

**Configuración de materialización y otros comportamientos por carpeta** también se declara aquí, vía bloques anidados por resource type (`models:`, `seeds:`, `snapshots:`, etc.) usando prefijo `+` para configs — ver §4.

---

## 2. Carpetas estándar — propósito y defaults, uno por uno

| Carpeta | Path-key | Default (si no se especifica) | Propósito, cita textual |
|---|---|---|---|
| `models/` | `model-paths` | `["models"]` — "By default, dbt will search for models and sources in the `models` directory." | Contiene modelos (`.sql`/`.py`), sources y unit tests. "Optionally specify a custom list of directories where models, sources, and unit tests are located." |
| `seeds/` | `seed-paths` | `["seeds"]` (implícito: "By default, seed files are located in the `seeds` subdirectory of your project") | CSVs versionados que dbt carga con `dbt seed`. Ver uso correcto/incorrecto abajo. |
| `snapshots/` | `snapshot-paths` | `["snapshots"]` (implícito, mismo patrón) — **no puede compartir carpeta con `models/`**: "You cannot co-locate snapshots and models in the same directory." | Implementa Type-2 SCD sobre tablas mutables: "dbt provides a mechanism, snapshots, which records changes to a mutable table over time." |
| `macros/` | `macro-paths` | `["macros"]` — "By default, dbt will search for macros in a directory named `macros`." **No puede compartir carpeta con `models/`**: "Note that you cannot co-locate models and macros." | Bloques Jinja reutilizables, "analogous to 'functions' in other programming languages." |
| `tests/` | `test-paths` | `["tests"]` — "Without specifying this config, dbt will search for tests in the `tests` directory." Dentro de esa carpeta, dbt busca específicamente definiciones genéricas en el subdirectorio `tests/generic` y tests singulares en el resto de archivos. | Ver distinción generic/singular abajo. |
| `analyses/` | `analysis-paths` | **Sin default implícito** — "Without specifying this config, dbt will **not** compile any `.sql` files as analyses." Sin embargo, `dbt init` sí puebla el valor como `analyses`. | Consultas SQL versionadas que se compilan pero **no se ejecutan ni se materializan**: "Any `.sql` files found in the `analyses/` directory ... will be compiled, but not executed." Diferencia explícita con modelos: "no `running_total_by_account` relation will be materialized in the database as this is an `analysis`, not a `model`." Se compilan con `dbt compile` → `target/compiled/{project}/analyses/...`. |

Fuentes: [project-configs/model-paths](https://docs.getdbt.com/reference/project-configs/model-paths), [project-configs/test-paths](https://docs.getdbt.com/reference/project-configs/test-paths), [project-configs/analysis-paths](https://docs.getdbt.com/reference/project-configs/analysis-paths), [project-configs/macro-paths](https://docs.getdbt.com/reference/project-configs/macro-paths), [docs/build/snapshots](https://docs.getdbt.com/docs/build/snapshots), [docs/build/seeds](https://docs.getdbt.com/docs/build/seeds), [docs/build/jinja-macros](https://docs.getdbt.com/docs/build/jinja-macros), [docs/build/analyses](https://docs.getdbt.com/docs/build/analyses), [docs/build/data-tests](https://docs.getdbt.com/docs/build/data-tests) — todas fetch directo.

### `seeds/` — uso correcto vs. anti-patrón (doc oficial es explícita sobre esto)

✅ Casos válidos citados: "mapping zip codes to states, or UTM parameters to marketing campaigns"; listas de emails de prueba a excluir; IDs de cuentas de empleados.

❌ **Anti-patrón declarado explícitamente**: "Do not use seeds to load data from a source system into your warehouse. If it exists in a system you have access to, you should be loading it with a proper EL tool into the raw data area of your warehouse. dbt is designed to operate on data in the warehouse, not as a data-loading tool." También: cargar CSVs grandes exportados de otro sistema "is not performant for large files"; y nunca PII/passwords en seeds.

Fuente: [docs/build/seeds](https://docs.getdbt.com/docs/build/seeds) y refuerzo idéntico en la guía de estructura: [best-practices/how-we-structure/5-the-rest-of-the-project](https://docs.getdbt.com/best-practices/how-we-structure/5-the-rest-of-the-project) — ambas fetch directo, mismo mensaje en las dos fuentes.

### `tests/` — generic vs. singular, cita textual completa

> "There are two ways of defining data tests in dbt:
> - A **singular** data test, in its simplest form, is when you write a SQL query that returns failing rows, you can save that query in a `.sql` file within your test directory.
> - A **generic** data test is a parameterized query that accepts arguments. The test query is defined in a special `test` block (like a macro). Once defined, you can reference the generic test by name throughout your `.yml` files—define it on models, columns, sources, snapshots, and seeds."

- **Singular**: un archivo `.sql` en `tests/` (o `test-paths` custom) cuyo nombre de archivo es el nombre del test; se ejecuta automáticamente con `dbt test`; no se referencia en YAML.
- **Generic**: definido con `{% test nombre(model, column_name) %} ... {% endtest %}` (vive típicamente en `tests/generic/` o en `macros/`), luego se invoca por nombre en YAML bajo `data_tests:` de una columna/modelo/source/snapshot/seed.
- **4 generic tests built-in**: `unique`, `not_null`, `accepted_values`, `relationships`.
- La guía de "resto del proyecto" añade el caso de uso específico donde singular sigue siendo la mejor herramienta: "testing multiple specific tables simultaneously... If you need to test the results of how several specific models interact or relate to each other, a singular test will likely be the quickest way."

Fuentes: [docs/build/data-tests](https://docs.getdbt.com/docs/build/data-tests), [best-practices/how-we-structure/5-the-rest-of-the-project](https://docs.getdbt.com/best-practices/how-we-structure/5-the-rest-of-the-project) — fetch directo.

---

## 3. La capa de modelado — vocabulario oficial de dbt vs. "medallion"

**VEREDICTO: la suposición del usuario es correcta y queda verificada de forma explícita, no por ausencia de evidencia sino por chequeo directo de contenido.**

### Vocabulario propio de dbt Labs: staging → intermediate → marts

La guía oficial vigente, publicada dentro de `docs.getdbt.com` (no un blog externo), es "How we structure our dbt projects", con 5 páginas fetcheadas directamente:

1. [best-practices/how-we-structure/1-guide-overview](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview)
2. [best-practices/how-we-structure/2-staging](https://docs.getdbt.com/best-practices/how-we-structure/2-staging)
3. [best-practices/how-we-structure/3-intermediate](https://docs.getdbt.com/best-practices/how-we-structure/3-intermediate)
4. [best-practices/how-we-structure/4-marts](https://docs.getdbt.com/best-practices/how-we-structure/4-marts)
5. [best-practices/how-we-structure/5-the-rest-of-the-project](https://docs.getdbt.com/best-practices/how-we-structure/5-the-rest-of-the-project)

**Terminología exacta que usa dbt** (no es aproximación mía, son términos que la doc nombra explícitamente):

- **"Source-conformed"** (staging) vs. **"business-conformed"** (intermediate/marts) — el eje central que dbt usa para explicar por qué existen las 3 capas.
- **Staging** — "the foundation of our project... condensing and refining [raw source data] into the individual atoms we'll later build more intricate and useful structures with." Prefijo `stg_[source]__[entity]s.sql`, en plural, un modelo de staging por tabla fuente ("1-to-1 relationship to our source tables"), subcarpetas por **sistema fuente** (no por área de negocio). Prohíbe explícitamente joins y agregaciones en esta capa ("joins are almost always a bad idea here"; "aggregations entail grouping, and we're not doing that at this stage"). Materialización recomendada: **view**.
- **Intermediate** — "preparing staging models for marts. Common patterns include grouping and pivoting to a different grain, fanning out rows, or isolating complex logic so marts stay readable." Prefijo `int_[entity]s_[verb]s.sql` (sin doble guión bajo, a diferencia de staging), organizado por **área de negocio**, no por sistema fuente. Explícitamente **no debe exponerse a usuarios finales**: "Intermediate models should generally not be exposed in the main production schema."
- **Marts** — "everything comes together... we sometimes like to call this the _entity_ _layer_ or _concept_ _layer_." Nombrado por entidad en inglés plano (`customers.sql`, `orders.sql`) — **la guía NO recomienda prefijos `fct_`/`dim_`** (dato relevante si el skill de modeling dimensional los menciona: aquí la fuente oficial de dbt no los usa, aunque tampoco los prohíbe). Organizado por **departamento/área de negocio** (marketing, finance) si hay más de ~10 marts.

**Ninguna de las 5 páginas de la guía menciona "medallion", "bronze", "silver" o "gold"** — verificado por fetch directo con búsqueda textual explícita sobre la página 1 y lectura completa de las páginas 2, 3, 4 y 5 sin que apareciera ninguno de esos términos.

### Búsqueda dedicada de "medallion" en docs.getdbt.com

Se ejecutó una búsqueda web (`site:docs.getdbt.com medallion architecture` y variantes) para confirmar ausencia total, no solo en la guía de estructura. **Resultado: cero resultados alojados en `docs.getdbt.com`.** Todo lo que aparece bajo "dbt + medallion" son fuentes de terceros — posts de Medium, un repo de GitHub de un usuario individual (`dbt-with-medallion-architecture`), un Substack, un blog independiente ("Data Engineer Things") — todos presentando "medallion" (bronze/silver/gold) como un patrón de **lakehouse** (típicamente Databricks/Delta Lake) que ellos *implementan usando* dbt como herramienta de transformación, no como terminología que dbt mismo publique o adopte.

**Conclusión verificada**: "medallion"/bronze-silver-gold es, en efecto, terminología del ecosistema lakehouse (asociada a Databricks/Delta Lake), popularizada por la comunidad como forma de mapear conceptualmente bronze≈raw/staging, silver≈cleaned/intermediate, gold≈business-ready/marts — pero **dbt Labs no la usa, no la menciona y no la endosa en ninguna página de `docs.getdbt.com` verificada en este research**. El vocabulario propio y documentado de dbt es exclusivamente **staging → intermediate → marts**. Si el skill quiere tender un puente pedagógico hacia medallion para lectores que ya conocen ese término (p. ej. viniendo de Databricks), debe presentarse explícitamente como una analogía de la comunidad, no como equivalencia oficial de dbt.

---

## 4. Materializaciones — solo el ángulo de declaración/config de proyecto

**Default si no se configura nada**: **`view`** — cita textual: "By default dbt will: Create models as views." Fuente: [docs/build/sql-models](https://docs.getdbt.com/docs/build/sql-models) (fetch directo).

**Tipos válidos** (enum documentado en la página de referencia del config `materialized`):

- `view` — "your model is rebuilt as a view on each run, via a `create view as` statement."
- `table` — "your model is rebuilt as a table on each run, via a `create table as` statement."
- `incremental` — "incremental models allow dbt to insert or update records into a table since the last time that model was run." (mecánica de `unique_key`/estrategias de merge: **fuera de alcance aquí**, ya cubierta en `sql-data-engineering`).
- `ephemeral` — "not directly built into the database. Instead, dbt will interpolate the code from an ephemeral model into its dependent models using a common table expression (CTE)." Restricciones documentadas: no se puede hacer `select` directo, otras operaciones no pueden `ref()` un nodo ephemeral, no soporta model contracts.
- `materialized_view` — "allows the creation and maintenance of materialized views in the target database... a combination of a view and a table." Nota importante de soporte por engine: "`dbt-snowflake` _does not_ support materialized views, it uses Dynamic Tables instead" — dato relevante si el skill menciona Snowflake.
- Custom materializations también son soportadas (mecanismo de extensión, no investigado en profundidad — fuera de alcance).

Fuentes: [docs/build/materializations](https://docs.getdbt.com/docs/build/materializations), [reference/resource-configs/materialized](https://docs.getdbt.com/reference/resource-configs/materialized) — fetch directo. La página de referencia de `materialized` no publica explícitamente un valor default en su propio texto (el default `view` está confirmado en `docs/build/sql-models`, no ahí — dos páginas distintas, ambas citadas).

### Tres lugares donde se declara — jerarquía de config (menos específico → más específico)

1. **`dbt_project.yml`** (nivel proyecto, aplica a toda una carpeta de resource-path vía prefijo `+`):
   ```yaml
   models:
     my_project:
       events:
         +materialized: table
   ```
2. **`properties.yml`** (nivel modelo, dentro del bloque `config:` del YAML de propiedades):
   ```yaml
   models:
     - name: events
       config:
         materialized: table
   ```
3. **Bloque `config()` en el archivo `.sql` del modelo** (nivel modelo, más específico, jinja):
   ```sql
   {{ config(materialized='table') }}
   ```

Esto es exactamente el ángulo "declaración/config a nivel de estructura de proyecto" pedido — **no se investigó ni se incluye aquí** la mecánica interna de `incremental` (estrategias `merge`/`delete+insert`, `unique_key`, `on_schema_change`), que el propio pedido marca como ya cubierta en otro skill del suite.

**Caso especial — modelos Python**: solo soportan `table` e `incremental`; explícitamente **no pueden** ser `view` ni `ephemeral`. Fuente: [docs/build/materializations](https://docs.getdbt.com/docs/build/materializations).

---

## 5. Contexto de versión — dbt Core 1.x vs. dbt Fusion / dbt Core 2.0

**Esta es la verificación más delicada del research porque el panorama de versiones de dbt cambió de forma sustancial y reciente** — no es un caso de "tomar la versión estable de siempre", hay una bifurcación real que el skill debe nombrar con precisión.

### Estado de versiones al momento del fetch (fecha de este research: 2026-08-02)

De la página oficial de versiones de dbt Core:

- **v1.12** (lanzado 16 jul 2026) — **Active support** hasta 15 jul 2027.
- **v1.11** (lanzado 19 dic 2025) — **Critical support** hasta 18 dic 2026.
- Versiones v1.10 y anteriores: Deprecated o End of Life.
- Ciclo de soporte documentado explícitamente: "dbt supports each minor version (for example, v1.8) for _one year_ from its initial release" — con transición de Active → Critical (solo fixes de seguridad/instalación) → End of Life.

Fuente: [docs/dbt-versions/core](https://docs.getdbt.com/docs/dbt-versions/core) (fetch directo).

### dbt Fusion — qué es, y por qué importa para este research

Cita textual completa de la página oficial de Fusion:

> "Fusion is written in Rust and has a native understanding of SQL across multiple engine dialects — catching errors before they reach your warehouse and powering editor features like autocomplete and inline errors as you type."
>
> "Fusion is the default experience when you install dbt. It gives you the recommended v2 experience from the command line and builds on the Apache 2.0 runtime available as dbt Core 2.0."

Es decir: **dbt Fusion (motor en Rust) es, al momento de este research, el default experience al instalar dbt** — construido sobre dbt Core 2.0 (el runtime open-source Apache 2.0 que sirve de base a Fusion). dbt Core 1.x (Python) sigue existiendo como su propia serie semver en paralelo, con soporte activo/crítico según la tabla de arriba.

**Claim más importante para este skill, verificado explícitamente**: la estructura de proyecto **no cambia** entre dbt Core 1.x (Python) y dbt Fusion/Core 2.0. Cita textual:

> "The dbt Fusion engine shares the same dbt framework you already know — the same dbt language and project structure — while enabling you to work faster and deploy transformation workloads more efficiently."

Fuente: [docs/fusion/about-fusion](https://docs.getdbt.com/docs/fusion/about-fusion) (fetch directo). La página no menciona ningún cambio a `dbt_project.yml`, a los path-keys, ni a las carpetas estándar — todo lo verificado en §1-§4 de este research aplica igual bajo Fusion.

**A qué versión/era atribuir las claims de este research**: todas las citas de §1-§4 vienen de las páginas de referencia "stable" actuales de `docs.getdbt.com`, que al momento del fetch (2026-08-02) documentan el comportamiento vigente para **dbt Core v1.12 / dbt Fusion (v2, Apache 2.0 runtime dbt Core 2.0)** — dbt Labs mantiene una sola versión de docs "stable" sin versionado histórico visible por URL para estas páginas de referencia de proyecto, a diferencia de, p. ej., Airflow. Si el lector está en dbt Core ≤1.4, la única diferencia material encontrada es que `version`/`config-version` eran campos requeridos (ver tabla en §1) — el resto de la estructura de carpetas y materializaciones es estable desde antes de esa ventana según toda la evidencia recopilada.

**No verificado / fuera de alcance de este research**: no se investigó dbt Cloud CLI como producto separado de dbt Core/Fusion (el pedido original lo nombra como posible eje de confusión de versiones, pero las páginas fetcheadas no lo tratan en detalle — solo se confirmó que `profile` "is not applicable" en contexto dbt Cloud). Si el skill necesita distinguir dbt Cloud CLI vs. dbt Core vs. Fusion con precisión, eso requiere una pasada de verificación dedicada adicional.

---

## Resumen de acciones para contenido futuro del skill

Todo lo anterior queda **confirmado contra documentación oficial de docs.getdbt.com**, con hallazgos accionables:

1. **Vocabulario de capas: usar staging/intermediate/marts como términos oficiales de dbt** — nunca presentar "medallion"/bronze-silver-gold como si fuera vocabulario de dbt. Si se menciona medallion, marcarlo explícitamente como término de comunidad/lakehouse (Databricks/Delta Lake), no como guía oficial de dbt — exactamente la distinción que pidió el usuario, y quedó verificada por chequeo directo de ausencia, no solo por no-encontrar-evidencia.
2. **`dbt_project.yml` requerido**: solo `name` es incondicionalmente requerido; `profile` es requerido solo fuera de dbt Cloud; `version`/`config-version` son opcionales desde dbt v1.5 (antes, `version` era requerido pero "not currently used meaningfully").
3. **Restricciones de co-ubicación real**: `snapshots/` no puede compartir carpeta con `models/`; `macros/` tampoco puede compartir carpeta con `models/`. Vale la pena mencionar esto como gotcha estructural real, no solo la lista de carpetas.
4. **Seeds: el anti-patrón está documentado explícitamente por dbt mismo** (no cargar datos de sistemas fuente vía seeds, dbt no es una herramienta de carga) — buen contenido "senior" para el skill, mismo espíritu que otros anti-patrones ya documentados en el suite.
5. **Materializaciones — jerarquía de 3 niveles de config** (`dbt_project.yml` con prefijo `+` por carpeta → `properties.yml` → `config()` en el `.sql`, de menos a más específico) es el ángulo limpio y sin solapamiento con la mecánica de `incremental` que ya vive en `sql-data-engineering`.
6. **dbt Fusion / dbt Core 2.0 es un cambio de versión real y reciente que el skill debe nombrar explícitamente** (motor Rust, default al instalar dbt, construido sobre dbt Core 2.0 Apache 2.0) — pero con el hallazgo tranquilizador de que **no afecta nada de lo documentado en este research sobre estructura de proyecto**: la propia doc de Fusion dice literalmente que comparte "the same dbt language and project structure."

**Nota de honestidad epistémica**: `function-paths`/`osi-paths` (vistos en la plantilla de `dbt_project.yml`) y dbt Cloud CLI como producto distinto quedan fuera de este research — no investigados en profundidad, marcados arriba en el punto donde aparecen. El default de `materialized_view` no soportado en Snowflake (Dynamic Tables como alternativa) se verificó pero no se exploró más allá de la cita — es dato de compatibilidad por engine, no de estructura de proyecto en sí.
