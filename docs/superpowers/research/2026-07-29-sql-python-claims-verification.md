# Research: re-verifying technical claims in `sql-data-engineering` and `python-data-engineering`

**Fecha:** 2026-07-29
**Alcance:** spot-check contra fuentes primarias de los claims técnicos con mayor riesgo de estar desactualizados (soporte por versión de motor, límites de features, pricing) en `skills/sql-data-engineering/references/*.md` y `skills/python-data-engineering/references/*.md`. Se excluyó a propósito el contenido de stdlib de Python muy estable (generators, decorators, OOP básico) — riesgo de haber cambiado prácticamente nulo.

5 investigaciones independientes en paralelo, cada una contra la documentación oficial del vendor correspondiente (no blogs ni write-ups de terceros, salvo donde se anota explícitamente lo contrario).

---

## 1. Soporte por versión — `aggregation-patterns.md`, `ctes-and-recursion.md`, `engineering-query-patterns.md`

| Claim | Resultado | Fuente |
|---|---|---|
| `FILTER (WHERE ...)`: Postgres sí (9.4+), Snowflake no soportado | **Confirmado** | postgresql.org/docs/9.4; docs.snowflake.com/en/sql-reference/functions-aggregation |
| `FILTER (WHERE ...)`: BigQuery sí, SQL Server solo 2025+, MySQL solo 9.7.0+ | **No verificable contra docs oficiales** — la página de sintaxis agregada de BigQuery, el T-SQL reference de SQL Server 2025 y el manual 9.7 de MySQL no mencionan `FILTER` en ningún lado. Un tracker de terceros (modern-sql.com, live-tested, no es doc oficial) sí reporta soporte en los tres. Gap docs-vs-comportamiento-real sin resolver — requeriría una query en vivo contra cada motor. **No se tocó el contenido del skill por esto** — la evidencia es inconclusa, no contradictoria. |
| `ROLLUP`/`CUBE`/`GROUPING SETS`: MySQL 8.4 solo `ROLLUP` | **Confirmado** | dev.mysql.com/doc/refman/8.4/en/group-by-modifiers.html |
| `WITH RECURSIVE` en BigQuery desde feb. 2022, "preview" | **Confirmado el dato, pero desactualizado** — feb. 2022 es correcto, pero pasó a GA el 2 de marzo de 2023 y el skill no lo mencionaba. **Corregido** (`ctes-and-recursion.md`, sección y tabla de common mistakes). | docs.cloud.google.com/bigquery/docs/release-notes-archive |
| CTE como optimization barrier: siempre en Postgres <12, inlineable en 12+ (`AS MATERIALIZED` fuerza el barrier) | **Confirmado** | postgresql.org/docs/11 y /docs/current, queries-with.html |
| `MERGE`: Postgres 15+ (oct. 2022), `RETURNING`/`merge_action()` recién en Postgres 17 (sept. 2024) | **Confirmado** | postgresql.org/docs/release/15.0, /docs/release/17.0 |

## 2. Claims de Oracle — `ctes-and-recursion.md`, `engineering-query-patterns.md`

Re-verificación independiente (no se asumió el cierre de la ronda anterior). Los 5 claims — `CONNECT BY PRIOR` + recursive subquery factoring desde 11.2.0.1, la palabra `RECURSIVE` no soportada en el `WITH` de Oracle, `MERGE` desde 9i, `MERGE` como sentencia determinística que lanza `ORA-30926`, y exactamente un `WHEN MATCHED`/`WHEN NOT MATCHED` por sentencia — **quedaron confirmados** contra el SQL Language Reference y las páginas de error oficiales de Oracle (docs.oracle.com). Sin cambios.

## 3. Mecánica y pricing de warehouses cloud — `query-optimization-and-production.md`

| Claim | Resultado |
|---|---|
| Snowflake: micro-particiones 50–500MB, clustering key opcional | **Confirmado** |
| Snowflake: billing por tiempo de cómputo (créditos/segundo, mínimo 60s) | **Confirmado** |
| BigQuery: partition pruning + clustering, sin índice secundario; on-demand = bytes escaneados, Editions = slot-hours | **Confirmado**, sin cambios estructurales |
| Redshift: sort keys + zone maps + distribution keys (no "clustering key"/"micro-partition", eso es vocabulario de Snowflake) | **Confirmado** — nota menor no bloqueante: el distribution style por defecto hoy es `AUTO`, no un valor fijo |
| dbt: `merge` default en Snowflake/BigQuery/Databricks, `delete+insert` default en Postgres/Redshift | **Confirmado, pero incompleto** — el default real en Postgres/Redshift es condicional: `append` si no hay `unique_key` configurado, `delete+insert` solo si lo hay. El skill ya hablaba en el contexto de `unique_key` configurado, pero no lo dejaba explícito. **Corregido** (`query-optimization-and-production.md`). |

## 4. Window functions e indexing — `window-functions.md`, `query-optimization-and-production.md`

Los 6 claims revisados — default `RANGE` implícito en Postgres/SQL Server/MySQL 8+/BigQuery, la excepción de Snowflake (agregadas vs. funciones de valor), soporte de `QUALIFY` en Snowflake/BigQuery/Redshift, la regla de prefijo izquierdo en índices compuestos, los casos de uso de GIN/GiST/BRIN, y el procedimiento de setup de `pg_stat_statements` — **quedaron confirmados** contra la documentación oficial de cada motor. Una sola reserva menor: el fetch directo a la página de BigQuery sobre window functions sirvió un shell JS en vez de contenido estático, así que ese punto puntual se corroboró por contenido indexado en vez de una cita textual directa — vale un spot-check manual si en algún momento se depende de esa cita específica, pero no cambia el contenido del skill.

## 5. Currency de Python — `concurrency-and-the-gil.md`, `data-validation.md`

- **GIL / free-threading (PEP 703 / PEP 779):** el skill ya tenía la salvedad correcta — Python 3.13 lo trae como build experimental opt-in, 3.14 lo pasa a "oficialmente soportado" pero sigue opt-in, sin fecha comprometida para que sea el build por defecto (PEP 779, "Phase III" sin resolver). El build con GIL sigue siendo el default en producción hoy. **Sin cambios necesarios.**
- **Ejemplo de Pydantic (`BaseModel` con campos anotados, import directo de `pydantic`):** sintaxis válida e idiomática en Pydantic v2 actual, no es un patrón solo-v1. **Sin cambios necesarios.**

---

## Resumen de acciones

- **2 fixes aplicados:** BigQuery `WITH RECURSIVE` GA desde marzo 2023 (`ctes-and-recursion.md`, 2 lugares); calificador de `unique_key` en el default de dbt para Postgres/Redshift (`query-optimization-and-production.md`).
- **1 punto abierto, sin tocar:** soporte de `FILTER (WHERE ...)` en BigQuery/SQL Server 2025/MySQL 9.7.0 — la documentación oficial de cada motor no lo confirma ni lo contradice explícitamente; un tracker de terceros live-tested sí reporta soporte. No se cambió el skill por evidencia inconclusa.
- **Todo lo demás verificado sin correcciones** — Oracle (5/5), mecánica y pricing de warehouses cloud (4/5 exactos + 1 con matiz agregado), window functions e indexing (6/6), Python GIL y Pydantic (2/2).
