# JTBD-19 COLLABORATE — Expanded 22-Dimension Analysis

**Date:** 2026-08-27
**Framework:** Expanded Analytical Framework (22 dimensions)
**Job:** "I need to work with others on this document"
**Status:** First-principles, long-term, doctrine-aligned analysis
**Extends:** `personas-jobs-expanded-model-2026-08-26.md` §11.2

---

## Purpose

COLLABORATE is the social job — the one that acknowledges documents are artifacts people exchange, annotate together, and reach agreement on. Previous analysis identified it as needing file-level merge first (§11.2 recommendation). This applies the full 22-dimension framework to understand every facet.

---

## 1. WHO

### 1.1 Person (Primary User)

| Persona | Core Need | Expertise | Frequency | Our Support |
|---|---|---|---|---|
| Legal reviewer | Contract markup exchange | Legal, not tech | Weekly | ✅ File-level merge exists |
| Editor | Manuscript feedback loop | Publishing | Daily | ⚠️ No threaded comments |
| Teacher | Assignment review + grading | Education | Daily | ⚠️ No per-student layers |
| Manager | Approval chain | Business | Weekly | ❌ No approval workflow |
| Consultant | Client deliverable review | Domain expert | Weekly | ⚠️ Basic merge only |
| Researcher | Peer review exchange | Academic | Monthly | ❌ No review scoring |
| Designer | Design spec feedback | Creative | Weekly | ❌ No visual annotation overlay |
| Student group | Study group document sharing | Variable | Daily | ⚠️ No real-time sync |

### 1.2 Actor

| Actor | How they collaborate | Our support |
|---|---|---|
| Human (local) | Export → annotate → import → merge | ✅ File-level merge |
| Human (LAN) | Share over local network | ❌ No LAN discovery |
| Human (cloud) | Cloud shared doc | ❌ No cloud sync |
| Automated agent | Batch annotation merge | ⚠️ Script foundation only |
| AI reviewer | Automated feedback | ❌ No AI integration |

### 1.3 Stakeholder

| Stakeholder | Impact of collaboration failure | Severity |
|---|---|---|
| Reviewer | Feedback lost, rework needed | HIGH |
| Author | Conflicting changes, confusion | HIGH |
| Legal team | Version chaos, liability | CRITICAL |
| Organization | Delayed approvals, cost | HIGH |
| Data subject | Privacy breach in shared docs | CRITICAL |
| End user | Wrong version shipped | HIGH |

---

## 2. WHAT

### 2.1 Thing (The Object Being Collaborated On)

| Object | Collaboration challenge | Our capability | Gap |
|---|---|---|---|
| Contract | Multiple reviewer markups | ✅ Annotation layer merge | Small |
| Manuscript | Editorial comments + revisions | ⚠️ No threaded comments | Medium |
| Form template | Field-level feedback | ⚠️ Form fill exists, no review | Medium |
| Design spec | Visual markup | ❌ No visual overlay | Large |
| Research paper | Peer review annotations | ❌ No structured review | Large |
| Policy document | Approval chain markup | ❌ No approval workflow | Large |
| Invoice | Verification marks | ✅ Annotation search | Small |
| Medical report | Multi-specialist review | ❌ No structured review | Large |

### 2.2 Action

| Action | Frequency | Our support | Priority |
|---|---|---|---|
| Export annotated copy | Every collaboration | ✅ JSON sidecar export | CRITICAL |
| Import partner's copy | Every collaboration | ✅ Package reader | CRITICAL |
| Review merge conflicts | Every collaboration | ✅ Conflict resolution UI | CRITICAL |
| Add comment on partner's mark | Often | ❌ No reply/thread | HIGH |
| Track who said what | Always | ⚠️ Author metadata exists | MEDIUM |
| Approve/reject changes | Formal review | ❌ No approval state | HIGH |
| Version the collaboration | Every session | ⚠️ VersionStore exists | MEDIUM |
| Export merged result | End of cycle | ✅ Sidecar write | HIGH |

### 2.3 Event (What Triggers Collaboration)

| Trigger | Context | Our support |
|---|---|---|
| Document shared via email | External review | ✅ Package export |
| Review deadline approaching | Time pressure | ❌ No reminders |
| New version uploaded | Update cycle | ⚠️ Version detection partial |
| Conflict detected | Merge time | ✅ Conflict resolution UI |
| Approval requested | Formal gate | ❌ No approval workflow |

### 2.4 Outcome

