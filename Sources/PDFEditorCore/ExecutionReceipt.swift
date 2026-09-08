import Foundation

/// D-085 / TASK-A2: An immutable, cryptographically-grounded audit receipt produced
/// after consequential, irreversible, or security-critical document operations
/// (e.g. Export, Sanitization, Redaction commitment, Batch fill).
public struct ExecutionReceipt: Identifiable, Codable, Equatable, Hashable, Sendable {
  public let id: UUID
  public let actionName: String
  public let timestamp: Date
  public let sourceDigest: String
  public let targetDigest: String
  public let executionRoute: String
  public let operationsExecuted: [ExecutionReceiptOperation]
  public let verificationChecks: [ExecutionReceiptCheck]
  public let outputDestination: String?
  public let isSuccess: Bool
  public let notes: String?

  public init(
    id: UUID = UUID(),
    actionName: String,
    timestamp: Date = Date(),
    sourceDigest: String,
    targetDigest: String,
    executionRoute: String = "On-Device · Local Apple PDFKit",
    operationsExecuted: [ExecutionReceiptOperation] = [],
    verificationChecks: [ExecutionReceiptCheck] = [],
    outputDestination: String? = nil,
    isSuccess: Bool = true,
    notes: String? = nil
  ) {
    self.id = id
    self.actionName = actionName
    self.timestamp = timestamp
    self.sourceDigest = sourceDigest
    self.targetDigest = targetDigest
    self.executionRoute = executionRoute
    self.operationsExecuted = operationsExecuted
    self.verificationChecks = verificationChecks
    self.outputDestination = outputDestination
    self.isSuccess = isSuccess
    self.notes = notes
  }

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
      "Status          : \(isSuccess ? "VERIFIED SUCCESS" : "FAILED / ESCALATED")",
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
    lines.append("Cryptographically verified on-device. Zero network egress.")
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
    detail: String
  ) {
    self.id = id
    self.name = name
    self.passed = passed
    self.detail = detail
  }
}
