# Especificación de Diseño: Skill `streaming-data-engineering`

## Octava skill de dominio de la suite `dataforge`

## 1. Contexto y objetivo

Streaming es el pilar donde converge el resto de la suite: el log y la dualidad
stream-tabla que `modeling-data-engineering` usa para eventos, el Structured Streaming
que `spark-data-engineering` declina explícitamente, el CDC al que apuntan tanto
`modeling` como `quality`, el schema registry que `quality-data-engineering` gobierna
como contrato, el backfill que `pipelines-architecture-data-engineering` enseña sobre
particiones, y la idempotencia que atraviesa `python-data-engineering` y `sql-data-engineering`.

El encuadre que organiza la skill entera, equivalente al "grano" en modelado o al
"shuffle" en Spark: **streaming es procesar un dataset no acotado**. En batch los datos
están acotados — se ven enteros, se sabe cuándo terminan, se pueden ordenar. En streaming
no terminan, llegan desordenados y con retraso, y hay que producir resultados antes de
haberlos visto todos. De esa tensión se derivan ventanas, watermarks, event-time,
exactly-once y estado. Toda la skill se explica desde ahí.

Objetivo: cubrir streaming de fundamentos a criterio senior, con la misma forma que las
siete skills de dominio ya entregadas — `SKILL.md` como router con overview, when-to-use,
quick reference y common mistakes, y el peso en `references/`.

## 2. Alcance y fronteras

### 2.1 Resolución de fronteras con skills existentes

Dos forks se resolvieron explícitamente antes de escribir el spec.

**Fork 1 — Kafka: modelo del log vs. provisión.** La regla es *si se decide en código,
es de streaming; si se decide en Terraform, es de `iac-cloud-data-engineering`*.

| A `streaming` | A `iac-cloud` (aún no existe) |
|---|---|
| topic, partición, offset, clave de partición | MSK vs. Kinesis vs. autogestionado |
| consumer groups y rebalance | sizing del cluster, número de brokers |
| trade de `acks`/ISR — es durabilidad, no provisión | IAM, KMS, red, VPC |
| compactación vs. retención | costo y operación del cluster |

La elección de clave de partición se queda en streaming porque es una decisión de
modelado con consecuencias de orden y de skew, no una decisión de infraestructura.

**Fork 2 — Lambda/Kappa y replay.** `pipelines-architecture-data-engineering` ya reclama
"structural idempotency and backfills" y el diseño de la capa de orquestación. La
resolución es que **streaming enseña Lambda vs. Kappa y el replay desde offset**, porque
ambos solo tienen sentido sobre un log reproducible, que es sustrato de streaming.
`pipelines` conserva el backfill de particiones batch y gana un puntero explícito hacia
streaming para el caso del replay.

Esto exige editar la description de `pipelines` y re-medir sus casos de triggering (§5).
Se eligió por encima de la alternativa "ambas skills lo enseñan desde su ángulo" porque
esa alternativa ya tiene precedente medido en este repo: el caso D2 (data contracts,
reclamado a la vez por `quality` y por `project-structure`) no dispara ninguna de las dos
— 3 de 5 reps en silencio. Cuando dos skills reclaman el mismo territorio, el voto se
parte.

### 2.2 Fronteras que se negocian sin invadir

| Tema | Dueño | Qué hace `streaming` |
|---|---|---|
| `MERGE`/upsert y dedup con `ROW_NUMBER` | `sql-data-engineering` | lo referencia como patrón de sink idempotente |
| idempotencia dentro de una función o task | `python-data-engineering` | reclama la propiedad **end-to-end**, no la implementación local |
| schema registry como contrato y compatibilidad | `quality-data-engineering` | lo referencia para productor/consumidor desacoplados en el tiempo |
| modelado de eventos, event sourcing, bitemporal | `modeling-data-engineering` | referencia la dualidad stream-tabla, no re-enseña el modelado |
| tuning de Spark, shuffle, skew | `spark-data-engineering` | referencia el micro-batch como modelo de ejecución |

