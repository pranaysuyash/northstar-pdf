# Documentation Index (Canonical)

**Canonical owner of this index:** `docs/INDEX.md`
**Authority rule (D-055):** `release-gates.md` owns gate/claim state; `task-inventory.md` owns task state; `decisions.md` owns durable decisions. No other doc may assert gate "PASS"/"FAIL" or capability "Implemented" as primary truth.
**Truth-status rule (OPERATING_DOCTRINE §2):** claims are Observed / Verified / Inferred / Proposed / Unknown / Contested. A capability is "Implemented" only when a passing, tier-appropriate assertion exists (see `docs/audits/pda-impl-plan-2026-08-28.md` Phase 1).

## Canonical (source of truth)
- `docs/decisions.md` — durable product/evaluation decisions (D-001 … D-064; D-007/D-010 collisions renumbered to D-056/D-057).
- `docs/release-gates.md` — release-gate state (single authority per D-055).
- `docs/task-inventory.md` — task state (single authority per D-055).
- `docs/DOCUMENTATION_DOCTRINE.md` — vendored documentation doctrine (symlink to `../OPERATING_DOCTRINE.md`).
- `docs/implementation-status.md` — feature implementation status (must link a claim ID).
- `docs/audits/native-macos-product-audit-per-0926-2026-08-31.md` — current native macOS product audit, findings, evidence register, first-principles/long-term/doctrine alignment, and new-age interaction agenda.
- `docs/roadmaps/native-macos-modernization-plan-2026-08-31.md` — proposed native shell, session ownership, evidence surface, accessibility, spatial prototype, provider, and release sequence.
- `docs/decisions/adaptive-contextual-command-doctrine-2026-08-31.md` — focused decision record for direct-context contextual menus, bounded local ranking, stable recovery, and behavior-history research.
- `docs/decisions/native-product-naming-2026-09-05.md` — accepted working decision for Northstar as the user-facing native product name and PDFEditor as the retained technical workspace name.
- `docs/decisions/native-empty-state-toolbar-2026-09-05.md` — accepted working decision to hide the document toolbar until a PDF is admitted while retaining menu-bar and welcome-surface recovery paths.
- `docs/audits/native-macos-snapshot-2026-09-01.json` — value-minimized native audit boundary with branch/status, relied-on file hashes and mtimes, tool versions, and process/lock observation.
- `docs/decisions/export-output-disposition-recovery-2026-09-01.md` — proposed split between durable pre-export review receipts and post-export output identity/disposition recovery.
- `docs/decisions/native-beta-contract-2026-09-01.md` — proposed versioned native beta user jobs, non-goals, evidence thresholds, and promotion rules.
- `docs/decisions/document-session-ownership-matrix-2026-09-01.md` — proposed one-owner-per-fact matrix and safe extraction order for native document and view state.
- `docs/explorations/native-macos-visual-grammar-2026-09-01.md` — source-backed visual grammar, motion/illustration/infographic rules, explicit and implicit design task inventory, and home-surface implementation plan.

## Audits — Rendering Pipeline (2026-08-28)
- `docs/audits/rendering-pipeline-1st-principles-architecture-2026-08-28.md` — Pipeline-as-sole-renderer decision, PipelineCanvasView, PipelineTileOverlayView, architecture options and evidence.

