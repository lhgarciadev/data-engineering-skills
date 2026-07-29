# Especificación de Diseño: Suite de Skills de Ingeniería de Datos
## Suite multi-runtime (Claude Code, Codex CLI, Gemini CLI, Copilot CLI) para el equipo del Data Team

**Fecha:** 2026-07-28
**Responsable:** Leonardo H. García Díaz (Org)
**Estado (2026-07-29):** 3 de 8 skills entregadas — orquestadora `data-engineering`, `python`, `sql`. Quedan 6 skills de dominio por construir: `spark`, `data-modeling`, `pipelines-architecture`, `streaming`, `data-quality`, `iac-cloud` (ver sección 7, ítem 6, actualizado). El `name` del manifiesto `.claude-plugin/plugin.json` se renombró de `data-engineering` a `data-engineering-suite` (ver sección 2) para evitar que la skill orquestadora, también llamada `data-engineering`, se invoque como `data-engineering:data-engineering` cuando se instala vía el flujo de plugin — el identificador de la skill orquestadora no cambió.

---

## 1. Contexto y objetivo

El equipo (chico, con retos grandes) construye soluciones de datos en varios repos separados de `legacy-repo` (que es puramente planeación/estrategia): `repo-a`, `repo-b`, `repo-c`, `repo-d`, `repo-e`, `repo-f`, `repo-g`, `repo-h`, entre otros.

El objetivo es que todo el equipo trabaje con el mismo estándar de ingeniería de datos — mismos criterios de diseño, mismas trampas evitadas, mismo vocabulario — sin importar en cuál de esos repos esté parado cada quien. Eso descarta que la suite viva dentro de un solo repo de código puntual: tiene que instalarse una vez por persona y quedar disponible en cualquier proyecto.

El contenido debe ser **agnóstico y generalista**: herramientas y patrones de ingeniería de datos en general (Python, SQL, Spark, modelado, pipelines, streaming, calidad, IaC/cloud), sin referencias a la infraestructura o vocabulario específico de Org (sys-1, sys-2, sys-3, sys-4, Databricks/Synapse como decisión particular, etc.).

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
    plugin.json                 # name: "data-engineering-suite" (renombrado 2026-07-29, ver Estado arriba), version, description, skills: "./skills/"
  skills/
    data-engineering/           # orquestadora — punto de entrada para tareas amplias/cruzadas
      SKILL.md
    python/                     # ya construida y probada (migra desde legacy-repo)
      SKILL.md
      references/
        iterators-and-generators.md
        decorators-and-context-managers.md
        oop-for-pipelines.md
        concurrency-and-the-gil.md
        memory-and-performance.md
        data-validation.md
        production-patterns.md
    sql/
      SKILL.md
    spark/                      # Spark en general; ejemplos de código en PySpark
      SKILL.md
    data-modeling/
      SKILL.md
    pipelines-architecture/
      SKILL.md
    streaming/
      SKILL.md
    data-quality/
      SKILL.md
    iac-cloud/
      SKILL.md
