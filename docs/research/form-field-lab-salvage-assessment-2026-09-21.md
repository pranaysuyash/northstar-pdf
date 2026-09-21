# PDF Form Field Lab → Swift app salvage assessment

Date: 2026-09-21
Question: what from `/Users/pranay/Projects/pdf_form_field_lab` (Fieldroom) is worth adding to the Swift app now?
Evidence tier: Tier 1 (static inspection of both codebases) + lab receipts cited from its docs. No code changed.

## Verdict

The full port stays gated (lab FFL-PORT-008 prerequisites FFL-NAT-003/REV-004/HQ-006/MIX-007 are not all
verified — HQ-006 human-review loop is still Proposed, 0/38 confirmed). But **selective semantic salvage** is
worthwhile: the lab independently hit and solved a set of form-field problems the Swift app has not yet hit,
and four capabilities + one rule-set port cleanly. Jev does **not** belong in this pipeline (see §Jev).

## Already at parity or ahead in the Swift app (do not port)

- Character-grid entry mode: Swift has it end-to-end (`CandidateEntryMode.characterGrid`, SharedContracts.swift:206;
  fill ops in PDFKitProvider.swift:530/1167; ProfileStore matching). The lab's "one string → cells" UX lesson is
  already implemented here.
- Immutable revisions + receipts: Swift's `PDFTemplateLifecycle` + `ReceiptSigning` (Ed25519 signed chain,
  canonical JSON) is ahead of the lab's hash-bound export receipts.
- Fill-then-reopen gates: `AcroFormParityExperiment` does cross-engine reopen (pdf-lib + PDFKit + qpdf) — the lab's
  "export must reopen and expose AcroForm inventory" gate is already exceeded here.
- Review-event flywheel concept: `CandidateReviewLearningEvents` exists (maturity vs lab FFL-FLY-011 unverified).
- Detector measurement discipline: `DetectorSemanticMeasurement` already scores precision/recall/abstention/label
  association with hard-negative gating (commit c2eb7fa hardened the precision-relevant hard-negative quantity).

## Worth porting (ranked)

### A1. Signature-occupancy audit as a separate lane (highest product value)
The lab separates **field detection** from **signature-slot audit**: a `SignatureObservation` (expected slot,
ink present/missing/uncertain) is review-only *document evidence*, deliberately not a FieldSpec. Proof case
(Medpiper financial statement): generic detection correctly returned **zero** editable targets while the
signature audit still found **12 expected slots — 9 present, 3 missing** — actionable audit findings with no
false fields. Swift has `signature` as a suggested field *type* but no ink-occupancy observation and the
2026-09-09 research map records signature detection as having zero eval coverage.
Port path: `SignatureObservation` contract + occupancy check over rendered-page rasters (Swift already has raster
machinery: ContentInvariantRasterExtractor, raster-blend gate). Eval fixtures from the lab's calibration
discipline. Feeds the verification/audit product narrative (missing-signature = finding, not a field).

### A2. Zero-target abstention UI contract (trivial, honest-claims)
Lab rule: a zero-target document must say "No editable targets found", stay at 0% reviewed, and offer manual-add
recovery — never render as "100% reviewed". Grep finds no equivalent state in Swift app views. Direct §13
honest-claims defect when it hits. Cheap UI-level fix.

### A3. Field-kind completion: textarea, named composite groups, photo target
Swift `SuggestedFieldType` (SharedContracts.swift:191) lacks `textarea`, `composite`, and `image`. The lab's
generalized lessons: composite targets need **explicit group names + child-cell semantics** ("Address group"
with ordered rows) because users could not tell which composite they were filling; one logical answer then a
deterministic split into cells. `characterGrid` is the special case; composite generalizes it with naming and
mixed child kinds. Photo targets are first-class app targets (upload/dropzone) whose export is a visual adapter,
never a fake AcroForm text field.

### A4. Hard-negative defect rules → Swift test fixtures (test-only, near-free)
The lab's defect→rule table maps 1:1 onto Swift's FieldLabelCanonicalizer / StaticRegionDetector:
- `Account no:` / `Phone no:` misread as Choice → token-boundary rule, standalone "no" is not a Choice cue
- `Candidate name:` misread as Date → exact date tokens, not substring match
- wide-shallow rectangles in statements/tables are hard negatives; geometry alone never promotes
- symmetric cross-type dedup (not exact-ID only); usable interior ≠ outer border; child grids need own coords
Port each observed defect as a Swift fixture + assertion before it recurs here.

