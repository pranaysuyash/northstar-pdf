# Personas & Jobs — Expanded Model (Beyond Reader/Creator)

**Date:** 2026-08-26
**Status:** First-principles model extension. Supersedes the implicit "Reader vs Creator" binary in earlier docs.
**Extends:** `pdf-reader-jtbd-first-principles-2026-08-26.md` (6 core jobs), `jtbd-01-read-layouts-and-modes-2026-08-26.md` (content-routed modes)
**Doctrine alignment:** §8 (capability routing — persona/mode-aware), §3 (do things smartly)

---

## 1. The False Binary

Earlier analysis split users into "Reader" and "Creator". That is wrong in two ways:

1. **It is not a binary** — engagement, direction, and document type each vary independently.
2. **It misses whole jobs** — signing is neither reading nor creating; consuming magazines is not "reading a form".

A persona is not a fixed label. It is a **position in a three-axis space**:

| Axis | Values | What it changes |
|---|---|---|
| **Intent** (what outcome the user wants) | Consume, Understand, Act, Produce, Govern | Which job fires |
| **Direction** (how value flows) | Extract (from doc) / Add (to doc) / Commit (bind to doc) | Read vs Create vs Sign |
| **Document type** (what the content is) | Text / Form / Graphic (comic) / Table / Mixed | Which mode routes |

---

## 2. The Expanded Job Taxonomy (19 jobs)

The original 6 jobs were reader-centric. The full model:

| # | Job | User statement | Direction | Depth | Persona |
|---|---|---|---|---|---|
| J1 | **CONSUME** | "I want to take in this content" | read-only | passive | Consumer |
| J2 | **READ** | "I want to understand this content" | read-only | active | Reader |
| J3 | **LEARN** | "I want to retain this content" | read-only | study | Student |
| J4 | **FIND** | "I want to locate specific info" | read-only | active | Any |
| J5 | **UNDERSTAND** | "I want to know what this means / requires" | read-only | analytic | Analyst |
| J6 | **INTERACT** | "I want to fill/operate this form" | add | active | Form-filler |
| J7 | **COMMIT** | "I want to bind myself/others to this" | bind | decisive | Signer |
| J8 | **CREATE** | "I want to produce a document" | produce | generative | Author |
| J9 | **TRANSFORM** | "I want to modify an existing document" | add | manipulative | Editor |
| J10 | **SHARE** | "I want to move this to others" | move | — | Communicator |
| J11 | **PROTECT** | "I want to secure this document" | add | — | Guardian |
| J12 | **GOVERN** | "I want to manage this across its life" | add | — | Manager |
| J13 | **ORGANIZE** | "I need to find this again later" | move | — | Manager |
| J14 | **VERSION** | "I want to track how this changed" | add | — | Manager |
| J15 | **BATCH** | "I need to do this to many documents" | meta | — | Power |
| J16 | **SCRIPT** | "I want to automate this workflow" | meta | — | Power |
| J17 | **INTEGRATE** | "I want this to talk to my other systems" | meta | — | Power |
| J18 | **ANNOTATE** | "I want to mark up and comment on this document" | add | analytic | Reviewer |
| J19 | **COLLABORATE** | "I want to work with others on this document" | move | social | Collaborator |

The original 6 (READ, FIND, UNDERSTAND, INTERACT, SHARE, PROTECT) remain the **reader-archetype core**. J13-J17 (Manager & Power) are analyzed in depth in §9-§10; J18-J19 and J3 (LEARN) in §11.

---

## 3. Signing = COMMIT (the "third persona" question)

**Question:** is signing READ or CREATE? **Answer: neither — it is a third job, COMMIT.**

### Why it is not READ
Reading ends at understanding. Signing requires **deciding and binding**. The success criteria are different:
- READ succeeds when the reader *understands* ("I get it")
- COMMIT succeeds when the signer *binds* ("I accept; this is now enforceable")