| Outcome | Success criteria | Our support |
|---|---|---|
| Agreement reached | All reviewers aligned | ❌ No consensus mechanism |
| Feedback integrated | All comments addressed | ⚠️ No tracking |
| Version clear | No ambiguity about which version | ✅ Content hash identity |
| Audit trail | Who said what, when | ⚠️ Partial (author metadata) |
| Document finalized | All approvals received | ❌ No finalization gate |

### 2.5 Artifact

| Artifact | Purpose | Our support |
|---|---|---|
| Collaboration package | Portable bundle of PDF + annotations | ✅ Implemented |
| Merge report | Summary of merge outcomes | ✅ MergeSummary |
| Conflict resolution log | Record of how conflicts were resolved | ❌ Not persisted |
| Approval record | Who approved what | ❌ Not implemented |
| Review score | Quality assessment of feedback | ❌ Not implemented |

---

## 3. WHEN

### 3.1 Time

| When | Pattern | Our support |
|---|---|---|
| Business hours | Primary collaboration window | N/A (desktop app) |
| After hours | Catch-up review | N/A |
| Meeting time | Real-time discussion | ❌ No real-time |

### 3.2 Sequence

| Phase | What happens | Our support |
|---|---|---|
| 1. Initiation | Author exports package | ✅ Package builder |
| 2. Distribution | Package sent to reviewers | ✅ File export |
| 3. Independent review | Each reviewer annotates independently | ✅ Annotation store |
| 4. Collection | Packages returned to author | ⚠️ Manual file transfer |
| 5. Merge | Author merges all feedback | ✅ AnnotationMerger |
| 6. Resolution | Conflicts resolved | ✅ Conflict UI |
| 7. Integration | Merged annotations applied | ✅ Sidecar write |
| 8. Re-export | Updated package sent back | ✅ Package builder |
| 9. Approval | Final sign-off | ❌ No approval gate |

### 3.3 Duration

| Collaboration type | Typical duration | Our support |
|---|---|---|
| Quick review | 30 minutes | ✅ Fast merge |
| Contract review | 1-3 days | ✅ Persistent annotations |
| Manuscript review | 1-2 weeks | ⚠️ No version tracking |
| Policy approval | 1-4 weeks | ❌ No approval workflow |
| Legal discovery | Months | ❌ No corpus management |

### 3.4 Frequency

| User type | Collaboration frequency | Our support |
|---|---|---|
| Editor | Daily | ⚠️ Basic merge only |
| Manager | Weekly | ⚠️ No approval chain |
| Legal | Weekly | ✅ File-level merge |
| Student | Weekly (study group) | ⚠️ No real-time |
| Individual | Rare | ✅ Package export/import |

---

## 4. WHERE

### 4.1 Place

| Location | Collaboration pattern | Our support |
|---|---|---|
| Office | Formal review cycles | ✅ Desktop app |
| Home | Remote review | ✅ Desktop app |
| Meeting room | Discussion + markup | ❌ No shared screen mode |
| Commute | Quick review on phone | ❌ No mobile app |

### 4.2 Platform

| Platform | Collaboration need | Our support |
|---|---|---|
| macOS | Primary | ✅ Native app |
| Windows | Cross-platform | ❌ No Windows app |
| iOS/iPadOS | Mobile review | ❌ No iOS app |
| Web | Browser-based review | ⚠️ Web viewer exists |
| Email | Package delivery | ✅ File export |
| Cloud storage | Package sync | ❌ No cloud integration |

### 4.3 Context

| Context | Collaboration need | Our support |
|---|---|---|
| Formal review | Structured feedback | ❌ No review templates |
| Informal feedback | Quick marks | ✅ Annotation store |
| Approval chain | Sequential review | ❌ No workflow engine |
| Parallel review | Simultaneous feedback | ✅ Package per reviewer |
| Ad hoc | Quick question | ❌ No commenting |

---

## 5. WHY

### 5.1 Reason

| Why collaborate | Depth | Our support |
|---|---|---|
| Quality assurance | Multiple eyes catch errors | ⚠️ Basic merge |
| Legal compliance | Required review/approval | ❌ No approval chain |
| Knowledge sharing | Teaching/learning | ⚠️ No threaded comments |
| Consensus building | Align on decisions | ❌ No voting/scoring |
| Accountability | Who said what | ⚠️ Author metadata |
| Efficiency | Parallel work | ✅ Independent annotation |

### 5.2 Motivation

