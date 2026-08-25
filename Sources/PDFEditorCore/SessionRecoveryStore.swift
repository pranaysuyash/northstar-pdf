import Foundation

/// Persistence errors for the metadata-only recovery store.
public enum SessionRecoveryStoreError: Error, LocalizedError, Sendable {
  case directoryCreationFailed(String)
  case encodingFailed(String)
  case decodingFailed(String)
  case fileOperationFailed(String)
  case unsupportedSchema(DocumentSessionSchemaVersion)
  case invalidEnvelope(String)
  case invalidFileName(String)
  case sessionIdentityMismatch(expected: UUID, actual: UUID)
  case filenameIdentityMismatch(
    fileName: String,
    filenameSessionID: UUID,
    envelopeSessionID: UUID
  )

  public var errorDescription: String? {
    switch self {
    case .directoryCreationFailed(let message):
      return "Could not create recovery directory: \(message)"
    case .encodingFailed(let message):
      return "Could not encode recovery envelope: \(message)"
    case .decodingFailed(let message):
      return "Could not decode recovery envelope: \(message)"
    case .fileOperationFailed(let message):
      return "Recovery file operation failed: \(message)"
    case .unsupportedSchema(let version):
      return "Unsupported recovery schema \(version.major).\(version.minor)."
    case .invalidEnvelope(let message):
      return "Invalid recovery envelope: \(message)"
    case .invalidFileName(let message):
      return "Invalid recovery file name: \(message)"
    case .sessionIdentityMismatch(let expected, let actual):
      return "Recovery session identity mismatch: expected \(expected.uuidString), found \(actual.uuidString)."
    case .filenameIdentityMismatch(
      let fileName,
      let filenameSessionID,
      let envelopeSessionID
    ):
      return "Recovery filename \(fileName) identifies \(filenameSessionID.uuidString), but the envelope identifies \(envelopeSessionID.uuidString)."
    }
  }
}

/// The reason a recovery record could not be admitted during discovery.
public enum SessionRecoveryCorruptionKind: String, Sendable {
  case invalidFileName
  case unreadable
  case decodingFailed
  case unsupportedSchema
  case invalidEnvelope
  case sessionIdentityMismatch
  case filenameIdentityMismatch
  case fileOperationFailed
}

/// A structured, non-fatal diagnostic for one recovery file.
///
/// The diagnostic intentionally contains only a file name and a sanitized
/// message. It does not include source bytes, OCR text, edit values, or other
/// document content.
public struct SessionRecoveryCorruption: Sendable, Equatable {
  public let fileName: String
  public let kind: SessionRecoveryCorruptionKind
  public let message: String

  public init(
    fileName: String,
    kind: SessionRecoveryCorruptionKind,
    message: String
  ) {
    self.fileName = fileName
    self.kind = kind
    self.message = message
  }
}

/// The result of recovery discovery.
///
/// Valid records remain available even when one or more files are corrupt.
/// Callers should surface `corruptions` as a recoverable warning rather than
/// treating a non-empty result as equivalent to a clean discovery.
public struct SessionRecoveryListResult: Sendable {
  public let envelopes: [DocumentSessionRecoveryEnvelope]
  public let corruptions: [SessionRecoveryCorruption]

  public init(
    envelopes: [DocumentSessionRecoveryEnvelope],
    corruptions: [SessionRecoveryCorruption]
  ) {
    self.envelopes = envelopes
    self.corruptions = corruptions
  }

  public var hasCorruptions: Bool {
    !corruptions.isEmpty
  }
}

/// Provider-neutral persistence for document-session recovery envelopes.
///
/// App-facing recovery discovery should always use `listRecoveries()`. It
/// returns both valid envelopes and structured corruption diagnostics, so a
/// partially damaged recovery directory cannot be mistaken for a clean one.
public protocol SessionRecoveryStoring: Sendable {
  func save(_ envelope: DocumentSessionRecoveryEnvelope) throws
  func load(sessionID: UUID) throws -> DocumentSessionRecoveryEnvelope?

  /// Legacy compatibility projection that intentionally discards corruption
  /// diagnostics. New callers must use `listRecoveries()` instead.
  ///
  /// This requirement remains in the protocol so existing alternate store
  /// implementations and callers remain source-compatible while migrating to
  /// the diagnostic-preserving contract.
  func list() throws -> [DocumentSessionRecoveryEnvelope]

