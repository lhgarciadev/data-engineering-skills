# Baseline de ruteo — entrega de `iac-cloud-data-engineering`

**Fecha:** 2026-08-08
**Modelo:** opus · **Reps:** 3 · **Concurrencia:** `-j 1` (serial)
**Comando:** `./run-matrix.sh -m opus -a with -r 3 -j 1 -o results/iac-delivery`
más `./run-matrix.sh -m opus -a with -r 3 -j 1 -f matrix-adversarial.tsv -o results/iac-delivery`
**Puntuado con:** `rescore.sh`, nunca con el verdict en vivo.

## Alcance medido

**40 casos** — 25 en `matrix.tsv` y 15 en `matrix-adversarial.tsv` — × 3 reps = **120 corridas**.
Las 120 se verificaron presentes en disco *antes* de puntuar. Este digest cubre esos 40 casos
y ningún otro.

**Resultado: 39 PASS, 1 FLAKY, 0 FAIL.**

## Incidente de la campaña, registrado

La primera invocación devolvió **exit code 0 habiendo corrido solo la matriz principal**.
`run-matrix.sh` toma `matrix.tsv` por defecto y solo `-f` lo cambia; el paso 4 del plan
llamaba al runner una vez y le pasaba las dos matrices a `rescore.sh`. Los 15 casos
adversariales —incluido `A9`, el que valida la entrega— nunca corrieron.

Se detectó contando los archivos producidos (101 donde debían ser 120), no leyendo la
salida. **Un exit code 0 no es evidencia de completitud.** El plan quedó corregido con
las dos invocaciones y con la instrucción de contar antes de puntuar.

## Ground truth cambiado

`A9` pasó de `gap-iac` / `NONE` a `positive` / `iac-cloud-data-engineering`. El cambio se
decidió **antes de correr nada**, porque el mundo cambió: una skill que no existía ahora
existe. Eso es categóricamente distinto de editar una expectativa después de ver un
resultado que no gustó. Su comportamiento previo a la entrega está en los baselines
anteriores de este directorio.

## Casos nuevos

| Caso | Qué prueba | Verdict |
|---|---|---|
| `A9` | Terraform para warehouse Snowflake con roles y warehouses de cómputo | 3/3 PASS |
| `P10` | Positivo directo: serverless vs cluster aprovisionado | 3/3 PASS |
| `D9` | Discriminador contra `streaming`: MSK vs Kinesis vs autogestionado | 3/3 PASS |
| `D10` | **Espejo**: nombra cluster, pregunta tuning → debe quedarse en `spark` | 3/3 PASS |
| `D11` | Spark en Kubernetes (añadido por un Minor del review de Task 8) | 3/3 PASS |
| `A14` | Sin jerga: "la factura del almacén se triplicó" | 3/3 PASS |
| `A15` | Negativo nuevo: feature store para ML, fuera de la suite | 3/3 PASS |

`D10` importa tanto como los positivos: una frontera que solo funciona en una dirección no
es una frontera. Que un caso que nombra un cluster se quede en `spark` es la evidencia de
que la skill nueva no actúa como imán.

## `D11` refuta una hipótesis abierta

El review de Task 8 marcó que la palabra "Kubernetes" no aparece léxicamente en `SKILL.md`
—la exclusión de alcance está en sustancia pero sin ancla— y planteó que eso podía impedir
el ruteo. **Refutado por medición:** 3/3 en posición 1. El caso se escribió neutral, con la
expectativa derivada de la frontera declarada y no de una predicción.

## `A11` decidido con los reps en la mano

`A11` ("exponer el warehouse como API REST") esperaba `NONE|pipelines-architecture`. Se
dejó **intacto a propósito** hasta tener datos. Rutea a `pipelines-architecture` 3/3, nunca
a `iac-cloud`. **Su conjunto esperado NO se ensancha.** Ensancharlo antes habría garantizado
un pase y no habría probado nada.

## El único FLAKY: `D5`, y no es regresión