### 2.3 Forward-pointers pendientes a cerrar

Tres skills declinan hoy hacia una skill que no existía. Al entregar esta, sus punteros
dejan de ser texto muerto y pasan a ser fronteras reales:

- `spark-data-engineering` — Structured Streaming (watermarks, exactly-once)
- `modeling-data-engineering` — mecánica de captura CDC (Debezium, WAL/binlog)
- `quality-data-engineering` — CDC/log-based change capture

Además, dos reference files apuntan al mismo lugar: `sql/references/engineering-query-patterns.md`
y `modeling/references/modeling-for-access-patterns.md`.

**Consecuencia sobre el orquestador.** El commit `f3f48cf` retiró `streaming-data-engineering`
de la lista de dominios de `data-engineering`, como parte de la mitigación de skills
fantasma. Al entregar esta skill hay que devolverlo, tanto en la description como en el
cuerpo. Ese cambio toca una description y por lo tanto se re-mide.

### 2.4 Qué no cubre esta skill

- Provisión y operación de clusters (§2.1, fork 1).
- Tuning de Spark ajeno al streaming.
- Modelado dimensional o de eventos como tal.
- APIs de un motor específico como tutorial. La suite es agnóstica: los motores se
  comparan para elegir, no se enseñan como manual de referencia.

## 3. Estructura de archivos

Seis reference files, misma escala que `modeling-data-engineering` (1.6k–3.5k palabras
cada uno), más `SKILL.md`.

### 3.1 `unbounded-data-and-when-not-to-stream.md`

Bounded vs. unbounded como distinción real, frente a "rápido vs. lento". Batch como caso
especial de streaming sobre datos acotados, y por qué ese marco explica que las mismas
primitivas apliquen a ambos. El trade de latencia contra costo, completitud y
simplicidad.

Incluye deliberadamente **cuándo NO hacer streaming**, que en el borrador de origen
aparecía al final de la capa de arquitectura. Se mueve al primer archivo porque es el
criterio que más se usa y el que más se ignora: enterrado al final de arquitectura queda
invisible justo para quien lo necesita antes de empezar.

### 3.2 `the-log-and-partitioning.md`

El log append-only como abstracción central. Topic, partición, offset, clave de
partición, consumer group y rebalance. La partición como átomo doble: paralelismo **y**
orden — el orden solo existe dentro de una partición, y asumir orden total es la fuente
de una clase entera de bugs. Trade de `acks` e ISR. Retención vs. compactación, y la
compactación como la dualidad stream-tabla hecha concreta. La clave de partición como
decisión de diseño, con el skew como consecuencia.

### 3.3 `event-time-windows-and-watermarks.md`

Los tres tiempos — event, processing, ingestion — y por qué event-time es el que casi
siempre importa. El skew entre event-time y processing-time como condición normal, no
como anomalía. Ventanas tumbling, sliding y de sesión. El watermark como estimación de
completitud, y su trade central: agresivo baja latencia y descarta tardíos, conservador
completa más y retiene más estado. Qué hacer con los datos que llegan tarde — descartar,
allowed lateness, side output. Triggers y el marco what/where/when/how.

Este archivo fusiona dos capas del borrador de origen porque son un solo arco: el
watermark es la materialización del problema del tiempo. Separarlos obliga a saltar entre
archivos para entender una idea.

### 3.4 `state-and-delivery-guarantees.md`

Procesamiento con estado y por qué el estado es lo difícil: es long-lived, debe sobrevivir
fallos, y no puede crecer sin límite en un flujo infinito — de ahí ventanas y TTLs.
State backends. Checkpointing y snapshots distribuidos como tolerancia a fallos del
estado, y por qué el log reproducible es su precondición.

Las tres semánticas de entrega, y la tesis central: **exactly-once no es una casilla que
se activa, es una propiedad end-to-end que requiere fuente reproducible, estado
checkpointeado y sink idempotente o transaccional, y se rompe en el eslabón más débil,
casi siempre el sink.**

### 3.5 `stream-processing-patterns.md`

