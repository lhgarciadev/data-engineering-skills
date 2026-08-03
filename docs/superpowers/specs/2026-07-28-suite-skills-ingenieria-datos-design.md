# Especificación de Diseño: Suite de Skills de Ingeniería de Datos
## Suite multi-runtime (Claude Code, Codex CLI, Gemini CLI, Copilot CLI) para un equipo de ingeniería de datos

**Fecha:** 2026-07-28
**Responsable:** Leonardo H. García Díaz
**Estado (2026-08-02):** el roadmap se amplió de 8 a **9** skills de dominio — `project-structure-data-engineering` (estructura de paquete, empaquetado y contratos de datos) se entregó el 2026-08-02 fuera del roadmap original y se incorporó formalmente a él ese mismo día, una vez confirmado el caso de uso real que motivó construirla (ver su propia spec, `docs/superpowers/specs/2026-08-02-project-structure-skill-design.md`, y la nota histórica en §8 sobre por qué no debe confundirse con la propuesta de "APIs" descartada antes). **6 de 9** skills de dominio entregadas: `python-data-engineering`, `sql-data-engineering`, `spark-data-engineering`, `pipelines-architecture-data-engineering`, `project-structure-data-engineering`, `quality-data-engineering`, más la orquestadora `data-engineering`. Quedan 3 por construir: `modeling-data-engineering`, `streaming-data-engineering`, `iac-cloud-data-engineering` (ver sección 7, ítem 6, actualizado).

El `name` del manifiesto `.claude-plugin/plugin.json` pasó por dos renombres: primero de `data-engineering` a `data-engineering-suite` (2026-07-29, para evitar que la skill orquestadora — también llamada `data-engineering` — se invocara como `data-engineering:data-engineering` al instalarse vía el flujo de plugin; ver sección 2), y luego de `data-engineering-suite` a `dataforge` (2026-07-30, por branding de cara a publicar en un marketplace).

El esquema de nombres de skill también cambió dos veces. El 2026-07-29 se prefijaron **todos** los identificadores con `dataeng-` (la orquestadora quedaba como `dataeng` a secas), para evitar choques de symlink en los namespaces planos y compartidos `~/.claude/skills/`/`~/.agents/skills/` (nombres genéricos como `python` o `sql` son choques esperando a pasar). El 2026-07-30, ya con el plugin renombrado a `dataforge`, se revirtió ese esquema a uno domain-first: cada skill de dominio termina en el sufijo `-data-engineering` (`python-data-engineering`, `sql-data-engineering`, etc.) y la orquestadora es simplemente `data-engineering` — más legible en un listado de marketplace, sin reintroducir riesgo de colisión porque el plugin ya no comparte nombre con ningún skill. Secciones 3, 4, 5 y 7 ya reflejan los identificadores actuales; la sección 6 conserva la narrativa histórica del primer rename (`python-data-engineering` → `python`, 2026-07-28) sin reescribirla — ver su nota al pie para la cadena completa hasta el nombre actual.

---

## 1. Contexto y objetivo

El equipo (chico, con retos grandes) construye soluciones de datos en varios repos de proyecto separados entre sí (sin repo central de código compartido) — un repo aparte de planeación/estrategia coordina el trabajo pero no contiene código de producto.

El objetivo es que todo el equipo trabaje con el mismo estándar de ingeniería de datos — mismos criterios de diseño, mismas trampas evitadas, mismo vocabulario — sin importar en cuál de esos repos esté parado cada quien. Eso descarta que la suite viva dentro de un solo repo de código puntual: tiene que instalarse una vez por persona y quedar disponible en cualquier proyecto.

El contenido debe ser **agnóstico y generalista**: herramientas y patrones de ingeniería de datos en general (Python, SQL, Spark, modelado, pipelines, streaming, calidad, IaC/cloud), sin referencias a la infraestructura o vocabulario específico de ninguna institución u organización particular (sistemas propietarios internos, Databricks/Synapse como decisión particular, etc.).

## 2. Empaquetado y distribución

