# PDF Editor Release Gate Registry

**Status:** Active canonical registry
**Created:** 2026-08-24
**Scope:** Native macOS reader/editor, local web companion, shared provider contracts, fixtures, validation, accessibility, security, recovery, and release evidence
**Release rule:** No unrestricted release claim while a hard gate is `OPEN`, `BLOCKED`, or `FAIL`.

## How to use this registry

Every feature is tracked by:

- A stable gate ID.
- A supported lane: native, web, shared, provider, validation, security, or release.
- An acceptance oracle that can be executed or observed.
- A current state: `PASS`, `PARTIAL`, `OPEN`, `BLOCKED`, or `FAIL`.
- A linked evidence artifact.
- A falsifier that prevents optimistic completion claims.

Documentation is part of completion. A gate is not complete until its implementation, test or observation, fixture provenance, limitations, and evidence location are recorded.

## Status vocabulary

| State | Meaning |
|---|---|
| `PASS` | Acceptance oracle executed and evidence recorded |
| `PARTIAL` | A bounded subset works, but support or evidence is incomplete |
| `OPEN` | Work or evidence has not been completed |
| `BLOCKED` | Completion requires an unavailable external capability or decision |
| `FAIL` | The current implementation violates the acceptance oracle |

## Release blockers

| ID | Gate | Lane | Current state | Completion oracle |
|---|---|---|---|---|
| RG-001 | Public AcroForm fidelity | Native/provider | `FAIL` | Product no-op export preserves source bytes; any edit against a document-level AcroForm is now rejected before PDFKit mutation with an explicit read-only capability boundary; a form-aware writer is still required |
| RG-002 | AcroForm provider decision | Shared/provider | `OPEN` | Adopt a form-aware provider or restrict supported form types with an explicit product boundary; qpdf rewrite is insufficient for widget reachability |
| RG-003 | Independent PDF structural validation | Validation | `PARTIAL` | Source fixtures pass qpdf 12.4.0; 6 recoverable Form 6 offset-warning artifacts are classified separately, while 8 generated artifacts remain hard failures for unreachable AcroForm widgets under the documented policy |
| RG-004 | PDF/UA validation | Validation | `BLOCKED` | A validator-backed PDF/UA report exists for supported output |
| RG-005 | Authored tag-tree preservation | Native/web/provider | `OPEN` | Source structure tree is preserved or explicitly rejected with evidence |
| RG-006 | Native VoiceOver workflow | Native/accessibility | `OPEN` | VoiceOver observation covers all reader controls, errors, and navigation |
| RG-007 | Browser screen-reader workflow | Web/accessibility | `OPEN` | Screen-reader observation covers landmarks, text layer, search, status, and password flow |
| RG-008 | Scanned-PDF OCR corpus | Shared/OCR | `PARTIAL` | Deterministic raster-only English fixture and native no-text fallback are covered; broader scanned corpus and web OCR remain open |
| RG-009 | OCR acceptance thresholds | OCR/validation | `PARTIAL` | Anchor-based Tesseract benchmark is recorded; Vision accuracy, layout, confidence, language, and uncertainty thresholds remain open |
| RG-010 | Encrypted-document corpus | Native/web/security | `PARTIAL` | AES-256 password fixture, native/web inspection, byte-preserving web no-op export, and qpdf validation are covered; edited encrypted PDFs, wrong/cancelled password corpus, and unsupported-encryption evidence remain open |
| RG-011 | Rotated-page corpus | Native/web/shared | `PARTIAL` | Native rotated-page inspection now has a regression fixture; full native/web rendering and coordinate corpus remains open |
| RG-012 | Malformed-PDF corpus | Shared/security | `PARTIAL` | Truncated fixture is generated and rejected by qpdf; native/web runtime and broader malformed-object corpus remain open |
| RG-013 | Large-document/resource limits | Shared/security | `PARTIAL` | Byte/page limits and a 20-page repeated fixture are covered; memory/time and large-structure corpus remain open |
| RG-014 | Signed-document behavior | Native/web/security | `OPEN` | Signatures are detected and edit invalidation is explicit and safe |
| RG-015 | XFA behavior | Native/web/provider | `OPEN` | XFA is detected, supported, or safely rejected without false AcroForm claims |
| RG-016 | Independent-viewer reopen | Validation | `PARTIAL` | Poppler and MuPDF independently reopen 35 eligible source and derived corpus PDFs while qpdf provides separate structural validation; visual diff and semantic fidelity comparison remain open |
| RG-017 | Source-integrity validation | Shared/provider | `PARTIAL` | Native and browser operation gates reject stale source digests before mutation; browser writer-call and pdf-lib-load probes pass, broader adapter and source-replacement coverage remains open |
| RG-018 | Output-integrity validation | Shared/provider | `PARTIAL` | Output preserves all bounded invariants after reopen |
| RG-019 | Native/web parity corpus | Shared | `PARTIAL` | Native and web runners now consume the same current ten-entry manifest with explicit password, malformed, OCR, and rotation expectations; normalized fact comparison remains open |
| RG-020 | Browser export fidelity | Web/provider | `PARTIAL` | Byte-preserving no-op export for all PDFs and bounded overlay/form exports have evidence; web output still lacks unrestricted external-form and encrypted-edit fidelity |
| RG-021 | Local dependency packaging | Web/release | `PASS` | PDF.js and pdf-lib are locally packaged with licenses and load successfully from the local server |
| RG-022 | Runtime-unavailable behavior | Web/release | `PASS` | Missing runtime disables controls and announces recovery without startup crash |
| RG-023 | External-link security | Web/security | `PARTIAL` | Dangerous schemes and malformed destinations are blocked and confirmed safely |
| RG-024 | Attachment security | Native/web/security | `OPEN` | Attachments cannot trigger unsafe execution or path traversal |
| RG-025 | Password handling security | Native/web/security | `PARTIAL` | Passwords never persist in logs, diagnostics, or durable state |
| RG-026 | Temporary-file cleanup | Native/provider | `PARTIAL` | Failed and interrupted exports clean temporary artifacts; staged validation now occurs before publication, interruption/crash sweep remains open |
| RG-027 | Permission enforcement | Native/web/provider | `PARTIAL` | Provider permissions are accurate and editing is blocked when required |
| RG-028 | Privacy boundary | Shared/release | `PARTIAL` | Document bytes and secrets remain local unless explicit consent authorizes transfer |
| RG-029 | Crash and recovery behavior | Native/web | `OPEN` | Import, render, worker, export, and termination failures recover safely |
| RG-030 | Undo and recovery corpus | Shared/native | `PARTIAL` | Undo rebuilds from immutable source for mixed operations |

