# Cross-JTBD Unified Implementation Roadmap

**Date:** 2026-08-26
**Source:** 6 JTBD expanded analyses (22 dimensions each)
**Status:** First-principles, long-term, doctrine-aligned implementation plan

---

## Purpose

This roadmap merges all 6 JTBD gap analyses into a single prioritized implementation plan. Features are ordered by:
1. **User impact** — how many users/jobs benefit
2. **Competitive gap** — how far behind competitors we are
3. **Foundation effect** — does this enable other features
4. **Effort** — implementation complexity
5. **Doctrine alignment** — does this match our principles

---

## 1. Master Gap Inventory

### 1.1 All Gaps Across All 6 JTBDs

| # | Gap | JTBD | Impact | Effort | Foundation | Priority Score |
|---|---|---|---|---|---|---|
| G-01 | Document summarization | UNDERSTAND | HIGH | Medium | HIGH | **9** |
| G-02 | Table extraction | UNDERSTAND | HIGH | Medium | HIGH | **9** |
| G-03 | Entity recognition | UNDERSTAND | HIGH | Medium | HIGH | **9** |
| G-04 | Key point extraction | UNDERSTAND | HIGH | Medium | HIGH | **9** |
| G-05 | Fuzzy search | FIND | HIGH | Small | MEDIUM | **8** |
| G-06 | Dark mode | READ | HIGH | Small | LOW | **7** |
| G-07 | Reading position persistence | READ | HIGH | Small | HIGH | **8** |
| G-08 | Batch form fill | INTERACT | HIGH | Large | MEDIUM | **7** |
| G-09 | Form validation rules | INTERACT | HIGH | Medium | MEDIUM | **7** |
| G-10 | Metadata stripping | PROTECT | HIGH | Medium | HIGH | **8** |
| G-11 | Audit logging | PROTECT | HIGH | Medium | HIGH | **8** |
| G-12 | Compression | SHARE | HIGH | Medium | LOW | **7** |
| G-13 | Batch export | SHARE | HIGH | Large | MEDIUM | **6** |
| G-14 | Search history | FIND | MEDIUM | Small | LOW | **6** |
| G-15 | Regex search | FIND | MEDIUM | Small | LOW | **5** |
| G-16 | Side-by-side comparison | READ | HIGH | Large | MEDIUM | **6** |
| G-17 | Reading modes | READ | MEDIUM | Medium | MEDIUM | **5** |
| G-18 | Image export | SHARE | MEDIUM | Medium | LOW | **5** |
| G-19 | Text export | SHARE | MEDIUM | Small | LOW | **5** |
| G-20 | Share sheet | SHARE | MEDIUM | Large | LOW | **4** |
| G-21 | Auto-fill integration | INTERACT | MEDIUM | Large | LOW | **4** |
| G-22 | Form templates | INTERACT | MEDIUM | Medium | LOW | **4** |
| G-23 | Watermarking | PROTECT | MEDIUM | Medium | LOW | **4** |
| G-24 | Access revocation | PROTECT | MEDIUM | Large | LOW | **3** |
| G-25 | Cross-platform | READ | CRITICAL | Very large | HIGH | **8** | 🅿️ PARKED (2026-08-26) — revisit after core macOS capability is complete |
| G-26 | WCAG accessibility | READ | CRITICAL | Large | HIGH | **7** |
| G-27 | AI summarization | UNDERSTAND | HIGH | Large | HIGH | **7** |
| G-28 | Semantic search | FIND | HIGH | Large | HIGH | **6** |
| G-29 | Cross-document search | FIND | LOW | Large | LOW | **3** |
| G-30 | Collaboration | READ | MEDIUM | Very large | LOW | **3** |
| G-31 | Batch protection | PROTECT | HIGH | Large | MEDIUM | **6** |
| G-32 | Protection templates | PROTECT | MEDIUM | Medium | LOW | **4** |
| G-33 | XFA form support | INTERACT | HIGH | Very large | LOW | **5** |
| G-34 | Concept mapping | UNDERSTAND | MEDIUM | Large | LOW | **3** |
| G-35 | Version comparison | UNDERSTAND | MEDIUM | Large | MEDIUM | **4** |
| G-36 | Cloud upload | SHARE | MEDIUM | Very large | LOW | **2** |

