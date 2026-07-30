# Especificación de Diseño: Skill `sql-data-engineering`
## Segunda skill de dominio de la suite `data-engineering-skills`

**Fecha:** 2026-07-28
**Responsable:** Leonardo H. García Díaz
**Estado:** Implementado y shippeado (2026-07-29) — ver `docs/superpowers/plans/2026-07-28-sql-skill-implementation.md` para el registro de ejecución. La verificación de Oracle que este spec dejaba pendiente (§2, §4.5, §4.6, §5) se cerró en un pase posterior — ver notas inline abajo. El identificador de esta skill se renombró dos veces después: de `sql` a `dataeng-sql` (2026-07-29), y de `dataeng-sql` a `sql-data-engineering` (2026-07-30) — ver Estado de la spec de la suite para el porqué de cada uno. Este documento ya usa el nombre actual en todo salvo donde cita rutas de terceros (`wshobson/agents`). **Cierre adicional (2026-07-29):** se agregó cobertura dirigida y verificada de Azure Synapse Analytics (dedicated SQL pools) y Microsoft Fabric Warehouse — mismo tratamiento que Oracle, no paridad completa — tras detectar que ningún motor cloud de Microsoft estaba cubierto pese a que Snowflake/BigQuery/Redshift sí lo estaban. Registro completo: `docs/superpowers/research/2026-07-29-sql-synapse-fabric-claims-verification.md`. **Ampliación de alcance (2026-07-30):** se revirtió la exclusión de extensiones procedurales (§2, §5 originales) — el equipo confirmó uso real de PL/SQL y T-SQL, y se agregó un octavo reference file, `procedural-extensions.md`, cubriendo también PostgreSQL PL/pgSQL y MySQL. Ver §4.8 y `docs/superpowers/research/2026-07-30-sql-procedural-extensions-verification.md`.

---

## 1. Contexto y objetivo

Primera de las 7 skills de dominio pendientes definidas en `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` (sección 4) al momento de escribir esta spec (2026-07-28) — ya entregada, ver Estado arriba; quedan 5 (`spark-data-engineering` se entregó después, 2026-07-29). Cubre optimización de queries, window functions, CTEs, planes de ejecución, indexación, modelado de queries analíticas, y (agregado 2026-07-30, §4.8) extensiones procedurales — SQL declarativo y procedural, no modelado de esquemas (eso es `modeling-data-engineering`).

Insumo: borrador de contenido aportado por el usuario (7 "capas", de fundamentos a optimización en producción), verificado contra documentación oficial (PostgreSQL, MySQL, SQL Server, Snowflake, BigQuery, Redshift, dbt) y complementado con revisión del plugin `data-engineering`/`developer-essentials` de `wshobson/agents` (MIT), según lo ya anticipado en la spec de la suite §4.

## 2. Alcance y fronteras

Reafirma la frontera ya fijada en la spec de la suite (§4):

- **Cubre**: SQL declarativo — orden lógico de ejecución, NULL/lógica de tres valores, joins, agregaciones, window functions, CTEs/recursión, patrones de ingeniería (dedup, gaps & islands, sesionización, MERGE, SCD2), optimización (EXPLAIN, índices, pushdown, costo por motor).
- **No cubre — frontera con otra skill**:
  - Modelado de esquemas/dimensional (star/snowflake, Kimball vs Data Vault) → `modeling-data-engineering`.
  - Arquitectura de proyecto dbt (medallion, naming conventions, DAG de modelos, `dbt_project.yml`) → `pipelines-architecture-data-engineering`. Mismo tratamiento que ya reciben Airflow/Dagster/Prefect en `skills/python-data-engineering/references/production-patterns.md` hoy: mención ilustrativa breve, con recorte/cross-link pendiente cuando `pipelines-architecture-data-engineering` exista (spec de la suite, §8). dbt es, en esencia, otro orquestador — especializado en la capa de transformación SQL — no un tema propio de lenguaje de consulta.
  - Extensiones procedimentales — **revertido 2026-07-30**: el equipo confirmó uso real de stored procedures en Oracle (PL/SQL) y SQL Server (T-SQL); se agregó cobertura dirigida para los 4 dialectos con soporte en este skill (Oracle PL/SQL, SQL Server T-SQL, PostgreSQL PL/pgSQL, MySQL) — ver §4.8. Ya no está fuera de alcance.
