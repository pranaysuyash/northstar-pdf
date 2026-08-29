# Implementation Plan — Persona Audit PDA-2026-08-28

**Scope note:** This plan is *requested output only*. It is **not authorized for execution** (the user asked to "work on the implementation plan," not to implement). Each phase specifies the evidence tier its exit gate requires so implementation can be done doctrine-compliantly later. Fixes to P0 defects require **S2** (failed-then-fixed); load-bearing invariants (sanitizer/redactor/parity/signature) require **S3** (mutation makes it fail).

**Sequencing principle (first-principles):** Phase 0 proves the dangerous P0s at runtime; Phase 1 installs the *capability/truth-status registry* that makes every later "Implemented/PASS" claim honest; Phases 2-9 collapse duplicates and wire enforcement; Phase 10 adds differentiators.

---

## Phase 0 — Reproduce P0 data-loss at runtime (Tier 2-3, safety)
- **Findings:** ENG-14 (sanitizer corrupts), ENG-15 (redactor corrupts whole file), ARC-17/18 (governance advisory-only → false safety).
- **Action:** Run `PDFSanitizer.sanitize` and `PDFContentStreamRedactor.redactStream` on 3 sample PDFs (text, hybrid, encrypted); diff byte/xref before/after; confirm corruption. Reproduce ARC-17 by opening a doc that should violate policy.
- **Exit gate:** S2 — a failing test that demonstrates corruption; document the exact byte/xref break. **Do not** "fix" by deleting the feature (No-Go salvage).
- **Owner:** engine + recovery. **Risk:** handle real user PDFs only in a sandbox copy.

## Phase 1 — CapabilityClaim + Truth-status registry (foundational)
- **Findings:** IMP-5, IMP-8, ENG-11/14/15/16/17/21/30, ARC-07/24, UI-05/07/18, DOC-07/08/23/24, EV-01/2.
- **Action:** New primitive `CapabilityClaim(id, label, evidenceTier:T0-5, sensitivity:S0-3, gate, owner, lastVerified)`. Every UI feature and doc claim references a claim ID. Release gates read claims; a gate cannot be PASS unless its claim's sensitivity assertion exists and passes.
- **Exit gate:** S3 — removing/lowering a claim's tier flips the dependent UI label and release-gate status (mutation-verified). **1P/LT/DOC = Y/Y/Y.**

## Phase 2 — Single document-model primitive
- **Findings:** ENG-03, ENG-04, ENG-05, ENG-07, IMP-1.
- **Action:** Demote `HybridPDFParser`/`PDFDocumentModel` to a thin importer; promote `PDFKitProvider.DocumentInspection` as the one model. Delete `ImprovedTextExtractor` synthetic bounds; delete duplicate `EntityRecognizer` (merge into `NERExtractor`).
- **Exit gate:** S2 — a test asserting no synthetic geometry/confidence is emitted; UI renders from the one model. **Y/Y/Y.**

## Phase 3 — Engine correctness (parsers, renderers, providers)
- **Findings:** ENG-01,02,06,08,09,10,11,12,13,16,17,18,19,20,23,25,26,27,28,29.
- **Action (principled, not band-aid):**
  - ENG-14/15: replace ASCII-rewrite with object-graph operation (or qpdf) preserving xref/byte offsets; intersect redaction with target rects. (S3)
  - ENG-17: real CMS/PKCS#7 verifier or relabel "byte-range digest check". (S2)
  - ENG-10: deliver progressive upgrades via completion/delegate. (S2)
  - ENG-12: parse PNG dims; validate `pdfium` CLI or drop. (S2)
  - ENG-26/27: fix string-literal `sessionID`/`generatedAt` bugs → real interpolation/`Date()`. (S2)
  - ENG-19/20/22/25: register real providers at startup; one capability enum; correct cascade comment or real `CascadeProvider`.
- **Exit gate:** S2/S3 per finding; no unverified claim remains in capability registry. **Y/Y/Y.**

## Phase 4 — Architecture contract consolidation (canonical-path rule §5)
- **Findings:** ARC-01,02,03,04,09,10,21,22,29,30; ENG-22.
- **Action:** One companion contract module (salvage `ProviderCompanionProtocol` capability-request shape — ARC-02 — into it before deleting the orphan). One version type. One session envelope. One capability enum. Remove `PART2_SENTINEL`. Route negotiation through `ContractValidation`.
- **Exit gate:** S2 — compile + a test that negotiation uses the single contract/version; no orphaned protocol compiled. **Y/Y/Y** (salvage on ARC-02).