**Requisito ampliado:** la suite debe funcionar no solo en Claude Code sino en el ecosistema más amplio de agentes (Codex CLI, Gemini CLI, Copilot CLI). Esto es viable sin mecanismo nuevo porque los cuatro runtimes ya comparten el formato `SKILL.md` (frontmatter `name`+`description` + markdown).

Repo nuevo con una carpeta `skills/` (un `SKILL.md` por skill, sin campos de frontmatter específicos de un runtime). La vía de distribución **primaria y universal** es symlink a la ruta de skills personales de cada runtime:

- `~/.claude/skills/<skill>` — Claude Code
- `~/.agents/skills/<skill>` — ruta compartida que ya reconocen Codex CLI, Gemini CLI y Copilot CLI

Cada persona del equipo clona el repo una vez y symlinkea cada carpeta de `skills/` a ambas rutas; queda disponible en todos sus repos sin copiar archivos a mano.

Como agregado **opcional**, el repo puede incluir además un manifiesto `.claude-plugin/plugin.json` (mismo formato que plugins ya instalados en esta máquina como `railway`/`supabase`/`superpowers`) para quienes prefieran instalar vía el flujo de marketplace de Claude Code en lugar de symlink manual — no es el mecanismo principal, es una comodidad adicional solo para ese runtime.

Nombre propuesto del repo: `data-engineering-skills` (renombrable si el equipo prefiere otro).

## 3. Estructura de carpetas

```
data-engineering-skills/
  README.md                     # instrucciones de instalación (symlinks) por runtime
  .claude-plugin/                # OPCIONAL — solo para instalar vía plugin de Claude Code
    plugin.json                 # name: "dataforge" (2 renombres, ver Estado arriba), version, description, skills: "./skills/"
  skills/
    data-engineering/                     # orquestadora — punto de entrada para tareas amplias/cruzadas
      SKILL.md
    python-data-engineering/              # ya construida y probada (migra desde un repo previo del equipo)
      SKILL.md
      references/
        iterators-and-generators.md
        decorators-and-context-managers.md
        oop-for-pipelines.md
        concurrency-and-the-gil.md
        memory-and-performance.md
        data-validation.md
        production-patterns.md
    sql-data-engineering/
      SKILL.md
    spark-data-engineering/                # Spark en general; ejemplos de código en PySpark
      SKILL.md
    modeling-data-engineering/
      SKILL.md
    pipelines-architecture-data-engineering/
      SKILL.md
    project-structure-data-engineering/            # entregada 2026-08-02 fuera del roadmap original, incorporada ese mismo día — ver Estado arriba
      SKILL.md
      references/
        package-layout.md
        packaging-and-tooling.md
        data-contracts.md
    streaming-data-engineering/
      SKILL.md
    quality-data-engineering/
      SKILL.md
    iac-cloud-data-engineering/
      SKILL.md
```

Todo identificador de skill de dominio termina en el sufijo `-data-engineering`, liderando con el nombre del dominio (la orquestadora es la excepción: `data-engineering` a secas) — ver Estado arriba para el porqué. Cada skill de dominio (todas menos la orquestadora) sigue el mismo formato que `python-data-engineering`: overview, "when to use", tabla de quick reference, reference files por tema pesado, tabla de common mistakes. Contenido en inglés (convención técnica ya acordada), ejemplos de código en el lenguaje más relevante al tema.

## 4. Las 9 skills de dominio — propósito de cada una

*(Nota histórica: 8 de estas 9 estaban en el roadmap original de esta spec (2026-07-28); `project-structure-data-engineering` se agregó después, el 2026-08-02, y se incorpora aquí como la novena — ver Estado arriba para el porqué y su propia spec para el detalle completo.)*

