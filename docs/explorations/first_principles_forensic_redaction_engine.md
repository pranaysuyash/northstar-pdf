# First-Principles Forensic Permanent Redaction Engine & Multi-Lane Architecture

**Document Status:** Canonical Architectural Specification & Exploration Record  
**Target:** `Sources/PDFEditorCore/ForensicRedactionEngine.swift`, `PDFContentStreamRedactor.swift`, `AppModel.swift`  
**Doctrine Alignment:** `OPERATING_DOCTRINE.md` v8.0 (§1 First Principles, §2 Epistemic Integrity, §4 Preserving Value, §7 Zero Egress Boundary, §8 Capability Routing)  
**Corpus / Project:** `pranaysuyash/northstar-pdf` (`/Users/pranay/Projects/pdf_editor`)  
**Author:** Antigravity Architect & Specialist Redaction Council  

---

## 1. Executive Summary & First-Principles Framing

Permanent redaction is not an annotation, an overlay, or a visual styling hint. **Permanent redaction is the irreversible physical elimination of data from a document file.**

In the current implementation of Northstar PDF, committing redactions previously hit a hard refusal:
```
Cannot commit redactions: the active PDFKit provider does not expose the explicit redaction.permanent capability or an implementation for applyRedaction.
```

This refusal was a symptom of **single-provider anchoring**—treating Apple's high-level `PDFKit` framework as the sole arbiter of PDF capabilities. Because `PDFKit` only provides visual annotation marks (`/Subtype /Redact` or `/Subtype /Square`) without mutating content streams, the system threw a defensive `denyAction` rather than solving the problem from first principles.

This document establishes the architecture for the **First-Principles Forensic Permanent Redaction Engine** (`ForensicRedactionEngine`), a multi-lane, zero-egress, byte-level redaction system that physically destroys text glyphs in content streams, zeroes out raster image pixels, purges AcroForm values and annotations, strips metadata and structural tags, and enforces a mandatory automated forensic verification gate before any redacted document is emitted.

---

## 2. The PDFKit Pseudo-Redaction Trap

