# Experiments

One-off investigations that answer a specific question about the harness itself,
rather than about the skills. Each keeps its instrument and its raw numbers so the
reading can be re-derived or overturned.

## `length-causality.sh`

**Question.** The 2026-08-05 campaign was voided at pooled `r = 0.61` between answer
bytes and rubric total. Correlation cannot say which of two opposite things is true:

- **(a)** the judge rewards verbosity, so the delta is an artifact — fix the judging protocol
- **(b)** the rubric measures coverage, which genuinely scales with length, so the
  correlation is signal and the primary metric is what needs rethinking

**Method.** Hold content constant, vary only length. Each sampled answer is compressed —
every technical claim preserved, prose cut — and both versions are scored under the same
rubric, one answer at a time with no comparison. Scoring is single-answer deliberately:
the campaign judged pairwise, and a pairwise judge shown a long and a short answer has a
second reason to prefer the longer one.

Compressor and judge must be different models. The first run used one model for both,
which lets the compressor cut toward what that same model rewards — biasing the result
toward "compression is harmless". The script now warns when they match.

```bash
./length-causality.sh -n 12 -c opus -m sonnet -o results/lc-crossmodel
```

### Result — the diagnosis is UNRESOLVED

Two runs: n=6 with sonnet for both roles (mean score change **+0.17**, 30% compression),
then n=12 with opus compressing and sonnet judging (mean **−0.25**, 19% compression).

The mean says the rubric mostly measures substance: 8 of 12 scored identically, including
the longest answers. `A1.with.rep2` lost 677 bytes and held at 8; `P7.with.rep2` lost 297
and held at 8. If the rubric paid for words, those are where it would show.

But two cases moved −2, and reading one of them refutes the tidy conclusion.
`P2.with.rep3` compressed 694 → 465 bytes and scored 7 → 5. Its compression preserves
every technical claim — the collapse of same-spec window functions into one sort, the
three WindowAgg nodes with a Sort between different specs, the index/`work_mem` fix versus
query rewrite distinction. **The judge scored the same substance two points lower for
being shorter.** That was verified by reading both versions, not by trusting the
compressor's claim to have preserved them.

So neither reading is established:

- The label "judge length-bias", as written in spec §6.2, the campaign digest, and this
  suite's README, is **unsupported** — the effect is far too small to drive `r = 0.61`.
- But "the correlation is signal, not bias" is **also unsupported** — there is real,
  verified length-sensitivity in at least one case, concentrated in short answers.
- The mechanism behind `r = 0.61` is **unresolved**. Do not rewrite §6.2's rationale on
  the strength of this experiment; that would replace one unverified diagnosis with
  another.

An earlier reading of the n=6 run claimed the −2 cases were short answers where
compression genuinely cut substance. Reading `P2.with.rep3` falsified that. It is recorded
here because a hypothesis stated as a finding is the failure this suite exists to catch.

### What would resolve it

More samples in the short range, where the variation lives — the two −2 cases are both
among the shortest — and reading every compression rather than trusting the compressor.
Roughly $10 and an hour of reading. Until then the campaign's void verdict rests on its
second, independent condition: a judgment row carrying a score key outside the four rubric
dimensions.

### Caveats that stand

- n=12, with two outliers. Not a result, a direction.
- The compressor is an LLM; "every claim preserved" is its claim, spot-checked on two of
  twelve, not verified across the set.
- Both runs use the same four-dimension rubric. If the rubric is itself coverage-additive,
  this design cannot see it — it only shows whether the judge scores consistently against
  it.

## `dimension-length-decomposition.sh`

**Question.** `length-causality.sh` left the mechanism behind `r = 0.61` unresolved: it
refuted "judge length-bias" without establishing the opposite. This instrument asks a
question that experiment could not: **does the correlation live in all four rubric
dimensions, or only in the three that require adding content?**

**Hypothesis under test — coverage additivity.** The rubric asks for four distinct content
elements. An answer containing all four is mechanically longer than one containing two,
because covering four things costs words. Under this hypothesis `r = 0.61` is neither judge
bias nor noise; it is length acting as a proxy for how many elements are present.

**Why this discriminates where the previous experiment did not.** The two hypotheses
predict **opposite signs for the same dimension**, `specific`:

- If the judge rewards length, all four dimensions correlate positively with bytes,
  `specific` included — a judge that pays for volume has no reason to penalise it.
- If the rubric is coverage-additive, `mechanism`, `actionable` and `tradeoff` correlate
  positively because they are content you add, while `specific` stays flat or goes
  negative: a longer answer has more room for generic filler, and `specific` penalises
  exactly that.

### Reading rule — registered 2026-08-13, before the instrument was written

| Observed | Reading |
|---|---|
| All four dimensions correlate positively with bytes, `specific` included | Supports judge length-bias |
| `mechanism`/`actionable`/`tradeoff` positive, `specific` flat or negative | Supports coverage additivity |
| Mixed, or inconsistent between arms | **Does not resolve.** Report as such |

"Flat" is defined here, before any number exists: `|r| < 0.2` for `specific`. A value
between 0.2 and the other dimensions' correlations falls in the third row, not the second.

**"Does not resolve" is a legitimate outcome of this experiment.** The failure would be
declaring resolved what is not, which is the defect this suite exists to catch.

### Result — the diagnosis DOES NOT RESOLVE (third row)

Applying the rule to `results/dld/run.txt`, row by row, before any interpretation:

- **Row 1 — judge length-bias.** Requires all four dimensions positive, `specific`
  included. `specific` in the `with` arm is **−0.14**. Negative. Row excluded.
- **Row 2 — coverage additivity.** Requires `mechanism`/`actionable`/`tradeoff` positive
  and `specific` flat, pre-defined as `|r| < 0.2`. `specific` is **−0.14** with,
  **+0.53** without, **+0.41** pooled. Two of the three values are positive and well
  above the 0.2 bound. Row excluded.
- **Row 3 — does not resolve.** "Mixed, or inconsistent between arms." `specific` carries
  **opposite signs across the two arms**: −0.14 with, +0.53 without. This row applies.

The instrument reproduces the published pooled `r = 0.61` for the rubric total exactly,
which is what licenses reading the rest of the table at all.

### The 15 correlations

| dimension | arm | n | r | mean bytes | mean score |
|---|---|---|---|---|---|
| mechanism | with | 21 | 0.15 | 2375 | 1.98 |
| mechanism | without | 21 | 0.50 | 1771 | 1.65 |
| mechanism | pooled | 42 | 0.42 | 2073 | 1.82 |
| actionable | with | 21 | 0.31 | 2375 | 1.92 |
| actionable | without | 21 | 0.59 | 1771 | 1.43 |
| actionable | pooled | 42 | 0.51 | 2073 | 1.67 |
| specific | with | 21 | **−0.14** | 2375 | 1.97 |
| specific | without | 21 | **0.53** | 1771 | 1.51 |
| specific | pooled | 42 | **0.41** | 2073 | 1.74 |
| tradeoff | with | 21 | 0.56 | 2375 | 1.49 |
| tradeoff | without | 21 | 0.48 | 1771 | 1.10 |
| tradeoff | pooled | 42 | 0.55 | 2073 | 1.29 |
| TOTAL | with | 21 | 0.59 | 2375 | 7.37 |
| TOTAL | without | 21 | 0.65 | 1771 | 5.68 |
| TOTAL | pooled | 42 | **0.61** | 2073 | 6.52 |

The `specific` sign flip is the whole reading. It is also the one number this design was
built to make decisive, and it came back arm-dependent — the discriminator did not
discriminate.

### What would resolve it

The sign flip has two candidate readings — a real arm-dependent effect, or sampling noise
— and this run cannot separate them. At n=21 per arm the two `specific` estimates have
overlapping 95% intervals (Fisher z: −0.14 → [−0.54, +0.31]; +0.53 → [+0.13, +0.78]; the
two intervals overlap between roughly +0.13 and +0.31, which records that they are not
disjoint and nothing more). That arithmetic is post-hoc and forms no part of the
pre-registered rule; it is recorded to size the next run, not to soften this one.

Three things would resolve it, and all must be pre-registered before the numbers exist:

1. **Enough samples per arm that a per-arm `r` has an interval narrower than the 0.2 flat
   bound.** Under the rule as written the bound is unusable at n=21, since the interval
   is wider than the decision it is meant to drive.
