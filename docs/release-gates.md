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
| RG-002 | AcroForm provider decision | Shared/provider | `PASS` | Resolved 2026-08-25: adopted a custom incremental-update form writer (`web/pdf-incremental-form-writer.mjs`). Source-prefix bytes preserved (RG-017/RG-018 hold by construction), external AcroForm radio choice survives independent reopen (pikepdf/Poppler), qpdf `--check` clean. Full rewrite falsified as RG-017 violation. Companion/PDFium/PDFBox paths remain optional (D-048). |
| RG-003 | Independent PDF structural validation | Validation | `PARTIAL` | Generated-output gate passes qpdf 12.4.0 for 39 PDFs with 0 hard failures; 6 Form 6 artifacts retain classified recoverable offset warnings and are not structurally clean |
| RG-004 | PDF/UA validation | Validation | `BLOCKED` | A validator-backed PDF/UA report exists for supported output |
| RG-005 | Authored tag-tree preservation | Native/web/provider | `OPEN` | Source structure tree is preserved or explicitly rejected with evidence |
| RG-006 | Native VoiceOver workflow | Native/accessibility | `OPEN` | VoiceOver observation covers all reader controls, errors, and navigation |
| RG-007 | Browser screen-reader workflow | Web/accessibility | `OPEN` | Screen-reader observation covers landmarks, text layer, search, status, and password flow |
| RG-008 | Scanned-PDF OCR corpus | Shared/OCR | `PARTIAL` | Deterministic raster-only English fixture and native no-text fallback are covered; broader scanned corpus and web OCR remain open |
| RG-009 | OCR acceptance thresholds | OCR/validation | `PARTIAL` | Anchor-based Tesseract benchmark is recorded; Vision accuracy, layout, confidence, language, and uncertainty thresholds remain open |
| RG-010 | Encrypted-document corpus | Native/web/security | `PARTIAL` | AES-256 password fixture, native/web inspection, byte-preserving web no-op export, and qpdf validation are covered; edited encrypted PDFs, wrong/cancelled password corpus, and unsupported-encryption evidence remain open |
| RG-011 | Rotated-page corpus | Native/web/shared | `PARTIAL` | Native rotated-page inspection now has a regression fixture; full native/web rendering and coordinate corpus remains open |
| RG-012 | Malformed-PDF corpus | Shared/security | `PARTIAL` | Truncated fixture is generated and rejected by qpdf; native/web runtime and broader malformed-object corpus remain open |
| RG-013 | Large-document/resource limits | Shared/security | `PARTIAL` | Byte/page limits, a 20-page repeated fixture, and a 40-page hybrid fixture are covered; memory/time and large-structure corpus remain open |
| RG-014 | Signed-document behavior | Native/web/security | `OPEN` | Signatures are detected and edit invalidation is explicit and safe |
| RG-015 | XFA behavior | Native/web/provider | `OPEN` | XFA is detected, supported, or safely rejected without false AcroForm claims |
| RG-016 | Independent-viewer reopen | Validation | `PARTIAL` | Poppler and MuPDF independently reopen 53 eligible source and derived corpus PDFs while qpdf provides separate structural validation; visual diff and semantic fidelity comparison remain open |
| RG-017 | Source-integrity validation | Shared/provider | `PARTIAL` | Native and browser operation gates reject stale source digests before mutation; browser writer-call and pdf-lib-load probes pass, broader adapter and source-replacement coverage remains open |
| RG-018 | Output-integrity validation | Shared/provider | `PARTIAL` | Output preserves all bounded invariants after reopen |
| RG-019 | Native/web parity corpus | Shared | `PARTIAL` | Native and web runners consume the same current eighteen-entry manifest with explicit scanned, synthetic handwriting-like, hybrid, password, malformed, large, OCR, and rotation expectations; 6 classified mismatches remain, 4 on Form 6 candidates and 2 on encrypted-hybrid geometry/coordinates |
| RG-020 | Browser export fidelity | Web/provider | `PARTIAL` | Byte-preserving no-op export and bounded overlay/form exports pass across the expanded valid corpus; web output still lacks unrestricted external-form, encrypted-edit, and universal provider fidelity |
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
| RG-061 | Image-only PDFs | `PARTIAL` | Clean, deterministic noisy raster, and synthetic handwriting-like fixtures are governed and structurally reviewed; genuine handwriting, OCR accuracy, low-contrast, multilingual, and rotated scan behavior remain open |
| RG-062 | Mixed PDFs | `PARTIAL` | Two-page text/form plus raster hybrid and 40-page hybrid stress fixtures pass browser/native reopen and bounded export gates; tables, annotations, and broader mixed-content classes remain open |
| RG-063 | Multi-column PDFs | `OPEN` | Columns, sidebars, and footnotes have documented reading-order behavior |
| RG-064 | Geometry PDFs | `OPEN` | Sizes, boxes, rotation, and coordinate transforms are reviewed |
| RG-065 | Navigation PDFs | `OPEN` | Links, destinations, outlines, missing targets, and remote actions are reviewed |
| RG-066 | Metadata PDFs | `OPEN` | Complete, absent, malformed, Unicode, and custom metadata are reviewed |
| RG-067 | Attachment PDFs | `OPEN` | Single, multiple, duplicate, large, and suspicious attachment names are reviewed |
| RG-068 | Encryption PDFs | `PARTIAL` | AES-256 user/owner password fixtures include native-widget and hybrid sources; correct-password open, no-op preservation, qpdf, and independent-viewer checks pass, while wrong, empty, restricted, unsupported encryption, and encrypted geometry parity remain open |
| RG-069 | Form PDFs | `PARTIAL` | Text, checkbox, radio, choice, signature, shared-name, and widget-parent cases are reviewed |
| RG-070 | Signed PDFs | `OPEN` | Valid, invalid, multiple, and post-signature edit cases are reviewed |
| RG-071 | XFA PDFs | `OPEN` | Static, dynamic, hybrid, and unsupported XFA cases are reviewed |
| RG-072 | Malformed PDFs | `PARTIAL` | Existing 128-byte and new 512-byte hybrid truncation fixtures fail safely in native and browser lanes; invalid xref/object/stream/page-tree/annotation classes remain open |
| RG-073 | Resource-stress PDFs | `PARTIAL` | Existing 20-page and new 40-page hybrid inputs pass reopen and bounded export checks; large-image, annotation, link, text, and attachment stress limits remain open |
| RG-074 | Provider comparison fixtures | `PARTIAL` | Same current eighteen-entry manifest runs through native and web lanes; 6 classified semantic mismatches remain and independent provider comparison is not complete |

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
| RG-082 | Fixture provenance | `PASS` | Existing corpus paths, hashes, generation commands, expected security outcomes, and the 16-entry privacy/provenance governed manifest are recorded; external source/license facts remain explicitly unresolved where applicable |
| RG-083 | Dependency provenance | `PARTIAL` | Vendored runtime versions, sources, hashes, licenses, and local validation-tool versions are recorded; upgrade policy and shipped-provider licensing remain open |
| RG-084 | Support policy | `OPEN` | Supported macOS, browsers, PDF types, limits, encryption, and OCR languages are explicit |
| RG-085 | Observability policy | `PARTIAL` | Canonical diagnostics boundary is documented; implementation and automated redaction evidence remain open |
| RG-086 | Recovery documentation | `PARTIAL` | Interrupted export, corrupt input, password, runtime, and unsupported-feature recovery are documented |
| RG-087 | Accessibility claim policy | `PASS` | Reader surface, extraction, tags, and PDF/UA are clearly separated |
| RG-088 | Independent review | `OPEN` | A non-implementation reviewer evaluates fidelity, browser behavior, and accessibility |
| RG-089 | Release sign-off | `OPEN` | All hard gates pass or are deliberately removed from the supported scope |
| RG-090 | Long-term web deployment shape | `PASS` | D-009 and `docs/web-deployment-decision.md` accept a browser local core plus an explicitly installed optional companion capability plane; OCR and high-fidelity editing are companion placements, while packaging and provider adoption remain separately gated |
| RG-091 | Capability-negotiated provider admission | `PARTIAL` | Separate provider-capability registry, exact artifact measurement binding, deterministic native/browser negotiation, license-state rejection, source-limit checks, abstention, and a typed reference host with source/output limits, timeout, cancellation, and zero-content diagnostics are tested; installer, cryptographic transport authentication, sandboxing, live provider measurement, revocation feed, and packaged runtime recovery remain open |
| RG-092 | Full-capability implementation continuity | `ACTIVE` | All long-term native, browser, OCR, high-fidelity, companion, security, accessibility, template, batch, and recovery lanes remain implementation targets. Evidence gates control activation and claims, not whether adapters, fixtures, benchmarks, or rollback paths are built |
| RG-093 | Native/web normalized semantic parity | `PARTIAL` | The shared comparator and mutation harness are implemented. The current 18-fixture run records 6 classified mismatches and 0 unexpected mismatches. OCR and companion provider evidence must pass this gate before it can be promoted; Form 6 detector parity and encrypted-hybrid coordinate precision remain open |
| RG-094 | Privacy and provenance governed corpus | `PASS` | The manifest verifies 16 artifact digests, required privacy/provenance fields, scanned/rotated/malformed/encrypted/handwritten/mixed-content coverage, qpdf status, encrypted password handling, malformed safe-failure expectations, and zero-content reporting |
| RG-095 | Reviewed completion safety metrics | `PARTIAL` | Versioned metrics and mutation guards pass the controlled value-free benchmark: 5/5 correction lift, 14/14 abstention, 0/7 hard-negative selections, 35/35 hard-negative replay abstentions, 5/5 source-bound safe-completion guards, and 0 silent autofills; held-out recurring documents, value correctness, reviewer agreement, and materialized-output fidelity remain open |
| RG-096 | OCR and companion provider bake-off | `PARTIAL` | Native Vision, local Tesseract CLI, and browser WASM Tesseract.js are measured on six governed OCR inputs with normalized bounds, confidence, latency, union alignment, and zero-content reporting; Vision passes the provisional class gate, both Tesseract lanes fail the noisy-scan gate, browser assets make no external requests in the measured run, malformed/encrypted/large recovery checks pass, and OCRmyPDF/PDFBox/MuPDF companion runtime, licensing, cancellation, and partial-output gates remain open |
| RG-097 | Privacy-first PDF preflight and sanitization boundary | `PARTIAL` | Delivered 2026-08-25: (1) metadata/attachment sanitization (`web/pdf-sanitize.mjs`) — qpdf removes unreferenced resources/attachments, pikepdf strips XMP `/Metadata` and empties trailer `/Info`; (2) active-content neutralization (`web/pdf-action-neutralize.mjs`) — custom pikepdf pass deletes `/OpenAction`, `/AA`, `/JS`, `/JavaScript` and annotation `/A`/`/Launch`/`/SubmitForm`, leaving user `/URI` links. Remaining active gates: hidden-revision analysis, signature effects, XFA/rich-media policy, partial-output recovery, native PDFKit/PDF.js preflight reporting surface |
| RG-098 | Device-adaptive browser resource governance | `PARTIAL` | Versioned browser resource policy chooses bounded render, high-DPI, OCR, batch, cancellation, and source-digest recovery budgets across five device profiles and six document classes; 242 browser checks, 30 value-free benchmark rows, native serialized decoding, and isolated Chrome evidence pass. Physical-device calibration, browser-version drift, real OCR worker memory, companion crash recovery, and long-run throughput remain open |
| RG-099 | Text-run replacement and OCR-layer alignment | `PARTIAL` | Native PDFKit/Vision and browser PDF.js projections run across all 18 current fixtures with source binding, zero-content logging, safe malformed failure, 29 measurable text pages, 10 measured OCR/reference pages, and 71 explicit OCR abstentions. Text geometry at 2 points and OCR geometry at 3 points currently fail; true replacement remains abstained until independent text, raster, reopen, and viewer gates pass |
| RG-100 | Native/browser semantic parity report | `PARTIAL` | Fresh PDFKit versus browser PDF.js/pdf-lib contract report runs across all 18 manifest fixtures with provider IDs, timestamps, generated IDs, diagnostic messages, and output digests normalized out of semantic equality; 16 readable source bindings match in both lanes, 2 malformed failures agree, 6 declared mismatches remain, and 0 unexpected mismatches remain. Static-candidate reconciliation, encrypted-hybrid point precision, non-noop edit sessions, OCR observations, companion providers, and independent-viewer semantics remain open |
| RG-101 | Native/browser privacy preflight parity | `PARTIAL` | Revision 1.1 emits metadata, attachment, annotation, script, revision, coverage, unknown-coverage, source-binding, and non-execution facts across all 18 fixtures; 16 readable reports and 2 malformed failures agree, with 3 retained PDFKit/PDF.js keyword-presence mismatches on `public-sample-form.pdf`; sanitization and hidden-revision removal remain separate implementation gates |
| RG-102 | Static geometry hard-negative calibration | `PARTIAL` | Versioned two-page fixture and labels cover vector rectangles, checkbox shapes, underlines, whitespace, and label association. Native PDFKit and browser PDF.js both pass overall precision 5/5 (1.00), recall 5/5 (1.00), 0/5 hard-negative false positives, 5/5 abstention, and semantic parity; mutation gates kill no-candidate, hard-negative-promotion, and evidence-mismatch bypasses. Generalization to rotated, multilingual, OCR-only, clipped, table, malformed, duplicate-candidate, and real-world PDFs remains open |
| RG-103 | Typed semantic text-run replacement | `PARTIAL` | Native and browser contracts represent source-run identity, original-text hash, optional font fingerprint, page-space bounds, reversible lineage, and value-free recovery metadata. The bounded browser simple-run provider passes same-width ASCII literal replacement, qpdf/Poppler reopen, and independent outside-region text/raster evidence; PDFKit and general pdf-lib paths still reject the operation until font/glyph/RTL/ligature preservation, compressed-stream handling, broader corpus, and independent-viewer gates pass |
| RG-104 | Native/browser semantic candidate parity | `PARTIAL` | Versioned candidate projection measures the same 18-fixture corpus without provider IDs, labels, evidence prose, timestamps, or output digests. Fresh evidence records 206 native candidates, 140 browser candidates, 118 geometry pairs, 57.28% native-candidate coverage by browser pairs, 84.29% browser-candidate coverage by native pairs, 68.21% agreement F1, 49 fully equivalent pairs, and named field-type, entry-mode, review-state, geometry, grouping, and rotation-coordinate mismatches. Reviewed target precision/recall, split/merge adjudication, and broader candidate-bearing corpus classes remain open |
| RG-106 | Independent browser-export renderer comparison | `PARTIAL` | Poppler independently extracts text, renders raster pages, reopens, and compares 16 readable browser no-op exports with the PDF.js `outsideRegionText` and `visualDiff` gates; all 16 text and raster agreements pass with 0 unexpected divergences, while malformed inputs remain expected-failure/unknown and edited-operation, MuPDF three-way, GUI-viewer, redaction, signature, XFA, and PDF/UA evidence remain open |
| RG-107 | Browser preservation metrics review surface | `PARTIAL` | The browser review/export panel exposes value-minimized outside-region text and raster status, compared/changed pages, changed/compared pixels, ratios, channel deltas, scale/tolerance, and evidence basis for both passing and failed exports; static Form 6 overlay preservation remains a deliberate failed validator case and independent-viewer/UI parity remains separate |
| RG-108 | Independent browser-export measurement and operation binding | `PARTIAL` | Poppler and PDF.js verdicts are joined with separate normalized metrics and explicit comparable/notComparable/notMeasured states; serialized browser operation regions are passed to Poppler and missing/mismatched regions abstain. Readable no-op corpus evidence is 16/16 agreement with 2 malformed expected failures; fresh current-browser full-corpus metric regeneration and edited-operation promotion remain open |
| RG-109 | Encrypted local template history and separate profile vault | `PARTIAL` | Native AES-GCM template/profile stores and the active browser IndexedDB adapter now pass focused round-trip, wrong-key, parent, deletion-audit, eviction-recovery, passphrase-recovery, explicit backup import/export, visible preflight, and zero-content tests. The OPFS adapter now exposes passphrase key recovery and eviction state, but its recovery UI, durable audit persistence, and cross-browser evidence are not promoted. Secure deletion across OS/browser backups, Keychain-loss recovery, quota/concurrency stress, encrypted-backup cross-platform parity, profile-value transfer policy, and native UI automation remain open |

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
- [Privacy and provenance governed corpus evidence](audits/pdf-corpus-governance-evidence-2026-08-25.md)
- [Privacy-first PDF preflight evidence](audits/pdf-preflight-evidence-2026-08-25.md)
- [Text-run replacement and OCR alignment evidence](audits/text-run-ocr-alignment-evidence-2026-08-25.md)
- [Independent browser-export renderer comparison evidence](audits/independent-browser-viewer-comparison-evidence-2026-08-25.md)
- [Browser preservation metrics evidence](audits/browser-preservation-metrics-evidence-2026-08-25.md)

