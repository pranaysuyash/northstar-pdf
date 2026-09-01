import Foundation

/// Shared semantic rejection codes emitted by native, browser, and companion
/// provider adapters. Provider-native reason strings never become semantic
/// truth; adapters map them into this closed vocabulary or abstain as unknown.
public enum PDFRejectionCode: String, Codable, CaseIterable, Hashable, Sendable {
  case staleSourceDigest
  case sourceByteCountMismatch
  case inputMissing
  case inputTooLarge
  case cannotOpen
  case passwordRequired
  case passwordIncorrect
  case invalidPage
  case invalidOperation
  case unsupportedOperation
  case destructiveOperation
  case unknownValidationState
  case coordinateMismatch
  case providerUnavailable
  case runtimeUnavailable
  case providerFailure
  case providerRevoked
  case licenseUnapproved
  case sourceOutsideProviderLimits
  case outputLimit
  case timeout
  case cancelled
  case exportFailed
  case validationFailed
  case unknownRejection
}

public enum PDFRejectionProviderKind: String, Codable, CaseIterable, Hashable, Sendable {
  case native
  case browser
  case companion
}

public enum PDFRejectionAttemptState: String, Codable, CaseIterable, Hashable, Sendable {
  case rejected
  case abstained
  case failed
  case cancelled
  case completed
}

public struct PDFOperationLineageRecord: Codable, Equatable, Hashable, Sendable {
  public let operationID: String
  public let kind: String
  public let pageIndex: Int
  public let sourceDigest: String

  public init(operationID: String, kind: String, pageIndex: Int, sourceDigest: String) {
    self.operationID = operationID
    self.kind = kind
    self.pageIndex = pageIndex
    self.sourceDigest = sourceDigest.lowercased()
  }
}

public struct PDFProviderRejectionAttempt: Codable, Equatable, Hashable, Sendable {
  public let attemptID: String
  public let caseID: String
  public let providerID: String
  public let providerKind: PDFRejectionProviderKind
  public let capability: String
  public let phase: String
  public let state: PDFRejectionAttemptState
  public let sourceDigest: String
  public let operationLineage: [PDFOperationLineageRecord]
  public let code: String?
  public let reasonCodes: [String]?
  public let outputDigest: String?
  public let observedAt: String?

  public init(
    attemptID: String,
    caseID: String,
    providerID: String,
    providerKind: PDFRejectionProviderKind,
    capability: String,
    phase: String,
    state: PDFRejectionAttemptState,
    sourceDigest: String,
    operationLineage: [PDFOperationLineageRecord],
    code: String? = nil,
    reasonCodes: [String]? = nil,
    outputDigest: String? = nil,
    observedAt: String? = nil
  ) {
    self.attemptID = attemptID
    self.caseID = caseID
    self.providerID = providerID
    self.providerKind = providerKind
    self.capability = capability
    self.phase = phase
    self.state = state
    self.sourceDigest = sourceDigest.lowercased()
    self.operationLineage = operationLineage
    self.code = code
    self.reasonCodes = reasonCodes
    self.outputDigest = outputDigest
    self.observedAt = observedAt
  }
}

public struct PDFNormalizedRejection: Codable, Equatable, Hashable, Sendable {
  public let code: PDFRejectionCode
  public let category: String
  public let retryable: Bool
  public let recovery: String
  public let providerReasonCodeCount: Int
  public let unknownProviderReasonCodeCount: Int
}

public struct PDFNormalizedRejectionAttempt: Codable, Equatable, Hashable, Sendable {
  public let attemptID: String
  public let caseID: String
  public let providerID: String
  public let providerKind: PDFRejectionProviderKind
  public let capability: String
  public let phase: String
  public let state: PDFRejectionAttemptState
  public let outcome: String
  public let sourceDigest: String
  public let operationLineage: [PDFOperationLineageRecord]
  public let operationLineageSignature: String
  public let rejection: PDFNormalizedRejection?
}