```

Cada skill de dominio (todas menos la orquestadora) sigue el mismo formato que `python`: overview, "when to use", tabla de quick reference, reference files por tema pesado, tabla de common mistakes. Contenido en inglés (convención técnica ya acordada), ejemplos de código en el lenguaje más relevante al tema.

## 4. Las 8 skills de dominio — propósito de cada una

| Skill | Cubre | No cubre (frontera con otra skill) |
|---|---|---|
| `python` | Generators/streaming, decoradores, context managers, OOP para pipelines, GIL/concurrencia, memoria/performance (pandas/Polars/DuckDB), validación (Pydantic/Pandera), testing e idempotencia a nivel de código | Orquestadores (Airflow/Dagster/Prefect) como sistema — eso es `pipelines-architecture` |
| `sql` | Optimización de queries, window functions, CTEs, planes de ejecución, indexación, modelado de queries analíticas | Modelado de esquemas/dimensional — eso es `data-modeling` |
| `spark` | Arquitectura y tuning de Spark en general (particionamiento, shuffles, AQE, Catalyst, joins, cache/checkpointing, memoria de executor/driver) + una sección propia para lo específico de PySpark (overhead de UDFs Python vía py4j, pandas UDFs con Arrow, riesgo de memoria de `.collect()`/`.toPandas()`) | Streaming estructurado (Structured Streaming, watermarks) — eso es `streaming` |
| `data-modeling` | Modelado dimensional (star/snowflake), Kimball vs Data Vault, SCDs, granularidad de hechos, normalización vs denormalización para analítica | Validación de esquema en tiempo de ejecución — eso es `data-quality` |
| `pipelines-architecture` | Elección y patrones de orquestador (Airflow/Dagster/Prefect), diseño de DAGs, backfills, dependency management, topología de despliegue | Cómo escribir el código idempotente dentro de una tarea — eso ya está en `python` |
| `streaming` | Kafka, Spark Structured Streaming, ventanas/watermarks, exactly-once vs at-least-once, particionamiento de tópicos | Arquitectura general de Spark batch — eso es `spark` |
| `data-quality` | Dimensiones de calidad de datos, frameworks de gobierno de datos (Great Expectations a nivel organizacional), monitoreo/alertas de DQ | Qué librería usar para validar un dataframe puntual (Pydantic vs Pandera) — eso ya está en `python` |
| `iac-cloud` | Terraform/IaC para infraestructura de datos, patrones de despliegue cloud-agnósticos, gestión de secretos, redes/permisos para plataformas de datos, **Docker/Compose** (stacks locales de desarrollo y containerización de jobs para despliegue — mismo modelo mental que Terraform: definir declarativamente un entorno) | Decisión de qué plataforma cloud/warehouse específica usar — eso es una decisión de proyecto, no de esta skill |

Los tópicos detallados de cada skill (más allá de este propósito de alto nivel) se definen en una siguiente fase, skill por skill, con el usuario aportando los temas y el asistente investigando para complementar — **dos fuentes**: búsqueda web (mismo proceso que se usó para `python`) y revisión del plugin `data-engineering` de `wshobson/agents` (MIT — `spark-optimization`, `airflow-dag-patterns`, `dbt-transformation-patterns`, `data-quality-frameworks`) como insumo adicional para los tópicos de `spark`, `pipelines-architecture`, `sql` y `data-quality`, con atribución. No se adopta tal cual: su estilo (cheat-sheet de do's/don'ts + snippets) y sus límites de dominio (ej. `airflow-dag-patterns` es solo-Airflow, no agnóstico de orquestador como se definió `pipelines-architecture` en la sección 4) difieren de los ya fijados acá.

## 5. Mecánica de la skill orquestadora (`data-engineering`)

- **Cuándo se activa**: tareas amplias o que cruzan varios dominios ("diseña este pipeline end-to-end", "revisa esta solución completa"). Una tarea de un solo dominio ("revisa este job de PySpark") activa directo la skill de dominio correspondiente por su propia descripción — la orquestadora no participa, sin overhead.
- **Qué hace al activarse**:
  1. Identifica cuáles de las 8 skills de dominio aplican a la tarea.
  2. Despacha un subagente por dominio relevante, **en paralelo cuando el entorno lo soporta** — redactado en lenguaje neutro de runtime, no atado a un tool específico de Claude Code, para que cada plataforma lo traduzca a su propio mecanismo: `Agent` tool nativo en Claude Code, `invoke_agent` nativo en Gemini CLI, `spawn_agent` en Codex CLI (requiere `multi_agent = true` en `~/.codex/config.toml` — apagado por defecto). **Fallback explícito**: si el entorno no soporta despacho de subagentes, hace el análisis de cada dominio en secuencia dentro de la misma sesión en vez de fallar.
  3. Sintetiza los resultados en una sola respuesta, señalando explícitamente las interacciones cruzadas entre dominios que un análisis aislado no vería (ejemplo: una partition key de Spark que no calza con la clustering key del warehouse).
- **Qué NO hace**: no ejecuta cambios de código ni ningún paso equivalente al "PR → CI → merge" de la skill `pm` de referencia (`catalhyst-matchmaking`) — esta suite es de referencia/diseño, no de ejecución de trabajo. La analogía con `pm` es solo el patrón de delegar análisis paralelizable a subagentes de solo lectura, no su ciclo de ejecución completo.

## 6. Migración de `python-data-engineering`

La skill ya construida en `legacy-repo/.claude/skills/python-data-engineering/` (SKILL.md + 7 reference files) se traslada sin cambios de contenido al nuevo repo, en `skills/python/`, renombrando solo el identificador (`python-data-engineering` → `python`) para evitar redundancia con el prefijo `data-engineering:` que Claude Code antepone a las skills de un plugin.

## 7. Próximos pasos (fuera de esta especificación)

1. Crear el repo `data-engineering-skills` con la estructura de la sección 3, incluyendo el `README.md` con instrucciones de symlink por runtime.
2. Resolver el destino del folder `python-data-engineering` que ya existe sin commitear en `legacy-repo/.claude/skills/`. Recomendación: commitearlo ahí como respaldo temporal y eliminarlo de este repo recién cuando la migración al repo nuevo esté confirmada — así no se pierde el trabajo si el proceso se corta a mitad de camino.
3. Migrar `python` según la sección 6.
4. Escribir `SKILL.md` de la orquestadora `data-engineering` según la sección 5.
5. Validar la orquestadora con un escenario de prueba que cruce 3+ dominios (análogo al test de discoverability que ya se le hizo a `python` con el escenario de la API paginada) — confirmar que el fan-out y la síntesis funcionan antes de darla por lista.
6. Por cada una de las 6 skills de dominio restantes (`spark`, `data-modeling`, `pipelines-architecture`, `streaming`, `data-quality`, `iac-cloud` — `sql` ya se entregó 2026-07-29, ver `docs/superpowers/specs/2026-07-28-sql-skill-design.md`): el usuario aporta tópicos → investigación web complementaria → redacción → validación de discoverability liviana (mismo proceso que `python` y `sql`).

## 8. Fuera de alcance (de esta fase)

- Contenido detallado (reference files) de las 7 skills de dominio pendientes — se define skill por skill en la fase siguiente.
- Visibilidad del repo (privado del equipo vs. algo más amplio) y si se publica además en un marketplace de Claude Code — se resuelve al crear el repo; no afecta la vía universal de symlinks, que ya queda definida en la sección 2.
- Cualquier convención o mandato específico de Org — la suite es agnóstica por decisión explícita (sección 1).
- Recorte y cross-linking de contenido que hoy vive en `python` pero en rigor pertenece a otra skill futura: las menciones a Airflow/Dagster/Prefect en `python/production-patterns.md` (territorio de `pipelines-architecture`), a Great Expectations en `python/data-validation.md` (territorio de `data-quality`), y un link explícito desde `python/concurrency-and-the-gil.md` (que ya menciona "delego a Spark" en la respuesta senior sobre el GIL) hacia la futura skill `spark`. Los tres se aplican recién cuando esas skills existan — hacerlo antes dejaría referencias rotas.