  /// Discovers recovery envelopes without hiding malformed or unreadable
  /// records.
  ///
  /// This is the preferred app-facing discovery contract. Callers must inspect
  /// both `envelopes` and `corruptions`, including when `envelopes` is non-empty.
  func listRecoveries() throws -> SessionRecoveryListResult
  func delete(sessionID: UUID) throws
}

public extension SessionRecoveryStoring {
  /// Compatibility adapter for existing alternate store implementations.
  ///
  /// Implementations that can inspect their backing store should override this
  /// method and return structured diagnostics. The default preserves source
  /// compatibility for legacy stores but cannot recover corruption information
  /// that their `list()` implementation does not expose.
  func listRecoveries() throws -> SessionRecoveryListResult {
    SessionRecoveryListResult(envelopes: try list(), corruptions: [])
  }
}

/// A local JSON recovery store using atomic replacement semantics.
///
/// `Data.write(to:options: .atomic)` writes a replacement file and keeps the
/// destination from being observed half-written. The store also serializes
/// access within one process and applies restrictive permissions to its
/// directory and files. The record remains metadata-only by construction.
public final class SessionRecoveryStore: SessionRecoveryStoring, @unchecked Sendable {
  private let directory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let lock = NSLock()

  public init(
    directory: URL,
    fileManager: FileManager = .default
  ) {
    self.directory = directory
    self.fileManager = fileManager
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
    self.encoder.outputFormatting = [.sortedKeys]
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
  }