## Reading and navigation gates

| ID | Gate | Lane | Current state | Completion oracle |
|---|---|---|---|---|
| RG-031 | Custom and missing page labels | Native/web | `PARTIAL` | Roman, custom, duplicate, blank, and absent labels behave predictably |
| RG-032 | Media/crop/bleed/trim/art boxes | Native/web | `PARTIAL` | Optional and unusual page boxes are surfaced without coordinate drift |
| RG-033 | Rotation coordinate integrity | Native/web | `PARTIAL` | Rotation preserves source geometry, links, search, and edit coordinates |
| RG-034 | Fit-width behavior | Native/web | `PARTIAL` | Portrait, landscape, mixed-size, and rotated pages fit without clipping |
| RG-035 | Fit-page behavior | Native/web | `PARTIAL` | Unusual page sizes center and scale correctly |
| RG-036 | Two-page behavior | Native/web | `PARTIAL` | Odd counts, cover pages, RTL, mixed sizes, and rotation are correct |
| RG-037 | Continuous-view performance | Native/web | `OPEN` | Large documents remain navigable within measured memory/time budgets |
| RG-038 | Thumbnail correctness | Native/web | `PARTIAL` | Thumbnail content, label, rotation, and selection remain synchronized |
| RG-039 | Extractable-text selection | Native/web | `PARTIAL` | Unicode, ligatures, line breaks, columns, rotation, and empty pages select correctly |
| RG-040 | OCR selection fallback | Native/web/OCR | `PARTIAL` | Native image-only state and OCR fixture are explicit; OCR-derived selectable text and web fallback remain open |
| RG-041 | Search matching | Native/web | `PARTIAL` | Unicode, case, ligatures, line breaks, repeated and empty matches are correct |
| RG-042 | Search highlight alignment | Native/web | `PARTIAL` | Highlights remain aligned under scale, rotation, and mixed page geometry |
| RG-043 | Search status announcements | Native/web/accessibility | `OPEN` | Match counts, current result, page changes, and no-match state are announced |
| RG-044 | Internal links | Native/web | `PARTIAL` | Valid, missing, invalid, named, and remote destinations are handled safely |
| RG-045 | External links | Native/web/security | `PARTIAL` | Only permitted schemes proceed after explicit confirmation |
| RG-046 | Outlines and bookmarks | Native/web | `PARTIAL` | Nested, missing-target, duplicate, empty, and deep outlines work predictably |
| RG-047 | Metadata normalization | Native/web | `PARTIAL` | Absent, malformed, Unicode, date, creator, producer, and custom metadata are safe |
| RG-048 | Permission normalization | Native/web | `PARTIAL` | Missing, restricted, encrypted, and provider-specific permissions are explicit |
| RG-049 | Attachment inventory | Native/web | `PARTIAL` | Attachments, duplicate names, unavailable payloads, and safe handling are covered |
| RG-050 | Password interaction | Native/web | `PARTIAL` | Wrong, empty, cancelled, repeated, and successful password flows reset safely |
| RG-051 | Accessible reading surface | Native/web | `PARTIAL` | Browser runtime gate proves landmarks, keyboard text spans, focus, and password semantics; native and assistive-technology consumption remains open |
| RG-052 | Accessibility source fidelity | Native/web | `OPEN` | Source structure is preserved or clearly marked unavailable |
| RG-053 | Tagged-content messaging | Native/web | `PASS` | UI never presents extracted text as PDF/UA proof |
| RG-054 | Empty-text state | Native/web | `PARTIAL` | Native inspection signals OCR/unavailable text; web OCR UI state remains open |
| RG-055 | Clipboard behavior | Native/web | `PARTIAL` | Secure, insecure, denied, empty, and large-copy paths are safe |
| RG-056 | Keyboard operation | Native/web | `PARTIAL` | Browser runtime gate covers landmarks, skip-link focus, text-layer focus, and password dialog; full reader action matrix and native keyboard observation remain open |
| RG-057 | Focus restoration | Native/web/accessibility | `OPEN` | Focus returns predictably after modal, search, link, error, and jump actions |
| RG-058 | Reduced motion | Native/web/accessibility | `OPEN` | Motion preferences are respected across reader transitions |
| RG-059 | Zoom and responsive layout | Web/accessibility | `OPEN` | 200% zoom, large text, narrow windows, and high contrast remain usable |