## Phase 5 — Companion & Governance: salvage, don't delete
- **Findings:** ARC-05,06,07,08,12,17,18,19; IMP-2, IMP-3.
- **Action (No-Go lens — these are wanted capabilities):**
  - Companion: configure a real, consent-gated transport (XPC or stdin/stdout) with HMAC-verified handshake (fix ARC-07), or record an explicit D- decision "companion off by default, reason X" and mark `overallHealth` neutral when absent (ARC-08). Do **not** delete the companion.
  - Governance: call `runComplianceCheck` from open/import (ARC-17); critical violations block with operator override + audit entry (ARC-18). Do **not** delete the dashboard.
  - `LaneLifecycle` (ARC-19): feed real build metrics or remove (salvage budget concept into a build check).
- **Exit gate:** S2 — companion handshake verified end-to-end OR explicit D- decision archived; governance blocks on a seeded violation. **Salvage-aligned (?,?,Y).**

## Phase 6 — Unified, value-free persistence
- **Findings:** ARC-23,25,27,28.
- **Action:** One versioned persistence layer; default value-free; explicit consent for value-bearing fields (fix ARC-23 contradiction). Hash queries in `PrivacyAuditTrail` (ARC-27). Reconcile session envelope lineages (ARC-21/28).
- **Exit gate:** S2 — migration test from old schema; value-free default enforced by assertion. **Y/Y/Y.**

## Phase 7 — UI surfacing & decomposition
- **Findings:** UI-01..21.
- **Action:** Surface WCAG suite (UI-01) as always-on a11y differentiator; delete/salvage orphan views (UI-04/05/06/08/09 — salvage reusable inspectors before removal); extract monoliths (UI-11/12/13); introduce `EditorViewState` view-model (UI-14); fold freeze-pane/study-loop state into `AppModel` (UI-15/17); rename "Agent" → "CommandPalette" (UI-18); adopt `@Environment(AppModel.self)` (UI-16).
- **Exit gate:** S2 — UI compiles; a11y audit runs from UI; no orphan view compiled. **Y/Y/Y** (salvage on UI-04/05/06/08/09).

## Phase 8 — Evidence gates that fail
- **Findings:** TST-01,02,03,04,05,06,07,08,09,10,11; BM-01,02,03; EV-01,02,3,4.
- **Action:** Fix no-op mutation (TST-01) and tautology (TST-02) → real S3; committed performance baselines (TST-03); stop skipping parity test (TST-04); real fail-closed asserts (TST-05/6); remove `ZZDiagTests` (TST-07); add `assert.equal(totalUnexpected,0)` to parity reporter (TST-09, BM-01, EV-2); tier/S annotations on all suites (TST-10); honesty recount in release-gates (EV-1). Reuse `independent-preservation-validator.mjs` (BM-03) pattern repo-wide.
- **Exit gate:** S3 — a deliberate mutation of a load-bearing invariant makes the relevant test fail; parity reporter fails on unexpected divergence. **Y/Y/Y.**

## Phase 9 — Documentation canonicalization
- **Findings:** DOC-01..30.
- **Action:** `docs/INDEX.md` (canonical/supporting/archived); enforce D-055 single status authority (collapse/link the 6 status docs); unique decision IDs + renumber collisions (DOC-03/04/05); backfill owners/revisit (DOC-06); archive `proposed-architecture.md`, quarantine explorations (DOC-10/13/14); "proposed/strategy — not a commitment" banners (DOC-22); vendor `DOCUMENTATION_DOCTRINE.md` (DOC-21); per-feature evidence-tier tags (DOC-24).
- **Exit gate:** S2 — docs build an index check; a lint asserts no duplicate D-ID and that every "Implemented" bullet links a claim ID from Phase 1. **Y/Y/Y.**

## Phase 10 — Best-in-class differentiators (additions)
- **Findings:** recommendations §5 items 8-10.
- **Action:** a11y as product differentiator (UI-01 suite surfaced + reported); `AppModel` decomposed behind view-model; provenance integrity (ENG-26/27) feeding a traceability UI; capability registry exposed to users as a trust/shipping-transparency view.
- **Exit gate:** S2 — each differentiator has a test and a documented user value. **Y/Y/Y.**