| Skill | Cubre | No cubre (frontera con otra skill) |
|---|---|---|
| `python-data-engineering` | Generators/streaming, decoradores, context managers, OOP para pipelines, GIL/concurrencia, memoria/performance (pandas/Polars/DuckDB), validación (Pydantic/Pandera), testing e idempotencia a nivel de código | Orquestadores (Airflow/Dagster/Prefect) como sistema — eso es `pipelines-architecture-data-engineering` |
| `sql-data-engineering` | Optimización de queries, window functions, CTEs, planes de ejecución, indexación, modelado de queries analíticas | Modelado de esquemas/dimensional — eso es `modeling-data-engineering` |
| `spark-data-engineering` | Arquitectura y tuning de Spark en general (particionamiento, shuffles, AQE, Catalyst, joins, cache/checkpointing, memoria de executor/driver) + una sección propia para lo específico de PySpark (overhead de UDFs Python vía py4j, pandas UDFs con Arrow, riesgo de memoria de `.collect()`/`.toPandas()`) | Streaming estructurado (Structured Streaming, watermarks) — eso es `streaming-data-engineering` |
| `modeling-data-engineering` | Modelado dimensional (star/snowflake), Kimball vs Data Vault, SCDs, granularidad de hechos, normalización vs denormalización para analítica | Validación de esquema en tiempo de ejecución — eso es `quality-data-engineering` |
| `pipelines-architecture-data-engineering` | Elección y patrones de orquestador (Airflow/Dagster/Prefect), diseño de DAGs, backfills, dependency management, topología de despliegue, arquitectura de proyecto dbt | Cómo escribir el código idempotente dentro de una tarea — eso ya está en `python-data-engineering`; mecánica SQL de `incremental` de dbt — eso es `sql-data-engineering` |
| `project-structure-data-engineering` | Layout de paquete de ingesta/exposición (`config`/`extract`/`transform`/`load`), empaquetado (Poetry vs. `uv`), contratos de datos | Código a nivel de función/clase — eso es `python-data-engineering`; decisión arquitectónica de servir datos vía API — eso es `pipelines-architecture-data-engineering` |
| `streaming-data-engineering` | Kafka, Spark Structured Streaming, ventanas/watermarks, exactly-once vs at-least-once, particionamiento de tópicos | Arquitectura general de Spark batch — eso es `spark-data-engineering` |
| `quality-data-engineering` | Dimensiones de calidad de datos, frameworks de gobierno de datos (Great Expectations a nivel organizacional), monitoreo/alertas de DQ | Qué librería usar para validar un dataframe puntual (Pydantic vs Pandera) — eso ya está en `python-data-engineering` |
| `iac-cloud-data-engineering` | Terraform/IaC para infraestructura de datos, patrones de despliegue cloud-agnósticos, gestión de secretos, redes/permisos para plataformas de datos, **Docker/Compose** (stacks locales de desarrollo y containerización de jobs para despliegue — mismo modelo mental que Terraform: definir declarativamente un entorno) | Decisión de qué plataforma cloud/warehouse específica usar — eso es una decisión de proyecto, no de esta skill |

Los tópicos detallados de cada skill (más allá de este propósito de alto nivel) se definen en una siguiente fase, skill por skill, con el usuario aportando los temas y el asistente investigando para complementar — **dos fuentes**: búsqueda web (mismo proceso que se usó para `python-data-engineering`) y revisión del plugin `data-engineering` de `wshobson/agents` (MIT — `spark-optimization`, `airflow-dag-patterns`, `dbt-transformation-patterns`, `data-quality-frameworks`) como insumo adicional para los tópicos de `spark-data-engineering`, `pipelines-architecture-data-engineering`, `sql-data-engineering` y `quality-data-engineering`, con atribución. No se adopta tal cual: su estilo (cheat-sheet de do's/don'ts + snippets) y sus límites de dominio (ej. `airflow-dag-patterns` es solo-Airflow, no agnóstico de orquestador como se definió `pipelines-architecture-data-engineering` en la sección 4) difieren de los ya fijados acá.

## 5. Mecánica de la skill orquestadora (`data-engineering`)

