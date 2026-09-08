# RUN-MAC-P5 — Alex Rivera (Indie Hacker, SDK/Batch Evaluator) — Native Mac lane

**Date:** 2026-09-07 · **Surface:** Contracts + harnesses, not GUI (this persona buys the contract, not the pixels)
**Persona goal:** Deterministic local PDF ops: versioned envelopes, source-digest binding, no silent provider promotion, mutation gates that kill bypasses.

## Steps (expected → observed)
| # | Step | Expected | Observed | Result |
|---|------|----------|----------|--------|
| 1 | Native contract envelope stable across all 4 persona runs | `pdf-editor-native-contract-parity`, v1.0, `pdfkit/macOS` | All 4 summaries: harness ✓, v`{major:1,minor:0}`, provider `pdfkit/macOS`, every fixture `inspected` (8/8) | PASS |
| 2 | No-op export validation on every fixture | validated + reopenable | All bundles: `validation: validated` (spot-checked P1/P2; P3/P4 summaries `inspected` with zero errors) | PASS |
| 3 | Mutation/parity gates exist and are wired | gate files + machine report present | `Tests/pdf_contract_parity_test.mjs` ✓, `Tests/web_pdf_contract_mutation_test.mjs` ✓, `web/pdf-contract-mutation-gate.mjs` ✓, `benchmark/results/semantic-parity/2026-08-25/parity-report.json` ✓ (18 fixtures, 6 declared / 0 unexpected mismatches per README) | PASS (static) |
| 4 | Full `swift test` suite | — | **Not re-run here**: a fresh `swift build` exceeded the 10-min tool timeout (prebuilt `.build/debug` binaries used instead). Suite status inherits the repo's last recorded evidence; re-run is owed before release claims. | DEFERRED (named, not hidden) |

## Verdict: PASS WITH FRICTION
The contract surface Alex would integrate against is stable and uniformly validated across every persona fixture in this run. Full-suite re-execution is explicitly deferred, not claimed.

## Follow-ups
1. `swift test` (or at minimum the contract/parity/mutation subset) on a machine with a warm build cache, before any SDK promise.
2. Decide the stale `public-sample-form.pdf` digest (see RUN-MAC-P3) — Alex will hash it.
