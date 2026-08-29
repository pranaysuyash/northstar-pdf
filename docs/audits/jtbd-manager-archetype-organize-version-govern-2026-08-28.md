# Manager Archetype — ORGANIZE / VERSION / GOVERN

**Date:** 2026-08-28
**Framework:** Expanded Analytical Framework (22 dimensions)
**Jobs:** ORGANIZE (corpus management), VERSION (change tracking), GOVERN (compliance)
**Status:** First-principles, long-term, doctrine-aligned analysis
**Extends:** `jtbd-creator-archetype-create-design-publish-2026-08-28.md`, `jtbd-01-read-first-principles-2026-08-26.md`

---

## Purpose

The Manager archetype is the **corpus-centric** shift. While Reader and Creator operate on a single document, Manager operates on a collection of documents. This is the biggest architectural change in the model — it requires an index, a version store, and a policy engine.

The Reader archetype asked: "How do I understand this document?"
The Creator archetype asked: "How do I make this document exist?"
The Manager archetype asks: "How do I keep track of all my documents?"

---

## Taxonomy

| Job | Core statement | Status | Key finding |
|---|---|---|---|
| **ORGANIZE** | "I need to find, tag, and manage my document collection" | ⚠️ Partial — DocumentIndex exists (303 lines), no UI | Engine is solid, no user surface |
| **VERSION** | "I need to track changes and compare versions" | ⚠️ Partial — VersionStore (233 lines), in-session undo/redo | Persistent version store exists, no revert UI |
| **GOVERN** | "I need to enforce policies and audit compliance" | ⚠️ Partial — DocumentPolicy (324 lines), audit infrastructure | Policy engine exists, no dashboard |

### The asymmetry

The Reader archetype has 19 fully-analyzed jobs with deep implementation. The Creator archetype has 3 jobs with engine-level code. The Manager archetype has 3 jobs with **substantial engine code but zero user-facing surface**. The engines are there — DocumentIndex, VersionStore, DocumentPolicy — but there's no way for a user to actually organize, version, or govern their documents through the UI.

### The architectural shift

Every feature so far operates on **one open document**. Manager jobs need:
- An **index** (DocumentIndex) — metadata about many documents
- A **version store** (VersionStore) — history of changes across time
- A **policy engine** (DocumentPolicy) — rules applied to many documents

This is the corpus-centric architecture. The in-session operation ledger is a VERSION store waiting to become persistent.

---

# 1. ORGANIZE — "I need to find, tag, and manage my document collection"

## 1.1 WHO

| Persona | Core need | Expertise | Frequency | Our support |
|---|---|---|---|---|
| Knowledge worker | Find a specific document in a large collection | Basic | Daily | ❌ No corpus search |
| Researcher | Organize papers by topic, project, reading status | Academic | Daily | ⚠️ DocumentIndex exists, no UI |
| Lawyer | Find documents by case, client, date range | Legal | Daily | ❌ No folder/tag system in UI |
| Accountant | Organize invoices, receipts, tax documents | Financial | Weekly | ❌ No auto-categorization |
| Student | Organize course materials, papers, notes | Education | Weekly | ❌ No study-specific organization |
| Manager | Oversee team document collection | Business | Daily | ❌ No corpus overview |
| Archivist | Maintain long-term document repository | Archival | Monthly | ❌ No retention automation |
| Personal user | Find that PDF from last month | Basic | Weekly | ❌ No recent/smart collections |

## 1.2 WHAT

| Object | Organization challenge | Our capability | Gap |
|---|---|---|---|
| Document collection | Find specific documents | ❌ No corpus search | Large — DocumentIndex has search logic, no UI |
| Tags | Categorize documents freely | ❌ Tag system in DocumentIndexEntry, no UI | Medium — data model exists |
| Folders | Group documents hierarchically | ❌ Folder field in DocumentIndexEntry, no UI | Medium — data model exists |
| Metadata | Extract title, author, dates | ⚠️ PDF metadata extraction works | Small — need to surface in index |
| Duplicates | Detect near-duplicate documents | ❌ DedupDetector in DocumentIndex, no UI | Medium — algorithm exists |
| Recent documents | Quick access to recently opened | ⚠️ lastAccessedAt tracked | Small — need recent list |
| Starred/favorites | Quick access to important documents | ⚠️ isStarred tracked | Small — need starred list |
| Smart collections | Auto-grouped by rules (date, tag, size) | ❌ No rule engine | Large |
| Cross-document search | Search text across all documents | ❌ No corpus-level text search | Large — per-document search exists |
| Corpus statistics | Overview of collection health | ❌ No stats dashboard | Medium |