### 1.2 Priority Score Calculation

```
Priority = Impact(1-3) + EffortInverse(1-3) + Foundation(1-3) + CompetitiveGap(0-1)
```

Where:
- Impact: CRITICAL=3, HIGH=2, MEDIUM=1, LOW=0
- EffortInverse: Small=3, Medium=2, Large=1, Very large=0
- Foundation: HIGH=3, MEDIUM=2, LOW=1
- CompetitiveGap: Yes=1, No=0

---

## 2. Implementation Phases

### Phase 0: UNDERSTAND Foundation (Weeks 1-3)

**Goal:** Close the #1 gap across all JTBDs — document comprehension

| Feature | Gap | Effort | What it delivers |
|---|---|---|---|
| **Document summarization** | G-01 | Medium | Key points, importance scoring, structure |
| **Entity recognition** | G-03 | Medium | Dates, amounts, emails, URLs, phones |
| **Key point extraction** | G-04 | Medium | Obligations, definitions, conclusions |
| **Table extraction** | G-02 | Medium | Structured data from tables |

**Already done:**
- ✅ `DocumentSummarizer.swift` — created, compiles
- ✅ `EntityRecognizer.swift` — created, compiles
- ✅ `KeyPointExtractor.swift` — created, compiles
- ✅ `UnderstandGapTests.swift` — 22 tests, verified passing
- ✅ **Rendering pipeline genuinely integrated (2026-08-26)** — see below

**What's next:**
- Verify build + tests pass
- Wire into UI (Inspector panel shows summary, entities, key points)
- Add real PDF fixture tests

**Enables:** G-27 (AI summarization), G-35 (version comparison), G-34 (concept mapping)

---

### Pipeline Integration — Verdict Update (2026-08-26)

Previously flagged: "pipeline implementations are protocol abstractions, not wired into the UI." **Fixed and verified:**

| Claim | Status | Evidence |
|---|---|---|
| Pipeline real rasterizer, not stubs | ✅ | `ProgressiveRenderer` renders real CGContext pages at 72/150/300 DPI + exact-DPI API |
| Wired into app UI | ✅ | `ContentView` owns one shared `RenderingPipeline`; canvas + page rail consume it |
| Real page thumbnails in rail | ✅ | `PageThumbnailRailView` renders each page via pipeline (`RailThumbnail`), async + cached |
| Tile grid uses real page bounds | ✅ | Removed hardcoded 612×792; grid derives from actual mediaBox (test: 1600×700 fixture) |
| Stats are real | ✅ | `cacheStats.totalSize` + tile `hitRate` computed, not hardcoded 0 (mutation-tested) |
| Same cache warm/lookups | ✅ | `warmUpPages` on load; `renderThumbnailAsync` reuses renderer cache |
| UNDERSTAND verified | ✅ | Phone regex + question detection fixed; all 22 UNDERSTAND tests pass |
| Full suite | ✅ | **402/402 tests pass** |

Layout/mode exploration (freeze-panes, content-routed modes, window-in-window, split) documented in `docs/audits/jtbd-01-read-layouts-and-modes-2026-08-26.md`.

### Phase 1: Quick Wins (Weeks 3-5)

**Goal:** High-impact, low-effort features that improve daily use

| Feature | Gap | Effort | What it delivers |
|---|---|---|---|
| **Dark mode** | G-06 | Small | Eye strain reduction |
| **Fuzzy search** | G-05 | Small | Typo tolerance |
| **Search history** | G-14 | Small | Repeat searches |
| **Reading position persistence** | G-07 | Small | Resume where left off |
| **Metadata stripping** | G-10 | Medium | Privacy on export |
| **Text export** | G-19 | Small | Copy text from PDF |

**Foundation effect:** Reading position persistence is already wired into the pipeline. Dark mode is a theme system. Fuzzy search builds on existing search.

