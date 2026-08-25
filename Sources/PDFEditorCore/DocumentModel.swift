import CoreGraphics
import Foundation

public struct PDFRect: Codable, Equatable, Hashable, Sendable {
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double

  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }

  public init(_ rect: CGRect) {
    let standardized = rect.standardized
    self.init(
      x: Double(standardized.origin.x),
      y: Double(standardized.origin.y),
      width: Double(standardized.size.width),
      height: Double(standardized.size.height)
    )
  }

  public var cgRect: CGRect {
    CGRect(x: x, y: y, width: width, height: height)
  }
}

public struct DocumentSource: Codable, Equatable, Hashable, Sendable {
  public let fileName: String
  public let byteCount: Int
  public let sha256: String

  public init(fileName: String, byteCount: Int, sha256: String) {
    self.fileName = fileName
    self.byteCount = byteCount
    self.sha256 = sha256
  }
}

public struct PageSnapshot: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let pageIndex: Int
  public let pageLabel: String
  public let bounds: PDFRect
  public let cropBox: PDFRect?
  public let bleedBox: PDFRect?
  public let trimBox: PDFRect?
  public let artBox: PDFRect?
  public let rotation: Int
  public let characterCount: Int
  public let annotationCount: Int
  public let hasSelectableText: Bool

  public var id: Int { pageIndex }

  public init(
    pageIndex: Int,
    pageLabel: String,
    bounds: PDFRect,
    cropBox: PDFRect?,
    bleedBox: PDFRect?,
    trimBox: PDFRect?,
    artBox: PDFRect?,
    rotation: Int,
    characterCount: Int,
    annotationCount: Int,
    hasSelectableText: Bool
  ) {
    self.pageIndex = pageIndex
    self.pageLabel = pageLabel
    self.bounds = bounds
    self.cropBox = cropBox
    self.bleedBox = bleedBox
    self.trimBox = trimBox
    self.artBox = artBox
    self.rotation = rotation
    self.characterCount = characterCount
    self.annotationCount = annotationCount
    self.hasSelectableText = hasSelectableText
  }
}

public enum NativeFieldKind: String, Codable, CaseIterable, Hashable, Sendable {
  case text
  case button
  case choice
  case signature
  case unknown
}

public struct NativeField: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let kind: NativeFieldKind
  public let pageIndex: Int
  public let bounds: PDFRect
  public let value: String?
  public let choices: [String]

  public init(
    id: String,
    name: String,
    kind: NativeFieldKind,
    pageIndex: Int,
    bounds: PDFRect,
    value: String?,
    choices: [String]
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.pageIndex = pageIndex
    self.bounds = bounds
    self.value = value
    self.choices = choices
  }
}

public enum CandidateKind: String, Codable, CaseIterable, Hashable, Sendable {
  case nativeField
  case vectorRegion
  case textAnchored
  case ocrRegion
  case manual
}

public enum CandidateStatus: String, Codable, CaseIterable, Hashable, Sendable {
  case suggested
  case confirmed
  case rejected
  case unknown
}

