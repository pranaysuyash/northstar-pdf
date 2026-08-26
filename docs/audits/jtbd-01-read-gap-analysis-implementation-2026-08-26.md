# JTBD-01 READ — Gap Analysis & Implementation Roadmap

**Date:** 2026-08-26
**Source:** Expanded 22-Dimension Analysis
**Status:** First-principles, long-term, doctrine-aligned implementation plan

---

## Purpose

This document maps the gaps identified in the 22-dimension analysis to specific, implementable features. Each feature is prioritized by impact, effort, and doctrine alignment.

---

## 1. Gap Summary by Dimension

### 1.1 CRITICAL Gaps (Must Fix)

| Gap | Dimensions | Impact | Evidence |
|---|---|---|---|
| No cross-platform support | WHERE (4.2) | CRITICAL | macOS only |
| No accessibility compliance | WHOM (9.2), WHERE (4.4) | CRITICAL | Partial VoiceOver |
| No privacy audit trail | WHOSE (8.1), HOW MUCH (10.1) | CRITICAL | No audit logging |
| No offline-first optimization | WHERE (4.5), WHEN (3.4) | CRITICAL | No caching strategy |

### 1.2 HIGH Gaps (Should Fix)

| Gap | Dimensions | Impact | Evidence |
|---|---|---|---|
| No AI summarization | WHAT (2.4), WHICH (7.3) | HIGH | No AI integration |
| No reading progress tracking | WHEN (3.3), HOW LONG (13.2) | HIGH | Session-only state |
| No dark mode | WHERE (4.4), HOW MUCH (10.1) | HIGH | No theme support |
| No side-by-side comparison | WHICH (7.3), WHAT ELSE (16.1) | HIGH | No multi-document |
| No batch processing | HOW MANY (11.2), WHAT ELSE (16.1) | HIGH | Single document only |

### 1.3 MEDIUM Gaps (Could Fix)

| Gap | Dimensions | Impact | Evidence |
|---|---|---|---|
| No reading modes | HOW (6.1), WHO (1.1) | MEDIUM | One-size-fits-all |
| No citation tools | WHAT (2.5), HOW (6.5) | MEDIUM | No citation support |
| No metadata view | HOW FAR (14.2), WHOSE (8.1) | MEDIUM | Basic metadata only |
| No collaboration features | WHOM (9.1), WHAT ELSE (16.1) | MEDIUM | No sharing |

### 1.4 LOW Gaps (Nice to Have)

| Gap | Dimensions | Impact | Evidence |
|---|---|---|---|
| No automation/scripting | HOW (6.4), WHAT ELSE (16.1) | LOW | No CLI |
| No advanced annotations | WHAT (2.5), HOW (6.5) | LOW | Basic only |
| No analytics | HOW OFTEN (12.1), WHAT NEXT (22.3) | LOW | No tracking |

---

## 2. Implementation Roadmap

### 2.1 Phase 1: Foundation (Weeks 1-4)

**Goal:** Fix critical gaps, establish long-term architecture

| Feature | Gap Addressed | Effort | Priority | Doctrine Alignment |
|---|---|---|---|---|
| **Offline-first caching** | WHERE (4.5) | Medium | CRITICAL | §3: Do things smartly |
| **Reading progress persistence** | WHEN (3.3), HOW LONG (13.2) | Small | HIGH | §5: Evidence-based |
| **Dark mode** | WHERE (4.4) | Small | HIGH | §8: Capability routing |
| **Privacy audit logging** | WHOSE (8.1) | Medium | CRITICAL | §5: Evidence-based |

**Deliverables:**
- Cache manager with LRU eviction
- Progress persistence (position, zoom, annotations)
- Theme system (light/dark/high-contrast)
- Audit log with privacy-preserving metadata

### 2.2 Phase 2: Intelligence (Weeks 5-8)

**Goal:** Add AI-powered understanding, improve comprehension

| Feature | Gap Addressed | Effort | Priority | Doctrine Alignment |
|---|---|---|---|---|
| **AI summarization** | WHAT (2.4), WHICH (7.3) | Large | HIGH | §8: Capability routing |
| **Text extraction improvement** | HOW (6.3), WHAT (2.1) | Medium | HIGH | §3: Do things smartly |
| **Search enhancement** | HOW (6.1), WHEN (3.2) | Medium | HIGH | §5: Evidence-based |
| **Reading modes** | HOW (6.1), WHO (1.1) | Medium | MEDIUM | §8: Capability routing |

