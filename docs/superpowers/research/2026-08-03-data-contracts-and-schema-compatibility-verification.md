# Research: contratos de datos — bloques `models`/`quality`/`servicelevels` de la Data Contract Specification, modos de compatibilidad de Confluent Schema Registry, reglas de evolución de Avro, y "shift-left" de calidad en CI/CD

**Fecha:** 2026-08-03
**Alcance:** verificación de 4 bloques de claims para contenido futuro de `quality-data-engineering` (capa "Contratos de datos" del draft) sobre: (1) estructura exacta de `models.<nombre>.fields.<campo>`, el bloque `quality` y el bloque `servicelevels` en la especificación oficial `datacontract/datacontract-specification`; (2) nombres oficiales y semántica exacta de los modos de compatibilidad de Confluent Schema Registry, y si el registro rechaza o solo advierte; (3) reglas reales de "schema resolution" de Apache Avro para evolución de esquemas; (4) si "el CI/CD del productor falla si rompe el contrato" tiene una implementación real y documentada, o es un patrón sin referencia única. Continúa la investigación previa de `2026-08-03-quality-wshobson-agents-review.md` §2.2 (root fields de la spec, ya confirmados ahí, no repetidos aquí salvo para reforzar con un ejemplo real). Todo verificado por fetch directo contra el repo oficial en GitHub (`datacontract/datacontract-specification`, `datacontract/datacontract-cli`, `datacontract/datacontract-action`), `docs.confluent.io` y `avro.apache.org` — sin blogs de terceros, salvo donde se marca explícitamente como búsqueda de corroboración.

---

## 1. Data Contract Specification — `models.<nombre>.fields.<campo>`, `quality`, `servicelevels`

