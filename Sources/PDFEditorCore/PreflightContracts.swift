import Foundation

/// Privacy-preserving evidence emitted before any PDF mutation is attempted.
///
/// This contract deliberately contains presence bits, counts, classifications,
/// and source binding only. It must not become a transport for metadata values,
/// attachment names, URLs, page text, OCR text, or source bytes.
public enum PDFPreflightSeverity: String, Codable, CaseIterable, Hashable, Sendable {
  case info
  case warning
  case blocked
  case unknown
}

public enum PDFPreflightFindingState: String, Codable, CaseIterable, Hashable, Sendable {
  case observed
  case possible
  case notObserved = "not-observed"
  case unknown
}

public enum PDFPreflightFindingCategory: String, Codable, CaseIterable, Hashable, Sendable {
  case metadata
  case embeddedData
  case networkBoundary
  case activeContent
  case security
  case preflight
}

public enum PDFPreflightCoverageState: String, Codable, CaseIterable, Hashable, Sendable {
  case observed
  case partial
  case notObserved = "not-observed"
  case unknown
}

public struct PDFPreflightCoverage: Codable, Equatable, Hashable, Sendable {
  public let state: PDFPreflightCoverageState
  public let reasonCodes: [String]

  public init(state: PDFPreflightCoverageState, reasonCodes: [String] = []) {
    self.state = state
    self.reasonCodes = reasonCodes.sorted()
  }
}

public enum PDFSanitizationStatus: String, Codable, CaseIterable, Hashable, Sendable {
  case notRun = "not-run"
  case completed
  case failed
  case unknown
}

public struct PDFPreflightMetadataField: Codable, Equatable, Hashable, Sendable {
  public let present: Bool

  public init(present: Bool) {
    self.present = present
  }
}

public struct PDFPreflightFinding: Codable, Equatable, Hashable, Sendable, Identifiable {
  public let id: String
  public let category: PDFPreflightFindingCategory
  public let code: String
  public let severity: PDFPreflightSeverity
  public let state: PDFPreflightFindingState
  public let count: Int
  public let reasonCodes: [String]
  public let evidence: String

  public init(
    id: String,
    category: PDFPreflightFindingCategory,
    code: String,
    severity: PDFPreflightSeverity,
    state: PDFPreflightFindingState,
    count: Int,
    reasonCodes: [String] = [],
    evidence: String = "inspection"
  ) {
    self.id = id
    self.category = category
    self.code = code
    self.severity = severity
    self.state = state
    self.count = count
    self.reasonCodes = reasonCodes.sorted()
    self.evidence = evidence
  }
}

public struct PDFPreflightSummary: Codable, Equatable, Hashable, Sendable {
  public let findingCount: Int
  public let warningCount: Int
  public let blockedCount: Int
  public let unknownCount: Int
  public let metadataFieldCount: Int
  public let embeddedDataCount: Int
  public let networkBoundaryCount: Int
  public let activeContentCount: Int
  public let unknownCoverageCount: Int

  public init(
    findingCount: Int,
    warningCount: Int,
    blockedCount: Int,
    unknownCount: Int,
    metadataFieldCount: Int,
    embeddedDataCount: Int,
    networkBoundaryCount: Int,
    activeContentCount: Int,
    unknownCoverageCount: Int = 0
  ) {
    self.findingCount = findingCount
    self.warningCount = warningCount
    self.blockedCount = blockedCount
    self.unknownCount = unknownCount
    self.metadataFieldCount = metadataFieldCount
    self.embeddedDataCount = embeddedDataCount
    self.networkBoundaryCount = networkBoundaryCount
    self.activeContentCount = activeContentCount
    self.unknownCoverageCount = unknownCoverageCount
  }
}

public struct PDFPreflightEmbeddedData: Codable, Equatable, Hashable, Sendable {
  public let attachmentCount: Int
  public let possibleTokenCounts: [String: Int]

  public init(attachmentCount: Int, possibleTokenCounts: [String: Int]) {
    self.attachmentCount = attachmentCount
    self.possibleTokenCounts = possibleTokenCounts
  }
}

