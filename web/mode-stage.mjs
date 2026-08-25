/**
 * Mode stage presentation controller (Northstar design §5, §6, §14).
 *
 * Owns the five-mode tab chrome (WAI-ARIA tabs pattern with arrow/Home/End
 * traversal), the per-mode evidence panels above the document, and the local
 * analysis reveal: a four-stage console driven by real inspection progress
 * with a persistent status pill and an always-available reader escape hatch.
 *
 * The module is presentation-only. All facts come from the `deps.getState()`
 * snapshot of the application's live document/operation state, so no second
 * source of truth exists: counts shown here are the contract's counts, and
 * panels render honest "unknown"/"not connected" states rather than derived
 * or decorative values.
 */

const MODE_ORDER = ["reader", "understand", "complete", "organize", "review"];

const ANALYSIS_STAGES = Object.freeze([
  { id: "digest", title: "Binding the source", copy: "Fingerprinting the opened file so every later operation stays source-bound." },
  { id: "structure", title: "Reading page structure", copy: "Measuring page boxes, labels, rotation, and the text layer." },
  { id: "fields", title: "Inspecting native fields", copy: "Reading real AcroForm widgets and their values, never guessing." },
  { id: "signals", title: "Finding review signals", copy: "Deriving conservative blank-region candidates from text and geometry evidence." }
]);

const VALIDATION_STATE_CLASS = {
  passed: "passed",
  warning: "warning",
  unknown: "unknown",
  failed: "failed",
  informational: "unknown"
};

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text != null) node.textContent = text;
  return node;
}

function describeValidationCheck(check) {
  const name = String(check?.name || check?.kind || "check").replace(/([a-z])([A-Z])/g, "$1 $2");
  return name.charAt(0).toUpperCase() + name.slice(1);
}

