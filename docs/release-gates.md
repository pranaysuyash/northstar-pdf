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
| RG-001 | Public AcroForm fidelity | Native/provider | `PARTIAL` | Native incremental form writer delivered 2026-08-25 (`PDFIncrementalFormWriter.swift` + routing in `PDFKitProvider.export`): bounded native field-value edits on AcroForm documents now emit a genuine incremental update — source bytes remain a byte-exact prefix (verified 10,768-byte artifact `benchmark/results/2026-08-25-native-incremental/`), radio `/V`+`/AS` semantics mirror the verified web lane, choice metadata survives pikepdf reopen, and `qpdf --check` exits 0. UTF-16BE hex `/T` names decoded; compressed-object and encrypted sources fail closed; non-field operations on AcroForm documents remain rejected. Appearance-stream regeneration delivered 2026-08-25: edited text widgets receive a self-contained `/AP /N` Form XObject (Helvetica, own resources, exact /Length) — verified in the durable artifact (obj 40, BBox 251x23, value content present) and by Poppler raster diff showing the value rendered in the widget region (15.8% pixel delta) with qpdf exit 0 and byte-exact prefix. Corpus breadth delivered 2026-08-26: object-stream-compressed sources now fail closed with a precise `compressedObject` diagnostic (required full xref-stream support — nested dict extraction, PNG /Predictor 12 undo, type-2 entry tracking; fixtures in `benchmark/results/2026-08-25-native-incremental/corpus/`), and tagged sources are detected, preserved through incremental edits, and validated (RG-005 wiring proven on tagged/tagged-no-AcroForm variants). Remaining: non-FlateDecode xref-stream filters, broader real-AcroForm corpus from multiple producers |
| RG-002 | AcroForm provider decision | Shared/provider | `PASS` | Resolved 2026-08-25: adopted a custom incremental-update form writer (`web/pdf-incremental-form-writer.mjs`) wired into the mutation gate as a source-preserving lane (`guardedSourcePreservingExport` + `selectWriterLane` in `web/pdf-contract-mutation-gate.mjs`). Source-prefix bytes preserved (RG-017/RG-018 hold by construction AND enforced post-write by a byte-exact prefix guard), external AcroForm radio choice survives independent reopen (pikepdf/Poppler), qpdf `--check` clean. Preflight runs before any writer execution; non-qualifying operations fall back to the pdf-lib lane; rewritten/truncated output cannot escape the gate. Full rewrite falsified as RG-017 violation. Companion/PDFium/PDFBox paths remain optional (D-048). |
| RG-003 | Independent PDF structural validation | Validation | `PARTIAL` | Generated-output gate passes qpdf 12.4.0 for 39 PDFs with 0 hard failures; 6 Form 6 artifacts retain classified recoverable offset warnings and are not structurally clean |
| RG-004 | PDF/UA validation | Validation | `PARTIAL` | veraPDF 1.30.2 vendored and integrated 2026-08-25 (`tools/verapdf` wrapper over `tools/verapdf-cli-1.30.2`, provenance in `benchmark/results/verapdf-2026-08-25/result.json`): validator-backed PDF/UA-1 (ISO 14289-1:2014) XML reports generated for all 15 corpus-sweep outputs with per-clause failure detail. All current synthetic outputs are recorded NON-compliant (untagged: missing StructTreeRoot/Lang/XMP) — honest baseline, not a claim. Tagged-output authoring/preservation and compliant-output evidence remain open |
| RG-005 | Authored tag-tree preservation | Native/web/provider | `PARTIAL` | Structural tag-tree detection delivered 2026-08-25 (`detectStructuralAccessibility` via CGPDF catalog /StructTreeRoot + /MarkInfo /Marked; PDFKit attributes alone proved unreliable): inspection reports the authored tag tree or explicitly marks it unavailable with evidence notes, and export validation now fails an export whose output loses the source /StructTreeRoot while passing byte-preserving lanes by construction. Remaining: tagged-corpus breadth and tagged-output authoring |
| RG-006 | Native VoiceOver workflow | Native/accessibility | `PARTIAL` | Implementation surface delivered 2026-08-25: search/page announcements (RG-043), ⌘F focus landing (RG-057), Reduce Motion gating (RG-058), increased-contrast chrome, and structural accessibility reporting (RG-052). Remaining: human VoiceOver observation across all reader controls, errors, and navigation |
| RG-007 | Browser screen-reader workflow | Web/accessibility | `PARTIAL` | Web lane carries 46 aria- attributes (index.html) and 11 (app.js) across landmarks/live regions; native announcements delivered 2026-08-25. Remaining: screen-reader observation covering landmarks, text layer, search, status, and password flow |
| RG-008 | Scanned-PDF OCR corpus | Shared/OCR | `PARTIAL` | Deterministic raster-only English fixture and native no-text fallback are covered; broader scanned corpus and web OCR remain open |
| RG-009 | OCR acceptance thresholds | OCR/validation | `PARTIAL` | Anchor-based Tesseract benchmark is recorded; Vision accuracy, layout, confidence, language, and uncertainty thresholds remain open |
| RG-010 | Encrypted-document corpus | Native/web/security | `PARTIAL` | AES-256 password fixture, native/web inspection, byte-preserving browser no-op, wrong-password rejection, and qpdf validation are covered; an explicit qpdf companion decrypt/browser-reviewed-edit/re-encrypt lane passes independent reopen and preservation. Cancellation, installer recovery, native parity, and broad encrypted corpus remain open |
| RG-011 | Rotated-page corpus | Native/web/shared | `PARTIAL` | Native and browser rotated inspection plus a 90-degree non-zero crop-box reviewed overlay now pass browser and Poppler text/raster/reopen gates; mixed multi-page rotation, native replay, and all operation classes remain open |
| RG-012 | Malformed-PDF corpus | Shared/security | `PARTIAL` | Truncated fixture is generated and rejected by qpdf; native/web runtime and broader malformed-object corpus remain open |
| RG-013 | Large-document/resource limits | Shared/security | `PARTIAL` | Byte/page limits, a 20-page repeated fixture, and a 40-page hybrid fixture are covered; memory/time and large-structure corpus remain open |
| RG-014 | Signed-document behavior | Native/web/security | `PARTIAL` | Native signature guard delivered 2026-08-26. Every export walks the AcroForm model via `walkAcroFormModel` and checks /SigFlags (nonzero) or any field with `/FT /Sig`. If either condition is met the edit session refuses with a precise diagnostic: "This document contains digital signature fields. An incremental update would invalidate the signatures; editing is refused until an explicit signature-acknowledgment flow is available." Unsigned and synthetic signed fixtures pass expected state tests. Real trusted signed corpus, revocation, long-term validation, and preservation remain open |
| RG-015 | XFA behavior | Native/web/provider | `PARTIAL` | XFA guard delivered 2026-08-26 as a native guard in the incremental writer path (RG-015). The `XFAFormProcessor.inspectXFA` call runs on every export — if the document kind is not `.absent`, the edit session refuses with a precise diagnostic: "XFA document (kind) ... native field edits require XFA-state regeneration and are refused to avoid corrupting the form." This mirrors the web-lane `assertNoXfaFormEdits` and makes the native lane fail-closed on XFA documents. Full static/dynamic/hybrid taxonomy and real XFA corpus remain open |
| RG-016 | Independent-viewer reopen | Validation | `PARTIAL` | Poppler and MuPDF independently reopen 53 eligible source and derived corpus PDFs while qpdf provides separate structural validation; visual diff and semantic fidelity comparison remain open |
| RG-017 | Source-integrity validation | Shared/provider | `PARTIAL` | Native and browser operation gates reject stale source digests before mutation; browser writer-call and pdf-lib-load probes pass, broader adapter and source-replacement coverage remains open |
| RG-018 | Output-integrity validation | Shared/provider | `PARTIAL` | Output preserves all bounded invariants after reopen |
| RG-019 | Native/web parity corpus | Shared | `PARTIAL` | Native and web runners consume the same current eighteen-entry manifest with explicit scanned, synthetic handwriting-like, hybrid, password, malformed, large, OCR, and rotation expectations; 6 classified mismatches remain, 4 on Form 6 candidates and 2 on encrypted-hybrid geometry/coordinates |
| RG-020 | Browser export fidelity | Web/provider | `PARTIAL` | Byte-preserving no-op export and bounded overlay/form exports pass across the expanded valid corpus; web output still lacks unrestricted external-form, encrypted-edit, and universal provider fidelity |
| RG-021 | Local dependency packaging | Web/release | `PASS` | PDF.js and pdf-lib are locally packaged with licenses and load successfully from the local server |
| RG-022 | Runtime-unavailable behavior | Web/release | `PASS` | Missing runtime disables controls and announces recovery without startup crash |
| RG-023 | External-link security | Web/security | `PARTIAL` | Dangerous schemes and malformed destinations are blocked and confirmed safely |
| RG-024 | Attachment security | Native/web/security | `PARTIAL` | Inventory + name-safety scan delivered 2026-08-25 (`web/pdf-attachment-scanner.mjs`): walks the EmbeddedFiles name tree (incl. Kids), flags traversal segments, absolute paths, drive letters, control characters, oversized names, and executable extensions; boundary verdict blocks unsafe inventories; malformed facts rejected (falsifier). Validated on an 8-entry synthetic corpus (5 flagged with exact reasons, duplicate detection). Payload execution sandboxing and malware inspection remain open |
| RG-025 | Password handling security | Native/web/security | `PARTIAL` | Passwords never persist in logs, diagnostics, or durable state |
| RG-026 | Temporary-file cleanup | Native/provider | `PARTIAL` | Failed and interrupted exports clean temporary artifacts; staged validation now occurs before publication, interruption/crash sweep remains open |
| RG-027 | Permission enforcement | Native/web/provider | `PARTIAL` | Provider permissions are accurate and editing is blocked when required |
| RG-028 | Privacy boundary | Shared/release | `PASS` | Document bytes and secrets remain local unless explicit consent authorizes transfer. **Network-egression assertion delivered 2026-08-26** (`Tests/browser_network_egression_assertion_test.mjs`): proves zero external HTTP requests during the full browser workflow cycle (load → inspect → apply overlay → undo) via `page.on('request')` interception with empty external-requests assertion (Tier 2/S1). CSP policy verified separately. Companion/OCR/hosted lanes require their own egress proofs. |
| RG-029 | Crash and recovery behavior | Native/web | `PARTIAL` | Recovery evidence mapped 2026-08-25: crash-interruption suite (payload/pair/metadata interruptions preserve the previous committed generation; first-save interruption leaves no discoverable recovery), termination-flush persistence test, provider-level export-failure tests (no publication, source intact, temp cleanup), and malformed-input rejection. Remaining: GUI-driven termination sweep during import/render/worker (RG-026 interruption sweep) |
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
| RG-037 | Continuous-view performance | Native/web | `PARTIAL` | Browser continuous-view measurement delivered 2026-08-25 (`Tests/perf-continuous-view_test.mjs` on `large-hybrid-40-pages.pdf`, real app, real scroller auto-detected): open-to-first-canvas 179ms, last-canvas reach 10ms (at-bottom condition asserted, no swallowed timeouts), jump dispatch 355ms, heap growth +3MB — all within recorded provisional budgets (`benchmark/results/2026-08-25-perf-continuous-view/result.json`). Formal budget ratification, native-lane measurement, device matrix, and long-run soak remain open |
| RG-038 | Thumbnail correctness | Native/web | `PARTIAL` | Thumbnail content, label, rotation, and selection remain synchronized |
| RG-039 | Extractable-text selection | Native/web | `PARTIAL` | Unicode, ligatures, line breaks, columns, rotation, and empty pages select correctly |
| RG-040 | OCR selection fallback | Native/web/OCR | `PARTIAL` | Native image-only state and OCR fixture are explicit; OCR-derived selectable text and web fallback remain open |
| RG-041 | Search matching | Native/web | `PARTIAL` | Unicode, case, ligatures, line breaks, repeated and empty matches are correct |
| RG-042 | Search highlight alignment | Native/web | `PARTIAL` | Highlights remain aligned under scale, rotation, and mixed page geometry |
| RG-043 | Search status announcements | Native/web/accessibility | `PARTIAL` | Implemented 2026-08-25: match counts, current result (position + page + snippet), page changes, and no-match state posted via NSAccessibility announcementRequested and recorded in `lastAccessibilityAnnouncement` for verification. Remaining: human VoiceOver observation |
| RG-044 | Internal links | Native/web | `PARTIAL` | Valid, missing, invalid, named, and remote destinations are handled safely |
| RG-045 | External links | Native/web/security | `PARTIAL` | Only permitted schemes proceed after explicit confirmation |
| RG-046 | Outlines and bookmarks | Native/web | `PARTIAL` | Nested, missing-target, duplicate, empty, and deep outlines work predictably |
| RG-047 | Metadata normalization | Native/web | `PARTIAL` | Absent, malformed, Unicode, date, creator, producer, and custom metadata are safe |
| RG-048 | Permission normalization | Native/web | `PARTIAL` | Missing, restricted, encrypted, and provider-specific permissions are explicit |
| RG-049 | Attachment inventory | Native/web | `PARTIAL` | Name-tree inventory with per-attachment filename/dosName/size, duplicate detection, and Kids-subtree coverage delivered 2026-08-25 via `web/pdf-attachment-scanner.mjs` (8-entry synthetic corpus incl. duplicates); large payloads and real-world corpora remain open |
| RG-050 | Password interaction | Native/web | `PARTIAL` | Wrong, empty, cancelled, repeated, and successful password flows reset safely |
| RG-051 | Accessible reading surface | Native/web | `PARTIAL` | Browser runtime gate proves landmarks, keyboard text spans, focus, and password semantics; native and assistive-technology consumption remains open |
| RG-052 | Accessibility source fidelity | Native/web | `PARTIAL` | Source-fidelity detection delivered 2026-08-25 with RG-005: documents with an authored /StructTreeRoot are reported as tagged with an explicit preservation-policy note (byte-preserving lane guaranteed; other writers unverified), untagged documents are clearly marked unavailable at the source, and export validation fails structure-tree loss with evidence. Remaining: validator-backed (veraPDF) clause detail surfaced in the summary |
| RG-053 | Tagged-content messaging | Native/web | `PASS` | UI never presents extracted text as PDF/UA proof |
| RG-054 | Empty-text state | Native/web | `PARTIAL` | Native inspection signals OCR/unavailable text; web OCR UI state remains open |
| RG-055 | Clipboard behavior | Native/web | `PARTIAL` | Secure, insecure, denied, empty, and large-copy paths are safe |
| RG-056 | Keyboard operation | Native/web | `PARTIAL` | Browser runtime gate covers landmarks, skip-link focus, text-layer focus, and password dialog; full reader action matrix and native keyboard observation remain open |
| RG-057 | Focus restoration | Native/web/accessibility | `PARTIAL` | ⌘F focus consumption delivered 2026-08-25: the Find focus event is now consumed by the document canvas, expanding the search HUD and focusing the field (previously the event fired without moving focus). Remaining: systematic audit of focus return after modals, links, errors, and jumps |
| RG-058 | Reduced motion | Native/web/accessibility | `PARTIAL` | All identified canvas animations honor Reduce Motion as of 2026-08-25 (ContentView spring was already gated; DocumentCanvasView search-expand now gated). Remaining: human observation across reader transitions |
| RG-059 | Zoom and responsive layout | Web/accessibility | `PARTIAL` | Implemented 2026-08-25: window minimum reduced 1080x700 to 720x480 so narrow windows and 200% zoom remain usable; increased-contrast chrome (contrast-aware HUD strokes) implemented; no fixed-size fonts found (Dynamic Type intact). Remaining: human 200%/large-text/high-contrast observation pass |

