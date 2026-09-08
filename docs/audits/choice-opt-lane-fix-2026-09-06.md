# Choice (/Opt) Fixture Hardening & PDFKit Choice Lane Fix (2026-09-06)

**Status:** COMPLETE — choice measured production-ready on PDFKit
**Supersedes:** the "choice experimental (89%)" row of RG-133; closes the pending half of the radio/choice fixture request
**Related:** `docs/audits/radio-choice-fixture-hardening-2026-09-06.md` (fixture + suite work, same day)

## Request (pending item)

> …the request mentions /Opt arrays. In AcroForm, /Opt is the field-dictionary options array used by choice fields, not radio groups… If the intent was to harden choice field handling with real /Opt arrays, that is a different field type and a different fixture set — I can generate those next if that's what you meant.

The fixture set and suite were completed earlier this session (7 fixtures, `GeneratedChoiceFixtureTests`, 7/7). What remained pending was the **measurement**: the RG-133 gate report did not exercise the new fixtures, and its choice row was wrong.

## Finding: the "PDFKit choice = unsupported" row was a phantom

Gate report before the fix: `PDFKit choice: 0 verified / 12 failed, decision unsupported` while pdf-lib verified 8/9 on the same corpus. A provider cannot be "unsupported" when an independent engine round-trips the same bytes — that asymmetry is the phantom signature.

Root cause (measured, two defects stacked):

1. **Wrong write API.** The experiment's `roundTripTest` wrote *every* single field through `buttonWidgetState` (the Sep-5 checkbox fix over-generalized to all single fields). `buttonWidgetState` is a `/Btn`-only API and **no-ops on `/Ch` and `/Tx` widgets**. The production path (`PDFKitProvider.applyNativeValue`) routes `.choice` and `.text` through `widgetStringValue`; the experiment did not.
2. **Spec-invalid test values.** `generateTestValue` produced `"RT-choice-…"` garbage not in the field's `/Opt` vocabulary. A non-combo choice rejects values outside `/Opt` (PDF 32000-1 §12.7.5.4), so even a successful write of such a value would prove nothing.

## Fix (`AcroFormParityExperiment.swift`)

- Choice test values are now drawn from the field's real `/Opt` exports, parsed structurally (`PDFIncrementalFormWriter.walkAcroForm`, the only `/Opt`-aware source — PDFKit's annotation API does not expose `/Opt`), excluding the current selection so the round-trip proves the *specific* new selection survives.
- `/Ch` and `/Tx` single fields route through `widgetStringValue` — the production API — with the falsification documented inline.
- Added `verifyChoiceValueStructurally` (the `/Opt`-aware counterpart of the radio structural verifier): saved bytes must carry `/V == expected`. Choice `specComplete` now gates on structural + qpdf cross-read, matching the radio standard — surviving PDFKit's own reopen proves nothing about the bytes because its annotation API omits `/V`.
- The 7 generated choice fixtures joined the experiment corpus (40 fixtures total).

## Measured result (gate report regenerated 2026-09-06)

| Field type | PDFKit | pdf-lib | qpdf (verifier) | Decision |
|---|---|---|---|---|
| **choice** | **11v/0f, conf 1.00, production_ready** | 15v/1f, conf 0.94, experimental | 8v/0f, experimental | **Mixed: production_ready, experimental** |
| text | 10v/2f, conf 0.83, experimental | 6v/2f, limited | 8v/0f | Mixed |
| radio | 16v/0f, conf 1.00 | 11v/5f, 0.69 | 8v/0f | Mixed |
| checkbox | 17v/9f, conf 0.65 | 16v/6f, 0.73 | 8v/0f | Mixed (RG-134 track) |

Choice went 0/12 → **11v/0f production-ready**. The text row also recovered (0v/12f → 10v/2f): the same no-op-API bug had silently regressed `/Tx` when the checkbox fix landed; both regressions and the repair are documented inline at the write site.

## Remaining honest failure classes (not phantoms)

- pdf-lib choice 15v/1f: the one failure is the pdf-lib-lane limitation on the pair-form `/Opt` write (its `select()` is display-string-keyed; the structural export survives — see the engine-semantics section of the sibling audit).
- checkbox 17v/9f is the open RG-134 investigation; the failures now cluster in the pikepdf-generated checkbox fixtures (producer encoding vs PDFKit save/reopen), distinct from the phantom class eliminated here.

## Verification

```
swift test --filter AcroFormParityExperimentTests → 4/4 passed (109s incl. full-corpus run)
GeneratedChoiceFixtureTests                        → 7/7 (prior, unchanged)
```

Artifacts: `benchmark/results/acroform-parity/acroform-parity-gate-report.json` (regenerated, corpus 40).
