# JTBD-03 LEARN — Expanded 22-Dimension Analysis

**Date:** 2026-08-27
**Framework:** Expanded Analytical Framework (22 dimensions)
**Job:** "I need to study and retain this content"
**Status:** First-principles, long-term, doctrine-aligned analysis
**Extends:** `personas-jobs-expanded-model-2026-08-26.md` §11.3

---

## Purpose

LEARN is the retention job — distinct from UNDERSTAND (comprehension now) and READ (consumption). LEARN is about remembering next week, next month. The study loop is its surface: mark → review → recall → retain. This analysis maps every dimension.

---

## 1. WHO

### 1.1 Person

| Persona | Core Need | Expertise | Frequency | Our Support |
|---|---|---|---|---|
| Medical student | Retain anatomy, pharmacology | Domain expert | Daily, hours | ✅ Study loop exists |
| Law student | Retain case law, statutes | Domain expert | Daily, hours | ✅ Study loop exists |
| Bar exam preper | Retain legal principles | Domain expert | Daily, months | ✅ Study loop exists |
| Professional certification | Retain exam material | Domain expert | Weekly, months | ✅ Study loop exists |
| Language learner | Retain vocabulary in context | Beginner-intermediate | Daily | ⚠️ No spaced repetition |
| Employee onboarding | Retain company policies | Novice | Weekly, weeks | ✅ Study loop exists |
| Researcher | Retain paper key findings | Expert | Weekly | ⚠️ No cross-document study |
| Teacher | Understand what students need to learn | Expert | Daily | ❌ No teaching mode |

### 1.2 Actor

| Actor | How they learn | Our support |
|---|---|---|
| Sighted reader | Read → highlight → review → recall | ✅ Study loop |
| Auditory learner | Listen → recall | ❌ No text-to-speech |
| Kinesthetic learner | Interactive recall | ⚠️ Quiz mode exists |
| Visual learner | Visual diagrams → recall | ❌ No visual study aids |
| Automated reviewer | Spaced repetition scheduler | ❌ No SM-2 implementation |

### 1.3 Stakeholder

| Stakeholder | Impact of learning failure | Severity |
|---|---|---|
| Student | Exam failure, career impact | HIGH |
| Professional | Certification failure | HIGH |
| Organization | Non-compliant employees | HIGH |
| Patient (medical) | Misdiagnosis | CRITICAL |
| Client (legal) | Bad legal advice | CRITICAL |

---

## 2. WHAT

### 2.1 Thing (What Gets Learned)

| Object | Learning challenge | Our capability | Gap |
|---|---|---|---|
| Text-heavy content | Retain key concepts | ✅ Highlight + note | Small |
| Form data | Retain field meanings | ⚠️ Form fill exists, no study | Medium |
| Visual content | Retain diagrams/charts | ❌ No visual study | Large |
| Tables | Retain data relationships | ⚠️ Table detection exists | Medium |
| Legal clauses | Retain clause implications | ✅ Highlight + note | Small |
| Medical terminology | Retain definitions | ⚠️ No flashcard mode | Medium |
| Code/API specs | Retain syntax and behavior | ❌ No code study mode | Large |
| Multi-document corpus | Retain across documents | ❌ No cross-document study | Large |

### 2.2 Action

| Action | Frequency | Our support | Priority |
|---|---|---|---|
| Create study marks | Every session | ✅ AnnotationMark | CRITICAL |
| Review marks (passive) | Every session | ✅ Review mode | CRITICAL |
| Recall (active testing) | Every session | ✅ Recall mode | CRITICAL |
| Quiz (random order) | Many sessions | ✅ Quiz mode | HIGH |
| Track progress | Every session | ✅ Mastery tracking | HIGH |
| See mastery levels | Every session | ✅ 5-level system | HIGH |
| Export study progress | Some sessions | ❌ No export | MEDIUM |
| Schedule review | Some sessions | ❌ No spaced repetition | HIGH |
| Cross-document study | Rare | ❌ No corpus study | LOW |

### 2.3 Artifact

| Artifact | Purpose | Our support |
|---|---|---|
| StudySession | Active study session | ✅ |
| MarkMastery | Per-mark mastery tracking | ✅ |
| MasterySummary | Aggregate mastery stats | ✅ |
| RecallQuestion | Question presented during recall | ✅ |
| RecallAnswer | Answer revealed after recall | ✅ |
| Study report | Export study progress | ❌ Not implemented |
| Spaced repetition schedule | When to review next | ❌ Not implemented |

