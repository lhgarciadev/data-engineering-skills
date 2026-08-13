# Especificación de Diseño: rubric v2 del eval de quality-uplift

## Una escala con recorrido, y una compuerta que lo verifica antes de gastar

## 1. Contexto y objetivo

El rubric actual está saturado. Medido sobre la campaña `results/full/` con el instrumento
`experiments/rubric-headroom.sh` (veredicto **CONFIRMED**, commit `d7ca71c`):

| dimensión (brazo con-skill) | media | SD | % en el máximo |
|---|---|---|---|
| `mechanism` | 1.984 | **0.071** | 95.2% |
| `specific` | 1.968 | **0.142** | 95.2% |
| `actionable` | 1.921 | **0.203** | 85.7% |
| `tradeoff` | 1.492 | 0.647 | 47.6% |

El brazo con-skill promedia **7.365 de 8**, y el **38.1%** de sus respuestas sacan un 8
perfecto. El uplift observado consume el **72.6%** del máximo detectable — o sea que lo
que la métrica llama "mejora" está determinado en gran parte por **cuánto le faltaba al
brazo sin-skill**, no por cuánto aporta la skill.

Con ese techo, cualquier mejora que una skill produzca por encima de "competente" es
invisible: la escala se acaba antes.

**Objetivo:** una escala donde una respuesta competente no toque el máximo, verificada
contra datos reales antes de gastar en una campaña.

### 1.1 Qué NO es este rediseño

- **No arregla los casos.** Dos de las 21 respuestas sin-skill ya sacan 8/8; ahí el uplift
  medible es cero por construcción. Si los siete casos son demasiado fáciles para el
  modelo base, ningún rubric lo compensa. Esa pregunta queda abierta y fuera de alcance.
- **No resuelve el cambio de signo de `specific`** que el diagnóstico anterior dejó sin
  explicar (−0.14 en el brazo con-skill, +0.53 en el sin-skill). Esa dimensión desaparece
  en el v2, así que la pregunta queda **sin respuesta, no resuelta**. Se registra como
  abandonada, no como cerrada.
- **No promete uplift.** Promete que si hay uplift, la escala tendrá recorrido para
  mostrarlo.

## 2. El principio de diseño

`tradeoff` es la única dimensión que discrimina, y se distingue en algo concreto: **pide
contenido de segundo orden.** No "contestá bien", sino "decí qué te cuesta tu propia
respuesta". Una respuesta competente no lo ofrece sola.

Las otras tres miden si contestaste bien, y un modelo base fuerte contesta bien. Dicho de
otro modo: **tres dimensiones medían competencia y una medía diligencia.** Con el modelo
base actual, la competencia es piso y no discrimina.

De ahí la regla que gobierna el v2:

> **El puntaje máximo debe exigir lo que una respuesta competente no produce por defecto.**

### 2.1 Por qué `specific` se reemplaza en vez de endurecerse

`specific` mide la **ausencia de un defecto** — "no tiene relleno genérico". Una ausencia
no tiene techo: no se puede ser más-que-no-genérico. Con un modelo fuerte satura por
construcción, y su SD de 0.142 lo confirma. Endurecerla no es posible sin convertirla en
otra cosa; se reemplaza.

## 3. El rubric v2

Cuatro dimensiones, **0 a 3 cada una, máximo 12**. Los niveles 0–2 conservan la semántica
actual; el 3 es nuevo y exige el segundo orden.

### 3.1 `mechanism`

- **0** — reformula el síntoma.
- **1** — apunta a una causa plausible sin precisarla.
- **2** — nombra el mecanismo específico y por qué produce este síntoma.
- **3** — además, nombra **qué observación distinguiría esa causa de la siguiente más
  probable**.

### 3.2 `actionable`

- **0** — ningún paso.
- **1** — una dirección sin especificidad.
- **2** — un paso concreto, con el comando, setting o forma de código necesarios.
- **3** — además, dice **cómo sabrías que funcionó**: qué medir u observar después.

### 3.3 `assumptions` — reemplaza a `specific`

- **0** — asume en silencio; no declara nada.
- **1** — reconoce incertidumbre en vago ("depende de tu setup").
- **2** — nombra al menos un supuesto concreto sobre el que se apoya la respuesta.
- **3** — además, dice **cómo cambia la respuesta si ese supuesto no vale**.