### Why it is not CREATE
Creating produces a *document*. Signing produces a *commitment* — it modifies the document's **legal state**, not its content. The artifact (the signature) is secondary; the outcome (binding intent) is primary.

### The COMMIT job flow
```
Verify identity → Verify document integrity → Understand what I'm binding to
→ Express intent (sign) → Verify the signature → Store the proof
```

### Persona: the Signer
| Attribute | Value |
|---|---|
| Trigger | "I need to agree / approve / authorize" |
| Anxiety | "Am I binding myself to something I don't understand?" |
| Needs | Integrity verification, clear terms, irreversible-action warning, audit trail |
| Frequency | Rare but high-stakes |

### Product implications (what a COMMIT lane must have)
- **Integrity-first**: signature must fail loudly if the document changed after review (ByteRange guard — already implemented)
- **Consent clarity**: show the exact binding text before signing
- **Proof**: verifiable signature + audit record
- **Recovery**: undo of intent, not just undo of pixels

*Note: signing is sometimes bundled under INTERACT (it is a form of interaction), but its *purpose* (binding) is distinct from filling (data entry). The app already has a signature sheet; the gap is the COMMIT framing — consent, verification, audit.*

---

## 4. The Consumer Persona (J1 CONSUME)

**"I could just be a consumer — read magazines, skim, not engage, or read comics."**

The Consumer reads for pleasure/awareness, not for work. Characteristics:

| Attribute | Value |
|---|---|
| Documents | magazines, comics, news, novels, catalogs |
| Engagement | passive — no annotations, no forms, no editing |
| Depth | skim → casual read → (rarely) deep |
| Success | "I enjoyed it", "I know what's new", "I kept my place" |
| Failure | janky scroll, blurry pages, lost position, aggressive chrome |

