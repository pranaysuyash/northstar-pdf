import CryptoKit
import Foundation

/// Value-free lifecycle state shared by native and browser persistence
/// adapters. A recovery envelope restores access to key material; an encrypted
/// backup restores records after an evicting store has lost them.
public enum PDFLocalStoreHealthState: String, Codable, CaseIterable, Hashable, Sendable {
  case uninitialized
  case locked
  case ready
  case recovered
  case recoveryRequired = "recovery-required"
  case evicted
  case deleted
  case unknown
}

public enum PDFLocalStoreKind: String, Codable, CaseIterable, Hashable, Sendable {
  case template
  case profile
}

public enum PDFLocalStoreAuditAction: String, Codable, CaseIterable, Hashable, Sendable {
  case unlock
  case unlockFailure = "unlock-failure"
  case recoveryExport = "recovery-export"
  case recoveryImport = "recovery-import"
  case backupExport = "backup-export"
  case backupImport = "backup-import"
  case recordDelete = "record-delete"
  case storeDelete = "store-delete"
  case healthCheck = "health-check"
}

public enum PDFLocalStoreAuditOutcome: String, Codable, CaseIterable, Hashable, Sendable {
  case succeeded
  case failed
  case warning
}

public struct PDFLocalStoreAuditEvent: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let storeKind: PDFLocalStoreKind
  public let action: PDFLocalStoreAuditAction
  public let outcome: PDFLocalStoreAuditOutcome
  /// A one-way opaque token. It is never the template/profile ID or a value.
  public let recordToken: String?
  public let state: PDFLocalStoreHealthState
  public let reasonCode: String?
  public let createdAt: Date

  public init(
    id: UUID = UUID(),
    storeKind: PDFLocalStoreKind,
    action: PDFLocalStoreAuditAction,
    outcome: PDFLocalStoreAuditOutcome,
    recordToken: String? = nil,
    state: PDFLocalStoreHealthState,
    reasonCode: String? = nil,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.storeKind = storeKind
    self.action = action
    self.outcome = outcome
    self.recordToken = recordToken
    self.state = state
    self.reasonCode = reasonCode
    self.createdAt = createdAt
  }
}

public struct PDFLocalStoreAuditJournal: Codable, Equatable, Sendable {
  public let storeKind: PDFLocalStoreKind
  public let events: [PDFLocalStoreAuditEvent]

  public init(storeKind: PDFLocalStoreKind, events: [PDFLocalStoreAuditEvent] = []) throws {
    guard events.allSatisfy({ $0.storeKind == storeKind }) else {
      throw PDFTemplatePersistenceError.invalidRevisionHistory("persistence audit store kind mismatch")
    }
    guard Set(events.map(\.id)).count == events.count else {
      throw PDFTemplatePersistenceError.invalidRevisionHistory("persistence audit IDs must be unique")
    }
    self.storeKind = storeKind
    self.events = events
  }

  public func appending(_ event: PDFLocalStoreAuditEvent) throws -> PDFLocalStoreAuditJournal {
    guard event.storeKind == storeKind else {
      throw PDFTemplatePersistenceError.invalidRevisionHistory("persistence audit store kind mismatch")
    }
    guard !events.contains(where: { $0.id == event.id }) else {
      throw PDFTemplatePersistenceError.invalidRevisionHistory("duplicate persistence audit event")
    }
    return try PDFLocalStoreAuditJournal(storeKind: storeKind, events: events + [event])
  }
}

public struct PDFLocalStoreHealth: Codable, Equatable, Hashable, Sendable {
  public let storeKind: PDFLocalStoreKind
  public let state: PDFLocalStoreHealthState
  public let primaryAvailable: Bool
  public let backupAvailable: Bool
  public let recordCount: Int
  public let auditEventCount: Int
  public let recoveryEnvelopeAvailable: Bool
  public let encryptedBackupRecommended: Bool
  public let messageCode: String

  public init(
    storeKind: PDFLocalStoreKind,
    state: PDFLocalStoreHealthState,
    primaryAvailable: Bool,
    backupAvailable: Bool,
    recordCount: Int,
    auditEventCount: Int,
    recoveryEnvelopeAvailable: Bool,
    encryptedBackupRecommended: Bool,
    messageCode: String
  ) {
    self.storeKind = storeKind
    self.state = state
    self.primaryAvailable = primaryAvailable
    self.backupAvailable = backupAvailable
    self.recordCount = max(0, recordCount)
    self.auditEventCount = max(0, auditEventCount)
    self.recoveryEnvelopeAvailable = recoveryEnvelopeAvailable
    self.encryptedBackupRecommended = encryptedBackupRecommended
    self.messageCode = messageCode
  }
}

