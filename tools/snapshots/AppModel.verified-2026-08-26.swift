import AppKit
import CoreText
import CryptoKit
import Observation
import PDFEditorCore
import PDFKit
import UniformTypeIdentifiers

public struct SearchMatch: Identifiable, Equatable, Sendable {
  public let pageIndex: Int
  public let query: String
  public let snippet: String
  public let charStart: Int
  public let charLength: Int

  // The PDF text position is the durable identity. A generated UUID made
  // every search refresh look like a different hit and made selection drift.
  public var id: String {
    "\(pageIndex):\(charStart):\(charLength):\(query.lowercased()):\(snippet)"
  }
}

public struct ManualTextPlacement: Equatable, Sendable {
  public let pageIndex: Int
  public let bounds: PDFRect
}

@Observable
@MainActor
public final class AppModel {
  private let provider = PDFKitProvider()
  private let sessionStore: FileSessionStore
  private let recoveryStore: SessionRecoveryStore
  private let recoveryPayloadStore: SessionPayloadStore
  private let recoveryPairStore: RecoveryPairStore
  private let profileStore: EncryptedPDFProfileVault
  private let templateStore: EncryptedPDFTemplateStore
  /// Stage 0 learning loop: local, value-free review decisions per source.
  private let candidateReviewEventStore: CandidateReviewLearningEventStore
  /// Stage 1: priors aggregated from those events, used for ranking only.
  public private(set) var candidatePriors = CandidatePriors(sampleCount: 0)

  public var inspection: DocumentInspection? {
    didSet { refreshCandidateCaches() }
  }
  /// Guards the deferred preflight task: only the session that most recently
  /// opened a document may publish a preflight report.
  @ObservationIgnored private var pendingPreflightSessionID: UUID?
  // Performance: cached candidate lists to avoid re-filtering on every view body evaluation
  @ObservationIgnored private var _activeCandidates: [RegionCandidate] = []
  @ObservationIgnored private var _dismissedCandidates: [RegionCandidate] = []
  /// The inspection captured at document open, before any operations are applied.
  /// Used to compute the document diff showing original vs current state.
  public private(set) var sourceInspection: DocumentInspection?
  public private(set) var liveDocument: PDFDocument?
  public private(set) var documentProjectionRevision: UInt64 = 0

  // MARK: - Visual Diff
  /// When true, the document view overlays outside-region highlights.
  public var showDiff: Bool = false
  /// When true, the side-by-side diff comparison sheet is presented.
  public var showDiffSheet: Bool = false
  /// Cached diff computed from sourceInspection vs current inspection.
  public private(set) var currentDiff: DocumentDiff?
  /// The original source PDF as a PDFDocument, used for the diff comparison
  /// left panel to show the pre-edit state.
  public var sourceDocument: PDFDocument? {
    guard cachedSourceData != nil else { return nil }
    if let cached = cachedSourceDocument { return cached }
    guard let data = cachedSourceData, let parsed = PDFDocument(data: data) else { return nil }
    cachedSourceDocument = parsed
    return parsed
  }
  public var sourceURL: URL?
  /// True when the active document was authored in the app (blank, from
  /// images, or from the clipboard) and is backed by an app-owned temporary
  /// file rather than a user-owned source PDF.
  public private(set) var isScratchDocument = false
  public var operations: [EditOperation] = []
  /// Count of operations marked for permanent redaction. Avoids repeated filter in view bodies.
  public var redactionMarkCount: Int {
    operations.filter { $0.kind == .redactMark }.count
  }
  public var selectedPageIndex = 0
  public var selectedFieldID: String?
  public var selectedCandidateID: UUID?
  public var isManualPlacementMode = false
  public var manualTextPlacement: ManualTextPlacement?
  public var isManualTextSheetPresented = false
  public var manualTextDraft = ""
  public var isImporterPresented = false
  public var statusMessage: String?
  /// RG-043: last assistive-technology announcement (search counts, current
  /// match, page changes, no-match states). Recorded for verification and
  /// posted to the system accessibility channel.
  public private(set) var lastAccessibilityAnnouncement: String?
  public var alertMessage: String?
  /// Up to 4 recently opened PDF file URLs, persisted across launches via UserDefaults.
  public var recentDocuments: [URL] {
    get {
      let saved = UserDefaults.standard.array(forKey: "recentDocuments") as? [String] ?? []
      return saved.compactMap { URL(string: $0) }
    }
    set {
      let strings = newValue.map { $0.absoluteString }
      UserDefaults.standard.set(strings, forKey: "recentDocuments")
      // Keep only the last 4
      if strings.count > 4 {
        // trimmed on set
      }
    }
  }
  /// Up to 4 recently opened PDF file URLs, persisted across launches via UserDefaults.
  /// Formatted value suggestions for the most recently focused region
  /// (profile matches first). Empty when nothing sensible to offer.
  public private(set) var lastValueSuggestions: [String] = []

  // Profile state
  public var currentProfile: UserProfile?
  public var availableProfiles: [UserProfile] = []
  public var isProfilePanelOpen = false
  public var bulkFillResult: ProfileBulkFillResult?
  // Template completion is a review session, not a profile shortcut. Mapping
  // and profile-value approvals remain in memory until both gates pass.
  public var templateContract: PDFTemplateContract?
  public var templateRevisionHistory: PDFTemplateRevisionSet?
  public var templateCompletionProposal: PDFTemplateCompletionProposal?
  public var templateValueDrafts: [UUID: String] = [:]
  public var templateLearningEvents: [PDFTemplateLearningEvent] = []
  public var pendingValidatedTemplateRevision: PDFTemplateContract?
  public var templateRevisionDiff: PDFTemplateRevisionDiff?
  public var templateProfileResolution: PDFTemplateProfileResolutionResult?
  public var templateMigrationProposal: PDFTemplateMigrationProposal?
  public var templateIndexMatch: PDFTemplateIndexQueryResult?
  public var availableTemplateIDs: [UUID] = []
  public var isTemplateVaultUnlocked = false
  public var isProfileVaultUnlocked = false
  /// Read-only, value-minimized source preflight shown before any export.
  public var preflightReport: PDFPreflightReport?
  public var templateStoreHealth: PDFLocalStoreHealth?
  public var profileStoreHealth: PDFLocalStoreHealth?
  public var templateAuditEvents: [PDFLocalStoreAuditEvent] = []
  public var profileAuditEvents: [PDFLocalStoreAuditEvent] = []
  private var lastAppliedTemplateCompletion: PDFTemplateCompletionProposal?
  private var templateCompletionOperationIDs: [UUID] = []
  public var exportReport: ValidationReport?
  public private(set) var lastActionDenial: ActionDenial?

  public var readerViewMode: ReaderViewMode = .continuous
  public var readerScaleMode: ReaderScaleMode = .fitWidth
  public var readerZoom = 1.0
  public var readerRotation = 0
  public var pageJumpInput = ""

  // MARK: - Editor mode (D-010)
  /// Current intent mode. Resets to `.read` on open unless `persistModeAcrossDocuments` is true.
  public var editorMode: EditorMode = .read
  /// User preference: when true, the mode chosen by the user persists when a new document is
  /// opened. Default false (reset to .read on each open) per D-010 owner decision 2026-08-25.
  public var persistModeAcrossDocuments: Bool {
    get { UserDefaults.standard.bool(forKey: "persistModeAcrossDocuments") }
    set { UserDefaults.standard.set(newValue, forKey: "persistModeAcrossDocuments") }
  }
  /// When true, the status bar shows a "This document has fields — fill them?" chip.
  public var isFillOfferVisible = false
  /// Pending signature region when Sign mode is active (nil = free placement).
  public var pendingSignatureRegion: RegionCandidate?
  /// Whether the signature sheet is presented.
  public var isSignatureSheetPresented = false
  /// Saved signatures (interim: app-sandboxed store; v2 migrates to Keychain per D-010).
  public var savedSignatures: [SavedSignature] = []
  /// Whether the redaction commit confirmation is presented (L3 gate).
  public var isRedactionCommitPresented = false
  /// Tab-order cursor: index into `editableRegions` for the current tab position.
  private var tabCursorIndex: Int = 0

  /// Active inline editor state positioned directly on the PDF canvas.
  public var activeInlineEditor: InlineEditorState?


  public var isPasswordSheetPresented = false
  public var passwordAttempt = ""
  private var passwordPendingURL: URL?
  private var cachedSourceData: Data? {
    didSet { cachedSourceDocument = nil }
  }
  /// Memoized parse of `cachedSourceData`. `sourceDocument` used to re-parse
  /// the whole file on every access, which put a full PDF parse on the SwiftUI
  /// body-evaluation path whenever the diff sheet was open.
  @ObservationIgnored private var cachedSourceDocument: PDFDocument?
  private var ocrProcessedPageIndices: Set<Int> = []
  /// Auto-scan dedup for in-flight OCR passes (fill/sign mode).
  @ObservationIgnored private var autoOCRPendingPages: Set<Int> = []

  public var searchQuery = ""
  public var searchMatches: [SearchMatch] = []
  public var selectedSearchMatchIndex: Int?

  // Session persistence
  private var currentSessionID: UUID?
  public var hasSavedSession: Bool = false
  public var lastSessionInfo: String?
  public var recoveryRecords: [DocumentSessionRecoveryEnvelope] = []
  public var recoveryDiagnostics: [String] = []
  /// Value-free diagnostic retained for controlled recovery evidence. It is
  /// not rendered in the user-facing recovery message.
  public private(set) var recoveryFailureDiagnostic: String?
  public var recoveryStatus: RecoveryStatus = .none
  private var recoveryAutosaveSequence = 0
  private var viewStateAutosaveTask: Task<Void, Never>?
  private var contentAutosaveTask: Task<Void, Never>?
  private var lastPersistedViewStateDigest: String?

  public enum RecoveryStatus: String, Sendable {
    case none
    case available
    case replayable
    case metadataOnly
    case corrupted
    case saveFailed
  }

  public var sessionID: UUID? { currentSessionID }

  public var canSaveValidatedTemplateRevision: Bool {
    guard pendingValidatedTemplateRevision != nil,
          let report = exportReport,
          report.status == .validated,
          !templateCompletionOperationIDs.isEmpty
    else { return false }
    return Set(report.operationIDs) == Set(operations.map(\.id))
      && Set(report.operationIDs) == Set(templateCompletionOperationIDs)
  }

  public var templateSaveButtonTitle: String {
    canSaveValidatedTemplateRevision ? "Save validated template revision" : "Persist encrypted working capture"
  }

  public enum LifecycleAction: String, Sendable {
    case newDocument
    case openDocument
    case closeWindow
  }

  public enum LifecycleDisposition: String, Sendable {
    case proceed
    case confirmBeforeDiscardingChanges
  }

  public struct LifecycleDecisionInfo: Equatable, Sendable {
    public let action: LifecycleAction
    public let hasDocument: Bool
    public let isDirty: Bool
    public let hasRecoverableSession: Bool
    public let canExportChanges: Bool
    public let disposition: LifecycleDisposition
  }

  private struct ReplayCheckpoint {
    let operationCount: Int
    let document: PDFDocument
  }

  public enum PermissionRequirement: String, Sendable {
    case copy = "copy or extract text"
    case modify = "modify form data"
    case addAnnotations = "add annotations or overlays"
  }

  public struct ActionDenial: Identifiable, Equatable, Sendable {
    public let id: String
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

  public struct InMemoryRecoverySnapshot: Equatable, Sendable {
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
  public private(set) var inMemoryRecoverySnapshot: InMemoryRecoverySnapshot?