**Enables:** G-17 (reading modes), G-12 (compression)

---

### Phase 2: Protection & Privacy (Weeks 5-8)

**Goal:** Close the privacy and compliance gaps

| Feature | Gap | Effort | What it delivers |
|---|---|---|---|
| **Audit logging** | G-11 | Medium | Who accessed what, when |
| **Batch protection** | G-31 | Large | Encrypt/password many docs |
| **Compression** | G-12 | Medium | Smaller file sizes |
| **Form validation rules** | G-09 | Medium | Prevent errors before save |
| **Regex search** | G-15 | Small | Power user search |

**Foundation effect:** Audit logging enables compliance certification. Compression enables better sharing.

**Enables:** G-32 (protection templates), G-13 (batch export)

---

### Phase 3: Intelligence (Weeks 8-12)

**Goal:** AI-powered understanding that competitors have

| Feature | Gap | Effort | What it delivers |
|---|---|---|---|
| **AI summarization** | G-27 | Large | One-paragraph summaries |
| **Semantic search** | G-28 | Large | Meaning-based search |
| **Side-by-side comparison** | G-16 | Large | Document diff view |
| **Reading modes** | G-17 | Medium | Study/Skim/Reference/Review |
| **Version comparison** | G-35 | Large | Track changes between versions |

**Foundation effect:** AI summarization builds on UNDERSTAND foundation. Semantic search builds on entity recognition.

**Enables:** G-34 (concept mapping), G-29 (cross-document search)

---

### Phase 4: Platform & Accessibility (Weeks 12-20)

**Goal:** Reach more users, meet accessibility standards

| Feature | Gap | Effort | What it delivers |
|---|---|---|---|
| **WCAG 2.1 compliance** | G-26 | Large | Screen reader, keyboard, contrast |
| **Image export** | G-18 | Medium | Export pages as PNG/JPEG |
| **Batch export** | G-13 | Large | Export many docs at once |
| **Watermarking** | G-23 | Medium | Attribution on exported PDFs |
| **Batch form fill** | G-08 | Large | Fill many forms from data |

**Foundation effect:** WCAG compliance is a legal requirement in many jurisdictions. Batch operations build on existing infrastructure.

**Enables:** G-20 (share sheet), G-21 (auto-fill)

---

### Phase 5: Cross-Platform (Weeks 20-30) — 🅿️ PARKED

**Goal:** Reach iOS, Windows, Android users

> **Decision (2026-08-26):** Parked for now. Cross-platform was marked CRITICAL/HIGH-impact but is Very-large effort with the weakest foundation of any gap. Per doctrine, it is deferred until the core macOS capability is complete and the architecture (capability routing, lane lifecycle) is stable enough to port. Revisit after Phase 3 (Intelligence) at the earliest. This does not remove G-25 from the inventory — it defers its phase.

| Feature | Gap | Effort | What it delivers |
|---|---|---|---|
| **iOS/iPadOS app** | G-25 | Very large | Touch-optimized reader |
| **Share sheet** | G-20 | Large | System integration |
| **Auto-fill integration** | G-21 | Large | Browser/OS form data |
| **Form templates** | G-22 | Medium | Reusable form layouts |
| **Access revocation** | G-24 | Large | Revoke document access |

**Foundation effect:** iOS app requires architecture decisions that affect all platforms.

**Enables:** G-30 (collaboration), G-33 (XFA), G-36 (cloud upload)

---

### Phase 6: Advanced (Weeks 30+)

**Goal:** Enterprise and power user features

| Feature | Gap | Effort | What it delivers |
|---|---|---|---|
| **Collaboration** | G-30 | Very large | Multi-user annotations |
| **XFA form support** | G-33 | Very large | Government/enterprise forms |
| **Concept mapping** | G-34 | Large | Visual relationship view |
| **Cross-document search** | G-29 | Large | Corpus-level search |
| **Protection templates** | G-32 | Medium | Reusable security configs |
| **Cloud upload** | G-36 | Very large | Cloud storage integration |

