# Baseline de ruteo — verificación post-edición del 2026-08-20

**Fecha:** 2026-08-20
**Alcance:** los **7 casos** cuya skill esperada recibió ediciones el 2026-08-20
(`python`, `spark`, `quality`). Los otros 33 casos de la matriz **no se midieron**: no
recibieron ediciones, y ninguna `description` de frontmatter cambió en toda la entrega
(verificado con `git diff 1635ce1..e5e6815 -- 'skills/*/SKILL.md'`, que sólo toca cuerpos).
**Puntuado con:** `rescore.sh`, nunca con el verdict en vivo. Las 21 corridas se
verificaron presentes en disco y coincidiendo con `run-reps` antes de puntuar.

## Por qué esta verificación era necesaria, y por qué es acotada

Las ediciones del 2026-08-20 son compuertas de decisión **dentro** de skills existentes,
no skills nuevas. Como el ruteo lo decide la `description` y ninguna cambió, el ruteo no
podía cambiar por la vía del disparo. Quedaba **un** mecanismo real: la compuerta de
cluster tax que se agregó a `spark-data-engineering/SKILL.md` **apunta a
`python-data-engineering`**, así que un caso de Spark podía encadenar una segunda
invocación. No ocurrió — D10 y P3 mantienen cadena corta en los dos modelos.

## Opus, 3 reps, serial — el modelo de uso diario y el de las baselines previas

**Comando:** `./run-matrix.sh -f <subset> -m opus -a with -r 3 -j 1 -o results/postedit-opus-with`

```
ID	EXPECTED	HITS	VERDICT	POSITIONS	CHAINS
D10	spark-data-engineering	3/3	PASS	1,1,1	spark-data-engineering spark-data-engineering spark-data-engineering
D2	quality-data-engineering|project-structure-data-engineering	3/3	PASS	1,1,1	quality-data-engineering quality-data-engineering quality-data-engineering
D4	python-data-engineering	3/3	PASS	1,1,1	python-data-engineering python-data-engineering python-data-engineering
D5	python-data-engineering	3/3	PASS	1,1,1	python-data-engineering python-data-engineering python-data-engineering
P1	python-data-engineering	3/3	PASS	1,1,1	python-data-engineering python-data-engineering python-data-engineering
P3	spark-data-engineering	3/3	PASS	1,1,1	spark-data-engineering>superpowers:systematic-debugging spark-data-engineering>superpowers:systematic-debugging spark-data-engineering
P6	quality-data-engineering	3/3	PASS	1,1,1	quality-data-engineering quality-data-engineering quality-data-engineering
```

### Contra `2026-08-08-iac-routing.md`, misma condición

| Caso | 2026-08-08 | 2026-08-20 | |
|---|---|---|---|
| D2 | 3/3 PASS `1,1,1` | 3/3 PASS `1,1,1` | igual |
| D4 | 3/3 PASS `1,1,1` | 3/3 PASS `1,1,1` | igual |
| D10 | 3/3 PASS `1,1,1` | 3/3 PASS `1,1,1` | igual |
| P1 | 3/3 PASS `1,1,1` | 3/3 PASS `1,1,1` | igual |
| P3 | 3/3 PASS `1,1,1` | 3/3 PASS `1,1,1` | igual |
| P6 | 3/3 PASS `1,1,1` | 3/3 PASS `1,1,1` | igual |
| D5 | 1/3 FLAKY `x,x,1` | 3/3 PASS `1,1,1` | mejor |

**Cero regresiones.** Sobre D5: **no se atribuye a estas ediciones.** No hay mecanismo —
ninguna `description` cambió, y el cuerpo de una skill se lee después de que disparó. Un
caso que la baseline previa ya registró como `FLAKY` moviéndose con n=3 es varianza entre
reps, y se registra como tal. Si alguien quiere afirmar que mejoró, hace falta n mayor.

## Haiku, 3 reps — primer punto de dato en el modelo débil, SIN baseline previa

Esta corrida se hizo primero y **no sirvió para su propósito**: las tres baselines del
repo (`RED-crowd-out.md`, `GREEN-crowd-out.md`, `2026-08-08-iac-routing.md`) son de opus,
así que un resultado de haiku no se compara contra nada. Se deja registrado porque es el
único dato de haiku que existe, **no** como evidencia de una regresión.

```
ID	EXPECTED	HITS	VERDICT	POSITIONS	CHAINS
D10	spark-data-engineering	3/3	PASS	1,1,1	spark-data-engineering spark-data-engineering spark-data-engineering
D2	quality-data-engineering|project-structure-data-engineering	0/3	FAIL	x,x,x	NONE NONE NONE
D4	python-data-engineering	0/3	FAIL	x,x,x	NONE quality-data-engineering quality-data-engineering
D5	python-data-engineering	2/3	FLAKY	1,1,x	python-data-engineering python-data-engineering pipelines-architecture-data-engineering
P1	python-data-engineering	2/3	FLAKY	1,1,x	python-data-engineering python-data-engineering superpowers:systematic-debugging
P3	spark-data-engineering	0/3	FAIL	x,x,x	superpowers:systematic-debugging superpowers:systematic-debugging superpowers:systematic-debugging
P6	quality-data-engineering	0/3	FAIL	x,x,x	pipelines-architecture-data-engineering pipelines-architecture-data-engineering NONE
```

Leer esto contra la regla que el README ya fija: *"a weak-model failure is not evidence of
a description problem: 6 of haiku's 11 failures passed cleanly on sonnet. Always re-run
failures on a stronger model — and on the model actually in daily use — before concluding
anything about the wording."* Los cuatro `FAIL` de haiku pasan 3/3 en opus, que es
exactamente el patrón que esa regla describe.

Lo que sí queda como pregunta abierta, y es un hueco de instrumentación: **no existe
baseline de haiku para ningún caso**, así que nadie puede detectar drift en el modelo
débil. Este digest es el primer punto de dato. Un segundo, en las mismas condiciones,
convertiría la pregunta en una medición.

## Lo que este digest NO cubre

- 33 de los 40 casos de la matriz completa (25 en `matrix.tsv` + 15 en
  `matrix-adversarial.tsv`). No recibieron ediciones y ninguna `description` cambió, pero
  no se midieron y este digest no habla por ellos.
- Si la compuerta de decisión **se leyó** una vez que la skill disparó. La matriz mide qué
  skill dispara, no si el lector llegó al párrafo nuevo. No hay instrumento para eso y no
  se construyó uno.