`D5` (escritura idempotente a S3 dentro de un task, espera `python-data-engineering`) dio
**1/3** en la campaña. Se re-corrió con 7 reps adicionales: **6/7**.

**Combinado: 7/10 ≈ 70%.** El baseline previo en opus lo registra en **2/3 ≈ 67%**, con una
nota que pedía explícitamente más reps —cosa que nunca se hizo—. Las dos tasas son
indistinguibles a este n. Además rutea a `pipelines-architecture-data-engineering`, no a la
skill nueva: **`iac-cloud` no lo está capturando.**

No se atribuye a esta entrega. `python-data-engineering` no fue tocado por ninguna de las
diez ediciones.

## Conjunto de regresión

Las cuatro descriptions editadas y sus casos, todos sosteniendo su verdict previo:

- `spark` → `P3`, `A4`, `A5`, `D10` — todos 3/3
- `modeling` → `P4`, `D7`, `A3`, `A7` — todos 3/3
- `streaming` → `P9`, `D6`, `D8`, `A8`, `A13` — todos 3/3
- orquestador `data-engineering` → `P8`, `A10` — ambos 3/3

`A2`, históricamente FLAKY (~50% sobre 10 reps, y ya flaky antes de que existiera
streaming), dio **3/3** en esta campaña. Se registra el dato sin sobreinterpretarlo: 3/3
sobre un caso de ~50% no es evidencia de mejora.

## Salida verbatim de `rescore.sh`