## 1.3 WHEN

| Phase | What happens | Our support |
|---|---|---|
| First document | User opens a PDF for the first time | ❌ No onboarding into organization |
| Growing collection | User accumulates 10+ documents | ❌ No automatic organization suggestions |
| Active use | User needs to find a specific document | ❌ No search, no recent list |
| Review | User reviews their collection periodically | ❌ No corpus overview |
| Cleanup | User removes duplicates, organizes folders | ❌ No dedup UI, no folder management |
| Archive | User moves old documents to archive | ❌ No archive/retention system |

## 1.4 WHERE

| Context | Organization need | Our support |
|---|---|---|
| File system | Documents live in ~/Documents | ❌ No file system integration |
| App library | Documents opened in the app | ❌ No library/collection view |
| Spotlight | macOS search | ❌ No Spotlight indexing |
| Recent | Recently opened documents | ⚠️ History tracked, no UI |
| Tags | macOS Finder tags | ❌ No Finder tag sync |
| Cloud | iCloud Drive, Dropbox | ❌ No cloud integration (privacy) |

## 1.5 WHY

| Motivation | Frequency | Our support |
|---|---|---|
| "I can't find that PDF" | Daily | ❌ No search |
| "I have too many PDFs" | Weekly | ❌ No organization tools |
| "Which version is current?" | Weekly | ⚠️ VersionStore exists |
| "Is this document safe to share?" | Per document | ❌ No pre-share check |
| "What's in my collection?" | Monthly | ❌ No overview |

## 1.6 HOW

| Method | Complexity | Our support |
|---|---|---|
| Manual tagging | Low | ❌ No tag UI |
| Folder organization | Low | ❌ No folder UI |
| Smart folders (rules) | Medium | ❌ No rule engine |
| Full-text search | Medium | ❌ No corpus search |
| AI categorization | High | ❌ No ML pipeline |
| Deduplication | Medium | ❌ DedupDetector exists, no UI |

## 1.7 WHICH (selection among alternatives)

| Alternative | Trade-off | Our choice |
|---|---|---|
| Manual vs auto organization | Manual is reliable, auto is convenient | Both — manual tags + auto metadata |
| Tags vs folders vs both | Tags are flexible, folders are hierarchical | Both — tags for classification, folders for grouping |
| Local vs cloud | Local is private, cloud is accessible | Local-only (privacy doctrine) |
| Per-document vs corpus-wide | Per-document is simple, corpus-wide is powerful | Start per-document, expand to corpus |

## 1.8 WHOSE (ownership)

| Owner | Responsibility | Our support |
|---|---|---|
| Document owner | Tags, folders, ratings | ❌ No UI for these |
| App | Auto-metadata, dedup detection | ⚠️ Engine exists, no surface |
| System | File system organization | ❌ No integration |

## 1.9 WHOM (recipient)

| Recipient | Need | Our support |
|---|---|---|
| The user themselves | Find their own documents | ❌ No search |
| Team members | Shared document access | ❌ No collaboration (COLLABORATE is separate) |
| Auditors | Compliance verification | ❌ No governance dashboard |

## 1.10 HOW MUCH (quantity)

| Metric | Current | Target |
|---|---|---|
| Documents in corpus | 0 (no index) | 1000+ |
| Tags per document | 0 | 10+ |
| Search latency | N/A | < 100ms for 1000 docs |
| Dedup accuracy | N/A | > 90% precision |

## 1.11 HOW MANY (count)

| Count | Current | Target |
|---|---|---|
| Organization features | 0 (engine only) | 8 (search, tags, folders, dedup, recent, starred, smart collections, stats) |
| Index entries | 0 | Dynamic (grows with corpus) |

## 1.12 HOW OFTEN (frequency)

| Action | Frequency | Our support |
|---|---|---|
| Search for document | Daily | ❌ |
| Tag a document | Per document | ❌ |
| Review corpus | Weekly | ❌ |
| Clean up duplicates | Monthly | ❌ |
| Reorganize folders | Monthly | ❌ |

## 1.13 HOW LONG (duration)

| Task | Duration | Our support |
|---|---|---|
| Find a document | < 30 seconds target | ❌ No search |
| Tag a document | < 10 seconds | ❌ No tag UI |
| Review collection | < 5 minutes | ❌ No overview |
| Clean up duplicates | < 10 minutes | ❌ No dedup UI |

