# Research: revisión de `wshobson/agents`' `data-quality-frameworks` (MIT) — insumo secundario para `quality-data-engineering`

**Fecha:** 2026-08-03
**Alcance:** cross-check del skill de terceros equivalente al dominio que vamos a construir, siguiendo el mismo tratamiento metodológico que ya recibieron `dbt-transformation-patterns` (`2026-08-02-dbt-wshobson-agents-review.md`), `spark-optimization` y `airflow-dag-patterns`: revisar con atribución, no adoptar verbatim, re-verificar cada claim técnico contra documentación oficial en vez de confiar en la fuente a ojo.

**Método:** contenido obtenido vía `gh api repos/wshobson/agents/contents/.../SKILL.md --jq '.content' | base64 -d` (y lo mismo para `references/details.md`) — no WebFetch, para tener el texto exacto sin resumen intermedio. Los claims técnicos se verificaron con WebFetch/WebSearch directo contra `docs.greatexpectations.io`, el repo oficial `datacontract/datacontract-specification`, y el repo oficial `dbt-labs/dbt-utils`.

---

## 1. Resumen fiel del contenido

La skill son dos archivos: `SKILL.md` (138 líneas, navegación + quick start) y `references/details.md` (452 líneas, 6 "patterns"). Cubre: dimensiones de calidad (tabla), una "testing pyramid" ilustrativa, Great Expectations (suite + checkpoint + pipeline de orquestación propia), dbt data tests (genéricos + custom + singulares), y un contrato de datos de ejemplo.

---

## 2. Errores factuales encontrados, con evidencia

### 2.1 API de Great Expectations desactualizada e internamente inconsistente — INCORRECTO / STALE

GX tuvo un cambio de API mayor (rompiente) en la migración V0→V1 (agosto 2024). Verificado por WebFetch directo contra `docs.greatexpectations.io` (página "Create a Checkpoint with Actions"): el patrón **actual** para crear y correr un Checkpoint es:

```python
checkpoint = gx.Checkpoint(
    name=checkpoint_name,
    validation_definitions=validation_definitions,
    actions=action_list,
    result_format={"result_format": "COMPLETE"},
)
context.checkpoints.add(checkpoint)
```

Contra esto, la fuente de terceros muestra **dos estilos distintos y mutuamente inconsistentes dentro del mismo skill**:
- `SKILL.md` (Quick Start): `context.add_expectation_suite("orders_suite")` + `gx.expectations.ExpectColumnValuesToNotBeNull(column="order_id")` + `context.run_checkpoint(checkpoint_name="daily_orders")`.
- `references/details.md` (Pattern 1, 2 y 6): `ExpectationSuite(expectation_suite_name=...)` + `ExpectationConfiguration(expectation_type="...", kwargs={...})` (sintaxis de la API V0, pre-2024) + un Checkpoint definido como dict/YAML (`class_name: Checkpoint`, `context.run_checkpoint(**checkpoint_config)`).

**Veredicto:** `context.run_checkpoint(checkpoint_name=...)` y la construcción de Checkpoints vía dict/YAML plano ya no reflejan la API actual (`gx.Checkpoint(...)` + `context.checkpoints.add()` + `.run()`). Además, el propio skill no es consistente consigo mismo: la Quick Start de `SKILL.md` usa el estilo de objetos `gx.expectations.X(...)` (más cercano al actual), pero `references/details.md` usa el estilo `ExpectationConfiguration` + string `expectation_type` (API vieja) para el resto de los ejemplos. Mismo patrón de defecto que ya se documentó para esta fuente en `dbt-transformation-patterns` (claim `delete+insert` incorrecto) y `airflow-dag-patterns` (inconsistencia interna de nombres de archivo): no verificar contra docs vigentes, y no ser internamente consistente.

### 2.2 Contrato de datos con esquema raíz inventado — INCORRECTO

`references/details.md`, Pattern 5, usa:

```yaml
apiVersion: datacontract.com/v1.0.0
kind: DataContract
...
schema:
  type: object
  properties:
    order_id:
      type: string
```

