# Corpus-Sweep Detector Manifest

Native-lane detector manifest for the 15 corpus-sweep fixtures. Each fixture
derives from the shared base AcroForm sample (6 widgets on page 0) plus
generator-added pages. The reviewed 108-case ground truth lives in
`benchmark/results/detector-calibration/corpus_sweep_ground_truth.json`
(exported from `ReviewedCandidateGroundTruth.canonical()`).

| Fixture | Pages | Page 0 widgets | Notes |
|---|---|---|---|
| `benchmark/results/corpus-sweep-2026-08-25/plain-text.pdf` | 3 | 6 | pages 1-2 text only |
| `benchmark/results/corpus-sweep-2026-08-25/multi-column.pdf` | 2 | 6 | page 1 text only |
| `benchmark/results/corpus-sweep-2026-08-25/navigation.pdf` | 3 | 6 | page 1 links only, page 2 text |
| `benchmark/results/corpus-sweep-2026-08-25/geometry.pdf` | 4 | 6 | pages 1-3 geometry variants |
| `benchmark/results/corpus-sweep-2026-08-25/metadata-complete.pdf` | 1 | 6 | metadata |
| `benchmark/results/corpus-sweep-2026-08-25/metadata-absent.pdf` | 1 | 6 | no metadata |
| `benchmark/results/corpus-sweep-2026-08-25/metadata-custom.pdf` | 1 | 6 | custom metadata |
| `benchmark/results/corpus-sweep-2026-08-25/metadata-malformed.pdf` | 1 | 6 | malformed metadata |
| `benchmark/results/corpus-sweep-2026-08-25/metadata-unicode.pdf` | 1 | 6 | unicode metadata |
| `benchmark/results/corpus-sweep-2026-08-25/signed-valid-structure.pdf` | 1 | 6 | valid signature structure |
| `benchmark/results/corpus-sweep-2026-08-25/signed-invalid-structure.pdf` | 1 | 6 | invalid signature structure |
| `benchmark/results/corpus-sweep-2026-08-25/signed-multiple.pdf` | 1 | 6 | multiple signatures |
| `benchmark/results/corpus-sweep-2026-08-25/xfa-static.pdf` | 1 | 6 | static XFA packet |
| `benchmark/results/corpus-sweep-2026-08-25/xfa-hybrid.pdf` | 1 | 6 | hybrid XFA packet |
| `benchmark/results/corpus-sweep-2026-08-25/xfa-dynamic.pdf` | 1 | 6 widgets, AcroForm tree empty | dynamic XFA |

Generate with `python3 Tests/fixtures/generate_corpus_sweep.py <outdir> <base_fixture_pdf>`.

## Native detector gate (run after every sweep)

The native candidate pipeline runs the detector measurement gate on every
sweep and **fails non-zero on regression**:

```bash
swift run PDFContractHarness --manifest docs/fixtures/corpus-sweep-detector-manifest.md \
  --output-dir benchmark/results/detector-calibration/native-corpus --detector-gate
```

Measures the live pipeline (candidates + fields channel) against the
reviewed 98 sweep cases per fixture, persists `detector-gate-report.json`
(schema `pdf-editor.detector-gate` v1.0), and exits 1 when any fixture
regresses, is unreviewed (fail-closed), or cannot be inspected. The same
measurement runs in CI on every push via `NativeDetectorGateTests`
(`swift test` Gate 1).