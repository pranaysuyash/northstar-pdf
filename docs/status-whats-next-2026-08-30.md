# What's Left / What's Next — 2026-08-30

**Question asked:** after the verification retry, what is actually left, and what
should happen next?

**Status authority:** `docs/release-gates.md` (decision D-055). This file is a
reading of that registry plus the canonical capability matrix — it asserts no
gate state of its own.

---

## 1. Verified state of the tree (this session, not inferred)

| Check | Result |
|---|---|
| `swift test --disable-sandbox` | **1329 tests / 130 suites, all pass** |
| `swift build --disable-sandbox` | **Build complete** (264 s cold) — `PDFEditor` links to a 37 MB arm64 executable |
| Persisted calibration artifact | deterministic; SHA-256 `5a209f27…` stable across runs |
| Working tree | uncommitted: artifact-determinism fix + dual-lane detector gate (another agent) |

Note: `swift test` requires `--disable-sandbox` here — SwiftPM's manifest compile
needs `sandbox-exec`, which is blocked for the agent process.

**The `PDFEditor` binary did not exist before this session.** Test targets were
being built continuously; the app target was not. That is the single most
important fact in this document (see §5).

---

## 2. Gate census

Two cuts, because they answer different questions.

### Release blockers table (RG-001…RG-059)

| State | Count |
|---|---:|
| PASS | 6 |
| PARTIAL | 53 |
| OPEN / BLOCKED / FAIL | 0 |

No release blocker is failing. **53 of 59 are PARTIAL** — a bounded subset works,
support or evidence is incomplete.

### Full registry (123 gates)

| State | Count |
|---|---:|
| PASS | 17 |
| PARTIAL | 102 |
| OPEN | 2 |
| BLOCKED | 2 |
| FAIL | 0 |

**OPEN**

| Gate | What |
|---|---|
| RG-089 | Release sign-off — all hard gates pass or are deliberately descoped |
| RG-121 | Arbitrary-PDF production preservation (the long-horizon gate) |

**BLOCKED**

| Gate | What | Blocked on |
|---|---|---|
| RG-122 | Native macOS codesign + notarization | Apple Developer account ($99/yr) + signing credentials |
| RG-123 | Auto-update mechanism (Sparkle 2.x plan documented) | Hosting setup + EdDSA key generation |

Release rule: *no unrestricted release claim while a hard gate is OPEN, BLOCKED,
or FAIL.* RG-089/121/122/123 are all OPEN or BLOCKED, so unrestricted release is
**NO-GO** — consistent with the disposition table.

### Canonical disposition (`docs/release-gates.md` §Current disposition)

| Area | Disposition |
|---|---|
| Feature A bounded reader/navigation | **GO** for internal development and review |
| Native and web smoke paths | **PASS** on current evidence |
| General lossless PDF editing | NO-GO |
| General AcroForm fidelity | NO-GO |
| PDF/UA conformance | NO-GO |
| Unrestricted production release | NO-GO |

---

## 3. Capability matrix — where the depth is missing

42 capabilities. Gate outcomes across them: **52 pass, 27 partial, 9 open.**

Nine capabilities currently have **zero passing gates**:

| Capability | Gates | Current product claim |
|---|---|---|
| cap-16-xfa | 0/2 | Explicitly unsupported until proven |
| cap-36-batch-processing | 0/2 | Partial — merge exists, general runner pending |
| cap-17-tagged-pdf | 0/3 | No PDF/UA claim |
| cap-04-ocr-fallback | 0/3 | Not a general release claim |
| cap-19-export-validation | 0/2 | No unrestricted fidelity claim |
| cap-15-signatures | 0/2 | Not supported for editing claims |
| cap-14-overlays | 0/2 | Bounded overlay subset |
| cap-21-undo-redo | 0/1 | Supported |
| cap-01-open-import | 0/2 | Supported for bounded local files |

Several of these are deliberately- bounded (XFA is legacy; signatures are
validation-only by design). The interesting ones are **batch processing** (merge
exists, runner pending — small delta, high user value) and **tagged PDF /
PDF-UA** (blocks accessibility claims, which blocks enterprise and public-sector
use).

---

## 4. The structural problem

**102 PARTIAL gates is not a backlog, it's a permanent NO-GO by construction.**

