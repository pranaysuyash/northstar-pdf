# Operating Doctrine Review

- Doctrine path: /Users/pranay/Projects/pdf_editor/OPERATING_DOCTRINE.md
- SHA-256: ff848618a7431a3b06c7409caa45683bd27c64263d45b93f9fcd36a89803466a
- Generated: 2026-09-02T09:21:14Z
- This is a generated review artifact, not an instruction source.

## SECTION_0

- Label: §0 Start from live truth
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_00_INTEGRATED

- Label: Full doctrine integrated audit
- Reviewed: True
- Evidence: Cross-section: new RG-135 human visual confirmation workflow. Sources/PDFEditorCore/HumanVisualConfirmation.swift adds digest-bound ledger + fail-closed gate (§2 truth taxonomy: confirmations are Verified only against current SHA-256; stale demotes to pending). Sources/PDFEditorApp/HumanReviewPanelView.swift records reviewer observations; no production document path is modified — panel is additive UI behind Workspace menu (§4: no side effects on existing flows). CI step validates artifact schemas, blocks on fail, warns on pending (no human in CI), uploads artifacts (§5 evidence-based; §13 claim reality: gate cannot vacuously pass — empty manifest is pending, verified by test). Docs updated in the same commit (§14). Residual: 0/38 fixtures confirmed by a human yet — gate honestly reports pending; release remains blocked per disposition.

## SECTION_1

- Label: §1 Outcomes and retained value
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_10

- Label: §10 Parallel work and contested state
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_11

- Label: §11 Engineering and data integrity
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_12

- Label: §12 AI output boundary
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_13

- Label: §13 Product, operator, and claim reality
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_14

- Label: §14 Documentation and decisions
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_15

- Label: §15 Completion contract
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_16

- Label: §16 Specialist doctrine routing
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_17

- Label: §17 Propagation contract
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_2

- Label: §2 Truth taxonomy
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_3

- Label: §3 Proportional rigor and evidence
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_4

- Label: §4 Authorization and side effects
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_5

- Label: §5 Canonical paths and ownership
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_6

- Label: §6 Semantic salvage and supersession
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_7

- Label: §7 Capability routing
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_8

- Label: §8 Skills lifecycle
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.

## SECTION_9

- Label: §9 Exploration and durable knowledge
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans Sources/PDFEditorCore/HumanVisualConfirmation.swift, Sources/PDFEditorApp/HumanReviewPanelView.swift, Sources/PDFEditorApp/ContentView.swift wiring, Tests/PDFEditorCoreTests/HumanVisualConfirmationTests.swift, .github/workflows/ci.yml RG-135 step, docs/release-gates.md RG-134+RG-135, docs/INDEX.md, progress.md, and the new benchmark/results/human-visual-confirmation/ artifact pair. Verified swift build clean and 13/13 tests pass before staging; verified CI YAML parses.
