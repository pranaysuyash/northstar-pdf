# Capability Maturity Model + Canonical Capability Matrix + Gate-Maturity Bridge

**Date:** 2026-08-28
**Status:** Observed + Verified
**Evidence tier:** Tier 2 (targeted tests — 12 + 11 + 12 tests pass)
**Test sensitivity:** S1 (all pass)

## 1. Decision context

Three gaps were identified in capability governance:

1. **No durable capability maturity model** — product scope, implementation status, provider support, and evidence clearance were conflated. A capability was either "implemented" or not, with no graduation.
2. **No canonical programmatic capability matrix** — `docs/capability-matrix.md` existed as prose with 20 rows, but nothing enforced it, sequenced it, or verified it.
3. **No gate-maturity bridge** — `docs/release-gates.md` (124 gates) had no programmatic link to capability maturity.

**Question:** How do we make capability readiness a five-dimensional, programmatic, gate-linked system?

## 2. Architecture

### `CapabilityMaturityModel.swift` (295 lines)

Five independent dimensions per capability:
1. **Product scope** — name, user statement, archetype, job ID, claim, claim accuracy
2. **Implementation status** — proposed → prototype → partial → complete → hardened
3. **Provider support** — unsupported / conditional / supported / primary
4. **Evidence clearance** — none → staticInspection → targetedTest → integration → liveRuntime → production
5. **Lane** — native / browser / companion / shared

`isClaimReady` requires maturity ≥ complete AND evidence ≥ integration — a capability is not claim-ready on one dimension alone.

### `CanonicalCapabilityMatrix.swift` (341 lines + 550-line population)

Programmatic version of `docs/capability-matrix.md`:
- `CapabilityMatrixEntry` — capability + scope + providers + contracts + evidence gates + dependencies + owner + sequence priority + claim
- `EvidenceGate` — id, description, status (open/partial/pass/fail/waived), required tier, sensitivity
- `ProviderEntry` — provider name, lane, support, version, license, limitations
- `sequenced` — topological sort by dependencies
- `toMarkdown()` — human-readable export matching the doc format

### `CanonicalCapabilityMatrixPopulation.swift` (550 lines)

All **42 capabilities** wired with real providers, gates, owners, and sequencing:

| Archetype | Count | Examples |
|---|---|---|
| Reader | 19 | Open/Import, Search, Reading Modes, Dark Mode, Freeze Panes |
| Creator | 4 | Overlays, Export Validation, Creator Canvas, Design System |
| Manager | 3 | Document Index, Version Control, Governance |
| Power | 4 | Provider Admission, Batch, Companion Health, Variance Registry |
| Forms/Editing | 3 | AcroForms, Signatures, XFA |
| Calibration | 2 | Page Box Policy, Recurring Form Calibration |
| LEARN/Annotate | 3 | Spaced Repetition, Annotation Marks, Collaboration |
| UNDERSTAND | 4 | Summarization, Entity Recognition, Table Extraction, Key Points |

Each entry references real RG-XXX gate IDs from `release-gates.md` with current status.

### `GateMaturityBridge.swift` (230 lines)

Maps capability gates to release gate statuses:
- `ReleaseGateStatus` — PASS/PARTIAL/OPEN/BLOCKED/FAIL (matches release-gates.md vocabulary)
- `mapAll()` — 42 mappings, one per capability
- `deriveRecommendedStatus()` — from maturity + evidence + gate pass ratio
- Detects **inconsistencies** between matrix gate status and release-gates.md
- `summaryReport()` + `toMarkdown()` — alignment report

Also added to `CapabilityMatrixEntry`: `overallMaturity` (derived from gate pass ratio) and `overallEvidence`.

## 3. First principle

A capability is not "done" until all five dimensions are explicitly stated. Vague claims like "supported" are forbidden. Gate status should be **derivable** from capability maturity — this prevents manual gate manipulation from diverging from actual implementation state.

## 4. Evidence

- `CapabilityMaturityTests.swift` — 12 tests
- `CanonicalMatrixPopulationTests.swift` — 12 tests (42 capabilities, all have providers/gates/owners/claims, topological sort valid)
- `GateMaturityBridgeTests.swift` — 11 tests (mapping, recommendation derivation, inconsistency detection)
- Full suite: 1275/1275 pass

## 5. Doctrine alignment

- §2 Truth taxonomy: every claim labeled by accuracy
- §5 Evidence-based: every gate measurable, recommended status derived
- §11 Engineering integrity: sequencing prevents broken dependencies
- §13 Product reality: claims must match implementation

## 6. Alternatives not taken

- **Single monolithic "implemented" flag:** loses graduation — rejected
- **Prose-only matrix:** no enforcement, no sequencing — rejected
- **Manual gate status editing:** allows divergence from reality — bridged instead

## 7. Open questions

- Should the bridge be wired into CI to fail on gate-maturity inconsistency?
- Should the matrix export replace `docs/capability-matrix.md` (single source of truth)?
- Should release-gates.md itself be generated from the matrix?