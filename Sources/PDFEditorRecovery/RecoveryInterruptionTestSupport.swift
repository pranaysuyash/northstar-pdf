import Foundation
import PDFEditorCore

/// Names the only persistence boundaries that the controlled interruption
/// harness is allowed to observe. The values are protocol labels, never
/// document content, operation values, paths, or encryption material.
public enum RecoveryInterruptionPhase: String, Codable, CaseIterable, Sendable {
  case payload
  case pairManifest = "pair-manifest"
  case metadataEnvelope = "metadata-envelope"
}

public extension Notification.Name {
  static let pdfEditorRecoveryWriteBoundary = Notification.Name(
    "PDFEditor.RecoveryWriteBoundary"
  )
}

/// Value-minimized observations returned by a fresh reader in interruption
/// tests. This is intentionally not a recovery record projection.
public struct RecoveryInterruptionObservation: Codable, Equatable, Sendable {
  public let committedGeneration: Int?
  public let discoveredEnvelopeCount: Int
  public let replayedOperationCount: Int
  public let recoveryStatus: String
  public let recoveryDiagnostic: String?

  public init(
    committedGeneration: Int?,
    discoveredEnvelopeCount: Int,
    replayedOperationCount: Int,
    recoveryStatus: String,
    recoveryDiagnostic: String? = nil
  ) {
    self.committedGeneration = committedGeneration
    self.discoveredEnvelopeCount = discoveredEnvelopeCount
    self.replayedOperationCount = replayedOperationCount
    self.recoveryStatus = recoveryStatus
    self.recoveryDiagnostic = recoveryDiagnostic
  }
}

/// Test-only bridge for exercising the production AppModel recovery path.
///
/// Normal application launches do not set `PDF_EDITOR_RECOVERY_INTERRUPTION_TEST`,
/// so boundary notifications and blocking behavior are inert. The bridge does
/// not expose payloads, keys, or source contents.
@MainActor
public enum RecoveryInterruptionTestSupport {
  nonisolated public static let testModeEnvironment = "PDF_EDITOR_RECOVERY_INTERRUPTION_TEST"
  nonisolated public static let childEnvironment = "PDF_EDITOR_RECOVERY_INTERRUPTION_CHILD"
  nonisolated public static let rootEnvironment = "PDF_EDITOR_RECOVERY_TEST_ROOT"
  nonisolated public static let sourceEnvironment = "PDF_EDITOR_RECOVERY_TEST_SOURCE"
  nonisolated public static let modeEnvironment = "PDF_EDITOR_RECOVERY_TEST_MODE"
  nonisolated public static let phaseEnvironment = "PDF_EDITOR_RECOVERY_TEST_PHASE"
  nonisolated public static let eventEnvironment = "PDF_EDITOR_RECOVERY_TEST_EVENT"
  nonisolated public static let keyAccountEnvironment = "PDF_EDITOR_RECOVERY_TEST_KEY_ACCOUNT"
  nonisolated public static let keyDataEnvironment = "PDF_EDITOR_RECOVERY_TEST_KEY_DATA"
  nonisolated public static let blockEnvironment = "PDF_EDITOR_RECOVERY_TEST_BLOCK"
  nonisolated public static let observerEnvironment = "PDF_EDITOR_RECOVERY_OBSERVER"
  nonisolated public static let observerOutputEnvironment = "PDF_EDITOR_RECOVERY_OBSERVER_OUTPUT"

  private static var boundaryArmed = true
  private static var diagnosticsArmed = false

  public static var isTestModeEnabled: Bool {
    ProcessInfo.processInfo.environment[testModeEnvironment] == "1" || diagnosticsArmed
  }

  private static var isBoundaryArmed: Bool {
    isTestModeEnabled && boundaryArmed
  }