## 1.14 HOW FAR (distance/scope)

| Scope | Current | Target |
|---|---|---|
| Single folder | ❌ | ✅ |
| Multi-folder | ❌ | ✅ |
| Entire ~/Documents | ❌ | ✅ |
| External drives | ❌ | ❌ (out of scope) |

## 1.15 WHAT IF (counterfactuals)

| Scenario | Impact | Our support |
|---|---|---|
| User has 1000+ PDFs | Can't find anything | ❌ No search |
| User loses a document | No recovery | ⚠️ History tracked |
| User shares wrong version | Compliance risk | ⚠️ VersionStore exists |
| User violates retention policy | Legal risk | ❌ No governance |

## 1.16 WHAT ELSE (omitted possibilities)

| Possibility | Value | Our support |
|---|---|---|
| Document relationship mapping | High | ❌ |
| Usage analytics (which docs are read most) | Medium | ❌ |
| Auto-backup of document collection | High | ❌ |
| Corpus health dashboard | Medium | ❌ |

## 1.17 WHAT CHANGED (delta over time)

| Change | When | Impact |
|---|---|---|
| DocumentIndex engine built | 2026-08-28 | Foundation ready |
| No UI for index | Current | Major gap |
| In-session operation ledger | 2026-08-25 | VERSION foundation |

## 1.18 COMPARED WITH WHAT (baseline)

| Comparator | Their approach | Our approach |
|---|---|---|
| Finder (macOS) | File system browsing | ❌ No equivalent |
| Eagle (designer) | Visual library with tags | ❌ No visual library |
| Zotero (researcher) | Academic reference manager | ❌ No reference features |
| Devonthink (power user) | AI-powered document management | ❌ No AI |
| Acrobat (enterprise) | Portfolio + catalog | ❌ No catalog |

## 1.19 UNDER WHAT CONDITIONS (constraints)

| Constraint | Impact | Our response |
|---|---|---|
| Privacy doctrine | No cloud, no accounts | Local-only index |
| No external services | No AI categorization | Rule-based only |
| Performance | Index must be fast | SQLite or in-memory |
| Storage | Index must not duplicate files | Store metadata only |

## 1.20 ACCORDING TO WHOM (provenance)

| Source | Claim | Evidence tier |
|---|---|---|
| User research | "I can't find my PDFs" | Inferred (no formal research) |
| Competitor analysis | Eagle, Devonthink, Zotero all have organization | Observed |
| DocumentIndex code | Engine exists and compiles | Verified |

## 1.21 WITH WHAT CONFIDENCE (uncertainty)

| Claim | Confidence | What would increase it |
|---|---|---|
| DocumentIndex is sufficient for 1000 docs | Medium | Benchmark test |
| Tag system is complete | Low | User testing |
| Dedup algorithm is accurate | Low | Corpus testing |

## 1.22 SO WHAT (significance)

| Implication | Priority |
|---|---|
| Without organization, the app is a single-document tool | HIGH |
| Organization is the gateway to the Manager archetype | HIGH |
| Corpus search is the #1 missing feature for power users | HIGH |

---

# 2. VERSION — "I need to track changes and compare versions"

## 2.1 WHO

| Persona | Core need | Expertise | Frequency | Our support |
|---|---|---|---|---|
| Author | Track drafts of a document | Basic | Per edit session | ⚠️ In-session undo/redo |
| Reviewer | Compare two versions side-by-side | Basic | Per review | ⚠️ DiffComparisonView exists |
| Lawyer | Prove document was not altered | Legal | Per document | ⚠️ Operation ledger + digest |
| Compliance officer | Audit document changes | Regulatory | Monthly | ⚠️ Audit trail exists |
| Developer | Track programmatic changes | Technical | Per build | ⚠️ Operation ledger |
| Student | Revert to earlier draft | Basic | Per study session | ⚠️ Undo exists |
| Editor | Compare edits from multiple contributors | Editorial | Per review cycle | ❌ No multi-contributor versioning |
| Archivist | Maintain version history for long-term storage | Archival | Per document | ❌ No persistent version store |

## 2.2 WHAT

