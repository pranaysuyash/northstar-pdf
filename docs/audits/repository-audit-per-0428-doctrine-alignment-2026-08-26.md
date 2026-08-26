# Repository Audit — PER-0428 Feedback Doctrine Alignment Reviewer — 2026-08-26

**Persona applied:** Feedback Doctrine Alignment Reviewer (`PER-0428`,
`~/desktop/personas_23rdaug26/01 Expanded Personas/05 Feedback, Critique &
Review/PER-0428 - Feedback Doctrine Alignment Reviewer.docx`), augmented with
the evidence-discipline rules of the Epistemic Integrity Architect (`PER-0922`)
and the repo-local parallel-work protocol (doctrine §10 as restated in
`docs/task-inventory-2026-08-25.md`).

**Central question (persona):** Is this repository's work being handled according to the
rules and evidence standards the project deliberately established — and are those
standards themselves first-principles sound and long-term viable?

**Doctrine baseline:** `OPERATING_DOCTRINE.md` v8.0 (project-local generated copy;
canonical at `/Users/pranay/Projects/agent-start/doctrines/OPERATING_DOCTRINE.md`).
Truth labels used throughout: Observed / Verified / Inferred / Proposed / Unknown / Contested.
Evidence tiers T0–T5; test sensitivity S0–S3.

**Audit method:** fresh live-truth verification (build, tests, file inspection),
two parallel exploration passes (native Swift surface; web/tooling surface),
reconciliation against three prior audit documents, then doctrine-alignment
evaluation of every finding and task. No source files were modified; only this
document and its companion implementation plan were written.

---

## 1. Executive summary

The repository is in unusually strong epistemic shape for a project of this
age: versioned contracts shared across native and browser lanes, fail-closed
mutation gates, independent-engine validation oracles, an explicit release-gate
registry with falsifiers, and honest "PARTIAL" labeling of 55+ gates rather
than optimistic claims. The five invariant pillars from the prior comprehensive
audit (source immutability, epistemic honesty, fail-closed security,
deterministic recovery, multi-oracle fidelity) are **Observed** in code, not
merely documented.

However, live truth on 2026-08-26 diverges from the documented state in four
material ways:

| # | Live-truth finding | State | Evidence |
|---|---|---|---|
| L-1 | **`swift build` is broken right now** — 2 errors in `PDFIncrementalFormWriter.swift` (`widths` used before declaration :249; `applyPngUpPredictor` not in scope :263) inside a dirty file (+91/−9 uncommitted). The previously-documented AppModel compile blocker is resolved. | Observed T1 | `swift build` output this session; `git diff --stat Sources/PDFEditorCore/PDFIncrementalFormWriter.swift` |
| L-2 | **A parallel-edit collision corrupted a test file**: `Tests/pdf-signature-guard_test.mjs:10-11` has a stray `import {` colliding with an inserted `import { pdfPython } from "./pdf-python.mjs";`, producing `SyntaxError: Unexpected reserved word`. | Observed T2 (test fails before assertions run) | Direct execution of the test file |
| L-3 | Contract suite is red but improving: **72/79 pass** (7 failures), with **5 additional timeout-flakes** on a first run (67/79). Baseline recorded 2026-08-25 was 48/76. | Observed T3 | Two full runs of `node tools/run-contract-tests.mjs` this session; `tmp/test-results-baseline.json` |
| L-4 | Prior audit documents contain stale/falsified claims that have not been reconciled: the 2026-08-25 audit asserts "zero React/Angular runtime dependencies" (falsified — a React 19 shell exists at `web/app/`) and the 2026-08-26 persona audit records RG-001 as `FAIL` (the registry now reads `PARTIAL` with extensive delivered evidence). | Contested → resolved in favor of the newer registry | `docs/audits/comprehensive-repository-audit-and-first-principles-evaluation-2026-08-25.md` §5.2 vs `web/app/package.json`; `docs/audits/full-persona-audit-2026-08-26.md` vs `docs/release-gates.md` RG-001 row |

**Doctrine-alignment verdict:** the *method* is aligned and largely
first-principles-derived. The *current failure* is not methodological but
operational: concurrent agent lanes are colliding (L-1, L-2), the canonical
task queue is drifting from live truth (L-4), and no automated gate exists to
catch a red build/red suite before more work stacks on top (no CI). These are
the highest-leverage fixes and they are cheap.

---

