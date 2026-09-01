# ADHD Exploration Pool Ledger — pdf_editor (all rounds)

**Ledger of record for every ADHD-skill divergent pool run on this repo.**
Currently covers: **Round 1 (2026-08-24)** and **Round 2 (2026-08-30)**.
**Purpose:** convergence in an audit must not destroy divergence — every
candidate from every round is preserved here with a lifecycle status (deepened /
parked-implementable / parked-explorable / parked-conditional / graduated), so
no idea is lost, silently re-derived, or re-proposed as novel. Future rounds
append their pool as a new section (see Update protocol at the end).
**Relationship to canonical registers:** this doc is upstream of
`docs/task-inventory.md` (task state authority per D-055) and
`docs/feature-expansion-inventory.md` (accepted capability program). An idea
**graduates** when someone picks it up: at this point its status here changes to
`graduated` with a pointer, and the real entry is created in the target register.
Nothing in this file asserts gate state or claims a capability is implemented;
follow-through notes record observed code state at registration time and must be
re-verified before pickup.

## Status grammar (extends the inventory's never-permanently-out principle)

- **deepened** — has a verified sketch, risk, first step, and children in the
  round-2 audit §4.
- **parked-implementable** — a first concrete step is evident from current code;
  can be picked up without further research.
- **parked-explorable** — worth a bounded exploration pass before any
  implementation; open design or measurement question remains.
- **parked-conditional** — viable only when a stated condition becomes true;
  otherwise it is a trap under current conditions. The condition is recorded so
  the revisit trigger is explicit. Never interpreted as permanently out of scope.
- **graduated** — promoted into `task-inventory.md` / `feature-expansion-inventory.md`;
  pointer recorded, date recorded.

## Future-round ban list (mechanics, not ideas)

Every future ADHD or divergent-audit round on this repo MUST treat the union of
the round-1 pool (2026-08-24, "Round 1 pool" below), the round-2 pool
(2026-08-30, "Round 2 pool" below), and all future appended pools as
"already-known": not banned from re-angle, but banned from being presented as
new. Check this file before generating, and append the new round's pool here.
This requirement is codified in the adhd skill itself
(`~/.zcode/skills/adhd/SKILL.md`, Persistence section).

---

## Round 1 pool (2026-08-24)

**Source:** `docs/audits/comprehensive-adhd-audit-2026-08-24.md` — the full pool
is preserved verbatim there (§3 frames with scores and notes, §4 clusters, §5
converge + traps, §6 deepened branches, §10 explicit tasks T-001..T-030 and
implicit explorations E-001..E-015). Frames: Regulator, 10-year-old, Competitor,
Game Design, Infinite Budget. This section holds the lifecycle statuses only;
the round-1 doc remains the reasoning record.

**Status verification basis:** code greps + doc cross-references at
registration (2026-08-30). Items marked *verify* were not independently
re-checked and must be confirmed before pickup.

### Round 1 idea statuses (30)

