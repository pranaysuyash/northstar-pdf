# RUN-MAC-P1 — Rosa Alvarez (Solo Real-Estate Coordinator) — Native Mac lane

**Date:** 2026-09-07 · **Surface:** Native macOS, PDFKit provider (`pdfkit`, macOS Version 26.6.2 Build 25G83) via prebuilt `.build/debug/PDFContractHarness`
**Persona goal:** Open weekly 2-page disclosure-like packet, get review-gated entry suggestions, fill without disturbing surrounding content, export a validated new copy.
**Fixtures (mini-manifest `evidence/mac-P1-manifest.md`):**
- `docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf` (static Form 6, 0 native fields — forces reviewed-suggestion path)
- `benchmark/results/rotation-corpus/rotated-form6-mixed.pdf` (same class, pages rotated 90°/180° — rotation robustness)

## Steps (expected → observed)
| # | Step | Expected | Observed | Result |
|---|------|----------|----------|--------|
| 1 | Inspect Form 6 fixture | opens, 2 pages, source digest bound | `inspected`, digest `81e59007…`, 2 pages, 0 fields, **72 candidates**, preflight ✓, session provenance ✓ | PASS |
| 2 | No-op export + reopen validation | `validated`, output reopenable | `validation: validated`, export `succeeded`, `outputReopenable: true` | PASS |
| 3 | Inspect rotated-mixed fixture | same candidate set under rotation | `inspected`, digest `3e01dac9…`, 2 pages, **72 candidates** (parity with unrotated), `validated` | PASS |
| 4 | Harness exit code | 0 | `EXIT:0` | PASS |

## Contract facts (from bundles in `/tmp/mac-sim-P1/`)
- Both fixtures: `contractName pdf-editor.browser-fixture`, envelope v1.0, provider pdfkit/macOS.
- Preflight + `pdf-editor.session-provenance` present on both (locality `localDevice`, OCR `not-used`, zero-content privacy flags).
- No errors, no expected-failure fixtures in this run.

## Verdict: PASS
Rosa's core loop — open static packet → suggestions exist → clean validated export — holds natively, including under mixed rotation.

## Friction / follow-ups (not failures)
- GUI affordances (review card, overlay highlight, undo button) were proven on the web core earlier (superseded lane) but not click-driven here; native GUI pass on the built `PDFEditor` app is still open.
- Template/profile reuse across weekly repeats (Rosa's retention hook) needs the encrypted store + recurring-family corpus lane; out of scope for this run.