- **Motores en alcance**: PostgreSQL, MySQL, SQL Server, Snowflake, BigQuery, Redshift — como motores de primera clase, con divergencias explícitas por motor donde existan (ver sección 4). Para SQL declarativo, Oracle recibe cobertura dirigida y verificada (cerrado 2026-07-29) solo en dos frentes — CTEs recursivas y `MERGE` (§4.5, §4.6) — no paridad completa con los otros seis motores en el resto de los archivos de referencia; `SKILL.md` refleja este alcance acotado en vez de listar a Oracle junto a los demás. Excepción: PL/SQL (extensiones procedurales, §4.8, agregado 2026-07-30) sí recibe la misma profundidad fundamentos-a-senior que el resto del skill — no es cobertura acotada como la declarativa. Azure Synapse Analytics (dedicated SQL pools) y Microsoft Fabric Warehouse reciben el mismo tratamiento (cerrado 2026-07-29): CTEs recursivas (no soportadas en ninguno de los dos), `MERGE` (preview en Synapse dedicated, GA en Fabric — divergen entre sí), `FILTER`/`ROLLUP`/`CUBE`/`GROUPING SETS` (§4.3), `QUALIFY` (§4.4), y mecánica/costo de warehouse (distribution types + clustered columnstore vs. autonomía de Fabric; DWU provisionado vs. Capacity Units de Fabric — §4.7). Synapse dedicated y Fabric Warehouse son productos relacionados pero distintos (Fabric es el sucesor activo) y divergen entre sí en varios de estos puntos — no tratarlos como intercambiables.

## 3. Fuentes

- Borrador original del usuario (7 capas) — traducido y corregido, no adoptado verbatim (contenido final en inglés, convención ya fijada en la spec de la suite §3).
- Verificación directa contra documentación oficial: PostgreSQL, MySQL 8.0/8.4, SQL Server (MS Learn), Snowflake, BigQuery (GCP docs), dbt-core.
- `wshobson/agents` (MIT) — revisado como insumo adicional, con atribución, sin adopción literal:
  - `plugins/developer-essentials/skills/sql-optimization-patterns/SKILL.md` — tipos de índice más allá de B-tree (GIN, GiST, BRIN), queries de monitoreo (`pg_stat_statements`). Aporta contenido nuevo a `query-optimization-and-production.md`.
  - `plugins/data-engineering/skills/dbt-transformation-patterns/` — confirma que el contenido de arquitectura dbt pertenece a `pipelines-architecture-data-engineering`, no a `sql-data-engineering` (ver sección 2).
  - `plugins/database-cloud-optimization/` y `plugins/database-design/skills/postgresql/` — solapamiento fuerte con `sql-optimization-patterns`, sin aporte adicional a esta skill; `database-design` trae contenido OLTP (normalización, constraints, JSONB, RLS) que no encaja limpio en `sql-data-engineering` ni en `modeling-data-engineering` tal como están definidas hoy — anotado como pendiente para cuando se planee `modeling-data-engineering`, no bloquea esta skill.
  - `plugins/database-migrations/` — mayormente territorio de `iac-cloud-data-engineering` (Flyway/Liquibase, Terraform), sin aporte a `sql-data-engineering`.
  - `plugins/data-validation-suite/` — descartado: es seguridad de aplicación (injection, JWT, CORS), no relacionado con ninguna de las 8 skills.

## 4. Estructura de archivos

```
skills/sql-data-engineering/
  SKILL.md
  references/
    query-execution-and-null-semantics.md
    joins.md
    aggregation-patterns.md
    window-functions.md
    ctes-and-recursion.md
    engineering-query-patterns.md
    query-optimization-and-production.md
    procedural-extensions.md
```

Mismo formato que `python-data-engineering`: overview, when to use, tabla de quick reference y tabla de common mistakes en `SKILL.md`; un archivo de reference por tema pesado.

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

**Synapse/Fabric (cerrado 2026-07-29):** `FILTER (WHERE ...)` no soportado en ninguno de los dos (ausencia confirmada en la referencia T-SQL de funciones agregadas, que aplica explícitamente a ambos). `ROLLUP`/`CUBE`/`GROUPING SETS` **no se comportan igual entre sí**: Synapse dedicated solo soporta `ROLLUP` (agregado marzo 2019, mismo punto que MySQL), mientras Fabric Warehouse soporta las tres con paridad completa con SQL Server (única excepción: `GROUPING_ID()` no disponible en Fabric, aunque `GROUPING()` sí). Verificado contra la documentación oficial de Microsoft Learn.

### 4.4 `window-functions.md`

Anatomía (`PARTITION BY`/`ORDER BY`/frame), `ROW_NUMBER` vs `RANK` vs `DENSE_RANK`, deduplicación canónica (CTE + `ROW_NUMBER` + filtro), top-N por grupo, `LAG`/`LEAD`, acumulados/móviles con frame explícito.

**Corrección a incorporar:** el default `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` aplica en Postgres/SQL Server/MySQL 8+/BigQuery, pero **Snowflake es la excepción real**: para funciones de agregación sigue el default ANSI (RANGE), pero para funciones de valor (`FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE`) el default es `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` — Snowflake documenta esto como no conforme al estándar ANSI y recomienda ser siempre explícito con el frame. Nombrar a Snowflake explícitamente, no "algunos motores".