### Product implications
- **Chrome-first design**: hide toolbars/inspectors by default; the document is the page
- **Dark mode** (critical for leisure reading — the #1 gap)
- **Position persistence** (✅ done — page/zoom/scroll)
- **Page-fit & full-bleed** rendering (magazines are designed as spreads)
- **Zero-friction**: no "mode switching", no permission dialogs
- **No forced interaction**: never prompt to fill/sign/annotate

---

## 5. Comic / Graphic Reading — a Distinct Mode (NOT "read")

Comics are **not text reading**. They are *visual flow* reading. The difference is structural:

| Dimension | Text PDF | Comic PDF |
|---|---|---|
| Content unit | Paragraph | Panel |
| Reading order | Top-left → bottom-right (or RTL) | **Panel order** (can be RTL, diagonal, layered) |
| Zoom | Text reflows / scales | **Panel zoom** (tap a panel → fill screen) |
| Layout | Flows | **Fixed, full-bleed, art-directed** |
| Color | Secondary | **Primary** (ink fidelity, color accuracy) |
| Two-page | Optional | **Spread-critical** (left-right reading) |
| Reflow | Possible | **Never** — would destroy the art |

### The comic reading mode (J1 CONSUME + graphic document type)
- **Page-fit** with full-bleed (no margins on the art)
- **Panel navigation**: tap to zoom into a panel, tap again to advance
- **Right-to-left** option (manga)
- **Spread view** for two-page art
- **Color-accurate rendering** (no whitewashing, no compression artifacts)
- **Position memory per page** (already have the mechanism)

### Why this matters architecturally
The rendering pipeline we just built (tile-based display, viewport tracking) is the *exact* foundation for panel zoom and spread view. Comic mode is a **routing decision** — same rasterizer, different display rules. This is §8 capability routing made concrete.

---

## 6. Persona × Job × Mode Matrix

| Persona | Primary job | Document type | Routing mode |
|---|---|---|---|
| Consumer (magazine) | CONSUME | Mixed text+image | Chrome-first, spread, page-fit |
| Consumer (comic) | CONSUME | Graphic | Comic mode: panel zoom, RTL, full-bleed |
| Reader | READ | Text | Standard reader |
| Student | LEARN | Text | Study mode (annotate, highlight, position) |
| Analyst | UNDERSTAND | Text/table | Extract mode (tables, entities, key points) |
| Form-filler | INTERACT | Form | Form mode (field nav, validation) |
| Signer | COMMIT | Form/legal | Sign mode (consent, integrity, audit) |
| Author | CREATE | Any | Editor |
| Editor | TRANSFORM | Any | Edit mode with diff |
| Guardian | PROTECT | Any | Security mode |

**Key rule:** the *document type* and the *persona* together select the *mode*. Neither alone is enough. A consumer reading a legal PDF still needs sign mode; a lawyer reading a comic still wants comic mode.

---

## 7. What This Changes in the Product

| Existing piece | What the expanded model adds |
|---|---|
| Rendering pipeline | Comic mode / panel zoom / spread — tile renderer foundation |
| Reading position persistence | Consumer needs it as *the* feature, not a nicety |
| Dark mode (gap R-05) | Now **the** consumer requirement |
| Signature sheet | Reframe as COMMIT: consent + integrity + audit |
| Content-routed modes (layouts doc) | Now persona-routed too — route on persona × document |
| Capability routing (§8) | The activation opt-in now has a *routing key*: persona × document |

---

## 8. Open Questions (recorded, not resolved)

*Resolved since first writing:*
- ~~**Is ANNOTATE its own job?**~~ → **Yes** — J18, the Reviewer persona exists (see §11.1)
- ~~**Is LEARN distinct from UNDERSTAND?**~~ → **Yes** — comprehension-now vs. retention-later (see §11.3)

*Still open:*
1. **Comic panel detection** — requires raster analysis (panel boundaries via whitespace/line detection). Feasible, unbuilt.
2. **Per-document persona memory** — should the app remember "this is a comic" vs "this is a form"? (connects to layout restore RG-057)

*Resolved-then-reopened:*
3. **ANNOTATE storage** — in-PDF vs. sidecar (moved to §14 Q9)

---

## 9. Manager User — ORGANIZE, VERSION, GOVERN

> "I need to organize, track, and govern documents."

The Manager acts on the **corpus** (the set of documents), not on content within a document. This is the biggest architectural shift in the model: everything so far is document-centric; Manager jobs are corpus-centric.

### 9.1 J13 ORGANIZE — "I need to find this again later"

| Dimension | Value |
|---|---|
| Success | A document is findable in seconds when needed again |
| Failure | Documents pile up; search misses; duplicates thrive |
| Frequency | Daily, low-intensity |

**What it needs:**
- A document **index** (folders, tags, saved searches) independent of the filesystem
- **Corpus search** — across documents, not within one (extends FIND from in-doc to cross-doc)
- Metadata (title, author, dates, page count) extracted at open-time and stored
- Deduplication / similarity detection

**Relationship to FIND:** FIND = locate *within* a document (J4). ORGANIZE = locate *across* documents (J13). They share search tech but differ in scope: one page-range vs. one index.

**Current status:** ❌ No library, tags, or saved searches. Search is in-document only.

### 9.2 J14 VERSION — "I want to track how this changed"

| Dimension | Value |
|---|---|
| Success | Know what changed, when, and by whom — and be able to go back |
| Failure | "Which version is this? Did I lose that edit?" |
| Frequency | Episodic, high-stakes |

**What it needs:**
- **Snapshots**: a version store (either incremental diffs or full copies at checkpoints)
- **Comparison**: exists for source-vs-current (diff view + side-by-side) — extends to version-vs-version
- **Revert**: restore a previous version safely (never overwrite current silently)
- **Provenance**: who/when/what changed per version (audit-aligned, value-free metadata per existing privacy design)

**Documented foundation:** the app already keeps an **operation ledger** (undo/redo, recovery records). VERSION is the *persistent* generalization of that in-session ledger: keep the ledger across sessions as the version history.

**Current status:** ✅ Substantial — `EditOperation` ledger (id, pageIndex, kind, value, bounds, previousValue, createdAt, sessionID, sourceDigest, reversible, destructive) + undo/redo + `operationLedgerDigest` + `RecoveryEnvelope` + `DiffComparisonView` (source-vs-current diff). **`VersionStore` (2026-08-27)** adds persistent snapshots, version-vs-version comparison, revert ops, and digest verification. Remaining: UI for version history panel, per-document version memory, revert button in diff view.

### 9.3 J12 GOVERN — "I want to manage this across its life"

| Dimension | Value |
|---|---|
| Success | Policy is applied consistently; access is controlled; nothing is kept past its time |
| Failure | Over-retention, unauthorized access, missed compliance deadlines |
| Frequency | Continuous, background |

**What it needs:**
- **Access control** — who may open/print/copy (PDF permission flags are enforced today; user-level policy is not)
- **Retention policies** — documents expire or archive after a rule (e.g. 7 years)
- **Compliance** — audit logs that prove policy was followed

**Distinction from PROTECT:** PROTECT (J11) secures a *single document* (encryption, redaction). GOVERN applies *policy across the corpus*: rules, schedules, audits. The SecurityVault + password handling is PROTECT; a retention schedule is GOVERN.

**Privacy-boundary note:** audit logging must remain **value-free** — the repo already has tests asserting recovery/audit records carry no document content ("value-free" design). GOVERN inherits that constraint: prove policy without storing content.

**Current status:** ⚠️ Partial — permission enforcement + vault exist; **no retention, no policy engine, no compliance audit**.

---

## 10. Power User — BATCH, SCRIPT, INTEGRATE

> "I need batch and programmatic control."

The Power user treats the app as an **engine**, not a surface. These are **meta-jobs**: they multiply other jobs (fill, protect, share) across many documents or many repetitions.

### 10.1 J15 BATCH — "I need to do this to many documents"

| Dimension | Value |
|---|---|
| Success | 50 forms filled, 200 files checked, in minutes, reliably |
| Failure | Clicking the same UI 50 times; one bad file aborts the run |
| Frequency | Periodic, time-boxed |

**First principle:** BATCH is a **multiplier**, not a feature. It applies to every other job:
- BATCH × INTERACT = batch fill (fill 100 forms from a data source)
- BATCH × PROTECT = batch redact/encrypt (redact all SSNs in 50 files)
- BATCH × SHARE = batch export/convert
- BATCH × FIND = corpus scan ("which docs contain this clause?")

**What it needs:**
- A **batch pipeline**: input set → per-item job → outcome report (per-item success/failure, never all-or-nothing)
- A **driver**: the current single-document operations must be parameterizable (inputs, outputs, options) so the batch runner can call them
- **Isolation**: one item's failure must not corrupt the run (atomic per-item semantics — the incremental writer's source-preservation guarantee extends naturally)

