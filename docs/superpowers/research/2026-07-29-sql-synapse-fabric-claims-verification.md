# Research: cerrando el gap de Azure Synapse Analytics / Microsoft Fabric Warehouse en `dataeng-sql`

**Fecha:** 2026-07-29
**Alcance:** `dataeng-sql` cubre PostgreSQL, MySQL, SQL Server, Snowflake, BigQuery, Redshift como motores primarios, más Oracle como cobertura dirigida (recursive CTEs, MERGE). Faltaba Azure Synapse Analytics y Microsoft Fabric Warehouse por completo — ni una mención en ningún archivo. Mismo tratamiento que Oracle: no full parity, cobertura dirigida y verificada donde estos dos productos realmente divergen. 3 investigaciones en paralelo contra Microsoft Learn (learn.microsoft.com) exclusivamente, vía el MCP oficial de Microsoft Learn.

**Alcance de producto:** Azure Synapse Analytics *dedicated SQL pools* (el motor MPP, no serverless SQL pools) y Microsoft Fabric *Warehouse* (no "SQL database in Fabric", que es un producto distinto con soporte diferente).

---

## Relación entre los dos productos (hallazgo previo, condiciona todo lo demás)

**Fabric Warehouse es el sucesor activo de Synapse dedicated SQL pools, no un producto no relacionado.** La propia documentación de Microsoft lo dice en un banner que aparece en casi cada página de dedicated SQL pool: *"If you're new to data warehousing, start with Fabric Data Warehouse. Existing dedicated SQL pool workloads can upgrade to Fabric."* Comparten gran parte de la superficie T-SQL ("shares a large surface area based on the SQL Database Engine"), pero la arquitectura física es distinta: dedicated SQL pool es un appliance MPP con distribución HASH/ROUND_ROBIN/REPLICATE sobre 60 distribuciones fijas; Fabric Warehouse es Delta/Parquet sobre OneLake con cómputo/storage separados y sin perillas de distribución manuales. Microsoft mantiene guías de migración activas hacia Fabric. No hay fecha de retiro anunciada para dedicated SQL pool, pero toda la guía para clientes nuevos apunta a Fabric — tratarlo como legacy/mantenimiento, Fabric como el camino activo.

**Implicación para el skill:** cuando Synapse dedicated y Fabric Warehouse divergen (y divergen en varios de estos puntos), hay que nombrar el producto específico — no basta con decir "Synapse/Fabric" como si fueran intercambiables.

## 1. Recursive CTEs — ambos NO soportados (a diferencia de Oracle)

- **Synapse dedicated SQL pool: no soportado.** Fuente oficial (`WITH common_table_expression (Transact-SQL)`, sección "Common table expressions in Azure Synapse Analytics and Analytics Platform System (PDW)"): *"A common table expression that includes references to itself (a recursive common table expression) isn't supported."*
- **Fabric Warehouse: no soportado**, confirmado dos veces (`Recursive queries using common table expressions` y `T-SQL surface area in Fabric Data Warehouse`, lista de limitaciones): *"Fabric Data Warehouse and the SQL analytics endpoint both support standard, sequential, and nested CTEs, but not recursive CTEs."* (Nota: "SQL database in Microsoft Fabric" — producto distinto — sí soporta recursión; no confundir con Warehouse.)

A diferencia de Oracle (que sí soporta recursión, solo con una sintaxis distinta), acá no hay ningún camino soportado a la recursión real — ni con keyword distinto, ni con restricción de profundidad. Es un "no" categórico en ambos productos.

## 2. MERGE — divergencia real entre los dos productos

- **Synapse dedicated SQL pool: soportado, pero preview desde octubre 2020** — sigue etiquetado "preview" en la documentación actual, años después. Restricciones documentadas: sin `merge_hint`/`TOP`; `WHEN NOT MATCHED INSERT` no funciona contra columnas `IDENTITY`; no se permite table value constructor en `USING`; `WHEN NOT MATCHED BY TARGET` exige que el target esté distribuido por `HASH`; bug histórico de corrupción de datos en builds anteriores a 10.0.17829.0 al actualizar columnas de distribución.
- **Fabric Warehouse: soportado, GA (general availability), sin la etiqueta preview.** Las restricciones específicas de dedicated SQL pool listadas arriba están documentadas solo para la versión `azure-sqldw-latest` de la doc, no para `fabric` — no se trasladan a Fabric Warehouse.

## 3. `FILTER (WHERE ...)` — no soportado en ninguno

Ninguna página de Microsoft Learn documenta una cláusula `FILTER (WHERE ...)` en T-SQL para ningún producto de la familia. La página `Aggregate functions (Transact-SQL)` aplica explícitamente a Azure Synapse Analytics y a "Warehouse in Microsoft Fabric", y enumera las 16 funciones agregadas soportadas sin mencionar `FILTER`. El diagrama de sintaxis de `SELECT` rotulado explícitamente para "Azure Synapse Analytics... and Microsoft Fabric" tampoco lo incluye.

**Nota epistémica, distinta del caso previo de SQL Server 2025/BigQuery/MySQL:** ahí la investigación anterior dejó esos tres como "no verificable" porque solo había *ausencia* de mención, sin un diagrama de sintaxis completo y explícito para ese producto que la contradijera. Acá sí hay un diagrama de sintaxis completo, vivo, y explícitamente rotulado para Synapse/Fabric que no incluye `FILTER` — es una ausencia más fuerte, tratada como "no soportado" en vez de "no verificable".