The registry has accumulated 123 gates with zero FAIL. Nothing is red, so
nothing forces a decision — and nothing can ever close, because "complete" for
most of these gates means "broader real-world corpus", which is unbounded. The
completion oracle for RG-001 is literally "*broader real-AcroForm corpus from
multiple producers*."

Consequence: the gate registry has drifted from a release instrument into a
wish list. It can only ever answer "are we done?" with "no."

This is the thing to fix before adding any more capability.

---

## 5. Recommendation — ranked

### 1. Run the app. Today.

The project has 1329 tests, 123 gates, 240 docs, and — until 20 minutes ago —
no built `PDFEditor` executable. That is a very large measurement apparatus
sitting on top of something that may never have been launched.

No gate in the registry covers "a human opened a real PDF and it felt right."
RG-006 (VoiceOver) and RG-007 (screen reader) are the only gates requiring human
observation, and both remain PARTIAL.

Concretely: open the built binary against 10 real PDFs from your own filesystem
— invoices, tax forms, a scanned contract, a 200-page spec. The first hour of
that will find more real defects than the next 100 tests.

### 2. Define a v1 shippable subset and explicitly descope the rest.

Pick roughly 15 gates that must reach `PASS` for a *bounded public release* —
a reader/annotator that is honest about what it won't do. Then record the
remaining ~100 as documented non-goals **for v1 only**, with the reason.

This converts the NO-GO from permanent to conditional, and it is the precondition
for RG-089 (release sign-off) ever closing. It does not violate the
full-capability mandate: the program rules already allow a capability to be
"staged, provider-specific, quarantined, or abstained for a source class" — they
forbid converting sequencing into a permanent product *boundary*, which is
exactly what an explicitly-versioned descope avoids.

### 3. Spend $99 and unblock distribution.

RG-122 (codesign/notarize) and RG-123 (auto-update) are BLOCKED on an Apple
Developer account and a hosting bucket. Both are already fully documented
(`docs/codesign-notarize-workflow.md`, `docs/auto-update-integration.md`); the
auto-update implementation is estimated at 1–2 days.

This is the cheapest real progress available: two external purchases convert two
BLOCKED gates into engineering work.

### 4. Then pick capability depth by product value, not by gate number.

If the goal is users rather than coverage:

- **Batch processing (cap-36)** — merge exists, general runner pending. Small
  delta, high value for anyone with more than one PDF.
- **OCR fallback (cap-04)** — three gates, all open; the single most requested
  PDF capability after editing.
- **Overlays (cap-14)** — already "bounded overlay subset"; widening it is
  incremental, not architectural.

Lower value per unit effort right now: **XFA** (legacy, Adobe deprecated it in
2017 — "explicitly unsupported" is a defensible permanent position, not a gap),
and **PDF/UA conformance** (real, but only worth it once there are users who need
to pass an accessibility audit).

---

## 6. Where the program's own plan says to go next

`docs/full-capability-build-program.md` §Current next unit lists seven items,
in summary:

1. classify retained native/browser semantic mismatches in the parity report
   without normalizing away product-relevant differences;
2. reduce browser geometry false positives from page borders and decorative
   lines;
3. expand the privacy preflight contract into a source-bound sanitizer
   operation;
4. add OCR alignment fixtures, keep browser OCR bounded;
5. define the companion capability handshake, run OCR/high-fidelity bake-offs;
6. run the provider bake-off against existing OCR and security corpora;
7. admit providers one capability at a time, preserving abstention.

Items 1–2 are directly served by the dual-lane detector gate that landed today
(commit `3b321f4`). Items 3–6 are the B4 security lane and the companion plane.

That plan is coherent. It is also entirely capability-expansion work — it will
not, by itself, close the NO-GO. Recommendation §2 is the missing piece that
makes the rest of it matter.

---

## 7. Evidence for this document

- `docs/release-gates.md` — parsed all 123 gate rows; state counts and the four
  non-PARTIAL gates read directly
- `Sources/PDFEditorCore/CanonicalCapabilityMatrixPopulation.swift` — 42
  capabilities, 88 gate references, per-capability pass counts
- `docs/full-capability-build-program.md` §Build order (B0–B5) and §Current next unit
- `swift test --disable-sandbox` — 1329/1329 pass, 2026-08-30T00:41 IST
- `swift build --disable-sandbox` — Build complete, 2026-08-30T00:37 IST