## Fixture corpus gates

| ID | Fixture category | Current state | Completion oracle |
|---|---|---|---|
| RG-060 | Plain text PDFs | `PARTIAL` | Synthetic multi-page fixture generated and reviewed 2026-08-25 (`benchmark/results/corpus-sweep-2026-08-25/plain-text.pdf`): headings, paragraphs, Latin-1 accented words, and cross-page flow extract via Poppler; qpdf clean; Unicode title round-trip verified in metadata variant. Ligature glyph substitution (font-shaping level) and real-world text corpora remain open |
| RG-061 | Image-only PDFs | `PARTIAL` | Clean, deterministic noisy raster, and synthetic handwriting-like fixtures are governed and structurally reviewed; genuine handwriting, OCR accuracy, low-contrast, multilingual, and rotated scan behavior remain open |
| RG-062 | Mixed PDFs | `PARTIAL` | Two-page text/form plus raster hybrid and 40-page hybrid stress fixtures pass browser/native reopen and bounded export gates; tables, annotations, and broader mixed-content classes remain open |
| RG-063 | Multi-column PDFs | `PARTIAL` | Synthetic two-column landscape fixture with sidebar generated and reviewed 2026-08-25 (`corpus-sweep-2026-08-25/multi-column.pdf`): both column headings plus sidebar extract via Poppler; qpdf clean. Formal reading-order adjudication across viewers and real-world column corpora remain open |
| RG-064 | Geometry PDFs | `PARTIAL` | Synthetic geometry fixture reviewed 2026-08-25 (`corpus-sweep-2026-08-25/geometry.pdf`): tall-narrow page (200x2000), /Rotate 90 page, and CropBox-clipped page all re-read with exact MediaBox/Rotate/CropBox facts via pikepdf; qpdf clean. Coordinate-transform parity under rendering remains open |
| RG-065 | Navigation PDFs | `PARTIAL` | Synthetic navigation fixture reviewed 2026-08-25 (`corpus-sweep-2026-08-25/navigation.pdf`): 2-item outline chain (First/Last/Next/Prev/Count verified), URI action link, internal /Fit destination link, and a /GoTo to a provably absent named destination (missing-target case confirmed); qpdf clean. Remote-action policy behavior and real-world nav corpora remain open |
| RG-066 | Metadata PDFs | `PARTIAL` | Five metadata variants generated and reviewed 2026-08-25 (`corpus-sweep-2026-08-25/metadata-{complete,absent,unicode,custom,malformed}.pdf`): full docinfo set, absent /Info, Unicode title (Título/Ünïcødé/✓/日本語) round-trip, custom keys, and a malformed scalar-int docinfo value all re-read safely; qpdf clean. XMP-malformed variants and viewer-level normalization remain open |
| RG-067 | Attachment PDFs | `PARTIAL` | Synthetic 8-entry corpus generated and reviewed 2026-08-25 (`Tests/pdf-attachment-scanner_test.mjs`): safe, traversal, absolute-path, drive-letter, control-character, oversized, executable-extension, and duplicate-name cases with expected outcomes; real-world/large-payload attachment corpora remain open |
| RG-068 | Encryption PDFs | `PARTIAL` | AES-256 user/owner password fixtures include native-widget and hybrid sources; correct-password open, no-op preservation, qpdf, and independent-viewer checks pass, while wrong, empty, restricted, unsupported encryption, and encrypted geometry parity remain open |
| RG-069 | Form PDFs | `PARTIAL` | Text, checkbox, radio, choice, signature, shared-name, and widget-parent cases are reviewed |
| RG-070 | Signed PDFs | `PARTIAL` | Structure-level signed fixtures generated and reviewed 2026-08-25 (`corpus-sweep-2026-08-25/signed-{valid,invalid,multiple}-structure.pdf`): detection via `web/pdf-signature-guard.mjs` reports SigFlags/sigField counts correctly (1/1/2); recorded finding: qpdf does NOT validate ByteRange/Contents consistency (invalid structure passes qpdf clean). Cryptographic validity and post-signature edit-behavior review remain open |
| RG-071 | XFA PDFs | `PARTIAL` | Three XFA fixtures generated and classified 2026-08-25 (`corpus-sweep-2026-08-25/xfa-{static,dynamic,hybrid}.pdf`) via `web/pdf-xfa-guard.mjs`: static (no config packet, hint=false), dynamic (config packet, hint=true), hybrid (XFA + retained PDF-side field verified). Heuristic classification only; real XFA corpus and viewer behavior remain open |
| RG-072 | Malformed PDFs | `PARTIAL` | Existing 128-byte and new 512-byte hybrid truncation fixtures fail safely in native and browser lanes; invalid xref/object/stream/page-tree/annotation classes remain open |
| RG-073 | Resource-stress PDFs | `PARTIAL` | Existing 20-page and new 40-page hybrid inputs pass reopen and bounded export checks; large-image, annotation, link, text, and attachment stress limits remain open |
| RG-074 | Provider comparison fixtures | `PARTIAL` | Same current eighteen-entry manifest runs through native and web lanes; 6 classified semantic mismatches remain and independent provider comparison is not complete |