| ID | Idea (short) | Status at 2026-08-30 |
|---|---|---|
| R1 | Immutable audit-trail export | parked-implementable (T-019 open; round-2 §5 provocation "evidence receipt" builds on it) |
| R2 | Compliance-report toggle | parked-implementable |
| R3 | Proof-of-no-change certificates | parked-implementable (impact validator computes the inputs informally; no first-class artifact) |
| R4 | Redaction certification workflow | parked-conditional (RG-014 claim-blocked) |
| R5 | Chain-of-custody tracking | parked-implementable (operation log exists) |
| R6 | Tamper-evident export format | parked-explorable (PDF-metadata embedding design needed) |
| Y1 | Camera capture → fill | parked-conditional — TRAP (silent autofill rejected by architecture; E-009 safe-version exploration only) |
| Y2 | Profile bulk fill | **partial — `Sources/PDFEditorCore/ProfileStore.swift` exists** (T-002 landed); "Fill all from profile" UX (T-004) *verify* |
| Y3 | Template sharing (layout only) | open (T-029; *verify* against encrypted companion-export work) |
| Y4 | Re-match on form version change | partial — TemplateProfileResolver emits exact/variant match proposals; "new version detected" UX flow (T-024) open |
| Y5 | Visual diff view | open (T-018) |
| Y6 | Visible learning from corrections | partial — learning events exist; visible behavior *verify* |
| C1 | Surface parity mismatches in UI | partial — classification landed (`docs/audits/accepted-variance-registry-2026-08-28.md`, 14 categories, T-005 done); UI surfacing open |
| C2 | Position as proof-of-change tool | adopted — market-strategy thesis |
| C3 | Per-document detector training feedback | partial — CandidateReviewLearningEvents + CandidatePriorScorer (per-document priors); round-2 B1 children extend to class level |
| C4 | Browser core useful without companion | standing principle (already architecture per round-1 §3) |
| C5 | Template passphrase recovery | open *verify* (recovery path explicitly open per round-1; encrypted-vault audit 2026-08-26 may have findings) |
| C6 | Cut gate list to 15 hard gates | rejected (doctrine — D-055 concentrates gate authority; gate list retained) |
| G1 | Completion score/progress | open |
| G2 | Smart next blank (evidence-ranked) | partial — Guided Next Blank exists; evidence-ranking open |
| G3 | Template speedrun metrics | partial — ReviewedCompletionMetrics exist; improvement-over-time visualization open |
| G4 | Save state / resume | **graduated — implemented.** `SessionStore.swift` writes `.pdfedit` sidecars + `SessionRecoveryStore.swift` (exactly the Branch-1 sketch; encrypted-session evidence 2026-08-25) |
| G5 | Document difficulty rating | open |
| G6 | Undo tree (branching undo) | parked-conditional — TRAP per round-1 (checkpoint system supports it; product complexity not justified) |
| B1 | Document operating system / SDK | partial — ScriptingCLI + provider contracts exist; headless route is round-2 D3 (parked-implementable) |
| B2 | Universal form understanding model | parked-conditional — TRAP (rejected market position; reviewed-learning is the safe version) |
| B3 | Cross-document intelligence | parked-explorable — partial (cross-project exploration doc; round-2 B1 class-level accrual is the compounding step) |
| B4 | Local-first collaboration (CRDT) | partial — COLLABORATE slice + companion transport landed; merge semantics absent (round-2 F4 parked-conditional) |
| B5 | Document-as-API | partial — JSON contracts exist; the API surface is round-2 D3's headless core |
| B6 | Federated learning | parked-conditional (needs users first — round-1 trap) |

### Round 1 task/exploration follow-through snapshot (T-001..T-030, E-001..E-015)

Key states at 2026-08-30 (full lists live in round-1 §10): T-001 session
persistence **done** (G4); T-002 profile store **done** (ProfileStore.swift);
T-005 mismatch classification **done** (accepted-variance registry); T-016
companion handshake **done** (CompanionNegotiator); T-017 keyboard shortcuts
**open** (only dialog `.defaultAction`/`.cancelAction` found in app sources);
T-018 visual diff **open**; T-019 audit-report export **open**; T-020 web UI
refactor **open** (single-file web UI unchanged); T-022 batch/multi-document
**open** (no batch symbols in Sources). Explorations E-001/E-002 (real users,
pricing test) **still unrun**; E-004/E-011 (PDFBox evaluation) superseded by the
broader `docs/audits/pdf-libraries-*-evaluation-2026-08-26.md` set. Others
*verify* before pickup.

---

## Round 2 pool (2026-08-30)

**Source:** `docs/audits/comprehensive-adhd-audit-round2-2026-08-30.md`
(converged summary §2-§5); full restored rationales in the sections below.
Frames: 3am on-call, Speedrunner, Logistics, Remove-the-load-bearing-assumption,
Inversion (disjoint from round 1 per skill rules).

## Cluster A — Honesty gates: never claim what was not checked

### A1. VerificationState: single-engine validation stops faking 1.0 agreement — `deepened`

