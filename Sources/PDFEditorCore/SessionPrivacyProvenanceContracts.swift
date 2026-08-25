import Foundation

/// Describes where PDF processing occurred. The value is about execution,
/// not where the user interface was displayed.
public enum PDFProcessingLocality: String, Codable, CaseIterable, Hashable, Sendable {
  case localDevice = "local-device"
  case localBrowser = "local-browser"
  case localCompanion = "local-companion"
  case remoteService = "remote-service"
  case mixed
  case unknown
}

public enum PDFDataEgressState: String, Codable, CaseIterable, Hashable, Sendable {
  case none
  case runtimeOnly = "runtime-only"
  case sourceBytes
  case derivedContent = "derived-content"
  case mixed
  case unknown
}

public enum PDFOCRUseState: String, Codable, CaseIterable, Hashable, Sendable {
  case notUsed = "not-used"
  case localDevice = "local-device"
  case localBrowser = "local-browser"
  case localCompanion = "local-companion"
  case remoteService = "remote-service"
  case mixed
  case unknown
}

public enum PDFSourceRetentionState: String, Codable, CaseIterable, Hashable, Sendable {
  case inMemorySession = "in-memory-session"
  case localDraft = "local-draft"
  case persistentLocal = "persistent-local"
  case external
  case notRetained = "not-retained"
  case unknown
}

public enum PDFRetentionDeletionState: String, Codable, CaseIterable, Hashable, Sendable {
  case pending
  case deleted
  case unavailable
  case notApplicable = "not-applicable"
  case unknown
}

public enum PDFSessionExportState: String, Codable, CaseIterable, Hashable, Sendable {
  case notAttempted = "not-attempted"
  case succeeded
  case failed
  case unknown
}

public enum PDFExportStorage: String, Codable, CaseIterable, Hashable, Sendable {
  case ephemeral
  case localDownload = "local-download"
  case localFile = "local-file"
  case external
  case unknown
  case notApplicable = "not-applicable"
}

public enum PDFSessionValidationState: String, Codable, CaseIterable, Hashable, Sendable {
  case notRun = "not-run"
  case validated
  case validatedWithWarnings = "validated-with-warnings"
  case failed
  case unknown
}

public struct PDFSessionPrivacyFlags: Codable, Equatable, Hashable, Sendable {
  public let sourceBytesIncluded: Bool
  public let documentTextIncluded: Bool
  public let ocrTextIncluded: Bool
  public let fieldValuesIncluded: Bool
  public let filenamesIncluded: Bool
  public let URLsIncluded: Bool

  public init(
    sourceBytesIncluded: Bool = false,
    documentTextIncluded: Bool = false,
    ocrTextIncluded: Bool = false,
    fieldValuesIncluded: Bool = false,
    filenamesIncluded: Bool = false,
    URLsIncluded: Bool = false
  ) {
    self.sourceBytesIncluded = sourceBytesIncluded
    self.documentTextIncluded = documentTextIncluded
    self.ocrTextIncluded = ocrTextIncluded
    self.fieldValuesIncluded = fieldValuesIncluded
    self.filenamesIncluded = filenamesIncluded
    self.URLsIncluded = URLsIncluded
  }
}

public struct PDFSessionProcessingProvenance: Codable, Equatable, Hashable, Sendable {
  public let locality: PDFProcessingLocality
  public let sourceInput: String
  public let dataEgress: PDFDataEgressState
  public let networkRequestCount: Int
  public let companionRequestCount: Int

  public init(
    locality: PDFProcessingLocality,
    sourceInput: String,
    dataEgress: PDFDataEgressState,
    networkRequestCount: Int = 0,
    companionRequestCount: Int = 0
  ) {
    self.locality = locality
    self.sourceInput = sourceInput
    self.dataEgress = dataEgress
    self.networkRequestCount = max(0, networkRequestCount)
    self.companionRequestCount = max(0, companionRequestCount)
  }
}

public struct PDFSessionOCRProvenance: Codable, Equatable, Hashable, Sendable {
  public let state: PDFOCRUseState
  public let providerIDs: [String]
  public let processedPageCount: Int
  public let recognizedTextRetained: Bool
  public let recognizedBoundsRetained: Bool

  public init(
    state: PDFOCRUseState = .notUsed,
    providerIDs: [String] = [],
    processedPageCount: Int = 0,
    recognizedTextRetained: Bool = false,
    recognizedBoundsRetained: Bool = false
  ) {
    self.state = state
    self.providerIDs = providerIDs.sorted()
    self.processedPageCount = max(0, processedPageCount)
    self.recognizedTextRetained = recognizedTextRetained
    self.recognizedBoundsRetained = recognizedBoundsRetained
  }
}

