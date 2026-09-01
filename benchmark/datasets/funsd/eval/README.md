# FUNSD External Evaluation Set

**Dataset:** FUNSD (Form Understanding in Noisy Scanned Documents)
**License:** CC BY 4.0
**Source:** https://guillaumejaume.github.io/FUNSD/
**HuggingFace:** `nielsr/funsd`
**Downloaded:** 2026-09-01

## Splits
- **test**: 50 documents
- **train**: 149 documents

## Ground Truth Format
Each document: `{id, text, entities[{text, box, type}], entityCount}`
Entity types: `header`, `question`, `answer`
