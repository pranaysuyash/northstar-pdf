import AppKit
import CryptoKit
import Observation
import PDFEditorCore
import PDFKit
import UniformTypeIdentifiers

struct SearchMatch: Identifiable, Equatable, Sendable {
  let pageIndex: Int
  let query: String
  let snippet: String
  let charStart: Int
  let charLength: Int

  // The PDF text position is the durable identity. A generated UUID made
  // every search refresh look like a different hit and made selection drift.
  var id: String {
    "\(pageIndex):\(charStart):\(charLength):\(query.lowercased()):\(snippet)"
  }
}

struct ManualTextPlacement: Equatable, Sendable {
  let pageIndex: Int
  let bounds: PDFRect
}

@Observable
@MainActor
final class AppModel {
  private let provider = PDFKitProvider()
  private let sessionStore: FileSessionStore
  private let recoveryStore: SessionRecoveryStore
  private let recoveryPayloadStore: SessionPayloadStore
  private let recoveryPairStore: RecoveryPairStore
  private let profileStore: EncryptedPDFProfileVault
  private let templateStore: EncryptedPDFTemplateStore

  var inspection: DocumentInspection?
  private(set) var liveDocument: PDFDocument?
  private(set) var documentProjectionRevision: UInt64 = 0
  var sourceURL: URL?
  var operations: [EditOperation] = []
  var selectedPageIndex = 0
  var selectedFieldID: String?
  var selectedCandidateID: UUID?
  var isManualPlacementMode = false
  var manualTextPlacement: ManualTextPlacement?
  var isManualTextSheetPresented = false
  var manualTextDraft = ""
  var isImporterPresented = false
  var statusMessage: String?
  var alertMessage: String?

  // Profile state
  var currentProfile: UserProfile?
  var availableProfiles: [UserProfile] = []
  var isProfilePanelOpen = false
  var bulkFillResult: ProfileBulkFillResult?
  // Template completion is a review session, not a profile shortcut. Mapping
  // and profile-value approvals remain in memory until both gates pass.
  var templateContract: PDFTemplateContract?
  var templateRevisionHistory: PDFTemplateRevisionSet?
  var templateCompletionProposal: PDFTemplateCompletionProposal?
  var templateValueDrafts: [UUID: String] = [:]
  var templateLearningEvents: [PDFTemplateLearningEvent] = []
  var pendingValidatedTemplateRevision: PDFTemplateContract?
  var templateRevisionDiff: PDFTemplateRevisionDiff?
  var templateIndexMatch: PDFTemplateIndexQueryResult?
  var availableTemplateIDs: [UUID] = []
  var isTemplateVaultUnlocked = false
  var isProfileVaultUnlocked = false
  /// Read-only, value-minimized source preflight shown before any export.
  var preflightReport: PDFPreflightReport?
  var templateStoreHealth: PDFLocalStoreHealth?
  var profileStoreHealth: PDFLocalStoreHealth?
  var templateAuditEvents: [PDFLocalStoreAuditEvent] = []
  var profileAuditEvents: [PDFLocalStoreAuditEvent] = []
  private var lastAppliedTemplateCompletion: PDFTemplateCompletionProposal?
  private var templateCompletionOperationIDs: [UUID] = []
  var exportReport: ValidationReport?
  private(set) var lastActionDenial: ActionDenial?

  var readerViewMode: ReaderViewMode = .continuous
  var readerScaleMode: ReaderScaleMode = .fitWidth
  var readerZoom = 1.0
  var readerRotation = 0
  var pageJumpInput = ""

  // MARK: - Editor mode (D-010)
  /// Current intent mode. Resets to `.read` on open unless `persistModeAcrossDocuments` is true.
  var editorMode: EditorMode = .read
  /// User preference: when true, the mode chosen by the user persists when a new document is
  /// opened. Default false (reset to .read on each open) per D-010 owner decision 2026-08-25.
  var persistModeAcrossDocuments: Bool {
    get { UserDefaults.standard.bool(forKey: "persistModeAcrossDocuments") }
    set { UserDefaults.standard.set(newValue, forKey: "persistModeAcrossDocuments") }
  }
  /// When true, the status bar shows a "This document has fields — fill them?" chip.
  var isFillOfferVisible = false
  /// Pending signature region when Sign mode is active (nil = free placement).
  var pendingSignatureRegion: RegionCandidate?
  /// Whether the signature sheet is presented.
  var isSignatureSheetPresented = false
  /// Saved signatures (interim: app-sandboxed store; v2 migrates to Keychain per D-010).
  var savedSignatures: [SavedSignature] = []
  /// Whether the redaction commit confirmation is presented (L3 gate).
  var isRedactionCommitPresented = false
  /// Tab-order cursor: index into `editableRegions` for the current tab position.
  private var tabCursorIndex: Int = 0


  var isPasswordSheetPresented = false
  var passwordAttempt = ""
  private var passwordPendingURL: URL?
  private var cachedSourceData: Data?
  private var ocrProcessedPageIndices: Set<Int> = []

  var searchQuery = ""
  var searchMatches: [SearchMatch] = []
  var selectedSearchMatchIndex: Int?

  // Session persistence
  private var currentSessionID: UUID?
  var hasSavedSession: Bool = false
  var lastSessionInfo: String?
  var recoveryRecords: [DocumentSessionRecoveryEnvelope] = []
  var recoveryDiagnostics: [String] = []
  var recoveryStatus: RecoveryStatus = .none
  private var recoveryAutosaveSequence = 0
  private var viewStateAutosaveTask: Task<Void, Never>?
  private var lastPersistedViewStateDigest: String?

  enum RecoveryStatus: String, Sendable {
    case none
    case available
    case replayable
    case metadataOnly
    case corrupted
    case saveFailed
  }

  var sessionID: UUID? { currentSessionID }

  var canSaveValidatedTemplateRevision: Bool {
    guard pendingValidatedTemplateRevision != nil,
          let report = exportReport,
          report.status == .validated,
          !templateCompletionOperationIDs.isEmpty
    else { return false }
    return Set(report.operationIDs) == Set(operations.map(\.id))
      && Set(report.operationIDs) == Set(templateCompletionOperationIDs)
  }

  var templateSaveButtonTitle: String {
    canSaveValidatedTemplateRevision ? "Save validated template revision" : "Persist encrypted working capture"
  }

  enum LifecycleAction: String, Sendable {
    case newDocument
    case openDocument
    case closeWindow
  }

  enum LifecycleDisposition: String, Sendable {
    case proceed
    case confirmBeforeDiscardingChanges
  }

  struct LifecycleDecisionInfo: Equatable, Sendable {
    let action: LifecycleAction
    let hasDocument: Bool
    let isDirty: Bool
    let hasRecoverableSession: Bool
    let canExportChanges: Bool
    let disposition: LifecycleDisposition
  }

  private struct ReplayCheckpoint {
    let operationCount: Int
    let document: PDFDocument
  }

  enum PermissionRequirement: String, Sendable {
    case copy = "copy or extract text"
    case modify = "modify form data"
    case addAnnotations = "add annotations or overlays"
  }

  struct ActionDenial: Identifiable, Equatable, Sendable {
    let id: String
    let action: String
    let requirement: PermissionRequirement?
    let message: String

    init(action: String, requirement: PermissionRequirement?, message: String) {
      self.action = action
      self.requirement = requirement
      self.message = message
      self.id = "denied:\(action):\(requirement?.rawValue ?? "document")"
    }
  }

  struct InMemoryRecoverySnapshot: Equatable, Sendable {
    let sessionID: UUID
    let sourceDigest: String
    let operationLedgerDigest: String
    let operationCount: Int
    let selectedPageIndex: Int
    let selectedFieldID: String?
    let selectedCandidateID: UUID?
    let selectedSearchMatchID: String?
    let readerViewMode: String
    let readerScaleMode: String
    let readerZoom: Double
    let readerRotation: Int
    let capturedAt: Date
  }

  private struct ViewStateSnapshot {
    let selectedPageIndex: Int
    let selectedFieldID: String?
    let selectedCandidateID: UUID?
    let selectedSearchMatchIndex: Int?
    let readerViewMode: ReaderViewMode
    let readerScaleMode: ReaderScaleMode
    let readerZoom: Double
    let readerRotation: Int
  }

  private struct OperationViewState {
    let before: ViewStateSnapshot
    let after: ViewStateSnapshot
  }

  private struct RedoEntry {
    let operation: EditOperation
    let viewStateAfter: ViewStateSnapshot
  }

  // Checkpoints bound undo replay work without making a full-document copy for
  // every edit. The source replay path remains the correctness fallback when a
  // checkpoint is unavailable or cannot be copied.
  private static let replayCheckpointInterval = 8
  private static let maximumReplayCheckpoints = 8
  private var replayCheckpoints: [ReplayCheckpoint] = []
  private var operationViewStates: [OperationViewState] = []
  private var redoEntries: [RedoEntry] = []
  private(set) var inMemoryRecoverySnapshot: InMemoryRecoverySnapshot?

  init(
    sessionStore: FileSessionStore = FileSessionStore(directory: FileSessionStore.defaultDirectory),
    recoveryStore: SessionRecoveryStore = SessionRecoveryStore(directory: SessionRecoveryStore.defaultDirectory),
    recoveryPayloadStore: SessionPayloadStore = SessionPayloadStore(),
    recoveryPairStore: RecoveryPairStore = RecoveryPairStore(),
    profileStore: EncryptedPDFProfileVault = EncryptedPDFProfileVault(directory: EncryptedPDFProfileVault.defaultDirectory),
    templateStore: EncryptedPDFTemplateStore = EncryptedPDFTemplateStore(directory: EncryptedPDFTemplateStore.defaultDirectory)
  ) {
    self.sessionStore = sessionStore
    self.recoveryStore = recoveryStore
    self.recoveryPayloadStore = recoveryPayloadStore
    self.recoveryPairStore = recoveryPairStore
    self.profileStore = profileStore
    self.templateStore = templateStore
    refreshProfiles()
    refreshTemplateIDs()
    refreshLocalPersistenceHealth()
    refreshRecoveryDiscovery()
  }

  /// Keychain-backed local vault access is explicit in the UI. No template
  /// or profile values are exposed merely because a store directory exists.
  func unlockTemplateVault() {
    do {
      availableTemplateIDs = try templateStore.unlock()
      isTemplateVaultUnlocked = true
      refreshLocalPersistenceHealth()
      statusMessage = "Unlocked the encrypted local template vault."
    } catch {
      isTemplateVaultUnlocked = false
      refreshLocalPersistenceHealth()
      alertMessage = "Could not unlock the local template vault: \(error.localizedDescription)"
    }
  }

  func lockTemplateVault() {
    isTemplateVaultUnlocked = false
    templateContract = nil
    templateRevisionHistory = nil
    templateLearningEvents = []
    pendingValidatedTemplateRevision = nil
    templateIndexMatch = nil
    refreshLocalPersistenceHealth()
    statusMessage = "Locked the local template vault."
  }

  func unlockProfileVault() {
    do {
      _ = try profileStore.unlock()
      isProfileVaultUnlocked = true
      refreshProfiles()
      refreshLocalPersistenceHealth()
      statusMessage = "Unlocked the encrypted local profile vault."
    } catch {
      isProfileVaultUnlocked = false
      refreshLocalPersistenceHealth()
      alertMessage = "Could not unlock the local profile vault: \(error.localizedDescription)"
    }
  }

  func lockProfileVault() {
    isProfileVaultUnlocked = false
    currentProfile = nil
    availableProfiles = []
    templateCompletionProposal = nil
    refreshLocalPersistenceHealth()
    statusMessage = "Locked the local profile vault."
  }

  /// Refreshes value-free persistence health and audit summaries. Any failure
  /// is surfaced as an unknown state rather than exposing a storage error's
  /// path, identifier, or profile value in the UI.
  func refreshLocalPersistenceHealth() {
    do {
      templateStoreHealth = try templateStore.health()
      templateAuditEvents = (try? templateStore.auditEvents()) ?? []
    } catch {
      templateStoreHealth = PDFLocalStoreHealth(
        storeKind: .template,
        state: .unknown,
        primaryAvailable: false,
        backupAvailable: false,
        recordCount: 0,
        auditEventCount: templateAuditEvents.count,
        recoveryEnvelopeAvailable: false,
        encryptedBackupRecommended: true,
        messageCode: "health-check-failed")
    }
    do {
      profileStoreHealth = try profileStore.health()
      profileAuditEvents = (try? profileStore.auditEvents()) ?? []
    } catch {
      profileStoreHealth = PDFLocalStoreHealth(
        storeKind: .profile,
        state: .unknown,
        primaryAvailable: false,
        backupAvailable: false,
        recordCount: 0,
        auditEventCount: profileAuditEvents.count,
        recoveryEnvelopeAvailable: false,
        encryptedBackupRecommended: true,
        messageCode: "health-check-failed")
    }
  }

