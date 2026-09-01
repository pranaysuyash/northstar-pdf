# ADHD Audit Round 2: PDF Editor

**Date:** 2026-08-30
**Mode:** ADHD (5-frame parallel divergent ideation → converge → deepened focus)
**Scope:** What is worth exploring and/or implementing next that the 2026-08-24
audit did not already cover.
**Frames used:** 3am on-call, Speedrunner, Logistics, Remove-the-load-bearing-
assumption, Inversion. (Round 1 used Regulator, 10-year-old, Competitor, Game
Design, Infinite Budget; per skill rules the frame set is varied across runs,
and all round-1 candidates were banned as ideas here.)
**Evidence note:** All file/line citations in this document are T1 (static,
verified by the audit agents at authoring time). Gate-state claims defer to
`docs/release-gates.md` per D-055; this audit changes no gate states.

---

## 1. Brief

**Problem:** Find the next things worth exploring/implementing in Northstar PDF
that no prior audit surfaced.

**Reframe used:** Round 1 established "local-first document mutation pipeline
with an evidence moat." Round 2's finding is sharper: **the moat has holes
where evidence is silently manufactured.** The most weighted ideas are all
cases where a report claims a check happened when it did not — which is the
one failure class this product's entire thesis says must be impossible.

---

## 2. Wide set (full pool by cluster)

Scores `[N V F]` = novelty / viability / fit, 0–10. Weighted = 0.35N + 0.40V + 0.25F.

### Cluster A — Honesty gates: never claim what was not checked [strongest cluster]

| Idea | Score | Wt | Evidence |
|---|---|---|---|
| Single-engine validation returns explicit "unverified" degraded state instead of fake 1.0 agreement | [N8 V9 F10] | 8.9 | `Sources/PDFEditorCore/MultiEngineValidator.swift:60-70` returns all-true + `overallAgreementRatio 1.0` when `observations.count < 2`; same fake-1.0 in `Sources/PDFEditorCore/ShadowMode.swift:112-125`; `Tests/PDFEditorCoreTests/LibraryCascadeTests.swift:166` asserts the bug |
| Glyph-coverage gate on synthesized values (non-Latin text silently becomes `?`) | [N9 V8 F9] | 8.6 | `PDFIncrementalFormWriter.swift:1085` `pdfString()` maps ≥ U+0100 to literal `?`; hard-coded Type1 `/Helvetica /WinAnsiEncoding` at ~:1002 |
| Class-level calibration accrual keyed by layout fingerprint (see Cluster B, listed here for weighting) | [N9 V8 F9] | 8.6 | see Cluster B |
| Corpus-coverage sentinel: flag documents whose fingerprint/OCR density sits outside the 108-case ground-truth distribution before detection is trusted | [N9 V7 F9] | 8.2 | `DetectorGate.swift` is fail-closed only against the internal corpus; `LayoutFingerprintV2.swift` provides the distance machinery |
| Structural capability triage on open (damaged xref, XFA, encryption, image-only → state what this document can/cannot support before editing effort is spent) | [N8 V8 F9] | 8.25 | `PreflightContracts.swift` covers privacy-only categories; no per-document feature-support finding exists |
| Free tier runs the complete evidence pipeline on the purchaser's own document with a visible evidence summary | [N8 V8 F9] | 8.25 | `docs/pdf-pricing-marketing-exploration-2026-08-25.md` defines pricing; nothing converts the moat into pre-purchase self-demonstration |
| On-device detector canary: re-run a corpus subset at first launch after an OS change to catch Apple Vision model drift CI can never see | [N9 V7 F9] | 8.2 | `AcceptedVarianceRegistry.swift:19` states drift detection is CI-only; Vision is a system component Apple updates under the user; `Sources/PDFOCRBenchmark/` has the machinery |

### Cluster B — Compounding-class moat: make recurring forms compound

