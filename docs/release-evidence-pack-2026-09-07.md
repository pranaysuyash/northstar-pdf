# Release-Readiness Evidence Pack — 2026-09-07 findings-closure round

**Status:** current as of 2026-09-07 ~12:30 IST · **Owner:** Pranay · **Scope:** native macOS launch lane
**Doctrines:** Operating 8.0, Testing 1.1, Release Readiness 1.0, Documentation 1.1, Security/Privacy/Safety 1.0, Research 1.0 (canonical: `/Users/pranay/Projects/agent-start/doctrines/`)
**Release unit:** Northstar native macOS PDF completion (bounded fill: text/checkbox/choice native fields + reviewed overlays, new-copy export). Web = zero-install companion (deprioritized). No cloud, no e-sign transactions, no XFA authoring, no PDF/UA conformance claim.
**Recommended decision: CONDITIONAL GO** on the bounded unit (conditions below); **NO-GO** on unrestricted production release (unchanged, RG-121 OPEN).

## Readiness profile

| Dimension | Status | Evidence (2026-09-07 unless noted) | Blocker / next |
|---|---|---|---|
| Build | READY (prebuilt) | `.build/debug` binaries used; `swift build` full rebuild exceeds 10-min tool budget | CI warm-cache build |
| Code | READY | Dirty tree preserved, uncommitted, no Git mutations | Owner review before commit |
| Contract/parity | READY | 8/8 persona fixtures `inspected`, exports `validated`; envelope v1.0 uniform | — |
| Focused tests | READY | 96 tests / 11 suites green via `swift test --skip-build` (IncrementalWriter 25, parity+reader+mutation+radio 35, provider+provenance+vault 36); binary newer than all linked sources except app-shell-only `PDFEditorApp.swift` | Full suite: `RecoveryCrashInterruptionTests` hangs in this env (pair-interruption case) — environment-blocked, exact rerun owed |
| Corpus governance | READY | `pdf_corpus_governance_test.mjs` passed:true; `provenance_contract_test.mjs` 14 assets | CI wiring on fixture changes |
| Fixture custody | READY after incident | D-077: Quartz-rewrite (`bb54…`, qpdf exit 3) diagnosed, pristine `5a68…` restored hash-verified, gates re-green | Overwrite vector Unknown — audit harnesses for input-path outputs |
| Encrypted refusal | READY | Writer S3 (`PDFIncrementalWriterTests:460-474`) + provider password gate S2 (`PDFReaderGateTests:167-188`) | Contract-layer encrypted-rejection unit missing (gap, non-blocking) |
| AcroForm fidelity | CONDITIONAL | Choice/text/checkbox 1.000 production_ready; radio 0.9375 Mixed → D-076 proposes radio experimental/review-gated | Owner ratification of D-076 |
| Signatures/XFA | NOT READY (scoped out) | Guards observational only; no fail-closed edit refusal in export lane | Keep out of launch scope; RG-014/015 PARTIAL stands |
| Human visual confirm | NOT READY | RG-135 0/38; panel exists (DEBUG per D-074) | Human pass via new runbook |
| GUI journey | **FAIL (Tier 4)** | `docs/simulations/RUN-2026-09-07-N2N1-native-first-run-and-fill.md` (ZCode computer use, same day): fill-mode scan never completes (GAP-C P0), argv/Apple-Event opens broken/half-wired (GAP-A/B P0), recents-click zombie (GAP-D P1), AX gaps (GAP-E P2). Gaps filed to `docs/audits/persona-launch-acceptance-audit-2026-09-07.md` §10.12 | Fix order GAP-C → A/B/D, then rerun runbook; GUI journey **excluded** from the conditional GO below |
| Pricing/market | NOT READY | D-052 decided; Van Westendorp + page-test + interview protocols written, nothing run | Human research |
| Provider licenses | READY (brief) | `docs/audits/provider-license-refresh-2026-09-07.md`; PoDoFo discrepancy resolved; MuPDF still quarantined; OCRmyPDF Ghostscript wording stale (isolated-worker boundary stands) | Bouncy Castle review (PDFBox lane) |
| Privacy/egress | READY (lanes run) | RG-028/RG-126 PASS; session provenance zero-content verified in sims | Companion/OCR/hosted lanes need own proofs when built |
| Distribution | BLOCKED (external) | RG-122 ($99 Apple account), RG-123 (hosting+EdDSA) | Purchase/setup decisions |

## Residual-risk ledger

| Risk | Evidence | Consequence | Mitigation | Owner | Accepted? |
|---|---|---|---|---|---|
| Test binary vs dirty sources | 96 green; 1 newer file is app-shell-only | Stale-code validation | Full `swift test` on warm cache/CI | Release lane | No — rerun owed |
| Fixture re-overwrite | Vector Unknown | Silent corpus corruption | Governance gate in CI on fixture paths | Release lane | No — CI check owed |
| Radio overclaim | D-076 proposed, wording pending | Wrong high-consequence selection | Review-gate + experimental label | Pranay | No — ratification owed |
| Sig/XFA silent edit | Observational guards only | Invalidated signature / corrupt XFA | Scope exclusion + explicit unsupported states | Core lane | Conditionally (excluded scope) |
| Human-gated items unrun | Protocols written | Launch without perceptual/market proof | CONDITIONAL GO limits exposure to bounded unit | Pranay | No — passes owed |

## Conditions for the CONDITIONAL GO
1. Bounded unit only (text/checkbox/choice + reviewed overlays **at the contract/provider layer**); radio experimental per D-076; signatures/XFA excluded with explicit unsupported states.
2. **GUI journey excluded**: the N2N1 FAIL stands — no user-facing launch claim may imply open → fill → export works in the app window until GAP-A..C are fixed and the runbook re-run passes.
3. No fixture change without a green governance run.
4. RG-135 + pricing validation complete before any paid-launch claim.

## Not assessed
Full-suite green in this env, physical-device calibration, real-world (non-synthetic) corpus breadth, versioned-update/renewal mechanics, MAS review path.
