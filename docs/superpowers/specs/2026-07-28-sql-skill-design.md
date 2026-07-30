# Especificación de Diseño: Skill `dataeng-sql`
## Segunda skill de dominio de la suite `data-engineering-skills`

**Fecha:** 2026-07-28
**Responsable:** Leonardo H. García Díaz
**Estado:** Implementado y shippeado (2026-07-29) — ver `docs/superpowers/plans/2026-07-28-sql-skill-implementation.md` para el registro de ejecución. La verificación de Oracle que este spec dejaba pendiente (§2, §4.5, §4.6, §5) se cerró en un pase posterior — ver notas inline abajo. El identificador de esta skill se renombró después, de `sql` a `dataeng-sql` (mismo día, ver Estado de la spec de la suite) — este documento ya usa el nombre nuevo en todo salvo donde cita rutas de terceros (`wshobson/agents`).

---

## 1. Contexto y objetivo

Primera de las 7 skills de dominio pendientes definidas en `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` (sección 4). Cubre optimización de queries, window functions, CTEs, planes de ejecución, indexación y modelado de queries analíticas — SQL declarativo, no procedimental, y no modelado de esquemas (eso es `dataeng-data-modeling`).

Insumo: borrador de contenido aportado por el usuario (7 "capas", de fundamentos a optimización en producción), verificado contra documentación oficial (PostgreSQL, MySQL, SQL Server, Snowflake, BigQuery, Redshift, dbt) y complementado con revisión del plugin `data-engineering`/`developer-essentials` de `wshobson/agents` (MIT), según lo ya anticipado en la spec de la suite §4.

## 2. Alcance y fronteras

Reafirma la frontera ya fijada en la spec de la suite (§4):

- **Cubre**: SQL declarativo — orden lógico de ejecución, NULL/lógica de tres valores, joins, agregaciones, window functions, CTEs/recursión, patrones de ingeniería (dedup, gaps & islands, sesionización, MERGE, SCD2), optimización (EXPLAIN, índices, pushdown, costo por motor).
- **No cubre — frontera con otra skill**:
  - Modelado de esquemas/dimensional (star/snowflake, Kimball vs Data Vault) → `dataeng-data-modeling`.
  - Arquitectura de proyecto dbt (medallion, naming conventions, DAG de modelos, `dbt_project.yml`) → `dataeng-pipelines-architecture`. Mismo tratamiento que ya reciben Airflow/Dagster/Prefect en `skills/dataeng-python/references/production-patterns.md` hoy: mención ilustrativa breve, con recorte/cross-link pendiente cuando `dataeng-pipelines-architecture` exista (spec de la suite, §8). dbt es, en esencia, otro orquestador — especializado en la capa de transformación SQL — no un tema propio de lenguaje de consulta.
  - Extensiones procedimentales (PL/SQL, T-SQL con stored procedures, PL/pgSQL) → fuera de las 8 skills actuales, no se cubre.
- **Motores en alcance**: PostgreSQL, MySQL, SQL Server, Snowflake, BigQuery, Redshift — como motores de primera clase, con divergencias explícitas por motor donde existan (ver sección 4). Oracle recibe cobertura dirigida y verificada (cerrado 2026-07-29) solo en dos frentes — CTEs recursivas y `MERGE` (§4.5, §4.6) — no paridad completa con los otros seis motores en el resto de los archivos de referencia; `SKILL.md` refleja este alcance acotado en vez de listar a Oracle junto a los demás.

## 3. Fuentes

