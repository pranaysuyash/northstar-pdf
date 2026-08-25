# PDF Editor Capability Matrix

**Status:** Canonical full-capability implementation and evidence matrix
**Rule:** A capability is not advertised as supported unless its provider,
fixture, validator, and failure behavior are all identified. This rule governs
claims and activation, not whether the capability is built. Every row is a
long-term implementation target for native, browser, companion, or provider
adapters.

Provider selection is governed by the separate
[`provider capability system`](provider-capability-system-design.md). An
installed engine is not automatically a supported capability. The registry must
bind the exact artifact digest to a named measurement, license state, source
limits, and revocation state before default routing.

This matrix is both a build register and an evidence register. A row marked
conditional, restricted, unknown, or unsupported describes the current provider
and claim state for a document class. It does not remove that row from the
long-term implementation target. Every such row must retain a contract,
adapter, corpus, validator, privacy/security model, and recovery path.

| Capability | Native macOS | Web companion | Shared contract | Evidence gate | Product claim |
|---|---|---|---|---|---|
| Open/import | PDFKit | PDF.js | `DocumentSource` | RG-001, RG-060 | Supported for bounded local files |
| Render/navigation | PDFKit/PDFView | PDF.js canvas/text layer | `ViewState` | RG-031-RG-038 | Supported on reviewed PDFs |
| Extractable text | PDFKit | PDF.js | page text evidence | RG-039, RG-060 | Supported with provider caveats |
| OCR fallback | Vision adapter | Not yet wired | OCR evidence | RG-008-RG-009, RG-061 | Not a general release claim |
| Search | PDFKit document search | PDF.js text content | search match contract | RG-041-RG-043 | Supported for extractable text |
| Text copy | NSPasteboard | Clipboard/fallback | page text | RG-039, RG-055 | Supported for extractable text |
| Links | PDFKit actions | PDF.js annotations | `PDFLink` | RG-044-RG-045 | Safe internal/external subset |
| Outlines | PDFKit outline | PDF.js outline | `PDFOutlineItem` | RG-046, RG-065 | Supported when source exposes targets |
| Metadata | PDFKit attributes | PDF.js metadata | `PDFDocumentMetadata` | RG-047, RG-066 | Provider-dependent facts |
| Permissions | PDFKit permissions | PDF.js permissions | `PDFPermissionsSummary` | RG-027, RG-048 | Informational until enforcement corpus passes |
| Attachments | PDFKit inventory | PDF.js inventory | attachment facts | RG-024, RG-049, RG-067 | Inventory only until safe extraction passes |
| Password open | PDFKit unlock | PDF.js callback | `PDFSecuritySummary` | RG-010, RG-050, RG-068 | Supported for provider-compatible encryption |
| Native AcroForms | PDFKit inspect/apply | pdf-lib bounded path | field operation contract | RG-001-RG-002, RG-069 | Restricted pending provider decision |
| Overlays | PDFKit FreeText | pdf-lib drawText | `EditOperation` | RG-018, RG-020 | Bounded overlay subset |
| Signatures | Detection not complete | Detection not complete | security facts | RG-014, RG-070 | Not supported for editing claims |
| XFA | Not established | Not established | unsupported capability | RG-015, RG-071 | Explicitly unsupported until proven |
| Tagged PDF | Conditional | Conditional | accessibility facts | RG-004-RG-005, RG-052 | No PDF/UA claim |
| Reader accessibility | Native UI | DOM landmarks/text layer | status/focus semantics | RG-006-RG-007, RG-051, RG-056-RG-059 | Surface implemented, observation pending |
| Export validation | PDFKit reopen checks | pdf-lib reopen checks | `ValidationReport` | RG-016-RG-020 | No unrestricted fidelity claim |
| Provider admission and revocation | Registry and native negotiator | Registry and browser negotiator | `pdf-editor.provider-capability-*` | provider registry, license, measurement, bridge, and revocation gates | Contract slice implemented; installer and live companion remain open |