### RG-105: Session privacy and export provenance

- **Scope:** Every successfully opened PDF session across native and browser
  adapters.
- **Required evidence:** Source-bound session provenance with processing
  locality, data egress, OCR use, source retention/deletion, export identity,
  validation, reopen evidence, and zero-content invariants.
- **Current evidence:** 16 readable native and 16 readable browser fixtures
  emitted valid records; 2 declared malformed fixtures emitted no session
  record. Swift, browser unit/live, preflight, and full parity checks pass.
- **Disposition:** Implemented for current native/browser no-OCR flows. OCR,
  companion, remote, encrypted-persistence, eviction, and deletion states need
  provider-specific runtime evidence before those flows can claim coverage.
- **Falsifier:** Any record leaks content, treats runtime-only network traffic
  as source egress, loses source binding, or calls an unvalidated export
  successful.
- **Evidence:** [`audits/session-privacy-provenance-evidence-2026-08-25.md`](audits/session-privacy-provenance-evidence-2026-08-25.md),
  [`../Tests/session_privacy_provenance_test.mjs`](../Tests/session_privacy_provenance_test.mjs),
  and [`../Tests/PDFEditorCoreTests/SessionPrivacyProvenanceTests.swift`](../Tests/PDFEditorCoreTests/SessionPrivacyProvenanceTests.swift).

