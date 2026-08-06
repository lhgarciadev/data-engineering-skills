# Especificación de Diseño: eval de uplift de calidad

## Segundo eje de validación de la suite `dataforge`

## 1. Contexto y objetivo

La suite tiene dos ejes de validación independientes. El primero, la verificación de
research bajo `docs/superpowers/research/`, comprueba que el **contenido** de cada skill
es cierto contra fuentes primarias. El segundo, la matriz de triggering bajo
`tests/triggering/`, comprueba que la skill **correcta se carga** ante un prompt realista.

Ninguno de los dos responde la pregunta que decide si la suite se queda instalada:
**¿la respuesta es mejor con la skill que sin ella?**

Son preguntas independientes. Una skill puede rutear 5/5 y cargar contenido cierto pero
genérico, que el modelo ya producía sin ayuda. En ese caso el ruteo es impecable, el
aporte es cero, y se están pagando entre 1.2k y 3.7k tokens por invocación a cambio de
nada. Este eval mide ese aporte.

Objetivo concreto: producir una tabla de uplift **por skill** que permita decidir skill
por skill, porque no hay razón para esperar que el resultado sea uniforme entre dominios.

## 2. Alcance y fronteras

### 2.1 Lo que este eval mide

Utilidad aparente de la respuesta para un ingeniero de datos senior, juzgada a ciegas
contra una rúbrica de dominio.

### 2.2 Lo que este eval NO mide

- **Corrección factual.** Un juez LLM mide utilidad percibida, no verdad. La corrección
  sigue cubierta por las verificaciones contra fuentes primarias. Los dos ejes son
  complementarios; ninguno sustituye al otro.
- **Fidelidad de transferencia.** No se mide si la respuesta repite los conceptos que la
  skill documenta. Esa métrica es circular: premia a la skill por decir lo que dice,
  incluso cuando ese contenido no aporta.
- **Ruteo.** Ya cubierto por `tests/triggering/`. Este eval lo *asume* y lo verifica como
  condición de validez (§4.2), no como resultado.

## 3. Casos

Un caso representativo por skill de dominio, reutilizando prompts ya ejercitados por la
matriz de triggering para no introducir variables nuevas.

| ID | Skill | Prompt (resumen) |
|----|-------|------------------|
| P1 | `python` | ETL en Python se come la RAM con un CSV de 40GB |
| P2 | `sql` | query Postgres con tres window functions tarda 8 min |
| A4 | `spark` | job sobre 2 mil millones de filas se pega en una sola tarea |
| P4 | `modeling` | grano de la fact table: línea de pedido o pedido completo |
| A2 | `pipelines` | relanzar el proceso produjo registros duplicados |
| A1 | `quality` | los números no cuadran con el origen y nadie se dio cuenta |
| P7 | `project-structure` | paquete nuevo de ingesta: Poetry o uv, y cómo organizar |

El orquestador `data-engineering` queda fuera: su valor es enrutar a otras skills, no
producir contenido, así que la rúbrica de §5 no le aplica.

## 4. Arquitectura

### 4.1 Brazos

Idénticos a la ablación ya validada en `tests/triggering/`:

- **CON**: suite habilitado, tal como está instalado.
- **SIN**: `--settings '{"enabledPlugins":{"dataforge@skills-dir":false}}'`.

El override desactiva **solo** esta suite. Todo lo demás — `CLAUDE.md`, superpowers,
hooks — queda igual, de modo que los brazos difieren en exactamente una variable.

Ambos brazos heredan las tres guardas del harness de triggering: `stdin` en `/dev/null`,
sandbox `mktemp -d` fuera del repo, y sin servidores MCP.

### 4.2 Condición de validez

En el brazo CON, la respuesta se acepta **solo si la skill esperada disparó**, verificado
chain-aware sobre los eventos `Skill` del log — el mismo criterio que `rescore.sh`.

Un sample donde la skill no disparó no es una medición de la skill: es ruido comparado
contra ruido. Esos samples se descartan y se vuelven a tirar, hasta un máximo de 3
reintentos por sample. Si un caso no logra 3 samples válidos, se reporta como
**no medible** en lugar de rellenarse con samples inválidos.

Al brazo SIN no se le aplica **gate de ruteo**: su comportamiento natural — incluyendo que
una skill de proceso de superpowers responda por él — es precisamente el contrafáctico
que interesa medir, y descartar una respuesta por no haber cargado una skill destruiría
esa medición.

