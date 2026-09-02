# Documentation Index (Canonical)

**Canonical owner of this index:** `docs/INDEX.md`
**Authority rule (D-055):** `release-gates.md` owns gate/claim state; `task-inventory.md` owns task state; `decisions.md` owns durable decisions. No other doc may assert gate "PASS"/"FAIL" or capability "Implemented" as primary truth.
**Truth-status rule (OPERATING_DOCTRINE §2):** claims are Observed / Verified / Inferred / Proposed / Unknown / Contested. A capability is "Implemented" only when a passing, tier-appropriate assertion exists (see `docs/audits/pda-impl-plan-2026-08-28.md` Phase 1).

## Canonical (source of truth)
- `docs/decisions.md` — durable product/evaluation decisions (D-001 … D-057; D-007/D-010 collisions renumbered to D-056/D-057).
- `docs/release-gates.md` — release-gate state (single authority per D-055).
- `docs/task-inventory.md` — task state (single authority per D-055).
- `docs/DOCUMENTATION_DOCTRINE.md` — vendored documentation doctrine (symlink to `../OPERATING_DOCTRINE.md`).
- `docs/implementation-status.md` — feature implementation status (must link a claim ID).
- `docs/audits/native-macos-product-audit-per-0926-2026-08-31.md` — current native macOS product audit, findings, evidence register, first-principles/long-term/doctrine alignment, and new-age interaction agenda.
- `docs/roadmaps/native-macos-modernization-plan-2026-08-31.md` — proposed native shell, session ownership, evidence surface, accessibility, spatial prototype, provider, and release sequence.
- `docs/decisions/adaptive-contextual-command-doctrine-2026-08-31.md` — focused decision record for direct-context contextual menus, bounded local ranking, stable recovery, and behavior-history research.
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

## Audits — Capability Governance (2026-08-28)
- `docs/audits/capability-maturity-model-and-matrix-2026-08-28.md` — 5-dimension maturity model, 42-capability canonical matrix with real providers/gates/owners, gate-maturity bridge (35 tests).

## Audits — OCR Benchmark (2026-08-31)
- `docs/audits/ocr-benchmark-expansion-2026-08-31.md` — 8 ground-truth fixtures (scans, noise, rotation, low-contrast, dense, small-font, punctuation, multi-column), Tesseract 5.5.0 baseline (1.2% avg WER), PDFKit baseline (no OCR on raster PDFs), cross-provider comparison, 14 tests.
- `docs/audits/ocr-cross-provider-benchmark-2026-08-31.md` — Cross-provider WER benchmark: Apple Vision (0.0% WER, 2.2s), Tesseract (0.2% WER, 2.0s), PaddleOCR PP-OCRv6 (9.1% WER, 19.2s). 9 fixtures × 3 providers, 22 Swift tests, Python benchmark script, Vision CLI tool.

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
- **RG-131: Control-viewer observation pre-release gate** (`Sources/PDFEditorCore/ControlViewerObservation.swift`, `Tests/PDFEditorCoreTests/ControlViewerObservationGateTests.swift`). Batch observation of governed corpus (192+ PDFs across 9 document classes) via PDFKit: reopen, rotation, visual fidelity, form visibility, text readability. Fails closed on any fixture failure. Writes `benchmark/results/control-viewer-gate-report.json` as CI artifact. Wired into `docs/runbooks/release-gates.md` §7 as a mandatory pre-release step — version bumps require `gatePassed == true`. Gate is PARTIAL: single viewer (PDFKit), under-represents scanned/rotated/encrypted/malformed/handwritten classes, no human visual confirmation.
- **RG-132: LayoutV2 family-threshold calibration artifact** (`Tests/PDFEditorCoreTests/LayoutFingerprintThresholdCalibrationTests.swift`). Persisted JSON artifact at `benchmark/results/detector-calibration/layout-v2-family-threshold-calibration-2026-08-28.json`. Corpus: 44 fixtures, 211 positive, 735 hard-negative pairs. Threshold: 0.90. CI regenerates and validates on every push via `scripts/calibration-gate.sh`.
- **RG-133: AcroForm cross-provider parity experiment** (`Sources/PDFEditorCore/AcroFormParityExperiment.swift`, `Tests/PDFEditorCoreTests/AcroFormParityExperimentTests.swift`). Write-reopen-read round-trip on 9 fixtures across 3 providers. Results: checkbox limited (67%), choice production-ready (100%), text production-ready (100%), radio unsupported. Gate report at `benchmark/results/acroform-parity/acroform-parity-gate-report.json`.
- **RG-134: AcroForm parity release blocker** (`docs/release-gates.md` RG-134). Version bumps blocked while checkbox confidence is below production-ready (≥90%). Current state: PARTIAL (67% checkbox). Resolution: fix PDFKit save/reopen, expand corpus, or classify as known-excluded.
- **RG-135: Human visual confirmation pre-release gate** (`Sources/PDFEditorCore/HumanVisualConfirmation.swift`, `Sources/PDFEditorApp/HumanReviewPanelView.swift`, `Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift`). SwiftUI reviewer panel records per-dimension confirmations bound to fixture SHA-256 digests; ledger + gate report persist at `benchmark/results/human-visual-confirmation/` and upload as CI artifacts. Fail-closed: `pending` until every governed fixture is human-confirmed against current bytes; reviewer-recorded failures block CI. Current state: PENDING (0/38 confirmed).

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
- `../findings.md`, `../progress.md`, `../task_plan.md` — working scratch; large, sampled only.

