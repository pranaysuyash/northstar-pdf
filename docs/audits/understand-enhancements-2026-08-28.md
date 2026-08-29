# UNDERSTAND Layer Enhancements

**Date:** 2026-08-28
**Status:** Observed + Verified
**Evidence tier:** Tier 2 (targeted tests — components build and pass)
**Test sensitivity:** S1 (tests pass), S2 (algorithm choices verified against known inputs)

## 1. Decision context

The UNDERSTAND layer was described as "⚠️ Early — Entire comprehension layer." The gap analysis identified it as the #1 priority across all JTBDs — every job benefits from understanding document content.

**Question:** What is the minimum viable UNDERSTAND layer that provides value without requiring AI/LLM infrastructure?

## 2. Architecture

### DocumentSummarizer
- Rule-based extraction: title detection, paragraph counting, keyword frequency
- Summary sections: title, key paragraphs, statistics
- No LLM dependency — works offline, privacy-preserving

### EntityRecognizer (NERExtractor)
- Pattern-based entity detection: dates, emails, phone numbers, monetary amounts, URLs
- Regex-based, not ML-based — deterministic, fast, privacy-preserving
- Entities returned with position, confidence, and type

### TableExtractor
- Detects table regions from text block layout analysis
- Groups text blocks by row/column proximity
- Returns structured `[[String]]` cells
- Existing `DetectedTable` type reused

### KeyPointExtractor
- Identifies key points from document structure:
  - Headings and subheadings (font size detection)
  - Lists (bullet/number detection)
  - Bold/emphasized text
  - Short paragraphs (likely key statements)

## 3. Key design decisions

**No LLM dependency.** The UNDERSTAND layer uses rule-based extraction, not AI summarization. This is intentional:
- Works offline (privacy doctrine)
- Deterministic (testability)
- Fast (no API calls)
- Can be enhanced with LLM later without changing the interface

**Algorithm choices need justification (§3 Proportional rigor):**
- Regex for entity detection: sufficient for common patterns, fast, deterministic
- Layout analysis for tables: groups text blocks by proximity, not ML classification
- Font size for headings: PDFKit provides font info, no OCR needed

## 4. Evidence

- Components build cleanly
- Integration with inspector panel verified
- Full suite: 1199/1199 pass

## 5. Doctrine alignment

- §2 Truth taxonomy: algorithm choices labeled as "rule-based" not "AI-powered"
- §3 Proportional rigor: regex sufficient for entity detection, no ML needed yet
- §5 Evidence-based: each component has defined inputs/outputs
- §12 Privacy stays value-free: all extraction is local, no network calls

## 6. Alternatives not taken

- **LLM-based summarization:** Requires API, network, privacy boundary. Deferred to companion architecture.
- **ML-based NER:** Overkill for common patterns. Regex is sufficient for v1.
- **OCR-based table detection:** Existing text extraction provides table regions without OCR.

## 7. Open questions

- When should LLM summarization be added? (Requires companion architecture)
- Should table extraction handle merged cells?
- Entity confidence thresholds — are current regex patterns sufficient?
