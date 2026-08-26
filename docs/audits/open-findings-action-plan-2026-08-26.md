# Open Findings — Action Plan

**Status:** All open findings that can be implemented/explored
**Created:** 2026-08-26
**Scope:** Implementable + explorable (excludes GitHub/CI work)
**Doctrine alignment:** Every item linked to OPERATING_DOCTRINE section

## 1. Implementable Findings (Can code now)

### 1.1 Cross-Project Patterns to Adopt

| # | Finding | Source | Doctrine | Effort |
|---|---|---|---|---|
| F-001 | Adopt library cascade pattern | invoice-intelligence | §1 (outcomes), §3 (proportional rigor) | 2 hours |
| F-002 | Add provenance tracking to DocumentInspection | metaextract | §2 (truth taxonomy), §5 (evidence) | 1 hour |
| F-003 | Add shadow mode for extraction | metaextract | §3 (proportional rigor), §7 (verification) | 2 hours |
| F-004 | Add hybrid routing for OCR | invoice-intelligence | §1 (outcomes), §8 (capability routing) | 1 hour |

### 1.2 PDFKit Limitations to Document

| # | Finding | Source | Doctrine | Effort |
|---|---|---|---|---|
| F-005 | Document PDFKit radio button bug (FB22167174) | Apple Developer Forums | §2 (truth taxonomy), §5 (evidence) | 30 min |
| F-006 | Document PDFKit tile crash (thread 837282) | Apple Developer Forums | §2 (truth taxonomy), §5 (evidence) | 30 min |
| F-007 | Add PDFKit fallback for rendering | PDFKit limitations | §6 (failure behavior), §10 (parallel work) | 1 hour |

### 1.3 Validation Pipeline Improvements

| # | Finding | Source | Doctrine | Effort |
|---|---|---|---|---|
| F-008 | Add QPDF to validation pipeline | permissive evaluation | §3 (proportional rigor), §5 (evidence) | 1 hour |
| F-009 | Add pdf_oxide for text extraction | permissive evaluation | §1 (outcomes), §8 (capability routing) | 1 hour |
| F-010 | Add pdfcpu for batch operations | permissive evaluation | §1 (outcomes), §8 (capability routing) | 1 hour |

### 1.4 Feature Improvements

| # | Finding | Source | Doctrine | Effort |
|---|---|---|---|---|
| F-011 | Improve text extraction with cascade | cross-project | §1 (outcomes), §3 (proportional rigor) | 2 hours |
| F-012 | Add OCR confidence scoring | OCR feature | §2 (truth taxonomy), §5 (evidence) | 1 hour |
| F-013 | Add form field validation | form features | §3 (proportional rigor), §7 (verification) | 2 hours |

## 2. Explorable Findings (Can prototype)

### 2.1 New Capabilities

| # | Finding | Source | Doctrine | Effort |
|---|---|---|---|---|
| E-001 | Explore PDFium for rendering | permissive evaluation | §8 (capability routing), §9 (evolution) | 4 hours |
| E-002 | Explore pdf_oxide for text extraction | permissive evaluation | §8 (capability routing), §9 (evolution) | 2 hours |
| E-003 | Explore QPDF for structural validation | permissive evaluation | §8 (capability routing), §9 (evolution) | 2 hours |
| E-004 | Explore pdfcpu for batch operations | permissive evaluation | §8 (capability routing), §9 (evolution) | 2 hours |

### 2.2 Architecture Patterns

| # | Finding | Source | Doctrine | Effort |
|---|---|---|---|---|
| E-005 | Prototype library cascade architecture | cross-project | §4 (architecture), §9 (evolution) | 4 hours |
| E-006 | Prototype provenance tracking system | cross-project | §2 (truth taxonomy), §5 (evidence) | 2 hours |
| E-007 | Prototype shadow mode validation | cross-project | §3 (proportional rigor), §7 (verification) | 2 hours |
| E-008 | Prototype hybrid routing engine | cross-project | §8 (capability routing), §9 (evolution) | 2 hours |

### 2.3 Testing Improvements

| # | Finding | Source | Doctrine | Effort |
|---|---|---|---|---|
| E-009 | Add multi-library validation tests | permissive evaluation | §5 (evidence), §7 (verification) | 2 hours |
| E-010 | Add provenance validation tests | cross-project | §2 (truth taxonomy), §5 (evidence) | 1 hour |
| E-011 | Add shadow mode comparison tests | cross-project | §3 (proportional rigor), §7 (verification) | 1 hour |

## 3. Prioritized Execution Order

### Phase 1: Quick Wins (1-2 hours each)

1. **F-005**: Document PDFKit radio button bug
2. **F-006**: Document PDFKit tile crash
3. **F-002**: Add provenance tracking to DocumentInspection
4. **F-004**: Add hybrid routing for OCR

### Phase 2: Core Improvements (2-4 hours each)

5. **F-001**: Adopt library cascade pattern
6. **F-003**: Add shadow mode for extraction
7. **F-008**: Add QPDF to validation pipeline
8. **F-009**: Add pdf_oxide for text extraction

### Phase 3: Exploration (4+ hours each)

9. **E-001**: Explore PDFium for rendering
10. **E-005**: Prototype library cascade architecture
11. **E-006**: Prototype provenance tracking system
12. **E-007**: Prototype shadow mode validation

## 4. Doctrine Alignment

| Finding | Doctrine Section | Alignment |
|---|---|---|
| Library cascade | §1 (outcomes) | Multiple fallbacks improve reliability |
| Provenance tracking | §2 (truth taxonomy) | Records which module produced what |
| Shadow mode | §3 (proportional rigor) | Parallel validation with diff |
| Hybrid routing | §8 (capability routing) | Routes to best capability |
| PDFKit documentation | §5 (evidence) | Records known limitations |
| QPDF validation | §7 (verification) | Independent structural validation |
| pdf_oxide extraction | §1 (outcomes) | Fastest text extraction |
| PDFium rendering | §8 (capability routing) | Best rendering performance |

## 5. Evidence

- `docs/audits/cross-project-pdf-text-work-2026-08-26.md` — 5 transferable patterns
- `docs/audits/pdf-libraries-permissive-evaluation-2026-08-26.md` — 28 permissive libraries
- `docs/audits/pdfkit-adequacy-audit-2026-08-26.md` — PDFKit limitations
- `docs/audits/pdf-features-library-matrix-2026-08-26.md` — 42 features evaluated