- **Cuándo se activa**: tareas amplias o que cruzan varios dominios ("diseña este pipeline end-to-end", "revisa esta solución completa"). Una tarea de un solo dominio ("revisa este job de PySpark") activa directo la skill de dominio correspondiente por su propia descripción — la orquestadora no participa, sin overhead.
- **Qué hace al activarse**:
  1. Identifica cuáles de las 9 skills de dominio aplican a la tarea.
  2. Despacha un subagente por dominio relevante, **en paralelo cuando el entorno lo soporta** — redactado en lenguaje neutro de runtime, no atado a un tool específico de Claude Code, para que cada plataforma lo traduzca a su propio mecanismo: `Agent` tool nativo en Claude Code, `invoke_agent` nativo en Gemini CLI, `spawn_agent` en Codex CLI (requiere `multi_agent = true` en `~/.codex/config.toml` — apagado por defecto). **Fallback explícito**: si el entorno no soporta despacho de subagentes, hace el análisis de cada dominio en secuencia dentro de la misma sesión en vez de fallar.
  3. Sintetiza los resultados en una sola respuesta, señalando explícitamente las interacciones cruzadas entre dominios que un análisis aislado no vería (ejemplo: una partition key de Spark que no calza con la clustering key del warehouse).
- **Qué NO hace**: no ejecuta cambios de código ni ningún paso equivalente al "PR → CI → merge" de la skill `pm` de referencia (`catalhyst-matchmaking`) — esta suite es de referencia/diseño, no de ejecución de trabajo. La analogía con `pm` es solo el patrón de delegar análisis paralelizable a subagentes de solo lectura, no su ciclo de ejecución completo.

## 6. Migración de `python-data-engineering`

La skill ya construida en el repo previo del equipo (`.claude/skills/python-data-engineering/`, SKILL.md + 7 reference files) se traslada sin cambios de contenido al nuevo repo, en `skills/python/`, renombrando solo el identificador (`python-data-engineering` → `python`) para evitar redundancia con el prefijo `data-engineering:` que Claude Code antepone a las skills de un plugin.

*(Nota 2026-07-29: ese identificador `python` se renombró de nuevo, a `dataeng-python` — ver Estado arriba. La narrativa de esta sección se deja intacta como registro histórico del primer rename.)*

*(Nota 2026-07-30: `dataeng-python` se renombró una vez más, de vuelta a `python-data-engineering` — el nombre original de esta misma sección. No es un error de circularidad: el motivo del rename original (evitar `data-engineering:python-data-engineering` redundante) ya no aplica porque el plugin se llama `dataforge`, no `data-engineering` — ver Estado arriba.)*

## 7. Próximos pasos (fuera de esta especificación)

1. Crear el repo `data-engineering-skills` con la estructura de la sección 3, incluyendo el `README.md` con instrucciones de symlink por runtime.
2. Resolver el destino del folder `python-data-engineering` que ya existe sin commitear en el `.claude/skills/` del repo previo del equipo. Recomendación: commitearlo ahí como respaldo temporal y eliminarlo de este repo recién cuando la migración al repo nuevo esté confirmada — así no se pierde el trabajo si el proceso se corta a mitad de camino.
3. Migrar `python` según la sección 6.
4. Escribir `SKILL.md` de la orquestadora `data-engineering` según la sección 5.
5. Validar la orquestadora con un escenario de prueba que cruce 3+ dominios (análogo al test de discoverability que ya se le hizo a `python` con el escenario de la API paginada) — confirmar que el fan-out y la síntesis funcionan antes de darla por lista.
6. Por cada una de las 3 skills de dominio restantes (`modeling-data-engineering`, `streaming-data-engineering`, `iac-cloud-data-engineering` — `sql-data-engineering` y `spark-data-engineering` ya se entregaron 2026-07-29, `pipelines-architecture-data-engineering` se entregó 2026-07-30, y `quality-data-engineering` se entregó 2026-08-03, ver `docs/superpowers/specs/2026-07-28-sql-skill-design.md`, `docs/superpowers/specs/2026-07-29-spark-skill-design.md`, `docs/superpowers/specs/2026-07-30-pipelines-architecture-skill-design.md` y `docs/superpowers/specs/2026-08-03-quality-skill-design.md`): el usuario aporta tópicos → investigación web complementaria → redacción → validación de discoverability liviana (mismo proceso que `python-data-engineering` y `sql-data-engineering`).
7. Al escribir las specs de `pipelines-architecture-data-engineering` e `iac-cloud-data-engineering` (parte del ítem 6): resolver ahí, explícitamente, el scope fork contra la potencial 9na skill "APIs para Ingeniería de Datos" — ver §8 para el detalle de qué le tocaría a cada lado. *(Nota 2026-07-30: la mitad de `pipelines-architecture-data-engineering` ya está resuelta — ver `docs/superpowers/specs/2026-07-30-pipelines-architecture-skill-design.md` §2.1. La mitad de `iac-cloud-data-engineering` sigue pendiente hasta que esa skill se escriba.)*
8. Al escribir la spec de `streaming-data-engineering` (parte del ítem 6): incluir explícitamente CDC (Debezium, captura basada en log/WAL/binlog, conectores Kafka Connect CDC) en su alcance — ver §8 para el detalle del gap encontrado.