| Motivation | User statement | Our support |
|---|---|---|
| Contract review | "Check this clause" | ✅ Annotation + merge |
| Manuscript feedback | "Improve this section" | ⚠️ No reply threads |
| Approval | "Sign off on this" | ❌ No approval gate |
| Quality check | "Find issues" | ✅ Annotation search |
| Learning | "Discuss this concept" | ❌ No discussion |

### 5.3 Consequence of Failure

| Failure mode | Impact | Severity |
|---|---|---|
| Feedback lost | Rework, delays | HIGH |
| Version confusion | Wrong document used | CRITICAL |
| Privacy breach | Sensitive data exposed | CRITICAL |
| Conflict unresolved | Blocked progress | HIGH |
| Audit missing | Compliance failure | CRITICAL |

---

## 6. HOW

### 6.1 Method

| Method | Description | Our support |
|---|---|---|
| File-level merge | Export → annotate → import → merge | ✅ Implemented |
| LAN sharing | Local network sync | ❌ Not implemented |
| Cloud sync | Real-time collaboration | ❌ Not implemented |
| Email thread | Back-and-forth packages | ✅ File export |
| Version control | Git-like document versioning | ⚠️ VersionStore partial |

### 6.2 Process

| Step | Current state | Needed |
|---|---|---|
| 1. Package creation | ✅ CollaborationPackageBuilder | Reviewer name prompt |
| 2. Package delivery | ⚠️ Manual file transfer | Email integration |
| 3. Annotation import | ✅ CollaborationPackageReader | Batch import |
| 4. Merge execution | ✅ AnnotationMerger | Multi-package merge |
| 5. Conflict resolution | ✅ CollaborationMergeView | Auto-resolution hints |
| 6. Result export | ✅ Sidecar write | Package re-export |
| 7. Approval recording | ❌ Not implemented | Approval workflow |

### 6.3 Mechanism

| Mechanism | Implementation | Status |
|---|---|---|
| Package format | JSON manifest + PDF + sidecar | ✅ |
| Document identity | SHA-256 content hash | ✅ |
| Integrity verification | Hash comparison | ✅ |
| Merge algorithm | Bounds/type/text matching | ✅ |
| Conflict detection | 4 conflict reasons | ✅ |
| Resolution strategies | keepLocal/keepPartner/keepBoth/merge | ✅ |
| Merge UI | Side-by-side cards + picker | ✅ |
| Audit trail | ❌ Not persisted | Needed |

---

## 7. WHO USES WHAT — Sub-Job Weighting

### 7.1 User × Sub-Job Matrix

| User | Package Export | Conflict Resolution | Approval | Thread Discussion | Why |
|---|---|---|---|---|---|
| **Legal reviewer** | 🔴 Critical | 🔴 Critical | 🔴 Critical | 🟡 Medium | Must prove review happened |
| **Editor** | 🟡 Medium | 🟡 Medium | 🟡 Medium | 🔴 Critical | Discussion is the product |
| **Manager** | 🟡 Medium | 🟡 Medium | 🔴 Critical | 🟢 Low | Approval is the gate |
| **Teacher** | 🟢 Low | 🟢 Low | 🟡 Medium | 🔴 Critical | Feedback is the product |
| **Student** | 🟢 Low | 🟢 Low | 🟢 Low | 🟡 Medium | Study group discussion |
| **Consultant** | 🔴 Critical | 🟡 Medium | 🟡 Medium | 🟢 Low | Professional deliverable |
| **Researcher** | 🟡 Medium | 🟡 Medium | 🟢 Low | 🔴 Critical | Peer review discussion |

### 7.2 When Each Sub-Job Fires

```
EXPORT happens at:   start of every review cycle
MERGE happens at:    collection phase (after independent review)
CONFLICT happens at: merge time (if marks overlap)
APPROVAL happens at: end of review cycle (formal only)
THREAD happens at:   throughout (discussion is continuous)
```

---

## 8. CURRENT STATE — Implementation Evidence

### 8.1 What Exists

| Component | File | Status | Tests |
|---|---|---|---|
| CollaborationPackage | CollaborationPackage.swift | ✅ Complete | Package identity, integrity |
| CollaborationPackageBuilder | CollaborationPackage.swift | ✅ Complete | Build + write to directory |
| CollaborationPackageReader | CollaborationPackage.swift | ✅ Complete | Read + verify |
| AnnotationMerger | AnnotationMerger.swift | ✅ Complete | 21 tests |
| CollaborationMergeView | CollaborationMergeView.swift | ✅ Complete | Conflict resolution UI |
| AnnotationMarks | AnnotationMarks.swift | ✅ Complete | Mark model |
| AnnotationStore | AnnotationStore.swift | ✅ Complete | CRUD + search + export |
| DiffComparisonView | DiffComparisonView.swift | ✅ Complete | Visual PDF diff |
| VersionStore | VersionStore.swift | ✅ Complete | Persistent snapshots |