Se eligió sobre las alternativas por una razón práctica: las siete preguntas del eval
están deliberadamente sub-especificadas, así que **siempre hay un supuesto que nombrar** y
la dimensión aplica a los siete casos sin excepciones. Priorización entre causas quedó
descartada porque no aplica cuando una respuesta nombra correctamente una sola causa, y
puntuar 0 por no priorizar cuando no había nada que priorizar es un defecto de diseño.
Límites de alcance quedó descartada por solaparse con `tradeoff`.

### 3.4 `tradeoff`

Su 0–2 se conserva **intacto** — es la única dimensión que hoy discrimina y no hay razón
para tocarla. Solo gana techo.

- **0** — no menciona costo.
- **1** — menciona una salvedad en vago.
- **2** — nombra un costo, límite o modo de falla concreto de su propia recomendación.
- **3** — además, nombra **bajo qué condición ese costo supera al beneficio**.

### 3.5 Qué se mantiene sin tocar

- Las reglas anti-longitud del prompt: *"Length is not quality"*, no premiar volumen,
  formato ni encabezados.
- La instrucción de ignorar menciones a archivos, código o rutas inaccesibles.
- La instrucción de juzgar solo las dos respuestas presentes, sin especular sobre origen.
- La preferencia `more_useful`: `"A"`, `"B"` o `"tie"`.
- El esquema con `additionalProperties: false`. El total pasa a sumar las cuatro
  dimensiones nombradas del v2.

## 4. La compuerta de no-saturación

**Es la pieza central de esta entrega, y corre antes de cualquier campaña nueva.**

Re-juzgar las **42 respuestas que ya existen** en `results/full/` con el rubric v2 y
verificar que el brazo con-skill ya no satura. Cuesta llamadas de juez pero **cero
generación de respuestas**: los answers están en disco desde la campaña anulada.

### 4.1 Umbral, fijado antes de correr

El v2 **pasa** si, sobre el brazo con-skill:

- **ninguna** de las cuatro dimensiones tiene ≥50% de las respuestas en el máximo (3); **y**
- **las cuatro** tienen SD ≥ 0.4.

El v2 **falla** si alguna de las dos condiciones no se cumple, y falla **explícitamente**:
un rediseño que sigue saturando es un rediseño que no funcionó, y hay que saberlo antes de
pagar una campaña, no después.

La SD de referencia es la de `tradeoff` en el v1 (0.647), la única dimensión que
discriminaba; 0.4 es un piso deliberadamente más laxo que eso, para no exigir que las
cuatro igualen a la mejor.

### 4.2 Qué hacer si falla

No se corre campaña. Se reporta qué dimensiones saturaron y con qué números, y el
rediseño vuelve al tablero. **"El v2 falló" es un desenlace legítimo de esta entrega.**

## 5. Recalibración obligatoria

Las dos compuertas de calibración existentes están calibradas contra la escala 0–8: la de
discriminación observó **8 contra 0/1/0**, y la de sesgo de longitud usa el mismo par.
Ambas se re-corren contra 0–12 y sus umbrales se re-declaran en el README.

Esto no es trámite. Un juez que bajo el rubric nuevo no distingue una respuesta específica
de una genérica, o que se compra con relleno, produce números que parecen autoritativos y
no significan nada — y ese fallo **no sería visible en la tabla de uplift**, solo en estas
dos corridas.

## 6. Restricción heredada, ahora explícita

Cualquier análisis que calcule correlaciones sobre estos datos **debe pre-registrar cómo
trata el clustering por caso** (7 casos × 3 reps). Ninguna de las dos reglas anteriores lo
hizo, y eso infla toda correlación calculada sobre la campaña. Es un defecto de diseño de
los diagnósticos previos, registrado en `experiments/README.md`, y se arrastra a cualquier
medición futura que no lo declare.

## 7. Qué queda sin resolver después de esto

- **El mecanismo detrás de `r = 0.61`.** El v2 cambia el instrumento, así que la
  correlación del v1 no se re-explica: se abandona junto con la dimensión que la producía.
- **Si los siete casos son lo bastante difíciles.** Dos respuestas sin-skill ya sacan
  8/8 en el v1. Bajo el v2 eso podría cambiar, pero no está garantizado y no se mide acá.
- **Si el uplift existe.** Este spec construye un instrumento con recorrido. Lo que ese
  instrumento vaya a mostrar es una pregunta aparte.

## 8. Próximos pasos

Plan de implementación vía `superpowers:writing-plans`.