| Idea | Score | Wt | Evidence |
|---|---|---|---|
| Accrue evidence/calibration/completion metrics at the recurring-form class level keyed by `LayoutFingerprintV2.digest`, across all instances (deepened in §4) | [N9 V8 F9] | 8.6 | All ledgers are per-document; `docs/audits/recurring-form-calibrator-and-page-box-policy-2026-08-28.md` establishes classes |
| Template-hit fast path: fingerprint match on open replays saved regions/candidates and skips re-detection + re-review for unchanged regions | [N8 V8 F10] | 8.5 | `TemplateProfileResolver.swift` deliberately returns "profile identity only" and forces full review every time |
| Cross-dock intake lane: a dropped PDF whose fingerprint clears threshold goes straight to fill/validate/export without parking as "opened" | [N8 V7 F9] | 7.85 | `FileBridge.swift` treats every document identically; the end-to-end chain already exists per `docs/audits/template-runtime-completion-evidence-2026-08-25.md` |

### Cluster C — Survive and diagnose: no silent loss, no unexplainable freeze

| Idea | Score | Wt | Evidence |
|---|---|---|---|
| Freshness TTL + build-digest invalidation for stored companion handshakes (version skew is a certainty while codesign/auto-update gates are blocked) | [N8 V8 F9] | 8.25 | `CompanionNegotiator.swift` persists handshakes across sessions; RG-122/123 blocked per `docs/status-whats-next-2026-08-30.md` |
| Independent syntax-lint pass on the staging file before publish (export path admits it does not prove PDF syntax validity) | [N7 V8 F9] | 7.9 | `docs/error-taxonomy.md` export transaction invariant, step 4; harness machinery exists in `Sources/PDFContractHarness` |
| Quarantine-and-surface corrupt session records instead of silent `try?`-skip | [N6 V9 F8] | 7.7 | `SessionStore.swift:~220-232` swallows decode errors; `SessionRecoveryStore.swift:59-112` has the right pattern to copy |
| Redacted local-only breadcrumb journal (JSONL, rotated) implementing RG-124's local-only crash-log option | [N7 V8 F8] | 7.65 | `docs/crash-reporting-boundary.md` lists the option but ships nothing; ~7 `os_log` call sites total |
| Main-thread stall watchdog with degrade-and-cancel escape hatch for the known hangs (survive the hang until fixed; force-quit is currently the only exit) | [N8 V6 F9] | 7.45 | root causes unfixed in `AppModel.swift`; `docs/roadmaps/performance-memory-observation-2026-08-25.md` |
| One-click sanitized support diagnostic bundle (build hash, preflight bits, engine provenance, content-stripped op-log) | [N7 V8 F7] | 7.4 | first wave of "it broke my client's 1099" tickets will arrive as unverifiable anecdotes |

### Cluster D — Pipeline shape: pull, don't push

| Idea | Score | Wt | Evidence |
|---|---|---|---|
| Just-in-time parsing: detect/OCR/validate only the page or region touched, never at open (removes the trigger, not just the patch) | [N8 V8 F9] | 8.25 | eager work is the hang: `AppModel.swift` double-parse + per-edit deep copies; different mechanism than "fix the double parse" |
| Incremental-writer express lane: export becomes an xref append via the existing byte-exact-prefix writer | [N7 V8 F8] | 7.65 | `PDFIncrementalFormWriter.swift` + `web/pdf-incremental-form-writer.mjs` exist; export is still a full-materialization step |
| Headless any% route: extend `ScriptingCLI` with detect/fill/export (see Cluster F merge) | [N7 V8 F7] | 7.4 | `ScriptingCLI.swift`, `UserScriptRunner.swift` define the sandboxed machinery |
| Validation memoization keyed by document hash + edit-set hash + validator version | [N6 V8 F7] | 7.05 | no caching found in `PDFImpactValidator.swift` / `QPDFValidator.swift` |

### Cluster E — Review flow physics

| Idea | Score | Wt | Evidence |
|---|---|---|---|
| Returns/rework lane for failed validations: disposition state machine (rework / accept-as-variance / scrap) with reason codes | [N8 V8 F8] | 8.0 | `AcceptedVarianceRegistry.swift` stores one disposition type; no rework routing exists |
| WIP-limited review conveyor: cap active candidates (≈5), park the rest in the already-scored backlog | [N8 V7 F9] | 7.85 | `CandidatePriorScorer.swift` ranks; no queue semantics in the completion workflow |
| Wave-picked review sequencing: group candidates into waves by page location so the reviewer walks the document once per wave | [N7 V8 F8] | 7.65 | candidates carry page/rect; review order is unsequenced per `docs/audits/reviewed-completion-metrics-evidence-2026-08-25.md` |