public struct RegionCandidate: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let pageIndex: Int
  public let bounds: PDFRect
  public let kind: CandidateKind
  public var status: CandidateStatus
  public let score: Double
  public let evidence: [String]
  public let nativeFieldID: String?
  public let coordinate: PDFPageRegion?
  public let suggestedFieldType: SuggestedFieldType?
  public let entryMode: CandidateEntryMode
  public let labelText: String?
  public let groupMemberCount: Int
  public let memberBounds: [PDFRect]
  public let evidenceItems: [CandidateEvidence]
  public let sourceDigest: String?
  public let fusion: EvidenceFusionResult?

  private enum CodingKeys: String, CodingKey {
    case id
    case pageIndex
    case bounds
    case kind
    case status
    case score
    case evidence
    case nativeFieldID
    case coordinate
    case suggestedFieldType
    case entryMode
    case labelText
    case groupMemberCount
    case memberBounds
    case evidenceItems
    case sourceDigest
    case fusion
  }

  public init(
    id: UUID = UUID(),
    pageIndex: Int,
    bounds: PDFRect,
    kind: CandidateKind,
    status: CandidateStatus = .suggested,
    score: Double,
    evidence: [String],
    nativeFieldID: String? = nil,
    coordinate: PDFPageRegion? = nil,
    suggestedFieldType: SuggestedFieldType? = nil,
    entryMode: CandidateEntryMode = .unknown,
    labelText: String? = nil,
    groupMemberCount: Int = 1,
    memberBounds: [PDFRect] = [],
    evidenceItems: [CandidateEvidence] = [],
    sourceDigest: String? = nil,
    fusion: EvidenceFusionResult? = nil
  ) {
    self.id = id
    self.pageIndex = pageIndex
    self.bounds = bounds
    self.kind = kind
    self.status = status
    self.score = score
    self.evidence = evidence
    self.nativeFieldID = nativeFieldID
    self.coordinate = coordinate
    self.suggestedFieldType = suggestedFieldType
    self.entryMode = entryMode
    self.labelText = labelText
    self.groupMemberCount = max(1, groupMemberCount)
    self.memberBounds = memberBounds
    self.evidenceItems = evidenceItems
    self.sourceDigest = sourceDigest
    self.fusion = fusion ?? EvidenceFusion.fuse(signals: evidenceItems.enumerated().map { index, item in
      EvidenceFusionSignal(
        id: item.id.uuidString,
        kind: item.kind,
        origin: item.origin,
        providerID: item.provider?.id,
        score: item.score ?? 0,
        region: item.region?.rect
      )
    })
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.pageIndex = try container.decode(Int.self, forKey: .pageIndex)
    self.bounds = try container.decode(PDFRect.self, forKey: .bounds)
    self.kind = try container.decode(CandidateKind.self, forKey: .kind)
    self.status = try container.decodeIfPresent(CandidateStatus.self, forKey: .status) ?? .unknown
    self.score = try container.decode(Double.self, forKey: .score)
    self.evidence = try container.decodeIfPresent([String].self, forKey: .evidence) ?? []
    self.nativeFieldID = try container.decodeIfPresent(String.self, forKey: .nativeFieldID)
    self.coordinate = try container.decodeIfPresent(PDFPageRegion.self, forKey: .coordinate)
    self.suggestedFieldType = try container.decodeIfPresent(
      SuggestedFieldType.self, forKey: .suggestedFieldType)
    self.entryMode =
      try container.decodeIfPresent(CandidateEntryMode.self, forKey: .entryMode) ?? .unknown
    self.labelText = try container.decodeIfPresent(String.self, forKey: .labelText)
    self.groupMemberCount = max(
      1, try container.decodeIfPresent(Int.self, forKey: .groupMemberCount) ?? 1)
    self.memberBounds = try container.decodeIfPresent([PDFRect].self, forKey: .memberBounds) ?? []
    self.evidenceItems =
      try container.decodeIfPresent([CandidateEvidence].self, forKey: .evidenceItems) ?? []
    self.sourceDigest = try container.decodeIfPresent(String.self, forKey: .sourceDigest)
    self.fusion = try container.decodeIfPresent(EvidenceFusionResult.self, forKey: .fusion)
  }

  public var isDirectlyEditable: Bool {
    switch entryMode {
    case .singleText, .characterGrid, .signature:
      return true
    case .checkbox, .radioGroup, .unknown:
      return false
    }
  }
}

public enum EditKind: String, Codable, CaseIterable, Hashable, Sendable {
  case nativeFieldValue
  case synthesizeNativeField
  case overlayText
  /// Semantic rewrite of an existing text run. This is distinct from an
  /// overlay and remains provider-gated until the writer proves glyph/font
  /// preservation and independent outside-region fidelity.
  case textRunReplacement
  case overlayImage
  case stamp
  case annotation
  case pageTransform
  case pageInsert
  case pageDelete
  case pageMove
  case flatten
  case redactMark
  case applyRedaction
  case metadata
  case sanitize
}

public struct EditOperation: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let pageIndex: Int
  public let targetID: String?
  public let kind: EditKind
  public let value: String
  public let bounds: PDFRect?
  public let candidateID: UUID?
  public let previousValue: String?
  public let createdAt: Date
  public let sessionID: UUID?
  public let parentOperationID: UUID?
  public let sourceDigest: String?
  public let coordinate: PDFPageRegion?
  public let payload: EditPayload?
  public let reversible: Bool
  public let destructive: Bool

  public init(
    id: UUID = UUID(),
    pageIndex: Int,
    targetID: String? = nil,
    kind: EditKind,
    value: String,
    bounds: PDFRect? = nil,
    candidateID: UUID? = nil,
    previousValue: String? = nil,
    createdAt: Date = Date(),
    sessionID: UUID? = nil,
    parentOperationID: UUID? = nil,
    sourceDigest: String? = nil,
    coordinate: PDFPageRegion? = nil,
    payload: EditPayload? = nil,
    reversible: Bool = true,
    destructive: Bool = false
  ) {
    self.id = id
    self.pageIndex = pageIndex
    self.targetID = targetID
    self.kind = kind
    self.value = value
    self.bounds = bounds
    self.candidateID = candidateID
    self.previousValue = previousValue
    self.createdAt = createdAt
    self.sessionID = sessionID
    self.parentOperationID = parentOperationID
    self.sourceDigest = sourceDigest
    self.coordinate = coordinate
    self.payload = payload
    self.reversible = reversible
    self.destructive = destructive
  }
}