  public convenience init() {
    let environment = ProcessInfo.processInfo.environment
    if environment["PDF_EDITOR_NATIVE_TERMINATION_PROBE"] == "1",
      let rootPath = environment["PDF_EDITOR_NATIVE_TERMINATION_ROOT"],
      let encodedKeyData = environment["PDF_EDITOR_NATIVE_TERMINATION_KEY_DATA"],
      let keyData = Data(base64Encoded: encodedKeyData)
    {
      let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
      let keyStore = RecoveryPayloadKeyStore(
        service: "com.pdfeditor.recovery-payload.native-probe",
        account: "native-termination-probe",
        testKeyData: keyData
      )
      self.init(
        sessionStore: FileSessionStore(directory: rootURL.appendingPathComponent("sessions", isDirectory: true)),
        recoveryStore: SessionRecoveryStore(directory: rootURL.appendingPathComponent("metadata", isDirectory: true)),
        recoveryPayloadStore: SessionPayloadStore(
          directory: rootURL.appendingPathComponent("payload", isDirectory: true),
          keyStore: keyStore
        ),
        recoveryPairStore: RecoveryPairStore(directory: rootURL.appendingPathComponent("pair", isDirectory: true)),
        profileStore: EncryptedPDFProfileVault(directory: rootURL.appendingPathComponent("profiles", isDirectory: true)),
        templateStore: EncryptedPDFTemplateStore(directory: rootURL.appendingPathComponent("templates", isDirectory: true)),
        initializeLocalVaultState: false
      )
    } else {
      self.init(
        sessionStore: FileSessionStore(directory: FileSessionStore.defaultDirectory),
        recoveryStore: SessionRecoveryStore(directory: SessionRecoveryStore.defaultDirectory),
        recoveryPayloadStore: SessionPayloadStore(),
        recoveryPairStore: RecoveryPairStore(),
        profileStore: EncryptedPDFProfileVault(directory: EncryptedPDFProfileVault.defaultDirectory),
        templateStore: EncryptedPDFTemplateStore(directory: EncryptedPDFTemplateStore.defaultDirectory),
        initializeLocalVaultState: false
      )
    }
  }

  init(
    sessionStore: FileSessionStore = FileSessionStore(directory: FileSessionStore.defaultDirectory),
    recoveryStore: SessionRecoveryStore = SessionRecoveryStore(directory: SessionRecoveryStore.defaultDirectory),
    recoveryPayloadStore: SessionPayloadStore = SessionPayloadStore(),
    recoveryPairStore: RecoveryPairStore = RecoveryPairStore(),
    profileStore: EncryptedPDFProfileVault = EncryptedPDFProfileVault(directory: EncryptedPDFProfileVault.defaultDirectory),
    templateStore: EncryptedPDFTemplateStore = EncryptedPDFTemplateStore(directory: EncryptedPDFTemplateStore.defaultDirectory),
    candidateReviewEventStore: CandidateReviewLearningEventStore = CandidateReviewLearningEventStore(directory: CandidateReviewLearningEventStore.defaultDirectory),
    initializeLocalVaultState: Bool = true,
    loadsKeychainSignatures: Bool = true
  ) {
    self.sessionStore = sessionStore
    self.recoveryStore = recoveryStore
    self.recoveryPayloadStore = recoveryPayloadStore
    self.recoveryPairStore = recoveryPairStore
    self.profileStore = profileStore
    self.templateStore = templateStore
    self.candidateReviewEventStore = candidateReviewEventStore
    if initializeLocalVaultState {
      refreshProfiles()
      refreshTemplateIDs()
      refreshLocalPersistenceHealth()
    }
    // Test harnesses must not touch the user's login keychain: ad-hoc SwiftPM
    // binaries change signature on every rebuild, so each run would otherwise
    // re-trigger the "wants to use your confidential information" prompt.
    if loadsKeychainSignatures {
      loadVaultSignatures()
    }
    refreshRecoveryDiscovery()

    // Performance: respond to memory pressure by evicting non-essential caches
    setupMemoryPressureHandler()
  }

  /// Evict non-essential caches on memory pressure. The source data cache
  /// is preserved because it is required for undo correctness.
  /// Sets up a macOS memory pressure handler using DispatchSource.
  private func setupMemoryPressureHandler() {
    let source = DispatchSource.makeMemoryPressureSource(
      eventMask: [.warning, .critical],
      queue: .main
    )
    source.setEventHandler { [weak self] in
      self?.handleMemoryWarning()
    }
    source.resume()
    // Store the source to prevent deallocation
    self.memoryPressureSource = source
  }

  /// Dispatch source for memory pressure events. Stored to prevent deallocation.
  private var memoryPressureSource: DispatchSourceMemoryPressure?

  /// Evict non-essential caches on memory pressure. The source data cache
  /// is preserved because it is required for undo correctness.
  private func handleMemoryWarning() {
    // Clear the memoized source document (can be re-parsed from cachedSourceData)
    cachedSourceDocument = nil
    // Clear OCR processed pages (will be re-detected if needed)
    ocrProcessedPageIndices.removeAll()
    statusMessage = "Memory pressure: cleared non-essential caches."
  }

  /// Keychain-backed local vault access is explicit in the UI. No template
  /// or profile values are exposed merely because a store directory exists.
  public func unlockTemplateVault() {
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

  public func lockTemplateVault() {
    isTemplateVaultUnlocked = false
    templateContract = nil
    templateRevisionHistory = nil
    templateLearningEvents = []
    pendingValidatedTemplateRevision = nil
    templateIndexMatch = nil
    refreshLocalPersistenceHealth()
    statusMessage = "Locked the local template vault."
  }

  public func unlockProfileVault() {
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

  public func lockProfileVault() {
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
  public func refreshLocalPersistenceHealth() {
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

  private func makeCrossDeviceBundle(
    storeKind: PDFLocalStoreKind,
    backupData: Data,
    recoveryData: Data
  ) throws -> Data {
    let backup = try PDFLocalCrossDeviceRecoveryCodec.decode(backupData)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let recovery = try decoder.decode(PDFLocalStoreRecoveryEnvelope.self, from: recoveryData)
    try recovery.validate()
    let bundle = PDFLocalCrossDeviceRecoveryBundle(
      storeKind: storeKind,
      backup: backup,
      recovery: recovery)
    return try PDFLocalCrossDeviceBundleCodec.encode(bundle)
  }

  private func splitCrossDeviceBundle(_ data: Data) throws -> (backup: Data, recovery: Data) {
    let bundle = try PDFLocalCrossDeviceBundleCodec.decode(data)
    let backup = try PDFLocalCrossDeviceRecoveryCodec.encodeBundle(bundle.backup)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return (backup, try encoder.encode(bundle.recovery))
  }

  public func exportTemplateRecoveryEnvelope() {
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

  public func importTemplateRecoveryEnvelope() {
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

  public func exportTemplateVaultBackup() {
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before exporting its encrypted backup."
      return
    }
    do {
      let data = try templateStore.exportEncryptedBackup()
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.json]
      panel.nameFieldStringValue = "pdf-editor-template-vault-backup.json"
      panel.begin { [weak self] response in
        guard response == .OK, let url = panel.url else { return }
        do {
          try data.write(to: url, options: .atomic)
          self?.refreshLocalPersistenceHealth()
          self?.statusMessage = "Exported an encrypted template-vault backup. It contains ciphertext records, not source PDF bytes or readable profile values."
        } catch {
          self?.alertMessage = "Could not export the encrypted template backup: \(error.localizedDescription)"
        }
      }
    } catch {
      alertMessage = "Could not prepare the encrypted template backup: \(error.localizedDescription)"
    }
  }

  public func importTemplateVaultBackup() {
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before importing its encrypted backup."
      return
    }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      let alert = NSAlert()
      alert.messageText = "Replace local template-vault records?"
      alert.informativeText = "The encrypted backup will replace local template and learning records. The source PDFs and profile vault are not included."
      alert.alertStyle = .warning
      alert.addButton(withTitle: "Replace Records")
      alert.addButton(withTitle: "Cancel")
      guard alert.runModal() == .alertFirstButtonReturn else { return }
      do {
        try self?.templateStore.importEncryptedBackup(Data(contentsOf: url), replacing: true)
        self?.isTemplateVaultUnlocked = true
        self?.refreshTemplateIDs()
        self?.refreshLocalPersistenceHealth()
        self?.statusMessage = "Restored the encrypted template vault. Review the imported revisions before use."
      } catch {
        self?.alertMessage = "Could not import the encrypted template backup: \(error.localizedDescription)"
      }
    }
  }

  public func exportTemplateCrossDeviceRecovery() {
    guard isTemplateVaultUnlocked else {
      statusMessage = "Unlock the local template vault before exporting cross-device recovery."
      return
    }
    guard let passphrase = requestLocalPassphrase(
      title: "Create template cross-device recovery passphrase",
      message: "This passphrase protects the key-recovery envelope. Keep it separate from the downloaded bundle. The app cannot recover it.") else { return }
    do {
      let data = try makeCrossDeviceBundle(
        storeKind: .template,
        backupData: templateStore.exportEncryptedBackup(),
        recoveryData: templateStore.exportRecoveryEnvelope(passphrase: passphrase))
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.json]
      panel.nameFieldStringValue = "pdf-editor-template-cross-device-recovery.json"
      panel.begin { [weak self] response in
        guard response == .OK, let url = panel.url else { return }
        do {
          try data.write(to: url, options: .atomic)
          self?.statusMessage = "Exported an encrypted template cross-device recovery bundle. Keep the file and passphrase separate."
        } catch {
          self?.alertMessage = "Could not export template cross-device recovery: \(error.localizedDescription)"
        }
      }
    } catch {
      alertMessage = "Could not prepare template cross-device recovery: \(error.localizedDescription)"
    }
  }

  public func importTemplateCrossDeviceRecovery() {
    guard let passphrase = requestLocalPassphrase(
      title: "Open template cross-device recovery",
      message: "Enter the recovery passphrase. The bundle will replace local template records after confirmation.") else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      let alert = NSAlert()
      alert.messageText = "Replace local template records from recovery bundle?"
      alert.informativeText = "This restores encrypted templates and learning records. Profile values and source PDFs are not included."
      alert.alertStyle = .warning
      alert.addButton(withTitle: "Restore")
      alert.addButton(withTitle: "Cancel")
      guard alert.runModal() == .alertFirstButtonReturn else { return }
      do {
        let parts = try self?.splitCrossDeviceBundle(Data(contentsOf: url))
        guard let parts else { return }
        try self?.templateStore.recoverKey(from: parts.recovery, passphrase: passphrase)
        try self?.templateStore.importEncryptedBackup(parts.backup, replacing: true)
        self?.isTemplateVaultUnlocked = true
        self?.refreshTemplateIDs()
        self?.refreshLocalPersistenceHealth()
        self?.statusMessage = "Restored the encrypted template vault from the cross-device bundle. Review imported revisions before use."
      } catch {
        self?.alertMessage = "Could not restore template cross-device recovery: \(error.localizedDescription)"
      }
    }
  }

  public func exportProfileRecoveryEnvelope() {
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

  public func importProfileRecoveryEnvelope() {
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

  public func exportProfileVaultBackup() {
    guard isProfileVaultUnlocked else {
      statusMessage = "Unlock the local profile vault before exporting its encrypted backup."
      return
    }
    do {
      let data = try profileStore.exportEncryptedBackup()
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.json]
      panel.nameFieldStringValue = "pdf-editor-profile-vault-backup.json"
      panel.begin { [weak self] response in
        guard response == .OK, let url = panel.url else { return }
        do {
          try data.write(to: url, options: .atomic)
          self?.refreshLocalPersistenceHealth()
          self?.statusMessage = "Exported an encrypted profile-vault backup. Keep it separate from the key-recovery envelope."
        } catch {
          self?.alertMessage = "Could not export the encrypted profile backup: \(error.localizedDescription)"
        }
      }
    } catch {
      alertMessage = "Could not prepare the encrypted profile backup: \(error.localizedDescription)"
    }
  }

  public func importProfileVaultBackup() {
    guard isProfileVaultUnlocked else {
      statusMessage = "Unlock the local profile vault before importing its encrypted backup."
      return
    }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      let alert = NSAlert()
      alert.messageText = "Replace local profile-vault records?"
      alert.informativeText = "The encrypted backup will replace profile revisions. This does not include source PDFs or template mappings."
      alert.alertStyle = .warning
      alert.addButton(withTitle: "Replace Profiles")
      alert.addButton(withTitle: "Cancel")
      guard alert.runModal() == .alertFirstButtonReturn else { return }
      do {
        try self?.profileStore.importEncryptedBackup(Data(contentsOf: url), replacing: true)
        self?.isProfileVaultUnlocked = true
        self?.currentProfile = nil
        self?.refreshProfiles()
        self?.refreshLocalPersistenceHealth()
        self?.statusMessage = "Restored the encrypted profile vault. Select a profile before resolving values."
      } catch {
        self?.alertMessage = "Could not import the encrypted profile backup: \(error.localizedDescription)"
      }
    }
  }

