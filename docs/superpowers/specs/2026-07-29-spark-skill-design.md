# Especificación de Diseño: Skill `dataeng-spark`
## Tercera skill de dominio de la suite `data-engineering-skills`

**Fecha:** 2026-07-29
**Responsable:** Leonardo H. García Díaz
**Estado:** Implementado y shippeado (2026-07-29) — ver `docs/superpowers/plans/2026-07-29-spark-skill-implementation.md` para el registro de ejecución.

---

## 1. Contexto y objetivo

Segunda de las 6 skills de dominio pendientes definidas en `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` (§4, `dataeng-sql` ya entregada). Cubre arquitectura y tuning de Spark en general, más una sección propia para lo específico de PySpark — el mismo alcance que ya fijaba la spec de la suite, sin recortes: el usuario confirmó explícitamente incluir memoria de executor/driver y la sección PySpark-específica en esta misma tanda, en vez de diferirlas.

Insumo: borrador de contenido aportado por el usuario (11 tópicos, de fundamentos de ejecución a benchmarking en producción), verificado contra documentación oficial de Apache Spark (spark.apache.org/docs/latest/, versión "latest" = 4.2.0 al momento de esta verificación) y complementado con revisión de `wshobson/agents`' `spark-optimization` (MIT), según lo ya anticipado en la spec de la suite §4. Registro completo de la verificación: `docs/superpowers/research/2026-07-29-spark-claims-verification.md`.

## 2. Alcance y fronteras

Reafirma la frontera ya fijada en la spec de la suite (§4):

- **Cubre**: modelo de ejecución (lazy evaluation, DAG, optimizador de queries, transformaciones vs. acciones, narrow vs. wide dependencies), shuffle y particionado (`repartition`/`coalesce`), joins (broadcast, skew — AQE y salting), caching/checkpointing, formatos columnares (Parquet, pushdown), particionado en escritura, Adaptive Query Execution, memoria de executor/driver, y una sección propia para lo específico de PySpark (overhead de UDFs, pandas UDFs con Arrow, riesgo de memoria de `.collect()`/`.toPandas()`).
- **No cubre — frontera con otra skill**:
  - Streaming estructurado (Structured Streaming, watermarks, exactly-once) → `dataeng-streaming` (spec de la suite, §4).
  - Despliegue/infraestructura de clústers Spark (Terraform, Docker, dimensionamiento de clúster como decisión de infra) → `dataeng-iac-cloud`.
  - Especificidad de formato de tabla Lakehouse (Delta Lake `OPTIMIZE`/`ZORDER`/`autoCompact`, Iceberg, Hudi) → fuera de las 8 skills actuales por ahora; el research (§7) encontró que `wshobson/agents` mezcla esto con Parquet/vanilla Spark y **no se adopta** esa mezcla — mismo criterio que excluyó el contenido OLTP de `database-design` al planear `dataeng-sql`.
  - Modelado dimensional/esquemas → `dataeng-data-modeling`.
- **Alcance de versión**: Apache Spark 3.x/4.x (comportamiento actual, `latest` = 4.2.0). Donde el comportamiento cambió entre versiones relevantes (AQE default-on desde 3.2.0, skew-join automático desde 3.0.0, Arrow-por-defecto en UDFs desde 4.2.0), se nombra la versión explícitamente en vez de generalizar "Spark reciente".

## 3. Fuentes

- Borrador original del usuario (11 tópicos) — traducido y corregido, no adoptado verbatim (contenido final en inglés, convención ya fijada en la spec de la suite §3).
- Verificación directa contra documentación oficial de Apache Spark: RDD Programming Guide, SQL Programming Guide, SQL Performance Tuning Guide, Tuning Guide, Cluster Mode Overview, PySpark API Reference (incluyendo Debugging PySpark y Apache Arrow in PySpark), y el wiki oficial "PySpark Internals" del propio proyecto Apache Spark.
- `wshobson/agents` — `plugins/data-engineering/skills/spark-optimization/` (MIT) — revisado como insumo adicional, con atribución, sin adopción literal: aporta contenido nuevo (bucket joins, checkpointing, detección programática de skew, `approx_count_distinct`) a las secciones correspondientes (ver §4.3, §4.4). Su estilo (cheat-sheet de do's/don'ts) y su mezcla con específicos de Delta Lake difieren de los ya fijados acá y no se adoptan — mismo tratamiento que recibió `sql-optimization-patterns` al planear `dataeng-sql`.

