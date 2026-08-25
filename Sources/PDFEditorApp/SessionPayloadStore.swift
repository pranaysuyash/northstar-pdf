import Foundation
import CryptoKit
import PDFEditorCore

/// The value-bearing half of the recovery contract.
///
/// `DocumentSessionRecoveryEnvelope` deliberately contains no edit values.
/// This record is therefore stored separately, under a different directory,
/// with its own schema, permissions, retention, and integrity checks. It is
/// never valid on its own: AppModel must bind it to the metadata envelope
/// before using the operations for replay.
struct SessionPayloadRecord: Codable, Equatable, Sendable {
  static let contractName = "pdf-editor.document-session-recovery-payload"
  static let schemaVersion = 2

  let contract: String
  let schemaVersion: Int
  let sessionID: UUID
  let sourceDigest: String
  let autosaveSequence: Int
  let operationLedgerDigest: String
  let metadataLedgerDigest: String
  let candidateStatusesDigest: String
  let viewStateDigest: String
  let payloadIdentityDigest: String
  let operations: [EditOperation]
  let candidateStatuses: [UUID: CandidateStatus]
  let selectedPageIndex: Int
  let updatedAt: Date

  init(
    sessionID: UUID,
    sourceDigest: String,
    autosaveSequence: Int = 1,
    operationLedgerDigest: String,
    metadataLedgerDigest: String,
    operations: [EditOperation],
    candidateStatuses: [UUID: CandidateStatus],
    viewStateDigest: String = "legacy-view-state",
    selectedPageIndex: Int,
    updatedAt: Date = Date()
  ) {
    self.contract = Self.contractName
    self.schemaVersion = Self.schemaVersion
    self.sessionID = sessionID
    self.sourceDigest = sourceDigest
    self.autosaveSequence = autosaveSequence
    self.operationLedgerDigest = operationLedgerDigest
    self.metadataLedgerDigest = metadataLedgerDigest
    self.candidateStatusesDigest = RecoveryLedgerIdentity.candidateStatusDigest(candidateStatuses)
    self.viewStateDigest = viewStateDigest
    self.operations = operations
    self.candidateStatuses = candidateStatuses
    self.selectedPageIndex = max(0, selectedPageIndex)
    self.updatedAt = updatedAt
    self.payloadIdentityDigest = RecoveryLedgerIdentity.payloadDigest(
      contract: self.contract,
      schemaVersion: self.schemaVersion,
      sessionID: self.sessionID,
      sourceDigest: self.sourceDigest,
      autosaveSequence: self.autosaveSequence,
      operationLedgerDigest: self.operationLedgerDigest,
      metadataLedgerDigest: self.metadataLedgerDigest,
      candidateStatusesDigest: self.candidateStatusesDigest,
      viewStateDigest: self.viewStateDigest,
      operations: self.operations,
      selectedPageIndex: self.selectedPageIndex
    )
  }
}

/// Schema policy for the value-bearing recovery plane.
///
/// Schema v2 is the current format. Older and unknown versions are
/// intentionally quarantined rather than guessed at or partially replayed.
/// The metadata envelope remains discoverable, so the user receives a
/// metadata-only recovery explanation instead of a silent loss or unsafe
/// migration.
enum SessionPayloadSchemaDisposition: Equatable, Sendable {
  case current
  case quarantine(reason: String)

  static func forVersion(_ version: Int) -> Self {
    if version == SessionPayloadRecord.schemaVersion {
      return .current
    }
    if version < SessionPayloadRecord.schemaVersion {
      return .quarantine(reason: "This older payload format has no approved migration path.")
    }
    return .quarantine(reason: "This payload was written by a newer app version.")
  }
}

enum SessionPayloadStoreError: Error, LocalizedError {
  case invalidRecord(String)
  case quarantinedSchema(version: Int, reason: String)
  case quarantinedRecord(reason: String)
  case keyUnavailable
  case authenticationFailed
  case encodingFailed(String)
  case decodingFailed(String)
  case directoryCreationFailed(String)
  case fileOperationFailed(String)
  case quarantineFailed