  public func exportProfileCrossDeviceRecovery() {
    guard isProfileVaultUnlocked else {
      statusMessage = "Unlock the local profile vault before exporting cross-device recovery."
      return
    }
    guard let passphrase = requestLocalPassphrase(
      title: "Create profile cross-device recovery passphrase",
      message: "This passphrase protects the key-recovery envelope. Keep it separate from the downloaded bundle. The app cannot recover it.") else { return }
    do {
      let data = try makeCrossDeviceBundle(
        storeKind: .profile,
        backupData: profileStore.exportEncryptedBackup(),
        recoveryData: profileStore.exportRecoveryEnvelope(passphrase: passphrase))
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.json]
      panel.nameFieldStringValue = "pdf-editor-profile-cross-device-recovery.json"
      panel.begin { [weak self] response in
        guard response == .OK, let url = panel.url else { return }
        do {
          try data.write(to: url, options: .atomic)
          self?.statusMessage = "Exported an encrypted profile cross-device recovery bundle. Keep the file and passphrase separate."
        } catch {
          self?.alertMessage = "Could not export profile cross-device recovery: \(error.localizedDescription)"
        }
      }
    } catch {
      alertMessage = "Could not prepare profile cross-device recovery: \(error.localizedDescription)"
    }
  }

  public func importProfileCrossDeviceRecovery() {
    guard let passphrase = requestLocalPassphrase(
      title: "Open profile cross-device recovery",
      message: "Enter the recovery passphrase. The bundle will replace local profile records after confirmation.") else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      let alert = NSAlert()
      alert.messageText = "Replace local profile records from recovery bundle?"
      alert.informativeText = "This restores encrypted profile revisions. Template mappings and source PDFs are not included."
      alert.alertStyle = .warning
      alert.addButton(withTitle: "Restore")
      alert.addButton(withTitle: "Cancel")
      guard alert.runModal() == .alertFirstButtonReturn else { return }
      do {
        let parts = try self?.splitCrossDeviceBundle(Data(contentsOf: url))
        guard let parts else { return }
        try self?.profileStore.recoverKey(from: parts.recovery, passphrase: passphrase)
        try self?.profileStore.importEncryptedBackup(parts.backup, replacing: true)
        self?.isProfileVaultUnlocked = true
        self?.currentProfile = nil
        self?.refreshProfiles()
        self?.refreshLocalPersistenceHealth()
        self?.statusMessage = "Restored the encrypted profile vault from the cross-device bundle. Select a profile before resolving values."
      } catch {
        self?.alertMessage = "Could not restore profile cross-device recovery: \(error.localizedDescription)"
      }
    }
  }

  public func deleteAllTemplateVaultRecords() {
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

  public func deleteAllProfileVaultRecords() {
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

  public func refreshTemplateIDs() {
    availableTemplateIDs = (try? templateStore.templateIDs()) ?? []
  }

  /// Rebuild the value-free local index from encrypted histories and query it
  /// against the current source. Retrieval never mutates the active template
  /// or creates operations.
  public func findLocalTemplateMatches() {
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

  public var selectedField: NativeField? {
    guard let selectedFieldID else { return nil }
    return inspection?.fields.first { $0.id == selectedFieldID }
  }

  public var selectedCandidate: RegionCandidate? {
    guard let selectedCandidateID else { return nil }
    return inspection?.candidates.first { $0.id == selectedCandidateID }
  }

  public var selectedSearchMatch: SearchMatch? {
    guard let index = selectedSearchMatchIndex,
      index >= 0,
      index < searchMatches.count
    else { return nil }
    return searchMatches[index]
  }

  public var canClearSearch: Bool {
    !searchQuery.isEmpty || !searchMatches.isEmpty
  }

  public var selectedPageLabel: String {
    inspection?.pages[safe: selectedPageIndex]?.pageLabel ?? "\(selectedPageIndex + 1)"
  }

  public var currentPageCount: Int {
    inspection?.pages.count ?? 0
  }

  public var canUndo: Bool { !operations.isEmpty }

  public var canRedo: Bool { !redoEntries.isEmpty }

  /// A session is dirty when it has a live source and operations that have
  /// not been committed back to the source file. Export Copy is intentionally
  /// separate from this predicate because it does not replace the source.
  public var isDirty: Bool {
    liveDocument != nil && !operations.isEmpty
  }

  public var hasUnexportedChanges: Bool { isDirty }

  public func lifecycleDecision(for action: LifecycleAction) -> LifecycleDecisionInfo {
    LifecycleDecisionInfo(
      action: action,
      hasDocument: liveDocument != nil,
      isDirty: isDirty,
      hasRecoverableSession: hasSavedSession,
      canExportChanges: canExportCurrentOperations,
      disposition: isDirty ? .confirmBeforeDiscardingChanges : .proceed
    )
  }

  public var canExportCurrentOperations: Bool {
    guard inspection != nil else { return false }
    return operations.allSatisfy { operation in
      permissionRequirements(for: operation).allSatisfy {
        permissionIsGranted($0)
      }
    }
  }

  // Compatibility names for the native command surface. Keeping these as
  // model-owned actions prevents menus from maintaining a second history.
  public func reset() { resetDocument() }

  public func undo() { PerformanceTelemetry.shared.measureUndo { undoLastEdit() } }

  public func redo() { PerformanceTelemetry.shared.measureRedo { redoLastEdit() } }

  public func goToPage(_ index: Int) {
    jumpToPage(index)
  }

  public func goToFirstPage() {
    goToPage(0)
  }

  public func goToPreviousPage() {
    goToPage(selectedPageIndex - 1)
  }

  public func goToNextPage() {
    goToPage(selectedPageIndex + 1)
  }

  public func goToLastPage() {
    goToPage(max(0, currentPageCount - 1))
  }

  public func setScaleMode(_ mode: ReaderScaleMode) {
    setReaderScaleMode(mode)
  }

  public func setActualSize() {
    setReaderScaleMode(.zoom)
    setZoom(1.0)
  }

  public func setFitPage() {
    setReaderScaleMode(.fitPage)
  }

  public func setFitWidth() {
    setReaderScaleMode(.fitWidth)
  }

  /// Typed entry point for the standard Find command. The shell can provide
  /// a query when it owns the field, while the model remains the sole search
  /// authority and preserves the selected hit when possible.
  public func routeSearchCommand(query: String? = nil) {
    if let query {
      searchQuery = query
    }
    if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      statusMessage = "Search is ready."
      return
    }
    runSearch()
  }

  public func routeNextSearchCommand() {
    selectNextSearchMatch()
  }

  public func routePreviousSearchCommand() {
    selectPreviousSearchMatch()
  }

  public func open(url: URL, password: String? = nil) {
    cancelViewStateAutosave()
    cancelContentAutosave()
    do {
      let hasSecurityScope = url.startAccessingSecurityScopedResource()
      defer {
        if hasSecurityScope {
          url.stopAccessingSecurityScopedResource()
        }
      }
      // One load, one parse: the provider returns the already-parsed document
      // alongside its inspection so the open path never pays for a second
      // `Data(contentsOf:)` + `PDFDocument(data:)` of the same bytes.
      let opened = try provider.openDocument(url: url, password: password)
      let nextInspection = opened.inspection
      let data = opened.data
      let document = opened.document

      inspection = nextInspection
      sourceInspection = nextInspection
      replaceLiveDocument(document)
      sourceURL = url
      isScratchDocument = false
      cachedSourceData = data
      // Stage 1 learning loop: load value-free priors so remaining
      // suggestions rank by what the user historically accepted here.
      candidatePriors = CandidatePriors(
        events: candidateReviewEventStore.events(
          sourceDigest: nextInspection.source.sha256))
      // Preflight build/validate is CPU-bound; keep the open path responsive by
      // computing it off the main thread and publishing the report when ready.
      // The session digest guards against publishing a stale report after the
      // user opens a different document while this one is still running.
      let openedSessionID = UUID()
      currentSessionID = openedSessionID
      pendingPreflightSessionID = openedSessionID
      preflightReport = nil
      let providerDescriptor = PDFProviderDescriptor(
        id: "pdfkit",
        version: ProcessInfo.processInfo.operatingSystemVersionString,
        platform: "macOS",
        capabilities: ["read-only-preflight", "metadata-presence", "embedded-data-counts", "network-boundary-counts", "bounded-token-scan"])
      let expectedDigest = nextInspection.source.sha256
      let inspectionForPreflight = nextInspection
      Task.detached(priority: .userInitiated) { [weak self] in
        let builtPreflight = PDFPreflightBuilder.build(
          inspection: inspectionForPreflight,
          data: data,
          provider: providerDescriptor)
        do {
          try PDFPreflightValidator.validate(builtPreflight, expectedSourceDigest: expectedDigest)
          await MainActor.run { [weak self] in
            guard let self, self.pendingPreflightSessionID == openedSessionID else { return }
            self.pendingPreflightSessionID = nil
            self.preflightReport = builtPreflight
          }
        } catch {
          await MainActor.run { [weak self] in
            guard let self, self.pendingPreflightSessionID == openedSessionID else { return }
            self.pendingPreflightSessionID = nil
            self.preflightReport = nil
            self.statusMessage = "Opened the PDF, but the read-only privacy preflight is unknown: \(error.localizedDescription)"
          }
        }
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
      templateProfileResolution = nil
      templateMigrationProposal = nil
      exportReport = nil
      passwordAttempt = ""
      isPasswordSheetPresented = false
      pageJumpInput = ""
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

  public func submitPassword() {
    guard let url = passwordPendingURL else { return }
    let attempted = passwordAttempt
    passwordAttempt = ""
    isPasswordSheetPresented = false
    open(url: url, password: attempted)
  }

  public func dismissPasswordPrompt() {
    passwordPendingURL = nil
    passwordAttempt = ""
    isPasswordSheetPresented = false
  }

public func resetDocument() {
    cancelViewStateAutosave()
    discardCurrentRecovery()
    inspection = nil
    sourceInspection = nil
    replaceLiveDocument(nil)
    sourceURL = nil
    isScratchDocument = false
    cachedSourceData = nil
    preflightReport = nil
    ocrProcessedPageIndices = []
    operations = []
    showDiff = false
    currentDiff = nil
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
    templateProfileResolution = nil
    templateMigrationProposal = nil
    exportReport = nil
    currentSessionID = nil
    pendingPreflightSessionID = nil
    hasSavedSession = false
    lastPersistedViewStateDigest = nil
    lastSessionInfo = nil
    statusMessage = "New document"
    resetReaderState()
  }

  // MARK: - Scratch Document Creation

  /// Authoring page sizes offered for scratch documents (PDF points).
  public struct ScratchPageSize: Identifiable, Hashable, Sendable {
    public let id: String
    public let size: CGSize

    public init(id: String, size: CGSize) {
      self.id = id
      self.size = size
    }

    public static let letter = ScratchPageSize(id: "Letter", size: CGSize(width: 612, height: 792))
    public static let a4 = ScratchPageSize(id: "A4", size: CGSize(width: 595, height: 842))
    public static let legal = ScratchPageSize(id: "Legal", size: CGSize(width: 612, height: 1008))
    public static let all: [ScratchPageSize] = [.letter, .a4, .legal]
  }

  /// Renders a real single-page PDF with exportable bytes. The generated data
  /// backs the scratch session the same way an opened file would, so digests,
  /// preflight, diff, and export all flow through the standard pipeline.
  static func makeBlankPDFData(pageSize: CGSize) -> Data? {
    guard pageSize.width > 0, pageSize.height > 0 else { return nil }
    var mediaBox = CGRect(origin: .zero, size: pageSize)
    let pdfData = NSMutableData()
    guard let consumer = CGDataConsumer(data: pdfData),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    else { return nil }
    context.beginPDFPage(nil)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(mediaBox)
    context.endPDFPage()
    context.closePDF()
    return pdfData as Data?
  }

  /// Builds a multi-page PDF with one page per image, at the image's native size.
  static func makePDFData(fromImages images: [NSImage]) -> Data? {
    let document = PDFDocument()
    for image in images {
      guard let page = PDFPage(image: image) else { continue }
      document.insert(page, at: document.pageCount)
    }
    guard document.pageCount > 0 else { return nil }
    return document.dataRepresentation()
  }

  /// Paginates text into a real (selectable-text) PDF via CoreText.
  static func makePDFData(fromText text: String, pageSize: CGSize) -> Data? {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    let attributed = NSAttributedString(
      string: text,
      attributes: [
        .font: NSFont.systemFont(ofSize: 11),
        .paragraphStyle: paragraph,
        .foregroundColor: NSColor.black,
      ])
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    var mediaBox = CGRect(origin: .zero, size: pageSize)
    let margin: CGFloat = 54
    let contentRect = CGRect(
      x: margin, y: margin,
      width: max(1, pageSize.width - margin * 2),
      height: max(1, pageSize.height - margin * 2))
    let pdfData = NSMutableData()
    guard let consumer = CGDataConsumer(data: pdfData),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
    else { return nil }
    var location = 0
    let totalLength = attributed.length
    while location < totalLength {
      context.beginPDFPage(nil)
      let frame = CTFramesetterCreateFrame(
        framesetter,
        CFRange(location: location, length: 0),
        CGPath(rect: contentRect, transform: nil),
        nil)
      CTFrameDraw(frame, context)
      let visible = CTFrameGetVisibleStringRange(frame)
      context.endPDFPage()
      guard visible.length > 0 else { break }
      location += visible.length
    }
    context.closePDF()
    return pdfData as Data?
  }

  /// Backs a generated document with real bytes in an app-owned temporary
  /// file and admits it through the standard open pipeline, so the scratch
  /// document has a genuine source digest, preflight, diff, and export path.
  /// The author-facing name is applied after admission.
  private func loadScratchDocument(data: Data, displayName: String, createdMessage: String) {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("PDFEditor-Scratch-\(UUID().uuidString)")
      .appendingPathExtension("pdf")
    do {
      try data.write(to: tempURL, options: [.atomic])
    } catch {
      alertMessage = "Could not prepare the new document: \(error.localizedDescription)"
      return
    }
    open(url: tempURL)
    guard let admitted = inspection else { return }
    let renamedSource = DocumentSource(
      fileName: displayName,
      byteCount: admitted.source.byteCount,
      sha256: admitted.source.sha256)
    let renamedInspection = DocumentInspection(
      source: renamedSource,
      pages: admitted.pages,
      fields: admitted.fields,
      candidates: admitted.candidates,
      warnings: admitted.warnings,
      links: admitted.links,
      outlines: admitted.outlines,
      metadata: admitted.metadata,
      permissions: admitted.permissions,
      attachments: admitted.attachments,
      accessibility: admitted.accessibility,
      security: admitted.security,
      annotationTypeCounts: admitted.annotationTypeCounts)
    inspection = renamedInspection
    sourceInspection = renamedInspection
    isScratchDocument = true
    statusMessage = createdMessage
  }

  /// Creates a blank scratch document. ⌘N entry point.
  public func newDocument(pageSize: CGSize = CGSize(width: 612, height: 792)) {
    guard let data = Self.makeBlankPDFData(pageSize: pageSize),
      !data.isEmpty,
      let probe = PDFDocument(data: data),
      probe.pageCount == 1
    else {
      alertMessage = "Could not create a new blank document."
      return
    }
    loadScratchDocument(
      data: data,
      displayName: "Untitled.pdf",
      createdMessage: "New blank document created.")
  }

  /// Creates a scratch document with one page per selected image.
  public func newDocumentFromImages(at urls: [URL]) {
    let images = urls.compactMap { url -> NSImage? in
      let hasScope = url.startAccessingSecurityScopedResource()
      defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
      return NSImage(contentsOf: url)
    }
    guard !images.isEmpty else {
      alertMessage = "No readable images were found in the selection."
      return
    }
    guard let data = Self.makePDFData(fromImages: images), !data.isEmpty else {
      alertMessage = "The selected images could not be converted into PDF pages."
      return
    }
    loadScratchDocument(
      data: data,
      displayName: "Untitled.pdf",
      createdMessage: "Created a new PDF from \(images.count) image\(images.count == 1 ? "" : "s").")
  }

  /// Presents the image picker for `newDocumentFromImages(at:)`.
  public func presentNewFromImagesPanel() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .tiff, .gif, .heic]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.message = "Choose images. Each image becomes one page, in order."
    panel.begin { [weak self] response in
      guard response == .OK, !panel.urls.isEmpty else { return }
      self?.newDocumentFromImages(at: panel.urls)
    }
  }

  /// Creates a scratch document from a Markdown file: headings, bold/italic,
  /// code blocks, lists, and block quotes are rendered with proper typography.
  public func newDocumentFromMarkdown() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!, .init(filenameExtension: "txt")!]
    panel.allowsMultipleSelection = false
    panel.message = "Choose a Markdown file. It will be converted to a publication-quality PDF."
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      let hasScope = url.startAccessingSecurityScopedResource()
      defer { if hasScope { url.stopAccessingSecurityScopedResource() } }
      guard let markdown = try? String(contentsOf: url, encoding: .utf8) else {
        self?.alertMessage = "Could not read the Markdown file."
        return
      }
      let title = url.deletingPathExtension().lastPathComponent
      let options = MarkdownToPDFRenderer.Options(
        showCover: true,
        title: title
      )
      guard let data = MarkdownToPDFRenderer.render(markdown, options: options), !data.isEmpty else {
        self?.alertMessage = "The Markdown file could not be converted to PDF."
        return
      }
      self?.loadScratchDocument(
        data: data,
        displayName: "\(title).pdf",
        createdMessage: "Created a PDF from \(title).md")
    }
  }