### RG-109: Encrypted local template history and separate profile vault

- **Scope:** Durable local template revisions and recurring profile values on
  native macOS and in the browser.
- **Required evidence:** Authenticated encryption, separate template/profile
  boundaries, immutable parent-linked revisions, explicit encrypted backup
  import/export, separate passphrase key recovery, deletion audit, explicit
  recovery and eviction states, wrong-key rejection, source-byte exclusion,
  visible privacy preflight, zero-content diagnostics, and browser eviction
  recovery.
- **Current evidence:** Native `EncryptedTemplatePersistenceTests` pass 5/5;
  the last green full Swift suite passed 102 tests in 12 suites. The active browser
  IndexedDB adapter and isolated Chrome security fixture pass encrypted backup
  restore, key-recovery export/import, wrong-recovery rejection, simulated
  eviction, deletion audit, visible preflight, and zero-content checks. The
  native SwiftUI inspector exposes the same health, recovery, deletion, and
  preflight state families. The OPFS adapter exposes the recovery API and
  stateful envelope availability, but its UI and durable audit/runtime parity
  are not promoted yet. A later whole-package rerun in the current dirty
  checkout is blocked by a separate `PDFEditorRecovery` public/internal
  visibility compile error, so the 102-test result remains the last green
  full-suite evidence rather than a fresh release claim.
