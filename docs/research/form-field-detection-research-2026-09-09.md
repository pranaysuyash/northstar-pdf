# Robust Field, Label, Checkbox & Signature Detection — Research Map

**Date:** 2026-09-09
**Status:** research record (durable knowledge; nothing here changes gate, task, or capability state — see D-055 owners)
**Scope:** native macOS plane (browser plane parked per PL-D14 Mac-first re-scope, `docs/audits/persona-launch-acceptance-audit-2026-09-07.md` §10.11)
**Method:** three parallel lanes — (1) live-code capability map of `Sources/PDFEditorCore` + tests, (2) eval-asset inventory of `benchmark/` + `docs/`, (3) external state-of-the-art scan with primary-source citations. Repo claims below were spot-verified against the working tree (Observed, Tier 1). External claims carry per-claim confidence notes in §8.
**Companion docs:** `docs/explorations/field-suggestions-exploration-2026-08-25.md` (prior detection exploration, R1–R7), `docs/implementation-status.md` (known limits), `docs/audits/rg134-checkbox-closure-2026-09-06.md` (AcroForm parity history), `docs/form6-benchmark.md` (static-form ground truth).

---

## 1. Problem taxonomy

"Detect form fields" is four different problems wearing one name. Any robust design must first classify the document, because the correct detection channel — and the achievable accuracy — depends on the regime:

| Regime | What exists in the file | Best channel |
|---|---|---|
| **Interactive AcroForm** | `/Root/AcroForm/Fields` tree + `/Widget` annotations | Structural object-graph parse (ground truth; ~100% achievable) |
| **Interactive XFA** | XML data layered on (often stub) AcroForm | Out of scope by policy (CAP-016 unsupported); detect and degrade |
| **Flat, vector-digital** | Drawn lines/rects + real text layer (no widgets) | Vector geometry + text-label anchoring + fusion |
| **Flat, scanned** | One big raster image per page | OCR + raster geometry + ML detector |

Within the flat regimes, the detection targets decompose into:

1. **Fillable regions** — text fields (single-line, multiline, comb/character grids, date runs `[DD][MM][YYYY]`), choice fields.
2. **Labels** — the text that names a region; the label↔region *association* is its own sub-problem (this is what FUNSD formalizes as QUESTION→ANSWER linking).
3. **Checkboxes and radio groups** — small square geometry + grouping into exclusive sets + *state* (checked/unchecked ink).
4. **Signature areas** — signature placement regions ("Sign here", X-marks, signature lines) and existing signature *ink*; distinct from AcroForm `/Sig` digital-signature fields (which this app already detects and refuses to edit, RG-014).

The app's product framing — fill-any-form incl. forms that were never interactive — requires all four targets in all flat regimes, plus correct AcroForm handling when fields do exist. That is the same target taxonomy as the external **CommonForms** dataset (§4.4): text input, choice button, signature.

---

## 2. Where the app is today (Observed)

### 2.1 AcroForm channel — mature, parity-governed

Four independent engines are reconciled by a parity experiment (`Sources/PDFEditorCore/AcroFormParityExperiment.swift`):

- **PDFKit annotation API** — production read path (`PDFKitProvider.swift:566-715`); maps `/Tx /Btn /Ch /Sig` to `NativeField` (no radio/checkbox split at this layer — both `.button`).
- **Custom structural parser** — `PDFIncrementalFormWriter.swift` (`walkAcroForm` :1059, `walkField` :1153); walks `/AcroForm/Fields` *and* merges orphan page-`/Annots` widgets; reads `/FT /V /AS /AP /Opt /Ff /I /Rect /T`. Also the production **write** substrate (incremental, byte-exact-prefix, RG-017).
- **pdf-lib lane** — independent pure-JS provider (`AcroFormExternalEngines.swift`, `benchmark/acroform-lane/lane.mjs`).
- **qpdf `--json`** — read-only verifier row.

