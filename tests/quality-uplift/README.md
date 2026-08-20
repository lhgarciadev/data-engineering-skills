# Quality-uplift eval

Behavioral test for **skill value**, not skill discovery. Research verification (under
`docs/superpowers/research/`) checks whether a skill's *content* is true. The triggering
matrix (`tests/triggering/`) checks whether the right skill *fires*. Neither answers the
question that decides whether the suite earns its place: **is the answer better with the
skill than without it?**

Full design rationale: `docs/superpowers/specs/2026-08-05-quality-uplift-eval-design.md`.
Implementation plan: `docs/superpowers/plans/2026-08-05-quality-uplift-eval-implementation.md`.

## Estado al 2026-08-20: eval CERRADO

Este eval queda **cerrado** sin haber producido evidencia de uplift, y por decisión
explícita: no hay v3 del rubric ni campaña de casos nuevos. Abajo está el registro de
por qué se cierra, qué quedó probado, y qué preguntas quedan sin responder a propósito.

### Por qué se cierra

Tres entregas y ninguna produjo evidencia de uplift. El rubric v1 **saturó** (brazo
con-skill 7.37 de 8). El diagnóstico de la correlación longitud↔puntaje devolvió **"no
resuelve"**. El rubric v2 —cuatro dimensiones de 0 a 3, `specific` reemplazado por
`assumptions`— **falló su propia compuerta pre-registrada**.

El dato más útil salió del brazo **sin** skill: cuanto más competente ya es el modelo
base en una dimensión, menos varianza produce el rubric ahí, monótono en los cuatro
puntos. El caso P4 puntúa **más alto sin la skill que con ella**. Eso apunta a los casos
y a las dimensiones elegidas, no al rubric — y ningún rubric crea varianza donde no hay
diferencia que medir. Números, veredictos y el umbral pre-registrado están en
`experiments/README.md`.

Hacer que este eval responda su pregunta exige casos nuevos y más difíciles —una
campaña paga— más un rubric recortado a las dimensiones que discriminan y el backlog de
abajo. Eso es construir un instrumento de investigación para medir una suite de
documentación: el costo no lo justifica mientras la suite misma sea el producto. Tres
entregas de pulido de instrumento contra lo que los datos ahora señalan como un problema
de dificultad de casos es la forma de un proyecto que se volvió su propio objetivo.

### Las cuatro decisiones abiertas, cerradas acá

**1. Un v3 del rubric — descartado.** El brazo sin-skill muestra que a mayor competencia
base del modelo en una dimensión, menos varianza produce el rubric ahí, monótono en los
cuatro puntos. Ningún rubric crea varianza donde no hay diferencia que medir, así que la
reescritura no ataca la causa.

**2. La medición de dificultad de casos — respondida por el registro; su instrumento NO
se construyó.** El umbral pre-registrado (un caso no puede medir si su brazo sin-skill
promedia ≥ 9.0 de 12) se aplica leyendo la tabla por caso de `experiments/README.md`: P4
queda descartado con 10.33 y el segundo más fácil es P7 con 7.89, lejos del umbral. El
script que derivara eso de `results/full-v2-judgments/` de forma reproducible se decidió
**no escribir**: su única función era alimentar un v3, y el v3 no va. Si el eval se
reabre, ese script es el primer paso y sigue costando cero llamadas de juez.

**3. `results/` versionado — no, y el harness no es auditable desde afuera.** Se acepta
por escrito: `results/` está gitignoreado y las 42 respuestas de la campaña v1 existen
sólo en la máquina donde se corrieron. Ninguna guarda de reproducción de este harness es
re-corrible desde un clone limpio. Versionar esos datos para volverlo auditable no se
hace, porque nadie va a auditar un eval cerrado. Quien lo reabra hereda esta limitación
como condición de entrada, no como defecto a descubrir.

**4. La fuga del sandbox — confound documentado, sin re-medición.** Las 10 de 42
respuestas que mencionan su propio `/tmp/qprobe-XXXXXX` (detalle en *Known deferred
issues*) siguen entrando al promedio sin marca. No se descartan como muestras inválidas
ni se hace invisible el sandbox: ambas opciones sólo cambian números que ya no alimentan
ninguna decisión. Si se corre una campaña nueva, hacer el sandbox invisible al modelo es
condición previa, no un arreglo posterior.