- Borrador original del usuario (7 capas) — traducido y corregido, no adoptado verbatim (contenido final en inglés, convención ya fijada en la spec de la suite §3).
- Verificación directa contra documentación oficial: PostgreSQL, MySQL 8.0/8.4, SQL Server (MS Learn), Snowflake, BigQuery (GCP docs), dbt-core.
- `wshobson/agents` (MIT) — revisado como insumo adicional, con atribución, sin adopción literal:
  - `plugins/developer-essentials/skills/sql-optimization-patterns/SKILL.md` — tipos de índice más allá de B-tree (GIN, GiST, BRIN), queries de monitoreo (`pg_stat_statements`). Aporta contenido nuevo a `query-optimization-and-production.md`.
  - `plugins/data-engineering/skills/dbt-transformation-patterns/` — confirma que el contenido de arquitectura dbt pertenece a `dataeng-pipelines-architecture`, no a `dataeng-sql` (ver sección 2).
  - `plugins/database-cloud-optimization/` y `plugins/database-design/skills/postgresql/` — solapamiento fuerte con `sql-optimization-patterns`, sin aporte adicional a esta skill; `database-design` trae contenido OLTP (normalización, constraints, JSONB, RLS) que no encaja limpio en `dataeng-sql` ni en `dataeng-data-modeling` tal como están definidas hoy — anotado como pendiente para cuando se planee `dataeng-data-modeling`, no bloquea esta skill.
  - `plugins/database-migrations/` — mayormente territorio de `dataeng-iac-cloud` (Flyway/Liquibase, Terraform), sin aporte a `dataeng-sql`.
  - `plugins/data-validation-suite/` — descartado: es seguridad de aplicación (injection, JWT, CORS), no relacionado con ninguna de las 8 skills.

## 4. Estructura de archivos

```
skills/dataeng-sql/
  SKILL.md
  references/
    query-execution-and-null-semantics.md
    joins.md
    aggregation-patterns.md
    window-functions.md
    ctes-and-recursion.md
    engineering-query-patterns.md
    query-optimization-and-production.md
```

Mismo formato que `dataeng-python`: overview, when to use, tabla de quick reference y tabla de common mistakes en `SKILL.md`; un archivo de reference por tema pesado.

### 4.1 `query-execution-and-null-semantics.md`

Orden lógico de ejecución (`FROM`/`JOIN` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `DISTINCT` → `ORDER BY` → `LIMIT`) y por qué las window functions no se filtran en `WHERE`. Lógica de tres valores, `NULL = NULL` → NULL, `NOT IN` con NULL → cero filas (recomendar `NOT EXISTS`), `COUNT(*)` vs `COUNT(columna)`, `COALESCE`/`NULLIF`.

Verificado sin correcciones — confirmado contra la documentación de PostgreSQL, aplica igual en los 6 motores en alcance.

### 4.2 `joins.md`

Semántica de cada tipo de join, la trampa del filtro de outer join en `WHERE` (vs `ON`), fan-out/inflado de cardinalidad, semi/anti-joins (`EXISTS`/`NOT EXISTS` vs `NOT IN`).

Verificado sin correcciones.

### 4.3 `aggregation-patterns.md`

`GROUP BY`/`HAVING`, `COUNT(*)` vs `COUNT(columna)` vs `COUNT(DISTINCT ...)`, agregación condicional (`CASE` vs `FILTER`), `GROUPING SETS`/`ROLLUP`/`CUBE`.

**Correcciones a incorporar:**
- MySQL (hasta 8.4) no soporta `CUBE` ni `GROUPING SETS`, solo `ROLLUP` — debe emularse con `UNION ALL` si se necesita en ese motor.
- `FILTER (WHERE ...)` no es tan portable como sugiere el borrador original: Snowflake no lo soporta en absoluto; SQL Server lo agregó apenas en SQL Server 2025; MySQL en 9.7.0. Para la inmensa mayoría de instancias en producción hoy, `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` es la forma **requerida**, no solo "la portable".

### 4.4 `window-functions.md`

Anatomía (`PARTITION BY`/`ORDER BY`/frame), `ROW_NUMBER` vs `RANK` vs `DENSE_RANK`, deduplicación canónica (CTE + `ROW_NUMBER` + filtro), top-N por grupo, `LAG`/`LEAD`, acumulados/móviles con frame explícito.

**Corrección a incorporar:** el default `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` aplica en Postgres/SQL Server/MySQL 8+/BigQuery, pero **Snowflake es la excepción real**: para funciones de agregación sigue el default ANSI (RANGE), pero para funciones de valor (`FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE`) el default es `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` — Snowflake documenta esto como no conforme al estándar ANSI y recomienda ser siempre explícito con el frame. Nombrar a Snowflake explícitamente, no "algunos motores".

### 4.5 `ctes-and-recursion.md`

CTEs para legibilidad/reuso, CTE como optimization barrier en algunos motores vs inline en otros, subconsultas correlacionadas vs no correlacionadas, CTEs recursivas (ancla + `UNION ALL` + recursión) para jerarquías y date spines.