## Product, documentation, and release-control gates

| ID | Gate | Current state | Completion oracle |
|---|---|---|---|
| RG-075 | Feature inventory alignment | `PARTIAL` | Inventory, journal, status, and audit agree on every feature state |
| RG-076 | Canonical capability matrix | `PARTIAL` | Machine-readable matrix delivered 2026-08-26 (`docs/capability-matrix.json`): 20 capabilities + 5 unsupported capabilities with native/web/contract/gate/claim/limits fields; prose matrix in `docs/capability-matrix.md` remains authoritative. Remaining: automated validation that JSON matches prose, integration with CI gate checks |
| RG-077 | Error taxonomy | `PARTIAL` | Stable native and web classes plus staged validation/recovery semantics are documented; complete UI/runtime observation and redaction evidence remain open |
| RG-078 | Evidence tier labeling | `PASS` | Source, unit, provider, browser, screen-reader, and validator evidence remain separate |
| RG-079 | Persona review record | `PASS` | Persona lenses and acceptance criteria are linked to the gates |
| RG-080 | Doctrine record | `PASS` | Local-first, source-preserving, capability-bounded, and evidence-led decisions are recorded |
| RG-081 | Release runbook | `PARTIAL` | Reproducible ordered runbook written 2026-08-25 (`docs/release-runbook.md`) and extended same day: veraPDF PDF/UA validation (`tools/verapdf --flavour ua1 ...`, RG-004), corpus-sweep regeneration (`Tests/fixtures/generate_corpus_sweep.py` + `Tests/fixture-corpus-sweep_test.mjs`), and the continuous-view perf measurement (`Tests/perf-continuous-view_test.mjs`). **CI wiring delivered 2026-08-26** (`.github/workflows/ci.yml`): three independent gates (Swift test + release build / 31 pure-Node contract tests / Playwright browser E2E via self-booting `run-web-e2e.mjs`); evidence gate summarizes results and gates the push. `Tests/web_editor_workflow_test.mjs` now self-boots its static server — zero external choreography required. Local pre-push hook mirror at `tools/pre-push-hook.sh`. Remaining: external-tool-dependent tests (qpdf, poppler, veraPDF, pikepdf) added to CI or gated behind tool-detection, full 78-file E2E suite stabilization. Verification at audit time: 230/230 Swift tests, 51 web contract checks, workflow test passes self-contained. |
| RG-082 | Fixture provenance | `PASS` | Existing corpus paths, hashes, generation commands, expected security outcomes, and the 16-entry privacy/provenance governed manifest are recorded; external source/license facts remain explicitly unresolved where applicable |
| RG-083 | Dependency provenance | `PARTIAL` | Vendored runtime versions, sources, hashes, licenses, and local validation-tool versions are recorded; veraPDF 1.30.2 added 2026-08-25 (`tools/verapdf-cli-1.30.2`, extracted from software.verapdf.org installer pack, Apache-2.0/GPL dual license upstream, digest-provenanced in `benchmark/results/verapdf-2026-08-25/result.json`); upgrade policy and shipped-provider licensing remain open |
| RG-084 | Support policy | `PARTIAL` | Support policy drafted 2026-08-26 (`docs/support-policy.md`): macOS 15+ (Apple Silicon primary), Safari/Chrome primary, 14 PDF types mapped, encryption support matrix, OCR (English only), accessibility status, supported/unsupported operations, update lifecycle. Remaining: human product decision on version numbers, page limits, and encryption levels before activation |
| RG-085 | Observability policy | `PARTIAL` | Canonical diagnostics boundary is documented; implementation and automated redaction evidence remain open |
| RG-086 | Recovery documentation | `PARTIAL` | Interrupted export, corrupt input, password, runtime, and unsupported-feature recovery are documented |
| RG-087 | Accessibility claim policy | `PASS` | Reader surface, extraction, tags, and PDF/UA are clearly separated |
| RG-088 | Independent review | `PARTIAL` | **Two independent reviews delivered 2026-08-26**: (1) PER-0206 Post-Fix Adversarial Reviewer (`docs/audits/independent-adversarial-review-per-0206-2026-08-26.md`) — 5 observations, no overclaiming; (2) PER-0163 Red-Team Reviewer (`docs/audits/red-team-review-per-0163-2026-08-26.md`) — adversarial attack-surface analysis, 5 recommendations, confirmed core invariants hold. Different analytical lenses from the builder. Structural independence (separate model/capability) remains the gap for full PASS. |
| RG-089 | Release sign-off | `OPEN` | All hard gates pass or are deliberately removed from the supported scope |
| RG-090 | Long-term web deployment shape | `PASS` | D-009 and `docs/web-deployment-decision.md` accept a browser local core plus an explicitly installed optional companion capability plane; OCR and high-fidelity editing are companion placements, while packaging and provider adoption remain separately gated |
| RG-091 | Capability-negotiated provider admission | `PARTIAL` | Separate provider-capability registry, exact artifact measurement binding, deterministic native/browser negotiation, license-state rejection, source-limit checks, abstention, and a typed reference host with source/output limits, timeout, cancellation, and zero-content diagnostics are tested; installer, cryptographic transport authentication, sandboxing, live provider measurement, revocation feed, and packaged runtime recovery remain open |
| RG-092 | Full-capability implementation continuity | `ACTIVE` | All long-term native, browser, OCR, high-fidelity, companion, security, accessibility, template, batch, and recovery lanes remain implementation targets. Evidence gates control activation and claims, not whether adapters, fixtures, benchmarks, or rollback paths are built |
| RG-093 | Native/web normalized semantic parity | `PARTIAL` | The shared comparator and mutation harness are implemented. The current 18-fixture run records 6 classified mismatches and 0 unexpected mismatches. OCR and companion provider evidence must pass this gate before it can be promoted; Form 6 detector parity and encrypted-hybrid coordinate precision remain open |
| RG-094 | Privacy and provenance governed corpus | `PASS` | The manifest verifies 16 artifact digests, required privacy/provenance fields, scanned/rotated/malformed/encrypted/handwritten/mixed-content coverage, qpdf status, encrypted password handling, malformed safe-failure expectations, and zero-content reporting |
| RG-095 | Reviewed completion safety metrics | `PARTIAL` | Versioned metrics and mutation guards pass the controlled value-free benchmark: 5/5 correction lift, 14/14 abstention, 0/7 hard-negative selections, 35/35 hard-negative replay abstentions, 5/5 source-bound safe-completion guards, and 0 silent autofills; held-out recurring documents, value correctness, reviewer agreement, and materialized-output fidelity remain open |
| RG-096 | OCR and companion provider bake-off | `PARTIAL` | Native Vision, local Tesseract CLI, and browser WASM Tesseract.js are measured on six governed OCR inputs with normalized bounds, confidence, latency, union alignment, and zero-content reporting; Vision passes the provisional class gate, both Tesseract lanes fail the noisy-scan gate, browser assets make no external requests in the measured run, malformed/encrypted/large recovery checks pass, and OCRmyPDF/PDFBox/MuPDF companion runtime, licensing, cancellation, and partial-output gates remain open |
| RG-097 | Privacy-first PDF preflight and sanitization boundary | `PARTIAL` | Delivered 2026-08-25: (1) metadata/attachment sanitization (`web/pdf-sanitize.mjs`) — qpdf strips unreferenced resources/attachments, pikepdf strips XMP `/Metadata` and empties trailer `/Info`; (2) active-content neutralization (`web/pdf-action-neutralize.mjs`) — deletes `/OpenAction`, `/AA`, `/JS`, `/JavaScript` and annotation `/A`/`/Launch`/`/SubmitForm`, preserving user `/URI` links; (3) hidden-revision analysis (`web/pdf-hidden-revision-analyzer.mjs`) — walks the `/Prev` chain, inventories shadowed objects per revision, and scans unreachable bodies for active-content remnants (validated: incremental edit shadows exactly its edit set; JS hidden in a prior revision is flagged while the current revision is clean; full rewrite collapses history — falsifier). Remaining active gates: partial-output recovery, native PDFKit/PDF.js preflight reporting surface. Corpus breadth 2026-08-26: incremental-lane xref-stream now covers compressed-object sources (fail-closed `compressedObject` diagnostic via nested-dict extraction, PNG /Predictor 12 undo, type-2 tracking) and tagged sources (detection/preservation). Nine synthetic-producer PDFs (`synthetic-producer-0/./5.pdf`) extend multi-producer coverage. Signature detection and XFA detection now have their own dedicated native guards — RG-014 and RG-015 respectively. Audited sanitization (`web/pdf-sanitize-audited.mjs`) ties the flow together: refuse-by-default when hidden-revision remnants exist, explicit acknowledgment to destroy evidence, post-write chain-collapse verification (`web/pdf-sanitize.mjs`) — qpdf strips unreferenced resources/attachments, pikepdf strips XMP `/Metadata` and empties trailer `/Info`; (2) active-content neutralization (`web/pdf-action-neutralize.mjs`) — deletes `/OpenAction`, `/AA`, `/JS`, `/JavaScript` and annotation `/A`/`/Launch`/`/SubmitForm`, preserving user `/URI` links; (3) hidden-revision analysis (`web/pdf-hidden-revision-analyzer.mjs`) — walks the `/Prev` chain, inventories shadowed objects per revision, and scans unreachable bodies for active-content remnants (validated: incremental edit shadows exactly its edit set; JS hidden in a prior revision is flagged while the current revision is clean; full rewrite collapses history — falsifier). Remaining active gates: partial-output recovery, native PDFKit/PDF.js preflight reporting surface. Corpus breadth 2026-08-26: incremental-lane xref-stream now covers compressed-object sources (fail-closed `compressedObject` diagnostic via nested-dict extraction, PNG /Predictor 12 undo, type-2 tracking) and tagged sources (detection/preservation). Synthetic-producer PDFs (`synthetic-producer-0/1/2.pdf`) extend multi-producer coverage. Signature detection and XFA detection now have their own dedicated native guards — RG-014 and RG-015 respectively. Audited sanitization (`web/pdf-sanitize-audited.mjs`) ties the flow together: refuse-by-default when hidden-revision remnants exist, explicit acknowledgment to destroy evidence, post-write chain-collapse verification (`web/pdf-sanitize.mjs`) — qpdf strips unreferenced resources/attachments, pikepdf strips XMP `/Metadata` and empties trailer `/Info`; (2) active-content neutralization (`web/pdf-action-neutralize.mjs`) — deletes `/OpenAction`, `/AA`, `/JS`, `/JavaScript` and annotation `/A`/`/Launch`/`/SubmitForm`, preserving user `/URI` links; (3) hidden-revision analysis (`web/pdf-hidden-revision-analyzer.mjs`) — walks the `/Prev` chain, inventories shadowed objects per revision, and scans unreachable bodies for active-content remnants (validated: incremental edit shadows exactly its edit set; JS hidden in a prior revision is flagged while the current revision is clean; full rewrite collapses history — falsifier). Remaining active gates: partial-output recovery, native PDFKit/PDF.js preflight reporting surface. Signature detection and XFA detection now have their own dedicated native guards — RG-014 and RG-015 respectively. Audited sanitization (`web/pdf-sanitize-audited.mjs`) ties the flow together: refuse-by-default when hidden-revision remnants exist, explicit acknowledgment to destroy evidence, post-write chain-collapse verification |
| RG-098 | Device-adaptive browser resource governance | `PARTIAL` | Versioned browser resource policy chooses bounded render, high-DPI, OCR, batch, cancellation, and source-digest recovery budgets across five device profiles and six document classes; 242 browser checks, 30 value-free benchmark rows, native serialized decoding, and isolated Chrome evidence pass. Physical-device calibration, browser-version drift, real OCR worker memory, companion crash recovery, and long-run throughput remain open |
| RG-099 | Text-run replacement and OCR-layer alignment | `PARTIAL` | Native PDFKit/Vision and browser PDF.js projections run across all 18 current fixtures with source binding, zero-content logging, safe malformed failure, 29 measurable text pages, 10 measured OCR/reference pages, and 71 explicit OCR abstentions. Text geometry at 2 points and OCR geometry at 3 points currently fail; true replacement remains abstained until independent text, raster, reopen, and viewer gates pass |
| RG-100 | Native/browser semantic parity report | `PARTIAL` | Fresh PDFKit versus browser PDF.js/pdf-lib contract report runs across all 18 manifest fixtures with provider IDs, timestamps, generated IDs, diagnostic messages, and output digests normalized out of semantic equality; 16 readable source bindings match in both lanes, 2 malformed failures agree, 6 declared mismatches remain, and 0 unexpected mismatches remain. Static-candidate reconciliation, encrypted-hybrid point precision, non-noop edit sessions, OCR observations, companion providers, and independent-viewer semantics remain open |
| RG-101 | Native/browser privacy preflight parity | `PARTIAL` | Revision 1.1 emits metadata, attachment, annotation, script, revision, coverage, unknown-coverage, source-binding, and non-execution facts across all 18 fixtures; 16 readable reports and 2 malformed failures agree, with 3 retained PDFKit/PDF.js keyword-presence mismatches on `public-sample-form.pdf`; sanitization and hidden-revision removal remain separate implementation gates |
| RG-102 | Static geometry hard-negative calibration | `PARTIAL` | Versioned two-page fixture and labels cover vector rectangles, checkbox shapes, underlines, whitespace, and label association. Native PDFKit and browser PDF.js both pass overall precision 5/5 (1.00), recall 5/5 (1.00), 0/5 hard-negative false positives, 5/5 abstention, and semantic parity; mutation gates kill no-candidate, hard-negative-promotion, and evidence-mismatch bypasses. Generalization to rotated, multilingual, OCR-only, clipped, table, malformed, duplicate-candidate, and real-world PDFs remains open |
| RG-103 | Typed semantic text-run replacement | `PARTIAL` | Native and browser contracts represent source-run identity, original-text hash, optional font fingerprint, page-space bounds, reversible lineage, and value-free recovery metadata. The bounded browser simple-run provider passes same-width ASCII literal replacement, qpdf/Poppler reopen, and independent outside-region text/raster evidence; PDFKit and general pdf-lib paths still reject the operation until font/glyph/RTL/ligature preservation, compressed-stream handling, broader corpus, and independent-viewer gates pass |
| RG-104 | Native/browser semantic candidate parity | `PARTIAL` | Versioned candidate projection measures the same 18-fixture corpus without provider IDs, labels, evidence prose, timestamps, or output digests. Fresh evidence records 206 native candidates, 140 browser candidates, 118 geometry pairs, 57.28% native-candidate coverage by browser pairs, 84.29% browser-candidate coverage by native pairs, 68.21% agreement F1, 49 fully equivalent pairs, and named field-type, entry-mode, review-state, geometry, grouping, and rotation-coordinate mismatches. Reviewed target precision/recall, split/merge adjudication, and broader candidate-bearing corpus classes remain open |
| RG-112 | Reviewed detector semantic comparison | `PARTIAL` | Versioned reviewed-region comparison passes the controlled 10-region fixture in native PDFKit and browser PDF.js: precision 1.00, recall 1.00, correct hard-negative abstention 1.00, evidence-family agreement 1.00, label association 1.00, grouping agreement 1.00, severity burden 0, and 0 native/browser reviewed-region mismatches. Five independent mutations are killed. Reviewed identities for Form 6, rotated, grouped, scanned, OCR-only, multilingual, handwriting, clipped, malformed, and mixed-content regions remain open |
| RG-106 | Independent browser-export renderer comparison | `PARTIAL` | Poppler independently extracts text, renders raster pages, reopens, and compares 16 readable browser no-op exports with the PDF.js `outsideRegionText` and `visualDiff` gates; MuPDF independently passes the public browser no-op text/raster/reopen control. Edited-operation MuPDF region mapping, malformed inputs, GUI-viewer, redaction, signature, XFA, and PDF/UA evidence remain open |
| RG-107 | Browser preservation metrics review surface | `PARTIAL` | The browser review/export panel exposes value-minimized outside-region text and raster status, compared/changed pages, changed/compared pixels, ratios, channel deltas, scale/tolerance, and evidence basis for both passing and failed exports; static Form 6 overlay preservation remains a deliberate failed validator case and independent-viewer/UI parity remains separate |
| RG-108 | Independent browser-export measurement and operation binding | `PARTIAL` | Poppler and PDF.js verdicts are joined with separate normalized metrics and explicit comparable/notComparable/notMeasured states; serialized browser operation regions are passed to Poppler and missing/mismatched regions abstain. Readable no-op corpus evidence is 16/16 agreement with 2 malformed expected failures; fresh current-browser full-corpus metric regeneration and edited-operation promotion remain open |
| RG-109 | Encrypted local template history and separate profile vault | `PARTIAL` | Native AES-GCM template/profile stores and the active browser IndexedDB adapter now pass focused round-trip, wrong-key, parent, deletion-audit, eviction-recovery, passphrase-recovery, explicit backup import/export, visible preflight, and zero-content tests. The OPFS adapter now exposes passphrase key recovery and eviction state, but its recovery UI, durable audit persistence, and cross-browser evidence are not promoted. Secure deletion across OS/browser backups, Keychain-loss recovery, quota/concurrency stress, encrypted-backup cross-platform parity, profile-value transfer policy, and native UI automation remain open |
| RG-113 | Rotated reviewed-operation replay with crop offsets | `PARTIAL` | `Tests/rotated_operation_replay_test.mjs` passes PDF.js browser inspection, crop-relative writer translation, browser text/raster outside-region validation, Poppler text/raster outside-region validation, non-zero Media/Crop/Bleed/Trim/Art box reopen, and 90-degree rotation reopen. The same fixture explicitly rejects an unsupported external widget fill. Multi-page, mixed rotations, crop transforms on every operation kind, and native PDFKit replay remain open |
| RG-114 | Edited object preservation | `PARTIAL` | `benchmark/pdf-object-preservation-validator.mjs` and `Tests/pdf_object_preservation_test.mjs` pass byte-identical no-op, detect unauthorized object mutation, and require explicit edited-object authorization. Full object-level preservation across all writer providers, streams, incremental revisions, annotations, signatures, and arbitrary PDFs remains open |
| RG-115 | Browser AcroForm semantic matrix | `PARTIAL` | `Tests/browser_acroform_semantic_matrix_test.mjs` validates text, multiline, checkbox, radio, choice, and hierarchical field operation/export/reopen on the public sample. Full native/web parity across external widget graphs, shared names, XFA, signatures, annotation appearance streams, and all PDF viewers remains open |
| RG-116 | Encrypted reviewed export companion lane | `PARTIAL` | `Tests/encrypted_companion_export_test.mjs` passes wrong-password rejection, qpdf AES-256 decrypt/re-encrypt, browser-reviewed overlay, source-bound operation, independent Poppler text/raster/reopen, and encrypted output checks. Installer lifecycle, sandboxing, cancellation/recovery, password UI, native parity, and broad encrypted corpus remain open |
| RG-117 | Signature integrity and validity evidence | `PARTIAL` | `validateSignatureIntegrity` separates unsigned, byte-range-invalid, CMS-failed, CMS-passed, trust-unevaluated, and unknown states; the synthetic signed fixture reaches structural-valid/CMS-failed as expected. Real signed CMS corpus, certificate trust, revocation, long-term validation, and preservation of valid signatures remain open |
| RG-118 | Redaction completeness | `PARTIAL` | `benchmark/redaction-completeness-validator.mjs` rejects whiteout overlays when target text survives and passes a controlled text-removal mutation with stable outside text. Image/vector/object removal, annotation and attachment erasure, hidden-revision forensics, raster evidence, and cryptographic erasure remain unknown or separate gates |
| RG-119 | GUI control-app observation | `PARTIAL` | Preview observation opens the public fixture and records front-document/window evidence without retaining raw PDF content or screenshots. Multi-page interaction, another independent GUI viewer, accessibility automation, and edited-output observations remain open |
| RG-120 | PDF/UA conformance baseline and authoring | `PARTIAL` | Vendored veraPDF reports are generated and normalized for the corpus; current synthetic outputs fail PDF/UA-1 with clause-level evidence. Tagged structure authoring, preservation, remediation, and compliant output evidence remain open |
| RG-121 | Arbitrary-PDF production preservation | `OPEN` | Long-term release gate covering general semantic editing, byte/object preservation, AcroForm/XFA/signatures, redaction, PDF/UA, independent viewers, malformed/encrypted recovery, resource budgets, cancellation, and support evidence. The full capability mandate remains active; no unrestricted production claim is made yet |
| RG-122 | Native macOS codesign and notarization | `BLOCKED` | Codesign workflow documented 2026-08-26 (`docs/codesign-notarize-workflow.md`): full build-sign-notarize-staple-verify pipeline with CI/CD GitHub Actions template, verification checklist, troubleshooting guide. Blocked on Apple Developer account ($99/year) and signing credentials |
| RG-123 | Auto-update mechanism | `BLOCKED` | Auto-update integration plan documented 2026-08-26 (`docs/auto-update-integration.md`): Sparkle 2.x framework recommended, EdDSA signing, appcast feed format, update flow, rollback strategy, privacy compliance, hosting requirements. 1-2 day implementation estimate. Blocked on hosting setup and EdDSA key generation |
| RG-124 | Crash-reporting boundary | `PARTIAL` | Crash-reporting boundary documented 2026-08-26 (`docs/crash-reporting-boundary.md`): privacy boundary recap, no-telemetry recommendation (safest), opt-in consent flow, what crash reports may/must-not contain, local-only crash logs alternative, network boundary, GDPR/CCPA compliance. Remaining: product decision on telemetry scope before implementation |
| RG-125 | Native performance budget ratification | `PARTIAL` | `Tests/PDFEditorCoreTests/NativePerformanceBudgetTests.swift` establishes cold-inspection (<2s), field-tree walk (<0.5s), incremental write (<0.5s), and field-lookup (<10ms/100) budgets on the public AcroForm fixture; provisional baselines recorded. Formal ratification requires device-matrix measurement across M1/M2/Intel configurations |
| RG-126 | Browser network-egression invariant | `PARTIAL` | `Tests/browser_network_egression_assertion_test.mjs` proves zero external HTTP requests during the full browser workflow cycle (Tier 2/S1). Covers the core editor surface; companion, OCR-worker, and hosted-mode lanes require separate egress proofs |
| RG-127 | S3 mutation-sweep coverage | `PARTIAL` | Deliberate-mutation tests delivered for PDFIncrementalFormWriter (12 Swift mutations), redaction completeness validator (7 Node mutations), and signature guard (12 Node mutations). Each proves a guard kills a specific tampering pattern. Broader S3 coverage for remaining validators and detectors remains open |