  /// Emits a phase-only notification after a successful store write. When a
  /// test asks to interrupt this phase, the child remains here until its
  /// parent terminates it. No production environment can enter this branch.
  public static func emit(_ phase: RecoveryInterruptionPhase) {
    guard isBoundaryArmed else { return }

    NotificationCenter.default.post(
      name: .pdfEditorRecoveryWriteBoundary,
      object: nil,
      userInfo: ["phase": phase.rawValue]
    )

    if let eventPath = ProcessInfo.processInfo.environment[eventEnvironment],
      !eventPath.isEmpty
    {
      let eventURL = URL(fileURLWithPath: eventPath)
      try? Data(phase.rawValue.utf8).write(to: eventURL, options: [.atomic])
    }

    let environment = ProcessInfo.processInfo.environment
    guard environment[phaseEnvironment] == phase.rawValue,
      environment[blockEnvironment] == "1"
    else { return }

    while true {
      Thread.sleep(forTimeInterval: 0.02)
    }
  }

  /// Runs one isolated child scenario. Failure is reported only as a status
  /// code to the harness caller; source values and storage details are never
  /// printed.
  public static func runChild() -> Bool {
    guard isTestModeEnabled,
      ProcessInfo.processInfo.environment[childEnvironment] == "1",
      let rootPath = ProcessInfo.processInfo.environment[rootEnvironment],
      let sourcePath = ProcessInfo.processInfo.environment[sourceEnvironment],
      let mode = ProcessInfo.processInfo.environment[modeEnvironment],
      let keyAccount = ProcessInfo.processInfo.environment[keyAccountEnvironment],
      let encodedKeyData = ProcessInfo.processInfo.environment[keyDataEnvironment],
      let keyData = Data(base64Encoded: encodedKeyData)
    else { return false }

    let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
    let sourceURL = URL(fileURLWithPath: sourcePath)
    let model = makeModel(rootURL: rootURL, keyAccount: keyAccount, keyData: keyData)
    model.open(url: sourceURL)
    guard model.inspection != nil else { return false }

    appendSyntheticOperation(to: model, ordinal: 1)
    if mode == "update" {
      boundaryArmed = false
      let baselineSaved = model.saveRecoveryForInterruptionTest()
      boundaryArmed = true
      guard baselineSaved else { return false }
      appendSyntheticOperation(to: model, ordinal: 2)
    } else if mode != "first-save" {
      return false
    }

    return model.saveRecoveryForInterruptionTest()
  }

  /// Opens the source with fresh model state and lets AppModel perform its
  /// normal recovery discovery and staged replay. Only value-minimized state
  /// is returned for assertions.
  public static func reopenAndObserve(
    rootURL: URL,
    sourceURL: URL,
    keyAccount: String,
    keyData: Data
  ) -> RecoveryInterruptionObservation {
    let model = makeModel(rootURL: rootURL, keyAccount: keyAccount, keyData: keyData)
    diagnosticsArmed = true
    defer { diagnosticsArmed = false }
    model.open(url: sourceURL)
    let generation = model.recoveryRecords
      .map { $0.session.recovery.autosaveSequence }
      .max()
    return RecoveryInterruptionObservation(
      committedGeneration: generation,
      discoveredEnvelopeCount: model.recoveryRecords.count,
      replayedOperationCount: model.operations.count,
      recoveryStatus: model.recoveryStatus.rawValue,
      recoveryDiagnostic: model.recoveryFailureDiagnostic ?? model.recoveryDiagnostics.first
    )
  }

