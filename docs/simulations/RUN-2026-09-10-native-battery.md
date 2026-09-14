# RUN-2026-09-10 — Native Battery: PL-V04 Full Wedge + NS-P2/P3/P5 Persona Runs

**Date:** 2026-09-10 (19:18–00:20) · **Personas:** N1 PER-0121 (battery driver), NS-P5 Privacy Forensics, NS-P3 Export Preservation Validator, NS-P2 Recovery & State Integrity · **Protocol:** `NATIVE-SIM-PROTOCOL.md`
**Binary:** scratch build `/tmp/pdfeditor-verify-build/.../PDFEditor` (HEAD `edb8379`+ staged waves; contains D-080/D-081 fixes + PL-I30b sweep)
**Fixtures:** source copy `/tmp/ns-battery-source.pdf` sha256 `294a2716…506886a` (working copy of governed `yes_off_unchecked_basic.pdf` — source protected per D-077 custody)

## Verdict: **PASS WITH FINDINGS** — the wedge journey is GUI-complete end-to-end for the first time (open → fill → apply → export → cross-reader validity → air-gap clean), with one real preservation-claim finding and one scoped defect reclassification.

## Phase 1 — PL-V04 battery (Apple-Event / odoc leg)

| Step | Expected | Observed | Verdict |
|---|---|---|---|
| Launch + odoc open | 1 window, doc loaded | 1 window; fixture loaded; field detected | **PASS** |
| Recovery restore | Banner, editable state | "Recovery session restored — 7 records"; prior session's applied edit auto-restored: checkbox `Checked=1`, **"1 / 1 fields filled"** | **PASS** (organic NS-P2 restore evidence) |
| Export Review sheet | Fingerprint + ledger checks | Sheet: source fingerprint `294a2716…` **matches recorded digest**; "1 typed operation"; preservation/permissions checks green | **PASS** |
| Save | File written | `ns-battery-export.pdf` (1916 B) saved; no keychain prompt blocked the flow this run | **PASS** |
| Canvas state | Applied edit visible | Canvas AX: `checkbox: true` | **PASS** |

## Phase 2 — argv leg

Bare-executable launch with a file argument produces a **windowless process** (window never created, 16-sample timing sweep, no crash). Root cause is SwiftUI/AppKit launch-arg suppression, **not** the router: removing the delegate `application(_:open:)` did not change it; a window is simply never created for argv-carrying launches of a bare binary. **Reclassification:** this is a developer-only artifact — buyers launch the *bundled, signed* app where Launch Services delivers runtime `odoc` events (verified working, one-window outcome). Developer workaround: `PDF_EDITOR_OPEN_SOURCE` (in-window hook; verified: 1 window + doc). Delegate `application(_:open:)` retained (runtime Open-With path) with an explanatory comment.

## Phase 3 — NS-P3 export validation

| Check | Result | Verdict |
|---|---|---|
| Source unchanged | `294a2716…` before == after | **PASS** |
| `qpdf --check` export | exit 0 (one benign repair warning on the minimal fixture) | **PASS** |
| Field value persisted | `/Subtype /Widget /T (consent) /V /Yes` | **PASS** |
| Cross-reader (Preview) | Opens: "ns-battery-export.pdf – 1 page" | **PASS** |
| **Byte-exact prefix** | **FAILS** — src 1553 B, exp 1916 B, prefix differs; trailer carries `/Prev 1212` | **FINDING F1** |

**F1 (claim-scope, PL-I12 follow-up):** the GUI Export Copy path for a native-field edit routes through the PDFKit provider (full rewrite, xref `/Prev` chain preserved) — *not* the byte-exact `PDFIncrementalFormWriter` prefix path that `docs/architecture.md` claims. The export is valid, semantically faithful, and cross-reader-clean, but "original bytes = byte-exact prefix" must be scoped to the incremental-writer path (or the writer wired into this flow). Evidence: `evidence/ns-battery-export-2026-09-10.pdf`.

## NS-P5 — Privacy forensics

`tools/airgap-watch.mjs` capture over the full battery session and a 12 s argv-leg window: **verdict PASS — 0 connections, 0 violations** (allowlist: loopback). Evidence: `evidence/ns-argv-airgap-2026-09-10.json`. The air-gap claim now has Tier-4 runtime evidence on the native plane.

## NS-P2 — Recovery & state integrity (bounded)

| Cell | Result | Verdict |
|---|---|---|
| Auto-restore across process death (organic, prior run) | Applied edit survived: restored session rendered `Checked=1`, "1/1 filled" | **PASS** |
| Honest degraded state | Keychain-denied saves → "Recovery save needs attention" banner (no silent loss) | **PASS** |
| Pristine SIGKILL (no edits) | No phantom recovery records after relaunch | **PASS** (correct negative) |
| Records persistence | Recovery store survived 6→7 records across many restarts | **PASS** |
| Recents/zombie (GAP-D) | Not re-exercised this run; code walk found no destructive path; watchlist stands | **OPEN (watch)** |

## Environment notes

- /tmp reaper deleted prior build + fixtures between sessions — battery re-copied the governed fixture and rebuilt. Future runs should stage under `docs/simulations/.tmp/` or the repo `.build/` dir, not /tmp.
- PL-I36 (ad-hoc keychain re-prompt) did **not** fire this run (prior Allow persisted); remains watchlisted, dissolves with signing.
- One transient first-read AX menu staleness noted; menus verified enabled after interaction in the prior verified run.

## Ledger deltas

- **PL-V04: PASS WITH FINDINGS** (this run). Remaining legs for the next battery: sanitized-export variant + flattened fail-closed check (GUI), and the bundled-app odoc leg post-RG-122.
- **NS-P5: first full PASS** (Tier 4). **NS-P2: PASS (bounded).** **NS-P3: PASS with finding F1.**
- **New PL-I37 (P2):** scope "source-preserving = byte-exact prefix" to the incremental-writer path in `docs/architecture.md`, or wire the writer into the native-field export flow; verify with a byte-prefix regression test.
