# Research: verificando el borrador de `dataeng-spark` contra fuentes primarias

**Fecha:** 2026-07-29
**Alcance:** el usuario aportó un borrador de temas (lazy evaluation/DAG/Catalyst, transformaciones vs. acciones, narrow vs. wide, shuffle, `repartition`/`coalesce`, broadcast joins, skew/salting, caching, Parquet pushdown, particionado en escritura, AQE, el pitfall de cold/warm cache benchmarking) más memoria de executor/driver y una sección PySpark-específica (UDFs vía py4j, pandas UDFs con Arrow, `.collect()`/`.toPandas()`) ya prevista en el spec de la suite (§4). 7 investigaciones en paralelo contra documentación oficial de Apache Spark (spark.apache.org/docs/latest/, versión actual "latest" = 4.2.0 al momento de esta verificación), más una revisión de `wshobson/agents`' `spark-optimization` (MIT) como insumo adicional, según lo ya anticipado en el spec de la suite §4.

---

## 1. Lazy evaluation, DAG, Catalyst, transformaciones vs. acciones, narrow vs. wide

- **Lazy evaluation:** confirmado verbatim tanto para RDD ("All transformations in Spark are lazy...") como para Dataset/DataFrame (el plan lógico se materializa recién con una acción, y ahí "Spark's query optimizer optimiza el logical plan"). Fuente: `rdd-programming-guide.html`, ScalaDoc de `Dataset`.
- **"DAG"** es terminología oficial pero vive en `web-ui.html` (visualización de jobs/stages), no en la guía de programación.
- **"Catalyst" no aparece en ningún doc de prosa oficial actual** (`rdd-programming-guide.html`, `sql-programming-guide.html`, `sql-performance-tuning.html`) — verificado por grep directo. La documentación oficial solo dice "Spark's query optimizer". El nombre "Catalyst" y sus mecánicas vienen del paper académico y del blog de ingeniería de Databricks, no de spark.apache.org/docs. Es real y verificable vía el namespace `org.apache.spark.sql.catalyst` del propio Scala API, pero el skill debe dejar claro que "Catalyst" es el nombre de facto/histórico, no un término que Spark documente en prosa.
- **Transformaciones vs. acciones:** confirmado exacto — terminología oficial en ambos APIs (RDD y Dataset), y la clasificación de cada operación nombrada (`map`, `filter`, `select`, `join`, `groupBy` = transformaciones; `count`, `collect`, `write`, `show` = acciones) es correcta.
- **Narrow vs. wide:** "narrow dependency" es terminología oficial pero solo vive en el **API reference** (`NarrowDependency` class doc), no en la guía de programación. **"Wide dependency" no tiene clase correspondiente** — el código de Spark usa `ShuffleDependency` en su lugar. Ambos términos originan del paper de RDD (citado en `research.html`), no de la guía de programación. La clasificación de ejemplos es correcta (`map`/`filter` = narrow; `groupByKey`/`join`/`repartition` = shuffle/wide), con la excepción de que `distinct` no aparece nombrado explícitamente en la lista oficial de operaciones con shuffle (aunque en la práctica sí dispara shuffle).

**Acción:** el skill debe presentar "Catalyst" y "wide dependency" como terminología estándar de la industria/community (originada en el paper de RDD y en el motor real), no citarlos como si fueran vocabulario textual de la guía oficial de Spark.

## 2. Shuffle y `repartition` vs. `coalesce`

