# PDFKit Known Bugs

**Status:** Documented with evidence and mitigation
**Created:** 2026-08-26
**Source:** Apple Developer Forums, our findings, community reports
**Gate:** A-02, RG-001

## 1. Critical Bugs

### BUG-001: Radio Button Serialization Corruption

**Apple ID:** FB22167174
**Severity:** HIGH
**Status:** Confirmed by Apple
**Impact on us:** Direct — we handle radio fields

**Description:**
PDFKit's `dataRepresentation()` corrupts in-memory state as a side effect when serializing radio button groups. When creating a radio button group with `PDFAnnotation`, only the first annotation's state is preserved. Subsequent radio buttons lose their state.

**Evidence:**
- Apple Developer Forums thread 818162
- `PDFFormField with no corresponding Widget sharing the field name` log message
- Our finding F-016: radio-choice metadata loss on no-op save

**Our mitigation:**
- `PDFIncrementalFormWriter` bypasses PDFKit for all form edits
- Source-preserving incremental update preserves radio metadata
- Byte-exact prefix invariant ensures original bytes untouched

**Test coverage:**
- `PDFIncrementalWriterTests.swift` — 12 mutation tests
- `singleByteSourcePrefixCorruptionIsDetected` — proves guard kills corruption

### BUG-002: Tile Rendering Crash on Lower-RAM iPads

**Apple ID:** Thread 837282
**Severity:** HIGH
**Status:** Confirmed by Apple
**Impact on us:** Direct — affects PDFView rendering

**Description:**
PDFKit's internal tile pool (`PDFTilePool`/`PDFTileSurface`) crashes with `EXC_BREAKPOINT` inside `CFRelease.cold.2` during ordinary PDF viewing. Concentrated on lower-RAM iPads (8th/9th gen) running iPadOS 26.x.

**Evidence:**
- Apple Developer Forums thread 837282
- 51 production crash events across 37 users
- 88% on iPad 9th gen, 100% on iPadOS 26.5.0
- Four independent trigger paths converging on same release path

**Our mitigation:**
- Documented in support policy
- Consider PDFium for rendering replacement
- Test on lower-RAM devices if targeting iPad

**Test coverage:**
- No direct test (crash is in Apple's private code)
- Documented as known limitation

### BUG-003: Radio-Choice Metadata Loss on No-Op Save

**Finding ID:** F-016
**Severity:** HIGH
**Status:** Verified by us
**Impact on us:** Direct — we handle AcroForm documents

**Description:**
PDFKit loses radio-choice metadata when performing a no-op save on a public AcroForm document. The public one-page AcroForm sample contained six widgets, including two `applicant.contact` radio widgets with choices `email` and `phone`. PDFKit reopened the no-op output with the widgets and text intact but returned empty choices for both radio widgets.

**Evidence:**
- `findings.md` F-016
- `docs/pdfkit-widget-benchmark.md`
- `benchmark/results/contract-parity-2026-08-24/native/benchmark__results__2026-08-23-public-acroform__noop.json`

**Our mitigation:**
- `PDFIncrementalFormWriter` bypasses PDFKit for all form edits
- Source-preserving incremental update preserves radio metadata
- Byte-exact prefix invariant ensures original bytes untouched

**Test coverage:**
- `PDFIncrementalWriterTests.swift` — radio-choice preservation tests
- `contract-parity-2026-08-24` — 18-entry parity suite

## 2. Moderate Bugs

### BUG-004: Form Field Handling Issues

**Source:** Apple Developer Forums
**Severity:** MEDIUM
**Status:** Confirmed by community
**Impact on us:** Indirect — affects form workflows

**Description:**
PDFKit has various form field handling issues including:
- Validation scripts not executed
- JavaScript actions not triggered
- Choice field values not preserved correctly
- Signature fields not handled properly

**Evidence:**
- Stack Overflow question 53057373
- Apple Developer Forums discussions

**Our mitigation:**
- `PDFIncrementalFormWriter` handles form fields directly
- Validation scripts not supported by design
- Signature fields refused by guard

### BUG-005: PDFKit Limitations Acknowledged by Apple

**Source:** WWDC22, TidBITS discussions
**Severity:** MEDIUM
**Status:** Acknowledged by Apple
**Impact on us:** Systemic — Apple acknowledges limitations

**Description:**
Apple has acknowledged PDFKit limitations in WWDC22 and community discussions. PDFKit's form handling was improved in macOS 13/iOS 16, but known issues remain.

**Evidence:**
- WWDC22: "What's new in PDFKit"
- TidBITS: "Apple has refused to update their PDFKit engine"
- Apple Developer Forums discussions

**Our mitigation:**
- Document all known limitations
- Use PDFIncrementalFormWriter for writes
- Consider PDFium for future replacement

## 3. Minor Issues

### BUG-006: PDFKit Raster Delta on No-Op

**Finding ID:** F-016
**Severity:** LOW
**Status:** Verified by us
**Impact on us:** Low — not a preservation claim

**Description:**
PDFKit's raster comparison differs by AE `166` (`8.27664e-05` normalized) between source and PDFKit no-op output. This is a visual difference, not a data loss.

**Evidence:**
- `findings.md` F-016
- `docs/pdfkit-widget-benchmark.md`

**Our mitigation:**
- Not a preservation claim
- Byte-exact prefix invariant enforced separately
- Visual diff is expected behavior

## 4. Mitigation Summary

| Bug | Mitigation | Status |
|---|---|---|
| BUG-001 (Radio serialization) | IncrementalWriter bypasses PDFKit | ✅ Implemented |
| BUG-002 (Tile crash) | Documented, consider PDFium | ⚠️ Documented |
| BUG-003 (Radio-choice loss) | IncrementalWriter bypasses PDFKit | ✅ Implemented |
| BUG-004 (Form handling) | IncrementalWriter handles directly | ✅ Implemented |
| BUG-005 (Acknowledged limitations) | Documented, use IncrementalWriter | ✅ Documented |
| BUG-006 (Raster delta) | Not a preservation claim | ✅ Accepted |

## 5. Recommendations

1. **Keep PDFKit for rendering** — works for most cases, document bugs
2. **Use IncrementalWriter for all writes** — bypasses PDFKit's broken form handling
3. **Add PDFium for future** — BSD license, better rendering
4. **Test on lower-RAM devices** — if targeting iPad
5. **Monitor Apple updates** — PDFKit improvements in future macOS versions

## 6. Evidence

- Apple Developer Forums: FB22167174 (radio button serialization)
- Apple Developer Forums: thread 837282 (tile rendering crash)
- `findings.md`: F-016 (radio-choice metadata loss)
- `Sources/PDFEditorCore/PDFKitProvider.swift` — current PDFKit usage
- `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift` — bypass for writes