Current parity report (`benchmark/results/acroform-parity/acroform-parity-gate-report.json`, regenerated 2026-09-09): `gatePassed: false`; checkbox/choice/text cross-provider agreement 1.0 (production-ready); **radio agreement 0.333** (PDFKit annotation API writes `/AS` but omits radio group `/V` — spec-incomplete row, documented in `docs/audits/rg134-checkbox-closure-2026-09-06.md`). No `/Sig` field type in the parity corpus.

Hard-won doctrine already encoded in code (do not regress): structural on-token derivation from `/AP /N` keys minus `/Off` (never hardcode "Yes"); `/Opt` pair-form display/export split; radio selection read from `/AS` never `/V` alone; document-level radio grouping by shared field name with >1 kid; `/NeedAppearances` deliberately avoided.

### 2.2 Flat-form heuristic channel — exists, measured weak, correctly untrusted

`StaticRegionDetector.swift` consumes `PDFVectorStreamParser.swift` geometry (`potentialInputBoxes` 24pt–0.92·page wide, `potentialUnderlines` ≥24×≤4pt, `potentialCheckboxes` square-ish 8–32pt) plus text lines, and produces `RegionCandidate`s with per-source heuristic scores (0.45–0.90; OCR ≤0.6):

- character-cell grids → one region (≥3 cells + label within 160pt, score 0.90)
- isolated checkbox geometry (label within 120pt; `interiorTextCoverage ≤ 0.40` rejects boxes over text; 0.85)
- input boxes (label within 160pt; 0.80)
- vector underlines → entry band (0.75)
- text-anchored underscore runs / trailing `:` (0.45/0.58)
- label association = nearest label left-of-same-row or above (`findNearestLabel` :486-523) + keyword table + hand-curated hard negatives (`isLikelyFieldLabel` :528-544)
- field-type inference by label keywords incl. "sign"/"signature" → `.signature` (:555-584)

**Measured baseline (Observed):** Form 6 static benchmark — 7/33 semantic targets, **21.21% label-associated recall proxy, 11.96% labeled-candidate precision proxy**, 97 candidates (`docs/implementation-status.md:228`; explicitly *not* geometric IoU, single fixture).

### 2.3 Trust infrastructure — the strong asset

This is the part most projects lack and this repo already has:

- **Evidence fusion** (`EvidenceFusion.swift`): per-kind weights, `score = 0.55·support + 0.25·coverage + 0.20·geometric-agreement(IoU)`; thresholds accept 0.72 / review 0.45; conflict → abstain with reason codes. Attached to every `RegionCandidate` at init.
- **Review-before-trust UI**: suggested → reviewed → confirmed flow in `ContextualInspectorView`; confirm/reject/rename journal as value-free `CandidateReviewLearningEvent`s; `CandidatePriors` (Beta(2,2), clamped multiplier) reorder ranking only, never contract scores; Stage-2 learned calibration re-fuses weights.
- **Detector gates**: `NativeDetectorGate` / `DualLaneDetectorGate` against a 108-case human-reviewed ground truth; detector-calibration policy artifact (positiveMatchIoU 0.25, hard-negative FPR 0, required recall 1.0).
- **Evidence graph** (`DocumentEvidenceGraph.swift`): field/candidate/table/entity nodes with `contains`/`annotates` edges + grounded search.

### 2.4 OCR channel

`VisionOCRProvider` (VNRecognizeTextRequest, `.accurate`, 2× raster) + `VisionCVProvider` (VNDetectRectangles) + `HybridOCRRouter` (digital-vs-scanned by text-length). OCR feeds detection only via `detectOCR` (underscore/colon lines → `.ocrRegion` candidates, "evidence, not a field contract"). Auto-OCR only on text-poor pages with no native fields (PL-I29/D-080), 45s watchdog. Cross-provider WER benchmark exists and is gated (`compare_ocr_wer.py`; Apple Vision avg WER 0.0 on the 8-fixture corpus).

### 2.5 Gaps (Observed, from live code + docs)