  var errorDescription: String? {
    switch self {
    case .invalidRecord(let message):
      "Recovery payload is invalid: \(message)"
    case .quarantinedSchema(let version, let reason):
      "Recovery payload schema v\(version) was quarantined: \(reason)"
    case .quarantinedRecord(let reason):
      "Recovery payload was quarantined: \(reason)"
    case .keyUnavailable:
      "Recovery payload encryption key is unavailable."
    case .authenticationFailed:
      "Recovery payload authentication failed."
    case .encodingFailed(let message):
      "Recovery payload could not be encoded: \(message)"
    case .decodingFailed(let message):
      "Recovery payload is corrupted: \(message)"
    case .directoryCreationFailed(let message):
      "Recovery payload storage is unavailable: \(message)"
    case .fileOperationFailed(let message):
      "Recovery payload file operation failed: \(message)"
    case .quarantineFailed:
      "Recovery payload could not be quarantined safely."
    }
  }
}

/// Local, restrictive, sensitive, value-bearing recovery storage.
///
/// The payload plane can contain user-entered values and profile-derived
/// values because it stores the full operations required by provider replay.
/// It intentionally does not contain source PDF bytes or OCR text, but it is
/// not value-free. The on-disk representation is an authenticated AES-GCM
/// envelope whose key is stable in the user's Keychain. Filesystem
/// permissions remain a second, independent local access-control boundary.
final class SessionPayloadStore: @unchecked Sendable {
  private struct EncryptedPayloadRecord: Codable {
    static let contractName = "pdf-editor.document-session-recovery-payload-encrypted"
    static let formatVersion = 1

    let contract: String
    let formatVersion: Int
    let sessionID: UUID
    let autosaveSequence: Int
    let sourceDigest: String
    let payloadSchemaVersion: Int
    let combinedCiphertext: Data
  }

  private struct AuthenticatedContext: Codable {
    let contract: String
    let formatVersion: Int
    let sessionID: UUID
    let autosaveSequence: Int
    let sourceDigest: String
    let payloadSchemaVersion: Int
  }

  private let directory: URL
  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let keyStore: RecoveryPayloadKeyStore
  private let lock = NSLock()

  init(
    directory: URL = SessionPayloadStore.defaultDirectory,
    fileManager: FileManager = .default,
    keyStore: RecoveryPayloadKeyStore = .shared
  ) {
    self.directory = directory
    self.fileManager = fileManager
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
    self.encoder.outputFormatting = [.sortedKeys]
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
    self.keyStore = keyStore
  }