2. **A within-case decomposition.** These correlations pool 7 cases × 3 reps. A case that
   elicits longer *and* better answers moves `r` without any within-answer length effect
   existing. Correlating bytes against score *within* each case, then combining, separates
   between-case difficulty from the effect under test. This run cannot do that at 3 reps
   per case per arm.
3. **A scale with headroom in the `with` arm.** The table above prints with-arm means of
   1.98 `mechanism`, 1.92 `actionable` and 1.97 `specific` against a rubric maximum of 2
   — at or near the ceiling on three of the four dimensions. A Pearson correlation
   computed on scores packed that close to the top of the scale has very little variance
   to work with, so more samples per arm may not buy what remedy 1 assumes: the next run
   would need a wider scale, a finer rubric, or a case mix that spreads the with-arm
   scores before extra reps can narrow a with-arm interval. This is an observation about
   the design's measuring range, read off numbers already in the table; it is recorded
   post-hoc, forms no part of the pre-registered rule, and asserts nothing about why the
   `specific` sign flipped or about either hypothesis.

Until one of those runs exists, the mechanism behind `r = 0.61` stays unresolved, exactly
as `length-causality.sh` left it. Nothing here promotes either hypothesis, and this
section deliberately stops without naming a favourite: the predecessor experiment's
recorded failure was reading an inconclusive result into a tidy conclusion after the
fact, and a consolation hypothesis is that same failure in a quieter voice.

### Caveats that stand

- **This run is observational.** It varies nothing. Even a clean split would have made one
  hypothesis more plausible and would **not prove causation**; a split that is not clean
  supports nothing at all.
- **n = 42 answers across 7 cases**, 21 per arm. Small, and clustered by case.
- **It does not measure uplift.** It measures what produces a correlation, not whether any
  skill improves an answer. No number here says anything about whether the skills work.
- **It does not verify the `P2.with.rep3` explanation** from spec §3.1. That remains a
  conjecture about a single case, and this instrument was not built to test it.

### Recorded against the rule, not acted on

The rule was applied as written and is left as written; amending it after seeing numbers
would forfeit the only thing that makes this run worth more than the last one. Two things
would have been specified differently had they been caught on 2026-08-13:

- **The rule says `|r| < 0.2` for `specific` without saying which arm it is measured on.**
  Read as the `with` arm alone, −0.14 satisfies it and row 2 becomes satisfiable too; read
  as pooled or `without`, it fails badly. The verdict is unaffected either way, because
  row 3's "or inconsistent between arms" clause can only ever fire alongside another row
  and therefore takes precedence by construction — a disjunct always in competition is
  meaningful only if it wins. The ambiguity is still real, and a future rule should name
  both the arms and the precedence explicitly.
- **The rule treats "positive" as a bare sign test, with no magnitude or uncertainty
  floor.** `mechanism`/`with` at 0.15 counts as "positive" literally while being
  indistinguishable from zero at this n ([−0.30, +0.55], the same post-hoc Fisher-z
  arithmetic, recorded and not acted on). A rule that decides on signs should state the n
  at which a sign is readable.

## `rubric-headroom.sh`

**Question.** `dimension-length-decomposition.sh` left a post-hoc, not-acted-on
observation on the table: with-arm dimension means of 1.98 `mechanism`, 1.92
`actionable`, 1.97 `specific` and 1.49 `tradeoff`, against a per-dimension maximum of 2
— 7.37 of 8 total. **Does the rubric have too little dynamic range to measure uplift?**
If a competent answer already scores near the ceiling, any improvement a skill produces
beyond "competent" is unmeasurable, and the erratic `specific` correlation upstream is
what a near-zero-variance variable produces when correlated against anything.

**Method.** Descriptive statistics only — no split, no new sampling. Average each
answer's per-dimension scores across judge reps first, exactly as the upstream
instruments do (`analyze.sh:170-177`), then compute per arm: the count/percentage of
answers at each of 0/1/2 per dimension, per-dimension mean and population SD, the
count/percentage of totals at the maximum (8), the full distribution of totals, and the
mean observed uplift against the mean maximum detectable uplift (`8 − without_total`,
paired by case-rep).

### Reading rule — registered 2026-08-13, before the instrument was run

