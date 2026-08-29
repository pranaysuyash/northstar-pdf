# Spaced Repetition / FSRS

**Date:** 2026-08-28
**Status:** Observed + Verified
**Evidence tier:** Tier 2 (targeted tests — algorithm verified against known inputs)
**Test sensitivity:** S1 (tests pass), S2 (SM-2 algorithm behavior verified)

## 1. Decision context

The LEARN job analysis identified spaced repetition as a key feature for studying. The question was: which algorithm, and how does it integrate with the annotation marks system?

**Question:** What spaced repetition algorithm to use, and how does it integrate with the LEARN study loop?

## 2. Algorithm choice

### SM-2 (SuperMemo 2) — chosen
- Simple, well-understood, proven over 30 years
- 3 ratings: Again (0), Hard (3), Good (4), Easy (5)
- Interval calculation: `interval = previousInterval * easeFactor`
- Ease factor: `easeFactor = easeFactor + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02))`
- Minimum ease factor: 1.3

### Alternatives considered
- **FSRS (Free Spaced Repetition Scheduler):** More sophisticated, uses machine learning to optimize intervals. Requires training data. Overkill for v1.
- **Leitner system:** Box-based, simpler but less adaptive. SM-2 is more widely used.
- **Anki's algorithm:** Proprietary, not fully documented. SM-2 is the open alternative.

### Truth taxonomy
- **Observed:** SM-2 algorithm implemented with standard parameters
- **Verified:** 8 tests verify interval calculation, ease factor bounds, review scheduling
- **Inferred:** Default parameters (initial ease 2.5, min ease 1.3) are reasonable starting points

## 3. Integration with LEARN study loop

- Marks (annotations) are the study items
- Each mark has: `reviewCount`, `easeFactor`, `interval`, `nextReview`, `lastReview`
- Study sessions: user reviews marks, rates recall quality
- SM-2 calculates next review date
- Spaced repetition scheduling: marks due for review surfaced first

## 4. Evidence

- Algorithm implementation in `SpacedRepetitionEngine` (within annotation/LEARN system)
- 8+ tests verify SM-2 behavior
- Full suite: 1199/1199 pass

## 5. Doctrine alignment

- §2 Truth taxonomy: algorithm claims labeled as "SM-2" not "AI-powered"
- §3 Proportional rigor: SM-2 sufficient for v1, FSRS deferred
- §5 Evidence-based: interval calculation verified against known inputs

## 6. Open questions

- Should FSRS be explored for v2? (Requires training data from user's review history)
- How should "Hard" rating be handled? (SM-2 treats it same as "Good" in some implementations)
- Should the algorithm be configurable per-user?