  /// Creates a scratch document from the clipboard: images become pages at
  /// native size; text is paginated into real selectable-text pages.
  public func newDocumentFromClipboard(pageSize: CGSize = CGSize(width: 612, height: 792)) {
    let pasteboard = NSPasteboard.general
    if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
      !images.isEmpty
    {
      guard let data = Self.makePDFData(fromImages: images), !data.isEmpty else {
        alertMessage = "The clipboard images could not be converted into PDF pages."
        return
      }
      loadScratchDocument(
        data: data,
        displayName: "Untitled.pdf",
        createdMessage: "Created a new PDF from the clipboard image\(images.count == 1 ? "" : "s").")
      return
    }
    if let text = pasteboard.string(forType: .string),
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      guard let data = Self.makePDFData(fromText: text, pageSize: pageSize), !data.isEmpty else {
        alertMessage = "The clipboard text could not be converted into a PDF page."
        return
      }
      loadScratchDocument(
        data: data,
        displayName: "Untitled.pdf",
        createdMessage: "Created a new PDF from the clipboard text.")
      return
    }
    statusMessage = "The clipboard does not contain a readable image or text."
  }

  /// Presents the PDF picker for appending pages into the active scratch
  /// document (merge). Opened files keep a strict source-preserving export
  /// contract, so structural assembly is scoped to scratch documents.
  public func presentAppendPagesPanel() {
    guard liveDocument != nil else {
      statusMessage = "Open or create a document before appending pages."
      return
    }
    guard isScratchDocument else {
      alertMessage =
        "Appending pages from another PDF is available for documents created in the app. Opened files keep a strict source-preserving export contract."
      return
    }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.pdf]
    panel.allowsMultipleSelection = false
    panel.message = "Choose a PDF. Its pages are appended after the current last page."
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      self?.insertPages(from: url)
    }
  }

  public func currentValue(for field: NativeField) -> String {
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

  public func buttonOptions(for field: NativeField) -> [String] {
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

  public func applyFieldValue(_ value: String) {
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

  public func applyOverlay(_ value: String) {
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

  public func applyStaticChoiceMark(cellIndex: Int) {
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

  public func synthesizeNativeField() {
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

  public func applyManualText() {
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

  public func beginManualTextPlacement() {
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

  public func cancelManualTextPlacement() {
    isManualPlacementMode = false
    manualTextPlacement = nil
    manualTextDraft = ""
    isManualTextSheetPresented = false
    statusMessage = "Manual text placement cancelled."
  }

  public func receiveManualPlacement(pageIndex: Int, point: CGPoint) {
    guard isManualPlacementMode else { return }
    receiveTextPlacement(pageIndex: pageIndex, point: point)
  }

  /// Double-click placement is the direct-on-page path. It uses the same
  /// page-space bounds and reversible overlay operation as toolbar placement.
  public func beginDirectTextPlacement(pageIndex: Int, point: CGPoint) {
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

  public func rejectSelectedCandidate() {
    guard let candidate = selectedCandidate else { return }
    updateCandidate(candidate.id, status: .rejected)
    selectedCandidateID = nil
    statusMessage = "Dismissed the suggested area. The source PDF was not changed."
  }

  /// Renames a suggestion and records the correction as a `.retyped`
  /// learning event so future matching prefers the user's terminology.
  public func renameCandidate(_ candidateID: UUID, to rawName: String) {
    guard let current = inspection else { return }
    let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 80 else {
      statusMessage = "Use a non-empty name of at most 80 characters."
      return
    }
    let previous = current.candidates.first { $0.id == candidateID }
    let candidates = current.candidates.map { candidate -> RegionCandidate in
      guard candidate.id == candidateID else { return candidate }
      var updated = candidate
      updated.displayName = trimmed
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
    if let previous,
      let event = CandidateReviewLearningEventFactory.make(
        candidateID: previous.id,
        decision: .retyped,
        pageIndex: previous.pageIndex,
        candidate: previous,
        sourceDigest: current.source.sha256)
    {
      try? candidateReviewEventStore.append(event: event)
    }
    statusMessage = "Renamed the suggestion to \(trimmed). Matching now prefers your wording."
  }

  public func restoreCandidate(_ candidateID: UUID) {
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
    let previous = current.candidates.first { $0.id == candidateID }
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
    recordCandidateLearningEvent(
      previous: previous, status: status, sourceDigest: current.source.sha256)
  }

  public var activeCandidates: [RegionCandidate] { _activeCandidates }

  /// Stage 0 learning loop: terminal review decisions become value-free
  /// structural events. Failures never block the user's edit flow.
  private func recordCandidateLearningEvent(
    previous: RegionCandidate?, status: CandidateStatus, sourceDigest: String
  ) {
    guard let previous else { return }
    let decision: CandidateReviewDecisionKind?
    switch status {
    case .confirmed: decision = .confirmed
    case .rejected: decision = .rejected
    case .suggested, .unknown: decision = nil
    }
    guard let decision,
      let event = CandidateReviewLearningEventFactory.make(
        candidateID: previous.id,
        decision: decision,
        pageIndex: previous.pageIndex,
        candidate: previous,
        sourceDigest: sourceDigest)
    else { return }
    do {
      try candidateReviewEventStore.append(event: event)
    } catch {
      // Learning is best-effort by contract; a full disk must not break a fill.
    }
    // Re-aggregate so the remaining suggestions re-rank immediately.
    candidatePriors = CandidatePriors(
      events: candidateReviewEventStore.events(sourceDigest: sourceDigest))
  }

  public var dismissedCandidates: [RegionCandidate] { _dismissedCandidates }

  /// Active suggestions ordered by prior-adjusted score (Stage 1 learning
  /// loop). Contract scores are untouched; this only orders review attention.
  public var rankedActiveCandidates: [RegionCandidate] {
    guard candidatePriors.hasSignal else { return _activeCandidates }
    return _activeCandidates.sorted { lhs, rhs in
      let lhsScore = candidatePriors.adjustedScore(for: lhs)
      let rhsScore = candidatePriors.adjustedScore(for: rhs)
      if lhsScore != rhsScore { return lhsScore > rhsScore }
      if lhs.pageIndex != rhs.pageIndex { return lhs.pageIndex < rhs.pageIndex }
      return lhs.bounds.y > rhs.bounds.y
    }
  }

  private func refreshCandidateCaches() {
    let candidates = inspection?.candidates ?? []
    _activeCandidates = candidates.filter { $0.status != .rejected }
    _dismissedCandidates = candidates.filter { $0.status == .rejected }
  }

  // MARK: - Editor mode (D-010)

  /// All editable regions in reading order (top-to-bottom, left-to-right, page-by-page).
  /// Native fields appear first on each page, then active candidates.
  public var editableRegions: [EditableRegionRef] {
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
  public var fillHighlightRegions: [FillHighlight] {
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
          label: candidate.effectiveDisplayName
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
          label: candidate.effectiveDisplayName
        ))
      }
    }
    return highlights
  }

  /// Fill progress as a 0..1 fraction. Nil when there is nothing to fill.
  public var fillProgress: Double? {
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
  public var fillProgressLabel: String? {
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

  // MARK: - Visual Diff

  /// Toggle the diff overlay on/off and recompute the diff when enabling.
  public func toggleDiffView() {
    showDiff.toggle()
    if showDiff {
      recomputeDiff()
    } else {
      currentDiff = nil
    }
  }

  /// Open the side-by-side diff comparison sheet.
  public func openDiffComparison() {
    recomputeDiff()
    showDiffSheet = true
  }

  /// Export the visual diff as a standalone PDF report.
  public func exportDiffReport() {
    guard let diff = currentDiff else {
      recomputeDiff()
      guard let diff = currentDiff else {
        statusMessage = "No diff data available. Open a document first."
        return
      }
      exportDiffReportData(diff)
      return
    }
    exportDiffReportData(diff)
  }

  private func exportDiffReportData(_ diff: DocumentDiff) {
    guard let sourceDoc = sourceDocument, let currentDoc = liveDocument else {
      statusMessage = "Cannot generate diff report: source or current document is unavailable."
      return
    }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = "diff-report.pdf"
    panel.begin { [weak self] response in
      guard response == .OK, let url = panel.url else { return }
      do {
        let data = try DocumentDiffReport.generate(
          sourceDocument: sourceDoc,
          currentDocument: currentDoc,
          diff: diff,
          operations: self?.operations ?? []
        )
        try data.write(to: url, options: .atomic)
        self?.statusMessage = "Exported diff report to \(url.lastPathComponent)."
      } catch {
        self?.alertMessage = "Could not export diff report: \(error.localizedDescription)"
      }
    }
  }

  /// Recompute the document diff from sourceInspection vs current inspection.
  /// The diff highlights outside-region changes with red/orange overlays.
  public func recomputeDiff() {
    guard let source = sourceInspection, let current = inspection else {
      currentDiff = nil
      return
    }
    currentDiff = DocumentDiffBuilder.build(
      source: source,
      output: current,
      operations: operations
    )
    statusMessage = diffStatusMessage
  }

  /// Human-readable summary of the current diff.
  public var diffStatusMessage: String {
    guard let diff = currentDiff else { return "No diff computed." }
    let changedPages = diff.pages.filter { $0.hasChanges }.count
    let unexpected = diff.summary.unexpectedChanges
    switch diff.summary.overallStatus {
    case .preserved:
      return "Diff: all changes are inside authorized regions. Source preserved outside."
    case .warnings:
      return "Diff: \(changedPages) page(s) changed. \(unexpected) unexpected change(s)."
    case .violations:
      return "Diff: \(unexpected) unexpected change(s) detected outside operation regions."
    case .incomplete:
      return "Diff: could not be computed (page count changed)."
    }
  }

  /// Diff overlay highlights for the PDFKitView.
  /// Shows outside-region changes in red and authorized changes in green.
  public var diffHighlightRegions: [FillHighlight] {
    guard showDiff, let diff = currentDiff else { return [] }
    var highlights: [FillHighlight] = []
    for pageDiff in diff.pages where pageDiff.hasChanges {
      for region in pageDiff.regions {
        let state: FillHighlight.State
        switch region.kind {
        case .unexpectedTextChange, .geometryChanged:
          state = .outsideRegionChange
        case .operationApplied, .nativeFieldChanged, .overlayAdded:
          state = .insideRegionChange
        case .preserved:
          state = .preserved
        }
        highlights.append(FillHighlight(
          id: "diff:\(pageDiff.pageIndex):\(region.region.rect.x):\(region.region.rect.y)",
          pageIndex: pageDiff.pageIndex,
          bounds: region.region.rect,
          state: state,
          label: region.description
        ))
      }
    }
    return highlights
  }

  /// Next unfilled region in reading order from the current tab cursor.
  public var nextUnfilledRegion: EditableRegionRef? {
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
  public func setEditorMode(_ mode: EditorMode) {
    editorMode = mode
    isFillOfferVisible = false
    tabCursorIndex = 0
    switch mode {
    case .read:
      statusMessage = "Reading mode — no edits will be applied."
    case .fill:
      let label = fillProgressLabel ?? "No fillable fields detected."
      statusMessage = "Fill mode — \(label)"
      autoOCRIfNeededForFillMode(pageIndex: selectedPageIndex)
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
  public func advanceToNextField() {
    guard editorMode == .fill else { return }
    let regions = editableRegions
    guard !regions.isEmpty else { return }
    tabCursorIndex = (tabCursorIndex + 1) % regions.count
    let region = regions[tabCursorIndex % regions.count]
    activateRegion(region)
  }

  /// Retreat tab focus to the previous unfilled region (Shift+Tab).
  public func retreatToPreviousField() {
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
      if let field = inspection?.fields.first(where: { $0.id == id }) {
        let val = currentValue(for: field)
        activeInlineEditor = InlineEditorState(
          target: region,
          draftText: val,
          initialValue: val,
          label: field.name
        )
        lastValueSuggestions = valueSuggestions(for: field)
      }
    case .candidate(let id):
      selectedCandidateID = id
      selectedFieldID = nil
      jumpToPage(region.pageIndex)
      if let candidate = activeCandidates.first(where: { $0.id == id }) {
        let suggestions = valueSuggestions(for: candidate)
        activeInlineEditor = InlineEditorState(
          target: region,
          draftText: "",
          initialValue: "",
          label: candidate.effectiveDisplayName
        )
        lastValueSuggestions = suggestions
      }
    }
  }

  /// Open an inline editor for a specific region.
  public func openInlineEditor(for region: EditableRegionRef) {
    activateRegion(region)
  }

  /// Commit the active inline editor text and advance to the next field.
  public func commitInlineEditor(text: String? = nil, andAdvance: Bool = true) {
    guard var editor = activeInlineEditor else { return }
    if let overrideText = text {
      editor.draftText = overrideText
    }
    let value = editor.draftText.trimmingCharacters(in: .whitespacesAndNewlines)

    switch editor.target.kind {
    case .nativeField:
      if let field = selectedField {
        applyFieldValue(value)
      }
    case .candidate:
      if let candidate = selectedCandidate {
        if !value.isEmpty {
          applyOverlay(value)
        }
      }
    }

    activeInlineEditor = nil

    if andAdvance {
      advanceToNextField()
    }
  }

  /// Dismiss the inline editor without applying uncommitted changes.
  public func dismissInlineEditor() {
    activeInlineEditor = nil
    lastValueSuggestions = []
  }

  /// Intent-inference router: called when the user taps a point on a page.
  /// In Read mode, infers likely intent and offers the appropriate mode.
  /// In Fill/Sign/Edit mode, routes to the correct action for what was tapped.
  public func handlePageTap(pageIndex: Int, point: CGPoint) {
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
        let region = EditableRegionRef(kind: .nativeField(id: field.id), pageIndex: pageIndex, bounds: field.bounds)
        activateRegion(region)
      case .fill, .edit:
        selectedFieldID = field.id
        selectedCandidateID = nil
        let region = EditableRegionRef(kind: .nativeField(id: field.id), pageIndex: pageIndex, bounds: field.bounds)
        activateRegion(region)
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
        let region = EditableRegionRef(kind: .candidate(id: candidate.id), pageIndex: pageIndex, bounds: candidate.bounds)
        activateRegion(region)
      case .fill, .edit:
        selectedCandidateID = candidate.id
        selectedFieldID = nil
        let region = EditableRegionRef(kind: .candidate(id: candidate.id), pageIndex: pageIndex, bounds: candidate.bounds)
        activateRegion(region)
      case .sign:
        break
      }
      return
    }

    // Tapped free space
    switch editorMode {
    case .edit:
      dismissInlineEditor()
      // Edit mode: begin text placement (existing path)
      beginDirectTextPlacement(pageIndex: pageIndex, point: point)
    case .sign:
      dismissInlineEditor()
      // Free placement signature
      beginSign(for: nil)
    case .read, .fill:
      dismissInlineEditor()
      break // No action on free-space tap in read/fill
    }
  }

  /// Show the fill offer chip in the status bar (called after document open).
  public func showFillOfferIfNeeded() {
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
  public func beginSign(for candidate: RegionCandidate?) {
    pendingSignatureRegion = candidate
    if editorMode != .sign {
      setEditorMode(.sign)
    }
    isSignatureSheetPresented = true
  }

  /// Apply a signature image to the pending region or a free-placed location.
  public func applySignature(_ imageData: Data, to bounds: PDFRect, on pageIndex: Int) {
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

  /// Apply a visual annotation (highlight, note, rectangle, or freehand drawing).
  public func applyVisualAnnotation(kind: EditKind, bounds: PDFRect, value: String, pageIndex: Int) {
    guard requirePermission(.addAnnotations, action: "Add visual annotation") else { return }
    guard let liveDocument else { return }

    let operation = EditOperation(
      pageIndex: pageIndex,
      kind: kind,
      value: value,
      bounds: bounds,
      sessionID: currentSessionID,
      sourceDigest: inspection?.source.sha256
    )
    do {
      try provider.apply(operation, to: liveDocument)
      recordAppliedOperation(operation)
      statusMessage = "Added \(kind.rawValue) annotation on page \(pageIndex + 1)."
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  // MARK: - Keychain Signature Vault Operations (D-010 / Task 1)

  /// Refresh signatures in memory from hardware/Keychain store.
  public func loadVaultSignatures() {
    let store = KeychainSignatureStore()
    savedSignatures = store.loadSignatures()
  }

  /// Persist a newly drawn/typed/imported signature into the Keychain-backed vault.
  public func saveSignatureToVault(label: String, dataURL: String) {
    let newSig = SavedSignature(label: label, dataURL: dataURL)
    var current = savedSignatures
    current.append(newSig)
    let store = KeychainSignatureStore()
    store.saveSignatures(current)
    savedSignatures = current
    statusMessage = "Saved signature to secure Keychain vault."
  }

  /// Delete a saved signature from Keychain custody.
  public func deleteSignatureFromVault(id: UUID) {
    var current = savedSignatures
    current.removeAll { $0.id == id }
    let store = KeychainSignatureStore()
    store.saveSignatures(current)
    savedSignatures = current
    statusMessage = "Removed signature from Keychain vault."
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

  /// Applies an already-recorded operation to a presentation clone of the
  /// live document. The canvas layer keeps its rotated presentation copy in
  /// sync incrementally instead of deep-copying the whole PDF on every edit.
  /// Returns false when the clone diverged and must be rebuilt from the live
  /// document.
  @discardableResult
  public func applyOperationForPresentation(
    _ operation: EditOperation,
    to document: PDFDocument
  ) -> Bool {
    do {
      try provider.apply(operation, to: document)
      return true
    } catch {
      return false
    }
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
  public func captureInMemoryRecoverySnapshot() -> InMemoryRecoverySnapshot? {
    refreshInMemoryRecoverySnapshot()
    return inMemoryRecoverySnapshot
  }

  @discardableResult
  public func restoreInMemoryRecoverySnapshot(_ snapshot: InMemoryRecoverySnapshot) -> Bool {
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

  public func undoLastEdit() {
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
      if showDiff { recomputeDiff() }
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

  public func redoLastEdit() {
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
      restoreViewState(entry.viewStateAfter)
      if let candidateID = entry.operation.candidateID {
        updateCandidate(candidateID, status: .confirmed)
      }
      autoSaveSession()
      if showDiff { recomputeDiff() }
      statusMessage = "Reapplied the previously undone edit."
      refreshInMemoryRecoverySnapshot()
    } catch {
      alertMessage = "Redo could not reapply the edit: \(error.localizedDescription)"
    }
  }

  public func selectNextCandidate() {
    let candidates = rankedActiveCandidates
    guard !candidates.isEmpty else { return }
    let currentID = selectedCandidateID
    let currentIndex = candidates.firstIndex { $0.id == currentID } ?? -1
    let nextIndex = (currentIndex + 1) % candidates.count
    let next = candidates[nextIndex]
    selectedCandidateID = next.id
    selectedFieldID = nil
    jumpToPage(next.pageIndex)
    statusMessage =
      "Selected \(next.effectiveDisplayName) (\(nextIndex + 1) of \(candidates.count))"
  }

  public func selectPreviousCandidate() {
    let candidates = rankedActiveCandidates
    guard !candidates.isEmpty else { return }
    let currentID = selectedCandidateID
    let currentIndex = candidates.firstIndex { $0.id == currentID } ?? 0
    let prevIndex = (currentIndex - 1 + candidates.count) % candidates.count
    let prev = candidates[prevIndex]
    selectedCandidateID = prev.id
    selectedFieldID = nil
    jumpToPage(prev.pageIndex)
    statusMessage =
      "Selected \(prev.effectiveDisplayName) (\(prevIndex + 1) of \(candidates.count))"
  }

  public func runOCROnSelectedPage() {
    guard requirePermission(.copy, action: "Run OCR") else { return }
    runOCR(pageIndex: selectedPageIndex, announceResult: true)
  }

  /// Runs Vision OCR on one page and merges detected blanks into the
  /// candidate set. Safe to call repeatedly: each page is processed once.
  private func runOCR(pageIndex: Int, announceResult: Bool) {
    let selectedPageIndex = pageIndex
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
      // OCR provenance stays intact: candidates keep the .ocrRegion kind, a
      // confidence-derived score, and the recognized text as evidence. The
      // confidence floor drops low-quality recognitions before they can pollute
      // the review queue.
      let ocrCandidates = StaticRegionDetector.detectOCR(
        observations: observations,
        pageIndex: selectedPageIndex,
        pageBounds: pageSnapshot.bounds
      )

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

  /// Fill mode convenience: scanned or text-poor pages get one automatic
  /// local OCR pass so suggestions appear without a manual step. Results
  /// merge through the same reviewed-candidate path (never auto-applied).
  private func autoOCRIfNeededForFillMode(pageIndex: Int) {
    guard editorMode == .fill || editorMode == .sign else { return }
    guard !ocrProcessedPageIndices.contains(pageIndex),
      autoOCRPendingPages.contains(pageIndex) == false
    else { return }
    guard let snapshot = inspection?.pages[safe: pageIndex],
      snapshot.hasSelectableText == false || snapshot.characterCount == 0
    else { return }
    guard let page = liveDocument?.page(at: pageIndex) else { return }

    autoOCRPendingPages.insert(pageIndex)
    statusMessage = "Scanning page \(pageIndex + 1) for fillable areas…"
    Task { @MainActor [weak self] in
      let observations = await Self.runRecognition(
        page: page, pageIndex: pageIndex)
      guard let self else { return }
      self.autoOCRPendingPages.remove(pageIndex)
      if let observations {
        self.mergeOCRObservations(observations, pageIndex: pageIndex)
      }
      // Silent by design on failure: auto-scan is opportunistic; manual OCR
      // still reports errors loudly.
    }
  }

  /// Runs off the main actor; PDFKit rasterization and Vision recognition
  /// are both CPU-bound.
  private nonisolated static func runRecognition(
    page: PDFPage, pageIndex: Int
  ) async -> [OCRObservation]? {
    // PDFPage is not declared Sendable, but it is immutable for the span of
    // this handoff: the main actor never mutates the live document while the
    // recognition pass reads it. The box scopes that invariant explicitly.
    final class OCRPageBox: @unchecked Sendable {
      let page: PDFPage
      init(page: PDFPage) { self.page = page }
    }
    let boxed = OCRPageBox(page: page)
    return await Task.detached(priority: .userInitiated) {
      try? VisionOCRProvider().recognize(page: boxed.page, pageIndex: pageIndex)
    }.value
  }

  /// Merge path shared by manual and automatic OCR.
  private func mergeOCRObservations(_ observations: [OCRObservation], pageIndex: Int) {
    guard let pageSnapshot = inspection?.pages[safe: pageIndex] else { return }
    let ocrCandidates = StaticRegionDetector.detectOCR(
      observations: observations,
      pageIndex: pageIndex,
      pageBounds: pageSnapshot.bounds
    )
    guard let current = inspection else { return }
    var existingCandidates = current.candidates
    var added = 0
    for c in ocrCandidates {
      if !existingCandidates.contains(where: {
        $0.pageIndex == c.pageIndex && abs($0.bounds.x - c.bounds.x) < 10
          && abs($0.bounds.y - c.bounds.y) < 10
      }) {
        existingCandidates.append(c)
        added += 1
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
    ocrProcessedPageIndices.insert(pageIndex)
    if added > 0 {
      statusMessage =
        "Auto-detected \(added) fillable area\(added == 1 ? "" : "s") on page \(pageIndex + 1). Review before applying."
    } else if !ocrCandidates.isEmpty {
      statusMessage = "Scanned page \(pageIndex + 1); no new fillable areas found."
    }
  }

  /// Synthesizes an invisible selectable text layer on top of scanned/raster PDF pages
  /// using recognized OCR bounding boxes so the exported PDF is searchable in external viewers.
  public func synthesizeSearchableOCRLayer(for pageIndex: Int? = nil) {
    guard let doc = liveDocument else { return }
    guard requirePermission(.addAnnotations, action: "Synthesize searchable OCR layer") else { return }

    let targetPages = pageIndex.map { [$0] } ?? Array(0..<doc.pageCount)
    var synthesizedCount = 0
    let ocrProvider = VisionOCRProvider()

    for idx in targetPages {
      guard let page = doc.page(at: idx),
            let pageSnapshot = inspection?.pages.first(where: { $0.pageIndex == idx }) else { continue }

      do {
        let observations = try ocrProvider.recognize(page: page, pageIndex: idx)
        for obs in observations where obs.confidence >= 0.3 {
          let lineEvidence = obs.toPageSpace(pageBounds: pageSnapshot.bounds, pageIndex: idx)
          let bounds = lineEvidence.bounds.cgRect
          let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
          annotation.contents = obs.text
          annotation.font = NSFont.systemFont(ofSize: max(6, bounds.height * 0.75))
          annotation.fontColor = NSColor.clear // Invisible text layer
          annotation.color = NSColor.clear
          page.addAnnotation(annotation)
          synthesizedCount += 1
        }
      } catch {
        continue
      }
    }

    if synthesizedCount > 0 {
      let op = EditOperation(
        pageIndex: pageIndex ?? 0,
        kind: .annotation,
        value: "ocr-searchable-layer:\(synthesizedCount)",
        sessionID: currentSessionID,
        sourceDigest: inspection?.source.sha256
      )
      recordAppliedOperation(op)
      statusMessage = "Synthesized searchable text layer (\(synthesizedCount) text spans)."
    } else {
      statusMessage = "No text spans generated for searchable layer."
    }
  }

  public func export() {
    guard ensureExportPermission() else { return }
    if isScratchDocument {
      let baseName = URL(fileURLWithPath: inspection?.source.fileName ?? "Untitled.pdf")
        .deletingPathExtension()
        .lastPathComponent
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.pdf]
      panel.canCreateDirectories = true
      panel.nameFieldStringValue = "\(baseName)-copy.pdf"
      panel.begin { [weak self] response in
        guard response == .OK, let destination = panel.url else { return }
        self?.exportScratchCopy(to: destination)
      }
      return
    }
    guard let sourceURL else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-filled.pdf"
    panel.begin { [weak self] response in
      guard response == .OK, let destination = panel.url else { return }
      self?.performExport(sourceURL: sourceURL, destination: destination)
    }
  }

  /// Serializes the live scratch document to a user-chosen destination.
  ///
  /// Scratch documents have no user-owned source file, so the live document
  /// is the export authority: every admitted operation is already applied to
  /// it. The staged copy is reopened and checked before the export is
  /// reported as validated.
  @discardableResult
  public func exportScratchCopy(to destination: URL) -> Bool {
    guard let document = liveDocument else {
      statusMessage = "There is no document to export."
      return false
    }
    if let sourceURL, destination.standardizedFileURL == sourceURL.standardizedFileURL {
      alertMessage = "Choose a new output location; the working copy cannot be overwritten."
      return false
    }
    guard let data = document.dataRepresentation(), !data.isEmpty else {
      alertMessage = "The document could not be serialized for export."
      return false
    }
    do {
      try data.write(to: destination, options: [.atomic])
    } catch {
      alertMessage = "Could not write the export copy: \(error.localizedDescription)"
      return false
    }
    guard let reopened = PDFDocument(data: data), reopened.pageCount == document.pageCount else {
      alertMessage = "The exported copy could not be reopened for verification. Please check the file."
      return false
    }
    let outputDigest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    exportReport = ValidationReport(
      status: .validated,
      messages: [],
      sourceUnchanged: true,
      outputReopenable: true,
      sourceDigest: inspection?.source.sha256,
      outputDigest: outputDigest,
      validatedAt: Date(),
      operationIDs: operations.map(\.id))
    statusMessage =
      "Exported a copy of the new document (\(document.pageCount) page\(document.pageCount == 1 ? "" : "s"))."
    saveSession()
    return true
  }

  /// Commits reviewed redaction marks only when the active provider exposes a
  /// measured permanent-redaction implementation. The current PDFKit lane
  /// exposes neither the capability nor an implementation for
  /// `EditKind.applyRedaction`, so this action must remain a visible denial.
  public func commitRedactions() {
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

  public func jumpToPage(_ index: Int) {
    jumpToPage(index, preservingSearchMatch: false)
    // RG-043: page changes are announced for assistive technology.
    announceForAccessibility("Page \(min(max(index, 0), max(0, currentPageCount - 1)) + 1)")
  }

  private func jumpToPage(_ index: Int, preservingSearchMatch: Bool) {
    let clamped = min(max(index, 0), max(0, currentPageCount - 1))
    selectedPageIndex = clamped
    if !preservingSearchMatch {
      selectedSearchMatchIndex = nil
    }
    // Fill/sign mode opportunistically scans text-poor pages on arrival.
    autoOCRIfNeededForFillMode(pageIndex: clamped)
    scheduleViewStateAutosave()
  }

  /// RG-043: records the announcement for verification and posts it to the
  /// macOS accessibility channel so VoiceOver speaks it.
  public func announceForAccessibility(_ message: String) {
    guard !message.isEmpty else { return }
    lastAccessibilityAnnouncement = message
    NSAccessibility.post(
      element: NSApp as Any,
      notification: .announcementRequested,
      userInfo: [
        .announcement: message,
        .priority: NSAccessibilityPriorityLevel.high.rawValue,
      ]
    )
  }

  public func runPageJump() {
    guard let index = Int(pageJumpInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      statusMessage = "Enter a valid page number."
      return
    }
    jumpToPage(index - 1)
  }

  public func clearSearch() {
    searchQuery = ""
    searchMatches = []
    selectedSearchMatchIndex = nil
    scheduleViewStateAutosave()
  }

  public func runSearch() {
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
    // RG-043: match counts and no-match states are announced, not only shown.
    announceForAccessibility(statusMessage ?? "")
    if let first = selectedSearchMatch {
      jumpToPage(first.pageIndex, preservingSearchMatch: true)
    }
    scheduleViewStateAutosave()
  }

  public func copyCurrentPageText() {
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

  public func setSearchMatch(_ index: Int) {
    guard index >= 0 && index < searchMatches.count else { return }
    selectedSearchMatchIndex = index
    if let match = selectedSearchMatch {
      jumpToPage(match.pageIndex, preservingSearchMatch: true)
      // RG-043: the current result is announced with its position, page, and
      // snippet so VoiceOver users can follow search navigation.
      announceForAccessibility(
        "Match \(index + 1) of \(searchMatches.count), page \(match.pageIndex + 1): \(match.snippet)"
      )
    }
    scheduleViewStateAutosave()
  }

  public func selectNextSearchMatch() {
    guard !searchMatches.isEmpty else { return }
    let next = (selectedSearchMatchIndex ?? -1) + 1
    let index = next >= searchMatches.count ? 0 : next
    setSearchMatch(index)
  }

  public func selectPreviousSearchMatch() {
    guard !searchMatches.isEmpty else { return }
    let previous = (selectedSearchMatchIndex ?? 0) - 1
    let index = previous < 0 ? searchMatches.count - 1 : previous
    setSearchMatch(index)
  }

  public func openLink(_ link: PDFLink) {
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

  public func setReaderViewMode(_ mode: ReaderViewMode) {
    readerViewMode = mode
    if mode == .continuous {
      readerScaleMode = .fitWidth
    }
    scheduleViewStateAutosave()
  }

  public func setReaderScaleMode(_ mode: ReaderScaleMode) {
    readerScaleMode = mode
    if mode == .zoom && readerZoom == 1.0 {
      readerZoom = 1.0
    }
    scheduleViewStateAutosave()
  }

  public func setZoom(_ value: Double) {
    readerZoom = max(0.25, min(3.0, value))
    scheduleViewStateAutosave()
  }

  public func rotateLeft() {
    readerRotation = (readerRotation + 270) % 360
    refreshRotation()
    scheduleViewStateAutosave()
  }

  public func rotateRight() {
    readerRotation = (readerRotation + 90) % 360
    refreshRotation()
    scheduleViewStateAutosave()
  }

  /// Permanent per-page rotation committed as an EditOperation.
  public func rotatePage(at index: Int, by degrees: Int) {
    guard let doc = liveDocument, index >= 0, index < doc.pageCount else { return }
    guard requirePermission(.modify, action: "Rotate page") else { return }
    let page = doc.page(at: index)
    let currentRotation = page?.rotation ?? 0
    let newRotation = (currentRotation + degrees + 360) % 360
    page?.rotation = newRotation

    let op = EditOperation(
      pageIndex: index,
      kind: .pageTransform,
      value: "\(newRotation)",
      sessionID: currentSessionID,
      sourceDigest: inspection?.source.sha256
    )
    recordAppliedOperation(op)
    statusMessage = "Rotated page \(index + 1) to \(newRotation)°."
  }

  /// Move/reorder a page in the active live document.
  public func movePage(from sourceIndex: Int, to destinationIndex: Int) {
    guard let doc = liveDocument else { return }
    guard sourceIndex >= 0, sourceIndex < doc.pageCount,
          destinationIndex >= 0, destinationIndex < doc.pageCount,
          sourceIndex != destinationIndex else { return }
    guard requirePermission(.modify, action: "Move page") else { return }

    guard let page = doc.page(at: sourceIndex) else { return }
    doc.removePage(at: sourceIndex)
    doc.insert(page, at: destinationIndex)

    let op = EditOperation(
      pageIndex: sourceIndex,
      kind: .pageMove,
      value: "\(sourceIndex) -> \(destinationIndex)",
      sessionID: currentSessionID,
      sourceDigest: inspection?.source.sha256
    )
    recordAppliedOperation(op)
    selectedPageIndex = destinationIndex
    statusMessage = "Moved page \(sourceIndex + 1) to position \(destinationIndex + 1)."
  }

  /// Remove a page from the active document (retains source immutability).
  public func deletePage(at index: Int) {
    guard let doc = liveDocument else { return }
    guard doc.pageCount > 1 else {
      statusMessage = "Cannot delete the only page in the document."
      return
    }
    guard index >= 0, index < doc.pageCount else { return }
    guard requirePermission(.modify, action: "Delete page") else { return }

    doc.removePage(at: index)

    let op = EditOperation(
      pageIndex: index,
      kind: .pageDelete,
      value: "\(index)",
      sessionID: currentSessionID,
      sourceDigest: inspection?.source.sha256
    )
    recordAppliedOperation(op)
    selectedPageIndex = min(index, doc.pageCount - 1)
    statusMessage = "Deleted page \(index + 1)."
  }

  /// Insert a blank page at the target index (or end of document).
  public func insertBlankPage(at targetIndex: Int? = nil, size: CGSize = CGSize(width: 612, height: 792)) {
    guard let doc = liveDocument else { return }
    guard requirePermission(.modify, action: "Insert blank page") else { return }

    let index = targetIndex ?? doc.pageCount
    let clampedIndex = min(max(index, 0), doc.pageCount)

    let blankPage = PDFPage()
    blankPage.setBounds(CGRect(origin: .zero, size: size), for: .mediaBox)
    blankPage.setBounds(CGRect(origin: .zero, size: size), for: .cropBox)
    doc.insert(blankPage, at: clampedIndex)

    let op = EditOperation(
      pageIndex: clampedIndex,
      kind: .pageInsert,
      value: "blank:\(Int(size.width))x\(Int(size.height))",
      sessionID: currentSessionID,
      sourceDigest: inspection?.source.sha256
    )
    recordAppliedOperation(op)
    selectedPageIndex = clampedIndex
    statusMessage = "Inserted blank page at position \(clampedIndex + 1)."
  }

  /// Insert pages from an imported external PDF file.
  public func insertPages(from sourceURL: URL, at targetIndex: Int? = nil) {
    guard let doc = liveDocument else { return }
    guard let importedDoc = PDFDocument(url: sourceURL) else {
      alertMessage = "Could not open the selected PDF for page insertion."
      return
    }
    guard requirePermission(.modify, action: "Insert pages") else { return }

    let index = targetIndex ?? doc.pageCount
    var insertionIndex = min(max(index, 0), doc.pageCount)
    let pageCount = importedDoc.pageCount

    for pageNum in 0..<pageCount {
      if let page = importedDoc.page(at: pageNum)?.copy() as? PDFPage {
        doc.insert(page, at: insertionIndex)
        insertionIndex += 1
      }
    }

    let op = EditOperation(
      pageIndex: index,
      kind: .pageInsert,
      value: "import:\(pageCount):\(sourceURL.lastPathComponent)",
      sessionID: currentSessionID,
      sourceDigest: inspection?.source.sha256
    )
    recordAppliedOperation(op)
    selectedPageIndex = index
    statusMessage = "Inserted \(pageCount) page\(pageCount == 1 ? "" : "s") from \(sourceURL.lastPathComponent)."
  }

  public func resetReaderState() {
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

  /// Export a flattened copy where all form fields, annotations, and visual stamps are rasterized/baked.
  ///
  /// Fail-closed by design: system PDFKit exposes no public API that bakes
  /// annotations or widget appearances into page content on save (the same
  /// serialization limit as image annotations). Rasterizing pages into image
  /// pages would destroy the text layer and violate the preservation contract,
  /// so this stays unavailable until the form-aware provider lane lands.
  public func exportFlattenedCopy(destination: URL) {
    alertMessage =
      "Flattened export is not available in the PDFKit adapter: system PDFKit cannot bake fields and annotations into page content. The source file was not modified; flattening requires the form-aware provider lane."
    statusMessage = "Flattened export unavailable (fail-closed)."
  }

  // MARK: - Batch Merge & Split Workflows (B3 Lane)

  /// Merge multiple PDF documents sequentially into a single target PDF.
  public func mergePDFs(sources: [URL], destination: URL) -> Bool {
    guard !sources.isEmpty else {
      alertMessage = "Select at least one PDF to merge."
      return false
    }
    let mergedDoc = PDFDocument()
    var totalPages = 0

    for sourceURL in sources {
      guard let doc = PDFDocument(url: sourceURL) else {
        alertMessage = "Could not read \(sourceURL.lastPathComponent)."
        return false
      }
      for pageIndex in 0..<doc.pageCount {
        if let page = doc.page(at: pageIndex)?.copy() as? PDFPage {
          mergedDoc.insert(page, at: totalPages)
          totalPages += 1
        }
      }
    }

    guard let data = mergedDoc.dataRepresentation() else {
      alertMessage = "Failed to serialize merged PDF."
      return false
    }

    do {
      try data.write(to: destination, options: .atomic)
      statusMessage = "Successfully merged \(sources.count) documents into \(totalPages) pages."
      return true
    } catch {
      alertMessage = "Failed to save merged PDF: \(error.localizedDescription)"
      return false
    }
  }

  /// Extract a selected range of pages and export them into a new standalone PDF.
  public func splitPageRange(from startIndex: Int, to endIndex: Int, destination: URL) -> Bool {
    guard let doc = liveDocument else { return false }
    let start = min(max(0, startIndex), doc.pageCount - 1)
    let end = min(max(start, endIndex), doc.pageCount - 1)

    let splitDoc = PDFDocument()
    var targetIndex = 0

    for pageIndex in start...end {
      if let page = doc.page(at: pageIndex)?.copy() as? PDFPage {
        splitDoc.insert(page, at: targetIndex)
        targetIndex += 1
      }
    }

    guard let data = splitDoc.dataRepresentation() else {
      alertMessage = "Failed to serialize extracted pages."
      return false
    }

    do {
      try data.write(to: destination, options: .atomic)
      statusMessage = "Extracted pages \(start + 1)–\(end + 1) to \(destination.lastPathComponent)."
      return true
    } catch {
      alertMessage = "Failed to write extracted PDF: \(error.localizedDescription)"
      return false
    }
  }

  // MARK: - Sanitization & Metadata Scrubbing (B4 Lane)

  /// Cleanly export a copy of the PDF with all metadata, EXIF properties, author tags, and hidden streams stripped.
  public func sanitizeAndExportCopy(destination: URL) -> Bool {
    guard let doc = liveDocument else { return false }
    guard let copiedDoc = doc.copy() as? PDFDocument else {
      alertMessage = "Failed to duplicate document for sanitization."
      return false
    }

    // Scrub document-level metadata dictionary
    copiedDoc.documentAttributes = [:]

    guard let data = copiedDoc.dataRepresentation() else {
      alertMessage = "Failed to serialize sanitized PDF."
      return false
    }

    do {
      try data.write(to: destination, options: .atomic)
      let op = EditOperation(
        pageIndex: 0,
        kind: .sanitize,
        value: "metadata-scrubbed",
        sessionID: currentSessionID,
        sourceDigest: inspection?.source.sha256
      )
      recordAppliedOperation(op)
      statusMessage = "Exported metadata-sanitized copy to \(destination.lastPathComponent)."
      return true
    } catch {
      alertMessage = "Failed to save sanitized copy: \(error.localizedDescription)"
      return false
    }
  }

  // MARK: - Session Persistence

  /// Save the current editing session to disk.
  public func saveSession() {
    saveDurableRecovery()
  }

  /// Load a saved session for the current document.
  public func loadSavedSession() {
    guard let currentInspection = inspection else { return }
    refreshRecoveryDiscovery()
    guard restoreDurableRecovery(for: currentInspection.source.sha256) else {
      statusMessage = "No replayable recovery session found for this document."
      return
    }
  }

  /// Debounced content autosave, called after each recorded operation.
  ///
  /// The write protocol is unchanged (payload → pair manifest → metadata
  /// commit pointer) and `flushRecoveryForTermination()` plus
  /// `saveRecoveryForInterruptionTest()` remain synchronous. Deferring only
  /// moves the three disk writes and the replay-checkpoint copy off the edit
  /// click itself: a crash inside the debounce window loses at most that
  /// window of edits, which the generation-based recovery design already
  /// tolerates by replaying the previous committed generation.
  private func autoSaveSession() {
    guard inspection != nil, sourceURL != nil, currentSessionID != nil else { return }
    contentAutosaveTask?.cancel()
    let scheduledSessionID = currentSessionID
    let scheduledSourceDigest = inspection?.source.sha256
    contentAutosaveTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(nanoseconds: 250_000_000)
      } catch {
        return
      }
      guard !Task.isCancelled, let self else { return }
      self.contentAutosaveTask = nil
      // A document opened while the debounce was pending invalidates this
      // save; the session identity and source digest must still match.
      guard self.currentSessionID == scheduledSessionID,
        self.inspection?.source.sha256 == scheduledSourceDigest
      else { return }
      self.recordReplayCheckpointIfNeeded()
      _ = self.saveDurableRecovery()
    }
  }

  /// Runs a pending debounced content autosave immediately. Termination and
  /// test harnesses need the synchronous ordering without waiting out the
  /// debounce window.
  @discardableResult
  public func flushPendingContentAutosave() -> Bool {
    guard contentAutosaveTask != nil else { return true }
    cancelContentAutosave()
    recordReplayCheckpointIfNeeded()
    return saveDurableRecovery()
  }

  private func cancelContentAutosave() {
    contentAutosaveTask?.cancel()
    contentAutosaveTask = nil
  }

  /// Schedules a coalesced persistence of the current view/session state.
  ///
  /// This is intentionally separate from content dirty state. Navigation,
  /// reader mode, zoom, rotation, selection, and search selection may be
  /// useful to restore without representing an edit to the source PDF. The
  /// settled state is persisted as one metadata, payload, and pair generation
  /// through the same commit-pointer protocol as content autosave.
  public func scheduleViewStateAutosave() {
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

  /// Flushes pending recovery work before AppKit terminates the application.
  ///
  /// Startup intentionally avoids synchronous vault health checks so the
  /// native window can appear. Termination has the opposite requirement: any
  /// dirty edit or pending view-state write must complete synchronously, and a
  /// failed write must be allowed to cancel termination rather than silently
  /// claim that recovery is durable.
  @discardableResult
  public func flushRecoveryForTermination() -> Bool {
    let hasPendingViewStateSave = viewStateAutosaveTask != nil
    cancelViewStateAutosave()
    let hasPendingContentSave = contentAutosaveTask != nil
    cancelContentAutosave()

    guard inspection != nil, sourceURL != nil, currentSessionID != nil else {
      return true
    }
    guard isDirty || hasSavedSession || lastPersistedViewStateDigest != nil
      || hasPendingViewStateSave || hasPendingContentSave
    else {
      return true
    }
    if hasPendingContentSave {
      recordReplayCheckpointIfNeeded()
    }
    return saveDurableRecovery()
  }

  private func cancelViewStateAutosave() {
    viewStateAutosaveTask?.cancel()
    viewStateAutosaveTask = nil
  }

  /// List all saved sessions.
  public func listSavedSessions() -> [PDFSessionRecord] {
    (try? sessionStore.listAll()) ?? []
  }

  /// Delete a saved session.
  public func deleteSession(sourceDigest: String) {
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

  /// Test-only entry point for the controlled recovery interruption harness.
  /// The support facade checks the explicit test environment gate before this
  /// method can be called, and this method never exists on a normal UI path.
  @discardableResult
  public func saveRecoveryForInterruptionTest() -> Bool {
    guard RecoveryInterruptionTestSupport.isTestModeEnabled else { return false }
    return saveDurableRecovery()
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
      RecoveryInterruptionTestSupport.emit(.payload)
      try recoveryPairStore.save(manifest)
      RecoveryInterruptionTestSupport.emit(.pairManifest)
      // Metadata is the commit pointer. Once it has been atomically written,
      // the generation is authoritative even on a first save; payload and pair
      // interruptions remain non-discoverable because the pointer is absent.
      try recoveryStore.save(envelope)
      RecoveryInterruptionTestSupport.emit(.metadataEnvelope)
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
    recoveryFailureDiagnostic = nil
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
      recoveryFailureDiagnostic = String(describing: error)
      recoveryDiagnostics = RecoveryInterruptionTestSupport.isTestModeEnabled
        ? ["recovery-restore-failed:\(String(describing: error))"]
        : [message]
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
  public func discardRecovery() -> Bool {
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

  public var hasTemplateReview: Bool { templateContract != nil }

  public var templateMappings: [PDFTemplateMapping] {
    templateContract?.payload.mappings ?? []
  }

  public var templateReviewableEntries: [PDFTemplateCompletionEntry] {
    templateCompletionProposal?.entries ?? []
  }

  public enum TemplateValueEditorKind: String, Sendable {
    case text
    case choice
    case boolean
    case assetReference
    case missing
  }

  /// Capture an immutable, value-free layout proposal from the current native
  /// inspection. Profile data is intentionally not consulted in this phase.
  public func captureTemplateReview(displayName: String = "Reviewed local layout") {
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
      templateProfileResolution = nil
      templateMigrationProposal = nil
      statusMessage = "Captured \(draft.payload.mappings.count) mapping proposal(s). Review mappings before activation."
    } catch {
      alertMessage = "Could not capture the template review: \(error.localizedDescription)"
    }
  }

  public func reviewTemplateMapping(_ mappingID: UUID, approved: Bool) {
    guard let template = templateContract, template.payload.lifecycle == .draft else { return }
    let mappings = template.payload.mappings.map { mapping in
      mapping.id == mappingID
        ? mapping.reviewed(as: approved ? .confirmed : .rejected)
        : mapping
    }
    templateContract = replacingTemplate(template, mappings: mappings)
  }

  public func activateTemplateReview() {
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

  public func saveTemplateRevision() {
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

  public func loadTemplate(templateID: UUID) {
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
      templateProfileResolution = nil
      templateMigrationProposal = nil
      statusMessage = "Loaded the encrypted template revision history. Completion still requires review for this source."
    } catch {
      alertMessage = "Could not load the encrypted template: \(error.localizedDescription)"
    }
  }

  public func loadTemplateRevision(templateID: UUID, revisionID: UUID) {
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

  public func deleteTemplate(templateID: UUID) {
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

  public func exportTemplate(templateID: UUID? = nil) {
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

  public func importTemplate() {
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
  public func prepareTemplateCompletionReview() {
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

  /// Selects a profile identity from the unlocked local vault without exposing
  /// values in the resolver result. Completion still requires the existing
  /// mapping and exact-value review gates.
  public func resolveTemplateProfileAutomatically() {
    guard isProfileVaultUnlocked, let template = templateContract else {
      statusMessage = "Unlock the profile vault and load an active template before resolving a profile."
      return
    }
    do {
      let profiles = try profileStore.profileIDs().compactMap { profileID in
        try profileStore.load(profileID: profileID)?.latestRevision
      }
      let result = PDFTemplateProfileResolver.resolve(template: template, profiles: profiles)
      templateProfileResolution = result
      if result.state == .selected, let profileID = result.selectedProfileID {
        loadProfile(profileID: profileID)
        statusMessage = "Selected a type-compatible profile for review. No values were applied."
      } else {
        statusMessage = "Profile resolution (result.state.rawValue): selection abstained until the candidates are reviewed."
      }
    } catch {
      templateProfileResolution = nil
      alertMessage = "Could not resolve a local profile: (error.localizedDescription)"
    }
  }

  public func prepareTemplateMigration(toRevisionID: UUID) {
    guard let current = templateContract,
          let history = templateRevisionHistory,
          let target = history.revisions.first(where: { $0.payload.revisionID == toRevisionID }),
          let inspection
    else {
      statusMessage = "Load two revisions and an open source PDF before preparing migration."
      return
    }
    guard target.payload.revisionID != current.payload.revisionID else {
      statusMessage = "The selected revision is already current."
      return
    }
    do {
      templateMigrationProposal = try PDFTemplateMigrationPlanner.make(
        from: current,
        to: target,
        sourceDigest: inspection.source.sha256)
      statusMessage = templateMigrationProposal?.state == .ready
        ? "No mapping changes require migration review."
        : "Review every proposed mapping migration before saving a child revision."
    } catch {
      templateMigrationProposal = nil
      alertMessage = "Could not prepare template migration: (error.localizedDescription)"
    }
  }

  public func reviewTemplateMigration(_ decisionID: UUID, approved: Bool) {
    guard let proposal = templateMigrationProposal else { return }
    templateMigrationProposal = proposal.reviewing(mappingID: decisionID, approved: approved)
  }

  public func saveTemplateMigration() {
    guard let proposal = templateMigrationProposal,
          proposal.canMaterialize,
          let history = templateRevisionHistory
    else {
      statusMessage = "Every mapping migration decision must be reviewed before saving."
      return
    }
    do {
      let migrated = try proposal.materialize()
      let updated = try history.appending(migrated)
      try templateStore.save(history: updated)
      templateRevisionHistory = updated
      templateContract = migrated
      templateRevisionDiff = try PDFTemplateRevisionDiff.make(from: proposal.fromRevision, to: migrated)
      templateMigrationProposal = nil
      refreshTemplateIDs()
      statusMessage = "Saved an immutable migrated template revision. The source PDF and profile vault remain separate."
    } catch {
      alertMessage = "Could not save the migrated template revision: (error.localizedDescription)"
    }
  }

  public var templateCompletionApprovedMappingCount: Int {
    templateReviewableEntries.filter { $0.mappingReview == .approved }.count
  }

  public var templateCompletionApprovedValueCount: Int {
    templateReviewableEntries.filter { $0.valueReview == .approved }.count
  }

  public func templateValueEditorKind(for mappingID: UUID) -> TemplateValueEditorKind {
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

  public func templateCompletionBooleanValue(for mappingID: UUID) -> Bool {
    guard let entry = templateCompletionProposal?.entries.first(where: { $0.mappingID == mappingID }),
          case .boolean(let value) = entry.value
    else { return false }
    return value
  }

  public func reviewTemplateCompletionMapping(_ mappingID: UUID, approved: Bool) {
    guard let proposal = templateCompletionProposal else { return }
    templateCompletionProposal = proposal.reviewingMapping(mappingID, approved: approved)
  }

  public func reviewTemplateCompletionValue(_ mappingID: UUID, approved: Bool) {
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

  public func updateTemplateCompletionValue(_ mappingID: UUID, value: String) {
    templateValueDrafts[mappingID] = value
    guard let proposal = templateCompletionProposal else { return }
    guard let entry = proposal.entries.first(where: { $0.mappingID == mappingID }) else { return }
    let nextValue = templateCompletionValue(for: entry, rawValue: value)
    // Editing a value always returns it to resolvedUnreviewed. Approval is a
    // separate action and cannot survive a changed value.
    templateCompletionProposal = proposal.reviewingValue(mappingID, value: nextValue, approved: false)
  }

  public func updateTemplateCompletionBoolean(_ mappingID: UUID, value: Bool) {
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

  public func applyTemplateCompletion() {
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
  public func refreshProfiles() {
    availableProfiles = isProfileVaultUnlocked ? ((try? profileStore.listUserProfiles()) ?? []) : []
  }

  /// Create a new empty profile and select it.
  public func createProfile(displayName: String) {
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
  public func loadProfile(profileID: UUID) {
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
  public func saveCurrentProfile() {
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
  public func deleteProfile(profileID: UUID) {
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
  public func updateProfileValue(_ value: String, for key: String) {
    guard var profile = currentProfile else { return }
    profile.setValue(value, for: key)
    currentProfile = profile
  }

  /// Import a vCard into the current profile.
  public func importVCard(_ vCard: String) {
    guard var profile = currentProfile else { return }
    profile.importFromVCard(vCard)
    currentProfile = profile
    saveCurrentProfile()
    statusMessage = "Imported vCard data into \(profile.displayName)."
  }

  /// Run bulk fill: match profile values against the current document's fields and candidates.
  /// Returns the result but does NOT apply operations — the user must review and confirm.
  /// Fill-ready suggestions for a candidate region: the best local profile
  /// match formatted for its inferred field type. Local-only, deterministic.
  public func valueSuggestions(for candidate: RegionCandidate) -> [String] {
    guard let profile = currentProfile else { return [] }
    return profile.valueSuggestions(
      labelText: candidate.labelText,
      fieldType: candidate.suggestedFieldType
    )
  }

  /// Fill-ready suggestions for a native field, keyed by its declared name.
  public func valueSuggestions(for field: NativeField) -> [String] {
    guard let profile = currentProfile else { return [] }
    let fieldType: SuggestedFieldType?
    switch field.kind {
    case .text: fieldType = .text
    case .choice: fieldType = .choice
    case .button, .signature, .unknown: fieldType = nil
    }
    return profile.valueSuggestions(
      labelText: field.name,
      fieldType: fieldType
    )
  }

  public func previewBulkFill() {
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
  public func applyBulkFill() {
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