### RG-006: Native VoiceOver workflow

- **Scope:** All native SwiftUI controls, navigation, errors, and interactive elements.
- **Required evidence:** Every button, picker, list item, and status element has an `.accessibilityLabel()`; every interactive element has an `.accessibilityHint()`; selection state uses `.accessibilityAddTraits(.isSelected)`.
- **Current evidence:** 38+ `.accessibilityLabel()` / `.accessibilityHint()` / `.accessibilityAddTraits()` annotations across 6 views: ContentView (toolbar, mode picker, agent palette, export, password), DocumentCanvasView (PDF canvas, zoom controls, rotation), ContextualInspectorView (candidate list, search matches, prev/next), PageThumbnailRailView (page items, insert button), DiffComparisonView (page navigation, zoom), AgentCommandHUD (clear button, command list items). All icon-only buttons have explicit labels. Picker items use `Label()` with system images for built-in VoiceOver text.
- **Disposition:** `PARTIAL`. Core reader controls are covered. Remaining gaps: WelcomeView page-size picker `.help()` text could use explicit `.accessibilityLabel()`, SettingsView toggles need audit, and VoiceOver rotor/navigation flow needs manual testing on device.
- **Falsifier:** Any interactive control lacks an accessible name or hint, or VoiceOver cannot reach a function the mouse can.
- **Evidence:** [`audits/full-persona-audit-2026-08-26.md`](audits/full-persona-audit-2026-08-26.md) — Researcher + Security Auditor + Reviewer persona audit.

