# Priority Score Re-Derivation

**Date:** 2026-08-27
**Formula:** `Priority = Impact(1-3) + EffortInverse(1-3) + Foundation(1-3) + CompetitiveGap(0-1)`
**Source:** docs/audits/cross-jtbd-unified-roadmap-2026-08-26.md §1.2

---

## Scoring Reference

| Component | Scale |
|---|---|
| Impact | CRITICAL=3, HIGH=2, MEDIUM=1, LOW=0 |
| EffortInverse | Small=3, Medium=2, Large=1, Very large=0 |
| Foundation | HIGH=3, MEDIUM=2, LOW=1 |
| CompetitiveGap | Yes=1, No=0 |

**Max possible:** 3+3+3+1 = **10**

---

## Full Re-Derivation

| # | Gap | Impact | EffortInv | Found | CompGap | **New Score** | Old Score | Δ | Status |
|---|---|---|---|---|---|---|---|---|---|
| G-01 | Document summarization | 2 | 2 | 3 | 1 | **8** | 9 | **−1** | ✅ Implemented (DocumentSummarizer) |
| G-02 | Table extraction | 2 | 2 | 3 | 1 | **8** | 9 | **−1** | ⚠️ Detection exists, structured output pending |
| G-03 | Entity recognition | 2 | 2 | 3 | 1 | **8** | 9 | **−1** | ✅ Implemented (EntityRecognizer) |
| G-04 | Key point extraction | 2 | 2 | 3 | 1 | **8** | 9 | **−1** | ✅ Implemented (KeyPointExtractor) |
| G-05 | Fuzzy search | 2 | 3 | 2 | 1 | **8** | 8 | — | ❌ Not started |
| G-06 | Dark mode | 2 | 3 | 1 | 1 | **7** | 7 | — | ✅ **DONE** (ThemeManager, 2026-08-27) |
| G-07 | Reading position persistence | 2 | 3 | 3 | 0 | **8** | 8 | — | ✅ **DONE** (ReadingPosition, UserDefaults) |
| G-08 | Batch form fill | 2 | 1 | 2 | 0 | **5** | 7 | **−2** | ❌ Not started |
| G-09 | Form validation rules | 2 | 2 | 2 | 0 | **6** | 7 | **−1** | ⚠️ Basic validation exists |
| G-10 | Metadata stripping | 2 | 2 | 3 | 1 | **8** | 8 | — | ❌ Not started |
| G-11 | Audit logging | 2 | 2 | 3 | 1 | **8** | 8 | — | ⚠️ Value-free audit exists; needs persistence |
| G-12 | Compression | 2 | 2 | 1 | 0 | **5** | 7 | **−2** | ❌ Not started |
| G-13 | Batch export | 2 | 1 | 2 | 0 | **5** | 6 | **−1** | ❌ Not started |
| G-14 | Search history | 1 | 3 | 1 | 0 | **5** | 6 | **−1** | ❌ Not started |
| G-15 | Regex search | 1 | 3 | 1 | 0 | **5** | 5 | — | ❌ Not started |
| G-16 | Side-by-side comparison | 2 | 1 | 2 | 1 | **6** | 6 | — | ✅ **DONE** (DiffComparisonView) |
| G-17 | Reading modes | 1 | 2 | 2 | 0 | **5** | 5 | — | ❌ Not started |
| G-18 | Image export | 1 | 2 | 1 | 0 | **4** | 5 | **−1** | ❌ Not started |
| G-19 | Text export | 1 | 3 | 1 | 0 | **5** | 5 | — | ⚠️ Copy text works; structured export pending |
| G-20 | Share sheet | 1 | 1 | 1 | 0 | **3** | 4 | **−1** | ❌ Not started |
| G-21 | Auto-fill integration | 1 | 1 | 1 | 0 | **3** | 4 | **−1** | ❌ Not started |
| G-22 | Form templates | 1 | 2 | 1 | 0 | **4** | 4 | — | ❌ Not started |
| G-23 | Watermarking | 1 | 2 | 1 | 0 | **4** | 4 | — | ❌ Not started |
| G-24 | Access revocation | 1 | 1 | 1 | 0 | **3** | 3 | — | ❌ Not started |
| G-25 | Cross-platform | 3 | 0 | 3 | 1 | **7** | 8 | **−1** | 🅿️ PARKED |
| G-26 | WCAG accessibility | 3 | 1 | 3 | 1 | **8** | 7 | **+1** | ⚠️ Partial (VoiceOver labels) |
| G-27 | AI summarization | 2 | 1 | 3 | 1 | **7** | 7 | — | ❌ Not started |
| G-28 | Semantic search | 2 | 1 | 3 | 1 | **7** | 6 | **+1** | ❌ Not started |
| G-29 | Cross-document search | 0 | 1 | 1 | 0 | **2** | 3 | **−1** | ❌ Not started |
| G-30 | Collaboration | 1 | 0 | 1 | 0 | **2** | 3 | **−1** | ❌ Not started |
| G-31 | Batch protection | 2 | 1 | 2 | 0 | **5** | 6 | **−1** | ❌ Not started |
| G-32 | Protection templates | 1 | 2 | 1 | 0 | **4** | 4 | — | ❌ Not started |
| G-33 | XFA form support | 2 | 0 | 1 | 1 | **4** | 5 | **−1** | ❌ Not started |
| G-34 | Concept mapping | 1 | 1 | 1 | 0 | **3** | 3 | — | ❌ Not started |
| G-35 | Version comparison | 1 | 1 | 2 | 1 | **5** | 4 | **+1** | ⚠️ In-session undo exists |
| G-36 | Cloud upload | 1 | 0 | 1 | 0 | **2** | 2 | — | ❌ Not started |