**Deliverables:**
- Local AI model integration (summarization, extraction)
- Improved text extraction (layout-aware, table detection)
- Enhanced search (fuzzy, semantic, highlight)
- Reading modes (Study, Skim, Reference, Review)

### 2.3 Phase 3: Platform (Weeks 9-12)

**Goal:** Cross-platform support, accessibility compliance

| Feature | Gap Addressed | Effort | Priority | Doctrine Alignment |
|---|---|---|---|---|
| **iOS/iPadOS app** | WHERE (4.2) | Very large | CRITICAL | §8: Capability routing |
| **WCAG 2.1 compliance** | WHERE (4.4), WHOM (9.2) | Large | CRITICAL | §5: Evidence-based |
| **Side-by-side comparison** | WHICH (7.3), WHAT ELSE (16.1) | Medium | HIGH | §3: Do things smartly |
| **Batch processing** | HOW MANY (11.2) | Medium | HIGH | §8: Capability routing |

**Deliverables:**
- Native iOS/iPadOS app with touch optimization
- Full WCAG 2.1 AA compliance
- Multi-document comparison view
- Batch operations (open, process, export)

### 2.4 Phase 4: Advanced (Weeks 13-16)

**Goal:** Advanced features, enterprise capabilities

| Feature | Gap Addressed | Effort | Priority | Doctrine Alignment |
|---|---|---|---|---|
| **Collaboration features** | WHOM (9.1) | Large | MEDIUM | §8: Capability routing |
| **Advanced annotations** | WHAT (2.5) | Medium | MEDIUM | §5: Evidence-based |
| **Automation/scripting** | HOW (6.4) | Medium | LOW | §3: Do things smartly |
| **Analytics dashboard** | HOW OFTEN (12.1) | Medium | LOW | §5: Evidence-based |

**Deliverables:**
- Shared annotations and comments
- Rich annotation system (highlights, notes, drawings)
- CLI and scripting interface
- Reading analytics and insights

---

## 3. Feature Specifications

### 3.1 Offline-First Caching

**Problem:** Users lose access when network is unavailable.

**Solution:** intelligent caching with LRU eviction.

**Architecture:**
```
CacheManager
├── DocumentCache (LRU, 100 documents max)
├── MetadataCache (all opened documents)
├── AnnotationCache (user annotations)
└── SearchCache (recent searches)
```

**First-principles design:**
- Cache what users need most (recent documents)
- Evict what users need least (old, large documents)
- Persist across sessions (survive app restart)
- Respect privacy (no cloud sync without consent)

### 3.2 Reading Progress Persistence

**Problem:** Users lose their place when closing documents.

**Solution:** Persistent progress tracking.

**Architecture:**
```
ProgressTracker
├── PositionCache (scroll position per document)
├── ZoomCache (zoom level per document)
├── ReadingHistory (documents opened, time spent)
└── BookmarkManager (user bookmarks)
```

**First-principles design:**
- Remember position, not just page
- Track reading time for analytics
- Support bookmarks and highlights
- Sync across devices (optional, privacy-preserving)

### 3.3 Dark Mode

**Problem:** Eye strain in low-light environments.

**Solution:** Theme system with dark/light/high-contrast modes.

**Architecture:**
```
ThemeManager
├── LightTheme (default)
├── DarkTheme (low-light)
├── HighContrastTheme (accessibility)
└── CustomTheme (user-defined)
```

**First-principles design:**
- Follow system theme by default
- Allow manual override
- Persist user preference
- Ensure accessibility in all themes

### 3.4 AI Summarization

**Problem:** Users spend time reading irrelevant content.

**Solution:** Local AI model for summarization and extraction.

**Architecture:**
```
AISummarizer
├── LocalModel (on-device inference)
├── ExtractionEngine (key points, entities)
├── ComparisonEngine (document differences)
└── PrivacyGuard (no data leaves device)
```

