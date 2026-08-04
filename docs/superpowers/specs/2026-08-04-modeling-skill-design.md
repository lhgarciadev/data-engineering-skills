# Especificación de Diseño: Skill `modeling-data-engineering`
## Séptima skill de dominio de la suite `data-engineering-skills`

**Fecha:** 2026-08-04
**Responsable:** Leonardo H. García Díaz
**Estado:** Implementado y shippeado (2026-08-04) — ver `docs/superpowers/plans/2026-08-04-modeling-skill-implementation.md` para el registro de ejecución (8 tareas: 6 reference files vía agentes en paralelo + `SKILL.md` + cross-links/bookkeeping/autorevisión). Las 6 investigaciones de verificación (R1-R6) confirmaron la mayoría del borrador con precisión de cita exacta y corrigieron 18 puntos (ver Global Constraints del plan de implementación) — entre los más relevantes: "un solo join de distancia" no es cita literal de Kimball (es "halo de dimension tables"); el Tipo 6 de SCD es contenido genuino de Kimball Group pero el nombre lo acuñó un ingeniero de HP no identificado en 2000, no Kimball; el insert-only de Data Vault es estrictamente cierto para Links pero los Satellites sí hacen un `UPDATE` (el propio libro de Linstedt lo llama "no requerido desde una perspectiva de modelado lógico"); y el hallazgo más fuerte del énfasis en Data Vault — el Cap. 14 del libro de Linstedt confirma explícitamente que Data Vault alimenta marts dimensionales de consumo usando el vocabulario propio de Kimball. Ver `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` Estado para el conteo actualizado del suite (7/9).

---

## 1. Contexto y objetivo