---

## 3. Dependency Map

```
Phase 0 (UNDERSTAND)
  ├── G-01 Summarization ──→ G-27 AI Summarization
  ├── G-02 Table extraction ──→ G-35 Version comparison
  ├── G-03 Entity recognition ──→ G-28 Semantic search
  └── G-04 Key points ──→ G-34 Concept mapping

Phase 1 (Quick Wins)
  ├── G-06 Dark mode ──→ G-17 Reading modes
  ├── G-05 Fuzzy search ──→ G-28 Semantic search
  ├── G-07 Position persistence ──→ (independent)
  ├── G-10 Metadata strip ──→ G-31 Batch protection
  └── G-14 Search history ──→ (independent)

Phase 2 (Protection)
  ├── G-11 Audit logging ──→ G-24 Access revocation
  ├── G-12 Compression ──→ G-13 Batch export
  ├── G-09 Form validation ──→ G-08 Batch form fill
  └── G-15 Regex search ──→ (independent)

Phase 3 (Intelligence)
  ├── G-27 AI summary ──→ G-30 Collaboration
  ├── G-28 Semantic search ──→ G-29 Cross-doc search
  ├── G-16 Side-by-side ──→ G-35 Version comparison
  └── G-17 Reading modes ──→ (independent)

Phase 4 (Platform)
  ├── G-26 WCAG ──→ G-25 Cross-platform
  ├── G-18 Image export ──→ (independent)
  ├── G-13 Batch export ──→ G-20 Share sheet
  └── G-08 Batch fill ──→ G-21 Auto-fill

Phase 5 (Cross-Platform)
  ├── G-25 iOS app ──→ G-30 Collaboration
  ├── G-20 Share sheet ──→ (independent)
  ├── G-21 Auto-fill ──→ (independent)
  └── G-24 Access revocation ──→ (independent)

Phase 6 (Advanced)
  ├── G-30 Collaboration ──→ (end state)
  ├── G-33 XFA ──→ (end state)
  └── G-36 Cloud ──→ (end state)
```

---

## 4. Competitive Positioning

### 4.1 Current State vs. Adobe Acrobat

| Capability | Us | Adobe | Gap |
|---|---|---|---|
| Reading | ✅ Strong | ✅ Strong | PARITY |
| Finding | ✅ Strong | ✅ Strong | PARITY |
| Understanding | ⚠️ Implementing | ✅ AI | CLOSING |
| Interacting | ✅ Strong | ✅ Strong | PARITY |
| Sharing | ✅ Strong | ✅ Strong | PARITY |
| Protecting | ✅ Strong | ✅ Strong | PARITY |
| Privacy | ✅ LOCAL | ❌ Cloud | **ADVANTAGE** |
| Price | ✅ FREE | ❌ $$$$ | **ADVANTAGE** |

### 4.2 After Phase 3 (Week 12)

| Capability | Us | Adobe | Gap |
|---|---|---|---|
| Understanding | ✅ AI-powered | ✅ AI | PARITY |
| Privacy | ✅ LOCAL | ❌ Cloud | **ADVANTAGE** |
| Price | ✅ FREE | ❌ $$$$ | **ADVANTAGE** |

### 4.3 After Phase 5 (Week 30)

| Capability | Us | Adobe | Gap |
|---|---|---|---|
| Cross-platform | ✅ macOS + iOS | ✅ All | CLOSING |
| Understanding | ✅ AI | ✅ AI | PARITY |
| Privacy | ✅ LOCAL | ❌ Cloud | **ADVANTAGE** |

---

## 5. Risk Assessment

### 5.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| AI model too large | MEDIUM | HIGH | Use smaller models, quantization |
| iOS performance | MEDIUM | HIGH | Optimize early, test often |
| Accessibility regressions | MEDIUM | MEDIUM | Automated testing |
| Performance degradation | LOW | HIGH | Benchmark continuously |
| Disk space constraints | HIGH | MEDIUM | CI/CD cleanup, incremental builds |