## 4. ROLLUP / CUBE / GROUPING SETS — Synapse y Fabric NO se comportan igual entre sí

| Cláusula | Synapse dedicated SQL pool | Fabric Warehouse |
|---|---|---|
| `ROLLUP` | **Sí** (agregado marzo 2019) | **Sí** |
| `CUBE` | **No** (workaround `UNION ALL`/`CROSS JOIN`) | **Sí** |
| `GROUPING SETS` | **No** (workaround `UNION ALL`) | **Sí** |

Synapse dedicated queda parecido a MySQL (solo `ROLLUP`). Fabric Warehouse tiene paridad completa con SQL Server en las tres — **más soporte que su propio predecesor arquitectónico**, consistente con el mensaje oficial de Microsoft de que migrar a Fabric da acceso a "nuevas capacidades". Matiz menor: `GROUPING_ID()` específicamente (a diferencia de `GROUPING()`) no está disponible en Fabric Warehouse.

Nota de discrepancia encontrada: un artículo de Microsoft sobre "workarounds" para `GROUP BY` en Synapse dedicated sigue listando `ROLLUP` como no soportado, pero la referencia de sintaxis T-SQL viva (`select-group-by-transact-sql`) y las release notes de marzo 2019 confirman que sí lo está desde entonces — ese artículo específico quedó desactualizado, se priorizó la referencia de sintaxis viva como fuente de verdad.

## 5. QUALIFY — no soportado en ninguno

El diagrama de sintaxis de `SELECT` para "Azure Synapse Analytics, Analytics Platform System (PDW), and Microsoft Fabric" no incluye `QUALIFY` en ninguna variante. Ambos productos requieren el patrón CTE + filtro en la capa externa, igual que SQL Server base.

## 6. Mecánica de warehouse y modelo de costos

**Organización de datos / pruning:**
- **Synapse dedicated SQL pool**: modelo MPP — tablas repartidas en 60 "distribuciones" fijas vía un tipo de distribución (`HASH`, `ROUND_ROBIN`, o `REPLICATE`), almacenadas por default en un **clustered columnstore index**, con `PARTITION` de rango opcional (ej. por fecha) para partition elimination dentro de cada distribución.
- **Fabric Warehouse**: arquitectura genuinamente distinta pese a compartir superficie T-SQL — sin tipo de distribución ni índice manual para tablas de usuario regulares. Storage es Delta/Parquet abierto en OneLake; el motor hace "distribución inteligente de datos" y compactación en segundo plano automáticamente. La guía de migración de Microsoft lo dice explícitamente: donde dedicated pool pedía tuning manual de índice/distribución, "Fabric takes care of that automatically for you".

**Costo/billing:**
- **Synapse dedicated SQL pool**: modelo de capacidad provisionada — se cobra por hora según el tamaño provisionado en **Data Warehouse Units (DWU/cDWU)**, sin importar el uso real; la única forma de parar el medidor es pausar el pool.
- **Fabric Warehouse**: se cobra vía **Capacity Units (CU)** de Fabric, compartidas entre todos los workloads de Fabric (Power BI, Data Factory, Spark, Warehouse, etc.), no un cargo específico de SQL — medido en Capacity Unit Seconds, suavizado en una ventana móvil en vez de por-query.

**Gotcha propio de Synapse dedicated:** elegir una columna de distribución de baja cardinalidad o sesgada concentra filas en una de las 60 distribuciones — "cada query es tan rápida como su distribución más lenta". Se corrige solo reconstruyendo la tabla (`CTAS`) con una mejor columna de distribución. Documentado explícitamente por Microsoft en su guía de troubleshooting de queries lentas.

---

## Resumen de acciones para el skill

**Archivos a tocar, con cobertura dirigida (no full parity):**
1. `ctes-and-recursion.md` — nota de que ninguno de los dos soporta CTEs recursivas (a diferencia de Oracle).
2. `engineering-query-patterns.md` — nota de la divergencia MERGE preview-vs-GA entre Synapse dedicated y Fabric Warehouse.
3. `aggregation-patterns.md` — extender la tabla de `FILTER` con ambos productos (no soportado); nota de que Synapse dedicated y Fabric Warehouse NO se comportan igual en `ROLLUP`/`CUBE`/`GROUPING SETS`.
4. `window-functions.md` — agregar ambos productos a la lista de motores sin `QUALIFY`.
5. `query-optimization-and-production.md` — agregar ambos productos a "Columnar cloud warehouses: a different mental model" y a "Cost in cloud warehouses", más el gotcha de distribution-key skew.
6. `SKILL.md` — agregar Synapse/Fabric como cobertura dirigida junto a Oracle en la description y el "when to use".
7. Spec de diseño (`2026-07-28-sql-skill-design.md`) — registrar el cierre en el Estado/§2, mismo patrón que el cierre de Oracle.

**Nota de honestidad epistémica, igual que con Oracle:** Synapse dedicated SQL pool y Microsoft Fabric Warehouse son productos activamente distintos hoy — no tratarlos como sinónimos ni asumir que una restricción de uno aplica al otro. Fabric Warehouse es el sucesor arquitectónico activo; Synapse dedicated es la vía legacy/mantenimiento.
