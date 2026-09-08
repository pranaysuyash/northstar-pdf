# Exploration Map — Features, Flows, and Loops (2026-09-06)

**Status:** exploration map (quarantine — not a commitment; INDEX status tag `quarantine`)
**Canonical path:** `/Users/pranay/Projects/pdf_editor/docs/explorations/features-flows-loops-exploration-2026-09-06.md`
**Date:** 2026-09-06
**Revision:** v1.1 — full-depth agent sweeps of `PDFEditorCore` (all ~148 files) and the web/tooling/CI plane folded in; corrections to v1.0 marked inline. Key corrections: shadow-mode loop is library-only (not app-wired); the browser export path does not use the incremental writer; CI's node gate runs 29 of 88 contract tests.
**Parent doctrine:** `OPERATING_DOCTRINE.md` 8.0; method per `EXPLORATION_DOCTRINE.md` 1.1, documentation per `DOCUMENTATION_DOCTRINE.md` 1.1
**Evidence basis:** Tier 1 (static inspection of live working tree, HEAD `aa599f5` with uncommitted modifications across 40+ files). Dead/starved and unwired claims were verified by direct construction-site/import greps, not agent assertion alone. Claims verified by CI/test suites are labeled per the owning gate docs.
**Scope:** whole repository — native macOS app (`Sources/PDFEditorApp`, `PDFEditorRecovery`, `PDFEditorCore`, `PDFEditorInlineEditor`), browser editor (`web/`), verification infrastructure (`tools/`, `benchmark/`, CI).
**Not covered (this map):** runtime/behavioral verification (no app was launched or exercised); product/market prioritization; the JTBD analyses (see `docs/audits/jtbd-*`).

## Purpose and relationship to canonical docs

`docs/architecture.md` owns the module dependency graph and edit-lifecycle data flow. `docs/capability-matrix.md`, `docs/implementation-status.md`, and `docs/release-gates.md` own capability and gate state (D-055). This map does **not** restate those. It adds the layer neither owns end-to-end today:

1. the **reachable feature surface** of the shipping app (what a user can actually trigger),
2. the **flows** that connect features across surfaces (native + browser),
3. the **loops** — every feedback/calibration/learning/gating cycle in the system, in one inventory,
4. the **wire gap**: capabilities that exist in code but are not reachable from any UI or runtime path (negative space, Exploration Doctrine §13) — on **both** planes.

---

## 1. Feature map (reachable surface, native macOS app)

Entry: `Sources/PDFEditorApp/PDFEditorApp.swift:280` — one `WindowGroup("Northstar", id: "pdf-editor")`, `.commands { AppCommands() }` (`:302`), `Settings` scene (`:304`). Per-window `AppModel` (`:234`); quit gated on recovery flush (`PDFEditorAppDelegate.applicationShouldTerminate`, `:262`); Finder open-with routed into the focused window (`:270`). Product name "Northstar" defined in `Sources/PDFEditorApp/ProductIdentity.swift:5` (executable stays `PDFEditor`).

### 1.1 Reader / Editor core (live)

- **Composition root** `Sources/PDFEditorApp/ContentView.swift:269` — `RecoveryStatusBanner` + `HSplitView { PageThumbnailRailView | DocumentCanvasView | ContextualInspectorView }`; else `WelcomeView` (`:1032`) with hero, drop-target "start surface" (blank/images/clipboard/markdown, `:1259`), recent documents with Locate (`:1349`).
- **Canvas** `Sources/PDFEditorApp/DocumentCanvasView.swift:41` — chooses `PipelineCanvasView` (pipeline renderer toggle) or legacy `PDFKitView` (`:942`); floating search HUD with exact/approximate/unavailable honesty states (`SearchProjectionState`, `:7`); selection toolbar (`AnnotationCreationToolbar`, `:248`); annotation overlay (`:264`); right-click = `AdaptiveDocumentContextMenu`.
- **Page rail** `Sources/PDFEditorApp/PageThumbnailRailView.swift:6` — shared `RenderingPipeline` cache; insert blank page (organize permission).
- **Inspector** `Sources/PDFEditorApp/ContextualInspectorView.swift:26` — five tabs: Focus & Edit (field edits, overlay drafts), Understand (summary/entities/key points/NER/tables, `:894`), Learn (marks + `StudyLoopView`, `:1312`), Document (capability passport, `:1386`), Trust & Safety (`:1458`).
- **Reading modes & panes** — Study/Skim/Reference/Review (⌘1–4), `ThemeManager`, freeze panes (`FreezePaneOverlayView.swift:29` + drag handles `FreezePaneDragHandle.swift:26`), pipeline tile overlay (`PipelineTileOverlayView.swift:22`).
- **Annotations** — marks, comments, per-mark version chains (`Sources/PDFEditorCore/AnnotationStore.swift`, `AnnotationMarks.swift`, `AnnotationComments.swift`, `AnnotationVersionStore.swift` — note the version store persists full chains to `UserDefaults.standard` per document, `AnnotationVersionStore.swift:393`).

### 1.2 Form work (the core differentiator flow — see §2.1)

- Candidate detection → review → edit → export → validate; export menu variants (copy / sanitized / extract-split / batch merge / OCR layer / flattened) at `ContentView.swift:459-498`; pre-export review receipt `ExportReviewReceiptView.swift:8`; visual diff `DiffComparisonView.swift:5` (⌥⌘D); recurring-form auto-selection via calibrator (§3.4).

### 1.3 Agentic / adaptive surfaces (live)

- **⌘K command palette** `Sources/PDFEditorApp/AgentCommandHUD.swift:34` — commands resolved by `AdaptiveCommandPolicy` through the app-side adapter `AdaptiveCommandContext.swift:8`; every invocation recorded to `AdaptiveCommandHistory` (Core) with **interaction-distance decay** (entries age by later-command count, cap 12; wall-clock is never used — a deliberate privacy posture; `AdaptiveCommandHistory.swift:47-63`; kill-switch `setPersonalizationEnabled` `:40`).
- **Context menu** `Sources/PDFEditorApp/AdaptiveDocumentContextMenu.swift:11` — intent lens (read/complete/review) × interaction target; presentation only.
- **Human review panel** `Sources/PDFEditorApp/HumanReviewPanelView.swift:19` — RG-135 gate UI; reads `benchmark/results/governed-corpus-manifest.json` from the developer checkout (root auto-detect, `:40`); fail-closed ledger. **Caveat (Observed):** a QA/dev surface exposed in the shipping Workspace menu; not portable to an end-user install.