### Lo que el eval sí dejó probado

Las dos compuertas de calibración funcionan bajo la escala 0–12: el juez discrimina 11
contra 1 y no se compra con relleno. Los instrumentos son agnósticos de versión y
reproducen sus salidas v1 byte a byte. Y hay una clase de defecto documentada que este
harness produce por diseño (ver *La forma de defecto* en `experiments/README.md`).

## What this measures, and what it does not

**Measures:** apparent usefulness of the answer to a senior data engineer, judged blind
against a four-dimension rubric (mechanism, actionable, assumptions, tradeoff — see
`rubric.md`; `assumptions` reemplazó a `specific` en el v2), by an LLM judge that never
sees which arm produced which answer. El modelo se resuelve desde el alias `sonnet`, que
**no** es un ID pineado — cada corrida registra el ID que efectivamente sirvió en
`model.txt` dentro de su directorio (en las corridas del 2026-08-13: `claude-sonnet-5`).

**Does not measure:**

- **Factual correctness.** An LLM judge measures perceived usefulness, not truth. A
  fluent, well-organized, *wrong* answer can still score high. Correctness stays covered
  by the research verifications under `docs/superpowers/research/`. The two axes are
  complementary — neither substitutes for the other, and a high uplift number here says
  nothing about whether the skill's claims hold up against primary sources.
- **Transfer fidelity.** Whether the answer repeats concepts the skill's own docs state.
  That metric would be circular: it rewards a skill for saying what it says, even where
  saying it adds nothing.
- **Routing.** Already covered by `tests/triggering/`. This eval *assumes* correct
  routing and enforces it as a validity condition on the with-arm (below), not as a
  result to report.

A number in `baselines/` answers "did a senior engineer-judge find the with-arm answer
more useful, on this one prompt, on this one day, against this model version" — nothing
broader. Treat it as one data point, not a certification.

## Contamination guards

Same three guards validated in `tests/triggering/`, carried over because the failure
modes are identical:

1. **`stdin` is `/dev/null`.** `claude -p` also reads stdin; without the redirect a
   probe launched from a `while read` loop over `cases.tsv` inherits the open file and
   the remaining rows leak into the prompt.
2. **Every session — answer probes *and* judge calls — runs from a fresh `mktemp -d`
   outside the repo, deleted afterwards.** Claude Code injects the cwd and its contents
   into session context; running from inside this repo would let an answer probe see the
   skill sources it is being tested against, and would let the judge see the run
   directory whose filenames carry the arm labels (see the blinding guard below).
3. **No MCP servers, memory-gated serial execution.** `--strict-mcp-config` keeps the
   session minimal; `generate-answers.sh` waits for ≥1200 MB of `MemAvailable` before
   every probe. This is a 6 GB WSL2 box that has OOM'd mid-campaign before under
   concurrency — do not raise concurrency to speed this up.

A fourth guard specific to this eval, not present in triggering: **the judge is blind,
and blinded structurally rather than by instruction**. What the judge's prompt says is
only half of it; the other half is what the judge can reach.

- **Prompt.** It receives the two answers labeled only `A`/`B`, is never told a skill or
  ablation is involved, and scores under a fixed rubric. `judge-pairs.sh` maps `A`/`B`
  back to `with`/`without` only after scoring.
- **Tools.** `--disallowedTools "Bash" "Read" "Write" "Edit" "Task" "Glob" "Grep"`. The
  judge has no way to read a file, list a directory, or grep for one.
- **Cwd.** A fresh `mktemp -d` outside the repo (guard 2). Run from the operator's
  `tests/quality-uplift` instead, a judge with `Read`/`Glob`/`Grep` could reach
  `cases.tsv` (which names the expected skill per case), `full-answers.log` (`ok
  A2.with.rep1 chain=…`), and `results/` — where every filename says `with` or
  `without`.
- **Skills.** `--settings '{"enabledPlugins":{"dataforge@skills-dir":false}}'`, so the
  judge cannot load the skills it is scoring.