Stateless vs. stateful. Stream-stream join y por qué **debe** acotarse por ventana: sin
cota temporal el estado es infinito. Stream-table join como el patrón workhorse, la
KTable como topic compactado materializado, y el enriquecimiento dimensional en tiempo
real. CDC como stream, cerrando el puntero de `modeling` y `quality`. Deduplicación con
estado y watermark. Cómo se expresa todo esto en SQL sobre streams.

### 3.6 `streaming-architecture-and-engines.md`

Lambda y su costo real — dos bases de código y dos lógicas que deben coincidir. Kappa y
el replay como sustituto de la capa batch. Elección de motor entre Kafka Streams, Flink,
Spark Structured Streaming y Beam, sobre los ejes de latencia, complejidad de estado y
ecosistema. Operación: consumer lag como métrica reina, backpressure, particiones como
techo de paralelismo del consumer group.

### 3.7 `SKILL.md`

Overview con el encuadre de dataset no acotado. When-to-use con triggers concretos y las
fronteras de §2. Quick reference. Common mistakes.

La description se escribe siguiendo lo que la matriz de triggering ya midió en este repo:
triggers sin jargon junto a los técnicos, porque los prompts diagnósticos reales no usan
el vocabulario del dominio; fronteras como condicionales sobre predicados observables, no
como prohibiciones; y el condicional de co-invocación que recuperó los casos capturados
por skills de proceso.

## 4. Plan de verificación de contenido

Siete pasadas contra fuente primaria, siguiendo la práctica de las 28 verificaciones ya
en `docs/superpowers/research/`.

1. **Modelo Dataflow** — el marco what/where/when/how y la tesis "batch es un caso
   especial de streaming", contra el paper de VLDB 2015.
2. **Kafka** — garantía de orden por partición, semántica de `acks`, ISR, compactación de
   log, mecánica del rebalance.
3. **Exactly-once end-to-end** — transacciones de Kafka y la afirmación de los tres
   eslabones necesarios.
4. **Flink** — snapshots distribuidos y barriers, semántica de watermarks, state backends.
5. **Spark Structured Streaming** — micro-batch frente al modo continuous y su estado
   actual, semántica de `withWatermark`, y comportamiento de late data **según output
   mode**.
6. **CDC/Debezium** — mecánica de lectura del log de transacciones y la afirmación
   push-vs-polling.
7. **Kappa** — formulación original y si "reemplaza la capa batch por completo" es una
   afirmación fiel o una simplificación.

Dos afirmaciones se marcan como candidatas a drift y deben verificarse antes de
escribirse: el estado del modo *continuous* de Spark, que pudo cambiar de experimental a
deprecado, y el comportamiento de late data en Spark, que depende del output mode y suele
contarse simplificado.

## 5. Plan de verificación de comportamiento

La skill no se considera entregada hasta que rutee, medido con el harness de
`tests/triggering/`.

- **Casos nuevos** para streaming en `matrix.tsv` y `matrix-adversarial.tsv`, con al
  menos un positivo, un discriminador contra `spark`, y un caso sin jargon.
- **D6 cambia de ground truth.** Hoy espera `NONE` y dispara `spark` 1 de 5; al existir
  esta skill su `EXPECTED` pasa a `streaming-data-engineering`. Es el caso que valida que
  la frontera de `spark` por fin funcione, y su histórico está en
  `tests/triggering/baselines/`.
- **A8 cambia de ground truth.** Hoy espera `NONE` — Kafka exactly-once hacia Delta — y
  dispara el orquestador, que no tiene a dónde rutear. Pasa a esperar streaming.
- **Re-medir toda description tocada**: `pipelines` (cede Kappa), `data-engineering`
  (recupera streaming en su lista), y los tres forward-pointers de `spark`, `modeling` y
  `quality`.
- Reps, no muestra única. Esta sesión ya documentó que un evento de 1 en 5 es invisible a
  n=1.

## 6. Próximos pasos

Plan de implementación vía `superpowers:writing-plans`.