## 2. Ground-truth inventory (verified this session)

### 2.1 Native plane (Swift)

From the exploration pass plus direct verification:

| Module | Files | Lines | Role |
|---|---|---|---|
| PDFEditorCore | 45 | 16,688 | Domain library: providers, contracts, detection, sanitization, vaults, incremental writer, OCR abstraction |
| PDFEditorApp | 11 | 5,523 | SwiftUI executable front-end |
| PDFEditorRecovery | 6 | 6,945 | AppModel (4,910 lines) + session persistence + Markdown renderer |
| PDFContractHarness | 1 | 364 | Coordinate-envelope CLI |
| PDFTemplateParityHarness | 1 | 71 | Template-parity CLI |
| PDFExperimentParityHarness | 1 | 253 | Version/policy parity ledger CLI |
| PDFOCRBenchmark / PDFTextRunOCRBenchmark / PDFPerformanceBenchmark | 3 | ~1,029 | Benchmark CLIs |
| PDFRecoveryInterruptionHarness | 1 | 17 | Crash-interruption wrapper |

- `Package.swift`: Swift tools 6.0, macOS 15 only, **zero external dependencies**
  (Apple frameworks only). Verified by reading Package.swift.
- Tests: 33 Swift files / 7,146 lines (Swift Testing framework, 31 files; 2
  legacy XCTest), plus ~85 `.mjs` browser/contract scripts and fixture/baseline
  assets under `Tests/`.
- Most recent recorded native verification: **226/226 tests across 32 suites**
  (`progress.md`, 2026-08-26 entry). Not re-runnable this session because the
  package does not build (L-1).

### 2.2 Web plane

- **Zero-build ES-module graph with frozen, versioned contracts**, runnable
  identically in Node and browser. Subsystems verified:
  - Sanitize/security guards (`pdf-sanitize*.mjs`, `pdf-action-neutralize.mjs`,
    `pdf-signature-guard.mjs`, `pdf-xfa-guard.mjs`, `pdf-preflight.mjs`) — all
    carry explicit "describe, never mutate" scope comments; value-free reports.
  - Template system (`pdf-template-store.mjs` 67 KB, contract/migration/sync modules).
  - Vault/recovery/provenance (`pdf-vault-worker.mjs` deliberately holds no keys,
    no DB handle, no parser; Worker-less fallback in client).
  - OCR/detectors (`pdf-geometry-detector.mjs` emits suggestions + evidence only).
  - Parity/validation gates (`pdf-contract-mutation-gate.mjs` runs preflight in
    both engines *before* any load/save; `pdf-evidence-fusion.mjs` frozen
    thresholds accept 0.72 / review 0.45 shared by both adapters).
  - Product modes (`product-modes.mjs` framework-neutral five-mode model;
    WAI-ARIA tabs in `mode-stage.mjs`).
- **Two frontends, one contract layer:** vanilla `web/app.js` (5,543 lines) and
  React 19 + TypeScript 5.8 + Vite 6.3 shell at `web/app/` (20 files, ~3,333
  LOC; `PdfController.ts` 849 lines) import the *same* `../../*.mjs` contract
  sources; `vite.config.ts` forbids vendored copies. Single-source discipline
  is structurally enforced.
- CSP: `web/index.html` sets `connect-src 'none'` (air-gap), no `unsafe-inline`
  script-src after red-team finding RT-004.
- Vendored deps: PDF.js **4.2.67** (Apache-2.0, version stamped in-bundle),
  pdf-lib (MIT, **version NOT stamped in bundle**), veraPDF CLI **1.30.2**
  (`tools/verapdf`).
- Tooling: `tools/deploy-web.mjs` derives ship set from the real import graph
  and fails on Node-builtin contamination; `tools/run-contract-tests.mjs`
  discovers 79 tests (47 node, 32 browser); `tools/regenerate_browser_contract_bundles.mjs`
  hardcodes a machine-local absolute Playwright path
  (`/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/...`).

### 2.3 Documentation & process surfaces

- `docs/release-gates.md` (352 lines): RG-001…RG-07x registry; current mix
  55 PARTIAL / 4 PASS / 0 FAIL / 0 OPEN per the 2026-08-25 closure pass entry
  in `progress.md`; every row carries acceptance oracle + evidence + falsifier.
- `docs/decisions.md`: 59 decision records (D-001…) with options considered,
  trade-offs, revisit triggers — genuinely decision-provenance-grade.
