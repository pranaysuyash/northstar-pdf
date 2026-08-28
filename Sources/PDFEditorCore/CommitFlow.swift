import CryptoKit
import Foundation

/// COMMIT flow: the signing experience.
///
/// First principle: signing is not "place an image." It is a binding act —
/// the user is saying "I accept, this is now enforceable." The flow must:
/// 1. Show what the user is binding to (the document's identity)
/// 2. Verify the document hasn't been tampered with (integrity check)
/// 3. Record the commitment (audit entry with who/when/what)
///
/// Architecture:
/// - `CommitBindingInfo` — what the user is signing (document identity)
/// - `CommitIntegrityCheck` — pre-sign verification result
/// - `CommitAuditEntry` — immutable record of the signing event
/// - `CommitFlowState` — the state machine for the signing flow
///
/// Doctrine alignment:
/// - §3: Do things smartly — verify before binding
/// - §5: Evidence-based — audit entries are the evidence of commitment
/// - §8: Capability routing — COMMIT is a distinct job from READ/CREATE

// MARK: - Binding Info

/// What the user is binding to — the document's identity at signing time.
public struct CommitBindingInfo: Sendable {
  /// Document file name.
  public let fileName: String
  /// SHA-256 hash of the document at signing time.
  public let documentHash: String
  /// Total file size in bytes.
  public let fileSize: Int
  /// Number of pages.
  public let pageCount: Int
  /// Document title (from PDF metadata, if available).
  public let documentTitle: String
  /// Document author (from PDF metadata, if available).
  public let documentAuthor: String
  /// When the binding info was captured.
  public let capturedAt: Date

  public init(
    fileName: String,
    documentHash: String,
    fileSize: Int,
    pageCount: Int,
    documentTitle: String = "Unknown",
    documentAuthor: String = "Unknown"
  ) {
    self.fileName = fileName
    self.documentHash = documentHash
    self.fileSize = fileSize
    self.pageCount = pageCount
    self.documentTitle = documentTitle
    self.documentAuthor = documentAuthor
    self.capturedAt = Date()
  }

  /// Human-readable summary of what's being signed.
  public var bindingSummary: String {
    """
    Document: \(documentTitle.isEmpty ? fileName : documentTitle)
    Author: \(documentAuthor)
    Pages: \(pageCount)
    Size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
    Hash: \(String(documentHash.prefix(16)))...
    """
  }
}

// MARK: - Integrity Check

/// Pre-sign verification result.
public struct CommitIntegrityCheck: Sendable {
  public enum Status: Sendable {
    /// Document has no existing signatures — safe to sign.
    case unsigned
    /// Document has existing signatures, all valid.
    case signedValid(count: Int)
    /// Document has existing signatures, some invalid (tampered).
    case signedAltered(count: Int)
    /// Could not verify (missing data, parse error).
    case unverifiable(reason: String)
  }

  public let status: Status
  public let sourceHash: String
  public let checkedAt: Date

  /// Whether the document is safe to sign.
  public var isSafeToSign: Bool {
    switch status {
    case .unsigned, .signedValid:
      return true
    case .signedAltered, .unverifiable:
      return false
    }
  }

  /// Human-readable status message.
  public var statusMessage: String {
    switch status {
    case .unsigned:
      return "Document has no existing signatures. Safe to sign."
    case .signedValid(let count):
      return "Document has \(count) valid existing signature(s). Your signature will be added."
    case .signedAltered(let count):
      return "⚠️ Document has \(count) altered signature(s). The document may have been modified after signing."
    case .unverifiable(let reason):
      return "⚠️ Could not verify document integrity: \(reason)"
    }
  }

  public init(status: Status, sourceHash: String) {
    self.status = status
    self.sourceHash = sourceHash
    self.checkedAt = Date()
  }
}

// MARK: - Audit Entry

/// Immutable record of a signing event.
public struct CommitAuditEntry: Codable, Sendable, Identifiable {
  public let id: UUID
  /// The signer's displayed name.
  public let signerName: String
  /// Document file name at signing time.
  public let fileName: String
  /// SHA-256 hash of the document at signing time.
  public let documentHash: String
  /// Page index where the signature was placed.
  public let pageIndex: Int
  /// Signature method (drawn, typed, image, saved).
  public let method: String
  /// Timestamp of the signing event.
  public let signedAt: Date
  /// Pre-sign integrity check result.
  public let integrityStatus: String
  /// Optional reason for signing.
  public let reason: String

  public init(
    signerName: String,
    fileName: String,
    documentHash: String,
    pageIndex: Int,
    method: String,
    integrityStatus: String,
    reason: String = ""
  ) {
    self.id = UUID()
    self.signerName = signerName
    self.fileName = fileName
    self.documentHash = documentHash
    self.pageIndex = pageIndex
    self.method = method
    self.signedAt = Date()
    self.integrityStatus = integrityStatus
    self.reason = reason
  }