public enum ReaderViewMode: String, Codable, CaseIterable, Hashable, Sendable {
  case singlePage
  case continuous
  case twoPage
}

public enum ReaderScaleMode: String, Codable, CaseIterable, Hashable, Sendable {
  case fitWidth
  case fitPage
  case zoom
}

// MARK: - Editor Mode (D-010)

/// The four user-facing intent modes for the editor.
///
/// Mode is always set by explicit user action (mode pill, keyboard shortcut, or
/// intent-inferred from a tap). It is never auto-set by document content. Every
/// call to `open(url:)` resets the mode to `.read`.
///
/// - `read`: Passive scroll and zoom. No edit affordances. Zero overlay highlights.
/// - `fill`: All editable regions highlighted. Tab/Return walks them in reading order.
/// - `sign`: Signature regions highlighted; draw/type/image sheet is active.
/// - `edit`: Full authoring palette. L3 ops (redact apply, flatten) require confirmation.
public enum EditorMode: String, Codable, CaseIterable, Hashable, Sendable {
  case read
  case fill
  case sign
  case edit

  /// Human-readable label for the mode pill.
  public var displayName: String {
    switch self {
    case .read: return "Read"
    case .fill: return "Fill"
    case .sign: return "Sign"
    case .edit: return "Edit"
    }
  }

  /// SF Symbol for the mode pill icon.
  public var symbolName: String {
    switch self {
    case .read: return "doc.text.magnifyingglass"
    case .fill: return "pencil.and.list.clipboard"
    case .sign: return "signature"
    case .edit: return "pencil.tip.crop.circle"
    }
  }
}

/// A region that the Fill-mode highlight overlay should draw.
///
/// The overlay layer is a purely visual `CAShapeLayer` on `PDFKitView`; it does
/// not modify the live `PDFDocument`. No `PDFAnnotation` is created until the
/// user confirms an edit and `provider.apply(_:to:)` is called.
public struct FillHighlight: Equatable, Hashable, Sendable {
  public enum State: String, Equatable, Hashable, Sendable {
    /// Native field: solid accent border.
    case nativeField
    /// Candidate not yet filled: dashed orange border.
    case candidateUnfilled
    /// Candidate already filled: solid green border.
    case candidateFilled
    /// Signature region: dashed purple border.
    case signatureRegion
    /// Currently focused / selected region: accent fill overlay.
    case focused
    /// Diff: change detected outside authorized operation regions (red).
    case outsideRegionChange
    /// Diff: change detected inside authorized operation regions (green).
    case insideRegionChange
    /// Diff: region preserved (no change).
    case preserved
  }

  public let id: String
  public let pageIndex: Int
  public let bounds: PDFRect
  public let state: State
  public let label: String?

  public init(
    id: String,
    pageIndex: Int,
    bounds: PDFRect,
    state: State,
    label: String? = nil
  ) {
    self.id = id
    self.pageIndex = pageIndex
    self.bounds = bounds
    self.state = state
    self.label = label
  }
}

/// A user-saved signature stored in the app sandbox.
///
/// Signatures are never stored in the source PDF or in any external service.
/// The user must explicitly check "Save this signature" for the entry to
/// persist across sessions. Cleared by "Forget all signatures" in Settings.
public struct SavedSignature: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let label: String
  /// PNG data URL for the signature image.
  public let dataURL: String
  public let createdAt: Date

  public var rawImageData: Data? {
    let prefix = "base64,"
    if let range = dataURL.range(of: prefix) {
      let base64 = String(dataURL[range.upperBound...])
      return Data(base64Encoded: base64)
    }
    return Data(base64Encoded: dataURL)
  }

  public init(id: UUID = UUID(), label: String, dataURL: String, createdAt: Date = Date()) {
    self.id = id
    self.label = label
    self.dataURL = dataURL
    self.createdAt = createdAt
  }
}

/// A reference to an editable region used by tab-order navigation.
public struct EditableRegionRef: Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case nativeField(id: String)
    case candidate(id: UUID)
  }
  public let kind: Kind
  public let pageIndex: Int
  public let bounds: PDFRect

  public init(kind: Kind, pageIndex: Int, bounds: PDFRect) {
    self.kind = kind
    self.pageIndex = pageIndex
    self.bounds = bounds
  }
}

