# Especificación de Diseño: Skill `iac-cloud-data-engineering`

## Novena y última skill de dominio de la suite `dataforge`

## 1. Contexto y objetivo

Esta skill cierra la suite en 9/9 y convierte en frontera real los diez punteros que hoy
declinan hacia un dominio que no existe. Es la única skill de la suite que se escribe
sabiendo exactamente qué le van a preguntar: las otras ocho ya declararon por escrito qué
le ceden.

**El encuadre que organiza la skill entera** — equivalente al "grano" en modelado, al
"shuffle" en Spark o a "acotado vs. no acotado" en streaming:

> **La infraestructura de datos es infraestructura con estado.**

La infraestructura de aplicación es ganado: se destruye y se recrea. Un warehouse, un
topic con retención, un state backend, un bucket con historia no. De esa única propiedad
se deriva todo lo demás: por qué la elección de servicio es una puerta de un solo sentido,
por qué el costo de migración es un criterio *de selección* y no una consecuencia
posterior, por qué `destroy`/`recreate` no está disponible, y por qué el drift sobre un
recurso con estado es un animal distinto al drift sobre un balanceador.

Ese encuadre es deliberado y se explica en §7: convierte un dominio que se lee como "de
juicio" en uno con mecanismo, que es la diferencia medida entre las skills que aportan
valor y las que no.

Objetivo: misma forma que las ocho skills entregadas — `SKILL.md` como router con
overview, when-to-use, quick reference y common mistakes, y el peso en `references/`.

## 2. Alcance y fronteras

### 2.1 La regla de frontera, ya decidida

Se hereda literal del spec de streaming §2.1, sin renegociar:

> *Si se decide en código, es de la skill de dominio; si se decide en Terraform, es de
> `iac-cloud-data-engineering`.*

| A la skill de dominio | A `iac-cloud` |
|---|---|
| clave de partición, grano, shuffle, watermark | MSK vs. Kinesis vs. autogestionado |
| consumer groups y rebalance | sizing del cluster, unidad de escalado |
| trade de `acks`/ISR — es durabilidad | IAM, KMS, red, VPC |
| diseño del esquema dimensional | hosting del almacén que lo contiene |
| tuning de memoria de executors | tipo de nodo y forma de cobro del cluster |

### 2.2 Los diez forward-pointers a cerrar

Al entregar esta skill dejan de ser texto muerto. Ubicaciones exactas, verificadas contra
el árbol en `432790b`:

| Skill | Ubicación | Qué cede |
|---|---|---|
| `spark-data-engineering` | `SKILL.md:3` (description) | deployment e infraestructura de clusters Spark |
| `spark-data-engineering` | `SKILL.md:21` (when-to-use) | ídem, en el cuerpo |
| `modeling-data-engineering` | `SKILL.md:3` (description) | infraestructura y hosting de NoSQL |
| `modeling-data-engineering` | `SKILL.md:23` (when-to-use) | ídem, en el cuerpo |
| `streaming-data-engineering` | `SKILL.md:3` (description) | provisión, sizing y elección de servicio gestionado |
| `streaming-data-engineering` | `SKILL.md:22` (when-to-use) | ídem, en el cuerpo |
| `pipelines-architecture-data-engineering` | `references/serving-pipeline-output.md:27` | hosting e infraestructura de una API de serving |
| `data-engineering` (orquestador) | `SKILL.md:3` (description) | el dominio IaC/cloud como tal |
| `data-engineering` (orquestador) | `SKILL.md:16` (when-to-use) | ídem |
| `data-engineering` (orquestador) | `SKILL.md:22` (paso 3, síntesis) | ídem |

**Cuatro son descriptions** — `spark`, `modeling`, `streaming` y el orquestador — y seis
son cuerpo. Esa distinción decide qué se re-mide y por qué (§6). La description de
`pipelines` no se toca: su puntero sobre hosting de APIs apunta a su propio reference file,
no a una skill inexistente.

**Cómo se llegó a diez, y por qué importa.** La primera enumeración devolvió seis porque el
patrón de grep era `"no skill in this suite yet"`. Las líneas de `spark:21` y `modeling:23`
usan otra redacción — *"an IaC/cloud skill is planned but does not exist yet"* — y quedaron
fuera del conteo. El patrón determinó el resultado, que es exactamente el artefacto de
medición contra el que advierte el proceso de este repo. El plan de implementación no debe
confiar en esta tabla: **enumera de nuevo con al menos dos patrones independientes** —
`iac`, `terraform`, `infrastructure as code` por un lado; `no skill`, `does not exist`,
`not yet`, `suite yet` por otro — y falla si el conteo no da diez.