  static var defaultDirectory: URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    return appSupport
      .appendingPathComponent("PDFEditor", isDirectory: true)
      .appendingPathComponent("RecoveryPayloads", isDirectory: true)
  }

  private var quarantineDirectory: URL {
    directory.appendingPathComponent("Quarantine", isDirectory: true)
  }

  func save(_ record: SessionPayloadRecord) throws {
    lock.lock()
    defer { lock.unlock() }

    try validate(record)
    try ensureDirectory()

    let data: Data
    do {
      let plaintext = try encoder.encode(record)
      let key = try keyStore.loadOrCreateKey()
      let context = try authenticatedContext(for: record)
      let sealedBox = try AES.GCM.seal(
        plaintext,
        using: key,
        authenticating: context
      )
      guard let combinedCiphertext = sealedBox.combined else {
        throw SessionPayloadStoreError.encodingFailed(
          "Authenticated payload encoding produced no ciphertext."
        )
      }
      data = try encoder.encode(
        EncryptedPayloadRecord(
          contract: EncryptedPayloadRecord.contractName,
          formatVersion: EncryptedPayloadRecord.formatVersion,
          sessionID: record.sessionID,
          autosaveSequence: record.autosaveSequence,
          sourceDigest: record.sourceDigest,
          payloadSchemaVersion: record.schemaVersion,
          combinedCiphertext: combinedCiphertext
        )
      )
    } catch let error as SessionPayloadStoreError {
      throw error
    } catch {
      if error is RecoveryPayloadKeyStoreError {
        throw SessionPayloadStoreError.keyUnavailable
      }
      throw SessionPayloadStoreError.encodingFailed(
        "Recovery payload encryption failed."
      )
    }

    do {
      let fileURL = url(for: record.sessionID, autosaveSequence: record.autosaveSequence)
      try data.write(to: fileURL, options: [.atomic])
      try fileManager.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o600))],
        ofItemAtPath: fileURL.path
      )
    } catch {
      throw SessionPayloadStoreError.fileOperationFailed(
        "Recovery payload file operation failed."
      )
    }
  }

  func load(sessionID: UUID) throws -> SessionPayloadRecord? {
    lock.lock()
    defer { lock.unlock() }

    guard let sequence = try latestAutosaveSequence(for: sessionID) else { return nil }
    return try loadUnlocked(sessionID: sessionID, autosaveSequence: sequence)
  }

  func load(sessionID: UUID, autosaveSequence: Int) throws -> SessionPayloadRecord? {
    lock.lock()
    defer { lock.unlock() }

    let fileURL = url(for: sessionID, autosaveSequence: autosaveSequence)
    guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
    return try loadUnlocked(sessionID: sessionID, autosaveSequence: autosaveSequence)
  }

  private func loadUnlocked(sessionID: UUID, autosaveSequence: Int) throws -> SessionPayloadRecord {
    let fileURL = url(for: sessionID, autosaveSequence: autosaveSequence)

    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch is DecodingError {
      try quarantine(fileURL)
      throw SessionPayloadStoreError.quarantinedRecord(
        reason: "The recovery payload format is unsupported."
      )
    } catch {
      throw SessionPayloadStoreError.fileOperationFailed(
        "Recovery payload file operation failed."
      )
    }

    let encryptedRecord: EncryptedPayloadRecord
    do {
      encryptedRecord = try decoder.decode(EncryptedPayloadRecord.self, from: data)
      try validate(encryptedRecord, sessionID: sessionID, autosaveSequence: autosaveSequence)
    } catch {
      try quarantine(fileURL)
      throw SessionPayloadStoreError.quarantinedRecord(
        reason: "The recovery payload format or identity is invalid."
      )
    }

    let plaintext: Data
    do {
      let key = try keyStore.loadOrCreateKey()
      let sealedBox = try AES.GCM.SealedBox(combined: encryptedRecord.combinedCiphertext)
      plaintext = try AES.GCM.open(
        sealedBox,
        using: key,
        authenticating: authenticatedContext(for: encryptedRecord)
      )
    } catch let error as RecoveryPayloadKeyStoreError {
      throw SessionPayloadStoreError.keyUnavailable
    } catch {
      try quarantine(fileURL)
      throw SessionPayloadStoreError.authenticationFailed
    }

    do {
      let record = try decoder.decode(SessionPayloadRecord.self, from: plaintext)
      guard record.sessionID == sessionID,
        record.autosaveSequence == autosaveSequence,
        record.sourceDigest == encryptedRecord.sourceDigest,
        record.schemaVersion == encryptedRecord.payloadSchemaVersion
      else {
        throw SessionPayloadStoreError.invalidRecord(
          "Recovery payload identity does not match its encrypted envelope."
        )
      }
      try validate(record)
      return record
    } catch {
      try quarantine(fileURL)
      throw SessionPayloadStoreError.quarantinedRecord(
        reason: "The authenticated recovery payload is invalid."
      )
    }
  }

  func delete(sessionID: UUID) throws {
    lock.lock()
    defer { lock.unlock() }

    do {
      guard fileManager.fileExists(atPath: directory.path) else { return }
      let prefix = "\(sessionID.uuidString)."
      let legacyName = "\(sessionID.uuidString).pdfpayload"
      let fileURLs = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      ).filter { url in
        (url.lastPathComponent.hasPrefix(prefix) || url.lastPathComponent == legacyName)
          && url.pathExtension == "pdfpayload"
      }
      for fileURL in fileURLs {
        try fileManager.removeItem(at: fileURL)
      }
      if fileManager.fileExists(atPath: quarantineDirectory.path) {
        let quarantinedURLs = try fileManager.contentsOfDirectory(
          at: quarantineDirectory,
          includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix(prefix) }
        for fileURL in quarantinedURLs {
          try fileManager.removeItem(at: fileURL)
        }
      }
    } catch {
      throw SessionPayloadStoreError.fileOperationFailed(
        "Recovery payload file operation failed."
      )
    }
  }

  /// Removes unreferenced generation files after a committed envelope has
  /// selected the current generation. The caller supplies the current
  /// generation and one known-good predecessor, so cleanup cannot remove the
  /// last committed rollback point. A failed removal is surfaced to the
  /// caller; it is never silently treated as successful cleanup.
  func garbageCollectUnreferencedGenerations(
    sessionID: UUID,
    keepingAutosaveSequences: Set<Int>
  ) throws {
    lock.lock()
    defer { lock.unlock() }

    guard fileManager.fileExists(atPath: directory.path) else { return }
    do {
      let prefix = "\(sessionID.uuidString)."
      let suffix = ".pdfpayload"
      let urls = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      ).filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "pdfpayload" }
      for fileURL in urls {
        guard let sequence = autosaveSequence(in: fileURL, prefix: prefix, suffix: suffix) else {
          continue
        }
        if !keepingAutosaveSequences.contains(sequence) {
          try fileManager.removeItem(at: fileURL)
        }
      }
    } catch {
      throw SessionPayloadStoreError.fileOperationFailed(
        "Recovery payload retention cleanup failed."
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
      throw SessionPayloadStoreError.directoryCreationFailed(
        "Recovery payload directory is unavailable."
      )
    }
  }

  private func ensureQuarantineDirectory() throws {
    do {
      try fileManager.createDirectory(
        at: quarantineDirectory,
        withIntermediateDirectories: true
      )
      try fileManager.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o700))],
        ofItemAtPath: quarantineDirectory.path
      )
    } catch {
      throw SessionPayloadStoreError.quarantineFailed
    }
  }

  private func quarantine(_ fileURL: URL) throws {
    try ensureQuarantineDirectory()
    let destination = quarantineDirectory.appendingPathComponent(
      "\(fileURL.lastPathComponent).\(UUID().uuidString).quarantined"
    )
    do {
      try fileManager.moveItem(at: fileURL, to: destination)
      try fileManager.setAttributes(
        [.posixPermissions: NSNumber(value: Int16(0o600))],
        ofItemAtPath: destination.path
      )
    } catch {
      throw SessionPayloadStoreError.quarantineFailed
    }
  }

  private func authenticatedContext(for record: SessionPayloadRecord) throws -> Data {
    try encoder.encode(
      AuthenticatedContext(
        contract: EncryptedPayloadRecord.contractName,
        formatVersion: EncryptedPayloadRecord.formatVersion,
        sessionID: record.sessionID,
        autosaveSequence: record.autosaveSequence,
        sourceDigest: record.sourceDigest,
        payloadSchemaVersion: record.schemaVersion
      )
    )
  }

  private func authenticatedContext(for record: EncryptedPayloadRecord) -> Data {
    (try? encoder.encode(
      AuthenticatedContext(
        contract: record.contract,
        formatVersion: record.formatVersion,
        sessionID: record.sessionID,
        autosaveSequence: record.autosaveSequence,
        sourceDigest: record.sourceDigest,
        payloadSchemaVersion: record.payloadSchemaVersion
      )
    )) ?? Data()
  }

  private func validate(
    _ record: EncryptedPayloadRecord,
    sessionID: UUID,
    autosaveSequence: Int
  ) throws {
    guard record.contract == EncryptedPayloadRecord.contractName,
      record.formatVersion == EncryptedPayloadRecord.formatVersion,
      record.sessionID == sessionID,
      record.autosaveSequence == autosaveSequence,
      !record.sourceDigest.isEmpty,
      !record.combinedCiphertext.isEmpty
    else {
      throw SessionPayloadStoreError.invalidRecord(
        "Encrypted recovery payload identity is invalid."
      )
    }
    switch SessionPayloadSchemaDisposition.forVersion(record.payloadSchemaVersion) {
    case .current:
      break
    case .quarantine(let reason):
      throw SessionPayloadStoreError.quarantinedSchema(
        version: record.payloadSchemaVersion,
        reason: reason
      )
    }
  }

  private func validate(_ record: SessionPayloadRecord) throws {
    guard record.contract == SessionPayloadRecord.contractName else {
      throw SessionPayloadStoreError.invalidRecord("Unexpected recovery payload contract.")
    }
    switch SessionPayloadSchemaDisposition.forVersion(record.schemaVersion) {
    case .current:
      break
    case .quarantine(let reason):
      throw SessionPayloadStoreError.quarantinedSchema(
        version: record.schemaVersion,
        reason: reason
      )
    }
    guard !record.sourceDigest.isEmpty else {
      throw SessionPayloadStoreError.invalidRecord("Source digest is empty.")
    }
    guard record.autosaveSequence > 0 else {
      throw SessionPayloadStoreError.invalidRecord("Autosave generation is invalid.")
    }
    guard record.operationLedgerDigest == RecoveryLedgerIdentity.operationDigest(record.operations) else {
      throw SessionPayloadStoreError.invalidRecord("Operation ledger identity does not match the payload.")
    }
    guard record.operations.allSatisfy({
      $0.sourceDigest == record.sourceDigest
    }) else {
      throw SessionPayloadStoreError.invalidRecord("Operation source does not match the session source.")
    }
    guard record.candidateStatusesDigest
      == RecoveryLedgerIdentity.candidateStatusDigest(record.candidateStatuses)
    else {
      throw SessionPayloadStoreError.invalidRecord("Candidate status identity does not match the payload.")
    }
    guard record.payloadIdentityDigest == RecoveryLedgerIdentity.payloadDigest(record) else {
      throw SessionPayloadStoreError.invalidRecord("Payload identity does not match its contents.")
    }
  }

  private func latestAutosaveSequence(for sessionID: UUID) throws -> Int? {
    guard fileManager.fileExists(atPath: directory.path) else { return nil }
    let prefix = "\(sessionID.uuidString)."
    let suffix = ".pdfpayload"
    let sequences = try fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    ).compactMap { fileURL -> Int? in
      let name = fileURL.lastPathComponent
      guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
      let start = name.index(name.startIndex, offsetBy: prefix.count)
      let end = name.index(name.endIndex, offsetBy: -suffix.count)
      return Int(name[start..<end])
    }
    return sequences.max()
  }

  private func autosaveSequence(in fileURL: URL, prefix: String, suffix: String) -> Int? {
    let name = fileURL.lastPathComponent
    guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
    let start = name.index(name.startIndex, offsetBy: prefix.count)
    let end = name.index(name.endIndex, offsetBy: -suffix.count)
    return Int(name[start..<end])
  }

  private func url(for sessionID: UUID, autosaveSequence: Int) -> URL {
    directory.appendingPathComponent(
      "\(sessionID.uuidString).\(autosaveSequence).pdfpayload"
    )
  }
}

