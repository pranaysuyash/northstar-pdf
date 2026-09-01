import Foundation

public enum DocumentCapabilityState: String, Codable, Equatable, Hashable, Sendable {
  case available
  case pending
  case needsReview
  case blocked
  case notApplicable
}

public struct DocumentCapabilityEntry: Codable, Equatable, Hashable, Sendable, Identifiable {
  public let id: String
  public let title: String
  public let detail: String
  public let state: DocumentCapabilityState

  public init(id: String, title: String, detail: String, state: DocumentCapabilityState) {
    self.id = id
    self.title = title
    self.detail = detail
    self.state = state
  }
}

/// A compact, user-facing projection of the current document's capabilities.
/// It describes what the current inspection supports; it does not activate a
/// provider, infer intent, or replace domain permission checks.
public struct DocumentCapabilityPassport: Codable, Equatable, Hashable, Sendable {
  public let sourceFileName: String
  public let sourceDigest: String?
  public let sourceWarningCount: Int
  public let entries: [DocumentCapabilityEntry]

  public init(
    sourceFileName: String,
    sourceDigest: String?,
    sourceWarningCount: Int,
    entries: [DocumentCapabilityEntry]
  ) {
    self.sourceFileName = sourceFileName
    self.sourceDigest = sourceDigest
    self.sourceWarningCount = max(0, sourceWarningCount)
    self.entries = entries
  }

  public static func make(
    inspection: DocumentInspection?,
    canExport: Bool,
    hasPreflightReport: Bool
  ) -> DocumentCapabilityPassport {
    guard let inspection else {
      return DocumentCapabilityPassport(
        sourceFileName: "No document",
        sourceDigest: nil,
        sourceWarningCount: 0,
        entries: [
          DocumentCapabilityEntry(
            id: "document",
            title: "Document",
            detail: "Open a PDF to inspect its capabilities.",
            state: .blocked
          )
        ]
      )
    }

    let permissions = inspection.permissions
    let hasFields = !inspection.fields.isEmpty
    let entries = [
      DocumentCapabilityEntry(
        id: "read-and-extract",
        title: "Read and extract text",
        detail: permissions.canCopy
          ? "Selectable text can be searched or copied in this session."
          : "Copy and extraction are restricted by the source permissions.",
        state: permissions.canCopy ? .available : .blocked
      ),
      DocumentCapabilityEntry(
        id: "fill-fields",
        title: "Complete native fields",
        detail: !hasFields
          ? "No native form fields were found in the source inspection."
          : permissions.canModify
            ? "Native fields can be edited; export remains a separate copy."
            : "Native fields were found, but modification is restricted.",
        state: !hasFields ? .notApplicable : permissions.canModify ? .available : .blocked
      ),
      DocumentCapabilityEntry(
        id: "annotate",
        title: "Annotate and add overlays",
        detail: permissions.canAddAnnotations
          ? "Annotation and overlay operations are admitted by the source permissions."
          : "Adding annotations or overlays is restricted by the source permissions.",
        state: permissions.canAddAnnotations ? .available : .blocked
      ),
      DocumentCapabilityEntry(
        id: "organize-pages",
        title: "Organize pages",
        detail: permissions.canModify
          ? "Page organization operations are admitted by the source permissions."
          : "Page organization requires document modification permission.",
        state: permissions.canModify ? .available : .blocked
      ),
      DocumentCapabilityEntry(
        id: "export-copy",
        title: "Export a separate copy",
        detail: canExport
          ? "The current operation ledger passes the export permission gate."
          : "The current operation ledger or permission contract blocks export.",
        state: canExport ? .available : .blocked
      ),
      DocumentCapabilityEntry(
        id: "preflight",
        title: "Privacy preflight",
        detail: hasPreflightReport
          ? "The local source preflight report is available for inspection."
          : "The local source preflight report has not completed in this session.",
        state: hasPreflightReport ? .available : .pending
      ),
      DocumentCapabilityEntry(
        id: "source-warnings",
        title: "Source inspection warnings",
        detail: inspection.warnings.isEmpty
          ? "No source inspection warnings are recorded."
          : "(inspection.warnings.count) source inspection warning\(inspection.warnings.count == 1 ? "" : "s") need review.",
        state: inspection.warnings.isEmpty ? .available : .needsReview
      )
    ]

    return DocumentCapabilityPassport(
      sourceFileName: inspection.source.fileName,
      sourceDigest: inspection.source.sha256,
      sourceWarningCount: inspection.warnings.count,
      entries: entries
    )
  }
}