- **`stdin` is the one deliberate exception to guard 1.** The rubric and both answers
  arrive on the judge's stdin; that is why it needs nothing from the filesystem.

No judge session log is kept, so after the fact there is no way to prove a judge did or
did not look at something it had access to. That is precisely why the access is removed
rather than trusted: only the invocation is auditable. `baselines/2026-08-05-uplift.md`
records the campaign that ran before this hardening existed.

**5. Exactly one writer per results directory, enforced by a lock in the scripts.**
Both `generate-answers.sh` and `judge-pairs.sh` take `mkdir "$RUN/.lock"` before writing
anything. `mkdir` fails atomically if the directory exists, so the second invocation
refuses to start, exits 69, and writes nothing; the holder releases the lock from a
`trap … EXIT`. A stale lock after a kill -9 is removed by hand: `rmdir <run>/.lock`.

This used to be an operator instruction, which is how the incident below happened.
During the 2026-08-05 campaign, `judge-pairs.sh` was started a second time against the
same `results/full/` while the first invocation was still running. Both processes
appended to the same `judgments.jsonl` concurrently, producing 62 duplicate
`(id, rep, judge_rep)` rows out of 125 total lines for what should have been 63 —
harmless in isolation (each row was a real judge call) but fatal to the "Judge
agreement" section, which depends on exactly one row per order-schedule slot. See
`baselines/2026-08-05-uplift.md` for the full incident and how the contaminated file
was preserved rather than silently deduplicated.

`analyze.sh` now also detects the damage after the fact: it rejects a second row for an
already-seen `(id, rep, judge_rep)` triplet, reports `duplicate (id,rep,judge_rep) rows
rejected: N`, and refuses to present the uplift table as a measurement when N is
non-zero. The lock prevents it; the report no longer certifies it as clean if it happens
anyway.

The old operator check still works as a secondary confirmation that nothing is running:

```bash
ps -eo pid,cmd | grep -E "generate-answers\.sh|judge-pairs\.sh" | grep -v grep
```

Do not use `pgrep -f` for this check — `pgrep -f` matches against the full command
line, including of the very shell invoking the check, and reports a false positive on
itself.

## The two calibration gates

Before spending anything on a real campaign, the judge itself has to be shown to work.
Both gates live in `results/calib/` and `results/calib-len/` and must be re-verified —
by reading the actual `judgments.jsonl`, not by re-running the gate and trusting a
summary — before any campaign is judged credible:

- **Discrimination gate** (`results/calib/`, re-verified in `results/calib-v2/`): given
  one deliberately specific answer and one deliberately generic one, does the judge pick
  the specific one, consistently, with a real score gap? Passing bar: 3/3 judge reps
  prefer the specific answer, with scores that actually separate them (observed: 11 vs 1
  on the 0–12 scale, 3/3 reps).
- **Length-bias gate** (`results/calib-len/`, re-verified in `results/calib-len-v2/`):
  given the same specific/generic pair, but with the *generic* one padded to be the
  *longer* file, does the judge still pick the specific one? The specific answer is the
  *shorter* file in this gate (the `without` arm); the padded generic answer is the
  `with` arm — inverted from the discrimination gate above, so read the winning arm
  carefully. Passing bar: 3/3 judge reps still prefer the specific answer despite it
  being shorter (observed: specific answer wins 3/3, 11 vs 1 on the 0–12 scale, despite
  being 848 bytes against a 1494-byte padded opponent).

**If either gate does not hold, the campaign is not run.** A judge that cannot tell a
specific answer from a generic one, or that can be bought with padding, produces numbers
that look authoritative and mean nothing — the failure would not be visible in the
uplift table itself, only in these two calibration runs.

## The validity gate on the with-arm

A with-arm sample is only accepted if the case's expected skill actually fired somewhere
in the invocation chain, checked the same chain-aware way `tests/triggering/rescore.sh`
checks it — not just as the first tool call. A sample where the skill never loaded is
not a measurement of the skill; it's noise, and averaging it in would understate the
very thing being measured. Up to 3 attempts per sample; a case that never gets 3 valid
with-arm samples is reported as **not measurable**, not filled in with an invalid one.