- Task queue: `docs/task-inventory-2026-08-25.md` (explicit + implicit tasks
  with maintenance rule), `task_plan.md` (36 phases), `findings.md` (~1,780
  lines), `progress.md` (~2,539 lines).
- Prior audits consulted and reconciled:
  - `comprehensive-repository-audit-and-first-principles-evaluation-2026-08-25.md`
  - `comprehensive-findings-tasks-and-first-principles-audit.md`
  - `full-persona-audit-2026-08-26.md`
  - Plus 60+ persona-scoped audits under `docs/audits/`.

---

## 3. Explicit findings inventory (with doctrine alignment evaluation)

Explicit = named in the repo's own registries (release gates, decisions,
task inventory, phase plan). Each evaluated on three axes:
**FP** = first-principles derivation; **LT** = long-term viability;
**DA** = doctrine alignment. Verdicts: Aligned / Aligned-with-risk / Misaligned.

### 3.1 Architecture-level explicit findings

| ID | Finding | Source | FP | LT | DA | Notes |
|---|---|---|---|---|---|---|
| E-01 | Source-immutability model: mutations are event streams over immutable bytes; SHA-256 digests gate staleness | D-010, RG-017/018 | **Aligned** — derives directly from "a PDF edit must never destroy what the user did not touch" | High — byte-prefix preservation survives any future writer swap | **Aligned** — enforced post-write by byte-exact prefix guard, not just claimed | The single strongest first-principles commitment in the repo |
| E-02 | Provider-neutral contracts (native PDFKit behind `PDFKitProvider`; browser pdf-lib/pdf.js behind same JSON shapes) | D-002, shared-contracts.md | **Aligned** — avoids platform lock-in as a derived consequence, not dogma | High — enables provider swaps without consumer churn | **Aligned** — parity evidence required before any claim | |
| E-03 | Fail-closed security posture: preflight describes risk; mutation gates reject unknown states; XFA/signature edits blocked pending acknowledgment | RG-014/015, web guards | **Aligned** — "unknown ⇒ refuse" is the correct default for irreversible document mutation | High | **Aligned** — matches doctrine authorization envelope | |
| E-04 | Reviewed-completion discipline: detectors never silently promote suggestions to edits; silent autofill forbidden by policy | D-001, reviewed-completion-metrics.mjs | **Aligned** — probabilistic inference ≠ ground truth (epistemic honesty pillar) | High | **Aligned** — human approval gate preserved | |
| E-05 | Multi-oracle fidelity: exports reopened via Poppler/MuPDF/PDFKit/qpdf/veraPDF rather than trusting the writer | benchmark validators, RG-016 | **Aligned** — writer self-validation is circular; independence is required | High | **Aligned** — Tier-3+ evidence culture made executable | |
| E-06 | Encrypted template/profile vaults; Keychain custody; value-free audit journals; cross-device zero-knowledge bundles | RG-023–028, F-023–025 | **Aligned** — template coordinates + profile values are PII | High | **Aligned** — S0/S1 sensitivity respected; secure-deletion & Keychain-loss recovery remain open (honestly gated) | |
| E-07 | Deterministic crash-safe recovery (generation-keyed atomic swap) | Recovery harness, RG-029/030 | **Aligned** — interruption during write must leave previous committed state intact | High | **Aligned** — S2-style interruption tests exist | GUI-driven termination sweep still open (RG-029 remainder) |
| E-08 | Release-gate registry with falsifiers; "no unrestricted release claim while hard gate OPEN/BLOCKED/FAIL" | docs/release-gates.md | **Aligned** — converts honesty into an enforceable artifact | High | **Aligned** — this registry is the doctrine's truth taxonomy operationalized | Registry itself needs drift control (see I-03) |

### 3.2 Process/doctrine explicit findings