## Status tags used in this index
`canonical` · `audit` · `design` · `proposed (non-commitment)` · `archived` · `quarantine`

## Status

- [What's Left / What's Next (2026-08-30)](status-whats-next-2026-08-30.md) — gate census, capability depth, and ranked next units

## RG-131 & Observation Gates

- `docs/audits/rg-131-dual-engine-verification-2026-09-01.md` — Poppler dual-engine verification: 5 dimensions × 2 viewers, 25-fixture governed corpus, manifest-driven, gate logic. PASS.

## External Evaluation Datasets

- `docs/audits/external-evaluation-datasets-2026-09-01.md` — FUNSD (199 forms, CC BY 4.0) + DocLayNet v1.1 (5,199 pages, CDLA-Permissive). Download scripts, eval manifests, integration tests.

## AI Engineering Toolkit Exploration

- `docs/audits/ai-engineering-toolkit-exploration-2026-09-01.md` — All 6 skills explored: Prompt Evaluator, Context Budget, RAG Pipeline, Agent Safety, Eval Harness, Product Sense. Top 3: OCR eval harness, agent safety audit, RAG for FIND job.

- `docs/audits/agent-safety-guard-65point-audit-2026-09-01.md` — 65-point red-team audit on companion bridge, transport, protocol, CLIRunner, and egress controls. 56 PASS, 1 FAIL (path traversal — fixed), 8 WARN.

- `Sources/PDFEditorCore/OCREvalHarness.swift` — Multi-dimensional OCR quality scoring with structured rubrics (text accuracy, layout, structure, calibration, robustness). Bias mitigation: provider anonymization, length normalization, position randomization.
- `Tests/PDFEditorCoreTests/OCREvalHarnessTests.swift` — 29 tests covering rubric scoring, bias mitigation, edge cases, cross-provider reports.

- `docs/audits/product-sense-coach-creator-archetype-2026-09-01.md` — 5-phase Product Sense Coach on CREATE/DESIGN/PUBLISH. Market: $5.5B, 18% CAGR. Moat: privacy + evidence + free. Path: 3 phases, first milestone is 5-minute test.

- `docs/audits/prompt-evaluator-8dimension-2026-09-01.md` — 8-dimension evaluation of 7 system prompts (doctrines, protocols, HUD, reading modes, adaptive policy). Average score: 77.6/100. Strongest: Safety (8.4). Weakest: Conciseness (6.9).
