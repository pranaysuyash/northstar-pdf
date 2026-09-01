# DocLayNet External Evaluation Set

**Dataset:** DocLayNet v1.1
**License:** CDLA-Permissive
**Source:** https://github.com/DS4SD/DocLayNet
**HuggingFace:** `docling-project/DocLayNet-v1.1`

## Description

80,863 pages from diverse document sources with human-annotated layout segmentation.
11 classes: Caption, Footnote, Formula, List-item, Page-footer, Page-header, Picture, Section-header, Table, Text, Title.

## Splits

- **test**: 4999 pages (full test split from v1.1)
- **train_sample**: 200 pages (first train shard, for calibration)

## Ground Truth Format

Each page: `{id, documentName, pageIndex, width, height, regionCount, regionsByType, classDistribution}`
