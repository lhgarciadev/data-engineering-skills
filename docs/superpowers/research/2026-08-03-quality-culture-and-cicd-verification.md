# Research: cultura de calidad, CI/CD y "circuit breakers" de datos — verificación de la Capa 6 del draft

**Fecha:** 2026-08-03
**Alcance:** verificación de 4 bloques de claims para contenido futuro de `quality-data-engineering` (6ta skill del suite) sobre la Capa 6 del draft de Leonardo ("La calidad como cultura y sistema"): (1) "data as a product" como principio de Data Mesh — cita textual de la fuente primaria de Zhamak Dehghani; (2) tests de dbt corriendo en CI/CD vía Slim CI / selector `state:modified`; (3) el patrón Circuit Breaker aplicado a datos — origen en arquitectura de software (Nygard/Fowler) vs. uso real en el dominio de datos; (4) si existe una fuente seria que formalice el "SLA de un dataset" con las dimensiones frescura/completitud/disponibilidad que menciona el draft. Todo verificado por fetch directo contra fuentes primarias (martinfowler.com, docs.getdbt.com, docs.getmontecarlo.com, docs.datahub.com) más búsqueda dedicada de corroboración donde no había una única fuente oficial (§3 y §4, marcado explícitamente donde aplica).

---

## 1. "Data as a product" — fuente primaria: Zhamak Dehghani, martinfowler.com (2019)

**VEREDICTO: el draft usa el término correctamente y con la fuente correcta implícita — verificado por fetch directo, cita textual completa disponible.**

**Fuente primaria**: Zhamak Dehghani, "How to Move Beyond a Monolithic Data Lake to a Distributed Data Mesh", publicado el **20 de mayo de 2019** en martinfowler.com, bajo su rol declarado en el artículo de "Principal technology consultant at Thoughtworks". Este es el artículo que acuñó públicamente el término Data Mesh — no es una fuente secundaria que lo describa, es el origen.