public struct PDFPreflightAttachments: Codable, Equatable, Hashable, Sendable {
  public let attachmentCount: Int
  public let fileAttachmentCount: Int
  public let embeddedFileNameTreeCount: Int
  public let unknownCount: Int
  public let coverage: PDFPreflightCoverage

  public init(
    attachmentCount: Int,
    fileAttachmentCount: Int,
    embeddedFileNameTreeCount: Int,
    unknownCount: Int,
    coverage: PDFPreflightCoverage
  ) {
    self.attachmentCount = attachmentCount
    self.fileAttachmentCount = fileAttachmentCount
    self.embeddedFileNameTreeCount = embeddedFileNameTreeCount
    self.unknownCount = unknownCount
    self.coverage = coverage
  }
}

public struct PDFPreflightAnnotations: Codable, Equatable, Hashable, Sendable {
  public let totalCount: Int
  public let byKind: [String: Int]
  public let unknownCount: Int
  public let coverage: PDFPreflightCoverage

  public init(totalCount: Int, byKind: [String: Int], unknownCount: Int, coverage: PDFPreflightCoverage) {
    self.totalCount = totalCount
    self.byKind = byKind
    self.unknownCount = unknownCount
    self.coverage = coverage
  }
}

public struct PDFPreflightScripts: Codable, Equatable, Hashable, Sendable {
  public let javaScriptActionCount: Int
  public let openActionCount: Int
  public let additionalActionCount: Int
  public let launchActionCount: Int
  public let submitFormActionCount: Int
  public let remoteGoToActionCount: Int
  public let uriActionCount: Int
  public let executionAttempted: Bool
  public let coverage: PDFPreflightCoverage

  public init(
    javaScriptActionCount: Int,
    openActionCount: Int,
    additionalActionCount: Int,
    launchActionCount: Int,
    submitFormActionCount: Int,
    remoteGoToActionCount: Int,
    uriActionCount: Int,
    executionAttempted: Bool,
    coverage: PDFPreflightCoverage
  ) {
    self.javaScriptActionCount = javaScriptActionCount
    self.openActionCount = openActionCount
    self.additionalActionCount = additionalActionCount
    self.launchActionCount = launchActionCount
    self.submitFormActionCount = submitFormActionCount
    self.remoteGoToActionCount = remoteGoToActionCount
    self.uriActionCount = uriActionCount
    self.executionAttempted = executionAttempted
    self.coverage = coverage
  }
}

public struct PDFPreflightRevisions: Codable, Equatable, Hashable, Sendable {
  public let eofMarkerCount: Int
  public let startxrefCount: Int
  public let previousRevisionReferenceCount: Int
  public let incrementalUpdateCountEstimate: Int
  public let hiddenContentState: PDFPreflightCoverageState
  public let coverage: PDFPreflightCoverage

  public init(
    eofMarkerCount: Int,
    startxrefCount: Int,
    previousRevisionReferenceCount: Int,
    incrementalUpdateCountEstimate: Int,
    hiddenContentState: PDFPreflightCoverageState,
    coverage: PDFPreflightCoverage
  ) {
    self.eofMarkerCount = eofMarkerCount
    self.startxrefCount = startxrefCount
    self.previousRevisionReferenceCount = previousRevisionReferenceCount
    self.incrementalUpdateCountEstimate = incrementalUpdateCountEstimate
    self.hiddenContentState = hiddenContentState
    self.coverage = coverage
  }
}

public struct PDFPreflightUnknownCoverage: Codable, Equatable, Hashable, Sendable {
  public let categories: [String: PDFPreflightCoverage]
  public let unknownCount: Int

  public init(categories: [String: PDFPreflightCoverage]) {
    self.categories = categories
    self.unknownCount = categories.values.filter { $0.state == .unknown }.count
  }
}

public struct PDFPreflightNetworkBoundaries: Codable, Equatable, Hashable, Sendable {
  public let externalURLCount: Int
  public let safeExternalURLCount: Int
  public let unsafeExternalURLCount: Int
  public let internalPageLinkCount: Int
  public let unknownDestinationCount: Int
  public let possibleActionTokenCounts: [String: Int]

