# EXP-JEV-1 replay report — 2026-09-21

Run mode: baseline + jev-1.13 (pinned)
Cases: 28 total / 24 scoreable (fixture-derived circular cases excluded from scoring)
Label semantics + honesty notes: tools/jev-replay/corpus.mjs header; scope amendment in docs/task-inventory.md (JEV-1)

Model-id amendment (2026-09-21, post-run): this run requested `jev-latest`,
which serves `jev-1.13.0` (raw captures record it). Subsequent probe found the
API also accepts the EXACT version `jev-1.13.0` as a request id (the minor
alias `jev-1.13` and wildcard `jev-1.13.x` are rejected) — the harness now
pins `jev-1.13.0` directly. Raw per-call captures in `tools/jev-replay/raw/`.

## Results

| Lane | Accuracy | Brier | Mean conf on known-FP class |
|---|---|---|---|
| Deterministic baseline | 0.542 | 0.142 | 0.737 |
| Jev (jev-1.13) | 0.208 | 0.201 | 0.407 |

Per-class (baseline): {"escalate":{"n":11,"hit":4},"close":{"n":13,"hit":9}}
Per-class (jev): {"escalate":{"n":11,"hit":4},"close":{"n":13,"hit":1}}
Jev API errors: 0

## Verdict

KILL SIGNAL: Jev materially worse than baseline or confidence-inflated on the known FP class

## Scope caveats (v1 smoke test)

- Corpus is smoke-test-grade: ~30 independent outcome-labeled cases; the FP
  class is one episode (Mimosa, narrative-reconstructed); no native "escalate"
  exemplar class exists — the mapping is experimenter-imposed and ratification
  is an open owner item (JEV register).
- Fixture labels are circular vs. the baseline and are excluded from scoring.
- Per-class calibration-error claims require the corpus expansion recorded in
  the register (synthetic FP/stale generation, raw Mimosa text recovery).