## 4. Estructura de archivos

```
skills/dataeng-spark/
  SKILL.md
  references/
    execution-model.md
    shuffle-and-partitioning.md
    joins-and-skew.md
    caching-and-file-formats.md
    adaptive-query-execution-and-benchmarking.md
    memory-management.md
    pyspark-specifics.md
```

Mismo formato que `dataeng-sql`/`dataeng-python`: overview, when to use, tabla de quick reference y tabla de common mistakes en `SKILL.md`; un archivo de reference por tema pesado. Contenido en inglés, ejemplos de código en PySpark (el lenguaje más relevante al tema, per spec de la suite §3).

### 4.1 `execution-model.md`

Lazy evaluation, el DAG de transformaciones, el optimizador de queries (nombrado como "Catalyst" — término estándar de industria/Databricks, no vocabulario textual de la doc oficial de Spark, ver nota de honestidad epistémica abajo), transformaciones vs. acciones, narrow vs. wide dependencies.

**Corrección a incorporar:** presentar "Catalyst" y "wide dependency" como terminología estándar de la industria (originada en el paper de RDD y el motor real, verificable en el namespace `org.apache.spark.sql.catalyst` del propio Scala API), no citarlos como si aparecieran textualmente en la guía de programación oficial — la doc oficial solo dice "Spark's query optimizer" en prosa. Aclarar también que Catalyst opera sobre el plan lógico de DataFrame/Dataset/SQL — los RDDs no pasan por Catalyst.

### 4.2 `shuffle-and-partitioning.md`

Qué es el shuffle y por qué es la operación más cara, `repartition` vs. `coalesce`.

**Correcciones a incorporar:**
- El shuffle tiene **tres** costos documentados, no dos: disk I/O, data serialization, y network I/O (`rdd-programming-guide.html`) — el borrador original solo mencionaba disco y red.
- "`repartition` rebalancea parejo" necesita matiz: los overloads por columna solo garantizan hash partitioning (puede sesgarse en claves de baja cardinalidad); el overload sin columnas no documenta su estrategia interna. Reformular sin prometer balance parejo garantizado.
- El parámetro `shuffle: Boolean` de `coalesce` solo existe en la API de RDD, no en `DataFrame`/`Dataset.coalesce` (que por diseño nunca hace shuffle) — vale la pena una nota breve para quien viene del API de RDD.

### 4.3 `joins-and-skew.md`

Broadcast joins (`broadcast()` hint, umbral automático), manejo de data skew.

**Corrección importante a incorporar (cambio de enfoque, no solo redacción):** AQE trae skew-join optimization automática desde Spark 3.0.0, on por default desde Spark 3.2.0 (`spark.sql.adaptive.enabled` + `spark.sql.adaptive.skewJoin.enabled`, ambos `true` por defecto). Detecta una partición sesgada por umbral (`skewedPartitionFactor`=5.0×, `skewedPartitionThresholdInBytes`=256MB) y la divide/replica automáticamente — pero **solo para sort-merge joins**, no para agregaciones/`groupBy` sesgadas (para eso, `optimizeSkewsInRebalancePartitions` requiere un hint `REBALANCE` explícito). El salting manual pasa a ser la técnica de **fallback** — para Spark <3.0, AQE deshabilitado, o skew en agregaciones sin hint — no la técnica primaria a enseñar primero.

**Contenido nuevo a incorporar** (de `wshobson/agents`, con atribución): bucket joins (`df.write.bucketBy(...).sortBy(...)`, una tercera estrategia de join sin shuffle en query-time) y detección programática de skew (`F.spark_partition_id()` agrupado/contado, heurística `max/avg > 2x`).

### 4.4 `caching-and-file-formats.md`

`.cache()`/`.persist()` y storage levels, Parquet con predicate/projection pushdown, particionado en escritura.

