# Working-Tree Recovery Plan — Stash-vs-Main Reconciliation — 2026-08-26

**Incident:** At ~16:31 a parallel salvage lane executed `reset: moving to HEAD`
(reflog `HEAD@{7}`) while reorganizing uncommitted work into commits
(`035db2b`→`514d109`, 16:20–17:07). The momentary revert discarded uncommitted
edits from two concurrent sessions. The lane preserved the displaced state in
**`stash@{0}` ("WIP on main: 035db2b", 96 files)** before/while rebuilding.

**Answer to "why was it deleted":** it wasn't hostile deletion — it was a
mid-flight salvage step whose intermediate state briefly hid concurrent work.
Everything displaced was captured in the stash. Nothing needs reconstruction
from memory except content the lane itself rewrote (D-055 annotations — done).

## 1. Forensic method (doctrine §0 live truth; REVIEW_DOCTRINE)

Three-way blob comparison HEAD ↔ `stash@{0}` ↔ worktree for all 96 stash files:

| Class | Count | Meaning |
|---|---|---|
| SAME | 6 | Already incorporated into main; droppable |
| DIFFERS | 90 | Adjudication needed |
| — of which evidence/binary artifacts | ~53 | Regenerable outputs; policy below |
| — of which code/docs | 37 | File-by-file disposition below |
| — of which ALSO currently dirty (lane-active) | 12 | Untouchable now (§10); queued |

Artifacts of this analysis: `tmp/stash-files.txt`, `tmp/worktree-files.txt`,
`tmp/recovery/classification.txt`, `tmp/recovery/recovery-matrix.txt`.

## 2. Dispositions

### 2.1 Execute now (quiet files where stash is verifiably better)

| File | Verdict | Basis | Oracle |
|---|---|---|---|
| `.github/workflows/ci.yml` | **RECOVER from stash** | Stash has CI Gate 4 (tool-dependent tests w/ graceful skip); main lacks it while RG-081 text already claims four gates — registry currently overclaims | YAML parse + `Tests/run-tool-dependent-tests.mjs` exists & runs |
| `tools/README.md` | **RECOVER verify-all section from stash** | Section documents shipped `tools/verify-all.sh`; lost in reset | Doc matches script flags (`--quick`, `--contracts`) |
| `docs/context/agent-start/SESSION_CONTEXT.md` | **RECOVER from stash** | Newer generation timestamp (07:15Z vs 05:58Z) | Timestamp check only |
| `benchmark/react-surface-smoke.mjs` | **RECOVER from stash** | Adds nine-breakpoint viewport overflow contract (DESIGN-HANDOFF); pure additive harness | `node benchmark/react-surface-smoke.mjs` passes |
| `Tests/toolbar_visual_regression_test.mjs` + 5 baselines | **RECOVER from stash** | Chrome-channel launcher + baselines regenerated under aligned engine; verified green ×2 pre-reset | Test passes twice consecutively |
| `docs/design-implementation-map.md` | **RECOVER D-056 section from stash** | Documents landed export-depth parity capability; main lost it in reset | Cross-ref consistency with restored D-056 |

### 2.2 Queue for owning lane (currently dirty — §10 no-race)

| File | Note |
|---|---|
| `docs/decisions.md` | Lane actively rewriting D-055/D-056 region. Full D-056 body survives in stash — one-command recovery: `git show 'stash@{0}:docs/decisions.md' | sed -n '/## D-056/,/^## /p'`. Keep worktree's D-055 incident annotations (they are newer). |
| `progress.md` | Both lanes' entries present in each side; lane merging |
| `web/app/src/App.tsx`, `CompleteWorkbench.tsx`, `PdfController.ts`, `pdfjs-runtime.d.ts` | Active React feature work (pdf-write-planning cutover) |
| `Sources/PDFEditorCore/PDFIncrementalFormWriter.swift`, `Sources/PDFEditorRecovery/AppModel.swift` | Active native lane; prior stash deltas already superseded by commits ac9a471/514d109 |

### 2.3 Coordinated React-shell bundle (recover together, not piecemeal)

`main.tsx` (react-scan dev block), `app.css` (.region-marker),
`ModePanels.tsx`, `ReaderStage.tsx`, `AgentCommandHUD.tsx`,
`ContextualInspector.tsx`, `PageThumbnailRail.tsx`, `Toolbar.tsx`,
`createDocument.ts` (concurrent embeds), `web/app.js` (candidate detail UI +
memberLabels) — these are sibling parts of ONE feature state. Merging subsets
against lane-active `App.tsx`/`PdfController.ts` breaks coherence. Recover as a
bundle behind the React test gate once the current refactor lands.

### 2.4 Keep main (stash stale here)

`docs/release-gates.md` (RG-081 four-gate + RG-097 producer corpus newer in
main), `docs/audits/full-persona-audit-2026-08-26.md` (banner wording without
ID dependency is more robust), `web/operation-history.d.mts` (expanded doc
comment), `Sources/PDFEditorApp/ContextualInspectorView.swift` (rename feature
is post-stash), `docs/reviews/motto_review.md` (newer generation stamp).

### 2.5 Evidence artifacts (~53 files)

Policy: benchmark/result JSON+PDF outputs are **regenerated evidence**, not
hand-authored truth. Keep main's versions; regenerate through pipelines when
next run. Exception logged: stash deleted
`benchmark/results/contract-parity-2026-08-24/native/exports/…native-noop.pdf`
(-2794) — confirm whether deletion was intentional cleanup before restoring.

## 3. Safety contract (no harm to main)

1. Only quiet files touched (verified against live `git status` immediately
   before each edit; mtime re-checked).
2. Every recovery lands as its own commit-sized unit with its oracle green
   before the next.
3. Whole-system gate after batch: `swift build && swift test && node
   tools/run-contract-tests.mjs` (or documented subset where external tools
   absent).
4. Stash is retained untouched until every line is confirmed incorporated
   (final `git diff stash@{0} <post-recovery-HEAD>` review), then and only then
   dropped.
5. Rollback: every applied change is a working-tree edit; `git checkout -- <f>`
   restores instantly; nothing force-pushed.

## 4. Completion ledger (append-only)

| Date | Item | Evidence |
|---|---|---|
| 2026-08-26 | Plan created; forensics complete; classification artifacts in tmp/recovery/ | this file |
| 2026-08-26 | Phase A executed: ci.yml, tools/README.md, SESSION_CONTEXT.md, react-surface-smoke.mjs, toolbar test + 5 baselines, design-map D-056 section restored worktree-only (unstaged) from stash@{0} after quiet-check | `git restore --source='stash@{0}' --worktree` output in session log |
| 2026-08-26 | Oracles: JS syntax ok ×2; ci.yml YAML-valid with tool-dependent gate present (8 refs); toolbar test green ×2 consecutive; swift build + swift test **252/252 across 36 suites** post-recovery | tmp/toolbar-rec-{a,b}.log; session verification outputs |
| 2026-08-26 | Deferred: React-shell bundle (§2.3) behind lane-active App.tsx/PdfController; D-056 append queued to decisions.md owner (exact command in §2.2) | this file |

**Maintenance rule:** completed items move down with evidence pointers, never
deleted. Stash retained until final `git diff stash@{0} HEAD` review confirms
full incorporation.