### 5.2 Product Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Feature bloat | HIGH | MEDIUM | Opt-in activation, lifecycle management |
| User confusion | MEDIUM | MEDIUM | Guided tours, documentation |
| Privacy concerns | LOW | CRITICAL | Local-first, no cloud |
| Competition | HIGH | MEDIUM | Focus on privacy, UX |
| Scope creep | HIGH | MEDIUM | Phase gates, milestone reviews |

---

## 6. Success Metrics

### 6.1 Per-Phase Metrics

| Phase | Metric | Target | How to measure |
|---|---|---|---|
| 0 | UNDERSTAND features working | 4 features | Tests pass |
| 1 | Quick wins delivered | 6 features | Tests pass |
| 2 | Protection complete | 5 features | Tests pass |
| 3 | AI features working | 5 features | User testing |
| 4 | WCAG compliance | AA level | Audit |
| 5 | iOS app shipped | App Store | Release |
| 6 | Enterprise features | 6 features | Tests pass |

### 6.2 Overall Success

| Metric | Target | Timeline |
|---|---|---|
| Feature parity with Adobe (core) | 90% | Phase 3 (Week 12) |
| Privacy advantage maintained | 100% | All phases |
| Test suite growth | 369 → 500+ | Phase 2 |
| Documentation coverage | 100% | All phases |

---

## 7. Evidence

- JTBD-01 READ expanded analysis (docs/audits/jtbd-01-read-expanded-analysis-2026-08-26.md)
- JTBD-02 FIND expanded analysis (docs/audits/jtbd-02-find-expanded-analysis-2026-08-26.md)
- JTBD-03 UNDERSTAND expanded analysis (docs/audits/jtbd-03-understand-expanded-analysis-2026-08-26.md)
- JTBD-04 INTERACT expanded analysis (docs/audits/jtbd-04-interact-expanded-analysis-2026-08-26.md)
- JTBD-05 SHARE expanded analysis (docs/audits/jtbd-05-share-expanded-analysis-2026-08-26.md)
- JTBD-06 PROTECT expanded analysis (docs/audits/jtbd-06-protect-expanded-analysis-2026-08-26.md)
- JTBD-18 ANNOTATE expanded analysis (docs/audits/jtbd-18-annotate-expanded-analysis-2026-08-27.md)
- JTBD-19 COLLABORATE expanded analysis (docs/audits/jtbd-19-collaborate-expanded-analysis-2026-08-27.md)
- JTBD-03 LEARN expanded analysis (docs/audits/jtbd-03-learn-expanded-analysis-2026-08-27.md)
- Creator archetype analysis (docs/audits/jtbd-creator-archetype-expanded-analysis-2026-08-27.md)
- Expanded analytical framework (docs/audits/analytical-framework-expanded-5w1h.md)
- Gap analysis & implementation roadmap (docs/audits/jtbd-01-read-gap-analysis-implementation-2026-08-26.md)
- Competitive analysis (docs/audits/pdf-libraries-permissive-evaluation-2026-08-26.md)
- Operating Doctrine §3, §5, §8

## 8. Completion Log (updated 2026-08-27)

### Reader Archetype (J1-J6, J18-J19)