### RG-007: Browser screen-reader workflow

- **Scope:** All web app controls, landmarks, text layer, search, status, and password flow.
- **Required evidence:** ARIA landmarks, roles, labels, live regions, and keyboard navigation覆盖 all interactive surfaces.
- **Current evidence:** `index.html` has 5 `role="status" aria-live="polite"` regions (status bar, product mode, analysis pill, analysis console, validation box). Search count span has `role="status" aria-live="polite" aria-atomic="true"`. All buttons have `aria-label` attributes. Skip-link present. Password dialog uses proper ARIA. Search controls (input, find, prev, next, count) all have `aria-label`.
- **Disposition:** `PARTIAL`. ARIA landmarks and live regions are in place. Remaining gaps: text-layer keyboard focus traversal needs verification, analysis overlay screen-reader behavior needs testing, and keyboard-shortcut help panel needs `aria-expanded` state management.
- **Falsifier:** A screen reader cannot discover or operate any function available via mouse, or status changes are not announced.
- **Evidence:** [`audits/full-persona-audit-2026-08-26.md`](audits/full-persona-audit-2026-08-26.md).

### RG-043: Search status announcements

- **Scope:** Search match count, current result position, page changes, and no-match state.
- **Required evidence:** Screen readers announce match count changes, current result index, page navigation, and "no matches" state.
- **Current evidence:** Web: `#searchCount` span has `role="status" aria-live="polite" aria-atomic="true"` — updates to "N result(s)" are announced by screen readers. No-match message div has `role="status"`. Native: `ContextualInspectorView` displays search match count in section header with `Text("Search Hits (\(model.searchMatches.count))")` and individual results have `.accessibilityLabel()` with page number and snippet.
- **Disposition:** `PARTIAL`. Web search count and no-match state are announced. Native search result navigation announcements are present. Remaining gaps: native VoiceOver rotor search navigation, web search result focus-trapping, and current-result-position announcement (e.g., "result 3 of 12").
- **Falsifier:** A screen reader user cannot determine how many matches exist or which result is selected.
- **Evidence:** [`audits/full-persona-audit-2026-08-26.md`](audits/full-persona-audit-2026-08-26.md).

