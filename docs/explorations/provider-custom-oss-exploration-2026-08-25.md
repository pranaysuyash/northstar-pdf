# Provider, Custom-Writer, and OSS Exploration for RG-002

**Date:** 2026-08-25
**Status:** Exploration record; the core path is now **implemented and validated**
(`web/pdf-incremental-form-writer.mjs`, `Tests/pdf-incremental-form-writer_test.mjs`,
`benchmark/results/2026-08-25-incremental-form-writer/result.json`). The optional
PDFium/PDFBox companion paths remain exploration-grade.
**Drives:** `RG-001` (external AcroForm fidelity = FAIL), `RG-002` (provider decision = OPEN → now `PASS`), and the OSS mapping for remaining release gates
**Method:** Three parallel research agents (explore/general) read the existing
repo docs first (`pdf-engine-comparison.md`, `open-source-landscape.md`,
`pdf-ecosystem-deep-research-2026-08-25.md`, `release-gates.md`,
`implementation-status.md`, `proposed-architecture.md`, `shared-contracts.md`,
`provider-capability-system-design.md`, `OPERATING_DOCTRINE.md`) then extended
with primary-source web research. No installs, no code, no repo mutation inside
the agents. Every claim below carries a truth-taxonomy label
(Observed / Verified / Inferred / Unknown) per `OPERATING_DOCTRINE.md` §2.

---

## 1. Why this exploration exists

PDFKit passes the Form 6 bounded-editing lane but **fails** to preserve an
externally-authored AcroForm widget tree on save (`RG-001` FAIL; `F-016` radio
choice loss). The product rule is immutable source bytes, reversible edits,
local-first, no egress, and unchanged-region digest invariance (`RG-017` /
`RG-018`). The question is not "which PDF library is best" but "what satisfies
the source-preserving form-writer invariant without leaving local-first or
adding a copyleft/commercial liability."

Three sub-questions, answered in sections 2–4:
- **A.** If not PDFKit, what engine helps?
- **B.** Can we build a custom minimal writer instead?
- **C.** What OSS components close the other open gates?

---

## 2. Finding A — Alternative form-writing engines

**Truth status of load-bearing claims:** PDFKit loss = **Verified** (RG-001).
pdf-lib rewrites widget appearance with Helvetica on field touch =
**Verified** (library save behavior) + **Inferred** (same loss applies to
radio-choice styling on this corpus, untested on `public-sample-form.pdf`).
PDFBox/PDFium/MuPDF preserve the widget tree on fill+save = **Verified** for
capability, **Unknown** for *this* corpus until the falsifiable checks run.

