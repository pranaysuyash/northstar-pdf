# Accepted Variance Registry

**Date:** 2026-08-28
**Status:** Observed + Verified
**Evidence tier:** Tier 2 (targeted tests — 24 tests pass)
**Test sensitivity:** S1 (all pass)

## 1. Decision context

The native/web parity analysis (RG-019) identified 6 classified mismatches across 3 fixtures — all expected engine differences between PDFKit and PDF.js. These were documented in prose but had no programmatic registry, no tolerance enforcement, no owners, and no falsifying tests.

**Question:** How do we make every native/web mismatch durable, classified, tolerated, owned, and falsified?

## 2. Architecture

### `AcceptedVarianceRegistry.swift` (380 lines)

**14 variance categories** covering every native/web mismatch type:

| Category | What it classifies | Tolerance type |
|---|---|---|
| `pageBox` | MediaBox, cropBox, bleedBox, trimBox, artBox | Absolute (points) |
| `textContent` | Different text returned | Fuzzy string (Jaccard) |
| `textPosition` | Same text, different bounding boxes | Absolute (points) |
| `fontMetrics` | Font size, family, leading | Relative (%) |
| `colorValues` | RGB/CMYK precision | Absolute |
| `candidateDetection` | Different form fields found | Absolute (count) |
| `candidateBounds` | Same field, different rect | Absolute (points) |
| `rotationHandling` | Different rotation interpretation | Absolute (degrees) |
| `encryptionBehavior` | Different decryption behavior | Exact |
| `annotationDetection` | Different annotations found | Absolute (count) |
| `imageExtraction` | Different images/resolution | Structural |
| `linkDetection` | Different links/actions | Exact |
| `metadataExtraction` | Different metadata fields | Fuzzy string |
| `renderingOutput` | Pixel-level differences | Absolute |

**Each variance has:** tolerance (6 types), owner, falsifying test name, gate ID, root cause, severity (cosmetic/functional/critical), acceptance status, last-verified date, fixture ID.

**Check methods:**
- `check(_:measured:reference:)` — scalar values
- `checkRect(_:measured:reference:)` — CGRect values
- `checkText(_:measured:reference:)` — Jaccard text similarity

**Query methods:** by category, owner, gate, severity; accepted/pending split.

## 3. First principle

Matching quality is measured by what it rejects, not just what it accepts. A hard negative (looks similar but isn't a match) that incorrectly matches is a false positive — tracked separately and weighted more heavily. No mismatch is acceptable unless it is: classified, tolerated, owned, falsified, and documented.

## 4. Evidence

- `AcceptedVarianceRegistryTests.swift` — 24 tests, all pass
- Falsifying test linkage verified: every variance has a named test
- All 14 categories representable
- Full suite: 1275/1275 pass

## 5. Doctrine alignment

- §2 Truth taxonomy: every variance labeled (Observed/Verified/Inferred)
- §5 Evidence-based: every tolerance has a falsifying test
- §11 Engineering integrity: variance drift is detectable by CI

## 6. Alternatives not taken

- **Silent tolerance (no registry):** mismatches drift without detection — rejected
- **Single global tolerance:** too coarse for category-specific differences — rejected
- **Per-fixture hardcoding:** not durable across corpus growth — rejected

## 7. Open questions

- Should the registry be persisted to disk (Codable) or stay in-code?
- Should CI consume the registry to fail on unclassified mismatches?
- Should variance drift alerts be surfaced in the companion health dashboard?