- **Costo del shuffle:** la doc oficial nombra **tres** factores, no dos — "disk I/O, data serialization, and network I/O" (`rdd-programming-guide.html`, sección "Performance Impact"). El borrador original solo mencionaba disco y red; falta serialización.
- **`repartition` vs. `coalesce`:** confirmado que `repartition` shuffle completo (puede subir o bajar count) y `coalesce` evita el shuffle completo fusionando particiones existentes (dependencia narrow) — verbatim en ScalaDoc/PySpark docs.
- **"`repartition` rebalancea parejo": necesita matiz.** Ningún doc oficial garantiza balance parejo. Los overloads por columna solo garantizan hash partitioning (puede sesgarse en claves de baja cardinalidad); el `repartition(numPartitions)` sin columnas no documenta su estrategia interna ("round-robin" no aparece en ningún doc oficial revisado). Reformular como "redistribuye vía hash partitioning (o una estrategia no documentada en el overload sin columnas), no un balance parejo garantizado".
- **`coalesce(shuffle=True)`:** el parámetro `shuffle: Boolean` (default `false`) solo existe en la API de RDD (`RDD.coalesce`), no en `DataFrame`/`Dataset.coalesce` — por diseño, el `coalesce` de DataFrame nunca hace shuffle. Pedir más particiones de las que hay sin `shuffle=True` (o vía DataFrame, que no tiene la opción) es un no-op documentado, no un error.

**Acción:** agregar serialización como tercer costo del shuffle; matizar la afirmación de "rebalance parejo" de `repartition`.

## 3. Broadcast joins y skew — salting vs. AQE (hallazgo más importante de esta ronda)

- **Broadcast join:** confirmado exacto — `spark.sql.autoBroadcastJoinThreshold` default 10MB (10485760 bytes) desde Spark 1.1.0; el hint `broadcast()`/`BROADCAST` fuerza la estrategia incluso por encima del umbral.
- **Skew — CAMBIO DE ENFOQUE NECESARIO.** Spark 3.0+ trae AQE con skew-join optimization automática (`spark.sql.adaptive.skewJoin.enabled`, default `true` desde 3.0.0; `spark.sql.adaptive.enabled` default `true` desde 3.2.0 — ambos deben estar en `true`, y lo están por defecto en Spark moderno). Detecta una partición como "skewed" si supera `skewedPartitionFactor` (default 5.0×) la mediana **y** supera `skewedPartitionThresholdInBytes` (default 256MB), y la divide/replica automáticamente. **Alcance limitado: solo cubre sort-merge joins**, no agregaciones/`groupBy` skeweadas (para eso existe `spark.sql.adaptive.optimizeSkewsInRebalancePartitions.enabled`, que solo actúa con un hint `REBALANCE` explícito).
- **Implicación para el skill:** el salting ya NO es la técnica primaria a enseñar para skew en joins — es un fallback para cuando AQE está deshabilitado, para Spark <3.0, o para skew en agregaciones sin hint `REBALANCE`. El skill debe enseñar primero el skew-join automático de AQE, y presentar el salting manual como la técnica de respaldo, no al revés.

**Acción:** reestructurar la sección de skew — AQE primero, salting como fallback explícito, no como la técnica default.

## 4. Caching/persist, Parquet pushdown, particionado en escritura

- **Storage levels y default de `.persist()`:** confirmado que el default de RDD es `MEMORY_ONLY`. El default de DataFrame **sí difiere** como afirma el borrador, pero la propia documentación de Spark es inconsistente entre sí: el docstring de PySpark dice `MEMORY_AND_DISK_DESER` ("changed to match Scala in 3.0"), mientras el ScalaDoc de `Dataset` sigue diciendo `MEMORY_AND_DISK` sin cambios desde 1.6.0 — y `StorageLevel` en Scala ni siquiera define una constante `MEMORY_AND_DISK_DESER`. Frase segura: "familia MEMORY_AND_DISK, deserializado — no MEMORY_ONLY de RDD".
- **`.unpersist()`:** no hay mecanismo de warning/leak — Spark evict automático vía LRU; `.unpersist()` es un override manual, no bloqueante por default.
- **Parquet predicate pushdown:** confirmado, `spark.sql.parquet.filterPushdown` default `true`.
- **Projection pushdown (column pruning):** real pero no es una feature nombrada/con flag propio como el predicate pushdown — la única confirmación en prosa oficial está en el contexto de tablas cacheadas, no de lectura Parquet directa en general.
- **Particionado en escritura:** confirmado, con umbral concreto en el ScalaDoc de `DataFrameWriter.partitionBy`: "el número de valores distintos en cada columna debería típicamente ser menor a decenas de miles". La frase literal "small files problem" no aparece en ningún doc oficial — es vocabulario de la comunidad, no de Spark.