- **Disposition:** Implemented for the native and active browser IndexedDB
  persistence paths; partial for the full product gate because OPFS recovery,
  secure OS/browser backup erasure, Keychain-loss recovery, quota/concurrency
  stress, encrypted-backup cross-adapter parity, profile-value transfer policy,
  and native UI automation remain active.
- **Falsifier:** A persisted envelope contains a profile value or PDF bytes, a
  wrong key yields a value, deletion leaves a readable recovery copy, primary
  corruption is presented as healthy, or the UI silently persists a secret.
- **Evidence:** [`audits/encrypted-template-profile-persistence-evidence-2026-08-25.md`](audits/encrypted-template-profile-persistence-evidence-2026-08-25.md),
  [`../Sources/PDFEditorCore/EncryptedTemplatePersistence.swift`](../Sources/PDFEditorCore/EncryptedTemplatePersistence.swift),
  [`../web/pdf-template-store.mjs`](../web/pdf-template-store.mjs), and
  [`../Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift`](../Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift).

### RG-110: Dual approval before reviewed template completion

- **Scope:** Native and browser recurring template completion sessions.
- **Required evidence:** A mapping approval and a separate profile-value
  approval must be visible, source-bound, and validated before an
  `EditOperation` is created. Mapping approval must bind the target and
  coordinate. Profile-value approval must bind profile identity, profile
  revision, semantic key, and exact value digest.