| ID | Finding | FP | LT | DA | Notes |
|---|---|---|---|---|---|
| E-09 | Git-mutation restraint: months of work accumulated without commits (~dozens modified/untracked files today) | Mixed | **Risk** — unrecovered work is one bad `checkout` away from loss; long-term viability of evidence depends on durable history | **Aligned with rule, misaligned with spirit** — doctrine forbids unauthorized Git mutation, which is correct; but nothing schedules the owner-decision moment, so the exception becomes permanent | Owner gate needed (see plan P-0) |
| E-10 | Parallel-work protocol exists (check mtime/git status; don't race contested files; document precisely instead) | task-inventory §Parallel-work protocol | Sound | High | **Aligned** but currently violated in effect: two collisions observed today (L-1 mid-edit build break; L-2 malformed import merge). Protocol lacks a lightweight claim/lease mechanism |
| E-11 | Documentation-first completion ("documentation is part of completion") | release-gates header | Sound | High | **Aligned**; however doc volume now creates reconciliation debt (I-01/I-03) |
| E-12 | Zero external dependency policy (Swift) + vendored-only web deps | Package.swift, web/vendor | **Aligned** — supply-chain minimization is a legitimate security first principle | Moderate-High — blocks convenient libs; acceptable given air-gap product thesis | **Aligned**; pdf-lib missing in-bundle version stamp weakens provenance (F-W9) |

---

## 4. Implicit findings inventory (surfaced by this audit)

Implicit = not named in any registry; discovered by inspection or live run.
Each carries truth label, axis verdicts, and disposition.

### 4.1 Immediate / blocking (Observed today)

| ID | Finding | Truth | Axis verdicts | Disposition |
|---|---|---|---|---|
| I-01 | **Build broken by in-flight edit** (L-1). `swift build` errors at `PDFIncrementalFormWriter.swift:249` (use of local `widths` before declaration) and `:263` (`applyPngUpPredictor` not in scope). File is +91/−9 uncommitted; likely a partially-applied extraction of a PNG-up-predictor helper. The old AppModel blocker recorded in the task inventory is gone. | Observed T1 | FP: neutral (process issue). LT: high risk if stacked on. DA: violates "verify before finalize" habit if the lane finished without building | Document precisely; repair when file quiet (owner/lane), then re-run `swift test` to confirm the 226-test baseline |
| I-02 | **Malformed import collision** (L-2): `Tests/pdf-signature-guard_test.mjs:10-11` — stray `import {` immediately followed by inserted `import { pdfPython } ...`, breaking parse of the module and failing the RG-014 signature-guard test suite before any assertion. Also note `Tests/pdf-python.mjs:17` hardcodes a user-specific absolute path `/Users/pranay/.workbuddy-ai/...` (works via env-var override `$PDF_PYTHON`, but the fallback chain embeds a machine-local path in-repo) | Observed T2 | DA: parallel-edit collision; also portability finding (machine-local path ×2 — see F-T1) | One-line repair when file quiet; add import-block placement convention |
| I-03 | **Documentation drift / contested status conflicts between audit docs**: RG-001 recorded `FAIL` in `full-persona-audit-2026-08-26.md` while `release-gates.md` shows `PARTIAL` with delivered evidence (appearance streams, compressed-object support, tagged preservation). The 2026-08-25 comprehensive audit claims "zero React dependencies" — falsified by `web/app/package.json` (React 19.1). Older audits are not marked superseded | Contested → resolved toward newer registry | DA: violates "if a source is stale, mark superseded" (doctrine §0) | Add supersession banners to stale audits; make release-gates.md the sole status authority |
| I-04 | **Flaky browser tests**: first full run had 5 timeouts (67/79), second run 7 failures (72/79) with different composition. Timeouts at 180 s each also make the suite slow (~20 min). Flakiness erodes trust in exactly the evidence system the project is built on | Observed T3 | FP: evidence integrity requires determinism. LT: high. DA: passing counts are not proof — flaky reds train agents/humans to ignore red | De-flake: identify timing-sensitive tests, quarantine with explicit flake label + tracking issue-style entry, raise determinism (fixed ports, waits on conditions not sleeps) |

### 4.2 Structural / native-plane implicit findings

| ID | Finding | Truth | Axis verdicts | Disposition |
|---|---|---|---|---|
| F-N1 | **God object**: `AppModel.swift` is 4,910 lines, ~211 functions, mixes search, permissions, lifecycle, replay checkpoints, rendering glue — and lives in a module named `PDFEditorRecovery` whose name describes maybe 15% of its contents | Observed T1 (size), Inferred (ownership mismatch) | FP: single-responsibility violation increases defect surface for the safety-critical state machine. LT: medium risk now, compounding later. DA: additive-value principle says reduce complexity, not grow it | Split along seams (search / field-editing / recovery / rendering glue); rename module to reflect reality; keep behavior-preserving refactor gated by the existing 226-test baseline |
| F-N2 | **Dead production code**: `XFAFormProcessor.swift` and `PDFBatchProcessor.swift` referenced nowhere in Sources outside their own files; only tests touch them | Observed T1 | DA: doctrine forbids "unowned artifacts"; either wire them into a capability lane or explicitly quarantine them like MuPDF/Tesseract were | Decide: promote into a lane with admission evidence, or move to quarantine with reason record |
| F-N3 | **Env-gated termination probe shipped in app binary**: `PDFEditorNativeTerminationProbe` reads env vars to open documents and write result files inside the production executable (`Sources/PDFEditorApp/PDFEditorApp.swift:7`) | Observed T1 | FP: test scaffolding in prod binary expands attack/change surface. LT: low-moderate. DA: workspace mutation boundary blurred | Move probe into the test target / separate debug executable |
| F-N4 | **No Swift tests import `PDFEditorApp`** — all 11 UI files untested at unit level; UI logic correctness relies on manual observation + .mjs browser lane | Observed T1 | LT: accessibility/release gates (RG-006/057/058) demand observation evidence anyway; some view-model logic deserves extraction | Extract testable view-model logic from views; keep pure-SwiftUI rendering under manual/golden observation |
| F-N5 | **Two-language verification split**: heavy behavioral evidence lives in ~85 `.mjs` scripts outside `swift test`; `swift test` sees only the contract/unit layer. No single command proves both planes | Observed T1 | DA: evidence tiers exist but the runner topology makes Tier-3 non-default | Make `run-contract-tests.mjs` + `swift test` a documented combined "full gate" command; eventually CI |
| F-N6 | **`@unchecked Sendable` mutable-state classes** in vault/session stores (`EncryptedPDFTemplateStore`, `EncryptedPDFProfileVault`, `EncryptedProfileStore`, `SessionRecoveryStore`, revision store) | Observed T1 | FP: concurrency safety asserted, not checked. LT: data-race risk in safety-critical custody code | Introduce actor wrappers or structured locking with targeted race tests where feasible |
| F-N7 | Harness copy-paste scaffolding: duplicate type names across executables (`Arguments`×4, `HarnessError`×4); `PDFExperimentParityHarness` declares a Core dependency it doesn't use | Observed T1 | Low severity | Minor cleanup batch |
| F-N8 | **Persona-named test suites** (`ComprehensivePersonaAuditProgramTests`, `HumanAIAuthorityArchitectTests`, `BoundarySystemsArchitectTests`, …) — names encode process, not behavior; risks "checking document presence rather than behavior" (the exact PER-0428 failure mode) | Observed T1 | DA: rename to describe the invariant tested, or verify each actually asserts behavioral properties | Rename/assertion audit — cheap, improves legibility |

### 4.3 Structural / web & tooling implicit findings

| ID | Finding | Truth | Axis verdicts | Disposition |
|---|---|---|---|---|
| F-T1 | **Machine-local paths embedded in tooling/tests**: `tools/regenerate_browser_contract_bundles.mjs:16` hardcodes absolute skill path to Playwright; `Tests/pdf-python.mjs:17` hardcodes `/Users/pranay/.workbuddy-ai/...` python env | Observed T1 | LT: reproducibility off-machine broken. DA: canonical-path hygiene | Resolve via env vars with sane defaults; document in tools/README |
| F-T2 | **pdf-lib vendored bundle carries no version stamp** (unlike PDF.js 4.2.67) — upgrade provenance relies on external memory | Observed T1 | DA: provenance discipline gap | Stamp version in a sidecar constant + record in vendor README |
| F-T3 | **Dual frontend weight**: `web/app.js` legacy 5,543-line vanilla shell coexists with React shell; both maintained against same contracts. Deliberate migration strategy, but unbounded dual maintenance is a cost | Observed T1 | FP: single-source contracts good; duplicated presentation layer is transitional debt | Define the cutover criterion (e.g., React shell reaches feature parity on the five-mode matrix) and record as a decision |
| F-T4 | Companion/server modules live in static web root (known open item, web-plane task 1 in task inventory) — deploy boundary correctly enforced structurally by closure-walking, so risk is contained | Known/open | Aligned-with-risk | Execute the move when companion lane is quiet (already queued) |
| F-T5 | **No CI anywhere**: all verification is agent-initiated. A broken build (I-01) or corrupted test (I-02) persisted until the next human-triggered audit | Observed T1 | FP: gates that aren't automatic are aspirations. LT: highest-leverage infrastructure gap | Even a local pre-commit/pre-stash hook or scheduled runner closes most of the gap without external services (air-gap friendly) |

### 4.4 Cross-cutting / documentation implicit findings

| ID | Finding | Truth | Disposition |
|---|---|---|---|
| F-D1 | Four overlapping queue/status documents (`task_plan.md`, `progress.md`, `findings.md`, `docs/task-inventory-*.md`) with a stated maintenance rule that is honored inconsistently (e.g., task-inventory item "commit the working tree" still open while tree keeps growing) | Observed T1 | Keep task-inventory as the single queue; progress/findings become append-only ledgers; add supersession banners |
| F-D2 | Audit corpus (60+ files) has no index or freshness metadata; consumers can't tell current from stale | Observed T1 | Generate an index table (date, persona, status: current/superseded) in docs/audits/README.md |
| F-D3 | Repo weight: 5.3 MB `Web-Prototype.zip` + hundreds of benchmark result artifacts tracked in git — deliberate evidence preservation (per task-inventory), acceptable until clone weight bites | Known/open | Revisit trigger already defined; keep |
| F-D4 | Working tree accumulation (E-09): ~30+ modified/untracked files spanning multiple lanes; a disk failure or bad checkout loses days of evidence-bearing work | Observed T1 | Owner Git-authorization gate — top of implementation plan |

---

## 5. First-principles evaluation of the overall program

Applying the persona's central question to the *system design itself*:

**What is derivable from first principles and correctly derived?**

1. A PDF is a rendered artifact whose byte stream encodes appearance; therefore
   safe editing preserves bytes you didn't intend to change ⇒ immutable-source +
   operation-log architecture (E-01). Correctly derived and enforced.
2. Heuristic geometry detection cannot be authoritative ⇒ candidates + review
   + fusion with abstention (E-04). Correctly derived.
3. A writer validating its own output is circular ⇒ independent-engine oracles
   (E-05). Correctly derived, unusually rigorous.
4. Local-first privacy ⇒ air-gapped CSP, vendored deps, encrypted vaults,
   value-free logging (E-06, RG-028). Consistently derived across planes.
5. Crash during write must be recoverable ⇒ generation-keyed atomic swap (E-07).

**Where first principles are not yet fully honored:**

1. **Verification determinism** (I-04): an evidence culture built on S0–S3
   sensitivity labels is undermined by flaky browser tests — a flaky red is a
   systematic falsehood injected into the truth system.
2. **Single canonical truth** (I-03, F-D1): doctrine demands one canonical
   owner per fact class; status facts currently have competing owners.
3. **Automaticity of gates** (F-T5): a gate that requires an agent to remember
   to run it is not a gate; it's a custom.

**Verdict:** the program is first-principles-aligned in architecture and
epistemically honest to a degree rare in software projects. The gaps are in
*operationalizing* the principles (automation, deduplication of status
authority, de-flaking), not in the principles themselves.

## 6. Long-term viability evaluation

- **Provider decoupling** means no engine decision is irreversible (MuPDF stays
  license-gated per D-003; PDFBox lane preserved; custom writer adopted where
  proven). Viable.
- **Zero-dependency Swift core** compiles for future platforms; macOS-15 floor
  is the main constraint. Viable.
- **Contract versioning** (major.minor, backward-compatible decoders) supports
  native/web divergence over time. Viable.
- **Risks to longevity:** AppModel monolith growth (F-N1); dual-frontend
  maintenance without a cutover criterion (F-T3); documentation mass exceeding
  reconcile capacity (F-D1/F-D2); evidence artifacts growing unboundedly
  (F-D3, tracked).
- **Missing for durability:** Git history itself. Until the working tree is
  committed (E-09/F-D4), the project's entire durable state lives outside
  version control's protection. This is the single largest long-term risk.

## 7. Doctrine alignment scorecard

| Doctrine requirement | Status | Evidence |
|---|---|---|
| Start from live truth | Partially honored — this audit found undocumented red state (I-01..I-04) | This document §1 |
| Truth taxonomy labeling | Strongly honored in gates/findings; audit docs sometimes assert without labels | release-gates rows vs full-persona-audit |
| Proportional rigor / S0–S3 | Honored in design (S2 interruption tests exist); flakiness erodes it (I-04) | ChaosEngineeringFaultInjectionTests; contract runs |
| Authorization envelope (incl. Git gate) | Honored literally; needs scheduled owner decisions (E-09) | git status; decisions.md approval sources |
| Canonical paths / single source of truth | Violated in status-documentation layer (I-03, F-D1) | Conflicting RG-001 records |
| Additive value / no unowned artifacts | Violated by dead code (F-N2) and stale unaudited docs | XFAFormProcessor/PDFBatchProcessor |
| Parallel-work coordination | Protocol exists; enforcement absent; collisions occurred today (I-01, I-02) | git status + file inspection |
| Documentation as part of completion | Over-honored to the point of drift debt (F-D1/D2) | 60+ audit files, no index |

## 8. What else can be done / improved / added ("make it the best")

Ordered by leverage-to-cost ratio:

1. **Automation layer (new):** a single `make verify` / `tools/verify-all.sh`
   running `swift build && swift test && node tools/run-contract-tests.mjs`,
   plus a launchd timer or pre-commit hook. Closes I-01/I-02 detection latency
   permanently. Air-gap compatible (all local).
2. **Status-authority consolidation:** release-gates.md becomes the only place
   gate state lives; task-inventory becomes the only task queue; older docs get
   superseded banners; generate `docs/audits/INDEX.md`.
3. **De-flaking program:** classify the 79 contract tests into deterministic /
   timing-sensitive; fix waits-on-conditions; quarantine persistent flakes with
   labeled reasons; target 79/79 twice consecutively as the green definition.
4. **Git checkpoint program (owner gate):** staged, described commits of the
   current tree split by subsystem; establishes the recovery baseline everything
   else assumes.
5. **Structural refactors (behavior-preserving, test-baseline-gated):**
   AppModel decomposition; Recovery-module renaming; termination probe
   relocation; dead-code disposition (F-N2).
6. **Portability hygiene:** remove machine-local paths (F-T1); stamp pdf-lib
   version (F-T2).
7. **Frontend cutover decision:** define React-shell parity criteria and a
   sunset date for the vanilla app.js presentation layer (keep contract layer).
8. **Accessibility observation passes:** the remaining RG-006/007/057/058/059
   work is human-observation evidence — schedule VoiceOver/screen-reader
   sessions and record results as Tier-4 evidence.
9. **Concurrency hardening:** actor-wrap vault/session stores (F-N6) with race-
   targeted tests.
10. **Strategic bets already identified in prior audits** (GPU rendering, local
    LLM fill assist, PAdES signatures, PDF/UA remediation, fuzzing) remain valid
    but should stay strictly sequenced *after* the automation/determinism layer —
    new capabilities on a red, flaky foundation compound risk, not value.

## 9. Session evidence ledger

| Evidence | Artifact / command | Tier |
|---|---|---|
| Build failure details | `swift build` output: `PDFIncrementalFormWriter.swift:249` (use before decl), `:263` (scope) | T1 Observed |
| Dirty-file scale | `git diff --stat Sources/PDFEditorCore/PDFIncrementalFormWriter.swift` → +91/−9 | T1 Observed |
| Contract suite results | Run 1: 67/79 (12 failed incl. 5 timeouts); Run 2: 72/79 (7 failed); saved `tmp/audit-contract-results.json` | T3 Observed |
| Malformed import | `head Tests/pdf-signature-guard_test.mjs` lines 10–11; direct node execution SyntaxError | T2 Observed |
| Machine-local paths | `tools/regenerate_browser_contract_bundles.mjs:16`; `Tests/pdf-python.mjs:17` | T1 Observed |
| React shell existence | `web/app/package.json` (react ^19.1, vite ^6.3) | T1 Observed |
| Gate-status conflict | `docs/audits/full-persona-audit-2026-08-26.md` (RG-001 FAIL) vs `docs/release-gates.md` RG-001 (PARTIAL, extensive evidence) | Contested→resolved |
| Prior native baseline | `progress.md` 2026-08-26 entry: 226/226 tests, 32 suites (not re-verifiable today due to I-01) | Recorded, Unverified-today |
| Native/web structure inventories | Two parallel exploration passes summarized in §2 | T1 Observed |
| Persona source | `PER-0428` docx converted via textutil; spec quoted in §0 of conversation | T1 Observed |

**No source files were modified by this audit.** Written artifacts: this
document and `docs/roadmaps/implementation-plan-2026-08-26.md`.