**Dos menciones que NO se editan**, verificadas y decididas: `data-engineering/SKILL.md:14`
usa Terraform dentro de un ejemplo de petición multi-dominio y sigue siendo válido —
gana un dominio al que rutear, no pierde sentido. `data-engineering/SKILL.md:36` es una
fila de common mistakes sobre skills no instaladas en general, no sobre IaC, y sobrevive
intacta.

**Consecuencia sobre el orquestador.** Sus tres menciones dicen hoy que el dominio existe
pero no tiene skill y hay que cubrirlo directamente. Las tres se reemplazan por la skill
real, y su lista de dominios pasa de ocho a nueve. Es un cambio de description y por lo
tanto se re-mide (§6).

### 2.3 Fronteras que se negocian sin invadir

| Tema | Dueño | Qué hace `iac-cloud` |
|---|---|---|
| clave de partición, orden, offsets | `streaming` | referencia el modelo del log; decide el servicio que lo aloja |
| shuffle, AQE, memoria de executors | `spark` | decide la forma del cluster, no el tuning del job |
| esquema dimensional, grano, SCD | `modeling` | decide el almacén, no el modelo dentro |
| capa de orquestación y DAGs | `pipelines` | decide dónde corre el orquestador, no cómo se diseña |
| contratos de datos y compatibilidad | `quality` | referencia el contrato; no lo re-enseña |
| empaquetado y `pyproject.toml` | `project-structure` | frontera limpia; no se toca |
| particionado y clustering de tablas | `sql` / `modeling` | los referencia como la palanca que mueve el costo por GB escaneado |

### 2.4 Dos líneas opinadas, decididas

Ambas se aprobaron explícitamente antes de escribir este spec.

**El DDL de tablas y esquemas está fuera de IaC.** El recurso que Terraform administra es
el almacén, no las tablas dentro de él. Crear tablas pertenece a migraciones o a dbt —
territorio de `pipelines` y `sql`. La skill enseña esta línea como criterio, no la asume:
es una de las confusiones más caras del dominio, porque poner DDL en Terraform hace que un
`destroy` accidental sea un evento de pérdida de datos en vez de un evento de
reaprovisionamiento.

**Kubernetes está fuera de alcance.** La orquestación de contenedores es ingeniería de
plataforma, no de datos, y el modelo base ya la cubre. Solo sobrevive la rebanada
específica de datos — por qué Spark-on-K8s es una decisión de cómputo con las mismas
preguntas del §4.2, y por qué un almacén con estado sobre un orquestador de contenedores
hereda los problemas del §4.1 — y vive dentro de `choosing-a-managed-service.md`.

### 2.5 Qué no cubre esta skill

- Tutorial de sintaxis de Terraform o HCL. El modelo base ya es fuerte ahí y una skill que
  lo repita no aporta uplift (§7).
- CI/CD genérico, Kubernetes, redes corporativas o gobierno de nube ajeno a datos.
- Precios, límites de servicio y tipos de instancia concretos (§3).
- Tuning de motores, que pertenece a cada skill de dominio.

## 3. Regla de agnosticismo y decaimiento

Esta skill tiene un problema que ninguna otra de la suite tiene: **sus hechos se pudren
más rápido de lo que se pueden verificar.** Los nombres de servicio, los límites y los
precios cambian en meses. El repo sostiene que una afirmación que no se puede sostener
contra fuente no se escribe; aplicado aquí, eso obliga a una regla explícita.

1. **Los ejes son la carga.** Costo operativo, granularidad de escalado, acoplamiento al
   proveedor, forma del throughput, modelo de recuperación. Los ejes son durables porque
   son propiedades del problema, no del catálogo de un proveedor.
2. **Los servicios se nombran como instancias de un eje**, nunca como el contenido. AWS,
   Azure y GCP se mapean en tablas comparativas — precedente medido: `sql-data-engineering`
   nombra seis motores sin volverse un manual de ninguno.
3. **Prohibición dura: ni una cifra.** Ningún límite, precio, tamaño de instancia, ni
   número de particiones máximo. El costo se enseña como **forma** — por hora
   aprovisionada, por request, por GB escaneado, por GB almacenado, por egress — nunca
   como figura.