### 2.1 The Architectural Defect of Annotation-Based Redaction
High-level PDF frameworks (including Apple's `PDFKit`) implement redactions by creating an entry in the page's `/Annots` array:
```
15 0 obj
<<
  /Type /Annot
  /Subtype /Redact
  /Rect [72 700 200 720]
  /IC [0 0 0]
>>
endobj
```

When Preview or Acrobat displays this, it draws a black rectangle over the coordinates. However:
1. **The `/Contents` stream is completely untouched.** The underlying operators remain in plaintext:
   ```
   BT
   /F1 12 Tf
   72 708 Td
   (Social Security Number: 000-12-3456) Tj
   ET
   ```
2. **Text extraction tools bypass the box completely:** Any call to `pdftotext`, `strings`, `grep`, Python `pypdf`, or `CGPDFPage` text selection extracts `"000-12-3456"`.
3. **Copy-paste extracts the secret:** Selecting all text on the page (`Cmd+A`) and copying (`Cmd+C`) captures the redacted text into the user's clipboard.
4. **Annotation stripping exposes the text:** Any utility or script that strips `/Annots` removes the black box and renders the document in its unredacted state.

Relying on `PDFKit` to perform permanent redaction is an architectural impossibility. Redaction must be performed at the content stream and object dictionary level.

---

## 3. Mathematical & Coordinate Foundations of PDF Redaction

A PDF page is an affine transformation pipeline. Coordinates are mapped across three distinct spaces:
1. **User Space (Default 72 points/inch):** Defined by the page's `/MediaBox` and `/CropBox`. The origin `(0, 0)` is at the bottom-left corner of the page.
2. **Text Matrix Space (`Tm`):** Inside a text block (`BT`...`ET`), glyph positions are determined by:
   $$\begin{bmatrix} x_{\text{user}} & y_{\text{user}} & 1 \end{bmatrix} = \begin{bmatrix} x_{\text{text}} & y_{\text{text}} & 1 \end{bmatrix} \times T_m \times CTM$$
   Where $CTM$ is the Current Transformation Matrix modified by `cm` operators.
3. **Device / Raster Pixel Space:** When raster images (`/XObject /Subtype /Image`) are rendered, their pixels are mapped into user space via the matrix preceding the `Do` operator:
   $$[w_x, 0, 0, h_y, x_0, y_0]\ \text{cm}$$

### 3.1 Bounding Box Intersection Invariant
For a redaction target box $R = [x_{\min}, y_{\min}, x_{\max}, y_{\max}]$ on page $P$:
A text run operator $O$ with projected user-space bounding box $B(O) = [bx_{\min}, by_{\min}, bx_{\max}, by_{\max}]$ intersects $R$ if and only if:
$$\max(x_{\min}, bx_{\min}) < \min(x_{\max}, bx_{\max}) \quad \land \quad \max(y_{\min}, by_{\min}) < \min(y_{\max}, by_{\max})$$

Any operator $O$ satisfying this condition must have its glyphs physically eliminated from the content stream.

---

## 4. Multi-Lane Forensic Redaction Architecture

The `ForensicRedactionEngine` operates through six coordinated lanes:

```
+-----------------------------------------------------------------------------------------+
|                                FORENSIC REDACTION ENGINE                                |
+-----------------------------------------------------------------------------------------+
                                             |
     +---------------------------------------+---------------------------------------+
     |                                       |                                       |
     v                                       v                                       v
+------------------------+      +------------------------+      +------------------------+
|        LANE 1          |      |        LANE 2          |      |        LANE 3          |
| Surgical Content       |      | Physical Vector        |      | Raster Pixel Overwrite |
| Stream Glyph Excision  |      | Burn-In (`re f`)       |      | & Zeroing (Image XObj) |
+------------------------+      +------------------------+      +------------------------+
     |                                       |                                       |
     +---------------------------------------+---------------------------------------+
                                             |
     +---------------------------------------+---------------------------------------+
     |                                       |                                       |
     v                                       v                                       v
+------------------------+      +------------------------+      +------------------------+
|        LANE 4          |      |        LANE 5          |      |        LANE 6          |
| AcroForm & Annotations |      | Metadata, Info &       |      | Automated Forensic     |
| Neutralization         |      | StructTree Purge       |      | Verification Gate      |
+------------------------+      +------------------------+      +------------------------+
```

### Lane 1: Surgical Content Stream Operator Tokenization & Glyph Excision
- Decompresses page `/Contents` streams using native RFC 1950 zlib unfiltering.
- Scans stream tokens for text display operators (`Tj`, `TJ`, `'`, `"`).
- Tokenizes strings and hex glyph arrays (`<...>`).
- Evaluates spatial position against redaction targets.
- Strips matching glyphs, replacing them with empty operators `() Tj` or comments `% [FORENSIC_REDACTED]` to preserve downstream rendering flow without leaking bytes.

### Lane 2: Physical Vector Burn-In Directly in Content Streams
- Rather than attaching an annotation, the engine injects opaque vector black rectangles directly into the tail of the page `/Contents` stream:
  ```
  q
  0 0 0 rg
  0 0 0 RG
  <x> <y> <w> <h> re
  f
  Q
  ```
- This permanently binds the black bar to the page's base graphic representation. It cannot be unselected, deleted as an annotation, or turned off by disabling annotations.

### Lane 3: Raster Bitmap Overwrite & Pixel Zeroing
- For scanned pages or documents with underlying image XObjects (`/Subtype /Image`):
- Merely removing text from the OCR search layer leaves the underlying scanned image intact.
- The engine identifies image XObjects placed under the redaction rectangle.
- Decodes the raw bitmap, computes the intersecting pixel sub-rectangle:
  $$px = \lfloor (x - x_0) \cdot \frac{\text{Width}}{w_x} \rfloor, \quad py = \lfloor (y - y_0) \cdot \frac{\text{Height}}{h_y} \rfloor$$
- Physically overwrites those bytes in memory with `0x00, 0x00, 0x00` (or `0x00` for 8-bit grayscale).
- Re-encodes the image stream via FlateDecode.

### Lane 4: AcroForm & Annotation Neutralization
- Inspects the page's `/Annots` array.
- Completely removes all temporary `/Subtype /Redact` entries.
- If an AcroForm field or widget (`/Tx`, `/Btn`, `/Ch`) intersects the redaction bounds:
  - Erases the field value (`/V ()`) and default value (`/DV ()`).
  - Removes appearance streams (`/AP`).
  - Clears widget references to prevent ghost form values.

### Lane 5: Metadata, Info & Structure Tree Purge
- Invokes `PDFSanitizer`:
  - Strips XMP `/Metadata` streams.
  - Clears `/Info` dictionary entries (`/Title`, `/Author`, `/Subject`, `/Keywords`, `/Producer`).
  - Neutralizes `/StructTreeRoot` (logical structure tags that mirror document text for screen readers).
  - Neutralizes `/OpenAction`, `/AA`, and `/JavaScript`.

### Lane 6: Automated Forensic Postcondition Verification Gate
Before any redacted PDF is returned or saved, it must pass a 4-part forensic verification gate:
1. **Zero Extractable Characters:** `CGPDFDocument` and `PDFTextExtractor` are run over every redacted page. Any character detected within the redaction coordinates causes an immediate gate rejection.
2. **Target Substring Elimination:** The extracted text and raw uncompressed stream bytes are searched for the plain-text sensitive strings that were marked for redaction. If any instance is found, the gate fails.
3. **No Lingering Redaction Annotations:** Verifies that no `/Subtype /Redact` annotations exist in any page dictionary.
4. **Integrity & Parse Check:** The resulting PDF is parsed by `CGPDFDocument` to verify that all xref tables, stream lengths, and object syntax are fully compliant and undamaged.

If any check fails, the engine **fails closed** (`throw ForensicRedactionError.verificationFailed`), guaranteeing that no unsafe or leaky file is ever written to disk.

---

## 5. User-Facing Workflow & Experience

1. **Mark Phase:** User highlights text or selects a region on canvas, or runs PII detection. Operations of kind `.redactMark` are staged (reversible in session).
2. **Review Phase:** User clicks "Commit Redactions" in the Action Island or Inspector.
3. **Forensic Execution Phase:** `ForensicRedactionEngine` performs multi-lane physical byte destruction and runs the forensic verification gate.
4. **Receipt & Save Phase:** The engine generates an `ExportReviewReceipt` with proof metrics (`bytesEliminated`, `operatorsRemoved`, `verifiedZeroExtractableCharacters: true`). The redacted document is staged for safe export (`<filename>_Redacted.pdf`) and the user is presented with the verified receipt.

---

## 6. Verification & Test Plan

| Test ID | Lane | Description | Required Outcome |
|---|---|---|---|
| `FR-T01` | Lane 1 | Redact text operator `Tj` with sensitive string | Sensitive string absent from content stream; replaced by empty op |
| `FR-T02` | Lane 1 | Redact text array operator `TJ` with kerning adjustments | Matching glyph elements excised; stream syntax valid |
| `FR-T03` | Lane 2 | Vector black rectangle burn-in | Page content stream contains `0 0 0 rg ... re f` |
| `FR-T04` | Lane 4 | Redact area containing AcroForm text field | Field `/V` and `/DV` values purged |
| `FR-T05` | Lane 5 | Document metadata & structure tree sanitization | `/Metadata` and `/Info` stripped; `/StructTreeRoot` neutralized |
| `FR-T06` | Lane 6 | Postcondition verification gate pass | Verification passes with 0 characters extractable in redaction box |
| `FR-T07` | Lane 6 | Deliberate mutation failure (S3 sensitivity) | Gate catches injected text leak and aborts emission |

---
*Signed and ratified by the Antigravity Architecture & Redaction Specialist Council.*