---

## 3. WHEN

### 3.1 Sequence (The Study Loop)

| Phase | What happens | Our support |
|---|---|---|
| 1. Mark creation | User highlights/notes important content | ✅ AnnotationMark |
| 2. Initial review | User reads through all marks | ✅ Review mode |
| 3. First recall | User tests themselves | ✅ Recall mode |
| 4. Correct/incorrect | User rates their recall | ✅ Mastery recording |
| 5. Repeat | User practices again | ✅ Session advancement |
| 6. Mastery achieved | 4+ correct in a row | ✅ MasteryLevel.mastered |
| 7. Re-review | User revisits mastered marks | ⚠️ No scheduling |
| 8. Retention check | User verifies long-term recall | ❌ No spaced repetition |

### 3.2 Duration

| Activity | Duration | Our support |
|---|---|---|
| Create a mark | 2 seconds | ✅ Fast model |
| Review one mark | 5 seconds | ✅ Review mode |
| Recall one mark | 10 seconds | ✅ Recall mode |
| Full session (20 marks) | 5-10 minutes | ✅ Session tracking |
| Mastery journey (all marks) | Days to weeks | ⚠️ No scheduling |

### 3.3 Frequency

| User type | Study frequency | Session length |
|---|---|---|
| Medical student | Daily, 2-3 sessions | 30-60 minutes |
| Bar exam preper | Daily, 1-2 sessions | 30-60 minutes |
| Certification preper | Weekly, 1 session | 30-60 minutes |
| Language learner | Daily, 1 session | 15-30 minutes |
| Employee onboarding | Weekly, 1 session | 15-30 minutes |

---

## 4. WHERE

### 4.1 Study Context

| Context | Study pattern | Our support |
|---|---|---|
| Desk (home/office) | Long study sessions | ✅ Desktop app |
| Commute | Quick recall sessions | ❌ No mobile app |
| Library | Deep study | ✅ Desktop app |
| Before exam | Intensive review | ✅ Quiz mode |
| Bedtime | Light review | ⚠️ No dark mode recall |
| Waiting (bus, queue) | Micro-sessions | ❌ No mobile app |

### 4.2 Study Materials

| Material | Study need | Our support |
|---|---|---|
| Textbook PDF | Highlight + recall | ✅ Study loop |
| Lecture notes PDF | Note + recall | ✅ Study loop |
| Legal case PDF | Clause recall | ✅ Study loop |
| Medical atlas PDF | Visual recall | ❌ No visual study |
| Research paper PDF | Finding recall | ⚠️ Basic study only |

---

## 5. WHY

### 5.1 Reason

| Why learn | Depth | Our support |
|---|---|---|
| Pass an exam | Survival | ✅ Quiz mode |
| Retain professional knowledge | Career | ✅ Mastery tracking |
| Understand complex material | Intellectual | ✅ Review + recall |
| Prepare for certification | Credential | ⚠️ No scheduling |
| Onboard to new role | Organizational | ✅ Study loop |
| Maintain compliance | Regulatory | ❌ No scheduling |
| Personal enrichment | Growth | ✅ Study loop |

### 5.2 Motivation

| Motivation | User statement | Our support |
|---|---|---|
| Exam pressure | "I need to know this by Friday" | ✅ Quiz mode |
| Career advancement | "I need to pass the bar" | ✅ Mastery tracking |
| Understanding | "I want to really get this" | ✅ Review mode |
| Compliance | "I need to know the policies" | ⚠️ No scheduling |
| Curiosity | "This is fascinating" | ✅ Study loop |

### 5.3 Consequence of Failure

| Failure | Impact | Severity |
|---|---|---|
| Marks not retained | Time wasted studying | HIGH |
| No progress tracking | Don't know what to review | HIGH |
| No recall testing | Passive re-reading (low retention) | HIGH |
| No scheduling | Spacing effect lost | MEDIUM |
| No cross-document study | Fragmented knowledge | LOW |

---

## 6. HOW

### 6.1 Method