/// Canonical identities shared by the metadata and payload recovery planes.
enum RecoveryLedgerIdentity {
  private struct CandidateStatusIdentity: Codable {
    let id: UUID
    let status: CandidateStatus
  }

  private struct PayloadIdentityMaterial: Codable {
    let contract: String
    let schemaVersion: Int
    let sessionID: UUID
    let sourceDigest: String
    let autosaveSequence: Int
    let operationLedgerDigest: String
    let metadataLedgerDigest: String
    let candidateStatusesDigest: String
    let viewStateDigest: String
    let operations: [EditOperation]
    let selectedPageIndex: Int
  }

  static func operationDigest(_ operations: [EditOperation]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(operations) else {
      return "operation-count:\(operations.count)"
    }
    return digest(data)
  }

  static func metadataDigest(_ metadata: [DocumentSessionOperationMetadata]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(metadata) else {
      return "metadata-count:\(metadata.count)"
    }
    return digest(data)
  }

  static func identifierDigest(_ identifier: String) -> String {
    digest(Data(identifier.utf8))
  }

  static func candidateStatusDigest(_ statuses: [UUID: CandidateStatus]) -> String {
    let material = statuses
      .map { CandidateStatusIdentity(id: $0.key, status: $0.value) }
      .sorted { $0.id.uuidString < $1.id.uuidString }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(material) else {
      return "candidate-status-count:\(statuses.count)"
    }
    return digest(data)
  }

