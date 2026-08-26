# PDF Editor Support Policy

**Gate:** RG-084
**Status:** DRAFT — requires human product decision before activation
**Created:** 2026-08-26
**Authority:** Release gate registry; not a marketing document

## Purpose

This document defines the explicit boundaries of what the PDF Editor supports.
Any capability outside these boundaries is either not supported or supported
with explicit caveats. The product must not advertise capabilities beyond these
boundaries without updating this document first.

## 1. Platform support

### macOS (native app)

| Tier | Platform | Minimum version | Architecture | Status |
|---|---|---|---|---|
| **Primary** | macOS Sequoia | 15.0+ | Apple Silicon (M1+) | Supported |
| **Secondary** | macOS Sonoma | 14.0+ | Apple Silicon (M1+) | Best-effort |
| **Tertiary** | macOS Ventura | 13.0+ | Intel (x86_64) | Not supported |

**Rationale:** Swift Package targets macOS 15 with no third-party runtime
dependencies. PDFKit behavior varies across macOS versions; we test on 15.0+.
Apple Silicon is primary because of Apple Vision framework availability and
performance budget compliance.

**Known PDFKit limitations:**
- Radio button serialization corruption (Apple FB22167174)
- Radio-choice metadata loss on no-op save (F-016)
- Tile rendering crashes on lower-RAM iPads (iPadOS 26.x)
- Form field handling issues (Apple Developer Forums)

These limitations are mitigated by using PDFIncrementalFormWriter for all
writes, which bypasses PDFKit's broken form handling.

### Web companion (browser)

| Tier | Browser | Minimum version | Status |
|---|---|---|---|
| **Primary** | Safari | 17.0+ (macOS Sonoma) | Supported |
| **Secondary** | Chrome | 120+ | Supported |
| **Tertiary** | Firefox | 121+ | Best-effort |
| **Unsupported** | Edge, Opera, mobile browsers | — | Not supported |

**Rationale:** The web companion uses PDF.js canvas/text layer, local vendor
bundling, and a strict Content Security Policy. Safari and Chrome are tested
in CI. Firefox is best-effort because PDF.js behavior varies. Mobile browsers
are not supported because the UI requires desktop-class interaction.

## 2. PDF type support

### Supported PDF types

| Type | Status | Evidence | Notes |
|---|---|---|---|
| Plain text PDFs | Supported | RG-060, corpus-sweep | Heading, paragraph, Latin-1 accented words |
| Image-only PDFs | Supported (read-only) | RG-061 | OCR available via Vision adapter (English) |
| Mixed text/form PDFs | Supported | RG-062 | Text/form plus raster hybrid covered |
| Multi-column PDFs | Supported | RG-063 | Two-column landscape with sidebar verified |
| Geometry PDFs | Supported | RG-064 | Unusual page sizes, rotation, crop boxes |
| Navigation PDFs | Supported | RG-065 | Outlines, URI links, internal destinations |
| Metadata PDFs | Supported | RG-066 | Complete, absent, Unicode, custom, malformed |
| Attachment PDFs | Supported (inventory) | RG-067 | 8-entry synthetic corpus; safe extraction pending |
| Encryption PDFs | Supported (read-only) | RG-068 | AES-256 user/owner password; edit requires decrypt |
| Form PDFs | Supported | RG-069 | Text, checkbox, radio, choice, signature fields |
| Signed PDFs | Supported (read-only) | RG-070 | Detection only; editing refused until signature flow |
| XFA PDFs | Supported (read-only) | RG-071 | Detection only; editing refused |
| Malformed PDFs | Supported (safe failure) | RG-072 | Truncated inputs fail safely; no crash |
| Resource-stress PDFs | Supported (bounded) | RG-073 | 20-page and 40-page fixtures pass reopen |

### Not supported

| Type | Status | Reason |
|---|---|---|
| Encrypted with unknown algorithm | Not supported | Provider admission rejects |
| Password-protected with unsupported encryption | Not supported | Provider admission rejects |
| Corrupted/invalid xref table | Partial (safe failure) | qpdf validates; native/web reject |
| PDF with embedded executables | Not supported | Security boundary |
| PDF with JavaScript (active content) | Refused for editing | Neutralized in sanitization flow |

## 3. Document limits

| Limit | Value | Evidence | Notes |
|---|---|---|---|
| Maximum file size | 500 MB | RG-013 | Resource-stress gate; larger files may fail |
| Maximum page count | 1000 pages | RG-013 | 40-page fixture tested; larger pages may degrade |
| Maximum field count | 10,000 fields | RG-001 | AcroForm field tree walk budget < 0.5s |
| Maximum attachment size | 100 MB total | RG-049 | Inventory only; extraction not yet supported |
| Maximum outline depth | 100 levels | RG-046 | Deep outlines handled safely |
| Maximum metadata size | 10 KB | RG-047 | Larger metadata truncated safely |

## 4. Encryption support