| Object | Versioning challenge | Our capability | Gap |
|---|---|---|---|
| Single document | Track edits over time | ⚠️ Operation ledger (in-session only) | Medium — need persistent store |
| Version snapshots | Named points in time | ⚠️ VersionSnapshot exists, no persistence | Small — need disk persistence |
| Version comparison | Diff between two versions | ⚠️ DiffComparisonView exists | Small — need version selector |
| Revert | Go back to a previous version | ❌ No revert implementation | Large — need revert engine |
| Provenance | Who changed what, when | ⚠️ Operation ledger tracks this | Small — need to surface |
| Branch | Parallel edits on same document | ❌ No branching model | Large — deferred |
| Merge | Combine changes from two branches | ❌ No merge model | Large — deferred |
| Audit log | Complete history of all changes | ⚠️ Value-free audit exists | Small — need persistent log |

## 2.3 WHEN

| Phase | What happens | Our support |
|---|---|---|
| First edit | User makes a change | ⚠️ Operation recorded in ledger |
| Multiple edits | User accumulates changes | ⚠️ Ledger grows |
| Review | User wants to see what changed | ⚠️ DiffComparisonView |
| Revert | User wants to undo multiple changes | ❌ No revert |
| Compare | User wants to compare two versions | ⚠️ Diff view exists |
| Share | User shares a specific version | ❌ No version export |
| Audit | User needs to prove document history | ⚠️ Ledger + digest |

## 2.4 WHERE

| Context | Versioning need | Our support |
|---|---|---|
| In-session | Undo/redo | ✅ Works |
| Across sessions | Persistent version history | ❌ Not persisted |
| Across devices | Version sync | ❌ No sync (privacy) |
| Export | Share a specific version | ❌ No version export |

## 2.5 WHY

| Motivation | Frequency | Our support |
|---|---|---|
| "I made a mistake, go back" | Per session | ⚠️ Undo works |
| "What changed since last time?" | Per session | ⚠️ Diff view |
| "Prove this document wasn't altered" | Per document | ⚠️ Digest exists |
| "Compare my edit with the original" | Per edit | ⚠️ Diff view |
| "Who made this change?" | Per audit | ⚠️ Ledger tracks |

## 2.6 HOW

| Method | Complexity | Our support |
|---|---|---|
| Undo/redo | Low | ✅ Works |
| Named snapshots | Medium | ⚠️ VersionSnapshot exists |
| Full document copies | High (storage) | ❌ Not implemented |
| Operation replay | Medium | ⚠️ Ledger supports this |
| Content-addressable storage | High | ❌ Not implemented |

## 2.7–2.22 Summary