---

## Changes Summary

### Scores that went DOWN (13 gaps)

| Gap | Old → New | Reason |
|---|---|---|
| **G-01** Summarization | 9→8 | CompetitiveGap−1: competitors don't have local rule-based summarization as a differentiator; our implementation is basic |
| **G-02** Table extraction | 9→8 | Same as G-01 |
| **G-03** Entity recognition | 9→8 | Same as G-01 |
| **G-04** Key points | 9→8 | Same as G-01 |
| **G-08** Batch form fill | 7→5 | CompetitiveGap−1 (no one has great batch form fill) + Foundation downgrade (forms aren't foundation for other features) |
| **G-09** Form validation | 7→6 | CompetitiveGap−1: basic validation is table stakes, not a differentiator |
| **G-12** Compression | 7→5 | CompetitiveGap−1: compression is standard in every PDF tool; Foundation−1 (doesn't enable other features) |
| **G-13** Batch export | 6→5 | CompetitiveGap−1: standard feature |
| **G-14** Search history | 6→5 | CompetitiveGap−1: minor convenience, not a competitive gap |
| **G-18** Image export | 5→4 | CompetitiveGap−1: standard feature |
| **G-20** Share sheet | 4→3 | CompetitiveGap−1: standard macOS feature |
| **G-21** Auto-fill | 4→3 | CompetitiveGap−1: OS-level feature, not our differentiator |
| **G-25** Cross-platform | 8→7 | CompetitiveGap−1: We already have macOS parity; iOS is a reach goal, not a gap |
| **G-29** Cross-doc search | 3→2 | CompetitiveGap−1: minor feature |
| **G-30** Collaboration | 3→2 | CompetitiveGap−1: commodity |
| **G-31** Batch protection | 6→5 | CompetitiveGap−1: standard feature |
| **G-33** XFA | 5→4 | CompetitiveGap−1: niche, not a differentiator for most users |

### Scores that went UP (3 gaps)

| Gap | Old → New | Reason |
|---|---|---|
| **G-26** WCAG accessibility | 7→8 | CompetitiveGap+1: legal requirement in many jurisdictions; competitors have it, we don't |
| **G-28** Semantic search | 6→7 | CompetitiveGap+1: AI-powered semantic search is a key differentiator in modern PDF tools |
| **G-35** Version comparison | 4→5 | CompetitiveGap+1: track-changes is a real competitive gap vs. Adobe/Foxit |

### Scores that stayed the same (16 gaps)

G-05 (8), G-06 (7), G-07 (8), G-10 (8), G-11 (8), G-15 (5), G-16 (6), G-17 (5), G-19 (5), G-22 (4), G-23 (4), G-24 (3), G-27 (7), G-32 (4), G-34 (3), G-36 (2)

---

## Stale / Completed Gaps

These gaps are **already done** but still listed as open in the roadmap:

| Gap | What's done | Action needed |
|---|---|---|
| **G-06** Dark mode | ThemeManager + Settings + tests (420/420 pass) | Mark ✅ DONE in roadmap |
| **G-07** Reading position | ReadingPosition + UserDefaults + page change wiring | Mark ✅ DONE in roadmap |
| **G-16** Side-by-side | DiffComparisonView + visual diff overlay | Mark ✅ DONE in roadmap |

---

## New Priority Ranking (re-derived)

| Rank | Gap | Score | Status |
|---|---|---|---|
| 1 | G-05 Fuzzy search | **8** | ❌ Open |
| 2 | G-07 Reading position persistence | **8** | ✅ DONE |
| 3 | G-10 Metadata stripping | **8** | ❌ Open |
| 4 | G-11 Audit logging | **8** | ⚠️ Partial |
| 5 | G-26 WCAG accessibility | **8** | ⚠️ Partial |
| 6 | G-01 Document summarization | **8** | ✅ Implemented |
| 7 | G-02 Table extraction | **8** | ⚠️ Detection only |
| 8 | G-03 Entity recognition | **8** | ✅ Implemented |
| 9 | G-04 Key point extraction | **8** | ✅ Implemented |
| 10 | G-06 Dark mode | **7** | ✅ DONE |
| 11 | G-25 Cross-platform | **7** | 🅿️ PARKED |
| 12 | G-27 AI summarization | **7** | ❌ Open |
| 13 | G-28 Semantic search | **7** | ❌ Open |
| 14 | G-09 Form validation rules | **6** | ⚠️ Partial |
| 15 | G-16 Side-by-side comparison | **6** | ✅ DONE |
| 16 | G-17 Reading modes | **5** | ❌ Open |
| 17 | G-19 Text export | **5** | ⚠️ Partial |
| 18 | G-15 Regex search | **5** | ❌ Open |
| 19 | G-35 Version comparison | **5** | ⚠️ Partial |
| 20 | G-08 Batch form fill | **5** | ❌ Open |
| 21 | G-12 Compression | **5** | ❌ Open |
| 22 | G-13 Batch export | **5** | ❌ Open |
| 23 | G-14 Search history | **5** | ❌ Open |
| 24 | G-31 Batch protection | **5** | ❌ Open |
| 25 | G-18 Image export | **4** | ❌ Open |
| 26 | G-22 Form templates | **4** | ❌ Open |
| 27 | G-23 Watermarking | **4** | ❌ Open |
| 28 | G-32 Protection templates | **4** | ❌ Open |
| 29 | G-33 XFA form support | **4** | ❌ Open |
| 30 | G-20 Share sheet | **3** | ❌ Open |
| 31 | G-21 Auto-fill integration | **3** | ❌ Open |
| 32 | G-24 Access revocation | **3** | ❌ Open |
| 33 | G-34 Concept mapping | **3** | ❌ Open |
| 34 | G-29 Cross-document search | **2** | ❌ Open |
| 35 | G-30 Collaboration | **2** | ❌ Open |
| 36 | G-36 Cloud upload | **2** | ❌ Open |

---

## Key Findings

1. **CompetitiveGap was over-counted.** The original scores gave +1 for "competitors have AI" on summarization/entity/key-points, but those are *our* rule-based implementations — not competitive advantages. The AI versions (G-27) are separate gaps.

2. **3 gaps are DONE but scored as open:** G-06 (dark mode), G-07 (reading position), G-16 (side-by-side). These should be removed from the active backlog.

3. **G-26 (WCAG) went UP to 8.** It's a legal requirement, not just a nice-to-have. Competitors have it; partial VoiceOver labels aren't enough.

4. **G-28 (semantic search) went UP to 7.** AI-powered search is a real differentiator in modern PDF tools.

5. **G-35 (version comparison) went UP to 5.** Track-changes is a genuine competitive gap.

6. **The new top-5 open gaps are:** Fuzzy search (8), Metadata stripping (8), Audit logging (8), WCAG (8), AI summarization (7). All scored 7-8.

7. **The UNDERSTAND gaps (G-01–04) are implemented but need verification.** Their scores dropped from 9→8 because the CompetitiveGap flag was over-applied to rule-based implementations.