| Method | Description | Our support |
|---|---|---|
| Highlight + review | Mark important text, re-read | ✅ Review mode |
| Active recall | Hide answer, test yourself | ✅ Recall mode |
| Spaced repetition | Review at increasing intervals | ❌ Not implemented |
| Quiz mode | Random order testing | ✅ Quiz mode |
| Mastery tracking | Track per-mark progress | ✅ 5-level system |
| Flashcards | Card-based study | ⚠️ Recall mode is similar |
| Mind maps | Visual concept connections | ❌ Not implemented |
| Practice tests | Simulated exam | ⚠️ Quiz mode is similar |

### 6.2 The Study Loop Data Model

```
StudyMode
├── review     — passive reading of marks
├── recall     — active testing (hide answer)
└── quiz       — random order + correctness tracking

MasteryLevel
├── new        — never reviewed (0)
├── seen       — viewed but not recalled (1)
├── learning   — recalled correctly once (2)
├── review     — recalled correctly 2-3 times (3)
└── mastered   — recalled correctly 4+ times (4)

MarkMastery
├── markID: UUID
├── level: MasteryLevel
├── correctStreak: Int
├── totalAttempts: Int
├── correctCount: Int
├── accuracy: Double (computed)
├── createdAt: Date
└── lastReviewedAt: Date?

StudySession
├── marks: [AnnotationMark]      — ordered for study
├── mode: StudyMode              — review/recall/quiz
├── currentIndex: Int            — progress
├── mastery: [UUID: MarkMastery] — per-mark state
├── progress: Double             — 0.0 to 1.0
├── isComplete: Bool
└── masterySummary: MasterySummary

StudyLoopManager
├── startSession(marks:mode:documentID:) → StudySession
├── nextSessionState(from:) → StudySession
├── recordCorrect(documentID:markID:)
├── recordIncorrect(documentID:markID:)
├── mastery(for:documentID:) → MarkMastery?
├── summary(for:marks:) → MasterySummary
├── marksNeedingReview(_:documentID:) → [AnnotationMark]
└── persistence (UserDefaults)
```

### 6.3 How Mastery Advances

```
New → (first review) → Seen → (correct recall) → Learning → (2 correct) → Review → (4 correct) → Mastered
         ↓                    ↓                        ↓                       ↓
      (no action)         (incorrect)              (incorrect)            (incorrect)
         ↓                    ↓                        ↓                       ↓
       [stay]              New(-1)                  Seen(-1)              Review(-1)
```

---

## 7. WHO USES WHAT — Sub-Job Weighting

### 7.1 User × Sub-Job Matrix

| User | Create Marks | Review Mode | Recall Mode | Quiz Mode | Mastery Tracking | Spaced Rep |
|---|---|---|---|---|---|---|
| **Medical student** | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🔴 Critical |
| **Bar exam preper** | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🔴 Critical |
| **Certification** | 🔴 Critical | 🟡 Medium | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🟡 Medium |
| **Language learner** | 🔴 Critical | 🟡 Medium | 🔴 Critical | 🟡 Medium | 🟡 Medium | 🟡 Medium |
| **Employee onboarding** | 🟡 Medium | 🟡 Medium | 🟡 Medium | 🟢 Low | 🟢 Low | 🟢 Low |
| **Researcher** | 🟡 Medium | 🟢 Low | 🟢 Low | 🟢 Low | 🟢 Low | 🟢 Low |

### 7.2 Study Mode Usage by User Type

| Mode | Student | Professional | Casual |
|---|---|---|---|
| Review | 🟡 Orientation | 🟡 Orientation | 🟢 Quick look |
| Recall | 🔴 Primary | 🔴 Primary | 🟡 Sometimes |
| Quiz | 🔴 Pre-exam | 🟡 Pre-certification | 🟢 Rarely |

---

## 8. CURRENT STATE — Implementation Evidence

### 8.1 What Exists

| Component | File | Status | Tests |
|---|---|---|---|
| StudyMode enum | StudyLoop.swift | ✅ 3 modes | review/recall/quiz |
| RecallQuestion | StudyLoop.swift | ✅ Complete | hint extraction from text |
| RecallAnswer | StudyLoop.swift | ✅ Complete | reveal full text + note |
| MasteryLevel | StudyLoop.swift | ✅ 5 levels | new→seen→learning→review→mastered |
| MarkMastery | StudyLoop.swift | ✅ Complete | streak-based advancement |
| StudySession | StudyLoop.swift | ✅ Complete | progress, sorting, completion |
| StudyLoopManager | StudyLoop.swift | ✅ Complete | session lifecycle + persistence |
| StudyLoopView | StudyLoopView.swift | ✅ Complete | SwiftUI review/recall UI |
| AnnotationMark | AnnotationMarks.swift | ✅ Complete | marks as substrate |
| AnnotationStore | AnnotationStore.swift | ✅ Complete | CRUD + search + export |
| 20 tests | StudyLoopTests.swift | ✅ All pass | mastery, recall, sessions |