public struct PDFProviderRejectionLedger: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.rejection-ledger"
  public let contract: String
  public let version: PDFContractVersion
  public let ledgerID: String
  public let sourceDigest: String
  public let attempts: [PDFNormalizedRejectionAttempt]

  public init(ledgerID: String, sourceDigest: String, attempts: [PDFProviderRejectionAttempt]) throws {
    guard !ledgerID.isEmpty, Self.isDigest(sourceDigest), !attempts.isEmpty else {
      throw PDFRejectionLedgerError.invalid("rejection ledger identity is invalid")
    }
    let normalized = try attempts.map(PDFRejectionLedgerOracle.normalize)
    guard normalized.allSatisfy({ $0.sourceDigest == sourceDigest.lowercased() }) else {
      throw PDFRejectionLedgerError.invalid("attempt source digest does not match ledger source digest")
    }
    guard Set(normalized.map(\.providerID)).count == 1,
      Set(normalized.map(\.providerKind)).count == 1 else {
      throw PDFRejectionLedgerError.invalid("all attempts in a ledger must belong to one provider")
    }
    self.contract = Self.contractName
    self.version = .current
    self.ledgerID = ledgerID
    self.sourceDigest = sourceDigest.lowercased()
    self.attempts = normalized
  }

  public static func isDigest(_ value: String) -> Bool {
    value.count == 64 && value.allSatisfy(\.isHexDigit)
  }
}

public struct PDFRejectionComparison: Codable, Equatable, Hashable, Sendable {
  public let caseID: String
  public let leftProviderID: String
  public let rightProviderID: String
  public let sameLineage: Bool
  public let sameOutcome: Bool
  public let sameCode: Bool
  public let sameRecovery: Bool
  public let comparable: Bool
  public let equivalent: Bool
}

public struct PDFProviderRejectionSummary: Codable, Equatable, Sendable {
  public let providerKind: PDFRejectionProviderKind
  public let attemptCount: Int
  public let rejectedCount: Int
  public let codes: [PDFRejectionCode]

  public init(providerKind: PDFRejectionProviderKind, attemptCount: Int, rejectedCount: Int, codes: [PDFRejectionCode]) {
    self.providerKind = providerKind
    self.attemptCount = attemptCount
    self.rejectedCount = rejectedCount
    self.codes = codes
  }
}

public struct PDFProviderRejectionComparisonReport: Codable, Equatable, Sendable {
  public let contract: String
  public let version: PDFContractVersion
  public let sourceDigests: [String]
  public let providerSummaries: [String: PDFProviderRejectionSummary]
  public let comparisons: [PDFRejectionComparison]
  public let providerCount: Int
  public let caseCount: Int
  public let comparisonCount: Int
  public let comparableCount: Int
  public let equivalentCount: Int
  public let disagreementCount: Int
  public let unknownCount: Int
}

public enum PDFRejectionLedgerError: Error, LocalizedError, Equatable, Sendable {
  case invalid(String)

  public var errorDescription: String? {
    switch self {
    case .invalid(let message): message
    }
  }
}

public enum PDFRejectionLedgerOracle {
  private struct Semantics {
    let category: String
    let retryable: Bool
    let recovery: String
  }

  private static let semantics: [PDFRejectionCode: Semantics] = [
    .staleSourceDigest: Semantics(category: "source", retryable: false, recovery: "reopenCurrentSource"),
    .sourceByteCountMismatch: Semantics(category: "source", retryable: false, recovery: "reinspectSource"),
    .inputMissing: Semantics(category: "input", retryable: true, recovery: "chooseAnotherSource"),
    .inputTooLarge: Semantics(category: "resource", retryable: false, recovery: "reduceScopeOrUseApprovedProvider"),
    .cannotOpen: Semantics(category: "input", retryable: false, recovery: "retainSourceAndInspect"),
    .passwordRequired: Semantics(category: "input", retryable: true, recovery: "requestPassword"),
    .passwordIncorrect: Semantics(category: "input", retryable: true, recovery: "retryPassword"),
    .invalidPage: Semantics(category: "contract", retryable: false, recovery: "reviseOperation"),
    .invalidOperation: Semantics(category: "contract", retryable: false, recovery: "reviseOperation"),
    .unsupportedOperation: Semantics(category: "capability", retryable: false, recovery: "chooseSupportedOperation"),
    .destructiveOperation: Semantics(category: "safety", retryable: false, recovery: "reviewDestructiveIntent"),
    .unknownValidationState: Semantics(category: "validation", retryable: false, recovery: "inspectValidationEvidence"),
    .coordinateMismatch: Semantics(category: "coordinate", retryable: false, recovery: "reinspectPageGeometry"),
    .providerUnavailable: Semantics(category: "provider", retryable: true, recovery: "retryOrSelectProvider"),
    .runtimeUnavailable: Semantics(category: "provider", retryable: true, recovery: "restoreRuntime"),
    .providerFailure: Semantics(category: "provider", retryable: true, recovery: "retryAsNewCopy"),
    .providerRevoked: Semantics(category: "provider", retryable: false, recovery: "selectAnotherProvider"),
    .licenseUnapproved: Semantics(category: "provider", retryable: false, recovery: "reviewProviderLicense"),
    .sourceOutsideProviderLimits: Semantics(category: "resource", retryable: false, recovery: "selectAnotherProvider"),
    .outputLimit: Semantics(category: "resource", retryable: false, recovery: "reduceScopeOrIncreaseApprovedLimit"),
    .timeout: Semantics(category: "runtime", retryable: true, recovery: "retryWithResourceBudget"),
    .cancelled: Semantics(category: "runtime", retryable: true, recovery: "resumeOrRetry"),
    .exportFailed: Semantics(category: "export", retryable: true, recovery: "retryAsNewCopy"),
    .validationFailed: Semantics(category: "validation", retryable: false, recovery: "inspectValidationEvidence"),
    .unknownRejection: Semantics(category: "unknown", retryable: false, recovery: "retainEvidenceAndReview")
  ]

