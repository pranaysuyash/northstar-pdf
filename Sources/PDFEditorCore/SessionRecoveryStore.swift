import Foundation

/// Persistence errors for the metadata-only recovery store.
public enum SessionRecoveryStoreError: Error, LocalizedError, Sendable {
  case directoryCreationFailed(String)
  case encodingFailed(String)
  case decodingFailed(String)
  case fileOperationFailed(String)
  case unsupportedSchema(DocumentSessionSchemaVersion)
  case invalidEnvelope(String)

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
    }
  }
}

/// Provider-neutral persistence for document-session recovery envelopes.
public protocol SessionRecoveryStoring: Sendable {
  func save(_ envelope: DocumentSessionRecoveryEnvelope) throws
  func load(sessionID: UUID) throws -> DocumentSessionRecoveryEnvelope?
  func list() throws -> [DocumentSessionRecoveryEnvelope]
  func delete(sessionID: UUID) throws
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

    do {
      let fileURL = url(for: envelope.session.sessionID)
      try data.write(to: fileURL, options: [.atomic])
      try fileManager.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o600))],
        ofItemAtPath: fileURL.path
      )
    } catch {
      throw SessionRecoveryStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  public func load(sessionID: UUID) throws -> DocumentSessionRecoveryEnvelope? {
    lock.lock()
    defer { lock.unlock() }

    let fileURL = url(for: sessionID)
    guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

    do {
      let data = try Data(contentsOf: fileURL)
      let envelope = try decoder.decode(DocumentSessionRecoveryEnvelope.self, from: data)
      try validate(envelope)
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

  public func list() throws -> [DocumentSessionRecoveryEnvelope] {
    lock.lock()
    defer { lock.unlock() }

    guard fileManager.fileExists(atPath: directory.path) else { return [] }

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
    for fileURL in files {
      do {
        let data = try Data(contentsOf: fileURL)
        let envelope = try decoder.decode(DocumentSessionRecoveryEnvelope.self, from: data)
        try validate(envelope)
        envelopes.append(envelope)
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

    return envelopes.sorted {
      $0.session.recovery.updatedAt > $1.session.recovery.updatedAt
    }
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

  private func validate(_ envelope: DocumentSessionRecoveryEnvelope) throws {
    guard envelope.contract == DocumentSessionRecoveryEnvelope.contractName else {
      throw SessionRecoveryStoreError.invalidEnvelope("Unexpected contract name.")
    }
    guard envelope.schemaVersion.isReadableBy() else {
      throw SessionRecoveryStoreError.unsupportedSchema(envelope.schemaVersion)
    }

    let sourceDigest = envelope.session.sourceDigest
    guard !sourceDigest.isEmpty else {
      throw SessionRecoveryStoreError.invalidEnvelope("Source digest is empty.")
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
  }

  private func url(for sessionID: UUID) -> URL {
    directory.appendingPathComponent(
      "\(sessionID.uuidString).pdfsession",
      isDirectory: false
    )
  }
}