## Audits — Calibration & Precision (2026-08-28)
- `docs/audits/recurring-form-calibrator-and-page-box-policy-2026-08-28.md` — 5-tier recurring form classification, canonical page-box precision/tolerance policy, 23 tests.
- `docs/audits/calibration-corpus-verification-2026-08-28.md` — real-corpus calibration run (13 tests), fingerprint-collision findings, FalsePositiveReport; **§8 V1→V2 migration** — calibration corpus moved to the V2 structured lane (`CorpusEntry.layoutV2`, V2-aware classify/calibrate, 0 V1 references), artifact corrected: navigation 0.900 `knownVariant` (V1 false-similarity) → 0.713 `noMatch` (V2 truth), 6/6 passed, 0 FPs/FNs, accuracy 1.0, suite 1322/1322 (14 tests). **§9 Expanded corpus (2026-08-30)** — 36 fixtures (was 30), F-5 weight renormalization for empty channels, separation gap 0.8418..0.9676, threshold 0.90 ratified, zero promotions.
- `docs/audits/accepted-variance-registry-2026-08-28.md` — 14-category native/web mismatch registry with tolerances, owners, falsifying tests (24 tests).
- `docs/audits/reviewed-candidate-ground-truth-measurement-2026-08-28.md` — 108-case reviewed ground truth (10 calibration + 98 sweep across all 15 form-bearing fixtures, all human-reviewed), native/browser precision/recall/abstention/label-agreement measurement, mjs v1.0 mirror + identity-fallback fix (21 tests).
- `docs/audits/layout-fingerprint-collision-exploration-2026-08-28.md` — first-principles analysis of the V1 fingerprint collision + false familyMatch; LayoutFingerprintV2 prototype (structured components, field-value masking, structured similarity); 3 new Observed findings (7 tests); **F-4 resolved** — per-page aligned similarity replaces pooled-cell Jaccard (geometry↔navigation text 0.824→0.355); **F-3 resolved** — family threshold recalibrated to **0.90** on a 36-fixture corpus with 233 positive / 397 negative pairs (measured gap 0.8418..0.9676), artifact `layout-v2-family-threshold-calibration-2026-08-28.json`; **Unification** — V2 cell channels keyed (HMAC, production) into `PDFTemplatePageSignature`, `make(layoutV2:)` + cell-aware `structuralScore` blend (legacy×0.85+cells×0.15, backward-compatible, browser-lane parity held), suite 1322/1322.
- `docs/audits/reviewed-candidate-ground-truth-measurement-2026-08-28.md` §9 — live native-vs-browser corpus report (15 fixtures, 98 cases, both lanes 1.0, deterministic artifact), fields-channel mapping finding, mjs FPR-null gate fix, egress-test fix, pre-existing parity findings.
- `docs/audits/reviewed-candidate-ground-truth-measurement-2026-08-28.md` §10 — automated detector gate (`NativeDetectorGate` + `PDFContractHarness --detector-gate`): live-pipeline measurement per fixture, fail-closed on unreviewed fixtures, exit-1 on regression, persisted self-describing report (7 gate tests, suite 1312/1312).
- **Dual-lane detector gate** (`DualLaneDetectorGate` + `PDFContractHarness --dual-lane-gate`): runs both native and browser lanes against the same reviewed 108-case ground truth on every corpus sweep; per-fixture scoping, fail-closed on unreviewed, exit-1 on regression (6 gate tests, suite 1329/1329).
- **Per-fixture candidate scoping** in `DetectorSemanticMeasurement.measure(fixtureID:)`: filters ground truth cases to only the named fixture, preventing pooled-lane cross-matching where identical base-form rects from different fixtures cross-match.
- `docs/audits/generator-manifest-name-vs-structure-audit-2026-08-28.md` — audit of remaining generator-manifest-derived expectations for name-vs-structure inference errors; no remaining errors found; stale manifest artifact identified (12/14 fixtures lack field-presence expectations).
- **CI calibration artifact gate** (`.github/workflows/ci.yml`): after `swift test` regenerates the persisted artifacts, a Python gate verifies both `recurring-form-calibration-report-2026-08-28.json` (schema, familyThreshold 0.90, 0 false positives, accuracy 1.0) and `layout-v2-family-threshold-calibration-2026-08-28.json` (familyThreshold 0.90, minPositive > 0.90, maxHardNegative < 0.90). Fails the job on regression; local verification confirmed pass.

## Audits — Raster Weight Analysis (2026-08-30)
- `docs/audits/raster-weight-analysis-2026-08-30.md` — raster weight analysis: SNR 799×, re-encoding noise caps practical weight. Updated 2026-09-01: raster weight = 0.24 (12× increase from 0.02). Projection profiles (95%) + edge detection (3%) + structural occupancy (2%). Calibration gap 0.9723..0.9017. Weight sweep tested 5 blends from 50/25/25 to 95/3/2.

## Audits — Content-Invariant Raster Extraction (2026-08-31)
- `docs/audits/content-invariant-raster-extraction-2026-08-31.md` — projection profiles unlocked 12× weight increase (0.02→0.24). Edge detection and structural occupancy wired at minimal weight (5% combined) because cell-level operations add rendering noise. Region-based extraction (flood-fill) also implemented. 44-fixture calibration corpus.
- `docs/audits/blend-sweep-binding-constraint-analysis-2026-09-03.md` — graded occupancy (cosine similarity) fixes the binding constraint: all 19 raster weight configurations now pass (0.02–0.20), gap improved from 0.045 to 0.44. **Updated 2026-09-08:** the 85/8/7 blend-sweep row itself now passes (0.9104, zero evidence promotions) via multi-scale graded occupancy (16/64pt), raster-only-page exclusion from cell channels, and rotation-aware geometry — pinned permanently by `RasterBlendCalibrationGateTests` (RG-139). **CI wiring 2026-09-11:** RG-139 is enforced on every push (fresh suite run → report validated in CI → `raster-blend-gate` artifact); see docs/release-gates.md RG-139. **Corrected 2026-09-18:** the wiring is verified implemented and the gate suite passes in-run on CI runners (274.4s in run 35200795630), but the dedicated CI step has not yet executed — blocked upstream (calibration-gate.sh evidence-floor mismatch 09-15→09-17; Swift-test semaphore-bound 09-18). **Upstream fix landed** (`c2eb7fa`: gate `maxHardNegativeWithEvidence`, raw max info-only; verified end-to-end green + S2 locally 2026-09-18) — step execution receipt still pending a CI run containing that commit. Full ledger in `docs/audits/rg139-ci-wiring-and-runner-portable-corpus-paths-2026-09-18.md`.
- `docs/audits/ocr-confirm-lane-withtimeout-crash-fix-2026-09-08.md` — EXC_BREAKPOINT crash in `OCRConfirmLane.withTimeout` under load (dynamic exclusivity violation on the captured result box) fixed; timeout degrades to abstention, never a torn read.
- `docs/audits/graded-occupancy-implementation-2026-09-03.md` — **Addendum 2026-09-08:** the original 4pt/0.15-scale graded occupancy was degenerate (single pixel sample per cell — binary in disguise); reworked to 16/64pt cells on a 0.5-scale render, genuinely fractional (falsifier in `RasterBlendCalibrationGateTests`).
- `docs/audits/graded-occupancy-implementation-2026-09-03.md` — implementation details: GradedCell struct, extractGradedOccupancy, cosine similarity, backward compatibility.