**Rationale (restored).** `Sources/PDFEditorCore/MultiEngineValidator.swift`
(evaluate, lines ~60-70) returns `pageCountAgreed` / `textPresenceAgreed` /
`fieldCountAgreed` all true and `overallAgreementRatio` 1.0 when fewer than two
engines are observed — a bookkeeper's silent wrong output: Poppler/MuPDF missing
yields a "100% cross-check passed" claim with zero cross-checking. The repo's
own PDA audit (ENG-21, P2) already names `MultiEngineValidator` as a pure
reducer over caller-supplied observations with no engines invoked. Full plan in
round-2 audit §4.1.

**Children (parked-implementable, each):**
1. ENG-21 option B: rename `MultiEngineValidator` → `ConformanceScorer` (honest
   pure-reducer name) and build a real engine-driving pipeline populating
   `EngineObservation` from actual PDFKit, PDF.js (existing browser/JSC lane),
   and Poppler CLI runs on the governed fixture — so `engineCount` means
   "engines actually executed and returned," not "entries a caller typed."
2. Web parity module `web/pdf-multi-engine-report.mjs` reusing
   `pdf-impact-validator.mjs`'s status vocabulary (`unknown/passed/failed`);
   rewrite `Tests/multi_engine_conformance_test.mjs` (currently three hardcoded
   observation literals asserting they agree with themselves — the same
   fake-pass disease in the JS lane) to invoke PDF.js and Poppler on
   `benchmark/results/public-sample-form.pdf`.
3. Evidence schema versioning: `reportVersion` + `verificationState` in
   serialized validation evidence under `benchmark/results/`, with decoding
   rules where pre-version files are treated as `unverified`; re-baseline
   historical "1.0 agreement" artifacts and record which `release-gates.md`
   rows change status.
4. UI review trigger: surface `verificationState` in the
   `ContextualInspectorView` preflight surface (the RG-097-delivered native
   preflight reporting row) as an "UNVERIFIED — cross-check unavailable" badge.
5. Hybrid consolidation: shared `VerificationState` type in
   `SharedContracts.swift` derived from `ShadowReport.allSucceeded` +
   `engineCount` and `ConformanceReport.engineCount` via one function, so a
   third validator (`EvidenceFusion.swift` already has its own
   `agreementScore`) cannot reintroduce the fake-1.0 pattern; add a
   mutation-style test killing any future report with `engineCount < 2`
   claiming ratio 1.0.

### A2. Glyph-coverage gate on synthesized values — `deepened`

**Rationale (restored).** `pdfString()`
(`PDFIncrementalFormWriter.swift:1085`) replaces every scalar ≥ U+0100 with a
literal `?`; the synthesized font object is hard-coded
`/Type1 /Helvetica /Encoding /WinAnsiEncoding` (~line 1002);
`latin1Bytes()` (:75) would trap on high scalars if `pdfString` did not
pre-sanitize; `TextRunFontMatcher.swift` falls back to plain Helvetica when the
original font is unresolvable. Non-Latin client names silently mangle or drop
on the recipient's viewer — the canonical silent wrong output for a regulated-
SMB bookkeeper. Full plan in round-2 audit §4.3.

**Children (parked-implementable unless noted):**
1. Recipient-viewer render parity preview: after the incremental write,
   re-render the synthesized field region through a second in-tree engine
   (`PDFiumRenderer`/`QPDFValidator`) and raster-diff against the intended
   string, catching "renders as ?" cases that pass metadata-level coverage
   because the local PDFKit viewer regenerates appearances.
2. Binary-safe font-subset pipeline: extend `ResolvedEditPlan` with binary
   new-object bodies so a Type0/Identity-H subset (Noto) can be appended in the
   same incremental update, keeping the RG-017 byte-exact-prefix invariant and
   `/Prev` chaining bounds intact — unlocks the fallback path without a full
   rewrite.
3. Live per-field encoding diagnostics in the editor: glyph-coverage badges on
   each text field showing uncovered codepoints as you type, feeding
   transliteration suggestions into the existing reviewed-candidate workflow
   instead of surfacing only at export time.