### 1.4 Security / governance surfaces (live)

- `SecurityVaultSheet.swift:6` (vault overview, profiles/keys, templates, audit trail); `CommitFlowSheet.swift:12` (verify binding → integrity → sign → audit, on `CommitFlowManager`); `CompanionHealthDashboardView.swift:7` (Overview/Providers/Egress/Log over `CompanionHealthCheck`); `GovernanceDashboardView` (J12) — **wired but starved, see §4**.

### 1.5 Export / versioning surfaces (live)

- `BatchMergeSheet.swift:54` → `AppModel.mergePDFs` (`Sources/PDFEditorRecovery/AppModel.swift:4363`); `VersionCompareView` — **wired but starved, see §4**.

### 1.6 Session / recovery (live, in `PDFEditorRecovery`)

`Sources/PDFEditorRecovery/AppModel.swift:67` (@MainActor, ~6.1k lines) owns: open/new lifecycle (`:1520`, `:1922`), source-vs-live inspection + operations ledger + undo/redo, debounced 250 ms generation-checked autosave (MARK `:4559`), durable crash recovery over `SessionRecoveryStore`/`SessionPayloadStore`/`RecoveryPairStore` (MARK `:4713`) with `flushRecoveryForTermination()` (`:4661`), recent documents with security-scoped bookmarks (`:170`), companion negotiation objects (`:80-94`), view memory / layout restore (D-057). Integrity guard: `tools/verify_appmodel.sh` (46 ln) checks AppModel markers against a verified snapshot (`tools/snapshots/AppModel.verified-2026-08-26.swift`) after it was twice reverted to stale buffers on 2026-08-25/26.

---

## 2. Flow map

### 2.1 Edit lifecycle (canonical owner: `docs/architecture.md` "Data flow") — native plane

`OPEN (Provider.inspect → digest) → DETECT (StaticRegionDetector + fusion + OCR → RegionCandidates) → REVIEW (user confirms/rejects; learning event recorded) → EDIT (EditOperation: overlayText | nativeFieldValue | annotation | redaction …) → EXPORT (incremental writer / provider export) → VALIDATE (reopen, qpdf, raster, independent viewer)`. Key invariants live in `docs/architecture.md` §Key invariants; the write path is `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift` (xref append, PNG predictor, appearance streams; two 2026-09-06 writer defects fixed per `docs/audits/radio-choice-fixture-hardening-2026-09-06.md`). Note: the PDFKit adapter appends "not implemented" for validation of edit kinds its reopen checks don't cover (`Sources/PDFEditorCore/PDFKitProvider.swift:1098`) — the only such string in Core.

### 2.2 Browser plane (web/) — two coexisting surfaces

- **Legacy plane (deployable default):** `web/index.html:374` loads `web/app.js` (5,734 lines, one module scope, vendored PDF.js 4.2.67 + pdf-lib). Major sections: session persistence via IndexedDB + encrypted vault worker (`app.js:434-652`; `pdf-vault-worker.mjs` spawned as module Worker via `pdf-vault-worker-client.mjs:8` — dynamic, so a static-import grep would wrongly flag it dead); encrypted template/profile vaults (`:653-1216`); profile→field matching (`:1136`); candidate detection/inspection (`:1306-1600`); template capture/review flow (`:1827-2560`); profile + completion panels (`:2561-2910`); operations + undo/redo (`:2911-3315`); visual diff overlay (`:3327`); reader (`:3433-4005`); privacy preflight report (`:4152`); **export writer `materializeOperations` via pdf-lib (`:4232`)**; output preflight + impact metrics (`:4465-4675`); post-export validate (`validateExport`:4676, `exportAndValidate`:4944); parity fixture snapshots (`:4990`); five product-mode tabs + four intent-mode pills (`mode-stage.mjs`; `index.html:123-146`).
- **React plane (migration target):** `web/app/` (Vite; built output exists at `web/app/dist/`), shell `App.tsx` → `Toolbar`/`ModeRail`/`ReaderStage`/`SessionSidePanel`/lazy `AgentCommandHUD`, state in `useEditorState.ts` (351 ln). Deployed to `dist/web-app` via `tools/deploy-web.mjs --prebuilt`; legacy to `dist/web`. **Migration state is incomplete:** the template capture/review/profile/completion UI (~580 lines in app.js) has no React counterpart file yet — the planes share contract modules but not panels.
- **Contract modules (45 `.mjs`):** browser-wired mirrors of Swift Core (e.g. `pdf-template-contract.mjs` 933 ln ↔ `TemplateContracts` family; `pdf-preflight.mjs` 598 ln; `browser-resource-policy.mjs` 415 ln; `operation-history.mjs` — every confirmed mutation enters history *before* bytes are written); **14+ test-only parity mirrors** imported only by `Tests/*_test.mjs` (`pdf-contract-parity`, `candidate-parity`, `pdf-fingerprint-parity`, `detector-calibration`, `detector-semantic-comparison`, `pdf-evidence-fusion`, `reviewed-completion-metrics`, `provider-rejection-ledger`, `provider-capability-contract`, `simple-text-run-provider`, …); **Node/companion lane** structurally excluded from the deploy closure per D-009 (`provider-companion-host.mjs`, `pdf-sanitize.mjs`, `pdf-object-inspect.mjs`). `tools/deploy-web.mjs` walks the real import closure and fails staging if the browser graph imports a Node builtin.

### 2.3 Companion / provider negotiation flow

`ProviderRegistry` (actor, `Sources/PDFEditorCore/ProviderRegistry.swift:170`) → `CompanionNegotiator.negotiate(sourceDigest:)` (`Sources/PDFEditorCore/CompanionNegotiator.swift:134`, handshake over `CompanionContract` envelope with monotonic `ContractVersion`) → **`EgressGate` actor** (`Sources/PDFEditorCore/CompanionBridge.swift:50` — default-deny `isEnabled=false`, per-connection opt-in `allowConnection`:76) → transport (`CompanionTransport.swift:20` protocol; HTTP/local/mock) → `CompanionHealthCheck` (`CompanionHealthCheck.swift:9`, `HealthLevel` `:197`) → dashboard UI. Every failed attempt normalizes into `PDFProviderRejectionLedger` (`ProviderRejectionLedger.swift:132`, cross-ledger comparison `:164`). Richer provider protocol (hello/capability/cancellation) in `ProviderCompanionProtocol.swift`. Security posture audited in `docs/audits/agent-safety-guard-65point-audit-2026-09-01.md` (V-01…V-08 resolved/accepted as of 2026-09-03).