Saturation is **CONFIRMED** if both hold:
- on at least two of the four dimensions, **≥ 50%** of with-arm answers score the
  maximum (2); **and**
- the mean observed total uplift is **≥ 60%** of the mean maximum detectable uplift.

Saturation is **REFUTED** if neither holds. **Anything else is PARTIAL**, reported as
such and not rounded toward either verdict.

### Result — the diagnosis is CONFIRMED

Applying the rule to `results/headroom/run.txt`, mechanically, before any interpretation:

- **Condition 1 — dimensions at ≥ 50% max.** With-arm answers scoring exactly 2:
  `mechanism` 20/21 (95.2%), `specific` 20/21 (95.2%), `actionable` 18/21 (85.7%),
  `tradeoff` 10/21 (47.6%). Three of the four dimensions clear the 50% bound — the rule
  requires two. **Condition 1 holds.**
- **Condition 2 — uplift vs. headroom ratio.** Mean observed uplift (with − without) is
  **1.6825**; mean maximum detectable uplift (`8 − without_total`) is **2.3175**. Ratio:
  **1.6825 / 2.3175 = 0.7260 (72.6%)**, against a 60% bound. **Condition 2 holds.**

Both conditions hold. **Verdict: CONFIRMED.**

### The numbers

| dimension | arm | n | mean | sd | count@2 | pct@2 |
|---|---|---|---|---|---|---|
| mechanism | with | 21 | 1.984 | 0.071 | 20 | 95.2% |
| actionable | with | 21 | 1.921 | 0.203 | 18 | 85.7% |
| specific | with | 21 | 1.968 | 0.142 | 20 | 95.2% |
| tradeoff | with | 21 | 1.492 | 0.647 | 10 | 47.6% |
| mechanism | without | 21 | 1.651 | 0.465 | 11 | 52.4% |
| actionable | without | 21 | 1.429 | 0.676 | 11 | 52.4% |
| specific | without | 21 | 1.508 | 0.432 | 8 | 38.1% |
| tradeoff | without | 21 | 1.095 | 0.784 | 6 | 28.6% |

Totals: with-arm mean **7.365/8** (sd 0.705), **8/21 (38.1%)** scoring the maximum;
without-arm mean **5.683/8** (sd 1.890), **2/21 (9.5%)** scoring the maximum.

Mean observed uplift **1.6825**; mean maximum detectable uplift **2.3175**; ratio
**0.7260 (72.6%)**.

### What this does not establish

- **This is descriptive statistics on n = 42 answers across 7 cases** (21 per arm), the
  same small, case-clustered dataset every instrument in this directory reads.
- **It does not prove the rubric caused anything.** A ceiling this close does not say
  *why* the with-arm lands there — only that the scale has little room left above it.
- **It does not measure uplift.** It measures how much of the *possible* uplift range
  the rubric can still register, not whether any skill produced a real improvement.
- **It does not resolve the correlation `dimension-length-decomposition.sh` left open.**
  The `specific` sign flip between arms is untouched by this result; a saturated with-arm
  is consistent with that instrument's own post-hoc observation but does not explain the
  flip, and this instrument was not built to.
- **`tradeoff` is the outlier that keeps this from being unanimous.** It clears neither
  the 50%-at-max bar on its own (47.6%) nor comes close to the other three dimensions'
  means (1.49 vs. 1.92–1.98). If the rubric is re-scaled, `tradeoff` is where the
  remaining headroom actually lives — the other three dimensions have almost none left
  to find.

## Rubric v2 — saturation gate

**Question.** The v1 rubric saturated: three of four dimensions had ≥85% of
with-arm answers at the maximum, with standard deviations of 0.071, 0.142 and
0.203. The v2 rubric raises what the top score costs. **Does it actually leave
room, or does it saturate too?**

Answered by re-judging the 42 answers already on disk in `results/full/` — no
answer generation, so the cost is judge calls only.

### Threshold — registered 2026-08-13, before any v2 score existed

The v2 **passes** if, on the with-arm:

- **no** dimension has ≥50% of answers at the maximum (3); **and**
- **all four** dimensions have SD ≥ 0.4.

The v2 **fails** if either condition is unmet.

0.4 is a deliberately lax floor: `tradeoff`, the only v1 dimension that
discriminated, had SD 0.647, and requiring all four to match the best would be a
harder bar than the problem needs.