**Synapse/Fabric (cerrado 2026-07-29):** ninguno de los dos soporta `QUALIFY` — mismo diagrama de sintaxis restringido que SQL Server, verificado contra la referencia oficial de `SELECT` de Microsoft Learn (rotulada explícitamente para "Azure Synapse Analytics... and Microsoft Fabric").

### 4.5 `ctes-and-recursion.md`

CTEs para legibilidad/reuso, CTE como optimization barrier en algunos motores vs inline en otros, subconsultas correlacionadas vs no correlacionadas, CTEs recursivas (ancla + `UNION ALL` + recursión) para jerarquías y date spines.

**Corrección a incorporar:** BigQuery solo soporta `WITH RECURSIVE` desde ~feb. 2022 (inicialmente en preview) — no asumir portabilidad hacia atrás.

**Oracle (cerrado 2026-07-29):** Oracle soporta ambas formas — `CONNECT BY PRIOR` desde siempre, y subquery factoring recursivo ANSI desde 11g R2 (11.2.0.1). El gotcha verificado: la cláusula `WITH` de Oracle no acepta la palabra clave `RECURSIVE` — la recursión se infiere automáticamente. Verificado contra la documentación oficial de Oracle.

**Synapse/Fabric (cerrado 2026-07-29):** a diferencia de Oracle, **ninguno de los dos soporta CTEs recursivas en absoluto** — no hay sintaxis alternativa ni workaround de keyword, es un "no soportado" categórico en ambos, verificado contra la documentación oficial de Microsoft Learn (referencia T-SQL de `WITH` para Synapse, superficie T-SQL de Fabric Warehouse).

### 4.6 `engineering-query-patterns.md`

Deduplicación canónica (cross-link a 4.4), gaps and islands, sesionización (`LAG` + suma acumulada de inicios de sesión), pivot/unpivot, upsert idempotente con `MERGE`, SCD Tipo 2.

**Corrección a incorporar:** `MERGE` en PostgreSQL existe desde v15 (oct. 2022); `RETURNING`/`merge_action()` con `MERGE` recién en PostgreSQL 17 (sept. 2024) — cualquier ejemplo con `RETURNING` debe marcarse como PG17+.

**Oracle (cerrado 2026-07-29):** `MERGE` existe en Oracle desde 9i. Verificado contra la documentación oficial: es una "sentencia determinística" — no puede actualizar la misma fila destino dos veces en una misma ejecución, y si el source produce más de una fila coincidente para un mismo destino, lanza `ORA-30926` en vez de aplicar una silenciosamente. Además admite exactamente una cláusula `WHEN MATCHED` y una `WHEN NOT MATCHED` por sentencia (sin las ramas condicionales múltiples de SQL Server).

**Synapse/Fabric (cerrado 2026-07-29):** `MERGE` **diverge fuerte entre los dos productos** — Synapse dedicated lo tiene desde octubre 2020 pero sigue etiquetado *preview* en la documentación actual, con restricciones reales (sin `merge_hint`/`TOP`, `WHEN NOT MATCHED INSERT` no funciona con columnas `IDENTITY`, `WHEN NOT MATCHED BY TARGET` exige distribución `HASH`). Fabric Warehouse lo tiene como *GA* completo, sin ninguna de esas restricciones heredadas. Verificado contra la documentación oficial de Microsoft Learn — no tratar ambos productos como equivalentes en este punto.

### 4.7 `query-optimization-and-production.md`

Leer el plan de ejecución (`EXPLAIN`/`EXPLAIN ANALYZE`) antes de optimizar, índices B-tree y su costo (regla del prefijo izquierdo, baja cardinalidad), partition pruning/predicate pushdown/projection pushdown, reescrituras sargables, cierre breve de SQL en dbt/ELT.

**Contenido nuevo a incorporar** (de `sql-optimization-patterns`, con atribución): tipos de índice más allá de B-tree — GIN, GiST, BRIN — y queries de monitoreo (`pg_stat_statements`, `pg_stat_user_indexes`).

**Correcciones a incorporar:**
- Redshift no usa "clustering keys" ni "micro-particiones" (vocabulario propio de Snowflake) — Redshift usa **sort keys + zone maps + distribution keys**. Nombrar cada motor con su terminología real, no generalizar.
- "Optimizo por bytes escaneados, no por tiempo de CPU" es preciso para BigQuery on-demand, pero es una simplificación excesiva para Snowflake: Snowflake cobra por **tiempo de cómputo del warehouse** (créditos por segundo), correlacionado con bytes escaneados pero no equivalente. Distinguir ambos modelos explícitamente en el cierre.
- Cierre de dbt: solo materializations, `unique_key`/incremental como mecanismo de idempotencia (conecta con `MERGE` de 4.6), y tests genéricos como aserciones SQL — con una línea explícita de que la arquitectura de proyecto dbt vive en `pipelines-architecture-data-engineering` (ver sección 2).