  public init(
    externalURLCount: Int,
    safeExternalURLCount: Int,
    unsafeExternalURLCount: Int,
    internalPageLinkCount: Int,
    unknownDestinationCount: Int,
    possibleActionTokenCounts: [String: Int]
  ) {
    self.externalURLCount = externalURLCount
    self.safeExternalURLCount = safeExternalURLCount
    self.unsafeExternalURLCount = unsafeExternalURLCount
    self.internalPageLinkCount = internalPageLinkCount
    self.unknownDestinationCount = unknownDestinationCount
    self.possibleActionTokenCounts = possibleActionTokenCounts
  }
}

public struct PDFPreflightActiveContent: Codable, Equatable, Hashable, Sendable {
  public let possibleActionTokenCounts: [String: Int]
  public let executionAttempted: Bool

  public init(possibleActionTokenCounts: [String: Int], executionAttempted: Bool) {
    self.possibleActionTokenCounts = possibleActionTokenCounts
    self.executionAttempted = executionAttempted
  }
}

public struct PDFPreflightSecurity: Codable, Equatable, Hashable, Sendable {
  public let encrypted: Bool
  public let locked: Bool
  public let permissionsObserved: Bool

  public init(encrypted: Bool, locked: Bool, permissionsObserved: Bool) {
    self.encrypted = encrypted
    self.locked = locked
    self.permissionsObserved = permissionsObserved
  }
}

public struct PDFPreflightSanitization: Codable, Equatable, Hashable, Sendable {
  public let status: PDFSanitizationStatus
  public let safeToClaimClean: Bool
  public let sourceUnchanged: Bool
  public let supportedModes: [String]
  public let limits: [String]

  public init(
    status: PDFSanitizationStatus = .notRun,
    safeToClaimClean: Bool = false,
    sourceUnchanged: Bool = true,
    supportedModes: [String] = ["report-only", "new-copy-required"],
    limits: [String]
  ) {
    self.status = status
    self.safeToClaimClean = safeToClaimClean
    self.sourceUnchanged = sourceUnchanged
    self.supportedModes = supportedModes
    self.limits = limits
  }
}

public struct PDFPreflightPayload: Codable, Equatable, Hashable, Sendable {
  public let summary: PDFPreflightSummary
  public let metadata: Metadata
  public let embeddedData: PDFPreflightEmbeddedData
  public let attachments: PDFPreflightAttachments
  public let annotations: PDFPreflightAnnotations
  public let scripts: PDFPreflightScripts
  public let revisions: PDFPreflightRevisions
  public let coverage: [String: PDFPreflightCoverage]
  public let unknownCoverage: PDFPreflightUnknownCoverage
  public let networkBoundaries: PDFPreflightNetworkBoundaries
  public let activeContent: PDFPreflightActiveContent
  public let security: PDFPreflightSecurity
  public let sanitization: PDFPreflightSanitization
  public let findings: [PDFPreflightFinding]

  public struct Metadata: Codable, Equatable, Hashable, Sendable {
    public let fields: [String: PDFPreflightMetadataField]
    public let rawValuesIncluded: Bool

    public init(fields: [String: PDFPreflightMetadataField], rawValuesIncluded: Bool = false) {
      self.fields = fields
      self.rawValuesIncluded = rawValuesIncluded
    }
  }