public struct PDFSessionSourceRetentionProvenance: Codable, Equatable, Hashable, Sendable {
  public let state: PDFSourceRetentionState
  public let retainedUntilSessionEnd: Bool
  public let deletion: PDFRetentionDeletionState
  public let sourceCopyCount: Int

  public init(
    state: PDFSourceRetentionState,
    retainedUntilSessionEnd: Bool,
    deletion: PDFRetentionDeletionState,
    sourceCopyCount: Int = 1
  ) {
    self.state = state
    self.retainedUntilSessionEnd = retainedUntilSessionEnd
    self.deletion = deletion
    self.sourceCopyCount = max(0, sourceCopyCount)
  }
}

public struct PDFSessionExportProvenance: Codable, Equatable, Hashable, Sendable {
  public let state: PDFSessionExportState
  public let sourceDigest: String
  public let outputDigest: String?
  public let storage: PDFExportStorage
  public let validation: PDFSessionValidationState
  public let outputReopenable: Bool?
  public let operationCount: Int
  public let exporterID: String?
  public let validationProviderID: String?

  public init(
    state: PDFSessionExportState,
    sourceDigest: String,
    outputDigest: String? = nil,
    storage: PDFExportStorage,
    validation: PDFSessionValidationState,
    outputReopenable: Bool? = nil,
    operationCount: Int = 0,
    exporterID: String? = nil,
    validationProviderID: String? = nil
  ) {
    self.state = state
    self.sourceDigest = sourceDigest
    self.outputDigest = outputDigest
    self.storage = storage
    self.validation = validation
    self.outputReopenable = outputReopenable
    self.operationCount = max(0, operationCount)
    self.exporterID = exporterID
    self.validationProviderID = validationProviderID
  }
}

public struct PDFSessionPrivacyProvenancePayload: Codable, Equatable, Hashable, Sendable {
  public let privacy: PDFSessionPrivacyFlags
  public let processing: PDFSessionProcessingProvenance
  public let ocr: PDFSessionOCRProvenance
  public let sourceRetention: PDFSessionSourceRetentionProvenance
  public let export: PDFSessionExportProvenance

  public init(
    privacy: PDFSessionPrivacyFlags = PDFSessionPrivacyFlags(),
    processing: PDFSessionProcessingProvenance,
    ocr: PDFSessionOCRProvenance = PDFSessionOCRProvenance(),
    sourceRetention: PDFSessionSourceRetentionProvenance,
    export: PDFSessionExportProvenance
  ) {
    self.privacy = privacy
    self.processing = processing
    self.ocr = ocr
    self.sourceRetention = sourceRetention
    self.export = export
  }
}

public struct PDFSessionPrivacyProvenanceHeader: Codable, Equatable, Hashable, Sendable {
  public let contractName: String
  public let version: PDFContractVersion
  public let sessionID: String
  public let sourceDigest: String
  public let generatedAt: String
  public let provider: PDFProviderDescriptor

  public init(
    sessionID: String,
    sourceDigest: String,
    provider: PDFProviderDescriptor,
    generatedAt: String
  ) {
    self.contractName = "pdf-editor.session-provenance"
    self.version = PDFContractVersion(major: 1, minor: 0)
    self.sessionID = sessionID
    self.sourceDigest = sourceDigest
    self.generatedAt = generatedAt
    self.provider = provider
  }
}

public struct PDFSessionPrivacyProvenance: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.session-provenance"
  public let header: PDFSessionPrivacyProvenanceHeader
  public let payload: PDFSessionPrivacyProvenancePayload

  public init(header: PDFSessionPrivacyProvenanceHeader, payload: PDFSessionPrivacyProvenancePayload) {
    self.header = header
    self.payload = payload
  }
}

public enum PDFSessionPrivacyProvenanceError: Error, LocalizedError, Equatable, Sendable {
  case invalidContract
  case unsupportedVersion
  case invalidDigest
  case invalidSessionID
  case sourceMismatch
  case privacyLeakFlag
  case invalidOCRState
  case invalidRetentionState
  case invalidExportState

  public var errorDescription: String? {
    switch self {
    case .invalidContract: "Session provenance contract name is invalid."
    case .unsupportedVersion: "Session provenance contract version is unsupported."
    case .invalidDigest: "Session provenance contains an invalid SHA-256 digest."
    case .invalidSessionID: "Session provenance requires an opaque session ID."
    case .sourceMismatch: "Session provenance source digests do not agree."
    case .privacyLeakFlag: "Session provenance cannot claim that content values or source bytes were serialized."
    case .invalidOCRState: "OCR provenance state contradicts its provider or page counts."
    case .invalidRetentionState: "Source retention provenance is internally inconsistent."
    case .invalidExportState: "Export provenance is internally inconsistent."
    }
  }
}