**Corrección a incorporar:** BigQuery solo soporta `WITH RECURSIVE` desde ~feb. 2022 (inicialmente en preview) — no asumir portabilidad hacia atrás.

**Oracle (cerrado 2026-07-29):** Oracle soporta ambas formas — `CONNECT BY PRIOR` desde siempre, y subquery factoring recursivo ANSI desde 11g R2 (11.2.0.1). El gotcha verificado: la cláusula `WITH` de Oracle no acepta la palabra clave `RECURSIVE` — la recursión se infiere automáticamente. Verificado contra la documentación oficial de Oracle.

### 4.6 `engineering-query-patterns.md`

Deduplicación canónica (cross-link a 4.4), gaps and islands, sesionización (`LAG` + suma acumulada de inicios de sesión), pivot/unpivot, upsert idempotente con `MERGE`, SCD Tipo 2.

**Corrección a incorporar:** `MERGE` en PostgreSQL existe desde v15 (oct. 2022); `RETURNING`/`merge_action()` con `MERGE` recién en PostgreSQL 17 (sept. 2024) — cualquier ejemplo con `RETURNING` debe marcarse como PG17+.

**Oracle (cerrado 2026-07-29):** `MERGE` existe en Oracle desde 9i. Verificado contra la documentación oficial: es una "sentencia determinística" — no puede actualizar la misma fila destino dos veces en una misma ejecución, y si el source produce más de una fila coincidente para un mismo destino, lanza `ORA-30926` en vez de aplicar una silenciosamente. Además admite exactamente una cláusula `WHEN MATCHED` y una `WHEN NOT MATCHED` por sentencia (sin las ramas condicionales múltiples de SQL Server).

### 4.7 `query-optimization-and-production.md`

Leer el plan de ejecución (`EXPLAIN`/`EXPLAIN ANALYZE`) antes de optimizar, índices B-tree y su costo (regla del prefijo izquierdo, baja cardinalidad), partition pruning/predicate pushdown/projection pushdown, reescrituras sargables, cierre breve de SQL en dbt/ELT.

**Contenido nuevo a incorporar** (de `sql-optimization-patterns`, con atribución): tipos de índice más allá de B-tree — GIN, GiST, BRIN — y queries de monitoreo (`pg_stat_statements`, `pg_stat_user_indexes`).

**Correcciones a incorporar:**
- Redshift no usa "clustering keys" ni "micro-particiones" (vocabulario propio de Snowflake) — Redshift usa **sort keys + zone maps + distribution keys**. Nombrar cada motor con su terminología real, no generalizar.
- "Optimizo por bytes escaneados, no por tiempo de CPU" es preciso para BigQuery on-demand, pero es una simplificación excesiva para Snowflake: Snowflake cobra por **tiempo de cómputo del warehouse** (créditos por segundo), correlacionado con bytes escaneados pero no equivalente. Distinguir ambos modelos explícitamente en el cierre.
- Cierre de dbt: solo materializations, `unique_key`/incremental como mecanismo de idempotencia (conecta con `MERGE` de 4.6), y tests genéricos como aserciones SQL — con una línea explícita de que la arquitectura de proyecto dbt vive en `dataeng-pipelines-architecture` (ver sección 2).

## 5. Fuera de alcance (de esta fase)

- Contenido OLTP de `database-design` (normalización, constraints, JSONB, RLS) — no encaja limpio en `dataeng-sql` ni en `dataeng-data-modeling` tal como están definidas hoy; queda anotado para cuando se planee `dataeng-data-modeling`.
- Arquitectura de proyecto dbt (medallion, naming conventions, DAG de modelos) — pertenece a la futura skill `dataeng-pipelines-architecture`.
- Extensiones procedimentales (PL/SQL, T-SQL, PL/pgSQL) — no es una de las 8 skills de la suite.

## 6. Próximos pasos

Transición a `superpowers:writing-plans` para el plan de implementación: redacción completa de `SKILL.md` + los 7 reference files, con el contenido final en inglés y las correcciones de la sección 4 incorporadas, siguiendo el mismo proceso de validación liviana de discoverability ya usado con `dataeng-python` y con la orquestadora `dataeng`.