Verificado contra el repo oficial `datacontract/datacontract-specification` (README, ejemplo mínimo citado tal cual): los campos raíz reales son `dataContractSpecification` (versión, ej. `1.2.1`), `id`, `info`, `servers`, `terms`, `models`, `definitions`, `servicelevels`, `links`, `tags`. **No existe `apiVersion` ni `kind`** en ningún punto de la especificación — son convenciones de Kubernetes, no de este spec, que en cambio sigue convenciones de OpenAPI/AsyncAPI. Tampoco existe una clave `schema:` con `type: object`/`properties` al estilo JSON Schema; el nivel correspondiente es `models: <nombre>: fields: <campo>: type: ...`.

**Veredicto:** el ejemplo de contrato de datos de esta fuente no es un YAML válido contra la especificación real que dice estar citando (`datacontract.com/v1.0.0` no es un valor real de la spec) — es una mezcla libre de convenciones k8s + JSON Schema. Si en algún momento la skill nueva muestra un ejemplo de contrato de datos, debe citarse contra el spec real, no contra este ejemplo.

---

## 3. Partes verificadas como correctas

- **Tests de dbt** (Pattern 3 y 4): `dbt_utils.recency`, `dbt_utils.at_least_one`, `dbt_utils.expression_is_true` — los tres confirmados como macros reales y vigentes del paquete oficial `dbt-labs/dbt-utils`, con los argumentos mostrados (`datepart`/`field`/`interval` para `recency`; `expression` para `expression_is_true`) coincidiendo con la documentación del paquete. La sintaxis de test genérico custom (`{% test row_count_in_range(model, min_count, max_count) %}` en `tests/generic/`) y de test singular en SQL plano también es correcta.
- Las siete/seis dimensiones de calidad que tabula (completeness, uniqueness, validity, accuracy, consistency, timeliness) coinciden en sustancia con el vocabulario estándar del dominio — sin errores factuales, aunque con una imprecisión conceptual menor (ver §4).

---

## 4. Brechas de contenido frente al draft de Leonardo (no son errores — son ausencias)

Esta fuente no cubre, en ningún punto:

- **Observabilidad de datos** — cero mención a los 5 pilares (freshness/volume/distribution/schema/lineage), detección de anomalías, *schema drift*, linaje/impact analysis, o métricas MTTD/MTTR. Es exactamente la Capa 5 del draft de Leonardo, la que marca la distinción senior testing-vs-observabilidad — ausente por completo.
- **Espectro de políticas ante fallo** — el único manejo de fallo que muestra es abort total (`raise ValueError("Data quality checks failed!")` en Pattern 6). No hay patrón de cuarentena, ni drop-con-alerta, ni umbrales tolerables — la Capa 2 del draft (fail/quarantine/drop/repair según coste asimétrico) no tiene equivalente aquí.
- **Schema Registry / streaming** — sin mención a Confluent Schema Registry ni enforcement de contratos en Kafka.
- **Cultura/ownership/SLA/shift-left como sistema** — sin mención a ownership de datasets, "data as a product", ni calidad en CI/CD más allá de un comentario suelto ("Automating data validation in CI/CD" en la lista de "When to Use").
- **Imprecisión conceptual menor**: el ejemplo de "Consistency" (`expect_column_pair_values_A_to_be_greater_than_B`) es en realidad una regla de negocio intra-fila, no integridad referencial entre tablas — el draft de Leonardo separa correctamente "consistencia" de "integridad referencial" como dimensiones distintas; esta fuente las difumina un poco al no dar un ejemplo de integridad referencial real (FK-contra-tabla-padre) en su tabla de dimensiones, aunque sí lo hace más abajo vía el test `relationships` de dbt.

**Conclusión para el diseño de la skill nueva:** esta fuente es útil como referencia de sintaxis dbt (verificada, reusable) y como confirmación de que el vocabulario de dimensiones es estándar, pero no debe citarse ni para el código de Great Expectations (API stale/inconsistente) ni para el ejemplo de contrato de datos (esquema raíz inventado). El contenido diferenciador del draft de Leonardo — observabilidad, políticas de fallo con umbrales, contratos de datos reales, cultura/SLA — no tiene overlap con esta fuente en absoluto, así que no hay riesgo de duplicar su cobertura ahí; si acaso, confirma que esas capas son el valor real que la skill nueva debe aportar por encima de lo que ya existe en el ecosistema de terceros.