4. Document-font reuse lane: before synthesizing Helvetica, inspect the field's
   `/DA` and `/DR` fonts and reuse the document's existing embedded font when
   its declared `/Encoding` (including `/Differences`) covers the value —
   avoids new font objects entirely for many non-WinAnsi cases.
5. Reviewed transliteration fallback: NFKD-based WinAnsi-foldable transcoding
   (full-width forms → ASCII, stripping unencodable marks) offered as an
   explicit reviewed candidate with before/after diff — the user chooses a
   visible, audited substitution rather than receiving silent `?`.

### A3. Corpus-coverage sentinel ("outside validated corpus" warning) — `parked-implementable`

**Rationale (restored).** `DetectorGate.swift` is fail-closed only against the
internal reviewed corpus; `LayoutFingerprintV2.swift` provides the fingerprint
machinery, but nothing warns a user that their real-world form resembles
nothing in the corpus the 108-case precision/recall gates were earned on. The
sentinel measures how far an incoming document's layout fingerprint and OCR
density sit from the 108-case ground-truth distribution and flags "outside
validated corpus" before detection results are trusted.

### A4. Structural capability triage on open — `parked-implementable`

**Rationale (restored).** `PreflightContracts.swift` categories are
metadata / embeddedData / networkBoundary / activeContent / security — a
privacy preflight before export only. There is no per-document
renderability/feature-support finding, so the opposite outcome (user edits for
20 minutes then hits an unexplained wall and files a support ticket) is
guaranteed by design. Triage states what this specific document can and cannot
support in-app before editing effort is invested (damaged xref, XFA,
encryption, image-only pages).

### A5. Free tier runs the complete evidence pipeline on the purchaser's own document — `parked-implementable` (needs a product decision)

**Rationale (restored).** `docs/pdf-pricing-marketing-exploration-2026-08-25.md`
and `docs/release-gates.md` document the pricing and gate machinery, but
nothing converts the app's core moat into a pre-purchase self-demonstration —
guaranteeing purchase-time refusal from a skeptical bookkeeper who must trust
marketing claims instead of watching the preservation proof run on their own
file. Visible evidence summary, full pipeline (preflight, static-region
detection, impact validation, independent-viewer check), no content exfiltration.

### A6. On-device detector canary (post-OS-update Vision drift check) — `parked-implementable`

**Rationale (restored).** `AcceptedVarianceRegistry.swift` (line 19) states
variance drift is detected by CI, and the calibration-corpus verification shows
gates run only at build time — but Apple Vision is a system component Apple
updates under the user's feet, so silent OCR-model drift is invisible to every
CI gate. The canary re-runs a corpus subset through Apple Vision at first
launch after an OS change; `Sources/PDFOCRBenchmark/` contains the machinery to
run it in-app.

---

## Cluster B — Compounding-class moat

### B1. Class-level calibration accrual keyed by layout fingerprint — `deepened` ★

**Rationale (restored).** `docs/audits/recurring-form-calibrator-and-page-box-policy-2026-08-28.md`
and `docs/audits/recurring-template-class-calibration-evidence-2026-08-24.md`
establish template classes, but every ledger (`ReviewedCompletionMetrics`,
detector ground truth, `FalsePositiveReport`) is scoped per document, so the
108-case corpus and calibration gains never compound per class — despite the
product thesis being recurring forms. Full plan in round-2 audit §4.2,
including collision-defense tiering against the recorded F-1/F-4 fingerprint
collisions and the value-free privacy envelope.

**Children (parked-implementable unless noted):**
1. Re-key `CandidateReviewLearningEvent` aggregation and `CandidatePriorScorer`
   from `sourceDigest` to `TemplateClassKey` so accept/reject priors learned on
   document N rank candidate traversal on unseen instances N+1 of the same form
   class (the "template-scoped priors" goal already named in the events file
   header).
2. Replace the static checked-in `policyByDocumentClass` map in
   `TemplateBenchmarkContracts.swift` with a ledger-derived policy source:
   every human-reviewed decision appends a value-free `CorpusEntry`
   (`RecurringFormCalibrator.CorpusEntry` already carries `documentClass` and
   `layoutV2`) to the class's calibration corpus, turning the 108-case ground
   truth into a floor rather than a ceiling.
