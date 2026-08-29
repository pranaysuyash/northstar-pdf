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

## Audits — Rendering Pipeline (2026-08-28)
- `docs/audits/rendering-pipeline-1st-principles-architecture-2026-08-28.md` — Pipeline-as-sole-renderer decision, PipelineCanvasView, PipelineTileOverlayView, architecture options and evidence.

## Audits — Calibration & Precision (2026-08-28)
- `docs/audits/recurring-form-calibrator-and-page-box-policy-2026-08-28.md` — 5-tier recurring form classification, canonical page-box precision/tolerance policy, 23 tests.
- `docs/audits/calibration-corpus-verification-2026-08-28.md` — real-corpus calibration run (13 tests), fingerprint-collision findings, FalsePositiveReport.
- `docs/audits/accepted-variance-registry-2026-08-28.md` — 14-category native/web mismatch registry with tolerances, owners, falsifying tests (24 tests).
- `docs/audits/reviewed-candidate-ground-truth-measurement-2026-08-28.md` — 15-case reviewed ground truth (10 human-reviewed + 5 generator-manifest), native/browser precision/recall/abstention/label-agreement measurement, mjs v1.0 mirror + identity-fallback fix (19 tests).
- `docs/audits/layout-fingerprint-collision-exploration-2026-08-28.md` — first-principles analysis of the V1 fingerprint collision + false familyMatch; LayoutFingerprintV2 prototype (structured components, field-value masking, structured similarity); 3 new Observed findings (7 tests).

## Audits — Capability Governance (2026-08-28)
- `docs/audits/capability-maturity-model-and-matrix-2026-08-28.md` — 5-dimension maturity model, 42-capability canonical matrix with real providers/gates/owners, gate-maturity bridge (35 tests).

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
- `docs/audits/pdf-library-evaluation-2026-08-26.md` — Library evaluation
- `docs/audits/pdfkit-adequacy-audit-2026-08-26.md` — PDFKit adequacy assessment
- `docs/audits/pdfkit-known-bugs-2026-08-26.md` — PDFKit known bugs

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
- `../findings.md`, `../progress.md`, `../task_plan.md` — working scratch; large, sampled only.

## Status tags used in this index
`canonical` · `audit` · `design` · `proposed (non-commitment)` · `archived` · `quarantine`
