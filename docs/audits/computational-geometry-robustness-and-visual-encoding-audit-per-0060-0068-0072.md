# Computational Geometry Robustness & Visual Encoding Audit

**Personas:** PER-0060 (Computational Geometry Architect), PER-0068 (Geometry Robustness & Degeneracy Reviewer), PER-0072 (Visual Encoding & Perceptual Accuracy Specialist)

**Audit Date:** 2026-08-26  
**Test File:** `Tests/PDFEditorCoreTests/ComprehensivePersonaAuditProgramTests.swift`  
**Result:** ✅ All geometry/visual encoding tests pass

---

## Executive Summary

The repo previously represented geometry purely through `CGRect` and raw `PDFRect` structs with no protection against degenerate inputs (NaN, negative dimensions, infinite coordinates). The vector stream parser consumed these structs without first standardizing them. Visual encoding (font matching) was isolated in `TextRunFontMatcher` but had no documented guarantees for monospace classification edge cases.

---

## PER-0060 — Computational Geometry Architect

### Findings

| ID | Finding | Severity | Type |
|----|---------|----------|------|
| CGA-01 | `PDFRect` had no intersection/union primitives — any caller rolled their own ad hoc spatial logic | High | Implicit |
| CGA-02 | No `standardized` normalizer meant negative-dimension rects (PDF lower-left origin confusion) propagated into region detection | High | Implicit |
| CGA-03 | `PDFVectorStreamParser` applied CTM transforms directly to potentially negative-dimension rects without pre-normalization | Medium | Implicit |
| CGA-04 | No containment test (`contains(x:y:)`) meant hit-testing in overlay/candidate systems was caller-bespoke | Medium | Implicit |

### Implementations

Added to [`DocumentModel.swift`](file:///Users/pranay/Projects/pdf_editor/Sources/PDFEditorCore/DocumentModel.swift) — `PDFRect` extension:

```swift
public var standardized: PDFRect { ... }          // normalizes negative W/H
public var isEmpty: Bool { ... }                   // guards zero-area rects
public var isNull: Bool { ... }                    // guards NaN coordinates
public func contains(x:y:) -> Bool { ... }
public func intersects(_ other: PDFRect) -> Bool { ... }
public func intersection(_ other: PDFRect) -> PDFRect? { ... }  // returns nil if disjoint
public func union(_ other: PDFRect) -> PDFRect { ... }
```

All operations route through `standardized` first, ensuring:
- Negative dimensions from PDF lower-left/upper-left ambiguity are normalized before any spatial math.
- NaN inputs detected at the boundary (`isNull`) — callers get `isEmpty == true` and avoid invalid geometry cascading.

---

## PER-0068 — Geometry Robustness & Degeneracy Reviewer

### Findings

| ID | Finding | Severity | Type |
|----|---------|----------|------|
| GRD-01 | Inverted rects (width/height < 0) from PDF coordinate systems not handled — passed raw to CoreGraphics | High | Implicit |
| GRD-02 | NaN/Inf bounds from corrupt streams reached region heuristics unchanged | High | Implicit |
| GRD-03 | Zero-width rects (underlines) could enter candidate pools as valid form boxes without area guard | Medium | Explicit |
| GRD-04 | Intersection test against zero-area rect could produce false positive "contained" | Medium | Implicit |

### Test Evidence

```
✔ Test geometryRobustnessNormalizesNegativeAndDegenerateRects() passed after 0.001 seconds.
✔ Test computationalGeometryIntersectionsAndUnions() passed after 0.001 seconds.
```

Regression assertions:
- `PDFRect(x: 100, y: 100, width: -40, height: -30).standardized` → `{x:60, y:70, w:40, h:30}` ✓
- `PDFRect(x: NaN, ...).isNull == true` ✓
- `PDFRect(x: NaN, ...).isEmpty == true` ✓
- Intersection of non-overlapping rects returns `nil` (no false positive) ✓

---

## PER-0072 — Visual Encoding & Perceptual Accuracy Specialist

### Findings

| ID | Finding | Severity | Type |
|----|---------|----------|------|
| VEA-01 | Font family classification (monospace vs proportional) in `TextRunFontMatcher` relied on substring matching; `CourierNew`, `Mono`, `Typewriter`, `Consolas`, `Menlo` covered, but no test validated this at boundary | Medium | Explicit |
| VEA-02 | No visual contract that "Helvetica-Bold" must not be classified as monospace | Low | Implicit |
| VEA-03 | `resolveFont()` is instance-bound but has no side effects — a static helper would have been safer (lower testability surface) | Low | Implicit |

### Test Evidence

```
✔ Test textRunFontMatcherResolvesStandardFontFamilies() passed after 0.001 seconds.
```

Validated:
- `CourierNewPSMT` → `isMonospace == true` ✓
- `Helvetica-Bold` → `isMonospace == false` ✓

---

## First Principles Alignment

| Principle | Status |
|-----------|--------|
| Fail closed on invalid inputs | ✅ `isNull` / `isEmpty` guard before any spatial op |
| No silent data corruption | ✅ `standardized` normalizes before all operations |
| Deterministic outputs | ✅ All geometry ops are pure functions with no mutation |
| Test coverage | ✅ 4 direct test assertions in `ComprehensivePersonaAuditProgramTests` |

---

## Open Improvement Areas

1. **Polygon/quadrilateral support** — PDF AcroForm fields can have quadrilateral bounds (e.g., non-axis-aligned forms). `PDFRect` only models axis-aligned rectangles. A `PDFQuad` type with 4-corner representation would handle rotated form fields.
2. **Coordinate system annotation** — `PDFRect` makes no distinction between PDF coordinate space (bottom-left origin) and CoreGraphics screen space (top-left). A phantom type (`PDFSpaceRect` vs `ScreenSpaceRect`) would catch origin-flip bugs at compile time.
3. **Intersection area ratio** — Adding `intersectionRatio(with:)` returning `0.0–1.0` of overlap would enable better candidate deduplication in `StaticRegionDetector`.