**Current status:** ⚠️ Partial — `BatchMergeSheet` (merge), `PdfCpuBatchProcessor` (external tool core), batch operations in the model. **No general batch pipeline** for arbitrary jobs; no per-item outcome reporting.

### 10.2 J16 SCRIPT — "I want to automate this workflow"

| Dimension | Value |
|---|---|
| Success | "It runs itself every week" |
| Failure | Manual repetition; process drift |
| Frequency | Set-once, run-forever |

**First principle:** SCRIPT is BATCH plus **expressiveness and scheduling** — reusable, composable, versionable workflows instead of one-off runs.

**What it needs:**
- A **surface**: CLI or scriptable entry point for core operations (open, validate, fill, redact, export, merge)
- **Workflow composition**: chain steps with conditions ("if the form validates, fill it; then export")
- **Resource bounds**: sandboxed execution (time, memory, file access) — a script must not be able to damage the corpus
- **Audit**: script runs recorded (value-free, per GOVERN)

**Current status:** ⚠️ Partial — `AgentCommandHUD` provides a user-facing command palette with searchable commands, keyboard navigation, and categorized actions. Internal harnesses (`PDFRecoveryInterruptionHarness`, `PDFContractHarness`, etc.) prove scriptability within the codebase; external tools wrapped (`qpdf`, `pdfcpu`, `pdf_oxide`). **No scheduler, no resource sandbox, no user-defined workflows** — the HUD is point-in-time commands, not composable scripts.