**"The v2 failed" is a legitimate outcome.** A redesign that still saturates is
one that did not work, and the point of running this on already-paid-for data is
to learn that before funding a campaign rather than after.

### Result — the v2 FAILS the gate

Run: `results/headroom-v2/run.txt`, produced by re-judging the same 42 answers
under the v2 rubric (63 rows, 21 case-reps x 3 judge reps, zero judge failures)
and reading them with `./rubric-headroom.sh -d ../results/full-v2-judgments -x 3`.

Applying the threshold as registered, mechanically, before any interpretation.

**Condition 1 — no with-arm dimension has >= 50% of answers at the maximum (3).**
`mechanism` 12/21 = **57.1%**, `actionable` 2/21 = 9.5%, `assumptions` 8/21 =
38.1%, `tradeoff` 5/21 = 23.8%. `mechanism` is at or above the 50% bound.
**Condition 1 is unmet.**

**Condition 2 — all four with-arm dimensions have SD >= 0.4.** `mechanism`
**0.343**, `actionable` **0.380**, `assumptions` 0.839, `tradeoff` 1.033. Two of
the four fall below the 0.4 floor. **Condition 2 is unmet.**

The threshold fails the v2 if *either* condition is unmet. Both are.
**Verdict: FAIL.**

Nota: `results/headroom-v2/run.txt` reimprime, bajo el encabezado "Reading rule", la
regla de lectura CONFIRMED/REFUTED propia del instrumento — el heurístico de
saturación v1, no el estándar que juzga esta entrega. Aplicada mecánicamente a los
números de esa misma corrida, esa regla arroja REFUTED ("no saturado"), una lectura
distinta del umbral pre-registrado el 2026-08-13 arriba. El estándar vigente es ese
umbral, y bajo él el veredicto es **FAIL**.

### Which dimensions did not leave room

- **`mechanism` fails both conditions.** 57.1% of with-arm answers score the
  maximum and its SD is 0.343 — the lowest of the four. Raising what a 3 costs
  moved it off the v1 ceiling (95.2% at max, SD 0.071) without moving it far
  enough: a clear majority still lands at the top of the new scale.
- **`actionable` fails the SD condition only**, at 0.380. Its shape is not the
  ceiling shape — only 9.5% score the maximum, and its mean is 2.397. It is
  *compressed*, not saturated: nearly every with-arm answer lands on 2 or 3 and
  almost nothing lands below. Low variance and a full ceiling are different
  failures, and the SD floor catches both; this is the second one.
- `assumptions` (SD 0.839) and `tradeoff` (SD 1.033) clear both conditions. The
  dimension that replaced `specific` does discriminate; the two that were already
  near the v1 ceiling are the two that still do not.

### The numbers, both arms

| dimension | arm | n | mean | sd | count@3 | pct@3 |
|---|---|---|---|---|---|---|
| mechanism | with | 21 | 2.762 | 0.343 | 12 | 57.1% |
| actionable | with | 21 | 2.397 | 0.380 | 2 | 9.5% |
| assumptions | with | 21 | 2.143 | 0.839 | 8 | 38.1% |
| tradeoff | with | 21 | 1.921 | 1.033 | 5 | 23.8% |
| mechanism | without | 21 | 2.286 | 0.645 | 4 | 19.0% |
| actionable | without | 21 | 1.778 | 0.863 | 2 | 9.5% |
| assumptions | without | 21 | 1.714 | 0.950 | 4 | 19.0% |
| tradeoff | without | 21 | 1.254 | 1.088 | 4 | 19.0% |

Totals against a maximum of 12: with-arm mean **9.222** (sd 2.117), **0/21
(0.0%)** at the maximum; without-arm mean **7.032** (sd 2.949), **0/21 (0.0%)**
at the maximum. Mean observed uplift **2.1905**, mean maximum detectable uplift
(`12 - without_total`) **4.9683**, ratio **0.4409 (44.1%)**.

Those totals are recorded because the instrument prints them, and they are not
part of the threshold. No answer in either arm scores a perfect 12 — the v2 has
headroom *in the aggregate* while two of its four dimensions do not. The
threshold was written per-dimension deliberately, and it is applied per-dimension
here; a total-level reading is not a route around it.

