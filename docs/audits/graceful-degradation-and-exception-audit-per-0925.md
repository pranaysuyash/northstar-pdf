# Graceful Degradation & Exception-Handling Architecture Audit (PER-0925 / PER-0929)

**Auditor:** Graceful Degradation Designer (`PER-0925`), supported by Exception-Handling Workflow Designer (`PER-0929`) and Evidence Architect (`PER-0923`)  
**Date:** 2026-08-26  
**Scope:** Degraded-mode taxonomy, capability fallback ladders, tie-breaking abstention semantics, search projection degradation, crash exception recovery states, and partial-result communications across the native PDF editing engine.  
**Doctrine Reference:** Operating Doctrine v8.0 / 6.1

---

## 1. Executive Summary

This audit evaluated how the application behaves when ideal dependencies, permissions, hardware capabilities, network bounds, or cryptographic keys are unavailable or uncertain. The core mandate of `PER-0925` and `PER-0929` is to ensure the product **never fails silently**, **never corrupts state**, and **communicates degraded modes with explicit provenance and safe fallbacks**.

### Fallback Ladders & Degradation Taxonomies:

```
+---------------------------------------------------------------------------------------------------+
| Capability Area      | Level 0 (Primary)    | Level 1 (Fallback 1)  | Level 2 (Fallback 2)  | Level 3 (Safe Abstention) |
+---------------------------------------------------------------------------------------------------+
| 1. Form Filling      | Native AcroForm      | Vector Box Overlay    | Heuristic Static Box  | Manual Point & Click      |
| 2. OCR / Extraction  | Native Text Stream   | Vision OCR Rects      | Character Grid Mesh   | Image-Only Warning Banner |
| 3. Template Matching | Exact Digest (1.0)   | Known Variant (>=0.85)| Family Cluster Review | Strict Tie Abstention     |
| 4. Search Projection | Exact Character Box  | Approximate Geometry  | Page Match Focus      | Unavailable Indicator     |
| 5. Recovery Storage  | Dual-Gen Commit      | Previous Generation   | In-Flight Log Flush   | Clean Zero-State Envelope |
| 6. Document Diff     | Preserved (0 outside)| Warnings (Inside Ops) | Violations (Blocked)  | Incomplete (Page Mismatch)|
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Key Findings & Verified Degradation Behaviors

1. **Provider Capability Negotiation Fallback (PER-0925):**
   - When a requested capability is revoked or out-of-bounds, `ProviderCapabilityNegotiator` strictly abstains with `.abstained`, `selectedProviderID: nil`, and emits unambiguous `reasonCodes` (`providerRevoked`, `capabilityState:revoked`). It never executes unmeasured code in place of a trusted provider.

2. **Template Profile Resolution Ambiguity & Tie Abstention (PER-0929):**
   - When multiple candidate user profiles match template mappings with scores within `ambiguityMargin` (0.05), `PDFTemplateProfileResolver` abstains with `state: .ambiguous` and `abstained: true`. It refuses to guess profile values, escalating to explicit human review.

3. **Document Diff Incompleteness Degradation:**
   - If output PDF geometry or page count differs from source, `DocumentDiffBuilder` degrades gracefully to `DiffOverallStatus.incomplete` with 0 compared regions rather than producing false-clean reports.

4. **Search Projection Visual & Accessibility Degradation:**
   - `SearchProjectionState` transitions through `.exact`, `.approximate`, and `.unavailable`, updating both canvas visual highlights and accessibility elements with assistive messages explaining why exact highlights were unavailable.

5. **OCR Space Coordinate Inversion Safety:**
   - Vision normalized coordinate space (`0...1`, lower-left origin) converts deterministically into PDF page space (`PDFRect`), preserving rotation and scale across non-standard geometries.

---

## 3. Verification Evidence

- **New Test Suite:** `Tests/PDFEditorCoreTests/GracefulDegradationExceptionTests.swift` (4 tests covering capability negotiation fallback, tie-breaking abstention, diff incompleteness, and OCR mapping).
- **Full Test Suite:** **187 tests in 24 suites passed with 0 failures** (`swift test`).
- **Web & Engine Contracts:** All 51 web reader checks and template index invariants passed.