## Audits — Radio & Choice Fixture Hardening (2026-09-06)
- `docs/audits/radio-choice-fixture-hardening-2026-09-06.md` — 8 radio fixtures (varied export vocabularies, hierarchical names, degenerate fail-closed cases) + 7 choice fixtures with real `/Opt` arrays (string, pair, numeric, hierarchical, combo, empty-selection). Measured engine semantics: pdf-lib maps `/Ch` to PDFDropdown (combo bit) vs PDFOptionList (listbox) — lane now covers both; pair-form `/Opt` viewer-facing strings (PDFKit widgetStringValue, pdf-lib select) vs structural export `/V` documented. Fixed 2 writer defects: same-object edit coalescing in `incrementalFieldUpdate`, stale-index insertion in `insertIntoDict`. 48 tests green across radio + choice + writer + parity suites.
- `docs/audits/choice-opt-lane-fix-2026-09-06.md` — falsified the "PDFKit choice = unsupported" gate row: the experiment wrote /Ch via `buttonWidgetState` (a /Btn-only API that no-ops on /Ch and /Tx) with spec-invalid values outside /Opt. Fix: /Opt-derived targets via structural parse, production `widgetStringValue` write, structural + qpdf read-back. Gate report: choice 0/12 → 11v/0f confidence 1.00 production-ready; text regression also repaired (0/12 → 10v/2f). Corpus now 40 fixtures incl. all 7 /Opt fixtures.

## Audits — Capability Governance (2026-08-28)
- `docs/audits/capability-maturity-model-and-matrix-2026-08-28.md` — 5-dimension maturity model, 42-capability canonical matrix with real providers/gates/owners, gate-maturity bridge (35 tests).

## Audits — OCR Benchmark (2026-08-31)
- `docs/audits/ocr-benchmark-expansion-2026-08-31.md` — 8 ground-truth fixtures (scans, noise, rotation, low-contrast, dense, small-font, punctuation, multi-column), Tesseract 5.5.0 baseline (1.2% avg WER), PDFKit baseline (no OCR on raster PDFs), cross-provider comparison, 14 tests.
- `docs/audits/ocr-cross-provider-benchmark-2026-08-31.md` — Cross-provider WER benchmark: Apple Vision (0.0% WER, 2.2s), Tesseract (0.2% WER, 2.0s), PaddleOCR PP-OCRv6 (9.1% WER, 19.2s). 9 fixtures × 3 providers, 22 Swift tests, Python benchmark script, Vision CLI tool.
- `Sources/PDFVisionOCRCLI/main.swift` — Apple Vision OCR CLI (registered SwiftPM executable target `PDFVisionOCRCLI`). Outputs JSON lines per text region; used by `VisionProvider` in `compare_ocr_wer.py`. Built via `swift build --product PDFVisionOCRCLI`.

## Audits — Creator Archetype (2026-08-28)
- `docs/audits/creator-archetype-implementation-2026-08-28.md` — AuthoringCanvasView (CREATE), DesignSystem (DESIGN), PublishPipeline (PUBLISH), 23 tests.

## Audits — UNDERSTAND Layer (2026-08-28)
- `docs/audits/understand-enhancements-2026-08-28.md` — DocumentSummarizer, EntityRecognizer, KeyPointExtractor, TableExtractor, rule-based extraction.

## Audits — Companion System (2026-08-28)
- `docs/audits/companion-health-dashboard-and-transport-2026-08-28.md` — Health dashboard, transport layer, lifecycle wiring, thread safety fixes.