- **Current evidence:** Native and browser runtime contracts implement the
  binding records and fail-closed materialization gate. Native SwiftUI and
  browser review surfaces expose separate controls. Native tests pass 92/92,
  browser contract tests pass, and isolated Chrome workflow and security tests
  pass on port 4174.
- **Disposition:** Implemented for the current native/browser template
  workflow; partial for full product readiness because automated macOS UI
  interaction coverage, mid-session profile revision changes, multi-reviewer
  authority, and export-audit approval projections remain open.
- **Falsifier:** A stale value, stale provider target, missing approval record,
  or UI bypass can create a template operation. Any falsifier disables template
  completion application while preserving source and encrypted histories.
- **Evidence:** [`audits/template-review-workflow-evidence-2026-08-25.md`](audits/template-review-workflow-evidence-2026-08-25.md),
  [`../Sources/PDFEditorCore/TemplateRuntimeContracts.swift`](../Sources/PDFEditorCore/TemplateRuntimeContracts.swift),
  [`../web/pdf-template-contract.mjs`](../web/pdf-template-contract.mjs), and
  [`../Tests/web_template_browser_test.mjs`](../Tests/web_template_browser_test.mjs).

### RG-111: Native/browser structural fingerprint parity

- **Scope:** Value-minimized structural inspection parity for the native PDFKit
  and browser PDF.js/pdf-lib adapters over the current 18-entry corpus.
