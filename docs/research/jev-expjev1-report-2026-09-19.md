# EXP-JEV-1 replay report — 2026-09-19

Run mode: baseline-only (no API key placed; Jev lane dormant)
Cases: 28 total / 24 scoreable (fixture-derived circular cases excluded from scoring)
Label semantics + honesty notes: tools/jev-replay/corpus.mjs header; scope amendment in docs/task-inventory.md (JEV-1)

## Results

| Lane | Accuracy | Brier | Mean conf on known-FP class |
|---|---|---|---|
| Deterministic baseline | 0.542 | 0.142 | 0.737 |
| Jev (not run) | — | — | — |

Per-class (baseline): {"escalate":{"n":11,"hit":4},"close":{"n":13,"hit":9}}
Per-class (jev): —
Jev API errors: n/a

## Verdict

n/a — smoke-test run

## Scope caveats (v1 smoke test)

- Corpus is smoke-test-grade: ~30 independent outcome-labeled cases; the FP
  class is one episode (Mimosa, narrative-reconstructed); no native "escalate"
  exemplar class exists — the mapping is experimenter-imposed and ratification
  is an open owner item (JEV register).
- Fixture labels are circular vs. the baseline and are excluded from scoring.
- Per-class calibration-error claims require the corpus expansion recorded in
  the register (synthetic FP/stale generation, raw Mimosa text recovery).