**Acción:** matizar el default de persist como "familia MEMORY_AND_DISK" sin fijar el nombre exacto de la constante; aclarar que projection pushdown no tiene flag dedicado; usar el umbral real de cardinalidad citado arriba.

## 5. AQE, el pitfall de cold/warm cache, memoria de executor/driver

- **AQE:** confirmado que re-optimiza con estadísticas de runtime. Matices: el flag original data de 1.6 pero el AQE documentado hoy es un rediseño de Spark 3.0.0 (SPARK-31412); enabled-by-default confirmado desde Spark 3.2.0 (SPARK-33679). **La doc actual (4.2.0) lista 5 features, no 3** — coalescing de particiones post-shuffle, sort-merge→broadcast, sort-merge→shuffled-hash, skew join splitting, y una quinta no listada originalmente. Decir "al menos tres" o listar las cinco, no presentar 3 como exhaustivo.
- **Cold vs. warm cache benchmarking:** confirmado que NO aparece en ningún doc oficial de Spark (`tuning.html`, `sql-performance-tuning.html` verificados por texto completo) — es sabiduría real de ingeniería de sistemas distribuidos/JVM, pero no un tema documentado por Spark. El skill debe decirlo así explícitamente en vez de forzar una cita que no existe.
- **Memoria executor/driver:** confirmado el modelo de memoria unificado (`spark.memory.fraction`=0.6 desde Spark 2.0.0 — no es un cambio 3.x como se podría asumir — `spark.memory.storageFraction`=0.5), spill de ejecución vs. eviction de storage, y el riesgo de OOM del driver por `collect()`. Un matiz: las broadcast variables son creadas por el driver pero sus copias cacheadas viven **en cada executor**, no principalmente en memoria del driver — no decir que el driver "las retiene".

**Acción:** listar (o decir "al menos") 5 features de AQE, no 3; fechar `spark.memory.fraction`=0.6 en Spark 2.0.0, no como cambio reciente 3.x; corregir la ubicación de las broadcast variables cacheadas (executors, no driver).

## 6. PySpark-específico — UDFs, Arrow, `.collect()`/`.toPandas()`

- **UDF overhead — corrección de mecanismo.** "py4j" es el término correcto solo para el lado driver (comunicación JVM↔Python del SparkContext). **Para el lado executor, el mecanismo real es: cada executor lanza un proceso worker de Python separado, y los datos viajan serializados (pickle) por pipes/sockets locales — no py4j.** Fuente: doc oficial de "Debugging PySpark" + la wiki de PySpark Internals del propio proyecto Apache Spark. Matiz adicional: desde Spark 4.2.0, los UDFs regulares usan Arrow por defecto para (de)serialización (`spark.sql.execution.pythonUDF.arrow.enabled`), ya no son puramente pickle.
- **Pandas UDFs:** terminología "Pandas UDFs (a.k.a. Vectorized UDFs)" sigue vigente en la doc actual, no fue renombrada — lo que sí se agregó son las "Pandas Function APIs" (`mapInPandas`, `applyInPandas`) y un Arrow Function API (`mapInArrow`) como adiciones separadas, no un reemplazo. `pandas_udf` existe desde Spark 2.3.0.
- **`.collect()`/`.toPandas()`:** confirmado el warning oficial en ambos — cargan todo en memoria del driver, usar solo si el resultado esperado es chico. `toPandas()` tiene ruta de optimización vía Arrow (`spark.sql.execution.arrow.pyspark.enabled`).