**Correcciones a incorporar:**
- El default de `.persist()` en DataFrame difiere del default de RDD (`MEMORY_ONLY`), pero la propia doc de Spark es inconsistente sobre el nombre exacto (PySpark dice `MEMORY_AND_DISK_DESER`, Scala dice `MEMORY_AND_DISK` sin ese sufijo) — usar la frase segura "familia MEMORY_AND_DISK, deserializado" sin fijar una constante que no está consistentemente documentada.
- Projection pushdown (column pruning) es real pero no tiene flag/feature nombrada propia como el predicate pushdown (`spark.sql.parquet.filterPushdown`, default `true`) — no presentarlos como paralelos simétricos.
- Particionado en escritura: usar el umbral real citado por Spark ("el número de valores distintos en cada columna debería típicamente ser menor a decenas de miles", `DataFrameWriter.partitionBy` ScalaDoc) en vez de la frase "small files problem", que es vocabulario de comunidad, no de la doc oficial.

**Contenido nuevo a incorporar** (de `wshobson/agents`, con atribución): checkpointing (`.checkpoint()`) para romper lineage en DAGs con muchos joins/agregaciones encadenados, distinto de caching; `approx_count_distinct` como ejemplo de evitar shuffle vía aproximación.

### 4.5 `adaptive-query-execution-and-benchmarking.md`

Qué hace AQE y por qué reoptimiza en runtime, el pitfall de benchmarkear en cold cache cuando producción corre en warm cache.

**Correcciones a incorporar:**
- La doc oficial actual (4.2.0) lista **5** features de AQE, no 3 — coalescing de particiones post-shuffle, sort-merge→broadcast, sort-merge→shuffled-hash, skew-join splitting, y una quinta. Decir "al menos" o listarlas todas, no fijar "tres" como si fuera exhaustivo y estable entre versiones.
- El pitfall de cold/warm cache benchmarking **no aparece en ningún doc oficial de Spark** (verificado por texto completo) — es sabiduría real de sistemas distribuidos/JVM, no un tema documentado por Spark. Presentarlo así explícitamente, sin forzar una cita oficial que no existe.

### 4.6 `memory-management.md`

Modelo de memoria unificado, memoria de executor vs. driver.

**Correcciones a incorporar:**
- `spark.memory.fraction`=0.6 viene de **Spark 2.0.0** (SPARK-15796) — no presentarlo como un cambio reciente de la serie 3.x.
- Las broadcast variables son creadas por el driver, pero sus copias cacheadas viven **en cada executor** — no decir que el driver "las retiene".

### 4.7 `pyspark-specifics.md`

Overhead de UDFs Python, pandas UDFs con Arrow, riesgo de memoria de `.collect()`/`.toPandas()`.

**Corrección importante a incorporar (error de mecanismo, no solo matiz):** "py4j" es el término correcto únicamente para el lado **driver** (comunicación JVM↔Python del SparkContext). Para el lado **executor** — donde corre un UDF regular fila-a-fila — el mecanismo real es un proceso worker de Python separado por executor, con los datos serializados (pickle) viajando por pipes/sockets locales, **no py4j**. Fuente: doc oficial "Debugging PySpark" + la wiki "PySpark Internals" del propio proyecto Apache Spark. Matiz adicional: desde Spark 4.2.0 los UDFs regulares usan Arrow por defecto para (de)serialización (`spark.sql.execution.pythonUDF.arrow.enabled`), ya no son puramente pickle. La terminología "Pandas UDFs (a.k.a. Vectorized UDFs)" sigue vigente (no fue renombrada); las "Pandas Function APIs" (`mapInPandas`, `applyInPandas`) son adiciones separadas, no un reemplazo.

## 5. Fuera de alcance (de esta fase)

- Structured Streaming — pertenece a la futura skill `dataeng-streaming`.
- Despliegue/infraestructura de clústers Spark (Terraform, Docker, dimensionamiento) — pertenece a `dataeng-iac-cloud`.
- Especificidad de formato de tabla Lakehouse (Delta Lake, Iceberg, Hudi) — no encaja limpio en ninguna de las 8 skills actuales tal como están definidas hoy; queda anotado, igual que quedó anotado el contenido OLTP de `database-design` al planear `dataeng-sql`.
- Modelado dimensional/esquemas — pertenece a `dataeng-data-modeling`.

## 6. Próximos pasos

Transición a `superpowers:writing-plans` para el plan de implementación: redacción completa de `SKILL.md` + los 7 reference files, con el contenido final en inglés y las correcciones de la sección 4 incorporadas, siguiendo el mismo proceso de validación liviana de discoverability ya usado con `dataeng-python` y `dataeng-sql`.