---

## Cross-cutting gates (doctrine §15, must hold before any phase ships)
1. **Single source of truth** — no new duplicate model/contract/enum/status doc introduced.
2. **Truth status on every claim** — no "Implemented/PASS/validated" without a linked capability claim + passing assertion.
3. **Semantic salvage** — any deletion of a capability/dashboard/view first salvages the reusable child (No-Go lens).
4. **Evidence tiers** — P0 defect fixes S2; load-bearing invariants S3.
5. **No Git mutation without explicit approval** — this plan is documentation; implementation needs a separate, explicit user gate.

## Recommended execution order (dependency graph)
Phase 0 → Phase 1 → {Phase 2, Phase 3} → Phase 4 → Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 9 → Phase 10.
Phase 1 unblocks honest status for all later phases; Phase 0 protects users from the data-loss P0s first.

## Owners (proposed, to be confirmed by user)
- Engine/parsers/renderers: PDFEditorCore maintainer.
- Architecture/companion/governance: PDFEditorCore + Recovery leads.
- UI: PDFEditorApp lead.
- Tests/benchmark: QA/engineer owning release-gates.
- Docs: project documentation owner (per D-055).

## Open decisions requiring user input (separate gates)
 - D-? : Companion — real transport vs explicit off-by-default decision (ARC-05).
 - D-? : Governance — block vs advisory on critical violation (ARC-18).
 - Approval to implement any phase (only the plan was requested).

---

## Progress Log (execution started 2026-08-28, after user said "do all")

**Authorized by:** user instruction "then do all" (explicit approval for L1 implementation within audited scope; Git/production mutations still excluded).

**Done & verified (compile-level):**
- **ENG-26** — `Sources/PDFContractHarness/main.swift:278`: fixed string-literal `sessionID` (was `"native-(...)"`, now interpolated `"native-\(...)"`). Compiled (PDFContractHarness linked).
- **ENG-27** — `Sources/PDFContractHarness/main.swift:229,260`: replaced hardcoded `generatedAt: "2026-08-25T00:00:00.000Z"` with `Date().ISO8601Format()` in session-provenance + preflight builders. Compiled.
- **TST-02** — `Tests/PDFEditorCoreTests/ChaosEngineeringFaultInjectionTests.swift:79`: replaced tautology `#expect(boxes.isEmpty || !boxes.isEmpty)` with a real finite-geometry assertion (`Self.rectIsFinite` over mediaBox/rectangles/horizontalLines). Compiles (file-level; full test target blocked by pre-existing breakage below).
- **TST-09** — `Tests/pdf_contract_parity_test.mjs`: added `assert.equal(report.unexpectedMismatchCount, 0, ...)` so the parity gate fails closed on unexpected divergence (was print-only). Gate now fails until BM-01 divergences resolved — correct per S3.

**Done (documentation, no build needed):**
- **DOC-03** — `docs/decisions.md`: renumbered colliding `D-007` (contract envelope) → `D-056` and `D-010` (editor modes) → `D-057`, each with an alias note. No duplicate decision IDs remain.
- **DOC-01** — created `docs/INDEX.md` (canonical index + authority rule + status tags).
- **DOC-21** — vendored doctrine as `docs/DOCUMENTATION_DOCTRINE.md` (symlink → `../OPERATING_DOCTRINE.md`).
- **DOC-10** — `docs/proposed-architecture.md`: added ARCHIVED banner (superseded by decisions.md + D-055).
- **DOC-22** — `docs/market-strategy.md`: added explicit "PROPOSED — not a commitment" banner.

**Blocked / not yet done (honest boundary):**
- **Full `swift test` run could not complete**: the `PDFEditorCoreTests` module has a pre-existing compile error in an unrelated file (`TileCompositorTests.swift` references `NSImage` without `import AppKit`), and the working tree shows concurrent mtime churn ("input file modified during build"). My changed test file compiles past its own errors; the gate is blocked by sibling breakage, not my edits. Fixing sibling test files is Wave D/E scope, not this wave.
- **Full `swift build` fails on `PDFEditorApp`**: pre-existing breakage (`PipelineTileOverlayView` referenced but `currentDocumentData` missing; files modified mid-build). This is WIP in the dirty tree (101 dirty files) and pre-dates this engagement. Address in Wave D (UI dead/free-floating views).
- **Wave C (ENG-14/15 P0 data-loss)** not started: requires Phase 0 runtime reproduction on sample PDFs (no fixtures present; needs `qpdf`/byte-diff). A correct object-graph sanitizer/redactor cannot be verified in this session without that repro. Deliberately NOT faked.
- **Waves D/E (architecture consolidation, capability registry)** not started: large, behavior-changing, and unsafe to apply while the package doesn't build and the tree is churning.