Séptima de las skills de dominio en entregarse (tras `python-data-engineering`, `sql-data-engineering`, `spark-data-engineering`, `pipelines-architecture-data-engineering`, `project-structure-data-engineering` y `quality-data-engineering`), cubriendo el pilar que la spec de la suite (`docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §4) ya anotaba: *"Modelado dimensional (star/snowflake), Kimball vs Data Vault, SCDs, granularidad de hechos, normalización vs denormalización para analítica"*.

**Insumo**: un borrador de contenido de Leonardo (mismo formato que los anteriores: entrevista técnica senior, de fundamentos a nivel senior), estructurado en 7 capas:

- **Capa 0** — OLTP vs. OLAP: normalización (1NF/2NF/3NF) vs. desnormalización analítica, como tensión de fondo.
- **Capa 1** — Modelado dimensional Kimball: tablas de hechos y dimensiones, star schema vs. snowflake schema.
- **Capa 2** — El grano (grain): declarar qué representa una fila, aditividad de los hechos (aditiva/semi-aditiva/no aditiva), los tres tipos de tabla de hechos (transaction, periodic snapshot, accumulating snapshot).
- **Capa 3** — Dimensiones y su evolución: surrogate keys, SCD Tipos 0–6, dimensiones que llegan tarde, dimensiones conformadas y bus matrix, degenerate/junk/role-playing dimensions, bridge tables.
- **Capa 4** — Metodologías: Inmon (top-down, 3NF) vs. Kimball (bottom-up, dimensional) vs. Data Vault (hubs/links/satellites).
- **Capa 5** — Modelado moderno: impacto del storage/cómputo columnar barato, arquitectura medallion, modeling-as-code con dbt, la trampa de la One Big Table (OBT).
- **Capa 6** — Señal senior: modelado para el patrón de acceso — serving layer/NoSQL (DynamoDB single-table design), modelado de eventos y streaming (dualidad stream-tabla), modelado bitemporal, data mesh y dominios.

El encuadre central del borrador ("el grano es el átomo del modelado", "toda decisión de modelado se justifica por los patrones de acceso, nunca por dogma") se mantiene como hilo conductor del `SKILL.md`. El borrador no cita ninguna empresa real (ya generalizado a "una entrevista técnica senior" desde su origen) — sin acción de anonimización pendiente.

**Énfasis explícito del usuario**: profundizar Data Vault / Data Vault 2.0 más allá del tratamiento de la Capa 4 del borrador (que lo trata en un párrafo, a la par de Inmon/Kimball). Insumo disponible para esto — **fuentes primarias ya en el repo**, `docs/superpowers/books/`:

- `building_a_scalable_data_warehouse_with_data_vault.md` — *Building a Scalable Data Warehouse with Data Vault 2.0* (Dan Linstedt & Michael Olschimke). La fuente primaria máxima posible: Linstedt es el creador del método. 19.497 líneas, cubre desde fundamentos de data warehousing hasta arquitectura DV2.0 completa (hubs, links, satellites, hash keys, Raw Vault vs. Business Vault, carga paralela, Business Vault, PIT/bridge tables).
- `data-vault-modeling-guide.md` — *Data Vault Modeling Guide* (Hans Hultgren, Genesee Academy, 2012). Segunda autoridad reconocida del método (autor también de *Modeling the Agile Data Warehouse with Data Vault*).
- `data_vault_modelling.md` — tesis de grado (Helsinki Metropolia, 2014), fuente secundaria/introductoria — se usa solo como cross-check de claridad pedagógica, nunca como fuente de una afirmación técnica que no esté respaldada por los dos libros anteriores.

Con esto, Data Vault deja de ser un párrafo dentro de la comparación de metodologías (Capa 4) y se convierte en su **propio reference file**, tratado con la misma profundidad que Kimball recibe en el resto del borrador.

## 2. Alcance y fronteras

### 2.1 Resolución de scope forks y fronteras con skills existentes

El borrador toca, directa o indirectamente, territorio ya cubierto por 4 skills shippeadas, más dos forward-pointers ya sembrados desde skills anteriores que esta skill debe resolver. Cada uno se resuelve aquí, con cross-link en vez de duplicación:

| Tema del borrador | Ya cubierto en | Resolución |
|---|---|---|
| SQL de SCD Tipo 2 (`UPDATE` + `INSERT`/`MERGE`, dos sentencias) | `sql-data-engineering/references/engineering-query-patterns.md` (líneas 135-183) | No se reabre el bloque SQL. Esta skill cubre la **decisión conceptual** — cuándo Tipo 1 vs. Tipo 2 vs. el resto del espectro (0, 3, 4, 6), por qué existe la surrogate key — y cross-linkea hacia allá para la mecánica de implementación. |
| "Medallion" (bronze/silver/gold) como vocabulario de dbt | `pipelines-architecture-data-engineering/references/dbt-project-architecture.md` (líneas 22-30) | Guardrail ya fijado: medallion **no es** terminología propia de dbt (es un término Databricks/lakehouse que algunos equipos mapean por analogía). Esta skill describe medallion como patrón de refinamiento por capas en general, nunca como sinónimo de staging/intermediate/marts, y cross-linkea allá para esa distinción. |
| Data-as-a-product / Data Mesh (las 6 cualidades de Dehghani, "SLO" no "SLA") | `quality-data-engineering/references/quality-culture-and-governance.md` (línea 7) | No se repiten las 6 cualidades. Esta skill cross-linkea desde la Capa 6 (dominios) hacia allá; su propio aporte es el ángulo de modelado (cada dominio modela y posee su propio data product), no el de gobierno/SLO ya cubierto. |
| Broadcast join contra tablas de dimensión | `spark-data-engineering/references/joins-and-skew.md` (línea 24) | Ya está enlazado desde `sql-data-engineering/joins.md`. Esta skill lo menciona como motivo de que el star schema sea rápido, sin reexplicar el mecanismo, y cross-linkea. |
| Confluent Schema Registry / modos de compatibilidad Avro | `quality-data-engineering/references/data-contracts-and-schema-compatibility.md` | La sección de modelado de eventos (Capa 6) menciona *que* los esquemas de eventos se versionan vía schema registry, pero no reexplica los 7 modos de compatibilidad — cross-link. |
| CDC log-based (Debezium, WAL/binlog) | Diferido explícitamente a la futura `streaming-data-engineering` (hallazgo cerrado en `docs/superpowers/specs/2026-07-28-suite-skills-ingenieria-datos-design.md` §8, y ya anotado en `sql-data-engineering/engineering-query-patterns.md` línea 107 y `quality-data-engineering/SKILL.md` línea 21) | Esta skill **no enseña la mecánica de captura**. La dualidad stream-tabla y el modelado de eventos (Capa 6) se explican en términos generales; la captura real queda como cross-link diferido hacia la futura skill, mismo tratamiento que los otros 4 diferidos ya registrados en la spec de suite. |
| Patrón `ROW_NUMBER`/CTE para dedup ("el mismo patrón que vimos") | `sql-data-engineering/references/window-functions.md` y `engineering-query-patterns.md` | Ya está cross-linkeado desde `python-data-engineering/external-api-integration.md`. Esta skill lo menciona de pasada como ejemplo de proyección stream→tabla, cross-link, sin reexplicar. |

### 2.2 Forward-pointer pendiente a cerrar (sembrado antes de que esta skill existiera)

`pipelines-architecture-data-engineering/references/idempotency-and-backfills.md` (líneas 46-48) ya dice: *"Backfilling is also the mechanism for absorbing late-arriving data... which connects directly to the late-arriving-fact patterns covered in dimensional modeling."* Esa cita habla explícitamente de **late-arriving facts**, no solo de late-arriving dimensions (lo único que el borrador de Leonardo cubre en su Capa 3). Acción: el reference file de dimensiones/SCD de esta skill debe cubrir **ambos** — late-arriving dimensions (placeholder/inferred member, ya en el borrador) y late-arriving facts (el hecho llega con fecha de negocio anterior a la fecha de carga — mismo problema que el modelado bitemporal de la Capa 6 aborda desde otro ángulo) — y, una vez implementado, actualizar esa mención en `idempotency-and-backfills.md` de prosa plana a hyperlink real, mismo tratamiento que se le dio al forward-pointer de `serving-pipeline-output.md` cuando se entregó `quality-data-engineering`.

### 2.3 Qué no cubre esta skill

Validación de esquema en tiempo de ejecución (`quality-data-engineering`), código a nivel de función/clase (`python-data-engineering`), SQL de implementación de SCD/window functions (`sql-data-engineering`), captura CDC real (futura `streaming-data-engineering`), infraestructura/hosting de un serving store NoSQL (futura `iac-cloud-data-engineering`).

## 3. Estructura de archivos propuesta

```
skills/modeling-data-engineering/
  SKILL.md
  references/
    star-schema-and-grain.md          # Capas 0-2: OLTP/OLAP, hechos/dimensiones, star vs snowflake, grano, aditividad, tipos de fact table
    scd-and-dimension-patterns.md     # Capa 3: surrogate keys, SCD 0-6, late-arriving dims Y facts, conformed dims/bus matrix, degenerate/junk/role-playing, bridge tables
    modeling-methodologies.md         # Capa 4: Inmon vs. Kimball vs. Data Vault — comparación y marco de decisión (Data Vault se explica aquí solo a nivel posicional, con pointer al archivo dedicado)
    data-vault-2-0.md                 # Data Vault en profundidad — hubs/links/satellites, hash keys, Raw Vault vs Business Vault, auditabilidad insert-only, carga paralela — grounded en los 2 libros canónicos locales
    modern-lakehouse-modeling.md      # Capa 5: columnar storage barato, medallion (cross-link a dbt), modeling-as-code, la trampa OBT
    modeling-for-access-patterns.md   # Capa 6: single-table design NoSQL, modelado de eventos/dualidad stream-tabla, bitemporal, data mesh (cross-link)
```

Seis reference files — mismo orden de magnitud que `sql-data-engineering` y `quality-data-engineering`. `data-vault-2-0.md` como archivo separado (no una sección dentro de `modeling-methodologies.md`) es la decisión estructural que refleja el énfasis pedido.

## 4. Plan de verificación

Mismo proceso que las 5 skills anteriores: por cada bloque temático, una investigación independiente contra fuentes primarias, registrada en `docs/superpowers/research/`. Seis investigaciones en paralelo:

- **R1 — Fundamentos Kimball** (star/snowflake, grano, aditividad, tipos de fact table): verificar contra material propio de Kimball Group (kimballgroup.com, *The Data Warehouse Toolkit*) — no contra artículos secundarios que reinterpretan a Kimball.
- **R2 — Dimensiones y SCD**: surrogate keys, los 6+1 tipos de SCD (**verificar con cuidado el Tipo 6 — "híbrido 1+2+3" es una afirmación del borrador que debe confirmarse contra Kimball Group, no asumirse**), late-arriving dimensions y facts, conformed dimensions/bus matrix, degenerate/junk/role-playing dimensions, bridge tables.
- **R3 — Inmon vs. Kimball vs. Data Vault**: verificar la caracterización de Inmon (top-down, EDW normalizado en 3NF, Corporate Information Factory) contra fuentes de Inmon, no solo contra comparaciones de terceros — para no repetir un error de caracterización unilateral.
- **R4 — Data Vault 2.0**: la investigación de énfasis. Fuente primaria = los 2 libros locales (Linstedt/Olschimke, Hultgren), no búsqueda web — extraer y citar con precisión (capítulo/sección) hubs, links, satellites, hash keys vs. sequence keys, Raw Vault vs. Business Vault, insert-only/auditabilidad, carga paralela, PIT/bridge tables en contexto DV.
- **R5 — Modelado moderno y OBT**: verificar el argumento de costo de storage/cómputo columnar barato, el patrón OBT como feature table de ML o extracto de BI, respetando el guardrail ya fijado de que medallion no es vocabulario de dbt.
- **R6 — Modelado para patrones de acceso**: DynamoDB single-table design (docs oficiales de AWS), modelado de eventos y dualidad stream-tabla (fuente primaria sólida — p. ej. Kafka/Confluent docs o el libro *Designing Data-Intensive Applications* de Kleppmann), modelado bitemporal (fuente primaria/académica reconocida, no un blog post).

## 5. Próximos pasos

1. Ejecutar R1–R6 (agentes de investigación en paralelo, resultado en `docs/superpowers/research/`).
2. Escribir el plan de implementación (`docs/superpowers/plans/2026-08-04-modeling-skill-implementation.md`), una tarea por reference file + `SKILL.md` + actualización del forward-pointer en `idempotency-and-backfills.md` + cross-links salientes hacia las 4 skills de la tabla §2.1.
3. Implementar vía `superpowers:subagent-driven-development`.
4. Autorevisión contra el estándar `writing-great-skills` + validación de discoverability.