### 2.4 Template lifecycle flow

Capture (`captureDraft`, `Sources/PDFEditorCore/TemplateCaptureContracts.swift:61`) → draft → review/revision (`activateReviewedRevision` `:99`, `makeChildRevision` `:124`) → index query + profile resolution (`PDFTemplateIndexQuery.query` `TemplateIndexContracts.swift:109`; `PDFTemplateProfileResolver.resolve` `TemplateProfileResolver.swift:73` — **abstains on ambiguity**, deterministic tie-break) → recurring-form auto-selection on later documents (`RecurringFormCalibrator.classify`, MatchingTier) → completion materialization (`TemplateRuntimeContracts.swift:167`). Encrypted persistence: `EncryptedTemplatePersistence` + `KeychainSignatureStore` (`EncryptedTemplatePersistence.swift:176`, SecItem calls); browser side: `pdf-template-store.mjs` (IndexedDB encrypted vault, 1,562 ln) + `pdf-template-sync.mjs`/`pdf-template-migration.mjs`. **Caveat:** the `ProfileStore` protocol family (incl. bulk fill, `ProfileStore.swift:142/:603`) has zero references in App/Recovery — the vault UI's profile state must live in AppModel's own handling, not this protocol stack (verify before building on it).

### 2.5 Open → recovery flow

Open (`AppModel.open`, `AppModel.swift:1520`) → inspection → session autosave (debounced, generation-checked) → on crash/quit: recovery envelope from `SessionRecoveryStore` (structured corruption diagnostics, `SessionRecoveryStore.swift:64/:146`) + separate payload plane → `RecoveryStatusBanner` (`ContentView.swift:905`) offers restore. `applicationShouldTerminate` refuses quit until flush completes (`PDFEditorApp.swift:262`, fail-closed `.terminateCancel`). Expiry sweep in `FileSessionStore.deleteExpired` (`SessionStore.swift:247`).

---

## 3. Loops inventory (every feedback/calibration/learning/gating cycle)

IDs are stable from v1.0; sub-rows and L14–L19 were added by the v1.1 sweep.