  public init(
    summary: PDFPreflightSummary,
    metadata: Metadata,
    embeddedData: PDFPreflightEmbeddedData,
    attachments: PDFPreflightAttachments? = nil,
    annotations: PDFPreflightAnnotations? = nil,
    scripts: PDFPreflightScripts? = nil,
    revisions: PDFPreflightRevisions? = nil,
    coverage: [String: PDFPreflightCoverage] = [:],
    unknownCoverage: PDFPreflightUnknownCoverage? = nil,
    networkBoundaries: PDFPreflightNetworkBoundaries,
    activeContent: PDFPreflightActiveContent,
    security: PDFPreflightSecurity,
    sanitization: PDFPreflightSanitization,
    findings: [PDFPreflightFinding]
  ) {
    self.summary = summary
    self.metadata = metadata
    self.embeddedData = embeddedData
    self.attachments = attachments ?? PDFPreflightAttachments(
      attachmentCount: embeddedData.attachmentCount,
      fileAttachmentCount: embeddedData.possibleTokenCounts["fileAttachment", default: 0],
      embeddedFileNameTreeCount: embeddedData.possibleTokenCounts["embeddedFiles", default: 0],
      unknownCount: 0,
      coverage: PDFPreflightCoverage(state: .unknown, reasonCodes: ["attachmentSurfaceNotProvided"]))
    self.annotations = annotations ?? PDFPreflightAnnotations(
      totalCount: 0, byKind: [:], unknownCount: 0,
      coverage: PDFPreflightCoverage(state: .unknown, reasonCodes: ["annotationSurfaceNotProvided"]))
    self.scripts = scripts ?? PDFPreflightScripts(
      javaScriptActionCount: embeddedData.possibleTokenCounts["javascriptAction", default: 0],
      openActionCount: 0, additionalActionCount: 0, launchActionCount: 0,
      submitFormActionCount: 0, remoteGoToActionCount: 0, uriActionCount: 0,
      executionAttempted: activeContent.executionAttempted,
      coverage: PDFPreflightCoverage(state: .unknown, reasonCodes: ["scriptSurfaceNotProvided"]))
    self.revisions = revisions ?? PDFPreflightRevisions(
      eofMarkerCount: 0, startxrefCount: 0, previousRevisionReferenceCount: 0,
      incrementalUpdateCountEstimate: 0, hiddenContentState: .unknown,
      coverage: PDFPreflightCoverage(state: .unknown, reasonCodes: ["revisionSurfaceNotProvided"]))
    self.coverage = coverage
    self.unknownCoverage = unknownCoverage ?? PDFPreflightUnknownCoverage(categories: coverage)
    self.networkBoundaries = networkBoundaries
    self.activeContent = activeContent
    self.security = security
    self.sanitization = sanitization
    self.findings = findings
  }
}

public struct PDFPreflightHeader: Codable, Equatable, Hashable, Sendable {
  public let contractName: String
  public let version: PDFContractVersion
  public let sourceDigest: String
  public let generatedAt: String
  public let provider: PDFProviderDescriptor

  public init(
    sourceDigest: String,
    provider: PDFProviderDescriptor,
    generatedAt: String = ISO8601DateFormatter().string(from: Date())
  ) {
    self.contractName = "pdf-editor.preflight"
    self.version = PDFContractVersion(major: 1, minor: 1)
    self.sourceDigest = sourceDigest
    self.generatedAt = generatedAt
    self.provider = provider
  }
}

public struct PDFPreflightReport: Codable, Equatable, Hashable, Sendable {
  public let header: PDFPreflightHeader
  public let payload: PDFPreflightPayload

  public init(header: PDFPreflightHeader, payload: PDFPreflightPayload) {
    self.header = header
    self.payload = payload
  }
}

public enum PDFPreflightValidationError: Error, LocalizedError, Equatable, Sendable {
  case invalidContractName
  case unsupportedVersion
  case invalidDigest
  case cleanClaimNotAllowed
  case sanitizationStateNotAllowed
  case activeContentExecuted
  case invalidFindingCount
  case staleSourceDigest

  public var errorDescription: String? {
    switch self {
    case .invalidContractName: "The preflight contract name is invalid."
    case .unsupportedVersion: "The preflight contract version is unsupported."
    case .invalidDigest: "The preflight source digest is not a SHA-256 digest."
    case .cleanClaimNotAllowed: "Preflight cannot claim that a PDF is sanitized or clean."
    case .sanitizationStateNotAllowed: "Preflight sanitization must remain in the not-run state."
    case .activeContentExecuted: "Preflight must not execute active PDF content."
    case .invalidFindingCount: "The preflight summary does not match its finding list."
    case .staleSourceDigest: "The preflight report is bound to a different source digest."
    }
  }
}