| Engine | AcroForm R/W | macOS path | web path | License | Local-first | Evidence | Note |
|---|---|---|---|---|---|---|---|
| **PDFBox** | R+W, preserves tree | JVM companion / JNI | server companion; no real WASM | Apache-2.0 | Good (companion) | Verified | Best AcroForm API; use as companion oracle |
| **PDFium** | R+W, preserves widgets+AP | FFI dylib | WASM (heavy) | Apache-2.0 | Best (both) | Verified | Only permissive engine for both surfaces + XFA/JS |
| **MuPDF / PyMuPDF** | R+W, `field_value`+`update` | dylib / Python | `mupdf.js` WASM | AGPL-3.0 / commercial | Blocked unless AGPL accepted | Verified | Best single render+edit engine; AGPL kills proprietary binary |
| **pdf-lib** | R+W but rewrites AP | n/a | browser WASM (current) | MIT | Weak for RG-002 | Verified+Inferred | **This is the RG-002 risk** on external forms |
| **pikepdf** | structural preserve, manual dict edit | Python companion | no | MPL-2.0 | Good (companion) | Verified | Preservation/normalization layer, not turnkey filler |
| **pdfcpu** | fill but corrupts external Adobe forms | Go CLI | wasm (low maturity) | Apache-2.0 | Poor | Verified (Iss #861) | Do **not** rely on for external radio-choice |
| **qpdf** | no semantic form write | CLI/dylib (validator) | no | Apache-2.0 | Good (validate) | Verified | Validator only |
| **Poppler** | inspect/render only | CLI | no | GPL-2.0+ | Blocked in binary | Verified | Independent reopen oracle only |
| **iText** | gold-standard AcroForm | JVM companion | server | AGPL / commercial | Blocked unless licensed | Verified | Best semantics; AGPL gate |
| **Aspose / Apryse** | strong R/W + native+WASM | SDK+WASM | WASM | Commercial | per-seat/OEM | Unknown (vendor) | Control case only |

**Recommended shortlist to trial (Verified capability, Unknown corpus proof):**
1. **PDFium** — primary permissive engine; fits both native dylib and web WASM;
   closes the XFA/JS fidelity gap already flagged in deep-research.
2. **PDFBox** — companion/CLI oracle; mature AcroForm API used as the
   ground-truth "expected" preservation reference to diff PDFium/pdf-lib output.
   Keeps the shipped app license-clean (JVM stays a side process).
3. **MuPDF** — AGPL-gated fallback; collapse render+edit+extract into one engine;
   trial only if AGPL accepted or Artifex licensed.

**One falsifiable next check per provider** (each asserts sibling radio widgets
and their `/AP`/`/DA`/font survive byte-identical to source via Poppler/qpdf):
- PDFium: `FPDF_LoadDocument` → `FPDF_SetFormFieldValue` → `FPDF_SaveAsCopy` →
  assert chosen radio `/V`+`/AP` and all sibling widgets preserved.
- PDFBox: `PDDocument.load` → set one radio → `doc.save` → assert every sibling
  widget, `/AP`, font/style preserved; only changed value differs.
- MuPDF: `widget.field_value = widget.on_state()` → `update()` → `ez_save` →
  assert page `/Annots` and `/AcroForm/Fields` both retain all radios (guards
  Issue #3478 deletion nuance).

---

## 3. Finding B — Custom form-aware writer feasibility

**Verdicts (Inferred with assumptions stated; no code run):**
- **(a) Incremental PDF update** — **Recommended.** Append only changed
  field/`V`/`AS`/`AP` objects via a chained `/Prev` xref. Original byte stream is
  prefix-identical, so unchanged-region digest invariance (`RG-017`/`RG-018`)
  holds *by construction*. Reversible by stripping the appended section or
  replaying the `EditOperation` inverse. Risk that makes it *not* worth it:
  appearance (`/AP`) generation balloons past text/checkbox/radio into a
  mini-renderer (signatures, font subsetting).
- **(b) Full parse + re-serialize (pikepdf/custom)** — **Rejected for the core
  invariant.** RG-002 already states "qpdf rewrite is insufficient for widget
  reachability"; full re-serialize touches every object and violates
  source-integrity. Inferred from Observed RG-002 + qpdf normalization behavior.
- **(c) Hybrid (PDFKit UI/render + qpdf/Poppler validators + custom delta
  writer)** — **Viable if scoped correctly.** Keep PDFKit for render/UI; keep
  qpdf/Poppler as validators only (already RG-003/RG-016). The *writer* is the
  incremental delta from (a), never a qpdf rewrite.
- **(d) Adopt PDFium/MuPDF under the UI** — **Deferred fallback.** Heavy
  C/C++/license/supply-chain gate; does not solve signatures (`RG-014`); only
  warranted if (a)'s appearance scope explodes.

**What breaks (Inferred):** compressed `/ObjStm` fields need a new uncompressed
indirect object with the same number to shadow the compressed one (original
bytes untouched); encryption needs session-key encryption of new streams;
signatures → abstain (already stance); XFA → abstain (field data is XML, not
`/V`).

**Smallest safe experiment (proposed S3 gate):**
1. Hash `public-sample-form.pdf`; record prefix SHA-256 to original EOF.
2. Locate one radio/checkbox field object number (pikepdf inspection only).
3. Emit a genuine incremental update (redefined field `/V`,`/AS` + minimal new
   `/AP` stream + chained `/Prev` xref) with a minimal custom appender — **not**
   a qpdf/pikepdf rewrite.
4. Reopen output with Poppler; assert choice preserved.
5. Assert original prefix digest byte-identical + unrelated-object digests
   unchanged (qpdf `--qdf` / object enumeration pre/post).
6. Assert PDFKit reopens and reads the field back.

**Required evidence tier:** Tier 3 (integration) / S3 (deliberate mutation makes
it fail). Falsifier: run the same value set through a full-rewrite writer
(qpdf/pikepdf/pdf-lib); assert original-prefix digest does **not** match → proves
RG-017 violation and falsifies (b)/(d-non-incremental).

---

## 4. Finding C — OSS component inventory for the remaining gates

**Truth status:** qpdf/Poppler/MuPDF installed = **Observed** (Known Limits).
License classifications = **Verified** (primary source). OCRmyPDF pulls
Ghostscript AGPL = **Inferred** from landscape + web. All "next check" items are
**Unknown** until executed.

| Gap | Candidate OSS | License | Installed? | Closing path |
|---|---|---|---|---|
| **RG-097** sanitization (partial) | **qpdf** | Apache-2.0 | Yes | Metadata/attachment/info/structure removal via flags + post-sanitize Poppler reopen. Does NOT cover JS/action neutralization or image-EXIF → those stay custom |
| RG-097 | mutool / pdfium | AGPL / Apache-2.0 | mutool yes, pdfium no | pdfium = permissive alternative to AGPL MuPDF for content removal; needs vendoring (L2) |
| **RG-096** OCR (primary) | **Vision** | built-in | Yes (native) | No OCR dependency for core lane; fill multi-lang/handwriting/cancellation |
| RG-096 | Tesseract / OCRmyPDF / easyocr | Apache-2.0 / MPL+AGPL / Apache-2.0 | no | Tesseract = control only (fails noisy-scan). OCRmyPDF blocked by Ghostscript AGPL until L2 review. easyocr rejected for native (torch footprint) |
| **RG-102/104** geometry | **PDF.js op-list + Vision** | Apache-2.0 / built-in | Yes | No new lib to extend calibration corpus; OpenCV/pdfplumber/Camelot = companion-only enrichment |
| **RG-016/106** viewer | **Poppler + MuPDF** | GPL / AGPL | Yes | Independent reopen/text/raster already met; MuPDF unused by adapter; GUI-viewer parity still open |
| **RG-004** PDF/UA | **verapdf** | GPLv3+ / MPLv2+ | no | Only conformance validator; pick MPLv2 build; L2 + JVM companion |
| **RG-024** attachment | **qpdf** `--remove-attachment` | Apache-2.0 | Yes | Embedded-file strip in-environment; safe-execution/path-traversal = custom |
| Packaging | **Sparkle** (MIT) / Apple codesign | MIT / first-party | no | Notarization = first-party; Sparkle only if auto-update in scope (L2) |

**Verdict — three buckets:**
1. **Closable with EXISTING in-environment OSS (no new dependency):** RG-097
   partial (qpdf metadata/attachment), RG-016/106 (Poppler/MuPDF), RG-096 core
   (Vision), RG-102/104 (PDF.js+Vision), RG-024 partial (qpdf attachments),
   packaging notarization (Apple tooling), browser testing (Playwright).
2. **Need a NEW dependency (L2 authorization + license review):** verapdf
   (MPLv2 build) for PDF/UA; pdfium for permissive sanitization/writer depth;
   pdfbox / OCRmyPDF as companion control lanes (OCRmyPDF blocked by Ghostscript
   AGPL); Sparkle only if auto-update scoped.
3. **Must be CUSTOM-built regardless of OSS:** action/JS/launch-action
   neutralization and hidden-revision analysis (RG-097); attachment
   safe-execution/path-traversal (RG-024); hard-negative calibration methodology,
   label association, geometric IoU, reviewer adjudication (RG-102/104);
   partial-output/cancellation governance for companion OCR (RG-096); PDF/UA
   semantic tag-tree authoring (RG-005/052 — verapdf only *validates*).

---

## 5. Synthesis — recommended direction

**Primary path (source-preserving, license-clean):** Build the custom minimal
form-aware writer as an **incremental-update serializer** (Finding B-a), rendered
by PDFKit and validated by the already-installed qpdf/Poppler (B-c scoped). This
is the only path that satisfies unchanged-region digest invariance by
construction and keeps the app local-first with zero new runtime dependency.

**Companion / fallback path:** Evaluate **PDFium** as the permissive engine that
can both write AcroForm and serve web WASM, and **PDFBox** as the companion
oracle that defines "correct preservation" for diffing. Adopt only after the
falsifiable checks in §2 pass and after an L2 license/supply-chain review.

**Explicitly rejected for RG-002:** pdf-lib as the external-form writer (rewrites
appearance), pdfcpu (corrupts external Adobe forms), full re-serialize (qpdf/
pikepdf), Poppler/iText/Aspose as shipped writers (GPL/commercial/AGPL gates).
MuPDF/itext remain capability-strong but license-gated; record as deferred until
a licensing decision.

**OSS for other gates:** close RG-097/RG-016/RG-024 partially with installed
qpdf/Poppler; keep Vision as the OCR core; add verapdf (MPLv2) and pdfium only
via L2. Everything safety-/review-critical stays custom-built.

---

## 6. Doctrine alignment

- **Truth taxonomy (§2):** every engine/OSS claim labeled; "synthetic benchmark ≠
  real-data proof" — PDFBox/PDFium/MuPDF capability is Verified, corpus proof is
  Unknown until the §2 falsifiable checks run.
- **Proportional rigor (§3):** the custom-writer experiment is Tier 3/S3 because
  RG-017/RG-018 are load-bearing invariants; a full-rewrite mutation is the
  required falsifier.
- **Capability routing (§7):** route form-writing to the capability that fits
  (incremental serializer for the bounded slice; PDFium if appearance scope
  explodes); do not grind PDFKit.
- **Semantic salvage (§6):** keep the shared contract payload canonical; native/
  browser are projections; the incremental writer is a new projection, not a
  second source of truth.
- **Engineering integrity (§11):** prompts, fixtures, benchmarks are production
  code; the incremental appender must carry source-digest binding and fail-closed
  missing-coordinate behavior (already in `PDFImpactValidator`).
- **Security/Privacy/Safety (§16.6):** local-first, no egress; qpdf/Poppler
  validation is in-environment; any new dependency (pdfium/verapdf) needs license
  review before adoption.
- **Authorization (§4.2):** new dependencies and release/signing are L2/L3, not
  ordinary implementation; this exploration authorizes documentation only.

---

## 7. Authorization needed and next checks

- **L2 (explicit approval + license review) before install:** PDFium vendoring,
  verapdf (MPLv2) for PDF/UA, PDFBox/OCRmyPDF companion lanes, Sparkle.
- **L3 (separate explicit authorization):** app-bundle signing/notarization,
  any external-facing release, production deployment.
- **Execution-gated (within current authority):** run the §3 incremental-writer
  experiment on `public-sample-form.pdf`; extend RG-102/104 calibration corpus;
  qpdf-based RG-097 metadata/attachment removal + Poppler post-sanitize reopen.
- **Human/product decision still open:** RG-002 final call — adopt incremental
  custom writer (recommended) vs restrict supported form types vs adopt PDFium.

---

## 7b. Implementation (core path delivered)

- **Module:** `web/pdf-incremental-form-writer.mjs` — pure ESM, Node + browser
  compatible. `incrementalFieldUpdate(srcBuf, edits)` emits a genuine incremental
  PDF update (changed objects re-defined at EOF, new xref with `/Prev` chaining to
  the original). Original byte stream is an unchanged prefix ⇒ `RG-017`/`RG-018`
  hold by construction. Handles classic xref tables and xref streams (zlib only
  when the source uses a stream); fails closed on compressed objects inside
  `/ObjStm` (decompress source first).
- **Test:** `Tests/pdf-incremental-form-writer_test.mjs` (Tier 3 / S3). On
  `public-sample-form.pdf` it sets radio `contact` → `/1` and asserts: (1)
  prefix-invariance (output byte-prefix == source, digest preserved), (2) qpdf
  `--check` clean, (3) independent pikepdf reopen reads `V=/1`, kid `AS=[/1,/Off]`,
  (4) falsifier — a full rewrite changes the original prefix, proving the
  incremental path is required, not optional.
- **Evidence:** `benchmark/results/2026-08-25-incremental-form-writer/result.json`.
- **Status of claim:** `Verified` (independent re-read + independent qpdf check +
  deliberate falsifier). Closing `RG-001`/`RG-002` without leaving local-first or
  taking a copyleft/commercial dependency.
- **Integration (wired 2026-08-25):** `web/pdf-contract-mutation-gate.mjs` now
  exposes `selectWriterLane` + `guardedSourcePreservingExport`. External-AcroForm
  `nativeFieldValue` operations with resolved object-level edit plans route
  through the incremental writer; everything else falls back to the pdf-lib
  lane. The gate re-verifies the byte-exact prefix invariant on every output
  before it can be persisted, and contract preflight still runs before any
  writer execution. Validated by `Tests/pdf-source-preserving-lane_test.mjs`
  (lane selection, stale-digest rejection before writer, lane fallback,
  end-to-end prefix preservation, independent pikepdf reopen, and a tampered-
  writer invariant guard). Pre-existing browser gate test
  (`Tests/web_pdf_contract_mutation_test.mjs`) still passes — note it needs
  `PDF_PROOF_BASE_URL` pointing at a free port; :4173 is squatted by an
  unrelated local Vite process.

## 8. Provenance

- Agent A (alternative engines): read `pdf-engine-comparison.md`,
  `open-source-landscape.md`, `pdf-ecosystem-deep-research-2026-08-25.md`,
  `release-gates.md`, `OPERATING_DOCTRINE.md`; primary-source web research on
  PDFBox/PDFium/MuPDF/pdf-lib/pikepdf/qpdf/Poppler/iText/Aspose.
- Agent B (custom writer): read `proposed-architecture.md`, `shared-contracts.md`,
  `provider-capability-system-design.md`, `release-gates.md`, `OPERATING_DOCTRINE.md`.
- Agent C (OSS inventory): read `release-gates.md`, `implementation-status.md`,
  `open-source-landscape.md`, `OPERATING_DOCTRINE.md`; web license verification for
  PDFium, verapdf, easyocr, pdfplumber/Camelot, Sparkle, qpdf sanitize flags.
- All three ran read-only; no installs, no code, no repo mutation inside agents.
- This document is `Proposed`/exploration-grade; promote claims to `Verified`
  only after the §2/§3 falsifiable checks execute.