Fuentes primarias fetcheadas directamente:
- [README.md del repo `datacontract/datacontract-specification`](https://github.com/datacontract/datacontract-specification/blob/main/README.md) (raw fetch, versión en `main` al 2026-08-03).
- [`datacontract.schema.json`](https://github.com/datacontract/datacontract-specification/blob/main/datacontract.schema.json) — el JSON Schema formal que valida la sintaxis (usado para confirmar nombres exactos de claves, p. ej. `servicelevels` en minúsculas y sin guión, línea 878 del schema).
- [`examples/orders-latest/datacontract.yaml`](https://github.com/datacontract/datacontract-specification/blob/main/examples/orders-latest/datacontract.yaml) — ejemplo real y completo mantenido por el propio repo, usado para confirmar que la documentación de texto coincide con un YAML válido de verdad (no solo con la tabla de referencia).

### 1.1 Bloque `models.<nombre>.fields.<campo>` — Field Object

Tabla de campos relevantes (cita textual de la [sección "Field Object"](https://github.com/datacontract/datacontract-specification/blob/main/README.md#field-object)):

| Campo | Tipo | Cita textual |
|---|---|---|
| `type` | [Data Type](#tipos-de-dato-soportados) | "The logical data type of the field." |
| `required` | `boolean` | "An indication, if this field must contain a value and may not be null. Default: `false`" |
| `unique` | `boolean` | "An indication, if the value must be unique within the model. Default: `false`" |
| `primaryKey` | `boolean` | "If this field is a primary key. Default: `false`" |
| `references` | `string` | "The reference to a field in another model. E.g. use 'orders.order_id' to reference the order_id field of the model orders. Think of defining a foreign key relationship." |
| `enum` | array de `string` | "A value must be equal to one of the elements in this array value." |
| `format` | `string` | `email`/`uri`/`uuid`, validados contra RFC 5321 §4.1.2, RFC 3986 y RFC 4122 respectivamente. |
| `precision` / `scale` | `number` | Solo para numéricos; default de `precision` es 38, default de `scale` es 0. |
| `pii` / `classification` | `boolean` / `string` | Indicador de dato personal y nivel de sensibilidad (`sensitive`, `restricted`, `internal`, `public` como ejemplos, no enum cerrado). |
| `$ref` | `string` | Referencia a un [Definition Object](https://github.com/datacontract/datacontract-specification/blob/main/README.md#definition-object) reusable — evita duplicar la documentación de un campo común (p. ej. `order_id`) entre modelos. |
| `fields` / `items` / `keys` / `values` | Field Object anidado | Para `object`/`record`/`struct` (`fields`), `array` (`items`), `map` (`keys`/`values`). |
| `quality` | Array de Quality Object | Calidad a nivel de campo — ver §1.2. |

**A nivel de modelo**, `primaryKey` también existe como campo separado del `Model Object` ("Array of `string`... Alternative to field-level `primaryKey`") para claves compuestas.

**Tipos de dato soportados** (cita textual completa de la [sección "Data Types"](https://github.com/datacontract/datacontract-specification/blob/main/README.md#data-types)):

> "Unicode character sequence: `string`, `text`, `varchar`" · "Any numeric type... `number`, `decimal`, `numeric`" · "32-bit signed integer: `int`, `integer`" · "64-bit signed integer: `long`, `bigint`" · `float`, `double`, `boolean`, `timestamp`/`timestamp_tz`, `timestamp_ntz`, `date`, `time`, `array`, `map`, `bytes`, "Complex type: `object`, `record`, `struct`", `variant`, `json`, `null`.

**Corrección importante respecto al draft**: la afirmación "garantías de calidad (columna nunca NULL, columna única)" está — en la especificación real — dividida en dos capas distintas, no unificada bajo "quality":
- **`required` y `unique` son atributos de primera clase del Field Object**, evaluados estructuralmente (forman parte del esquema/tipo del campo), no del bloque `quality`.
- El **bloque `quality`** (§1.2) es para checks adicionales — de negocio, estadísticos, de completitud avanzada — no para NOT NULL/UNIQUE, que ya están cubiertos por `required`/`unique`.

Esto es una distinción real de diseño en la spec, útil para el skill: "esquema + restricciones estructurales" (`required`, `unique`, `primaryKey`, `type`) vs. "calidad" (`quality`) son dos bloques separados, no uno solo.

### 1.2 Bloque `quality` — Quality Object

Cita textual de la definición general:

> "Quality attributes can be: A text in natural language... A predefined metric from the library of commonly used metrics... An individual SQL query that returns a single value that can be compared... Engine-specific types: Pre-defined quality checks, as defined by data quality libraries. Currently, the engines `soda` and `great-expectations` are supported."

Fuente: [sección "Quality Object"](https://github.com/datacontract/datacontract-specification/blob/main/README.md#quality-object).

**Se puede especificar a nivel de campo o de modelo** ("A quality object can be specified on the field level and on the model level. The top-level quality object is deprecated.").

Cuatro variantes documentadas, con su cita exacta de tipo:

| Variante | `type` | Descripción / mecanismo |
|---|---|---|
| **Texto libre** | `text` | Descripción en lenguaje natural, sin validación automática — "It can also be used as a prompt to check the data with an AI engine." |
| **SQL** | `sql` | Query SQL custom que retorna un único número comparado contra un umbral (`mustBe`, `mustBeLessThan`, `mustBeBetween`, etc.). Placeholders `{model}`/`{table}`, `{field}`/`{column}`. Nota de seguridad explícita en la doc: *"Establish a secure development process and use read-only connections, as the misuse of SQL queries can lead to SQL injection attacks."* |
| **Library / Metrics** | `library` (o se omite si `metric` está definido) | Métricas predefinidas agnósticas de motor: `nullValues`, `missingValues`, `invalidValues`, `duplicateValues`, `rowCount` — "These metrics are aligned with ODCS 3.1" (Open Data Contract Standard). |
| **Custom (engine-specific)** | `custom` | Delega en un motor externo vía `engine` + `implementation`. Motores soportados **explícitamente listados**: `soda` y `great-expectations`. |

**Respuesta directa a la pregunta del pedido ("¿referencia SodaCL, Great Expectations, o SQL custom? ¿cómo?")**: **las tres cosas, como variantes independientes y explícitas del mismo objeto `quality`, seleccionadas por el campo `type`/`engine`** — no es una sola de ellas. Ejemplo textual de Soda (nota de estado experimental incluida en la doc):

```yaml
models:
  my_table:
    fields:
      order_id:
        type: string
        quality:
          - type: custom
            engine: soda
            implementation:
              type: no_duplicate_values
```

> Nota textual de la doc sobre Soda: *"Soda Data contract check reference is experimental and may change in the future. Currently only supported by Postgres, Snowflake, and Spark (Databricks)."*

Ejemplo textual de Great Expectations:

```yaml
models:
  my_table:
    quality:
      - type: custom
        engine: great-expectations
        implementation:
          expectation_type: expect_table_row_count_to_be_between
          kwargs:
            min_value: 10000
            max_value: 50000
```

Fuente de ambos ejemplos: [sección "Custom (Engine: Soda)"](https://github.com/datacontract/datacontract-specification/blob/main/README.md#custom-engine-soda) y [sección "Custom (Engine: Great Expectations)"](https://github.com/datacontract/datacontract-specification/blob/main/README.md#custom-engine-great-expectations).

### 1.3 Bloque `servicelevels` (SLA) — Service Levels Object

**Nombre exacto de la clave raíz confirmado contra el JSON Schema formal**: `servicelevels` (todo en minúscula, sin guión ni camelCase) — línea 878 de `datacontract.schema.json`, y confirmado también en el YAML de ejemplo real citado abajo.

Cita textual de la definición general: *"A service level is defined as an agreed-upon, measurable level of performance for provided the data."*

Fuente: [sección "Service Levels Object"](https://github.com/datacontract/datacontract-specification/blob/main/README.md#service-levels-object).

Siete sub-objetos documentados, con los campos reales (no aproximados):

| Sub-objeto | Campos reales | Qué garantiza (cita textual) |
|---|---|---|
| **`availability`** | `description`, `percentage` (string, ej. `99.9%`) | "the promised uptime of the system that provides the data" |
| **`retention`** | `description`, `period` (duración simple o ISO 8601, ej. `P1Y`), `unlimited` (boolean), `timestampField` | "the period how long data will be available" |
| **`latency`** | `description`, `threshold` (duración), `sourceTimestampField`, `processedTimestampField` | "the maximum amount of time from the source to its destination" |
| **`freshness`** | `description`, `threshold` (duración), `timestampField` | "the maximum age of the youngest entry" |
| **`frequency`** | `description`, `type` (`batch`/`micro-batching`/`streaming`/`manual`), `interval`, `cron` | "how often data is updated" |
| **`support`** | `description`, `time` (ej. `24/7`), `responseTime` | "the times when support will be available for contact" |
| **`backup`** | `description`, `interval`, `cron`, `recoveryTime` (RTO), `recoveryPoint` (RPO) | "details about data backup procedures" |

**Respuesta directa a la pregunta del pedido**: el bloque de SLA modela explícitamente **frescura (`freshness`) y disponibilidad (`availability`) como objetos separados**, y además **latencia (`latency`)** como un tercer objeto distinto — los tres nombres que pedía verificar el research existen literalmente como claves documentadas, con semántica no solapada: `freshness` = edad del dato más reciente; `latency` = tiempo desde que el dato se originó en la fuente hasta que está disponible para el consumidor (con campos que apuntan a los timestamps de origen y de procesamiento); `availability` = uptime del sistema que sirve el dato, no del dato en sí.

Ejemplo real completo (recortado a `servicelevels`) del propio repo, `examples/orders-latest/datacontract.yaml`:

```yaml
servicelevels:
  availability:
    description: The server is available during support hours
    percentage: 99.9%
  latency:
    description: Data is available within 25 hours after the order was placed
    threshold: 25h
    sourceTimestampField: orders.order_timestamp
    processedTimestampField: orders.processed_timestamp
  freshness:
    description: The age of the youngest row in a table.
    threshold: 25h
    timestampField: orders.order_timestamp
```

Fuente: [`examples/orders-latest/datacontract.yaml`](https://github.com/datacontract/datacontract-specification/blob/main/examples/orders-latest/datacontract.yaml).

### Veredicto §1

**Confirmado con alta confianza, contra fuente primaria (README + JSON Schema + ejemplo real, los tres coinciden).** El draft puede citar `required`/`unique`/`primaryKey` como atributos de campo, y `quality` (con sus 4 variantes: `text`, `sql`, `library`, `custom` engine `soda`/`great-expectations`) y `servicelevels` (con sus 7 sub-objetos, incluyendo `freshness` y `availability` nombrados exactamente así) como bloques reales y documentados — no aproximaciones. La única corrección necesaria al draft es la que se explica en §1.1: NOT NULL/UNIQUE no viven "dentro de quality", viven en el Field Object.

**No verificado / fuera de alcance**: no se revisaron en profundidad el Lineage Object, el Config Object, ni las particularidades de `additionalFields` a nivel de modelo — mencionados en la tabla del Model Object pero no citados aquí por no ser parte de lo pedido.

---

## 2. Confluent Schema Registry — modos de compatibilidad exactos

Fuente primaria: [Schema Evolution & Compatibility Types — docs.confluent.io](https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html) (fetch directo del HTML, texto extraído verbatim) y [Schema Registry API Reference — docs.confluent.io](https://docs.confluent.io/platform/current/schema-registry/develop/api.html) para el mecanismo de rechazo.

### 2.1 Los 7 modos — nombres exactos confirmados

Confirmado: los 7 nombres del pedido son exactamente los que documenta Confluent — `BACKWARD`, `BACKWARD_TRANSITIVE`, `FORWARD`, `FORWARD_TRANSITIVE`, `FULL`, `FULL_TRANSITIVE`, `NONE`.

| Modo | Cita textual exacta | Qué protege |
|---|---|---|
| **`BACKWARD`** | "consumers using the new schema can read data produced with the last schema... `BACKWARD` compatibility ensures that consumers using the new schema `X` can process data written by producers using schema `X` or `X-1`, but not necessarily `X-2`." | Al consumidor — permite avanzar el consumidor sin romper la lectura de datos ya escritos. Es el **default** de Confluent Schema Registry. |
| **`BACKWARD_TRANSITIVE`** | "`BACKWARD_TRANSITIVE` compatibility ensures that consumers using the new schema `X` can process data written by producers using schema `X`, `X-1`, or `X-2`." | Igual que arriba pero contra **todas** las versiones anteriores, no solo la inmediatamente previa. |
| **`FORWARD`** | "`FORWARD` compatibility means that data produced with a new schema can be read by consumers using the last schema, even though they may not be able to use the full capabilities of the new schema." | Al productor — permite adelantar al productor sin romper a los consumidores que aún no actualizaron. |
| **`FORWARD_TRANSITIVE`** | "data produced using schema `X` can be read by consumers with schema `X`, `X-1`, or `X-2`" | Igual que `FORWARD` pero contra todas las versiones anteriores. |
| **`FULL`** | "`FULL` compatibility means schemas are both backward [and] forward compatible." | Ambos lados, solo contra la última versión. |
| **`FULL_TRANSITIVE`** | "backward and forward compatible between schemas X, X-1, and X-2" | Ambos lados, contra todas las versiones. |
| **`NONE`** | "`NONE` compatibility type means schema compatibility checks are disabled." | Ninguno — el equipo asume manualmente la coordinación (p. ej. migrando a un tópico nuevo). |

Regla general de "transitive" (cita textual): *"If compatibility is configured as transitive, then it checks compatibility of a new schema against all previously registered schemas; otherwise, it checks compatibility of a new schema only against the latest schema."*

**Tabla resumen de cambios permitidos** (Avro/Protobuf), citada tal cual aparece en la doc:

| Cambio permitido | BACKWARD | FORWARD | FULL |
|---|---|---|---|
| Agregar campo opcional | ✔ | ✔ | ✔ |
| Quitar campo opcional | ✔ | ✔ | ✔ |
| Agregar campo requerido | | ✔ | |
| Quitar campo requerido | ✔ | | |
| Ensanchar un tipo escalar (ej. `int`→`long`) | | ✔ | |
| Angostar un tipo escalar | ✔ | | |

**Nota importante no pedida explícitamente pero relevante**: la ampliación/reducción de un tipo escalar (`widen`/`narrow`) **no** es compatible en `FULL` en la tabla oficial actual — solo en uno de los dos lados (`FORWARD` para ensanchar, `BACKWARD` para angostar), dato que contradice una intuición común de que "ensanchar tipos siempre es seguro en ambos sentidos".

### 2.2 Mecanismo real: ¿rechaza o solo advierte?

**Confirmado: el Schema Registry rechaza el registro del esquema, no es una simple advertencia.**

Cita textual de la doc general: *"Schema Registry enforces compatibility by comparing new schema versions against previous versions using configurable compatibility types... Schema Registry checks compatibility before accepting the new version."*

Confirmación a nivel de contrato HTTP real, de la [API Reference](https://docs.confluent.io/platform/current/schema-registry/develop/api.html), endpoint `POST /subjects/(string: subject)/versions` (registrar una nueva versión de esquema bajo un subject):

> Status Codes: **`409 Conflict` – Incompatible schema**

Y sobre el lado del productor: los serializers oficiales registran el esquema automáticamente por defecto al producir. Cita textual de [Kafka SerDes — docs.confluent.io](https://docs.confluent.io/platform/current/schema-registry/fundamentals/serdes-develop/index.html): *"The serializers and Kafka Connect converters for all supported schema formats automatically register schemas by default"*, controlable con la opción `auto.register.schemas`.

**Encadenando ambos hechos documentados** (esto es una inferencia directa de dos citas verbatim, no una tercera cita textual explícita que una las dos cosas en una sola frase): cuando un productor con `auto.register.schemas=true` (el default) intenta producir con un esquema nuevo, el serializer llama primero al registro; si el registro devuelve `409 Conflict`, el serializer no puede completar la serialización y el `send()` del productor falla con una excepción — el mensaje **no llega a producirse**. No es "el registro advierte y el mensaje pasa igual": es un rechazo duro en el momento del registro/producción del esquema nuevo. Una vez que un esquema ya está registrado (tiene ID), los mensajes que usan ese ID no vuelven a chequearse uno por uno — el chequeo de compatibilidad ocurre **al registrar una versión de esquema**, no por mensaje individual.

### Veredicto §2

**Confirmado con alta confianza.** Los 7 nombres, sus definiciones exactas y la tabla de cambios permitidos están verificados contra la doc oficial vigente. El mecanismo de rechazo (HTTP 409 en el registro, no advertencia) también está confirmado con cita textual directa del API reference — el único paso que es inferencia (no una sola cita textual) es unir "el serializer registra automáticamente" + "el registro devuelve 409 si es incompatible" para explicar por qué esto bloquea al productor; ambas piezas están citadas literalmente por separado.

---

## 3. Reglas de evolución de esquema Avro — Schema Resolution

Fuente primaria: [Apache Avro™ 1.12.0 Specification, sección "Schema Resolution"](https://avro.apache.org/docs/1.12.0/specification/#schema-resolution) (fetch directo, texto extraído verbatim del HTML oficial de `avro.apache.org`).

### 3.1 Reglas verbatim, campo por campo

Cita textual completa y literal de las reglas de resolución para records (la sección central del pedido):

> "if both are records: the ordering of fields may be different: fields are matched by name. schemas for fields with the same name in both records are resolved recursively. if the writer's record contains a field with a name not present in the reader's record, the writer's value for that field is ignored. **if the reader's record schema has a field that contains a default value, and writer's schema does not have a field with the same name, then the reader should use the default value from its field. if the reader's record schema has a field with no default value, and writer's schema does not have a field with the same name, an error is signalled.**"

Traducción de la mecánica a la pregunta exacta del pedido:

| Escenario | ¿Seguro? | Condición exacta |
|---|---|---|
| Agregar un campo nuevo al **reader** (schema evoluciona agregando campo) que **tiene default** | **Sí, seguro** | El reader usa el valor `default` cuando lee datos viejos que no tienen ese campo. |
| Agregar un campo nuevo al **reader** que **no tiene default** | **No es seguro — error explícito** | Cita literal: *"an error is signalled"*. |
| Quitar un campo que el **writer** tenía y el **reader** ya no tiene | **Seguro, siempre** (independientemente de si tenía default) | Cita literal: *"the writer's value for that field is ignored"* — el dato no se pierde en el sentido de romper la lectura, simplemente no se usa. |
| Cambiar el **tipo** de un campo | **Solo seguro si el cambio es una "promoción" explícitamente listada**, no un cambio de tipo arbitrario | Ver §3.2. |
| Renombrar un campo o un tipo con nombre (record/enum/fixed) | **No es seguro por default** — Avro empareja campos **solo por nombre exacto** (*"fields are matched by name"*) — a menos que se use `aliases` | Ver §3.3. |

Esto **confirma la afirmación del draft** ("agregar campos opcionales sí, quitar o cambiar tipos no") con una precisión importante que el draft no capturaba: no es "agregar campos opcionales" en general lo que es seguro — es específicamente que **el campo nuevo tenga un `default`** (un campo puede ser "opcional" en un sentido semántico sin tener `default`, y ahí sigue siendo inseguro). Y "quitar campos" **sí es seguro siempre** en Avro (no requiere default para ser removido, solo el reader necesita default si es él quien agrega un campo que el writer no tiene) — el draft simplifica correctamente la intención pero la condición real es más específica: seguridad depende de la dirección del cambio (reader agrega con default = seguro; reader quita campo del writer = siempre seguro por ser ignorado).

### 3.2 Cambios de tipo — "promociones" permitidas (lista cerrada, no cualquier cambio)

Cita textual exacta:

> "the writer's schema may be promoted to the reader's as follows: int is promotable to long, float, or double; long is promotable to float or double; float is promotable to double; string is promotable to bytes; bytes is promotable to string"

Es decir: **no es un "no" absoluto a cambiar tipos** — hay una lista cerrada y específica de promociones seguras (ensanchamiento numérico, e intercambio `string`↔`bytes`). Cualquier cambio de tipo fuera de esa lista (p. ej. `string`→`int`, o angostar `long`→`int`) no está permitido y dispara el error de "no match" ("It is an error if the two schemas do not match").

### 3.3 Renombrado — el mecanismo de `aliases`

Cita textual de la sección "Aliases":

> "Named types and fields may have aliases. An implementation may optionally use aliases to map a writer's schema to the reader's... if data was written as a record with a field named 'x' and is read as a record with a field named 'y' with alias 'x', then the implementation would act as though 'x' were named 'y' when reading."

Es decir: sin `aliases`, renombrar un campo se comporta exactamente como "quitar el campo viejo + agregar un campo nuevo" (con las reglas de §3.1 aplicando a cada lado por separado — el campo nuevo necesita `default` si se quiere que sea seguro leer datos viejos). Con `aliases`, el campo renombrado se resuelve como si nunca hubiera cambiado de nombre.

### 3.4 Enums — regla equivalente con `default` a nivel de símbolo

Dato adicional encontrado, no pedido explícitamente pero directamente relacionado: los enums tienen la misma lógica de "default" que los records. Cita textual: *"if both are enums: if the writer's symbol is not present in the reader's enum and the reader has a default value, then that value is used, otherwise an error is signalled."*

### Veredicto §3

**Confirmado, con la precisión añadida arriba.** La afirmación del draft es directionally correcta (agregar sí, quitar/cambiar tipo no, en general) pero la condición exacta y verificable es: agregar es seguro **si y solo si el campo nuevo tiene `default`**; quitar es seguro **siempre** (el valor simplemente se ignora); cambiar tipo es seguro **solo dentro de la lista cerrada de promociones** (no cualquier cambio); y renombrar es inseguro **a menos que se declare explícitamente vía `aliases`**. Todo esto tiene respaldo de cita textual directa de la especificación oficial, sección `#schema-resolution` y `#aliases` de `avro.apache.org/docs/1.12.0/specification/`.

---

## 4. "El productor se compromete a un contrato y su CI/CD falla si lo rompe" — ¿patrón o implementación real?

**Veredicto adelantado**: **hay implementaciones de referencia reales y documentadas oficialmente por dos proyectos/vendors distintos** — no es solo un patrón de diseño sin anclaje. Se encontraron dos, independientes entre sí (una a nivel de esquema de evento Kafka, otra a nivel de contrato de datos completo).

### 4.1 Confluent — Schema Registry Maven Plugin, goal `test-compatibility`

Fuente: [Schema Registry Maven Plugin — docs.confluent.io](https://docs.confluent.io/platform/current/schema-registry/develop/maven-plugin.html) (fetch directo).

Cita textual de la descripción del goal: *"This goal is used to read schemas from the local file system and test them for compatibility against the Schema Registry servers."* Y explícitamente: *"This goal can be used in a continuous integration pipeline to ensure that schemas in the project are compatible with the schemas in another environment."*

Existe también, desde Confluent Platform 7.2.0, un goal `test-local-compatibility` que compara contra esquemas locales sin necesitar conexión al Schema Registry — pensado para feedback más rápido en desarrollo, antes incluso de llegar a CI.

La doc referencia explícitamente un repo de ejemplo de **GitHub Actions** (`kafka-github-actions`) para integrar este chequeo en un pipeline real.

### 4.2 Data Contract CLI / `datacontract-action` — a nivel de contrato completo

Fuente: [README de `datacontract/datacontract-cli`](https://github.com/datacontract/datacontract-cli/blob/main/README.md) (fetch directo) y [README de `datacontract/datacontract-action`](https://github.com/datacontract/datacontract-action/blob/main/README.md) (fetch directo) — ambos repos bajo la misma organización de GitHub que mantiene la especificación (`datacontract`), por lo que cuentan como fuente cuasi-oficial del ecosistema de la spec, no un proyecto de terceros no relacionado.

Cita textual del README del CLI: *"It can be used as a standalone CLI tool, in a CI/CD pipeline, or directly as a Python library."* El comando `ci` está listado explícitamente en el índice de comandos, y su descripción en [docs.datacontract.com/commands](https://docs.datacontract.com/commands) (fetch directo) es literalmente: *"Run tests for CI/CD pipelines."*

El **GitHub Action oficial** (`datacontract/datacontract-action`, mismo org) provee un workflow listo para usar:

```yaml
- name: Data Contract Tests
  uses: datacontract/datacontract-action@main
  with:
    location: datacontract.yaml
    server: all
    junit-test-report: TEST-datacontract.xml
```

Cita textual de su propósito: *"You can use this GitHub action to enforce data contracts whenever your data contract specification changes and for periodic checks. The action generates a test report in JUnit XML format."* — el reporte JUnit es exactamente el formato que GitHub Actions/Jenkins interpretan nativamente para marcar un step (y por lo tanto el build) como fallido si un test no pasa.

### 4.3 Honestidad epistémica sobre el alcance de esta confirmación

- **Lo que SÍ está confirmado por cita textual directa de fuente oficial**: existen dos herramientas de referencia, mantenidas por los propios dueños de las tecnologías involucradas (Confluent para Schema Registry; la organización `datacontract` para la Data Contract Specification), con instrucciones explícitas y ejemplos de YAML para correr el chequeo de compatibilidad **en CI/CD antes de desplegar** — esto no es un patrón inventado por terceros sin anclaje, es documentación de primera parte con ejemplos ejecutables.
- **Lo que NO está confirmado**: que exista **una única implementación de referencia universal** — no la hay; son dos ecosistemas distintos (mensajería por evento vs. contrato de datos declarativo) con herramientas distintas, cada equipo debe cablear el step en su propio pipeline (no es un gate automático/obligatorio de la infraestructura, es una integración que el equipo adopta). El draft debe presentarlo como "patrón con tooling oficial de referencia en al menos dos ecosistemas", no como "un estándar único".
- **Un intento de fetch directo a `docs.datacontract.com/ci-cd`** (que aparece indexado con el título "Scheduling and CI/CD | Data Contract CLI" en resultados de búsqueda) devolvió `404 Not Found` en dos intentos independientes desde esta sesión — no se pudo verificar su contenido de forma directa, por lo que **no se cita ningún texto de esa URL específica** en este research; lo que sí se cita (`docs.datacontract.com/commands`, README del CLI, README del Action) sí se pudo fetchear con éxito.
- **La Data Contract Specification en sí (el YAML/JSON Schema) no define modos de compatibilidad propios** (a diferencia de Avro/Protobuf/Confluent) — se buscó explícitamente "compat", "breaking" y "semver" en el README completo de la spec y no aparece ninguno de esos términos. El único campo relacionado con versión es `info.version`, documentado como *"REQUIRED. The version of the data contract document (which is distinct from the Data Contract Specification version or the Data Product implementation version)"* — sin formato obligatorio (no se exige semver) ni reglas de evolución backward/forward propias de la spec. Cualquier regla de compatibilidad "hacia atrás" del draft debe entenderse como heredada de la tecnología de esquema subyacente que el contrato referencia (Avro, Protobuf, JSON Schema...) o impuesta por la herramienta que corre el `ci`/`test` (que sí puede clasificar cambios como breaking vía su propio `changelog`/`ci`), no como una regla nativa y formal del documento de contrato en sí.

### Veredicto §4

**Confirmado que es una práctica con implementación de referencia real y documentada oficialmente — no una idea sin anclaje —, pero no es un estándar único ni un gate automático de infraestructura.** Hay al menos dos herramientas de primera parte (Confluent Schema Registry Maven Plugin; Data Contract CLI + `datacontract-action`) con ejemplos ejecutables de CI/CD que bloquean el build/pipeline del productor si el cambio de esquema/contrato es incompatible. El draft puede afirmar esto con confianza citando ambas como ejemplo, evitando la formulación de que existe "una" implementación universal.

---

## Resumen de acciones para contenido futuro del skill

1. **Separar explícitamente "esquema/restricciones estructurales" de "calidad"** en la explicación de la Data Contract Specification: `required`/`unique`/`primaryKey`/`type` son atributos del Field Object; `quality` es un bloque aparte con 4 variantes (`text`, `sql`, `library`/métricas agnósticas alineadas a ODCS 3.1, y `custom` con `engine: soda` o `engine: great-expectations`). El draft actual mezcla ambas capas bajo "garantías de calidad" — vale la pena corregirlo en el contenido final.
2. **`servicelevels`** (nombre exacto de la clave, confirmado contra el JSON Schema) tiene 7 sub-objetos con campos reales — usar `freshness.threshold`/`timestampField` y `availability.percentage` como ejemplos concretos citables, no solo "SLA de frescura y disponibilidad" en abstracto.
3. **Los 7 modos de compatibilidad de Confluent** están confirmados con nombres y semántica exactos — útil aclarar la tabla de "qué cambio es compatible con qué modo" (agregar/quitar campo opcional vs. requerido, ensanchar/angostar tipo), porque no todos los modos tratan igual esos 6 tipos de cambio.
4. **El mecanismo de rechazo es HTTP 409 en el registro del esquema** (no una advertencia silenciosa), y ocurre automáticamente al producir por el comportamiento default de auto-registro de los serializers — dato concreto y citable para reforzar "el CI/CD del productor falla antes de desplegar" con un mecanismo real subyacente.
5. **Las reglas de Avro son más precisas que "agregar sí, quitar no"**: la condición real es "agregar con `default` sí, sin `default` no"; "quitar siempre es seguro" (no depende de si el campo tenía default); cambiar tipo solo dentro de una lista cerrada de promociones; renombrar requiere `aliases` explícitos. Vale la pena que el skill use esta versión más precisa en vez de la simplificación del draft.
6. **La afirmación de CI/CD del productor tiene dos referencias de primera parte citables** (Confluent Maven Plugin; Data Contract CLI + GitHub Action oficial) — pero se debe presentar como "patrón con tooling oficial de al menos dos ecosistemas", no como un estándar universal único, y aclarar que la propia Data Contract Specification no define sus propios modos de compatibilidad (eso lo hereda de la tecnología de esquema subyacente o lo impone la herramienta de CI que se elija).

**Nota de honestidad epistémica global**: no se investigó en este research el Lineage Object, el Config Object, ODCS (Open Data Contract Standard) como especificación en sí más allá de la mención de alineación de métricas, ni el ecosistema de Protobuf/JSON Schema con el mismo nivel de detalle que Avro (solo se usó Protobuf/JSON Schema para la tabla comparativa de Confluent, tal como aparece publicada). Si el skill necesita profundizar en ODCS como estándar competidor/complementario, o en las reglas de evolución específicas de Protobuf, eso requiere una pasada de verificación dedicada adicional.
