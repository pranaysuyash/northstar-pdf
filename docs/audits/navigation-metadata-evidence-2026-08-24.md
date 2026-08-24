# Reading and Navigation Metadata Evidence

**Scope:** representative native/web coverage for links, safe-open policy, internal destinations, outlines, attachments, page labels, page boxes, permissions, and security metadata.

**Evidence date:** 2026-08-24

## Fixture

| Artifact | Evidence |
|---|---|
| `benchmark/results/navigation-corpus/navigation-metadata.pdf` | SHA-256 `80216d04ff21a6344910d78aed5d54abd770e46abd560b53c98a41e811a8eb45` |
| Generator | `benchmark/generate_navigation_fixture.sh` |
| Native authoring | `benchmark/PDFKitNavigationFixture.swift` authors three pages, crop/bleed/trim/art boxes, safe and unsafe URL actions, an internal destination, nested outlines, and metadata |
| Structure post-processing | `benchmark/add_navigation_metadata.py` adds three page-label ranges and `fixture-note.txt` through `pypdf`; this boundary is documented because PDFKit does not author file-attachment annotations reliably |
| Independent structure | `qpdf --check` passed with no syntax or stream-encoding errors |

## Contract evidence

`node Tests/pdf_contract_parity_test.mjs` inspected all 11 manifest fixtures. The navigation fixture has zero semantic mismatches for its metadata surfaces after parity projection removes provider-generated identifiers:

- Links: safe `https` URL, blocked `file:` URL preserved as visible metadata, and internal page destination with bounds.
- Outlines: `Introduction`, `Details`, and nested `Nested appendix` hierarchy with page targets.
- Attachments: `fixture-note.txt` is reported by both native and web providers.
- Page labels: uppercase Roman, lowercase letter, and decimal ranges with prefixes.
- Page boxes: crop, bleed, trim, art, and media geometry are present and normalized; shared `bounds` means crop-box geometry.
- Permissions/security: fixture is unencrypted and provider permission facts agree.

## Implementation boundary

- Native extraction uses PDFKit for page actions/outlines and Core Graphics for the PDF name tree; a bounded fallback handles name-tree leaves that Core Graphics does not surface through the Swift bridge.
- Web extraction uses PDF.js for annotations/outlines/labels and pdf-lib for the five page boxes and attachment-preserving inspection support.
- External navigation is allowed only for `http` and `https`; `file:`, `javascript:`, and other schemes remain visible but blocked.
- Internal destinations are safe because they remain inside the opened document.
- Outline root containers are not emitted as user-facing outline rows.
- Provider-generated IDs and explanatory accessibility notes are not parity semantics; labels, destinations, bounds, hierarchy, attachment names, and boolean capability facts are.

## Release interpretation

This closes representative reading/navigation metadata coverage for the fixture and proves native/web semantic parity for those surfaces. It does not claim universal PDF feature support: named-destination edge cases, malformed name trees, encrypted attachment access, tagged-PDF reading order, and PDF/UA conformance remain conditional provider/validator work.