public enum PDFPreflightValidator {
  public static func validate(_ report: PDFPreflightReport, expectedSourceDigest: String? = nil) throws {
    guard report.header.contractName == "pdf-editor.preflight" else {
      throw PDFPreflightValidationError.invalidContractName
    }
    guard report.header.version == PDFContractVersion(major: 1, minor: 1) else {
      throw PDFPreflightValidationError.unsupportedVersion
    }
    guard report.header.sourceDigest.range(of: "^[0-9a-fA-F]{64}$", options: .regularExpression) != nil else {
      throw PDFPreflightValidationError.invalidDigest
    }
    if let expectedSourceDigest {
      guard report.header.sourceDigest.caseInsensitiveCompare(expectedSourceDigest) == .orderedSame else {
        throw PDFPreflightValidationError.staleSourceDigest
      }
    }
    guard report.payload.metadata.rawValuesIncluded == false,
      report.payload.sanitization.status == .notRun,
      report.payload.sanitization.sourceUnchanged == true,
      report.payload.sanitization.safeToClaimClean == false
    else {
      if report.payload.sanitization.status != .notRun || report.payload.sanitization.sourceUnchanged == false {
        throw PDFPreflightValidationError.sanitizationStateNotAllowed
      }
      throw PDFPreflightValidationError.cleanClaimNotAllowed
    }
    guard report.payload.activeContent.executionAttempted == false else {
      throw PDFPreflightValidationError.activeContentExecuted
    }
    guard report.payload.scripts.executionAttempted == false else {
      throw PDFPreflightValidationError.activeContentExecuted
    }
    let findings = report.payload.findings
    let summary = report.payload.summary
    guard summary.findingCount == findings.count,
      summary.warningCount == findings.filter({ $0.severity == .warning }).count,
      summary.blockedCount == findings.filter({ $0.severity == .blocked }).count,
      summary.unknownCount == findings.filter({ $0.state == .unknown }).count,
      summary.unknownCoverageCount == report.payload.unknownCoverage.unknownCount
    else {
      throw PDFPreflightValidationError.invalidFindingCount
    }
  }
}

public enum PDFPreflightBuilder {
  private static let metadataFields = [
    "title", "author", "subject", "creator", "producer", "creationDate", "modificationDate", "keywords"
  ]

  private struct TokenScan {
    let counts: [String: Int]
    let scannedByteCount: Int
    let truncated: Bool
  }