### Cluster F — Headless core, durable semantics, conversion

| Idea | Score | Wt | Evidence |
|---|---|---|---|
| Headless core flow (detect→review→validate→apply executable without UI), scripts/agents as first-class clients | [N8 V8 F8] | 8.0 | `Package.swift` ships no headless target; `web/pdf-contract-mutation-gate.mjs` proves the seam |
| Persist the semantic layer (index, citations, entity graph, FSRS schedule) as a durable value-free artifact surviving re-import | [N9 V7 F7] | 7.7 | `DocumentIndex.swift`, `CitationTools.swift`, `EntityRecognizer.swift`, `FSRSScheduler.swift` are all in-memory |
| Corpus-coverage sentinel — see Cluster A | — | — | — |
| Declarative per-edit invariant spec replacing pixel-equality as the preservation definition | [N10 V5 F7] | 7.25 | `docs/audits/raster-weight-analysis-2026-08-30.md` shows raster is noise-capped (weight 0.02) — a symptom of a mis-weighted definition; RG-121 OPEN |
| Typed authority contract: machine-satisfiable review-gate evidence tokens per `docs/audits/human-ai-authority-architecture-audit-per-0927.md` | [N9 V5 F7] | 6.9 | audit defines tiers; nothing implements machine-satisfiable consent |
| Last-mile outbox: staged exports with per-recipient packing list | [N7 V6 F6] | 6.35 | delivery terminates at `FileBridge.swift` writes |
| XFA dataset write-back (write `<xfa:data>`, let the viewer regenerate appearances) | [N9 V4 F6] | 6.25 | `XFAFormProcessor.swift` detects/extracts; XFA claim is blocked (RG-071) |
| Mergeable review-decision artifact across devices (union-merge, not sync) | [N9 V4 F5] | 6.0 | lane exists (`CompanionTransport.swift`, `RecoveryPairStore.swift`); no merge semantics anywhere |
| Companion-lane offload of OCR/validation run concurrently | [N7 V5 F6] | 5.95 | transport/negotiation/health proven; sequential blocking remains |

---

## 3. Converge

**Shortlist (2–4):**

1. **VerificationState honest-contract fix** (Cluster A, wt 8.9). On the list
   because it is a genuine bug-class finding — the product that claims evidence
   discipline reports a fabricated 100% agreement under single-engine
   conditions — and the fix is small *now* because no production consumer has
   accreted onto the fake pass yet. Confirmed by the repo's own PDA audit
   (ENG-21, P2).
2. **Class-level calibration accrual** ★ (Cluster B, wt 8.6). The
   non-obvious-but-viable pick. It converts the product thesis (recurring
   forms) from a marketing claim into a compounding accuracy moat, and every
   ingredient (fingerprints, classes, encrypted value-free stores, calibrator
   thresholds) already exists — only the keying is wrong.