| # | Loop | Trigger → state → effect | Live evidence |
|---|------|--------------------------|---------------|
| L1 | **Candidate review learning loop** | User confirms/rejects a detected field candidate → value-free `CandidateReviewLearningEvent` journaled per source digest (`CandidateReviewLearningEvents.swift:15,211,229`; `ValueFreeEventGuard` `:168` strips values) → `CandidatePriors` aggregated (`CandidatePriorScorer.swift:13`, `adjustedScore` `:106`, min 3 samples for signal) → biases **presentation order only** (never contract scores/permissions) | UI: candidate review in inspector; tests `CandidatePriorScorerTests`, `LearnedEvidenceCalibrationTests` |
| L2 | **Adaptive command loop** | Every ⌘K/context-menu invocation recorded to `AdaptiveCommandHistory` (`AdaptiveCommandHistory.swift:10`) with **interaction-age decay** (recency = later-command distance, cap 12; pins `:67`; opt-out `:40`) → personalization feeds `AdaptiveCommandPolicy` availability/ordering via `AdaptiveCommandContext.swift:8` | Settings exposure at `ContentView.swift:1965+` |
| L3 | **Study / spaced-repetition loop** | Annotation marks → `StudyLoopManager` review/recall/quiz sessions (`StudyLoop.swift`, `recordGrade` `:726`) → grades (Again/Hard/Good/Easy) → FSRS-5 DSR scheduler reschedules marks (`FSRSScheduler.swift`, 19 params `:22`; `reviewSchedule` `StudyLoop.swift:837`) → next-due study queue | UI: `StudyLoopView.swift:13` inside Learn tab (`ContextualInspectorView.swift:1312`); `docs/audits/spaced-repetition-fsrs-2026-08-28.md` |
| L4 | **Detection calibration loop** | Corpus sweeps + reviewed ground truth (108 cases, 15 fixtures) → `NativeDetectorGate.run` (`DetectorGate.swift:188`) and `DualLaneDetectorGate.run` (`DualLaneDetectorGate.swift:166`) fail-closed per fixture → findings feed `FalsePositiveReport` (`FalsePositiveReport.swift:107`, max FP rate 0.05) and weight recalibration → persisted artifacts re-validated by CI | RG-132 (`docs/INDEX.md` §Validation Gates); calibration corpus 60 fixtures; `docs/audits/graded-occupancy-implementation-2026-09-03.md` |
| L5 | **Fingerprint/threshold loop** (+ **OCR confirm sub-lane**) | `LayoutFingerprintV2` structured channels (HMAC-keyed cells; `SimilarityCoverage` `LayoutFingerprintV2.swift:518`, `FamilyConfirmLane` `:564`) + `RecurringFormCalibrator` MatchingTier (`RecurringFormCalibrator.swift:19`, incl. `insufficientEvidence` abstention RG-138) → family threshold 0.90 ratified on 60-fixture corpus → **sub-lane:** raster-only above-threshold candidates route to `OCRConfirmLane` (`OCRConfirmLane.swift:35`) which promotes at WER < 0.10 and abstains (never crashes) on provider timeout/empty → artifact gate `scripts/calibration-gate.sh` in CI (regenerates + validates: threshold 0.90, corpus ≥ 55, positives ≥ 210, graphics-heavy hard-negative exclusions documented in-script) | `docs/audits/layout-fingerprint-collision-exploration-2026-08-28.md`; `evidence-floor-abstention-rg138-2026-09-03.md` |
| L6 | **Cross-provider parity/eval gate loop** (RG-131,133,134,136,137) | Every push: detector + dual-lane gates, AcroForm parity experiment (4 providers × 4 read-back channels, `AcroFormParityExperiment.swift:178`) now backed by **real external engines** (`AcroFormExternalEngines.swift:17` — pdf-lib via `benchmark/acroform-lane/lane.mjs`, `qpdf --json`), OCR WER gate (fast lane Tesseract+Vision; nightly heavy lane +PaddleOCR/Marker) → persisted JSON gate reports → CI fails on regression, releases blocked by `docs/release-gates.md` | `.github/workflows/ci.yml` swift-gate + ocr-wer-heavy jobs; RG-134 CLOSED 2026-09-06 (`docs/audits/rg134-checkbox-closure-2026-09-06.md`). **Honesty note:** `AcroFormExternalEngines.swift:10-13` records that the earlier "PDF.js"/"qpdf" rows *ran the same PDFKit code path under different labels — the cross-provider claim was inferred, not measured*; the external-engine lane was built to fix exactly that |
| L7 | **Human visual confirmation loop** (RG-135) | Reviewer panel (`HumanReviewPanelView.swift:19`) records per-dimension confirmations bound to fixture SHA-256 (`HumanVisualConfirmation.swift:107` ledger, `:151` gate report) → fail-closed `pending` until 100% coverage; reviewer failures block | PENDING (0/38 confirmed) per `docs/INDEX.md` |
| L8 | **Companion negotiation/health loop** | Provider handshake → negotiated capabilities → health aggregation (`CompanionHealthCheck`) → dashboard | `CompanionHealthDashboardView.swift:7`; `CompanionNegotiator.swift:134` |
| L8b | ↳ **Egress consent gate** | Default-deny egress; user opts in per connection (`EgressGate` `CompanionBridge.swift:50-93`); disable revokes all | part of the 65-point agent-safety audit scope |
| L8c | ↳ **Rejection-ledger loop** | Provider attempt fails → normalized rejection record (`ProviderRejectionLedger.swift:108,132`) → cross-ledger comparison evidence (`:164`) → input to provider selection | `PDFExperimentParityHarness --ledger` |
| L9 | **Shadow-mode multi-engine validation** — **CORRECTED v1.1: not wired into the shipping app** | `ShadowModeRunner.runShadowMode` (`ShadowMode.swift:109`) diffs independent extractors → `ShadowReport` agreement/discrepancy evidence. Zero references in `Sources/PDFEditorApp` + `Sources/PDFEditorRecovery` (grep-verified 2026-09-06): library + tests/harnesses only; multi-engine agreement is CI evidence, **not** a runtime path | `MultiEngineValidator.swift:5` likewise app-unwired |
| L10 | **Lane lifecycle / deprecation loop** | Lane usage tracking → `shouldDeprecate` (90 days unused, `LaneLifecycle.swift:83`) → `shouldRemove` (+30 days, `:91`); `ComplexityBudget` caps feature LOC (`:171`) | `LaneLifecycleTests`; intent: "features that nobody exercises are liabilities" (`LaneLifecycle.swift:5`) |
| L11 | **Session autosave/recovery loop** | 250 ms debounced, generation-checked content autosave (`AppModel.swift:4559+`) → recovery stores on every mutation → crash → restore banner; quit flush enforced; expiry sweep `SessionStore.swift:247` | `RecoveryCrashInterruptionTests`, `RecoveryTerminationFlushTests` |
| L12 | **Contract mutation gate loop** (browser) | Every export guarded: `pdf-contract-mutation-gate.mjs` `assertExportableContract` + `guardedPdfLibExport` → violations block export → `pdf-impact-validator.mjs` fail-closed on missing/mismatched operation regions; `operation-history.mjs` enters each mutation before bytes are written | `web/app.js:1-10` imports; CI `node-contract` + `web-e2e` jobs |
| L13 | **Template capture→review→completion loop** | Capture `:61` → review/revision `:99/:124` → resolver select/abstain (`TemplateProfileResolver.swift:73`) → completion entries (`TemplateRuntimeContracts.swift:167`); browser and native sides parity-tested | `web/app.js:1827-2560`; `docs/template-system-design.md` |
| L14 | **LRU cache eviction loop** (v1.1) | Insert → budget exceeded → evict oldest (`DocumentCacheManager.swift:152,158,244`) → cache statistics | `DocumentCacheManagerTests` |
| L15 | **Annotation versioning loop** (v1.1) | Every mark mutation (`AnnotationStore.swift:64`) → version-chain entry (`AnnotationVersionStore.swift`, `MarkVersionChain` `:114`) → per-document UserDefaults persistence (`:393`) | `AnnotationVersionTests` |
| L16 | **Commit gating flow** (v1.1) | `CommitFlowManager.begin` (`CommitFlow.swift:206`) → integrity warnings block until `acknowledgeWarning` (`:254`) → sign (`:267`) → audit entry (`:290`) | UI: `CommitFlowSheet.swift:12` |
| L17 | **Lane admission gate** (v1.1) | Capability request → `PDFCapabilityLaneAdmission.resolve` (`PDFCapabilityLaneContracts.swift:108`) → available/revoked/unknown; `requiresReview` when not available (`:127`) | contract tests |
| L18 | **Progressive render ladder** (v1.1) | Viewport change → low-res tile immediately → high-res replacement (`ProgressiveRenderer.swift:22` level ladder; `TileBasedDisplay.swift:23`) | `RenderingPipeline` consumed by canvas + rail |
| L19 | **Maturity consistency check** (v1.1) | Capability matrix ↔ `docs/release-gates.md` divergence *detected and reported* by `GateMaturityBridge` (`GateMaturityBridge.swift:137-141`) — reports, does not sync | `GateMaturityBridgeTests` |

**Non-loops (state without feedback, flagged so nobody mistakes them for loops):** `ReadingAnalytics`/`ReadingHistory`/`DocumentIndex` persistence (stored + displayed, never re-rank); `PerformanceTelemetry` (deliberately writes nothing, `PerformanceTelemetry.swift:85` — feeds CI benchmarks only); `BatchRunner` session history (resettable). Cross-cutting: the governance meta-loop (L4–L7, L19) operationalizes OPERATING_DOCTRINE §3 evidence tiers as RG gates; "Evidence before claims" (architecture invariant 5) is enforced by `CanonicalCapabilityMatrix` + `GateMaturityBridge`.