### A5. Per-page lane composition invariant (verify-then-fix)
Lab invariant: native evidence suppresses only an **overlapping** inferred proposal; unrelated painted fields
elsewhere on the same page survive; composition is per page, never whole-document fallback (their FFL-MIX-007
found whole-document raster fallback bugs). Verify Swift's composition has the same invariant; add the fixture.

### B1. Multilingual fill contract (register the contract now, implement later)
Four-way separation — interface language / document language+script / input language+script / output font — with
glyph-coverage pre-check and **honest export error** for unsupported scripts; never silently translate or
transliterate. Grep: Swift has nothing. The lab designed it as additive future metadata; porting the contract
(schema only) now costs little and prevents ad-hoc i18n later.

### B2. Label-governance patterns (prerequisite for any future model lane)
From FFL-LBL-002 / FFL-GOV-001: verified records survive repo rebuilds; source-hash change demotes verified→
re-review; family-disjoint holdout; receipt-bound fail-closed training view; proxy labels behind an explicit flag.
This is the gate both the lab's advisory model and any Jev/ML lane failed without: **field-level gold labels are
the scarce resource**, not model choice.

## Jev verdict: do not wire it into the form pipeline

Three independent reasons, in strength order:
1. **Zero-egress is a doctrine-level invariant of this app** (ReceiptSigning, CompanionBridge, DemandLedger all
   encode it). Jev is a remote typed-decision API; a form-field call would break the product's evidence story
   unless explicitly opt-in.
2. **Two independent weak-model results say supervision, not model choice, is the bottleneck**: the lab's own
   advisory reranker on proxy labels came out near-noise (0.378 acc / 0.25 macro-F1 → park-or-fund), and Jev's
   EXP-JEV-1 on security triage returned 0.208 vs 0.542 baseline (kill signal, recorded in memory/docs).
3. **The class of decision Jev would make here is already deterministic-rule territory.** The surviving Jev lane
   (short structured typed decisions — EXP-JEV-4) maps to label→type disambiguation, but the lab proved those
   failures (e.g. "Account no:" → Choice) are token-boundary *rule* bugs, fixable and auditable without a model
   call. If the owner wants one more Jev experiment, the only defensible slot is a shadow lane on label→kind
   disambiguation **after** a small field-level gold set exists (A4 fixtures + FUNSD harness as start) — and even
   then behind the zero-egress opt-in wall.

## Provenance and boundary

Source project: `/Users/pranay/Projects/pdf_form_field_lab` (read-only reference; its AGENTS/README state the
sibling pdf_editor checkout stays outside its ownership boundary, and this phase must not create a second
semantic source of truth — any port lands as Swift-native code with Swift-native tests, citing the lab lesson in
the test/doc comment where useful). Nothing in the lab repo was modified.

## Status update (2026-09-21, same day)

A2, A4, A5, and A1 were implemented and verified the same day — see
`form-field-lab-salvage-implementation-2026-09-21.md` for the change list, cross-lane zlib
fix, and Tier 2–4 evidence (tests 11/11 + regressions; live-app screenshots of the abstention
state and the Signature Audit card). Remaining: A3 (composite/photo kinds), B1 (multilingual
contract), B2 (label governance), signature embedded-image lane, manual-add affordance.

## Follow-ups (owner decisions)

1. Pick the A-tier order (recommendation: A2 → A4 → A1 → A3 → A5) and slot against the 2026-09-21 start order
   (owner-hour → PERF-S01/S02 → RG-135 → commerce). A2+A4 are no-regret smalls.
2. Decide whether signature-occupancy audit (A1) joins the launch-critical path or the post-launch audit lane.
3. Register this doc in docs/task-inventory.md when the parallel lane's dirty state clears (file is currently
   modified by another lane; not touched here).
4. Jev: the owner kill-or-continue decision from 2026-09-21 remains open; this assessment adds the zero-egress
   argument for kill, with the form-field shadow lane named as the only surviving-lane candidate if continuing.