| Encryption type | Read | Edit | Notes |
|---|---|---|---|
| AES-256 (user password) | ✅ | ✅ (incremental) | Source-preserving incremental update |
| AES-256 (owner password) | ✅ | ✅ (incremental) | Same as user password |
| AES-128 | ✅ | ✅ (incremental) | Same as AES-256 |
| RC4 (40-bit) | ✅ | ⚠️ (limited) | Older encryption; some providers may reject |
| RC4 (128-bit) | ✅ | ⚠️ (limited) | Same as RC4 40-bit |
| No encryption | ✅ | ✅ | Full support |

**Edit policy:** Encryption is transparent for read operations. For edit
operations, the document is decrypted before editing and re-encrypted after
export. The source-preserving incremental update lane preserves the original
encryption. The companion lane uses qpdf decrypt/re-encrypt.

## 5. OCR support

| Language | Provider | Status | Notes |
|---|---|---|---|
| English | Apple Vision | Supported | Full page-rendering recognition |
| English | Tesseract CLI | Best-effort | Fails noisy-scan gate (RG-096) |
| English | Tesseract.js WASM | Best-effort | Fails noisy-scan gate (RG-096) |
| Other languages | — | Not supported | Multilingual OCR is a Gen 2 target |

**OCR policy:** OCR is a fallback for image-only PDFs where extractable text
is unavailable. It is not a general release claim. OCR results are presented
as provider-dependent facts, not ground truth.

## 6. Accessibility support

| Feature | Status | Notes |
|---|---|---|
| VoiceOver (macOS) | Partial | 38+ annotations; human observation pending |
| Keyboard navigation | Partial | ⌘F focus, skip-link, text-layer focus implemented |
| Reduce Motion | Partial | All identified animations gated |
| High Contrast | Partial | Contrast-aware HUD strokes implemented |
| Screen reader (web) | Partial | 46+ aria- attributes; observation pending |
| Dynamic Type | Partial | No fixed-size fonts; large-text observation pending |

**Accessibility policy:** Accessibility features are implemented but not
fully observed. No accessibility claim is made until human observation passes
across all controls.

## 7. Supported operations

| Operation | Native | Web | Notes |
|---|---|---|---|
| Open/read | ✅ | ✅ | Full support |
| Navigate | ✅ | ✅ | Page, outline, search |
| Search | ✅ | ✅ | Extractable text only |
| Copy text | ✅ | ✅ | Extractable text only |
| View metadata | ✅ | ✅ | Provider-dependent |
| View permissions | ✅ | ✅ | Informational only |
| View attachments | ✅ | ✅ | Inventory only |
| Fill text fields | ✅ | ✅ | AcroForm text widgets |
| Toggle checkboxes | ✅ | ✅ | AcroForm checkbox widgets |
| Select radio options | ✅ | ✅ | AcroForm radio groups |
| Place text overlay | ✅ | ✅ | Reversible FreeText overlay |
| Direct text placement | ✅ | ✅ | Double-click placement |
| Undo | ✅ | ✅ | Source-preserving undo |
| Export (source-preserving) | ✅ | ✅ | Incremental update |
| Export (overlay) | ✅ | ✅ | PDFKit/pdf-lib |
| Sanitize (metadata/attachments) | ✅ | ✅ | qpdf + pikepdf pipeline |
| Neutralize (active content) | ✅ | ✅ | Delete JS/actions/launch |
| Inspect hidden revisions | ✅ | ✅ | Revision chain walker |
| OCR (English) | ✅ | ❌ | Vision adapter only |

## 8. Not supported operations

| Operation | Status | Notes |
|---|---|---|
| Arbitrary text editing | Not supported | Text-run replacement under development |
| Image/vector redaction | Not supported | Whiteout rejection only |
| XFA form editing | Not supported | Detection and refusal only |
| Signature creation | Not supported | Detection and refusal only |
| Signature validation | Not supported | Structural detection only |
| PDF/UA authoring | Not supported | Tagged structure preservation only |
| Collaboration | Not supported | Gen 3 target |
| Sync | Not supported | Gen 3 target |
| Batch processing | Not supported | Individual document workflow |
| Cloud storage integration | Not supported | Local-first architecture |

## 9. Update and support lifecycle

| Phase | Duration | Support level |
|---|---|---|
| Current release | Active development | Full support per this policy |
| Previous release | N-1 | Security fixes only |
| Older releases | N-2+ | No support |

**Support commitment:** Security vulnerabilities are patched within 72 hours
of confirmation. Feature requests are tracked but not guaranteed.

## 10. Evidence and verification

Every claim in this policy is backed by:
- A specific evidence gate (RG-XXX) in the release gate registry
- A test suite that exercises the boundary
- A falsifier that proves the limitation

This policy is reviewed and updated with each release. Changes to supported
capabilities require updating this document, the capability matrix
(`docs/capability-matrix.json`), and the release gate registry.

---

**Decision required:** This document is a DRAFT. The human product owner must
review and approve the specific version numbers, page limits, and encryption
support levels before this policy becomes active. The values above are based
on current implementation evidence and should be treated as recommendations.