**Acción:** corregir "py4j" → "proceso worker de Python vía pipes/sockets locales" para el mecanismo de UDFs regulares en el executor; mantener py4j solo para el lado driver.

## 7. Revisión de `wshobson/agents`' `spark-optimization` (MIT, con atribución)

Fuente: `plugins/data-engineering/skills/spark-optimization/` (SKILL.md + `references/details.md`). Cubre terreno similar al ya planeado (shuffle, broadcast/sort-merge, skew+salting+AQE, repartition/coalesce, caching, Parquet, particionado, memoria de executor, AQE) pero sin tratar Catalyst/lazy eval/DAG, transformaciones-vs-acciones, o narrow-vs-wide como conceptos propios — su modelo de ejecución es un diagrama ASCII de 4 líneas, no una explicación.

**Contenido nuevo, genuinamente útil (se suma con atribución):**
- **Bucket joins** (`df.write.bucketBy(...).sortBy(...)`) — una tercera estrategia de join además de broadcast/sort-merge, ausente del plan original.
- **Checkpointing** (`.checkpoint()`) para romper lineage en DAGs con muchos joins/agregaciones encadenados — distinto de caching, ausente del plan original.
- **Detección programática de skew** (`F.spark_partition_id()` agrupado/contado, heurística `max/avg > 2x`) — complemento de diagnóstico a la sección de skew/salting.
- **`approx_count_distinct`** como ejemplo de evitar shuffle vía aproximación.

**Qué NO se adopta:** su estilo es cheat-sheet puro (tablas, do's/don'ts, casi sin prosa explicativa) — opuesto al enfoque de prosa-con-ejemplos ya establecido en `dataeng-sql`/`dataeng-python`. Tampoco es Spark-agnóstico: su Pattern 6 se apoya en específicos de Delta Lake (`optimizeWrite`, `autoCompact`, `OPTIMIZE ... ZORDER BY`) — eso es una decisión de formato de tabla, no vanilla Spark/Parquet, y no se adopta (mismo criterio que se aplicó al descartar contenido fuera de frontera en la ronda de `sql`).

---

## Resumen de acciones para el design spec

**Correcciones a incorporar:**
1. Shuffle: 3 costos (agregar serialización), no 2.
2. `repartition`: matizar "rebalance parejo" — es hash partitioning, no una garantía de balance.
3. Skew: reestructurar — AQE skew-join automático como técnica primaria (Spark 3.0+, on por default), salting como fallback explícito, no como técnica default.
4. `.persist()` default de DataFrame: "familia MEMORY_AND_DISK deserializado", sin fijar el nombre exacto de constante (la propia doc de Spark es inconsistente entre Scala/PySpark).
5. AQE: al menos 5 features documentadas hoy, no 3.
6. `spark.memory.fraction`=0.6 viene de Spark 2.0.0, no es un cambio reciente de la serie 3.x.
7. Broadcast variables cacheadas viven en cada executor, no en el driver.
8. UDFs regulares: corregir el mecanismo executor-side de "py4j" a "proceso worker de Python vía pipes/sockets" (py4j es solo driver-side).
9. Agregar contenido nuevo de wshobson (bucket joins, checkpointing, detección programática de skew, `approx_count_distinct`) donde encaje.

**Sin corrección, ya precisos:** transformaciones vs. acciones, broadcast join threshold (10MB), coalesce sin shuffle en DataFrame (con el parámetro `shuffle=True` solo existiendo en RDD), predicate pushdown de Parquet, umbral de cardinalidad para particionado en escritura, terminología de Pandas UDFs, warning de `.collect()`/`.toPandas()`.

**Nota de honestidad epistémica:** "Catalyst", "wide dependency", y el pitfall de cold/warm cache benchmarking son reales y correctos, pero no aparecen en la documentación oficial de Spark en prosa — el skill debe presentarlos como terminología/sabiduría estándar de la industria, no citarlos como si vinieran textualmente de spark.apache.org/docs.