  /// Runs a fresh-reader observation in a separate process and writes only the
  /// value-minimized observation contract to an explicitly supplied file.
  /// This is used by the packaged native termination probe after the app exits.
  public static func runObserver() -> Bool {
    guard ProcessInfo.processInfo.environment[observerEnvironment] == "1",
      let rootPath = ProcessInfo.processInfo.environment[rootEnvironment],
      let sourcePath = ProcessInfo.processInfo.environment[sourceEnvironment],
      let keyAccount = ProcessInfo.processInfo.environment[keyAccountEnvironment],
      let encodedKeyData = ProcessInfo.processInfo.environment[keyDataEnvironment],
      let keyData = Data(base64Encoded: encodedKeyData),
      let outputPath = ProcessInfo.processInfo.environment[observerOutputEnvironment]
    else { return false }

    let observation = reopenAndObserve(
      rootURL: URL(fileURLWithPath: rootPath, isDirectory: true),
      sourceURL: URL(fileURLWithPath: sourcePath),
      keyAccount: keyAccount,
      keyData: keyData
    )
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let data = try encoder.encode(observation)
      try data.write(to: URL(fileURLWithPath: outputPath), options: [.atomic])
      return true
    } catch {
      return false
    }
  }

  /// Exercises the synchronous termination transaction without exposing
  /// payload values or requiring a live AppKit process. The native delegate
  /// invokes the same `AppModel` method before allowing termination.
  public static func runTerminationFlush(
    rootURL: URL,
    sourceURL: URL,
    keyAccount: String,
    keyData: Data
  ) -> (flushed: Bool, observation: RecoveryInterruptionObservation) {
    let model = makeModel(rootURL: rootURL, keyAccount: keyAccount, keyData: keyData)
    model.open(url: sourceURL)
    appendSyntheticOperation(to: model, ordinal: 1)
    let flushed = model.flushRecoveryForTermination()
    let observation = reopenAndObserve(
      rootURL: rootURL,
      sourceURL: sourceURL,
      keyAccount: keyAccount,
      keyData: keyData
    )
    return (flushed, observation)
  }

  private static func makeModel(rootURL: URL, keyAccount: String, keyData: Data) -> AppModel {
    let fileManager = FileManager.default
    let sessionDirectory = rootURL.appendingPathComponent("sessions", isDirectory: true)
    let metadataDirectory = rootURL.appendingPathComponent("metadata", isDirectory: true)
    let payloadDirectory = rootURL.appendingPathComponent("payload", isDirectory: true)
    let pairDirectory = rootURL.appendingPathComponent("pair", isDirectory: true)
    let profileDirectory = rootURL.appendingPathComponent("profiles", isDirectory: true)
    let templateDirectory = rootURL.appendingPathComponent("templates", isDirectory: true)
    try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

    let keyStore = RecoveryPayloadKeyStore(
      service: "com.pdfeditor.recovery-payload.test",
      account: keyAccount,
      testKeyData: keyData
    )
    return AppModel(
      sessionStore: FileSessionStore(directory: sessionDirectory),
      recoveryStore: SessionRecoveryStore(directory: metadataDirectory),
      recoveryPayloadStore: SessionPayloadStore(
        directory: payloadDirectory,
        keyStore: keyStore
      ),
      recoveryPairStore: RecoveryPairStore(directory: pairDirectory),
      profileStore: EncryptedPDFProfileVault(directory: profileDirectory),
      templateStore: EncryptedPDFTemplateStore(directory: templateDirectory),
      initializeLocalVaultState: false
    )
  }

  private static func appendSyntheticOperation(to model: AppModel, ordinal: Int) {
    guard let inspection = model.inspection,
      let page = inspection.pages.first,
      let sourceDigest = model.inspection?.source.sha256
    else { return }

    let bounds = PDFRect(
      x: page.bounds.x + 24,
      y: page.bounds.y + 24,
      width: min(160, max(48, page.bounds.width - 48)),
      height: 20
    )
    model.operations.append(EditOperation(
      pageIndex: page.pageIndex,
      targetID: "controlled-recovery-(ordinal)",
      kind: .overlayText,
      value: "controlled recovery test value (ordinal)",
      bounds: bounds,
      sessionID: model.sessionID,
      sourceDigest: sourceDigest,
      coordinate: PDFPageRegion(pageIndex: page.pageIndex, rect: bounds)
    ))
  }
}