/// State for an inline text editor placed on top of the PDF canvas at a target region.
public struct InlineEditorState: Equatable, Sendable {
  public let target: EditableRegionRef
  public var draftText: String
  public let initialValue: String
  public let label: String?

  public init(
    target: EditableRegionRef,
    draftText: String,
    initialValue: String = "",
    label: String? = nil
  ) {
    self.target = target
    self.draftText = draftText
    self.initialValue = initialValue
    self.label = label
  }
}


public enum PDFLinkKind: String, Codable, CaseIterable, Hashable, Sendable {
  case externalURL
  case internalPage
  case namedDestination
  case outline
  case unknown
}

public struct PDFLink: Codable, Equatable, Hashable, Sendable {
  public let id: String
  public let pageIndex: Int
  public let label: String
  public let kind: PDFLinkKind
  public let targetPageIndex: Int?
  public let destination: String?
  public let destinationBounds: PDFRect?
  public let isSafeExternal: Bool

  public init(
    id: String,
    pageIndex: Int,
    label: String,
    kind: PDFLinkKind,
    targetPageIndex: Int? = nil,
    destination: String? = nil,
    destinationBounds: PDFRect? = nil,
    isSafeExternal: Bool = false
  ) {
    self.id = id
    self.pageIndex = pageIndex
    self.label = label
    self.kind = kind
    self.targetPageIndex = targetPageIndex
    self.destination = destination
    self.destinationBounds = destinationBounds
    self.isSafeExternal = isSafeExternal
  }
}

public struct PDFOutlineItem: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let level: Int
  public let destinationPageIndex: Int?
  public let children: [PDFOutlineItem]

  public init(
    id: String,
    title: String,
    level: Int,
    destinationPageIndex: Int? = nil,
    children: [PDFOutlineItem] = []
  ) {
    self.id = id
    self.title = title
    self.level = level
    self.destinationPageIndex = destinationPageIndex
    self.children = children
  }
}

public struct PDFDocumentMetadata: Codable, Equatable, Hashable, Sendable {
  public let title: String
  public let author: String
  public let subject: String
  public let creator: String
  public let producer: String
  public let creationDate: String
  public let modificationDate: String
  public let keywords: String

  public init(
    title: String,
    author: String,
    subject: String,
    creator: String,
    producer: String,
    creationDate: String,
    modificationDate: String,
    keywords: String
  ) {
    self.title = title
    self.author = author
    self.subject = subject
    self.creator = creator
    self.producer = producer
    self.creationDate = creationDate
    self.modificationDate = modificationDate
    self.keywords = keywords
  }

  public static let unknown = PDFDocumentMetadata(
    title: "",
    author: "",
    subject: "",
    creator: "",
    producer: "",
    creationDate: "",
    modificationDate: "",
    keywords: ""
  )
}

public struct PDFPermissionsSummary: Codable, Equatable, Hashable, Sendable {
  public let canPrint: Bool
  public let canCopy: Bool
  public let canModify: Bool
  public let canAddAnnotations: Bool
  public let isReadOnly: Bool

  public init(
    canPrint: Bool, canCopy: Bool, canModify: Bool, canAddAnnotations: Bool, isReadOnly: Bool
  ) {
    self.canPrint = canPrint
    self.canCopy = canCopy
    self.canModify = canModify
    self.canAddAnnotations = canAddAnnotations
    self.isReadOnly = isReadOnly
  }

  public static let unknown = PDFPermissionsSummary(
    canPrint: false,
    canCopy: false,
    canModify: false,
    canAddAnnotations: false,
    isReadOnly: false
  )
}

public struct PDFSecuritySummary: Codable, Equatable, Hashable, Sendable {
  public let isEncrypted: Bool
  public let isLocked: Bool
  public let requiresPassword: Bool

  public init(isEncrypted: Bool, isLocked: Bool, requiresPassword: Bool) {
    self.isEncrypted = isEncrypted
    self.isLocked = isLocked
    self.requiresPassword = requiresPassword
  }

  public static let unknown = PDFSecuritySummary(
    isEncrypted: false, isLocked: false, requiresPassword: false)
}

public struct PDFAccessibilitySummary: Codable, Equatable, Hashable, Sendable {
  public let hasTaggedContent: Bool
  public let hasReadingOrder: Bool
  public let notes: [String]

  public init(hasTaggedContent: Bool, hasReadingOrder: Bool, notes: [String]) {
    self.hasTaggedContent = hasTaggedContent
    self.hasReadingOrder = hasReadingOrder
    self.notes = notes
  }

  public static let unknown = PDFAccessibilitySummary(
    hasTaggedContent: false, hasReadingOrder: false,
    notes: ["Tagged-content/reading-order validation not run in this lane."])
}