### 8.2 What's Missing

| Gap | Severity | Priority | First-principle reason |
|---|---|---|---|
| Spaced repetition (SM-2) | HIGH | HIGH | Retention requires scheduling |
| Study progress export | MEDIUM | HIGH | Users need to track progress externally |
| Cross-document study | LOW | MEDIUM | Corpus-level learning |
| Visual study aids | LOW | LOW | Diagrams, charts need visual recall |
| Audio playback | LOW | LOW | Auditory learners |
| Study streaks/motivation | LOW | LOW | Gamification for engagement |

### 8.3 What's Honest About the Study Loop

The study loop works:
- **Review mode**: passive reading of marks in order ✅
- **Recall mode**: hide answer, "I Knew It" / "Didn't Know" ✅
- **Quiz mode**: random order, correctness tracking ✅
- **Mastery tracking**: 5 levels, streak-based advancement ✅
- **Persistence**: mastery data saved to UserDefaults ✅

What it does NOT do:
- **No spaced repetition** — marks are reviewed on-demand, not scheduled
- **No study scheduling** — user must remember to come back
- **No motivation system** — no streaks, no reminders, no gamification
- **No cross-document study** — each document is isolated

---

## 9. FIRST-PRINCIPLES ASSESSMENT

### 9.1 Is This a Real Job?

**Yes.** The expanded model (§11.3) correctly identifies LEARN as distinct from UNDERSTAND:
- UNDERSTAND = comprehension now (extract meaning)
- LEARN = retention later (remember meaning)

The evidence: cognitive science shows active recall + spaced repetition dramatically improve retention vs. passive re-reading. Our study loop implements active recall but not spaced repetition.

### 9.2 Are We Aligned to Doctrines?

| Doctrine | Alignment | Evidence |
|---|---|---|
| §3 Do things smartly | ✅ | Reuses annotation marks as substrate |
| §5 Evidence-based | ✅ | Mastery levels are data-driven |
| §8 Capability activation | ✅ | Study loop is opt-in |
| §12 Privacy value-free | ✅ | Study data is user's, not document content |

### 9.3 The Dependency Chain is Correct

```
ANNOTATE (J18) — marks are the substrate
    ↓
LEARN (J3) — study marks, not the whole document
    ↓
COLLABORATE (J19) — marks that travel
```

LEARN is correctly positioned as depending on ANNOTATE. The study loop consumes AnnotationMarks directly.

---

## 10. LONG-TERM VISION

### 10.1 The Learning Spectrum

```
BASIC (now)              SCHEDULED (future)       INTELLIGENT (far future)
Review + Recall + Quiz   SM-2 spaced repetition   AI-adaptive scheduling
5 mastery levels         Per-mark scheduling       Difficulty estimation
UserDefaults persistence SQLite + sync             Cloud + cross-device
✅ Implemented           ❌ Not started            ❌ Not started
```

### 10.2 What Basic Learning Proves

Before building spaced repetition, basic learning answers:
1. Do users actually use recall mode? (engagement signal)
2. What's the average mastery level? (difficulty signal)
3. How many marks per study session? (volume signal)
4. Do users return for repeat sessions? (retention signal)

---

## 11. EVIDENCE

- `Sources/PDFEditorCore/StudyLoop.swift` — study session, recall, mastery tracking
- `Sources/PDFEditorApp/StudyLoopView.swift` — SwiftUI review/recall/quiz UI
- `Tests/PDFEditorCoreTests/StudyLoopTests.swift` — 20 tests
- `Sources/PDFEditorCore/AnnotationMarks.swift` — marks as substrate
- `Sources/PDFEditorCore/AnnotationStore.swift` — mark persistence
- `docs/audits/personas-jobs-expanded-model-2026-08-26.md` §11.3 — original analysis