Fuente: [martinfowler.com/articles/data-monolith-to-mesh.html](https://martinfowler.com/articles/data-monolith-to-mesh.html) (fetch directo).

### La sección exacta y las seis cualidades, cita textual

El principio vive bajo el heading exacto **"Domain data as a product"** (no "data as a product" a secas — el matiz de Dehghani es que cada *dominio* es dueño de su propio data product, coherente con el resto del artículo sobre arquitectura distribuida por dominios). Dehghani nombra explícitamente seis cualidades que un data product debe tener:

- **Discoverable**: "A data product must be easily discoverable. A common implementation is to have a registry, a data catalogue, of all available data products with their meta information."
- **Addressable**: "A data product, once discovered, should have a unique address following a global convention that helps its users to programmatically access it."
- **Trustworthy and truthful**: "No one will use a product that they can't trust... owners of the data products to provide an acceptable Service Level Objective around the truthfulness of the data."
- **Self-describing semantics and syntax**: "Quality products require no consumer hand holding to be used: they can be independently discovered, understood and consumed... Data schemas are a starting point."
- **Inter-operable and governed by global standards**: "Following certain standards and harmonization rules... Such standardizations should belong to a global governance, to enable interoperability between polyglot domain datasets."
- **Secure and governed by a global access control**: "Accessing product datasets securely is a must... the access control is applied at a finer granularity, for each domain data product."

**Nota importante para el skill**: estas seis cualidades vienen textualmente de la fuente primaria — si el skill las va a citar como lista, debería usar estos seis nombres exactos (Dehghani los usa como subtítulos), no una paráfrasis libre.

### SLOs de calidad — lo que la fuente dice y lo que NO dice (relevante para §4)

Dentro de la misma sección, y separado de las seis cualidades, Dehghani también dice:

> "Each domain dataset must establish *Service Level Objectives* for the quality of the data it provides: timeliness, error rates, etc."

Y más abajo:

> "Each data product defines and assures the target level of its integrity and truthfulness as a set of SLOs."

**Verificado por búsqueda textual completa del artículo**: las palabras "SLA", "freshness", "completeness" y "availability" **no aparecen en ningún punto del artículo**. Dehghani usa "SLO" (no "SLA") y da como ejemplos "timeliness" y "error rates" — no la tríada frescura/completitud/disponibilidad que usa el draft. Esto es relevante para el veredicto de §4: la fuente de Data Mesh respalda la *idea* de SLOs por dataset, pero no la formalización específica con esas tres dimensiones exactas.

---

## 2. dbt tests en CI/CD — Slim CI y el selector `state:modified`

**VEREDICTO: el mecanismo es real, documentado y verificado con sintaxis exacta contra docs.getdbt.com. El draft debe nombrarlo como "Slim CI" + `state:modified`, no como una descripción genérica de "correr tests en el pipeline".**

### El término "Slim CI" sí es terminología oficial de dbt (no informal)

Cita textual de la página de referencia de estado local:

> "Together, the [`state`](https://docs.getdbt.com/reference/node-selection/methods#state) selector and deferral enable ['slim CI'](https://docs.getdbt.com/best-practices/best-practice-workflows#run-only-modified-models-to-test-changes-slim-ci)."

Fuente: [reference/node-selection/state-selection — "About local state in dbt"](https://docs.getdbt.com/reference/node-selection/state-selection) (fetch directo).

El propio anchor de esa cita apunta a una sección con el nombre literal `run-only-modified-models-to-test-changes-slim-ci` en la guía de mejores prácticas, que confirma el mecanismo con explicación y sintaxis:

> "By comparing to artifacts from a previous production run, dbt can determine which models are modified and build them on top of their unmodified parents."

Fuente: [best-practices/best-practice-workflows](https://docs.getdbt.com/best-practices/best-practice-workflows) (fetch directo).

### Sintaxis exacta (cita textual de comandos, misma página)

```bash
dbt run -s state:modified+ --defer --state path/to/prod/artifacts
dbt test -s state:modified+ --defer --state path/to/prod/artifacts
```

Variantes documentadas en la misma página, para re-ejecutar solo lo que falló (útil para el ángulo "circuit breaker" de CI, ver §3):

```bash
dbt build --select state:modified+ result:error+ --defer --state path/to/prod/artifacts
dbt build --select state:modified+ result:error+ result:fail+ --defer --state path/to/prod/artifacts
```

### El selector `state:modified` en detalle — página de referencia de node-selection methods

- `state:new` — "There is no node with the same `unique_id` in the comparison manifest."
- `state:modified` — "All new nodes, plus any changes to existing nodes."
- `state:old` / `state:unmodified` — los complementos.
- Sub-selectores: `state:modified.body`, `state:modified.configs`, `state:modified.relation`, `state:modified.persisted_descriptions`, `state:modified.macros`, `state:modified.contract`.
- Requisito explícito: "The file path of the comparison manifest *must* be specified via the `--state` flag or environment variable."

Fuente: [reference/node-selection/methods](https://docs.getdbt.com/reference/node-selection/methods) (fetch directo).

### Cómo se obtiene el "estado de producción" contra el que se compara (dbt Cloud CI jobs)

> "dbt tracks the state of what's running in your production environment. When you run a CI job, only the modified data assets in your pull request (PR) and their downstream dependencies are built and tested in a staging schema."

Y, específicamente sobre qué usa dbt como referencia de comparación:

> "To be able to find modified nodes, dbt needs to have something to compare against. dbt uses the last successful run of any job in your Production environment as its comparison state."

Fuentes: [docs/deploy/continuous-integration](https://docs.getdbt.com/docs/deploy/continuous-integration), [guides/set-up-ci](https://docs.getdbt.com/guides/set-up-ci) (fetch directo, ambas). En dbt Cloud, el build de CI corre en un schema temporal aislado con convención `dbt_cloud_pr_<job_id>_<pr_id>`.

**Nota de honestidad epistémica**: "Slim CI" y `state:modified` son terminología de dbt Core / mecanismo agnóstico de plataforma (funciona en cualquier CI que invoque el CLI con `--state`); la parte de schema temporal `dbt_cloud_pr_*` es específica de **dbt Cloud** como producto — si el skill quiere ser preciso, debe separar "el mecanismo `state:modified` + `--defer`" (dbt Core, universal) de "cómo dbt Cloud lo empaqueta en un job de CI con schema aislado" (específico de plataforma). No se verificó en este research el equivalente exacto para GitHub Actions/dbt Core standalone más allá de que la sintaxis de comandos es la misma — el pedido no lo requería.

---

## 3. "Circuit breaker" aplicado a datos — origen en software, uso real (y honesto) en el dominio de datos

**VEREDICTO: el patrón original es de arquitectura de software (Fowler/Nygard) y NO trata de datos — pero, a diferencia de lo que se podría asumir, SÍ existe una corriente real y con nombre propio dentro de ingeniería de datos que usa "circuit breaker" formalmente. El draft debe presentarlo como préstamo consciente de un patrón de software, con atribución, y con una corrección importante: la parte de "servir el último snapshot bueno" NO es lo que las fuentes de datos que usan este término describen — ellas describen bloqueo/vacío, no fallback a datos viejos.**

### 3.1 El patrón original — Fowler, citando a Nygard

Cita textual de Martin Fowler, bliki, sobre el problema que resuelve:

> "One of the big differences between in-memory calls and remote calls is that remote calls can fail, or hang without a response until some timeout limit is reached... What's worse if you have many callers on a unresponsive supplier, then you can run out of critical resources leading to cascading failures across multiple systems."

Mecanismo:

> "You wrap a protected function call in a circuit breaker object, which monitors for failures. Once the failures reach a certain threshold, the circuit breaker trips, and all further calls to the circuit breaker return with an error, without the protected call being made at all."

Atribución explícita a Nygard, cita textual:

> "Michael Nygard popularized the Circuit Breaker pattern to prevent this kind of catastrophic cascade" — en su libro *Release It!*

Estados descritos: **closed** (operación normal), **open** (umbral de fallos superado, deja de intentar), **half-open** (intenta recuperación tras un timeout).

Fuente: [martinfowler.com/bliki/CircuitBreaker.html](https://martinfowler.com/bliki/CircuitBreaker.html) (fetch directo). **Verificado explícitamente: este artículo no menciona pipelines de datos ni datasets en ningún punto** — es 100% sobre llamadas remotas entre servicios.

### 3.2 ¿Existe una fuente seria de datos que use "circuit breaker" formalmente? Sí — con matiz importante

Búsqueda dedicada de corroboración (no una única fuente oficial de docs, sino un rastreo de quién acuñó/popularizó el uso en el dominio de datos):

- **Sandeep Uttamchandani** (Chief Data Architect en Intuit al momento de la charla, luego autor de un libro O'Reilly sobre plataformas de datos, 20+ años en Data/Analytics/AI) dio una charla llamada explícitamente **"Circuit breakers to safeguard for garbage in, garbage out"** en **Strata Data Conference NY 2018** — probablemente el punto de origen del término aplicado a datos. Cita del abstract: pipeline de múltiples etapas (ingestion, cleansing, transformations, analysis) con checkpoints; "the circuit is broken, and processing does not progress to the next stage" cuando se violan reglas de calidad. Fuente: [conferences.oreilly.com/strata/strata-ny-2018 — detail/69610](https://conferences.oreilly.com/strata/strata-ny-2018/public/schedule/detail/69610.html).
- El mismo autor publicó el post **"How we deal with Data Quality using Circuit Breakers"**, con esta cita textual clave sobre qué pasa río abajo cuando el circuito se abre: **"The result is that data will be missing in the reports for time-periods of low quality, but if present, it is guaranteed to be correct."** Fuente: [modern-cdo.medium.com/taming-data-quality-with-circuit-breakers](https://modern-cdo.medium.com/taming-data-quality-with-circuit-breakers-dbe550d3ca78).
- **Andrew Jones** — autor reconocido en el espacio de data contracts (autor de data-contracts.com, con trayectoria en GoCardless/Monzo), escribe explícitamente: **"we use the circuit breaker pattern to stop a data pipeline when the data does not meet our quality or integrity expectations"**, con el objetivo declarado de evitar que "poor data spreading widely through other pipelines and services or being used to make automated decisions that could affect our customers." Fuente: [andrew-jones.com/daily/2024-06-10-the-circuit-breaker-pattern](https://andrew-jones.com/daily/2024-06-10-the-circuit-breaker-pattern/).
- **Ingeniería de Ibotta** (blog técnico de la empresa), post **"Pipeline Quality Checks, Circuit Breakers, and Other Validation Mechanisms"**: "'Circuit-breaker' validations are upstream of the final table build task, so they halt the process that builds the table if the source table does not pass the checks" — con un ejemplo real de un caso donde un humano tuvo que aprobar manualmente para que el pipeline continuara. Fuente: [medium.com/building-ibotta/pipeline-quality-checks-circuit-breakers-and-other-validation-mechanisms](https://medium.com/building-ibotta/pipeline-quality-checks-circuit-breakers-and-other-validation-mechanisms-761fc5b1ebe4).

**Conclusión de esta sub-sección**: "circuit breaker" **sí es un término con uso real y repetido en ingeniería de datos**, no una analogía inventada por el draft — hay al menos cuatro fuentes independientes (una charla de conferencia reconocida + su autor, un practicante de data contracts con credibilidad propia, y un blog de ingeniería de una empresa) que lo usan con ese nombre exacto. **No es, sin embargo, un término estandarizado por ningún organismo/vendor de referencia** (no aparece así en docs.getdbt.com, Great Expectations, ni en documentación oficial de ningún catálogo/observabilidad revisado en este research) — es terminología de práctica/comunidad, con origen rastreable a Uttamchandani (2018), no un patrón "oficial" del dominio de datos al nivel de, por ejemplo, `state:modified` en dbt.

### 3.3 El matiz que el draft debe corregir: "bloquear" sí, "servir el último snapshot bueno" no está en las fuentes de datos

**Este es el hallazgo más importante de esta sección.** Las cuatro fuentes de datos revisadas (Uttamchandani x2, Andrew Jones, Ibotta) describen consistentemente el circuit breaker de datos como **bloqueo/vacío**, no como servir un snapshot viejo:

- Uttamchandani, textual: los datos **"will be missing in the reports for time-periods of low quality"** — no dice que se sirva la versión anterior, dice que el reporte queda sin datos para ese período.
- Ibotta, textual: el circuit breaker **"halt[s] the process that builds the table"** — requiere intervención manual, no hay fallback automático a una versión anterior.
- Se revisó también un cuarto post de un vendor de calidad de datos (firsteigen.com) por completitud: mismo patrón — **"halts the further propagation of data to downstream systems"**, sin mención de servir datos previos.

Es decir: el ingrediente "**no promover datos malos**" del draft está bien respaldado por estas fuentes reales de "circuit breaker" de datos. Pero el ingrediente "**sirve el último snapshot bueno en vez del nuevo corrupto**" **no aparece en ninguna de las fuentes que usan el término "circuit breaker"** — ese comportamiento específico (fallback automático a la última versión válida) es más cercano al **fallback** del patrón de software original de Fowler/Nygard (que sí incluye la idea de devolver una respuesta alternativa cuando el circuito está abierto, aunque Fowler no lo llama "snapshot") que a cómo se usa el término en el dominio de datos.

**Ángulo de consistencia interna del suite (verificado)**: la idea de "seguir sirviendo el último dato bueno" **ya existe en el suite**, pero desde un ángulo distinto — arquitectura de orquestación, no calidad. En `skills/pipelines-architecture-data-engineering/references/serving-pipeline-output.md`:

> "A live-serving layer carries an availability/latency SLA that the batch pipeline feeding it does not. That's exactly why they're separated: if the pipeline fails, the serving layer keeps answering from the last good snapshot instead of going down with it."

Esa frase describe una **consecuencia de la arquitectura desacoplada** (batch pipeline separado del serving store) ante un **fallo del pipeline** — no un chequeo de calidad que decide activamente no promover. El draft de la Capa 6, en cambio, describe un **gate deliberado de calidad** ("si un chequeo crítico falla") que decide no promover. Son complementarios, no duplicados: la skill de calidad debería enfocarse en *cuándo y por qué se dispara el bloqueo* (el chequeo que falla, el umbral, quién decide) y remitir al lector a `serving-pipeline-output.md` para el *cómo* arquitectónico de que el consumidor siga viendo algo válido — sin repetir esa mecánica de desacople ahí. Recomendación concreta: si el skill de calidad usa "circuit breaker" con el detalle "sirve el último snapshot bueno", debe marcarlo explícitamente como **una aplicación combinada** — el bloqueo viene del patrón circuit-breaker-de-datos (real, con las fuentes de arriba), el fallback a snapshot viene de la arquitectura de desacople ya documentada en `pipelines-architecture-data-engineering`, y esa combinación específica (bloquear + fallback automático) no está, tal cual, en ninguna fuente única verificada.

---

## 4. Ownership y SLA de un dataset con dimensiones frescura/completitud/disponibilidad

**VEREDICTO: no existe una única fuente primaria oficial que formalice exactamente esa tríada (frescura + completitud + disponibilidad) como "el" SLA de un dataset. Hay piezas parciales y reales en Data Mesh, Monte Carlo y DataHub — pero cada una cubre un subconjunto distinto, y ninguna las agrupa así. El draft debe presentarlo como síntesis razonable del espacio de observabilidad/data-mesh, no citar una única fuente que lo diga textualmente así.**

### Data Mesh (Dehghani) — ya cubierto en §1

SLOs sí, pero con "timeliness, error rates" como ejemplos — no la tríada exacta del draft, y usa "SLO" no "SLA". Ver cita completa en §1.

### Monte Carlo — dimensiones de calidad documentadas, pero sin "SLA" formal ni "availability" como dimensión propia

Cita textual de la documentación de producto:

> **Freshness**: "Checks if data arrives within the expected window for timely decisions."
> **Completeness**: "Assesses if all necessary data points are included."

Fuente: [docs.getmontecarlo.com/docs/data-quality](https://docs.getmontecarlo.com/docs/data-quality) (fetch directo).

**Hallazgo importante verificado por fetch directo**: las seis dimensiones que Monte Carlo documenta formalmente en esa página son **Accuracy, Completeness, Consistency, Timeliness, Validity, Uniqueness** — "Availability" **no es una de sus seis dimensiones documentadas**. "Freshness" tampoco aparece en esa lista de seis (aparece "Timeliness", que es el concepto más cercano, no verificado aquí si Monte Carlo los trata como sinónimos exactos). Búsqueda dedicada de "SLA" en `docs.getmontecarlo.com` solo encontró una mención de uso ("customers use SLAs to report on the current state and trend of specific monitors") — no una página que defina formalmente "data SLA" como concepto propio con dimensiones nombradas.

### DataHub — sí formaliza "SLA operacional" pero solo para frescura, vía Data Contracts

Cita textual, definición de Data Contract:

> "an agreement between a data asset's producer and consumer, serving as a promise about the quality of the data."

Y, en el contexto de qué hace verificable a un contrato:

> "schema checks, column-level data checks, and operational SLA-s"

Fuente: [docs.datahub.com/docs/managed-datahub/observe/data-contract](https://docs.datahub.com/docs/managed-datahub/observe/data-contract) (fetch directo). Los tipos de assertion documentados son **Schema, Freshness, Volume, Custom, Column** — no hay una categoría llamada "Completeness" ni "Availability" como tipos de assertion de primer nivel (Volume es lo más cercano a completitud agregada; no se verificó una categoría específica de "disponibilidad" del dataset en sí, distinta de frescura).

**Sobre ownership**: se revisó `docs.datahub.com/docs/introduction` — DataHub menciona ownership como metadato adjunto a un dataset (ej. `"owner_team": "data-platform"` vía SDK) y como parte de "Rich Dataset Profiles", pero **no formaliza responsabilidades de ownership ni las ata explícitamente a un SLA con dimensiones nombradas** en la página de introducción revisada.

### Conclusión honesta de §4

No se encontró una fuente primaria única que diga, textualmente, "el SLA de un dataset tiene estas tres dimensiones: frescura, completitud, disponibilidad". Lo que sí está verificado:

1. **El concepto de "SLO/SLA por dataset" es real y tiene raíz en Data Mesh** (Dehghani, 2019) — ownership + garantías explícitas por dominio.
2. **"Frescura" (freshness/timeliness) es la dimensión mejor y más consistentemente formalizada** entre las fuentes revisadas — aparece en Monte Carlo (dimensión propia), DataHub (tipo de assertion de primer nivel, con "operational SLA-s" citado literalmente en ese contexto), y como ejemplo explícito de Dehghani ("timeliness").
3. **"Completitud" está documentada como dimensión de calidad** (Monte Carlo la nombra explícitamente), pero no ligada al lenguaje de "SLA" en la fuente revisada.
4. **"Disponibilidad" es la más débil de las tres en la evidencia recolectada** — no aparece como dimensión propia en Monte Carlo, ni como tipo de assertion en DataHub, en las páginas verificadas. Si el skill la usa, debe tratarse como un término razonable por analogía con SLAs de infraestructura clásicos (uptime de un servicio), no como algo formalmente definido así por una fuente de calidad de datos.

**Recomendación concreta para el skill**: presentar la tríada frescura/completitud/disponibilidad como una **síntesis pedagógica razonable** (útil para explicar el concepto), citando a Data Mesh para el "por qué" (ownership + SLO por dominio) y a Monte Carlo/DataHub para "frescura" y "completitud" como dimensiones con respaldo documental real — pero sin atribuir la tríada completa, tal cual, a ninguna fuente única, y marcando "disponibilidad" como el eslabón más débil de los tres.

---

## Resumen de acciones para contenido futuro del skill

1. **"Data as a product"**: citar a Dehghani (martinfowler.com, 2019) con las seis cualidades exactas — Discoverable, Addressable, Trustworthy and truthful, Self-describing, Inter-operable, Secure — bajo el heading "Domain data as a product". Usar "SLO" (no "SLA") si se cita a Dehghani directamente, ya que es el término que ella usa.
2. **dbt tests en CI**: nombrar el mecanismo real — "Slim CI" (término oficial de docs.getdbt.com) + selector `state:modified` (o `state:modified+` para incluir downstream) + flag `--state`/`--defer`, comparado contra "the last successful run of any job in your Production environment". Dar la sintaxis exacta (`dbt build --select state:modified+ --defer --state path/to/prod/artifacts`), no una descripción genérica de "correr tests en el CI".
3. **Circuit breaker**: presentarlo explícitamente como un préstamo del patrón de arquitectura de software (Fowler/Nygard, *Release It!*, sobre llamadas remotas) que la comunidad de ingeniería de datos adoptó y usa con nombre propio desde al menos 2018 (Uttamchandani/Strata, luego Andrew Jones, Ibotta) — con atribución a ambos orígenes. Corregir el matiz: las fuentes de datos que usan "circuit breaker" describen **bloqueo/vacío** (datos faltantes, proceso detenido), no "servir el último snapshot bueno" — ese comportamiento de fallback viene de la arquitectura de desacople ya documentada en `pipelines-architecture-data-engineering/references/serving-pipeline-output.md`. Si el skill combina ambos (bloquear + fallback automático), debe decir explícitamente que es una combinación de dos patrones de fuentes distintas, no una única fuente que ya lo describa así.
4. **Ownership/SLA**: anclar el "por qué" en Data Mesh (Dehghani) y la dimensión de frescura en Monte Carlo/DataHub (ambas con SLA/SLO explícito documentado). Tratar "completitud" como dimensión de calidad real pero sin el lenguaje de SLA en la fuente verificada, y "disponibilidad" como la pieza más débil — analogía razonable, no término establecido con esa función exacta en las fuentes de datos revisadas.

**Nota de honestidad epistémica general**: este research no cubrió Great Expectations, Atlan, ni el libro completo de Dehghani (*Data Mesh: Delivering Data-Driven Value at Scale*, O'Reilly) más allá del artículo original de martinfowler.com — si el skill necesita profundizar en cómo el libro (que es posterior y más extenso que el artículo de 2019) trata SLAs/ownership, eso requeriría una pasada de verificación dedicada adicional contra el libro mismo, no solo el artículo. Tampoco se verificó Soda Core ni Atlan, mencionados de pasada en resultados de búsqueda pero no fetcheados directamente.