  private func requestLocalPassphrase(title: String, message: String) -> String? {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .informational
    let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    field.placeholderString = "At least 12 characters"
    alert.accessoryView = field
    alert.addButton(withTitle: "Continue")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return nil }
    let passphrase = field.stringValue
    return passphrase.isEmpty ? nil : passphrase
  }

  func exportTemplateRecoveryEnvelope() {
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before exporting recovery material."
      return
    }
    guard let passphrase = requestLocalPassphrase(
      title: "Export template-vault recovery envelope",
      message: "This encrypted envelope protects the vault key. Store it separately from the encrypted backup. The passphrase cannot be recovered by the app.") else { return }
    do {
      let data = try templateStore.exportRecoveryEnvelope(passphrase: passphrase)
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.json]
      panel.nameFieldStringValue = "pdf-editor-template-vault-recovery.json"
      panel.begin { [weak self] response in
        guard response == .OK, let url = panel.url else { return }
        do {
          try data.write(to: url, options: .atomic)
          self?.refreshLocalPersistenceHealth()
          self?.statusMessage = "Exported encrypted template-vault recovery material. Keep the passphrase separate."
        } catch {
          self?.alertMessage = "Could not export template-vault recovery material: \(error.localizedDescription)"
        }
      }
    } catch {
      alertMessage = "Could not prepare template-vault recovery material: \(error.localizedDescription)"
    }
  }

  func importTemplateRecoveryEnvelope() {
    guard let passphrase = requestLocalPassphrase(
      title: "Import template-vault recovery envelope",
      message: "Enter the passphrase used when this recovery envelope was exported. No PDF bytes or profile values are read by this operation.") else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      do {
        try self?.templateStore.recoverKey(from: Data(contentsOf: url), passphrase: passphrase)
        self?.isTemplateVaultUnlocked = true
        self?.refreshTemplateIDs()
        self?.refreshLocalPersistenceHealth()
        self?.statusMessage = "Recovered the template-vault key. Existing records remain encrypted and require normal review."
      } catch {
        self?.alertMessage = "Could not import template-vault recovery material: \(error.localizedDescription)"
      }
    }
  }

  func exportProfileRecoveryEnvelope() {
    guard isProfileVaultUnlocked else {
      statusMessage = "Unlock the local profile vault before exporting recovery material."
      return
    }
    guard let passphrase = requestLocalPassphrase(
      title: "Export profile-vault recovery envelope",
      message: "This encrypted envelope protects the profile-vault key. It does not contain a readable profile export.") else { return }
    do {
      let data = try profileStore.exportRecoveryEnvelope(passphrase: passphrase)
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.json]
      panel.nameFieldStringValue = "pdf-editor-profile-vault-recovery.json"
      panel.begin { [weak self] response in
        guard response == .OK, let url = panel.url else { return }
        do {
          try data.write(to: url, options: .atomic)
          self?.refreshLocalPersistenceHealth()
          self?.statusMessage = "Exported encrypted profile-vault recovery material. Keep the passphrase separate."
        } catch {
          self?.alertMessage = "Could not export profile-vault recovery material: \(error.localizedDescription)"
        }
      }
    } catch {
      alertMessage = "Could not prepare profile-vault recovery material: \(error.localizedDescription)"
    }
  }

  func importProfileRecoveryEnvelope() {
    guard let passphrase = requestLocalPassphrase(
      title: "Import profile-vault recovery envelope",
      message: "Enter the passphrase used when this recovery envelope was exported. Profile values remain inside the encrypted native vault.") else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      do {
        try self?.profileStore.recoverKey(from: Data(contentsOf: url), passphrase: passphrase)
        self?.isProfileVaultUnlocked = true
        self?.refreshProfiles()
        self?.refreshLocalPersistenceHealth()
        self?.statusMessage = "Recovered the profile-vault key. Select a profile before resolving any values."
      } catch {
        self?.alertMessage = "Could not import profile-vault recovery material: \(error.localizedDescription)"
      }
    }
  }

  func deleteAllTemplateVaultRecords() {
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before deleting its records."
      return
    }
    let alert = NSAlert()
    alert.messageText = "Delete all local template records?"
    alert.informativeText = "This removes encrypted templates, learning events, and mappings. The value-free deletion audit remains. This cannot be undone without an encrypted backup."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Delete Records")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    do {
      try templateStore.deleteAllRecords()
      templateContract = nil
      templateRevisionHistory = nil
      templateCompletionProposal = nil
      refreshTemplateIDs()
      refreshLocalPersistenceHealth()
      statusMessage = "Deleted all encrypted template records. The deletion audit was retained without values."
    } catch {
      alertMessage = "Could not delete local template records: \(error.localizedDescription)"
    }
  }

  func deleteAllProfileVaultRecords() {
    guard isProfileVaultUnlocked else {
      statusMessage = "Unlock the local profile vault before deleting its records."
      return
    }
    let alert = NSAlert()
    alert.messageText = "Delete all local profile records?"
    alert.informativeText = "This removes encrypted profile values. The value-free deletion audit remains. This cannot be undone without a separate encrypted recovery path."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Delete Profiles")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    do {
      try profileStore.deleteAllRecords()
      currentProfile = nil
      refreshProfiles()
      refreshLocalPersistenceHealth()
      statusMessage = "Deleted all encrypted profile records. The deletion audit was retained without values."
    } catch {
      alertMessage = "Could not delete local profile records: \(error.localizedDescription)"
    }
  }

  func refreshTemplateIDs() {
    availableTemplateIDs = (try? templateStore.templateIDs()) ?? []
  }

  /// Rebuild the value-free local index from encrypted histories and query it
  /// against the current source. Retrieval never mutates the active template
  /// or creates operations.
  func findLocalTemplateMatches() {
    guard let inspection else {
      statusMessage = "Open a PDF before searching local templates."
      return
    }
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before searching local templates."
      return
    }
    do {
      let histories = try availableTemplateIDs.compactMap { try templateStore.load(templateID: $0) }
      let index = try PDFTemplateIndex(histories: histories)
      let fingerprint = PDFTemplateFingerprint.make(
        from: inspection,
        workspaceKey: Data("pdf-editor-native-template-workspace".utf8),
        includeExactSourceDigest: false)
      templateIndexMatch = try PDFTemplateIndexQuery.query(
        index: index,
        fingerprint: fingerprint,
        sourceDigest: inspection.source.sha256)
      let state = templateIndexMatch?.state.rawValue ?? "noMatch"
      statusMessage = "Local template search: \(state). Review the evidence before loading a revision."
    } catch {
      templateIndexMatch = nil
      alertMessage = "Could not search the encrypted local template index: \(error.localizedDescription)"
    }
  }

  var selectedField: NativeField? {
    guard let selectedFieldID else { return nil }
    return inspection?.fields.first { $0.id == selectedFieldID }
  }

  var selectedCandidate: RegionCandidate? {
    guard let selectedCandidateID else { return nil }
    return inspection?.candidates.first { $0.id == selectedCandidateID }
  }

  var selectedSearchMatch: SearchMatch? {
    guard let index = selectedSearchMatchIndex,
      index >= 0,
      index < searchMatches.count
    else { return nil }
    return searchMatches[index]
  }

  var canClearSearch: Bool {
    !searchQuery.isEmpty || !searchMatches.isEmpty
  }

  var selectedPageLabel: String {
    inspection?.pages[safe: selectedPageIndex]?.pageLabel ?? "\(selectedPageIndex + 1)"
  }

  var currentPageCount: Int {
    inspection?.pages.count ?? 0
  }

  var canUndo: Bool { !operations.isEmpty }

  var canRedo: Bool { !redoEntries.isEmpty }

  /// A session is dirty when it has a live source and operations that have
  /// not been committed back to the source file. Export Copy is intentionally
  /// separate from this predicate because it does not replace the source.
  var isDirty: Bool {
    liveDocument != nil && !operations.isEmpty
  }

  var hasUnexportedChanges: Bool { isDirty }

  func lifecycleDecision(for action: LifecycleAction) -> LifecycleDecisionInfo {
    LifecycleDecisionInfo(
      action: action,
      hasDocument: liveDocument != nil,
      isDirty: isDirty,
      hasRecoverableSession: hasSavedSession,
      canExportChanges: canExportCurrentOperations,
      disposition: isDirty ? .confirmBeforeDiscardingChanges : .proceed
    )
  }

  var canExportCurrentOperations: Bool {
    guard inspection != nil else { return false }
    return operations.allSatisfy { operation in
      permissionRequirements(for: operation).allSatisfy {
        permissionIsGranted($0)
      }
    }
  }

  // Compatibility names for the native command surface. Keeping these as
  // model-owned actions prevents menus from maintaining a second history.
  func reset() { resetDocument() }

  func undo() { PerformanceTelemetry.shared.measureUndo { undoLastEdit() } }

  func redo() { PerformanceTelemetry.shared.measureRedo { redoLastEdit() } }

  func goToPage(_ index: Int) {
    jumpToPage(index)
  }

  func goToFirstPage() {
    goToPage(0)
  }

  func goToPreviousPage() {
    goToPage(selectedPageIndex - 1)
  }

  func goToNextPage() {
    goToPage(selectedPageIndex + 1)
  }

  func goToLastPage() {
    goToPage(max(0, currentPageCount - 1))
  }

  func setScaleMode(_ mode: ReaderScaleMode) {
    setReaderScaleMode(mode)
  }

  func setActualSize() {
    setReaderScaleMode(.zoom)
    setZoom(1.0)
  }

  func setFitPage() {
    setReaderScaleMode(.fitPage)
  }

  func setFitWidth() {
    setReaderScaleMode(.fitWidth)
  }

  /// Typed entry point for the standard Find command. The shell can provide
  /// a query when it owns the field, while the model remains the sole search
  /// authority and preserves the selected hit when possible.
  func routeSearchCommand(query: String? = nil) {
    if let query {
      searchQuery = query
    }
    if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      statusMessage = "Search is ready."
      return
    }
    runSearch()
  }

  func routeNextSearchCommand() {
    selectNextSearchMatch()
  }

  func routePreviousSearchCommand() {
    selectPreviousSearchMatch()
  }

  func open(url: URL, password: String? = nil) {
    cancelViewStateAutosave()
    do {
      let hasSecurityScope = url.startAccessingSecurityScopedResource()
      defer {
        if hasSecurityScope {
          url.stopAccessingSecurityScopedResource()
        }
      }
      let nextInspection = try provider.inspect(url: url, password: password)
      let data = try Data(contentsOf: url, options: [.mappedIfSafe])
      guard let document = PDFDocument(data: data) else {
        throw PDFEditorError.cannotOpen(url.lastPathComponent)
      }
      if document.isLocked, let password {
        _ = document.unlock(withPassword: password)
      }

      inspection = nextInspection
      replaceLiveDocument(document)
      sourceURL = url
      cachedSourceData = data
      let builtPreflight = PDFPreflightBuilder.build(
        inspection: nextInspection,
        data: data,
        provider: PDFProviderDescriptor(
          id: "pdfkit",
          version: ProcessInfo.processInfo.operatingSystemVersionString,
          platform: "macOS",
          capabilities: ["read-only-preflight", "metadata-presence", "embedded-data-counts", "network-boundary-counts", "bounded-token-scan"]))
      do {
        try PDFPreflightValidator.validate(
          builtPreflight,
          expectedSourceDigest: nextInspection.source.sha256)
        preflightReport = builtPreflight
      } catch {
        preflightReport = nil
        statusMessage = "Opened the PDF, but the read-only privacy preflight is unknown: \(error.localizedDescription)"
      }
      ocrProcessedPageIndices = []
      operations = []
      replayCheckpoints = []
      operationViewStates = []
      redoEntries = []
      inMemoryRecoverySnapshot = nil
      lastActionDenial = nil
      selectedPageIndex = 0
      selectedFieldID = nil
      selectedCandidateID = nil
      isManualPlacementMode = false
      manualTextPlacement = nil
      isManualTextSheetPresented = false
      manualTextDraft = ""
      selectedSearchMatchIndex = nil
      searchQuery = ""
      searchMatches = []
      templateContract = nil
      templateRevisionHistory = nil
      templateCompletionProposal = nil
      templateValueDrafts = [:]
      templateLearningEvents = []
      pendingValidatedTemplateRevision = nil
      lastAppliedTemplateCompletion = nil
      templateCompletionOperationIDs = []
      templateRevisionDiff = nil
      exportReport = nil
      passwordAttempt = ""
      isPasswordSheetPresented = false
      pageJumpInput = ""
      currentSessionID = UUID()
      hasSavedSession = false
      lastSessionInfo = nil

      // D-010: Reset mode on open unless user has opted into persistence.
      if !persistModeAcrossDocuments {
        editorMode = .read
      }
      isFillOfferVisible = false
      isSignatureSheetPresented = false
      pendingSignatureRegion = nil
      tabCursorIndex = 0

      refreshRecoveryDiscovery()
      if !restoreDurableRecovery(for: nextInspection.source.sha256) {
        hasSavedSession = false
        lastSessionInfo = nil
        statusMessage = "Opened \(url.lastPathComponent)"
      }
      // After setting status, offer fill chip if the document has editable regions.
      showFillOfferIfNeeded()
    } catch {
      switch error {
      case PDFEditorError.passwordRequired:
        passwordPendingURL = url
        passwordAttempt = ""
        isPasswordSheetPresented = true
      case PDFEditorError.passwordIncorrect:
        passwordPendingURL = url
        passwordAttempt = ""
        statusMessage = "Wrong password. Try again."
        isPasswordSheetPresented = true
      default:
        alertMessage = error.localizedDescription
      }
    }
  }

  func submitPassword() {
    guard let url = passwordPendingURL else { return }
    let attempted = passwordAttempt
    passwordAttempt = ""
    isPasswordSheetPresented = false
    open(url: url, password: attempted)
  }

  func dismissPasswordPrompt() {
    passwordPendingURL = nil
    passwordAttempt = ""
    isPasswordSheetPresented = false
  }

  func resetDocument() {
    cancelViewStateAutosave()
    discardCurrentRecovery()
    inspection = nil
    replaceLiveDocument(nil)
    sourceURL = nil
    cachedSourceData = nil
    preflightReport = nil
    ocrProcessedPageIndices = []
    operations = []
    replayCheckpoints = []
    operationViewStates = []
    redoEntries = []
    inMemoryRecoverySnapshot = nil
    lastActionDenial = nil
    selectedPageIndex = 0
    selectedFieldID = nil
    selectedCandidateID = nil
    selectedSearchMatchIndex = nil
    searchQuery = ""
    searchMatches = []
    templateContract = nil
    templateRevisionHistory = nil
    templateCompletionProposal = nil
    templateValueDrafts = [:]
    templateLearningEvents = []
    pendingValidatedTemplateRevision = nil
    lastAppliedTemplateCompletion = nil
    templateCompletionOperationIDs = []
    templateRevisionDiff = nil
    exportReport = nil
    currentSessionID = nil
    hasSavedSession = false
    lastPersistedViewStateDigest = nil
    lastSessionInfo = nil
    statusMessage = "New document"
    resetReaderState()
  }

  func currentValue(for field: NativeField) -> String {
    guard let page = liveDocument?.page(at: field.pageIndex) else { return field.value ?? "" }
    let widgets = page.annotations.filter {
      $0.type == "Widget"
        && $0.fieldName == field.name
    }
    if field.kind == .button {
      return widgets.first(where: { $0.buttonWidgetState == PDFWidgetCellState(rawValue: 1) })?
        .buttonWidgetStateString ?? ""
    }
    return widgets.first?.widgetStringValue ?? field.value ?? ""
  }

  func buttonOptions(for field: NativeField) -> [String] {
    guard let page = liveDocument?.page(at: field.pageIndex) else { return [] }
    var seen = Set<String>()
    return page.annotations
      .filter { $0.type == "Widget" && $0.fieldName == field.name }
      .compactMap { annotation -> String? in
        let value = annotation.buttonWidgetStateString.trimmingCharacters(
          in: .whitespacesAndNewlines)
        guard !value.isEmpty, seen.insert(value).inserted else { return nil }
        return value
      }
  }

  func applyFieldValue(_ value: String) {
    guard requirePermission(.modify, action: "Edit form field") else { return }
    guard let field = selectedField, let liveDocument else { return }
    guard field.kind != .signature else {
      alertMessage = "Signature fields are not edited in this lane."
      return
    }
    let operation = EditOperation(
      pageIndex: field.pageIndex,
      targetID: field.name,
      kind: .nativeFieldValue,
      value: value,
      bounds: field.bounds,
      previousValue: currentValue(for: field),
      sourceDigest: inspection?.source.sha256,
      coordinate: PDFPageRegion(pageIndex: field.pageIndex, rect: field.bounds),
      payload: .text(value)
    )
    do {
      try provider.apply(operation, to: liveDocument)
      recordAppliedOperation(operation)
      statusMessage = "Applied a reversible native-field edit."
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  func applyOverlay(_ value: String) {
    guard requirePermission(.modify, action: "Add text overlay"),
      requirePermission(.addAnnotations, action: "Add text overlay")
    else { return }
    guard let candidate = selectedCandidate else { return }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if candidate.entryMode == .characterGrid {
      guard !candidate.memberBounds.isEmpty else {
        statusMessage =
          "This character grid has no cell geometry. Use manual placement or rerun inspection."
        return
      }
      guard Array(normalized).count <= candidate.memberBounds.count else {
        statusMessage = "The value is longer than the detected character grid."
        return
      }
    }
    applyTextOverlay(
      value: normalized,
      pageIndex: candidate.pageIndex,
      bounds: candidate.bounds,
      candidateID: candidate.id,
      markCandidateConfirmed: true,
      payload: candidate.entryMode == .characterGrid
        ? .characterGrid(text: normalized, cells: candidate.memberBounds)
        : .text(normalized)
    )
  }

  func applyStaticChoiceMark(cellIndex: Int) {
    guard requirePermission(.modify, action: "Add choice mark"),
      requirePermission(.addAnnotations, action: "Add choice mark")
    else { return }
    guard let candidate = selectedCandidate,
      [.checkbox, .radioGroup].contains(candidate.entryMode),
      candidate.memberBounds.indices.contains(cellIndex)
    else {
      statusMessage = "Choose one detected choice cell before marking it."
      return
    }
    let cell = candidate.memberBounds[cellIndex]
    applyTextOverlay(
      value: "X",
      pageIndex: candidate.pageIndex,
      bounds: cell,
      candidateID: candidate.id,
      markCandidateConfirmed: true,
      payload: .choiceMark(cell: cell)
    )
  }

  func synthesizeNativeField() {
    guard requirePermission(.modify, action: "Create native field"),
      requirePermission(.addAnnotations, action: "Create native field")
    else { return }
    guard let candidate = selectedCandidate,
      candidate.isDirectlyEditable,
      let liveDocument
    else {
      statusMessage = "Only reviewed text-like regions can become native fields."
      return
    }
    let fieldName = "static_\(candidate.id.uuidString.replacingOccurrences(of: "-", with: "_"))"
    let operation = EditOperation(
      pageIndex: candidate.pageIndex,
      targetID: fieldName,
      kind: .synthesizeNativeField,
      value: "",
      bounds: candidate.bounds,
      candidateID: candidate.id,
      sourceDigest: inspection?.source.sha256,
      coordinate: PDFPageRegion(pageIndex: candidate.pageIndex, rect: candidate.bounds),
      payload: .nativeField(fieldType: candidate.suggestedFieldType ?? .text)
    )
    do {
      try provider.apply(operation, to: liveDocument)
      recordAppliedOperation(operation)
      updateCandidate(candidate.id, status: .confirmed)
      statusMessage =
        "Created a reviewed native text field overlay. Export will preserve the static page and reopen the new field."
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  func applyManualText() {
    guard requirePermission(.modify, action: "Place manual text"),
      requirePermission(.addAnnotations, action: "Place manual text")
    else { return }
    guard let placement = manualTextPlacement else { return }
    let value = manualTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
      statusMessage = "Enter text before placing it."
      return
    }
    applyTextOverlay(
      value: value,
      pageIndex: placement.pageIndex,
      bounds: placement.bounds,
      candidateID: nil,
      markCandidateConfirmed: false,
      payload: .text(value)
    )
    manualTextPlacement = nil
    manualTextDraft = ""
    isManualTextSheetPresented = false
  }

  func beginManualTextPlacement() {
    guard requirePermission(.modify, action: "Place manual text"),
      requirePermission(.addAnnotations, action: "Place manual text")
    else { return }
    guard liveDocument != nil else {
      statusMessage = "Open a PDF before placing text."
      return
    }
    selectedCandidateID = nil
    selectedFieldID = nil
    manualTextPlacement = nil
    isManualPlacementMode = true
    statusMessage = "Click the document where the new text should begin."
  }

  func cancelManualTextPlacement() {
    isManualPlacementMode = false
    manualTextPlacement = nil
    manualTextDraft = ""
    isManualTextSheetPresented = false
    statusMessage = "Manual text placement cancelled."
  }

  func receiveManualPlacement(pageIndex: Int, point: CGPoint) {
    guard isManualPlacementMode else { return }
    receiveTextPlacement(pageIndex: pageIndex, point: point)
  }

  /// Double-click placement is the direct-on-page path. It uses the same
  /// page-space bounds and reversible overlay operation as toolbar placement.
  func beginDirectTextPlacement(pageIndex: Int, point: CGPoint) {
    guard requirePermission(.modify, action: "Place manual text"),
      requirePermission(.addAnnotations, action: "Place manual text")
    else { return }
    guard liveDocument != nil else {
      statusMessage = "Open a PDF before placing text."
      return
    }
    selectedCandidateID = nil
    selectedFieldID = nil
    receiveTextPlacement(pageIndex: pageIndex, point: point)
  }

  private func receiveTextPlacement(pageIndex: Int, point: CGPoint) {
    guard let page = liveDocument?.page(at: pageIndex) else { return }
    let pageBounds = page.bounds(for: .cropBox)
    let width = min(180.0, max(80.0, pageBounds.width - 16.0))
    let height = min(28.0, max(18.0, pageBounds.height - 16.0))
    let x = min(max(point.x, pageBounds.minX + 8.0), pageBounds.maxX - width - 8.0)
    let y = min(max(point.y, pageBounds.minY + 8.0), pageBounds.maxY - height - 8.0)
    manualTextPlacement = ManualTextPlacement(
      pageIndex: pageIndex,
      bounds: PDFRect(x: x, y: y, width: width, height: height)
    )
    isManualPlacementMode = false
    manualTextDraft = ""
    isManualTextSheetPresented = true
    statusMessage = "Enter the text for the selected document area."
  }

  func rejectSelectedCandidate() {
    guard let candidate = selectedCandidate else { return }
    updateCandidate(candidate.id, status: .rejected)
    selectedCandidateID = nil
    statusMessage = "Dismissed the suggested area. The source PDF was not changed."
  }

  func restoreCandidate(_ candidateID: UUID) {
    updateCandidate(candidateID, status: .suggested)
    statusMessage = "Restored the suggested area for review."
  }

  private func applyTextOverlay(
    value: String,
    pageIndex: Int,
    bounds: PDFRect,
    candidateID: UUID?,
    markCandidateConfirmed: Bool,
    payload: EditPayload
  ) {
    guard requirePermission(.addAnnotations, action: "Add text overlay") else { return }
    guard let liveDocument else { return }
    let operation = EditOperation(
      pageIndex: pageIndex,
      kind: .overlayText,
      value: value,
      bounds: bounds,
      candidateID: candidateID,
      sourceDigest: inspection?.source.sha256,
      coordinate: PDFPageRegion(pageIndex: pageIndex, rect: bounds),
      payload: payload
    )
    do {
      try provider.apply(operation, to: liveDocument)
      recordAppliedOperation(operation)
      if markCandidateConfirmed, let candidateID {
        updateCandidate(candidateID, status: .confirmed)
      }
      if case .characterGrid = payload {
        statusMessage = "Placed one glyph per detected character cell. The edit remains reversible."
      } else {
        statusMessage =
          candidateID == nil
            ? "Added reversible text to the document preview."
            : "Added reviewed text. It remains an overlay, not a native PDF field."
      }
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  private func updateCandidate(_ candidateID: UUID, status: CandidateStatus) {
    guard let current = inspection else { return }
    let candidates = current.candidates.map { candidate in
      guard candidate.id == candidateID else { return candidate }
      var updated = candidate
      updated.status = status
      return updated
    }
    inspection = DocumentInspection(
      source: current.source,
      pages: current.pages,
      fields: current.fields,
      candidates: candidates,
      warnings: current.warnings,
      links: current.links,
      outlines: current.outlines,
      metadata: current.metadata,
      permissions: current.permissions,
      attachments: current.attachments,
      accessibility: current.accessibility,
      security: current.security
    )
  }

  var activeCandidates: [RegionCandidate] {
    inspection?.candidates.filter { $0.status != .rejected } ?? []
  }

  var dismissedCandidates: [RegionCandidate] {
    inspection?.candidates.filter { $0.status == .rejected } ?? []
  }

  // MARK: - Editor mode (D-010)

  /// All editable regions in reading order (top-to-bottom, left-to-right, page-by-page).
  /// Native fields appear first on each page, then active candidates.
  var editableRegions: [EditableRegionRef] {
    guard let inspection else { return [] }
    var regions: [EditableRegionRef] = []
    for pageIndex in 0..<inspection.pages.count {
      let fields = inspection.fields
        .filter { $0.pageIndex == pageIndex && $0.kind != .signature }
        .sorted { $0.bounds.y > $1.bounds.y } // PDF lower-left: descending y = top first
      for field in fields {
        regions.append(EditableRegionRef(
          kind: .nativeField(id: field.id),
          pageIndex: pageIndex,
          bounds: field.bounds
        ))
      }
      let candidates = activeCandidates
        .filter { $0.pageIndex == pageIndex && $0.entryMode != .signature && $0.isDirectlyEditable }
        .sorted { $0.bounds.y > $1.bounds.y }
      for candidate in candidates {
        regions.append(EditableRegionRef(
          kind: .candidate(id: candidate.id),
          pageIndex: pageIndex,
          bounds: candidate.bounds
        ))
      }
    }
    return regions
  }

  /// FillHighlight descriptors for the PDFKitView overlay layer.
  /// Empty unless editorMode is .fill or .sign.
  var fillHighlightRegions: [FillHighlight] {
    guard let inspection, editorMode == .fill || editorMode == .sign else { return [] }
    var highlights: [FillHighlight] = []

    if editorMode == .fill {
      for field in inspection.fields {
        let isFocused = selectedFieldID == field.id
        let state: FillHighlight.State = isFocused ? .focused : .nativeField
        highlights.append(FillHighlight(
          id: "field:\(field.id)",
          pageIndex: field.pageIndex,
          bounds: field.bounds,
          state: state,
          label: field.name
        ))
      }
      for candidate in activeCandidates {
        let isFocused = selectedCandidateID == candidate.id
        let isFilled = candidate.status == .confirmed
        let state: FillHighlight.State
        if isFocused { state = .focused }
        else if candidate.entryMode == .signature { state = .signatureRegion }
        else if isFilled { state = .candidateFilled }
        else { state = .candidateUnfilled }
        highlights.append(FillHighlight(
          id: "candidate:\(candidate.id.uuidString)",
          pageIndex: candidate.pageIndex,
          bounds: candidate.bounds,
          state: state,
          label: candidate.labelText
        ))
      }
    } else {
      // Sign mode: only signature candidates
      for candidate in activeCandidates where candidate.entryMode == .signature {
        let isFocused = selectedCandidateID == candidate.id
        highlights.append(FillHighlight(
          id: "sig:\(candidate.id.uuidString)",
          pageIndex: candidate.pageIndex,
          bounds: candidate.bounds,
          state: isFocused ? .focused : .signatureRegion,
          label: candidate.labelText ?? "Signature"
        ))
      }
    }
    return highlights
  }

  /// Fill progress as a 0..1 fraction. Nil when there is nothing to fill.
  var fillProgress: Double? {
    guard let inspection else { return nil }
    let totalFields = inspection.fields.filter { $0.kind != .signature }.count
    let totalCandidates = activeCandidates.filter {
      $0.entryMode != .signature && $0.isDirectlyEditable
    }.count
    let total = totalFields + totalCandidates
    guard total > 0 else { return nil }
    let filledFields = inspection.fields.filter { field in
      field.kind != .signature && (currentValue(for: field)).isEmpty == false
    }.count
    let filledCandidates = activeCandidates.filter { $0.status == .confirmed }.count
    let filled = filledFields + filledCandidates
    return Double(filled) / Double(total)
  }

  /// Human-readable "3 / 9 fields filled" string. Nil when nothing to fill.
  var fillProgressLabel: String? {
    guard let inspection else { return nil }
    let totalFields = inspection.fields.filter { $0.kind != .signature }.count
    let totalCandidates = activeCandidates.filter {
      $0.entryMode != .signature && $0.isDirectlyEditable
    }.count
    let total = totalFields + totalCandidates
    guard total > 0 else { return nil }
    let filledFields = inspection.fields.filter { field in
      field.kind != .signature && !currentValue(for: field).isEmpty
    }.count
    let filledCandidates = activeCandidates.filter { $0.status == .confirmed }.count
    let filled = filledFields + filledCandidates
    return "\(filled) / \(total) fields filled"
  }

  /// Next unfilled region in reading order from the current tab cursor.
  var nextUnfilledRegion: EditableRegionRef? {
    let regions = editableRegions.filter { region in
      switch region.kind {
      case .nativeField(let id):
        guard let field = inspection?.fields.first(where: { $0.id == id }) else { return false }
        return currentValue(for: field).isEmpty
      case .candidate(let id):
        return activeCandidates.first(where: { $0.id == id })?.status != .confirmed
      }
    }
    guard !regions.isEmpty else { return nil }
    let next = tabCursorIndex % regions.count
    return regions[safe: next]
  }

  /// Set editor mode. Resets tap inference and status appropriately.
  func setEditorMode(_ mode: EditorMode) {
    editorMode = mode
    isFillOfferVisible = false
    tabCursorIndex = 0
    switch mode {
    case .read:
      statusMessage = "Reading mode — no edits will be applied."
    case .fill:
      let label = fillProgressLabel ?? "No fillable fields detected."
      statusMessage = "Fill mode — \(label)"
    case .sign:
      let count = activeCandidates.filter { $0.entryMode == .signature }.count
      statusMessage = count > 0
        ? "Sign mode — \(count) signature region\(count == 1 ? "" : "s") detected."
        : "Sign mode — click anywhere to place a signature."
    case .edit:
      statusMessage = "Edit mode — all authoring tools available."
    }
  }

  /// Advance tab focus to the next unfilled region (Tab / Return handler).
  func advanceToNextField() {
    guard editorMode == .fill else { return }
    let regions = editableRegions
    guard !regions.isEmpty else { return }
    tabCursorIndex = (tabCursorIndex + 1) % regions.count
    let region = regions[tabCursorIndex % regions.count]
    activateRegion(region)
  }

  /// Retreat tab focus to the previous unfilled region (Shift+Tab).
  func retreatToPreviousField() {
    guard editorMode == .fill else { return }
    let regions = editableRegions
    guard !regions.isEmpty else { return }
    tabCursorIndex = (tabCursorIndex - 1 + regions.count) % regions.count
    let region = regions[tabCursorIndex]
    activateRegion(region)
  }

  private func activateRegion(_ region: EditableRegionRef) {
    switch region.kind {
    case .nativeField(let id):
      selectedFieldID = id
      selectedCandidateID = nil
      jumpToPage(region.pageIndex)
    case .candidate(let id):
      selectedCandidateID = id
      selectedFieldID = nil
      jumpToPage(region.pageIndex)
    }
  }

  /// Intent-inference router: called when the user taps a point on a page.
  /// In Read mode, infers likely intent and offers the appropriate mode.
  /// In Fill/Sign/Edit mode, routes to the correct action for what was tapped.
  func handlePageTap(pageIndex: Int, point: CGPoint) {
    guard liveDocument != nil, let inspection else { return }

    // Check if the tap hit a native field
    if let field = inspection.fields.first(where: { field in
      field.pageIndex == pageIndex && field.bounds.cgRect.contains(point)
    }) {
      switch editorMode {
      case .read:
        // Soft-enter fill mode for this field
        setEditorMode(.fill)
        selectedFieldID = field.id
        selectedCandidateID = nil
        isFillOfferVisible = true
      case .fill, .edit:
        selectedFieldID = field.id
        selectedCandidateID = nil
      case .sign:
        break // Signature mode ignores non-signature taps
      }
      return
    }

    // Check if the tap hit a candidate region
    if let candidate = activeCandidates.first(where: { c in
      c.pageIndex == pageIndex && c.bounds.cgRect.contains(point)
    }) {
      if candidate.entryMode == .signature {
        // Always route to sign sheet for signature candidates
        beginSign(for: candidate)
        return
      }
      switch editorMode {
      case .read:
        setEditorMode(.fill)
        selectedCandidateID = candidate.id
        selectedFieldID = nil
        isFillOfferVisible = true
      case .fill, .edit:
        selectedCandidateID = candidate.id
        selectedFieldID = nil
      case .sign:
        break
      }
      return
    }

    // Tapped free space
    switch editorMode {
    case .edit:
      // Edit mode: begin text placement (existing path)
      beginDirectTextPlacement(pageIndex: pageIndex, point: point)
    case .sign:
      // Free placement signature
      beginSign(for: nil)
    case .read, .fill:
      break // No action on free-space tap in read/fill
    }
  }

  /// Show the fill offer chip in the status bar (called after document open).
  func showFillOfferIfNeeded() {
    guard let inspection else { return }
    let hasFields = !inspection.fields.isEmpty
    let hasCandidates = !activeCandidates.isEmpty
    if hasFields || hasCandidates {
      isFillOfferVisible = true
      let count = inspection.fields.count + activeCandidates.count
      statusMessage = "This document has \(count) fillable area\(count == 1 ? "" : "s"). Tap Fill to start."
    }
  }

  /// Begin sign workflow for a specific candidate region (or nil for free placement).
  func beginSign(for candidate: RegionCandidate?) {
    pendingSignatureRegion = candidate
    if editorMode != .sign {
      setEditorMode(.sign)
    }
    isSignatureSheetPresented = true
  }

  /// Apply a signature image to the pending region or a free-placed location.
  func applySignature(_ imageData: Data, to bounds: PDFRect, on pageIndex: Int) {
    guard requirePermission(.modify, action: "Place signature"),
      requirePermission(.addAnnotations, action: "Place signature")
    else { return }
    guard let liveDocument else { return }

    let operation = EditOperation(
      pageIndex: pageIndex,
      kind: .overlayImage,
      value: "signature",
      bounds: bounds,
      candidateID: pendingSignatureRegion?.id,
      sourceDigest: inspection?.source.sha256,
      coordinate: PDFPageRegion(pageIndex: pageIndex, rect: bounds),
      payload: .asset(assetID: "signature-\(UUID().uuidString)", mimeType: "image/png"),
      reversible: true,
      destructive: false
    )
    do {
      try provider.apply(operation, to: liveDocument)
      recordAppliedOperation(operation)
      if let candidate = pendingSignatureRegion {
        updateCandidate(candidate.id, status: .confirmed)
      }
      isSignatureSheetPresented = false
      pendingSignatureRegion = nil
      statusMessage = "Signature placed. The edit is reversible with Undo."
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  private func requirePermission(_ requirement: PermissionRequirement, action: String) -> Bool {
    guard let permissions = inspection?.permissions else {
      denyAction(
        action: action,
        requirement: nil,
        message: "Cannot \(action.lowercased()): open a PDF before using this action."
      )
      return false
    }

    guard permissionIsGranted(requirement, permissions: permissions) else {
      denyAction(
        action: action,
        requirement: requirement,
        message: "Cannot \(action.lowercased()): this PDF's permissions do not allow \(requirement.rawValue)."
      )
      return false
    }
    lastActionDenial = nil
    return true
  }

  private func permissionIsGranted(
    _ requirement: PermissionRequirement,
    permissions: PDFPermissionsSummary? = nil
  ) -> Bool {
    guard let permissions = permissions ?? inspection?.permissions else { return false }
    switch requirement {
    case .copy:
      return permissions.canCopy
    case .modify:
      return permissions.canModify
    case .addAnnotations:
      return permissions.canAddAnnotations
    }
  }

  private func ensureExportPermission() -> Bool {
    guard inspection != nil else {
      denyAction(
        action: "Export copy",
        requirement: nil,
        message: "Cannot export a copy: open a PDF before exporting."
      )
      return false
    }
    for operation in operations {
      for requirement in permissionRequirements(for: operation) {
        guard requirePermission(requirement, action: "Export copy") else { return false }
      }
    }
    return true
  }

  private func denyAction(
    action: String,
    requirement: PermissionRequirement?,
    message: String
  ) {
    let denial = ActionDenial(action: action, requirement: requirement, message: message)
    lastActionDenial = denial
    statusMessage = message
    alertMessage = message
  }

  private func recordAppliedOperation(_ operation: EditOperation) {
    invalidatePendingValidatedRevision()
    let viewStateAfter = captureViewState()
    let viewStateBefore = operationViewStates.last?.after ?? viewStateAfter
    searchMatches = []
    selectedSearchMatchIndex = nil
    operations.append(operation)
    advanceDocumentProjectionRevision()
    operationViewStates.append(
      OperationViewState(before: viewStateBefore, after: viewStateAfter))
    redoEntries.removeAll()
    recordReplayCheckpointIfNeeded()
    autoSaveSession()
    refreshInMemoryRecoverySnapshot()
  }

  private func invalidatePendingValidatedRevision() {
    guard pendingValidatedTemplateRevision != nil else { return }
    pendingValidatedTemplateRevision = nil
    templateRevisionDiff = nil
    templateLearningEvents = []
    statusMessage = "The pending template revision was withdrawn because the edit ledger changed after validation."
  }

  private func seedViewStateHistoryForLoadedOperations() {
    let state = captureViewState()
    operationViewStates = operations.map { _ in
      OperationViewState(before: state, after: state)
    }
  }

  private func captureViewState() -> ViewStateSnapshot {
    ViewStateSnapshot(
      selectedPageIndex: selectedPageIndex,
      selectedFieldID: selectedFieldID,
      selectedCandidateID: selectedCandidateID,
      selectedSearchMatchIndex: selectedSearchMatchIndex,
      readerViewMode: readerViewMode,
      readerScaleMode: readerScaleMode,
      readerZoom: readerZoom,
      readerRotation: readerRotation
    )
  }

  private func restoreViewState(_ state: ViewStateSnapshot) {
    selectedPageIndex = min(max(state.selectedPageIndex, 0), max(0, currentPageCount - 1))
    selectedFieldID = state.selectedFieldID
    selectedCandidateID = state.selectedCandidateID
    selectedSearchMatchIndex = state.selectedSearchMatchIndex
    readerViewMode = state.readerViewMode
    readerScaleMode = state.readerScaleMode
    readerZoom = state.readerZoom
    readerRotation = state.readerRotation
  }

  private func operationLedgerDigest() -> String {
    RecoveryLedgerIdentity.operationDigest(operations)
  }

  private func advanceDocumentProjectionRevision() {
    precondition(
      documentProjectionRevision < UInt64.max,
      "Document projection revision exhausted its representable range."
    )
    documentProjectionRevision += 1
  }

  private func replaceLiveDocument(_ document: PDFDocument?) {
    liveDocument = document
    advanceDocumentProjectionRevision()
  }

  private func refreshInMemoryRecoverySnapshot() {
    guard let sessionID = currentSessionID,
      let sourceDigest = inspection?.source.sha256
    else {
      inMemoryRecoverySnapshot = nil
      return
    }
    inMemoryRecoverySnapshot = InMemoryRecoverySnapshot(
      sessionID: sessionID,
      sourceDigest: sourceDigest,
      operationLedgerDigest: operationLedgerDigest(),
      operationCount: operations.count,
      selectedPageIndex: selectedPageIndex,
      selectedFieldID: selectedFieldID,
      selectedCandidateID: selectedCandidateID,
      selectedSearchMatchID: selectedSearchMatch?.id,
      readerViewMode: readerViewMode.rawValue,
      readerScaleMode: readerScaleMode.rawValue,
      readerZoom: readerZoom,
      readerRotation: readerRotation,
      capturedAt: Date()
    )
  }

  /// Returns a lightweight view/history checkpoint. It never stores PDF bytes
  /// or edit values; the source digest is the binding for a future
  /// DocumentSession recovery adapter.
  func captureInMemoryRecoverySnapshot() -> InMemoryRecoverySnapshot? {
    refreshInMemoryRecoverySnapshot()
    return inMemoryRecoverySnapshot
  }

  @discardableResult
  func restoreInMemoryRecoverySnapshot(_ snapshot: InMemoryRecoverySnapshot) -> Bool {
    guard currentSessionID == snapshot.sessionID else {
      statusMessage = "Recovery snapshot belongs to a different editing session."
      return false
    }
    guard inspection?.source.sha256 == snapshot.sourceDigest else {
      statusMessage = "Recovery snapshot belongs to a different PDF source."
      return false
    }
    guard operations.count == snapshot.operationCount,
      operationLedgerDigest() == snapshot.operationLedgerDigest
    else {
      statusMessage = "Recovery snapshot belongs to a different edit history."
      return false
    }
    if let selectedFieldID = snapshot.selectedFieldID,
      inspection?.fields.contains(where: { $0.id == selectedFieldID }) != true
    {
      statusMessage = "Recovery snapshot references a field that is no longer available."
      return false
    }
    if let selectedCandidateID = snapshot.selectedCandidateID,
      inspection?.candidates.contains(where: { $0.id == selectedCandidateID }) != true
    {
      statusMessage = "Recovery snapshot references a candidate that is no longer available."
      return false
    }
    selectedPageIndex = min(max(snapshot.selectedPageIndex, 0), max(0, currentPageCount - 1))
    selectedFieldID = snapshot.selectedFieldID
    selectedCandidateID = snapshot.selectedCandidateID
    if let index = searchMatches.firstIndex(where: { $0.id == snapshot.selectedSearchMatchID }) {
      selectedSearchMatchIndex = index
    } else {
      selectedSearchMatchIndex = nil
    }
    if let mode = ReaderViewMode(rawValue: snapshot.readerViewMode) {
      readerViewMode = mode
    }
    if let mode = ReaderScaleMode(rawValue: snapshot.readerScaleMode) {
      readerScaleMode = mode
    }
    readerZoom = max(0.25, min(3.0, snapshot.readerZoom))
    readerRotation = ((snapshot.readerRotation % 360) + 360) % 360
    statusMessage = "Restored the in-memory document view checkpoint."
    refreshInMemoryRecoverySnapshot()
    return true
  }

  private func recordReplayCheckpointIfNeeded() {
    guard operations.count > 0,
      operations.count % Self.replayCheckpointInterval == 0,
      let liveDocument,
      let snapshot = liveDocument.copy() as? PDFDocument
    else {
      return
    }

    replayCheckpoints.append(
      ReplayCheckpoint(operationCount: operations.count, document: snapshot))
    if replayCheckpoints.count > Self.maximumReplayCheckpoints {
      replayCheckpoints.removeFirst(replayCheckpoints.count - Self.maximumReplayCheckpoints)
    }
  }

  private func replayDocument(upTo operationCount: Int) throws
    -> (document: PDFDocument, usedCheckpoint: Bool)
  {
    try replayDocument(
      operations: operations,
      upTo: operationCount,
      checkpoints: replayCheckpoints,
      shouldCacheSourceData: true
    )
  }

  private func replayDocument(
    operations stagedOperations: [EditOperation],
    upTo operationCount: Int,
    checkpoints: [ReplayCheckpoint],
    shouldCacheSourceData: Bool
  ) throws -> (document: PDFDocument, usedCheckpoint: Bool) {
    guard operationCount >= 0, operationCount <= stagedOperations.count else {
      throw PDFEditorError.invalidOperation("The requested edit history position is invalid.")
    }

    for checkpoint in checkpoints.reversed()
    where checkpoint.operationCount <= operationCount {
      guard let restored = checkpoint.document.copy() as? PDFDocument else { continue }
      do {
        for operation in stagedOperations.dropFirst(checkpoint.operationCount)
          .prefix(operationCount - checkpoint.operationCount)
        {
          try provider.apply(operation, to: restored)
        }
        return (restored, true)
      } catch {
        // A stale or provider-invalid checkpoint is not an authority. Fall
        // back to the source replay path, which preserves the old behavior.
        continue
      }
    }

    let data: Data
    if let cached = cachedSourceData {
      data = cached
    } else if let sourceURL {
      data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
      if shouldCacheSourceData {
        cachedSourceData = data
      }
    } else {
      throw PDFEditorError.cannotOpen("The active PDF source is unavailable.")
    }
    guard let rebuilt = PDFDocument(data: data) else {
      throw PDFEditorError.cannotOpen(sourceURL?.lastPathComponent ?? "PDF")
    }
    for operation in stagedOperations.prefix(operationCount) {
      try provider.apply(operation, to: rebuilt)
    }
    return (rebuilt, false)
  }

  func undoLastEdit() {
    guard !operations.isEmpty else { return }
    searchMatches = []
    selectedSearchMatchIndex = nil
    let removedOperation = operations[operations.count - 1]
    let removedViewState = operationViewStates.last
    let targetOperationCount = operations.count - 1
    do {
      let replay = try replayDocument(upTo: targetOperationCount)
      replaceLiveDocument(replay.document)
      operations.removeLast()
      invalidatePendingValidatedRevision()
      if let removedViewState {
        operationViewStates.removeLast()
        redoEntries.append(
          RedoEntry(operation: removedOperation, viewStateAfter: removedViewState.after))
        restoreViewState(removedViewState.before)
      } else {
        redoEntries.append(RedoEntry(operation: removedOperation, viewStateAfter: captureViewState()))
      }
      replayCheckpoints.removeAll { $0.operationCount > operations.count }
      if let candidateID = removedOperation.candidateID {
        updateCandidate(candidateID, status: .suggested)
      }
      // Viewer rotation is derived UI state, not an edit operation. Reapply it
      // after restoring a source or checkpoint document.
      autoSaveSession()
      refreshInMemoryRecoverySnapshot()
      statusMessage = replay.usedCheckpoint
        ? "Removed the last edit and restored the preview from an in-memory checkpoint."
        : "Removed the last edit and rebuilt the preview from the cached source."
    } catch {
      alertMessage = "Undo could not rebuild the preview: \(error.localizedDescription)"
    }
  }

  private func permissionRequirements(for operation: EditOperation) -> [PermissionRequirement] {
    switch operation.kind {
    case .nativeFieldValue:
      return [.modify]
    case .textRunReplacement:
      return [.modify]
    case .overlayText, .synthesizeNativeField:
      return [.modify, .addAnnotations]
    case .overlayImage, .stamp, .annotation:
      return [.modify, .addAnnotations]
    case .pageTransform, .pageInsert, .pageDelete, .pageMove:
      return [.modify]
    case .flatten, .redactMark, .applyRedaction:
      return [.modify]
    case .metadata, .sanitize:
      return [.modify]
    }
  }

  func redoLastEdit() {
    guard let entry = redoEntries.last else { return }
    for requirement in permissionRequirements(for: entry.operation) {
      guard requirePermission(requirement, action: "Redo edit") else { return }
    }
    guard let liveDocument else {
      statusMessage = "Redo is unavailable because the active PDF preview is missing."
      return
    }

    do {
      let viewStateBefore = captureViewState()
      try provider.apply(entry.operation, to: liveDocument)
      advanceDocumentProjectionRevision()
      searchMatches = []
      selectedSearchMatchIndex = nil
      operations.append(entry.operation)
      invalidatePendingValidatedRevision()
      operationViewStates.append(
        OperationViewState(before: viewStateBefore, after: entry.viewStateAfter))
      redoEntries.removeLast()
      recordReplayCheckpointIfNeeded()
      restoreViewState(entry.viewStateAfter)
      if let candidateID = entry.operation.candidateID {
        updateCandidate(candidateID, status: .confirmed)
      }
      autoSaveSession()
      statusMessage = "Reapplied the previously undone edit."
      refreshInMemoryRecoverySnapshot()
    } catch {
      alertMessage = "Redo could not reapply the edit: \(error.localizedDescription)"
    }
  }

  func selectNextCandidate() {
    let candidates = activeCandidates
    guard !candidates.isEmpty else { return }
    let currentID = selectedCandidateID
    let currentIndex = candidates.firstIndex { $0.id == currentID } ?? -1
    let nextIndex = (currentIndex + 1) % candidates.count
    let next = candidates[nextIndex]
    selectedCandidateID = next.id
    selectedFieldID = nil
    jumpToPage(next.pageIndex)
    statusMessage =
      "Selected candidate \(nextIndex + 1) of \(candidates.count) (\(next.suggestedFieldType?.rawValue ?? "field"))"
  }

  func selectPreviousCandidate() {
    let candidates = activeCandidates
    guard !candidates.isEmpty else { return }
    let currentID = selectedCandidateID
    let currentIndex = candidates.firstIndex { $0.id == currentID } ?? 0
    let prevIndex = (currentIndex - 1 + candidates.count) % candidates.count
    let prev = candidates[prevIndex]
    selectedCandidateID = prev.id
    selectedFieldID = nil
    jumpToPage(prev.pageIndex)
    statusMessage =
      "Selected candidate \(prevIndex + 1) of \(candidates.count) (\(prev.suggestedFieldType?.rawValue ?? "field"))"
  }

  func runOCROnSelectedPage() {
    guard requirePermission(.copy, action: "Run OCR") else { return }
    guard let page = liveDocument?.page(at: selectedPageIndex),
      let pageSnapshot = inspection?.pages[safe: selectedPageIndex]
    else {
      statusMessage = "Select a valid page before running OCR."
      return
    }
    do {
      let ocrProvider = VisionOCRProvider()
      let observations = try ocrProvider.recognize(page: page, pageIndex: selectedPageIndex)
      guard !observations.isEmpty else {
        statusMessage = "No additional text recognized by OCR on page \(selectedPageIndex + 1)."
        return
      }
      let pageLines = observations.map {
        $0.toPageSpace(pageBounds: pageSnapshot.bounds, pageIndex: selectedPageIndex)
      }
      let ocrCandidates = StaticRegionDetector.detect(lines: pageLines)

      if let current = inspection {
        var existingCandidates = current.candidates
        for c in ocrCandidates {
          if !existingCandidates.contains(where: {
            $0.pageIndex == c.pageIndex && abs($0.bounds.x - c.bounds.x) < 10
              && abs($0.bounds.y - c.bounds.y) < 10
          }) {
            existingCandidates.append(c)
          }
        }
        inspection = DocumentInspection(
          source: current.source,
          pages: current.pages,
          fields: current.fields,
          candidates: existingCandidates,
          warnings: current.warnings,
          links: current.links,
          outlines: current.outlines,
          metadata: current.metadata,
          permissions: current.permissions,
          attachments: current.attachments,
          accessibility: current.accessibility,
          security: current.security
        )
        ocrProcessedPageIndices.insert(selectedPageIndex)
        statusMessage =
          "OCR recognized \(observations.count) text regions (\(ocrCandidates.count) candidate blanks)."
      }
    } catch {
      alertMessage = "OCR recognition error: \(error.localizedDescription)"
    }
  }

  func export() {
    guard let sourceURL else { return }
    guard ensureExportPermission() else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-filled.pdf"
    panel.begin { [weak self] response in
      guard response == .OK, let destination = panel.url else { return }
      self?.performExport(sourceURL: sourceURL, destination: destination)
    }
  }

  /// Commits reviewed redaction marks only when the active provider exposes a
  /// measured permanent-redaction implementation. The current PDFKit lane
  /// exposes neither the capability nor an implementation for
  /// `EditKind.applyRedaction`, so this action must remain a visible denial.
  func commitRedactions() {
    let markedOperations = operations.filter { $0.kind == .redactMark }
    guard !markedOperations.isEmpty else {
      denyAction(
        action: "Commit redactions",
        requirement: nil,
        message: "Cannot commit redactions: add at least one redaction mark first."
      )
      return
    }
    guard requirePermission(.modify, action: "Commit redactions") else { return }
    denyAction(
      action: "Commit redactions",
      requirement: nil,
      message: "Cannot commit redactions: the active PDFKit provider does not expose the explicit \(PDFCapabilityLane.permanentRedaction.rawValue) capability or an implementation for \(EditKind.applyRedaction.rawValue). The \(EditKind.redactMark.rawValue) entries remain reversible; no PDF export or document mutation was performed."
    )
  }

  func jumpToPage(_ index: Int) {
    jumpToPage(index, preservingSearchMatch: false)
  }

  private func jumpToPage(_ index: Int, preservingSearchMatch: Bool) {
    let clamped = min(max(index, 0), max(0, currentPageCount - 1))
    selectedPageIndex = clamped
    if !preservingSearchMatch {
      selectedSearchMatchIndex = nil
    }
    scheduleViewStateAutosave()
  }

  func runPageJump() {
    guard let index = Int(pageJumpInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      statusMessage = "Enter a valid page number."
      return
    }
    jumpToPage(index - 1)
  }

  func clearSearch() {
    searchQuery = ""
    searchMatches = []
    selectedSearchMatchIndex = nil
    scheduleViewStateAutosave()
  }

  func runSearch() {
    guard let document = liveDocument else {
      searchMatches = []
      selectedSearchMatchIndex = nil
      return
    }
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      searchMatches = []
      selectedSearchMatchIndex = nil
      return
    }
    guard requirePermission(.copy, action: "Search document text") else {
      searchMatches = []
      selectedSearchMatchIndex = nil
      return
    }

    let previousMatchID = selectedSearchMatch?.id

    var nextMatches: [SearchMatch] = []
    let needle = query.lowercased()
    for pageIndex in 0..<document.pageCount {
      guard let page = document.page(at: pageIndex), let pageText = page.string else { continue }
      let haystack = pageText.lowercased() as NSString
      guard haystack.length > 0 else { continue }
      var cursor = 0
      while cursor < haystack.length {
        let range = haystack.range(
          of: needle, options: [],
          range: NSRange(location: cursor, length: haystack.length - cursor))
        if range.location == NSNotFound { break }
        let snippetRange = NSRange(
          location: max(0, range.location - 32),
          length: min(110, max(0, haystack.length - max(0, range.location - 32))))
        let snippet = haystack.substring(with: snippetRange).replacingOccurrences(
          of: "\n", with: " ")
        nextMatches.append(
          SearchMatch(
            pageIndex: pageIndex,
            query: query,
            snippet: snippet,
            charStart: range.location,
            charLength: range.length
          )
        )
        let nextCursor = range.location + max(range.length, 1)
        if nextCursor >= haystack.length { break }
        cursor = nextCursor
      }
    }
    searchMatches = nextMatches
    selectedSearchMatchIndex = nextMatches.firstIndex { $0.id == previousMatchID }
      ?? (nextMatches.isEmpty ? nil : 0)
    statusMessage =
      nextMatches.isEmpty
      ? "No matches found for \(query)." : "Found \(nextMatches.count) matches for \(query)."
    if let first = selectedSearchMatch {
      jumpToPage(first.pageIndex, preservingSearchMatch: true)
    }
    scheduleViewStateAutosave()
  }

  func copyCurrentPageText() {
    guard requirePermission(.copy, action: "Copy page text") else { return }
    guard let page = liveDocument?.page(at: selectedPageIndex) else {
      statusMessage = "Open a page first before copying."
      return
    }
    let text = page.string ?? ""
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    if pasteboard.setString(text, forType: .string) {
      statusMessage = "Copied page \(selectedPageIndex + 1) text."
    } else {
      statusMessage = "Page text copy failed."
    }
  }

  func setSearchMatch(_ index: Int) {
    guard index >= 0 && index < searchMatches.count else { return }
    selectedSearchMatchIndex = index
    if let match = selectedSearchMatch {
      jumpToPage(match.pageIndex, preservingSearchMatch: true)
    }
    scheduleViewStateAutosave()
  }

  func selectNextSearchMatch() {
    guard !searchMatches.isEmpty else { return }
    let next = (selectedSearchMatchIndex ?? -1) + 1
    let index = next >= searchMatches.count ? 0 : next
    setSearchMatch(index)
  }

  func selectPreviousSearchMatch() {
    guard !searchMatches.isEmpty else { return }
    let previous = (selectedSearchMatchIndex ?? 0) - 1
    let index = previous < 0 ? searchMatches.count - 1 : previous
    setSearchMatch(index)
  }

  func openLink(_ link: PDFLink) {
    switch link.kind {
    case .internalPage, .outline, .namedDestination:
      if let targetPage = link.targetPageIndex {
        selectedPageIndex = max(0, min(targetPage, max(0, currentPageCount - 1)))
      } else {
        statusMessage = "No mapped page target found for this link."
      }
    case .externalURL:
      guard link.isSafeExternal, let raw = link.destination, let url = URL(string: raw) else {
        statusMessage = "Blocked a potentially unsafe or malformed external destination."
        return
      }
      NSWorkspace.shared.open(url)
    case .unknown:
      statusMessage = "Cannot navigate this link type in current lane."
    }
  }

  func setReaderViewMode(_ mode: ReaderViewMode) {
    readerViewMode = mode
    if mode == .continuous {
      readerScaleMode = .fitWidth
    }
    scheduleViewStateAutosave()
  }

  func setReaderScaleMode(_ mode: ReaderScaleMode) {
    readerScaleMode = mode
    if mode == .zoom && readerZoom == 1.0 {
      readerZoom = 1.0
    }
    scheduleViewStateAutosave()
  }

  func setZoom(_ value: Double) {
    readerZoom = max(0.25, min(3.0, value))
    scheduleViewStateAutosave()
  }

  func rotateLeft() {
    readerRotation = (readerRotation + 270) % 360
    refreshRotation()
    scheduleViewStateAutosave()
  }

  func rotateRight() {
    readerRotation = (readerRotation + 90) % 360
    refreshRotation()
    scheduleViewStateAutosave()
  }

  func resetReaderState() {
    readerViewMode = .continuous
    readerScaleMode = .fitWidth
    readerZoom = 1.0
    readerRotation = 0
    pageJumpInput = ""
    clearSearch()
  }

  private func refreshRotation() {
    // Reader rotation is session/view state. The PDFKit presentation layer
    // projects this value onto its own copy, so the editable document keeps
    // the source PDF coordinate system used by operations and export.
  }

  private func performExport(sourceURL: URL, destination: URL) {
    do {
      let result = try provider.export(url: sourceURL, operations: operations, to: destination)
      exportReport = result.report
      prepareValidatedTemplateRevision(from: result.report)
      switch result.report.status {
      case .validated:
        statusMessage = "Exported and reopened a validated copy."
      case .validatedWithWarnings:
        statusMessage =
          "Exported with validation warnings. Review the report before relying on the copy."
      case .failed:
        statusMessage =
          "Exported, but validation failed. The source and edit history remain available."
      }
      if result.report.status == .failed {
        alertMessage = result.report.messages.joined(separator: "\n")
      }
      // Save session after successful export
      saveSession()
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  // MARK: - Session Persistence

  /// Save the current editing session to disk.
  func saveSession() {
    saveDurableRecovery()
  }

  /// Load a saved session for the current document.
  func loadSavedSession() {
    guard let currentInspection = inspection else { return }
    refreshRecoveryDiscovery()
    guard restoreDurableRecovery(for: currentInspection.source.sha256) else {
      statusMessage = "No replayable recovery session found for this document."
      return
    }
  }

  /// Auto-save session periodically (call after each operation).
  private func autoSaveSession() {
    _ = saveDurableRecovery()
  }

  /// Schedules a coalesced persistence of the current view/session state.
  ///
  /// This is intentionally separate from content dirty state. Navigation,
  /// reader mode, zoom, rotation, selection, and search selection may be
  /// useful to restore without representing an edit to the source PDF. The
  /// settled state is persisted as one metadata, payload, and pair generation
  /// through the same commit-pointer protocol as content autosave.
  func scheduleViewStateAutosave() {
    guard inspection != nil, sourceURL != nil, currentSessionID != nil else { return }
    guard let currentDigest = currentViewStateDigest(),
      currentDigest != lastPersistedViewStateDigest
    else { return }

    viewStateAutosaveTask?.cancel()
    viewStateAutosaveTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(nanoseconds: 250_000_000)
      } catch {
        return
      }
      guard !Task.isCancelled, let self else { return }
      self.viewStateAutosaveTask = nil
      guard let currentDigest = self.currentViewStateDigest(),
        currentDigest != self.lastPersistedViewStateDigest
      else { return }
      _ = self.saveDurableRecovery()
    }
  }

  private func cancelViewStateAutosave() {
    viewStateAutosaveTask?.cancel()
    viewStateAutosaveTask = nil
  }

  /// List all saved sessions.
  func listSavedSessions() -> [PDFSessionRecord] {
    (try? sessionStore.listAll()) ?? []
  }

  /// Delete a saved session.
  func deleteSession(sourceDigest: String) {
    do {
      refreshRecoveryDiscovery()
      for envelope in recoveryRecords where envelope.sourceDigest == sourceDigest {
        try recoveryPayloadStore.delete(sessionID: envelope.session.sessionID)
        try recoveryPairStore.delete(sessionID: envelope.session.sessionID)
        try recoveryStore.delete(sessionID: envelope.session.sessionID)
      }
      // Keep the legacy store cleanup for records written by older builds.
      try sessionStore.delete(sourceDigest: sourceDigest)
      if inspection?.source.sha256 == sourceDigest {
        hasSavedSession = false
        lastSessionInfo = nil
      }
      refreshRecoveryDiscovery()
    } catch {
      recoveryDiagnostics = ["Could not delete the recovery session safely."]
      recoveryStatus = .corrupted
    }
  }

  // MARK: - Durable recovery adapter

  /// Enumerates only the privacy-safe metadata plane. The value-bearing
  /// payload plane is opened later, after the user selects a matching source
  /// and the envelope identity has been checked.
  private func refreshRecoveryDiscovery() {
    do {
      let result = try recoveryStore.listRecoveries()
      recoveryRecords = result.envelopes
      recoveryDiagnostics = result.corruptions.map {
        "\($0.fileName): \($0.message)"
      }
      if !result.envelopes.isEmpty {
        recoveryStatus = .available
      } else if !result.corruptions.isEmpty {
        recoveryStatus = .corrupted
      } else {
        recoveryStatus = .none
      }
    } catch {
      recoveryRecords = []
      recoveryDiagnostics = ["Recovery records could not be discovered safely."]
      recoveryStatus = .corrupted
    }
  }

  /// Builds the privacy-safe ledger projection. Every payload-bearing edit
  /// receives an opaque reference equal to its operation ID; the corresponding
  /// value remains in the separately governed payload record.
  private func recoveryMetadata(for sourceDigest: String) -> [DocumentSessionOperationMetadata] {
    operations.map { operation in
      DocumentSessionOperationMetadata(
        operation: operation,
        sourceDigest: sourceDigest,
        targetIDDigest: operation.targetID.map(RecoveryLedgerIdentity.identifierDigest),
        payloadReferenceID: operation.id
      )
    }
  }

  private func recoveryCandidateStatuses() -> [UUID: CandidateStatus] {
    guard let candidates = inspection?.candidates else { return [:] }
    return candidates.reduce(into: [UUID: CandidateStatus]()) { result, candidate in
      if candidate.status != .suggested {
        result[candidate.id] = candidate.status
      }
    }
  }

  private func recoveryViewState() -> DocumentSessionViewState {
    DocumentSessionViewState(
      selectedPageIndex: selectedPageIndex,
      viewMode: readerViewMode,
      scaleMode: readerScaleMode,
      zoomScale: readerScaleMode == .zoom ? readerZoom : nil,
      pageRotation: readerRotation,
      selectedCandidateID: selectedCandidateID,
      selectedFieldIDDigest: selectedFieldID.map(RecoveryLedgerIdentity.identifierDigest),
      searchQueryDigest: searchQuery.isEmpty
        ? nil
        : RecoveryLedgerIdentity.identifierDigest(searchQuery),
      selectedSearchMatchIndex: selectedSearchMatchIndex
    )
  }

  /// Returns the canonical digest used to coalesce view-state recovery writes.
  /// The digest is intentionally derived from the same Codable view-state
  /// contract persisted in the recovery envelope and pair manifest.
  private func currentViewStateDigest() -> String? {
    guard inspection != nil, sourceURL != nil, currentSessionID != nil else {
      return nil
    }
    return RecoveryLedgerIdentity.viewStateDigest(recoveryViewState())
  }

  /// Commits a generation-specific payload and pair manifest before replacing
  /// the metadata envelope. The metadata envelope is the commit pointer. If
  /// the final write fails, the previous envelope still selects its previous
  /// payload and pair generation; newly written files are harmless orphans.
  @discardableResult
  private func saveDurableRecovery() -> Bool {
    guard let inspection, sourceURL != nil else { return false }

    let sessionID = currentSessionID ?? UUID()
    let sourceDigest = inspection.source.sha256
    guard operations.allSatisfy({ $0.sourceDigest == sourceDigest }) else {
      recoveryStatus = .saveFailed
      recoveryDiagnostics = [
        "Recovery autosave was not committed because an edit is not bound to the active PDF source."
      ]
      statusMessage = recoveryDiagnostics[0]
      return false
    }
    let metadata = recoveryMetadata(for: sourceDigest)
    let metadataDigest = RecoveryLedgerIdentity.metadataDigest(metadata)
    let nextSequence = recoveryAutosaveSequence + 1
    let candidateStatuses = recoveryCandidateStatuses()
    let viewState = recoveryViewState()
    let payload = SessionPayloadRecord(
      sessionID: sessionID,
      sourceDigest: sourceDigest,
      autosaveSequence: nextSequence,
      operationLedgerDigest: operationLedgerDigest(),
      metadataLedgerDigest: metadataDigest,
      operations: operations,
      candidateStatuses: candidateStatuses,
      viewStateDigest: RecoveryLedgerIdentity.viewStateDigest(viewState),
      selectedPageIndex: viewState.selectedPageIndex
    )
    let session = DocumentSession(
      sessionID: sessionID,
      sourceArtifact: DocumentSessionSourceArtifact(source: inspection.source),
      inspectionReference: DocumentSessionInspectionReference(
        sourceDigest: sourceDigest,
        pageCount: inspection.pages.count,
        nativeFieldCount: inspection.fields.count,
        candidateCount: inspection.candidates.count
      ),
      privacyProvenance: makeSessionPrivacyProvenance(
        sessionID: sessionID,
        sourceDigest: sourceDigest,
        operationCount: operations.count),
      operationLedger: metadata,
      viewState: recoveryViewState(),
      recovery: DocumentSessionRecoveryMetadata(
        state: .pending,
        reason: .autosave,
        autosaveSequence: nextSequence,
        hasUnexportedChanges: isDirty
      )
    )
    let envelope = DocumentSessionRecoveryEnvelope(session: session)
    let manifest = RecoveryPairManifest(
      sessionID: sessionID,
      sourceDigest: sourceDigest,
      autosaveSequence: nextSequence,
      metadataLedgerDigest: metadataDigest,
      operationLedgerDigest: payload.operationLedgerDigest,
      candidateStatusesDigest: payload.candidateStatusesDigest,
      viewStateDigest: payload.viewStateDigest,
      payloadIdentityDigest: payload.payloadIdentityDigest,
      metadataUpdatedAt: envelope.session.recovery.updatedAt,
      payloadUpdatedAt: payload.updatedAt
    )

    do {
      try recoveryPayloadStore.save(payload)
      try recoveryPairStore.save(manifest)
      try recoveryStore.save(envelope)
      currentSessionID = sessionID
      recoveryAutosaveSequence = nextSequence
      hasSavedSession = true
      recoveryStatus = .replayable
      recoveryDiagnostics.removeAll()
      lastSessionInfo = "Recovery autosaved: \(operations.count) edits"
      lastPersistedViewStateDigest = payload.viewStateDigest

      let retainedGenerations = Set(
        [nextSequence, recoveryAutosaveSequence - 1].filter { $0 > 0 }
      )
      var cleanupDiagnostics: [String] = []
      do {
        try recoveryPayloadStore.garbageCollectUnreferencedGenerations(
          sessionID: sessionID,
          keepingAutosaveSequences: retainedGenerations
        )
      } catch {
        cleanupDiagnostics.append(
          "Older sensitive recovery payload generations could not be cleaned up."
        )
      }
      do {
        try recoveryPairStore.garbageCollectUnreferencedGenerations(
          sessionID: sessionID,
          keepingAutosaveSequences: retainedGenerations
        )
      } catch {
        cleanupDiagnostics.append(
          "Older recovery pair generations could not be cleaned up."
        )
      }
      if !cleanupDiagnostics.isEmpty {
        recoveryStatus = .available
        recoveryDiagnostics = cleanupDiagnostics
        statusMessage = "Recovery was saved, but retention cleanup needs attention."
      }
      refreshInMemoryRecoverySnapshot()
      return true
    } catch {
      recoveryStatus = .saveFailed
      recoveryDiagnostics = [
        "Recovery autosave is unavailable. The current document remains in memory, but it may not be recoverable after termination."
      ]
      statusMessage = recoveryDiagnostics[0]
      return false
    }
  }

  private func makeSessionPrivacyProvenance(
    sessionID: UUID,
    sourceDigest: String,
    operationCount: Int
  ) -> PDFSessionPrivacyProvenance {
    let export: PDFSessionExportProvenance
    if let report = exportReport {
      let validation: PDFSessionValidationState
      let state: PDFSessionExportState
      switch report.status {
      case .validated:
        validation = .validated
        state = .succeeded
      case .validatedWithWarnings:
        validation = .validatedWithWarnings
        state = .succeeded
      case .failed:
        validation = .failed
        state = .failed
      }
      export = PDFSessionExportProvenance(
        state: state,
        sourceDigest: sourceDigest,
        outputDigest: report.outputDigest,
        storage: .localFile,
        validation: validation,
        outputReopenable: report.outputReopenable,
        operationCount: operationCount,
        exporterID: report.provider?.id,
        validationProviderID: report.provider?.id)
    } else {
      export = PDFSessionExportProvenance(
        state: .notAttempted,
        sourceDigest: sourceDigest,
        storage: .notApplicable,
        validation: .notRun,
        operationCount: operationCount)
    }
    return PDFSessionPrivacyProvenanceBuilder.build(
      sessionID: sessionID.uuidString,
      sourceDigest: sourceDigest,
      provider: PDFProviderDescriptor(
        id: "pdfkit",
        version: ProcessInfo.processInfo.operatingSystemVersionString,
        platform: "macOS",
        capabilities: ["session-provenance", "source-binding", "local-processing"]),
      generatedAt: ISO8601DateFormatter().string(from: Date()),
      processing: PDFSessionProcessingProvenance(
        locality: .localDevice,
        sourceInput: "local-file",
        dataEgress: .none),
      ocr: PDFSessionOCRProvenance(
        state: ocrProcessedPageIndices.isEmpty ? .notUsed : .localDevice,
        providerIDs: ocrProcessedPageIndices.isEmpty ? [] : ["vision"],
        processedPageCount: ocrProcessedPageIndices.count,
        recognizedTextRetained: false,
        recognizedBoundsRetained: false),
      sourceRetention: PDFSessionSourceRetentionProvenance(
        state: cachedSourceData == nil ? .notRetained : .inMemorySession,
        retainedUntilSessionEnd: cachedSourceData != nil,
        deletion: cachedSourceData == nil ? .deleted : .pending,
        sourceCopyCount: cachedSourceData == nil ? 0 : 1),
      export: export)
  }

  /// Restores a matching recovery only when both planes prove the same
  /// session, source, operation order, and ledger identities. A metadata-only
  /// record is intentionally not replayed and is surfaced as a safe re-apply
  /// workflow instead.
  @discardableResult
  private func restoreDurableRecovery(for sourceDigest: String) -> Bool {
    guard let envelope = recoveryRecords
      .filter({ $0.sourceDigest == sourceDigest })
      .max(by: { $0.session.recovery.updatedAt < $1.session.recovery.updatedAt })
    else {
      recoveryStatus = recoveryRecords.isEmpty ? .none : .available
      return false
    }

    do {
      let generation = envelope.session.recovery.autosaveSequence
      guard let payload = try recoveryPayloadStore.load(
        sessionID: envelope.session.sessionID,
        autosaveSequence: generation
      ) else {
        throw SessionPayloadStoreError.invalidRecord("The replay payload is missing.")
      }
      guard let manifest = try recoveryPairStore.load(
        sessionID: envelope.session.sessionID,
        autosaveSequence: generation
      ) else {
        throw RecoveryPairStoreError.invalidManifest("The committed pair manifest is missing.")
      }
      guard payload.sourceDigest == sourceDigest else {
        throw SessionPayloadStoreError.invalidRecord("The replay payload belongs to another source.")
      }
      guard payload.autosaveSequence == generation,
        manifest.autosaveSequence == generation,
        manifest.sessionID == envelope.session.sessionID,
        manifest.sourceDigest == sourceDigest
      else {
        throw SessionPayloadStoreError.invalidRecord("The recovery generations do not match.")
      }
      guard payload.operationLedgerDigest == RecoveryLedgerIdentity.operationDigest(payload.operations),
        payload.payloadIdentityDigest == RecoveryLedgerIdentity.payloadDigest(payload)
      else {
        throw SessionPayloadStoreError.invalidRecord("The replay payload ledger identity does not match.")
      }
      guard manifest.operationLedgerDigest == payload.operationLedgerDigest,
        manifest.payloadIdentityDigest == payload.payloadIdentityDigest
      else {
        throw SessionPayloadStoreError.invalidRecord("The pair manifest does not bind the replay payload.")
      }
      guard payload.metadataLedgerDigest
        == RecoveryLedgerIdentity.metadataDigest(envelope.session.operationLedger)
      else {
        throw SessionPayloadStoreError.invalidRecord("The metadata and payload ledgers do not match.")
      }
      guard manifest.metadataLedgerDigest == payload.metadataLedgerDigest,
        manifest.metadataUpdatedAt == envelope.session.recovery.updatedAt,
        manifest.payloadUpdatedAt == payload.updatedAt
      else {
        throw SessionPayloadStoreError.invalidRecord("The pair manifest does not bind the metadata generation.")
      }
      guard payload.operations.map(\.id) == envelope.session.operationIDs else {
        throw SessionPayloadStoreError.invalidRecord("The operation order does not match the recovery envelope.")
      }
      guard envelope.session.operationLedger.count == payload.operations.count else {
        throw SessionPayloadStoreError.invalidRecord("The operation count does not match the recovery envelope.")
      }
      guard envelope.session.operationLedger.allSatisfy({ $0.sourceDigest == sourceDigest }),
        payload.operations.allSatisfy({ $0.sourceDigest == sourceDigest }),
        zip(envelope.session.operationLedger, payload.operations).allSatisfy({ metadata, operation in
          metadata.id == operation.id
            && metadata.payloadReferenceID == operation.id
            && operation.sourceDigest == sourceDigest
      }) else {
        throw SessionPayloadStoreError.invalidRecord("An operation is not bound to the source or payload reference.")
      }

      let expectedCandidateStatusDigest = RecoveryLedgerIdentity.candidateStatusDigest(
        payload.candidateStatuses
      )
      guard payload.candidateStatusesDigest == expectedCandidateStatusDigest,
        manifest.candidateStatusesDigest == expectedCandidateStatusDigest
      else {
        throw SessionPayloadStoreError.invalidRecord("Candidate status identity does not match the recovery pair.")
      }
      let expectedViewStateDigest = RecoveryLedgerIdentity.viewStateDigest(envelope.session.viewState)
      guard payload.viewStateDigest == expectedViewStateDigest,
        manifest.viewStateDigest == expectedViewStateDigest,
        payload.selectedPageIndex == envelope.session.viewState.selectedPageIndex
      else {
        throw SessionPayloadStoreError.invalidRecord("View state identity does not match the recovery pair.")
      }

      // Stage all recovered state and replay against a separate document.
      // No active ledger, inspection, selection, history, or live document is
      // changed until this replay succeeds.
      let stagedInspection = inspectionApplyingRecoveryCandidateStatuses(
        payload.candidateStatuses,
        to: inspection
      )
      let stagedViewState = recoveryViewStateSnapshot(
        envelope.session.viewState,
        inspection: stagedInspection
      )
      let replay = try replayDocument(
        operations: payload.operations,
        upTo: payload.operations.count,
        checkpoints: [],
        shouldCacheSourceData: false
      )

      // Commit point. The remaining assignments do not perform fallible
      // provider work because replay has already succeeded.
      currentSessionID = envelope.session.sessionID
      recoveryAutosaveSequence = generation
      hasSavedSession = true
      lastSessionInfo = "Recovery metadata found: \(payload.operations.count) edits"
      inspection = stagedInspection
      operations = payload.operations
      restoreViewState(stagedViewState)
      searchQuery = ""
      searchMatches = []
      selectedSearchMatchIndex = nil
      operationViewStates = operations.map { _ in
        OperationViewState(before: stagedViewState, after: stagedViewState)
      }
      redoEntries = []
      replayCheckpoints = []
      replaceLiveDocument(replay.document)
      recordReplayCheckpointIfNeeded()
      recoveryStatus = .replayable
      recoveryDiagnostics.removeAll()
      lastPersistedViewStateDigest = expectedViewStateDigest
      refreshInMemoryRecoverySnapshot()
      statusMessage = "Restored \(operations.count) edits from the local recovery session."
      return true
    } catch {
      let message: String
      if let payloadError = error as? SessionPayloadStoreError,
        case let .quarantinedSchema(version, reason) = payloadError
      {
        message =
          "Recovery payload schema v\(version) was quarantined: \(reason) No edits were applied."
      } else {
        message =
          "Recovery metadata is available, but its edit payload could not be trusted. No edits were applied. Re-open the matching source PDF and re-apply the listed edits manually."
      }
      recoveryStatus = .metadataOnly
      recoveryDiagnostics = [message]
      statusMessage = recoveryDiagnostics[0]
      return true
    }
  }

  private func applyRecoveryCandidateStatuses(_ statuses: [UUID: CandidateStatus]) {
    guard let currentInspection = inspection else { return }
    inspection = inspectionApplyingRecoveryCandidateStatuses(statuses, to: currentInspection)
  }

  private func inspectionApplyingRecoveryCandidateStatuses(
    _ statuses: [UUID: CandidateStatus],
    to currentInspection: DocumentInspection?
  ) -> DocumentInspection? {
    guard let currentInspection else { return nil }
    var candidates = currentInspection.candidates
    for index in candidates.indices {
      if let status = statuses[candidates[index].id] {
        candidates[index].status = status
      }
    }
    return DocumentInspection(
      source: currentInspection.source,
      pages: currentInspection.pages,
      fields: currentInspection.fields,
      candidates: candidates,
      warnings: currentInspection.warnings,
      links: currentInspection.links,
      outlines: currentInspection.outlines,
      metadata: currentInspection.metadata,
      permissions: currentInspection.permissions,
      attachments: currentInspection.attachments,
      accessibility: currentInspection.accessibility,
      security: currentInspection.security
    )
  }

  private func recoveryViewStateSnapshot(
    _ state: DocumentSessionViewState,
    inspection: DocumentInspection?
  ) -> ViewStateSnapshot {
    let pageCount = inspection?.pages.count ?? 0
    let selectedCandidateID = state.selectedCandidateID.flatMap { candidateID in
      inspection?.candidates.contains(where: { $0.id == candidateID }) == true
        ? candidateID
        : nil
    }
    let selectedFieldID = state.selectedFieldIDDigest.flatMap { digest in
      inspection?.fields.first(where: {
        RecoveryLedgerIdentity.identifierDigest($0.id) == digest
      })?.id
    }
    return ViewStateSnapshot(
      selectedPageIndex: min(max(state.selectedPageIndex, 0), max(0, pageCount - 1)),
      selectedFieldID: selectedFieldID,
      selectedCandidateID: selectedCandidateID,
      selectedSearchMatchIndex: nil,
      readerViewMode: state.viewMode,
      readerScaleMode: state.scaleMode,
      readerZoom: max(0.25, min(3.0, state.zoomScale ?? 1.0)),
      readerRotation: state.pageRotation
    )
  }

  private func restoreRecoveryViewState(_ state: DocumentSessionViewState) {
    restoreViewState(recoveryViewStateSnapshot(state, inspection: inspection))
    searchQuery = ""
    searchMatches = []
    selectedSearchMatchIndex = nil
  }

  /// Deletes the persisted recovery pair for the active session without
  /// changing the in-memory document or its edit ledger. Callers that also
  /// want to discard the active document should follow this with
  /// `resetDocument()` or their own lifecycle transition.
  @discardableResult
  func discardRecovery() -> Bool {
    cancelViewStateAutosave()
    guard let sessionID = currentSessionID else {
      hasSavedSession = false
      recoveryAutosaveSequence = 0
      refreshRecoveryDiscovery()
      return true
    }
    do {
      try recoveryPayloadStore.delete(sessionID: sessionID)
      try recoveryPairStore.delete(sessionID: sessionID)
      try recoveryStore.delete(sessionID: sessionID)
    } catch {
      recoveryDiagnostics = ["The recovery session could not be fully deleted from local storage."]
      recoveryStatus = .corrupted
      statusMessage = recoveryDiagnostics[0]
      return false
    }
    recoveryRecords.removeAll { $0.session.sessionID == sessionID }
    hasSavedSession = false
    recoveryAutosaveSequence = 0
    lastPersistedViewStateDigest = nil
    refreshRecoveryDiscovery()
    return true
  }

  private func discardCurrentRecovery() {
    _ = discardRecovery()
  }

  // MARK: - Profile Management

  // MARK: - Reviewed Template Completion

  var hasTemplateReview: Bool { templateContract != nil }

  var templateMappings: [PDFTemplateMapping] {
    templateContract?.payload.mappings ?? []
  }

  var templateReviewableEntries: [PDFTemplateCompletionEntry] {
    templateCompletionProposal?.entries ?? []
  }

  enum TemplateValueEditorKind: String, Sendable {
    case text
    case choice
    case boolean
    case assetReference
    case missing
  }

  /// Capture an immutable, value-free layout proposal from the current native
  /// inspection. Profile data is intentionally not consulted in this phase.
  func captureTemplateReview(displayName: String = "Reviewed local layout") {
    guard let inspection else {
      statusMessage = "Open a PDF before capturing a completion template."
      return
    }
    do {
      let draft = try PDFTemplateCapture.captureDraft(
        from: inspection,
        workspaceKey: Data("pdf-editor-native-template-workspace".utf8),
        displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ? "Reviewed local layout"
          : displayName.trimmingCharacters(in: .whitespacesAndNewlines),
        sessionID: currentSessionID)
      templateContract = draft
      templateRevisionHistory = try PDFTemplateRevisionSet(
        templateID: draft.payload.templateID,
        revisions: [draft])
      templateCompletionProposal = nil
      templateValueDrafts = [:]
      templateLearningEvents = []
      pendingValidatedTemplateRevision = nil
      lastAppliedTemplateCompletion = nil
      templateCompletionOperationIDs = []
      templateRevisionDiff = nil
      statusMessage = "Captured \(draft.payload.mappings.count) mapping proposal(s). Review mappings before activation."
    } catch {
      alertMessage = "Could not capture the template review: \(error.localizedDescription)"
    }
  }

  func reviewTemplateMapping(_ mappingID: UUID, approved: Bool) {
    guard let template = templateContract, template.payload.lifecycle == .draft else { return }
    let mappings = template.payload.mappings.map { mapping in
      mapping.id == mappingID
        ? mapping.reviewed(as: approved ? .confirmed : .rejected)
        : mapping
    }
    templateContract = replacingTemplate(template, mappings: mappings)
  }

  func activateTemplateReview() {
    guard let draft = templateContract else { return }
    do {
      let reviewedIDs = Set(draft.payload.mappings.filter { $0.status != .proposed }.map(\.id))
      let approvedIDs = Set(draft.payload.mappings.filter(\.isApproved).map(\.id))
      let active = try PDFTemplateCapture.activateReviewedRevision(
        from: draft,
        approvedMappingIDs: approvedIDs,
        reviewedMappingIDs: reviewedIDs,
        sessionID: currentSessionID)
      templateRevisionHistory = try (templateRevisionHistory ?? PDFTemplateRevisionSet(
        templateID: draft.payload.templateID,
        revisions: [draft])).appending(active)
      templateContract = active
      statusMessage = "Activated \(approvedIDs.count) reviewed mapping(s). Profile values still require separate approval."
    } catch {
      alertMessage = "Template mapping review is incomplete: \(error.localizedDescription)"
    }
  }

  func saveTemplateRevision() {
    guard templateContract != nil else { return }
    if canSaveValidatedTemplateRevision,
       let pending = pendingValidatedTemplateRevision,
       let history = templateRevisionHistory,
       let parent = history.revisions.last
    {
      do {
        let updated = try history.appending(pending)
        try templateStore.save(history: updated)
        for event in templateLearningEvents {
          _ = try templateStore.append(learningEvent: event.applying())
        }
        templateRevisionHistory = updated
        self.templateContract = pending
        templateLearningEvents = templateLearningEvents.map { $0.applying() }
        templateRevisionDiff = try PDFTemplateRevisionDiff.make(from: parent, to: pending)
        pendingValidatedTemplateRevision = nil
        lastAppliedTemplateCompletion = nil
        templateCompletionOperationIDs = []
        refreshTemplateIDs()
        statusMessage = "Saved a new validated template revision. The source PDF and profile vault remain separate."
      } catch {
        alertMessage = "Could not save the validated template revision: \(error.localizedDescription)"
      }
      return
    }
    persistWorkingTemplate()
  }

  private func persistWorkingTemplate() {
    guard let templateContract else { return }
    do {
      if let history = templateRevisionHistory {
        try templateStore.save(history: history)
      } else {
        try templateStore.save(history: PDFTemplateRevisionSet(
          templateID: templateContract.payload.templateID,
          revisions: [templateContract]))
      }
      isTemplateVaultUnlocked = true
      refreshTemplateIDs()
      statusMessage = "Persisted the encrypted working template capture. It cannot change future behavior until a validated revision is saved."
    } catch {
      alertMessage = "Could not persist the encrypted template capture: \(error.localizedDescription)"
    }
  }

  func loadTemplate(templateID: UUID) {
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before loading a template."
      return
    }
    do {
      guard let history = try templateStore.load(templateID: templateID) else {
        statusMessage = "Template revision history was not found."
        return
      }
      templateRevisionHistory = history
      templateContract = history.activeRevision ?? history.revisions.last
      templateLearningEvents = (try? templateStore.learningEvents(templateID: templateID)) ?? []
      pendingValidatedTemplateRevision = nil
      templateRevisionDiff = nil
      statusMessage = "Loaded the encrypted template revision history. Completion still requires review for this source."
    } catch {
      alertMessage = "Could not load the encrypted template: \(error.localizedDescription)"
    }
  }

  func loadTemplateRevision(templateID: UUID, revisionID: UUID) {
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before loading a template revision."
      return
    }
    do {
      guard let history = try templateStore.load(templateID: templateID),
            let revision = history.revisions.first(where: { $0.payload.revisionID == revisionID })
      else {
        statusMessage = "The selected template revision was not found."
        return
      }
      templateRevisionHistory = history
      templateContract = revision
      templateLearningEvents = (try? templateStore.learningEvents(templateID: templateID)) ?? []
      templateCompletionProposal = nil
      pendingValidatedTemplateRevision = nil
      templateRevisionDiff = nil
      statusMessage = "Loaded the selected template revision for explicit mapping and value review."
    } catch {
      alertMessage = "Could not load the selected template revision: \(error.localizedDescription)"
    }
  }

  func deleteTemplate(templateID: UUID) {
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before deleting a template."
      return
    }
    do {
      try templateStore.delete(templateID: templateID)
      try templateStore.deleteLearningEvents(templateID: templateID)
      if templateContract?.payload.templateID == templateID {
        templateContract = nil
        templateRevisionHistory = nil
        templateCompletionProposal = nil
      }
      refreshTemplateIDs()
      statusMessage = "Deleted the selected template history and learning journal."
    } catch {
      alertMessage = "Could not delete the template: \(error.localizedDescription)"
    }
  }

  func exportTemplate(templateID: UUID? = nil) {
    let id = templateID ?? templateContract?.payload.templateID
    guard let id else { return }
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before exporting a template."
      return
    }
    do {
      let data = try templateStore.exportHistory(templateID: id)
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.json]
      panel.nameFieldStringValue = "pdf-template-\(id.uuidString).json"
      panel.begin { [weak self] response in
        guard response == .OK, let url = panel.url else { return }
        do {
          try data.write(to: url, options: .atomic)
          self?.statusMessage = "Exported a value-free template transfer envelope."
        } catch {
          self?.alertMessage = "Could not export the template: \(error.localizedDescription)"
        }
      }
    } catch {
      alertMessage = "Could not prepare the template export: \(error.localizedDescription)"
    }
  }

  func importTemplate() {
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before importing a template."
      return
    }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      do {
        let history = try self?.templateStore.importHistory(Data(contentsOf: url), replacing: false)
        if let history {
          self?.isTemplateVaultUnlocked = true
          self?.templateRevisionHistory = history
          self?.templateContract = history.activeRevision ?? history.revisions.last
          self?.refreshTemplateIDs()
          self?.statusMessage = "Imported a value-free template revision history. Review current mappings before completion."
        }
      } catch {
        self?.alertMessage = "Could not import the template: \(error.localizedDescription)"
      }
    }
  }

  /// Build a completion proposal from an active template and the selected
  /// profile revision. This only resolves candidate values as unreviewed.
  func prepareTemplateCompletionReview() {
    guard let template = templateContract,
          template.payload.lifecycle == .active,
          let inspection,
          isProfileVaultUnlocked,
          let profileID = currentProfile?.profileID,
          let profile = try? profileStore.load(profileID: profileID)?.latestRevision
    else {
      statusMessage = "Activate a template and select an unlocked profile before preparing completion."
      return
    }
    let match = PDFTemplateMatcher.propose(
      fingerprint: template.payload.fingerprint,
      sourceDigest: inspection.source.sha256,
      template: template)
    guard var proposal = PDFTemplateCompletionProposal.make(
      match: match,
      template: template,
      profile: profile,
      sessionID: currentSessionID ?? UUID())
    else {
      statusMessage = "The current PDF did not produce a reviewable template match."
      return
    }
    for entry in proposal.entries where entry.target.kind == .nativeField {
      if let field = inspection.fields.first(where: {
        $0.pageIndex == entry.target.pageIndex && $0.bounds == entry.target.region.rect
      }) {
        proposal = proposal.resolvingNativeTarget(entry.mappingID, targetID: field.id)
      }
    }
    templateCompletionProposal = proposal
    lastAppliedTemplateCompletion = nil
    templateCompletionOperationIDs = []
    pendingValidatedTemplateRevision = nil
    exportReport = nil
    templateValueDrafts = Dictionary(uniqueKeysWithValues: proposal.entries.compactMap { entry in
      guard let value = entry.value else { return nil }
      switch value {
      case .text(let text), .choice(let text), .assetReference(let text): return (entry.mappingID, text)
      case .boolean(let value): return (entry.mappingID, value ? "true" : "false")
      }
    })
    statusMessage = "Review mappings first, then approve each exact profile value before applying."
  }

  var templateCompletionApprovedMappingCount: Int {
    templateReviewableEntries.filter { $0.mappingReview == .approved }.count
  }

  var templateCompletionApprovedValueCount: Int {
    templateReviewableEntries.filter { $0.valueReview == .approved }.count
  }

  func templateValueEditorKind(for mappingID: UUID) -> TemplateValueEditorKind {
    guard let entry = templateCompletionProposal?.entries.first(where: { $0.mappingID == mappingID }) else {
      return .missing
    }
    guard let value = entry.value else { return .missing }
    switch value {
    case .text: return .text
    case .choice: return .choice
    case .boolean: return .boolean
    case .assetReference: return .assetReference
    }
  }

  func templateCompletionBooleanValue(for mappingID: UUID) -> Bool {
    guard let entry = templateCompletionProposal?.entries.first(where: { $0.mappingID == mappingID }),
          case .boolean(let value) = entry.value
    else { return false }
    return value
  }

  func reviewTemplateCompletionMapping(_ mappingID: UUID, approved: Bool) {
    guard let proposal = templateCompletionProposal else { return }
    templateCompletionProposal = proposal.reviewingMapping(mappingID, approved: approved)
  }

  func reviewTemplateCompletionValue(_ mappingID: UUID, approved: Bool) {
    guard let proposal = templateCompletionProposal,
          let entry = proposal.entries.first(where: { $0.mappingID == mappingID })
    else { return }
    let value = templateCompletionValue(for: entry, rawValue: templateValueDrafts[mappingID] ?? "")
    if case .assetReference = value {
      templateCompletionProposal = proposal.reviewingValue(mappingID, value: value, approved: false)
      statusMessage = "Asset references need an explicit native asset picker before completion can apply them."
      return
    }
    templateCompletionProposal = proposal.reviewingValue(mappingID, value: value, approved: approved)
    if approved && value == nil {
      statusMessage = "A non-empty profile value is required before approval."
    } else if entry.profileRevisionID == nil {
      statusMessage = "This value is not bound to an unlocked profile revision."
    }
  }

  func updateTemplateCompletionValue(_ mappingID: UUID, value: String) {
    templateValueDrafts[mappingID] = value
    guard let proposal = templateCompletionProposal else { return }
    guard let entry = proposal.entries.first(where: { $0.mappingID == mappingID }) else { return }
    let nextValue = templateCompletionValue(for: entry, rawValue: value)
    // Editing a value always returns it to resolvedUnreviewed. Approval is a
    // separate action and cannot survive a changed value.
    templateCompletionProposal = proposal.reviewingValue(mappingID, value: nextValue, approved: false)
  }

  func updateTemplateCompletionBoolean(_ mappingID: UUID, value: Bool) {
    templateValueDrafts[mappingID] = value ? "true" : "false"
    guard let proposal = templateCompletionProposal,
          let entry = proposal.entries.first(where: { $0.mappingID == mappingID })
    else { return }
    templateCompletionProposal = proposal.reviewingValue(
      mappingID,
      value: templateCompletionValue(for: entry, rawValue: value ? "true" : "false"),
      approved: false)
  }

  private func templateCompletionValue(
    for entry: PDFTemplateCompletionEntry,
    rawValue: String
  ) -> PDFProfileValue? {
    switch entry.value {
    case .text:
      return rawValue.isEmpty ? nil : .text(rawValue)
    case .choice:
      return rawValue.isEmpty ? nil : .choice(rawValue)
    case .boolean:
      return .boolean(rawValue == "true")
    case .assetReference:
      return rawValue.isEmpty ? nil : .assetReference(rawValue)
    case nil:
      return rawValue.isEmpty ? nil : .text(rawValue)
    }
  }

  func applyTemplateCompletion() {
    guard let proposal = templateCompletionProposal, let liveDocument else {
      statusMessage = "Prepare a template completion review first."
      return
    }
    guard let inspection else { return }
    do {
      let staged = try proposal.materializeOperations(currentSourceDigest: inspection.source.sha256)
      var applied = 0
      for operation in staged {
        guard permissionRequirements(for: operation).allSatisfy({ requirePermission($0, action: "Template completion") }) else { continue }
        try provider.apply(operation, to: liveDocument)
        recordAppliedOperation(operation)
        applied += 1
      }
      guard applied == staged.count else {
        statusMessage = "Applied \(applied) of \(staged.count) reviewed operations. Remaining entries stay available for review."
        return
      }
      lastAppliedTemplateCompletion = proposal
      templateCompletionOperationIDs = staged.map(\.id)
      pendingValidatedTemplateRevision = nil
      exportReport = nil
      statusMessage = "Applied \(applied) operations after separate mapping and profile-value approval. Export and strict validation are required before learning can be saved."
    } catch {
      statusMessage = "Template completion blocked: \(error.localizedDescription)"
    }
  }

  private func replacingTemplate(_ template: PDFTemplateContract, mappings: [PDFTemplateMapping]) -> PDFTemplateContract {
    PDFTemplateContract(
      header: template.header,
      payload: PDFTemplatePayload(
        templateID: template.payload.templateID,
        revisionID: template.payload.revisionID,
        parentRevisionID: template.payload.parentRevisionID,
        displayName: template.payload.displayName,
        lifecycle: template.payload.lifecycle,
        privacyMode: template.payload.privacyMode,
        fingerprint: template.payload.fingerprint,
        mappings: mappings,
        reviewPolicy: template.payload.reviewPolicy))
  }

  private func prepareValidatedTemplateRevision(from report: ValidationReport) {
    pendingValidatedTemplateRevision = nil
    guard let parent = templateContract,
          let proposal = lastAppliedTemplateCompletion,
          let inspection,
          report.status == .validated,
          report.sourceUnchanged,
          report.outputReopenable,
          report.sourceDigest == inspection.source.sha256,
          !templateCompletionOperationIDs.isEmpty,
          Set(report.operationIDs) == Set(operations.map(\.id)),
          Set(report.operationIDs) == Set(templateCompletionOperationIDs)
    else { return }
    let event = PDFTemplateLearningEvent(
      templateID: parent.payload.templateID,
      baseRevisionID: parent.payload.revisionID,
      sourceDigest: inspection.source.sha256,
      kind: .completionValidated,
      completionSessionID: proposal.sessionID,
      status: .pending,
      note: "Strict export validation completed after two-stage reviewed completion.")
    guard PDFTemplateRevisionGate.canPromote(
      template: parent,
      sourceDigest: inspection.source.sha256,
      validation: report,
      events: [event])
    else { return }
    do {
      pendingValidatedTemplateRevision = try PDFTemplateCapture.makeValidatedCompletionRevision(
        from: parent,
        sourceDigest: inspection.source.sha256,
        sessionID: proposal.sessionID)
      templateLearningEvents = [event]
      templateRevisionDiff = try PDFTemplateRevisionDiff.make(from: parent, to: pendingValidatedTemplateRevision!)
      statusMessage = "Validated export is ready. Save the proposed child revision explicitly to remember this reviewed completion."
    } catch {
      alertMessage = "Validated completion could not produce a child revision: \(error.localizedDescription)"
    }
  }

  /// Refresh the list of available profiles from disk.
  func refreshProfiles() {
    availableProfiles = isProfileVaultUnlocked ? ((try? profileStore.listUserProfiles()) ?? []) : []
  }

  /// Create a new empty profile and select it.
  func createProfile(displayName: String) {
    if !isProfileVaultUnlocked { unlockProfileVault() }
    guard isProfileVaultUnlocked else { return }
    let profile = UserProfile.standard(displayName: displayName)
    do {
      try profileStore.save(profile: profile)
      currentProfile = profile
      refreshProfiles()
      statusMessage = "Created profile \(displayName)."
    } catch {
      alertMessage = "Could not create profile: \(error.localizedDescription)"
    }
  }

  /// Load a profile by ID and make it current.
  func loadProfile(profileID: UUID) {
    guard isProfileVaultUnlocked else {
      statusMessage = "Unlock the local profile vault before selecting a profile."
      return
    }
    do {
      if let profile = try profileStore.loadUserProfile(profileID: profileID) {
        currentProfile = profile
        statusMessage = "Loaded profile \(profile.displayName)."
      } else {
        statusMessage = "Profile not found."
      }
    } catch {
      alertMessage = "Could not load profile: \(error.localizedDescription)"
    }
  }

  /// Save the current profile to disk.
  func saveCurrentProfile() {
    guard isProfileVaultUnlocked else {
      statusMessage = "Unlock the local profile vault before saving profile values."
      return
    }
    guard var profile = currentProfile else { return }
    do {
      profile.lastModifiedAt = Date()
      try profileStore.save(profile: profile)
      currentProfile = profile
      refreshProfiles()
    } catch {
      alertMessage = "Could not save profile: \(error.localizedDescription)"
    }
  }

  /// Delete a profile by ID.
  func deleteProfile(profileID: UUID) {
    guard isProfileVaultUnlocked else {
      statusMessage = "Unlock the local profile vault before deleting a profile."
      return
    }
    do {
      try profileStore.delete(profileID: profileID)
      if currentProfile?.profileID == profileID {
        currentProfile = nil
      }
      refreshProfiles()
      statusMessage = "Profile deleted."
    } catch {
      alertMessage = "Could not delete profile: \(error.localizedDescription)"
    }
  }

  /// Update a value in the current profile.
  func updateProfileValue(_ value: String, for key: String) {
    guard var profile = currentProfile else { return }
    profile.setValue(value, for: key)
    currentProfile = profile
  }

  /// Import a vCard into the current profile.
  func importVCard(_ vCard: String) {
    guard var profile = currentProfile else { return }
    profile.importFromVCard(vCard)
    currentProfile = profile
    saveCurrentProfile()
    statusMessage = "Imported vCard data into \(profile.displayName)."
  }

  /// Run bulk fill: match profile values against the current document's fields and candidates.
  /// Returns the result but does NOT apply operations — the user must review and confirm.
  func previewBulkFill() {
    guard let profile = currentProfile, let inspection else {
      statusMessage = "Open a document and select a profile before bulk fill."
      return
    }
    let result = profile.bulkFill(
      fields: inspection.fields,
      candidates: inspection.candidates,
      sourceDigest: inspection.source.sha256
    )
    bulkFillResult = result
    if result.totalMatches > 0 {
      statusMessage = "Profile matches \(result.totalMatches) field(s). \(result.unmatchedFields.count) field(s) unmatched. Review before applying."
    } else {
      statusMessage = "No profile values matched this document's fields."
    }
  }

  /// Apply all matched operations from the last bulk fill preview.
  func applyBulkFill() {
    guard let result = bulkFillResult, let liveDocument else {
      statusMessage = "Run a bulk fill preview first."
      return
    }
    var applied = 0
    var skipped = 0
    for operation in result.matchedOperations {
      let requirements = permissionRequirements(for: operation)
      guard requirements.allSatisfy({ requirePermission($0, action: "Bulk fill") }) else {
        skipped += 1
        continue
      }
      do {
        try provider.apply(operation, to: liveDocument)
        recordAppliedOperation(operation)
        applied += 1
      } catch {
        skipped += 1
      }
    }
    bulkFillResult = nil
    statusMessage =
      skipped == 0
      ? "Applied \(applied) profile field(s) to the document."
      : "Applied \(applied) profile field(s); skipped \(skipped) (permission denied or field unavailable)."
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
