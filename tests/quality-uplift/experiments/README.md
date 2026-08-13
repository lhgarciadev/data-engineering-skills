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