  private static let aliases: [String: PDFRejectionCode] = [
    "sourceDigestMismatch": .staleSourceDigest,
    "staleSource": .staleSourceDigest,
    "capabilityNotSupported": .unsupportedOperation,
    "unsupported": .unsupportedOperation,
    "unsupportedFeature": .unsupportedOperation,
    "noHandler": .providerUnavailable,
    "providerNotInstalled": .providerUnavailable,
    "capabilityRevoked": .providerRevoked,
    "capabilityStateRevoked": .providerRevoked,
    "unapprovedLicense": .licenseUnapproved,
    "providerTimeout": .timeout,
    "exportFailedValidation": .validationFailed,
    "unknownValidation": .unknownValidationState
  ]

  public static func lineageSignature(_ lineage: [PDFOperationLineageRecord]) -> String {
    lineage
      .sorted { "\($0.pageIndex):\($0.kind):\($0.operationID)" < "\($1.pageIndex):\($1.kind):\($1.operationID)" }
      .map { "\($0.pageIndex)|\($0.kind)|\($0.operationID)|\($0.sourceDigest)" }
      .joined(separator: ";")
  }

  public static func normalize(_ attempt: PDFProviderRejectionAttempt) throws -> PDFNormalizedRejectionAttempt {
    guard !attempt.attemptID.isEmpty, !attempt.caseID.isEmpty, !attempt.providerID.isEmpty,
      !attempt.capability.isEmpty, !attempt.phase.isEmpty,
      PDFProviderRejectionLedger.isDigest(attempt.sourceDigest), !attempt.operationLineage.isEmpty
    else { throw PDFRejectionLedgerError.invalid("rejection attempt identity is invalid") }
    guard attempt.operationLineage.allSatisfy({
      !$0.operationID.isEmpty && !$0.kind.isEmpty && $0.pageIndex >= 0
        && PDFProviderRejectionLedger.isDigest($0.sourceDigest)
        && $0.sourceDigest.lowercased() == attempt.sourceDigest.lowercased()
    }) else { throw PDFRejectionLedgerError.invalid("operation lineage is invalid") }

    let rawCodes = attempt.reasonCodes ?? []
    let knownCodeCount = rawCodes.reduce(into: 0) { count, rawCode in
      if canonicalCode(rawCode: rawCode, reasonCodes: [], state: .completed) != nil { count += 1 }
    }
    let canonical = canonicalCode(rawCode: attempt.code, reasonCodes: rawCodes, state: attempt.state)
    let rejected = [.rejected, .abstained, .failed, .cancelled].contains(attempt.state)
    guard !rejected || canonical != nil else { throw PDFRejectionLedgerError.invalid("rejected attempt has no canonical rejection code") }
    let rejection = canonical.map { code -> PDFNormalizedRejection in
      let meaning = semantics[code]!
      return PDFNormalizedRejection(
        code: code,
        category: meaning.category,
        retryable: meaning.retryable,
        recovery: meaning.recovery,
        providerReasonCodeCount: knownCodeCount,
        unknownProviderReasonCodeCount: max(0, rawCodes.count - knownCodeCount))
    }
    let sortedLineage = attempt.operationLineage.sorted { "\($0.pageIndex):\($0.kind):\($0.operationID)" < "\($1.pageIndex):\($1.kind):\($1.operationID)" }
    return PDFNormalizedRejectionAttempt(
      attemptID: attempt.attemptID,
      caseID: attempt.caseID,
      providerID: attempt.providerID,
      providerKind: attempt.providerKind,
      capability: attempt.capability,
      phase: attempt.phase,
      state: attempt.state,
      outcome: rejected ? "rejected" : "completed",
      sourceDigest: attempt.sourceDigest.lowercased(),
      operationLineage: sortedLineage,
      operationLineageSignature: lineageSignature(sortedLineage),
      rejection: rejection)
  }