4. Toda afirmación de capacidad de un servicio pasa por §5 antes de escribirse.

## 4. Estructura de archivos

Seis reference files (1.6k–3.5k palabras cada uno, escala de `modeling-data-engineering`)
más `SKILL.md`.

### 4.1 `statefulness-and-the-one-way-door.md`

El encuadre. Ganado vs. mascota aplicado a datos, y por qué la analogía se rompe justo
donde importa. La escalera de reversibilidad: qué decisiones se deshacen barato (motor de
cómputo), cuáles caro (formato y servicio de almacenamiento), cuáles casi nunca (el
almacén con años de historia). El costo de migración como criterio de selección y no como
consecuencia. Gravedad de datos y egress como el mecanismo concreto del lock-in — no una
metáfora, una línea en la factura.

### 4.2 `choosing-a-managed-service.md`

Los ejes, que son el contenido durable: carga operativa, granularidad de escalado,
acoplamiento, forma del throughput, modelo de fallo y recuperación, encaje con el
ecosistema existente. El trade gestionado vs. autogestionado planteado como transferencia
de trabajo, no como ahorro. Serverless vs. aprovisionado y qué pregunta lo decide.
Contiene la comparación trabajada que `streaming` cede — MSK vs. Kinesis vs.
autogestionado, con sus equivalentes en Azure y GCP — y la rebanada de datos de
Spark-on-K8s (§2.4).

### 4.3 `sizing-and-the-cost-model.md`

El costo como forma, cruzado contra la forma de la carga: estable, con picos,
exploratoria. Por qué el cobro por GB escaneado convierte un `SELECT *` en una decisión de
arquitectura y conecta con particionado y clustering en `sql`. Sizing como función del
recurso que es cuello de botella, no del tamaño del dato. Por qué aprovisionar para el
pico y por qué no.

### 4.4 `identity-network-and-encryption.md`

Identidad de servicio frente a identidad de usuario, que es la distinción que rompe a los
pipelines: un pipeline no tiene a nadie sentado delante. Least privilege sobre almacenes de
datos y por qué el permiso de lectura masiva es la superficie real. Colocación de red y
endpoints privados. Cifrado en reposo y en tránsito, y qué cubre realmente "cifrado por
defecto". Secretos para pipelines, y el state de Terraform como secreto en sí mismo.

### 4.5 `iac-for-stateful-resources.md`

El único contenido de práctica IaC, y solo donde el estado lo cambia. Protección contra
destrucción y qué bloquea de verdad. Qué **no** pertenece a IaC (§2.4). Drift sobre
recursos que escalan solos, donde la infraestructura cambia legítimamente sin que nadie
toque el código. Paridad de entornos cuando no se puede clonar producción — el problema
que no tiene equivalente en infraestructura de aplicación. Secretos y state.

### 4.6 `platform-archetypes.md`

El archivo que absorbe los diez punteros. Cinco arquetipos — plataforma de streaming,
cómputo Spark/distribuido, warehouse-lakehouse, almacén NoSQL de serving, hosting de API
de serving — cada uno con la misma estructura: qué decide la skill de dominio, qué se
decide aquí, y cuál es la puerta de un solo sentido del arquetipo.

### 4.7 `SKILL.md`

Router de ~1.0k–1.3k palabras: overview con el encuadre de §1, when-to-use con los "not
for" que devuelven a cada skill de dominio, quick reference de seis filas hacia los
references, y common mistakes.

## 5. Plan de verificación de contenido

Siete pasadas contra fuente primaria, siguiendo las 35 verificaciones ya en
`docs/superpowers/research/`. Ninguna afirmación de capacidad se escribe sin verdicto.

1. **`lifecycle.prevent_destroy` de Terraform** — qué bloquea exactamente, si cubre el
   reemplazo además del destroy, y qué lo elude.
2. **State de Terraform como dato sensible** — la afirmación de que puede contener
   secretos en claro, contra la documentación oficial.
3. **Formas de cobro** — verificar que la *forma* es la declarada (por byte escaneado, por
   segundo de cómputo, por request) para los almacenes que se nombren. Sin cifras (§3).
4. **Servicios de streaming gestionados** — que la unidad de escalado que se afirme exista
   como se describe en MSK, Kinesis, Event Hubs y Pub/Sub.
5. **Cómputo Spark gestionado** — que los nombres de servicio sigan vigentes y que las
   variantes serverless existan como se afirme.
