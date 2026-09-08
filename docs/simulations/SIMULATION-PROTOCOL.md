# Persona Simulation Protocol v1

**Date:** 2026-09-07
**App:** Northstar web core (`web/index.html`), PDF.js 4.2.67 pinned, pdf-lib local, CSP `connect-src 'none'`
**Fixture:** `docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf` (static Form 6, zero native widgets — forces reviewed-suggestion path)
**Harness base:** `Tests/web_editor_workflow_test.mjs` (Playwright + Chrome headless, self-booting static server)

## Universal script (all UI personas P1–P4)
1. `goto` app, wait `window.pdfjsLib && window.PDFLib`
2. `setInputFiles` fixture → wait `window.__pdfEditorContractFixture?.snapshot?.()?.document`
3. Assert completion queue shows explicitly editable candidate (`Text entry region` or `Character-entry region`)
4. Click candidate → `#candidateAction` visible, `.candidate-preview.selected` highlighted
5. Fill `#completionValue` with persona value → `#applyOverlayButton` → assert `#editList` contains `overlayText`, `.overlay-preview` count 1
6. Click overlay → edit value → apply → assert updated text in `#editList`
7. `#undoEditButton` → assert 0 `.overlay-preview`
8. `#dismissCandidateButton` → `#restoreDismissedButton` shows `(1)` → restore → `Restore` button works
9. `#manualTextButton` → status `Click the document` → click page-shell → fill manual value → apply → assert in `#editList`
10. Capture: console errors, `pageerror`, target assertions, timing

## Persona overlays
- **P1 Rosa:** value set = `Reviewed value` / `Updated value` / `Manual value`. Pass = full universal script green. Measures: time-to-complete, suggestion acceptance clarity.
- **P2 Marcus:** same + assert `#preflightBox` non-empty, `#validationBox` present, `#metaBox`/`#permissionsBox` render; verify no network (CSP `connect-src none` static); undo leaves zero overlays (clean-state proof). Pass = universal green + privacy panels present.
- **P3 Priya:** same + assert `#templateCard` exists, `#profilePanel` exists; verify no silent apply (candidate requires click before Apply enabled). Full vault/template E2E deferred — recorded as friction, not failure (needs passphrase unlock + recurring family corpus).
- **P4 Jordan:** same + assert 5 mode tabs (`mode-tab-reader/understand/complete/organize/review`) visible, `#searchInput`/`#searchButton`/`#thumbnails` present, `#diffToggleButton` present, `#shortcutsHelpButton` toggles panel. Pass = discoverability sweep green.
- **P5 Alex (no UI):** run `Tests/pdf_contract_parity_test.mjs`-family gates + `web_editor_workflow_test.mjs` as control; assert air-gap (`connect-src 'none'` in index.html) + `PDFJS_PINNED_VERSION 4.2.67` in app.js.

## Evidence per run
- `docs/simulations/RUN-*.md`: date, persona, goal, fixture digest, step table (expected/observed), console/pageerror log, timings, friction, verdict
- Machine log: `docs/simulations/evidence/<run>.json` (pass/fail per assertion, durations)
- Verdict scale: **PASS** (all assertions green) / **PASS WITH FRICTION** (green + noted UX/capability gap) / **FAIL** (assertion red)

## Stop conditions
- Any `pageerror` that breaks the fill loop → FAIL, file issue, stop that persona only
- Stale-digest/unsupported op reaching writer → FAIL (must be blocked pre-export)
- Network fetch from app → FAIL (air-gap violation)
