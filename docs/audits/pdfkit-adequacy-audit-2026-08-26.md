# A-02: PDFKit Adequacy Audit

**Assumption:** "PDFKit will remain adequate as the native provider"
**Status:** PARTIALLY VERIFIED — adequate for bounded lanes; known failures for AcroForm preservation
**Created:** 2026-08-26
**Gate:** RG-001, RG-002, F-016

## 1. What has been tested with PDFKit

### Corpus breadth

| Corpus | PDFs | PDFKit tested | Status |
|---|---|---|---|
| Contract parity (18-entry) | 18 | ✅ All 18 via `PDFContractHarness` | 16 readable pass, 2 malformed expected |
| Native incremental (9) | 9 | ✅ All 9 via `PDFIncrementalWriterTests` | 12 mutation tests pass |
| Native perf budgets (4) | 1 | ✅ tagged-acroform.pdf | All 4 budgets pass |
| Synthetic producers (6) | 6 | ✅ All 6 via corpus sweep | qpdf clean, pikepdf reopen |
| Total PDFKit-tested | **34** | | |

### What PDFKit handles well

| Capability | Evidence | Confidence |
|---|---|---|
| Open/import | 34 PDFs opened successfully | High |
| Render/navigation | 18-entry parity suite | High |
| Extractable text | Contract parity + perf budgets | High |
| Search | Perf budget test (field lookup) | High |
| Metadata | Corpus sweep (5 variants) | High |
| Permissions | Contract parity | High |
| Password open | Encrypted corpus (AES-256) | Medium |
| FreeText overlays | Contract parity + mutation tests | High |
| Field inspection | 34 PDFs inspected | High |

### Known PDFKit failures

| Failure | Severity | Evidence | Mitigation |
|---|---|---|---|
| **F-016: Radio-choice loss on no-op save** | HIGH | Public AcroForm: 6 widgets, 2 radio groups with `email`/`phone` choices → empty choices after PDFKit no-op | `PDFIncrementalFormWriter` bypasses PDFKit writer; source-preserving incremental update preserves radio metadata |
| **F-016: Raster delta on no-op** | MEDIUM | AE `166` (`8.27664e-05` normalized) between source and PDFKit no-op output | Not a preservation claim; byte-exact prefix invariant enforced separately |
| **Compressed object streams** | HIGH | `PDFIncrementalFormWriter` rejects compressed xref streams with `compressedObject` diagnostic | Fail-closed; full xref-stream support remains open |
| **XFA documents** | HIGH | `XFAFormProcessor.inspectXFA` refuses edit on any XFA document | Fail-closed; XFA is explicitly unsupported |
| **Signed documents** | HIGH | Signature guard refuses edit on signed documents | Fail-closed; signature preservation remains open |

## 2. Where PDFKit is NOT adequate

| Gap | Impact | Current workaround |
|---|---|---|
| **Radio-choice round-trip** | External AcroForm radio fields lose choices on PDFKit no-op | `PDFIncrementalFormWriter` bypasses PDFKit for field-value edits |
| **Appearance-stream regeneration** | PDFKit does not regenerate widget appearances | `PDFIncrementalFormWriter` generates self-contained `/AP /N` Form XObjects |
| **Compressed xref streams** | PDFKit handles them internally but our parser can't extract fields | Fail-closed; requires full xref-stream support |
| **XFA state regeneration** | PDFKit cannot regenerate XFA form state | XFA documents are refused for editing |
| **Signature preservation** | PDFKit cannot preserve digital signatures through edits | Signed documents are refused for editing |

## 3. What would break the assumption

| Falsifier | Likelihood | Impact |
|---|---|---|
| New macOS version changes PDFKit behavior | Low (Apple rarely changes PDFKit) | Would require regression testing on new OS |
| Real-world PDF with unusual AcroForm structure | Medium (synthetic corpus is limited) | Would require broader real-world corpus |
| PDFKit deprecation in future macOS | Very low (PDFKit is actively maintained) | Would require provider replacement |
| Performance regression on large documents | Low (perf budgets are generous) | Would require device-matrix testing |

## 4. Verdict

**PDFKit is adequate for:**
- Reading and rendering all PDF types
- Text extraction and search
- Metadata and permissions inspection
- FreeText overlay operations
- Password-protected document handling

**PDFKit is NOT adequate for:**
- AcroForm field-value preservation (radio-choice loss)
- Appearance-stream regeneration
- Compressed xref stream handling
- XFA form state management
- Signature preservation

**The assumption holds** because:
1. The `PDFIncrementalFormWriter` already bypasses PDFKit for AcroForm edits
2. The fail-closed guards (compressed objects, XFA, signatures) protect against unknown failure modes
3. 34 PDFs have been tested across multiple corpus types
4. The known failures are documented and mitigated

**To strengthen the assumption:**
1. Expand the real-world AcroForm corpus beyond synthetic fixtures
2. Test on a broader set of macOS versions (currently 15+ only)
3. Add PDFKit version detection and behavioral fingerprinting
4. Consider PDFKit as read-only provider and `PDFIncrementalFormWriter` as the sole write path

## 5. Evidence

- `Tests/PDFEditorCoreTests/PDFIncrementalWriterTests.swift` — 12 mutation tests
- `Tests/PDFEditorCoreTests/NativePerformanceBudgetTests.swift` — 4 perf budgets
- `benchmark/results/2026-08-25-native-incremental/` — 9 corpus PDFs
- `benchmark/results/contract-parity-2026-08-24/native/` — 18-entry parity suite
- `findings.md` F-016, F-017 — PDFKit failure documentation