### RG-057: Focus restoration

- **Scope:** Focus returns predictably after modal dismissal, search navigation, link jumps, error alerts, and page jumps.
- **Required evidence:** After every modal/sheet/alert dismiss, focus returns to the triggering element or a logical successor.
- **Current evidence:** Native: SwiftUI sheets (password, manual text, signature, security vault, diff comparison) automatically restore focus to the triggering control on dismiss — this is default SwiftUI behavior. `@FocusState` in AgentCommandHUD manages search-field focus within the HUD. Web: No explicit focus management beyond browser defaults; the `#searchInput` retains focus during search operations.
- **Disposition:** `PARTIAL`. SwiftUI default focus restoration covers sheet dismissal. Remaining gaps: explicit focus restoration after AgentCommandHUD dismiss (should return to main content), keyboard-shortcut help panel toggle needs focus management, and web analysis overlay dismiss needs focus return.
- **Falsifier:** After dismissing a modal, the keyboard focus is lost or trapped in a non-interactive region.
- **Evidence:** [`audits/full-persona-audit-2026-08-26.md`](audits/full-persona-audit-2026-08-26.md).

### RG-058: Reduced motion

- **Scope:** All transitions, animations, and motion-based feedback across native and web.
- **Required evidence:** `prefers-reduced-motion: reduce` disables or minimizes animations; `accessibilityReduceMotion` is respected in SwiftUI.
- **Current evidence:** Web: `design-system.css` has `@media (prefers-reduced-motion: reduce)` that sets `transition-duration: 0.01ms`, `animation-duration: 0.01ms`, `animation-iteration-count: 1` globally, with explicit `transform: none` on analysis overlays. `app.js` checks `window.matchMedia("(prefers-reduced-motion: reduce)").matches` before initiating rubber-band scroll and mode-stage transitions. Native: `ContentView` reads `@Environment(\.accessibilityReduceMotion)` and selects `.easeInOut(duration: 0.15)` instead of `.spring(response: 0.25, dampingFraction: 0.8)` for the agent HUD animation.
- **Disposition:** `PARTIAL`. Core transitions respect motion preferences. Remaining gaps: sheet presentation transitions (`.scale + .opacity`) don't explicitly check `reduceMotion` (SwiftUI handles automatically for implicit animations), and rubber-band overscroll CSS fallback for reduced-motion needs verification.
- **Falsifier:** Enabling `prefers-reduced-motion: reduce` or VoiceOver reduce motion still causes jarring or vestibular-triggering animations.
- **Evidence:** [`audits/full-persona-audit-2026-08-26.md`](audits/full-persona-audit-2026-08-26.md).

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

