# RUN-MAC-P2 — Marcus Chen (Clinic Front-Office Lead, Regulated) — Native Mac lane

**Date:** 2026-09-07 · **Surface:** Native macOS, PDFKit provider via prebuilt `.build/debug/PDFContractHarness`
**Persona goal:** Process PHI-adjacent intake packets with local-only handling, visible privacy preflight + provenance, and safe behavior on encrypted/problem inputs. Nothing leaves the device; no silent automation.
**Fixtures (mini-manifest `evidence/mac-P2-manifest.md`):**
- `benchmark/results/browser-corpus/hybrid-text-raster-form.pdf` (text/form + raster page, 6 native fields)
- `benchmark/results/browser-corpus/encrypted-hybrid.pdf` (AES-256, reader password `reader-password`)
- `benchmark/results/navigation-corpus/navigation-metadata.pdf` (3 pages, outlines, URLs, attachment — preflight stress)

## Steps (expected → observed)
| # | Step | Expected | Observed | Result |
|---|------|----------|----------|--------|
| 1 | Inspect hybrid form | opens, fields visible, candidates require review | `inspected`, digest `91d7ede0…`, 2 pages, **6 fields**, 0 candidates, preflight ✓, `validated` | PASS |
| 2 | Inspect encrypted hybrid | opens with harness password policy, provenance bound, no secret persisted | `inspected`, digest `7aa4e042…`, 2 pages, 6 fields, preflight ✓, provenance `sessionID native-7aa4e042…`, OCR `not-used`, URLs/text/values excluded from provenance | PASS |
| 3 | Inspect navigation/attachment fixture | preflight surfaces metadata/attachment/URL presence as counts, not content | `inspected`, digest `80216d04…`, 3 pages, 0 fields, preflight ✓, `validated` | PASS |
| 4 | Harness exit code | 0 | `EXIT:0` | PASS |

## Privacy facts (encrypted-hybrid bundle, `/tmp/mac-sim-P2/`)
- `session-provenance` header: `pdf-editor.session-provenance` v1.0, provider pdfkit/macOS.
- Payload: export `succeeded`/`local-file`/`validated`/`outputReopenable: true`; OCR `not-used` with `recognizedTextRetained: false`; privacy flags `URLsIncluded/ documentTextIncluded/fieldValuesIncluded: false`.
- No password, bytes, or field values in any bundle (value-free by contract).

## Verdict: PASS
Marcus's trust prerequisites — local-only provenance, preflight on every open, encrypted input handled inside the password policy without leaking secrets — hold in the native lane.

## Friction / follow-ups (not failures)
- Verified 2026-09-07 (evidence map, Tier 1 + focused suites green): encrypted sources are refused fail-closed at three writer entries (`PDFIncrementalFormWriter.swift:299,890,1066`, `encryptedUnsupported`, S3 via `PDFIncrementalWriterTests:460-474`) plus the provider password gate (`PDFKitProvider.swift:31-36,64-70`, S2 via `PDFReaderGateTests:167-188`). Compressed-object sources are **not** refused — ObjStm is transparently resolved since the 2026-09-07 retirement (`PDFIncrementalFormWriter.swift:122-124,483-495`); only genuinely undecodable streams throw. Older docs citing a `compressedObject` refusal are stale on this point.
- Known gaps (recorded, not hidden): no encrypted-rejection unit in `ProviderCapabilityContracts` (contract layer), and signature/XFA presence is observational (`sigFlags`/`inspectXFA` recorded, no fail-closed edit refusal in the export lane) — matches RG-014/RG-015 PARTIAL.
- Native GUI display of the preflight/provenance panels (what Marcus actually sees) still needs a click-through on the built app (runbook: `docs/simulations/NATIVE-GUI-CLICKTHROUGH-RUNBOOK.md`).