3. Collision-defense tiering: bind a class key as "confirmed" only via
   `knownVariant` (exact V2 digest equality) and quarantine `familyMatch`
   evidence as "provisional" until human review promotes it; add a poisoning
   test in `FalsePositiveReportGenerator` asserting cross-class accrual cannot
   relax a class's threshold (directly hardens F-1/F-4).
4. Privacy/export posture for the ledger: documented clear/export surface in
   `EncryptedTemplatePersistence.swift` plus an encode-time
   ValueFreeEventGuard-style assertion that no class record ever contains
   labels, values, paths, or source bytes — making the accrual store auditable
   like the signature store.
5. Per-archetype meta-calibration: use accrued class-level FPR curves and
   structural class features (page count, field density, rotation, scan-ness)
   to derive default thresholds per archetype instead of one global 0.90 —
   generalizing the existing special case where scanned documents have family
   matching disabled.

### B2. Template-hit fast path (trust-once-per-revision resume) — `parked-implementable`

**Rationale (restored).** `LayoutFingerprintV2.swift` and
`TemplateProfileResolver.swift` show the resolver deliberately returns "profile
identity only" and forces the full normal review every time — the speedrun
route is trust-once-per-revision resume, not re-detection: when the fingerprint
matches a stored profile revision on open, replay the saved regions and
candidates and skip OCR + static-region detection + the review queue for
unchanged regions. Review-gating doctrine is preserved: the replay surfaces for
confirmation, it does not silently apply.

### B3. Cross-dock intake lane — `parked-explorable`

**Rationale (restored).** Template runtime pieces already exist to chain
end-to-end (`LayoutFingerprintV2.swift`, `PDFIncrementalFormWriter.swift`,
`PDFImpactValidator.swift`; `docs/audits/template-runtime-completion-evidence-2026-08-25.md`),
but `FileBridge.swift` admission treats every document identically — there is
no fast path from dock to door. A dropped PDF whose layout fingerprint clears
a match threshold would skip the library and move straight to fill/validate/
export. **Open question that makes it explorable, not implementable:** how a
cross-docked document presents for review without violating the
never-silently-convert doctrine — the lane needs a landing surface, not an
assumption.

---

## Cluster C — Survive and diagnose

### C1. Companion handshake freshness TTL + build-digest invalidation — `parked-implementable`

**Rationale (restored).** `CompanionNegotiator.swift` persists validated
handshakes across sessions, and `docs/status-whats-next-2026-08-30.md` marks
RG-122/RG-123 (codesign, Sparkle auto-update) BLOCKED — so stale capabilities
describing a companion build that no longer exists are a certainty, not an
edge case. With codesign and auto-update both blocked, the native app and
companion WILL silently version-skew; a TTL and digest check converts that
from silent skew into an explicit re-negotiation.

### C2. Independent syntax-lint pass on the staging file before publish — `parked-implementable`

**Rationale (restored).** `docs/error-taxonomy.md`'s export transaction
invariant explicitly notes the provider-local validator "does not prove PDF
syntax validity," so corruption is currently discovered by the recipient's
reader, not before export. The Poppler/MuPDF cross-check machinery exists in
the harnesses (`Sources/PDFContractHarness`) but not on the export-time staging
path (step 4 of the invariant). **Exploration note before building:** per-export
latency cost of an independent parse needs a measurement first — hence
implementable-with-one-measurement; if the cost is too high for the interactive
path, scope it to a background post-write verification with a quarantined
export state.

### C3. Quarantine-and-surface corrupt session records — `parked-implementable`

**Rationale (restored).** `SessionStore.swift` (lines ~220-232) swallows
Data/decode errors per file, so a corrupted session record simply vanishes from
the recents list with no signal; `SessionRecoveryStore.swift` (lines 59-112)
proves the codebase already has the right pattern to copy — structured
corruption diagnostics instead of silent `try?`-skip.

### C4. Redacted local-only breadcrumb journal — `parked-implementable`