**Next gates required:**
1. Stabilize the tree (resolve `PDFEditorApp` + `TileCompositorTests` pre-existing breakage) so `swift build`/`swift test` are green.
2. Phase 0: reproduce ENG-14/15 corruption on sample PDFs; then implement S3-guarded fixes.
3. Explicit user go-ahead to enter Waves D/E (architecture/UI consolidation), which touch contracts and views.

**Completeness statement:** ~5 of 127+8 findings have concrete edits in place; the remainder are planned, not implemented. This log reflects only verified or documentation-level changes — no finding is marked "done" without the evidence above.

---

## Progress Log #2 (2026-08-28, "keep going anyway")

**User directive:** proceed implementing findings against current files; accept that the
working tree is concurrently edited by another process (collisions reconciled as found).

**Done & verified:**

- **UI-04 / salvage (critique resolution):** Investigated the removal of untracked
  `PipelineTileOverlayView.swift`. The tiling/compositor capability was **not deleted** —
  it lives in `PipelinePageView` (canonical "intended sole renderer", tiling + progressive
  quality, PDFKit demoted to data source). Corrected the false "sole renderer" claim in
  `Sources/PDFEditorApp/PipelinePageView.swift` (now `PROPOSED`/aspirational, documents the
  outstanding integration). Recorded **D-059** (salvage + integration plan) in `decisions.md`.
  Used D-059 (not D-058) to avoid colliding with the existing React D-058 — exactly the
  DOC-03 defect class. This is the first-principles improvement: preserve the wanted
  primitive, kill the lie, plan the wiring.
- **ENG-12:** `Sources/PDFEditorCore/PDFiumRenderer.swift` — replaced hardcoded
  `width:0/height:0` (`// Would need to parse PNG header`) with real PNG IHDR dimension
  parsing (signature + big-endian width/height at bytes 16–23). Verified in full
  `swift build` (9.98s, green).
- **TST-01:** `Tests/PDFEditorCoreTests/PrivacyProvenanceMutationTests.swift` — MUT-PP-01 was
  a no-op (`#expect(throws: Never.self)` on a valid record, mislabeled "Invalid version").
  Rewrote as a real S3 mutation: tamper the integrity digest → expect
  `PDFSessionPrivacyProvenanceError.invalidDigest`. File **compiled** in `swift test`
  (test target module built past it).
- **DOC-02 / DOC-24:** `docs/implementation-status.md` — added D-055 status-authority banner
  (release-gates.md owns gate state) + evidence-tier legend (T0–T5).
- Re-verified earlier Wave A/B items compile (core + harness build green at 1.16s).

**Blocked by concurrent refactor (not my code):**

- Full `swift test` still cannot complete: the `PDFEditorApp` target is mid-refactor by the
  parallel editor and currently fails to compile — `AuthoringCanvasView.swift` references
  `ShapeProperties.fillOpacity` (removed) and `props.fillColor` is now optional. This is
  churn-induced, outside my stable surface; I did not guess-fix colliding app code.
- `ProviderCapabilityComparisonEngine.swift` (ENG-16) and `PDFImageExtractor.swift` (ENG-12
  original location) were renamed/moved by the churn; ENG-16 re-targeted/deferred.

**Stance:** improving the stable surfaces (PDFEditorCore, PDFContractHarness, docs/audits).
App-target findings (UI dead views, companion wiring, architecture consolidation) wait until
the concurrent refactor settles or are owned by the parallel editor to avoid edit collisions.

**Completeness statement (updated):** ~8 findings have concrete, verified-or-compiling edits
(ENG-12, ENG-26, ENG-27, TST-01, TST-02, TST-09, UI-04/D-059, DOC-01/02/03/10/21/22). The
remainder are planned; app-surface items are blocked by the live refactor, not by scope.