export function createModeStageController(deps) {
  const { ui, getState, actions } = deps;
  let analysis = createAnalysisState();
  let overlayDismissTimer = 0;

  function createAnalysisState() {
    return {
      status: "idle", // idle | running | complete | partial | skipped | unavailable | failed
      completedStages: new Set(),
      activeStage: null,
      nativeFieldCount: 0,
      candidateCount: 0,
      cancelledPage: null
    };
  }

  /* ---------------- Tab chrome (WAI-ARIA tabs) ---------------- */

  function tabButtons() {
    return [...(ui.productModeNav?.querySelectorAll("[data-product-mode]") ?? [])];
  }

  function syncChrome(surfaceState) {
    for (const button of tabButtons()) {
      const modeID = button.dataset.productMode;
      const isActive = modeID === surfaceState.activeMode;
      button.classList.toggle("is-active", isActive);
      button.setAttribute("aria-selected", isActive ? "true" : "false");
      button.tabIndex = isActive ? 0 : -1;
      const capability = surfaceState.capabilities[modeID];
      const stateElement = button.querySelector("[data-mode-state]");
      if (stateElement && capability) {
        stateElement.textContent = readableCapabilityState(capability);
      }
    }
  }

  function readableCapabilityState(state) {
    return String(state).replaceAll("_", " ").replace(/\b\w/g, (c) => c.toUpperCase());
  }

  function bindTablist() {
    ui.productModeNav?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-product-mode]");
      if (button) actions.selectMode(button.dataset.productMode);
    });
    ui.productModeNav?.addEventListener("keydown", (event) => {
      const buttons = tabButtons();
      const currentIndex = buttons.findIndex((b) => b === document.activeElement);
      if (currentIndex === -1) return;
      let nextIndex = null;
      if (event.key === "ArrowDown" || event.key === "ArrowRight") nextIndex = (currentIndex + 1) % buttons.length;
      else if (event.key === "ArrowUp" || event.key === "ArrowLeft") nextIndex = (currentIndex - 1 + buttons.length) % buttons.length;
      else if (event.key === "Home") nextIndex = 0;
      else if (event.key === "End") nextIndex = buttons.length - 1;
      if (nextIndex === null) return;
      event.preventDefault();
      buttons[nextIndex].focus();
      actions.selectMode(buttons[nextIndex].dataset.productMode);
    });
    for (const button of ui.modePanels ? Object.values(ui.modePanels) : []) {
      button?.querySelector("[data-mode-return]")?.addEventListener("click", () => {
        actions.selectMode("reader");
      });
    }
  }

  /* ---------------- Panel visibility + content ---------------- */

  function selectMode(modeID) {
    for (const [id, panel] of Object.entries(ui.modePanels ?? {})) {
      if (!panel) continue;
      if (id === modeID) panel.removeAttribute("hidden");
      else panel.setAttribute("hidden", "");
    }
    if (ui.modeStage) {
      if (modeID === "reader") ui.modeStage.classList.add("mode-stage-reader");
      else ui.modeStage.classList.remove("mode-stage-reader");
    }
    renderPanel(modeID);
  }

  function refreshPanels() {
    renderPanel(getState().activeMode);
  }

  function renderPanel(modeID) {
    try {
      if (modeID === "reader") renderReaderPanel();
      else if (modeID === "understand") renderUnderstandPanel();
      else if (modeID === "complete") renderCompletePanel();
      else if (modeID === "organize") renderOrganizePanel();
      else if (modeID === "review") renderReviewPanel();
    } catch (error) {
      // Panel rendering is a presentation surface; a failure must not break
      // the reading/completion lane that the contract tests drive.
      console.warn("mode panel render failed:", error);
    }
  }

  function renderReaderPanel() {
    updateReaderContext();
  }

  function updateReaderContext() {
    if (!ui.readerContextLine) return;
    const state = getState();
    if (!state.pageCount) {
      ui.readerContextLine.textContent = "Open a PDF to begin — nothing leaves this device.";
      return;
    }
    const fitLabels = { fitWidth: "fit width", fitPage: "fit page", zoom: "zoom" };
    const parts = [
      `Page ${state.currentPage} of ${state.pageCount}`,
      fitLabels[state.fitMode] || state.fitMode,
      `${Math.round(state.zoom * 100)}%`
    ];
    if (state.rotation) parts.push(`rotated ${state.rotation}°`);
    if (state.searchCount > 0) parts.push(`${state.searchCount} match${state.searchCount === 1 ? "" : "es"}`);
    ui.readerContextLine.textContent = parts.join(" · ");
  }

  function renderUnderstandPanel() {
    const state = getState();
    renderDocumentMap(state);
    renderEvidenceSummary(state);
    renderNextAction(state);
  }

  function renderDocumentMap(state) {
    const box = ui.understandDocumentMap;
    if (!box) return;
    box.replaceChildren();
    box.append(el("span", "block-label", "Document map"));
    if (!state.documentContract) {
      box.append(el("div", "next-action-empty", "No document mapped yet — open a PDF to inspect it locally."));
      return;
    }
    const map = el("div", "docmap");
    const pagesWithText = state.pagesWithTextCount;
    const rotated = state.rotatedPageCount;
    map.append(
      docmapRow("Pages", `${state.pageCount}`),
      docmapRow("Outline sections", `${state.outlineCount}`),
      docmapRow("Pages with selectable text", `${pagesWithText}`),
      docmapRow("Rotated pages", `${rotated}`)
    );
    for (const section of state.topOutlineSections) {
      map.append(docmapRow(`  ${section.title}`, section.pageLabel));
    }
    box.append(map);
  }

  function docmapRow(label, value) {
    const row = el("div", "docmap-row");
    const labelNode = el("span", "docmap-label", label);
    labelNode.style.overflow = "hidden";
    labelNode.style.textOverflow = "ellipsis";
    labelNode.style.whiteSpace = "nowrap";
    row.append(labelNode, el("span", "docmap-count", value));
    return row;
  }

  function renderEvidenceSummary(state) {
    const box = ui.understandEvidence;
    if (!box) return;
    box.replaceChildren();
    box.append(el("span", "block-label", "What this document knows"));
    if (!state.documentContract) {
      box.append(el("div", "next-action-empty", "Evidence appears after local inspection."));
      return;
    }
    const map = el("div", "evidence-summary");
    map.append(
      evidenceRow("Native fields", `${state.nativeFieldCount}`, state.nativeFieldCount ? "native" : "unknown"),
      evidenceRow("Suggested regions", `${state.candidateCount}`, state.candidateCount ? "review" : "unknown"),
      evidenceRow("Confirmed by you", `${state.confirmedCount}`, "reviewed"),
      evidenceRow("Dismissed", `${state.dismissedCount}`, "unknown")
    );
    box.append(map);
    box.append(el("div", "vr-note", "Suggestions are evidence-backed guesses. Native fields are contract facts. Neither is filled automatically."));
  }

  function evidenceRow(label, count, kind) {
    const row = el("div", "evidence-row");
    const chip = el("span", `evidence-chip chip ${kind}`, kind === "native" ? "Native field" : kind === "review" ? "Needs review" : kind === "reviewed" ? "Reviewed" : "Unknown");
    chip.style.fontSize = "8px";
    chip.style.fontFamily = "var(--pdf-mono)";
    chip.style.letterSpacing = "0.06em";
    chip.style.textTransform = "uppercase";
    chip.style.padding = "1px 6px";
    chip.style.border = "1px solid var(--pdf-border)";
    chip.style.borderRadius = "99px";
    chip.style.color = kind === "native" ? "var(--pdf-green-ink)" : kind === "reviewed" ? "var(--pdf-accent-deep)" : "var(--pdf-ink-faint)";
    row.append(el("span", "evidence-label", label), chip, el("span", "evidence-count", count));
    return row;
  }

  function renderNextAction(state) {
    const box = ui.understandNextAction;
    if (!box) return;
    box.replaceChildren();
    box.append(el("span", "block-label", "Next best action"));
    const pending = state.firstPendingCandidate;
    if (pending) {
      const card = el("div", "next-action-card");
      const copy = el("div", "next-action-copy");
      copy.append(
        el("strong", null, `Review “${pending.label}” on page ${pending.page}`),
        el("div", "vr-note", `${pending.reason} — nothing is applied until you confirm it.`)
      );
      const button = el("button", null, "Open review");
      button.type = "button";
      button.addEventListener("click", () => actions.focusCandidate(pending.id));
      card.append(copy, button);
      box.append(card);
      return;
    }
    if (state.candidateCount > 0) {
      box.append(el("div", "next-action-empty", "Every suggestion has a decision. Remaining work is yours to start."));
      return;
    }
    box.append(el("div", "next-action-empty", state.documentContract ? "No suggested regions — this document may already be complete." : "Open a PDF to see suggested work."));
  }

  function renderCompletePanel() {
    const box = ui.completeProgress;
    if (!box) return;
    const state = getState();
    box.replaceChildren();
    const total = state.candidateCount;
    const decided = state.confirmedCount + state.dismissedCount;
    const map = el("div", "evidence-summary");
    map.append(
      docmapRow("Suggested regions", total ? `${decided} of ${total} decided` : "0"),
      docmapRow("Native fields filled", `${state.filledNativeFieldCount}`),
      docmapRow("Operations in ledger", `${state.operationCount}`),
      docmapRow("Undos available", state.operationCount ? "Yes — rebuild from source" : "—")
    );
    box.append(map);
    const hint = el("div", "next-action-card");
    const copy = el("div", "next-action-copy");
    copy.append(
      el("strong", null, "The review queue is in the inspector"),
      el("div", "vr-note", "Every change becomes a reversible, source-bound operation. The source file itself is never modified.")
    );
    hint.append(copy);
    const openButton = el("button", null, "Open completion queue");
    openButton.type = "button";
    openButton.addEventListener("click", () => actions.focusCompletionQueue());
    hint.append(openButton);
    box.append(hint);
  }

  function renderOrganizePanel() {
    const box = ui.organizeInventory;
    if (!box) return;
    const state = getState();
    box.replaceChildren();
    const map = el("div", "evidence-summary");
    map.append(
      docmapRow("Pages in source", `${state.pageCount}`),
      docmapRow("Rotated pages", `${state.rotatedPageCount}`),
      docmapRow("Page operations applied", "0")
    );
    box.append(map);
    box.append(el("div", "organize-boundary",
      "Page reordering, extraction, and rotation-as-edit run in the native/companion lane, not in this browser surface. This panel stays honest about that boundary rather than offering controls that are not connected."));
  }

  function renderReviewPanel() {
    renderGuardrail();
    renderValidationReport();
  }

  function renderGuardrail() {
    const box = ui.reviewGuardrail;
    if (!box) return;
    const state = getState();
    box.replaceChildren();
    box.append(el("span", "block-label", "Three decisions before export"));
    const digestKnown = Boolean(state.sourceDigest);
    const decisions = [
      {
        satisfied: digestKnown,
        label: "1 · Source binding",
        note: digestKnown
          ? `Session is bound to source digest ${state.sourceDigest.slice(0, 12)}… — edits cannot drift to another file.`
          : "No source is open yet."
      },
      {
        satisfied: state.operationCount > 0,
        pending: state.operationCount === 0 && digestKnown,
        label: "2 · Reviewed changes",
        note: state.operationCount > 0
          ? `${state.operationCount} reversible operation${state.operationCount === 1 ? "" : "s"} in the ledger. Undo rebuilds from the immutable source.`
          : digestKnown
            ? "No changes yet — export would write a faithful new copy."
            : "Open a document to build an operation ledger."
      },
      {
        satisfied: Boolean(state.validationComplete),
        pending: digestKnown && !state.validationComplete,
        label: "3 · Export validation",
        note: state.validationComplete
          ? `New copy reopened and validated: ${state.validationSummary}.`
          : "Unknown until export: a new copy is written, reopened, and checked for structure, geometry, and untouched text."
      }
    ];
    for (const decision of decisions) {
      const card = el("div", `guardrail-decision ${decision.satisfied ? "is-satisfied" : decision.pending ? "is-pending" : ""}`);
      card.append(el("div", "guardrail-label", decision.label), el("div", "guardrail-note", decision.note));
      box.append(card);
    }
  }

  function renderValidationReport() {
    const box = ui.reviewValidation;
    if (!box) return;
    const state = getState();
    box.replaceChildren();
    box.append(el("span", "block-label", "Validation report"));
    const checks = state.validationChecks ?? [];
    if (!state.validationComplete) {
      box.append(el("div", "next-action-empty", "No export yet. Validation states stay unknown until a new copy is written and reopened."));
      return;
    }
    const report = el("div", "validation-report");
    for (const check of checks) {
      const row = el("div", "vr-row");
      const label = el("span", "vr-label", describeValidationCheck(check));
      label.style.minWidth = "0";
      label.style.overflow = "hidden";
      label.style.textOverflow = "ellipsis";
      row.append(label, el("span", `vr-state ${VALIDATION_STATE_CLASS[check.state] || "unknown"}`, check.state));
      report.append(row);
    }
    box.append(report);
  }

  /* ---------------- Local analysis reveal ---------------- */

  function analysisStage(stageID) {
    if (analysis.status !== "running") return;
    analysis.activeStage = stageID;
    renderAnalysisConsole();
  }

  function analysisStageDone(stageID) {
    if (analysis.status !== "running") return;
    analysis.completedStages.add(stageID);
    analysis.activeStage = null;
    renderAnalysisConsole();
  }

  function beginAnalysis() {
    analysis = createAnalysisState();
    analysis.status = "running";
    window.clearTimeout(overlayDismissTimer);
    if (ui.analysisOverlay) {
      ui.analysisOverlay.removeAttribute("hidden");
      ui.analysisOverlay.classList.remove("is-leaving");
    }
    renderAnalysisConsole();
    renderAnalysisPill();
  }

  function cancelAnalysis() {
    if (analysis.status !== "running") return;
    analysis.status = "skipped";
    analysis.cancelledPage = null;
    dismissOverlay();
    renderAnalysisPill();
  }

  function completeAnalysis({ nativeFieldCount = 0, candidateCount = 0, partialPage = null } = {}) {
    if (analysis.status !== "running") return;
    analysis.nativeFieldCount = nativeFieldCount;
    analysis.candidateCount = candidateCount;
    if (partialPage != null) {
      analysis.status = "partial";
      analysis.cancelledPage = partialPage;
    } else {
      analysis.status = "complete";
    }
    dismissOverlay();
    renderAnalysisPill();
  }

  function blockAnalysis(reason) {
    analysis.status = "unavailable";
    dismissOverlay(true);
    renderAnalysisPill(reason);
  }

  function failAnalysis(reason) {
    analysis.status = "failed";
    dismissOverlay(true);
    renderAnalysisPill(reason);
  }

  function dismissOverlay(immediate = false) {
    if (!ui.analysisOverlay || ui.analysisOverlay.hidden) return;
    const hide = () => ui.analysisOverlay.setAttribute("hidden", "");
    if (immediate || window.matchMedia?.("(prefers-reduced-motion: reduce)").matches) {
      hide();
      return;
    }
    ui.analysisOverlay.classList.add("is-leaving");
    overlayDismissTimer = window.setTimeout(() => {
      ui.analysisOverlay?.setAttribute("hidden", "");
      ui.analysisOverlay?.classList.remove("is-leaving");
    }, 220);
  }

  function renderAnalysisConsole() {
    if (!ui.analysisTitle || ui.analysisOverlay?.hidden) return;
    const stageIndex = ANALYSIS_STAGES.findIndex((s) => s.id === analysis.activeStage);
    const activeStage = stageIndex >= 0 ? ANALYSIS_STAGES[stageIndex] : null;
    const doneCount = analysis.completedStages.size;
    if (activeStage) {
      ui.analysisTitle.textContent = activeStage.title;
      if (ui.analysisCopy) ui.analysisCopy.textContent = activeStage.copy;
    }
    if (ui.analysisProgress) {
      ui.analysisProgress.setAttribute("aria-valuenow", String(doneCount));
    }
    if (ui.analysisProgressFill) {
      ui.analysisProgressFill.style.width = `${(doneCount / ANALYSIS_STAGES.length) * 100}%`;
    }
    for (const signal of ui.analysisSignals?.querySelectorAll("[data-signal]") ?? []) {
      const id = signal.dataset.signal;
      signal.classList.toggle("is-done", analysis.completedStages.has(id));
      signal.classList.toggle("is-active", analysis.activeStage === id);
    }
  }

  function renderAnalysisPill(reasonOverride) {
    if (!ui.analysisStatusPill) return;
    const pill = ui.analysisStatusPill;
    pill.className = "analysis-pill";
    pill.replaceChildren();
    const state = getState();
    const makeRetry = () => {
      const retry = el("button", null, "Re-analyze");
      retry.type = "button";
      retry.addEventListener("click", () => actions.rerunAnalysis());
      return retry;
    };
    if (analysis.status === "complete") {
      pill.classList.add("is-complete");
      const total = analysis.nativeFieldCount + analysis.candidateCount;
      pill.append(el("span", "pill-copy", `${total} editable signal${total === 1 ? "" : "s"} found — ${analysis.nativeFieldCount} native, ${analysis.candidateCount} suggested`));
      pill.append(makeRetry());
      return;
    }
    if (analysis.status === "partial") {
      pill.classList.add("is-partial");
      pill.append(el("span", "pill-copy", `Analysis cancelled on page ${analysis.cancelledPage} — partial results only`));
      pill.append(makeRetry());
      return;
    }
    if (analysis.status === "skipped") {
      pill.classList.add("is-skipped");
      pill.append(el("span", "pill-copy", "Analysis skipped — reader only"));
      pill.append(makeRetry());
      return;
    }
    if (analysis.status === "unavailable") {
      pill.classList.add("is-unavailable");
      pill.append(el("span", "pill-copy", reasonOverride || "Analysis unavailable"));
      return;
    }
    if (analysis.status === "failed") {
      pill.classList.add("is-failed");
      pill.append(el("span", "pill-copy", reasonOverride || "Analysis failed — source unchanged"));
      return;
    }
    if (analysis.status === "running") {
      pill.append(el("span", "pill-copy", "Analysing locally…"));
      return;
    }
    if (state.pageCount) {
      pill.append(el("span", "pill-copy", "Ready"));
    }
  }

  function isAnalysisCancelled() {
    return analysis.status !== "running";
  }

  function bindAnalysisControls() {
    ui.analysisCancelButton?.addEventListener("click", cancelAnalysis);
  }

  bindTablist();
  bindAnalysisControls();
  renderAnalysisPill();

  return {
    syncChrome,
    selectMode,
    refreshPanels,
    updateReaderContext,
    analysisStage,
    analysisStageDone,
    beginAnalysis,
    cancelAnalysis,
    completeAnalysis,
    blockAnalysis,
    failAnalysis,
    isAnalysisCancelled
  };
}
