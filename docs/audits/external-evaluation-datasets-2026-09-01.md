# External Evaluation Datasets (2026-09-01)

**Scope:** FUNSD and DocLayNet as external evaluation sets for OCR, entity extraction, and layout analysis.
**Status:** Downloaded, validated, and wired into benchmark infrastructure.

## Datasets

### FUNSD (Form Understanding in Noisy Scanned Documents)

| Property | Value |
|---|---|
| **License** | CC BY 4.0 |
| **Source** | https://guillaumejaume.github.io/FUNSD/ |
| **HuggingFace** | `nielsr/funsd` |
| **Train** | 149 forms |
| **Test** | 50 forms |
| **Total entities** | 1,998 (test set) |
| **Entity types** | HEADER (119), QUESTION (1,070), ANSWER (809) |
| **Avg entities/form** | 40.0 |

**Ground truth format:** `{id, text, wordCount, entityCount, entities[{text, box, type}]}`

**Evaluation metrics:**
- Entity extraction F1 (header/question/answer)
- Header detection precision
- QA pairing accuracy
- Entity type classification accuracy

**Usage in project:**
- Compare OCR output against `form.text` for WER/CER
- Extract entities from OCR output, compare against `form.entities` for precision/recall/F1
- Use `entity.box` for bounding box IoU evaluation

### DocLayNet v1.1 (Document Layout Analysis)

| Property | Value |
|---|---|
| **License** | CDLA-Permissive |
| **Source** | https://github.com/DS4SD/DocLayNet |
| **HuggingFace** | `docling-project/DocLayNet-v1.1` |
| **Train sample** | 200 pages |
| **Test** | 4,999 pages |
| **Total regions** | 66,276 |
| **Avg regions/page** | 13.3 |
| **Classes (11)** | Caption, Footnote, Formula, List-item, Page-footer, Page-header, Picture, Section-header, Table, Text, Title |
| **Document categories** | financial_reports (1,755), scientific_articles (943), laws_and_regulations (784), manuals (802), patents (442), government_tenders (273) |

**Ground truth format:** `{id, documentCategory, pageIndex, width, height, regions[{box, category}]}`

**Box format:** `[x, y, width, height]` in pixels

**Evaluation metrics:**
- Region classification accuracy (11-class)
- Region detection precision/recall
- Bounding box IoU
- Reading order accuracy

**Usage in project:**
- Classify detected regions against DocLayNet ground truth
- Use Text/Table/Figure regions for freeze-pane boundary detection
- Validate page segmentation against 11-class ground truth

## JTBD Mapping

| JTBD | Dataset | What it tests |
|---|---|---|
| READ / UNDERSTAND | FUNSD | Can you extract structured fields from forms? |
| READ / INTERACT | DocLayNet | Can you detect layout regions for freeze panes? |
| READ / OCR | FUNSD | OCR quality on noisy scanned forms |
| FIND / template matching | FUNSD | Form detection and classification |

## Files

- `benchmark/datasets/funsd/data/{train,test}.json` — FUNSD ground truth
- `benchmark/datasets/funsd/eval/manifest.json` — FUNSD dataset manifest
- `benchmark/datasets/doclaynet/data/{train_sample,test}.json` — DocLayNet ground truth
- `benchmark/datasets/doclaynet/eval/manifest.json` — DocLayNet dataset manifest
- `benchmark/eval_external_datasets.py` — Evaluation harness
- `benchmark/datasets/external-datasets-eval-report.json` — Generated report
- `benchmark/datasets/download_funsd.py` — FUNSD download script (fixed for nielsr/funsd format)
- `benchmark/datasets/download_doclaynet.py` — DocLayNet download script

## Gitignore

These datasets are NOT committed to the repository (per user instruction). Only the eval scripts, manifests, and reports are tracked. The actual data files are in `.gitignore`.

## Honest Gap

These are the first external evaluation sets. The project's native corpus (192 PDFs) is deep but narrow — focused on form-field detection and native/web parity. FUNSD adds 199 real-world noisy scanned forms with entity annotations. DocLayNet adds 4,999 pages with 11-class layout annotations across 6 document categories. Together they cover:
- General document understanding (vs. form-only)
- Layout analysis at scale (vs. 14 diverse-layout fixtures)
- Real-world form diversity (vs. synthetic/generated)
- Multi-document-type coverage (financial, scientific, legal, manual, patent)