**First-principles design:**
- Run locally for privacy
- Provide confidence scores
- Allow user correction
- Learn from feedback

---

## 4. Evidence Requirements

### 4.1 For Each Feature

| Evidence Type | What we need | How to get it |
|---|---|---|
| Unit tests | Code correctness | Write tests |
| Integration tests | System behavior | Test workflows |
| Performance benchmarks | Speed, memory | Run benchmarks |
| User testing | Usability | Schedule sessions |
| Accessibility audit | WCAG compliance | Hire auditor |
| Security audit | Privacy, safety | External review |

### 4.2 For the Roadmap

| Evidence | What it proves | How to get it |
|---|---|---|
| Phase 1 completion | Foundation works | All tests pass |
| Phase 2 completion | AI works locally | Summaries accurate |
| Phase 3 completion | Cross-platform works | iOS app functional |
| Phase 4 completion | Advanced features work | Users can collaborate |

---

## 5. Doctrine Alignment Check

### 5.1 Operating Doctrine §3: Do Things Smartly

| Feature | How it aligns |
|---|---|
| Offline-first caching | Smart resource management |
| Reading modes | Adapt to user context |
| AI summarization | Intelligent content processing |
| Batch processing | Efficient operations |

### 5.2 Operating Doctrine §5: Evidence-Based

| Feature | Evidence required |
|---|---|
| All features | Unit tests, integration tests |
| Performance | Benchmarks, profiling |
| Accessibility | WCAG audit |
| Security | Privacy audit |

### 5.3 Operating Doctrine §8: Capability Routing

| Feature | How it routes |
|---|---|
| Reading modes | Different modes for different contexts |
| AI summarization | Optional capability, opt-in |
| Cross-platform | Platform-specific implementations |
| Collaboration | Optional, privacy-preserving |

---

## 6. Risk Assessment

### 6.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| AI model too large | MEDIUM | HIGH | Use smaller models, quantization |
| iOS app performance | MEDIUM | HIGH | Optimize early, test often |
| Accessibility regressions | MEDIUM | MEDIUM | Automated testing |
| Performance degradation | LOW | HIGH | Benchmark continuously |

### 6.2 Product Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Feature bloat | HIGH | MEDIUM | Opt-in activation |
| User confusion | MEDIUM | MEDIUM | Guided tours, documentation |
| Privacy concerns | LOW | CRITICAL | Local-first, no cloud |
| Competition | HIGH | MEDIUM | Focus on privacy, UX |

---

## 7. Success Metrics

### 7.1 Phase 1 Success

| Metric | Target | How to measure |
|---|---|---|
| Cache hit rate | > 80% | Analytics |
| Progress persistence | 100% | Tests |
| Dark mode adoption | > 30% | Analytics |
| Audit log completeness | 100% | Tests |

### 7.2 Phase 2 Success

| Metric | Target | How to measure |
|---|---|---|
| AI summary accuracy | > 85% | User testing |
| Text extraction quality | > 90% | Benchmark |
| Search relevance | > 90% | User testing |
| Reading mode usage | > 50% | Analytics |

### 7.3 Phase 3 Success

| Metric | Target | How to measure |
|---|---|---|
| iOS app rating | > 4.5 stars | App Store |
| WCAG compliance | AA level | Audit |
| Comparison usage | > 20% | Analytics |
| Batch processing | > 10% | Analytics |

### 7.4 Phase 4 Success

| Metric | Target | How to measure |
|---|---|---|
| Collaboration adoption | > 15% | Analytics |
| Annotation usage | > 40% | Analytics |
| Script usage | > 5% | Analytics |
| User satisfaction | > 90% | Survey |

---

## 8. EVIDENCE

- Expanded 22-Dimension Analysis (docs/audits/jtbd-01-read-expanded-analysis-2026-08-26.md)
- Expanded Analytical Framework (docs/audits/analytical-framework-expanded-5w1h.md)
- JTBD-01 First Principles Breakdown (docs/audits/jtbd-01-read-first-principles-2026-08-26.md)
- Stage 1-4 Deep Dives (docs/audits/jtbd-01-stage*-first-principles.md)
- 354 passing tests (evidence of current capability)
- Operating Doctrine §3, §5, §8 (alignment requirements)