**Synapse/Fabric (cerrado 2026-07-29):** agregados a la sección de "mental model" de warehouses columnar junto a Snowflake/BigQuery/Redshift. Synapse dedicated: modelo MPP con distribution types (`HASH`/`ROUND_ROBIN`/`REPLICATE`) sobre 60 distribuciones fijas + clustered columnstore index por default; billing por DWU provisionado (capacidad fija, no consumo). Fabric Warehouse: arquitectura distinta pese a compartir superficie T-SQL — sin distribution key ni índice manual, Delta/Parquet sobre OneLake, distribución automática; billing por Capacity Units compartidas con el resto de Fabric. Gotcha propio de Synapse dedicated: distribution key de baja cardinalidad/sesgada concentra filas en una de las 60 distribuciones (se corrige con `CTAS`). Verificado contra la documentación oficial de Microsoft Learn.

### 4.8 `procedural-extensions.md` (agregado 2026-07-30)

Alcance revertido desde §2 — el equipo confirmó uso real de stored procedures en Oracle y SQL Server; se agregó también PostgreSQL y MySQL por costo marginal bajo, evitando la asimetría de cubrir SQL declarativo en los 4 pero procedural solo en 2. Mismo nivel de profundidad que el resto del skill: fundamentos → señal senior, con divergencia nombrada explícitamente por motor.

Cubre, en este orden: (1) estructura de bloque y fundamentos (`DECLARE/BEGIN/EXCEPTION/END` de PL/SQL con `%TYPE`/`%ROWTYPE`; `CREATE PROCEDURE`/`CREATE FUNCTION` y `GO` de T-SQL, table variables vs. temp tables; la distinción `FUNCTION` vs `PROCEDURE` de Postgres —agregada en PG11, oct. 2018—; `DELIMITER` de MySQL y ausencia real de packages); (2) cursores y el anti-patrón RBAR (*Row-By-Agonizing-Row*, término de comunidad — Jeff Moden, SQLServerCentral 2005, no vocabulario de vendor — con guía oficial de "evitar fila-por-fila" confirmada para Oracle y SQL Server, parcial para MySQL, inexistente para PostgreSQL); (3) manejo de excepciones (Oracle es el único de los 4 con advertencia de compilador — `PLW-06009` — si `WHEN OTHERS` no termina en `RAISE`; `TRY/CATCH`/`THROW` de T-SQL, agregado en 2005/2012 respectivamente; `RAISE` de PL/pgSQL con el tip oficial de performance sobre bloques `EXCEPTION`; `DECLARE HANDLER`/`SIGNAL` de MySQL, con `UNDO` confirmado como no implementado); (4) transacciones dentro de una rutina (Postgres como el caso más nítido — solo `PROCEDURE` puede COMMIT/ROLLBACK, nunca `FUNCTION` — mismo patrón subyacente en los otros 3); (5) SQL dinámico y la defensa contra injection citada textualmente por los 4 vendors; (6) parameter sniffing de T-SQL (sin equivalente documentado en los otros 3); (7) packages de Oracle, sin equivalente directo en ninguno de los otros 3.

Fuentes: documentación oficial exclusivamente — docs.oracle.com (PL/SQL Language Reference, SQL Language Reference), learn.microsoft.com (T-SQL reference, vía el MCP oficial de Microsoft Learn), postgresql.org/docs, dev.mysql.com/doc/refman. Registro completo de la verificación: `docs/superpowers/research/2026-07-30-sql-procedural-extensions-verification.md`.

Cross-link agregado a `skills/python-data-engineering/references/production-patterns.md` para la discusión de manejo de errores. De paso se corrigió un link roto preexistente en `engineering-query-patterns.md` (apuntaba a la carpeta `python/` en vez de `python-data-engineering/`, remanente del rename del 2026-07-29).

## 5. Fuera de alcance (de esta fase)

- Contenido OLTP de `database-design` (normalización, constraints, JSONB, RLS) — no encaja limpio en `sql-data-engineering` ni en `modeling-data-engineering` tal como están definidas hoy; queda anotado para cuando se planee `modeling-data-engineering`.
- Arquitectura de proyecto dbt (medallion, naming conventions, DAG de modelos) — pertenece a la futura skill `pipelines-architecture-data-engineering`.

## 6. Próximos pasos

Transición a `superpowers:writing-plans` para el plan de implementación: redacción completa de `SKILL.md` + los 7 reference files, con el contenido final en inglés y las correcciones de la sección 4 incorporadas, siguiendo el mismo proceso de validación liviana de discoverability ya usado con `python-data-engineering` y con la orquestadora `data-engineering`.