## Audits — Spaced Repetition (2026-08-28)
- `docs/audits/spaced-repetition-fsrs-2026-08-28.md` — SM-2 algorithm, integration with LEARN study loop, 8 tests.

## Audits — Reading UI (2026-08-28)
- `docs/audits/reading-modes-dark-mode-freeze-panes-tile-overlay-2026-08-28.md` — Study/Skim/Reference/Review modes, ThemeManager, freeze panes, tile overlay.

## Audits — JTBD Analyses
- `docs/audits/jtbd-01-read-first-principles-2026-08-26.md` — READ job 5W1H analysis
- `docs/audits/jtbd-01-read-expanded-analysis-2026-08-26.md` — 22-dimension expanded READ analysis
- `docs/audits/jtbd-01-read-layouts-and-modes-2026-08-26.md` — Layout modes (freeze panes, split view, content-routed)
- `docs/audits/jtbd-01-read-who-and-how-2026-08-26.md` — Sub-job weighting by user type
- `docs/audits/jtbd-01-read-technical-approaches-2026-08-26.md` — Technical approaches for READ
- `docs/audits/jtbd-01-read-gap-analysis-implementation-2026-08-26.md` — Gap analysis with priority scoring
- `docs/audits/jtbd-02-find-expanded-analysis-2026-08-26.md` — FIND job analysis
- `docs/audits/jtbd-03-understand-expanded-analysis-2026-08-26.md` — UNDERSTAND job analysis
- `docs/audits/jtbd-03-learn-expanded-analysis-2026-08-27.md` — LEARN job analysis
- `docs/audits/jtbd-04-interact-expanded-analysis-2026-08-26.md` — INTERACT job analysis
- `docs/audits/jtbd-05-share-expanded-analysis-2026-08-26.md` — SHARE job analysis
- `docs/audits/jtbd-06-protect-expanded-analysis-2026-08-26.md` — PROTECT job analysis
- `docs/audits/jtbd-18-annotate-expanded-analysis-2026-08-27.md` — ANNOTATE job analysis
- `docs/audits/jtbd-19-collaborate-expanded-analysis-2026-08-27.md` — COLLABORATE job analysis
- `docs/audits/jtbd-creator-archetype-create-design-publish-2026-08-28.md` — Creator archetype analysis
- `docs/audits/jtbd-creator-archetype-expanded-analysis-2026-08-27.md` — Creator expanded analysis
- `docs/audits/cross-jtbd-unified-roadmap-2026-08-26.md` — Unified roadmap across all JTBDs

## Audits — Personas & Models
- `docs/audits/personas-jobs-expanded-model-2026-08-26.md` — Expanded persona × job model
- `docs/audits/full-persona-audit-2026-08-26.md` — Full persona audit
- `docs/audits/pdf-reader-jtbd-first-principles-2026-08-26.md` — Reader JTBD first principles
- `docs/audits/analytical-framework-expanded-5w1h.md` — 22-dimension analytical framework

## Audits — Library Evaluation
- `docs/audits/pdf-features-library-matrix-2026-08-26.md` — Feature × library matrix
- `docs/audits/pdf-libraries-complete-evaluation-2026-08-26.md` — Complete library evaluation
- `docs/audits/pdf-libraries-permissive-evaluation-2026-08-26.md` — Permissive-only evaluation (28 libs)
- `docs/audits/pdfbox-mupdf-bakeoff-evidence-2026-08-31.md` — PDFBox versus MuPDF preservation, licensing, packaging, and recovery bake-off
- `docs/audits/browser-preexport-privacy-transition-evidence-2026-08-31.md` — browser pre-export and staged-output privacy transition gate for metadata, attachments, actions, encryption, and privacy-sensitive content
- `docs/audits/pdf-library-evaluation-2026-08-26.md` — Library evaluation
- `docs/audits/pdfkit-adequacy-audit-2026-08-26.md` — PDFKit adequacy assessment
- `docs/audits/pdfkit-known-bugs-2026-08-26.md` — PDFKit known bugs