**Doctrine tension:** scripting power vs. safety. Resolution per doctrine: capability activation is **opt-in** — a scripting lane that is off by default, enabled by a conscious user action, matches the existing capability-activation pattern.

### 10.3 J17 INTEGRATE — "I want this to talk to my other systems"

| Dimension | Value |
|---|---|
| Success | Documents flow: email → review → approve → archive, with the app as the processing core |
| Failure | Copy-paste between systems; re-processing by hand |
| Frequency | Continuous, background |

**What it needs:**
- **Interfaces**, not embedded apps: file formats in/out (already: PDF, image, clipboard, markdown-in); hooks (open-with, drag-drop) |
- **Connections** (email, DMS, cloud) — **this is the doctrine-critical one**

**The privacy boundary (first principle):** the app's core promise is **zero egress by default** (enforced by egress-assertion tests). INTEGRATE must not erode that:
- Every connection is **opt-in, per-connection, with consent** (not a global "allow network")
- The core engine stays offline; only explicitly connected lanes may egress
- Exports are the integration bridge: "export to folder / format" is INTEGRATE's safe surface

**Current status:** ⚠️ Minimal by design — file importer/exporter + clipboard/markdown/image intake. **No external connections** (correct per privacy doctrine); the design question is which opt-in bridges are worth building.

---

## 11. Reader-Adjacent Jobs — ANNOTATE (J18), COLLABORATE (J19), LEARN (J3)

> "Even within Reader, we may have missed jobs." — analysis of the three candidates

### 11.1 J18 ANNOTATE — "I need to mark up and comment on this document"

**Resolves open question #1: ANNOTATE is its own job, not a mode of READ.** There is a persona whose *primary* purpose is annotation: the **Reviewer** (lawyer reviewing a contract, editor marking a manuscript, teacher grading). For them, reading is the means; the markup is the end.

| Dimension | Value |
|---|---|
| Success | My marks survive, are findable, and can travel (export / share) |
| Failure | Marks lost, can't search notes, can't extract them cleanly |
| Frequency | Reviewers: daily; general readers: occasional |

**Distinction from INTERACT (J6):** INTERACT *operates* the document (fills fields, changes data). ANNOTATE *adds a commentary layer* that changes no document data. Filling a form mutates the document's state; highlighting a clause only adds meaning.

**What it needs:**
- Highlight / underline / note / sticky — the core markup kit
- **Search within annotations** (find my own notes)
- **Annotation export** (with or without the document: a review sheet)
- **Layers** — personal vs. shared (by author, by color, by date)
- **Reply / thread** on a mark (a note attached to a highlight that others can respond to — this is where ANNOTATE connects to COLLABORATE)

**Current status:** ⚠️ Basic — the app has fill, signature, and inline-text placement (which are INTERACT/CREATE, not ANNOTATE), and a diff-overlay. **No highlight/note/comment system, no annotation search, no annotation export.**

### 11.2 J19 COLLABORATE — "I need to work with others on this document"

**Resolves the last open model gap: documents are social artifacts.** Review cycles, approval chains, shared feedback — people rarely read *alone* in professional life.

| Dimension | Value |
|---|---|
| Success | "We reached agreement on this document" — opinions exchanged, version clear |
| Failure | Version chaos, feedback lost, "who said what" unknown |
| Frequency | Reviewers: weekly; teams: continuous |

**Distinction from SHARE (J10):** SHARE moves the document *one way* (send it). COLLABORATE moves **meaning back and forth** (annotated copies, merged feedback, threaded discussion).

**The doctrine tension (first principles):** collaboration conventionally implies cloud/shared state — which collides with the local-first, **zero-egress** promise (enforced by egress tests). Resolution, in order of doctrine-safety:

1. **File-level collaboration** (safest, local-first): export an annotated copy → the other party annotates → import and **merge feedback**. The diff and merge infrastructure (`DiffComparisonView`, `BatchMergeSheet`) is already the skeleton. This is async track-changes, no cloud, never leaves the machine.
2. **LAN peer-to-peer** (local, but egress beyond the app): drafts/shared state over local network — still no internet, but more plumbing and a consent gate.
3. **Opt-in sync service** (violates local-first unless explicitly user-chosen): a conscious, per-account activation — matches §8 capability activation, but is a *future* decision, not a default.

**First-principles recommendation:** build (1) file-level merge first — it reuses the diff/merge core, preserves the privacy promise, and validates whether users even need (2)/(3).

**Current status:** ⚠️ Partial — diff + side-by-side + merge sheets exist (single-user). **No multi-user annotations, no feedback merging, no shared state.**

### 11.3 J3 LEARN — "I need to study and retain this content"

**Resolves open question #2: LEARN is distinct from UNDERSTAND.** UNDERSTAND is *comprehension now*; LEARN is *retention later*. Different success metric (recall next week vs. grasp this minute), different product surface (extraction tools vs. review/study tools).

| Dimension | Value |
|---|---|
| Success | "I remember this after I close it" — recall next week, next month |
| Failure | "I read it but retained nothing" |
| Frequency | Students: daily, cyclical; professionals: certificate/Onboarding study |
| Persona | Student (J3 primary); Reviewer (as a secondary) |

**The study loop (first principles):**
```
Consume → Mark (highlight/note the important parts)
→ Review (revisit marks, not the whole doc)
→ Retrieve (test recall: hide text, ask "what did it say?")
→ Retain (spaced repetition of marked items)
```
Each stage needs a different surface: marking needs ANNOTATE (J18); reviewing needs a marks-only view; retrieval needs a quiz/recall mode; retention needs scheduling.

**What it needs:**
- **Marks as first-class** — the highlight/note system from J18 is LEARN's substrate
- **Marks-only review view** — see only what I marked (skip re-reading)
- **Recall mode** — hide a marked passage, prompt recall, reveal
- **Progress indication** — per-document study state (like the fill-progress meter)
- **Spaced repetition** (later) — schedule re-review of marks

**Current status:** ❌ Nothing. No highlight system, no notes, no review view, no recall mode. This is the *largest* unexplored reader-side job — and it is nearly free to begin once J18 (ANNOTATE) lands, because marking is its substrate.

### 11.4 Why these three are a chain, not a list

```
LEARN needs ANNOTATE (marks are the substrate of study)
ANNOTATE needs nothing (standalone markup)
COLLABORATE needs ANNOTATE (feedback is markup that travels)
COLLABORATE needs SHARE + VERSION (a doc must move and be versioned to be reviewed)
```
So the build order is: **ANNOTATE → LEARN → COLLABORATE**. Marking first unlocks both studying and sharing. This is a dependency map, not a priority ranking — but the dependencies are hard.

---

## 12. Meta-Principles (what the 6 Manager/Power jobs share)

1. **Corpus-centric, not document-centric.** ORGANIZE/VERSION/GOVERN/BATCH all treat documents as members of a set with state — requiring an index, a version store, a policy store, and a batch runner beyond the current single-document session model.
2. **Failure is per-item, not all-or-nothing.** The batch per-item outcome report and the version store's forward-only snapshots both encode this.
3. **Power comes with consent.** SCRIPT (opt-in lane), INTEGRATE (opt-in connections), GOVERN (policy the user authored) — every expansion of reach is gated, matching §8 capability activation.
4. **Privacy stays value-free.** Audit (GOVERN), version metadata (VERSION), and batch reports (BATCH) record *what happened*, never document content.
5. **They multiply existing strength.** BATCH × the incremental writer's source-preservation, SCRIPT × the existing harnesses, GOVERN × the existing vault/encryption — these jobs reuse what exists rather than inventing new core engines.

