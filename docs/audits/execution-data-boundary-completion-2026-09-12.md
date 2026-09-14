# ExecutionDataBoundary Completion — TASK-A2 Data-Boundary Fact (2026-09-12)

**Status:** CLOSED — implemented on the working tree; uncommitted, pending the
other session's review of `ExecutionReceipt.swift` / `AppModel.swift` (flagged
for that review in the 2026-09-12 consolidated-suite session).

**Truth-status legend used below:** **[Observed]** = read directly from live
files or command output; **[Verified]** = independently checked with a stated
tier/sensitivity; **[Inferred]** = best explanation, assumption named;
**[Unknown]** = check named. Per OPERATING_DOCTRINE §2.

## What the abandoned edit intended

An earlier session left two layers of edits on `ExecutionReceipt.swift` that
this session inherited (both **[Observed]** in `git diff --cached` and
`git diff`):

1. **Staged layer (the abandoned edit):** `ExecutionReceiptCheck.detail`
   gained a default value (`detail: String = "Verified"`), and
   `AppModel.currentExecutionReceipt()` / `recordExecutionReceipt()` /
   HUD check construction were staged with the receipt types. Intent
   **[Inferred, assumption: the staged diff plus the old doc comment is the
   whole of that session's aim]**: reduce call-site friction so the
   TASK-A2 receipt could be built from many action paths without forcing
   every check to author a detail string.
2. **Pre-existing contract defect the layers exposed:** the pre-existing
   `ExecutionReceipt` shipped a fabricated provenance default
   (`executionRoute: String = "On-Device · Local Apple PDFKit"`) and an
   unconditional export footer `"Cryptographically verified on-device. Zero
   network egress."` **[Observed in HEAD version]**. TASK-A2's own matrix row
   lists "Route (On-device)" as receipt content
   (`docs/audits/chatgpt_architectural_review_task_matrix.md:56`), but a
   default-less claim and an unconditional slogan are epistemically wrong: a
   receipt that never asked the executing path where data could travel was
   printing "zero network egress" anyway.

## What this session added (the completion)

All **[Observed]** in the live tree; build **[Verified, Tier 2 / S1]**:
`swift build --build-tests` clean across every session run, including the
full-suite single-process pass of 2026-09-12 (176 suites, 0 failures).

1. **`ExecutionDataBoundary` enum** (`Sources/PDFEditorCore/ExecutionReceipt.swift:9`):
   `onDeviceIsolated` / `onDeviceWithEgress`, `Codable`/`Sendable`, with
   `renderedDescription` prose per case. It is a **mandatory, default-less
   argument** of `ExecutionReceipt` — no receipt can exist without the
   executing path stating where its data could travel.
2. **Fabricated defaults removed:** `executionRoute` lost its
   `"On-Device · Local Apple PDFKit"` default (now mandatory).
3. **Unconditional slogan removed:** the export footer
   `"Cryptographically verified on-device. Zero network egress."` is deleted;
   the exported text now carries a conditional
   `"Data Boundary : \(dataBoundary.renderedDescription)"` line, and the
   status word changed from the stronger `"VERIFIED SUCCESS"` to
   `"COMPLETED"` for success.
4. **Call-site honesty:** `AppModel.currentExecutionReceipt()` supplies
   `.onDeviceIsolated` **with a genuinely derived execution route**
   (`usePipelineRendering ? "Custom Metal Pipeline" : "Local Apple PDFKit"`);
   `recordExecutionReceipt` propagates `base.dataBoundary`.
   **[Observed]** `Sources/PDFEditorRecovery/AppModel.swift:519-546`.
5. **The abandoned staged line retained, not reverted** — `detail = "Verified"`
   stays; doctrine §10 (preserve compatible work, salvage rather than discard).
   All 12 current `ExecutionReceiptCheck(` call sites pass `detail:`
   explicitly **[Observed]**, so the default is currently exercised by zero
   callers — it is friction-reduction insurance, not a behavior change.

**Egress contract (documented in code, not separately enforced):** an
`onDeviceWithEgress` receipt is *incomplete by construction* if its `notes`
are empty — stated on the enum case doc and rendered by
`renderedDescription` pointing at the notes. **[Observed]** the text exporter
prints notes when non-empty (`ExecutionReceipt.swift:101-103`); **[Unknown /
open check]** no compile-time or runtime assertion enforces notes-nonempty for
the egress case. Named check: add an `ExecutionReceiptTests` case asserting
export text for `.onDeviceWithEgress` with empty notes carries the incomplete
boundary line (S2-able by construction).

## Why this shape (options considered)

- **Free-text `dataBoundary: String`** — rejected: recreates the fabricated-
  default problem at every call site; no exhaustive rendering.
- **Boolean `hadEgress`** — rejected: loses the two-sided prose contract and
  cannot evolve a third state without an API break.
- **Two-case enum, mandatory argument** — chosen: exhaustive switch for
  rendering, no receipt without the fact, Codable-stable raw values for the
  exported JSON/TXT artifacts. Tradeoff accepted: every new receipt call site
  must state the boundary explicitly (that is the point).

## Evidence and falsifier

- Build green with the mandatory-parameter change **[Verified, Tier 2 / S1]**;
  call sites compile only because every construction path states the boundary.
- Full-suite run 2026-09-12: 176 suites 0 failures in-process, 184/184 green
  including the consumers (`ContextualInspectorView`, `AgentCommandHUD`)
  **[Verified, Tier 2 / S1]**.
- **Falsifier (what would make this record wrong):** if any
  `ExecutionReceipt(` construction site in any target compiles without a
  `dataBoundary:` argument, or if the exported text ever emits an
  unconditional on-device/zero-egress sentence not derived from
  `renderedDescription`, the claim "no receipt without a stated boundary /
  conditional rendering only" is false. Check command:
  `grep -rn "ExecutionReceipt(" Sources/ -A8 | grep -L dataBoundary` plus a
  grep of the export body for hardcoded provenance strings. **[Observed
  2026-09-12: falsifier does not fire]** — both AppModel sites pass it, no
  hardcoded provenance remains in `exportAsPlainText`.
- Residual risk: no dedicated unit test pins the enum's rendering or the
  egress-notes contract (receipt types currently have zero test-file
  references **[Observed]**). Hardening path: `ExecutionReceiptTests` covering
  (a) both `renderedDescription` cases, (b) export-text conditional boundary
  line, (c) egress-with-empty-notes incompleteness (S2 target above).

## Record hygiene

- Supersedes the `D-085` citation in the old code comment: **[Observed]** no
  project document defines or records any `D-085` decision (grep across
  `docs/` is empty), so the identifier is dangling provenance; the new doc
  comment cites OPERATING_DOCTRINE §2 and the TASK-A2 matrix row instead.
- Decision-record fields per DOCUMENTATION_DOCTRINE §14: date (2026-09-12),
  context (abandoned staged edit + epistemic defect), options (three above),
  chosen path (enum), tradeoffs (explicit at call sites), assumptions (staged
  layer's intent — labeled Inferred), risks (no dedicated tests — labeled),
  validation (build + full suite, S1; S2 path named), rollback (single-file
  revert of the unstaged layer restores HEAD's default-based API), owner
  (pdf_editor maintainers), revisit trigger (first `onDeviceWithEgress`
  producer, or the TASK-A2 export-format extension `.json`/PDF, whichever
  lands first).
- Nothing committed; both `ExecutionReceipt.swift` diff layers remain staged/
  unstaged exactly as inherited for the pending cross-session review.