  /// Human-readable summary of the audit entry.
  public var summary: String {
    let dateStr = DateFormatter.auditStyle.string(from: signedAt)
    return "\(dateStr) — \(signerName) signed page \(pageIndex + 1) of \(fileName) using \(method). Integrity: \(integrityStatus)."
  }
}

// MARK: - Commit Flow State

/// State machine for the signing flow.
public enum CommitFlowState: Sendable {
  /// Showing binding info and integrity check.
  case verifying
  /// Ready to sign (integrity passed).
  case ready(binding: CommitBindingInfo, integrity: CommitIntegrityCheck)
  /// Integrity check failed — user must acknowledge.
  case integrityWarning(binding: CommitBindingInfo, integrity: CommitIntegrityCheck)
  /// Signing in progress.
  case signing
  /// Signing complete — audit entry recorded.
  case complete(auditEntry: CommitAuditEntry)
}

// MARK: - Commit Flow Manager

/// Manages the COMMIT flow: captures binding info, verifies integrity, records audit.
@MainActor
public final class CommitFlowManager: ObservableObject {
  @Published public var state: CommitFlowState = .verifying
  @Published public var signerName: String = ""
  @Published public var signingReason: String = ""

  private var bindingInfo: CommitBindingInfo?
  private var integrityCheck: CommitIntegrityCheck?
  private var auditLog: [CommitAuditEntry] = []

  public init() {
    loadAuditLog()
  }

  // MARK: - Flow Control

  /// Begin the COMMIT flow: capture binding info and verify integrity.
  public func begin(
    fileName: String,
    documentData: Data,
    pageCount: Int,
    documentTitle: String = "",
    documentAuthor: String = ""
  ) {
    state = .verifying

    // Capture binding info
    let hash = SHA256.hash(data: documentData)
    let hashHex = hash.map { String(format: "%02x", $0) }.joined()

    let binding = CommitBindingInfo(
      fileName: fileName,
      documentHash: hashHex,
      fileSize: documentData.count,
      pageCount: pageCount,
      documentTitle: documentTitle,
      documentAuthor: documentAuthor
    )
    self.bindingInfo = binding

    // Verify integrity
    let verifier = PDFDigitalSignatureVerifier()
    let verification = verifier.verifySignature(pdfData: documentData)

    let status: CommitIntegrityCheck.Status
    switch verification.status {
    case .unsigned:
      status = .unsigned
    case .validDigestUntrustedCert, .validAndTrusted:
      status = .signedValid(count: 1)
    case .invalidByteRange, .digestMismatch:
      status = .signedAltered(count: 1)
    }

    let integrity = CommitIntegrityCheck(status: status, sourceHash: hashHex)
    self.integrityCheck = integrity

    if integrity.isSafeToSign {
      state = .ready(binding: binding, integrity: integrity)
    } else {
      state = .integrityWarning(binding: binding, integrity: integrity)
    }
  }

  /// User acknowledges the integrity warning and chooses to proceed.
  public func acknowledgeWarning() {
    guard let binding = bindingInfo, let integrity = integrityCheck else { return }
    state = .ready(binding: binding, integrity: integrity)
  }

  /// Cancel the flow.
  public func cancel() {
    state = .verifying
    bindingInfo = nil
    integrityCheck = nil
  }

  /// Record a completed signing event.
  public func recordSign(
    pageIndex: Int,
    method: String
  ) {
    guard let binding = bindingInfo else { return }

    let entry = CommitAuditEntry(
      signerName: signerName.isEmpty ? "Unknown Signer" : signerName,
      fileName: binding.fileName,
      documentHash: binding.documentHash,
      pageIndex: pageIndex,
      method: method,
      integrityStatus: integrityCheck?.statusMessage ?? "unknown"
    )

    auditLog.append(entry)
    saveAuditLog()

    state = .complete(auditEntry: entry)
  }

  // MARK: - Audit Log

  public func getAuditLog() -> [CommitAuditEntry] {
    auditLog
  }

  public func clearAuditLog() {
    auditLog = []
    saveAuditLog()
  }

  // MARK: - Persistence

  private let auditLogKey = "commitAuditLog"

  private func saveAuditLog() {
    if let data = try? JSONEncoder().encode(auditLog) {
      UserDefaults.standard.set(data, forKey: auditLogKey)
    }
  }

  private func loadAuditLog() {
    guard let data = UserDefaults.standard.data(forKey: auditLogKey),
          let log = try? JSONDecoder().decode([CommitAuditEntry].self, from: data)
    else { return }
    auditLog = log
  }
}

// MARK: - DateFormatter

extension DateFormatter {
  static let auditStyle: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .medium
    return f
  }()
}