  public static func compare(_ ledgers: [PDFProviderRejectionLedger]) throws -> PDFProviderRejectionComparisonReport {
    guard ledgers.count >= 2 else { throw PDFRejectionLedgerError.invalid("at least two rejection ledgers are required") }
    let keys = Set(ledgers.map(\.sourceDigest)).sorted()
    var groups: [String: [PDFNormalizedRejectionAttempt]] = [:]
    for ledger in ledgers {
      for attempt in ledger.attempts {
        groups["\(attempt.caseID)|\(attempt.capability)", default: []].append(attempt)
      }
    }
    var comparisons: [PDFRejectionComparison] = []
    for attempts in groups.values {
      for leftIndex in attempts.indices {
        for rightIndex in attempts.indices where rightIndex > leftIndex {
          let left = attempts[leftIndex]
          let right = attempts[rightIndex]
          guard left.providerID != right.providerID else { continue }
          let sameLineage = left.sourceDigest == right.sourceDigest && left.operationLineageSignature == right.operationLineageSignature
          let sameOutcome = left.outcome == right.outcome
          let sameCode = left.rejection?.code == right.rejection?.code
          let sameRecovery = left.rejection?.recovery == right.rejection?.recovery
          let comparable = sameLineage && left.rejection?.code != .unknownRejection && right.rejection?.code != .unknownRejection
          comparisons.append(PDFRejectionComparison(
            caseID: left.caseID,
            leftProviderID: left.providerID,
            rightProviderID: right.providerID,
            sameLineage: sameLineage,
            sameOutcome: sameOutcome,
            sameCode: sameCode,
            sameRecovery: sameRecovery,
            comparable: comparable,
            equivalent: comparable && sameOutcome && sameCode && sameRecovery))
        }
      }
    }
    let comparable = comparisons.filter(\.comparable)
    let providerSummaries = Dictionary(uniqueKeysWithValues: ledgers.map { ledger in
      let providerID = ledger.attempts[0].providerID
      let attempts = ledger.attempts
      return (providerID, PDFProviderRejectionSummary(
        providerKind: attempts[0].providerKind,
        attemptCount: attempts.count,
        rejectedCount: attempts.filter { $0.outcome == "rejected" }.count,
        codes: Array(Set(attempts.compactMap { $0.rejection?.code })).sorted { $0.rawValue < $1.rawValue }))
    })
    return PDFProviderRejectionComparisonReport(
      contract: "pdf-editor.rejection-comparison-report",
      version: .current,
      sourceDigests: keys,
      providerSummaries: providerSummaries,
      comparisons: comparisons,
      providerCount: ledgers.count,
      caseCount: groups.count,
      comparisonCount: comparisons.count,
      comparableCount: comparable.count,
      equivalentCount: comparable.filter(\.equivalent).count,
      disagreementCount: comparable.filter { !$0.equivalent }.count,
      unknownCount: comparisons.filter { !$0.comparable }.count)
  }

  private static func canonicalCode(rawCode: String?, reasonCodes: [String], state: PDFRejectionAttemptState) -> PDFRejectionCode? {
    for candidate in [rawCode].compactMap({ $0 }) + reasonCodes {
      if let code = PDFRejectionCode(rawValue: candidate) { return code }
      if let alias = aliases[candidate] { return alias }
    }
    switch state {
    case .cancelled: return .cancelled
    case .failed: return .providerFailure
    case .abstained, .rejected: return .unknownRejection
    case .completed: return nil
    }
  }
}
