# ADHD Exploration Pool Ledger — pdf_editor (all rounds)

**Ledger of record for every ADHD-skill divergent pool run on this repo.**
Currently covers: **Round 1 (2026-08-24)**, **Round 2 (2026-08-30)**, and
**Round 3 (2026-09-17)**.
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

## Owner steering notes (recorded signals, not bans)

- **2026-09-17 (owner, during round-6 render discussion):** "no i dont care about the git thing."
  Interpretation: the git/VCS-flavored direction (R5-01…R5-06 git-historian frame — redline rebase,
  patch bundles, reflog, submodules, bisect, hooks — and ledger-as-VCS framings generally) is
  **deprioritized**: do not promote these into task registers without explicit owner revival, and
  future rounds must not re-anchor on VCS metaphors. Statuses remain parked (never deleted); the
  mechanisms are still valid hygiene if a need resurfaces organically. R5-05 ledger bisect keeps
  its deepened status as a diagnostic substrate but carries this steering tag.

## Future-round ban list (mechanics, not ideas)

Every future ADHD or divergent-audit round on this repo MUST treat the union of
the round-1 pool (2026-08-24, "Round 1 pool" below), the round-2 pool
(2026-08-30, "Round 2 pool" below), the round-3 pool (2026-09-17, "Round 3
pool" below), and all future appended pools as "already-known": not banned from
re-angle, but banned from being presented as new. Check this file before
generating, and append the new round's pool here.
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
| R4 | Redaction certification workflow | parked-conditional (RG-014 claim-blocked; promote when RG-014 redaction policy unblocks certification claims) |
| R5 | Chain-of-custody tracking | parked-implementable (operation log exists) |
| R6 | Tamper-evident export format | parked-explorable (PDF-metadata embedding design needed) |
| Y1 | Camera capture → fill | parked-conditional — TRAP (silent autofill rejected by architecture; promote when E-009 safe-capture exploration yields a reviewed, non-silent fill flow) |
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
| G6 | Undo tree (branching undo) | parked-conditional — TRAP per round-1 (checkpoint system supports it; promote when observed multi-branch editing demand justifies the product complexity) |
| B1 | Document operating system / SDK | partial — ScriptingCLI + provider contracts exist; headless route is round-2 D3 (parked-implementable) |
| B2 | Universal form understanding model | parked-conditional — TRAP (rejected market position; reviewed-learning is the safe version; promote only if the market position changes or B1 class-level accrual saturates and demands an on-device model tier) |
| B3 | Cross-document intelligence | parked-explorable — partial (cross-project exploration doc; round-2 B1 class-level accrual is the compounding step) |
| B4 | Local-first collaboration (CRDT) | partial — COLLABORATE slice + companion transport landed; merge semantics absent (round-2 F4 parked-conditional) |
| B5 | Document-as-API | partial — JSON contracts exist; the API surface is round-2 D3's headless core |
| B6 | Federated learning | parked-conditional (promote when a real user cohort exists — round-1 trap at zero users) |

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
| F3 | Typed authority contract | F | parked-conditional (promote when a real delegation use case or multi-reviewer workflow exists) |
| F4 | Mergeable review artifact | F | parked-conditional (promote when multi-device usage is real) |
| F5 | Last-mile outbox | F | parked-conditional (promote when real delivery volume exists) |
| F6 | Companion-lane offload | F | parked-conditional (promote when the companion is a guaranteed, health-checked presence) |
| F7 | XFA dataset write-back | F | parked-conditional (promote when measurable XFA corpus demand or an RG-071 policy change) |

Count: 29 idea slots (D3 merged with the speedrunner branch's headless-CLI idea;
the original pool of 30 reduces by that one merge). Deepened: 3.
Parked-implementable: 16. Parked-explorable: 5. Parked-conditional: 5.
Deepening children: 15 (5 per deepened idea), all listed inline above.

---

## Round 3 pool (2026-09-17)

**Source:** `docs/audits/comprehensive-adhd-audit-round3-2026-09-17.md` — full
restored rationales, verbatim branch outputs, scoring, clusters, converge, and
deepening sketches live there. This section holds the statuses. Frames
(disjoint from rounds 1–2): hardware engineer, biology, markets,
$0-budget-1-hour, ant colony. Problem P: unblock the first paying cohort
(0 users, RG-135 0/38, parity red, 0% commerce, $79 price fixed).

**Status verification basis:** deepen-agent file citations independently
verified at registration (2026-09-17): `Sources/PDFExperimentParityHarness`,
`benchmark/results/preflight-parity-2026-08-25/parity-report.json`,
`benchmark/results/rejection-ledger/`, `docs/decisions.md`,
`pdf-editor.human-review-gate` schema key. Market-side assumptions NOT verified.

### Round 3 idea statuses (29 slots)

| ID | Idea (short) | Status at 2026-09-17 |
|---|---|---|
| R3-01 | Load-time POST screen (honest per-stage timing readout) | parked-implementable |
| R3-02 | Datasheet operating envelope | deepened (folded into the R3-03+R3-22 branch, audit §7.1). **Follow-through 2026-09-17:** `Sources/PDFEditorCore/OperatingEnvelope.swift` + shipped `Resources/operating-envelope.json` landed (9/9 tests; fail-closed load, all-exceeded-rows naming, provisional parse-budget row). Open-time wiring into `AppModel.open` pending (parallel-lane collision avoidance); envelope-claim adoption = D-055 decision gate |
| R3-03 | Cohort-as-fixture campaign | deepened (merged with R3-22; audit §7.1) ★. **Remaining first steps:** D-055 decision entry + W-9 cohort fixture generator keeping the `pdf-editor.human-review-gate` schema |
| R3-04 | Burn-in service seat | parked-conditional — TRAP under zero-egress unless inverted to local-first onboarding or a consented redacted-contribution lane; promote when that lane exists |
| R3-05 | Secure-boot offline entitlement licensing | parked-implementable (delivery mechanism for R3-25). **Follow-through 2026-09-17:** signed evidence chain landed — `ReceiptSigning.swift` (`GateReportAttestation`, `ReceiptVerificationKey`, deterministic canonical encoding) + `CohortEntitlement.swift` (entitlement → attestation → report-digest chain, per-link verdicts) + optional `ExecutionReceipt.signature`; 8/8 tests incl. authority-mismatch + tamper mutations. Issuance tooling (offline signer CLI) pending |
| R3-06 | Public errata board (live fixture red/green) | parked-implementable |
| R3-07 | Niche partitioning (sub-50MB first SKU) | deepened (envelope row of the merged branch, audit §7.1) |
| R3-08 | Apoptotic fixture culling | parked-conditional — promote only via a D-055 decision entry, published reason-coded known-limitations, and reviewer-of-record signoff; otherwise gate-gaming |
| R3-09 | Horizontal gene transfer (conformance corpora as fixtures) | parked-conditional — TRAP (wrong gate: syntactic conformance ≠ visual acceptance); promote only if a syntactic gate needs corpus seeding (veraPDF already vendored in `tools/`) |
| R3-10 | VDJ cohort edition (3 form families) | parked-implementable (multi-form variant of the merged branch) |
| R3-11 | Quorum-sensing founder deposits | parked-implementable (variant of R3-25; zero-cash $0-auth form is audit §7.2 child 2) |
| R3-12 | Microbiome habitat distribution | parked-explorable (bounded channel-research pass first) |
| R3-13 | Fixture auction | parked-implementable (variant of R3-25) |
| R3-14 | Dated-delivery futures | parked-implementable (variant of R3-25; slip-linked pricing child, audit §7.2) |
| R3-15 | Parity clearing via netting | parked-conditional — **premise falsified by measurement 2026-09-17** (`tools/parity-settlement-classify.mjs` over the 18-fixture parity report: 13 exact-agree / 3 classified-variance / 2 malformed-agree / **0 disputes** — the parity state is open measurement scope, not a dispute backlog; a settlement reducer would attest an empty set). Promote when a fresh run records `disputeCount > 0`; the classifier stays as the per-run regression detector |
| R3-16 | Maker inventory seeding (buy a backlog) | parked-explorable (document custody + consent/egress design pass first) |
| R3-17 | Cohort-staffed acceptance gate | parked-explorable (review-integrity design needed) |
| R3-18 | Exchange listing w/ gate-ledger disclosure | parked-implementable. **Research re-angle 2026-09-17:** integration app marketplaces (e.g. QuickBooks App Store) require QBO OAuth integration — structurally incompatible with zero-egress; viable venues are CPA-society vendor directories, association catalogs, practitioner newsletters (`docs/research/round3-cohort-research-2026-09-17.md` §5 Q2) |
| R3-19 | Invoice-first presale | parked-implementable (variant of R3-25) |
| R3-20 | VoC corpus from community mining | parked-implementable |
| R3-21 | Named human reviewer of record | parked-implementable |
| R3-22 | Single-form edition (W-9 edition) | deepened (merged with R3-03; audit §7.1) ★ |
| R3-23 | Homepage = live gate status | parked-implementable |
| R3-24 | Hard-reject >50MB at open | parked-implementable (envelope row; claim narrowing needs a doctrine note). **Follow-through 2026-09-17:** row-evaluation + honest multi-row rejection message implemented in `OperatingEnvelope` (tested); open-time wiring pending |
| R3-25 | Refund-escrowed presale + demand-priced gate backlog | deepened (audit §7.2) ★ |
| R3-26 | Mac App Store distribution | parked-conditional — near-obvious; promote only after a sandboxed-intake PoC (Open With/dock file access under sandbox) |
| R3-27 | Fixture conscription (one fixture per onboarder) | parked-explorable (review-integrity design needed) |
| R3-28 | Envelope + local-only demand log | deepened (demand-ledger child of the merged branch, audit §7.1 child 3). **Follow-through 2026-09-17:** `Sources/PDFEditorCore/DemandLedger.swift` landed (3/3 tests; value-free JSONL, single-generation rotation, preserve-on-malformed; truncation defect caught by S2 and fixed); in-app wiring pending |
| R3-29 | Public validated-form-class ledger waitlist | deepened (spine artifact of R3-25, audit §7.2 step 1). **Follow-through 2026-09-17:** `tools/export-form-class-ledger.mjs` landed; `docs/public/form_class_ledger.json` + `ledger.html` generated (38 fixtures, 0 confirmed, form-classes honestly empty; source-report digests embedded) |
| R3-30 | Prove the payment rail with the $4.99 AI add-on first | parked-conditional — TRAP (proves the rail with the unproven SKU, muddles positioning); promote only after the $79 rail works AND observed AI-add-on demand exists |

Count: 30 IDs / 29 slots (R3-03 + R3-22 merged). Deepened-marked: 7 (2 branches
★ plus 5 folded/spine; R3-15 demoted to parked-conditional on measurement
evidence 2026-09-17). Parked-implementable: 13. Parked-explorable: 4.
Parked-conditional (incl. traps): 6. Deepening children: 15 (5 per branch),
recorded in the audit doc §7 with full rationale.

### Round 3 cross-round deltas (declare, don't silently collide)

- Envelope scoping (R3-02/07/24) vs round-2 A3 "corpus-coverage sentinel":
  different mechanism — A3 warns a user at open-time against the detection
  corpus; the envelope is a product-claim narrowing that makes the sell honest
  before gates close. Composable.
- Presale family (R3-25 and variants) vs round-2 A5 "free-tier evidence
  self-demonstration": different stage — A5 is pre-purchase demonstration;
  R3-25 is purchase mechanics. The §7.1 child 5 self-test overlaps A5's
  surface; treat as one build item when picked up.
- Netting (R3-15) vs round-2 E2 (WIP conveyor), E1 (rework lane), A1
  (VerificationState): netting changes the attestation unit (per-settlement);
  the others are flow control, failure routing, and state honesty. All compose;
  delta stated in audit §7.3.

---

## Round 4 pool (2026-09-17)

**Source:** `docs/audits/comprehensive-adhd-audit-round4-2026-09-17.md` — full branch outputs,
scoring, clusters, traps, and the three deepened sketches live there. Frames (disjoint from
rounds 1–3): **Inversion** (the only unused table frame), **Time traveler**, **The document's
perspective** (wild), **Insurance underwriter**, **Museum curator** — four composed frames because
14 of the skill table's 15 were consumed by rounds 1–3. Problem P: post-D-083 AI-native agentic
shell — capabilities, interactions, trust mechanics, identity moves past the obvious answers.

**Ban-list basis:** the R1–R3 union (83 slots) plus D-078 gate mechanics were supplied to every
branch as already-known; the obvious three (chat sidebar, generic autofill, AI summaries) banned.
D-078 collisions flagged, not hidden: R4-03 (digest-binding exists), R4-06 (per-step approval
exists).

### Round 4 idea statuses (30)

| ID | Idea (short) | Cluster | Frame | Status at 2026-09-17 |
|---|---|---|---|---|
| R4-01 | Rehearsal mode by default (ledger fork → inspected diff → hash-gated graduation) | B | inversion | deepened ★ (audit §3; first step: `Ledger.clone()` + `dryRun` on the D-078 executor; composes with what-if branches and rehearse-the-undo children) |
| R4-02 | Confidence quarantine (unprovable fields abstain into a visible queue) | C | inversion | parked-implementable (abstention doctrine exists; UX queue is the work) |
| R4-03 | Drift-lock surfacing (visible invalidate + re-baseline) | C | inversion | parked-conditional — mechanic exists (D-078 invariant 4); promote the UX when slice 2 (goal capture) is designed |
| R4-04 | Redline zones (loop-enforced no-go regions) | C | inversion | parked-explorable |
| R4-05 | Challenge-and-replay (re-derive any step live on demand) | D | inversion | parked-implementable (deterministic core makes re-derivation genuinely reproducible) |
| R4-06 | Single-use expiring authority | A | inversion | parked-conditional — partial collision with D-078 invariant 5; promote when approval-banking demand observed |
| R4-07 | Standing orders (dated conditional intents binding future sessions) | D | time-traveler | parked-explorable |
| R4-08 | Assumption-TTL approvals (assumptions recorded, visibly expire) | D | time-traveler | parked-explorable |
| R4-09 | Agent succession memo (handover across model upgrades, owner countersigns) | D | time-traveler | parked-explorable |
| R4-10 | Retroactive validation sweeps (old edits re-judged by new rule packs) | D | time-traveler | parked-explorable |
| R4-11 | Charter ratification per session | D | time-traveler | parked-conditional — promote when long-lived-document usage pattern is observed |
| R4-12 | Dormancy rehearsal gate (agent narrates prior arc; owner corrects) | D | time-traveler | parked-explorable |
| R4-13 | Consent interview at open | E | doc-perspective | parked-conditional — TRAP as literal persona UX; salvageable core collides with R3-02/R3-24 envelope open-time wiring; promote through that lane |
| R4-14 | Field testimony (typed field constraints veto fills at cell granularity) | C | doc-perspective | deepened ★ (audit §3; first step: `FieldTestimonyContracts.swift` + plan-validation abstention; cold-start solved via correction-to-rule promotion) |
| R4-15 | Anatomy-based counterproposal (refusal offers alternative placement) | E | doc-perspective | parked-explorable |
| R4-16 | End-of-life petition (document-initiated disposition) | E | doc-perspective | parked-conditional — overlaps R4-29; promote when disposition demand observed |
| R4-17 | Twin tribunal (near-duplicate identity resolution) | E | doc-perspective | parked-explorable |
| R4-18 | Stale-section recanting (document nominates its own decay) | E | doc-perspective | parked-conditional — needs semantic staleness detection beyond deterministic scope; promote when ratified model assistance exists |
| R4-19 | Experience-rated autonomy (approval rate-cards from revert history) | A | underwriter | parked-explorable — child of R4-20 (settlement history is the dataset) |
| R4-20 | Claim settlement as scoped counter-mutation | B | underwriter | deepened ★ (audit §3; first step: read-only `reconstructPair(at k)` beside `VersionStore.swift`; risk: mid-history dependency graph absent — suffix-adjacent safe today) |
| R4-21 | Deductible absorption (auto-revert first N small mistakes) | A | underwriter | parked-conditional — TRAP as worded ("silently" violates honesty doctrine); promote only reframed as logged micro-reverts |
| R4-22 | Capability riders (per-job pre-committed checkpoints; unriddered batch refused at quote) | A | underwriter | parked-implementable (rides the existing `AgentPlanStep` destructive flag) |
| R4-23 | Void conditions contract (co-authored exclusion schedule) | B | underwriter | parked-conditional — promote when multi-source mutation reality exists |
| R4-24 | Subrogation ledger (fault attribution from receipt chains) | A | underwriter | parked-explorable |
| R4-25 | Acquisition charter (intake scope authored by user) | E | curator | parked-explorable |
| R4-26 | Conservator mode (never edit in place; escalating consent layers) | B | curator | parked-implementable — formalizes D-068 view/export discipline as intervention-depth UX; re-read against the vision styling track |
| R4-27 | Tombstone labels (maker/date/medium/why-acquired before content) | E | curator | parked-implementable — partial collision: inspector Document tab covers metadata facts |
| R4-28 | Gallery rotation (finite "on view" shelf, scheduled rehang) | E | curator | parked-conditional — TRAP: multi-document corpus management inside NM-T39's declined scope (D-083 boundary); promote only when NM-T39's falsifier fires |
| R4-29 | Deaccession ceremony (deletion as governed rite) | E | curator | parked-explorable |
| R4-30 | Original order (never auto-organize; views over the user's arrangement) | E | curator | parked-implementable |

Count: 30 ideas / 30 slots. Deepened: 3 (R4-01, R4-20, R4-14 — one per cluster for breadth).
Parked-implementable: 6. Parked-explorable: 11. Parked-conditional (incl. 3 traps): 10.
Deepening children: 15 (5 per branch), recorded in the round-4 audit §3 with full rationale.

### Round 4 cross-round deltas (declare, don't silently collide)

- **R4-01 rehearsal / R4-20 settlement vs G4 save-resume (R1, graduated) and round-2 E1/E2:**
  different mechanism — G4 persists sessions across launches; rehearsal forks the *operations
  ledger in memory for one plan*, and settlement appends a counter-mutation. All compose on the
  same append-only ledger.
- **R4-26 conservator mode vs D-068 (view-only transforms):** D-068 is the constraint; R4-26 is
  the *product surface* that makes the constraint visible and graduated. Not a duplicate; a
  framing graduation candidate for the D-083 styling track.
- **R4-13/R4-16/R4-29 vs R1-R5 chain-of-custody and R3 form-class ledger:** disposition and
  custody overlap; treat R4-16/R4-29 as one build item when picked up.
- **R4-14 field testimony vs R1-Y2/C3 profile bulk fill and learning events:** testimonies are
  constraints, profiles are values; the correction-to-rule promotion reuses the C3 learning path
  as its proposal source — composable, not colliding.
- **D-083 alignment:** R4-01/R4-14/R4-20 are all slice-compatible (they ride the wired D-078 loop
  and strengthen the inspectable-agent promise); they are candidates to enrich slices 1–3, entered
  via task-inventory per the promotion rule — not automatic.

---

## Round 5 pool (2026-09-17)

**Source:** `docs/audits/comprehensive-adhd-audit-round5-2026-09-17.md` — branch outputs, scoring,
clusters, and the three deepened sketches live there. Frames (all composed — the skill table's 15
frames exhausted by rounds 1–4): **Git historian**, **Notary/legal clerk**, **Accountant/auditor**,
**Platform economist**, **Music-producer/film-editor (NLE/DAW)**. Problem P: the R4 provocation —
the mutation ledger as the product ("every change provable, reversible, attributable"); the round
was also licensed to falsify that thesis.

**Ban-list basis:** R1–R4 union (113 slots) as already-known, including R4's rehearsal mode /
claim settlement / field testimony and D-078 mechanics; obvious three banned.

### Round 5 idea statuses (30)

| ID | Idea (short) | Cluster | Frame | Status at 2026-09-17 |
|---|---|---|---|---|
| R5-01 | Redline rebase (replay approved chain onto updated upstream) | G | git | parked-explorable |
| R5-02 | Patch bundles as travel format (self-verifying, offline) | G | git | parked-implementable (ReceiptSigning landed) |
| R5-03 | Ledger reflog (discarded proposals addressable forever) | H | git | parked-implementable |
| R5-04 | Pinned clause submodules | J | git | parked-conditional — fleet composition is NM-T39 adjacency; single clause-library case viable now |
| R5-05 | Ledger bisect (binary-search the defect-entering op) | H | git | deepened ★ (audit §3; headless `LedgerBisect` fixture first; risk = comparator monotonicity, budgeted structurally) |
| R5-06 | Pre-approval hooks (policy-as-code on ledger entries) | F | git | parked-implementable (rides R4-14 testimony substrate) |
| R5-07 | Liber/folio citation (citable state identifiers) | G | notary | parked-implementable |
| R5-08 | Exemplified-copy issuance (conformity-attested historical export) | G | notary | parked-implementable (composes ReceiptSigning) |
| R5-09 | Codicil amendment protocol (append-only as legal identity) | J | notary | parked-implementable — framing formalization of existing D-068/export-only architecture |
| R5-10 | Abstract-of-title generator (counterparty-facing trust artifact) | G | notary | parked-implementable ★-adjacent (8.85) |
| R5-11 | Witnessed execution ceremony (two-device local countersign) | J | notary | parked-explorable |
| R5-12 | Executor custody succession (sealed key escrow) | J | notary | parked-explorable |
| R5-13 | Balanced-entry enforcement (offsetting counter-entry required) | F | accountant | parked-explorable |
| R5-14 | Trial balance self-audit (replay-vs-bytes reconcile; quarantine; signed seal) | F | accountant | deepened ★ — top of pool (9.25; first step: `ReconciliationAudit.swift` + fixture; risk = replay determinism across engine versions, mitigated by engineVersion pinning + rebaseline escape hatch) |
| R5-15 | Fiscal closing of a document (freeze periods; adjusting entries) | J | accountant | parked-implementable |
| R5-16 | Provision register (future obligations booked as accruals) | J | accountant | parked-conditional — merges with R4-07 standing orders on pickup |
| R5-17 | Depreciation write-downs (staleness as booked events) | J | accountant | parked-conditional — needs ratified model assistance |
| R5-18 | Audit season as product ritual (sealed attestation pack) | F | accountant | parked-implementable (R3-05 ReceiptSigning reusable; renewal-story tie) |
| R5-19 | .pdoc provenance sidecar format | J | platform | parked-explorable |
| R5-20 | Sneakernet marketplace (signed policy packs verified on ingest) | J | platform | parked-explorable (sibling of R3-11) |
| R5-21 | E-discovery / PREMIS export | G | platform | parked-implementable |
| R5-22 | Ledger-examiner credential | J | platform | parked-conditional — TRAP at zero cohort; promote when cohort + examiner demand real |
| R5-23 | Receipt-stamping firmware | J | platform | parked-conditional — TRAP; promote only with committed hardware partner |
| R5-24 | Agent conformance mark | J | platform | parked-conditional — promote when third-party agent ecosystem exists |
| R5-25 | Stems export (per-contributor partition; Revert-stem vs Strip-attribution modes) | G/I | NLE | deepened ★ (audit §3; first step: `stems(selecting:deselecting:)` filter + hash-distinct test; risk = attribution/revert ambiguity — hard-named modes + signed receipt encode the mode) |
| R5-26 | Turnover as EDL (signed machine-readable change list) | G | NLE | parked-implementable |
| R5-27 | Automation write modes (READ/TOUCH/LATCH/WRITE per agent lane) | I | NLE | parked-implementable — D-083's graduated-autonomy vocabulary |
| R5-28 | Insert chain (bypassable validation; bypassed-inserts audit question) | I | NLE | parked-implementable |
| R5-29 | Multicam sync (divergent copies as synced angles) | H | NLE | parked-explorable |
| R5-30 | Room tone (backfill deletions from author's ledger voice) | I | NLE | parked-conditional — needs ratified model assistance |

Count: 30 ideas / 30 slots. Deepened: 3 (R5-05, R5-14, R5-25 — one per frame-family for breadth).
Parked-implementable: 13. Parked-explorable: 7. Parked-conditional (incl. 2 traps): 7.
Deepening children: 15 (5 per branch), recorded in the round-5 audit §3 with full rationale.

### Round 5 cross-round deltas (declare, don't silently collide)

- **R5-14 vs R2-A1 VerificationState:** A1 = honest claim-state; R5-14 = runnable replay-integrity. Compose.
- **R5-05 vs R4-01 divergence-localization child vs R5-14 checkpoint child:** same binary-search mechanism three times — compose into one `LedgerBisect` substrate (R5-05 is the user-facing product).
- **R5-16 vs R4-07 standing orders:** merge on pickup (forward-bound ledger intents).
- **R5-25 vs R3-05 ReceiptSigning / R4-01 rehearsal / R4-20 settlement:** all ledger-partition + replay compositions; stems is the export-side partition.
- **R5-26 vs R1 audit-trail export:** different audience (counterparties vs auditors); one build item if picked up together.
- **R5-09 vs D-068:** naming/architecture-claim surface over existing mechanics, not new mechanics.
- **D-083 alignment:** R5-14's agent pre-flight gate rides the wired loop (slice-compatible); R5-25/R5-26 strengthen the $79 trust story; R5-27 supplies D-083's graduated-autonomy vocabulary. Entry via task-inventory per the promotion rule — not automatic.

---

## Round 6 pool (2026-09-17)

**Source:** `docs/audits/comprehensive-adhd-audit-round6-2026-09-17.md` — branch outputs, scoring,
clusters, deepened sketches. Frames (all composed): **Trust attacker** (attacks on the artifacts,
negated into defenses), **Second-lane designer** (what earns "AI-native" under D-078's model gate),
**Cartographer**, **Aviation CRM**, **Watchmaker**. Problem P: the open flanks of the registry-clerk
identity — artifact integrity, the second model lane, navigability, approval human-factors,
precision philosophy.

**Ban-list basis:** full R1–R5 union (173 slots) as already-known, incl. R4 rehearsal/settlement/
testimony and R5 trial balance/stems/bisect/write modes; obvious three banned.

### Round 6 idea statuses (30)

| ID | Idea (short) | Cluster | Frame | Status at 2026-09-17 |
|---|---|---|---|---|
| R6-01 | Hash-sealed genesis snapshot (replay never touches live tree) | K | trust-attacker | parked-implementable |
| R6-02 | Non-transplantable receipts (instance identity + chain position binding) | K | trust-attacker | parked-implementable |
| R6-03 | Lineage-import quarantine (matching genesis must import chain or quarantine) | K | trust-attacker | parked-implementable |
| R6-04 | Net-zero smuggling rejection (reconciler catches offsetting pairs) | K | trust-attacker | parked-explorable |
| R6-05 | Capability-bound attribution + logical sequence (never wall-clock) | K | trust-attacker | parked-implementable |
| R6-06 | Causal lineage persistence (AI content keeps AI lineage through reverts; anti-laundering) | K | trust-attacker | deepened ★ (audit §3; first step: `EditOperation.resultDigest`/`restores` + `computeLineage` fixture test in DocumentModel.swift; risk scoped honestly — tamper-evident, not tamper-proof) |
| R6-07 | Edit-pattern induction (replay-validated rule proposals) | L | second-lane | parked-conditional — promote when an on-device lane + quality harness exists (D-078 gate) |
| R6-08 | Version-contradiction triage (semantic conflict vs rewording tags) | L | second-lane | parked-conditional — model-lane gate |
| R6-09 | Obligation extraction (span-anchored commitments; feeds R5-16 provisions) | L | second-lane | parked-conditional — model-lane gate |
| R6-10 | Import ontology mapping (model proposes, validator gates) | L | second-lane | parked-conditional — model-lane gate |
| R6-11 | Skeptical-auditor pass (span-anchored challenge proposals) | L | second-lane | parked-conditional — model-lane gate |
| R6-12 | Mutation materiality tagging (substantive vs cosmetic; validator checks spans) | L | second-lane | parked-conditional — model-lane gate; deepens the ledger differentiator itself |
| R6-13 | Beck transit diagram of contributor stems | M | cartographer | parked-explorable |
| R6-14 | Terrae incognitae layer (regions without receipts rendered as honest blank space) | M | cartographer | deepened ★ — top of round (9.60; first step: read-only coverage audit over region-to-resource attribution; risk = attribution mapping precision, absorbed by granularity ladder) |
| R6-15 | Projection switcher (each map mode declares its distortion) | M | cartographer | parked-explorable |
| R6-16 | Live legend (every symbol IS its receipt) | M | cartographer | parked-implementable |
| R6-17 | Themed atlas plates (shared graticule across themes) | M | cartographer | parked-explorable |
| R6-18 | Provenance hydrology (authorship as watershed) | M | cartographer | parked-conditional — behind projection substrate |
| R6-19 | Sterile cockpit for the approver (canvas locks during high-stakes windows) | N | aviation | parked-implementable |
| R6-20 | Approver fatigue management (dwell-time plausibility → cooldown) | N | aviation | parked-implementable |
| R6-21 | Non-punitive near-miss register (personal ASRS log) | N | aviation | parked-implementable |
| R6-22 | Readback/hearback on intent (approval attaches to the restatement) | N | aviation | parked-implementable — slice-2 interaction model |
| R6-23 | Brief-and-fly-the-brief (deviation-only interruption; brief = plan approval) | N | aviation | parked-implementable — D-078-compatible by construction; slice-2/3 interaction model |
| R6-24 | Puzzled-look rule (hesitation → agent explains; silence never consents) | N | aviation | parked-implementable |
| R6-25 | Deadbeat rendering (UI advances only on verified ledger ticks) | O | watchmaker | deepened ★ (audit §3; first step: LedgerProjectionStore + frame==head CI test on the receipts timeline; risk = commit-latency budget, draft-buffer carve-out for typing) |
| R6-26 | Tourbillon regulation (counterfactual position-averaging of heuristics) | O | watchmaker | parked-conditional — research-heavy; promote when order-sensitive model outputs exist |
| R6-27 | Perpetual ordering (monotonic tick as causal spine; civil time display-only) | O | watchmaker | parked-implementable (pairs with R5-14 engineVersion pinning) |
| R6-28 | Jewels (hardened invariants at friction seams; displayed count) | O | watchmaker | parked-implementable |
| R6-29 | Spare-parts covenant (published parts catalog; third-party servicer) | O | watchmaker | parked-explorable |
| R6-30 | Crown-out freeze (stop-the-world at a named tick) | O | watchmaker | parked-implementable |

Count: 30 ideas / 30 slots. Deepened: 3 (R6-06, R6-14, R6-25). Parked-implementable: 14.
Parked-explorable: 5. Parked-conditional: 8 (6 share the model-lane gate — they ARE the definition
of what "AI-native" naming waits for). Deepening children: 15, in the round-6 audit §3.

### Round 6 cross-round deltas (declare, don't silently collide)

- **R6-06 ↔ R5-25 stems:** lineage is the integrity substrate of contributor partition — partition
  only means something if attribution cannot be laundered. Compose.
- **R6-06 replay-convergence child extends D-078** (state re-derivations must recompute lineage
  and converge; mismatch = integrity failure, ledger unchanged on failure).
- **R6-19..24 ↔ R4-01 per-op graduation / R4-14 objection panel / R4-22 riders:** together the
  approval-surface program; R6-23 is D-078-compatible by construction (brief = plan approval;
  deviations = new plan) and is the slice-2/3 interaction model.
- **R6-25 ↔ MAD-I8 reduce-motion** (beat motion gated) and **↔ R5-14** (a tick includes receipt
  verification — shared LedgerHead substrate).
- **R6-14 ↔ R5-14:** trial balance proves global integrity; terrae maps the spatial extent of what
  the ledger can testify about. The honesty pair.
- **D-083 alignment:** R6-22/R6-23 slice-2/3; R6-14/R6-16/R6-25 identity layer for slices 3–4;
  R6-06 is the enforcement substrate that makes "agentic review-first" naming mean something.
  Entry via task-inventory promotion rule — not automatic.

---

## Round 7 pool (2026-09-17)

**Source:** `docs/audits/comprehensive-adhd-audit-round7-2026-09-17.md` — branch outputs, scoring,
the convergence finding, and three deepened passes. Frames (all composed, owner steer applied — no
VCS metaphors): **Improviser**, **Diary keeper**, **Zen gardener**, **Playground designer**,
**Demolition & salvage**. Problem P: the R6 provocation — when is provability the wrong tool?
**Headline finding:** all five frames independently converged on one feature — **the dark session**
(a ledger that records the opening/closing of an un-oathed session and swears to nothing between)
with four supporting mechanics. 30 ideas = one feature specification + variants.

### Round 7 idea statuses (30)

| ID | Idea (short) | Cluster | Frame | Status at 2026-09-17 |
|---|---|---|---|---|
| R7-01 | The Pocket (tempo telemetry, not notes) | Q | improviser | parked-explorable (merges with R7-15) |
| R7-02 | Liner notes (human memoir as distinct genre; type-enforced) | Q | improviser | deepened ★ (audit §3; `SessionLinerNote.swift` + decode-parity test; risk = genre erosion at consumer boundary) |
| R7-03 | The Room Witness (co-signed co-presence attestations) | S | improviser | parked-explorable (sibling R5-11) |
| R7-04 | Chalk privileges (visible, not citable, until inked) | S | improviser | parked-implementable |
| R7-05 | The Call (invocation rite for dark sessions) | P | improviser | deepened (merged — session-boundary contract) |
| R7-06 | Certified absence (stamped boundary of the ledger's own ignorance) | P | improviser | deepened (merged — session-boundary contract) |
| R7-07 | Burn tombstones (notarized destruction records) | P | diary | parked-implementable (irreversible-session variant of the contract) |
| R7-08 | Ciphertext ledger (integrity over encrypted blobs) | T | diary | parked-conditional — replay requires plaintext; promote when commitment-based integrity design exists |
| R7-09 | The sovereign margin (declared not-under-oath zone) | S | diary | parked-implementable ★-adjacent (9.20) |
| R7-10 | Pre-registered silence (time-locked sealed entries) | T | diary | parked-conditional — TRAP as worded ("subpoena cannot open" overclaims); promote reframed as local-only time-lock |
| R7-11 | Documents born adult (admitted without lineage) | S | diary | parked-implementable (composes R6-06 lineage degradation classes) |
| R7-12 | Masked attribution (rotating pseudonym) | S | diary | parked-conditional — re-identification design pass first |
| R7-13 | Water-writing board (evaporating surface; transcription handoff) | R | zen | parked-implementable |
| R7-14 | Quorum-pooled attribution (facts sworn, persons sealed) | S | zen | parked-explorable |
| R7-15 | Rake marks (content-free process telemetry) | Q | zen | parked-explorable (merges with R7-01) |
| R7-16 | One-take seal ("performed, not edited") | R | zen | parked-explorable |
| R7-17 | Pinch of sand (non-reconstructive witness seals) | S | zen | parked-explorable |
| R7-18 | Attested blindness (the ledger's own looking-away entry type) | P | zen | deepened ★ — top of round (9.60; first step: content-sink census + `blind_session` tombstone schema; two structural risks: sink leakage → ContentSink registry + CI contract; silent invocation → witnessed Call inside the tombstone; D-067 gains "asserted-by-mechanism" tier) |
| R7-19 | Chalk-line fields (opened/closed, nothing between) | P | playground | deepened (merged — session-boundary contract) |
| R7-20 | The sealed blob (opaque commit; snapshot-replay) | R | playground | parked-implementable (contract disposition c) |
| R7-21 | The game did it (communal actor; degraded-provenance flag) | S | playground | parked-implementable (composes R6-06 lineage classes) |
| R7-22 | Decay, not deletion (visible fade clock) | R | playground | parked-implementable |
| R7-23 | Pick-up-able laws (rebuild the rule stack to exit play) | S | playground | parked-explorable |
| R7-24 | Zero-state instruments (no scoreboards in affordances) | S | playground | parked-implementable |
| R7-25 | Boundary survey (perimeter attested, interior never) | P | demolition | deepened (merged — session-boundary contract) |
| R7-26 | Mass-balance wreck report (N attempted, M adopted, K vaporized) | Q | demolition | parked-implementable (contract accounting) |
| R7-27 | Containment envelope (sealed wholesale disposal) | R | demolition | parked-explorable |
| R7-28 | Salvage provenance stamp ("recovered from unattested session") | Q | demolition | deepened (merged — contract disposition b; composes R6-06 lineage classes) |
| R7-29 | Blast permit (declared region + duration; permit is the whole testimony) | P | demolition | deepened ★ (contract core; with R7-18 + R7-05 constitutes the dark-session architecture: tombstone entry, resumption digest, chalk/seal/salvage dispositions, D-067 "asserted-by-mechanism" tier, agent claim ceiling) |
| R7-30 | Chalk-grade writes (ephemeral by construction) | R | demolition | parked-implementable (contract disposition a) |

Count: 30 ideas / 30 slots. Deepened: 6 (3 passes; the session-boundary family R7-05/06/18/19/25/29
merged into one architecture + liner notes R7-02). Parked-implementable: 11. Parked-explorable: 8.
Parked-conditional (1 trap): 3. Seven rounds = 233 idea slots.

### Round 7 cross-round deltas (declare, don't silently collide)

- **R7 contract ↔ R5-14 trial balance:** dark spans get named replay semantics (chalk = skip,
  seal = snapshot-load); the reconciler's verdict vocabulary extends ("prefix verified / replay
  impossible across dark span / suffix anchor-verified").
- **R7 ↔ R6-14 terrae:** dark spans render as deliberate incognita rows — the honesty pair becomes
  a trio with R5-14.
- **R7-28/R7-21 ↔ R6-06 lineage:** salvage and play re-entry are lineage classes; R6-06's
  resurrection-op taxonomy audit gains "dark session" as a class.
- **R7 ↔ D-078:** agent plans never bind to dark digests; claims intersecting dark spans cap at
  advisory ("unknown, downstream of dark span"). R6-23 brief-and-fly composes (the brief declares
  region + intent; the tombstone declares the rest).
- **R7 ↔ D-067/D-069:** new claim vocabulary — "asserted-by-mechanism" evidence tier,
  "performed, not edited" claims, degraded provenance grades ("recovered from unattested session").
- **Strategic tension recorded (owner-visible):** the dark session repositions the R5 thesis from
  "every change provable" to "every change provable **or** its absence certified." Honest
  repositioning, not thesis failure — must be acknowledged wherever the thesis sentence is quoted.


## Update protocol

- When an idea is picked up: change its status to `graduated`, add the pointer
  (task-inventory / feature-expansion-inventory entry or commit), add the date.
- When a parked-conditional trigger fires: promote its status and record why.
- When a new divergent round runs: append its pool here (new section), extend
  the ban list, and re-check this file before generating.
- Do not delete entries. Superseded ideas get a `superseded-by` note.