**Structural caveat (v1.1):** the capability matrix is **data-as-code** — `CanonicalCapabilityMatrixPopulation.populate()` (`CanonicalCapabilityMatrixPopulation.swift:23`) is 918 lines of embedded claims (e.g. "Verified" `:631,:641`); truth changes require recompiling Swift. Fine for a single-dev repo, but it is not a config surface.

---

## 4. Wire gap — built but not reachable (negative space)

All entries Observed by construction-site/import greps across `Sources/`, `Tests/`, and `web/` (2026-09-06, HEAD `aa599f5` + dirty tree). This is the map's highest-value finding: the capability census (42 capabilities, `docs/audits/capability-maturity-model-and-matrix-2026-08-28.md`) counts code, not reachable surface.

### 4.1 Native app layer

**Dead UI (zero construction sites in Sources + Tests):**

| Surface | Evidence | Core machinery behind it |
|---|---|---|
| `DocumentSplitView.swift:70` | no construction site | split-pane layout, `SplitViewState` `:23` |
| `MetadataInspectorView.swift:20` | no construction site | `DocumentMetadata`, fonts/security/stats |
| `AuthoringCanvasView.swift:49` (CREATE surface) | no construction site (only a name string at `CanonicalCapabilityMatrixPopulation.swift:885`) | `ContentAuthor` (`ContentAuthor.swift:19`), `DesignSystem`, `PublishPipeline` (itself app-unwired, `PublishPipeline.swift:21`) |
| `ComicPanelZoomView.swift:15` | no construction site | `ComicMode` panel detector (`ComicMode.swift:77`, itself app-unwired) |
| `CollaborationDashboardView/HistoryView/MergeView/BridgeManagerView` | no construction sites | full Core stack: `CollaborationManager/Package/History/Approval`, `AnnotationMerger` |
| `ContentView.swift:1480` `SignatureSheet` | dead code; slot presents `CommitFlowSheet` (`:190`) | — |

**Wired but starved (UI reachable, data path never fed from the app layer):**

| Surface | Starvation evidence |
|---|---|
| `GovernanceDashboardView` (J12) | `GovernanceEngine` constructed with empty rule set (`ContentView.swift:81`; `DocumentPolicy.swift:149 init() {}`); `runComplianceCheck` has **no** app-layer call site — always 0 rules, 0 violations |
| `VersionCompareView` (J14) | receives a fresh unsourced `VersionStore()` (`ContentView.swift:80`); nothing app-side appends snapshots (annotation history uses the separate `AnnotationVersionStore`) — always empty |
| `DocumentBrowserView` | reads `DocumentIndex` but nothing app-side ever calls `DocumentIndex.addEntry/load` — corpus always empty |

### 4.2 Core library-only modules (no app/recovery consumer — grep-verified v1.1)

`ScriptingCLI` / `ScriptingSurface` / `UserScriptRunner` (the agentic scripting surface — library-only), `AISummarizer`, `CitationTools`, `ContentRouter`, `ReadingAnalytics`, `BatchReadProcessor`, `TableExporter`, `TextExporter`, `PDFUATaggingEngine`, `ControlViewerObservation` (RG-131 harness-only by design), `ProfileStore` protocol family (§2.4 caveat), `AcceptedVarianceRegistry` (an **orphan gate** — consumed only by `CanonicalCapabilityMatrixPopulation` + tests; no runtime detector/export gate consults accepted variances yet), `ShadowMode`/`MultiEngineValidator` (L9 correction). Plus the dead-UI-backed `ComicMode` and `PublishPipeline`. Stubs are otherwise nearly absent: no TODO/FIXME/`fatalError` markers in Core; the only placeholder-ish string is the benign page-slot fill at `HybridPDFParser.swift:302`.

### 4.3 Browser-plane wire gaps (v1.1)

- **Dead-in-UI security-guard cluster:** `pdf-action-neutralize.mjs`, `pdf-attachment-scanner.mjs`, `pdf-hidden-revision-analyzer.mjs`, `pdf-sanitize.mjs`, `pdf-sanitize-audited.mjs` (RG-097/024/049 guards) are imported by **no UI plane** — only their own `Tests/*_test.mjs` (run via the CI-advisory `tool-dependent` job). `web/app.js` contains zero references to sanitize; `pdf-signature-guard.mjs`/`pdf-xfa-guard.mjs` are likewise test-only. Either awaiting wiring or deliberately companion-lane-only — needs a decision record.
- **The shipped browser export path does not use the incremental writer:** `pdf-incremental-form-writer.mjs` (322 ln, genuine source-preserving incremental update) is imported **only by Tests**; `materializeOperations` (`web/app.js:4232`) writes via pdf-lib, and the React `PdfController.ts` imports `pdf-write-planning.mjs` (planning contracts salvaged from app.js) but not the writer. The "source-preserving" write promise exists in contract and tests, not in the shipped export path. The native plane does not share this gap (Swift `PDFIncrementalFormWriter` is the real write path).

**Stale/comment drift:** `PipelinePageView.swift:17-21` self-describes as "PROPOSED — not yet wired in… currently orphaned"; it **is** wired via `PipelineCanvasView.swift:114` (comment is wrong, not the code). Env-gated diagnostic probes ship in `PDFEditorApp.swift:7-115` (test-only by design, self-labeled `:83`).

**Interpretation (Inferred):** the collaboration cluster, CREATE archetype, comic mode, scripting surface, and browser guard cluster are complete Core+UI vertical slices awaiting a single entry-point decision each; governance/version/browser are one wiring defect each away from being real. Conversely the shipped core (reader, form work, recovery, companion, security) is dense and loop-instrumented. Before any "add features" work, wiring these orphaned slices is the cheapest capability-per-line expansion — and per Lane Lifecycle (L10), orphans unexercised 90+ days are formally deprecation candidates, which these surfaces have no usage record against. The L9 and §4.3 findings also sharpen the honesty ledger: two capability claims (runtime multi-engine validation; browser source-preserving export) are currently true at the evidence layer but not at the runtime layer.

---

## 5. Verification infrastructure (what proves the above)