---

## 13. Updated Persona × Job × Mode Matrix (full)

| Persona | Primary job | Secondary | Document scope | Routing mode |
|---|---|---|---|---|
| Consumer (magazine) | CONSUME | — | one doc | Chrome-first, spread |
| Consumer (comic) | CONSUME | — | one doc | Comic mode |
| Reader | READ | ORGANIZE | one doc / corpus | Standard reader |
| Student | LEARN | ORGANIZE | one doc | Study mode |
| Analyst | UNDERSTAND | ORGANIZE | one doc / corpus | Extract mode |
| Form-filler | INTERACT | — | one doc | Form mode |
| Signer | COMMIT | PROTECT | one doc | Sign mode |
| Author | CREATE | VERSION | one doc | Editor |
| Editor | TRANSFORM | VERSION | one doc | Edit + diff |
| Guardian | PROTECT | GOVERN | one doc / corpus | Security mode |
| Reviewer | ANNOTATE | LEARN | one doc | Review mode (marks, comments) |
| Collaborator | COLLABORATE | SHARE / VERSION | one doc / corpus | Review + merge mode |
| Student (study) | LEARN | ANNOTATE | one doc | Study mode (marks, recall) |
| Manager | ORGANIZE / VERSION / GOVERN | BATCH | **corpus** | Library, history, policy views |
| Power | BATCH / SCRIPT / INTEGRATE | — | **corpus** | Batch runner, scripting lane, bridges |

---

## 14. Open Questions (Manager, Power, Reader-Adjacent)

4. **One index or many?** Does ORGANIZE need a real document index (SQLite store) or is a tags/metadata sidecar enough at first?
5. **VERSION storage:** incremental deltas (ledger) vs. full snapshots vs. hybrid — the incremental writer suggests deltas, but revert-safety favors snapshots.
6. **Does SCRIPT precede INTEGRATE?** A scripting surface that can call export/import effectively *is* integration (file-level). Network-level INTEGRATE may never be needed under local-first doctrine.
7. **Which batch jobs first?** BATCH × INTERACT (fill) and BATCH × PROTECT (redact) are the two highest-value multipliers — worth confirming with users before building the general runner.
8. **Where do annotations live?** In-PDF annotation objects (portable, but pollute the doc and can break incremental preservation) vs. a sidecar store (clean, but not portable). The incremental writer's source-preservation promise favors a sidecar or a carefully-written annotation layer.
9. **Which COLLABORATE tier first?** File-level merge (reuses diff + merge, doctrine-safe) vs. LAN sync vs. opt-in cloud. Recommendation: file-level merge first — it validates demand before any egress decision.
10. **Does COLLABORATE subsume SHARE?** SHARE moves the document one way; COLLABORATE moves meaning both ways. They share export/import plumbing, so treat SHARE as COLLABORATE's single-direction subset rather than a separate stack.

---

## 15. Evidence

- `pdf-reader-jtbd-first-principles-2026-08-26.md` — original 6 jobs (superseded in part)
- `jtbd-01-read-*-2026-08-26.md` — READ deep dives
- `jtbd-01-read-layouts-and-modes-2026-08-26.md` — content-routed modes
- `personas-jobs-expanded-model-2026-08-26.md` — this document (sections above)
- `DiffComparisonView`, `BatchMergeSheet` (sources) — COLLABORATE foundation
- `PDFIncrementalFormWriter` (source) — annotation-storage constraint (Q9)
- Signature guard + ByteRange integrity (sources) — COMMIT foundation
- Rendering pipeline (tile display, adaptive zoom) — comic mode foundation
- `Sources/PDFEditorCore/PdfCpuBatchProcessor.swift` — batch foundation
- `Sources/PDFEditorCore/LibraryCascade.swift`, `QPDFValidator.swift`, `PdfOxideExtractor.swift` — external-tool wrappers (SCRIPT foundation)
- Operating Doctrine §8 (capability routing), §3 (do things smartly), §5 (evidence-based)