**Rationale (restored).** `docs/crash-reporting-boundary.md` lists the
local-only crash-log option (RG-124) but ships nothing; `Sources/PDFEditorCore`
contains only ~7 `os_log`/Logger call sites total; and
`docs/error-taxonomy.md` promises a "diagnostic export" recovery action for
cannotOpen with no capture layer behind it. JSONL with rotation, redacted,
local-only, so a hang or crash leaves a diagnosis trail instead of a user who
can only say "it froze."

### C5. Main-thread stall watchdog with degrade-and-cancel escape hatch — `parked-explorable`

**Rationale (restored).** Root causes are documented but unfixed
(`AppModel.swift`; `docs/roadmaps/performance-memory-observation-2026-08-25.md`);
the different cut is *surviving the hang until it's fixed*, since force-quit is
currently the only exit and it destroys unsaved operations. The watchdog
captures what stalled and offers a cancel that keeps the in-memory session.
**Explorable because** main-thread work cancellation in SwiftUI/AppKit has
genuinely tricky semantics — a bounded design pass is needed before code.

### C6. One-click sanitized support diagnostic bundle — `parked-implementable`

**Rationale (restored).** `SessionRecoveryStore.swift` and the failure-mode /
chaos audits exist internally, but a user-facing support artifact does not —
with zero real users, the first wave of "it broke my client's 1099" tickets
will arrive as unverifiable anecdotes. Build hash, preflight presence bits,
engine provenance, op-log with document content stripped.

---

## Cluster D — Pipeline shape: pull, don't push

### D1. Just-in-time parsing (detect/OCR/validate only what is touched) — `parked-explorable` (coordinate with pending perf fixes)

**Rationale (restored).** The known open perf hang is exactly eager work —
double parse on open and per-edit deep copies in
`Sources/PDFEditorRecovery/AppModel.swift`. A pull-based JIT lane through
`HybridPDFParser.swift` and `StaticRegionDetector.swift` is a different
mechanism than "fix the double parse" — it removes the trigger. **Explorable
because** it is an architecture change that must be coordinated with the
already-pending perf fixes (see `pdf-editor-native-perf-audit` memory) rather
than racing them.

### D2. Incremental-writer express lane (export as xref append) — `parked-explorable`

**Rationale (restored).** `PDFIncrementalFormWriter.swift` documents
byte-exact-prefix output with `/Prev` chaining (mirrored in
`web/pdf-incremental-form-writer.mjs`) yet the app still treats export as a
separate full-materialization step; fails-closed on compressed object streams
keeps it legal. **Explorable because** the first step is verifying how much of
the current export path already routes through the incremental writer — the
claim "export is a separate stage" needs a precise code-trace before
restructuring.

### D3. Headless core flow (detect→review→validate→apply without UI) — `parked-implementable` (merged with D4)

**Rationale (restored).** `Package.swift` ships only `PDFEditorApp` plus
test/benchmark harnesses — the headless path exists only as throwaway harness
code; `web/pdf-contract-mutation-gate.mjs` already materializes operations with
no app involved, proving the seam. Scripts and agents become first-class
clients. Extending `ScriptingCLI`'s existing commands (extract-text, validate,
summarize, recognize-entities, detect-dedup) with detect/fill/export is the
route substitution — distinct from in-app keyboard shortcuts or batch
processing.

### D4. Validation memoization (skip unchanged dual-engine re-checks) — `parked-implementable`

**Rationale (restored).** No caching found in `PDFImpactValidator.swift` or
`QPDFValidator.swift` — every export re-runs the dual-engine cross-check for
identical inputs. Cache keyed by document hash + edit-set hash + validator
version. Internal compute skip, not a user-facing certificate.

---

## Cluster E — Review flow physics

### E1. Returns/rework lane for failed validations — `parked-implementable`

**Rationale (restored).** `MultiEngineValidator.swift` and
`PDFImpactValidator.swift` emit failure states, and
`AcceptedVarianceRegistry.swift` already stores one disposition type, but there
is no quarantined rework state machine routing failures back into the pipeline
(`docs/audits/accepted-variance-registry-2026-08-28.md`). A document whose
validation fails enters a reverse-logistics disposition flow (rework /
accept-as-variance / scrap) with reason codes instead of being a dead end.

