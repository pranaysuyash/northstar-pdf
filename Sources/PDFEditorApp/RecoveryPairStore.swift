import Foundation
import PDFEditorCore

/// The commit record joining one metadata envelope to one value-bearing
/// payload generation. It is intentionally separate from both records so a
/// payload cannot authenticate itself by changing its own stored digest.
struct RecoveryPairManifest: Codable, Equatable, Sendable {
  static let contractName = "pdf-editor.document-session-recovery-pair"
  static let schemaVersion = 1

  let contract: String
  let schemaVersion: Int
  let sessionID: UUID
  let sourceDigest: String
  let autosaveSequence: Int
  let metadataLedgerDigest: String
  let operationLedgerDigest: String
  let candidateStatusesDigest: String
  let viewStateDigest: String
  let payloadIdentityDigest: String
  let metadataUpdatedAt: Date
  let payloadUpdatedAt: Date

  init(
    sessionID: UUID,
    sourceDigest: String,
    autosaveSequence: Int,
    metadataLedgerDigest: String,
    operationLedgerDigest: String,
    candidateStatusesDigest: String,
    viewStateDigest: String,
    payloadIdentityDigest: String,
    metadataUpdatedAt: Date,
    payloadUpdatedAt: Date
  ) {
    self.contract = Self.contractName
    self.schemaVersion = Self.schemaVersion
    self.sessionID = sessionID
    self.sourceDigest = sourceDigest
    self.autosaveSequence = autosaveSequence
    self.metadataLedgerDigest = metadataLedgerDigest
    self.operationLedgerDigest = operationLedgerDigest
    self.candidateStatusesDigest = candidateStatusesDigest
    self.viewStateDigest = viewStateDigest
    self.payloadIdentityDigest = payloadIdentityDigest
    self.metadataUpdatedAt = metadataUpdatedAt
    self.payloadUpdatedAt = payloadUpdatedAt
  }
}

enum RecoveryPairStoreError: Error, LocalizedError {
  case invalidManifest(String)
  case decodingFailed(String)
  case directoryCreationFailed(String)
  case fileOperationFailed(String)

  var errorDescription: String? {
    switch self {
    case .invalidManifest(let message):
      "Recovery pair manifest is invalid: \(message)"
    case .decodingFailed(let fileName):
      "Recovery pair manifest is corrupted: \(fileName)"
    case .directoryCreationFailed(let message):
      "Recovery pair storage is unavailable: \(message)"
    case .fileOperationFailed(let message):
      "Recovery pair file operation failed: \(message)"
    }
  }
}

/// Stores generation-specific pair manifests. A new generation never
/// overwrites the previous manifest, so a failed envelope write leaves the
/// previous metadata, payload, and manifest generation recoverable together.
final class RecoveryPairStore: @unchecked Sendable {
  private let directory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let lock = NSLock()

  init(
    directory: URL = RecoveryPairStore.defaultDirectory,
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

  static var defaultDirectory: URL {
    SessionRecoveryStore.defaultDirectory
      .appendingPathComponent("PairManifests", isDirectory: true)
  }

  func save(_ manifest: RecoveryPairManifest) throws {
    lock.lock()
    defer { lock.unlock() }
    try validate(manifest)
    try ensureDirectory()
    do {
      let data = try encoder.encode(manifest)
      let url = url(for: manifest.sessionID, autosaveSequence: manifest.autosaveSequence)
      try data.write(to: url, options: [.atomic])
      try fileManager.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o600))],
        ofItemAtPath: url.path
      )
    } catch let error as RecoveryPairStoreError {
      throw error
    } catch {
      throw RecoveryPairStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  func load(sessionID: UUID, autosaveSequence: Int) throws -> RecoveryPairManifest? {
    lock.lock()
    defer { lock.unlock() }
    let fileURL = url(for: sessionID, autosaveSequence: autosaveSequence)
    guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
    do {
      let data = try Data(contentsOf: fileURL)
      let manifest = try decoder.decode(RecoveryPairManifest.self, from: data)
      guard manifest.sessionID == sessionID,
        manifest.autosaveSequence == autosaveSequence
      else {
        throw RecoveryPairStoreError.invalidManifest(
          "Session identity does not match its generation file."
        )
      }
      try validate(manifest)
      return manifest
    } catch let error as RecoveryPairStoreError {
      throw error
    } catch is DecodingError {
      throw RecoveryPairStoreError.decodingFailed(fileURL.lastPathComponent)
    } catch {
      throw RecoveryPairStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  func delete(sessionID: UUID) throws {
    lock.lock()
    defer { lock.unlock() }
    guard fileManager.fileExists(atPath: directory.path) else { return }
    do {
      let prefix = "\(sessionID.uuidString)."
      let urls = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      ).filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "pdfpair" }
      for url in urls {
        try fileManager.removeItem(at: url)
      }
    } catch {
      throw RecoveryPairStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  /// Removes unreferenced generation manifests after the metadata envelope
  /// has committed a new generation. Keeping the current generation and one
  /// known-good predecessor bounds sensitive recovery metadata while retaining
  /// a rollback point. Cleanup failures are thrown for user-facing reporting.
  func garbageCollectUnreferencedGenerations(
    sessionID: UUID,
    keepingAutosaveSequences: Set<Int>
  ) throws {
    lock.lock()
    defer { lock.unlock() }
    guard fileManager.fileExists(atPath: directory.path) else { return }

    do {
      let prefix = "\(sessionID.uuidString)."
      let suffix = ".pdfpair"
      let urls = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      ).filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "pdfpair" }
      for fileURL in urls {
        guard let sequence = autosaveSequence(in: fileURL, prefix: prefix, suffix: suffix) else {
          continue
        }
        if !keepingAutosaveSequences.contains(sequence) {
          try fileManager.removeItem(at: fileURL)
        }
      }
    } catch {
      throw RecoveryPairStoreError.fileOperationFailed(
        "Recovery pair retention cleanup failed: \(error.localizedDescription)"
      )
    }
  }

  private func ensureDirectory() throws {
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      try fileManager.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o700))],
        ofItemAtPath: directory.path
      )
    } catch {
      throw RecoveryPairStoreError.directoryCreationFailed(error.localizedDescription)
    }
  }

  private func validate(_ manifest: RecoveryPairManifest) throws {
    guard manifest.contract == RecoveryPairManifest.contractName else {
      throw RecoveryPairStoreError.invalidManifest("Unexpected recovery pair contract.")
    }
    guard manifest.schemaVersion == RecoveryPairManifest.schemaVersion else {
      throw RecoveryPairStoreError.invalidManifest("Unsupported recovery pair schema.")
    }
    guard manifest.autosaveSequence > 0,
      !manifest.sourceDigest.isEmpty,
      !manifest.metadataLedgerDigest.isEmpty,
      !manifest.operationLedgerDigest.isEmpty,
      !manifest.payloadIdentityDigest.isEmpty
    else {
      throw RecoveryPairStoreError.invalidManifest("Required pair identity is missing.")
    }
  }

  private func url(for sessionID: UUID, autosaveSequence: Int) -> URL {
    directory.appendingPathComponent(
      "\(sessionID.uuidString).\(autosaveSequence).pdfpair"
    )
  }

  private func autosaveSequence(in fileURL: URL, prefix: String, suffix: String) -> Int? {
    let name = fileURL.lastPathComponent
    guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
    let start = name.index(name.startIndex, offsetBy: prefix.count)
    let end = name.index(name.endIndex, offsetBy: -suffix.count)
    return Int(name[start..<end])
  }
}