1. Detection accuracy unproven at production grade (§2.2 numbers; no geometric IoU ground truth; per-class metrics explicitly listed as the next benchmark).
2. No radio/checkbox distinction in the app's `NativeField` model (only in the parity experiment).
3. `NativeField` carries no confidence; evidence-graph field nodes hard-code 1.0; fusion weights not per-class calibrated.
4. Label association is proximity + keyword table only.
5. No general whitespace analysis; no ruling-line clustering reused from table detection (table detection itself is a text-position heuristic).
6. Signature-area detection is label-keyword only; no classifier; no signature fixtures in any eval corpus; no `/Sig` in parity corpus.
7. Single OCR engine, English-centric; handwriting gate open.
8. Structural parser limits: encrypted refused; FlateDecode-only ObjStm; PDFKit cannot reopen hybrid incremental revisions.
9. Dual-lane gating depends on the parked browser lane (PL-D14).

---

## 3. How AcroForm detection must work (channel A — ground truth)

Verified against ISO 32000-1 §12.7 and corroborated by this repo's RG-134 history. The repo already handles most of this; listed as the complete checklist for robustness:

- **Four `/FT` values only**: `/Tx /Btn /Ch /Sig`. Subtype disambiguation needs `/Ff` flags: `/Btn` bit 16 = radio, bit 17 = pushbutton; `/Tx` bit 13 multiline, bit 14 password, bit 25 comb; `/Ch` bit 18 combo, bit 22 multi-select.
- **Two legal layouts**: separate field + widget dicts linked by `/Parent`, or **merged** field-keys-on-widget. Walk BOTH `/AcroForm/Fields` (with inheritance of `/FT /T /V /Ff /DA /Q` through ancestors) AND page `/Annots`; dedupe. (In-repo: orphan-widget merge already implemented; field-only enumeration yields no geometry — always resolve to widget `/Rect`.)
- **Terminal kids may omit `/FT`** (inherited) — naive widget-only walks misclassify them (in-repo fixed, RG-134 root cause 5).
- **On-state names are arbitrary**: checkbox/radio `/AP /N` keys minus `/Off`; radio kids in one group may have *different* on-names. (In-repo: `checkboxOnToken` derivation.)
- **Radio group = one field, many kids**, each with own `/Rect` and on-state; the group's `/V` names the *selected kid's on-state*, not "Yes". Read selection from kid `/AS`; write `/V` on the field + `/AS` on the carrier kid + `/Off` on siblings.
- **`/Opt` may be string-array or display/export pair-array** (§12.7.5.4 Table 247); PDFKit `dataRepresentation()` drops radio parent `/Opt` — map from original bytes (in-repo doctrine).
- **`/NeedAppearances`** may be set by third-party producers; values can be invisible in viewers that ignore it. (In-repo: per-widget `/AP /N` generation instead.)
- **XFA** (`/AcroForm/XFA`): treat as detect-and-degrade ("not reliably fillable"); the repo's `XFAFormProcessor` is a dead-code candidate (task A-10) — raw `/XFA` byte-scan exists but no XFA lane is claimed.
- **Degenerate producers** exist in the wild (duplicate `/V`, treeless `/Annots`, qpdf-observed quirks) — the parity corpus exists precisely to measure these rather than assume them; open hypothesis that real-producer quirks still show round-trip gaps (`docs/explorations/post-audit-exploration-ledger-2026-09-06.md:22`).