### 8.2 What's Missing

| Gap | Severity | Priority | First-principle reason |
|---|---|---|---|
| Threaded comments / replies | HIGH | HIGH | Discussion is the product for editors |
| Approval workflow | HIGH | HIGH | Legal compliance requires it |
| Multi-package merge | MEDIUM | HIGH | Real reviews involve 3+ reviewers |
| Merge audit trail | MEDIUM | HIGH | Who resolved what, when |
| Email integration | LOW | MEDIUM | Convenience, not core |
| Real-time sync | LOW | LOW | Violates local-first doctrine |
| Review scoring | LOW | LOW | Nice-to-have quality metric |

### 8.3 Open Questions Resolved

| # | Question | Resolution |
|---|---|---|
| Q9 | Where do annotations live? | Sidecar (existing AnnotationStore) — preserves source-preservation |
| Q10 | Which COLLABORATE tier first? | File-level merge — implemented, validates demand |
| Q11 | Does COLLABORATE subsume SHARE? | Yes — SHARE is single-direction subset of COLLABORATE |
| Q12 | Multi-package merge? | Needed — 3+ reviewers is the norm, not exception |

---

## 9. FIRST-PRINCIPLES ASSESSMENT

### 9.1 Is This a Real Job?

**Yes.** Documents are social artifacts. The expanded model (§11.2) correctly identifies COLLABORATE as distinct from SHARE. The evidence:
- Every professional document type involves review cycles
- The annotation sidecar + merge infrastructure proves the need
- The conflict resolution UI proves the complexity

### 9.2 Are We Aligned to Doctrines?

| Doctrine | Alignment | Evidence |
|---|---|---|
| §3 Do things smartly | ✅ | Reuses annotation store + diff/merge core |
| §5 Evidence-based | ✅ | Package integrity hash, merge summary |
| §8 Capability activation | ✅ | COLLABORATE is opt-in, not default |
| §12 Privacy value-free | ✅ | No document content in audit records |

### 9.3 What's the Minimum Viable Collaboration?

```
1. Export package (✅ done)
2. Import partner's package (✅ done)
3. Merge annotations (✅ done)
4. Resolve conflicts (✅ done)
5. Re-export merged result (✅ done — sidecar write)
```

**The minimum viable collaboration is complete.** The remaining gaps (threads, approval, multi-package) are enhancements, not foundations.

---

## 10. LONG-TERM VISION

### 10.1 The Collaboration Spectrum

```
FILE-LEVEL (now)          LAN (future)           CLOUD (far future)
Export → Import → Merge   Discover → Sync → Merge  Edit → Sync → Merge
No network needed         Local network only       Opt-in, per-account
Zero egress               Egress within LAN        Egress to cloud
✅ Implemented            ❌ Not started           ❌ Not started
```

### 10.2 What File-Level Collaboration Proves

Before building LAN or cloud sync, file-level merge answers:
1. Do users actually exchange annotated copies? (demand signal)
2. How many conflicts arise in practice? (complexity signal)
3. Is the merge UI sufficient? (UX signal)
4. Do users need threading? (feature signal)

If file-level merge is used heavily, the demand for LAN/cloud sync becomes evidence-based, not speculative.

---

## 11. EVIDENCE

- `Sources/PDFEditorCore/CollaborationPackage.swift` — package format, builder, reader, integrity
- `Sources/PDFEditorCore/AnnotationMerger.swift` — merge algorithm with 4 conflict reasons
- `Sources/PDFEditorApp/CollaborationMergeView.swift` — conflict resolution UI
- `Tests/PDFEditorCoreTests/CollaborationMergeTests.swift` — 21 tests
- `Sources/PDFEditorApp/DiffComparisonView.swift` — visual PDF diff (COLLABORATE foundation)
- `Sources/PDFEditorCore/AnnotationStore.swift` — sidecar annotation persistence
- `docs/audits/personas-jobs-expanded-model-2026-08-26.md` §11.2 — original analysis
- `Sources/PDFEditorCore/VersionStore.swift` — persistent version snapshots