The VERSION job is the **most complete** of the three Manager jobs. The engine is solid — operation ledger, digests, DiffComparisonView, VersionSnapshot all exist. The main gap is **persistence** (versions don't survive app restart) and **revert** (no way to actually go back to a previous version).

**Key insight:** The in-session operation ledger IS a version store. Making it persistent is the highest-leverage single change.

---

# 3. GOVERN — "I need to enforce policies and audit compliance"

## 3.1 WHO

| Persona | Core need | Expertise | Frequency | Our support |
|---|---|---|---|---|
| Compliance officer | Ensure documents meet regulations | Regulatory | Weekly | ❌ No governance UI |
| IT administrator | Enforce encryption, access control | Technical | Monthly | ⚠️ Encrypted vault exists |
| Legal counsel | Verify document integrity | Legal | Per document | ⚠️ Signature verification |
| Privacy officer | Ensure data handling compliance | Privacy | Weekly | ⚠️ Privacy provenance exists |
| Manager | Oversee team document practices | Business | Weekly | ❌ No dashboard |
| Auditor | Review document handling history | Audit | Quarterly | ⚠️ Audit trail exists |
| Security engineer | Monitor for unauthorized access | Technical | Daily | ❌ No monitoring |
| End user | Know their document is safe | Basic | Per document | ⚠️ Encryption status shown |

## 3.2 WHAT

| Object | Governance challenge | Our capability | Gap |
|---|---|---|---|
| Retention policies | Auto-delete old documents | ❌ PolicyRule exists, no engine | Large |
| Access control | Who can open/edit/export | ❌ PolicyRule exists, no enforcement | Large |
| Encryption | Ensure documents are encrypted | ⚠️ Encrypted vault exists | Small — need policy link |
| Annotation governance | Control who can annotate | ❌ No annotation policies | Medium |
| Export governance | Control what can be exported | ❌ No export policies | Medium |
| Size limits | Prevent oversized documents | ❌ PolicyRule exists, no enforcement | Small |
| Compliance audit | Track all policy evaluations | ⚠️ GovernanceEngine exists, no UI | Medium |
| Violation alerts | Notify when policies are breached | ❌ No alert system | Large |
| Policy templates | Pre-built policies for common regulations | ❌ No templates | Large |
| Dashboard | Overview of compliance status | ❌ No dashboard | Large |

## 3.3 WHEN

| Phase | What happens | Our support |
|---|---|---|
| Document opened | Check encryption, permissions | ⚠️ PDFPermissionsSummary |
| Document edited | Check annotation/export policies | ❌ |
| Document exported | Check export governance | ❌ |
| Periodic review | Audit all documents | ❌ No audit UI |
| Policy violation | Alert and remediate | ❌ No alert system |
| Retention check | Auto-archive/delete old docs | ❌ No retention engine |

## 3.4–3.22 Summary

The GOVERN job has the **most engine code but the least user-facing surface**. DocumentPolicy (324 lines) defines rule types, the GovernanceEngine evaluates policies, and violations are tracked. But there's no way for a user to:
- Create or edit policies
- See which documents violate which policies
- Get alerts when violations occur
- Run compliance audits
- Use policy templates

**Key insight:** The privacy doctrine constrains GOVERN significantly. The app can't monitor user behavior or phone home. Governance must be local, transparent, and opt-in.

---

# 4. Cross-Job Analysis

## 4.1 Dependencies

```
ORGANIZE ← depends on → VERSION (version history is organizational metadata)
VERSION ← depends on → ORGANIZE (versions need to be findable)
GOVERN ← depends on → ORGANIZE + VERSION (policies apply to indexed documents with history)
```

## 4.2 Implementation Priority

| Priority | Job | Reason |
|---|---|---|
| 1 | VERSION | Most complete engine; persistence + revert is highest leverage |
| 2 | ORGANIZE | Second-most complete; search is #1 user need |
| 3 | GOVERN | Most engine code, least user need; defer to companion |

## 4.3 Architecture Implications

| Implication | Impact | Action |
|---|---|---|
| Corpus-centric, not document-centric | Index, version store, policy engine needed | Build persistent index |
| Failure is per-item, not all-or-nothing | Individual document failures don't block corpus | Design for partial success |
| Power comes with consent | GOVERN/ORGANIZE/VERSION all gated | Match §8 capability activation |
| Privacy stays value-free | Audit records actions, not content | Already enforced |
| They multiply existing strength | batch × incremental writer, script × harnesses | Design for composition |

## 5. What Exists vs What's Needed

| Component | Lines | Exists | UI | Priority |
|---|---|---|---|---|
| DocumentIndex | 303 | ✅ Engine | ❌ No | HIGH |
| VersionStore | 233 | ✅ Engine | ❌ No | HIGH |
| DocumentPolicy | 324 | ✅ Engine | ❌ No | MEDIUM |
| GovernanceEngine | (in DocumentPolicy) | ✅ Logic | ❌ No | MEDIUM |
| DedupDetector | (in DocumentIndex) | ✅ Logic | ❌ No | MEDIUM |
| CorpusSearch | (in DocumentIndex) | ✅ Logic | ❌ No | HIGH |
| DiffComparisonView | (existing) | ✅ View | ✅ Yes | DONE |
| OperationLedger | (existing) | ✅ Engine | ⚠️ Internal | DONE |
| AuditTrail | (existing) | ✅ Engine | ❌ No | LOW |

## 6. Open Questions

1. Should the index be SQLite-backed for performance, or pure in-memory Codable?
2. Should VERSION persistence use the operation ledger (replay) or full snapshots (copy)?
3. Should GOVERN be deferred to the companion architecture (requires external enforcement)?
4. Should ORGANIZE include Spotlight integration (requires macOS entitlements)?
5. How should cross-document search work — index all text at index time, or search on demand?
6. Should the Manager archetype have its own toolbar/mode, or be accessed from existing UI?

## 7. Implementation Roadmap

### Phase 1 — VERSION Persistence (highest leverage)
- Persist VersionStore to disk (Codable + file)
- Add revert UI (select version → apply)
- Add version comparison UI (select two versions → diff)

### Phase 2 — ORGANIZE Surface
- Corpus search (index text at index time, search on query)
- Tag/folder management UI
- Recent/starred collections
- Dedup detection UI

### Phase 3 — GOVERN Dashboard
- Policy editor (create/edit/enable rules)
- Compliance dashboard (violations by severity)
- Retention engine (auto-archive based on rules)
- Audit log viewer

### Phase 4 — Advanced
- Smart collections (rule-based auto-grouping)
- Corpus statistics dashboard
- Cross-document relationships
- Policy templates for common regulations
