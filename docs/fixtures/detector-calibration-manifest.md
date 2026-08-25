# Detector Calibration Fixture Manifest

This manifest is a deliberately synthetic, privacy-safe two-page PDF used to
calibrate native and browser geometry detectors. Page one contains reviewed
positive examples. Page two contains structurally plausible hard negatives.
The labels and expected states live in
[`detector_calibration_labels.json`](../../benchmark/results/detector-calibration/detector_calibration_labels.json).

| Fixture | Characteristics | Evidence rule |
|---|---|---|
| `benchmark/results/detector-calibration/detector-calibration.pdf` | Two pages, standard Helvetica, vector rectangles, a vector checkbox, a vector underline, text-only whitespace, and generic decorative controls | Positive regions require a semantically plausible label; generic or unlabeled regions must abstain |

Generate it with `python3 benchmark/generate_detector_calibration_fixture.py`.