## 8. Fuera de alcance (de esta fase)

- Contenido detallado (reference files) de las skills de dominio pendientes — se define skill por skill en la fase siguiente. Eran 7 al escribir esta spec (2026-07-28); `sql-data-engineering`, `spark-data-engineering`, `pipelines-architecture-data-engineering`, `project-structure-data-engineering` (9na skill agregada al roadmap, 2026-08-02) y `quality-data-engineering` ya se entregaron desde entonces, quedan 3 (ver Estado arriba y §7 ítem 6).
- Visibilidad del repo (privado del equipo vs. algo más amplio) y si se publica además en un marketplace de Claude Code — se resuelve al crear el repo; no afecta la vía universal de symlinks, que ya queda definida en la sección 2.
- Cualquier convención o mandato específico de una institución u organización particular — la suite es agnóstica por decisión explícita (sección 1).
- Recorte y cross-linking de contenido que hoy vive en `python-data-engineering` pero en rigor pertenece a otra skill futura: las menciones a Airflow/Dagster/Prefect en `skills/python-data-engineering/references/production-patterns.md` (territorio de `pipelines-architecture-data-engineering`) y a Great Expectations en `skills/python-data-engineering/references/data-validation.md` (territorio de `quality-data-engineering`). Ambas se aplican recién cuando esas skills existan — hacerlo antes dejaría referencias rotas. El cross-link hacia `spark-data-engineering` (desde `concurrency-and-the-gil.md`) ya se cerró (2026-07-29), y el de Great Expectations hacia `quality-data-engineering` también (2026-08-03, parte de la entrega de esa skill — ver Estado arriba). Solo queda pendiente el de Airflow/Dagster/Prefect hacia `pipelines-architecture-data-engineering`, aunque esa skill ya entregó (2026-07-30) — no se aplicó como parte de esa entrega y sigue abierto.
- **"APIs para Ingeniería de Datos" como potencial 9na skill de dominio — CERRADO 2026-07-30 (descartada).** Hallazgo original (backlog agregado 2026-07-30, equipo evaluando construcción de APIs para compartir datos y consumo de APIs externas — no confirmado ni scopeado formalmente en su momento): esta misma spec afirmaba que "el consumo de APIs (ingesta: paginación, rate limiting, retries) ya está cubierto dentro de `python-data-engineering` — eso no es gap." Esa afirmación era **incorrecta** — verificado contra el contenido real: lo único que existía era un decorator de retry genérico, sin jitter y sin manejo específico de 429. Cierre: al escribir la spec de `pipelines-architecture-data-engineering` (2026-07-30) se resolvió el scope fork completo contra las tres mitades de la propuesta — mitad de consumo → `python-data-engineering/references/external-api-integration.md` (nuevo reference file, cierra el gap real recién confirmado); mitad de decisión de serving (API vs. stream vs. export vs. share) → `pipelines-architecture-data-engineering/references/serving-pipeline-output.md`; mitad de implementación (construir/hostear un servicio API real — framework, REST/GraphQL/gRPC, endpoints) → excluida explícitamente del alcance de la suite en vez de diferida, por ser ingeniería de backend general sin caso de uso real confirmado. Ver `docs/superpowers/specs/2026-07-30-pipelines-architecture-skill-design.md` §2.1 para el razonamiento completo. Con las tres mitades resueltas (dos con hogar, una excluida explícitamente), la 9na skill queda descartada como propuesta — la mitad de hosting/infraestructura y la de contrato/versionado de esquema, si algún día se confirma un caso de uso real de serving, se resuelven como cross-links normales hacia `iac-cloud-data-engineering`/`quality-data-engineering` cuando esas skills existan, no como parte de una 9na skill dedicada.
- **Novena skill de dominio, pero NO la de "APIs" descartada arriba — `project-structure-data-engineering`, entregada 2026-08-02.** No confundir con la propuesta de "APIs para Ingeniería de Datos" descartada en el punto anterior: son dos propuestas de 9na skill completamente distintas, evaluadas en momentos distintos contra el mismo criterio de la suite (uso real confirmado). La de APIs se descartó por falta de caso de uso real; `project-structure-data-engineering` sí lo tenía (dos repos privados reales compartidos por un colega, más una necesidad concreta del equipo) y se construyó — ver su spec dedicada, `docs/superpowers/specs/2026-08-02-project-structure-skill-design.md`.
- **CDC (captura de cambios en el origen) sin cobertura explícita en ningún lado** (hallazgo 2026-07-30, verificado por grep contra el contenido real de las 3 skills shippeadas, no supuesto). `sql-data-engineering` cubre "el patrón detrás de la deduplicación CDC" (CTE + `ROW_NUMBER`, en `window-functions.md`/`engineering-query-patterns.md`) pero **asume que el dato de cambio ya llegó** por algún mecanismo externo — no enseña cómo se captura. Ningún skill construido o planeado cubre la captura real (Debezium, log-based/WAL/binlog tailing, conectores Kafka Connect CDC). El hogar natural es `streaming-data-engineering` (Kafka ya está en su alcance), pero su descripción actual en §4 solo menciona semántica de *procesamiento* de streams (ventanas/watermarks, exactly-once), no *captura* de cambios en el origen. Acción ya registrada en §7 ítem 8: incluir CDC explícitamente en el alcance de esa spec cuando se escriba. `engineering-query-patterns.md` menciona ahora explícitamente (2026-07-30, ver cierre abajo) que el CDC log-based queda fuera de su alcance y pertenece a esa futura skill — cuarto cross-link deferido de este ítem (mismo tratamiento que los tres de `python-data-engineering` arriba).
- **Full load (truncate-and-reload) e incremental del lado de extracción, sin cobertura — CERRADO 2026-07-30.** Hallazgo original: verificado por grep, cero menciones de "full load"/"full refresh"/watermark de extracción en ninguna de las 3 skills shippeadas; lo único cubierto era el lado de **escritura** del incremental (`MERGE`/upsert-by-key en `sql-data-engineering`, upsert-by-key en `python-data-engineering`). Cierre: 2 investigaciones en paralelo contra documentación oficial (PostgreSQL, MySQL, SQL Server/Azure Synapse, Snowflake, BigQuery, Redshift, dbt para full load; Microsoft Learn/Azure Data Factory, AWS whitepapers/Glue, Airbyte, Fivetran, Meltano Singer SDK, Airflow/Dagster/Prefect para extracción incremental) — ver `docs/superpowers/research/2026-07-30-full-load-truncate-reload-verification.md` y `docs/superpowers/research/2026-07-30-incremental-extraction-watermark-verification.md`. Contenido agregado: sección "Full load (truncate-and-reload)" e "Incremental extraction: the watermark pattern" en `sql-data-engineering/references/engineering-query-patterns.md` (mecánica SQL por motor); sección "Incremental extraction: tracking what's new" en `python-data-engineering/references/production-patterns.md` (dónde vive el estado del watermark entre corridas — tabla de control, estado nativo del orquestador, checkpoint file). Ambos `SKILL.md` actualizados (quick reference + common mistakes). Autorevisión aplicada contra el estándar `writing-great-skills`.
