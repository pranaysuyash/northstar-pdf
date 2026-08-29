# Generator-Manifest Name-vs-Structure Inference Audit

**Date:** 2026-08-28
**Finding:** The review pass (2026-08-28) corrected 5 generator-manifest "no editable candidates" cases that were wrong. This audit checks whether the same error class exists elsewhere.

## 1. The original error (Observed, qpdf 12.4 structural inspection)

The generator manifest (`benchmark/results/corpus-sweep-2026-08-25/manifest.json`) recorded `expected` facts for each fixture. The 5 corpus-sweep fixtures (plain-text, multi-column, geometry, navigation, signed-valid-structure) had **no field-presence expectations** — the manifest only checked page count, rotation, and metadata.

The "no editable candidates" claim was an **inference from fixture names** (e.g., "plain-text" implies no forms), not from actual PDF structure. qpdf 12.4 structural inspection proved this wrong: **every** fixture is `public-sample-form.pdf` (6 AcroForm widgets on page 0) with pages added by `generate_corpus_sweep.py`.

## 2. Current generator manifest expectations

| Fixture | Expected facts | Field presence checked? |
|---|---|---|
| plain-text.pdf | pages: 3 | ❌ No |
| multi-column.pdf | pages: 2 | ❌ No |
| geometry.pdf | pages: 4, rotate: 0, facts | ❌ No |
| navigation.pdf | pages: 3, outlinesCount: 2, annots: 6, ... | ✅ Yes (annots: 6 = widgets) |
| metadata-complete.pdf | title, weirdType | ❌ No (metadata only) |
| metadata-absent.pdf | infoKeys, title | ❌ No (metadata only) |
| metadata-unicode.pdf | title | ❌ No (metadata only) |
| metadata-malformed.pdf | weirdType | ❌ No (metadata only) |
| signed-valid-structure.pdf | pages: 1 | ❌ No |
| signed-invalid-structure.pdf | pages: 1 | ❌ No |
| signed-multiple.pdf | pages: 1 | ❌ No |
| xfa-static.pdf | pages: 1 | ❌ No |
| xfa-dynamic.pdf | pages: 1 | ❌ No |
| xfa-hybrid.pdf | pages: 1, acroFormFieldCount: 1 | ✅ Yes |

**12 of 14 fixtures have no field-presence expectations.** Only `navigation.pdf` (annots: 6) and `xfa-hybrid.pdf` (acroFormFieldCount: 1) verify field presence.

## 3. Corrected ground truth (Verified, qpdf 12.4)

The review pass corrected `ReviewedCandidateGroundTruth.swift` with:
- **90 native-field positives** (6 widgets × 15 form-bearing fixtures, page 0)
- **8 page-level abstains** for genuinely widget-free added pages (plain-text ×2, multi-column ×1, navigation ×2, geometry ×3)

The review record documents each fixture's actual structure:
```
"plain-text.pdf": "3 pages; page 0 = base form with 6 AcroForm widgets; pages 1-2 no /Annots"
"multi-column.pdf": "2 pages; page 0 = base form with 6 widgets; page 1 no /Annots"
"geometry.pdf": "4 pages; page 0 = base form with 6 widgets; pages 1-3 no /Annots"
```

## 4. Remaining name-vs-structure inference issues

### 4.1 Generator manifest is stale (Medium priority)

The manifest's `expected` facts don't verify field presence for 12 of 14 fixtures. The manifest should be updated to include `acroFormFieldCount: 6` for all form-bearing fixtures, matching the corrected ground truth.

**Fix:** Add `acroFormFieldCount` to the generator manifest's expected facts for each fixture, and add a test assertion that verifies field presence against the manifest.

### 4.2 No other name-vs-structure inference errors found (Verified)

The rest of the codebase correctly uses structural inspection:
- `ReviewedCandidateGroundTruth.swift`: 108 cases verified via qpdf 12.4 structural inspection
- `NativeDetectorGate`: live pipeline measurement against reviewed ground truth
- `DualLaneDetectorGate`: both lanes measured against same truth
- `DetectorSemanticMeasurement`: per-fixture scoping prevents cross-matching
- `CalibrationCorpusVerificationTests`: V2 structured similarity on real corpus
- All web tests: runtime checks (if no fields found, skip), not name-based

### 4.3 No remaining "no editable candidates" claims (Verified)

Searched for `no editable`, `no.*candidates`, `no.*fields`, `no.*widgets` across all source and test files. No remaining name-based claims found. The only references are:
- Documentation comments explaining the original error
- Review record documenting the correction
- Mutation tests proving the gate can fail

## 5. Recommendation

Update the generator manifest to include field-presence expectations, and add a CI gate that verifies field presence against the manifest. This prevents the name-vs-structure error from recurring.

## 6. Evidence

- Generator manifest: `benchmark/results/corpus-sweep-2026-08-25/manifest.json`
- Corrected ground truth: `Sources/PDFEditorCore/ReviewedCandidateGroundTruth.swift`
- Review record: `ReviewedCandidateGroundTruth.reviewRecord`
- Full suite: 1330/1330 tests pass