```
ID	EXPECTED	HITS	VERDICT	POSITIONS	CHAINS
A1	quality-data-engineering	3/3	PASS	1,1,1	quality-data-engineering quality-data-engineering quality-data-engineering
A10	data-engineering	3/3	PASS	2,2,1	superpowers:brainstorming>data-engineering superpowers:brainstorming>data-engineering data-engineering
A11	NONE|pipelines-architecture-data-engineering	3/3	PASS	2,2,2	superpowers:brainstorming>pipelines-architecture-data-engineering superpowers:brainstorming>pipelines-architecture-data-engineering superpowers:brainstorming>pipelines-architecture-data-engineering
A12	NONE	3/3	PASS	-,-,-	NONE NONE superpowers:brainstorming
A13	streaming-data-engineering	3/3	PASS	2,2,2	superpowers:systematic-debugging>streaming-data-engineering superpowers:systematic-debugging>streaming-data-engineering superpowers:systematic-debugging>streaming-data-engineering
A14	iac-cloud-data-engineering	3/3	PASS	1,1,1	iac-cloud-data-engineering iac-cloud-data-engineering>superpowers:systematic-debugging iac-cloud-data-engineering
A15	NONE	3/3	PASS	-,-,-	superpowers:brainstorming superpowers:brainstorming superpowers:brainstorming
A2	pipelines-architecture-data-engineering	3/3	PASS	2,2,2	superpowers:systematic-debugging>pipelines-architecture-data-engineering superpowers:systematic-debugging>pipelines-architecture-data-engineering superpowers:systematic-debugging>pipelines-architecture-data-engineering
A3	modeling-data-engineering	3/3	PASS	1,1,1	modeling-data-engineering>superpowers:brainstorming modeling-data-engineering modeling-data-engineering
A4	spark-data-engineering	3/3	PASS	1,1,1	spark-data-engineering>superpowers:systematic-debugging spark-data-engineering>superpowers:systematic-debugging spark-data-engineering>superpowers:systematic-debugging
A5	spark-data-engineering|sql-data-engineering	3/3	PASS	1,1,1	spark-data-engineering spark-data-engineering spark-data-engineering
A6	python-data-engineering|sql-data-engineering	3/3	PASS	1,1,1	python-data-engineering python-data-engineering>sql-data-engineering python-data-engineering>sql-data-engineering
A7	modeling-data-engineering|pipelines-architecture-data-engineering	3/3	PASS	1,1,1	modeling-data-engineering>pipelines-architecture-data-engineering modeling-data-engineering>pipelines-architecture-data-engineering modeling-data-engineering
A8	streaming-data-engineering	3/3	PASS	1,1,1	streaming-data-engineering streaming-data-engineering streaming-data-engineering
A9	iac-cloud-data-engineering	3/3	PASS	2,2,2	superpowers:brainstorming>iac-cloud-data-engineering superpowers:brainstorming>iac-cloud-data-engineering superpowers:brainstorming>iac-cloud-data-engineering
D1	pipelines-architecture-data-engineering	3/3	PASS	1,1,1	pipelines-architecture-data-engineering pipelines-architecture-data-engineering pipelines-architecture-data-engineering
D10	spark-data-engineering	3/3	PASS	1,1,1	spark-data-engineering spark-data-engineering spark-data-engineering
D11	iac-cloud-data-engineering	3/3	PASS	1,1,1	iac-cloud-data-engineering iac-cloud-data-engineering iac-cloud-data-engineering
D2	quality-data-engineering|project-structure-data-engineering	3/3	PASS	1,1,1	quality-data-engineering quality-data-engineering quality-data-engineering
D3	sql-data-engineering	3/3	PASS	1,1,1	sql-data-engineering sql-data-engineering sql-data-engineering
D4	python-data-engineering	3/3	PASS	1,1,1	python-data-engineering python-data-engineering python-data-engineering
D5	python-data-engineering	1/3	FLAKY	x,x,1	pipelines-architecture-data-engineering pipelines-architecture-data-engineering python-data-engineering>pipelines-architecture-data-engineering
D6	streaming-data-engineering	3/3	PASS	2,2,1	superpowers:systematic-debugging>streaming-data-engineering superpowers:systematic-debugging>streaming-data-engineering streaming-data-engineering>superpowers:systematic-debugging
D7	modeling-data-engineering	3/3	PASS	1,1,1	modeling-data-engineering modeling-data-engineering modeling-data-engineering
D8	streaming-data-engineering	3/3	PASS	1,1,1	streaming-data-engineering streaming-data-engineering streaming-data-engineering
D9	iac-cloud-data-engineering	3/3	PASS	1,1,1	iac-cloud-data-engineering iac-cloud-data-engineering iac-cloud-data-engineering
N1	NONE	3/3	PASS	-,-,-	NONE NONE NONE
N2	NONE	3/3	PASS	-,-,-	NONE superpowers:brainstorming superpowers:brainstorming
N3	NONE	3/3	PASS	-,-,-	NONE NONE NONE
N4	NONE	3/3	PASS	-,-,-	NONE NONE NONE
P1	python-data-engineering	3/3	PASS	1,1,1	python-data-engineering python-data-engineering>superpowers:systematic-debugging python-data-engineering
P10	iac-cloud-data-engineering	3/3	PASS	1,1,1	iac-cloud-data-engineering iac-cloud-data-engineering iac-cloud-data-engineering>superpowers:brainstorming
P2	sql-data-engineering	3/3	PASS	1,1,1	sql-data-engineering sql-data-engineering sql-data-engineering
P3	spark-data-engineering	3/3	PASS	1,1,1	spark-data-engineering spark-data-engineering spark-data-engineering>superpowers:systematic-debugging
P4	modeling-data-engineering	3/3	PASS	1,1,1	modeling-data-engineering modeling-data-engineering modeling-data-engineering
P5	pipelines-architecture-data-engineering	3/3	PASS	1,1,1	pipelines-architecture-data-engineering pipelines-architecture-data-engineering pipelines-architecture-data-engineering
P6	quality-data-engineering	3/3	PASS	1,1,1	quality-data-engineering quality-data-engineering quality-data-engineering
P7	project-structure-data-engineering	3/3	PASS	1,1,1	project-structure-data-engineering project-structure-data-engineering project-structure-data-engineering
P8	data-engineering	3/3	PASS	2,2,2	superpowers:brainstorming>data-engineering superpowers:brainstorming>data-engineering superpowers:brainstorming>data-engineering
P9	streaming-data-engineering	3/3	PASS	1,1,1	streaming-data-engineering streaming-data-engineering streaming-data-engineering
```
