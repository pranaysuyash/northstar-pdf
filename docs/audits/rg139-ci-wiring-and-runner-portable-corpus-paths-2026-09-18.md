# RG-139 CI Wiring + Runner-Portable Corpus Paths — Audit Record (2026-09-18)

**Status:** IMPLEMENTATION LANDED AND VERIFIED LOCALLY; CI ENFORCEMENT NOT YET
OBSERVED EXECUTING — blocked upstream by two unrelated CI failures. This record
states both facts with receipts, because a wired gate that has never run is not
the same claim as a gate that has run and passed.

**Truth-status legend:** **[Observed]** = read directly from live files, command
output, or GitHub API responses on 2026-09-18; **[Verified]** = independently
checked with a stated tier/sensitivity; **[Inferred]** = best explanation,
assumption named; **[Unknown]** = check named. Per OPERATING_DOCTRINE §2.

---

## 1. What was wired (the RG-139 CI job)

**[Observed]** `.github/workflows/ci.yml`, `swift-gate` job (macos-15), step
`Raster blend gate (RG-139)` (lines ~86–136), introduced in commit `a89da99`
("feat(workspace): pin evidence chain, land launch audits and native sim
evidence", 2026-09-14). The step:

1. Reruns the permanent gate suite fresh: `swift test --filter
   RasterBlendCalibrationGate` — the report is a product of this run, not a
   committed file (§5 evidence-based; same fresh-regeneration pattern as the
   RG-136 fast lane and the acroform-parity gate).
2. Validates the persisted report
   `benchmark/results/raster-blend-gate/raster-blend-gate-report.json` with an
   inline Python gate: schema `pdf-editor.raster-blend-gate`, corpus floor ≥ 50
   (of the 56-fixture F-3 corpus), `gatePassed == true`, per-blend
   `minPositive ≥ 0.90` for both gated blends (95/3/2 shipped, 85/8/7 target),
   zero evidence-bearing hard-negative promotions (RG-138 floor), non-empty
   blend rows.
3. Uploads the report as the `raster-blend-gate` workflow artifact
   (`if: always()`, `if-no-files-found: error`) — same artifact-parity pattern
   as the other gates.

Fail-closed semantics mirror the RG-136 WER gate: any failure prints
`::error::` and exits non-zero, failing the `swift-gate` job, which fails the
`CI evidence gate` job (`needs.swift-gate.result != success` → exit 1,
**[Observed]** ci.yml ~line 557).

**Design property preserved [Verified, Tier 2 / S1]:** the gate's assertions
are in the test; the CI step only re-runs the test and re-checks the JSON. The
opt-in diagnostics flag `PDF_EDITOR_BLEND_GATE_DIAG=1` (added 2026-09-12,
**[Observed]** `RasterBlendCalibrationGateTests.swift:133-144`) changes
printing only, never assertions, so a CI run and a local diag run measure the
same thing.

## 2. What was changed for runner portability (corpus paths)

**[Observed]** commit `4a2421f` ("fix(tests): repo-relative corpus paths
everywhere; not_ran skips for tool-dependent tests", 2026-09-15 00:02 IST):

1. **New `Tests/PDFEditorCoreTests/TestRepoRoot.swift`** — resolves the repo
   root from `#filePath` (compile-time file location), exposing `url`,
   `prefix`, `benchmarkResults`, and `path(_:)`. Because `#filePath` is baked
   per-file at compile time, corpus paths stay correct wherever the repo is
   checked out — CI runners check out to `/Users/runner/work/northstar-pdf/`
   **[Observed in run 35200795630 logs]**, where any hardcoded
   `/Users/pranay/...` path could only ever fail.
2. **17 Swift test files, 28 hardcoded absolute paths converted** — including
   every calibration-family consumer: `LayoutFingerprintThresholdCalibrationTests`
   (F-3), `CalibrationCorpusVerificationTests`,
   `FullCorpusRasterRecalibrationTests`, `RasterWeightRecalibrationTests`,
   `EvidenceFloorAbstentionTests`, plus detector, OCR-confirm-lane, and
   manifest-presence gates. `RasterBlendCalibrationGateTests` resolves its
   corpus root from its own `#filePath` **[Observed, line 43-46]** with the
   honest comment that the previous hardcoded path "would have extracted zero
   fixtures on CI."
3. **One CI-executed .mjs converted** (`pdf_object_preservation_test.mjs`) and
   tool-dependent tests moved to the repo's absence=`not_ran` convention
   (PopplerRendererTests, Form6DetectorTests, the qpdf-dependent preservation
   validator) instead of failing closed on missing local tools.

**Scope honesty [Observed]:** 13 other `.mjs` test files still contain
hardcoded `/Users/pranay/...` paths. None of them is referenced by any CI job
(checked by name against every `CORE_TESTS`/job list in ci.yml — 0 refs for
12 of 13; `pdf-source-preserving-lane_test.mjs` is referenced only in a
comment). They run only on the owner's machine today, so the portability
defect is dormant, not fixed — recorded as the residual in §5.

## 3. Verification status — the honest ledger

**Local (Tier 2 / S1, multiple runs):** `RasterBlendCalibrationGateTests`
4/4 pass on the current binary with pinned values minPositive **0.9251**
(95/3/2) and **0.9104** (85/8/7), zero evidence promotions, 6 abstentions
each — re-confirmed 2026-09-12 (multiple runs), and **[Observed]** passing
*inside CI itself* in run 35200795630's `swift test` step:
`✔ Suite "Raster Blend Calibration Gate (85/8/7)" passed after 274.366
seconds` (2026-09-17 08:48:13Z). The F-3 suite also passed in-run (85.7s).
So the gate logic and the portability fix both execute green on a real CI
runner — as part of the unfiltered suite.

**CI enforcement (the dedicated step): NOT YET OBSERVED EXECUTING.**
**[Observed via `gh run view` step conclusions, runs 34948210982 (09-15),
35074534770 (09-16), 35200795630 (09-17), 35323352649 (09-18)]:** in every
scheduled run, `Raster blend gate (RG-139)` = **skipped**, because the
sequential step before it failed:

- **09-15 → 09-17:** `Calibration gate (regenerate + validate 60-fixture
  corpus)` (`scripts/calibration-gate.sh`) failed **after** the F-3 test
  passed (85.7s), at validation: `✗ maxHardNegative 1 > 0.99 — possible
  regression beyond graphics-heavy cluster`. **[Inferred, mechanism named]:**
  the script's validator is not RG-138-aware — the F-3 test records
  above-threshold evidence-less hard negatives as *abstentions* (the
  evidence floor), while the script reads the raw `maxHardNegative` count
  from the artifact and treats 1 as a regression. The gate semantics
  diverged from the gate test; the script needs the same
  evidence-floor-aware reading the test applies.
- **09-18:** `Swift test` itself failed on the known OCRConfirmLane
  semaphore-bound class (4 tests, 367s each, bounded-acquire 300s message
  fired correctly with its own remediation text — the flaky-register
  2026-09-12 pattern manifesting on a cold runner), and the WER heavy gate
  failed separately; all gate steps skipped.

Also **[Observed]**: zero of the last 20 CI runs concluded `success` — the
repo's main branch has been red throughout the wiring window, so no run has
reached the RG-139 step. The upload steps (`Upload raster blend gate
artifacts`) succeeded in every run because `if: always()` uploads the
committed report file even when the gate never ran — an artifact upload is
therefore **not** evidence of gate execution.

## 4. Falsifier

Per §9 (falsifiers recorded in durable docs):

1. **CI wiring falsifier:** "The `Raster blend gate (RG-139)` step exists in
   ci.yml, runs `swift test --filter RasterBlendCalibrationGate` fresh, and
   its Python validator fails the job on schema mismatch, corpus < 50,
   `gatePassed=false`, minPositive < 0.90, or any evidence promotion." If any
   of these is not true of the working tree, this record is false. — Checked
   2026-09-18 against the live file: **holds**.
2. **Portability falsifier:** "No Swift test file contains a hardcoded
   `/Users/pranay/...` corpus path outside a comment." — Checked 2026-09-18:
   exactly 1 match in `Tests/**.swift`, and it is the doc comment in
   `RasterBlendCalibrationGateTests.swift:44` describing the removed defect.
   **Holds** for Swift. The 13 non-CI `.mjs` files are the recorded residual.
3. **Enforcement falsifier (open):** "The RG-139 step has executed and passed
   in a CI run." — Currently **does not hold**; it is the gate's open
   closure condition. The first scheduled/push run that clears the upstream
   calibration-gate.sh and Swift-test failures will close it.

## 5. Residuals and next checks (each named, not hidden)

1. ~~**`scripts/calibration-gate.sh` is not evidence-floor-aware** — its
   `maxHardNegative` validation contradicts the F-3 test's RG-138 abstention
   semantics (the test records evidence-less hard negatives as abstentions;
   the script counts them as regressions). This is what has blocked the
   RG-139 step since 09-15.~~ **Resolved by commit `c2eb7fa` (2026-09-15,
   after the CI runs this record analyzed): the script now gates
   `maxHardNegativeWithEvidence` (0.99 bound) and reports the raw
   `maxHardNegative` as info-only; verified end-to-end green 2026-09-18
   (F-3 regeneration 63.5s + validation pass, local) with S2 reproduction
   of the old failure (old rule fails on the current artifact — the exact
   09-17 CI error — new rule passes). Residual push-state note: `c2eb7fa`
   sits on local main ahead of origin/main with this record's companion
   fixes; origin/main had not received it as of 2026-09-18, so the blocked
   CI state persisted on remote until push.**
2. **OCRConfirmLane semaphore-bound on CI cold runners** (09-18 failure) —
   the 300s bounded acquire is exceeded when the serialized suite queues
   behind slow first-build extraction on a 2-vCPU-class runner. ~~Options
   recorded for the owner: raise the bound for CI, or make the lane's
   acquire bound environment-scaled.~~ **Resolved 2026-09-18 (same day):**
   the acquire bound is now environment-scaled in all three
   `SharedHeavyTestResourceLock` copies — explicit
   `PDF_EDITOR_HEAVY_SEMAPHORE_ACQUIRE_BOUND` override, CI (GITHUB_ACTIONS /
   XCODE_ACTION) 5400s, local 600s; the fail-closed message reports the
   actual scaled bound (it previously hardcoded "300s" — a stale-text bug
   that made CI logs lie about the code). Verified: confirm-lane suite 8/8,
   recovery 4/4, mutation proof of the override + fail-closed path (external
   holder, 1s bound → Code=3 in 1.9s naming the override);
   `docs/flaky-register.md` 2026-09-18 entry records the CI manifestation,
   scaled design, and extended diagnostic rule. Already committed locally
   (unpushed) as part of the bound-raise series; this scaling is the
   working-tree refinement on top.
3. **13 non-CI `.mjs` tests still carry hardcoded paths** — dormant (not run
   by CI), but the same defect class. ~~The `not_ran`/portability convention
   should be extended to them when they next enter a CI job.~~ **Closed
   2026-09-18 (same day), see the Addendum below:** all converted to the
   derived-path convention with three root-cause repairs (web-module Python
   resolver bypass, manifest-row parser drop, dead env-var name) verified S2.
4. **RG-139 step execution receipt** — to be appended here (dated addendum)
   the first time a CI run shows `Raster blend gate (RG-139): success`.

## 6. Doctrine alignment

- §5 Evidence-based: gate reruns fresh, never trusts committed state;
  values measured on the corpus (0.9251/0.9104), not asserted.
- §10 Failure: precision constraint (zero evidence promotions) encoded in
  CI, not just recall; corpus floor prevents silent shrinkage.
- §2 Truth taxonomy: this record separates *implemented* [Verified] from
  *CI-enforced* [not yet observed] instead of merging them.
- §3 Proportional rigor: local Tier 2/S1 receipts + in-CI suite pass
  (Tier 3) for the logic; the enforcement claim is explicitly left at
  "check needed" until a run executes the step.

**Cross-references:** `docs/release-gates.md` RG-139 row (CI wiring
paragraph); `Tests/PDFEditorCoreTests/RasterBlendCalibrationGateTests.swift`;
`Tests/PDFEditorCoreTests/TestRepoRoot.swift`; `scripts/calibration-gate.sh`;
`docs/audits/blend-sweep-binding-constraint-analysis-2026-09-03.md`;
`docs/audits/graded-occupancy-implementation-2026-09-03.md`;
`docs/flaky-register.md` (2026-09-12 semaphore + ENOSPC entries).

---

## Addendum 2026-09-18 (same day): Residual 3 closed — mjs portability + three root-cause repairs

**Residual 3 (13 non-CI `.mjs` files with hardcoded paths) is CLOSED.** All 12
test files and the shared Python resolver were converted to the derived-path
convention (`path.resolve(new URL("..", import.meta.url).pathname)` /
`fileURLToPath(import.meta.url)`, matching the `4a2421f` exemplar). **[Verified,
falsifier re-run]**: `grep -rl "/Users/pranay" Tests/ --include="*.mjs"` now
matches 1 file, comment-only (the explanatory comment in
`cross_project_evidence_ledger_parity_test.mjs`); zero executable occurrences.

The conversion surfaced three pre-existing root-cause defects in the same
pipeline; per §10 doctrine they were repaired, not waived, and each is S2
(failed for the stated reason before, passes after):

1. **Web runtime bypassed the Python resolver** [Observed]:
   `web/pdf-sanitize.mjs:59`, `web/pdf-action-neutralize.mjs:53`, and
   `web/pdf-object-inspect.mjs:33` spawned literal `"python3"`, violating the
   project's own documented rule ("Tests must never hardcode python3 for
   pikepdf work") — the root cause of 7 test files failing with
   `ModuleNotFoundError: No module named 'pikepdf'` (identical at HEAD, so the
   failures pre-dated this task but blocked verification). Repair: the
   canonical resolver now lives at **`web/pdf-python.mjs`** (companion-runtime
   placement; `$PDF_PYTHON` → PATH `python3`+pikepdf probe → documented
   pdf-utils venv **derived from `$HOME`**, removing the last machine-local
   literal) and the three modules import it; **`Tests/pdf-python.mjs` is a
   one-line re-export shim**, keeping all 12 historical import sites valid
   with one source of truth. S2: 7/7 failing tests → 7/7 pass.
2. **Manifest parser silently dropped a governed row** [Observed]:
   `manifestEntries()` required `| ` immediately after the digest, but the
   `public-sample-form.pdf` row carries the D-054 provenance note inside the
   digest cell — parsed 17 of 18 rows, failing `cases.length ===
   manifest.length` (18 ≠ 17). The manifest document was correct; the test
   parser was too strict. Repair: regex no longer requires the trailing `|`.
   S2: 18≠17 → pass, and an independent parse confirms 18 rows.
3. **Dead environment-variable name between parent/child tests** [Observed]:
   the ledger test exported `PDF_PROOF_BASE_URL` (zero consumers repo-wide)
   while the spawned `pdf_contract_parity_test.mjs` requires
   `PDF_EDITOR_BASE_URL`. Repair: parent passes the child's actual contract
   name. S2: FATAL → full end-to-end pass (server start → parity run →
   `passed: true`, 0 unexpected mismatches).

**Honest boundary [Observed]:** the ledger fixture's governed
`canonicalOwner` value still records the historical absolute path; the test's
assertion was converted to a repository-identity (basename) contract instead
of silently migrating governed data. Migrating that fixture remains a
separate, governed decision.

**Final test evidence (all 12 converted files, same binary state):**
fixture-corpus-sweep, pdf-sanitize, pdf-action-neutralize,
pdf-attachment-scanner, pdf-hidden-revision-analyzer,
pdf-incremental-form-writer, pdf-sanitize-audited, pdf-signature-guard,
pdf-xfa-guard, pdf-source-preserving-lane,
cross_project_evidence_ledger_parity, perf-continuous-view — all exit 0.
(`rotated_operation_replay_test` also consumes the shim; it remains
env-gated on `PDF_EDITOR_BASE_URL` by design and was not modified.)

---

## Addendum 2026-09-18 (b): Fail-closed / env-scaled helper audit (semaphore-class sweep)

**Scope [Observed]:** every fail-closed helper with a reader-facing duration or
diagnostic (`NSLocalizedDescriptionKey` — 10 sites), every env-scaled or
env-gated test helper (`processInfo.environment[` — 10 sites across 7 files),
bounded child-process waits in Tests, and `swift test`'s CI invocation shape
(full target, no skip lists — so every suite IS CI-enforced; the
unenforcement risk lives only in the helper wiring, not in CI selection).

**Findings:**

1. **Semaphore helpers (3 copies): CLEAN post-2026-09-18** — bound
   environment-scaled, message reports the effective value, override named,
   wiring CI-proven by the fail-fast `Semaphore wiring proof` step (both legs
   verified locally from the extracted workflow script).
2. **`RecoveryCrashInterruptionTests` startup deadline (480s): IN-CLASS
   DEFECT, FIXED this audit** — the child-startup deadline was a flat literal
   and its failure message ("within the startup deadline") did not state the
   value or any remediation: a reader could not tell what fired, forcing
   manual starvation-vs-regression classification (the exact manual triage
   this session performed on the 09-12 chunk-A failure). Repair mirrors the
   semaphore pattern: explicit `PDF_EDITOR_RECOVERY_STARTUP_DEADLINE`
   override, message reports the effective seconds and names the override.
   Verified: build clean, suite 4/4 (2.9s).
3. **Env-gated fixture helpers (PDF_EDITOR_PUBLIC_ACROFORM_INPUT,
   _INCREMENTAL_CORPUS_DIR, _FORM6_INPUT, _RG001_ARTIFACTS): CORRECT, no
   defect** — they gate on file *existence* (not on the env var merely being
   set), which is exactly the right semantics: CI checks out the tracked
   fixtures but must be handed their paths explicitly; absent
   configuration yields an honest skip rather than a false pass. Documented
   expectation, verified in guard code — no action.
4. **`OCRCompanionBenchmarkTests` not_ran guards (12 sites): CORRECT** —
   tool absence (tesseract/paddle/marker venvs) records `not_ran` provenance
   and exits cleanly per the `4a2421f` convention; where tools exist the
   strict assertions apply. No message/code drift found.
5. **`ReadGapFeatureTests` fixture-missing throw: CORRECT** — fail-closed
   with the resolved path in the message (tracked fixture; a missing file is
   a real defect and rightly fails rather than skips).
6. **Production-side `OCRConfirmLane.providerTimeout` (30s default):
   CORRECT** — timeout degrades to abstention (fail-closed for the decision,
   not a crash), which is the documented §8 semantics; load sensitivity is
   absorbed by the test-side lock, not by weakening the production bound.
   No change.

**Disposition summary:** 1 in-class defect found and fixed (finding 2);
6 areas verified clean with dated evidence. The sweep's meta-conclusion: the
repo's remaining fail-closed helpers already follow the honest pattern
(value-reporting messages, existence-based gating, provenance-recording
skips); the semaphore and recovery-deadline were the two outliers, and both
are now closed.
