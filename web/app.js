  // The independent impact validator is fail-closed for missing or mismatched operation regions.
  import { compareOutsideRegions } from "./pdf-impact-validator.mjs";
  import {
    assertExportableContract,
    guardedPdfLibExport,
    ContractMutationError
  } from "./pdf-contract-mutation-gate.mjs";
  import { detectGeometryCandidates } from "./pdf-geometry-detector.mjs";
  import {
    calibrateDocumentClassPolicies,
    classifyTemplateIndex,
    scoreTemplateFingerprints
  } from "./template-match-benchmark.mjs";
  import { runReviewedCorrectionBenchmark } from "./template-correction-benchmark.mjs";
  import {
    canMaterializeCompletion,
    canPromoteTemplateRevision,
    captureTemplateDraft,
    activateTemplateRevision,
    appendTemplateRevision,
    createCompletionProposal,
    createLearningEvent,
    createTemplateFingerprint,
    diffTemplateRevisions,
    exportTemplateHistory,
    importTemplateHistory,
    makeValidatedTemplateRevision,
    matchTemplate,
    materializeCompletionOperations,
    resolveCompletionTarget,
    reviewCompletionMapping,
    reviewCompletionValue,
    validateProfileContract,
    validateTemplateContract
  } from "./pdf-template-contract.mjs";
  import {
    createEncryptedTemplateStore,
    createEncryptedOPFSTemplateStore,
    createEphemeralTemplateStore,
    createZeroContentLogger,
    TemplateStoreError
  } from "./pdf-template-store.mjs";
  import { runIhatepdfExperimentParity } from "./ihatepdf-experiment-contract.mjs";
  import { buildPreflightReport, validatePreflightReport } from "./pdf-preflight.mjs";
  import {
    createSessionPrivacyProvenance,
    validateSessionPrivacyProvenance
  } from "./pdf-session-provenance.mjs";
  import {
    decryptTemplateSyncEnvelope,
    encryptTemplateSyncEnvelope,
    mergeTemplateHistories
  } from "./pdf-template-sync.mjs";
  import {
    chooseBrowserResourcePolicy,
    collectBrowserResourceEnvironment,
    validateBrowserResourcePolicy,
    normalizeResourceDocument,
    runAdaptiveBatches,
    createResourceCheckpoint,
    validateResourceCheckpoint,
    summarizeResourceEvent
  } from "./browser-resource-policy.mjs";
  import {
    buildTextRunReplacementProbe,
    compareOCRLayerAlignment,
    compareTextRunProjections,
    normalizePdfJsTextItems,
    validateTextRunOCRAlignmentReport
  } from "./text-run-ocr-alignment-benchmark.mjs";
  import {
    createProductSurfaceState,
    getProductMode,
    selectProductMode
  } from "./product-modes.mjs";
  import { createModeStageController } from "./mode-stage.mjs";

  const pdfLib = window.PDFLib;
  const WEB_ERROR_CODES = Object.freeze({
    inputMissing: "input-missing",
    cannotOpen: "cannot-open",
    passwordRequired: "password-required",
    passwordIncorrect: "password-incorrect",
    runtimeUnavailable: "runtime-unavailable",
    exportFailed: "export-failed",
    invalidOperation: "invalid-operation",
    unsupported: "unsupported"
  });
  // The vendored PDF.js build is the only runtime source: CSP `script-src 'self'`
  // and `connect-src 'none'` make CDN fallbacks unreachable dead code, and the
  // air-gap is a product promise. The pin is declared here so the contract test
  // can keep asserting the version without network URL strings.
  const PDFJS_PINNED_VERSION = "4.2.67";
  const pdfjsRuntimeURLs = ["./vendor/pdfjs/pdf.min.mjs"];
  const pdfjsWorkerURLs = ["./vendor/pdfjs/pdf.worker.min.mjs"];
  let pdfjsLib = null;
  let pdfjsRuntimeURL = null;
  for (const runtimeURL of pdfjsRuntimeURLs) {
    try {
      pdfjsLib = await import(runtimeURL);
      pdfjsRuntimeURL = runtimeURL;
      break;
    } catch {
      // Try the next pinned runtime before showing the local error state.
    }
  }

  const ui = {
    fileInput: document.getElementById("fileInput"),
    fitMode: document.getElementById("fitMode"),
    viewMode: document.getElementById("viewMode"),
    rotateL: document.getElementById("rotateL"),
    rotateR: document.getElementById("rotateR"),
    zoomSlider: document.getElementById("zoomSlider"),
    zoomValue: document.getElementById("zoomValue"),
    pageInput: document.getElementById("pageInput"),
    jumpButton: document.getElementById("jumpButton"),
    searchInput: document.getElementById("searchInput"),
    searchButton: document.getElementById("searchButton"),
    searchPrev: document.getElementById("searchPrev"),
    searchNext: document.getElementById("searchNext"),
    searchCount: document.getElementById("searchCount"),
    copyPageText: document.getElementById("copyPageText"),
    manualTextButton: document.getElementById("manualTextButton"),
    productModeNav: document.getElementById("productModeNav"),
    productModeStatus: document.getElementById("productModeStatus"),
    status: document.getElementById("status"),
    thumbnails: document.getElementById("thumbnails"),
    viewerStack: document.getElementById("viewerStack"),
    outlineBox: document.getElementById("outlineBox"),
    linksBox: document.getElementById("linksBox"),
    searchBox: document.getElementById("searchBox"),
    metaBox: document.getElementById("metaBox"),
    permissionsBox: document.getElementById("permissionsBox"),
    attachmentsBox: document.getElementById("attachmentsBox"),
    preflightBox: document.getElementById("preflightBox"),
    accessibilityBox: document.getElementById("accessibilityBox"),
    completionSource: document.getElementById("completionSource"),
    templateCard: document.getElementById("templateCard"),
    templateSummary: document.getElementById("templateSummary"),
    captureTemplateButton: document.getElementById("captureTemplateButton"),
    saveTemplateButton: document.getElementById("saveTemplateButton"),
    exportTemplateButton: document.getElementById("exportTemplateButton"),
    importTemplateButton: document.getElementById("importTemplateButton"),
    templateImportInput: document.getElementById("templateImportInput"),
    exportTemplateSyncButton: document.getElementById("exportTemplateSyncButton"),
    importTemplateSyncButton: document.getElementById("importTemplateSyncButton"),
    templateSyncImportInput: document.getElementById("templateSyncImportInput"),
    templateHealthButton: document.getElementById("templateHealthButton"),
    templateBackupButton: document.getElementById("templateBackupButton"),
    templateRestoreButton: document.getElementById("templateRestoreButton"),
    templateBackupInput: document.getElementById("templateBackupInput"),
    templateRecoveryButton: document.getElementById("templateRecoveryButton"),
    templateRecoveryRestoreButton: document.getElementById("templateRecoveryRestoreButton"),
    templateRecoveryInput: document.getElementById("templateRecoveryInput"),
    templateDeleteStoreButton: document.getElementById("templateDeleteStoreButton"),
    activateTemplateButton: document.getElementById("activateTemplateButton"),
    prepareTemplateButton: document.getElementById("prepareTemplateButton"),
    templateMappingList: document.getElementById("templateMappingList"),
    templateCompletionList: document.getElementById("templateCompletionList"),
    applyTemplateButton: document.getElementById("applyTemplateButton"),
    fieldList: document.getElementById("fieldList"),
    candidateList: document.getElementById("candidateList"),
    candidateAction: document.getElementById("candidateAction"),
    candidateActionDetail: document.getElementById("candidateActionDetail"),
    choiceCellControl: document.getElementById("choiceCellControl"),
    choiceCellSelect: document.getElementById("choiceCellSelect"),
    fieldControl: document.getElementById("fieldControl"),
    dismissCandidateButton: document.getElementById("dismissCandidateButton"),
    manualAction: document.getElementById("manualAction"),
    cancelManualTextButton: document.getElementById("cancelManualTextButton"),
    restoreDismissedButton: document.getElementById("restoreDismissedButton"),
    completionValue: document.getElementById("completionValue"),
    applyFieldButton: document.getElementById("applyFieldButton"),
    applyOverlayButton: document.getElementById("applyOverlayButton"),
    synthesizeFieldButton: document.getElementById("synthesizeFieldButton"),
    undoEditButton: document.getElementById("undoEditButton"),
    exportButton: document.getElementById("exportButton"),
    editList: document.getElementById("editList"),
    validationBox: document.getElementById("validationBox"),
    impactMetricsContent: document.getElementById("impactMetricsContent"),
    statusEl: document.getElementById("status"),
    modal: document.getElementById("passwordModal"),
    passwordForm: document.getElementById("passwordForm"),
    passwordInput: document.getElementById("passwordInput"),
    passwordSubmit: document.getElementById("passwordSubmit"),
    passwordCancel: document.getElementById("passwordCancel"),
    modeStage: document.getElementById("modeStage"),
    modePanels: {
      reader: document.getElementById("mode-panel-reader"),
      understand: document.getElementById("mode-panel-understand"),
      complete: document.getElementById("mode-panel-complete"),
      organize: document.getElementById("mode-panel-organize"),
      review: document.getElementById("mode-panel-review")
    },
    readerContextLine: document.getElementById("readerContextLine"),
    analysisStatusPill: document.getElementById("analysisStatusPill"),
    analysisOverlay: document.getElementById("analysisOverlay"),
    analysisTitle: document.getElementById("analysisTitle"),
    analysisCopy: document.getElementById("analysisCopy"),
    analysisProgress: document.getElementById("analysisProgress"),
    analysisProgressFill: document.getElementById("analysisProgressFill"),
    analysisSignals: document.getElementById("analysisSignals"),
    analysisCancelButton: document.getElementById("analysisCancelButton"),
    understandDocumentMap: document.getElementById("understandDocumentMap"),
    understandEvidence: document.getElementById("understandEvidence"),
    understandNextAction: document.getElementById("understandNextAction"),
    completeProgress: document.getElementById("completeProgress"),
    organizeInventory: document.getElementById("organizeInventory"),
    reviewGuardrail: document.getElementById("reviewGuardrail"),
    reviewValidation: document.getElementById("reviewValidation")
  };

  function disableReaderForRuntimeFailure() {
    document.querySelectorAll("button, input, select").forEach((control) => {
      control.disabled = true;
    });
    ui.status.className = "status danger";
    ui.status.textContent = `${WEB_ERROR_CODES.runtimeUnavailable}: PDF.js runtime unavailable. Check network access or provide a local PDF.js bundle.`;
  }

  if (!pdfjsLib) {
    disableReaderForRuntimeFailure();
  } else {
    window.pdfjsLib = pdfjsLib;
    pdfjsLib.GlobalWorkerOptions.workerSrc = new URL(pdfjsWorkerURLs[0], document.baseURI).href;
  }

  let pdfDoc = null;
  let pdfData = null;
  let currentPage = 1;
  let rotation = 0;
  let pageLabels = [];
  let links = [];
  let outlines = [];
  let attachments = [];
  let metadata = {};
  let permissions = {};
  let pageFacts = [];
  let searchResults = [];
  let selectedSearchIndex = -1;
  let pageTextCache = new Map();
  let pendingPassword = null;
  let isEncryptedDocument = false;
  let sourceName = "document.pdf";
  let sourceDigest = "";
  let currentSessionID = null;
  let documentContract = null;
  let textRunProjections = [];
  let nativeFields = [];
  let formOptionMap = new Map();
  let candidates = [];
  let operations = [];
  let reviews = [];
  let selectedField = null;
  let selectedCandidate = null;
  let selectedOperation = null;
  let manualPlacementMode = false;
  let manualPlacement = null;
  let showDismissedCandidates = false;
  let lastValidation = null;
  let preflightReport = null;
  let sessionProvenance = null;
  let resourcePolicy = null;
  let templateFingerprint = null;
  let templateContract = null;
  let templateRevisionHistory = null;
  let templateProposal = null;
  let templateValueDrafts = {};
  let templateLearningEvents = [];
  let pendingValidatedTemplateRevision = null;
  let templateRevisionDiff = null;
  let lastAppliedTemplateProposal = null;
  let templateCompletionOperationIDs = [];
  let browserStoreLogger = createZeroContentLogger();
  let browserStoreHealth = null;
  let loadGeneration = 0;
  let productSurfaceState = createProductSurfaceState();
  const scaleState = {
    fitMode: "fitWidth",
    viewMode: "continuous",
    zoom: 1,
    pageCount: 0
  };

  function readableCapabilityState(state) {
    return state.replaceAll("_", " ").replace(/\b\w/g, (character) => character.toUpperCase());
  }

  // --- Mode stage controller (Northstar five-mode surfaces + analysis reveal) ---
  // Presentation lives in mode-stage.mjs; this wires it to the live application
  // state via getters so the panels can never hold a second source of truth.
  const modeStage = createModeStageController({
    ui,
    getState: () => ({
      activeMode: productSurfaceState.activeMode,
      documentContract,
      sourceDigest,
      pageCount: scaleState.pageCount,
      currentPage,
      fitMode: scaleState.fitMode,
      zoom: scaleState.zoom,
      rotation,
      searchCount: searchResults.length,
      outlineCount: outlines.length,
      topOutlineSections: outlines.slice(0, 4).map((node) => ({
        title: node.title || "Section",
        pageLabel: node.pageLabel || ""
      })),
      pagesWithTextCount: pageFacts.length && documentContract
        ? documentContract.payload.pages.filter((page) => page.hasSelectableText).length
        : 0,
      rotatedPageCount: pageFacts.filter((fact) => fact.rotate % 360 !== 0).length,
      nativeFieldCount: nativeFields.length,
      candidateCount: candidates.length,
      confirmedCount: candidates.filter((candidate) => candidate.status === "confirmed").length,
      dismissedCount: candidates.filter((candidate) => candidate.status === "rejected").length,
      firstPendingCandidate: candidates.find((candidate) => candidate.status === "suggested") || null,
      filledNativeFieldCount: operations.filter((operation) => operation.kind === "nativeFieldValue").length,
      operationCount: operations.length,
      validationComplete: Boolean(lastValidation),
      validationSummary: lastValidation?.status || "",
      validationChecks: lastValidation?.checks || []
    }),
    actions: {
      selectMode: (modeID) => selectVisibleProductMode(modeID),
      focusCandidate: (candidateID) => {
        const row = ui.candidateList?.querySelector(`[data-candidate-id="${CSS.escape(candidateID)}"] button`)
          || ui.candidateList?.querySelector(`[data-candidate-id="${CSS.escape(candidateID)}"]`);
        if (row instanceof HTMLButtonElement) {
          row.click();
        } else if (row) {
          const button = row.querySelector("button") || row;
          button.click();
        } else {
          setStatus("That suggestion is not visible in the current queue.");
        }
      },
      focusCompletionQueue: () => {
        const card = document.querySelector(".completion-card");
        card?.scrollIntoView({ block: "start" });
        (card?.querySelector("button:not([disabled])") || card)?.focus?.();
      },
      rerunAnalysis: () => {
        if (!pdfDoc) return;
        setStatus("Re-running local analysis…");
        modeStage.beginAnalysis();
        buildCompletionContract().finally(() => {
          renderCompletionPanel();
          renderVisiblePages();
        });
      }
    }
  });

  function renderProductModeState() {
    modeStage.syncChrome(productSurfaceState);
    const mode = getProductMode(productSurfaceState.activeMode);
    const capability = productSurfaceState.capabilities[mode.id];
    if (ui.productModeStatus) {
      ui.productModeStatus.textContent = `${mode.label}: ${mode.description} Capability is ${readableCapabilityState(capability)}.`;
    }
  }

  function selectVisibleProductMode(modeID) {
    productSurfaceState = selectProductMode(productSurfaceState, modeID);
    renderProductModeState();
    modeStage.selectMode(modeID);
    if (modeID === "reader") {
      setStatus("Reader mode active.");
      return;
    }
    if (modeID === "complete") {
      setStatus("Complete mode active. Review a native field or suggested region before applying a change.");
      return;
    }
    if (modeID === "review") {
      setStatus("Review mode active. Export remains gated by validation.");
      return;
    }
    setStatus(`${getProductMode(modeID).label} mode is mapped and visible; its provider surface is not fully connected yet.`);
  }

  renderProductModeState();

  // --- Web Session Persistence (IndexedDB) ---
  const SESSION_DB_NAME = "pdf-editor-sessions";
  const SESSION_STORE_NAME = "sessions";
  const SESSION_DB_VERSION = 1;

  function openSessionDB() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(SESSION_DB_NAME, SESSION_DB_VERSION);
      request.onupgradeneeded = () => {
        const db = request.result;
        if (!db.objectStoreNames.contains(SESSION_STORE_NAME)) {
          db.createObjectStore(SESSION_STORE_NAME, { keyPath: "sourceDigest" });
        }
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async function saveWebSession() {
    if (!sourceDigest || !documentContract) return;
    try {
      const db = await openSessionDB();
      const tx = db.transaction(SESSION_STORE_NAME, "readwrite");
      const store = tx.objectStore(SESSION_STORE_NAME);
      const record = {
        sourceDigest,
        sourceName,
        savedAt: new Date().toISOString(),
        pageCount: scaleState.pageCount,
        operationCount: operations.length,
        operations: JSON.parse(JSON.stringify(operations)),
        candidateStatuses: {},
        selectedPageIndex: currentPage - 1,
        completionProgress: {
          totalCandidates: candidates.length,
          confirmedCount: candidates.filter(c => c.status === "confirmed").length,
          rejectedCount: candidates.filter(c => c.status === "rejected").length,
          remainingCount: candidates.filter(c => c.status !== "confirmed" && c.status !== "rejected").length
        }
      };
      for (const c of candidates) {
        if (c.status !== "suggested") {
          record.candidateStatuses[c.id] = c.status;
        }
      }
      store.put(record);
      db.close();
    } catch (err) {
      // Session save failure is non-fatal
      console.warn("Session save failed:", err);
    }
  }

  async function loadWebSession(digest) {
    try {
      const db = await openSessionDB();
      const tx = db.transaction(SESSION_STORE_NAME, "readonly");
      const store = tx.objectStore(SESSION_STORE_NAME);
      return new Promise((resolve) => {
        const request = store.get(digest);
        request.onsuccess = () => resolve(request.result || null);
        request.onerror = () => resolve(null);
      }).finally(() => db.close());
    } catch {
      return null;
    }
  }

  async function listWebSessions() {
    try {
      const db = await openSessionDB();
      const tx = db.transaction(SESSION_STORE_NAME, "readonly");
      const store = tx.objectStore(SESSION_STORE_NAME);
      return new Promise((resolve) => {
        const request = store.getAll();
        request.onsuccess = () => {
          const sessions = request.result || [];
          sessions.sort((a, b) => new Date(b.savedAt) - new Date(a.savedAt));
          resolve(sessions);
        };
        request.onerror = () => resolve([]);
      }).finally(() => db.close());
    } catch {
      return [];
    }
  }

  async function deleteWebSession(digest) {
    try {
      const db = await openSessionDB();
      const tx = db.transaction(SESSION_STORE_NAME, "readwrite");
      const store = tx.objectStore(SESSION_STORE_NAME);
      store.delete(digest);
      db.close();
    } catch {
      // Non-fatal
    }
  }

  async function restoreWebSession(record) {
    if (!record) return false;
    // Restore candidate statuses
    for (const c of candidates) {
      if (record.candidateStatuses && record.candidateStatuses[c.id]) {
        c.status = record.candidateStatuses[c.id];
      }
    }
    // Restore operations
    operations.length = 0;
    for (const op of (record.operations || [])) {
      operations.push(op);
    }
    // Restore page selection
    if (typeof record.selectedPageIndex === "number") {
      currentPage = Math.max(1, Math.min(record.selectedPageIndex + 1, scaleState.pageCount));
    }
    renderCompletionPanel();
    renderVisiblePages();
    setStatus(`Restored session from ${new Date(record.savedAt).toLocaleDateString()} — ${record.operationCount} edits, ${record.completionProgress?.confirmedCount || 0}/${record.completionProgress?.totalCandidates || 0} fields filled`);
    return true;
  }

  // --- Encrypted local template and profile vaults ---
  const LOCAL_VAULT_DB_NAME = "pdf-editor-local-template-vault-v3";
  let encryptedBrowserStore = null;
  let browserStorePassphrase = null;
  let browserProfilePassphrase = null;
  let currentProfile = null;

  function profilePassphrasePrompt() {
    return window.prompt(
      "Unlock the encrypted local profile vault. Use at least 12 characters. The vault is local to this browser profile.",
      ""
    );
  }

  function templatePassphrasePrompt() {
    return window.prompt(
      "Unlock the encrypted local template store. Use at least 12 characters. This protects layout history, not PDF bytes.",
      ""
    );
  }

  async function ensureEncryptedBrowserStore({ promptForPassphrase = false } = {}) {
    if (!browserStorePassphrase && promptForPassphrase) {
      const passphrase = templatePassphrasePrompt();
      if (!passphrase) return null;
      browserStorePassphrase = passphrase;
    }
    if (!browserStorePassphrase) return null;
    if (!encryptedBrowserStore) {
      encryptedBrowserStore = createEncryptedTemplateStore({
        dbName: LOCAL_VAULT_DB_NAME,
        passphrase: browserStorePassphrase,
        logger: createZeroContentLogger()
      });
    }
    try {
      await encryptedBrowserStore.unlock(browserStorePassphrase);
      return encryptedBrowserStore;
    } catch (error) {
      browserStorePassphrase = null;
      if (error instanceof TemplateStoreError) throw error;
      throw new Error("The encrypted local store could not be unlocked.");
    }
  }

  async function unlockEncryptedProfileVault() {
    const store = await ensureEncryptedBrowserStore({ promptForPassphrase: true });
    if (!store) return false;
    const passphrase = browserProfilePassphrase || profilePassphrasePrompt();
    if (!passphrase) return false;
    browserProfilePassphrase = passphrase;
    const profiles = await store.list("profileHistory", { storePassphrase: browserStorePassphrase });
    for (const entry of profiles) {
      try {
        await store.unlockProfile(entry.id, browserProfilePassphrase, { storePassphrase: browserStorePassphrase });
      } catch {
        // A profile-specific unlock failure remains local and value-free. The
        // panel lists only profiles that can be authenticated explicitly.
      }
    }
    return true;
  }

  const STANDARD_KEYS = [
    { key: "person.firstName", label: "First Name" },
    { key: "person.lastName", label: "Last Name" },
    { key: "person.fullName", label: "Full Name" },
    { key: "person.email", label: "Email" },
    { key: "person.phone", label: "Phone" },
    { key: "person.dateOfBirth", label: "Date of Birth" },
    { key: "person.address.street", label: "Street Address" },
    { key: "person.address.city", label: "City" },
    { key: "person.address.state", label: "State" },
    { key: "person.address.zip", label: "ZIP Code" },
    { key: "person.address.country", label: "Country" },
    { key: "person.ssn", label: "SSN" },
    { key: "person.employer", label: "Employer" },
    { key: "person.jobTitle", label: "Job Title" }
  ];

  async function saveProfile(profile) {
    try {
      const store = await ensureEncryptedBrowserStore({ promptForPassphrase: true });
      if (!store) return false;
      if (!browserProfilePassphrase) {
        browserProfilePassphrase = profilePassphrasePrompt();
      }
      if (!browserProfilePassphrase) return false;
      const revisionID = makeID("profile-revision");
      const profileContract = {
        header: {
          contractName: "pdf-editor.profile",
          version: { major: 1, minor: 0 },
          profileID: profile.profileID,
          revisionID,
          generatedAt: new Date().toISOString(),
          provider: providerDescriptor()
        },
        payload: {
          profileID: profile.profileID,
          revisionID,
          parentRevisionID: profile.__profileRevisionID || null,
          displayName: profile.displayName,
          revisionNumber: Number(profile.__profileRevisionNumber || 0) + 1,
          storageScope: "deviceLocal",
          requiresUnlock: true,
          values: (profile.values || []).map((value) => ({
            id: value.id || makeID("profile-value"),
            semanticKey: value.semanticKey,
            value: { kind: "text", text: value.textValue || "" }
          }))
        }
      };
      validateProfileContract(profileContract);
      await store.saveProfileRevision(profileContract, {
        storePassphrase: browserStorePassphrase,
        profilePassphrase: browserProfilePassphrase
      });
      profile.__profileRevisionID = revisionID;
      profile.__profileRevisionNumber = profileContract.payload.revisionNumber;
      return true;
    } catch (error) {
      setStatus(`Encrypted profile save failed: ${error.message || "unknown error"}.`, "danger");
      return false;
    }
  }

  async function loadProfile(profileID) {
    if (!encryptedBrowserStore || !browserStorePassphrase || !browserProfilePassphrase) return null;
    try {
      const history = await encryptedBrowserStore.getProfileHistory(profileID, {
        storePassphrase: browserStorePassphrase,
        profilePassphrase: browserProfilePassphrase
      });
      const latest = history?.revisions?.at(-1);
      if (!latest) return null;
      return {
        profileID: latest.payload.profileID,
        displayName: latest.payload.displayName,
        values: (latest.payload.values || []).map((entry) => ({
          semanticKey: entry.semanticKey,
          textValue: entry.value?.text || entry.value?.choice || "",
          label: entry.semanticKey,
          category: "general"
        })),
        createdAt: latest.header.generatedAt,
        lastModifiedAt: latest.header.generatedAt,
        __profileRevisionID: latest.payload.revisionID,
        __profileRevisionNumber: latest.payload.revisionNumber
      };
    } catch {
      return null;
    }
  }

  async function listProfiles() {
    if (!encryptedBrowserStore || !browserStorePassphrase || !browserProfilePassphrase) return [];
    try {
      const entries = await encryptedBrowserStore.list("profileHistory", { storePassphrase: browserStorePassphrase });
      const profiles = [];
      for (const entry of entries) {
        const profile = await loadProfile(entry.id);
        if (profile) profiles.push(profile);
      }
      return profiles;
    } catch {
      return [];
    }
  }

  async function deleteProfile(profileID) {
    if (!encryptedBrowserStore || !browserStorePassphrase || !browserProfilePassphrase) return;
    try {
      await encryptedBrowserStore.deleteProfile(profileID, {
        storePassphrase: browserStorePassphrase,
        profilePassphrase: browserProfilePassphrase
      });
    } catch (error) {
      setStatus(`Encrypted profile deletion failed: ${error.message || "unknown error"}.`, "danger");
    }
  }

  function profileGetValue(profile, key) {
    const entry = (profile.values || []).find(v => v.semanticKey === key);
    return entry ? entry.textValue : "";
  }

  function profileSetValue(profile, key, value) {
    if (!profile.values) profile.values = [];
    const idx = profile.values.findIndex(v => v.semanticKey === key);
    if (idx >= 0) {
      profile.values[idx].textValue = value;
    } else {
      profile.values.push({ semanticKey: key, textValue: value, label: key, category: "general" });
    }
    profile.lastModifiedAt = new Date().toISOString();
  }

  function matchProfileToFields(profile, fields, candidates) {
    const operations = [];
    const unmatched = [];
    const usedKeys = new Set();
    const values = (profile.values || []).filter(v => v.textValue);

    // Match native fields
    for (const field of fields) {
      const name = field.name.toLowerCase();
      let matched = false;
      for (const pv of values) {
        const key = pv.semanticKey.toLowerCase();
        if ((name.includes("name") && key.includes("fullname")) ||
            (name.includes("first") && key.includes("firstname")) ||
            (name.includes("last") && key.includes("lastname")) ||
            (name.includes("email") && key.includes("email")) ||
            (name.includes("phone") && key.includes("phone")) ||
            (name.includes("address") && key.includes("address.street")) ||
            (name.includes("city") && key.includes("address.city")) ||
            (name.includes("state") && key.includes("address.state")) ||
            ((name.includes("zip") || name.includes("postal")) && key.includes("address.zip")) ||
            (name.includes("ssn") && key.includes("ssn")) ||
            ((name.includes("dob") || name.includes("birth")) && key.includes("dateofbirth")) ||
            ((name.includes("employer") || name.includes("company")) && key.includes("employer")) ||
            (name.includes("title") && key.includes("jobtitle"))) {
          usedKeys.add(pv.semanticKey);
          operations.push(makeOperation({
            pageIndex: field.pageIndex,
            kind: "nativeFieldValue",
            value: pv.textValue,
            targetID: field.name,
            bounds: field.bounds,
            sourceDigest,
            coordinate: field.coordinate,
            payload: { kind: field.kind === "button" ? "boolean" : "text", value: pv.textValue }
          }));
          matched = true;
          break;
        }
      }
      if (!matched) unmatched.push(field.name);
    }

    // Match static candidates
    for (const candidate of candidates) {
      if (!candidateIsDirectlyEditable(candidate)) continue;
      const label = (candidate.labelText || "").toLowerCase();
      if (!label) continue;
      for (const pv of values) {
        const key = pv.semanticKey.toLowerCase();
        if ((label.includes("name") && key.includes("fullname")) ||
            (label.includes("email") && key.includes("email")) ||
            (label.includes("phone") && key.includes("phone")) ||
            (label.includes("address") && key.includes("address.street")) ||
            (label.includes("city") && key.includes("address.city")) ||
            (label.includes("state") && key.includes("address.state")) ||
            ((label.includes("zip") || label.includes("postal")) && key.includes("address.zip")) ||
            (label.includes("ssn") && key.includes("ssn"))) {
          usedKeys.add(pv.semanticKey);
          const payload = candidate.entryMode === "characterGrid"
            ? { kind: "characterGrid", text: pv.textValue, cells: candidate.memberBounds || [] }
            : { kind: "text", text: pv.textValue };
          operations.push(makeOperation({
            pageIndex: candidate.pageIndex,
            kind: "overlayText",
            value: pv.textValue,
            bounds: candidate.bounds,
            candidateID: candidate.id,
            sourceDigest,
            coordinate: candidate.coordinate,
            payload
          }));
          break;
        }
      }
    }

    return { operations, unmatched, usedKeys: [...usedKeys], totalMatches: operations.length };
  }

  function setStatus(message, kind = "muted") {
    ui.status.className = `status ${kind}`;
    ui.status.textContent = message;
  }

  function normalizeReaderError(error, fallbackCode = WEB_ERROR_CODES.exportFailed) {
    if (error?.readerCode) {
      return error;
    }
    let readerCode = fallbackCode;
    if (error instanceof ContractMutationError || error?.name === "ContractMutationError") {
      readerCode = WEB_ERROR_CODES.invalidOperation;
    }
    if (error?.name === "PasswordException") {
      readerCode = error.code === pdfjsLib?.PasswordResponses?.NEED_PASSWORD
        ? WEB_ERROR_CODES.passwordRequired
        : WEB_ERROR_CODES.passwordIncorrect;
    } else if (/did not load|runtime unavailable/i.test(error?.message || "")) {
      readerCode = WEB_ERROR_CODES.runtimeUnavailable;
    } else if (/not supported|unsupported/i.test(error?.message || "")) {
      readerCode = WEB_ERROR_CODES.unsupported;
    } else if (fallbackCode === WEB_ERROR_CODES.cannotOpen) {
      readerCode = WEB_ERROR_CODES.cannotOpen;
    }
    const normalized = new Error(error?.message || "The PDF operation failed.");
    normalized.name = "PDFReaderError";
    normalized.readerCode = readerCode;
    normalized.contractCode = error?.code || null;
    normalized.contractIssues = error?.issues || [];
    normalized.retryable = readerCode !== WEB_ERROR_CODES.passwordIncorrect;
    normalized.cause = error;
    return normalized;
  }

  function displayReaderError(error, fallbackCode = WEB_ERROR_CODES.exportFailed) {
    const normalized = normalizeReaderError(error, fallbackCode);
    setStatus(`${normalized.readerCode}: ${normalized.message}`, "danger");
    return normalized;
  }

  function setSafeText(element, value) {
    element.textContent = value || "Not available";
  }

  function setHidden(el, hidden) {
    if (!el) { return; }
    el.hidden = hidden;
    el.style.display = hidden ? "none" : "block";
  }

  function activeCandidates() {
    return candidates.filter((candidate) => candidate.status !== "rejected");
  }

  function confidenceLabel(score) {
    const percent = Math.round(score * 100);
    if (score >= 0.75) { return `High · ${percent}%`; }
    if (score >= 0.5) { return `Medium · ${percent}%`; }
    return `Low · ${percent}%`;
  }

  function candidateEntryMode(candidate) {
    if (candidate.entryMode) { return candidate.entryMode; }
    if (candidate.suggestedFieldType === "checkbox") { return "checkbox"; }
    if (candidate.suggestedFieldType === "signature") { return "signature"; }
    return "singleText";
  }

  function candidateIsDirectlyEditable(candidate) {
    return ["singleText", "characterGrid", "signature"].includes(candidateEntryMode(candidate));
  }

  function candidateEntryLabel(candidate) {
    switch (candidateEntryMode(candidate)) {
      case "characterGrid":
        return `Character-entry region · ${candidate.groupMemberCount || 1} cells`;
      case "checkbox":
        return "Checkbox pattern · review only";
      case "radioGroup":
        return "Choice pattern · review only";
      case "signature":
        return "Signature region";
      case "singleText":
        return "Text entry region";
      default:
        return "Unclassified entry region";
    }
  }

  function makeID(prefix = "id") {
    if (window.crypto?.randomUUID) {
      return window.crypto.randomUUID();
    }
    return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }

  async function sha256Hex(bytes) {
    const digest = await window.crypto.subtle.digest("SHA-256", bytes);
    return [...new Uint8Array(digest)].map((value) => value.toString(16).padStart(2, "0")).join("");
  }

  function providerDescriptor() {
    return {
      id: "pdfjs-pdflib",
      version: "pdfjs-4.2.67+pdf-lib-1.17.1",
      platform: "web",
      capabilities: ["render", "text", "forms", "overlay", "export", "reopen-validation"]
    };
  }

  function normalizeRect(rect) {
    const [x1, y1, x2, y2] = rect;
    return {
      x: Math.min(x1, x2),
      y: Math.min(y1, y2),
      width: Math.abs(x2 - x1),
      height: Math.abs(y2 - y1)
    };
  }

  function coordinateFor(pageIndex, rect, pageRotation = 0) {
    return {
      pageIndex,
      rect,
      coordinateSpace: {
        unit: "points",
        origin: "lowerLeft",
        pageBox: "crop",
        rotationDegrees: ((pageRotation % 360) + 360) % 360
      }
    };
  }

  function fieldKind(annotation) {
    const value = annotation.fieldType || annotation.fieldTypeName || "";
    if (value === "Tx") { return "text"; }
    if (value === "Btn") { return "button"; }
    if (value === "Ch") { return "choice"; }
    if (value === "Sig") { return "signature"; }
    return "unknown";
  }

  function suggestedType(text) {
    const value = text.toLowerCase();
    if (/(sign|signature)/.test(value)) { return "signature"; }
    if (/(date|dob|birth)/.test(value)) { return "date"; }
    if (/(amount|number|count|zip|postal|phone|tel)/.test(value)) { return "number"; }
    if (/(yes|no|agree|check|mark)/.test(value)) { return "checkbox"; }
    return "text";
  }

  function stringValue(value) {
    if (value === null || value === undefined) { return ""; }
    if (Array.isArray(value)) { return value.join(", "); }
    if (typeof value === "object") { return value.displayValue || value.exportValue || value.value || ""; }
    return String(value);
  }

  function nativeButtonOptions(field) {
    const entries = nativeFields
      .filter((entry) => entry.name === field.name && entry.kind === "button");
    const values = entries
      .flatMap((entry) => entry.choices?.length ? entry.choices : (entry.value ? [entry.value] : []));
    const isGroup = entries.length > 1;
    return [...new Set(values.filter((value) => {
      if (!value || /^off$/i.test(String(value).trim())) { return false; }
      return isGroup || !/^\d+$/.test(String(value).trim());
    }))];
  }

  function renderNativeFieldControl() {
    ui.fieldControl.innerHTML = "";
    const field = selectedField;
    if (!field) {
      setHidden(ui.fieldControl, true);
      return;
    }
    if (field.kind === "button") {
      const options = nativeButtonOptions(field);
      if (options.length > 1) {
        const select = document.createElement("select");
        select.setAttribute("aria-label", `Option for ${field.name}`);
        options.forEach((option) => {
          const item = document.createElement("option");
          item.value = option;
          item.textContent = option;
          select.appendChild(item);
        });
        select.value = ui.completionValue.value || field.value || options[0];
        select.addEventListener("change", () => {
          ui.completionValue.value = select.value;
          renderCompletionPanel();
        });
        ui.fieldControl.append("Selected option ", select);
      } else {
        const label = document.createElement("label");
        const checkbox = document.createElement("input");
        checkbox.type = "checkbox";
        checkbox.checked = /^(1|true|yes|on|checked)$/i.test(ui.completionValue.value || field.value || "");
        checkbox.addEventListener("change", () => {
          ui.completionValue.value = checkbox.checked ? (options[0] || "Yes") : "false";
          renderCompletionPanel();
        });
        label.append(checkbox, " Checked");
        ui.fieldControl.appendChild(label);
      }
      setHidden(ui.fieldControl, false);
      return;
    }
    if (field.kind === "choice" && field.choices?.length) {
      const select = document.createElement("select");
      select.setAttribute("aria-label", `Option for ${field.name}`);
      const empty = document.createElement("option");
      empty.value = "";
      empty.textContent = "Empty";
      select.appendChild(empty);
      field.choices.forEach((option) => {
        const item = document.createElement("option");
        item.value = option;
        item.textContent = option;
        select.appendChild(item);
      });
      select.value = ui.completionValue.value || field.value || "";
      select.addEventListener("change", () => {
        ui.completionValue.value = select.value;
        renderCompletionPanel();
      });
      ui.fieldControl.append("Selected option ", select);
      setHidden(ui.fieldControl, false);
      return;
    }
    setHidden(ui.fieldControl, true);
  }

  function normalizedAnnotationKind(annotation) {
    const subtype = annotation?.subtype || annotation?.annotationType || "unknown";
    if (subtype === "Widget") return "widget";
    if (subtype === "Link") return "link";
    if (subtype === "FileAttachment") return "fileAttachment";
    if (["Text", "FreeText", "Highlight", "Underline", "StrikeOut", "Squiggly", "Ink", "Square", "Circle", "Line", "Polygon", "PolyLine", "Caret", "Stamp", "Popup"].includes(subtype)) return "markup";
    return "unknown";
  }

  async function inspectNativeFields(pageNum) {
    const page = await pdfDoc.getPage(pageNum);
    const annotations = await page.getAnnotations({ intent: "display" });
    return annotations
      .filter((annotation) => annotation.subtype === "Widget" || annotation.fieldType)
      .map((annotation, index) => {
        const pageIndex = pageNum - 1;
        const name = annotation.fieldName || annotation.id || `field-${pageNum}-${index + 1}`;
        const bounds = normalizeRect(annotation.rect || [0, 0, 0, 0]);
        let rawChoices = annotation.options || [];
        if (annotation.fieldType === "Btn") {
          rawChoices = (annotation.fieldFlags & 32768) && formOptionMap.has(name)
            ? formOptionMap.get(name)
            : [];
        }
        const choices = rawChoices.map((option) => {
          if (typeof option === "string") { return option; }
          return option.displayValue || option.exportValue || option.value || "";
        }).filter((option) => {
          if (!option) return false;
          // pdf-lib can expose numeric widget indices as radio options. They
          // are implementation placeholders, not user-facing export values;
          // keep meaningful string values while matching the native contract.
          return !((annotation.fieldFlags & 32768) && /^\d+$/.test(String(option).trim()));
        });
        const rawValue = stringValue(annotation.fieldValue);
        const value = annotation.fieldType === "Btn" && /^off$/i.test(rawValue) ? "" : rawValue;
        return {
          id: name,
          name,
          kind: fieldKind(annotation),
          pageIndex,
          bounds,
          value,
          choices,
          coordinate: coordinateFor(pageIndex, bounds, page.rotate || 0),
          annotationID: annotation.id || null,
          fieldFlags: annotation.fieldFlags ?? null
        };
      });
  }

  function pdfRectForText(viewport, item) {
    const transform = pdfjsLib.Util.transform(viewport.transform, item.transform);
    const fontSize = Math.max(1, Math.hypot(transform[0], transform[1]));
    const x = transform[4];
    const yTop = transform[5] - fontSize;
    const width = Math.max(1, item.width || 0);
    const topLeft = viewport.convertToPdfPoint(x, yTop);
    const bottomRight = viewport.convertToPdfPoint(x + width, yTop + fontSize);
    return normalizeRect([topLeft[0], topLeft[1], bottomRight[0], bottomRight[1]]);
  }

  async function detectStaticCandidates(pageNum) {
    const page = await pdfDoc.getPage(pageNum);
    const pageIndex = pageNum - 1;
    return detectGeometryCandidates({
      pdfjsLib,
      page,
      pageIndex,
      pageRotation: page.rotate || 0,
      sourceDigest
    });
  }

  function outlineContractItems(items, parentID = "outline") {
    return items.map((item, index) => {
      const id = `${parentID}-${index + 1}`;
      return {
        id,
        title: item.title || "Section",
        level: item.level || 0,
        destinationPageIndex: item.destPage ? item.destPage - 1 : null,
        children: outlineContractItems(item.items || [], id)
      };
    });
  }

  function linkContractItems() {
    return links.map((link, index) => ({
      id: `link-${index + 1}`,
      pageIndex: Math.max(0, (link.page || 1) - 1),
      label: link.label || "Link",
      kind: link.url ? "externalURL" : link.pageTarget != null ? "internalPage" : "unknown",
      destination: link.url || (link.pageTarget != null ? String(link.pageTarget) : link.dest || null),
      destinationBounds: link.bounds || null,
      isSafeExternal: link.pageTarget != null || Boolean(link.safe),
      ...(link.pageTarget != null ? { targetPageIndex: link.pageTarget - 1 } : {})
    }));
  }

  function buildResourcePolicy() {
    const pages = documentContract?.payload?.pages || [];
    const pageAreas = pages.map((page) => Math.max(0, (page.bounds?.width || 0) * (page.bounds?.height || 0)));
    const maxPageAreaPoints = Math.max(...pageAreas, 612 * 792);
    const maxPageDimensionPoints = Math.max(...pages.map((page) => Math.max(page.bounds?.width || 0, page.bounds?.height || 0)), 792);
    const selectableTextPageCount = pages.filter((page) => page.hasSelectableText).length;
    resourcePolicy = chooseBrowserResourcePolicy({
      environment: collectBrowserResourceEnvironment(window),
      document: normalizeResourceDocument({
        byteCount: pdfData?.byteLength || 0,
        pageCount: pages.length || 1,
        maxPageAreaPoints,
        maxPageDimensionPoints,
        rotatedPageCount: pages.filter((page) => page.rotation).length,
        rasterPageCount: pages.filter((page) => !page.hasSelectableText).length,
        selectableTextPageCount,
        nativeFieldCount: nativeFields.length,
        candidateCount: candidates.length,
        isEncrypted: isEncryptedDocument
      }),
      request: { renderMode: "reader", ocrRequested: false, batchRequested: false },
      sourceDigest,
      provider: providerDescriptor()
    });
    validateBrowserResourcePolicy(resourcePolicy, { expectedSourceDigest: sourceDigest });
    return resourcePolicy;
  }

  async function buildCompletionContract() {
    // Analysis reveal: the four inspection stages report real progress and the
    // user may cancel into reader-only mode; a cancelled pass leaves partial,
    // clearly-scoped results instead of pretending completion.
    modeStage.analysisStage("digest");
    sourceDigest = await sha256Hex(pdfData);
    modeStage.analysisStageDone("digest");
    const fields = [];
    const staticCandidates = [];
    const pages = [];
    const projectedTextRuns = [];
    const annotationTypeCounts = {};
    let cancelledPage = null;
    modeStage.analysisStage("fields");
    for (let pageNum = 1; pageNum <= scaleState.pageCount; pageNum += 1) {
      if (modeStage.isAnalysisCancelled()) {
        cancelledPage = pageNum;
        break;
      }
      const page = await pdfDoc.getPage(pageNum);
      const content = await page.getTextContent();
      const annotations = await page.getAnnotations({ intent: "display" });
      for (const annotation of annotations) {
        const kind = normalizedAnnotationKind(annotation);
        annotationTypeCounts[kind] = (annotationTypeCounts[kind] || 0) + 1;
      }
      const fact = pageFacts.find((entry) => entry.page === pageNum);
      const view = fact?.view || [0, 0, page.view?.[2] || 0, page.view?.[3] || 0];
      const bounds = fact?.boxes?.crop || normalizeRect(view);
      fields.push(...await inspectNativeFields(pageNum));
      projectedTextRuns.push(...await normalizePdfJsTextItems({
        items: content.items,
        pageIndex: pageNum - 1,
        pageBounds: bounds,
        rotation: page.rotate || 0,
        providerID: "pdfjs",
        sourceDigest
      }));
      pages.push({
        pageIndex: pageNum - 1,
        pageLabel: fact?.label || String(pageNum),
        bounds,
        cropBox: fact?.boxes?.crop || bounds,
        bleedBox: fact?.boxes?.bleed || null,
        trimBox: fact?.boxes?.trim || null,
        artBox: fact?.boxes?.art || null,
        rotation: page.rotate || 0,
        characterCount: content.items.reduce((total, item) => total + (item.str || "").length, 0),
        annotationCount: annotations.length,
        hasSelectableText: content.items.some((item) => Boolean((item.str || "").trim()))
      });
    }
    modeStage.analysisStageDone("fields");
    if (!cancelledPage && !modeStage.isAnalysisCancelled()) {
      modeStage.analysisStage("signals");
      for (let pageNum = 1; pageNum <= scaleState.pageCount; pageNum += 1) {
        if (modeStage.isAnalysisCancelled()) {
          cancelledPage = pageNum;
          break;
        }
        staticCandidates.push(...await detectStaticCandidates(pageNum));
      }
      modeStage.analysisStageDone("signals");
    } else if (!cancelledPage) {
      cancelledPage = 1;
    }
    nativeFields = fields;
    candidates = staticCandidates;
    textRunProjections = projectedTextRuns;
    documentContract = {
      header: {
        contractName: "pdf-editor.document",
        version: { major: 1, minor: 0 },
        sourceDigest,
        generatedAt: new Date().toISOString(),
        provider: providerDescriptor()
      },
      payload: {
        source: { fileName: sourceName, byteCount: pdfData.byteLength, sha256: sourceDigest },
        pages,
        fields: nativeFields,
        candidates,
        warnings: cancelledPage
          ? [`Local analysis was cancelled on page ${cancelledPage}; review signals for pages ${cancelledPage}–${scaleState.pageCount} were not inspected.`]
          : candidates.length ? [] : ["No static blank-region candidate was inferred from text extraction."],
        links: linkContractItems(),
        outlines: outlineContractItems(outlines),
        metadata: {
          title: metadata.Title || "",
          author: metadata.Author || "",
          subject: metadata.Subject || "",
          creator: metadata.Creator || "",
          producer: metadata.Producer || "",
          creationDate: metadata.CreationDate || "",
          modificationDate: metadata.ModDate || "",
          keywords: metadata.Keywords || ""
        },
        permissions: {
          canPrint: Boolean(permissions.print),
          canCopy: Boolean(permissions.copy),
          canModify: Boolean(permissions.modify),
          canAddAnnotations: Boolean(permissions.annotate),
          isReadOnly: permissions.modify === false
        },
        attachments,
        annotationTypeCounts,
        accessibility: {
          hasTaggedContent: false,
          hasReadingOrder: pages.some((page) => page.hasSelectableText),
          notes: ["Reading order is derived from PDF.js text extraction and is not an authored-tag guarantee."]
        },
        security: { isEncrypted: Boolean(isEncryptedDocument), isLocked: false, requiresPassword: false }
      }
    };
    preflightReport = buildPreflightReport({
      document: documentContract,
      sourceBytes: pdfData,
      provider: providerDescriptor()
    });
    validatePreflightReport(preflightReport);
    buildResourcePolicy();
    sessionProvenance = buildSessionPrivacyProvenance();
    renderPreflightReport();
    renderCompletionPanel();
    modeStage.completeAnalysis({
      nativeFieldCount: nativeFields.length,
      candidateCount: candidates.length,
      partialPage: cancelledPage
    });
  }

  function buildSessionPrivacyProvenance() {
    if (!sourceDigest) return null;
    const externalRuntime = /^https?:\/\//i.test(pdfjsRuntimeURL || "");
    const validation = lastValidation;
    let exportProvenance;
    if (!validation) {
      exportProvenance = {
        state: "not-attempted",
        sourceDigest,
        outputDigest: null,
        storage: "not-applicable",
        validation: "not-run",
        outputReopenable: null,
        operationCount: operations.length,
        exporterID: null,
        validationProviderID: null
      };
    } else {
      const succeeded = validation.status === "validated" || validation.status === "validated-with-warnings";
      exportProvenance = {
        state: succeeded ? "succeeded" : "failed",
        sourceDigest,
        outputDigest: validation.outputDigest || null,
        storage: succeeded ? "local-download" : "not-applicable",
        validation: validation.status === "validated" ? "validated"
          : validation.status === "validated-with-warnings" ? "validated-with-warnings"
            : validation.status === "failed" ? "failed" : "unknown",
        outputReopenable: validation.outputReopenable ?? null,
        operationCount: operations.length,
        exporterID: validation.provider?.id || null,
        validationProviderID: validation.provider?.id || null
      };
    }
    const record = createSessionPrivacyProvenance({
      sessionID: currentSessionID || "browser-session-pending",
      sourceDigest,
      provider: providerDescriptor(),
      processing: {
        locality: "local-browser",
        sourceInput: "local-file-picker",
        dataEgress: externalRuntime ? "runtime-only" : "none",
        networkRequestCount: externalRuntime ? 1 : 0,
        companionRequestCount: 0
      },
      ocr: {
        state: "not-used",
        providerIDs: [],
        processedPageCount: 0,
        recognizedTextRetained: false,
        recognizedBoundsRetained: false
      },
      sourceRetention: {
        state: "in-memory-session",
        retainedUntilSessionEnd: true,
        deletion: "pending",
        sourceCopyCount: 1
      },
      exportProvenance
    });
    validateSessionPrivacyProvenance(record, { expectedSourceDigest: sourceDigest });
    return record;
  }

  async function captureTemplateLayout() {
    if (!documentContract) return;
    try {
      templateFingerprint = await createTemplateFingerprint({
        document: documentContract,
        workspaceKey: "browser-local-template-key",
        includeExactSourceDigest: true
      });
      templateContract = captureTemplateDraft({
        document: documentContract,
        fingerprint: templateFingerprint,
        displayName: "Reviewed local layout",
        sessionID: makeID("template-capture")
      });
      const mappings = templateContract.payload.mappings || [];
      templateProposal = null;
      templateValueDrafts = {};
      templateLearningEvents = [];
      pendingValidatedTemplateRevision = null;
      templateRevisionDiff = null;
      lastAppliedTemplateProposal = null;
      templateCompletionOperationIDs = [];
      templateRevisionHistory = {
        templateID: templateContract.payload.templateID,
        revisions: [templateContract]
      };
      validateTemplateContract(templateContract);
      setStatus(`Captured ${mappings.length} mapping proposal(s). Review them before activation.`);
      renderCompletionPanel();
    } catch (error) {
      displayReaderError(error);
    }
  }

  function updateTemplateMapping(mappingID, changes) {
    if (!templateContract) return;
    templateContract = {
      ...templateContract,
      payload: {
        ...templateContract.payload,
        mappings: templateContract.payload.mappings.map((mapping) => mapping.id === mappingID
          ? { ...mapping, ...changes }
          : mapping)
      }
    };
  }

  function canSaveValidatedTemplateRevision() {
    if (!pendingValidatedTemplateRevision || !lastValidation || lastValidation.status !== "validated") return false;
    const currentIDs = new Set(operations.map((operation) => operation.id));
    const validatedIDs = new Set(lastValidation.operationIDs || []);
    const completionIDs = new Set(templateCompletionOperationIDs);
    return currentIDs.size > 0
      && currentIDs.size === validatedIDs.size
      && [...currentIDs].every((id) => validatedIDs.has(id))
      && currentIDs.size === completionIDs.size
      && [...currentIDs].every((id) => completionIDs.has(id));
  }

  async function saveTemplateRevisionLocally() {
    if (!templateContract) return;
    try {
      const store = await ensureEncryptedBrowserStore({ promptForPassphrase: true });
      if (!store) return;
      if (canSaveValidatedTemplateRevision()) {
        const parent = templateContract;
        const child = pendingValidatedTemplateRevision || makeValidatedTemplateRevision({
          template: parent,
          sourceDigest,
          sessionID: lastAppliedTemplateProposal?.sessionID || null
        });
        templateRevisionHistory = await store.saveTemplateRevision(child, {
          storePassphrase: browserStorePassphrase
        });
        for (const event of templateLearningEvents) {
          await store.saveLearningEvent({ ...event, status: "applied" }, {
            storePassphrase: browserStorePassphrase
          });
        }
        templateRevisionDiff = diffTemplateRevisions(parent, child);
        templateContract = child;
        templateLearningEvents = templateLearningEvents.map((event) => ({ ...event, status: "applied" }));
        pendingValidatedTemplateRevision = null;
        lastAppliedTemplateProposal = null;
        templateCompletionOperationIDs = [];
        setStatus("Saved a new validated template revision. Profile values remain outside template history.");
      } else {
        templateRevisionHistory = await store.saveTemplateRevision(templateContract, {
          storePassphrase: browserStorePassphrase
        });
        setStatus(`Persisted encrypted ${templateContract.payload.lifecycle} working capture. A strict validated export is still required before learning is saved.`);
      }
      renderCompletionPanel();
    } catch (error) {
      setStatus(`Encrypted template save failed: ${error.message || "unknown error"}.`, "danger");
    }
  }

  async function exportTemplateTransfer() {
    if (!templateContract) return;
    try {
      const store = await ensureEncryptedBrowserStore({ promptForPassphrase: true });
      if (!store) return;
      const envelope = await store.exportTemplateHistory(templateContract.payload.templateID, {
        storePassphrase: browserStorePassphrase
      });
      const blob = new Blob([JSON.stringify(envelope, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `${templateContract.payload.displayName.replace(/[^a-z0-9_-]+/gi, "-") || "pdf-template"}.json`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setStatus("Exported a value-free template transfer envelope. Source bytes and profile values were excluded.");
    } catch (error) {
      setStatus(`Template export failed: ${error.message || "unknown error"}.`, "danger");
    }
  }

  async function importTemplateTransfer(file) {
    if (!file) return;
    try {
      const store = await ensureEncryptedBrowserStore({ promptForPassphrase: true });
      if (!store) return;
      const envelope = JSON.parse(await file.text());
      const history = await store.importTemplateHistory(envelope, {
        storePassphrase: browserStorePassphrase,
        replace: false
      });
      templateRevisionHistory = history;
      templateContract = history.revisions.at(-1) || null;
      templateFingerprint = templateContract?.payload?.fingerprint || null;
      templateProposal = null;
      templateLearningEvents = await store.getLearningEvents(history.templateID, {
        storePassphrase: browserStorePassphrase
      });
      pendingValidatedTemplateRevision = null;
      templateRevisionDiff = null;
      setStatus("Imported a value-free template revision history. Review the current document before completion.");
      renderCompletionPanel();
    } catch (error) {
      setStatus(`Template import failed: ${error.message || "unknown error"}.`, "danger");
    }
  }

  async function exportTemplateSync() {
    if (!templateRevisionHistory || !templateContract) return;
    const passphrase = templatePassphrasePrompt();
    if (!passphrase) return;
    try {
      const envelope = await encryptTemplateSyncEnvelope({
        history: templateRevisionHistory,
        learningEvents: templateLearningEvents,
        deviceID: "browser-local-device",
        generation: templateRevisionHistory.revisions.length,
        passphrase
      });
      const blob = new Blob([JSON.stringify(envelope, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `${templateContract.payload.displayName.replace(/[^a-z0-9_-]+/gi, "-") || "pdf-template"}-sync.json`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      setStatus("Exported a client-encrypted template sync envelope. The passphrase never leaves this browser.");
    } catch (error) {
      setStatus(`Encrypted sync export failed: ${error.message || "unknown error"}.`, "danger");
    }
  }

  async function importTemplateSync(file) {
    if (!file) return;
    const passphrase = templatePassphrasePrompt();
    if (!passphrase) return;
    try {
      const envelope = JSON.parse(await file.text());
      const incoming = await decryptTemplateSyncEnvelope(envelope, { passphrase });
      if (templateRevisionHistory) {
        const merged = mergeTemplateHistories(templateRevisionHistory, incoming.history);
        if (merged.conflicts.length) throw new Error(`Sync merge requires review: ${merged.conflicts.map((entry) => entry.reason).join(", ")}`);
        templateRevisionHistory = merged.history;
      } else {
        templateRevisionHistory = incoming.history;
      }
      templateContract = templateRevisionHistory.revisions.at(-1) || null;
      templateFingerprint = templateContract?.payload?.fingerprint || null;
      templateLearningEvents = incoming.learningEvents || [];
      pendingValidatedTemplateRevision = null;
      templateProposal = null;
      templateRevisionDiff = null;
      const store = await ensureEncryptedBrowserStore({ promptForPassphrase: true });
      if (store && templateRevisionHistory) {
        for (const revision of templateRevisionHistory.revisions) {
          const existing = await store.getTemplateHistory(revision.payload.templateID, { storePassphrase: browserStorePassphrase });
          if (!existing?.revisions?.some((entry) => entry.payload.revisionID === revision.payload.revisionID)) {
            await store.saveTemplateRevision(revision, { storePassphrase: browserStorePassphrase });
          }
        }
      }
      setStatus("Imported and merged a client-encrypted template sync envelope. No profile values were synchronized.");
      renderCompletionPanel();
    } catch (error) {
      setStatus(`Encrypted sync import failed: ${error.message || "unknown error"}.`, "danger");
    }
  }

  function prepareValidatedTemplateRevisionFromValidation() {
    pendingValidatedTemplateRevision = null;
    templateRevisionDiff = null;
    if (!lastAppliedTemplateProposal || !templateContract || !lastValidation) return;
    const currentIDs = new Set(operations.map((operation) => operation.id));
    const completionIDs = new Set(templateCompletionOperationIDs);
    const validationIDs = new Set(lastValidation.operationIDs || []);
    if (lastValidation.status !== "validated"
      || !lastValidation.sourceUnchanged
      || !lastValidation.outputReopenable
      || lastValidation.sourceDigest !== sourceDigest
      || !completionIDs.size
      || currentIDs.size !== validationIDs.size
      || [...currentIDs].some((id) => !validationIDs.has(id))
      || currentIDs.size !== completionIDs.size
      || [...currentIDs].some((id) => !completionIDs.has(id))
      || (lastValidation.checks || []).some((check) => ["unknown", "failed"].includes(check.status))) return;
    const event = createLearningEvent({
      template: templateContract,
      proposal: lastAppliedTemplateProposal,
      kind: "completionValidated",
      note: "Strict export validation completed after two-stage reviewed completion."
    });
    if (!canPromoteTemplateRevision({
      template: templateContract,
      sourceDigest,
      validation: lastValidation,
      events: [event]
    })) return;
    try {
      pendingValidatedTemplateRevision = makeValidatedTemplateRevision({
        template: templateContract,
        sourceDigest,
        sessionID: lastAppliedTemplateProposal.sessionID
      });
      templateLearningEvents = [event];
      templateRevisionDiff = diffTemplateRevisions(templateContract, pendingValidatedTemplateRevision);
      setStatus("Validated export is ready. Save the proposed child revision explicitly to remember this reviewed completion.");
    } catch (error) {
      setStatus(`Validated completion could not create a child revision: ${error.message || "unknown error"}.`, "danger");
    }
  }

  function activateReviewedTemplate() {
    if (!templateContract) return;
    const mappings = templateContract.payload.mappings || [];
    const reviewedMappingIDs = mappings
      .filter((mapping) => mapping.status === "confirmed" || mapping.status === "rejected")
      .map((mapping) => mapping.id);
    const approvedMappingIDs = mappings
      .filter((mapping) => mapping.status === "confirmed")
      .map((mapping) => mapping.id);
    try {
      const activeRevision = activateTemplateRevision({
        draft: templateContract,
        approvedMappingIDs,
        reviewedMappingIDs,
        sessionID: makeID("template-review")
      });
      templateRevisionHistory = appendTemplateRevision(
        templateRevisionHistory || { templateID: templateContract.payload.templateID, revisions: [templateContract] },
        activeRevision
      );
      templateContract = activeRevision;
      validateTemplateContract(templateContract);
    } catch (error) {
      setStatus(error.message || "The template review is incomplete.", "danger");
      return;
    }
    setStatus(`Activated a reviewed template with ${approvedMappingIDs.length} mapping(s). Values remain session-only until reviewed.`);
    renderCompletionPanel();
  }

  function prepareTemplateCompletion() {
    if (!templateContract || templateContract.payload.lifecycle !== "active") return;
    const approvedMappings = templateContract.payload.mappings.filter((mapping) => mapping.status === "confirmed");
    const profileID = currentProfile?.profileID || makeID("session-profile");
    const revisionID = currentProfile?.__profileRevisionID || makeID("session-profile-revision");
    const profileValues = approvedMappings
      .map((mapping) => ({
        id: makeID("profile-value"),
        semanticKey: mapping.semanticKey,
        value: { kind: "text", text: currentProfile ? profileGetValue(currentProfile, mapping.semanticKey) : templateValueDrafts[mapping.id] || "" }
      }))
      .filter((entry) => entry.value.text);
    const profile = {
      header: { contractName: "pdf-editor.profile", version: { major: 1, minor: 0 }, profileID, revisionID, generatedAt: new Date().toISOString(), provider: providerDescriptor() },
      payload: { profileID, revisionID, displayName: currentProfile?.displayName || "Session values", revisionNumber: currentProfile?.__profileRevisionNumber || 0, storageScope: currentProfile ? "deviceLocal" : "deviceLocal", requiresUnlock: Boolean(currentProfile), values: profileValues }
    };
    const match = matchTemplate({ template: templateContract, fingerprint: templateFingerprint, sourceDigest });
    templateProposal = createCompletionProposal({ template: templateContract, match, profile, sessionID: makeID("completion") });
    lastAppliedTemplateProposal = null;
    templateCompletionOperationIDs = [];
    pendingValidatedTemplateRevision = null;
    templateLearningEvents = [];
    templateRevisionDiff = null;
    for (const entry of templateProposal?.entries || []) {
      if (entry.target.kind !== "nativeField") continue;
      const field = nativeFields.find((candidate) => candidate.pageIndex === entry.target.pageIndex
        && candidate.coordinate?.rect?.x === entry.target.region?.rect?.x
        && candidate.coordinate?.rect?.y === entry.target.region?.rect?.y);
      if (field) templateProposal = resolveCompletionTarget(templateProposal, entry.mappingID, field.name);
    }
    setStatus("Review every template mapping and value before queuing completion operations.");
    renderCompletionPanel();
  }

  function renderTemplateReview() {
    if (!ui.templateCard) return;
    if (!pdfDoc || !documentContract) {
      setHidden(ui.templateCard, true);
      return;
    }
    setHidden(ui.templateCard, false);
    ui.templateMappingList.innerHTML = "";
    ui.templateCompletionList.innerHTML = "";
    ui.captureTemplateButton.disabled = false;
    ui.saveTemplateButton.disabled = !templateContract;
    ui.saveTemplateButton.textContent = canSaveValidatedTemplateRevision()
      ? "Save validated template revision"
      : "Persist encrypted working capture";
    ui.exportTemplateButton.disabled = !templateContract;
    ui.exportTemplateSyncButton.disabled = !templateContract || !templateRevisionHistory;
    ui.activateTemplateButton.disabled = true;
    ui.prepareTemplateButton.disabled = true;
    ui.applyTemplateButton.disabled = true;
    if (!templateContract) {
      ui.templateSummary.textContent = "No template captured. Capture the current layout to create review-only mapping proposals.";
      return;
    }
    const mappings = templateContract.payload.mappings || [];
    const promotionState = canSaveValidatedTemplateRevision()
      ? " · validated child revision ready to save"
      : pendingValidatedTemplateRevision
        ? " · pending revision withdrawn until the ledger is unchanged"
        : "";
    const diffState = templateRevisionDiff
      ? ` · diff +${templateRevisionDiff.mappingChanges.filter((change) => change.change === "added").length}`
        + ` / -${templateRevisionDiff.mappingChanges.filter((change) => change.change === "removed").length}`
        + ` / ~${templateRevisionDiff.mappingChanges.filter((change) => change.change === "changed").length}`
        + ` mappings, +${templateRevisionDiff.exactSourceDigestsAdded.length}`
        + ` / -${templateRevisionDiff.exactSourceDigestsRemoved.length} source variant(s)`
      : "";
    ui.templateSummary.textContent = `${templateContract.payload.lifecycle} revision · ${mappings.length} mapping(s) · source-bound ${sourceDigest.slice(0, 12)}...${diffState}${promotionState}`;
    mappings.forEach((mapping) => {
      const row = document.createElement("div");
      row.className = "template-mapping";
      const label = document.createElement("label");
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = mapping.status === "confirmed";
      checkbox.disabled = templateContract.payload.lifecycle === "active";
      checkbox.addEventListener("change", () => {
        updateTemplateMapping(mapping.id, { status: checkbox.checked ? "confirmed" : "rejected" });
        renderTemplateReview();
      });
      label.append(checkbox, ` Approve ${mapping.target.kind} on page ${mapping.target.pageIndex + 1}`);
      const semantic = document.createElement("input");
      semantic.type = "text";
      semantic.value = mapping.semanticKey;
      semantic.disabled = templateContract.payload.lifecycle === "active";
      semantic.setAttribute("aria-label", `Semantic key for mapping ${mapping.id}`);
      semantic.addEventListener("change", () => updateTemplateMapping(mapping.id, { semanticKey: semantic.value.trim() || mapping.semanticKey }));
      row.append(label, semantic);
      ui.templateMappingList.appendChild(row);
    });
    if (templateContract.payload.lifecycle === "draft") {
      const everyMappingReviewed = mappings.every((mapping) => mapping.status === "confirmed" || mapping.status === "rejected");
      ui.activateTemplateButton.disabled = !everyMappingReviewed || !mappings.some((mapping) => mapping.status === "confirmed");
      return;
    }
    ui.prepareTemplateButton.disabled = false;
    mappings.filter((mapping) => mapping.status === "confirmed").forEach((mapping) => {
      const row = document.createElement("div");
      row.className = "template-mapping";
      const label = document.createElement("label");
      label.textContent = `Current value for ${mapping.semanticKey}`;
      const value = document.createElement("input");
      value.type = "text";
      value.placeholder = "Value remains session-only until export";
      value.value = templateValueDrafts[mapping.id] || "";
      value.addEventListener("input", () => { templateValueDrafts[mapping.id] = value.value; });
      row.append(label, value);
      ui.templateCompletionList.appendChild(row);
    });
    if (!templateProposal) return;
    ui.templateCompletionList.appendChild(document.createElement("hr"));
    templateProposal.entries.forEach((entry) => {
      const row = document.createElement("div");
      row.className = "template-mapping";
      const mappingReview = document.createElement("input");
      mappingReview.type = "checkbox";
      mappingReview.checked = entry.mappingReview === "approved";
      mappingReview.addEventListener("change", () => {
        templateProposal = reviewCompletionMapping(templateProposal, entry.mappingID, mappingReview.checked);
        renderTemplateReview();
      });
      const mappingLabel = document.createElement("label");
      mappingLabel.append(mappingReview, ` Approve mapping ${entry.semanticKey}`);
      const value = document.createElement("input");
      value.type = "text";
      value.value = entry.value?.text || "";
      value.addEventListener("input", () => {
        templateProposal = reviewCompletionValue(templateProposal, entry.mappingID, { kind: "text", text: value.value }, false);
        ui.applyTemplateButton.disabled = true;
      });
      const valueReview = document.createElement("input");
      valueReview.type = "checkbox";
      valueReview.checked = entry.valueReview === "approved";
      valueReview.addEventListener("change", () => {
        templateProposal = reviewCompletionValue(templateProposal, entry.mappingID, { kind: "text", text: value.value }, valueReview.checked);
        renderTemplateReview();
      });
      const valueLabel = document.createElement("label");
      valueLabel.append(valueReview, " Approve exact profile value");
      row.append(mappingLabel, value, valueLabel);
      ui.templateCompletionList.appendChild(row);
    });
    ui.applyTemplateButton.disabled = !canMaterializeCompletion({ proposal: templateProposal, currentSourceDigest: sourceDigest }).ok;
  }

  function applyTemplateCompletion() {
    if (!templateProposal) return;
    const gate = canMaterializeCompletion({ proposal: templateProposal, currentSourceDigest: sourceDigest });
    if (!gate.ok) {
      setStatus(`Template completion blocked: ${gate.code}.`, "danger");
      return;
    }
    try {
      operations.push(...materializeCompletionOperations({ proposal: templateProposal, currentSourceDigest: sourceDigest }));
      lastAppliedTemplateProposal = templateProposal;
      templateCompletionOperationIDs = operations.slice(-templateProposal.entries.length).map((operation) => operation.id);
      pendingValidatedTemplateRevision = null;
      templateLearningEvents = [];
      templateRevisionDiff = null;
      templateProposal = null;
      setStatus("Queued reviewed template operations. The source remains unchanged until export and strict validation.");
      renderCompletionPanel();
      renderVisiblePages();
      saveWebSession();
    } catch (error) {
      displayReaderError(error);
    }
  }

  function renderProfilePanel() {
    const panel = document.getElementById("profilePanel");
    if (!panel) return;
    panel.innerHTML = "";

    if (currentProfile) {
      // Active profile
      const header = document.createElement("div");
      header.style.cssText = "display:flex;align-items:center;gap:8px;margin-bottom:8px;";
      header.innerHTML = `<strong style="font-size:13px;">${currentProfile.displayName}</strong>`;
      const switchBtn = document.createElement("button");
      switchBtn.textContent = "Switch";
      switchBtn.style.cssText = "font-size:11px;margin-left:auto;";
      switchBtn.onclick = () => { currentProfile = null; renderProfilePanel(); };
      header.appendChild(switchBtn);
      panel.appendChild(header);

      // Profile fields
      for (const sk of STANDARD_KEYS) {
        const val = profileGetValue(currentProfile, sk.key);
        const row = document.createElement("div");
        row.style.cssText = "display:flex;gap:4px;align-items:center;margin:2px 0;";
        const label = document.createElement("span");
        label.textContent = sk.label;
        label.style.cssText = "width:80px;text-align:right;font-size:11px;color:#64748b;flex-shrink:0;";
        const input = document.createElement("input");
        input.type = "text";
        input.value = val;
        input.placeholder = "—";
        input.style.cssText = "flex:1;font-size:11px;padding:2px 4px;border:1px solid #d1d5db;border-radius:4px;";
        input.onchange = () => {
          profileSetValue(currentProfile, sk.key, input.value);
          saveProfile(currentProfile);
        };
        row.appendChild(label);
        row.appendChild(input);
        panel.appendChild(row);
      }

      // Bulk fill buttons
      const actions = document.createElement("div");
      actions.style.cssText = "display:flex;gap:6px;margin-top:8px;flex-wrap:wrap;";
      const previewBtn = document.createElement("button");
      previewBtn.textContent = "Preview Fill";
      previewBtn.className = "primary";
      previewBtn.onclick = () => {
        const result = matchProfileToFields(currentProfile, nativeFields, candidates);
        if (result.totalMatches > 0) {
          // Apply matched operations
          for (const op of result.operations) {
            operations.push(op);
            if (op.candidateID) {
              reviews.push({
                id: makeID("review"), candidateID: op.candidateID, kind: "confirmed",
                region: op.coordinate, fieldType: "text",
                note: "Confirmed by profile bulk fill.", createdAt: new Date().toISOString()
              });
              candidates = candidates.map(c => c.id === op.candidateID ? { ...c, status: "confirmed" } : c);
            }
          }
          renderCompletionPanel();
          renderVisiblePages();
          saveWebSession();
          setStatus(`Applied ${result.totalMatches} profile field(s). ${result.unmatched.length} unmatched.`);
        } else {
          setStatus("No profile values matched this document's fields.");
        }
      };
      actions.appendChild(previewBtn);

      const saveBtn = document.createElement("button");
      saveBtn.textContent = "Save";
      saveBtn.onclick = () => { saveProfile(currentProfile); setStatus("Profile saved."); };
      actions.appendChild(saveBtn);
      panel.appendChild(actions);

    } else {
      // No profile — show list or create
      const info = document.createElement("div");
      info.className = "small muted";
      info.textContent = "Select or create a profile to enable bulk fill.";
      panel.appendChild(info);

      const unlockButton = document.createElement("button");
      unlockButton.type = "button";
      unlockButton.textContent = "Unlock encrypted local profiles";
      unlockButton.onclick = async () => {
        try {
          await unlockEncryptedProfileVault();
          renderProfilePanel();
        } catch (error) {
          setStatus(`Profile vault unlock failed: ${error.message || "unknown error"}.`, "danger");
        }
      };
      panel.appendChild(unlockButton);

      // Load profiles list
      listProfiles().then(profiles => {
        for (const p of profiles) {
          const row = document.createElement("div");
          row.style.cssText = "display:flex;align-items:center;gap:6px;padding:4px 0;border-top:1px solid #e5e7eb;";
          const btn = document.createElement("button");
          btn.textContent = p.displayName;
          btn.style.cssText = "flex:1;text-align:left;font-size:12px;";
          btn.onclick = () => { currentProfile = p; renderProfilePanel(); };
          row.appendChild(btn);
          panel.appendChild(row);
        }
      });

      // Create new profile
      const createRow = document.createElement("div");
      createRow.style.cssText = "margin-top:6px;display:flex;gap:4px;";
      const nameInput = document.createElement("input");
      nameInput.type = "text";
      nameInput.placeholder = "Profile name";
      nameInput.style.cssText = "flex:1;font-size:12px;padding:4px;border:1px solid #d1d5db;border-radius:4px;";
      const createBtn = document.createElement("button");
      createBtn.textContent = "Create";
      createBtn.className = "primary";
      createBtn.style.cssText = "font-size:12px;";
      createBtn.onclick = async () => {
        const name = nameInput.value.trim();
        if (!name) return;
        const newProfile = {
          profileID: makeID("profile"),
          displayName: name,
          values: STANDARD_KEYS.map(sk => ({ semanticKey: sk.key, textValue: "", label: sk.label, category: "general" })),
          createdAt: new Date().toISOString(),
          lastModifiedAt: new Date().toISOString()
        };
        const saved = await saveProfile(newProfile);
        if (!saved) return;
        currentProfile = newProfile;
        nameInput.value = "";
        renderProfilePanel();
        setStatus(`Created profile ${name}.`);
      };
      createRow.appendChild(nameInput);
      createRow.appendChild(createBtn);
      panel.appendChild(createRow);
    }
  }

  function renderCompletionPanel() {
    if (!ui.completionSource) { return; }
    if (!pdfDoc || !documentContract) {
      ui.completionSource.textContent = "Load a PDF to inspect fields and blank-region candidates.";
      ui.fieldList.innerHTML = "";
      ui.candidateList.innerHTML = "";
      ui.editList.innerHTML = "";
      ui.validationBox.textContent = "No export validation yet.";
      renderImpactMetrics(null);
      setHidden(ui.candidateAction, true);
      setHidden(ui.manualAction, true);
      ui.applyFieldButton.disabled = true;
      ui.applyOverlayButton.disabled = true;
      ui.synthesizeFieldButton.disabled = true;
      ui.completionValue.disabled = true;
      setHidden(ui.fieldControl, true);
      setHidden(ui.choiceCellControl, true);
      setHidden(ui.choiceCellSelect, true);
      ui.undoEditButton.disabled = true;
      ui.exportButton.disabled = true;
      renderTemplateReview();
      return;
    }

    const payload = documentContract.payload;
    ui.completionSource.textContent = `${sourceName} | ${payload.pages.length} page(s) | ${nativeFields.length} native field(s) | ${activeCandidates().length} suggested area(s) | SHA-256 ${sourceDigest.slice(0, 16)}...`;
    renderProfilePanel();
    ui.fieldList.innerHTML = "";
    if (!nativeFields.length) {
      const empty = document.createElement("div");
      empty.className = "small muted";
      empty.textContent = "No AcroForm widgets detected.";
      ui.fieldList.appendChild(empty);
    } else {
      nativeFields.forEach((field) => {
        const row = document.createElement("div");
        row.className = "completion-item";
        if (selectedField?.id === field.id) { row.style.background = "#dbeafe"; }
        const detail = document.createElement("div");
        detail.className = "small";
        detail.textContent = `p${field.pageIndex + 1} ${field.kind}: ${field.name}`;
        const value = document.createElement("div");
        value.className = "small muted";
        value.textContent = `Current value: ${field.value || "empty"}${field.choices.length ? ` | choices: ${field.choices.join(", ")}` : ""}`;
        const button = document.createElement("button");
        button.type = "button";
        button.textContent = "Select field";
        button.addEventListener("click", () => {
          selectedField = field;
          selectedCandidate = null;
          selectedOperation = null;
          manualPlacement = null;
          ui.completionValue.value = field.value || "";
          ui.completionValue.disabled = false;
          currentPage = field.pageIndex + 1;
          renderCompletionPanel();
          renderVisiblePages();
        });
        row.append(detail, value, button);
        ui.fieldList.appendChild(row);
      });
    }

    renderNativeFieldControl();

    ui.candidateList.innerHTML = "";
    const visibleCandidates = showDismissedCandidates
      ? candidates
      : candidates.filter((candidate) => candidate.status !== "rejected");
    if (!visibleCandidates.length) {
      const empty = document.createElement("div");
      empty.className = "small muted";
      empty.textContent = showDismissedCandidates ? "No dismissed suggestions." : "No active suggestions. Use Add text to place one manually.";
      ui.candidateList.appendChild(empty);
    } else {
      visibleCandidates.forEach((candidate) => {
        const row = document.createElement("div");
        row.className = "completion-item";
        if (selectedCandidate?.id === candidate.id) { row.style.background = "#e7f0ff"; }
        if (candidate.status === "rejected") { row.style.opacity = "0.65"; }
        const detail = document.createElement("div");
        detail.className = "small";
        const evidenceText = candidate.evidenceItems?.[0]?.text || "document structure";
        detail.textContent = `Page ${candidate.pageIndex + 1} · ${candidateEntryLabel(candidate)} · ${evidenceText}`;
        const score = document.createElement("div");
        score.className = "small candidate-score";
        score.textContent = candidate.status === "rejected" ? "Dismissed" : confidenceLabel(candidate.score);
        const button = document.createElement("button");
        button.type = "button";
        button.textContent = candidate.status === "rejected" ? "Restore" : "Review candidate";
        button.addEventListener("click", () => {
          if (candidate.status === "rejected") {
            candidates = candidates.map((entry) => entry.id === candidate.id ? { ...entry, status: "suggested" } : entry);
            showDismissedCandidates = false;
            setStatus("Restored the suggested area for review.");
          } else {
            selectedCandidate = candidate;
            selectedField = null;
            selectedOperation = null;
            manualPlacement = null;
            currentPage = candidate.pageIndex + 1;
            ui.completionValue.value = "";
            ui.completionValue.disabled = false;
            setStatus("Review the highlighted area, then add text or dismiss it.");
          }
          renderCompletionPanel();
          renderVisiblePages();
        });
        row.append(detail, score, button);
        ui.candidateList.appendChild(row);
      });
    }

    const isChoiceCandidate = selectedCandidate && ["checkbox", "radioGroup"].includes(candidateEntryMode(selectedCandidate));
    ui.applyFieldButton.disabled = true;
    if (isChoiceCandidate) {
      ui.choiceCellSelect.innerHTML = "";
      (selectedCandidate.memberBounds || []).forEach((_, index) => {
        const option = document.createElement("option");
        option.value = String(index);
        option.textContent = `Option ${index + 1}`;
        ui.choiceCellSelect.appendChild(option);
      });
      setHidden(ui.choiceCellControl, false);
      setHidden(ui.choiceCellSelect, false);
      ui.applyOverlayButton.disabled = !(selectedCandidate.memberBounds || []).length;
      ui.applyOverlayButton.textContent = "Mark selected box";
    } else {
      setHidden(ui.choiceCellControl, true);
      setHidden(ui.choiceCellSelect, true);
      ui.applyFieldButton.disabled = !selectedField || (!ui.completionValue.value && selectedField.kind !== "button");
      ui.applyOverlayButton.disabled = !(selectedCandidate || manualPlacement || selectedOperation)
        || !ui.completionValue.value
        || (selectedCandidate && !candidateIsDirectlyEditable(selectedCandidate));
      ui.applyOverlayButton.textContent = selectedOperation ? "Update text" : "Add text here";
    }
    ui.dismissCandidateButton.disabled = !selectedCandidate;
    ui.synthesizeFieldButton.disabled = !selectedCandidate || !candidateIsDirectlyEditable(selectedCandidate);
    setHidden(ui.candidateAction, !selectedCandidate && !manualPlacement && !selectedOperation);
    setHidden(ui.manualAction, !manualPlacementMode);
    if (selectedCandidate) {
      const evidenceText = selectedCandidate.evidenceItems?.[0]?.text || "document structure";
      const editability = candidateIsDirectlyEditable(selectedCandidate)
        ? "Adding text creates a reversible overlay."
        : "This pattern is reviewable. Choose a detected box to place a reversible mark, or dismiss it.";
      ui.candidateActionDetail.textContent = `Page ${selectedCandidate.pageIndex + 1} · ${confidenceLabel(selectedCandidate.score)} · ${candidateEntryLabel(selectedCandidate)}. ${evidenceText} ${editability}`;
    } else if (manualPlacement) {
      ui.candidateActionDetail.textContent = `Manual text area on page ${manualPlacement.pageIndex + 1}. This is a reversible overlay placed by you.`;
    } else if (selectedOperation) {
      ui.candidateActionDetail.textContent = `Pending ${selectedOperation.kind === "nativeFieldValue" ? "native field value" : "text overlay"} on page ${selectedOperation.pageIndex + 1}.`;
    }
    ui.restoreDismissedButton.textContent = `Show dismissed (${candidates.filter((candidate) => candidate.status === "rejected").length})`;
    setHidden(ui.restoreDismissedButton, !candidates.some((candidate) => candidate.status === "rejected"));
    ui.completionValue.disabled = !selectedField && !selectedCandidate && !manualPlacement && !selectedOperation;
    ui.undoEditButton.disabled = operations.length === 0;
    ui.exportButton.disabled = !pdfData;
    ui.editList.innerHTML = "";
    if (!operations.length) {
      ui.editList.textContent = "No pending edits.";
    } else {
      operations.forEach((operation, index) => {
        const row = document.createElement("div");
        row.className = "completion-item";
        row.textContent = `${index + 1}. ${operation.kind} on p${operation.pageIndex + 1}: ${operation.value || "(empty)"}`;
        ui.editList.appendChild(row);
      });
    }

    if (lastValidation) {
      ui.validationBox.innerHTML = "";
      const heading = document.createElement("div");
      heading.className = lastValidation.status === "failed" ? "danger" : "success";
      heading.textContent = `Last export: ${lastValidation.status}`;
      ui.validationBox.appendChild(heading);
      for (const check of lastValidation.checks) {
        const row = document.createElement("div");
        row.className = "item small";
        row.textContent = `${check.status}: ${check.kind} | ${check.message}`;
        ui.validationBox.appendChild(row);
      }
    } else {
      ui.validationBox.textContent = "No export validation yet.";
    }
    renderImpactMetrics(lastValidation);
    renderTemplateReview();
  }

  function makeOperation({ pageIndex, targetID = null, kind, value, bounds = null, candidateID = null, previousValue = null, payload = null, coordinate = null }) {
    return {
      id: makeID("operation"),
      pageIndex,
      targetID,
      kind,
      value,
      bounds,
      candidateID,
      previousValue,
      createdAt: new Date().toISOString(),
      sessionID: null,
      parentOperationID: operations.at(-1)?.id || null,
      sourceDigest,
      coordinate,
      payload,
      reversible: true,
      destructive: false
    };
  }

  function applyNativeFieldOperation() {
    if (!selectedField) {
      setStatus("Select a native field first.", "danger");
      return;
    }
    const value = ui.completionValue.value;
    if (!value && selectedField.kind !== "button") {
      setStatus("Enter a value before applying the field edit.", "danger");
      return;
    }
    const buttonOptions = selectedField.kind === "button" ? nativeButtonOptions(selectedField) : [];
    const operation = makeOperation({
      pageIndex: selectedField.pageIndex,
      targetID: selectedField.name,
      kind: "nativeFieldValue",
      value,
      bounds: selectedField.bounds,
      previousValue: selectedField.value || null,
      payload: selectedField.kind !== "button"
        ? { kind: selectedField.kind, value }
        : buttonOptions.length > 1
          ? { kind: "radio", value, options: buttonOptions }
          : { kind: "boolean", value },
      coordinate: selectedField.coordinate
    });
    operations.push(operation);
    selectedField.value = value;
    nativeFields = nativeFields.map((field) => field.id === selectedField.id ? { ...field, value } : field);
    setStatus(`Queued native field fill for ${selectedField.name}.`);
    renderCompletionPanel();
    renderVisiblePages();
    saveWebSession();
  }

  function synthesizeNativeField() {
    if (!selectedCandidate || !candidateIsDirectlyEditable(selectedCandidate)) {
      setStatus("Only reviewed text-like regions can become native fields.", "danger");
      return;
    }
    const targetID = `static_${selectedCandidate.id.replace(/[^a-zA-Z0-9_]/g, "_")}`;
    const operation = makeOperation({
      pageIndex: selectedCandidate.pageIndex,
      targetID,
      kind: "synthesizeNativeField",
      value: "",
      bounds: selectedCandidate.bounds,
      candidateID: selectedCandidate.id,
      payload: { kind: "nativeField", fieldType: selectedCandidate.suggestedFieldType || "text" },
      coordinate: selectedCandidate.coordinate
    });
    operations.push(operation);
    reviews.push({
      id: makeID("review"),
      candidateID: selectedCandidate.id,
      kind: "confirmed",
      region: selectedCandidate.coordinate,
      fieldType: selectedCandidate.suggestedFieldType || "text",
      note: "Confirmed by the user before native-field synthesis.",
      createdAt: new Date().toISOString()
    });
    candidates = candidates.map((candidate) => candidate.id === selectedCandidate.id ? { ...candidate, status: "confirmed" } : candidate);
    selectedCandidate = { ...selectedCandidate, status: "confirmed" };
    setStatus("Queued a native text field for the reviewed region. The static page remains preserved until export.");
    renderCompletionPanel();
    renderVisiblePages();
    saveWebSession();
  }

  function applyOverlayOperation() {
    if (selectedCandidate && ["checkbox", "radioGroup"].includes(candidateEntryMode(selectedCandidate))) {
      const index = Number.parseInt(ui.choiceCellSelect.value || "0", 10);
      const cell = selectedCandidate.memberBounds?.[index];
      if (!cell) {
        setStatus("Choose a detected choice cell before marking it.", "danger");
        return;
      }
      const operation = makeOperation({
        pageIndex: selectedCandidate.pageIndex,
        kind: "overlayText",
        value: "X",
        bounds: cell,
        candidateID: selectedCandidate.id,
        payload: { kind: "choiceMark", cell },
        coordinate: coordinateFor(selectedCandidate.pageIndex, cell, rotation)
      });
      operations.push(operation);
      reviews.push({
        id: makeID("review"),
        candidateID: selectedCandidate.id,
        kind: "confirmed",
        region: selectedCandidate.coordinate,
        fieldType: selectedCandidate.suggestedFieldType || "checkbox",
        note: "Confirmed by the user before placing a static choice mark.",
        createdAt: new Date().toISOString()
      });
      candidates = candidates.map((candidate) => candidate.id === selectedCandidate.id ? { ...candidate, status: "confirmed" } : candidate);
      selectedCandidate = { ...selectedCandidate, status: "confirmed" };
      setStatus("Marked the selected static choice cell. The mark remains reversible until export.");
      renderCompletionPanel();
      renderVisiblePages();
      saveWebSession();
      return;
    }
    const value = ui.completionValue.value.trim();
    if (!value) {
      setStatus("Enter a value before applying the overlay.", "danger");
      return;
    }
    if (selectedOperation) {
      selectedOperation.value = value;
      selectedOperation.payload = selectedOperation.payload?.kind === "characterGrid"
        ? { kind: "characterGrid", value, cells: selectedOperation.payload.cells || [] }
        : { kind: "text", value };
      selectedOperation.coordinate = coordinateFor(selectedOperation.pageIndex, selectedOperation.bounds, rotation);
      selectedOperation = null;
      ui.completionValue.value = "";
      setStatus("Updated the text overlay. It remains reversible until export.");
      renderCompletionPanel();
      renderVisiblePages();
      return;
    }
    const reviewTarget = selectedCandidate || (manualPlacement ? {
      id: null,
      pageIndex: manualPlacement.pageIndex,
      bounds: manualPlacement.bounds,
      coordinate: manualPlacement.coordinate,
      suggestedFieldType: "text"
    } : null);
    if (!reviewTarget) {
      setStatus("Select a suggested area or click Add text to place one manually.", "danger");
      return;
    }
    const candidateCells = selectedCandidate?.entryMode === "characterGrid"
      ? (selectedCandidate.memberBounds || [])
      : [];
    if (selectedCandidate?.entryMode === "characterGrid") {
      if (!candidateCells.length) {
        setStatus("This character grid has no cell geometry. Use manual placement or rerun inspection.", "danger");
        return;
      }
      if ([...value].length > candidateCells.length) {
        setStatus(`The value is longer than the detected character grid (${candidateCells.length} cells).`, "danger");
        return;
      }
    }
    const payload = candidateCells.length
      ? { kind: "characterGrid", value, cells: candidateCells }
      : { kind: "text", value };
    const operation = makeOperation({
      pageIndex: reviewTarget.pageIndex,
      kind: "overlayText",
      value,
      bounds: reviewTarget.bounds,
      candidateID: reviewTarget.id,
      payload,
      coordinate: reviewTarget.coordinate
    });
    operations.push(operation);
    if (selectedCandidate) {
      reviews.push({
        id: makeID("review"),
        candidateID: selectedCandidate.id,
        kind: "confirmed",
        region: selectedCandidate.coordinate,
        fieldType: selectedCandidate.suggestedFieldType || "text",
        note: "Confirmed by the user before overlay export.",
        createdAt: new Date().toISOString()
      });
      candidates = candidates.map((candidate) => candidate.id === selectedCandidate.id ? { ...candidate, status: "confirmed" } : candidate);
      selectedCandidate = { ...selectedCandidate, status: "confirmed" };
    }
    manualPlacement = null;
    manualPlacementMode = false;
    ui.completionValue.value = "";
    setStatus(candidateCells.length
      ? "Placed one character per detected cell. The edit remains reversible until export."
      : "Added reversible text. The source page remains unchanged until export.");
    renderCompletionPanel();
    renderVisiblePages();
    saveWebSession();
  }

  function dismissSelectedCandidate() {
    if (!selectedCandidate) { return; }
    reviews.push({
      id: makeID("review"),
      candidateID: selectedCandidate.id,
      kind: "rejected",
      region: selectedCandidate.coordinate,
      fieldType: selectedCandidate.suggestedFieldType || "text",
      note: "Dismissed by the user; no PDF mutation was performed.",
      createdAt: new Date().toISOString()
    });
    candidates = candidates.map((candidate) => candidate.id === selectedCandidate.id ? { ...candidate, status: "rejected" } : candidate);
    selectedCandidate = null;
    ui.completionValue.value = "";
    setStatus("Dismissed the suggested area. The source PDF was not changed.");
    renderCompletionPanel();
    renderVisiblePages();
  }

  function undoLastOperation() {
    const operation = operations.pop();
    if (!operation) { return; }
    if (operation.candidateID) {
      const reviewIndex = reviews.findLastIndex((review) => review.candidateID === operation.candidateID);
      if (reviewIndex >= 0) { reviews.splice(reviewIndex, 1); }
      candidates = candidates.map((candidate) => candidate.id === operation.candidateID ? { ...candidate, status: "suggested" } : candidate);
      selectedCandidate = candidates.find((candidate) => candidate.id === operation.candidateID) || null;
    }
    if (operation.kind === "nativeFieldValue" && operation.targetID) {
      nativeFields = nativeFields.map((field) => field.name === operation.targetID ? { ...field, value: operation.previousValue || "" } : field);
    }
    if (selectedOperation?.id === operation.id) { selectedOperation = null; }
    setStatus("Removed the last pending edit.");
    renderCompletionPanel();
    renderVisiblePages();
    saveWebSession();
  }

  function renderCandidatePreviews(pageNum, viewport, shell) {
    candidates.filter((candidate) => candidate.pageIndex === pageNum - 1 && candidate.status !== "rejected").forEach((candidate) => {
      const bounds = candidate.bounds;
      const viewportRect = viewport.convertToViewportRectangle([bounds.x, bounds.y, bounds.x + bounds.width, bounds.y + bounds.height]);
      const rect = normalizeRect(viewportRect);
      const preview = document.createElement("div");
      const isGrid = candidateEntryMode(candidate) === "characterGrid";
      const selected = selectedCandidate?.id === candidate.id;
      // Character-grid candidates are rendered as a transparent union outline
      // plus per-cell tints. The previous behavior painted a single solid
      // block at 25% opacity that visually obscured the underlying PDF
      // text and extended across the gaps between cells.
      preview.className = `candidate-preview${isGrid ? " character-grid" : ""}${selected ? " selected" : ""}`;
      preview.style.left = `${rect.x}px`;
      preview.style.top = `${rect.y}px`;
      preview.style.width = `${Math.max(24, rect.width)}px`;
      preview.style.height = `${Math.max(14, rect.height)}px`;
      preview.textContent = isGrid ? "" : `${candidateEntryMode(candidate)} · ${Math.round(candidate.score * 100)}%`;
      preview.title = "Select suggested area for review";
      preview.tabIndex = 0;
      const select = () => {
        selectedCandidate = candidate;
        selectedField = null;
        selectedOperation = null;
        manualPlacement = null;
        currentPage = pageNum;
        ui.completionValue.value = "";
        ui.completionValue.disabled = false;
        setStatus("Review the highlighted area, then add text or dismiss it.");
        renderCompletionPanel();
        renderVisiblePages();
      };
      preview.addEventListener("click", (event) => {
        event.stopPropagation();
        select();
      });
      preview.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          select();
        }
      });
      shell.appendChild(preview);
      if (isGrid && Array.isArray(candidate.memberBounds)) {
        for (const cell of candidate.memberBounds) {
          const cellViewportRect = viewport.convertToViewportRectangle([cell.x, cell.y, cell.x + cell.width, cell.y + cell.height]);
          const cellRect = normalizeRect(cellViewportRect);
          const tint = document.createElement("div");
          tint.className = `candidate-cell-tint${selected ? " selected" : ""}`;
          tint.style.left = `${cellRect.x}px`;
          tint.style.top = `${cellRect.y}px`;
          tint.style.width = `${Math.max(2, cellRect.width)}px`;
          tint.style.height = `${Math.max(2, cellRect.height)}px`;
          shell.appendChild(tint);
        }
      }
    });
  }

  function renderOperationPreviews(pageNum, viewport, shell) {
    operations.filter((operation) => operation.pageIndex === pageNum - 1 && operation.bounds).forEach((operation) => {
      if (operation.payload?.kind === "characterGrid" && Array.isArray(operation.payload.cells)) {
        [...operation.value].forEach((character, index) => {
          const cell = operation.payload.cells[index];
          if (!cell) { return; }
          const viewportRect = viewport.convertToViewportRectangle([cell.x, cell.y, cell.x + cell.width, cell.y + cell.height]);
          const rect = normalizeRect(viewportRect);
          const preview = document.createElement("div");
          preview.className = "overlay-preview";
          preview.style.left = `${rect.x}px`;
          preview.style.top = `${rect.y}px`;
          preview.style.width = `${Math.max(8, rect.width)}px`;
          preview.style.height = `${Math.max(8, rect.height)}px`;
          preview.style.background = "rgba(219, 234, 254, 0.30)";
          preview.style.border = "1px solid rgba(37, 99, 235, 0.55)";
          preview.style.color = "#0f172a";
          preview.style.fontWeight = "600";
          preview.style.padding = "0";
          preview.style.textAlign = "center";
          preview.textContent = character;
          preview.title = "Character-grid cell preview";
          shell.appendChild(preview);
        });
        return;
      }
      const bounds = operation.bounds;
      const viewportRect = viewport.convertToViewportRectangle([bounds.x, bounds.y, bounds.x + bounds.width, bounds.y + bounds.height]);
      const rect = normalizeRect(viewportRect);
      const preview = document.createElement("div");
      preview.className = "overlay-preview";
      preview.style.left = `${rect.x}px`;
      preview.style.top = `${rect.y}px`;
      preview.style.width = `${Math.max(8, rect.width)}px`;
      preview.style.height = `${Math.max(8, rect.height)}px`;
      preview.style.background = "rgba(219, 234, 254, 0.30)";
      preview.style.border = "1px solid rgba(37, 99, 235, 0.55)";
      preview.style.color = "#0f172a";
      preview.style.fontWeight = "600";
      preview.textContent = operation.value;
      preview.title = operation.kind === "overlayText" ? "Click to edit this pending text" : "Native field preview";
      if (operation.kind === "overlayText") {
        preview.addEventListener("click", (event) => {
          event.stopPropagation();
          selectedOperation = operation;
          selectedCandidate = null;
          selectedField = null;
          ui.completionValue.value = operation.value || "";
          ui.completionValue.disabled = false;
          setStatus("Edit the selected pending text, then apply the update.");
          renderCompletionPanel();
        });
      }
      shell.appendChild(preview);
    });
  }

  function updateZoomFromSlider() {
    scaleState.zoom = ui.zoomSlider.value / 100;
    ui.zoomValue.textContent = `${ui.zoomSlider.value}%`;
    renderVisiblePages();
  }

  function rotate(delta) {
    rotation = (rotation + delta + 360) % 360;
    renderVisiblePages();
  }

  function safeExternal(url) {
    return /^https?:\/\//i.test(url || "");
  }

  function showPasswordPrompt() {
    ui.passwordInput.value = "";
    ui.modal.classList.add("show");
    setTimeout(() => ui.passwordInput.focus(), 0);
  }

  function closePasswordPrompt() {
    ui.modal.classList.remove("show");
  }

  async function openFile(file, password = null) {
    try {
      const arrayBuffer = await file.arrayBuffer();
      sourceName = file.name || "document.pdf";
      await loadPdf(new Uint8Array(arrayBuffer), password);
    } catch (error) {
      modeStage.failAnalysis();
      displayReaderError(error, WEB_ERROR_CODES.cannotOpen);
    }
  }

  async function loadPdf(data, password = null) {
    const generation = ++loadGeneration;
    pendingPassword = password;
    isEncryptedDocument = Boolean(password);
    const sourceBytes = new Uint8Array(data);
    pdfData = new Uint8Array(sourceBytes);
    sourceDigest = "";
    currentSessionID = makeID("session");
    documentContract = null;
    preflightReport = null;
    sessionProvenance = null;
    resourcePolicy = null;
    nativeFields = [];
    candidates = [];
    operations = [];
    reviews = [];
    templateFingerprint = null;
    templateContract = null;
    templateRevisionHistory = null;
    templateProposal = null;
    templateValueDrafts = {};
    templateLearningEvents = [];
    pendingValidatedTemplateRevision = null;
    templateRevisionDiff = null;
    lastAppliedTemplateProposal = null;
    templateCompletionOperationIDs = [];
    selectedField = null;
    selectedCandidate = null;
    lastValidation = null;
    pageTextCache = new Map();
    rotation = 0;
    selectedOperation = null;
    manualPlacementMode = false;
    manualPlacement = null;
    showDismissedCandidates = false;
    renderCompletionPanel();
    modeStage.beginAnalysis();

    while (true) {
      try {
        const loadingTask = pdfjsLib.getDocument({
          data: new Uint8Array(sourceBytes),
          password: pendingPassword || null
        });
        pdfDoc = await loadingTask.promise;
        break;
      } catch (error) {
        if (error?.name === "PasswordException") {
          closePasswordPrompt();
          showPasswordPrompt();
          modeStage.blockAnalysis("Analysis unavailable — password required");
          return;
        }
        throw normalizeReaderError(error, WEB_ERROR_CODES.cannotOpen);
      }
    }

    if (generation !== loadGeneration) { return; }
    closePasswordPrompt();
    modeStage.analysisStage("structure");
    await hydrateDocumentFacts();
    modeStage.analysisStageDone("structure");
    if (generation !== loadGeneration) { return; }
    await buildThumbnails(generation);
    if (generation !== loadGeneration) { return; }
    await hydrateMetadataFacts();
    if (generation !== loadGeneration) { return; }
    await runPageLinks();
    if (generation !== loadGeneration) { return; }
    await buildCompletionContract();
    if (generation !== loadGeneration) { return; }
    // Attempt to restore a saved session for this source
    const savedSession = await loadWebSession(sourceDigest);
    if (savedSession && generation === loadGeneration) {
      await restoreWebSession(savedSession);
    }
    await renderVisiblePages();
    if (generation !== loadGeneration) { return; }
    await runSearch();
    modeStage.refreshPanels();
    if (!savedSession) {
      setStatus(`Loaded ${scaleState.pageCount} page(s).`);
    }
  }

  async function hydrateDocumentFacts() {
    scaleState.pageCount = pdfDoc.numPages;
    currentPage = 1;
    pageFacts = [];
    for (let pageNum = 1; pageNum <= scaleState.pageCount; pageNum += 1) {
      const page = await pdfDoc.getPage(pageNum);
      const rawViewport = page.getViewport({ scale: 1 });
      pageFacts.push({
        label: (pageLabels[pageNum - 1] || String(pageNum)),
        page: pageNum,
        view: page.view ? Array.from(page.view).map(Math.floor) : [0, 0, Math.round(rawViewport.width), Math.round(rawViewport.height)],
        rotate: page.rotate || 0
      });
    }

    try {
      const labels = await pdfDoc.getPageLabels();
      pageLabels = labels || [];
      for (const fact of pageFacts) {
        const idx = fact.page - 1;
        if (pageLabels[idx]) {
          fact.label = pageLabels[idx];
        }
      }
    } catch {
      pageLabels = [];
    }
    try {
      const rawOutlines = await pdfDoc.getOutline();
      outlines = [];
      for (const node of (rawOutlines || [])) {
        outlines.push(await normalizeOutline(node));
      }
    } catch {
      outlines = [];
    }
    try {
      const allAttachments = await pdfDoc.getAttachments();
      attachments = allAttachments ? Object.keys(allAttachments) : [];
    } catch {
      attachments = [];
    }
    try {
      const boxDocument = await pdfLib.PDFDocument.load(new Uint8Array(pdfData));
      formOptionMap = new Map();
      try {
        const form = boxDocument.getForm();
        for (const fact of pageFacts) {
          const page = await pdfDoc.getPage(fact.page);
          const annotations = await page.getAnnotations({ intent: "display" });
          for (const annotation of annotations) {
            if (annotation.fieldType !== "Btn" || !(annotation.fieldFlags & 32768)) { continue; }
            const name = annotation.fieldName || annotation.id;
            if (!name || formOptionMap.has(name)) { continue; }
            const group = form.getRadioGroup(name);
            const options = group.getOptions();
            if (Array.isArray(options) && options.length) {
              formOptionMap.set(name, options);
            }
          }
        }
      } catch {
        formOptionMap = new Map();
      }
      boxDocument.getPages().forEach((page, index) => {
        const box = (value) => value
          ? normalizeRect([value.x, value.y, value.x + value.width, value.y + value.height])
          : null;
        const fact = pageFacts[index];
        if (!fact) { return; }
        fact.boxes = {
          media: box(page.getMediaBox()),
          crop: box(page.getCropBox()),
          bleed: box(page.getBleedBox()),
          trim: box(page.getTrimBox()),
          art: box(page.getArtBox())
        };
      });
    } catch {
      // Encrypted or provider-limited documents retain the PDF.js crop view.
    }
  }

  function paintThumbnailsIfAny(generation = loadGeneration) {
    ui.thumbnails.innerHTML = "";
    for (let pageNumber = 1; pageNumber <= scaleState.pageCount; pageNumber += 1) {
      const figure = document.createElement("div");
      figure.className = "thumb";
      figure.dataset.pageNumber = String(pageNumber);
      const canvas = document.createElement("canvas");
      figure.appendChild(canvas);
      const caption = document.createElement("div");
      caption.className = "small";
      const fact = pageFacts.find((item) => item.page === pageNumber);
      const label = fact?.label || pageLabels[pageNumber - 1] || String(pageNumber);
      const mediaText = fact?.view ? `(${fact.view.join(", ")})` : "";
      caption.textContent = `Page ${label} ${mediaText}`;
      figure.appendChild(caption);
      figure.addEventListener("click", () => {
        currentPage = pageNumber;
        renderVisiblePages();
      });
      ui.thumbnails.appendChild(figure);
      renderThumb(pageNumber, canvas, generation);
    }
  }

  async function renderThumb(pageNum, canvas, generation = loadGeneration) {
    if (generation !== loadGeneration || !pdfDoc || pageNum > pdfDoc.numPages) { return; }
    const page = await pdfDoc.getPage(pageNum);
    if (generation !== loadGeneration) { return; }
    const viewport = page.getViewport({ scale: 0.18, rotation });
    canvas.width = viewport.width;
    canvas.height = viewport.height;
    const ctx = canvas.getContext("2d");
    await page.render({ canvasContext: ctx, viewport }).promise;
  }

  function updateThumbSelection() {
    [...ui.thumbnails.querySelectorAll(".thumb")].forEach(node => {
      node.classList.toggle("selected", Number(node.dataset.pageNumber) === currentPage);
    });
  }

  async function buildThumbnails(generation = loadGeneration) {
    ui.thumbnails.innerHTML = "";
    paintThumbnailsIfAny(generation);
  }

  function resolveScale(viewportWidth) {
    if (scaleState.fitMode === "fitPage") {
      return Math.min(
        1.0,
        (ui.viewerStack.clientWidth - 24) / viewportWidth
      );
    }
    if (scaleState.fitMode === "fitWidth") {
      return Math.min(3, Math.max(0.2, (ui.viewerStack.clientWidth - 24) / viewportWidth));
    }
    return scaleState.zoom;
  }

  async function ensurePageText(pageNum) {
    if (pageTextCache.has(pageNum)) { return pageTextCache.get(pageNum); }
    const page = await pdfDoc.getPage(pageNum);
    const content = await page.getTextContent();
    const text = content.items.map(item => item.str || "").join(" ");
    pageTextCache.set(pageNum, text);
    return text;
  }

  function appendHighlightedText(span, text, query) {
    if (!query) {
      span.textContent = text;
      return;
    }
    const lower = text.toLowerCase();
    let cursor = 0;
    while (cursor < text.length) {
      const found = lower.indexOf(query, cursor);
      if (found === -1) {
        span.appendChild(document.createTextNode(text.slice(cursor)));
        break;
      }
      if (found > cursor) {
        span.appendChild(document.createTextNode(text.slice(cursor, found)));
      }
      const mark = document.createElement("mark");
      mark.textContent = text.slice(found, found + query.length);
      span.appendChild(mark);
      cursor = found + query.length;
    }
  }

  async function buildTextLayer(page, viewport, pageNum, shell) {
    const content = await page.getTextContent();
    const layer = document.createElement("div");
    layer.className = "text-layer";
    layer.setAttribute("role", "document");
    layer.setAttribute("aria-label", `Selectable text for page ${pageNum}`);
    const query = ui.searchInput.value.trim().toLowerCase();
    for (const item of content.items) {
      if (!item.str) { continue; }
      const span = document.createElement("span");
      const transform = pdfjsLib.Util.transform(viewport.transform, item.transform);
      const fontSize = Math.max(1, Math.hypot(transform[0], transform[1]));
      span.style.left = `${transform[4]}px`;
      span.style.top = `${transform[5] - fontSize}px`;
      span.style.fontSize = `${fontSize}px`;
      span.style.transform = `rotate(${Math.atan2(transform[1], transform[0])}rad)`;
      span.tabIndex = 0;
      span.setAttribute("aria-label", item.str);
      appendHighlightedText(span, item.str, query);
      layer.appendChild(span);
    }
    shell.appendChild(layer);
  }

  async function renderVisiblePages(generation = loadGeneration) {
    if (!pdfDoc || generation !== loadGeneration) { return; }
    document.body.classList.toggle("manual-placement", manualPlacementMode);
    ui.viewerStack.innerHTML = "";
    const pagesToShow = [];
    if (scaleState.viewMode === "single") {
      pagesToShow.push(currentPage);
    } else if (scaleState.viewMode === "twoPage") {
      pagesToShow.push(currentPage);
      if (currentPage + 1 <= scaleState.pageCount) {
        pagesToShow.push(currentPage + 1);
      }
    } else {
      for (let i = 1; i <= scaleState.pageCount; i += 1) {
        pagesToShow.push(i);
      }
    }

    const scaleSeed = resolveScale(595);
    for (const pageNum of pagesToShow) {
      if (generation !== loadGeneration || !pdfDoc || pageNum > pdfDoc.numPages) { return; }
      const page = await pdfDoc.getPage(pageNum);
      if (generation !== loadGeneration) { return; }
      const viewport = page.getViewport({ scale: scaleSeed, rotation });
      const canvas = document.createElement("canvas");
      canvas.className = "page-canvas";
      canvas.width = viewport.width;
      canvas.height = viewport.height;
      const ctx = canvas.getContext("2d");
      const fact = pageFacts.find((item) => item.page === pageNum);
      const label = fact?.label || pageLabels[pageNum - 1] || String(pageNum);
      const row = document.createElement("div");
      row.className = "item";
      row.dataset.pageNumber = String(pageNum);
      const shell = document.createElement("div");
      shell.className = "page-shell";
      shell.dataset.pageNumber = String(pageNum);
      shell.appendChild(canvas);
      const placeTextAtEvent = (event, direct = false) => {
        if ((!manualPlacementMode && !direct) || event.target.closest?.(".candidate-preview, .overlay-preview")) { return; }
        const canvasRect = canvas.getBoundingClientRect();
        const localX = event.clientX - canvasRect.left;
        const localY = event.clientY - canvasRect.top;
        const [pdfX, pdfY] = viewport.convertToPdfPoint(localX, localY);
        const pageBounds = normalizeRect(page.view || [0, 0, viewport.width / scaleSeed, viewport.height / scaleSeed]);
        const width = Math.min(180, Math.max(80, pageBounds.width - 16));
        const height = Math.min(28, Math.max(18, pageBounds.height - 16));
        const x = Math.min(Math.max(pdfX, pageBounds.x + 8), pageBounds.x + pageBounds.width - width - 8);
        const y = Math.min(Math.max(pdfY, pageBounds.y + 8), pageBounds.y + pageBounds.height - height - 8);
        manualPlacement = {
          pageIndex: pageNum - 1,
          bounds: { x, y, width, height },
          coordinate: coordinateFor(pageNum - 1, { x, y, width, height }, page.rotate || 0)
        };
        manualPlacementMode = false;
        selectedCandidate = null;
        selectedField = null;
        selectedOperation = null;
        ui.completionValue.value = "";
        ui.completionValue.disabled = false;
        setStatus(`${direct ? "Double-click" : "Manual placement"} selected a text area on page ${pageNum}. Enter a value, then add it.`);
        renderCompletionPanel();
        renderVisiblePages();
      };
      shell.addEventListener("click", (event) => placeTextAtEvent(event, false));
      shell.addEventListener("dblclick", (event) => {
        if (manualPlacementMode) { return; }
        placeTextAtEvent(event, true);
      });
      row.appendChild(shell);
      const caption = document.createElement("div");
      caption.className = "small muted";
      caption.textContent = `Page ${label} selectable text layer`;
      row.appendChild(caption);
      ui.viewerStack.appendChild(row);
      await page.render({ canvasContext: ctx, viewport }).promise;
      if (generation !== loadGeneration) { return; }
      await buildTextLayer(page, viewport, pageNum, shell);
      renderCandidatePreviews(pageNum, viewport, shell);
      renderOperationPreviews(pageNum, viewport, shell);
    }
    updateThumbSelection();
  }

  async function runPageLinks() {
    const discovered = [];
    for (let pageNum = 1; pageNum <= scaleState.pageCount; pageNum += 1) {
      const page = await pdfDoc.getPage(pageNum);
      const annotations = await page.getAnnotations({ intent: "display" });
      for (const annotation of annotations) {
        if (annotation.subtype !== "Link") { continue; }
        const rawURL = annotation.url || annotation.unsafeUrl || "";
        const hasURL = typeof rawURL === "string" && rawURL.length > 0;
        const destinationPage = await resolveAnnotationDestination(annotation.dest);
        discovered.push({
          page: pageNum,
          label: annotation.contents || `Page ${pageNum} link`,
          url: hasURL ? rawURL : "",
          dest: annotation.dest || "",
          pageTarget: destinationPage,
          bounds: normalizeRect(annotation.rect || [0, 0, 0, 0]),
          safe: hasURL ? safeExternal(rawURL) : destinationPage != null
        });
      }
    }
    links = discovered;
    renderLinks();
    renderOutlines();
  }

  function walkOutlines(list, level = 0, parent) {
    for (const item of list) {
      const row = document.createElement("div");
      row.className = "item outline-item";
      row.style.marginLeft = `${level * 10}px`;
      const label = document.createElement("span");
      label.textContent = item.title || "Section";
      label.title = item.title || "";
      label.className = "small";
      const button = document.createElement("button");
      button.textContent = item.destPage ? `Page ${item.destPage}` : "Go";
      if (!item.destPage) {
        button.disabled = true;
      }
      button.addEventListener("click", () => {
        if (item.destPage) {
          const maybe = Number(item.destPage);
          if (Number.isInteger(maybe)) {
            currentPage = Math.min(scaleState.pageCount, Math.max(1, maybe));
            renderVisiblePages();
          }
        }
      });
      row.appendChild(button);
      row.appendChild(label);
      parent.appendChild(row);
      if (item.items && item.items.length > 0) {
        walkOutlines(item.items, level + 1, parent);
      }
    }
  }

  function renderOutlines() {
    ui.outlineBox.innerHTML = "";
    if (!outlines.length) {
      const empty = document.createElement("div");
      empty.className = "small muted";
      empty.textContent = "No outline entries.";
      ui.outlineBox.appendChild(empty);
      return;
    }
    walkOutlines(outlines, 0, ui.outlineBox);
  }

  function renderLinks() {
    ui.linksBox.innerHTML = "";
    if (!links.length) {
      const empty = document.createElement("div");
      empty.className = "small muted";
      empty.textContent = "No discovered links.";
      ui.linksBox.appendChild(empty);
      return;
    }

    links.forEach((link) => {
      const row = document.createElement("div");
      row.className = "item";
      const label = document.createElement("div");
      label.className = "small muted";
      label.textContent = link.label;
      const button = document.createElement("button");
      const hasPageTarget = Boolean(link.pageTarget);
      const hasUrl = Boolean(link.url);
      button.textContent = hasUrl
        ? link.url
        : hasPageTarget
        ? `Page ${link.pageTarget}`
        : "No local target";
      button.disabled = !hasUrl && !hasPageTarget;
      button.addEventListener("click", async () => {
        if (hasUrl) {
          if (!safeExternal(link.url)) {
            alert("Unsafe destination blocked. Only http/https links are allowed.");
            return;
          }
          if (confirm(`Open ${link.url}?`)) {
            window.open(link.url, "_blank", "noopener");
          }
          return;
        }
        if (!hasPageTarget) {
          return;
        }
        currentPage = Math.min(scaleState.pageCount, Math.max(1, Number(link.pageTarget)));
        renderVisiblePages();
        updateThumbSelection();
      });
      row.appendChild(label);
      row.appendChild(button);
      if (hasUrl && !link.safe) {
        const warning = document.createElement("span");
        warning.className = "small danger";
        warning.textContent = " unsafe";
        row.appendChild(warning);
      }
      if (!hasUrl && !hasPageTarget) {
        const warning = document.createElement("span");
        warning.className = "small danger";
        warning.textContent = " no usable target";
        row.appendChild(warning);
      }
      ui.linksBox.appendChild(row);
    });
  }

  async function resolveOutlineDestination(dest) {
    return resolveDestinationToPage(dest);
  }

  async function normalizeOutline(item, level = 0) {
    const normalized = {
      title: item.title || "Section",
      dest: item.dest || "",
      destPage: await resolveOutlineDestination(item.dest),
      items: [],
      level
    };
    if (item.items && item.items.length > 0) {
      for (const child of item.items) {
        normalized.items.push(await normalizeOutline(child, level + 1));
      }
    }
    return normalized;
  }

  async function resolveAnnotationDestination(dest) {
    return resolveDestinationToPage(dest);
  }

  async function resolveDestinationToPage(destination) {
    if (!destination) { return null; }
    let normalizedDestination = destination;

    if (typeof destination === "string") {
      try {
        normalizedDestination = await pdfDoc.getDestination(destination);
      } catch {
        return null;
      }
    }

    if (!Array.isArray(normalizedDestination) || !normalizedDestination.length) {
      return null;
    }

    const firstTarget = normalizedDestination[0];
    if (typeof firstTarget === "number") {
      const candidate = firstTarget + 1;
      return candidate >= 1 && candidate <= scaleState.pageCount ? candidate : null;
    }

    try {
      const pageIndex = await pdfDoc.getPageIndex(firstTarget);
      const candidate = pageIndex + 1;
      return candidate >= 1 && candidate <= scaleState.pageCount ? candidate : null;
    } catch {
      return null;
    }
  }

  async function runSearch() {
    const query = ui.searchInput.value.trim().toLowerCase();
    if (!query || !pdfDoc) {
      searchResults = [];
      renderSearchResults();
      return;
    }
    const next = [];
    for (let pageNum = 1; pageNum <= scaleState.pageCount; pageNum += 1) {
      const text = await ensurePageText(pageNum);
      const lower = text.toLowerCase();
      let cursor = 0;
      while (cursor <= lower.length) {
        const found = lower.indexOf(query, cursor);
        if (found === -1) { break; }
        const snippetStart = Math.max(0, found - 30);
        const snippet = lower.substring(snippetStart, Math.min(lower.length, found + query.length + 30));
        next.push({ page: pageNum, snippet, charStart: found, charLength: query.length });
        cursor = found + Math.max(1, query.length);
      }
    }
    searchResults = next;
    selectedSearchIndex = next.length ? 0 : -1;
    renderSearchResults();
    if (next.length > 0) {
      currentPage = next[0].page;
      renderVisiblePages();
    }
  }

  function renderSearchResults() {
    ui.searchBox.innerHTML = "";
    ui.searchCount.textContent = `${searchResults.length} result(s)`;
    searchResults.forEach((result, index) => {
      const row = document.createElement("div");
      row.className = "item";
      const link = document.createElement("button");
      link.textContent = `p ${result.page}`;
      link.className = "small";
      link.addEventListener("click", () => {
        selectedSearchIndex = index;
        currentPage = result.page;
        renderVisiblePages();
        renderSearchResults();
      });
      const detail = document.createElement("span");
      detail.className = "small muted";
      detail.textContent = result.snippet || "";
      if (index === selectedSearchIndex) {
        detail.style.fontWeight = "700";
      }
      row.appendChild(link);
      row.appendChild(detail);
      ui.searchBox.appendChild(row);
    });
  }

  function moveSearch(direction) {
    if (!searchResults.length) {
      return;
    }
    const next = (selectedSearchIndex + direction + searchResults.length) % searchResults.length;
    selectedSearchIndex = next;
    currentPage = searchResults[selectedSearchIndex].page;
    renderSearchResults();
    renderVisiblePages();
  }

  async function hydrateMetadataFacts() {
    try {
      const md = await pdfDoc.getMetadata();
      metadata = md?.info || {};
    } catch {
      metadata = {};
    }
    try {
      permissions = (await pdfDoc.getPermissions()) || {};
    } catch {
      permissions = {};
    }

    ui.metaBox.innerHTML = "";
    const entries = [
      ["Title", metadata.Title],
      ["Author", metadata.Author],
      ["Subject", metadata.Subject],
      ["Creator", metadata.Creator],
      ["Producer", metadata.Producer],
      ["Creation", metadata.CreationDate],
      ["Modified", metadata.ModDate]
    ];
    for (const [label, value] of entries) {
      const row = document.createElement("div");
      row.className = "item small";
      row.textContent = `${label}: ${value || "not declared"}`;
      ui.metaBox.appendChild(row);
    }

    ui.permissionsBox.innerHTML = "";
    const permissionRows = [
      ["Print", permissions.print],
      ["Modify", permissions.modify],
      ["Copy", permissions.copy],
      ["Annotate", permissions.annotate]
    ];
    for (const [label, value] of permissionRows) {
      const row = document.createElement("div");
      row.className = "item small";
      row.textContent = `${label}: ${value ? "yes" : "no"}`;
      ui.permissionsBox.appendChild(row);
    }
    const currentPageFact = pageFacts.find((item) => item.page === currentPage);
    if (currentPageFact) {
      ui.permissionsBox.appendChild(document.createElement("hr"));
      const pageBoxLabel = document.createElement("div");
      pageBoxLabel.className = "item small";
      pageBoxLabel.textContent = `Current page: ${currentPageFact.label || currentPage}`;
      ui.permissionsBox.appendChild(pageBoxLabel);
      const mediaRow = document.createElement("div");
      mediaRow.className = "item small";
      mediaRow.textContent = `Media/view box: ${currentPageFact.view.join(" ")}`;
      ui.permissionsBox.appendChild(mediaRow);
    }
    ui.attachmentsBox.innerHTML = "";
    if (!attachments.length) {
      const empty = document.createElement("div");
      empty.className = "small muted";
      empty.textContent = "No embedded attachments found.";
      ui.attachmentsBox.appendChild(empty);
    } else {
      for (const attachment of attachments) {
        const row = document.createElement("div");
        row.className = "small item";
        row.textContent = attachment;
        ui.attachmentsBox.appendChild(row);
      }
    }
  }

  function renderPreflightReport() {
    if (!ui.preflightBox) return;
    ui.preflightBox.textContent = "";
    if (!preflightReport) {
      ui.preflightBox.textContent = "Preflight is not available until a PDF is loaded.";
      return;
    }
    const payload = preflightReport.payload;
    const summary = document.createElement("div");
    summary.className = "item small";
    summary.textContent = `Observed ${payload.summary.findingCount} finding(s): ${payload.summary.warningCount} warning(s), ${payload.summary.blockedCount} blocked surface(s).`;
    ui.preflightBox.appendChild(summary);
    const status = document.createElement("div");
    status.className = "item small";
    status.textContent = `Sanitization: ${payload.sanitization.status}; clean claim: no; source unchanged: yes.`;
    ui.preflightBox.appendChild(status);
    const categories = [
      ["Metadata fields present", payload.summary.metadataFieldCount],
      ["Embedded-data observations", payload.summary.embeddedDataCount],
      ["Network-boundary observations", payload.summary.networkBoundaryCount],
      ["Possible active-content tokens", payload.summary.activeContentCount]
    ];
    for (const [label, count] of categories) {
      const row = document.createElement("div");
      row.className = "small muted";
      row.textContent = `${label}: ${count}`;
      ui.preflightBox.appendChild(row);
    }
    const limits = document.createElement("div");
    limits.className = "small muted";
    limits.textContent = `Limits: ${payload.sanitization.limits.length} documented; preflight does not remove or execute PDF content.`;
    ui.preflightBox.appendChild(limits);
  }

  async function writeClipboardText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return;
    }
    const fallback = document.createElement("textarea");
    fallback.value = text;
    fallback.setAttribute("readonly", "true");
    fallback.style.position = "fixed";
    fallback.style.opacity = "0";
    document.body.appendChild(fallback);
    fallback.select();
    document.execCommand("copy");
    fallback.remove();
  }

  async function copyCurrentPageText() {
    if (!pdfDoc) { return; }
    const text = await ensurePageText(currentPage);
    await writeClipboardText(text || "");
    setStatus("Current page text copied.");
  }

  async function materializeOperations() {
    if (operations.length === 0) {
      return new Uint8Array(pdfData);
    }
    if (isEncryptedDocument) {
      const error = new Error("Encrypted PDF editing is not supported by the browser writer. The protected source remains read-only; unchanged export is byte-preserving.");
      error.readerCode = WEB_ERROR_CODES.unsupported;
      throw error;
    }
    if (!pdfLib?.PDFDocument) {
      throw new Error("pdf-lib did not load in this browser.");
    }
    const currentSourceDigest = await sha256Hex(pdfData);
    assertExportableContract({
      currentSourceDigest,
      operations,
      pageCoordinates: documentContract?.payload?.pages || [],
      validation: lastValidation
    });
    const outputDocument = await pdfLib.PDFDocument.load(pdfData);
    const formOperations = operations.filter((operation) => ["nativeFieldValue", "synthesizeNativeField"].includes(operation.kind));
    const overlayOperations = operations.filter((operation) => operation.kind === "overlayText");
    let form = null;
    let font = null;
    if (formOperations.length) {
      form = outputDocument.getForm();
      font = await outputDocument.embedFont(pdfLib.StandardFonts.Helvetica);
      for (const operation of formOperations) {
        if (operation.kind === "synthesizeNativeField") {
          const field = form.createTextField(operation.targetID);
          const bounds = operation.bounds;
          if (!bounds) { throw new Error(`Synthesized field ${operation.targetID} has no bounds.`); }
          field.addToPage(outputDocument.getPage(operation.pageIndex), {
            x: bounds.x,
            y: bounds.y,
            width: bounds.width,
            height: bounds.height,
            borderWidth: 0
          });
          continue;
        }
        const field = form.getField(operation.targetID);
        const value = operation.value;
        if (typeof field.setText === "function") {
          field.setText(value);
        } else if (typeof field.check === "function" && typeof field.uncheck === "function") {
          const truthy = /^(1|true|yes|on|checked)$/i.test(value.trim());
          truthy ? field.check() : field.uncheck();
        } else if (typeof field.select === "function") {
          field.select(value);
        } else {
          throw new Error(`Field ${operation.targetID} does not expose a supported pdf-lib setter.`);
        }
      }
      form.updateFieldAppearances(font);
    }
    if (overlayOperations.length) {
      font ||= await outputDocument.embedFont(pdfLib.StandardFonts.Helvetica);
      const boundedTextMinimumSize = 6;
      const boundedTextPadding = 2;
      const singleLineLayouts = new Map();
      const isExplicitMultiline = (operation) => operation.multiline === true
        || operation.payload?.multiline === true
        || operation.payload?.lineMode === "multiline";
      const measureTextHeight = (size) => typeof font.heightAtSize === "function"
        ? font.heightAtSize(size)
        : size;

      // Preflight all bounded single-line overlays before mutating the
      // in-memory output document. pdf-lib's maxWidth option can wrap text;
      // it is not a one-line fit guarantee and can therefore escape the
      // operation's declared authorization rectangle.
      for (const operation of overlayOperations) {
        if (!operation.bounds) {
          throw new Error(`Overlay ${operation.id} has no coordinate bounds.`);
        }
        if (operation.payload?.kind === "characterGrid" || isExplicitMultiline(operation)) {
          continue;
        }
        const text = String(operation.value || "");
        const availableWidth = operation.bounds.width - (boundedTextPadding * 2);
        const availableHeight = operation.bounds.height - (boundedTextPadding * 2);
        const preferredSize = Math.max(8, Math.min(14, operation.bounds.height * 0.72));
        const preferredWidth = font.widthOfTextAtSize(text, preferredSize);
        const preferredHeight = measureTextHeight(preferredSize);
        const widthSize = preferredWidth > 0 ? (preferredSize * availableWidth) / preferredWidth : preferredSize;
        const heightSize = preferredHeight > 0 ? (preferredSize * availableHeight) / preferredHeight : preferredSize;
        const size = Math.min(preferredSize, widthSize, heightSize);
        if (!Number.isFinite(size) || size < boundedTextMinimumSize) {
          throw new Error(
            `Bounded single-line text operation ${operation.id} cannot fit inside its declared region `
            + `(${operation.bounds.width.toFixed(2)} x ${operation.bounds.height.toFixed(2)}pt) `
            + `at the supported minimum font size of ${boundedTextMinimumSize}pt. `
            + "Choose a larger region or explicitly request multiline text."
          );
        }
        const measuredWidth = font.widthOfTextAtSize(text, size);
        const measuredHeight = measureTextHeight(size);
        if (measuredWidth > availableWidth + 0.01 || measuredHeight > availableHeight + 0.01) {
          throw new Error(
            `Bounded single-line text operation ${operation.id} cannot fit its measured text footprint `
            + "inside the declared operation region. Choose a larger region or explicitly request multiline text."
          );
        }
        singleLineLayouts.set(operation.id, {
          x: operation.bounds.x + boundedTextPadding,
          y: operation.bounds.y + boundedTextPadding + Math.max(0, (availableHeight - measuredHeight) / 2),
          size
        });
      }

      for (const operation of overlayOperations) {
        if (!operation.bounds) { throw new Error(`Overlay ${operation.id} has no coordinate bounds.`); }
        const page = outputDocument.getPage(operation.pageIndex);
        if (operation.payload?.kind === "characterGrid" && Array.isArray(operation.payload.cells)) {
          const characters = [...operation.value];
          if (characters.length > operation.payload.cells.length) {
            throw new Error(`Overlay ${operation.id} has more characters than detected cells.`);
          }
          operation.payload.cells.slice(0, characters.length).forEach((cell, index) => {
            page.drawText(characters[index], {
              x: cell.x + Math.max(1, cell.width * 0.18),
              y: cell.y + Math.max(1, cell.height * 0.12),
              size: Math.max(6, Math.min(11, cell.height * 0.72)),
              font,
              color: pdfLib.rgb(0.06, 0.18, 0.35),
              maxWidth: Math.max(4, cell.width - 2),
              lineHeight: Math.max(7, cell.height)
            });
          });
          continue;
        }
        if (isExplicitMultiline(operation)) {
          page.drawText(operation.value, {
            x: operation.bounds.x + 2,
            y: operation.bounds.y + 2,
            size: Math.max(8, Math.min(14, operation.bounds.height * 0.72)),
            font,
            color: pdfLib.rgb(0.06, 0.18, 0.35),
            maxWidth: Math.max(8, operation.bounds.width - 4),
            lineHeight: Math.max(9, operation.bounds.height)
          });
          continue;
        }
        const layout = singleLineLayouts.get(operation.id);
        if (!layout) {
          throw new Error(`Bounded single-line text operation ${operation.id} has no validated layout.`);
        }
        page.drawText(operation.value, {
          x: layout.x,
          y: layout.y,
          size: layout.size,
          font,
          color: pdfLib.rgb(0.06, 0.18, 0.35)
        });
      }
    }
    return outputDocument.save({ useObjectStreams: false });
  }

  async function inspectFieldsInDocument(document) {
    const fields = [];
    for (let pageNum = 1; pageNum <= document.numPages; pageNum += 1) {
      const page = await document.getPage(pageNum);
      const annotations = await page.getAnnotations({ intent: "display" });
      annotations.filter((annotation) => annotation.subtype === "Widget" || annotation.fieldType).forEach((annotation, index) => {
        fields.push({
          id: annotation.fieldName || annotation.id || `field-${pageNum}-${index + 1}`,
          name: annotation.fieldName || annotation.id || `field-${pageNum}-${index + 1}`,
          value: stringValue(annotation.fieldValue),
          pageIndex: pageNum - 1,
          kind: fieldKind(annotation)
        });
      });
    }
    return fields;
  }

  function operationMetricIDs(operationIDs = []) {
    return [...new Set((Array.isArray(operationIDs) ? operationIDs : []).filter(Boolean))];
  }

  function textImpactMetrics(result, operationIDs = [], basis = "pdfjs-text-outside-region") {
    const pages = Array.isArray(result?.pages) ? result.pages : [];
    return {
      basis,
      comparedPageCount: pages.length,
      changedPageCount: pages.filter((page) => page?.equal === false).length,
      operationCount: operationMetricIDs(operationIDs).length,
      operationIDs: operationMetricIDs(operationIDs)
    };
  }

  function rasterImpactMetrics(result, operationIDs = [], basis = "pdfjs-raster-outside-region") {
    const pages = Array.isArray(result?.pages) ? result.pages : [];
    const comparedPixelCount = pages.reduce((total, page) => total + (Number(page?.outsidePixelCount) || 0), 0);
    const changedPixelCount = pages.reduce((total, page) => total + (Number(page?.changedPixelCount) || 0), 0);
    return {
      basis,
      comparedPageCount: pages.length,
      changedPageCount: pages.filter((page) => page?.status === "failed").length,
      comparedPixelCount,
      changedPixelCount,
      outsidePixelRatio: comparedPixelCount ? changedPixelCount / comparedPixelCount : 0,
      maximumChannelDelta: pages.reduce((maximum, page) => Math.max(maximum, Number(page?.maxChannelDelta) || 0), 0),
      scale: Number.isFinite(result?.scale) ? result.scale : null,
      channelTolerance: Number.isFinite(result?.channelTolerance) ? result.channelTolerance : null,
      maxAllowedOutsidePixelRatio: Number.isFinite(result?.maxAllowedOutsidePixelRatio) ? result.maxAllowedOutsidePixelRatio : null,
      operationCount: operationMetricIDs(operationIDs).length,
      operationIDs: operationMetricIDs(operationIDs)
    };
  }

  function metricValueClass(status) {
    if (status === "passed") return "success";
    if (status === "failed") return "danger";
    return "muted";
  }

  function formatMetricNumber(value, digits = 0) {
    return Number.isFinite(value) ? value.toLocaleString(undefined, { maximumFractionDigits: digits }) : "not measured";
  }

  function appendImpactMetricRow(container, label, value, status = null) {
    const row = document.createElement("div");
    row.className = "impact-metric-row";
    const labelElement = document.createElement("span");
    labelElement.className = "impact-metric-label";
    labelElement.textContent = label;
    const valueElement = document.createElement("span");
    valueElement.className = `impact-metric-value${status ? ` ${metricValueClass(status)}` : ""}`;
    valueElement.textContent = value;
    row.append(labelElement, valueElement);
    container.appendChild(row);
  }

  function renderImpactMetrics(validation) {
    if (!ui.impactMetricsContent) return;
    ui.impactMetricsContent.innerHTML = "";
    if (!validation) {
      ui.impactMetricsContent.textContent = "No outside-region validation metrics yet.";
      return;
    }
    const textCheck = validation.checks?.find((check) => check.kind === "outsideRegionText") || null;
    const rasterCheck = validation.checks?.find((check) => check.kind === "visualDiff") || null;
    if (!textCheck && !rasterCheck) {
      ui.impactMetricsContent.textContent = "Outside-region validation was not reported.";
      return;
    }
    const textMetrics = textCheck?.metrics || {};
    const rasterMetrics = rasterCheck?.metrics || {};
    const summary = document.createElement("div");
    summary.className = "small muted";
    summary.textContent = "Counts exclude document text and field values.";
    ui.impactMetricsContent.appendChild(summary);

    const textHeading = document.createElement("div");
    textHeading.className = "list-title";
    textHeading.style.marginTop = "6px";
    textHeading.textContent = "Outside-region text";
    ui.impactMetricsContent.appendChild(textHeading);
    appendImpactMetricRow(ui.impactMetricsContent, "Status", textCheck?.status || "unknown", textCheck?.status || "unknown");
    if (Number.isFinite(textMetrics.sourcePageCount)) {
      appendImpactMetricRow(ui.impactMetricsContent, "Source pages", formatMetricNumber(textMetrics.sourcePageCount));
    }
    appendImpactMetricRow(ui.impactMetricsContent, "Pages compared", formatMetricNumber(textMetrics.comparedPageCount));
    appendImpactMetricRow(ui.impactMetricsContent, "Pages changed outside region", formatMetricNumber(textMetrics.changedPageCount));
    appendImpactMetricRow(ui.impactMetricsContent, "Authorized operations", formatMetricNumber(textMetrics.operationCount));

    const rasterHeading = document.createElement("div");
    rasterHeading.className = "list-title";
    rasterHeading.style.marginTop = "8px";
    rasterHeading.textContent = "Outside-region raster";
    ui.impactMetricsContent.appendChild(rasterHeading);
    appendImpactMetricRow(ui.impactMetricsContent, "Status", rasterCheck?.status || "unknown", rasterCheck?.status || "unknown");
    if (Number.isFinite(rasterMetrics.sourcePageCount)) {
      appendImpactMetricRow(ui.impactMetricsContent, "Source pages", formatMetricNumber(rasterMetrics.sourcePageCount));
    }
    appendImpactMetricRow(ui.impactMetricsContent, "Pages compared", formatMetricNumber(rasterMetrics.comparedPageCount));
    appendImpactMetricRow(ui.impactMetricsContent, "Pages changed outside region", formatMetricNumber(rasterMetrics.changedPageCount));
    appendImpactMetricRow(ui.impactMetricsContent, "Changed pixels / compared", `${formatMetricNumber(rasterMetrics.changedPixelCount)} / ${formatMetricNumber(rasterMetrics.comparedPixelCount)}`);
    appendImpactMetricRow(ui.impactMetricsContent, "Outside-pixel ratio", Number.isFinite(rasterMetrics.outsidePixelRatio) ? `${(rasterMetrics.outsidePixelRatio * 100).toFixed(4)}%` : "not measured");
    appendImpactMetricRow(ui.impactMetricsContent, "Maximum channel delta", formatMetricNumber(rasterMetrics.maximumChannelDelta));
    appendImpactMetricRow(ui.impactMetricsContent, "Render scale / tolerance", `${rasterMetrics.scale == null ? "not measured" : `${rasterMetrics.scale}x`} / ${rasterMetrics.channelTolerance == null ? "not measured" : rasterMetrics.channelTolerance}`);
    if (textMetrics.basis || rasterMetrics.basis) {
      appendImpactMetricRow(ui.impactMetricsContent, "Evidence basis", `${textMetrics.basis || "unknown"} / ${rasterMetrics.basis || "unknown"}`);
    }
  }

  function validationCheck(kind, status, message, operationIDs = [], region = null, metrics = null) {
    return {
      id: makeID("check"),
      kind,
      status,
      message,
      region,
      operationIDs,
      ...(metrics ? { metrics } : {})
    };
  }

  function valuesMatch(expected, actual, operation) {
    if (operation.payload?.kind === "radio") {
      const options = Array.isArray(operation.payload.options) ? operation.payload.options : [];
      const expectedIndex = options.indexOf(expected);
      if (expectedIndex >= 0 && String(expectedIndex) === String(actual || "").trim()) {
        return true;
      }
      return (expected || "").trim() === (actual || "").trim();
    }
    if (operation.payload?.kind === "boolean") {
      const expectedTruthy = /^(1|true|yes|on|checked)$/i.test(expected.trim());
      const actualTruthy = !/^(off|false|no|0|)$/i.test((actual || "").trim());
      return expectedTruthy === actualTruthy;
    }
    return (expected || "").trim() === (actual || "").trim();
  }

  async function validateExport(outputBytes) {
    if (operations.length === 0) {
      const outputDigest = await sha256Hex(outputBytes);
      const sourceUnchanged = outputDigest === sourceDigest;
      const operationIDs = [];
      const checks = [
        validationCheck(
          "sourceDigest",
          sourceUnchanged ? "passed" : "failed",
          sourceUnchanged ? "Source bytes still match the inspected SHA-256." : "Preserved encrypted bytes differ from the inspected source.",
          operationIDs
        ),
        validationCheck(
          "outputReopen",
          sourceUnchanged ? "passed" : "failed",
          sourceUnchanged ? `Encrypted source remains open in PDF.js with ${pdfDoc.numPages} page(s).` : "The preserved encrypted output cannot be trusted because its bytes changed.",
          operationIDs
        ),
        validationCheck("pageGeometry", "passed", "No-op export preserves the already-inspected encrypted page geometry.", operationIDs),
        validationCheck("nativeFields", "skipped", "No native field operations were requested.", operationIDs),
        validationCheck("appliedOperations", "passed", "0 queued operation(s) were applied; the protected source was copied byte-for-byte.", operationIDs),
        validationCheck(
          "outsideRegionText",
          "passed",
          "No page content changed because the protected source was copied byte-for-byte.",
          operationIDs,
          null,
          {
            ...textImpactMetrics({ pages: [] }, operationIDs, "source-digest-equality"),
            sourcePageCount: pdfDoc.numPages
          }
        ),
        validationCheck(
          "visualDiff",
          "passed",
          "No raster content changed because the protected source was copied byte-for-byte.",
          operationIDs,
          null,
          {
            ...rasterImpactMetrics({ pages: [] }, operationIDs, "source-digest-equality"),
            sourcePageCount: pdfDoc.numPages,
            renderedPageCount: 0
          }
        ),
        validationCheck(
          "providerCapability",
          "passed",
          isEncryptedDocument
            ? "Encrypted no-op export used byte-preserving source download; browser editing remains unsupported."
            : "No-op export used byte-preserving source download; no PDF writer was invoked.",
          operationIDs
        )
      ];
      return {
        status: sourceUnchanged ? "validated" : "failed",
        messages: checks.map((check) => check.message),
        sourceUnchanged,
        outputReopenable: sourceUnchanged,
        checks,
        sourceDigest,
        outputDigest,
        provider: providerDescriptor(),
        validatedAt: new Date().toISOString(),
        operationIDs
      };
    }
    const checks = [];
    const outputDigest = await sha256Hex(outputBytes);
    const sourceDigestAtValidation = await sha256Hex(pdfData);
    const sourceUnchanged = sourceDigestAtValidation === sourceDigest;
    checks.push(validationCheck(
      "sourceDigest",
      sourceUnchanged ? "passed" : "failed",
      sourceUnchanged ? "Source bytes still match the inspected SHA-256." : "Source bytes changed after inspection.",
      operations.map((operation) => operation.id)
    ));

    let outputDocument = null;
    try {
      outputDocument = await pdfjsLib.getDocument({ data: new Uint8Array(outputBytes) }).promise;
      checks.push(validationCheck("outputReopen", "passed", `Export reopened in PDF.js with ${outputDocument.numPages} page(s).`));
    } catch (error) {
      checks.push(validationCheck("outputReopen", "failed", `Export could not be reopened: ${error.message}`));
    }

    if (outputDocument) {
      const samePageCount = outputDocument.numPages === pdfDoc.numPages;
      let sameGeometry = samePageCount;
      if (sameGeometry) {
        for (let pageNum = 1; pageNum <= pdfDoc.numPages; pageNum += 1) {
          const originalPage = await pdfDoc.getPage(pageNum);
          const outputPage = await outputDocument.getPage(pageNum);
          const originalView = Array.from(originalPage.view || []);
          const outputView = Array.from(outputPage.view || []);
          if (originalView.length !== outputView.length || originalView.some((value, index) => Math.abs(value - outputView[index]) > 0.01)) {
            sameGeometry = false;
            break;
          }
        }
      }
      checks.push(validationCheck(
        "pageGeometry",
        sameGeometry ? "passed" : "failed",
        sameGeometry ? "Page count and PDF page boxes are unchanged." : "Page count or PDF page boxes changed during export."
      ));

      const outputFields = await inspectFieldsInDocument(outputDocument);
      const fieldOperations = operations.filter((operation) => operation.kind === "nativeFieldValue");
      const synthesizedFieldOperations = operations.filter((operation) => operation.kind === "synthesizeNativeField");
      let nativeFieldsPassed = true;
      for (const operation of fieldOperations) {
        const outputField = outputFields.find((field) => field.name === operation.targetID);
        if (!outputField || !valuesMatch(operation.value, outputField.value, operation)) {
          nativeFieldsPassed = false;
          checks.push(validationCheck("nativeFields", "failed", `Native field ${operation.targetID} did not round-trip to the requested value.`, [operation.id], operation.coordinate));
        }
      }
      if (!fieldOperations.length) {
        checks.push(validationCheck("nativeFields", "skipped", "No native field operations were requested."));
      } else if (nativeFieldsPassed) {
        checks.push(validationCheck("nativeFields", "passed", `${fieldOperations.length} native field operation(s) round-tripped through PDF.js.`, fieldOperations.map((operation) => operation.id)));
      }
      const missingSynthesizedFields = synthesizedFieldOperations.filter((operation) => !outputFields.some((field) => field.name === operation.targetID));
      if (synthesizedFieldOperations.length) {
        checks.push(validationCheck(
          "nativeFields",
          missingSynthesizedFields.length ? "failed" : "passed",
          missingSynthesizedFields.length
            ? `${missingSynthesizedFields.length} synthesized native field(s) did not reopen.`
            : `${synthesizedFieldOperations.length} synthesized native field(s) reopened in PDF.js.`,
          synthesizedFieldOperations.map((operation) => operation.id)
        ));
      }

      const pageTexts = [];
      for (let pageNum = 1; pageNum <= outputDocument.numPages; pageNum += 1) {
        const page = await outputDocument.getPage(pageNum);
        const content = await page.getTextContent();
        pageTexts.push(content.items.map((item) => item.str || "").join(" "));
      }
      const overlayOperations = operations.filter((operation) => operation.kind === "overlayText");
      const missingOverlays = overlayOperations.filter((operation) => !pageTexts[operation.pageIndex]?.includes(operation.value));
      checks.push(validationCheck(
        "appliedOperations",
        missingOverlays.length ? "warning" : "passed",
        missingOverlays.length ? `${missingOverlays.length} overlay value(s) were not found in PDF.js text extraction.` : `${operations.length} queued operation(s) are represented in the exported artifact.`,
        operations.map((operation) => operation.id)
      ));
      try {
        const impact = await compareOutsideRegions({
          pdfjsLib,
          sourceDocument: pdfDoc,
          outputDocument,
          operations
        });
        checks.push(validationCheck(
          "outsideRegionText",
          impact.text.status,
          impact.text.message,
          operations.map((operation) => operation.id),
          null,
          textImpactMetrics(impact.text, operations.map((operation) => operation.id))
        ));
        checks.push(validationCheck(
          "visualDiff",
          impact.raster.status,
          `${impact.raster.message}${impact.raster.scale ? ` Scale ${impact.raster.scale}.` : ""}`,
          operations.map((operation) => operation.id),
          null,
          rasterImpactMetrics(impact.raster, operations.map((operation) => operation.id))
        ));
      } catch (error) {
        checks.push(validationCheck(
          "outsideRegionText",
          "unknown",
          `Outside-region impact validation could not run: ${error.message}`,
          operations.map((operation) => operation.id),
          null,
          textImpactMetrics(null, operations.map((operation) => operation.id))
        ));
        checks.push(validationCheck(
          "visualDiff",
          "unknown",
          "Raster impact validation was not completed.",
          operations.map((operation) => operation.id),
          null,
          rasterImpactMetrics(null, operations.map((operation) => operation.id))
        ));
      }
      checks.push(validationCheck("providerCapability", "passed", "PDF.js reopened the export and pdf-lib produced the bytes."));
    }

    const failed = checks.some((check) => check.status === "failed");
    const warning = checks.some((check) => ["warning", "unknown"].includes(check.status));
    return {
      status: failed ? "failed" : warning ? "validatedWithWarnings" : "validated",
      messages: checks.map((check) => check.message),
      sourceUnchanged,
      outputReopenable: checks.some((check) => check.kind === "outputReopen" && check.status === "passed"),
      checks,
      sourceDigest,
      outputDigest,
      provider: providerDescriptor(),
      validatedAt: new Date().toISOString(),
      operationIDs: operations.map((operation) => operation.id)
    };
  }

  function downloadBytes(bytes) {
    const blob = new Blob([bytes], { type: "application/pdf" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `${sourceName.replace(/\.pdf$/i, "")}-web-proof.pdf`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  async function exportAndValidate() {
    if (!pdfData) {
      setStatus("Load a PDF before exporting.", "danger");
      return;
    }
    ui.exportButton.disabled = true;
    setStatus("Exporting with pdf-lib and validating with PDF.js...");
    try {
      const outputBytes = await materializeOperations();
      lastValidation = await validateExport(outputBytes);
      prepareValidatedTemplateRevisionFromValidation();
      renderCompletionPanel();
      if (lastValidation.status === "failed") {
        setStatus("Export validation failed. The artifact was not downloaded.", "danger");
        return;
      }
      downloadBytes(outputBytes);
      setStatus(`Exported and ${lastValidation.status}: ${sourceName}-web-proof.pdf`, lastValidation.status === "validated" ? "success" : "muted");
    } catch (error) {
      const normalized = normalizeReaderError(error, WEB_ERROR_CODES.exportFailed);
      lastValidation = {
        status: "failed",
        checks: [validationCheck("appliedOperations", "failed", `${normalized.readerCode}: ${normalized.message}`)],
        messages: [`${normalized.readerCode}: ${normalized.message}`],
        sourceUnchanged: true,
        outputReopenable: false,
        sourceDigest,
        outputDigest: null,
        provider: providerDescriptor(),
        validatedAt: new Date().toISOString(),
        operationIDs: operations.map((operation) => operation.id)
      };
      pendingValidatedTemplateRevision = null;
      templateLearningEvents = [];
      templateRevisionDiff = null;
      renderCompletionPanel();
      displayReaderError(normalized);
    } finally {
      ui.exportButton.disabled = false;
    }
  }

  function cloneContractValue(value) {
    return value === undefined ? null : JSON.parse(JSON.stringify(value));
  }

  function contractFixtureSnapshot() {
    if (!documentContract) {
      return null;
    }

    const generatedAt = documentContract.header.generatedAt;
    const provider = providerDescriptor();
    const pageCoordinates = documentContract.payload.pages.map((page) => ({
      pageIndex: page.pageIndex,
      region: coordinateFor(page.pageIndex, page.bounds, page.rotation)
    }));

    return {
      contractName: "pdf-editor.browser-fixture",
      version: { major: 1, minor: 0 },
      document: cloneContractValue(documentContract),
      coordinates: {
        contractName: "pdf-editor.coordinates",
        version: { major: 1, minor: 0 },
        sourceDigest,
        generatedAt,
        provider,
        pages: pageCoordinates
      },
      candidates: cloneContractValue(documentContract.payload.candidates),
      textRuns: cloneContractValue(textRunProjections),
      preflight: cloneContractValue(preflightReport),
      sessionProvenance: cloneContractValue(buildSessionPrivacyProvenance() || sessionProvenance),
      resourcePolicy: cloneContractValue(resourcePolicy),
      editSession: {
        header: {
          contractName: "pdf-editor.edit-session",
          version: { major: 1, minor: 0 },
          sourceDigest,
          generatedAt,
          provider
        },
        source: cloneContractValue(documentContract.payload.source),
        reviews: cloneContractValue(reviews),
        operations: cloneContractValue(operations)
      },
      validation: cloneContractValue(lastValidation)
    };
  }

  async function runMaterializationProbe({ operationsOverride, validationOverride } = {}) {
    const previousOperations = operations;
    const previousValidation = lastValidation;
    if (Array.isArray(operationsOverride)) operations = operationsOverride;
    if (validationOverride !== undefined) lastValidation = validationOverride;
    try {
      return await materializeOperations();
    } finally {
      operations = previousOperations;
      lastValidation = previousValidation;
    }
  }

  window.__pdfEditorContractFixture = {
    snapshot: contractFixtureSnapshot,
    createTemplateFingerprint: async ({ workspaceKey, includeExactSourceDigest = false } = {}) => {
      if (!documentContract) throw new Error("Open a PDF before creating a template fingerprint.");
      return createTemplateFingerprint({ document: documentContract, workspaceKey, includeExactSourceDigest });
    },
    classifyTemplateIndex,
    calibrateDocumentClassPolicies,
    scoreTemplateFingerprints,
    runReviewedCorrectionBenchmark,
    runIhatepdfExperimentParity,
    chooseBrowserResourcePolicy,
    collectBrowserResourceEnvironment,
    validateBrowserResourcePolicy,
    normalizeResourceDocument,
    runAdaptiveBatches,
    createResourceCheckpoint,
    validateResourceCheckpoint,
    summarizeResourceEvent,
    normalizePdfJsTextItems,
    compareTextRunProjections,
    compareOCRLayerAlignment,
    buildTextRunReplacementProbe,
    validateTextRunOCRAlignmentReport,
    resourcePolicy: () => cloneContractValue(resourcePolicy),
    buildPreflightReport: ({ sourceBytes, provider, generatedAt } = {}) => {
      if (!documentContract) throw new Error("Open a PDF before creating a preflight report.");
      const report = buildPreflightReport({
        document: documentContract,
        sourceBytes: sourceBytes || pdfData,
        provider: provider || providerDescriptor(),
        generatedAt
      });
      validatePreflightReport(report);
      return report;
    },
    validatePreflightReport,
    createSessionPrivacyProvenance,
    validateSessionPrivacyProvenance,
    validateTemplateContract,
    matchTemplate,
    createCompletionProposal,
    reviewCompletionMapping,
    reviewCompletionValue,
    resolveCompletionTarget,
    canMaterializeCompletion,
    materializeCompletionOperations,
    createLearningEvent,
    canPromoteTemplateRevision,
    makeValidatedTemplateRevision,
    diffTemplateRevisions,
    exportTemplateHistory,
    importTemplateHistory,
    encryptTemplateSyncEnvelope,
    decryptTemplateSyncEnvelope,
    mergeTemplateHistories,
    captureTemplateDraft,
    activateTemplateRevision,
    appendTemplateRevision,
    createEncryptedTemplateStore,
    createEncryptedOPFSTemplateStore,
    createEphemeralTemplateStore,
    createZeroContentLogger,
    assertExportableContract,
    guardedPdfLibExport,
    ContractMutationError,
    runMaterializationProbe,
    TemplateStoreError
  };

  ui.fileInput.addEventListener("change", async (event) => {
    const [file] = event.target.files || [];
    if (file) {
      await openFile(file);
    }
  });

  ui.fitMode.addEventListener("change", () => {
    scaleState.fitMode = ui.fitMode.value;
    renderVisiblePages();
  });

  ui.viewMode.addEventListener("change", () => {
    scaleState.viewMode = ui.viewMode.value;
    renderVisiblePages();
  });

  ui.rotateL.addEventListener("click", () => rotate(-90));
  ui.rotateR.addEventListener("click", () => rotate(90));
  ui.zoomSlider.addEventListener("input", updateZoomFromSlider);
  ui.jumpButton.addEventListener("click", () => {
    const value = Number(ui.pageInput.value);
    if (Number.isInteger(value) && value >= 1 && value <= scaleState.pageCount) {
      currentPage = value;
      renderVisiblePages();
    } else {
      setStatus("Invalid page number.");
    }
  });

  ui.searchButton.addEventListener("click", runSearch);
  ui.searchPrev.addEventListener("click", () => moveSearch(-1));
  ui.searchNext.addEventListener("click", () => moveSearch(1));
  ui.copyPageText.addEventListener("click", copyCurrentPageText);
  ui.manualTextButton.addEventListener("click", () => {
    if (!pdfDoc) {
      setStatus("Load a PDF before placing text.", "danger");
      return;
    }
    selectedCandidate = null;
    selectedField = null;
    selectedOperation = null;
    manualPlacement = null;
    manualPlacementMode = !manualPlacementMode;
    setStatus(manualPlacementMode ? "Click the document where the new text should begin." : "Manual text placement cancelled.");
    renderCompletionPanel();
    renderVisiblePages();
  });
  ui.cancelManualTextButton.addEventListener("click", () => {
    manualPlacementMode = false;
    manualPlacement = null;
    ui.completionValue.value = "";
    renderCompletionPanel();
    renderVisiblePages();
    setStatus("Manual text placement cancelled.");
  });
  ui.dismissCandidateButton.addEventListener("click", dismissSelectedCandidate);
  ui.captureTemplateButton.addEventListener("click", captureTemplateLayout);
  ui.saveTemplateButton.addEventListener("click", saveTemplateRevisionLocally);
  ui.exportTemplateButton.addEventListener("click", exportTemplateTransfer);
  ui.importTemplateButton.addEventListener("click", () => ui.templateImportInput.click());
  ui.templateImportInput.addEventListener("change", async (event) => {
    await importTemplateTransfer(event.target.files?.[0] || null);
    event.target.value = "";
  });
  ui.exportTemplateSyncButton.addEventListener("click", exportTemplateSync);
  ui.importTemplateSyncButton.addEventListener("click", () => ui.templateSyncImportInput.click());
  ui.templateSyncImportInput.addEventListener("change", async (event) => {
    await importTemplateSync(event.target.files?.[0] || null);
    event.target.value = "";
  });
  ui.activateTemplateButton.addEventListener("click", activateReviewedTemplate);
  ui.prepareTemplateButton.addEventListener("click", prepareTemplateCompletion);
  ui.applyTemplateButton.addEventListener("click", applyTemplateCompletion);
  ui.restoreDismissedButton.addEventListener("click", () => {
    showDismissedCandidates = !showDismissedCandidates;
    renderCompletionPanel();
  });
  ui.completionValue.addEventListener("input", () => renderCompletionPanel());
  ui.applyFieldButton.addEventListener("click", applyNativeFieldOperation);
  ui.synthesizeFieldButton.addEventListener("click", synthesizeNativeField);
  ui.applyOverlayButton.addEventListener("click", applyOverlayOperation);
  ui.undoEditButton.addEventListener("click", undoLastOperation);
  ui.exportButton.addEventListener("click", exportAndValidate);

  ui.passwordForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    await loadPdf(pdfData, ui.passwordInput.value);
  });
  ui.passwordCancel.addEventListener("click", () => {
    closePasswordPrompt();
  });

  window.addEventListener("resize", () => {
    if (pdfDoc) {
      renderVisiblePages();
    }
  });

  setStatus("Load a PDF to begin.");

  // Initial mode surface render happens only after every state binding above
  // exists (the controller reads them through its getState snapshot).
  modeStage.selectMode("reader");