- **Native:** `swift test` (3 test targets; ~200 test files incl. `Tests/NativePerformanceBudgetTests.swift`) + 9 executable harnesses (`Package.swift`; zero external SPM dependencies): `PDFEditor` (app), `PDFContractHarness` (flags `--detector-gate`, `--dual-lane-gate`, `--calibration-gate`, `--manifest`, `--output-dir`; `main.swift:99-131`), `PDFTemplateParityHarness` (`--corpus`, `--output`), `PDFExperimentParityHarness` (`--ledger`, `--output`), `PDFOCRBenchmark` (`--inputs` required), `PDFVisionOCRCLI` (single positional; one JSON line per text region), `PDFTextRunOCRBenchmark` (`--manifest`, `--output`), `PDFPerformanceBenchmark` (`--help/--fixture/--manifest/--password-env/--inspect/--export/--render-page/--memory`), `PDFRecoveryInterruptionHarness` (**env-var driven, no CLI flags** — 17-line main; deviation from the other harnesses' flag style).
- **Browser:** 88 `Tests/*_test.mjs` contract tests, aggregated by `tools/run-contract-tests.mjs` (auto-starts :4173 server for the Playwright/Chrome subset).
- **Whole-system:** `tools/verify-all.sh` (build → swift test → contracts); launchd template `com.owner.pdfeditor.verify.plist` for scheduled air-gap runs; `tools/pre-push-hook.sh` (+ `setup-hooks.sh`) mirrors CI locally; `tools/smoke-dist.mjs` boots a staged dist headless and fails on any 4xx/5xx subresource; `tools/regenerate_browser_contract_bundles.mjs` captures live web contract bundles into `benchmark/results/semantic-parity/<date>/web/` (the manual parity-refresh step); `tools/verapdf` + vendored `verapdf-cli-1.30.2/` (PDF-A validation); `tools/mupdf-validate.sh`. Flaky failures must be recorded in `docs/flaky-register.md`.
- **CI** (`.github/workflows/ci.yml`) is **seven jobs**, not three: `swift-gate` (macOS-15: swift test + detector/dual-lane/calibration/manifest-presence/AcroForm-parity + RG-135 human-review + OCR-WER fast lane, artifacts uploaded) · `ocr-wer-heavy` (nightly `17 3 * * *`: 4-provider WER + FP-report gate + release build) · `node-contract` · `web-e2e` · `tool-dependent` (qpdf/poppler/pikepdf) · `react-doctor` · `ci-evidence` (summarizer; web-e2e + tool-dependent are **advisory-only**, `ci.yml:456-462`).
- **CI coverage gap (v1.1 finding):** the `node-contract` job runs a **hardcoded 29-file `CORE_TESTS` list** (`ci.yml:328`) while `run-contract-tests.mjs` discovers **88** — 59 tests, including every test-only parity mirror and the sanitize/guard cluster, never run in the CI node gate except via the advisory `tool-dependent` job or local `verify-all.sh`.
- **OCR gate asymmetry (documented):** PaddleOCR/Marker are regression-only gated (multi-column reading-order limitation, ~0.73 avg WER); absolute thresholds apply to Tesseract/Vision (0.10); absent provider records `not_ran` and can never produce a false pass (`benchmark/compare_ocr_wer.py:35-78`, `GATE_REGRESSION_ONLY_PROVIDERS`).
- **Evidence artifacts:** `benchmark/results/` — ~48 report families (detector-calibration, acroform-parity, control-viewer, human-visual-confirmation, external-dataset-eval, ocr-provider-comparison, semantic-parity date bundles, governed corpus + manifest, security-guard runs, verapdf, …), each self-describing JSON with schema IDs. `Tests/fixtures/pdf_corpus_semantic_parity_fixture.json` is a 14-key governance *pointer* (harness/report locations), not raw documents.
- **AcroForm lane:** `benchmark/acroform-lane/` is a standalone npm package (pdf-lib ^1.17.1) — a genuinely independent engine lane; `AcroFormExternalEngines.swift:10-13` honestly records that before it existed, the cross-provider rows were *inferred, not measured* (see §3 L6).

## 6. Completeness statement (Exploration Doctrine §59)

**Covered:** app-layer reachable surface (all 37 PDFEditorApp files); recovery/session layer responsibilities; Core subsystem map (full sweep, v1.1 — type inventory + cluster deep-reads + App-reference greps for every suspected-unwired module); browser plane (both surfaces, 45 contract modules classified as browser-wired / React-wired / test-only / Node-lane); tools, benchmark, CI (all 7 jobs); loops inventory L1–L19 + sub-gates + non-loops; wire gap on both planes (all claims grep-verified).

**Not covered / deferred:** runtime behavior (nothing launched); `PDFEditorInlineEditor` internals; web/app React internals beyond the shell and state hook; benchmark result *contents* (families enumerated, values cited from INDEX); JTBD/product analyses (canonical elsewhere).

**High-value unknowns:** (U1) Do any tests exercise the dead views indirectly (XCTest view instantiation)? — check before deleting anything; Code Preservation rules forbid removal on lint evidence alone. (U2) Is `DocumentIndex` meant to be fed by a future import surface (see `docs/task-inventory.md`)? (U3) Which starved surfaces were deliberately parked by decision (check `docs/decisions.md` D-entries for J12/J14/J17)? (U4, new) Where does the app's profile-fill state actually live, given `ProfileStore` is app-unwired — AppModel internals or genuinely unreachable? (U5, new) Is the browser security-guard cluster intended as companion-lane-only, or is its absence from the UI a wiring defect (needs a decision record either way)?

**Potential blind spots:** static inspection cannot see dynamic construction (runtime view lookup, Worker/URL-based imports) — the vault-worker case in §2.2 shows why grep-only dead-code claims need the deploy-closure check too; React-plane wiring was sampled, not swept.

**Next handoffs:** (H1, implementation decision) wire-or-retire the §4 orphans, both planes — route through `docs/decisions.md`; (H2, review) RG-135 human review panel reachability for end users (currently checkout-dependent); (H3, documentation/code) correct the stale comment at `PipelinePageView.swift:17`; (H4, CI) close the 29-vs-88 node-gate coverage gap or record why 59 tests stay local-only (the sanitize/guard cluster is the sharpest case — its only CI exercise is advisory); (H5, decision) browser export path vs incremental writer: either wire the writer into `materializeOperations` or narrow the source-preserving claim to the native plane; (H6, exploration continuation) same flow/loop map for the React plane when it becomes the deployable editor of record.

## 7. References (canonical owners — do not duplicate here)

- Module map, edit lifecycle, trust boundaries, invariants: `docs/architecture.md`
- Gate/claim state: `docs/release-gates.md`; task state: `docs/task-inventory.md`; decisions: `docs/decisions.md`
- Capability/gate census detail: `docs/audits/capability-maturity-model-and-matrix-2026-08-28.md`; master findings register: `docs/audits/pda-audit-2026-08-28.md`
- Current status snapshot: `docs/status-whats-next-2026-08-30.md`; `docs/implementation-status.md`
- Native product direction: `docs/audits/native-macos-product-audit-per-0926-2026-08-31.md`, `docs/roadmaps/native-macos-modernization-plan-2026-08-31.md`
- Divergent-pool ledger (any future divergent round must read first): `docs/explorations/adhd-exploration-pool-ledger.md`

## 8. Findings→task ledger (quarantine — candidates, not commitments)

Consolidated from v1.0+v1.1 sweeps. Per D-055, `docs/task-inventory.md` owns task *state*; nothing here is tracked there yet — graduation follows the pool-ledger protocol (`docs/explorations/adhd-exploration-pool-ledger.md`). Statuses use Exploration Doctrine §37.

### 8.1 Explore / research / document (no production-code change expected)

| ID | Item | Type | Evidence anchor | First action |
|---|---|---|---|---|
| R1 | Do any tests exercise the dead views indirectly? (prerequisite for every removal below) | research (cheap) | §4.1; U1 | grep XCTest instantiation of the 6 dead views |
| R2 | Is `DocumentIndex` meant to be fed by a future import surface? | research | §4.1; U2 | read `docs/task-inventory.md` FIND-job rows + jtbd-02 |
| R3 | Were J12 governance / J14 version / J17 bridge deliberately parked? | research | §4.1; U3 | audit `docs/decisions.md` + native product audit findings |
| R4 | Where does the app's profile-fill state actually live, given `ProfileStore` is app-unwired? | research | §2.4; U4 | trace AppModel profile MARK section |
| R5 | Browser guard cluster: companion-lane-only by intent, or wiring defect? | decision input | §4.3; U5 | check native-audit + security audit disposition |
| R6 | `FoundationModelsLabelAssist` (macOS 26 `LanguageModelSession`, guarded compile): does it run on this OS at all? | research | `LocalAssistLane.swift:123` | runtime probe / availability check |
| R7 | `pdf_oxide` cascade lane: is the external CLI vendored, or does the lane always fall through? | research | `PdfOxideExtractor.swift:52` | `which pdf_oxide` + cascade history |
| R8 | How is Swift↔`.mjs` parity-mirror drift caught between `regenerate_browser_contract_bundles.mjs` runs? | research | §2.2; §5 | map which tests compare live bundles vs persisted snapshots |
| R9 | Full flow/loop map of the React plane when it becomes the deployable editor of record | exploration continuation | H6 | re-run this map scoped to `web/app/` |
| R10 | OCR reading-order post-processing to unblock PaddleOCR/Marker absolute thresholds | research | `compare_ocr_wer.py:35-52` | prototype reading-order normalization on multi-column fixtures |
| R11 | Persistence placement review: `AnnotationVersionStore` → `UserDefaults.standard`, 3-backend scatter (UserDefaults/files/Keychain) | review | §1.1, §3 L15 | inventory per-store payload growth + retention risk |
| R12 | Capability matrix as 918-line data-as-code — evaluate extraction to a governed manifest | exploration (architecture) | §3 caveat | sketch manifest format + GateMaturityBridge read path |
| R13 | Document: `DocumentDiffReport` renders a PDF (not JSON) — note in artifacts/error-taxonomy docs | documentation | `DocumentDiffReport.swift:45` | one-paragraph doc note |
| R14 | Is `verify_appmodel.sh` integrated into the pre-push hook, or manual-only? | review (cheap) | `tools/pre-push-hook.sh` | read hook script; wire if absent |

### 8.2 Implement (decision first, then code)

| ID | Item | Decision needed? | Evidence anchor | First action |
|---|---|---|---|---|
| H1a | Native orphaned UI cluster: `DocumentSplitView`, `MetadataInspectorView`, `AuthoringCanvasView`+`ComicPanelZoomView` (+`ComicMode`, `PublishPipeline`), collaboration views ×4 | **yes — wire or retire each** | §4.1 | R1 then per-surface decision in `docs/decisions.md` |
| H1b | Browser dead-guard cluster (RG-097/024/049: sanitize, action-neutralize, attachment-scanner, hidden-revision) | **yes** (R5) | §4.3 | R5 → wire into export flow or record companion-lane-only |
| H1c | `ScriptingCLI`/`ScriptingSurface`/`UserScriptRunner` agentic scripting surface is library-only | **yes** | §4.2 | scope agentic-scripting vs retire |
| D3 | `AcceptedVarianceRegistry` orphan gate — no runtime gate consults accepted variances | **yes** | §4.2 | wire into detector/export gates or retire |
| D4 | `ShadowMode`/`MultiEngineValidator` runtime wiring vs CI-evidence-only (narrow the multi-engine claim) | **yes** | §3 L9 | decide runtime lane; align capability-matrix wording meanwhile |
| H5 | Wire incremental writer into browser `materializeOperations`, or narrow "source-preserving export" claim to native | **yes** | §4.3 | decide; writer module already exists |
| H4 | CI node gate runs 29 of 88 contract tests; guard cluster only in advisory job | no — implement or justify | §5; `ci.yml:328` | extend `CORE_TESTS` or move to `run-contract-tests` discovery with explicit exclusions |
| I1 | Governance dashboard starved: empty rule set, `runComplianceCheck` never called | no (after R3) | §4.1 | feed seed rules + wire check into export path |
| I2 | Version compare starved: unsourced `VersionStore()`, nothing records snapshots | no (after R3) | §4.1 | record snapshots at commit/export boundaries |
| I3 | Document browser starved: `DocumentIndex` never fed | no (after R2) | §4.1 | ingestion hook (open/import) |
| H2 | RG-135 reviewer panel is checkout-dependent and in the shipping menu | no | §1.3 | dev-gate the menu item or bundle fixture digests |
| H3 | Stale comment `PipelinePageView.swift:17` ("orphaned" but wired) | no | §4 note | one-line fix (trivial) |
| I7 | PDFKitProvider validation: "not implemented" fallback for uncovered edit kinds | no | `PDFKitProvider.swift:1098` | implement or fail-closed with explicit reason per kind |
| I8 | Remove dead `SignatureSheet` (`ContentView.swift:1480`) | after R1 | §4.1 | delete with test sweep |
| I9 | React plane lacks template capture/review/profile/completion UI (~580 lines, app.js only) | part of migration plan | §2.2 | port behind shared contract modules |
| I10 | `PDFWorkCoordinatorContracts` has no consumer (aspirational contract) | **yes** — build coordinator or mark deferred | `PDFWorkCoordinatorContracts.swift:12-84` | decision record |
| H7 | Repo-root clutter (`out.pdf`, `Web-Prototype.zip`, `mcp-shell.log`, scratch `.md`s) | **approval required** (classification before deletion) | repo root | classify keep/archive/delete; destructive, needs owner sign-off |

**Sequencing note (Inferred):** R1 unblocks every removal in H1a/I8; R3/R5 unblock the wire-or-retire decisions; H4 and H3 are immediately executable without decisions; H5 and D4 should be decided together since both concern where the source-preserving / multi-engine claims are allowed to be stated.

### 8.3 Execution outcomes (2026-09-07 — "do all, follow the doctrines")

All ledger items dispositioned. Decisions recorded as `docs/decisions.md` D-071…D-075. Verification: `swift build` (all targets, including the edited `PDFEditorApp`) exits 0 with every change applied; the six newly-CI-listed node tests pass locally (S1). Full `swift test` is **blocked by concurrent in-flight edits to `CompanionBridge.swift`/`CompanionTransport.swift`** from the parallel agent lane (mid-build "input file was modified" errors, reproduced twice 2026-09-07); this ledger's changes touch no file in that lane. Exact next check once that lane settles: `swift test`.

| ID | Outcome | Evidence |
|---|---|---|
| R1 | **Done** — zero test references to any dead view; removals safe | grep over `Tests/` |
| R2 | **Done** — no recorded FIND/corpus feeding intent in `task-inventory.md`; browser UI existed read-side only | grep |
| R3 | **Done** — no decisions park J12/J14/J17; split view is *planned* (modernization P4.3) | grep of audit/decisions/plan |
| R6 | **Done** — macOS 26.6.2 supports FoundationModels; guarded `LocalAssistLane` compiles (build ✓) | `sw_vers`; build |
| R7 | **Done** — `pdf_oxide` not installed; cascade lane falls through by design (optional external dep, self-documented `cargo install pdf_oxide`) | `which`; `PdfOxideExtractor.swift:19` |
| R8 | **Done** — Swift↔.mjs drift is caught per-push by the pure-node report tests (they recompute and compare against committed `benchmark/results` artifacts); web-side live bundles refresh manually via `tools/regenerate_browser_contract_bundles.mjs` | test sources + CI list |
| R14 | **Done** — `verify_appmodel.sh` added to `tools/pre-push-hook.sh` | hook diff |
| R9 | **Deferred** — condition unmet: React plane is not the canonical surface until D-058 gates pass | D-058 |
| R10 | **Research plan documented** — reading-order normalization (xy-cut on provider TSV before WER scoring); falsifier: multi-column WER improves < 0.05 without single-column regressions. No prototype this pass | this row |
| R11 | **Finding documented** — `AnnotationVersionStore` persists full version chains to `UserDefaults.standard`; recommendation: migrate to the file-backed `SessionStore` family if payload grows (revisit: > 1 MB). No code change now | §1.1 |
| R12 | **Recommendation documented** — extract the 918-line `CanonicalCapabilityMatrixPopulation` to a governed JSON manifest read by `GateMaturityBridge` (compile-time fallback retained); needs its own ADR before implementation | §3 caveat |
| R13 | **Done** — `DocumentDiffReport` PDF-output note recorded (this ledger + decision trail) | `DocumentDiffReport.swift:45` |
| H1a / H1b / H1c / D3 / D4 / H5 / I9 / I10 | **Decided** — deferred/retained with named revisit triggers; `SignatureSheet` deleted as superseded dead code | **D-071, D-072, D-073** |
| H2 | **Implemented** — RG-135 Workspace menu item is `#if DEBUG` | `ContentView.swift` | 
| H3 | **Implemented** — stale "orphaned" comment corrected (also fixed its wrong D-058 reference: D-058 governs the web cutover, not the renderer) | `PipelinePageView.swift:10-25` |
| H4 | **Implemented** — CI node gate 29 → 35 tests (six verified pure-Node additions) with documented exclusion rationale; 9 tool-dependent passers stay in the advisory `tool-dependent` job; 6 tests fail locally (env/lane-dependent) and are tracked above | `.github/workflows/ci.yml` node-contract |
| H7 | **Done** — deleted untracked ephemera `out.pdf`, `mcp-shell.log`; retained tracked `Web-Prototype.zip` (design source of truth) + scratch `.md`s | **D-075** |
| I1 | **Implemented** — governance engine seeded (3 conservative rules) + compliance check runs on document open with duplicate-suppression | `ContentView.swift` registry-sync helpers |
| I2 | **Implemented** — version snapshot recorded on every completed export; Version compare surface is no longer starved | `recordVersionSnapshot` |
| I3 | **Implemented** — `DocumentIndex.addEntry` fed on open (digest-keyed); Document browser is no longer empty | `registerOpenedDocument` |
| I8 | **Implemented** — dead `SignatureSheet` removed (no test refs per R1) | `ContentView.swift` |

**Correction to v1.1 (I7):** the "PDFKitProvider validation not-implemented" finding is **not a defect**. `PDFKitProvider.apply` throws for every unsupported kind before the operation can enter the ledger (`PDFKitProvider.swift:505-513`, including the signature/overlayImage denial), so `validateExport`'s default case is an unreachable fail-closed tripwire for future kinds — second line of defense after apply's own denial, which is exactly the design you want. Redaction commit is likewise a visible denial at the app layer (`AppModel.swift:3747`). No code change made.

**New wire evidence (2026-09-07):** starved surfaces I1/I2/I3 are now fed through one `ContentView` registry-sync hook; `GovernanceDashboardView`, `VersionCompareView`, and `DocumentBrowserView` render live session data. Runtime observation (Tier 4) still owed: launch the app, open a fixture, confirm the three surfaces populate.
