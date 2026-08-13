# Especificación de Diseño: diagnóstico de la correlación longitud–puntaje

## Descomposición por dimensión sobre datos ya existentes

## 1. Contexto y objetivo

La campaña de quality-uplift publicada está **VOID**. Una de las dos condiciones que la
anulan es una correlación de Pearson agrupada `r = 0.61` entre los bytes de la respuesta y
el total del rubric, por encima del umbral de 0.5 documentado en
`tests/quality-uplift/README.md`.

**La causa de esa correlación sigue sin establecerse**, y ese es el problema que este
diagnóstico ataca. El estado exacto, según `tests/quality-uplift/experiments/README.md`:

- La etiqueta "sesgo de longitud del juez" está marcada como **no soportada**: el
  experimento `length-causality.sh` comprimió respuestas preservando cada afirmación
  técnica y las puntuó, y 8 de 12 no se movieron — incluidas las más largas. El efecto es
  demasiado chico para producir `r = 0.61`.
- La lectura opuesta —"la correlación es señal, no sesgo"— **tampoco** está soportada:
  `P2.with.rep3` pasó de 694 a 465 bytes y de 7 a 5 puntos, con cada afirmación técnica
  preservada y verificado leyendo ambas versiones.
- Por lo tanto el mecanismo detrás de `r = 0.61` está **sin resolver**, y el propio doc
  prohíbe reescribir la racionalización de §6.2 sobre la fuerza de ese experimento.

**Consecuencia sobre la suite.** Mientras esto no se resuelva, ninguna de las nueve skills
puede reclamar uplift de calidad medido. La suite tiene evidencia en dos ejes —contenido
verificado y ruteo medido— y ninguna en el tercero.

**Objetivo de esta entrega: diagnosticar, no rediseñar.** Establecer qué produce la
correlación antes de tocar el juez, el rubric o la métrica. Rediseñar sobre un diagnóstico
que no cerró es cómo se reemplaza una explicación no verificada por otra.

## 2. Alcance

### 2.1 Qué incluye

Un instrumento de **solo lectura** que corre sobre los datos ya pagados de la campaña
`tests/quality-uplift/results/full/`: 42 respuestas (7 casos × 2 brazos × 3 reps) y 63
filas de juicio. Costo de probes: **cero**.

### 2.2 Qué NO incluye

- Ningún cambio al rubric, al juez, al protocolo de juzgamiento ni a la métrica primaria.
- Ninguna campaña nueva.
- Ningún cambio al umbral de void. El umbral se queda donde está hasta que haya
  diagnóstico: una métrica cuya relación con la longitud no se entiende no se publica.

### 2.3 Por qué el diagnóstico va primero

El experimento anterior falló en un modo específico y documentado: leyó su resultado hacia
una conclusión prolija después de verlo. La primera lectura del run n=6 afirmó que los
casos −2 eran respuestas cortas donde comprimir había cortado sustancia de verdad; leer
`P2.with.rep3` la falsificó. Ese antecedente es el que obliga a pre-registrar la regla de
lectura (§4) antes de correr nada.

## 3. La hipótesis, y por qué es testeable

### 3.1 Aditividad por cobertura

El rubric (`tests/quality-uplift/rubric.md`) pide **cuatro elementos de contenido
distintos**, de 0 a 2 cada uno:

| Dimensión | Qué exige |
|---|---|
| `mechanism` | nombrar la causa específica y por qué produce el síntoma |
| `actionable` | un paso concreto, con el comando, setting o forma de código |
| `specific` | que **no** haya relleno genérico |
| `tradeoff` | un costo, límite o modo de falla concreto de la propia recomendación |

Una respuesta que contiene los cuatro es **mecánicamente más larga** que una que contiene
dos: cubrir cuatro cosas cuesta palabras. Bajo esta hipótesis, `r = 0.61` no es sesgo del
juez ni ruido — es el rubric siendo aditivo por cobertura, con la longitud actuando como
proxy de cuántos elementos están presentes.

La hipótesis explica los tres hechos que hoy no encajan entre sí:

1. **8 de 12 compresiones no movieron el puntaje** — se cortó prosa, no elementos.
2. **"Sesgo de longitud del juez" quedó refutado** — el juez no premia palabras, premia
   elementos presentes.
3. **`P2.with.rep3` cayó −2** — comprimir pudo fundir el `tradeoff` en una subordinada, y
   un tradeoff fundido se lee como "caveat vago" (1) en vez de "costo concreto" (2). La
   afirmación técnica sobrevive; la **distinguibilidad del elemento**, no.