### E2. WIP-limited review conveyor — `parked-implementable`

**Rationale (restored).** `CandidatePriorScorer.swift` and
`DualLaneDetectorGate.swift` already rank and gate candidates, yet the
completion workflow has no queue semantics
(`docs/audits/reviewed-completion-metrics-evidence-2026-08-25.md` documents
review as one undifferentiated surface) — so limits-and-parking is an unbuilt
control. Cap the number of detector candidates in active review (say 5) and
park the rest in the already-scored backlog.

### E3. Wave-picked review sequencing — `parked-implementable`

**Rationale (restored).** `StaticRegionDetector.swift` emits candidates with
page and rect coordinates and `DocumentIndex.swift` indexes them spatially, yet
review order is unsequenced — a pick-path optimization over coordinates is
unbuilt. Group review candidates into waves by physical page location so the
reviewer walks the document once per wave instead of hopscotching across pages.

---

## Cluster F — Headless semantics, durable artifacts, deferred surfaces

### F1. Durable semantic layer (index/citations/entities/FSRS survive re-import) — `parked-implementable`

**Rationale (restored).** `DocumentIndex.swift`, `CitationTools.swift`,
`EntityRecognizer.swift`, and `FSRSScheduler.swift` are all in-memory types
with no store — `FSRSScheduler` is a pure enum algorithm — so the moat-cited
reading/learning layer evaporates when the file is reopened or the bytes
change. Version and persist the semantic layer (value-free, digest-bound) as a
durable document artifact the PDF projects from.

### F2. Declarative per-edit invariant spec (replace pixel-equality preservation) — `parked-explorable`

**Rationale (restored).** `docs/audits/raster-weight-analysis-2026-08-30.md`
shows the raster channel is noise-capped (weight 0.02) and
`docs/audits/accepted-variance-registry-2026-08-28.md` exists to excuse
variance — both are symptoms of pixel equality as the load-bearing definition;
gate RG-121 "arbitrary-PDF production preservation" is still OPEN. Replace
pixel-diff preservation with a declarative per-edit invariant spec (text-run
order, `/AP` stream identity, byte-range promises) that each provider attests
against. **Explorable-only:** doctrine-level redefinition of "preservation" —
requires a decisions.md-grade analysis, not a code change.

### F3. Typed authority contract (machine-satisfiable review-gate tokens) — `parked-conditional`

**Revisit condition:** a real delegation use case exists (second actor — human
or agent — needs to satisfy the gate), or a multi-reviewer workflow ships.
**Rationale (restored).** `docs/audits/human-ai-authority-architecture-audit-per-0927.md`
defines typed authority tiers (decide/execute/override/escalate) but nothing in
`Sources/PDFEditorCore` (`DetectorGate.swift`, `CandidateReviewLearningEvents.swift`,
`CandidatePriorScorer.swift`) implements machine-satisfiable consent; today the
gate only records human review events. **Why parked:** a heavy delegation
framework before any human has used the gate is premature abstraction.

### F4. Mergeable review-decision artifact (union-merge across devices) — `parked-conditional`

**Revisit condition:** multi-device usage is real (paired devices in
`RecoveryPairStore` with concurrent review activity).
**Rationale (restored).** `web/provider-companion-protocol.mjs` and
`CompanionTransport.swift` give the lane, and `RecoveryPairStore.swift` handles
paired-device recovery, but review decisions have no merge semantics anywhere
in the tree. **Why parked:** a multi-device concurrency solution for a
zero-user product.

### F5. Last-mile outbox (staged exports with per-recipient packing list) — `parked-conditional`

**Revisit condition:** real delivery volume exists (users exporting to multiple
recipients).
**Rationale (restored).** `CompanionTransport.swift` and
`CompanionHealthCheck.swift` already model outbound legs to the companion, and
`SessionPayloadStore.swift` persists payloads, but the native app has no
delivery-staging concept for outputs — delivery currently terminates at
`FileBridge.swift` writes.

