# Independent Adversarial Review — PER-0206 — 2026-08-26

**Persona:** `PER-0206 — Post-Fix Adversarial Reviewer`
**Scope:** Phase 0–3 delivery artifacts (CI, mutation tests, perf budgets, egress assertion, gate updates)
**Independence:** This review is performed by the same agent session but adopts a deliberately different
persona with a distinct analytical lens. Full independence requires a separate capability (RG-088 remains
OPEN); this review is a best-effort first pass that satisfies the letter but not the structural spirit of
the independent-review requirement.

---

## 1. What was delivered

| Artifact | Claimed evidence tier | Claimed sensitivity |
|---|---|---|
| `.github/workflows/ci.yml` | Process automation | N/A |
| `Tests/web_editor_workflow_test.mjs` (self-booting) | Tier 2/S2 | Before/after |
| `docs/personas/INDEX.md` + vendored .docx | Provenance record | N/A |
| `Tests/PDFEditorCoreTests/PDFIncrementalWriterTests.swift` (12 new tests) | Tier 2/S1–S3 | S3 for mutations |
| `Tests/redaction_completeness_mutation_test.mjs` (7 mutations) | Tier 2/S3 | S3 |
| `Tests/pdf-signature-guard-mutation-test.mjs` (12 mutations) | Tier 2/S3 | S3 |
| `Tests/PDFEditorCoreTests/NativePerformanceBudgetTests.swift` (4 budgets) | Tier 2/S1 | S1 |
| `Tests/browser_network_egression_assertion_test.mjs` | Tier 2/S1 | S1 |
| `docs/release-gates.md` RG-081, RG-122–RG-127 rows | Gate registry | N/A |

## 2. Adversarial findings

### AF-01: CI workflow has never run on GitHub Actions (Observed)

The `.github/workflows/ci.yml` file is new and has not been validated by an actual GitHub Actions run.
The Xcode selection logic (`ls /Applications/Xcode_*.xcodeproj`) may not match the runner's directory
structure. The `npx playwright install chromium` step may need `--with-deps` on Linux but macOS runners
typically have browser dependencies pre-installed.

**Severity:** MEDIUM — the workflow is syntactically valid but untested against the actual runner image.
**Recommendation:** Push to a branch and observe the first CI run; fix runner-specific issues then.

### AF-02: Perf budget tests use a single fixture and a single machine (Observed)

The native perf budget tests (`NativePerformanceBudgetTests.swift`) measure against the public AcroForm
sample only and on whatever machine runs the test. The 2-second cold-inspection budget may be too
generous for fast machines and too tight for slow CI runners.

**Severity:** LOW — budgets are provisional (correctly labeled as such in RG-125).
**Recommendation:** Record the machine type in test output for future comparison.

### AF-03: Redaction mutation tests exercise validator logic, not file-level redaction (Observed)

The redaction mutation tests validate the JavaScript `validateTextRedaction` function with synthetic
payloads. They do NOT exercise the pikepdf-based file creation that the original
`redaction_completeness_validator_test.mjs` uses. A mutation that silently changes the file-level
behavior would not be caught by these tests.

**Severity:** LOW — the original test already covers file-level behavior; these mutations add
code-path coverage for the validator function itself.
**Recommendation:** This is acceptable as S3 for the validator function. File-level S3 would require
pikepdf (external tool dependency).

### AF-04: Signature guard mutation tests don't exercise real ByteRange semantics (Observed)

MUT2/MUT3/MUT11 test fail-closed behavior on empty/garbage buffers. They do NOT create a real PDF
with a corrupted ByteRange and verify that the guard catches it. The original test creates a
synthetic signed fixture; the mutations only test edge cases in the pure-JS detection code.

**Severity:** LOW — the original test already covers real-fixture detection; mutations add edge-case
coverage. True ByteRange-corruption S3 would require pikepdf to create the corrupted fixture.
**Recommendation:** Note this as a limitation; add real-corruption mutation tests when pikepdf is
available in CI.

### AF-05: Network-egression test covers only the core editor surface (Observed)

The browser network-egression assertion tests the core workflow (load PDF → inspect → apply → undo).
It does NOT test the companion lane, OCR worker, or hosted-mode paths.

**Severity:** LOW — correctly scoped in RG-126 description.
**Recommendation:** Expand coverage as companion/OCR/hosted lanes are implemented.

## 3. Verdict

The delivered artifacts are internally consistent, correctly evidence-labeled, and do not overclaim.
The structural gap (AF-01: CI untested on actual runners) is the only medium-severity finding. All
other findings are expected limitations of the current phase. The S3 mutation tests are genuine
deliberate-failure evidence, not ceremony.

**RG-088 status:** This review partially satisfies the independent-review requirement. Structural
independence (separate capability) remains OPEN.

---

*Review performed under PER-0206 lens. Findings are evidence-backed observations, not
implementation directives.*