**Design consequence (already the repo's implicit architecture, restated):** the structural parser is the ground-truth channel for interactive PDFs; PDFKit's `PDFFormField` API is a rendering/convenience layer, not a contract layer. PDFKit exposes nothing for `/Ff`, `/AP` enumeration, XFA, or NeedAppearances, and its annotation-API saves are the documented source of the radio spec-incomplete row.

---

## 4. External state of the art

### 4.1 Flat-form heuristics (channel B+C) — validated patterns

The classic pipeline, consistent across pdfplumber/PyMuPDF practice and the best OSS reference implementation (pdf-form-builder):

1. Text layer → label candidates: trailing `:`, `Name`-like tokens, literal underscore runs `____` (underscore runs are *text*, not lines, in many flat PDFs — handle both).
2. Vector geometry → merge collinear horizontal segments; long-thin horizontals = underlines; small squares = checkbox candidates; four separate lines may form a box; filled white rects may be boxes.
3. Candidate region synthesis: box bounded by underline + next label/verticals; whitespace analysis for borderless blanks.
4. Raster fallback for scans: morphological line/box detection **after deskew** (crooked scans are the norm).

Working heuristics worth porting: label-left-of-underline on same baseline; label-above-box; evenly spaced tick marks inside a box → **comb field**; `[DD]/[MM]/[YYYY]` box runs → linked date fields; small square + adjacent text → checkbox. (The repo implements most of these already; comb/date-run linking is thinner.)

Known failure modes (robustness catalog §6): table rules masquerading as underlines; dotted leaders; multi-column labels; "X" marks misread as text; decorative boxes over text (in-repo `interiorTextCoverage` gate exists); scans with no reliable OCR-to-line alignment.

### 4.2 Form-understanding datasets & SOTA

Corrected facts (several prompt-level folklore numbers are wrong — see §8 confidence notes):

- **FUNSD**: 199 forms (149/50), 31,485 words, **9,707 semantic entities**, 5,304 relations; labels question/answer/header/other. It is a *semantic entity labeling + linking* benchmark over OCR tokens — **not** a fillable-region detection benchmark. FUNSD+ relabels it and grows to 1,113 docs.
- **XFUND**: multilingual FUNSD (7 languages); **CORD**: receipt KIE; **DocLayNet**: 80,863 pages, 11 classes — **no form/field class** (so DocLayNet cannot measure this problem; the repo's DocLayNet eval scores a text-only heuristic baseline, advisory only).
- FUNSD SER F1 (for context): LayoutLMv2 84.2 → LiLT ≈88.4 → ERNIE-Layout 93.12, LayoutLMv3 92.08. These require transformer text+layout models that **cannot run in CoreML** (§5.3) and solve a different task anyway.

### 4.3 Direct form-field detection — CommonForms / FFDNet (Sept 2025) — the missing piece

- **CommonForms**: 55,000 documents / 450k+ pages filtered from 8M Common Crawl PDFs; **3 classes: Text Input, Choice Button (checkbox+radio), Signature** — the first large-scale dataset for exactly this app's target taxonomy. Code `jbarrow/commonforms`; val subset on HF (Voxel51).
- **FFDNet-S/L**: YOLO11-based detectors (9M/25M params), 1216px input: **mAP50-95 72.3 / 81.0 overall** (Text 61.5/71.4, Choice 71.3/78.1, **Signature 84.2/93.5**). Inference ~5–16 ms/page on a 3090Ti; <$500 training each.
- **Resolution dominates**: ~20 mAP between 640 and 1536px input — small checkboxes are the resolution-bound class.
- Qualitative finding directly relevant to positioning: **Adobe Acrobat and Apple Preview's auto-detect miss checkboxes/choice buttons entirely**.
- Applied tooling exists: `Stirling-Tools/commonforms-cpu` converts any PDF into a fillable form with the open models.

### 4.4 Checkbox specifics

- Vector PDFs: near-square hollow region (8–20pt) + state by ink coverage inside the box — cheap and deterministic; adjacent-label OCR for naming.
- Scans: small YOLO-class detector (existing open checkbox detectors: LynnHaDo/Checkbox-Detection YOLOv8 weights; FFDNet "Choice" class).
- **VLMs have a documented checkbox blind spot** (CheckboxQA, arXiv:2504.10419) — never delegate checkbox *state* to a prompted VLM.
- AcroForm side is trivial by comparison (`/AS` vs `/AP /N` keys — in-repo).

### 4.5 Signature-area detection

- ML: signature is the *easiest* of the three CommonForms classes (FFDNet-L 93.5 mAP50-95). Open datasets: Tobacco800 (~1,290 scanned docs), SignverOD (2,576 docs / 7,103 boxes), tech4humans/signature-detection (368 imgs + YOLO detector), Ultralytics 178-img signature set. (High reported accuracies on Tobacco800 should be treated skeptically — small, clean benchmark.)
- Vector flats: "Signature:"/"Sign here"/"X______" label matching + underline association (same pipeline as text fields; the repo's keyword table does exactly this) covers most business forms; ML catches signature ink where labels are absent.
- Azure Document Intelligence detects signature *presence* only, and only in specific prebuilt models — cloud is not a shortcut here.
- Product shape: propose a placement box (wider than tall, ~180×45pt) anchored on the detected line/label — matches this app's Sign mode, which already filters candidates to `entryMode == .signature`.

### 4.6 Vision-LLM assist — classify, never ground

- GPT-4o-class models are measurably weak at bounding-box coordinate regression; Gemini is relatively better (native normalized boxes); GPT-5 vision improved but is not detection SOTA. Structured-output prompting makes output parseable, not accurate.
- Right pattern (validated by pdf-form-builder): deterministic offline detection by default; optional VLM pass, **user's own API key**, only for *naming* fields and *classifying* ambiguous candidates — then **snap the VLM decision to the nearest geometric candidate** (line/rect/OCR word). Never trust VLM coordinates directly.
- Cost/privacy: cloud VLM sends the user's legal/medical/financial forms off-device — contrary to the local-first product promise; keep opt-in. (Pricing direction already assumes local-first AI re-anchored at $4.99 — `docs/` pricing doc.)

### 4.7 License hazards (binding)

- **pdf-form-builder and PyMuPDF are AGPL-3.0** — study the ideas, never port code into this proprietary app without an Artifex license. Clean-room reimplementation of published heuristics is the path.
- pdfplumber (MIT) and pypdf (BSD) are safe to study. **CommonForms/FFDNet model+dataset license must be verified before any weights ship** (paper is CC BY 4.0; repo license unstated in the paper — check `jbarrow/commonforms` LICENSE before planning a CoreML bundle).

---

## 5. Proposed robust architecture (Proposed)

Not a rewrite — a tiered channel design that plugs into the existing fusion/review/gate infrastructure. The insight from the evidence: **the trust machinery is already built; what's missing is channel quality, per-class evaluation, and an ML tier.**

### 5.1 Channel stack (routing by document class)

| Channel | Detects | Runs when | Confidence posture |
|---|---|---|---|
| **A. Structural AcroForm parse** (existing) | interactive fields, types, states, options | AcroForm present | ground truth; parity-governed |
| **B. Vector geometry** (existing, extend) | input boxes, underlines, checkbox squares, comb cells, table rules as hard negatives | vector-digital flats | evidence, fused |
| **C. Text-label anchoring** (existing, extend) | underscore runs, `:` labels, label→region association | any text layer | evidence, fused |
| **D. OCR** (existing Vision; add languages later) | text + word boxes on scans | text-poor pages | evidence only (current doctrine) |
| **E. Raster geometry** (VNDetectRectangles exists) | box contours on scans | scanned pages | evidence, fused |
| **F. ML detector — FFDNet-style YOLO in CoreML** (new) | text-input / choice / signature regions + checkbox state | flat + scanned pages; local, on-device | one more evidence family with its own weights in fusion |
| **G. VLM naming assist** (new, optional) | field *names*, ambiguous-candidate classification | user opt-in, BYO key | never grounds coordinates; snaps to nearest A–F candidate |

Routing matrix: AcroForm present → A (others off). No AcroForm + text layer → B+C(+F). Scanned → D+E+F. F is the only channel that works acceptably on ugly scans; B/C remain cheaper and more precise on clean digital flats. Channel F's per-class outputs map cleanly onto the existing `CandidateKind`/`CandidateEvidence` model as a new evidence origin (e.g. `.mlDetector`) with weights learned by the existing Stage-2 calibration.

### 5.2 Per-target playbooks

**Text fields** — A `/Tx` (+ `/Ff` comb/multiline). B input boxes + underlines. C underscore runs / colon labels. Comb grids: ≥3 evenly-spaced tick marks or same-sized adjacent cells → one region with `characterGrid` entry mode (exists). Date runs `[DD][MM][YYYY]` → linked fields with `.date` suggested type (extend). Whitespace analysis for borderless blanks (gap between label end and next same-row text) — currently only implicit; make explicit.

**Labels & association** — keep proximity rules (left-of same-row baseline; above) but: (1) replace/augment the hand keyword table with a learned label classifier once the review-event corpus grows (Stage-2 path exists); (2) measure association directly (§7); (3) optional channel G for naming. Anchor disambiguation rule when two labels compete: prefer same-baseline left, then nearest-above, then same-column below — encode as tie-break scores, not silent picks.

**Checkboxes** — B square 8–32pt + `interiorTextCoverage` gate (exists) + new interior-ink-ratio state read for scans; F choice-class boxes; grouping into radio sets: same-size squares, same row/column, evenly spaced, one shared label → `radioGroup` entry mode with `memberBounds` (model fields exist). AcroForm side: document-level grouping already proven in the parity experiment — promote it into `PDFKitProvider.inspection`/`NativeField` (gap 2.2).

**Signature areas** — C label keywords (exists) + underline/X-marker anchoring; F signature class (the best-condition ML class — 93.5 mAP50-95 externally); default placement proposal ~180×45pt anchored on the detected line. Keep RG-014 refusal-to-edit `/Sig` fields; "signature area" detection is about *placement regions on flat forms*, not digital signatures.

### 5.3 Swift implementation notes

- **YOLO11 → CoreML is first-class** (official Ultralytics export incl. ANE-targeted quantization). Known gotchas: pre/post-processing mismatch and post-conversion accuracy drift — budget a conversion-parity test (same images through PyTorch and CoreML, box-level IoU agreement gate) before trusting weights.
- **LayoutLM-family → CoreML is not feasible** (transformer + dynamic sequence lengths; ONNX importer removed from coremltools). Do not plan a LiLT/ERNIE-Layout local lane.
- 25M params at ~1216px is Mac-friendly; class count is 3, so ANE quantization headroom is good.
- PDFKit stays render/convenience-only for forms (§3). Vision OCR word boxes are the label anchor substrate for scans (already implemented).
- Fallback ladder for F: model missing/failed → channels B/C/E only, current behavior unchanged (fail-closed posture preserved).

---

## 6. Robustness catalog (checklist to gate against)

Each row: failure mode → current handling → gap. Use as fixture-generator spec (the repo's pikepdf generator pattern extends naturally).

| # | Case | Today |
|---|---|---|
| 1 | Merged field/widget dicts; orphan widgets; `/FT`-less kids | handled (structural parser; RG-134) |
| 2 | Arbitrary on-state names; per-kid differing radio on-names | handled (`checkboxOnToken`) |
| 3 | `/Opt` pair display/export forms | handled (fixture-hardened) |
| 4 | Radio group `/V` omission on PDFKit save | known; parity row open; IncrementalWriter path correct |
| 5 | XFA presence | byte-scan detect; no fill claim (policy) |
| 6 | Encrypted docs | refused (writer policy) |
| 7 | Hybrid incremental revisions PDFKit can't reopen | measured, excluded, documented |
| 8 | Underscores as glyphs vs vector lines | both handled (text-anchored + vector underline) |
| 9 | Table rules masquerading as underlines/boxes | partial (interior-text gate); no ruling-line table negatives in calibration corpus |
| 10 | Decorative boxes over text | handled (interiorTextCoverage ≤ 0.40) |
| 11 | Dotted leaders, multi-column labels, rotated pages | rotation: separate audit lanes exist; leaders/columns: unmeasured |
| 12 | Comb/date-run linking | comb grids yes; date-run linking: thin |
| 13 | Checkbox state on scans (ink ratio) | not implemented |
| 14 | Radio grouping on flats (same-size square runs) | model exists (`groupMemberCount`); grouping logic thin |
| 15 | Crooked scans (deskew before geometry) | not implemented (Vision rectangles is rotation-tolerant only partly) |
| 16 | Producer quirks beyond pikepdf fixtures | open measurement (post-audit ledger) |
| 17 | ML-detector degenerate cases (low-res scans, handwriting-only forms, stamps/seals as signature false-positives) | no coverage (no ML tier yet) |
| 18 | VLM blind spots (checkbox state; coordinate grounding) | policy: classify-not-ground (§4.6) |

---

## 7. Evaluation plan (Proposed — closes the measured gaps)

Current eval truth (Observed): FUNSD harness scores a **bbox-fed upper bound** (1.0 everywhere — measures nothing about the detector); DocLayNet eval scores a text heuristic baseline (advisory); QA-pairing heuristic F1 0.228 (sequence heuristic, not geometric linking); the production `StaticRegionDetector` has **never been scored on any public dataset**; signature detection has **zero eval coverage anywhere**; label association has no dedicated metric.

Proposed ladder, cheapest-first, reusing existing harness patterns:

1. **FD-E1 — run the production detector on FUNSD test (50 docs).** Match predicted regions to QUESTION/ANSWER entities at IoU ≥ 0.5 (the repo's DocLayNet matcher already implements greedy IoU matching — reuse). Report per-class P/R/F1 + label-association accuracy (predicted `labelText` vs associated GT question text). This converts the 21.21% proxy into a real, comparable number on public data. FUNSD is scanned-noisy, so this also exercises channels D/E.
2. **FD-E2 — adopt CommonForms val subset** as the text/choice/signature detection benchmark; report mAP50 + mAP50-95 per class. This is the only public corpus with the exact 3-class taxonomy. (License check first — §4.7.)
3. **FD-E3 — per-class Form 6 metrics** (name grids, choices, dates, signature areas, photo boxes, decorative geometry separately) — already named as the required next benchmark in `implementation-status.md`.
4. **FD-E4 — signature fixtures**: extend the pikepdf generator with `/Sig` field fixtures for the parity corpus (parity gap) + flat signature-area fixtures (label/line/X-marker) for the detector gates.
5. **FD-E5 — wire OCR→FUNSD WER** (documented in the harness notes, never run) to keep the scan-regime input quality measured.
6. **FD-E6 — extend `DetectorSemanticMeasurement`** to emit per-class and per-entry-mode precision/recall so fusion-weight learning and `CandidatePriors` get class-level signal (existing value-free machinery, no new policy).
7. **FD-E7 — CoreML conversion-parity gate** if/when channel F lands: PyTorch vs CoreML box IoU agreement on a fixed image set (S3 falsifier per TESTING_DOCTRINE).

Gates stay advisory until wired to production code paths (RG-137 precedent), then graduate through the existing NativeDetectorGate pattern.

---

## 8. Claim confidence appendix (RESEARCH_DOCTRINE)

- **High confidence (primary sources)**: FUNSD/DocLayNet/XFUND/CORD statistics; LayoutLMv3 92.08 / ERNIE-Layout 93.12 FUNSD SER F1; CommonForms 55k docs + FFDNet mAP table; YOLO→CoreML exportability; LayoutLM→CoreML infeasibility; AGPL status of PyMuPDF/pdf-form-builder; ISO 32000-1 field model.
- **Medium confidence**: LiLT ≈88.4 (paper table, config-dependent); GraphLayoutLM 93.15 (leaderboard-derived); Tobacco800 ~99.5% detector accuracy (small clean benchmark, secondary reports); XFUND exact totals.
- **Corrected folklore (do not cite)**: FUNSD is NOT 792 docs / 9,636 entities; DocLayNet is NOT 27k pages; "DocUFC" does not exist (CommonForms is the real 2025 work); "BES-signatures" dataset unverified (use Tobacco800/SignverOD/tech4humans); "Strawberry" Apple OCR model name unverified; "AnyLine" local layout tool unverified.
- **Inferred**: that FFDNet-class models transfer to this app's Mac-user form distribution without retraining (needs FD-E2 measurement on our corpora); that fusion weights can absorb ML evidence without re-tuning (needs FD-E6).
- **Unknown**: CommonForms weights/dataset license; real-producer AcroForm quirk rate beyond the current corpus.

## 9. Proposed task ledger

Research output → candidate tasks (owners/state live in `task-inventory.md` per D-055; nothing here is scheduled):

| ID | Task | Depends on |
|---|---|---|
| FD-R1 | FD-E1: production detector on FUNSD test w/ IoU + label-association metrics | — |
| FD-R2 | Verify CommonForms license; if clear, FD-E2 benchmark harness | license check |
| FD-R3 | Promote radio/checkbox split + document-level radio grouping from parity experiment into `NativeField`/inspection | — |
| FD-R4 | Extend pikepdf fixture generator: `/Sig` parity fixtures + flat signature-area/checkbox-state fixtures (FD-E4) | — |
| FD-R5 | Per-class detector metrics in `DetectorSemanticMeasurement` (FD-E6) | — |
| FD-R6 | Date-run linking + explicit whitespace analysis in StaticRegionDetector | FD-R1 baseline |
| FD-R7 | Checkbox ink-state read for scans; flat radio-group grouping | FD-R1 baseline |
| FD-R8 | CoreML FFDNet lane as evidence family (channel F) + conversion-parity gate (FD-E7) | FD-R2, FD-R5 |
| FD-R9 | Optional VLM naming assist, classify-not-ground, BYO key (channel G) | naming-eval design |
| FD-R10 | Deskew pre-pass for scanned geometry (channel E) | FD-R8 ordering |

Existing related open items: NM-T28 (calibration drift before detector claims), NM-T19 (page-local review waves), R5–R7 gated items in `field-suggestions-exploration-2026-08-25.md` (profile matcher, learning-loop closure, local-LLM label canonicalization — channel G overlaps R7).

## 10. Sources

- ISO 32000-1:2008 (PDF 1.7) §12.7 — opendata Adobe copy: https://opensource.adobe.com/dc-acrobat-sdk/docs/pdfstandards/PDF32000_2008.pdf; errata: https://pdf-issues.pdfa.org/32000-2-2020/clause12.html
- pypdf forms guide — https://pypdf.readthedocs.io/en/latest/user/forms.html; HexaPDF field docs — https://hexapdf.gettalong.org/documentation/api/HexaPDF/Type/AcroForm/Field/index.html
- FUNSD — https://guillaumejaume.github.io/FUNSD/ , arXiv:1905.13538; FUNSD+ — https://huggingface.co/datasets/Voxel51/form_understanding_in_noisy_scanned_documents_plus
- DocLayNet — https://github.com/DS4SD/DocLayNet , arXiv:2206.01062; XFUND — arXiv ACL 2022.findings-acl.253
- CommonForms / FFDNet — arXiv:2509.16506 , https://github.com/jbarrow/commonforms , https://github.com/Stirling-Tools/commonforms-cpu , HF val subset: Voxel51/commonforms_val_subset
- ERNIE-Layout — arXiv:2210.06155; LiLT — arXiv:2202.13669; LayoutLMv3 FUNSD F1 92.08 — HyperAI leaderboard summary
- CheckboxQA (VLM checkbox blind spot) — arXiv:2504.10419; LynnHaDo/Checkbox-Detection — github.com/LynnHaDo/Checkbox-Detection
- Signature datasets — TC11 Tobacco800 (tc11.cvc.uab.es), SignverOD (Kaggle victordibia/signverod), tech4humans/signature-detection (HF), Ultralytics signature dataset docs; dataset index: iapr-tc4.org/signature-datasets/
- VLM grounding weakness — arXiv:2507.01955 (coordinate regression evaluation); GPT-5 vision eval — latent.space/p/gpt5-vision
- pdf-form-builder (AGPL, reference implementation) — github.com/tstevenson-3000/pdf-form-builder; pdfplumber borderless-region discussion — github.com/jsvine/pdfplumber/discussions/647
- Azure Document Intelligence layout/prebuilt-form schema — learn.microsoft.com (selectionMark state+confidence+polygon output contract)
- Ultralytics CoreML export — docs.ultralytics.com/integrations/coreml; conversion drift issues — ultralytics#13794; coremltools flexible-shapes/ANE docs
- Apryse auto-detect — apryse.com/blog/auto-detect-pdf-form-fields-with-smart-data-extraction; Foxit form recognition — developers.foxit.com
- Apple Vision OCR — developer.apple.com/documentation/vision/recognizing-text-in-images; community benchmarks: gety.ai OCR benchmark, bitfactory.io Vision-vs-MLKit
