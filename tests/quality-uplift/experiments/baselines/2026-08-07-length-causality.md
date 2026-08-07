# length-causality — raw results

Reading and caveats: see README.md. The diagnosis is UNRESOLVED; these are the numbers.

## Run 2 — n=12, compressor opus, judge sonnet (the one to cite)

| answer | orig bytes | orig score | compressed bytes | compressed score | delta |
|---|---|---|---|---|---|
| A1.with.rep2 | 3981 | 8 | 3304 | 8 | 0 |
| A2.with.rep2 | 1259 | 6 | 1047 | 6 | 0 |
| A2.without.rep1 | 1390 | 5 | 1141 | 3 | -2 |
| A4.without.rep1 | 2090 | 7 | 1469 | 8 | 1 |
| P1.without.rep1 | 1763 | 6 | 1410 | 6 | 0 |
| P2.with.rep1 | 1009 | 8 | 790 | 8 | 0 |
| P2.with.rep3 | 694 | 7 | 465 | 5 | -2 |
| P2.without.rep1 | 1071 | 6 | 858 | 6 | 0 |
| P4.without.rep1 | 2622 | 7 | 1960 | 7 | 0 |
| P4.without.rep2 | 2677 | 8 | 2431 | 8 | 0 |
| P7.with.rep1 | 3065 | 8 | 2802 | 8 | 0 |
| P7.with.rep2 | 3157 | 8 | 2860 | 8 | 0 |

  n=12  mean compression 19%  mean score change -0.25
  READING: compression barely moves the score — the rubric measures substance,
  so the length correlation is signal, not judge bias, and the primary metric
  is what needs rethinking rather than the judge.

## Run 1 — n=6, sonnet for both roles (confounded, kept for the record)

| answer | orig bytes | orig score | compressed bytes | compressed score | delta |
|---|---|---|---|---|---|
| A1.with.rep1 | 2992 | 8 | 2044 | 8 | 0 |
| A1.with.rep2 | 3981 | 8 | 1605 | 8 | 0 |
| P1.without.rep3 | 1476 | 7 | 1174 | 6 | -1 |
| P2.with.rep3 | 694 | 4 | 500 | 6 | 2 |
| P2.without.rep3 | 1109 | 6 | 780 | 7 | 1 |
| P7.without.rep1 | 2538 | 8 | 2338 | 7 | -1 |

  n=6  mean compression 30%  mean score change +0.17
  READING: compression barely moves the score — the rubric measures substance,
  so the length correlation is signal, not judge bias, and the primary metric
  is what needs rethinking rather than the judge.
