# Stash Recovery Plan — 2026-08-26

**Audit scope:** `stash@{0}` — 96 files, based on `035db2b` (Phase 0-3 commit)
**Doctrine alignment:** OPERATING_DOCTRINE §6 (semantic salvage), §10 (parallel work), §14 (documentation)
**Recovery principle:** Adopt every improvement that strengthens the codebase without introducing regressions. Reject nothing that has value. Partial adoptions allowed when only parts of a change are better.

---

## 1. Stash inventory by category

| Category | Files | Lines changed | Assessment |
|---|---|---|---|
| **Source (Swift)** | 4 | ~326 | All improvements — adopt |
| **Tests (JS)** | 2 | ~6 | Minor fixes — adopt |
| **Baseline images** | 5 | binary | Updated baselines — adopt |
| **Web app (React)** | 15 | ~1,400 | Major feature work — adopt |
| **Web root** | 2 | ~24 | Minor fixes — adopt |
| **Docs** | 7 | ~230 | Decision records + audit updates — adopt |
| **Tools** | 2 | ~25 | Minor fixes — adopt |
| **CI** | 1 | ~35 | Tool-dependent gate — ALREADY IN HEAD (committed in `91c512c`) |
| **Benchmark (JSON)** | 38 | ~8,000 | Generated artifacts — REGENERATE, don't adopt |
| **Benchmark (PDF)** | 15 | binary | Generated fixtures — REGENERATE, don't adopt |
| **Benchmark (JS)** | 1 | ~17 | react-surface-smoke.mjs — adopt |
| **progress.md** | 1 | ~28 | Session entries — adopt (append-only) |

---

## 2. File-by-file analysis

### SOURCE FILES (4) — ADOPT ALL

#### `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift` (+124 lines)
**Status:** ✅ ALREADY ADOPTED (committed in `514d109`)
**What it adds:**
1. PNG predictor undo (`applyPngUpPredictor`) — fixes xref streams with `/Predictor 12`
2. Compressed object tracking (`compressedObjects: Set<Int>`) — type-2 entries fail closed with precise diagnostic
3. Depth-matched dict extraction (`skipValue`) — fixes nested `/DecodeParms` truncation
**Verdict:** Critical bug fixes. Already applied.

