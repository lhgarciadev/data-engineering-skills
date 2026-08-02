# Research: dbt (data build tool) — `ref()`/`source()`, convenciones de naming, entornos y targets, selectors/tags, ecosistema de packages

**Fecha:** 2026-08-02
**Alcance:** investigación de dbt para servir de base al futuro contenido de orquestación/arquitectura de pipelines en `pipelines-architecture-data-engineering` (o el archivo de referencia que trate transformación declarativa/dbt dentro de ese skill). Cubre seis áreas: `ref()`/`source()` y construcción del DAG, convenciones de naming de modelos, `profiles.yml`/`dbt_project.yml`/targets/entornos (dbt Core vs. dbt Cloud/Fusion), selectors y tags, el ecosistema de packages (`packages.yml`, `dbt deps`, `dbt-utils`, `dbt_expectations`), y el contexto de versión vigente. Fuentes primarias: exclusivamente `docs.getdbt.com` (dbt Developer Hub), complementado solo donde el propio dbt Labs publica contenido oficial en GitHub bajo su organización (`github.com/dbt-labs/*`, verificado vía `gh api`, no vía navegador). Sin blogs de terceros, Stack Overflow, ni conocimiento previo del modelo sin verificar — cada claim se recorre hasta la página exacta que lo respalda. Donde un fetch de docs.getdbt.com falló (404) se dice explícitamente y se buscó la URL correcta antes de marcar algo como NO VERIFICADO.

---

## 1. `ref()` y `source()`: construcción del DAG en tiempo de compilación

**VERIFIED**, con cita textual directa de ambas páginas de referencia oficiales.

### `ref()`

> "This function:
> - Returns a Relation for a model, seed, or snapshot
> - Creates dependencies between the referenced node and the current model, which is useful for documentation and node selection
> - Compiles to the full object name in the database"