### RG-076: Canonical capability matrix

- **Scope:** Single source of truth for every capability, provider implementation state, evidence gates, and product claim.
- **Required evidence:** A machine-readable registry (`capability-matrix.json`) and prose matrix (`capability-matrix.md`) that agree on every capability state.
- **Current evidence:** Machine-readable matrix delivered 2026-08-26 (`docs/capability-matrix.json`): 20 capabilities + 5 unsupported capabilities with native/web/contract/gate/claim/limits fields. Prose matrix (`docs/capability-matrix.md`) remains authoritative with 21 capability rows covering native macOS, web companion, shared contract, evidence gate, and product claim.
- **Disposition:** `PARTIAL` — JSON and prose matrices exist and agree; automated validation and CI integration remain open.
- **Falsifier:** JSON and prose matrices disagree on any capability state, or a capability is advertised without evidence gate linkage.
- **Evidence:** [`capability-matrix.json`](capability-matrix.json), [`capability-matrix.md`](capability-matrix.md).

### RG-084: Support policy

- **Scope:** Explicit boundaries for supported platforms, browsers, PDF types, limits, encryption, and OCR languages.
- **Required evidence:** A document that defines what is supported, what is not, and what limits apply.
- **Current evidence:** Support policy drafted 2026-08-26 (`docs/support-policy.md`): macOS 15+ (Apple Silicon primary), Safari/Chrome primary, 14 PDF types mapped, encryption support matrix, OCR (English only), accessibility status, supported/unsupported operations, update lifecycle.
- **Disposition:** `PARTIAL` — document exists with recommendations; human product decision required before activation.
- **Falsifier:** A capability is advertised as supported outside the boundaries defined in this policy.
- **Evidence:** [`support-policy.md`](support-policy.md).