- **Required evidence:** A versioned fingerprint must bind to the source digest,
  exclude raw content and provider representation noise, compare page geometry,
  text shape, fields, candidates, evidence, coordinate spaces, navigation,
  permissions, security, and accessibility, and retain feature-level
  divergence clusters. Expected malformed failures must remain explicit.
- **Current evidence:** The generated fixture contains 18 cases. Two malformed
  expected failures agree. Sixteen readable cases retain divergence: permission
  observability on 16, character-count representation differences on 8,
  encrypted page-box precision on 1, and static Form 6 candidate-family
  divergence on 2. Focused mutations detect rotation, stale source digest,
  permissions, candidate count, coordinate space, and tolerated text drift.
- **Disposition:** `PARTIAL`. The structural fingerprint fixture and comparator
  are implemented and mutation-tested. Permission observed-versus-unknown
  normalization, encrypted page-box precision, rotation coordinate normalization,
  and candidate grouping/classification still require adapter remediation and a
  fresh native plus isolated-browser regeneration.
- **Falsifier:** The fixture retains raw labels or timestamps, source drift is
  not reported, a candidate coordinate mutation disappears, or malformed
  failures are counted as readable parity.
- **Rollback:** Remove this fingerprint report from release promotion while
  retaining the existing serialized contract and candidate parity reports. No
  source PDF or shared operation contract changes are required.
- **Evidence:** [`audits/native-browser-fingerprint-parity-evidence-2026-08-25.md`](audits/native-browser-fingerprint-parity-evidence-2026-08-25.md),
  [`../web/pdf-fingerprint-parity.mjs`](../web/pdf-fingerprint-parity.mjs),
  [`../Tests/fixtures/pdf_fingerprint_parity_fixture.json`](../Tests/fixtures/pdf_fingerprint_parity_fixture.json),
  [`../Tests/native_browser_fingerprint_parity_test.mjs`](../Tests/native_browser_fingerprint_parity_test.mjs),
  and [`../benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json`](../benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json).