The without-arm has no such gate. Its natural behavior — including a superpowers process
skill answering instead of the suite — *is* the counterfactual being measured, and
rejecting a without-arm sample for not loading a suite skill would destroy the
measurement.

Both arms share a non-emptiness floor: a 0-byte answer (timeout kill, or a log with no
`result` event) is an infrastructure failure, not a real counterfactual, and is
discarded and retried under the same 3-attempt cap.

## What voids a campaign

State these plainly in every report of the numbers, not just here:

- Either calibration gate failing.
- Pearson r above 0.5 between answer length and rubric total (`analyze.sh`'s "Score vs
  length" section). Read the per-arm lines too, not just the pooled one: a pooled r is
  high both when the judge rewards length and when the with-arm is simply longer *and*
  better, and only the per-arm decomposition separates them.

  **What a high r means is unresolved.** The original rationale was that correlation
  surviving within an arm is judge length-bias. `experiments/length-causality.sh` tested
  that directly — compress an answer, preserving every technical claim, and score both
  versions — and did not support it: 8 of 12 scored identically, including the longest
  answers. But it did not establish the opposite either, since one verified case scored
  two points lower for being shorter with its substance intact. The threshold still voids
  a campaign, because a metric whose relationship to length is not understood is not a
  metric you publish. Do not cite "judge length-bias" as the established cause. See
  `experiments/README.md`.
- A case whose with-arm never passed the validity gate in 3 attempts — report as **not
  measurable**, never filled in.
- Fewer than 3 accepted samples per arm for a case.
- Any duplicate `(id, rep, judge_rep)` rows rejected by `analyze.sh`. More than one
  writer touched `judgments.jsonl`, so which competing row survived per slot is an
  artifact of write order — re-judge into a clean directory instead of publishing it.
- A non-zero extra-key count. A score object carrying a key outside the four rubric
  dimensions means the judge did not answer the rubric it was given. Totals now sum the
  four named dimensions explicitly, so an extra key can no longer inflate a score — but a
  judge that invents a dimension is not scoring reliably, and its other rows are not
  trustworthy either. The schema sets `additionalProperties: false`, so reaching a
  non-zero count means the schema was not enforced, which is itself the finding.

`analyze.sh` also reports, and a digest must carry forward without editing:
judge-coherence failures (a row that scores one answer higher but prefers the other),
judge failures (empty/unparseable judge replies — a dropped row means a case averaged
over fewer reps than the table implies), the per-case judgment count against the count
expected from the data (reps × judging passes), discard counts by reason, and
malformed-input counts rejected by the report itself — malformed lines, duplicate slots,
and score objects carrying keys outside the four rubric dimensions (which inflate a
rubric total above the documented max of 8; observed once, `tradeeoff` alongside
`tradeoff`). None of these are footnotes; a non-zero count in any of them changes how
much the uplift table can be trusted.

## Reading uplift against cost

A delta alone doesn't say whether a skill earns its keep. Per spec §7.1, cross the
uplift against the skill's own on-invoke token cost (`claude plugin details
dataforge@skills-dir`) — a small delta at 3.7k tokens per invocation does not earn its
cost, even if it's technically positive.

## Running

```bash
cd tests/quality-uplift
nohup ./generate-answers.sh -r 3 -o results/full > full-answers.log 2>&1 &
# watch: grep -E "ok |discard|UNMEASURABLE" full-answers.log
# expect 42 `ok` lines, or fewer with matching UNMEASURABLE lines

nohup ./judge-pairs.sh -o results/full -r 3 > full-judge.log 2>&1 &
# expect 63 judgments

./analyze.sh -x 3 results/full | tee baselines/<date>-uplift.md
```

`-x 3` matches `rubric.md`'s current per-dimension scale (0-3, four dimensions, max 12
per answer). `analyze.sh` defaults `-x` to 2 — the retired v1 scale — purely so it keeps
reading the committed v1 baselines unchanged; running the *current* rubric through that
default would understate the header's declared ceiling, and `analyze.sh` now aborts
rather than print a report against the wrong one (see "What voids a campaign"). Check
`rubric.md`'s stated per-dimension range before a campaign and pass `-x` to match it.

~42 `opus` answer sessions plus ~63 `sonnet` judgments, serial by design, roughly 45
minutes and ~$16 at the per-answer cost observed while writing the eval plan. Do not
raise concurrency — see contamination guard 3, above.

Running from this directory is safe: no `claude` session started by these scripts
inherits it as a cwd (guard 2), and neither script will write into a run directory
another writer holds (guard 5).

`results/` is gitignored and fully regenerable; re-run the scripts to reproduce or
extend it. `baselines/` is the committed record — each file there is a single campaign's
`analyze.sh` output, verbatim, plus the hand-appended cost column. Never edit a
committed baseline's numbers after the fact; a re-run gets a new dated file, and the old
one stays as the record of what was true when it ran. Appending a dated amendment that
discloses something later found out about how the run was produced is the one allowed
edit — it adds context, it does not restate a number.

**The first campaign, `baselines/2026-08-05-uplift.md`, is void** — its score-vs-length
correlation was r = 0.61, above the 0.5 threshold above. Read that file for why, and do
not treat its per-skill delta table as a standing result. It is kept as the record of
what happened, not as evidence about the suite's uplift. Its amendments section also
discloses that it was judged before the blinding hardening in guard 4 existed, so its
judge structurally could have read the arm labels.

## Known deferred issues

Dormante junto con el eval (ver *Estado* arriba). Nada de esto se arregla mientras el
eval esté cerrado; es la condición de entrada para quien lo reabra.

- `generate-answers.sh` exits 2 under `pipefail` when zero samples are accepted for a
  run. That reads as a generic pipe error, not "zero valid samples" — check the
  `accepted samples:` count in the log rather than trusting the exit code alone.
- Case IDs containing a literal `.` would break the `${base%%.*}` parse in
  `judge-pairs.sh` (none of the current 7 case IDs do).
- An out-of-enum `more_useful` string from the judge falls through to `"tie"` rather
  than erroring.

### Carried from the whole-branch review, for a follow-up branch

Ruled non-blocking for the first campaign, since it published VOID. Several are the same
class the harness exists to prevent — a confident number computed over data that was
silently dropped — so treat them as a backlog, not as polish.

**Decide before the next campaign is run:**

- ~~A non-zero extra-key count is not in *What voids a campaign* above.~~ **CERRADO
  2026-08-13.** Las tres partes están: `additionalProperties: false` en el
  `--json-schema` del juez (dos veces, en `a` y `b`), la suma sobre exactamente las
  dimensiones derivadas de los datos en vez de un `add` crudo, y el conteo de clave
  extra promovido a condición que anula (`analyze.sh` imprime *"rows with score keys
  outside the four rubric dimensions (VOIDS the campaign)"*). Queda un residual
  documentado en `experiments/README.md`: `rubric-headroom.sh` **no** aplica esa
  condición, así que los dos instrumentos discrepan sobre qué anula una campaña.

**~~Prioridad alta — dos compuertas que hoy no pueden disparar~~ — CERRADAS 2026-08-13:**

- ~~La canaria anti-fuga de `check-generate.sh` grepea `EXPECTED`~~ **Cerrado.** Se
  eliminó el patrón muerto y se separó en dos chequeos, porque eran dos fugas distintas:
  una de *nombres de archivo* (`qprobe-`, `cases.tsv`) y otra de *contenido* — el prompt
  de otro caso dentro de una respuesta, que es lo que pasa cuando el TSV entero baja por
  stdin y donde ningún nombre de archivo aparece. La firma es los primeros 40 caracteres
  del prompt, distintos entre los 7 casos, y se excluye el prompt propio: una respuesta
  hace eco de su propia pregunta y compararla contra sí misma dispararía siempre.
- ~~`EXPECTED_N` se deriva de las filas sobrevivientes~~ **Cerrado.** El conteo esperado
  ahora sale de lo que la corrida fue **instruida** a producir, no de lo que logró:
  `judge-pairs.sh` escribe `run-expected.tsv` antes de llamar al primer juez, y
  `analyze.sh` lo lee y además contrasta el total de filas. Una corrida vieja sin ese
  archivo sigue siendo analizable por el camino anterior, pero el reporte **declara** que
  el conteo se derivó de sobrevivientes y que ahí una pérdida uniforme es invisible.

**Hallazgo al arreglar la primera: el sandbox se filtra en las respuestas.**

Al probar la canaria contra la campaña v1 saltó que **10 de 42 respuestas mencionan su
propio sandbox** (`/tmp/qprobe-XXXXXX`, creado en `generate-answers.sh:69`). No es que el
prompt se filtrara: el modelo **miró su directorio de trabajo** y lo reportó — *"en esta
sesión no tengo nada de contexto, `/tmp/qprobe-lJtWDJ` está vacío"*.

Reparto: 6 en el brazo `with` y 4 en `without`, sobre 21 cada uno, concentradas en P1, P2
y A2. No es un sesgo grueso entre brazos, pero **A2 tiene 5 de sus 6 respuestas afectadas
y es el caso que peor puntuó en el re-juicio v2** (con 5.67, sin 4.11, el más bajo de los
siete). No es prueba de causalidad y no se midió como tal; el mecanismo plausible es que
esas respuestas gastaron su texto explicando que no tenían contexto en vez de contestar.

**Decidir antes de la próxima campaña:** si el sandbox debe ser invisible para el modelo,
o si una respuesta que lo comenta debe descartarse como muestra inválida igual que una
donde la skill no cargó. Hoy no es ninguna de las dos cosas: entra al promedio sin marca.

**Both harnesses:**

- `analyze.sh` never enforces the spec's "fewer than 3 accepted samples per arm ⇒ void"
  rule, and silently drops a `.meta` with no matching judgment from the correlation
  without counting the drop.
- Incoherent judgment rows are reported but not excluded from the uplift average, which
  contradicts spec §6.1.
- No judge session logs are saved, so a judging pass cannot be re-scored under a corrected
  rubric without paying for it again. `results/` is regenerable *in kind*, not
  reproducible — a re-run of a nondeterministic paid campaign yields different numbers.
- Discarded attempts overwrite their own probe log (`$tag.jsonl` is attempt-invariant), so
  a discard is recorded in `discards.tsv` but not backed by a log.
- `judge-failures.tsv` is not truncated at the start of a run, while `judgments.jsonl` is,
  so stale failures can be reported against a fresh judgment set.
- `generate-answers.sh` truncates the whole run's `discards.tsv` on every invocation, so
  topping up one case with `-c` erases the discard record for the others.
- `check-generate.sh`'s scaffolding-leak canary greps for `EXPECTED`, a column that exists
  in the *triggering* matrix, not in `cases.tsv`. It cannot detect the stdin leak it
  guards against; grep for a distinctive token from a non-target row instead.
- `EXPECTED_N` is derived from surviving rows, so a *uniform* loss is invisible: if one
  judging pass failed for every pair, every case would report a complete count.
- `await_memory` and the chain-extraction `jq` are duplicated across the two harnesses —
  three copies of the latter. The chain extractor *is* the definition of "the skill
  fired", so the two harnesses can silently drift on the measurement itself. Extract a
  shared `tests/lib/probe.sh`.

**`tests/triggering/` specifically:**

- `rescore.sh` scores `NONE|X` inconsistently with bare `NONE`: the `NONE` branch treats
  process skills as "no domain skill fired", the alternation branch does not, which
  misgrades case A11.
- `rescore.sh` degrades to all-`FAIL` when a matrix argument is omitted, because the
  unresolved expectation `?` matches nothing. It should report no-expectation and exit
  non-zero.
- Stale `.rep*.jsonl` files from a longer prior run inflate the denominator, manufacturing
  `FLAKY` verdicts.
- `run-matrix.sh` writes its non-authoritative position-1 verdict to `summary.tsv` under a
  `VERDICT` column with no caveat, and `results/matrix-green1-opus-with/summary.tsv` still
  carries the exact false finding this branch spent a commit correcting.
- Nothing checks the 1024-character frontmatter cap. `pipelines-architecture-data-engineering`
  currently sits at 1021 with three characters of headroom.
