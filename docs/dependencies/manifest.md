# Dependency Provenance Manifest

| Asset | Version | Source | SHA-256 | License |
|---|---|---|---|---|
| `web/vendor/pdfjs/pdf.min.mjs` | `4.2.67` | `https://unpkg.com/pdfjs-dist@4.2.67/build/pdf.min.mjs` | `c3caae2cf1fe9d6e25588d0d239d02454422778ed5897314981496a4656eab82` | `web/vendor/pdfjs/LICENSE` |
| `web/vendor/pdfjs/pdf.worker.min.mjs` | `4.2.67` | `https://unpkg.com/pdfjs-dist@4.2.67/build/pdf.worker.min.mjs` | `ee61de6dd3effd826b7083739409e50bae43c2e41a896f27ea8dd2d77e2f349b` | `web/vendor/pdfjs/LICENSE` |
| `web/vendor/pdf-lib/pdf-lib.min.js` | `1.17.1` | `https://unpkg.com/pdf-lib@1.17.1/dist/pdf-lib.min.js` | `0f9a5cad07941f0826586c94e089d89b918c46e5c17cf2d5a3c6f666e3bc694f` | `web/vendor/pdf-lib/LICENSE.md` |
| `web/vendor/pdfjs/LICENSE` | `4.2.67` | `https://unpkg.com/pdfjs-dist@4.2.67/LICENSE` | `0d542e0c8804e39aa7f37eb00da5a762149dc682d7829451287e11b938e94594` | Bundled license |
| `web/vendor/pdf-lib/LICENSE.md` | `1.17.1` | `https://unpkg.com/pdf-lib@1.17.1/LICENSE.md` | `f2c9fc00fdb66eb99ac156ba52d734af66d8d309f65753ae809ad34ee2883bcb` | Bundled license |

The upgrade policy remains open: each runtime upgrade must update this manifest, rerun the web contract/browser gates, and preserve the license files.

## Independent validation tools

| Tool | Version | Installation/source | Role | Product dependency? |
|---|---|---|---|---|
| qpdf | `12.4.0` | Homebrew formula; local validation environment | Structural syntax, encryption, and object reachability checks | No; release/test oracle only |
| Poppler `pdfinfo`/`pdftotext` | `26.08.0` | Homebrew formula; local validation environment | Independent reopen and text-stream checks | No; release/test oracle only |
| MuPDF `mutool` | `1.28.2` | Homebrew `mupdf-tools`; local validation environment | Second independent parser/viewer reopen check | No; release/test oracle only |

These tools are not bundled into the native or web product. Their licenses and
distribution obligations must be reviewed separately if any tool is promoted
from a test oracle to a shipped provider.
