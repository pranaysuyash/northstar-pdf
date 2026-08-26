# Vendored Persona Definitions

**Source repository:** `/Users/pranay/Desktop/personas_23rdaug26/`
**Purpose:** These persona definitions are referenced by durable audit artifacts in this project.
Vendoring them preserves provenance and satisfies the OPERATING_DOCTRINE §5 canonical-path rule.

## In use

| File | Persona | Source path (relative to repository root) | SHA-256 of source .docx | Used by |
|---|---|---|---|---|
| `PER-0428 - Feedback Doctrine Alignment Reviewer.docx` | PER-0428 — Feedback Doctrine Alignment Reviewer | `01 Expanded Personas/05 Feedback, Critique & Review/PER-0428 - Feedback Doctrine Alignment Reviewer.docx` | `5a424b919e0a8afa0ca20d5c7468bb7652a704b1ae65fadd3a2f593da6297e31` | [`docs/audits/doctrine-alignment-audit-per-0428-2026-08-26.md`](../audits/doctrine-alignment-audit-per-0428-2026-08-26.md) |
| `PER-0164 - Assumption Auditor.docx` | PER-0164 — Assumption Auditor | `01 Expanded Personas/05 Feedback, Critique & Review/PER-0164 - Assumption Auditor.docx` | `3e399f2fad2d338209b42acbef32306334ee99aef313af831e6cd122dd767cc9` | [`docs/audits/doctrine-alignment-audit-per-0428-2026-08-26.md`](../audits/doctrine-alignment-audit-per-0428-2026-08-26.md) |
| `PER-0930 - Shadow-System Investigator.docx` | PER-0930 — Shadow-System Investigator | `01 Expanded Personas/14 Meta-Reasoning & Decision Systems/PER-0930 - Shadow-System Investigator.docx` | `f0a0908320a4e5fca9b2bb6d7bd33ac2400cf4d20ed23c5b153aa46a429248a6` | [`docs/audits/doctrine-alignment-audit-per-0428-2026-08-26.md`](../audits/doctrine-alignment-audit-per-0428-2026-08-26.md) |

| `PER-0926 - Product Evolution Architect.docx` | PER-0926 — Product Evolution Architect | `01 Expanded Personas/14 Meta-Reasoning & Decision Systems/PER-0926 - Product Evolution Architect.docx` | `86180e3f95e0c00b56fbed71d66a06645005cf89299f3fc4a110a78d3a825007` | [`docs/audits/product-evolution-map-per-0926-2026-08-26.md`](../audits/product-evolution-map-per-0926-2026-08-26.md) |

## Policy

- `.docx` files are the canonical binary artifacts; `.txt` copies are for repo readability.
- When an audit or persona adoption references these files, verify the source SHA-256 still matches before claiming provenance.
- New persona adoptions must add their entry to this index before the first durable audit record cites them.