El punto 3 es una explicación posible del caso, no un hallazgo. Este diagnóstico no lo
verifica y no debe presentarse como si lo hiciera.

### 3.2 La predicción que discrimina

Las dos hipótesis predicen **signos opuestos para la misma dimensión**, `specific`:

- **Si el juez premia longitud**, las cuatro dimensiones suben con los bytes. `specific`
  incluida: un juez que recompensa volumen no tiene razón para penalizar al largo.
- **Si el rubric es aditivo por cobertura**, `mechanism`, `actionable` y `tradeoff` suben
  —son contenido que se agrega— pero `specific` queda **plana o negativa**: una respuesta
  más larga tiene más lugar para relleno genérico, y `specific` castiga exactamente eso.

Ese contraste es lo que faltaba. Todo lo medido hasta ahora era compatible con las dos
hipótesis a la vez; esto no puede serlo.

## 4. Regla de lectura, pre-registrada

**Se escribe antes de correr el instrumento y no se modifica después de ver los números.**

| Resultado observado | Lectura |
|---|---|
| Las cuatro dimensiones correlacionan positivo con los bytes, `specific` incluida | Apoya sesgo de longitud del juez |
| `mechanism`/`actionable`/`tradeoff` positivas y `specific` plana o negativa | Apoya aditividad por cobertura |
| Patrón mixto, o inconsistente entre brazos | **No resuelve.** Se reporta como tal |

"Plana" se define antes de mirar: `|r| < 0.2` para `specific`. Un valor entre 0.2 y el
umbral de las otras dimensiones cae en la tercera fila, no en la segunda.

**"No resuelve" es un desenlace legítimo de esta entrega**, no un fracaso. El fracaso
sería declarar resuelto lo que no lo está, que es precisamente el defecto que este repo
existe para atrapar.

## 5. El instrumento

`tests/quality-uplift/experiments/dimension-length-decomposition.sh`, de solo lectura.

Une `results/full/judgments.jsonl` con los bytes que los archivos `.meta` ya registran por
`(id, arm, rep)`, y reporta:

- Pearson `r` entre bytes y **cada una de las cuatro dimensiones por separado**.
- Pearson `r` entre bytes y el total, para reproducir el `0.61` publicado.
- Todo lo anterior **por brazo y agrupado**, con la `n` de cada correlación.

Salida cruda a `experiments/results/`, más una sección nueva en `experiments/README.md`
que registre la pre-registración de §4, los números y el veredicto.

## 6. Guardas

Las cuatro salen de defectos que este harness ya tuvo, no de prudencia genérica.

1. **Reproducir primero el `r = 0.61` del total.** Si no reproduce, el join está mal y
   nada aguas abajo vale. Es la única forma de saber que el instrumento mide lo que se
   cree. Un desvío se reporta y detiene el análisis.
2. **Usar `judgments.jsonl`, nunca `judgments.contaminated-2runs.jsonl`.** El archivo
   contaminado vive en el mismo directorio con nombre parecido.
3. **Chequear duplicados de `(id, rep, judge_rep)` antes de correlacionar.** El README
   registra que más de un escritor tocó ese archivo y que cuál fila sobrevivió por slot es
   artefacto del orden de escritura. Un duplicado detiene el análisis.
4. **Reportar por brazo, no solo agrupado.** El propio README advierte que un `r` agrupado
   es alto tanto cuando el juez premia longitud como cuando el brazo con-skill es
   simplemente más largo *y* mejor, y que solo la descomposición por brazo los separa.

También se reporta el conteo de filas de juicio efectivamente usadas contra las 63
esperadas. Una fila descartada cambia sobre cuántos datos se calculó cada correlación.

## 7. Qué NO establece este diagnóstico

- **Es observacional.** Aun con un corte limpio en `specific`, vuelve una hipótesis mucho
  más plausible; no prueba causalidad. El doc de resultados debe decirlo en esas palabras.
- **n = 42 respuestas sobre 7 casos.** Es una dirección, no un resultado — el mismo caveat
  que `length-causality.sh` lleva escrito.
- **No mide uplift.** No dice si alguna skill mejora las respuestas; dice qué produce la
  correlación que impide publicar esa medición.
- **No verifica la explicación de `P2.with.rep3`** de §3.1. Esa sigue siendo una
  conjetura sobre un caso.

## 8. Próximos pasos

Plan de implementación vía `superpowers:writing-plans`. El rediseño del juzgamiento —si
hace falta— es una entrega aparte, decidida con este diagnóstico en la mano.