  public static var defaultDirectory: URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    return appSupport
      .appendingPathComponent("PDFEditor", isDirectory: true)
      .appendingPathComponent("Recovery", isDirectory: true)
  }

  public func save(_ envelope: DocumentSessionRecoveryEnvelope) throws {
    lock.lock()
    defer { lock.unlock() }

    try validate(envelope)
    try ensureDirectory()

    let data: Data
    do {
      data = try encoder.encode(envelope)
    } catch {
      throw SessionRecoveryStoreError.encodingFailed(error.localizedDescription)
    }

    try write(data, to: url(for: envelope.session.sessionID))
  }

  public func load(sessionID: UUID) throws -> DocumentSessionRecoveryEnvelope? {
    lock.lock()
    defer { lock.unlock() }

    let fileURL = url(for: sessionID)
    guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

    do {
      let data = try Data(contentsOf: fileURL)
      let envelope = try decoder.decode(DocumentSessionRecoveryEnvelope.self, from: data)
      try validate(envelope, expectedSessionID: sessionID)
      return envelope
    } catch let error as SessionRecoveryStoreError {
      throw error
    } catch is DecodingError {
      throw SessionRecoveryStoreError.decodingFailed(
        "Recovery file is corrupted: \(fileURL.lastPathComponent)"
      )
    } catch {
      throw SessionRecoveryStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  /// Legacy compatibility projection. Prefer `listRecoveries()` so callers do
  /// not discard corruption diagnostics.
  @available(
    *,
    deprecated,
    message: "Use listRecoveries() to preserve recovery corruption diagnostics."
  )
  public func list() throws -> [DocumentSessionRecoveryEnvelope] {
    try listRecoveries().envelopes
  }

  public func listRecoveries() throws -> SessionRecoveryListResult {
    lock.lock()
    defer { lock.unlock() }

    guard fileManager.fileExists(atPath: directory.path) else {
      return SessionRecoveryListResult(envelopes: [], corruptions: [])
    }

    let files: [URL]
    do {
      files = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      ).filter { $0.pathExtension == "pdfsession" }
    } catch {
      throw SessionRecoveryStoreError.fileOperationFailed(error.localizedDescription)
    }

    var envelopes: [DocumentSessionRecoveryEnvelope] = []
    var corruptions: [SessionRecoveryCorruption] = []
    for fileURL in files {
      do {
        guard let filenameSessionID = UUID(
          uuidString: fileURL.deletingPathExtension().lastPathComponent
        ) else {
          throw SessionRecoveryStoreError.invalidFileName(
            "Recovery filename does not contain a valid session ID."
          )
        }
        let data = try Data(contentsOf: fileURL)
        let envelope = try decoder.decode(DocumentSessionRecoveryEnvelope.self, from: data)
        guard envelope.session.sessionID == filenameSessionID else {
          throw SessionRecoveryStoreError.filenameIdentityMismatch(
            fileName: fileURL.lastPathComponent,
            filenameSessionID: filenameSessionID,
            envelopeSessionID: envelope.session.sessionID
          )
        }
        try validate(envelope, expectedSessionID: filenameSessionID)
        envelopes.append(envelope)
      } catch {
        corruptions.append(corruption(for: error, fileURL: fileURL))
      }
    }

    let sortedEnvelopes = envelopes.sorted {
      $0.session.recovery.updatedAt > $1.session.recovery.updatedAt
    }
    let sortedCorruptions = corruptions.sorted {
      $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
    }
    return SessionRecoveryListResult(
      envelopes: sortedEnvelopes,
      corruptions: sortedCorruptions
    )
  }

  public func delete(sessionID: UUID) throws {
    lock.lock()
    defer { lock.unlock() }

    let fileURL = url(for: sessionID)
    guard fileManager.fileExists(atPath: fileURL.path) else { return }

    do {
      try fileManager.removeItem(at: fileURL)
    } catch {
      throw SessionRecoveryStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  private func ensureDirectory() throws {
    do {
      try fileManager.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      try fileManager.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o700))],
        ofItemAtPath: directory.path
      )
    } catch {
      throw SessionRecoveryStoreError.directoryCreationFailed(error.localizedDescription)
    }
  }

  private func write(_ data: Data, to fileURL: URL) throws {
    do {
      try data.write(to: fileURL, options: [.atomic])
      try fileManager.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o600))],
        ofItemAtPath: fileURL.path
      )
    } catch {
      throw SessionRecoveryStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  private func validate(
    _ envelope: DocumentSessionRecoveryEnvelope,
    expectedSessionID: UUID? = nil
  ) throws {
    guard envelope.contract == DocumentSessionRecoveryEnvelope.contractName else {
      throw SessionRecoveryStoreError.invalidEnvelope("Unexpected contract name.")
    }
    guard envelope.schemaVersion.isReadableBy() else {
      throw SessionRecoveryStoreError.unsupportedSchema(envelope.schemaVersion)
    }
    if let expectedSessionID,
       envelope.session.sessionID != expectedSessionID {
      throw SessionRecoveryStoreError.sessionIdentityMismatch(
        expected: expectedSessionID,
        actual: envelope.session.sessionID
      )
    }

    let sourceDigest = envelope.session.sourceDigest
    guard !sourceDigest.isEmpty else {
      throw SessionRecoveryStoreError.invalidEnvelope("Source digest is empty.")
    }
    guard envelope.sourceDigest == sourceDigest else {
      throw SessionRecoveryStoreError.invalidEnvelope(
        "Envelope source digest does not match the session source digest."
      )
    }
    if let inspection = envelope.session.inspectionReference,
       inspection.sourceDigest != sourceDigest {
      throw SessionRecoveryStoreError.invalidEnvelope(
        "Inspection reference does not match the source digest."
      )
    }
    if envelope.session.operationLedger.contains(where: {
      $0.sourceDigest != sourceDigest
    }) {
      throw SessionRecoveryStoreError.invalidEnvelope(
        "Operation metadata does not match the source digest."
      )
    }
    if envelope.session.operationLedger.contains(where: { $0.pageIndex < 0 }) {
      throw SessionRecoveryStoreError.invalidEnvelope(
        "Operation metadata contains a negative page index."
      )
    }
  }

  private func corruption(
    for error: Error,
    fileURL: URL
  ) -> SessionRecoveryCorruption {
    let kind: SessionRecoveryCorruptionKind
    let message: String

    if let recoveryError = error as? SessionRecoveryStoreError {
      switch recoveryError {
      case .unsupportedSchema:
        kind = .unsupportedSchema
      case .sessionIdentityMismatch:
        kind = .sessionIdentityMismatch
      case .filenameIdentityMismatch:
        kind = .filenameIdentityMismatch
      case .invalidEnvelope:
        kind = .invalidEnvelope
      case .invalidFileName:
        kind = .invalidFileName
      case .decodingFailed:
        kind = .decodingFailed
      case .fileOperationFailed:
        kind = .fileOperationFailed
      case .directoryCreationFailed, .encodingFailed:
        kind = .fileOperationFailed
      }
      message = recoveryError.localizedDescription
    } else if error is DecodingError {
      kind = .decodingFailed
      message = "Recovery file is corrupted."
    } else {
      kind = .unreadable
      message = "Recovery file could not be read."
    }

    let filename = fileURL.lastPathComponent
    return SessionRecoveryCorruption(
      fileName: filename,
      kind: kind,
      message: message
    )
  }

  private func url(for sessionID: UUID) -> URL {
    directory.appendingPathComponent(
      "\(sessionID.uuidString).pdfsession",
      isDirectory: false
    )
  }

}