| Gap | Feature | Status | Evidence |
|---|---|---|---|
| G-01 | Document summarization | ✅ DONE | `DocumentSummarizer.swift`, 6 tests |
| G-02 | Table extraction | ✅ DONE | `ImprovedTextExtractor.detectTables()`, `DetectedTable` with cells |
| G-03 | Entity recognition | ✅ DONE | `EntityRecognizer.swift`, 12 tests |
| G-04 | Key point extraction | ✅ DONE | `KeyPointExtractor.swift`, 6 tests |
| G-05 | Fuzzy search | ✅ DONE | Levenshtein distance, 33% tolerance, SearchMode.fuzzy |
| G-06 | Dark mode | ✅ DONE | `ThemeManager.swift`, 18 tests, Settings panel |
| G-07 | Reading position persistence | ✅ DONE | `ReadingPosition` struct, UserDefaults, page change wiring |
| G-14 | Search history | ✅ DONE | UserDefaults persistence, max 20, dropdown UI |
| G-15 | Regex search | ✅ DONE | `NSRegularExpression`, SearchMode.regex |
| G-16 | Side-by-side comparison | ✅ DONE | `DiffComparisonView.swift` |
| G-17 | Reading modes | ✅ DONE | `ReadingMode.swift` (Study/Skim/Reference/Review), 12 tests, toolbar picker |
| G-14 | Freeze-panes layout | ✅ DONE | `FreezePaneLayout.swift`, 18 tests, auto-detect from table structure |
| G-02 | UNDERSTAND inspector tab | ✅ DONE | `ContextualInspectorView.swift` — summary/entities/key points |
| G-05 | Search mode picker | ✅ DONE | Menu in search HUD (exact/fuzzy/regex icons) |
| G-30 | Collaboration (file-level) | ✅ DONE | `CollaborationPackage.swift`, `AnnotationMerger.swift`, 21 tests |
| G-30 | Annotation system | ✅ DONE | `AnnotationMarks.swift`, `AnnotationStore.swift`, 29 tests |
| G-30 | Study loop (LEARN) | ✅ DONE | `StudyLoop.swift`, `StudyLoopView.swift`, 20 tests |
| Pipeline | Adaptive quality rendering | ✅ DONE | `adaptiveDPI(for:)`, `preRenderForViewport()` wired into canvas |

### Creator Archetype (J7-J9)

| Gap | Feature | Status | Evidence |
|---|---|---|---|
| CREATE | Document creation from scratch | ❌ NOT STARTED | — |
| CREATE | Form field designer | ❌ NOT STARTED | — |
| TRANSFORM | In-place text editing | ⚠️ PARTIAL | Overlay text exists (not true in-place) |
| TRANSFORM | Page manipulation UI | ⚠️ EXTERNAL | PdfCpuBatchProcessor wraps pdfcpu |
| COMMIT | Approval workflow | ❌ NOT STARTED | — |
| COMMIT | Multi-party signing | ❌ NOT STARTED | — |

### Documentation (22-dimension analyses)

| JTBD | Status | File |
|---|---|---|
| READ (J2) | ✅ DONE | `jtbd-01-read-expanded-analysis-2026-08-26.md` (804 lines) |
| FIND (J4) | ✅ DONE | `jtbd-02-find-expanded-analysis-2026-08-26.md` |
| UNDERSTAND (J5) | ✅ DONE | `jtbd-03-understand-expanded-analysis-2026-08-26.md` |
| INTERACT (J6) | ✅ DONE | `jtbd-04-interact-expanded-analysis-2026-08-26.md` |
| SHARE (J10) | ✅ DONE | `jtbd-05-share-expanded-analysis-2026-08-26.md` |
| PROTECT (J11) | ✅ DONE | `jtbd-06-protect-expanded-analysis-2026-08-26.md` |
| ANNOTATE (J18) | ✅ DONE | `jtbd-18-annotate-expanded-analysis-2026-08-27.md` |
| COLLABORATE (J19) | ✅ DONE | `jtbd-19-collaborate-expanded-analysis-2026-08-27.md` |
| LEARN (J3) | ✅ DONE | `jtbd-03-learn-expanded-analysis-2026-08-27.md` |
| Creator (J7-J9) | ✅ DONE | `jtbd-creator-archetype-expanded-analysis-2026-08-27.md` |
| Manager (J12-J14) | ✅ DONE | `personas-jobs-expanded-model-2026-08-26.md` §9 |
| Power (J15-J17) | ✅ DONE | `personas-jobs-expanded-model-2026-08-26.md` §10 |

**Test suite: 620/620 tests pass (76 suites).**

**Still open (by priority):**
- G-10 Metadata stripping (score 8)
- G-11 Audit logging (score 8)
- G-26 WCAG accessibility (score 8)
- G-27 AI summarization (score 7)
- CREATE: Document creation from scratch (Creator archetype)
- COMMIT: Approval workflow (Creator archetype)
- G-28 Semantic search (score 7)
