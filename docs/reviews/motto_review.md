# Operating Doctrine Review

- Doctrine path: /Users/pranay/Projects/pdf_editor/OPERATING_DOCTRINE.md
- SHA-256: ff848618a7431a3b06c7409caa45683bd27c64263d45b93f9fcd36a89803466a
- Generated: 2026-09-01T18:07:45Z
- This is a generated review artifact, not an instruction source.

## SECTION_0

- Label: §0 Start from live truth
- Reviewed: True
- Evidence: Verified live checkout: benchmark/results/governed-corpus-manifest.json contains 38 fixtures. swift build clean (0.38s). RG-131 test passes with 38/38 fixtures.

## SECTION_00_INTEGRATED

- Label: Full doctrine integrated audit
- Reviewed: True
- Evidence: Cross-section: small targeted change — only governed-corpus-manifest.json expanded from 25 to 38 fixtures. §14: RG-131 audit doc updated with new stats. §9: progress.md updated. §13: gate PASS with 38/38 fixtures. §0: verified all paths exist. No code changes, no routing changes, no side effects.

## SECTION_1

- Label: §1 Outcomes and retained value
- Reviewed: True
- Evidence: verified benchmark/results/governed-corpus-manifest.json: expanding from 25 to 38 fixtures across 14 classes adds coverage for scanned (9), malformed (4), layout (7), XFA (2), navigation (2). Retained: RG-131 gate now tests more diverse PDFs.

## SECTION_10

- Label: §10 Parallel work and contested state
- Reviewed: True
- Evidence: N/A: no parallel work conflicts. Single manifest file updated.

## SECTION_11

- Label: §11 Engineering and data integrity
- Reviewed: True
- Evidence: verified benchmark/results/governed-corpus-manifest.json: all 38 relativePath values resolve to existing files on disk. JSON validated.

## SECTION_12

- Label: §12 AI output boundary
- Reviewed: True
- Evidence: N/A: no AI output in production paths.

## SECTION_13

- Label: §13 Product, operator, and claim reality
- Reviewed: True
- Evidence: verified benchmark/results/control-viewer-gate-report.json: 38/38 pass with 0 failures. Honest: 38 fixtures is better than 25 but still not comprehensive for all real-world PDFs.

## SECTION_14

- Label: §14 Documentation and decisions
- Reviewed: True
- Evidence: verified docs/audits/rg-131-dual-engine-verification-2026-09-01.md: updated corpus table (14 classes, 38 fixtures). verified progress.md: expansion entry added.

## SECTION_15

- Label: §15 Completion contract
- Reviewed: True
- Evidence: verified benchmark/results/control-viewer-gate-report.json: gate PASS. swift build clean. RG-131 test passes with 38/38 fixtures.

## SECTION_16

- Label: §16 Specialist doctrine routing
- Reviewed: True
- Evidence: N/A: no specialist doctrine routing changes.

## SECTION_17

- Label: §17 Propagation contract
- Reviewed: True
- Evidence: verified progress.md: new entry documents expansion. No other repos affected.

## SECTION_2

- Label: §2 Truth taxonomy
- Reviewed: True
- Evidence: verified benchmark/results/control-viewer-gate-report.json: 38/38 fixtures pass RG-131 gate (Verified tier). All new fixture paths verified to exist on disk.

## SECTION_3

- Label: §3 Proportional rigor and evidence
- Reviewed: True
- Evidence: verified benchmark/results/governed-corpus-manifest.json: Tier 3 (integration test via swift test). Evidence: 38/38 fixtures pass dual-engine observation. Tier stated in docs/audits/rg-131-dual-engine-verification-2026-09-01.md.

## SECTION_4

- Label: §4 Authorization and side effects
- Reviewed: True
- Evidence: N/A: manifest update only, no auth/payment/side-effect changes. verified benchmark/results/governed-corpus-manifest.json is data-only.

## SECTION_5

- Label: §5 Canonical paths and ownership
- Reviewed: True
- Evidence: verified benchmark/results/governed-corpus-manifest.json: canonical path for governance manifest. verified docs/audits/rg-131-dual-engine-verification-2026-09-01.md: canonical audit doc path.

## SECTION_6

- Label: §6 Semantic salvage and supersession
- Reviewed: True
- Evidence: verified docs/audits/rg-131-dual-engine-verification-2026-09-01.md: updated with 38-fixture stats, superseding 25-fixture version.

## SECTION_7

- Label: §7 Capability routing
- Reviewed: True
- Evidence: N/A: no capability routing changes. RG-131 gate reads manifest and runs observations — same path, more fixtures.

## SECTION_8

- Label: §8 Skills lifecycle
- Reviewed: True
- Evidence: N/A: no skill lifecycle changes.

## SECTION_9

- Label: §9 Exploration and durable knowledge
- Reviewed: True
- Evidence: verified docs/audits/rg-131-dual-engine-verification-2026-09-01.md: updated with expanded corpus evidence. verified progress.md: new entry documenting expansion.