public enum PDFSessionPrivacyProvenanceValidator {
  public static func validate(
    _ record: PDFSessionPrivacyProvenance,
    expectedSourceDigest: String? = nil
  ) throws {
    guard record.header.contractName == PDFSessionPrivacyProvenance.contractName else {
      throw PDFSessionPrivacyProvenanceError.invalidContract
    }
    guard record.header.version == PDFContractVersion(major: 1, minor: 0) else {
      throw PDFSessionPrivacyProvenanceError.unsupportedVersion
    }
    guard record.header.sessionID.isEmpty == false else {
      throw PDFSessionPrivacyProvenanceError.invalidSessionID
    }
    guard isDigest(record.header.sourceDigest), isDigest(record.payload.export.sourceDigest) else {
      throw PDFSessionPrivacyProvenanceError.invalidDigest
    }
    guard record.header.sourceDigest.caseInsensitiveCompare(record.payload.export.sourceDigest) == .orderedSame else {
      throw PDFSessionPrivacyProvenanceError.sourceMismatch
    }
    if let expectedSourceDigest {
      guard record.header.sourceDigest.caseInsensitiveCompare(expectedSourceDigest) == .orderedSame else {
        throw PDFSessionPrivacyProvenanceError.sourceMismatch
      }
    }
    let privacy = record.payload.privacy
    guard !privacy.sourceBytesIncluded, !privacy.documentTextIncluded,
      !privacy.ocrTextIncluded, !privacy.fieldValuesIncluded,
      !privacy.filenamesIncluded, !privacy.URLsIncluded
    else {
      throw PDFSessionPrivacyProvenanceError.privacyLeakFlag
    }
    let ocr = record.payload.ocr
    if ocr.state == .notUsed {
      guard ocr.providerIDs.isEmpty, ocr.processedPageCount == 0,
        !ocr.recognizedTextRetained, !ocr.recognizedBoundsRetained
      else { throw PDFSessionPrivacyProvenanceError.invalidOCRState }
    } else if ocr.state == .unknown {
      guard ocr.providerIDs.isEmpty, ocr.processedPageCount == 0,
        !ocr.recognizedTextRetained, !ocr.recognizedBoundsRetained
      else { throw PDFSessionPrivacyProvenanceError.invalidOCRState }
    } else {
      guard ocr.processedPageCount > 0,
        !ocr.providerIDs.isEmpty
      else { throw PDFSessionPrivacyProvenanceError.invalidOCRState }
    }
    let retention = record.payload.sourceRetention
    if retention.state == .unknown {
      guard !retention.retainedUntilSessionEnd, retention.sourceCopyCount == 0 else {
        throw PDFSessionPrivacyProvenanceError.invalidRetentionState
      }
    } else if retention.state == .notRetained {
      guard !retention.retainedUntilSessionEnd, retention.sourceCopyCount == 0 else {
        throw PDFSessionPrivacyProvenanceError.invalidRetentionState
      }
    } else {
      guard retention.sourceCopyCount > 0 else { throw PDFSessionPrivacyProvenanceError.invalidRetentionState }
    }
    let export = record.payload.export
    switch export.state {
    case .notAttempted:
      guard export.outputDigest == nil, export.validation == .notRun,
        export.storage == .notApplicable, export.outputReopenable == nil
      else { throw PDFSessionPrivacyProvenanceError.invalidExportState }
    case .succeeded:
      guard let outputDigest = export.outputDigest, isDigest(outputDigest),
        export.validation == .validated || export.validation == .validatedWithWarnings,
        export.storage != .notApplicable, export.outputReopenable == true
      else { throw PDFSessionPrivacyProvenanceError.invalidExportState }
    case .failed:
      guard export.validation == .failed || export.validation == .unknown else {
        throw PDFSessionPrivacyProvenanceError.invalidExportState
      }
    case .unknown:
      break
    }
  }

  private static func isDigest(_ value: String) -> Bool {
    value.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil
  }
}

public enum PDFSessionPrivacyProvenanceBuilder {
  public static func build(
    sessionID: String,
    sourceDigest: String,
    provider: PDFProviderDescriptor,
    generatedAt: String,
    processing: PDFSessionProcessingProvenance,
    ocr: PDFSessionOCRProvenance = PDFSessionOCRProvenance(),
    sourceRetention: PDFSessionSourceRetentionProvenance,
    export: PDFSessionExportProvenance
  ) -> PDFSessionPrivacyProvenance {
    PDFSessionPrivacyProvenance(
      header: PDFSessionPrivacyProvenanceHeader(
        sessionID: sessionID,
        sourceDigest: sourceDigest,
        provider: provider,
        generatedAt: generatedAt),
      payload: PDFSessionPrivacyProvenancePayload(
        processing: processing,
        ocr: ocr,
        sourceRetention: sourceRetention,
        export: export))
  }
}
