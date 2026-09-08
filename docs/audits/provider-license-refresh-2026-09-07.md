# Provider License / Packaging Refresh Brief — 2026-09-07

**Status:** Refresh brief, not legal advice and not a distribution approval.
**Scope:** Re-check the license-relevant recorded state from 2026-08-23/24
against current primary sources, only where the answer changes a decision.
**Baseline:** `findings.md` F-005, F-006, F-007, F-008, F-017–F-027;
`docs/pdf-engine-comparison.md`; `docs/pdfbox-packaging-review.md`;
`docs/audits/pdfbox-mupdf-bakeoff-evidence-2026-08-31.md`; RG-128.
**Bake-off pins (2026-08-31):** PDFBox `3.0.8` (SHA-512 matched);
MuPDF `1.28.2` local `mutool`.

## Truth taxonomy

- **Observed** — seen in a named source during this pass.
- **Verified** — confirmed against a primary source (project site, repo,
  license file, release page) cited inline.
- **Inferred** — reasoned from evidence; marked as such.
- **Proposed** — a recommended next step, not a fact.
- **Unknown** — not established; paired with the exact check owed.

## Per-provider table

| Provider | Recorded state (2026-08-23/24 + bake-off) | Refreshed state (2026-09-07) | Decision impact |
|---|---|---|---|
| MuPDF | **Observed (recorded):** `1.28.0` release history (F-019); local `1.28.2` in bake-off; AGPL/commercial dual model; quarantined pending legal decision (RG-128). | **Verified:** latest release is `1.28.3` (source-only, 2026-08-26); license still GNU AGPL with commercial path. Sources: `mupdf.com/releases/history`, `mupdf.readthedocs.io/en/latest/license.html`. | **No change.** Still quarantined; commercial-terms review still open. Local `1.28.2` lane is one patch behind but the gate is licensing, not version. |
| PoDoFo | **Observed (recorded):** source snapshot `1.1.2` vs generated docs `1.2.0` — version boundary open (F-021); headers LGPL-2.0-or-later OR MPL-2.0 (F-007); writer-beside-renderer role. | **Verified:** latest GitHub release tag is `1.1.2` (published 2026-08-19). No `1.2.0` release tag exists in the release list. **Inferred:** the `1.2.0` label is the generated-docs version (master/unreleased docs), not a release. License headers **not** re-inspected this pass — retained as recorded, re-verification owed. Sources: `github.com/podofo/podofo/releases`, `releasealert.dev/github/podofo/podofo`. | **Discrepancy resolved (see below).** Pin reference becomes `1.1.2`; role unchanged (bounded-writer experiment only). |
| Poppler | **Observed (recorded):** `26.08.0` (2026-08-02); cpp/GLib/Qt5/Qt6 frontends; Qt6 header GPL v2-or-later; component-license matrix open (F-006, F-020). | **Verified:** latest stable is still `26.08.0` (2026-08-02) per `poppler.freedesktop.org`. Component-license matrix **not** re-inspected — retained as recorded, still open. | **No change.** Still a GPL-boundary reader/form candidate, not a permissive default. |
| PDFBox | **Observed (recorded):** `3.0.8` + `2.0.37` lines, Apache-2.0 (F-017, F-025); packaging review: ~13 MB fat jar, 40–80 MB jlink runtime, Bouncy Castle notice review open; opt-in companion direction (D-007); RG-128 permissive AcroForm control lane. | **Verified:** download page still lists `3.0.8` / `2.0.37` as latest; Jira references `3.0.9` / `2.0.38` only as unreleased fix versions. License and packaging facts **not** re-inspected — retained as recorded. Sources: `pdfbox.apache.org/download.html`, ASF Jira PDFBOX-6219/6237. | **No change.** `3.0.8` pin confirmed current; companion-lane decision stands; Bouncy Castle notice review still owed. |
| OCRmyPDF | **Observed (recorded):** Ghostscript required dependency + malware-warning (F-027); isolated-worker boundary; license review open. | **Verified:** since v17.0.0 Ghostscript is **optional** — rasterization via pypdfium2 OR Ghostscript; PDF/A via verapdf+pikepdf OR Ghostscript. Minimum install is tesseract + (pypdfium2 OR Ghostscript) + fpdf2. The malware-warning text was **not** re-checked — retained as recorded. Sources: `ocrmypdf.readthedocs.io` installation + maintainers pages (v17.x). | **Partial change:** packaging burden is lower than recorded (Ghostscript avoidable via pypdfium2/verapdf path), but isolated-worker boundary, license review, and threat review remain. F-027's "required" wording is stale for v17+. |
| PDFium | **Observed (recorded):** Chromium-scale embed, public/ headers BSD-style, exact packaged-dependency inventory open (F-018). | **Unknown** — no versioned release to refresh (follows Chromium); not re-checked this pass by design (decision does not turn on a version number). | **No change.** Low-level control lane only; SBOM/notice review still owed before any packaging. |

## PoDoFo 1.1.2 / 1.2.0 discrepancy — resolution

- **Verdict: resolved as a category error, not a release gap.**
- **Observed (recorded):** F-021 saw `1.1.2` in source and `1.2.0` in generated docs.
- **Verified (this pass):** the GitHub release list tops out at `1.1.2`
  (2026-08-19); no `1.2.0` tag exists.
- **Inferred:** `1.2.0` is the documentation-site version for master, not a
  shippable release. The adoptable pin is `1.1.2`.
- **Check owed before adoption:** confirm the `1.1.2` tag's license headers
  still carry LGPL-2.0-or-later OR MPL-2.0, and record which
  `podofo.github.io` docs version maps to the pinned tag.

## Explicit Unknowns and exact checks owed

1. **PoDoFo license re-verification:** read `LICENSE` + SPDX headers at tag
   `1.1.2` before any adoption experiment.
2. **Poppler component-license matrix:** still open since F-006; needs a
   per-frontend (core/cpp/GLib/Qt5/Qt6/utils) license inventory from the
   `26.08.0` tree before any distribution-adjacent use.
3. **MuPDF commercial terms:** still open; no license purchased or inferred.
   Owner decision required; check `artifex.com/licensing` terms at purchase time.
4. **OCRmyPDF malware-warning currency:** re-read the current
   `introduction.html` warning text; confirm whether v17 wording changed.
5. **PDFBox Bouncy Castle notices:** review and bundle before shipping the
   companion lane (carried over from `pdfbox-packaging-review.md`).
6. **PDFium packaged-dependency SBOM:** owed for the exact wheel/build if ever
   packaged; not yet started.

## Falsifier

This brief is wrong if: MuPDF's primary license page no longer states AGPL,
a PoDoFo `1.2.0` release tag exists that this pass missed, Poppler or PDFBox
shipped a newer stable than stated above, or OCRmyPDF v17 still mandates
Ghostscript with no alternative path.

## Revisit trigger

Re-run this refresh when any of these fires: a provider release newer than
the refreshed state above; a license-file or release-line change in any
quarantined provider; a decision to package a companion/helper (PDFBox JVM,
MuPDF native, OCRmyPDF worker); or 90 days elapsing (next due 2026-12-07).