  public static func build(
    inspection: DocumentInspection,
    data: Data,
    provider: PDFProviderDescriptor,
    generatedAt: String = ISO8601DateFormatter().string(from: Date()),
    maximumScanBytes: Int = 50_000_000
  ) -> PDFPreflightReport {
    let scan = scan(data: data, maximumScanBytes: maximumScanBytes)
    let metadataValues = [
      inspection.metadata.title, inspection.metadata.author, inspection.metadata.subject,
      inspection.metadata.creator, inspection.metadata.producer, inspection.metadata.creationDate,
      inspection.metadata.modificationDate, inspection.metadata.keywords
    ]
    let metadata = Dictionary(uniqueKeysWithValues: zip(metadataFields, metadataValues).map {
      ($0.0, PDFPreflightMetadataField(present: !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    })
    let metadataCount = metadata.values.filter(\.present).count
    let external = inspection.links.filter { $0.kind == .externalURL }
    let unsafeExternal = external.filter { !$0.isSafeExternal }
    let counts = scan.counts
    let annotationKindCounts = inspection.annotationTypeCounts
    let annotationTotal = annotationKindCounts.values.reduce(0, +)
    let annotationUnknownCount = annotationKindCounts["unknown", default: 0]
    let coverage: [String: PDFPreflightCoverage] = [
      "metadata": PDFPreflightCoverage(
        state: counts["metadataStream", default: 0] > 0 ? .partial : .observed,
        reasonCodes: counts["metadataStream", default: 0] > 0 ? ["xmpMetadataPresenceDetectedButNotParsed"] : []),
      "attachments": PDFPreflightCoverage(
        state: scan.truncated ? .partial : .observed,
        reasonCodes: scan.truncated ? ["boundedScanTruncated"] : ["embeddedPayloadBytesNotRetained"]),
      "annotations": PDFPreflightCoverage(state: .observed, reasonCodes: ["pdfkitPageAnnotationEnumeration"]),
      "scripts": PDFPreflightCoverage(
        state: .partial,
        reasonCodes: ["tokenScanDoesNotProveReachability"] + (scan.truncated ? ["boundedScanTruncated"] : [])),
      "revisions": PDFPreflightCoverage(state: .unknown, reasonCodes: ["incrementalRevisionParserNotRun"])
    ]
    let unknownCoverage = PDFPreflightUnknownCoverage(categories: coverage)
    let findings: [PDFPreflightFinding] = [
      makeFinding("metadata-presence", .metadata, "metadata.present", metadataCount > 0 ? .warning : .info, metadataCount > 0 ? .observed : .notObserved, metadataCount, metadataCount > 0 ? ["metadataValuesMayContainPersonalInformation"] : []),
      makeFinding("embedded-attachments", .embeddedData, "embedded.attachments", inspection.attachments.isEmpty ? .info : .warning, inspection.attachments.isEmpty ? .notObserved : .observed, inspection.attachments.count, inspection.attachments.isEmpty ? [] : ["embeddedContentRequiresSeparateReview"]),
      tokenFinding(counts, "embeddedFiles", .embeddedData, "embedded-file-spec-token", .warning, ["possibleEmbeddedFileNameTree"]),
      tokenFinding(counts, "fileAttachment", .embeddedData, "file-attachment-token", .warning, ["possibleEmbeddedAttachmentAnnotation"]),
      tokenFinding(counts, "xfa", .embeddedData, "xfa-token", .blocked, ["xfaSemanticsNotPreservedBySharedContract"]),
      tokenFinding(counts, "richMedia", .embeddedData, "rich-media-token", .blocked, ["richMediaRequiresIsolatedProvider"]),
      makeFinding("network-external", .networkBoundary, "network.external-links", external.isEmpty ? .info : .warning, external.isEmpty ? .notObserved : .observed, external.count, external.isEmpty ? [] : ["destinationNotFetchedByPreflight"]),
      makeFinding("network-unsafe", .networkBoundary, "network.unsafe-links", unsafeExternal.isEmpty ? .info : .blocked, unsafeExternal.isEmpty ? .notObserved : .observed, unsafeExternal.count, unsafeExternal.isEmpty ? [] : ["unsafeSchemeOrDestination"]),
      tokenFinding(counts, "uriAction", .networkBoundary, "network-uri-action-token", .warning, ["possibleNetworkAction"]),
      tokenFinding(counts, "remoteGoToAction", .networkBoundary, "network-remote-goto-token", .warning, ["possibleRemoteDocumentReference"]),
      tokenFinding(counts, "submitFormAction", .networkBoundary, "network-submit-form-token", .blocked, ["formSubmissionMustNeverBeExecutedByPreflight"]),
      tokenFinding(counts, "launchAction", .activeContent, "active-launch-token", .blocked, ["launchActionNeverExecuted"]),
      tokenFinding(counts, "javascriptAction", .activeContent, "active-javascript-token", .blocked, ["embeddedJavaScriptNeverExecuted"]),
      tokenFinding(counts, "openAction", .activeContent, "active-open-action-token", .warning, ["documentOpenActionNotExecuted"]),
      tokenFinding(counts, "additionalAction", .activeContent, "active-additional-action-token", .warning, ["additionalActionsNotExecuted"]),
      tokenFinding(counts, "signature", .security, "signature-token", .warning, ["signatureValidityRequiresCryptographicValidator"]),
      makeFinding("security-encryption", .security, "security.encryption", inspection.security.isEncrypted ? .warning : .info, inspection.security.isEncrypted ? .observed : .notObserved, inspection.security.isEncrypted ? 1 : 0, inspection.security.isEncrypted ? ["passwordAndPermissionsBoundary"] : []),
      makeFinding("byte-scan-state", .preflight, "preflight.byte-scan", scan.truncated ? .warning : .info, .observed, scan.scannedByteCount, scan.truncated ? ["boundedScanTruncated"] : [], evidence: "boundedTokenScan")
    ]
    let summary = PDFPreflightSummary(
      findingCount: findings.count,
      warningCount: findings.filter({ $0.severity == .warning }).count,
      blockedCount: findings.filter({ $0.severity == .blocked }).count,
      unknownCount: findings.filter({ $0.state == .unknown }).count,
      metadataFieldCount: metadataCount,
      embeddedDataCount: inspection.attachments.count + (counts["embeddedFiles", default: 0]) + (counts["fileAttachment", default: 0]),
      networkBoundaryCount: external.count + counts["uriAction", default: 0] + counts["remoteGoToAction", default: 0] + counts["submitFormAction", default: 0],
      activeContentCount: counts["javascriptAction", default: 0] + counts["openAction", default: 0] + counts["additionalAction", default: 0] + counts["launchAction", default: 0],
      unknownCoverageCount: unknownCoverage.unknownCount
    )
    let payload = PDFPreflightPayload(
      summary: summary,
      metadata: .init(fields: metadata),
      embeddedData: .init(attachmentCount: inspection.attachments.count, possibleTokenCounts: [
        "embeddedFiles": counts["embeddedFiles", default: 0], "fileAttachment": counts["fileAttachment", default: 0],
        "xfa": counts["xfa", default: 0], "richMedia": counts["richMedia", default: 0]
      ]),
      attachments: .init(
        attachmentCount: inspection.attachments.count,
        fileAttachmentCount: annotationKindCounts["fileAttachment", default: 0] + counts["fileAttachment", default: 0],
        embeddedFileNameTreeCount: counts["embeddedFiles", default: 0],
        unknownCount: scan.truncated ? 1 : 0,
        coverage: coverage["attachments"]!),
      annotations: .init(
        totalCount: annotationTotal,
        byKind: annotationKindCounts,
        unknownCount: annotationUnknownCount,
        coverage: coverage["annotations"]!),
      scripts: .init(
        javaScriptActionCount: counts["javascriptAction", default: 0],
        openActionCount: counts["openAction", default: 0],
        additionalActionCount: counts["additionalAction", default: 0],
        launchActionCount: counts["launchAction", default: 0],
        submitFormActionCount: counts["submitFormAction", default: 0],
        remoteGoToActionCount: counts["remoteGoToAction", default: 0],
        uriActionCount: counts["uriAction", default: 0],
        executionAttempted: false,
        coverage: coverage["scripts"]!),
      revisions: .init(
        eofMarkerCount: counts["eofMarker", default: 0],
        startxrefCount: counts["startxref", default: 0],
        previousRevisionReferenceCount: counts["previousRevision", default: 0],
        incrementalUpdateCountEstimate: max(0, counts["eofMarker", default: 0] - 1),
        hiddenContentState: .unknown,
        coverage: coverage["revisions"]!),
      coverage: coverage,
      unknownCoverage: unknownCoverage,
      networkBoundaries: .init(
        externalURLCount: external.count,
        safeExternalURLCount: external.count - unsafeExternal.count,
        unsafeExternalURLCount: unsafeExternal.count,
        internalPageLinkCount: inspection.links.filter { $0.kind == .internalPage }.count,
        unknownDestinationCount: inspection.links.filter { $0.kind == .unknown }.count,
        possibleActionTokenCounts: ["uri": counts["uriAction", default: 0], "remoteGoTo": counts["remoteGoToAction", default: 0], "submitForm": counts["submitFormAction", default: 0]]
      ),
      activeContent: .init(possibleActionTokenCounts: ["javascript": counts["javascriptAction", default: 0], "openAction": counts["openAction", default: 0], "additionalAction": counts["additionalAction", default: 0], "launch": counts["launchAction", default: 0]], executionAttempted: false),
      security: .init(encrypted: inspection.security.isEncrypted, locked: inspection.security.isLocked, permissionsObserved: true),
      sanitization: .init(limits: [
        "Preflight does not remove metadata or embedded data.",
        "Preflight does not execute or neutralize document JavaScript or actions.",
        "Preflight does not prove that hidden incremental revisions are absent.",
        "Preflight does not prove that signatures remain valid after mutation.",
        "Preflight does not certify XFA, rich media, annotations, or embedded files as preserved or removed.",
        "A bounded token scan may report possible structures without proving reachability."
      ]),
      findings: findings
    )
    return PDFPreflightReport(header: .init(sourceDigest: inspection.source.sha256, provider: provider, generatedAt: generatedAt), payload: payload)
  }

  private static func makeFinding(
    _ id: String,
    _ category: PDFPreflightFindingCategory,
    _ code: String,
    _ severity: PDFPreflightSeverity,
    _ state: PDFPreflightFindingState,
    _ count: Int,
    _ reasonCodes: [String],
    evidence: String = "inspection"
  ) -> PDFPreflightFinding {
    PDFPreflightFinding(id: id, category: category, code: code, severity: severity, state: state, count: count, reasonCodes: reasonCodes, evidence: evidence)
  }

  private static func tokenFinding(
    _ counts: [String: Int],
    _ token: String,
    _ category: PDFPreflightFindingCategory,
    _ code: String,
    _ severity: PDFPreflightSeverity,
    _ reasonCodes: [String]
  ) -> PDFPreflightFinding {
    let count = counts[token, default: 0]
    return makeFinding("\(category.rawValue)-\(code)", category, code, count == 0 ? .info : severity, count == 0 ? .notObserved : .possible, count, count == 0 ? [] : reasonCodes, evidence: "boundedTokenScan")
  }

  private static func scan(data: Data, maximumScanBytes: Int) -> TokenScan {
    let scanData = data.prefix(maximumScanBytes)
    let bytes = Array(scanData)
    let tokens: [String: [UInt8]] = [
      "embeddedFiles": Array("/EmbeddedFiles".utf8), "fileAttachment": Array("/FileAttachment".utf8), "xfa": Array("/XFA".utf8), "richMedia": Array("/RichMedia".utf8),
      "javascriptAction": Array("/JavaScript".utf8) + Array("/JS".utf8), "openAction": Array("/OpenAction".utf8), "additionalAction": Array("/AA".utf8), "launchAction": Array("/Launch".utf8),
      "submitFormAction": Array("/SubmitForm".utf8), "remoteGoToAction": Array("/GoToR".utf8), "uriAction": Array("/URI".utf8), "encryption": Array("/Encrypt".utf8), "signature": Array("/Sig".utf8), "metadataStream": Array("/Metadata".utf8), "eofMarker": Array("%%EOF".utf8), "startxref": Array("startxref".utf8), "previousRevision": Array("/Prev".utf8)
    ]
    var counts: [String: Int] = [:]
    for (key, token) in tokens {
      if key == "javascriptAction" {
        counts[key] = count(bytes, token: Array("/JavaScript".utf8)) + count(bytes, token: Array("/JS".utf8))
      } else if key == "signature" {
        counts[key] = count(bytes, token: token) + count(bytes, token: Array("/DocTimeStamp".utf8))
      } else {
        counts[key] = count(bytes, token: token)
      }
    }
    return TokenScan(counts: counts, scannedByteCount: bytes.count, truncated: data.count > maximumScanBytes)
  }

  private static func count(_ bytes: [UInt8], token: [UInt8]) -> Int {
    guard !token.isEmpty, bytes.count >= token.count else { return 0 }
    var total = 0
    for index in 0...(bytes.count - token.count) where Array(bytes[index..<(index + token.count)]) == token {
      let end = index + token.count
      let next = end < bytes.count ? bytes[end] : nil
      if next == nil || !isPDFNameCharacter(next!) {
        total += 1
      }
    }
    return total
  }

  private static func isPDFNameCharacter(_ byte: UInt8) -> Bool {
    (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) ||
      (byte >= 97 && byte <= 122) || byte == 45 || byte == 95
  }
}