## Fixture corpus gates

| ID | Fixture category | Current state | Completion oracle |
|---|---|---|---|
| RG-060 | Plain text PDFs | `OPEN` | Text, Unicode, ligatures, headings, paragraphs, and multi-page cases are reviewed |
| RG-061 | Image-only PDFs | `PARTIAL` | Clean printed raster fixture is reviewed; skewed, noisy, low-contrast, handwritten, and rotated scans remain open |
| RG-062 | Mixed PDFs | `OPEN` | Text, images, annotations, tables, and forms coexist without false facts |
| RG-063 | Multi-column PDFs | `OPEN` | Columns, sidebars, and footnotes have documented reading-order behavior |
| RG-064 | Geometry PDFs | `OPEN` | Sizes, boxes, rotation, and coordinate transforms are reviewed |
| RG-065 | Navigation PDFs | `OPEN` | Links, destinations, outlines, missing targets, and remote actions are reviewed |
| RG-066 | Metadata PDFs | `OPEN` | Complete, absent, malformed, Unicode, and custom metadata are reviewed |
| RG-067 | Attachment PDFs | `OPEN` | Single, multiple, duplicate, large, and suspicious attachment names are reviewed |
| RG-068 | Encryption PDFs | `PARTIAL` | AES-256 user/owner password fixture is recorded; empty, wrong, restricted, and unsupported-encryption cases remain open |
| RG-069 | Form PDFs | `PARTIAL` | Text, checkbox, radio, choice, signature, shared-name, and widget-parent cases are reviewed |
| RG-070 | Signed PDFs | `OPEN` | Valid, invalid, multiple, and post-signature edit cases are reviewed |
| RG-071 | XFA PDFs | `OPEN` | Static, dynamic, hybrid, and unsupported XFA cases are reviewed |
| RG-072 | Malformed PDFs | `PARTIAL` | Truncated input is recorded; invalid xref/object/stream/page-tree/annotation cases remain open |
| RG-073 | Resource-stress PDFs | `PARTIAL` | 20-page repeated input is recorded; large-image, annotation, link, text, and attachment stress cases remain open |
| RG-074 | Provider comparison fixtures | `PARTIAL` | Same current ten-entry manifest runs through native and web lanes; independent provider comparison and normalized diff remain open |