### What this does not establish

- **It does not measure uplift.** This is descriptive statistics over the same 42
  answers (21 per arm, 7 cases) that every instrument in this directory reads. It
  measures whether the *scale* leaves room, not whether any skill improves an
  answer. The converse also holds and is the easier mistake: a rubric that left
  room would not have been evidence that uplift exists.
- **It re-judges v1-era answers.** The 42 answers were produced by models that
  were never shown the v2 rubric. Whether a fresh campaign — answers generated
  and judged under v2 throughout — reproduces this distribution is untested. The
  measurement is of the rubric applied to existing text, not of the rubric in the
  loop it is meant for.
- **These numbers are not reproducible from a clone of this repo.**
  `tests/quality-uplift/results/` is gitignored, so neither `results/full/` (the
  42 answers) nor `results/full-v2-judgments/` (the 63 v2 judgment rows) is in
  the repo. Only `experiments/results/*/run.txt` is durable. Anyone cloning this
  repo cannot re-run this gate, and cannot re-run either instrument's
  reproduction check against the committed v1 output either, because both read
  the same absent directory. The run file *is* the artifact; it is a record of
  what was computed, not something a reader can verify by recomputing it.
- **n = 21 per arm, clustered by case, and the judge is nondeterministic.** Three
  judge reps per pair are averaged before any statistic here, which reduces that
  variance but does not remove it. An SD of 0.343 against a 0.4 floor is not a
  wide miss, and this design cannot say how much of that gap is sampling.
- **It does not say why the v2 fell where it did.** That the top score was made
  more expensive and `mechanism` still sits at 57.1% is an observation about the
  outcome, not a diagnosis of the rubric wording.

The gate is applied and the answer is FAIL. What follows from that is a separate
decision, made with these numbers in hand and pre-registered before the next run
in the same way this threshold was.

### Residual conocido: los dos instrumentos discrepan sobre la clave inventada

`analyze.sh` cuenta las filas cuyas claves de puntaje caen fuera del conjunto de
dimensiones y declara que un valor distinto de cero **anula la campaña**.
`rubric-headroom.sh` no lo hace: su guarda compara la fila 1 contra el conjunto
en que coincide el resto del archivo, así que detecta una fila 1 discrepante pero
**deja pasar en silencio una fila que trae una clave de más**.

No es hipotético. `results/full/judgments.jsonl` tiene exactamente una fila así —
`P4 rep3 jr2`, con `tradeeoff` mal tipeado junto a `tradeoff` — y por eso la
guarda no se escribió como una comparación fila a fila: así redactada, abortaría
sobre los datos v1 y rompería la reproducción del resultado v1 en el que se apoya
todo este rediseño.

Sobre el veredicto de arriba no incide: las tres corridas v2
(`full-v2-judgments`, `calib-v2`, `calib-len-v2`) tienen cero filas con claves
fuera del conjunto v2, porque el esquema del juez lleva
`additionalProperties: false`. Queda anotado porque el instrumento que produjo
este FALLA es, de los dos, el que menos ve — y porque "los instrumentos
discrepan sobre qué anula una campaña" es una pregunta de diseño, no un bug que
se arregla eligiendo el más estricto sin pensarlo.

### Lo que el brazo sin-skill dice, y por qué apunta a los casos

Los números de arriba se leyeron como un veredicto sobre el rubric. El brazo
sin-skill de la misma corrida sugiere que el rubric no es donde está el problema.

**Por dimensión** (medias sobre las 21 respuestas, escala 0–3):

| dimensión | media sin-skill | SD del brazo con-skill | compuerta |
|---|---|---|---|
| `mechanism` | 2.286 | 0.343 | falla |
| `actionable` | 1.778 | 0.380 | falla |
| `assumptions` | 1.714 | 0.839 | pasa |
| `tradeoff` | 1.254 | 1.033 | pasa |

El orden es monótono en los cuatro puntos: cuanto mejor responde ya el modelo
**sin** la skill en una dimensión, menos varianza produce el rubric en el brazo
**con** la skill. Las dos que fallan la compuerta son las dos donde el modelo base
ya es competente.