### RG-122: Native macOS codesign and notarization

- **Scope:** App binary is codesign-identified, notarized by Apple, and staple-verified before any distribution claim.
- **Required evidence:** Successful codesign, notarization, and stapling with a valid signature chain.
- **Current evidence:** Codesign workflow documented 2026-08-26 (`docs/codesign-notarize-workflow.md`): full build-sign-notarize-staple-verify pipeline with CI/CD GitHub Actions template, verification checklist, troubleshooting guide.
- **Disposition:** `BLOCKED` — requires Apple Developer account ($99/year) and signing credentials.
- **Falsifier:** `spctl --assess --type execute` fails on the app bundle, or notarization ticket is missing.
- **Evidence:** [`codesign-notarize-workflow.md`](codesign-notarize-workflow.md).

### RG-123: Auto-update mechanism

- **Scope:** A documented update channel delivers signed updates to users; rollback and version-compatibility are explicit.
- **Required evidence:** Update mechanism configured, tested, and privacy-compliant.
- **Current evidence:** Auto-update integration plan documented 2026-08-26 (`docs/auto-update-integration.md`): Sparkle 2.x framework recommended, EdDSA signing, appcast feed format, update flow, rollback strategy, privacy compliance, hosting requirements. 1-2 day implementation estimate.
- **Disposition:** `BLOCKED` — requires hosting setup and EdDSA key generation.
- **Falsifier:** Update mechanism sends data without consent, or fails to verify EdDSA signatures.
- **Evidence:** [`auto-update-integration.md`](auto-update-integration.md).

### RG-124: Crash-reporting boundary

- **Scope:** Crash telemetry is bounded by the privacy policy (RG-028); opt-in consent is explicit; no raw PDF bytes or user content leak into crash reports.
- **Required evidence:** Crash reporting respects privacy boundary and requires explicit consent.
- **Current evidence:** Crash-reporting boundary documented 2026-08-26 (`docs/crash-reporting-boundary.md`): privacy boundary recap, no-telemetry recommendation (safest), opt-in consent flow, what crash reports may/must-not contain, local-only crash logs alternative, network boundary, GDPR/CCPA compliance.
- **Disposition:** `PARTIAL` — boundary document exists; product decision on telemetry scope required before implementation.
- **Falsifier:** Crash report contains PDF content, user data, or file paths, or telemetry is sent without consent.
- **Evidence:** [`crash-reporting-boundary.md`](crash-reporting-boundary.md).
