# Add a New Corpus Fixture — Runbook

Every new fixture must pass through this pipeline before it appears in any
gate or calibration corpus. Skipping steps creates false-confidence bugs
(name-vs-structure inference, false positives, calibration drift).

## Prerequisites

- The PDF fixture exists on disk (generated, downloaded, or hand-crafted)
- qpdf is installed (`brew install qpdf`)
- Swift toolchain is available

## Checklist

### 1. Emit — generate or place the fixture

```bash
# Place the fixture in the appropriate directory:
# - corpus-sweep-2026-08-25/  — sweep fixtures (form variants)
# - browser-corpus/            — browser-specific fixtures
# - detector-calibration/      — detector measurement fixtures
# - rotation-corpus/           — rotation test fixtures
# - security-corpus/           — security test fixtures
```

### 2. Validate — verify structural properties with qpdf

```bash
# Structural check (must be clean or expected warning):
qpdf --check benchmark/results/corpus-sweep-2026-08-25/your-fixture.pdf

# Count form fields:
qpdf --show-object=trailer benchmark/results/corpus-sweep-2026-08-25/your-fixture.pdf

# Page count:
qpdf --show-npages benchmark/results/corpus-sweep-2026-08-25/your-fixture.pdf
```

### 3. Probe — extract V2 layout fingerprint

Run the `ManifestFieldPresenceProbe` or write a quick probe:

```swift
let doc = PDFDocument(url: URL(fileURLWithPath: "path/to/fixture.pdf"))!
let fp = LayoutFingerprintV2Extractor.extract(from: doc)!
print("digest: \(fp.digest)")
print("pages: \(fp.pages.count)")
for page in fp.pages {
    print("  p\(page.pageIndex): \(page.widthPoints)x\(page.heightPoints) rot\(page.rotationDegrees) text=\(page.textCells.count) field=\(page.fieldCells.count) annot=\(page.annotationCells.count)")
}
```

### 4. Review — classify the fixture

Assign a **family label** based on actual structure (never by name):

| Label | Meaning | How to determine |
|---|---|---|
| **A** | Layout-identical to base form | Same page geometry, same widget layout, same text positions |
| **B/C/D** | Distinct family | Different page count, different geometry, different widget layout |
| **N** | Hard negative (layout-distinct) | Different structure entirely |
| **Excluded** | Cannot extract (encrypted, malformed) | qpdf or PDFKit fails to open |

**Critical rule**: the label must come from structural inspection (qpdf +
PDFKit probe), not from the filename. The original 2026-08-28 audit found
5 name-vs-structure inference errors — this checklist prevents recurrence.

### 5. Label — add to the manifest

Update `benchmark/results/corpus-sweep-2026-08-25/manifest.json`:

```json
{
  "your-fixture.pdf": {
    "category": "your-category",
    "sha256": "<actual sha256 from qpdf or shasum>",
    "qpdf": "clean",
    "expected": {
      "pages": <actual page count>,
      "acroFormFieldCount": <actual widget count>,
      "widgetCount": <actual widget count>,
      "annotationCount": <actual non-widget annotation count>,
      "textChars": <actual character count from PDFKit>
    }
  }
}
```

### 6. Gate — verify the detector gate fails closed

The detector gate must reject unreviewed fixtures. Run:

```bash
swift run PDFContractHarness \
  --manifest docs/fixtures/corpus-sweep-detector-manifest.md \
  --output-dir benchmark/results/detector-calibration/native-corpus \
  --detector-gate
```

The gate should **fail** until the fixture is explicitly added to the
`ReviewedCandidateGroundTruth` with verified expected states.

### 7. Register — add to ground truth (if applicable)

If the fixture should be measured by the detector gate, add entries to
`Sources/PDFEditorCore/ReviewedCandidateGroundTruth.swift`:

```swift
ReviewedCandidateGroundTruth.Case(
    fixtureID: "your-fixture",
    expectedState: "detect" | "abstain",
    evidence: "Verified: <structural facts>",
    provenance: "reviewed-2026-08-30"
)
```

### 8. Calibrate — add to threshold calibration (if applicable)

If the fixture is part of the layout family calibration, add to
`Tests/PDFEditorCoreTests/LayoutFingerprintThresholdCalibrationTests.swift`:

```swift
("your-fixture.pdf", "A", "description of why this is family A"),
```

And update the `url()` function to route to the correct directory.

### 9. Verify — run the full gate suite

```bash
# Manifest field presence gate:
swift test --filter ManifestFieldPresenceGate

# V2 threshold calibration gate:
swift test --filter LayoutFingerprintThresholdCalibrationTests

# Detector gate:
swift run PDFContractHarness --detector-gate ...

# Full suite:
swift test
```

All gates must pass before committing.

### 10. Commit — one commit with doctrine attestation

Group the fixture, manifest update, ground truth, and any calibration
changes into one commit. Include:

- The fixture PDF
- Manifest update with verified field presence
- Ground truth entries (if applicable)
- Test evidence (probe results, gate output)

## Common pitfalls

1. **Name-vs-structure inference**: Never label a fixture based on its
   filename. Always verify with qpdf + PDFKit.

2. **Missing field presence**: Every fixture must have `widgetCount` and
   `annotationCount` in the manifest. The gate test verifies this.

3. **Pooled measurement**: Use per-fixture scoping in detector gates to
   prevent cross-fixture false matches.

4. **V2 fingerprint without layoutV2**: If adding to the calibration
   corpus, every entry must have a `layoutV2` fingerprint. The legacy
   string lane has been retired.

## Doctrine alignment

- **§2 Truth taxonomy**: labels are Verified facts, not inferred from names
- **§5 Evidence-based**: every assertion backed by live PDFKit inspection
- **§10 Failure**: gate fails closed on unreviewed fixtures
- **§6 Documentation**: this runbook is the durable knowledge record
