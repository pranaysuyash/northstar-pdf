import Foundation

/// The kind of derived PDF copy being prepared. Profiles are explicit because
/// a clean edited copy, a sanitized copy, and a page extraction have different
/// source-preservation and validation obligations.
public enum ExportReviewProfile: String, Codable, Equatable, Hashable, Sendable {
  case editedCopy
  case sanitizedCopy
  case pageExtraction
  case flattenedCopy
  case redactedCopy

  public var title: String {
    switch self {
    case .editedCopy: return "Export Copy"
    case .sanitizedCopy: return "Sanitized Copy"
    case .pageExtraction: return "Extracted Pages"
    case .flattenedCopy: return "Flattened Copy"
    case .redactedCopy: return "Permanently Redacted Copy"
    }
  }

  public var detail: String {
    switch self {
    case .editedCopy:
      return "A separate PDF containing the admitted document operations."
    case .sanitizedCopy:
      return "A separate PDF with document-level metadata removed."
    case .pageExtraction:
      return "A separate PDF containing the selected page range."
    case .flattenedCopy:
      return "A separate PDF with fields and annotations baked into page content."
    case .redactedCopy:
      return "A separate PDF with text glyphs destroyed, raster areas burned, and metadata purged."
    }
  }
}

/// The state of the pre-export review moment. This is deliberately distinct
/// from `ValidationStatus`: validation exists only after a staged output has
/// been reopened and checked.
public enum ExportReviewReceiptState: String, Codable, Equatable, Hashable, Sendable {
  case ready
  case needsReview
  case blocked
  case validated
}

public enum ExportReviewCheckState: String, Codable, Equatable, Hashable, Sendable {
  case confirmed
  case pending
  case needsReview
  case blocked
}

public struct ExportReviewCheck: Codable, Equatable, Hashable, Sendable, Identifiable {
  public let id: String
  public let title: String
  public let detail: String
  public let state: ExportReviewCheckState

  public init(id: String, title: String, detail: String, state: ExportReviewCheckState) {
    self.id = id
    self.title = title
    self.detail = detail
    self.state = state
  }
}

/// A value-minimized operation summary suitable for a human review surface.
/// It includes no operation values, selected text, coordinates, or timestamps.
public struct ExportReviewOperationSummary: Codable, Equatable, Hashable, Sendable, Identifiable {
  public let id: String
  public let kind: EditKind
  public let title: String
  public let count: Int
  public let containsDestructiveOperation: Bool

  public init(
    kind: EditKind,
    title: String,
    count: Int,
    containsDestructiveOperation: Bool
  ) {
    self.id = "operation-kind:\(kind.rawValue)"
    self.kind = kind
    self.title = title
    self.count = max(0, count)
    self.containsDestructiveOperation = containsDestructiveOperation
  }
}

/// The canonical pre-export review projection.
///
/// The receipt is a read-only description of an export attempt. It does not
/// write files, validate output, or grant a capability. `AppModel.export()`
/// remains the sole export authority after the user explicitly continues.
public struct ExportReviewReceipt: Codable, Equatable, Hashable, Sendable {
  public let profile: ExportReviewProfile
  public let sourceFileName: String
  public let sourceDigest: String?
  public let operationCount: Int
  public let operationIDs: [UUID]
  public let operationSummaries: [ExportReviewOperationSummary]
  public let checks: [ExportReviewCheck]
  public let sourceWarningCount: Int
  public let state: ExportReviewReceiptState
  public let canProceed: Bool
  public let requiresExplicitReview: Bool

  public init(
    profile: ExportReviewProfile = .editedCopy,
    sourceFileName: String,
    sourceDigest: String?,
    operationCount: Int,
    operationIDs: [UUID],
    operationSummaries: [ExportReviewOperationSummary],
    checks: [ExportReviewCheck],
    sourceWarningCount: Int,
    state: ExportReviewReceiptState,
    canProceed: Bool,
    requiresExplicitReview: Bool
  ) {
    self.profile = profile
    self.sourceFileName = sourceFileName
    self.sourceDigest = sourceDigest
    self.operationCount = max(0, operationCount)
    self.operationIDs = operationIDs
    self.operationSummaries = operationSummaries
    self.checks = checks
    self.sourceWarningCount = max(0, sourceWarningCount)
    self.state = state
    self.canProceed = canProceed
    self.requiresExplicitReview = requiresExplicitReview
  }