  static func viewStateDigest(_ viewState: DocumentSessionViewState) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(viewState) else {
      return "view-state-page:\(viewState.selectedPageIndex)"
    }
    return digest(data)
  }

  static func payloadDigest(_ record: SessionPayloadRecord) -> String {
    payloadDigest(
      contract: record.contract,
      schemaVersion: record.schemaVersion,
      sessionID: record.sessionID,
      sourceDigest: record.sourceDigest,
      autosaveSequence: record.autosaveSequence,
      operationLedgerDigest: record.operationLedgerDigest,
      metadataLedgerDigest: record.metadataLedgerDigest,
      candidateStatusesDigest: record.candidateStatusesDigest,
      viewStateDigest: record.viewStateDigest,
      operations: record.operations,
      selectedPageIndex: record.selectedPageIndex
    )
  }

  static func payloadDigest(
    contract: String,
    schemaVersion: Int,
    sessionID: UUID,
    sourceDigest: String,
    autosaveSequence: Int,
    operationLedgerDigest: String,
    metadataLedgerDigest: String,
    candidateStatusesDigest: String,
    viewStateDigest: String,
    operations: [EditOperation],
    selectedPageIndex: Int
  ) -> String {
    let material = PayloadIdentityMaterial(
      contract: contract,
      schemaVersion: schemaVersion,
      sessionID: sessionID,
      sourceDigest: sourceDigest,
      autosaveSequence: autosaveSequence,
      operationLedgerDigest: operationLedgerDigest,
      metadataLedgerDigest: metadataLedgerDigest,
      candidateStatusesDigest: candidateStatusesDigest,
      viewStateDigest: viewStateDigest,
      operations: operations,
      selectedPageIndex: selectedPageIndex
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(material) else {
      return "payload-count:\(operations.count):generation:\(autosaveSequence)"
    }
    return digest(data)
  }

  private static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