## Validation Gates
- **RG-131: Control-viewer observation pre-release gate** (`Sources/PDFEditorCore/ControlViewerObservation.swift`, `Tests/PDFEditorCoreTests/ControlViewerObservationGateTests.swift`). Batch dual-engine (PDFKit + Poppler) observation of the 38-fixture / 14-document-class governed corpus: reopen, rotation, visual fidelity, form visibility, text readability. Fails closed on any fixture failure. Writes `benchmark/results/control-viewer-gate-report.json` as CI artifact (ISO-8601 timestamps as of 2026-09-06). Wired into `docs/runbooks/release-gates.md` §7 as a mandatory pre-release step — version bumps require `gatePassed == true`. Gate is `PASS` (38/38 on 2026-09-06 artifact); remaining: human visual confirmation (RG-135) and broader real-world corpus.
- **RG-132: LayoutV2 family-threshold calibration artifact** (`Tests/PDFEditorCoreTests/LayoutFingerprintThresholdCalibrationTests.swift`). Persisted JSON artifact at `benchmark/results/detector-calibration/layout-v2-family-threshold-calibration-2026-08-28.json`. Corpus: 44 fixtures, 211 positive, 735 hard-negative pairs. Threshold: 0.90. CI regenerates and validates on every push via `scripts/calibration-gate.sh`.
- **RG-133: AcroForm cross-provider parity experiment** (`Sources/PDFEditorCore/AcroFormParityExperiment.swift`, `Tests/PDFEditorCoreTests/AcroFormParityExperimentTests.swift`). Write-reopen-read round-trip on 40 corpus fixtures (9 base + 8 radio + 13 checkbox + 7 choice + producer variants) across 4 providers (PDFKit, IncrementalWriter, pdf-lib Node, qpdf CLI) with four independent read-back channels. Results (2026-09-06 gate report): **checkbox 1.000** (all providers production-ready — PDFKit 23v/0f, pdf-lib 22v/0f), **choice 1.000** (all production-ready), **text 1.000** (all production-ready), **radio 0.938** (pdf-lib 16v/0f production-ready; PDFKit experimental — its annotation API omits group `/V` on save; IncrementalWriter experimental — compressed/no-AcroForm sources refused fail-closed). Gate report at `benchmark/results/acroform-parity/acroform-parity-gate-report.json` (regenerated 2026-09-06 19:34Z on the post-multiselect binary — identical numbers, no regression from the dict-editor removal semantics). The 7 generated `/Opt` choice fixtures are guarded corpus members: a composition test (`generatedChoiceFixturesInCorpus`) fails if any leaves the corpus, and choice provider floors (≥16 verified per write lane, ≥8 qpdf verifier) fail the suite if the real `/Opt` coverage stops measuring.
- **RG-134: AcroForm parity release blocker** (`docs/release-gates.md` RG-134). **CLOSED 2026-09-06 — `PASS`, resolved by fix, not exclusion.** The "PDFKit drops checkbox values" premise was falsified — the 3 failing fixtures were measurement artifacts (wrong write API, hardcoded Yes/Off expectations, leading-slash tokens); checkbox is now production_ready on every provider with aggregate round-trip 1.000 (re-measured 20:03Z with all 13 generated vocabulary fixtures as guarded corpus members — composition guard, per-lane floors ≥22 verified, ≥0.9 confidence bar asserted in the suite). Full falsification record + 10 root causes (incl. two genuine production defects: orphan page-annot widgets invisible to `walkAcroForm`, `/Opt`-mapped radio state resolution) in `docs/audits/rg134-checkbox-closure-2026-09-06.md`.
- **Multi-select listbox pipeline (2026-09-06)** — extension of the choice pipeline to `/Ff` bit 22 (2097152) fields with array `/V` + `/I`. Structural decode (`FormObjectNode.isMultiSelect/.values/.selectedIndices`), `resolveMultiSelectEditPlan` mirroring pdf-lib's measured three shapes (multi = array `/V` + sorted `/I`, singleton = scalar `/V` + `/I` removed, empty = both removed), fail-closed refusals (out-of-vocabulary, multi-write to single-select — no silent `/Ff` upgrades), real key removal in `insertIntoDict`, `choice_multi` lane type, 5 new fixtures (`listbox_multi_*.pdf` + single-select negative control), 9-test round-trip suite incl. a PDFKit array-`/V` read-limitation drift canary. Evidence: `docs/audits/multiselect-listbox-pipeline-2026-09-06.md`.
- **RG-135: Human visual confirmation pre-release gate** (`Sources/PDFEditorCore/HumanVisualConfirmation.swift`, `Sources/PDFEditorApp/HumanReviewPanelView.swift`, `Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift`). SwiftUI reviewer panel records per-dimension confirmations bound to fixture SHA-256 digests; ledger + gate report persist at `benchmark/results/human-visual-confirmation/` and upload as CI artifacts. Fail-closed: `pending` until every governed fixture is human-confirmed against current bytes; reviewer-recorded failures block CI. Wired into `docs/runbooks/release-gates.md` §8 as a version-bump blocker (2026-09-08): a version bump must not run while RG-135 is not `PASS`, enforced via the §9 release-disposition hard-blocker list. Reviewer pass tracking CLI: `swift run PDFReviewStatus [root] [--write-report]` (2026-09-08) prints the per-fixture review table + gate status, exits 2 on `fail`. Current state: PENDING (0/38 confirmed).
- **RG-136: Cross-provider OCR WER regression gate** (`benchmark/compare_ocr_wer.py --gate`, `Tests/PDFEditorCoreTests/OCRWerGateTests.swift`). Fast lane (Tesseract + Apple Vision) on every push; heavy lane (all four providers — Tesseract, Vision, PaddleOCR, Marker) nightly + manual dispatch. Baseline (re-generated 2026-09-11 with reading-order post-processing in the PaddleOCR lane, 8 fixtures): Tesseract 0.0024, Vision 0.000, **PaddleOCR 0.0179** (was 0.1091; multi-column outlier 0.7297 → 0.0000), Marker 0.0157 avg WER. Fails on regression beyond +0.05 tolerance or the 0.10 absolute threshold; PaddleOCR now carries the absolute threshold (regression-only classification completed per the gate config's documented intent), Marker remains regression-only (residual WER is markdown-conversion design). Receipt: `docs/audits/ocr-cross-provider-benchmark-2026-09-01.md` §2026-09-11 addendum. Absent providers are provenance (`not_ran`), never a false pass. CI uploads baseline, gate report, and cross-provider report as artifacts.

## Audits — Quality & Security
- `docs/audits/pda-audit-2026-08-28.md` — Master findings register (127 explicit + 8 implicit)
- `docs/audits/pda-runtime-ledger-2026-08-28.md` — Chat/process evidence trail
- `docs/audits/pda-impl-plan-2026-08-28.md` — Phased implementation plan
- `docs/audits/independent-adversarial-review-per-0206-2026-08-26.md` — Independent review
- `docs/audits/spaced-repetition-algorithm-exploration-2026-08-28.md` — SM-2/FSRS exploration
- `docs/audits/signature-extraction-native-capabilities-2026-08-26.md` — Signature extraction
- `docs/audits/structural-independence-review-2026-08-26.md` — Structural independence
- `docs/audits/priority-score-rederivation-2026-08-27.md` — Priority score rederivation
- `docs/audits/native-web-parity-analysis-2026-08-26.md` — Native/web parity

## Audits — Earlier (pre-2026-08-28)
- `docs/audits/doctrine-alignment-audit-per-0428-2026-08-26.md` — Doctrine alignment
- `docs/audits/repository-audit-2026-08-26-continuation.md` — Repository audit continuation
- `docs/audits/comprehensive-findings-tasks-and-first-principles-audit.md` — Comprehensive audit
- `docs/audits/session-2026-08-26-comprehensive.md` — Session comprehensive
- `docs/audits/chaos-engineering-and-fault-injection-audit-per-pl2-0035.md` — Chaos engineering
- `docs/audits/encrypted-vault-security-audit-2026-08-26.md` — Encrypted vault security
- `docs/audits/full-fidelity-open-items-evidence-2026-08-25.md` — Full fidelity open items
- `docs/audits/exploration-closure-evidence-2026-08-24.md` — Exploration closure

## Design (current)
- `docs/architecture.md`, `docs/design-implementation-map.md`, `docs/design-system-specimen.md`, `docs/intent-mode-design.md`, `docs/provider-capability-system-design.md`, `docs/template-system-design.md`, `docs/codesign-notarize-workflow.md`.

## Proposed / Strategy — **not a commitment**
- `docs/proposed-architecture.md` — **ARCHIVED**: superseded by `decisions.md` + D-055; kept for history only.
- `docs/market-strategy.md` — proposed research synthesis; not a product approval.

## Explorations (quarantine — not a commitment)
- `docs/explorations/adhd-exploration-pool-ledger.md` — durable ledger of ALL ADHD divergent pools on this repo: Round 1 (2026-08-24, 30 ideas, per-idea statuses + follow-through snapshot incl. graduated G4 save/resume and landed ProfileStore) and Round 2 (2026-08-30, 29 idea slots with restored rationales, lifecycle statuses, 15 deepening child ideas); future-round ban list, status grammar, and graduation protocol into task-inventory. Any new divergent round must read it first and append its pool.
- `docs/explorations/features-flows-loops-exploration-2026-09-06.md` — whole-repo exploration map, v1.1 (Tier 1 static, HEAD aa599f5 + dirty tree; full-depth Core + web/CI sweeps): reachable native feature surface, native + browser flows (two web planes, 45 contract modules classified), loops inventory L1–L19 + sub-gates (learning, adaptive-command, FSRS study, calibration + OCR confirm lane, RG gate/eval family, companion health + egress/rejection sub-gates, shadow-mode [corrected: library-only], lane lifecycle, autosave/recovery, contract-mutation, template lifecycle, LRU/annotation-versioning/commit-gate/admission/render-ladder/maturity-consistency), and the wire gap on both planes — dead/starved UI surfaces (split view, metadata inspector, CREATE canvas, comic mode, collaboration cluster, governance/version/browser dashboards), Core library-only modules (scripting, AI summarizer, orphan AcceptedVarianceRegistry, ProfileStore), browser dead-guard cluster (RG-097/024/049 modules), and the browser export path not using the incremental writer — all grep-verified. **Executed 2026-09-07 (§8.3):** wire gap dispositions in D-071…D-073 (defer-with-triggers), RG-135 panel DEBUG-gated (D-074), CI node gate 29→35, starved governance/version/browser surfaces now fed via a ContentView registry-sync hook, dead `SignatureSheet` removed, stale renderer comment corrected, root ephemera cleaned (D-075); full `swift test` pending on the parallel companion-lane edits settling. Complements, does not restate, `docs/architecture.md`.
- `../findings.md`, `../progress.md`, `../task_plan.md` — working scratch; large, sampled only.

## Status tags used in this index
`canonical` · `audit` · `design` · `proposed (non-commitment)` · `archived` · `quarantine`

## Status

- [What's Left / What's Next (2026-08-30)](status-whats-next-2026-08-30.md) — gate census, capability depth, and ranked next units

## RG-131 & Observation Gates

- `docs/audits/rg-131-dual-engine-verification-2026-09-01.md` — Poppler dual-engine verification: 5 dimensions × 2 viewers, 25-fixture governed corpus, manifest-driven, gate logic. PASS.

## External Evaluation Datasets

- `docs/audits/external-evaluation-datasets-2026-09-01.md` — FUNSD (199 forms, CC BY 4.0) + DocLayNet v1.1 (5,199 pages, CDLA-Permissive). Download scripts, eval manifests, integration tests.
- `docs/audits/external-dataset-eval-harness-2026-09-02.md` — RG-137 eval harness audit. FUNSD: bbox-guided upper bound perfect F1 (1.000), QA pairing limited (0.228 F1). DocLayNet: text-only heuristics detect boundaries (1.000 IoU) but cannot classify (0% F1). Honest findings about what text-only extraction CAN and CANNOT do.
- `docs/audits/evidence-floor-abstention-rg138-2026-09-03.md` — RG-138 evidence-floor abstention. Falsified the "corpus composition is the binding constraint" hypothesis: 60 fixtures including 11 graphics-heavy PDFs did NOT separate the graphics-heavy high scorers (scanned-noisy↔low-contrast = 0.9886). Measured finding: extraction resolution is the binding constraint, not corpus composition. Fix: `SimilarityCoverage` + `insufficientEvidence` tier — raster-only above-threshold candidates abstain and route to the OCR/vision confirm lane instead of promoting (fail-closed, §4.3). Blend-sweep answer: edge/occupancy rows cannot be made green by tuning weights (occupancy Jaccard on identical re-encodings ≈ 0.873 vs projection ≈ 0.987); the channel must be fixed (graded occupancy, tolerant multi-scale) or the decision moved to the OCR lane.
- `benchmark/datasets/eval_funsd_entities.py` — FUNSD entity extraction eval harness. Bbox-guided upper bound: perfect precision/recall/F1 (1.000) on 50 test forms; QA pairing limited (0.228 F1). Honest finding: text-only extraction CAN achieve perfect entity detection with position guidance.
- `benchmark/datasets/eval_doclaynet_layout.py` — DocLayNet layout eval harness. Text-only heuristics detect region boundaries (1.000 F1 by IoU) but cannot classify correctly (most classes 0% F1). Honest finding: layout classification requires visual features.
- `benchmark/results/external-dataset-eval/funsd-entity-eval-report.json` — Persisted FUNSD eval report (schema pdf-editor.funsd-entity-eval v1.0, 50 docs, 1,998 entities).
- `benchmark/results/external-dataset-eval/doclaynet-layout-eval-report.json` — Persisted DocLayNet eval report (schema pdf-editor.doclaynet-layout-eval v1.0, 100 pages, 1,307 regions).

## Consolidated Audits (2026-09-02)

- `docs/audits/first-principles-audit-2026-09-02.md` — Full 1st principles audit of all 10 components. All proportional to problems, failure modes identified and mitigated.
- `docs/audits/long-term-alignment-audit-2026-09-02.md` — Scalability, maintainability, and technical debt. All components HIGH 6-month viability.
- `docs/audits/doctrine-alignment-audit-2026-09-02.md` — §0–§17 compliance. All 18 sections PASS.
- `docs/audits/consolidated-audit-2026-09-02.md` — Single source of truth combining the three core-component audits (2026-09-02).
- `docs/audits/read-gap-features-first-principles-audit-2026-09-03.md` — First-principles audit of the 17 READ-gap features (R-01…R-17) + canonical R-mapping.
- `docs/audits/read-gap-features-long-term-audit-2026-09-03.md` — Long-term alignment audit of the 17 READ-gap features + OCR gate.
- `docs/audits/read-gap-features-doctrine-audit-2026-09-03.md` — Doctrine (§0–§17) audit of the 17 READ-gap features + OCR gate.
- `docs/audits/consolidated-audit-2026-09-03.md` — Consolidated audit superseding 09-02: core components + READ-gap features + 4-provider OCR gate. **Consolidated cycle 2026-09-06 → 2026-09-08 appended:** eight streams (RG-134 closure, RG-133 regeneration, radio/choice hardening, multiselect pipeline, D-079 object streams, CI acroform-parity gate, RG-139 blend gate, OCRConfirmLane crash fix) with per-stream falsifiers and honest remaining risks.
- `docs/audits/execution-data-boundary-completion-2026-09-12.md` — TASK-A2 completion record: `ExecutionDataBoundary` two-case enum as a mandatory default-less receipt argument, fabricated `executionRoute` default and unconditional "Cryptographically verified on-device. Zero network egress." footer removed, conditional boundary rendering on exports; falsifier (construction-site + export-text greps) observed not firing; S2 hardening path (egress-notes test) named as open.

## AI Engineering Toolkit Exploration

- `docs/audits/ai-engineering-toolkit-exploration-2026-09-01.md` — All 6 skills explored: Prompt Evaluator, Context Budget, RAG Pipeline, Agent Safety, Eval Harness, Product Sense. Top 3: OCR eval harness, agent safety audit, RAG for FIND job.

- `docs/audits/agent-safety-guard-65point-audit-2026-09-01.md` — 65-point red-team audit on companion bridge, transport, protocol, CLIRunner, and egress controls. 62 PASS, 0 FAIL, 3 WARN after the 2026-09-03 resolution log: V-01 path traversal fixed, V-02 HMAC implemented, V-03 TLS validation + pinning, V-04 socat removed (native sockets), V-05/V-06 documented, V-07 accepted residual, V-08 verified.

- `Sources/PDFEditorCore/OCREvalHarness.swift` — Multi-dimensional OCR quality scoring with structured rubrics (text accuracy, layout, structure, calibration, robustness). Bias mitigation: provider anonymization, length normalization, position randomization.
- `Tests/PDFEditorCoreTests/OCREvalHarnessTests.swift` — 29 tests covering rubric scoring, bias mitigation, edge cases, cross-provider reports.

- `docs/audits/product-sense-coach-creator-archetype-2026-09-01.md` — 5-phase Product Sense Coach on CREATE/DESIGN/PUBLISH. Market: $5.5B, 18% CAGR. Moat: privacy + evidence + free. Path: 3 phases, first milestone is 5-minute test.

- `docs/audits/prompt-evaluator-8dimension-2026-09-01.md` — 8-dimension evaluation of 7 system prompts (doctrines, protocols, HUD, reading modes, adaptive policy). Average score: 77.6/100. Strongest: Safety (8.4). Weakest: Conciseness (6.9).

## Research

- `docs/research/form-field-detection-research-2026-09-09.md` — research map for robust field/label/checkbox/signature-area detection: current capability baseline (AcroForm 4-engine parity; StaticRegionDetector 21.21% recall proxy on Form 6), external SOTA (CommonForms/FFDNet 3-class form-field detection, mAP50-95 up to 81.0; signature class 93.5), proposed 7-channel architecture (A structural → G VLM naming assist) over the existing fusion/review/gate infrastructure, robustness catalog, eval plan (FD-E1…E7: production detector on FUNSD, CommonForms benchmark, /Sig fixtures, per-class metrics), and proposed task ledger FD-R1…R10. License hazards flagged (AGPL pdf-form-builder/PyMuPDF clean-room only; CommonForms weights license unverified).
- `docs/research/pricing-validation-protocol-2026-09-07.md` — pricing validation protocol (pre-existing, now indexed).
- `docs/research/user-interview-guide-2026-09-07.md` — user interview guide (pre-existing, now indexed).
- `docs/research/jev-system-one-model-capability-map-2026-09-18.md` — **living doc** for TypeSafe AI's Jev ("System One" typed-decision model, launched 2026-09-15): capability + hype audit (type-safe ≠ correct; calibration via RLCD is the real differentiator), product-fit map J-01…J-06 (agent-shell judgment tier, receipt risk triage, security-finding triage, OCR confirm-queue ordering, backend routing), hard risks (state prompt-injection, zero-egress conflict, text-only/no-math), post-access increments EXP-JEV-1…5. Early access requested 2026-09-18; spike = NM-R15; exploration map entry 10.