3. **Glyph-coverage gate** (Cluster A, wt 8.6). On the list because it is the
   canonical silent-wrong-output for the exact buyer wedge (non-Latin client
   names becoming `?` on a recipient's viewer) with a bounded first cut that
   needs no binary font emission.

**Traps (flagged, excluded from deepening):**

- **XFA dataset write-back** — claim-blocked capability (RG-071), dynamic XFA
  is a vanishing format, huge effort for a ghost.
- **Companion-lane offload** — assumes companion presence and health; merges
  two lanes' latency models; complexity ≫ win.
- **Mergeable review-decision CRDT** — a multi-device concurrency solution
  for a zero-user product.
- **Typed authority contract** — a heavy delegation framework before a single
  human has ever clicked the gate.
- **Last-mile outbox** — delivery staging with no deliveries.
- **Declarative invariant spec** — real signal (raster weight 0.02), but it is
  a doctrine-level redefinition of "preservation"; exploration item, not an
  implementation item now.

---

## 4. Focus (three deepened branches)

### 4.1 VerificationState: stop faking single-engine agreement [wt 8.9]

**Sketch.** `MultiEngineValidator.swift:60-70` returns `pageCountAgreed` /
`textPresenceAgreed` / `fieldCountAgreed` all `true` and
`overallAgreementRatio 1.0` when fewer than two engine observations exist, and
`ShadowMode.swift:112-125` repeats the same fake-1.0. The fix adds a
`VerificationState { verified, degraded, unverified }` plus `evidenceCount` to
`ConformanceReport` and `ShadowReport`, with the shared type living in
`SharedContracts.swift`; fewer than two engines (or engine execution failure)
yields `.unverified` with agreement booleans false-by-absence. The web lane
already has the right vocabulary — `web/pdf-impact-validator.mjs` uses
`unknown/passed/failed` — so the JS side mirrors the tri-state instead of
inventing terms. `docs/release-gates.md` gains a row requiring gates to fail
or downgrade to PARTIAL on `unverified`, and the capability matrix gains a
multi-engine-conformance row validated by the existing parity test. The only
current consumers are tests — including `LibraryCascadeTests.swift:166`, which
asserts agreement 1.0 for a one-engine run and thereby codifies the bug — so
the contract change is cheap now and prevents accretion of fake-pass believers.

**Load-bearing risk.** Historical evidence re-interpretation: any recorded
"100% cross-check passed" from a single-engine run becomes retroactively
invalid, so serialized reports need a schema version with fail-closed decoding
(pre-version files decode as `unverified`, never `verified`). Gates flip
status by design — `LibraryCascadeTests.swift:166` goes red until fixed,
`Tests/multi_engine_conformance_test.mjs` (which hand-builds three hardcoded
literals agreeing with themselves) goes red until it invokes real engines —
and any release-gate row leaning on multi-engine conformance may drop PASS →
PARTIAL. Native/web drift risk: the Swift enum and JS tri-state must be mapped
in one place or the parity debt returns.

**First concrete step.** In `Sources/PDFEditorCore/MultiEngineValidator.swift`,
add `public enum VerificationState: String, Sendable { case verified, degraded, unverified }`
and a `verificationState` field on `ConformanceReport`; change the
`observations.count < 2` path to return `.unverified` with the agreement flags
`false` and ratio 0; return `.verified` only at count ≥ 2. Mirror in
`ShadowMode.swift:112-125`; flip `LibraryCascadeTests.swift:166`; add a test
that the single-observation path yields `.unverified`.

**Child ideas.**
- Execute ENG-21 option B: rename `MultiEngineValidator` → `ConformanceScorer`
  (honest pure-reducer name) and build a real engine-driving pipeline feeding
  `EngineObservation` from actual PDFKit / PDF.js / Poppler runs on the
  governed fixture, so `engineCount` means "engines executed," not "entries
  typed."
- Web parity module `web/pdf-multi-engine-report.mjs` reusing the
  impact-validator status vocabulary; rewrite `multi_engine_conformance_test.mjs`
  to run real engines on `benchmark/results/public-sample-form.pdf`.
- Evidence schema versioning: `reportVersion` + `verificationState` in
  serialized evidence under `benchmark/results/`, pre-version files decode
  `unverified`; re-baseline which gate rows change status.
- UI review trigger: `verificationState` surfaced in the preflight/inspection
  surface as an "UNVERIFIED — cross-check unavailable" badge.
- Hybrid consolidation: derive `VerificationState` from both report types via
  one shared function in `SharedContracts.swift` (watch `EvidenceFusion.swift`'s
  own `agreementScore` for pattern re-introduction), plus a mutation-style test
  killing any future `engineCount < 2 ∧ ratio == 1.0`.

### 4.2 Class-level calibration accrual keyed by fingerprint ★ [wt 8.6]

**Sketch.** The class key composes the raw `LayoutFingerprintV2.digest`
(value-free SHA-256 over the text-free canonical descriptor) with the
calibrator's `documentClass`, and — inside a workspace — the HMAC-keyed
template fingerprint linking to a `PDFTemplatePayload` class; the raw digest
is the cross-instance key while the workspace HMAC stays the privacy boundary.
Class-scoped records: per-class `MatchingThresholds` (replacing the static
`.layoutV2Calibrated` preset in `RecurringFormCalibrator.swift`), accrued
`FalsePositiveReport` counts per class, merged `PDFReviewedCompletionMetrics`
(counts are value-free by construction, so sums are safe), and
`CandidatePriors` re-keyed from `sourceDigest` to class. Document-scoped stays
everything binding actual bytes: exact source digests, session decisions,
mappings under review, profile values. The store is a new
`TemplateClassEvidenceLedger` persisted with the existing
`EncryptedRevisionFileStore` + Keychain pattern, with encode-time fail-closed
guards (ValueFreeEventGuard-style) so no labels, values, paths, or source
bytes can enter a record. Document N improves N+1 because
`RecurringFormCalibrator.classify` and `PDFTemplateMatcher.propose` consult
the class ledger for thresholds and priors (falling back to the global preset
until minimum samples accrue), review priors bias traversal order for the same
class, and nothing ever lowers review requirements. Revision interaction:
ledger entries bind to template/revision IDs; corrections fork child revisions
whose evidence accrues to the class; a redesigned form produces a new digest,
the old class stops accruing and ages out via `lastSeenAt` GC.

**Load-bearing risk.** Fingerprint collision mis-scoping: the collision
exploration already recorded F-1 (two corpus PDFs sharing a V1 fingerprint)
and F-4 (0.824 text-layout similarity between different documents), so a
lookalike form passing `familyMatch` would accrue evidence into the wrong
class and progressively relax that class's thresholds — a feedback loop that
poisons exactly the calibration this exists to improve. V2's 0.90 threshold
plus digest-equality binding mitigates but does not eliminate this on sparse
layouts. Second: privacy — the digest is content-free but is a stable
cross-session identifier of a specific recurring form, so the ledger must hold
the same value-free/encrypted discipline; one regression turns a calibration
cache into a tracking artifact. Third: stale classes after form redesigns must
GC or they silently hold stale thresholds.

**First concrete step.** Create `Sources/PDFEditorCore/TemplateClassEvidenceLedger.swift`
defining `TemplateClassKey` (raw V2 digest + documentClass + keyScope) and a
Codable record (accrued thresholds, false-positive counts, merged completion
counts, sampleCount, template/revision IDs, lastSeenAt, privacy envelope);
then the smallest behavior change in `RecurringFormCalibrator.swift`: give
`classify(...)` an optional class-thresholds override so a matching class uses
accrued thresholds and everything else falls back to the preset — zero
call-site breakage, immediately testable against the existing corpus with the
ledger empty.

**Child ideas.**
- Re-key `CandidateReviewLearningEvent` aggregation and `CandidatePriorScorer`
  from `sourceDigest` to class key (the "template-scoped priors" goal already
  named in the file header).
- Replace the static checked-in `policyByDocumentClass` map in
  `TemplateBenchmarkContracts.swift` with a ledger-derived policy source, so
  the 108-case ground truth becomes a floor, not a ceiling.
- Collision-defense tiering: bind class keys as "confirmed" only via exact V2
  digest equality; quarantine `familyMatch` evidence as "provisional" until
  human review promotes it; add a poisoning test asserting cross-class accrual
  cannot relax a threshold (hardens F-1/F-4 directly).
- Privacy/export posture: documented clear/export surface in
  `EncryptedTemplatePersistence.swift` plus an encode-time assertion that no
  class record contains labels, values, paths, or source bytes.
- Per-archetype meta-calibration: derive default thresholds per archetype from
  accrued class-level FPR curves and structural features (page count, field
  density, rotation, scan-ness), generalizing the existing special case where
  scanned documents have family matching disabled.

### 4.3 Glyph-coverage gate on synthesized values [wt 8.6]

**Sketch.** Verified mechanism: `pdfString()` (`PDFIncrementalFormWriter.swift:1085`)
replaces every scalar ≥ U+0100 with a literal `?`, the synthesized font object
is hard-coded `/Type1 /Helvetica /Encoding /WinAnsiEncoding` (~:1002), and
`latin1Bytes()` (:75) would trap on high scalars if `pdfString` did not
pre-sanitize. The gate runs in the AcroForm incremental export path as a new
step between `resolveEditPlan` and `incrementalFieldUpdate`: a pure
`checkEncodingCoverage(value:)` maps every Unicode scalar through the same
substitution rules `pdfString` applies (including the exact WinAnsi 0x80–0x9F
CP1252 table, Unicode-normalization-aware) and flags scalars with no encoding
slot. Uncovered codepoints become a new `ValidationCheck` (`fontEncodingCoverage`
in `ValidationCheckKind`, `SharedContracts.swift:373`) carrying per-field
evidence: field FQN, the exact scalars, and what each renders as (`?`).
Because `validate()` treats `.failed` as a hard publication block and
`CommitFlow` already has the `acknowledgeWarning()` reviewed-warning state
machine, the failure surface is a *reviewed* failure: export blocks by
default; the user proceeds only after explicit acknowledgment with a
before/after rendering, or by choosing a fallback (embedded CID-capable subset,
or document-font reuse). Coverage runs pre-commit on intent; impact validation
runs post-write on output; both append to the same report and one review
surface.

**Load-bearing risk.** The fallback, not the gate: an embedded Unicode font
(CJK realistically means a Type0/Identity-H TTF subset) is binary, but
`ResolvedEditPlan` carries new-object bodies as `[String]`, so embedding breaks
the string-based emission model and threatens the byte-exact-prefix invariant
unless a binary-safe object emitter is built first; bundled faces carry
embedding-permission (`fsType`) and licensing constraints; and a naive coverage
table causes false-positive friction on legal Latin-1/CP1252 edge characters
(`é`, `ñ`, the 0x80–0x9F block) — if the gate is too strict, bookkeepers train
themselves to click through the warning, recreating the silent-mangle problem
as a silent-ignore problem.

**First concrete step.** Add `case fontEncodingCoverage` to
`ValidationCheckKind` in `SharedContracts.swift`; implement pure
`checkEncodingCoverage(value:)` in `PDFIncrementalFormWriter.swift` mirroring
`pdfString`'s ≥ U+0100 rule plus the exact WinAnsi table; call it per
text/choice operation inside `resolveEditPlan` (~:952); append the resulting
check in `PDFKitProvider.exportAcroFormViaIncrementalWriter` so uncovered
fields block publication with evidence. No binary-emission changes for the
first cut.

**Child ideas.**
- Recipient-viewer render parity preview: re-render the synthesized field
  region through a second in-tree engine and raster-diff against the intended
  string, catching "renders as ?" cases that pass metadata-level coverage
  because the local viewer regenerates appearances.
- Binary-safe font-subset pipeline: extend `ResolvedEditPlan` with binary new
  object bodies so a Type0/Identity-H subset can ride the same incremental
  update — unlocks the fallback without a full rewrite.
- Live per-field encoding badges in the editor, feeding transliteration
  suggestions into the reviewed-candidate workflow instead of surfacing only
  at export.
- Document-font reuse lane: before synthesizing Helvetica, inspect the field's
  `/DA` and `/DR` fonts and reuse a document-embedded font when its declared
  encoding (including `/Differences`) covers the value.
- Reviewed transliteration fallback: NFKD-based WinAnsi-foldable transcoding
  offered as an explicit reviewed candidate with before/after diff.

---

## 5. Provocation

Every shortlisted item is a variation of one question: *what does the app
refuse to claim?* The wildcard that opens a new direction: **make the evidence
receipt the product surface itself.** One artifact — "what was checked, by
which engines, with what result, on which bytes" — that the free tier can run
on the purchaser's own document before any payment (Cluster A idea 6), that
every gate (`unverified`, glyph coverage, corpus distance, handshake freshness)
appends to, and that doubles as the support diagnostic bundle. If the receipt
is the demo, the marketing site can be a live run of it — the moat stops being
a claim and becomes something a skeptical bookkeeper can watch happen to their
own 1099.

---

## Adoption notes

- **Durable pool ledger:** the complete divergent pool with restored full
  rationales, per-idea lifecycle statuses, and the 15 deepening child ideas is
  preserved in
  [`../explorations/adhd-exploration-pool-ledger.md`](../explorations/adhd-exploration-pool-ledger.md)
  (Round 2 section), alongside the Round 1 pool with follow-through statuses.
  This document's §2 tables are a scored summary; the ledger is the ledger of
  record — future rounds must treat both pools as "already-known" before
  generating.
- Round 1 (`comprehensive-adhd-audit-2026-08-24.md`) remains current for its
  scope; this document extends it with a disjoint frame set and bans its
  candidates rather than superseding it.
- Item 4.1 intersects the repo's own PDA audit finding ENG-21 (P2); if
  implemented, close both from one change.
- Item 4.3's mechanism (silent `?` substitution) is a candidate finding for
  `findings.md` independent of whether the gate ships.
- No gate states were changed by this audit; implementing 4.1 will
  intentionally change some.