  public static func make(
    source: DocumentInspection?,
    operations: [EditOperation],
    canExport: Bool,
    profile: ExportReviewProfile = .editedCopy,
    outputValidation: ValidationReport? = nil
  ) -> ExportReviewReceipt {
    let sourceFileName = source?.source.fileName ?? "No document"
    let sourceDigest = source?.source.sha256
    let warningCount = source?.warnings.count ?? 0
    let grouped = Dictionary(grouping: operations, by: \.kind)
    let summaries = grouped.keys.sorted { $0.rawValue < $1.rawValue }.map { kind in
      let groupedOperations = grouped[kind] ?? []
      return ExportReviewOperationSummary(
        kind: kind,
        title: title(for: kind),
        count: groupedOperations.count,
        containsDestructiveOperation: groupedOperations.contains(where: \.destructive)
      )
    }

    let sourceState: ExportReviewCheckState
    let sourceDetail: String
    if let outputValidation {
      sourceState = outputValidation.sourceUnchanged ? .confirmed : .blocked
      sourceDetail = outputValidation.sourceUnchanged
        ? "The validated output reports the source as unchanged."
        : "The output did not prove that the source remained unchanged."
    } else if source != nil {
      sourceState = .pending
      sourceDetail = "The export-only path will write a separate copy; verification is pending."
    } else {
      sourceState = .blocked
      sourceDetail = "Open a PDF before preparing an export."
    }

    let permissionState: ExportReviewCheckState = source == nil
      ? .blocked
      : canExport ? .confirmed : .blocked
    let permissionDetail = canExport
      ? "Current document permissions and admitted operations allow this export path."
      : "The current permission or operation contract does not allow this export."

    let operationIDs = operations.map(\.id)
    let ledgerState: ExportReviewCheckState = Set(operationIDs).count == operationIDs.count
      ? .confirmed
      : .blocked
    let ledgerDetail = operations.isEmpty
      ? "No pending document operations are included."
      : "\(operations.count) typed operation\(operations.count == 1 ? "" : "s") will be included."

    let validationState: ExportReviewCheckState
    let validationDetail: String
    if let outputValidation {
      switch outputValidation.status {
      case .validated:
        validationState = outputValidation.outputReopenable ? .confirmed : .blocked
        validationDetail = outputValidation.outputReopenable
          ? "The output reopened successfully after export."
          : "The output did not reopen successfully."
      case .validatedWithWarnings:
        validationState = .needsReview
        validationDetail = "The output reopened, but validation reported warnings."
      case .failed:
        validationState = .blocked
        validationDetail = "Output validation failed."
      }
    } else {
      validationState = .pending
      validationDetail = "Independent output reopen and fidelity checks run after saving."
    }

    let warningState: ExportReviewCheckState = warningCount == 0 ? .confirmed : .needsReview
    let warningDetail = warningCount == 0
      ? "No source inspection warnings are recorded."
      : "\(warningCount) source inspection warning\(warningCount == 1 ? "" : "s") need review."

    let checks = [
      ExportReviewCheck(id: "source-preservation", title: "Source preservation", detail: sourceDetail, state: sourceState),
      ExportReviewCheck(id: "permissions", title: "Permissions", detail: permissionDetail, state: permissionState),
      ExportReviewCheck(id: "operation-ledger", title: "Operation ledger", detail: ledgerDetail, state: ledgerState),
      ExportReviewCheck(id: "validation", title: "Output validation", detail: validationDetail, state: validationState),
      ExportReviewCheck(id: "source-warnings", title: "Source warnings", detail: warningDetail, state: warningState)
    ]

    let hasDestructiveOperation = operations.contains(where: \.destructive)
      || operations.contains { operation in
        switch operation.kind {
        case .applyRedaction, .flatten, .sanitize:
          return true
        default:
          return false
        }
      }
    let hasReviewState = checks.contains { $0.state == .needsReview }
    let hasBlockedState = checks.contains { $0.state == .blocked }
    let state: ExportReviewReceiptState
    if hasBlockedState {
      state = .blocked
    } else if outputValidation?.status == .validated {
      state = .validated
    } else if hasReviewState || hasDestructiveOperation {
      state = .needsReview
    } else {
      state = .ready
    }

    return ExportReviewReceipt(
      profile: profile,
      sourceFileName: sourceFileName,
      sourceDigest: sourceDigest,
      operationCount: operations.count,
      operationIDs: operationIDs,
      operationSummaries: summaries,
      checks: checks,
      sourceWarningCount: warningCount,
      state: state,
      canProceed: state != .blocked && canExport,
      requiresExplicitReview: hasReviewState || hasDestructiveOperation
    )
  }

  private static func title(for kind: EditKind) -> String {
    switch kind {
    case .nativeFieldValue: return "Native field values"
    case .synthesizeNativeField: return "New native fields"
    case .overlayText: return "Text overlays"
    case .textRunReplacement: return "Text replacements"
    case .overlayImage: return "Image overlays"
    case .stamp: return "Stamps"
    case .annotation: return "Annotations"
    case .pageTransform: return "Page transforms"
    case .pageInsert: return "Inserted pages"
    case .pageDelete: return "Deleted pages"
    case .pageMove: return "Moved pages"
    case .flatten: return "Flattening"
    case .redactMark: return "Redaction marks"
    case .applyRedaction: return "Permanent redactions"
    case .metadata: return "Metadata changes"
    case .sanitize: return "Sanitization"
    }
  }
}
