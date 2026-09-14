# Form 6 Benchmark

**Status:** Reviewed semantic benchmark fixture with an initial detector baseline
**Reviewed:** 2026-08-24
**Input:** `/Users/pranay/Desktop/RAr0Lq2Avu.pdf`
**SHA-256:** `2cf1421343c22676f15eff0ec6f31a4df6e7f7975dc0f3d88d2b29a1dcc79d34`
**Reference:** <https://voters.eci.gov.in/formspdf/Form_6_English.pdf>

## Purpose

This fixture is the first precision-oriented benchmark for detecting and filling
blank regions without changing surrounding document content. It is a difficult
static-form case, not a native PDF form.

## Structural Fingerprint

| Property | Observed value | Evidence |
|---|---|---|
| Pages | 2 | `pdfinfo` and parsed pages |
| Page size | 612 x 841.68 points on both pages | `pdfinfo` |
| PDF version | 1.5 | `pdfinfo` |
| Form inventory | none | `pdfinfo`: `Form: none` |
| JavaScript | none | `pdfinfo`: `JavaScript: no` |
| Encryption | none | `pdfinfo`: `Encrypted: no` |
| Tagged | yes | `pdfinfo` |
| Creator | Microsoft Word 2016 | `pdfinfo` |
| Producer | www.ilovepdf.com | `pdfinfo` |
| Embedded raster images | 1 JPEG, 162 x 155 pixels | `pdfimages -list` |
| Text extraction | successful; text and font information present | `pdftotext`, `pdffonts` |
| Source size | 794,730 bytes | `pdfinfo`, filesystem metadata |

The logo is the only embedded raster image reported. The visible entry regions,
rules, grids, checkboxes, and table borders are therefore primarily vector/text
geometry and must not be mistaken for AcroForm widgets.

## Ground-Truth Logical Targets

These are semantic target groups, not a final count of every individual box or
line segment. A detector may produce smaller atomic candidates, but evaluation
must map them back to these stable groups.

| ID | Page | Target | Visual primitive | Expected operation | Risk |
|---|---:|---|---|---|---|
| F6-01 | 1 | Office form number | underline | text entry | office-only field |
| F6-02 | 1 | Assembly constituency number/name | small boxes and underline | text entry | two distinct labels |
| F6-03 | 1 | Parliamentary constituency number/name | small boxes and underline | text entry | conditional section |
| F6-04 | 1 | Photograph | bordered rectangle | image placement | not a text field |
| F6-05 | 1 | Name in official language, first/middle name | repeated cell grid | text entry | script and cell fitting |
| F6-06 | 1 | Name in official language, surname | repeated cell grid | text entry | optional value |
| F6-07 | 1 | Name in English, first/middle name | repeated cell grid | text entry | block letters and fitting |
| F6-08 | 1 | Name in English, surname | repeated cell grid | text entry | optional value |
| F6-09 | 1 | Relative type | five checkbox-like squares | one-of-many selection | semantic grouping |
| F6-10 | 1 | Relative name in official language | repeated cell grid | text entry | depends on F6-09 |
| F6-11 | 1 | Relative name in English | repeated cell grid | text entry | block letters |
| F6-12 | 1 | Mobile number | two-row digit grid | text entry | self or relative meaning |
| F6-13 | 1 | Email ID | underline | text entry | long-value fit |
| F6-14 | 1 | Aadhaar choice and number | checkbox-like square and digit grid | conditional entry | sensitive identifier |
| F6-15 | 1 | Gender | three checkbox-like squares | one-of-many selection | semantic grouping |
| F6-16 | 1 | Date of birth | segmented date boxes | date entry | strict format |
| F6-17 | 1 | Date-of-birth proof choice | six checkbox-like squares | one-of-many selection | legal/supporting evidence |
| F6-18 | 1 | Other date-of-birth document | underline | conditional text entry | conditional section |
| F6-19 | 1 | Present residence address | eight table cells | text entry | multi-cell layout |
| F6-20 | 2 | Residence proof choice | seven checkbox-like squares | one-of-many selection | legal/supporting evidence |
| F6-21 | 2 | Other residence document | underline | conditional text entry | conditional section |
| F6-22 | 2 | Disability category | three checkbox-like squares | multi/one-of-many selection | optional field |
| F6-23 | 2 | Other disability description | underline | text entry | optional field |
| F6-24 | 2 | Disability percentage and certificate | small entry plus two choices | text and selection | numeric constraint |
| F6-25 | 2 | Existing family member | three underlined values | text entry | relationship semantics |
| F6-26 | 2 | Declaration place of birth | three underlined values | text entry | legal declaration |
| F6-27 | 2 | Residence since | underline | month/year entry | legal declaration |
| F6-28 | 2 | Enclosed age-proof document | underline | text entry | legal declaration |
| F6-29 | 2 | Declaration date and place | underlines | text entry | legal declaration |
| F6-30 | 2 | Applicant signature/thumb impression | large open region | ink/image/signature | signature semantics |
| F6-31 | 2 | Acknowledgement number/date | lines | text entry | office-only section |
| F6-32 | 2 | Received applicant name | line | text entry | office-only section |
| F6-33 | 2 | ERO/AERO/BLO signature | open region | ink/image/signature | office-only section |