Lo que sí aplica a **ambos** brazos es un piso de no-vacío. Una respuesta de 0 bytes no es
un contrafáctico: es un fallo de infraestructura — un `timeout` que mató el proceso, o un
log sin evento `result`. Aceptarla produciría una muestra indistinguible de una válida que
el análisis promediaría. Los samples vacíos se descartan y se reintentan bajo el mismo
límite de 3 intentos, y quedan registrados en `discards.tsv` con `EMPTY` en la columna de
cadena.

### 4.3 Repeticiones

n=3 por brazo por caso. 7 casos × 2 brazos × 3 = **42 sesiones de respuesta**, seriales,
con la misma guarda de memoria del harness de triggering (≥1200 MB de holgura antes de
cada probe; la VM tiene 6 GB y ya sufrió OOM con concurrencia).

Modelo de respuesta: `opus`, el de uso diario.

## 5. Rúbrica

Cuatro dimensiones, 0–2 cada una, máximo 8 por respuesta:

| Dimensión | Pregunta |
|-----------|----------|
| mecanismo | ¿identifica la causa real, en vez de describir el síntoma? |
| accionable | ¿da un siguiente paso concreto y ejecutable? |
| específico | ¿evita el consejo genérico tipo "revisá la configuración"? |
| trade-off | ¿advierte el costo o el riesgo de lo que propone? |

## 6. Juicio

- El juez recibe las dos respuestas **sin metadata**, y no se le menciona que existan
  skills ni que haya dos condiciones.
- Califica **ambas** respuestas en la rúbrica y declara cuál le sirve más a un senior.
- **3 reps por par**, con el orden de presentación fijado así: rep 1 con CON primero,
  rep 2 con SIN primero, rep 3 con CON primero. Dos órdenes sobre tres reps permite
  detectar sesgo de posición sin dejar ningún par con un solo orden.
- Modelo de juicio: `sonnet`. Distinto del modelo que respondió, para evitar
  auto-preferencia.

### 6.1 Métrica primaria

La métrica que decide es el **delta de rúbrica** (score CON − score SIN), promediado sobre
reps. La preferencia declarada por el juez es una señal **secundaria**: sirve para detectar
incoherencia — un juez que puntúa más alto una respuesta pero prefiere la otra está siendo
inconsistente, y eso invalida ese par. No se promedian las dos métricas entre sí.

### 6.2 Control de sesgo de longitud

El brazo CON tiende a producir respuestas más largas, y los jueces LLM favorecen la
verbosidad. Dos medidas, en ese orden de confianza:

1. Se instruye al juez que la longitud no es calidad.
2. **Se mide el largo de cada respuesta y se reporta la correlación entre score y
   longitud.** Esta es la medida que cuenta: si el uplift correlaciona con verbosidad, el
   resultado queda invalidado y el diseño del juicio se rehace.

No se confía en la instrucción sin la verificación. Es exactamente el error que ya se
cometió una vez en este repo al aceptar el autoreporte de un modelo sobre su propio
contexto.

## 7. Salida

`tests/quality-uplift/results/<timestamp>/`:

- Score por caso, brazo y rep, más el delta por skill.
- Correlación score↔longitud sobre todos los pares.
- Tasa de descarte por §4.2, por caso.
- Concordancia entre reps de juicio, como medida de confiabilidad del juez.

El digest para commitear va a `tests/quality-uplift/baselines/`, siguiendo la convención
de `tests/triggering/`: los logs crudos quedan gitignorados por volumen y son
regenerables.

### 7.1 Lectura del resultado

El uplift se cruza con el costo ya medido por `claude plugin details` (1.2k–3.7k tokens
por invocación). "Vale la pena" es una razón, no un delta suelto: una skill con uplift
pequeño y 3.7k por invocación no gana su costo.

## 8. Fuera de alcance de esta fase

- El orquestador `data-engineering` (§3).
- `streaming-data-engineering` e `iac-cloud-data-engineering`, que aún no existen.
- Más de un caso por skill. Con un caso por dominio, un uplift alto no distingue "la
  skill sirve" de "ese caso sirve". Si el resultado justifica profundizar, se amplía a
  3 casos en las skills donde la decisión quede ajustada.

## 9. Próximos pasos

Plan de implementación vía `superpowers:writing-plans`.