6. **Identidad de servicio** — el modelo de asunción de rol para cargas de trabajo en los
   tres proveedores, con su terminología correcta.
7. **Cifrado gestionado por el cliente** — qué cubre y qué no el cifrado por defecto, y la
   terminología por proveedor.

**Candidatas a drift, a verificar antes de escribirse:** el estado de Azure Synapse frente
a Fabric; la vigencia de los nombres de las variantes serverless; y la licencia de
Terraform frente a OpenTofu, que cambió y que afecta a cómo se nombra la herramienta en
una skill agnóstica.

**Regla de revisión heredada.** El hallazgo más caro de la entrega de streaming fue que
seis autores distintos escribieron una afirmación sobre un motor que sonaba cierta y no
tenía verdicto detrás, y dos eran falsas. Ese tipo de afirmación no *se siente* como
afirmación y esquiva el self-review. Aquí el riesgo es mayor porque toda la skill nombra
servicios. **Todo prompt de revisión de esta entrega incluye: grep del corpus de research
por cada nombre de servicio mencionado, y verdicto explícito o borrado.**

## 6. Plan de verificación de comportamiento

La skill no se considera entregada hasta que rutee, medido con `tests/triggering/`,
puntuado con `rescore.sh` y nunca con el verdict en vivo.

**Alcance: matriz completa.** 34 casos existentes — 21 en `matrix.tsv` y 13 en
`matrix-adversarial.tsv` — más los casos nuevos, 3 reps, opus. La justificación no es el
precedente sino un argumento: una novena entrada cambia el listado de skills que *toda*
decisión de ruteo lee, así que la perturbación no se limita a las cuatro descriptions que
se editan. Una medición dirigida dejaría el 19/19 de streaming apoyado sobre un listado
que ya no existe.

**A9 cambia de ground truth.** Hoy es `gap-iac` y espera `NONE`; su prompt pide Terraform
para un warehouse de Snowflake con roles y warehouses de cómputo. Al existir esta skill su
`EXPECTED` pasa a `iac-cloud-data-engineering`. Es el caso que valida la entrega entera.

**A11 se decide contra la medición, no por aserción.** "Exponer el warehouse como API
REST" espera hoy `NONE|pipelines-architecture-data-engineering`. La decisión
arquitectónica de servir por API sigue siendo de `pipelines`; el hosting pasa a ser de
esta skill. Si el conjunto esperado debe ensancharse se decide con los reps en la mano.

**Casos nuevos**, mínimo: un positivo directo, un discriminador contra `streaming`
(elección de servicio gestionado frente a clave de partición), un discriminador contra
`spark` (forma del cluster frente a tuning del job), y un adversarial sin jargon que no
diga "Terraform", "IaC" ni "infraestructura". A9 deja de cubrir el hueco `gap-*` al
convertirse en positivo, así que se añade al menos un negativo nuevo que siga estando
fuera de la suite.

**Restricciones heredadas.** A2 sigue siendo FLAKY al ~50% y no se arregla aquí; cualquier
arreglo va en un cuerpo o en la redacción del caso, **nunca en una description**, porque el
19/19 se midió contra ellas. Reps, no muestra única: un evento de 1 en 5 es invisible a
n=1.

## 7. Riesgo conocido: es un dominio de juicio

La única señal que sobrevivió a la campaña de calidad anulada es que `modeling` — dominio
donde el modelo base ya es fuerte — puntuó delta *negativo*, mientras `spark` puntuó +3.0.
IaC/cloud se lee como dominio de juicio, no de mecanismo, y por lo tanto hereda ese riesgo.

Las tres mitigaciones son de diseño, no de redacción:

1. El encuadre de statefulness (§1) convierte el juicio en mecanismo: no "depende", sino
   "esta es la propiedad de la que depende".
2. La prohibición de tutorial de Terraform (§2.5) evita competir con lo que el modelo base
   ya hace bien, que es la hipótesis más plausible del delta negativo.
3. Los ejes (§4.2) dan estructura verificable donde el modelo base da prosa.

**Lo que no se puede hacer:** medir el uplift. El instrumento está VOID a r=0.61 y su
causa sigue sin resolverse. Esta entrega **no reclama uplift medido** y no debe presentarse
como si lo tuviera. La evidencia de esta skill es de contenido (§5) y de ruteo (§6),
punto.

## 8. Próximos pasos

Plan de implementación vía `superpowers:writing-plans`.