public struct PDFLocalStoreRecoveryEnvelope: Codable, Equatable, Hashable, Sendable {
  public let contractName: String
  public let version: PDFContractVersion
  public let storeKind: PDFLocalStoreKind
  public let keyIdentifier: String
  public let kdf: String
  public let iterations: Int
  public let salt: Data
  public let nonce: Data
  public let ciphertext: Data
  public let tag: Data
  public let createdAt: Date

  public init(
    storeKind: PDFLocalStoreKind,
    keyIdentifier: String,
    iterations: Int,
    salt: Data,
    nonce: Data,
    ciphertext: Data,
    tag: Data,
    createdAt: Date = Date()
  ) {
    self.contractName = "pdf-editor.local-store-recovery"
    self.version = PDFContractVersion(major: 1, minor: 0)
    self.storeKind = storeKind
    self.keyIdentifier = keyIdentifier
    self.kdf = "PBKDF2-HMAC-SHA256"
    self.iterations = iterations
    self.salt = salt
    self.nonce = nonce
    self.ciphertext = ciphertext
    self.tag = tag
    self.createdAt = createdAt
  }

  public func validate() throws {
    guard contractName == "pdf-editor.local-store-recovery",
          version == PDFContractVersion(major: 1, minor: 0),
          kdf == "PBKDF2-HMAC-SHA256",
          keyIdentifier.isEmpty == false,
          iterations >= 100_000,
          !salt.isEmpty,
          !nonce.isEmpty,
          !ciphertext.isEmpty,
          !tag.isEmpty
    else {
      throw PDFTemplatePersistenceError.invalidRevisionHistory("invalid passphrase recovery envelope")
    }
  }
}

public enum PDFLocalStoreRecoveryCrypto {
  public static let minimumPassphraseLength = 12
  public static let defaultIterations = 150_000

  public static func validatePassphrase(_ passphrase: String) throws {
    guard passphrase.count >= minimumPassphraseLength else {
      throw PDFTemplatePersistenceError.invalidPassphrase("passphrase must contain at least 12 characters")
    }
  }

  public static func makeEnvelope(
    keyData: Data,
    passphrase: String,
    storeKind: PDFLocalStoreKind,
    keyIdentifier: String,
    iterations: Int = defaultIterations
  ) throws -> PDFLocalStoreRecoveryEnvelope {
    guard !keyData.isEmpty else { throw PDFTemplatePersistenceError.emptyKey }
    try validatePassphrase(passphrase)
    let salt = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
    let key = SymmetricKey(data: pbkdf2(passphrase: passphrase, salt: salt, iterations: iterations))
    let authenticatedContext = Data("pdf-editor.local-store-recovery|\(storeKind.rawValue)|\(keyIdentifier)".utf8)
    let sealed = try AES.GCM.seal(keyData, using: key, authenticating: authenticatedContext)
    return PDFLocalStoreRecoveryEnvelope(
      storeKind: storeKind,
      keyIdentifier: keyIdentifier,
      iterations: iterations,
      salt: salt,
      nonce: Data(sealed.nonce),
      ciphertext: sealed.ciphertext,
      tag: sealed.tag)
  }

  public static func openEnvelope(_ envelope: PDFLocalStoreRecoveryEnvelope, passphrase: String) throws -> Data {
    try envelope.validate()
    try validatePassphrase(passphrase)
    let key = SymmetricKey(data: pbkdf2(passphrase: passphrase, salt: envelope.salt, iterations: envelope.iterations))
    let context = Data("pdf-editor.local-store-recovery|\(envelope.storeKind.rawValue)|\(envelope.keyIdentifier)".utf8)
    do {
      let sealed = try AES.GCM.SealedBox(
        nonce: AES.GCM.Nonce(data: envelope.nonce),
        ciphertext: envelope.ciphertext,
        tag: envelope.tag)
      return try AES.GCM.open(sealed, using: key, authenticating: context)
    } catch {
      throw PDFTemplatePersistenceError.decryptionFailed
    }
  }

  private static func pbkdf2(passphrase: String, salt: Data, iterations: Int) -> Data {
    let passwordKey = SymmetricKey(data: Data(passphrase.utf8))
    var input = salt
    var blockIndex = UInt32(1).bigEndian
    withUnsafeBytes(of: &blockIndex) { input.append(contentsOf: $0) }
    var u = Data(HMAC<SHA256>.authenticationCode(for: input, using: passwordKey))
    var output = u
    if iterations > 1 {
      for _ in 1..<iterations {
        u = Data(HMAC<SHA256>.authenticationCode(for: u, using: passwordKey))
        for index in output.indices { output[index] ^= u[index] }
      }
    }
    return output
  }
}

public enum PDFLocalStoreAuditIdentity {
  public static func token(_ recordID: String) -> String {
    SHA256.hash(data: Data(recordID.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}