public enum ValidationStatus: String, Codable, Hashable, Sendable {
  case validated
  case validatedWithWarnings
  case failed
}

public struct ValidationReport: Codable, Equatable, Hashable, Sendable {
  public let status: ValidationStatus
  public let messages: [String]
  public let sourceUnchanged: Bool
  public let outputReopenable: Bool
  public let checks: [ValidationCheck]
  public let sourceDigest: String?
  public let outputDigest: String?
  public let provider: PDFProviderDescriptor?
  public let validatedAt: Date?
  public let operationIDs: [UUID]

  public init(
    status: ValidationStatus,
    messages: [String],
    sourceUnchanged: Bool,
    outputReopenable: Bool,
    checks: [ValidationCheck] = [],
    sourceDigest: String? = nil,
    outputDigest: String? = nil,
    provider: PDFProviderDescriptor? = nil,
    validatedAt: Date? = nil,
    operationIDs: [UUID] = []
  ) {
    self.status = status
    self.messages = messages
    self.sourceUnchanged = sourceUnchanged
    self.outputReopenable = outputReopenable
    self.checks = checks
    self.sourceDigest = sourceDigest
    self.outputDigest = outputDigest
    self.provider = provider
    self.validatedAt = validatedAt
    self.operationIDs = operationIDs
  }
}

public struct DocumentInspection: Codable, Equatable, Sendable {
  public let source: DocumentSource
  public let pages: [PageSnapshot]
  public let fields: [NativeField]
  public let candidates: [RegionCandidate]
  public let warnings: [String]
  public let links: [PDFLink]
  public let outlines: [PDFOutlineItem]
  public let metadata: PDFDocumentMetadata
  public let permissions: PDFPermissionsSummary
  public let attachments: [String]
  public let accessibility: PDFAccessibilitySummary
  public let security: PDFSecuritySummary
  /// Provider-neutral annotation taxonomy used by the read-only privacy preflight.
  /// Keys are normalized categories such as widget, link, markup, and unknown.
  public let annotationTypeCounts: [String: Int]

  public init(
    source: DocumentSource,
    pages: [PageSnapshot],
    fields: [NativeField],
    candidates: [RegionCandidate],
    warnings: [String],
    links: [PDFLink] = [],
    outlines: [PDFOutlineItem] = [],
    metadata: PDFDocumentMetadata = .unknown,
    permissions: PDFPermissionsSummary = .unknown,
    attachments: [String] = [],
    accessibility: PDFAccessibilitySummary = .unknown,
    security: PDFSecuritySummary = .unknown,
    annotationTypeCounts: [String: Int] = [:]
  ) {
    self.source = source
    self.pages = pages
    self.fields = fields
    self.candidates = candidates
    self.warnings = warnings
    self.links = links
    self.outlines = outlines
    self.metadata = metadata
    self.permissions = permissions
    self.attachments = attachments
    self.accessibility = accessibility
    self.security = security
    self.annotationTypeCounts = annotationTypeCounts
  }
}

public struct ExportResult: Sendable {
  public let outputURL: URL
  public let report: ValidationReport

  public init(outputURL: URL, report: ValidationReport) {
    self.outputURL = outputURL
    self.report = report
  }
}

public enum PDFEditorError: Error, LocalizedError, Sendable {
  case inputMissing(String)
  case inputTooLarge(Int)
  case cannotOpen(String)
  case passwordRequired(String)
  case passwordIncorrect(String)
  case invalidPage(Int)
  case invalidOperation(String)
  case exportFailed(String)

  public var errorDescription: String? {
    switch self {
    case .inputMissing(let path):
      "The selected PDF could not be found: \(path)"
    case .inputTooLarge(let byteCount):
      "The PDF is too large for the current safety limit (\(byteCount) bytes)."
    case .cannotOpen(let path):
      "The PDF could not be opened safely: \(path)"
    case .passwordRequired(let path):
      "The PDF is password-protected: \(path). Enter a password to continue."
    case .passwordIncorrect(let path):
      "The provided password for \(path) was incorrect."
    case .invalidPage(let index):
      "The edit targets an unavailable page (\(index + 1))."
    case .invalidOperation(let message):
      message
    case .exportFailed(let message):
      message
    }
  }
}

public protocol PDFProvider {
  func inspect(url: URL, password: String?) throws -> DocumentInspection
  func export(url: URL, operations: [EditOperation], to outputURL: URL) throws -> ExportResult
}

extension PDFProvider {
  public func inspect(url: URL) throws -> DocumentInspection {
    try inspect(url: url, password: nil)
  }
}
