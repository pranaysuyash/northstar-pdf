# Real-Document Corpus Plan (X1) — OCR & Parity Gate Falsifiability

**Date:** 2026-09-18
**Status:** research plan (X1 of `docs/explorations/post-audit-exploration-ledger-2026-09-06.md`, PROMOTED from ledger row to executed plan; nothing here changes gate state until the slice runs)
**Origin:** random-document audit of `docs/pdf-feature-frontier.md` (2026-09-18) + X1 ledger row
**Companion docs:** `docs/research/form-field-detection-research-2026-09-09.md` (§4 external datasets: CommonForms, FUNSD, FFDNet), `docs/audits/persona-launch-acceptance-audit-2026-09-07.md` (C4/RG-135 human-cost reality), `docs/fixtures/pdf-corpus-governance.md` (fixture governance)

## 1. Problem (Observed)

Both OCR and parity quality gates are measured against **synthetic corpora**:

- OCR corpus: 8 ImageMagick-rendered pages in `benchmark/results/ocr-corpus/` with hand-written `.gt.txt`. Apple Vision measures WER 0.000 across all fixtures (`benchmark/results/ocr-corpus/cross-provider-wer-report.json`), so the RG-136 absolute threshold (0.10) is **near-unfalsifiable** — it can only catch gross regressions, not real-world degradation.
- Parity corpus: ~40 fixtures machine-generated with pikepdf (`docs/audits/choice-opt-lane-fix-2026-09-06.md`). Vocabulary-diverse by design, but produced by one writer; real producer quirks (dated /DA strings, nested /AP N-ranges, need-appearances flags, orphan annots in unusual orders) are underrepresented.

A gate that cannot fail on realistic inputs is not evidence of robustness — it is evidence about the generator.

## 2. Hypotheses under test (from X1)

- **H-OCR:** on a real-document slice (true scans, camera captures, degraded prints, producer-stamped PDFs), provider WER will be materially above the synthetic 0.000 for at least one gated provider — i.e. the current threshold is representative of the generator, not of production.
- **H-PARITY:** real-world AcroForm documents will expose round-trip gaps (field write, reopen, structural verify) that the pikepdf corpus does not — visible as new failed rows in `AcroFormParityExperiment`.

## 3. Sampling frame (first principles)

A real slice is only useful if it is **governed**: every document classified, licensed, and ground-truthed by a recorded procedure. Reuse the document-class taxonomy the product already maintains rather than inventing one (frontier §1 + detector research §1):

| Class | Source | n (initial) | Ground truth cost |
|---|---|---|---|
| Clean digital print | Project-authored exports, public-domain gov PDFs | 3 | low (text layer as GT, verified) |
| True scan (300dpi flatbed) | Owned documents only | 3 | high (hand transcription) |
| Degraded scan (skew/noise/fax) | Deliberately degraded owned scans (diskew/denoise applied *outside* the gate) | 3 | high |
| Camera capture | Phone photo of a printed page | 2 | high |
| Real AcroForm (producer-stamped) | Public-domain forms (IRS W-9/W-4-style, gov forms with verified license) | 4 | low (field inventory = GT) |
| Real static/vector form | Same sources, flattened variants | 3 | medium (region labels) |
| Multi-column layout | Two-column public-domain article PDF | 2 | medium |

Total ≈ 20 documents — the X1 ledger's stated size. Every item gets a manifest row (source, license, SHA-256, class, GT provenance) in the fixture-manifest format `docs/fixtures/manifest.md` already defines.

**License gate:** only documents whose license permits redistribution into the repo, or documents held as untracked local fixtures with a recorded hash and regeneration procedure (the corpus-governance doc's existing pattern).

## 4. Procedure (bounded, three steps)

1. **Acquire + classify + manifest** (half a session): collect per §3, write manifest rows, run the existing corpus-sweep detector to catch any accidental PII before a fixture is tracked (`docs/fixtures/corpus-sweep-detector-manifest.md` — the sweep gate must pass on every new fixture; this is a hard precondition, same as existing corpus work).
2. **Ground-truth** (the expensive step, honest about it): hand-write `.gt.txt` for the OCR classes; export field inventories for AcroForm classes. Estimate ~2–4 min/page transcribing clean text, ~8–15 min/page for degraded scans. Total human cost ≈ 2–3 hours — comparable in kind to the RG-135 review pass, and worth batching into the same sitting.
3. **Measure + adjudicate**: run `benchmark/compare_ocr_wer.py` over the slice (per-class WER, not just average) and `AcroFormParityExperiment` over the AcroForm slice. Record per-class results in `benchmark/results/ocr-corpus/` beside the synthetic report.

## 5. Outcomes and falsifiers (pre-registered)

- **Falsifier for H-OCR:** real-slice WER ≈ synthetic WER (all gated providers < 0.02 avg) → gates are representative; record "synthetic gates representative on 2026-09-18 real slice" as evidence in `docs/release-gates.md` and close X1. This is a *win* — it converts an unfalsifiable gate into a falsified-once gate.
- **If H-OCR holds:** add the real slice as a **second RG-136 lane** with per-class thresholds set from measured baselines + documented headroom (the 2026-09-11 re-baseline pattern: threshold ≈ 5× measured average). The synthetic corpus stays (deterministic regression canary); the real slice becomes the representativeness gate. Requires RG-136 owner sign-off — decision listed.
- **Falsifier for H-PARITY:** no new failed rows vs. the pikepdf corpus → parity evidence upgraded to "real-producer-slice verified 2026-09-18"; any new failure becomes a named provider task with the S2 discipline (failed first, then fixed).

## 6. Explicit non-goals

- No ML-detector training data collection in this slice (that is the FD-R1 FUNSD run, `docs/research/form-field-detection-research-2026-09-09.md` §6 — separate lane, separate decision).
- No browser-plane corpus work (PL-D14 Mac-first re-scope).
- No attempt to make the synthetic corpus "more realistic" — its value is determinism; realism comes from the second lane.

## 7. Dependencies

- Human time (owner or delegated reviewer) for ground truth — the only resource that cannot be parallelized away.
- RG-136 threshold adoption is an owner/release-gate decision after measurement.
- None of this blocks or is blocked by the launch spine (C1–C8); it is pre-GA hardening that de-risks the "quality gates green" claim a buyer will eventually audit.