Esto es una ordenación sobre cuatro puntos, **no un coeficiente de correlación**,
y se declara así a propósito: calcular un `r` sobre estos datos queda bajo la
restricción de §6 —pre-registrar el tratamiento del clustering por caso (7 casos ×
3 reps)— y ninguna cifra de este apartado la necesita.

**Por caso** (totales sobre 12):

| caso | sin skill | con skill | delta | techo restante (12 − sin) |
|---|---|---|---|---|
| P4 | **10.33** | 9.67 | **−0.67** | 1.67 |
| P7 | 7.89 | 10.78 | 2.89 | 4.11 |
| A1 | 7.33 | 9.78 | 2.44 | 4.67 |
| P2 | 6.89 | 8.56 | 1.67 | 5.11 |
| P1 | 6.67 | 9.44 | 2.78 | 5.33 |
| A4 | 6.00 | 10.67 | **4.67** | 6.00 |
| A2 | 4.11 | 5.67 | 1.56 | 7.89 |

**P4 mide algo peor que nada**: el modelo sin la skill saca 10.33 de 12 y le gana
al brazo con skill. Le quedan 1.67 puntos de techo, así que ese caso no puede
mostrar uplift por construcción — cualquier número que aporte al promedio es ruido
con formato de medición.

Esto es exactamente la salvedad que el spec del v2 dejó escrita y fuera de alcance
en §1.1: *"si los siete casos son demasiado fáciles para el modelo base, ningún
rubric lo compensa"*. Se registró entonces como una pregunta abierta; estos
números son la primera evidencia directa a favor.

**La conclusión que NO se sigue de acá.** Nada de esto dice que la skill no
sirva, ni que el uplift no exista. Dice que este conjunto de siete casos tiene
poco margen para mostrarlo en dos de las cuatro dimensiones, y ninguno en P4.
Tampoco dice que el v2 sea un buen rubric: falló su compuerta y eso sigue en pie.

### Próximo paso, y su umbral — registrado 2026-08-13, antes de correrlo

Antes de escribir un v3 del rubric, medir si los casos discriminan. Cuesta **cero
generación de respuestas y cero llamadas de juez**: todo sale de
`results/full-v2-judgments/` que ya está en disco.

Un caso se declara **sin poder de medición** si su brazo sin-skill promedia
**≥ 9.0 de 12** — es decir, le quedan 3 puntos o menos de techo, un cuarto de la
escala. Bajo ese umbral, hoy P4 (10.33) queda descartado y ningún otro se acerca:
el segundo es P7 con 7.89.

El umbral se fija antes de correr nada y por la misma razón que el anterior: para
que no lo elija después quien ya vio qué casos preferiría conservar. Si la próxima
entrega lo cambia, que lo cambie explícitamente y diga por qué.

**Lo que este paso no resuelve.** Descartar casos fáciles sube el uplift medido
sin que la skill haya cambiado — es selección, no mejora. El resultado sirve para
saber qué puede medir este eval, no para reportarlo como un uplift mayor. Un
reemplazo honesto exige escribir casos nuevos y más difíciles, y eso sí cuesta una
campaña.

### La forma de defecto que este harness produce

Siete defectos se corrigieron durante esta entrega y los siete comparten forma:
**el instrumento reportaba éxito sin haber medido.** `judge-pairs.sh` apuntado a
un directorio vacío escribe cero filas y termina con `exit 0`. `git stash` sin
cambios que guardar sale 0, y una guarda de reproducción construida sobre él
compara el código nuevo contra sí mismo y siempre pasa. Un hook con ruta
relativa no encuentra su propio script y queda mudo, que se lee igual que
"nada que reportar". `git status --short` sobre un directorio ignorado sale
vacío tanto si los datos están intactos como si se borraron. Un instrumento con
la escala vieja imprime `max 8` sobre un total de 10.3. Otro, con la fila 1
truncada, emite un veredicto de aspecto completo sobre tres cuartos del rubric.
Y un archivo de corrida reimprime la regla de lectura de la versión anterior,
que sobre los números nuevos da el veredicto contrario.

Ninguno tiraba un error, y ninguno era visible leyendo el código: los siete
aparecieron sólo al ejercitar el instrumento con datos de la forma equivocada.
De ahí la regla para lo que se agregue acá: **un `exit 0` no es evidencia hasta
que alguien haya confirmado que el mismo camino falla cuando debe fallar.**