## Product, documentation, and release-control gates

| ID | Gate | Current state | Completion oracle |
|---|---|---|---|
| RG-075 | Feature inventory alignment | `PARTIAL` | Inventory, journal, status, and audit agree on every feature state |
| RG-076 | Canonical capability matrix | `OPEN` | Native, web, provider, OCR, validator, and unsupported states are centralized |
| RG-077 | Error taxonomy | `PARTIAL` | Stable native and web classes plus staged validation/recovery semantics are documented; complete UI/runtime observation and redaction evidence remain open |
| RG-078 | Evidence tier labeling | `PASS` | Source, unit, provider, browser, screen-reader, and validator evidence remain separate |
| RG-079 | Persona review record | `PASS` | Persona lenses and acceptance criteria are linked to the gates |
| RG-080 | Doctrine record | `PASS` | Local-first, source-preserving, capability-bounded, and evidence-led decisions are recorded |
| RG-081 | Release runbook | `OPEN` | One reproducible sequence runs tests, benchmarks, browser fixtures, validators, and reports |
| RG-082 | Fixture provenance | `PARTIAL` | Seven-entry corpus paths, hashes, generation commands, and expected security outcomes are recorded; external source/license confirmation and broader corpus expansion remain open |
| RG-083 | Dependency provenance | `PARTIAL` | Vendored runtime versions, sources, hashes, licenses, and local validation-tool versions are recorded; upgrade policy and shipped-provider licensing remain open |
| RG-084 | Support policy | `OPEN` | Supported macOS, browsers, PDF types, limits, encryption, and OCR languages are explicit |
| RG-085 | Observability policy | `PARTIAL` | Canonical diagnostics boundary is documented; implementation and automated redaction evidence remain open |
| RG-086 | Recovery documentation | `PARTIAL` | Interrupted export, corrupt input, password, runtime, and unsupported-feature recovery are documented |
| RG-087 | Accessibility claim policy | `PASS` | Reader surface, extraction, tags, and PDF/UA are clearly separated |
| RG-088 | Independent review | `OPEN` | A non-implementation reviewer evaluates fidelity, browser behavior, and accessibility |
| RG-089 | Release sign-off | `OPEN` | All hard gates pass or are deliberately removed from the supported scope |
| RG-090 | Long-term web deployment shape | `PASS` | D-009 and `docs/web-deployment-decision.md` accept a browser local core plus an explicitly installed optional companion capability plane; OCR and high-fidelity editing are companion placements, while packaging and provider adoption remain separately gated |

## Current disposition

| Area | Disposition |
|---|---|
| Feature A bounded reader/navigation | `GO` for internal development and review |
| Native and web smoke paths | `PASS` on current evidence |
| General lossless PDF editing | `NO-GO` |
| General AcroForm fidelity | `NO-GO` |
| PDF/UA conformance | `NO-GO` |
| Unrestricted production release | `NO-GO` |

## Evidence links

- [Feature A implementation journal](feature-expansion-implementation-log-a.md)
- [Feature A evidence audit](audits/feature-a-reading-navigation-evidence-2026-08-24.md)
- [Implementation status](implementation-status.md)
- [Feature inventory](feature-expansion-inventory.md)
- [Native/web platform matrix](native-web-platform-matrix.md)
- [Project decisions](decisions.md)
- [Web contract test](../Tests/web_reader_contract_test.mjs)
- [Native core tests](../Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift)
- [Contract negative-test evidence](audits/contract-negative-test-evidence-2026-08-24.md)
