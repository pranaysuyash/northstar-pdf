import Foundation

/// TASK-A2 / OPERATING_DOCTRINE §2 (truth-status): an observed provenance fact
/// stating where the operation's data could travel while it executed. It is a
/// mandatory, default-less argument of `ExecutionReceipt`, so no receipt can
/// exist without the executing path stating this fact. `renderedDescription`
/// renders the fact conditionally — it never asserts a guarantee the executing
/// path did not supply.
public enum ExecutionDataBoundary: String, Codable, Sendable, Hashable {
  /// Inputs read and outputs written entirely on this device; no data left the
  /// process boundary during execution (as observed by the executing path).
  case onDeviceIsolated = "on-device-isolated"

  /// On-device execution with a documented exception: data left the device.
  /// The receipt's `notes` must state what left and where; a receipt using
  /// this boundary with empty notes is incomplete by construction.
  case onDeviceWithEgress = "on-device-with-egress"

  /// The prose rendering printed on the receipt's "Data Boundary" line.
  public var renderedDescription: String {
    switch self {
    case .onDeviceIsolated:
      return "On-device · data confined to the local process boundary (no network egress observed by the executing path)."
    case .onDeviceWithEgress:
      return "On-device execution · data left the device during execution (see receipt notes for the documented exception)."
    }
  }
}

/// TASK-A2 (docs/audits/chatgpt_architectural_review_task_matrix.md): An immutable
/// audit receipt produced after consequential, irreversible, or security-critical
/// document operations (e.g. Export, Sanitization, Redaction commitment, Batch fill).
///
/// Epistemic contract (OPERATING_DOCTRINE §2 truth-status): `executionRoute` and
/// `dataBoundary` are observed provenance facts supplied by the executing path —
/// they have no defaults, so a receipt cannot be created without stating where and
/// how the work ran. Claims are rendered conditionally from those facts; the
/// receipt never prints an unconditional provenance slogan.
public struct ExecutionReceipt: Identifiable, Codable, Equatable, Hashable, Sendable {
  public let id: UUID
  public let actionName: String
  public let timestamp: Date
  public let sourceDigest: String
  public let targetDigest: String
  public let executionRoute: String
  public let dataBoundary: ExecutionDataBoundary
  public let operationsExecuted: [ExecutionReceiptOperation]
  public let verificationChecks: [ExecutionReceiptCheck]
  public let outputDestination: String?
  public let isSuccess: Bool
  public let notes: String?
  /// Ed25519 signature over this receipt's canonical encoding, when the
  /// receipt was issued by a signing authority. Nil means explicitly unsigned
  /// — the receipt's provenance is then its producing path, and no consumer
  /// may render it as cryptographically verified. See `ReceiptSigning.swift`.
  public let signature: Data?

  public init(
    id: UUID = UUID(),
    actionName: String,
    timestamp: Date = Date(),
    sourceDigest: String,
    targetDigest: String,
    executionRoute: String,
    dataBoundary: ExecutionDataBoundary,
    operationsExecuted: [ExecutionReceiptOperation] = [],
    verificationChecks: [ExecutionReceiptCheck] = [],
    outputDestination: String? = nil,
    isSuccess: Bool = true,
    notes: String? = nil,
    signature: Data? = nil
  ) {
    self.id = id
    self.actionName = actionName
    self.timestamp = timestamp
    self.sourceDigest = sourceDigest
    self.targetDigest = targetDigest
    self.executionRoute = executionRoute
    self.dataBoundary = dataBoundary
    self.operationsExecuted = operationsExecuted
    self.verificationChecks = verificationChecks
    self.outputDestination = outputDestination
    self.isSuccess = isSuccess
    self.notes = notes
    self.signature = signature
  }

  /// Observed fact: whether this receipt carries a signature. Rendering of any
  /// "verified" claim must branch on this — an unsigned receipt must never be
  /// described as cryptographically verified.
  public var isSigned: Bool { signature != nil }

  /// Formats the execution receipt as a structured plain-text audit record.
  public func exportAsPlainText() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let dateStr = formatter.string(from: timestamp)

    var lines: [String] = [
      "============================================================",
      "             NORTHSTAR DOCUMENT EXECUTION RECEIPT           ",
      "============================================================",
      "Receipt ID      : \(id.uuidString)",
      "Action          : \(actionName)",
      "Timestamp       : \(dateStr)",
      "Execution Route : \(executionRoute)",
      "Data Boundary   : \(dataBoundary.renderedDescription)",
      "Status          : \(isSuccess ? "COMPLETED" : "FAILED / ESCALATED")",
      "Source SHA-256  : \(sourceDigest)",
      "Target SHA-256  : \(targetDigest)",
    ]

    if let dest = outputDestination {
      lines.append("Output Target   : \(dest)")
    }
    if let notes = notes, !notes.isEmpty {
      lines.append("Notes           : \(notes)")
    }

    lines.append("")
    lines.append("--- Operations Executed (\(operationsExecuted.count)) ---")
    if operationsExecuted.isEmpty {
      lines.append("  (No mutating operations)")
    } else {
      for (idx, op) in operationsExecuted.enumerated() {
        lines.append("  [\(idx + 1)] Page \(op.pageIndex + 1) · \(op.kind): \(op.detail)")
      }
    }

    lines.append("")
    lines.append("--- Verification & Invariant Checks (\(verificationChecks.count)) ---")
    for check in verificationChecks {
      let mark = check.passed ? "[PASS]" : "[FAIL]"
      lines.append("  \(mark) \(check.name): \(check.detail)")
    }

    lines.append("============================================================")
    return lines.joined(separator: "\n")
  }

  /// Encodes the receipt as pretty-printed JSON data.
  public func exportAsJSON() -> Data? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try? encoder.encode(self)
  }
}

public struct ExecutionReceiptOperation: Identifiable, Codable, Equatable, Hashable, Sendable {
  public let id: UUID
  public let kind: String
  public let pageIndex: Int
  public let detail: String

  public init(
    id: UUID = UUID(),
    kind: String,
    pageIndex: Int,
    detail: String
  ) {
    self.id = id
    self.kind = kind
    self.pageIndex = pageIndex
    self.detail = detail
  }
}

public struct ExecutionReceiptCheck: Identifiable, Codable, Equatable, Hashable, Sendable {
  public let id: UUID
  public let name: String
  public let passed: Bool
  public let detail: String

  public init(
    id: UUID = UUID(),
    name: String,
    passed: Bool,
    detail: String = "Verified"
  ) {
    self.id = id
    self.name = name
    self.passed = passed
    self.detail = detail
  }
}
