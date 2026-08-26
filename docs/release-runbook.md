# PDF Editor Release Runbook

**Status:** Active (RG-081)
**Created:** 2026-08-25
**Scope:** One reproducible, ordered sequence that runs unit tests, contract tests,
browser fixtures, structural validators, and evidence generation for release review.

Release rule (from `release-gates.md`): no unrestricted release claim while a hard
gate is `OPEN`, `BLOCKED`, or `FAIL`. This runbook produces the evidence; it does
not by itself authorize a release (RG-089 remains a separate human decision).

## 0. Environment prerequisites

| Tool | Version used in evidence | Check |
|---|---|---|
| Node.js | 24.13.0 | `node --version` |
| Python 3 + pikepdf | 3.14.x / pikepdf 10.12.0 (`pip3 install --break-system-packages pikepdf`) | `python3 -c "import pikepdf; print(pikepdf.__version__)"` |
| qpdf | 12.4.0 | `qpdf --version` |
| Poppler (pdftotext/pdftoppm) | homebrew | `pdftotext -v` |
| MuPDF (mutool) | installed | `mutool -v` |
| Chrome (for Playwright browser lanes) | channel: chrome | Playwright launches it headless |
| Swift toolchain | SwiftPM (`Package.swift` at repo root) | `swift --version` |

All commands run from the repository root. Everything is local: no step requires
or performs network egress.

## 1. Shared-module and companion-lane unit/contract tests

Run the full `.mjs` suite (64 files). Every file is standalone; failures print
assertion details.

```sh
for t in Tests/*_test.mjs; do
  node "$t" >/dev/null 2>&1 && echo "PASS $t" || echo "FAIL $t"
done
```

Note: some `_test.mjs` files are browser lanes requiring a static server; see §2.
Their failure under this loop means the server was not up — re-run them per §2.

Key RG-002/RG-097 security-lane tests added 2026-08-25 (must all pass):

```sh
node Tests/pdf-incremental-form-writer_test.mjs      # source-preserving writer
node Tests/pdf-source-preserving-lane_test.mjs       # mutation-gate integration
node Tests/pdf-sanitize_test.mjs                     # metadata/attachment sanitize
node Tests/pdf-action-neutralize_test.mjs            # active-content neutralization
node Tests/pdf-hidden-revision-analyzer_test.mjs     # hidden-revision analysis
node Tests/pdf-sanitize-audited_test.mjs             # refuse-by-default audit flow
node Tests/pdf-signature-guard_test.mjs              # RG-014 detection + invalidation gate
node Tests/pdf-xfa-guard_test.mjs                    # RG-015 detect + safe reject
node Tests/pdf-attachment-scanner_test.mjs           # RG-024/RG-049/RG-067 corpus + traversal
```

## 2. Browser contract tests (Playwright)

Use the canonical runner. It starts a static server on a **free port** (never
4173 — commonly squatted by unrelated dev servers), serves the project root so
`/web/`, `/Tests/`, and `/benchmark/` modules all resolve, and exports the
unified `PDF_EDITOR_BASE_URL` to every test.

```sh
node Tests/run-web-e2e.mjs              # full web Playwright suite (30 files)
node Tests/run-web-e2e.mjs web_editor   # only files matching a name filter
```

Requirements: `playwright` resolvable from the repo root (`npm i playwright`),
`npx playwright install chromium`, and Chrome for the `channel: "chrome"` lanes.
Tests that invoke pikepdf resolve Python via `Tests/pdf-python.mjs` (override
with `PDF_PYTHON`). All 30 browser tests read `PDF_EDITOR_BASE_URL`; individual
files keep their previous hardcoded URL as fallback when the env var is absent.

## 3. Native lane

```sh
swift test
```

Known checkout caveat (recorded in RG-109): a dirty tree has intermittently hit a
`PDFEditorRecovery` public/internal visibility compile error; if `swift test`
fails to compile, record the failure output as current-checkout evidence rather
than citing the last green run.

## 4. Structural validation of outputs

Any produced or mutated PDF must pass an independent validator before it counts:

```sh
qpdf --check path/to/output.pdf          # expect: No syntax or stream encoding errors
pdftotext path/to/output.pdf -           # text-layer sanity for text-bearing outputs
mutool draw -F txt path/to/output.pdf -  # second independent reader where applicable
```

For fixture digests, verify provenance before use:

```sh
shasum -a 256 benchmark/results/public-sample-form.pdf
# expected: 5a681d44622f2ee577808e77f034525314d48a628b9cad26f7788564c9e922e8
```

## 5. Benchmark / parity regeneration

Existing governed reports live under `benchmark/results/` with one directory per
run date and a `result.json` mirroring the shared schema (fixture, inputSHA256,
provider, pages, provider-specific facts, falsifier note, evidence pointer).
Regenerate per feature before a release claim; never hand-edit a result.

Security-lane evidence directories (2026-08-25):

- `benchmark/results/2026-08-25-incremental-form-writer/result.json`
- `benchmark/results/2026-08-25-pdf-sanitize/result.json`
- `benchmark/results/2026-08-25-pdf-action-neutralize/result.json`
- `benchmark/results/2026-08-25-pdf-hidden-revision-analyzer/result.json`

## 6. Gate registry update discipline

After evidence is produced:

1. Update the row in `docs/release-gates.md` (state + completion-oracle summary).
2. Reference the test file and result JSON in the row or the linked evidence doc.
3. Record any scope boundary explicitly ("X remains open") — optimistic rows are
   treated as regressions.
4. Never move a state without a fresh current-checkout run backing it.

## Known environmental caveats

- **Base-fixture mutation incident (2026-08-25):** `public-sample-form.pdf` was
  found externally rewritten mid-session (an appended incremental revision,
  digest `0b890ace…`, causing spurious qpdf widget-reachability warnings in
  downstream outputs). No suite in this repo mutates it — verified by per-suite
  digest bisection. Suspected parallel process on the shared checkout. If
  `shasum -a 256 benchmark/results/public-sample-form.pdf` does not return
  `5a681d44622f2ee577808e77f034525314d48a628b9cad26f7788564c9e922e8`, restore
  with `git checkout -- benchmark/results/public-sample-form.pdf` before
  running anything.
- Port 4173 is squatted on this machine by an unrelated Vite process; always use
  `PDF_PROOF_BASE_URL` with a free port.
- `qpdf --remove-metadata` clears XMP but leaves trailer `/Info`; the sanitizer
  strips `/Info` via pikepdf (`web/pdf-sanitize.mjs`).
- `qpdf --remove-attachment` requires an explicit name; enumerate first.
- pikepdf objects are auto-dereferenced; do not call `Pdf.get_object()` on them,
  and read stream content with `read_bytes()`, not `str()`.
