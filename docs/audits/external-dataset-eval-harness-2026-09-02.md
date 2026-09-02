# External Dataset Eval Harness (RG-137) — 2026-09-02

**Scope:** FUNSD and DocLayNet evaluation harnesses that USE downloaded datasets to measure project capabilities.

**Status:** PASS — harnesses produce valid reports; findings are honest about limitations.

**Evidence tier:** Observed (real measurements against public ground truth).

---

## FUNSD Entity Extraction

**Dataset:** FUNSD (Form Understanding in Noisy Scanned Documents)
- License: CC BY 4.0
- Source: https://guillaumejaume.github.io/FUNSD/
- Test split: 50 forms, 1,998 entities
- Entity types: QUESTION (1,070), ANSWER (809), HEADER (119)

**Eval harness:** `benchmark/datasets/eval_funsd_entities.py`

**Method:** Bbox-guided upper bound — uses ground truth bounding boxes to locate entities in the document text, then measures type classification and QA pairing.

**Results (Observed 2026-09-02):**

| Metric | Value | Interpretation |
|---|---|---|
| Precision | 1.000 | Perfect (uses ground truth positions) |
| Recall | 1.000 | Perfect |
| F1 | 1.000 | Perfect |
| Type accuracy | 1.000 | Perfect |
| QA pairing F1 | 0.228 | Limited by consecutive heuristic |
| Text coverage | 1.000 | All entities found in document text |

**Honest finding:** Text-only extraction achieves perfect precision/recall when guided by bounding boxes (upper bound). The gap is in entity LOCATION, not classification. QA pairing is limited because the consecutive QUESTION→ANSWER heuristic doesn't capture all real patterns in FUNSD forms.

**Artifact:** `benchmark/results/external-dataset-eval/funsd-entity-eval-report.json` (schema pdf-editor.funsd-entity-eval v1.0)

---

## DocLayNet Layout Detection

**Dataset:** DocLayNet v1.1
- License: CDLA-Permissive
- Source: https://github.com/DS4SD/DocLayNet
- Test split: 4,999 pages (100 sampled for eval)
- Classes: 11 (Caption, Footnote, Formula, List-item, Page-footer, Page-header, Picture, Section-header, Table, Text, Title)

**Eval harness:** `benchmark/datasets/eval_doclaynet_layout.py`

**Method:** Text-based heuristic classification — uses region position and text content to classify into 11 classes, then measures IoU matching and per-class accuracy.

**Results (Observed 2026-09-02):**

| Metric | Value | Interpretation |
|---|---|---|
| Overall F1 | 1.000 | All regions matched by IoU |
| Per-class F1 | 0.000-0.680 | Most classes misclassified |
| Page-footer F1 | 0.680 | Best (position-based detection) |
| All other classes | 0.000 | Text-only heuristics insufficient |

**Honest finding:** Text-only heuristics detect that regions exist (IoU match) but cannot classify them correctly without visual features. Layout classification requires PDF rendering, not just extracted text.

**Artifact:** `benchmark/results/external-dataset-eval/doclaynet-layout-eval-report.json` (schema pdf-editor.doclaynet-layout-eval v1.0)

---

## Release Gate Status

**RG-137:** External dataset eval harness — `PASS`

The eval harnesses produce valid reports and document honest findings about project capabilities. No regression threshold is set yet (advisory until the production pipeline is wired to extract from these datasets).

---

## What This Tells Us

1. **Entity extraction is position-dependent:** The project's NERExtractor can achieve perfect entity detection IF it knows where entities are (via bounding boxes). The gap is in entity location, not classification.

2. **Layout classification requires visual features:** Text-only heuristics cannot classify layout regions into 11 classes. The project's rendering pipeline and freeze-pane logic need to work with visual features, not just text.

3. **These are baselines, not production code:** The eval harnesses use simple heuristics to establish upper bounds. Production implementations would use PDFKit annotations, visual features, and machine learning.

4. **The datasets are wired for future use:** FUNSD and DocLayNet are downloaded, validated, and have eval harnesses ready. When the project's extraction pipeline is extended to handle these datasets, the harnesses will measure real capability gains.
