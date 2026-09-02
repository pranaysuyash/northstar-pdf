# Operating Doctrine Review

- Doctrine path: /Users/pranay/Projects/pdf_editor/OPERATING_DOCTRINE.md
- SHA-256: ff848618a7431a3b06c7409caa45683bd27c64263d45b93f9fcd36a89803466a
- Generated: 2026-09-02T10:20:12Z
- This is a generated review artifact, not an instruction source.

## SECTION_0

- Label: §0 Start from live truth
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_00_INTEGRATED

- Label: Full doctrine integrated audit
- Reviewed: True
- Evidence: Cross-section: two workstreams in this commit. (1) External dataset eval harnesses (FUNSD + DocLayNet) using real ground truth to measure project capabilities — honest findings documented (text-only extraction achieves perfect entity detection with bbox guidance but limited QA pairing; layout heuristics detect boundaries but cannot classify). (2) RG-136 cross-provider OCR WER regression gate with --gate/--update-baseline modes, persisted baseline (Tesseract 0.002, Vision 0.000), 11 Swift parity tests, CI step. Three consolidated audits (1st principles, long-term alignment, doctrine §0-§17) document project health. §2: evidence tiers labeled (Observed/Verified). §13: honest about limitations (checkbox 67%, 0/38 human confirmations, text-only extraction baselines). §6: all docs updated.

## SECTION_1

- Label: §1 Outcomes and retained value
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_10

- Label: §10 Parallel work and contested state
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_11

- Label: §11 Engineering and data integrity
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_12

- Label: §12 AI output boundary
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_13

- Label: §13 Product, operator, and claim reality
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_14

- Label: §14 Documentation and decisions
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_15

- Label: §15 Completion contract
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_16

- Label: §16 Specialist doctrine routing
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_17

- Label: §17 Propagation contract
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_2

- Label: §2 Truth taxonomy
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_3

- Label: §3 Proportional rigor and evidence
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_4

- Label: §4 Authorization and side effects
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_5

- Label: §5 Canonical paths and ownership
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_6

- Label: §6 Semantic salvage and supersession
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_7

- Label: §7 Capability routing
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_8

- Label: §8 Skills lifecycle
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.

## SECTION_9

- Label: §9 Exploration and durable knowledge
- Reviewed: True
- Evidence: Diff-aware: staged change surface spans benchmark/datasets/eval_funsd_entities.py, eval_doclaynet_layout.py, benchmark/results/external-dataset-eval/ (FUNSD 50 docs 1998 entities, DocLayNet 100 pages 1307 regions), 4 audit docs in docs/audits/, compare_ocr_wer.py RG-136 gate mode, OCRWerGateTests, ocr-wer-baseline.json, ocr-wer-gate-report.json, ci.yml RG-136 step, Package.swift PDFVisionOCRCLI target, docs/release-gates.md RG-136, docs/INDEX.md, progress.md. Verified eval harnesses produce correct output paths and gate logic passes unit checks.