## Non-Targets

The following must not be suggested as fillable regions by default:

- Form labels, instructions, disclaimers, notes, declaration prose, and legal text.
- Page borders, table borders, grid separators, and underline strokes as standalone
  text targets.
- The Election Commission logo and the photograph instruction text.
- Accessibility instructions and the acknowledgement scissors marks.

## Required Detector Behavior

1. Native-form inventory must return zero fields for this fixture.
2. Static candidates may be proposed only with page coordinates, evidence, and a
   confidence score explicitly labeled as a detection score.
3. Candidate grouping must preserve label relationships and conditional logic.
4. No candidate may be auto-applied solely because it resembles a box or line.
5. Checkboxes, signatures, photograph placement, and legal-declaration fields must
   remain review-required even if geometry confidence is high.
6. The user must be able to correct, resize, reject, or manually add every target.
7. The export path must preserve the original bytes and produce a reopenable copy.

## Future Evaluation Record

The first browser measurement is recorded by
[`Tests/fixtures/static_region_reviewed_corpus.mjs`](../Tests/fixtures/static_region_reviewed_corpus.mjs)
and [`Tests/static_region_reviewed_benchmark_browser_test.mjs`](../Tests/static_region_reviewed_benchmark_browser_test.mjs).
It matched 7 of 33 reviewed semantic targets, producing a label-associated recall
proxy of 21.21% and a labeled-candidate precision proxy of 11.96%, with 3
abstentions and 97 candidates. This is a baseline for detector work, not a
geometric IoU result or a production accuracy claim.

The benchmark harness should record, per candidate run:

- field-group precision, recall, and F1;
- false-positive rate on non-target text and decorative geometry;
- label-to-region association accuracy;
- checkbox grouping and conditional-rule accuracy;
- value fit and overflow outcomes for short, long, Unicode, and numeric values;
- output reopen success and expected-operation verification;
- raster-diff and content-extraction results outside edited regions;
- latency, memory, warnings, and abstentions.

The fixture now has a bounded reviewed editor run covering grouped character
regions, static choice marking, native-field synthesis, export, and reopen
validation. OCR/CV fallback evidence is covered separately by the native reader
gate. General detector quality remains an open research and measurement problem.

### September 2026 Native Engine Evaluation Record

- **Engine Core Updates**:
  - `PDFVectorStreamParser.swift`: Registered `"h"` closepath callback; reconstructed orthogonal 4-point/5-point closed paths into candidate bounding boxes.
  - `StaticRegionDetector.swift`: Added right-side label association for checkbox rows (`[ ] Yes`), bottom-label association for signature/underline lines, expanded voter-domain dictionary, and added photo-frame density exception.
- **Observed Native Output**:
  - Live native preview app (`PDFEditor`) identified 55+ interactive candidates directly from the source vector stream and text runs without AcroForm widgets.
  - Form 6 evaluation visual evidence captured in `docs/audits/screenshots/screen48_form6_absolute_path.png` and logged as Screen 33 in `docs/audits/screen_improvement_log.md`.

## Documented Gaps for Subsequent Detection Iterations

Visual inspection of the rendered document canvas and the sidebar suggestions on `form6-voter-application.pdf` confirms that candidate detection is currently broken in multiple critical ways:

### 1. The 4 Severe Failures Visible on the Canvas

1. **Table Rules Slicing Through Printed Text (False Positives)**:
   - In **Section 7(b)** (*Document for Proof of Date of Birth*), orange dashed boxes slice horizontally directly through printed text (*"Birth certificate issued by Competent Local Body..."*, *"PAN Card"*, *"Indian Passport"*).
   - **Why**: The detector classifies every horizontal vector line in the table as a `potentialUnderline`, assumes it is a blank fill line, and draws a 26pt entry band directly on top of the printed table rows without checking for existing text.

2. **Static Headers & Declaration Sentences Treated as Form Fields**:
   - The entire legal declaration sentence *"I submit application for inclusion of my name in the electoral roll for the above constituency"* is enclosed in an orange box as if it were an input field.
   - Column headers like *"First Name followed by Middle Name"* and *"Surname (if any)"* have candidate boxes drawn over the label text itself rather than the blank writing area.
   - In the right sidebar under **Suggestions (72)**, the user is repeatedly prompted to "fill" static text:
     - `I submit application for inclusion of my name in t...` (listed twice)
     - `First Name followed by Middle Name` (listed 3+ times)

3. **Character Grids are Severely Fragmented or Completely Missed (False Negatives)**:
   - **Row 1(a) (Official Language)**: Only 5 isolated cells in the middle are highlighted in yellow; the other 10 cells in the row are completely missed.
   - **Row 1(b) (English BLOCK LETTERS)**: The entire 15-cell grid is **completely blank** — zero detection.
   - **Date of Birth (`[d][d] / [m][m] / [y][y][y][y]`)**: The slash-separated date cells have zero detection.
   - **Mobile Number & Aadhaar Grids**: Treated as a single wide dashed rectangle cutting through the internal grid separators.

4. **Square Checkboxes are Missed & Misaligned**:
   - The checkboxes for relatives (*Father, Mother, Husband, Wife*) and gender (*Male, Female*) are completely unhighlighted.
   - For *Third Gender*, instead of detecting the square checkbox `[ ]` to the left, an orange box is drawn directly over the text `"Third Gender"`.

---

### 2. First-Principles Technical Root Cause

1. **Stroked Grid Matrix vs. Closed Rectangles**:
   - In this government PDF (generated from Microsoft Word), the character entry boxes are **not** individual rectangle operators (`re` or `m l l l h`). They are drawn as a **ruled grid table** with continuous horizontal and vertical path strokes (`m ... l ... S`).
   - Because `PDFVectorStreamParser.swift` only detects isolated rectangles or standalone closed paths, it fails to reconstruct the cells formed by intersecting grid strokes.
2. **Table Border Rule Confusion in `StaticRegionDetector.swift`**:
   - Any horizontal vector line with text above it is currently treated as an "underline for a form field". In a dense form with boxed tables, this heuristic generates false positives over every table row border.
3. **Failure to Suppress Explicit Non-Targets**:
   - Section 88 of `docs/form6-benchmark.md` defines the non-target contract:
     > *"The following must not be suggested as fillable regions by default: Form labels, instructions, disclaimers, declaration prose, page borders, table borders, grid separators."*
   - Currently, `StaticRegionDetector` does not filter out text runs with high character counts (>40 chars) or table borders, allowing full sentences to enter the suggestion queue.

---

### 3. What Needs to Be Done to Fix It Properly

1. **Table & Rule Suppression**: Detect when a horizontal vector line is part of a table border or has printed text sitting directly on it (text bounding box intersecting the line), and suppress it from `potentialUnderlines`.
2. **Grid Cell Reconstruction from Stroke Intersections**: Reconstruct cell rectangles from orthogonal intersecting stroke grids (`horizontalLines` $\cap$ `verticalLines`), uniting them into a single `.characterGrid` band instead of random scattered cells.
3. **Non-Target Prose Rejection**: Reject any candidate whose associated text is a disclaimer, instructional paragraph, or sentence exceeding 40 characters without explicit blank markers.
4. **Checkbox Spatial Anchor**: Anchor standalone checkboxes to the square box geometry (`box.width == box.height`), binding the label to the right (`[ ] Label`) without drawing the candidate box over the label text.