Fuente: [About ref function — dbt Developer Hub](https://docs.getdbt.com/reference/dbt-jinja-functions/ref) (fetch directo).

Sobre el mecanismo interno y la razón de ser de `ref()` frente a nombres de tabla hardcodeados:

> "`ref()` is, under the hood, actually doing two important things. First, it is interpolating the schema into your model file to allow you to change your deployment schema via configuration. Second, it is using these references between models to automatically build the dependency graph. This will enable dbt to deploy models in the correct order when using `dbt run`."

> "The most important function in dbt is `ref()`; it's impossible to build even moderately complex models without it. `ref()` is how you reference one model within another."

Fuente: misma página (fetch directo). La documentación no contiene una frase explícita del tipo "no hardcodees nombres de tabla" — ese principio se infiere del hecho de que el ejemplo canónico de la página usa siempre `{{ ref(...) }}` en vez de `schema.table`, y de que la función misma existe para resolver el nombre completo del objeto en runtime según el entorno. Esto es una inferencia razonable de la mecánica documentada, no una cita textual de una prohibición.

### `source()`

> "This function:
> - Returns a Relation for a source
> - Creates dependencies between a source and the current model, which is useful for documentation and node selection
> - Compiles to the full object name in the database"

Sintaxis:
```
select * from {{ source("source_name", "table_name") }}
```

Fuente: [About source function — dbt Developer Hub](https://docs.getdbt.com/reference/dbt-jinja-functions/source) (fetch directo).

### Por qué esto importa para el ordenamiento de dependencias

Ambas páginas usan literalmente la misma frase — "Creates dependencies between [...] and the current model, which is useful for documentation and node selection" — que es el enlace textual explícito entre `ref()`/`source()` y la construcción del grafo de dependencias (DAG) que dbt usa para: (a) ordenar la ejecución de `dbt run`/`dbt build` correctamente, y (b) habilitar la sintaxis de selección de nodos (`--select`, operadores `+`, ver §4). No encontré en ninguna de las dos páginas la palabra literal "DAG", pero sí "dependency graph" y "dependencies", que es el vocabulario oficial equivalente.

**Veredicto: VERIFIED** — la mecánica (interpolación de schema + construcción de grafo de dependencias) y el uso resultante (orden de ejecución vía `dbt run`, node selection) están confirmados con cita textual directa de ambas páginas oficiales. La recomendación "no hardcodees nombres de tabla" es inferencia razonable de la mecánica, no una prohibición citada verbatim.

---

## 2. Convenciones de naming de modelos: guía oficial de dbt Labs vs. práctica de comunidad

**Parcialmente verificado, con distinción crítica que hay que preservar en el skill: esto SÍ es una guía oficialmente publicada por dbt Labs (`docs.getdbt.com/best-practices`), pero la propia guía se presenta explícitamente a sí misma como opinión/punto de partida, no como regla obligatoria del lenguaje dbt.** Es la misma disciplina que el archivo hermano aplica a RBAR, pero con un matiz distinto: aquí sí hay una fuente oficial de dbt Labs — lo que varía es cuánto peso normativo la propia fuente se atribuye a sí misma.

### La guía existe y es oficial, publicada como "Best Practices" en docs.getdbt.com

URL raíz: `docs.getdbt.com/best-practices/how-we-structure/*` y `docs.getdbt.com/best-practices/how-we-style/*`. Ambas viven bajo el dominio oficial del Developer Hub de dbt Labs, no en un repo de comunidad.

### Hedging explícito — dbt Labs marca esto como recomendación, no regla

Sobre la guía de estructura de proyecto:

> "This guide is just a starting point... You may decide that you prefer Birkenstocks or a purple hoodie for your project over Jobs-ian minimalism. That's fine."
>
> "What's important is that you think through the reasoning for those changes in your organization, explicitly declare them in a thorough, accessible way for all contributors, and above all _stay consistent_."
>
> "we recommend the approach that we do, so that you're equipped to decide when and where to deviate from these recommendations to better fit your organization's unique needs"

Fuente: [How we structure our dbt projects — dbt Developer Hub](https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview) (fetch directo).

Sobre la guía de estilo, el hedging es todavía más explícito:

> "You should style the project in a way you and your teammates or collaborators agree on. The most important thing is that you have a style guide and stick to it. This guide is just a suggestion to get you started and to give you a sense of what a style guide might look like."
>
> "**Again, the important thing is not to follow this style guide; it's to make _your_ style guide and follow it.**"

Fuente: [How we style our dbt projects — dbt Developer Hub](https://docs.getdbt.com/best-practices/how-we-style/0-how-we-style-our-dbt-projects) (fetch directo). Nota de precisión de URL: la ruta correcta de esta página es el índice `0-...`, no `1-...` — un primer intento con `/best-practices/how-we-style/1-how-we-style-our-dbt-projects` devolvió 404; se corrigió con la URL real antes de dar por perdido el dato.

### `stg_` prefix — oficial, con receta de naming explícita

> "✅ `stg_[source]__[entity]s.sql` - the double underscore between source system and entity helps visually distinguish the separate parts... In a single-source project like Jaffle Shop, `stg_orders.sql` and `stg_customers.sql` are clear enough without the source prefix."
>
> "❌ `stg_[entity].sql` - might be specific enough at first for a single-source project, but will break down in time as you add sources."

Fuente: [Staging: Preparing our atomic building blocks — dbt Developer Hub](https://docs.getdbt.com/best-practices/how-we-structure/2-staging) (fetch directo).

### Un modelo por tabla fuente (staging) — oficial

> "Staging models are the only place we'll use the `source` macro, and our staging models should have a 1-to-1 relationship to our source tables. That means for each source system table we'll have a single staging model referencing it, acting as its entry point — _staging_ it — for use downstream."

Fuente: misma página (fetch directo). Esto confirma la relación 1:1 modelo-fuente para staging específicamente — no es una regla general de "un modelo por archivo" declarada como tal en ningún punto de la documentación revisada (ver más abajo).

### Marts nombrados por área de negocio/departamento — oficial, con hedging propio

> "✅ **Group by department or area of concern.** If you have fewer than 10 or so marts you may not have much need for subfolders... grouping by departments (marketing, finance, etc.) is the most common structure at this stage."
>
> "❌ **Build the same concept differently for different teams.** `finance_orders` and `marketing_orders` is typically considered an anti-pattern."

Fuente: [Marts: Business-defined entities — dbt Developer Hub](https://docs.getdbt.com/best-practices/how-we-structure/4-marts) (fetch directo).

### Estructura de directorios staging/intermediate/marts — oficial

La guía recomienda organizar `models/` en tres capas — `staging/`, `intermediate/`, `marts/` — documentado con ejemplos de árbol de directorios en las páginas 2, 3 y 4 de la misma guía (`how-we-structure/2-staging`, `.../3-intermediate`, `.../4-marts`), enlazadas todas desde la página raíz `how-we-structure/1-guide-overview`. Fuente: mismas páginas (fetch directo).

### "Un modelo por archivo que coincide con el nombre del modelo" — NO encontrado como regla explícita separada

Revisé `how-we-style/1-how-we-style-our-dbt-models` buscando específicamente esta regla. La página confirma convenciones de nombres de campo/modelo (pluralización, `snake_case`, primary keys `<object>_id`, evitar puntos en nombres de modelo) pero **no contiene una frase explícita "un modelo por archivo, y el archivo debe llamarse igual que el modelo"** — ese principio es una consecuencia mecánica implícita de cómo dbt identifica modelos (el nombre del archivo `.sql` es el nombre del modelo, es la única forma en que dbt sabe interpretarlo), no una regla de estilo enunciada aparte. Fuente: [How we style our dbt models — dbt Developer Hub](https://docs.getdbt.com/best-practices/how-we-style/1-how-we-style-our-dbt-models) (fetch directo).

### Distinción clave: qué es "oficial dbt Labs" y qué es "convención de comunidad"

Es importante no confundir dos cosas que suenan parecido:

1. **La guía Best Practices en `docs.getdbt.com/best-practices`** — esto SÍ es contenido oficial publicado y mantenido por dbt Labs, con las convenciones citadas arriba (`stg_`, marts por departamento, estructura de 3 capas). Se presenta explícitamente como opinión/punto de partida, no como sintaxis obligatoria del lenguaje.
2. **Repos de estilo tipo "dbt-labs/corp" o "dbt-labs/dbt-style-guide"**, citados en múltiples blogs de terceros como "el style guide de dbt Labs" — intenté verificar `github.com/dbt-labs/corp` y `github.com/dbt-labs/dbt-style-guide` directamente (tanto vía WebFetch como vía `gh api repos/dbt-labs/corp`) y **ambos devuelven 404 / repositorio no encontrado hoy**, es decir, ya no son accesibles públicamente bajo esos nombres — pueden haberse vuelto privados, renombrado o eliminado. Lo único confirmado y accesible es `github.com/dbt-labs/dbt-proserv` (repo público real, confirmado vía `gh api`, descripción propia: *"This is a public repository that the dbt proserv team uses for collective demos"*), que contiene un `dbt_proserv_style_guide.md` con convenciones (`stg_`, `int_`, `dim_`, `fct_`, `base_`) más granulares que la guía de docs.getdbt.com, y que **enlaza explícitamente** a la guía oficial ("Read [How we structure our dbt projects](https://docs.getdbt.com/guides/best-practices/how-we-structure/1-guide-overview) for an example and more details around organization"). Este repo es del equipo de *professional services* de dbt Labs (proserv) usado para demos, no la guía general de la compañía para todos los usuarios — se cita aquí como contexto adicional, pero **no debe presentarse en el skill como "la" guía oficial de naming de dbt Labs**; ese rol lo cumple `docs.getdbt.com/best-practices`.

**Veredicto: VERIFIED como guía oficial de dbt Labs (existe, está publicada bajo su dominio, cubre exactamente las convenciones preguntadas), pero con hedging explícito de la propia fuente ("this guide is just a starting point", "the important thing is not to follow this style guide") que el skill debe preservar** — no presentar `stg_`/marts-por-departamento/3-capas como sintaxis obligatoria de dbt, sino como la recomendación publicada por dbt Labs que la mayoría de la comunidad adoptó de facto. El repo `dbt-labs/corp` frecuentemente citado en la comunidad como "el style guide" **ya no es accesible** (404 verificado); no usarlo como fuente citable.

---

## 3. `profiles.yml`, `dbt_project.yml`, targets, y la brecha dbt Core vs. dbt Cloud/Fusion

**VERIFIED**, con hallazgo importante: la documentación actual distingue explícitamente el modelo de dbt Core (`profiles.yml` + targets) del modelo de dbt Cloud/plataforma (entornos gestionados en UI), y los presenta como dos formas distintas de resolver el mismo problema — no como una jerarquía donde uno reemplaza al otro en la doc vigente.

### `profiles.yml`: qué es, estructura, dónde vive

> "The `profiles.yml` file stores database connection credentials and configuration for dbt projects, including: Connection details... Target definitions — Define different environments (dev, staging, prod) within a single profile. Default target — Set which environment to use by default. Execution parameters... Credential separation — Keep sensitive information out of version control."

> "`~/.dbt/profiles.yml` is the recommended location for the following reasons: Security — Keeps credentials out of project directories and version control. Reusability — A single file for all dbt projects on the machine. Separation — Connection details don't travel with project code."

Estructura básica (profile name → `target` → `outputs`):
```yaml
my_project_profile:
  target: dev
  outputs:
    dev:
      type: adapter_type
      account: abc123
      database: docs_team
      schema: dev_schema
      threads: 4
```

Fuente: [About profiles.yml — dbt Developer Hub](https://docs.getdbt.com/docs/core/connect-data-platform/profiles.yml) (fetch directo).

### El concepto `target` y el flag `--target`

> "dbt supports multiple targets within one profile to encourage the use of separate development and production environments... A typical profile for an analyst using dbt locally will have a target named `dev`, and have this set as the default. You may also have a `prod` target within your profile."

> "dbt makes it easy to maintain separate production and development environments through the use of [targets] within a [profile]... We recommend using _different schemas within one database_ to separate your environments."

Fuente: [dbt environments (Local development) — dbt Developer Hub](https://docs.getdbt.com/docs/local/dbt-core-environments) (fetch directo). Página con nota explícita de alcance: encabezada como "Local development", con enlace aparte a "Running dbt in production" — confirma que esta página describe específicamente el modelo dbt Core/CLI.

El objeto Jinja `target` expone estas propiedades, derivadas directamente de `profiles.yml`:

| Variable | Ejemplo | Descripción |
|---|---|---|
| `target.name` | `dev` | Nombre del target activo |
| `target.schema` | `dbt_alice` | Schema/dataset activo |
| `target.type` | `postgres` | Adapter activo |
| `target.threads` | `4` | Threads en uso |

Fuente: [About target variables — dbt Developer Hub](https://docs.getdbt.com/reference/dbt-jinja-functions/target) (fetch directo), que confirma también el flag CLI: `dbt run --target prod`.

### `DBT_TARGET` como variable de entorno — verificado explícitamente: NO existe

Revisé la página oficial de variables de entorno buscando específicamente `DBT_TARGET`. **No aparece en ningún punto.** Las variables de entorno reservadas/definidas por dbt documentadas en esa página son variables de contexto de dbt Cloud (`DBT_CLOUD_ENVIRONMENT_NAME`, `DBT_CLOUD_PROJECT_ID`, `DBT_CLOUD_JOB_ID`, `DBT_CLOUD_RUN_ID`, `DBT_CLOUD_GIT_SHA`, etc.) y `DBT_ENV`, ninguna de las cuales es `DBT_TARGET`. Fuente: [Environment variables — dbt Developer Hub](https://docs.getdbt.com/docs/build/environment-variables) (fetch directo). Confirmado además por una segunda página de referencia específica de nombres de target personalizados, que tampoco menciona `DBT_TARGET` en ningún punto: [Custom target names — dbt Developer Hub](https://docs.getdbt.com/docs/build/custom-target-names) (fetch directo) — esa página documenta el mecanismo real para fijar un target custom en dbt Cloud (campo "Target Name" en la configuración del Job, o en credenciales de usuario en el IDE), que es una configuración de UI, no una variable de entorno.

**Conclusión explícita: `DBT_TARGET` NO es una variable de entorno oficialmente documentada por dbt.** El mecanismo documentado para cambiar de target es el flag `--target` en CLI (dbt Core) o el campo "Target Name" en la UI de Job Settings / credenciales de usuario (dbt Cloud) — no una variable de entorno con ese nombre.

### Relación `dbt_project.yml` (en el repo) vs. `profiles.yml` (fuera del repo)

> "Every dbt project needs a `dbt_project.yml` file — this is how dbt knows a directory is a dbt project. It also contains important information that tells dbt how to operate your project."
>
> "By default, dbt looks for the `dbt_project.yml` in your current working directory and its parents, but you can set a different directory using the `--project-dir` flag or the environment variable."

Fuente: [dbt_project.yml — dbt Developer Hub](https://docs.getdbt.com/reference/dbt_project.yml) (fetch directo). `dbt_project.yml` vive en el repo del proyecto (control de versiones); `profiles.yml` vive fuera del repo, en `~/.dbt/` por defecto, precisamente para separar credenciales del código versionado (ver cita de §3 arriba, "Keeps credentials out of project directories and version control"). Esta separación repo/no-repo es la razón estructural por la que dbt necesita dos archivos de configuración distintos en vez de uno.

### dbt Cloud/Fusion: modelo de entornos distinto y más nuevo — confirmado explícitamente

La documentación actual tiene una página dedicada que compara ambos modelos directamente:

> "Typically, there are two types of environments in dbt: Deployment or Production (or _prod_)... Development (or _dev_)..."
>
> Para dbt (plataforma/Cloud): "Seamlessly configure development and deployment environments in dbt to control how your project runs in both the Studio IDE, dbt platform CLI, and dbt jobs."
>
> Para dbt Core: "Setup and maintain separate deployment and development environments through the use of targets within a profile file."

Fuente: [About environments — dbt Developer Hub](https://docs.getdbt.com/docs/environments-in-dbt) (fetch directo). Esta página confirma textualmente que "targets dentro de un profile file" es el mecanismo específico de **dbt Core**, contrapuesto al modelo de entornos configurados en la plataforma dbt Cloud.

Sobre el modelo de credenciales de dbt Cloud específicamente:

> "Deployment credentials are managed through connection profiles, which are created at the project level and assigned to deployment environments. Profiles define the credentials and attributes dbt uses to connect to your warehouse."

Fuente: [Deployment environments — dbt Developer Hub](https://docs.getdbt.com/docs/deploy/deploy-environments) (fetch directo). Nota de precisión: dbt Cloud también usa la palabra "profile" para este concepto, pero es un objeto gestionado en la UI/API de la plataforma ("About dbt platform profiles"), **no** el archivo `profiles.yml` local de dbt Core — son dos cosas distintas que comparten nombre, y el skill debe evitar la ambigüedad.

**Veredicto: VERIFIED en su totalidad**, incluyendo la verificación negativa explícita de `DBT_TARGET` (no documentado) y la distinción dbt Core (`profiles.yml`/`--target`) vs. dbt Cloud/plataforma (entornos + "connection profiles" gestionados en UI, terminología superpuesta pero mecanismo distinto).

---

## 4. Selectors y tags: mecánica de `--select`, operador `+`, `tag:`

**VERIFIED**, cita directa de la documentación de referencia de Node Selection.

### Mecánica general de `--select`

> "dbt gathers all the resources that are matched by one or more of the `--select` criteria, in the order of selection methods (e.g. `tag:`), then graph operators (e.g. `+`), then finally set operators (unions, intersections, exclusions)."
>
> "The selected resources may be models, sources, seeds, snapshots, tests."
>
> "dbt now has a list of still-selected resources of varying types. As a final step, it tosses away any resource that does not match the resource type of the current task. (Only seeds are kept for `dbt seed`, only models for `dbt run`, only tests for `dbt test`, and so on.)"

Fuente: [Syntax overview — Node Selection, dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/syntax) (fetch directo). Página con selector de versión visible (v2/v1, 1.12/1.11), consistente con el hallazgo de versión de §6.

### El operador `+` (upstream/downstream)

> "The `+` operator expands your selection to include ancestors (upstream dependencies) or descendants (downstream dependencies) of a resource... Placed after a model/resource — includes the resource itself and all its descendants. Placed before a model/resource — includes the resource itself and all its ancestors. Placed on both sides — includes the resource itself, all ancestors, and all descendants."

```
dbt run --select "my_model+"     # my_model y todos sus descendientes
dbt run --select "+my_model"     # my_model y todos sus ancestros
dbt run --select "+my_model+"    # my_model, ancestros y descendientes
```

Fuente: [Graph operators — dbt Developer Hub](https://docs.getdbt.com/reference/node-selection/graph-operators) (fetch directo).

### El selector `tag:`

```
dbt run --select "tag:nightly"   # corre modelos con el tag "nightly"
dbt run --select "path:marts/finance,tag:nightly,config.materialized:table"  # combinación de métodos
```

Fuente: [Syntax overview — Node Selection](https://docs.getdbt.com/reference/node-selection/syntax) (fetch directo).

### Cómo se configuran los tags

Vía `config()` inline en el `.sql`:
```sql
{{ config(tags=["finance"]) }}
```

Vía propiedades `.yml` del modelo:
```yaml
models:
  - name: stg_customers
    config:
      tags: ['santi']
```

Vía `dbt_project.yml`, a nivel de carpeta (heredado por todos los modelos dentro):
```yaml
models:
  jaffle_shop:
    +tags: "contains_pii"
    staging:
      +tags:
        - "hourly"
```

Fuente: [tags — dbt Developer Hub](https://docs.getdbt.com/reference/resource-configs/tags) (fetch directo).

**Veredicto: VERIFIED** — mecánica de `--select`, operador `+` (ambos sentidos), selector `tag:`, y las tres formas de configurar tags (`config()`, `.yml` de propiedades, `dbt_project.yml` a nivel de carpeta con el prefijo `+`) están todas confirmadas con cita textual y ejemplo directo de la documentación oficial de referencia.

---

## 5. El ecosistema de packages: `packages.yml`, `dbt deps`, `dbt-utils`, `dbt_expectations`

**VERIFIED**, incluyendo la distinción de mantenedor entre ambos paquetes, verificada directamente contra los propios repos de GitHub (no inferida).

### Qué es un package

> "dbt _packages_ are in fact standalone dbt projects, with models, macros, and other resources that tackle a specific problem area. As a dbt user, by adding a package to your project, all of the package's resources will become part of your own project. This means: Models in the package will be materialized when you `dbt run`. You can use `ref` in your own models to refer to models from the package. You can use `source` to refer to sources in the package. You can use macros in the package in your own project."

Fuente: [Packages — dbt Developer Hub](https://docs.getdbt.com/docs/build/packages) (fetch directo).

### `packages.yml`

```yaml
packages:
  - package: dbt-labs/snowplow
    version: 0.7.0
  - git: "https://github.com/dbt-labs/dbt-utils.git"
    revision: 0.9.2
  - local: /opt/dbt/redshift
```

Fuente: misma página (fetch directo). Soporta tres formas de referenciar un paquete: hub de dbt Labs (`package:`), git (`git:`), o ruta local (`local:`).

### `dbt deps` y `dbt_packages/`

> "Run `dbt deps` to install the package(s). Packages get installed in the `dbt_packages` directory – by default this directory is ignored by git, to avoid duplicating the source code for the package."
>
> "`dbt deps` pulls the most recent version of the dependencies listed in your `packages.yml` from git."

Fuente: [Packages](https://docs.getdbt.com/docs/build/packages) y [About dbt deps command](https://docs.getdbt.com/reference/commands/deps) (ambas fetch directo). `dbt deps` además genera un `package-lock.yml` con las versiones resueltas exactas (incluyendo commit SHA) para instalaciones reproducibles.

### `dbt-utils` — mantenido por dbt Labs

Confirmado directamente contra la API de GitHub (no vía docs.getdbt.com, que solo lo menciona como ejemplo):

> `full_name: "dbt-labs/dbt-utils"`, descripción propia del repo: `"Utility functions for dbt projects."`

Fuente: [github.com/dbt-labs/dbt-utils](https://github.com/dbt-labs/dbt-utils) (verificado vía `gh api repos/dbt-labs/dbt-utils`, no solo mención indirecta en docs). Es una colección de macros de utilidad (generic tests como `equal_rowcount`, `not_accepted_values`, `unique_combination_of_columns`; macros introspectivos; generadores SQL como `date_spine`) de propósito general para cualquier proyecto dbt.

### `dbt_expectations` — mantenido por la comunidad, inspirado en Great Expectations

> `full_name: "calogica/dbt-expectations"` — **no** pertenece a la organización `dbt-labs`, sino a `calogica` (mantenedor de comunidad).
>
> Del propio README: "`dbt-expectations` is an extension package for **dbt**, inspired by the [Great Expectations package for Python](https://greatexpectations.io/). The intent is to allow dbt users to deploy GE-like tests in their data warehouse directly from dbt."

Fuente: [github.com/calogica/dbt-expectations](https://github.com/calogica/dbt-expectations) (verificado vía `gh api repos/calogica/dbt-expectations` + lectura directa del `README.md` del repo). **Nota importante encontrada durante la verificación, no anticipada por el research original**: el propio README del repo indica, en su primera línea: *"Note: This package is no longer actively supported."* Esto es un dato de estado del proyecto que vale la pena incluir en el skill si se recomienda `dbt_expectations` — es funcional y ampliamente usado, pero ya no tiene mantenimiento activo confirmado por sus propios autores.

**Veredicto: VERIFIED**, incluyendo la distinción de mantenedor (dbt-labs vs. calogica/comunidad) confirmada directamente contra los metadatos de ambos repos de GitHub, no asumida. Hallazgo adicional no solicitado explícitamente pero relevante: `dbt_expectations` se declara a sí mismo sin mantenimiento activo — esto debería mencionarse si el skill lo recomienda como opción viva.

---

## 6. Contexto de versión: dbt-core actual y el cambio de era v1 → v2/Fusion

**VERIFIED — este es el hallazgo más importante de todo el research y cambia cómo debe enmarcarse el resto del contenido.** Al momento de este research (agosto 2026), dbt está en medio de una transición de versión mayor real y muy reciente, análoga en magnitud al caso "Airflow 3.3.0 al momento del fetch" del research hermano de orquestación — pero aquí la transición es más disruptiva porque implica un cambio de motor (Python → Rust) y de licencia de una parte del código.

### Versión estable actual: dbt Core v1.12

Confirmado directamente contra GitHub Releases:

> Latest release: **v1.12.0**, released **July 16, 2026**.

Fuente: [github.com/dbt-labs/dbt-core/releases](https://github.com/dbt-labs/dbt-core/releases) (fetch directo). Confirmado también por la tabla de versiones soportadas de la documentación oficial:

> "dbt Core latest releases: v1.12 — Jul 16, 2026 — Active support until July 15, 2027. v1.11 — Dec 19, 2025 — Critical support until Dec 18, 2026. v1.10 y anteriores — Deprecated/End of Life."

Fuente: [About dbt versions — dbt Developer Hub](https://docs.getdbt.com/docs/dbt-versions) (fetch directo). La página confirma explícitamente el esquema de semantic versioning para la serie 1.x: *"Major versions (for example, v1 to v2) may include breaking changes... Minor versions... add features and are backwards compatible... Patch versions... include fixes only."*

### El cambio de era: dbt Core v2.0 / dbt Fusion (alpha, en curso)

Confirmado por el anuncio oficial en el blog de dbt Developer Hub (no un blog de terceros — vive bajo `docs.getdbt.com/blog`):

> "Today, we published the **first alpha release of dbt Core version 2.0**... What makes this release significant is that dbt Core 2.0 is now built on the same foundations as the [dbt Fusion engine](https://www.getdbt.com/product/fusion) – we've open-sourced a lot of Fusion code for the first time."

Fecha del anuncio: **June 1, 2026** (fecha propia del post: "June 1, 2026 · 9 min read"). Fuente: [dbt Core v2 is here: still open source, now rebuilt for what's next — dbt Developer Blog](https://docs.getdbt.com/blog/dbt-core-v2-is-here) (fetch directo).

Estado del código Python/v1 — explícitamente NO deprecado ni forzado:

> "The existing Python code is still available. We just released a new beta version of dbt Core v1.12.0, and all the old versions are still available on PyPI and GitHub. **You don't have to move to v2.x today, tomorrow, or ever.**"

Fuente: misma página (fetch directo).

### Qué es Fusion, y su relación con dbt Core 2.0

> "Fusion is written in Rust and has a native understanding of SQL across multiple engine dialects — catching errors before they reach your warehouse and powering editor features like autocomplete and inline errors as you type. Fusion is the default experience when you install dbt. It gives you the recommended v2 experience from the command line and builds on the Apache 2.0 runtime available as dbt Core 2.0."
>
> "_Need Apache 2.0 only? Install dbt Core 2.0, the open-source project behind Fusion._"

Fuente: [About Fusion — dbt Developer Hub](https://docs.getdbt.com/docs/fusion/about-fusion) (fetch directo). Es decir: **dbt Core 2.0** es la base Apache 2.0 open-source; **Fusion** es la distribución/experiencia recomendada construida sobre esa base, con capacidades adicionales (algunas gratuitas, otras premium con login). v2.0 está confirmado como **alpha** en GitHub Releases al momento del fetch (`v2.0.0-alpha.5`, 20 de julio de 2026), no como versión estable — la tabla de versiones de `docs.getdbt.com/docs/dbt-versions` lo confirma: *"dbt Fusion: v2.0 — Currently in alpha (support end date: TBD)."*

### Señal adicional encontrada de forma incidental: `config-version` en `dbt_project.yml`

La página de referencia de `dbt_project.yml`, al momento del fetch, distingue explícitamente "Fusion release tracks" (v2) de "Core release tracks" (v1) en su selector de versión de documentación, y muestra `config-version: 2` en el ejemplo de configuración raíz — consistente con que `config-version` es un campo del schema YAML de dbt Core que ya lleva tiempo en `2` (no cambia con la transición v1→v2 de motor, son numeraciones independientes: `config-version` versiona el schema de `dbt_project.yml`, no el motor de dbt). Fuente: [dbt_project.yml — dbt Developer Hub](https://docs.getdbt.com/reference/dbt_project.yml) (fetch directo). No se investigó a fondo el historial de `config-version: 1` por estar fuera del alcance puntual de esta pregunta; se deja como dato de contexto, no como claim central.

**Veredicto: VERIFIED, con nota de vigencia crítica para el skill.** Todo el contenido de las secciones 1–5 de este research (`ref()`/`source()`, `profiles.yml`, node selection, packages) aplica y está documentado bajo **dbt Core v1.12 / la era "Core release tracks"**, que es la versión estable con soporte activo al momento de este research y la que sigue documentada como tal en `docs.getdbt.com`. **dbt Core v2.0 / Fusion existe, es real, está anunciada oficialmente y en desarrollo activo (alpha), pero no es la versión estable recomendada para producción todavía** — el propio anuncio de dbt Labs dice textualmente que nadie está obligado a migrar. El skill debe anclar su contenido a v1.x/Core (que es lo que la mayoría de instalaciones en producción usan hoy) y mencionar Fusion/v2 como el rumbo futuro anunciado, sin presentarlo como el estado actual de la mayoría de proyectos dbt en producción.

---

## Resumen de acciones para el archivo de skill que use este research

1. **`ref()`/`source()`**: usar la cita compartida "Creates dependencies between [...] and the current model, which is useful for documentation and node selection" como el ancla textual del concepto "DAG en tiempo de compilación" — es la frase más citable y aparece idéntica en ambas páginas oficiales.
2. **Naming**: presentar `stg_`, marts-por-departamento, y estructura de 3 capas como **recomendación oficialmente publicada por dbt Labs** (con cita y link), pero preservar el hedging explícito de la fuente ("this guide is just a starting point", "the important thing is not to follow this style guide") — no convertir la recomendación en regla sintáctica de dbt. No citar `github.com/dbt-labs/corp` como fuente — ya no es accesible (404 verificado); si se quiere un ejemplo de convención más granular (`int_`, `dim_`, `fct_`, `base_`), usar `dbt-labs/dbt-proserv` marcándolo explícitamente como "guía interna de un equipo de dbt Labs, publicada como demo — no la política oficial de la compañía para todos los usuarios".
3. **`profiles.yml`/targets**: enfatizar la separación repo (`dbt_project.yml`) vs. fuera-de-repo (`profiles.yml`, `~/.dbt/`) como decisión de seguridad de credenciales, no accidente histórico. Documentar explícitamente que `DBT_TARGET` **no existe** como variable de entorno oficial — el mecanismo es `--target` (CLI, dbt Core) o el campo "Target Name" en UI (dbt Cloud). Marcar con claridad que dbt Cloud tiene su **propio** modelo de entornos (Development/Deployment environments en la plataforma) que no usa `profiles.yml` directamente, aunque reutiliza la palabra "profile" para un concepto distinto gestionado en UI — riesgo real de confusión terminológica a prevenir en el skill.
4. **Selectors/tags**: usar los tres ejemplos verbatim de `--select "my_model+"` / `"+my_model"` / `"tag:nightly"` y las tres formas de declarar tags (`config()`, `.yml`, `dbt_project.yml` con `+tags`) tal como aparecen citadas.
5. **Packages**: mencionar el hallazgo no solicitado pero relevante de que `dbt_expectations` se declara a sí mismo "no longer actively supported" en su propio README — dato de riesgo operacional real si el skill lo recomienda sin matiz.
6. **Versión**: anclar todo el contenido explícitamente a **dbt Core v1.12 / "Core release tracks"** como la versión estable vigente (soporte activo hasta julio 2027), y mencionar dbt Core v2.0/Fusion (alpha desde junio 2026, motor Rust) como la dirección futura anunciada oficialmente — sin tratarlo como el estado por defecto de los proyectos dbt en producción hoy. Esta distinción es la más importante de todo el research para no dejar el skill desactualizado prematuramente ni, al revés, ignorar un cambio de motor que dbt Labs ya anunció formalmente.

**Nota de honestidad epistémica**: dos puntos débiles a señalar. Primero, la ausencia de una frase textual "no hardcodees nombres de tabla" en la doc de `ref()` (§1) — el principio se sostiene por inferencia mecánica razonable, no por cita directa de una prohibición; si el skill lo presenta como regla, debe presentarlo como consecuencia lógica de la mecánica de `ref()`, no como advertencia textual de dbt Labs. Segundo, la sección de `config-version` en `dbt_project.yml` (§6) se registró de forma incidental durante el fetch de otra pregunta y no se investigó en profundidad su historial (`config-version: 1` vs. `2`) — si el skill necesita ese detalle, requiere una verificación adicional específica no cubierta aquí. Todo lo demás en este archivo está respaldado por fetch directo de docs.getdbt.com o por verificación directa vía `gh api` de metadatos de repos de GitHub bajo la organización oficial `dbt-labs` (o, en el caso de `dbt_expectations`, del propio repo de comunidad citado).