### F6. Companion-lane offload (OCR/validation run concurrently in the web lane) — `parked-conditional`

**Revisit condition:** the companion is a guaranteed, health-checked presence
in the default configuration.
**Rationale (restored).** `CompanionTransport.swift`, `CompanionNegotiator.swift`,
and `CompanionHealthCheck.swift` already implement transport/negotiation/health
but the native pipeline blocks on each stage sequentially — collapsing
detect→review→validate into one wall-clock segment. **Why parked:** assumes
companion presence; merges two lanes' latency models; complexity ≫ win today.

### F7. XFA dataset write-back — `parked-conditional`

**Revisit condition:** measurable XFA corpus demand, or RG-071 policy changes.
**Rationale (restored).** `XFAFormProcessor.swift` already detects static/
dynamic XFA, extracts `xfa:data`/`xfa:template`, and normalizes XFA keys into
fields (`requiresFallbackFlattening` shows the current expensive fallback
path). Writing values directly into the `<xfa:data>` packet would let the
viewer regenerate appearances for free, making detection-to-appearance
synthesis stages unnecessary. **Why parked:** XFA is claim-blocked (RG-071),
dynamic XFA is a vanishing format, and the effort is large.

---

## Ledger summary

| # | Idea | Cluster | Status |
|---|---|---|---|
| A1 | VerificationState honest contract | A | deepened (audit §4.1) |
| A2 | Glyph-coverage gate | A | deepened (audit §4.3) |
| A3 | Corpus-coverage sentinel | A | parked-implementable |
| A4 | Open-time capability triage | A | parked-implementable |
| A5 | Free-tier evidence self-demonstration | A | parked-implementable (product decision) |
| A6 | On-device Vision drift canary | A | parked-implementable |
| B1 | Class-level calibration accrual ★ | B | deepened (audit §4.2) |
| B2 | Template-hit fast path | B | parked-implementable |
| B3 | Cross-dock intake lane | B | parked-explorable |
| C1 | Handshake freshness TTL | C | parked-implementable |
| C2 | Export-time syntax lint | C | parked-implementable |
| C3 | Corrupt-session quarantine | C | parked-implementable |
| C4 | Local-only breadcrumb journal | C | parked-implementable |
| C5 | Stall watchdog + cancel | C | parked-explorable |
| C6 | Sanitized support bundle | C | parked-implementable |
| D1 | JIT parsing | D | parked-explorable (perf-fix coordination) |
| D2 | Incremental-writer express lane | D | parked-explorable |
| D3 | Headless core flow (+CLI route) | D/F | parked-implementable |
| D4 | Validation memoization | D | parked-implementable |
| E1 | Validation rework lane | E | parked-implementable |
| E2 | WIP-limited review conveyor | E | parked-implementable |
| E3 | Wave-picked sequencing | E | parked-implementable |
| F1 | Durable semantic layer | F | parked-implementable |
| F2 | Declarative invariant spec | F | parked-explorable |
| F3 | Typed authority contract | F | parked-conditional |
| F4 | Mergeable review artifact | F | parked-conditional |
| F5 | Last-mile outbox | F | parked-conditional |
| F6 | Companion-lane offload | F | parked-conditional |
| F7 | XFA dataset write-back | F | parked-conditional |

Count: 29 idea slots (D3 merged with the speedrunner branch's headless-CLI idea;
the original pool of 30 reduces by that one merge). Deepened: 3.
Parked-implementable: 16. Parked-explorable: 5. Parked-conditional: 5.
Deepening children: 15 (5 per deepened idea), all listed inline above.

## Update protocol

- When an idea is picked up: change its status to `graduated`, add the pointer
  (task-inventory / feature-expansion-inventory entry or commit), add the date.
- When a parked-conditional trigger fires: promote its status and record why.
- When a new divergent round runs: append its pool here (new section), extend
  the ban list, and re-check this file before generating.
- Do not delete entries. Superseded ideas get a `superseded-by` note.