#### `Sources/PDFEditorRecovery/AppModel.swift` (+179 lines)
**Status:** ❌ NOT YET ADOPTED
**What it adds:**
1. `CandidateReviewLearningEventStore` — Stage 0 learning loop: records confirmed/rejected review decisions per source digest (value-free, privacy-safe)
2. `CandidatePriors` — Stage 1: aggregates events into per-candidate acceptance priors for ranking
3. `autoOCRPendingPages` — dedup set for in-flight OCR passes
4. `recordCandidateLearningEvent()` — records decisions without blocking the user's edit flow
5. Integration: loads priors on document open, re-aggregates after each decision
**Verdict:** High-value feature. Improves candidate ranking over time. Fails closed (learning errors don't block edits). Privacy-safe (value-free structural events). **ADOPT.**

#### `Sources/PDFEditorApp/ContentView.swift` (+5 lines)
**Status:** ❌ NOT YET ADOPTED
**What it adds:** `createFromMarkdown` callback and "From Markdown..." menu button in WelcomeView
**Verdict:** Minor UI extension. Depends on `AppModel.newDocumentFromMarkdown()` existing. **ADOPT if the method exists; SKIP if it doesn't.**

#### `Sources/PDFEditorApp/ContextualInspectorView.swift` (+18 lines)
**Status:** ❌ NOT YET ADOPTED
**What it adds:**
1. `SuggestionExplainer.explain(candidate)` — deterministic evidence card showing reasons and cautions
2. Changes `model.activeCandidates` to `model.rankedActiveCandidates` — uses learning-loop-ranked candidates
**Verdict:** UI improvement that surfaces candidate reasoning. Requires `rankedActiveCandidates` property (from AppModel learning loop). **ADOPT with AppModel.**

### TEST FILES (2) — ADOPT BOTH

#### `Tests/pdf-signature-guard_test.mjs` (2 lines)
**Change:** Import order fix — `pdfPython` import moved before other imports
**Verdict:** Cosmetic, no functional change. **ADOPT.**

#### `Tests/toolbar_visual_regression_test.mjs` (4 lines)
**Change:** `chromium.launch({ headless: true })` → `chromium.launch({ channel: "chrome", headless: true })`
**Verdict:** Aligns with repo convention (system Chrome, air-gap friendly). **ADOPT.**

### BASELINE IMAGES (5) — ADOPT ALL

Updated toolbar screenshots at various viewport widths (320px, 768px, 1024px, 1440px, 1920px).
**Verdict:** Reflect current UI state. **ADOPT.**

### WEB APP (15 files) — ADOPT ALL

Major React feature work:

| File | Lines | What it adds |
|---|---|---|
| `App.tsx` | +319 | Export flow, undo history, candidate dismissal, region rect tracking |
| `PdfController.ts` | +551 | Rect normalization, SHA-256 hashing, export copy with field/overlay ops, page fact replay, box replay |
| `CompleteWorkbench.tsx` | +164 | Export panel, preservation metrics, review surface |
| `ReaderStage.tsx` | +65 | Mode-aware rendering, candidate integration |
| `AgentCommandHUD.tsx` | +85 | Command palette improvements |
| `ContextualInspector.tsx` | +22 | Evidence card integration |
| `PageThumbnailRail.tsx` | +11 | Minor UI fixes |
| `Toolbar.tsx` | +4 | Minor fixes |
| `main.tsx` | +7 | Entry point updates |
| `app.css` | +7 | Style updates |
| `createDocument.ts` | +13 | Document creation updates |
| `pdfjs-runtime.d.ts` | +4 | Type declarations |
| `vendor.d.ts` | +35 | Type declarations for pdf-lib exports |

**Verdict:** All represent genuine feature progress. **ADOPT ALL.**

### WEB ROOT (2 files) — ADOPT BOTH

| File | Lines | What it adds |
|---|---|---|
| `app.js` | +18 | Minor fixes |
| `operation-history.d.mts` | +6 | Type declaration updates |

**Verdict:** Minor fixes. **ADOPT.**

### DOCS (7 files) — ADOPT ALL

| File | Lines | What it adds |
|---|---|---|
| `docs/decisions.md` | +85 | D-055: Single status authority decision |
| `docs/design-implementation-map.md` | +19 | Design-implementation mapping updates |
| `docs/audits/full-persona-audit-2026-08-26.md` | +10 | Audit updates |
| `docs/audits/comprehensive-repository-audit-...md` | +10 | Audit updates |
| `docs/explorations/field-suggestions-exploration-2026-08-25.md` | +66 | Exploration notes |
| `docs/context/agent-start/SESSION_CONTEXT.md` | +4 | Session context |
| `docs/release-gates.md` | +2 | Gate updates |

**Verdict:** Decision records and audit updates. **ADOPT ALL.**

### TOOLS (2 files) — ADOPT BOTH

| File | Lines | What it adds |
|---|---|---|
| `tools/run-contract-tests.mjs` | +5 | Minor fix |
| `tools/README.md` | +20 | Documentation |

**Verdict:** Minor improvements. **ADOPT.**

### CI (1 file) — ALREADY IN HEAD

`.github/workflows/ci.yml` — tool-dependent gate. **Already committed in `91c512c`. SKIP.**

### BENCHMARK JSON (38 files) — REGENERATE

Generated test output. Changes reflect re-run results, not code improvements.
**Verdict:** Don't adopt stale generated artifacts. **REGENERATE by running the test suites.**

### BENCHMARK PDF (15 files) — REGENERATE

Generated fixtures. Same reasoning.
**Verdict:** **REGENERATE.**

### BENCHMARK JS (1 file) — ADOPT

`benchmark/react-surface-smoke.mjs` (+17 lines)
**Verdict:** New benchmark script. **ADOPT.**

### progress.md — ADOPT (append-only)

Session entries from prior work. Append-only ledger per D-055.
**Verdict:** **ADOPT** (merge with existing entries).

---

## 3. Recovery execution plan

### Phase A: Source adoption (highest priority)

1. **AppModel.swift** — Apply the learning loop additions (CandidateReviewLearningEventStore, CandidatePriors, recordCandidateLearningEvent, autoOCRPendingPages). These depend on CandidatePriorScorer.swift and CandidateReviewLearningEvents.swift which are already in HEAD.

2. **ContentView.swift** — Apply the `createFromMarkdown` addition. Check if `AppModel.newDocumentFromMarkdown()` exists; if not, add a stub.

3. **ContextualInspectorView.swift** — Apply the evidence card and ranked candidates changes. Depends on AppModel having `rankedActiveCandidates`.

### Phase B: Test and baseline adoption

4. Apply import order fix in signature-guard_test.mjs
5. Apply Chrome channel fix in toolbar_visual_regression_test.mjs
6. Apply updated baseline PNGs

### Phase C: Web app adoption

7. Apply all 15 web app file changes (React feature work)

### Phase D: Doc/tool adoption

8. Apply decision records, audit updates, tool fixes

### Phase E: Verification

9. `swift test` — must pass 252+ tests
10. `node Tests/web_reader_contract_test.mjs` — 51 checks
11. `node Tests/pdf_contract_parity_mutation_test.mjs` — 10 checks
12. `node Tests/web_editor_workflow_test.mjs` — self-contained pass
13. Build web app — no TypeScript errors

### Phase F: Benchmark regeneration (optional, deferred)

14. Run full test suites to regenerate benchmark JSONs
15. Regenerate corpus PDFs if needed

---

## 4. Risk assessment

| Risk | Mitigation |
|---|---|
| AppModel learning loop introduces runtime errors | Fails closed — learning errors don't block edits |
| ContentView markdown feature has no backing method | Check for method existence; add stub if missing |
| Web app changes break existing functionality | Verify with Playwright E2E suite |
| Stale benchmark JSONs cause test failures | Regenerate after adoption |

---

## 5. Doctrine citations

- **§6 (Semantic salvage):** Every piece of the stash is compared at the smallest meaningful semantic unit. Compatible improvements are integrated. Nothing is discarded by label.
- **§10 (Parallel work):** The stash exists because parallel sessions modified the same files. Recovery restores the useful work without discarding the current main's improvements.
- **§14 (Documentation):** Decision records and audit updates from the stash are adopted to keep the durable record current.
- **§3 (Proportional rigor):** Source changes get Tier 2 verification (swift test). Web changes get Tier 2 (Playwright). Benchmark regeneration is deferred.

---

*Recovery plan produced under PER-0926 (Product Evolution Architect) and PER-0428 (Doctrine Alignment Reviewer) lenses.*
