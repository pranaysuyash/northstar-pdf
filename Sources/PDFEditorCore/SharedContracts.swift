import Foundation

/// Version negotiated by native and web adapters before decoding a payload.
///
/// The first contract intentionally uses a conservative compatibility rule:
/// the reader accepts the same major version and only a minor version it knows.
/// This prevents an unknown enum value or a changed safety invariant from being
/// mistaken for a harmless additive field.
public struct PDFContractVersion: Codable, Equatable, Hashable, Sendable {
  public let major: Int
  public let minor: Int

  public init(major: Int, minor: Int) {
    self.major = major
    self.minor = minor
  }

  public static let current = PDFContractVersion(major: 1, minor: 0)

  public func isReadableBy(_ supported: PDFContractVersion = .current) -> Bool {
    major == supported.major && minor <= supported.minor
  }
}

public struct PDFProviderDescriptor: Codable, Equatable, Hashable, Sendable {
  public let id: String
  public let version: String
  public let platform: String
  public let capabilities: [String]

  public init(
    id: String,
    version: String,
    platform: String,
    capabilities: [String] = []
  ) {
    self.id = id
    self.version = version
    self.platform = platform
    self.capabilities = capabilities
  }
}

public struct PDFContractHeader: Codable, Equatable, Hashable, Sendable {
  public let contractName: String
  public let version: PDFContractVersion
  public let sourceDigest: String
  public let generatedAt: Date
  public let provider: PDFProviderDescriptor

  public init(
    contractName: String,
    version: PDFContractVersion = .current,
    sourceDigest: String,
    generatedAt: Date = Date(),
    provider: PDFProviderDescriptor
  ) {
    self.contractName = contractName
    self.version = version
    self.sourceDigest = sourceDigest
    self.generatedAt = generatedAt
    self.provider = provider
  }
}

/// A stable JSON envelope shared by native and web adapters.
public struct PDFContractEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
  public let header: PDFContractHeader
  public let payload: Payload

  public init(header: PDFContractHeader, payload: Payload) {
    self.header = header
    self.payload = payload
  }

  public func isReadableBy(_ supported: PDFContractVersion = .current) -> Bool {
    header.version.isReadableBy(supported)
  }
}

public typealias PDFDocumentContract = PDFContractEnvelope<DocumentInspection>
public typealias PDFValidationContract = PDFContractEnvelope<ValidationReport>

public enum PDFCoordinateUnit: String, Codable, CaseIterable, Hashable, Sendable {
  case points
}

public enum PDFCoordinateOrigin: String, Codable, CaseIterable, Hashable, Sendable {
  case lowerLeft
  case upperLeft
}

public enum PDFPageBox: String, Codable, CaseIterable, Hashable, Sendable {
  case media
  case crop
  case bleed
  case trim
  case art
}

/// Describes the coordinate convention for a page-space rectangle.
public struct PDFCoordinateSpace: Codable, Equatable, Hashable, Sendable {
  public let unit: PDFCoordinateUnit
  public let origin: PDFCoordinateOrigin
  public let pageBox: PDFPageBox
  public let rotationDegrees: Int

  public init(
    unit: PDFCoordinateUnit = .points,
    origin: PDFCoordinateOrigin = .lowerLeft,
    pageBox: PDFPageBox = .crop,
    rotationDegrees: Int = 0
  ) {
    self.unit = unit
    self.origin = origin
    self.pageBox = pageBox
    self.rotationDegrees = rotationDegrees
  }

  public static let pageUserSpace = PDFCoordinateSpace()
}

public struct PDFPageRegion: Codable, Equatable, Hashable, Sendable {
  public let pageIndex: Int
  public let rect: PDFRect
  public let coordinateSpace: PDFCoordinateSpace

  public init(
    pageIndex: Int,
    rect: PDFRect,
    coordinateSpace: PDFCoordinateSpace = .pageUserSpace
  ) {
    self.pageIndex = pageIndex
    self.rect = rect
    self.coordinateSpace = coordinateSpace
  }
}

public enum CandidateEvidenceKind: String, Codable, CaseIterable, Hashable, Sendable {
  case nativeField
  case textLabel
  case underline
  case vectorLine
  case vectorRectangle
  case whitespace
  case ocrText
  case spatialRelationship
  case repeatedPattern
  case manual
}

public enum CandidateEvidenceOrigin: String, Codable, CaseIterable, Hashable, Sendable {
  case provider
  case textExtraction
  case geometryExtraction
  case ocr
  case user
}

public struct CandidateEvidence: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let kind: CandidateEvidenceKind
  public let origin: CandidateEvidenceOrigin
  public let summary: String
  public let region: PDFPageRegion?
  public let text: String?
  public let score: Double?
  public let provider: PDFProviderDescriptor?

  public init(
    id: UUID = UUID(),
    kind: CandidateEvidenceKind,
    origin: CandidateEvidenceOrigin,
    summary: String,
    region: PDFPageRegion? = nil,
    text: String? = nil,
    score: Double? = nil,
    provider: PDFProviderDescriptor? = nil
  ) {
    self.id = id
    self.kind = kind
    self.origin = origin
    self.summary = summary
    self.region = region
    self.text = text
    self.score = score
    self.provider = provider
  }
}

public enum SuggestedFieldType: String, Codable, CaseIterable, Hashable, Sendable {
  case text
  case date
  case number
  case checkbox
  case radio
  case choice
  case signature
  case unknown
}

/// Describes how a reviewed region should be interacted with, independently
/// from the semantic type inferred from its label.
public enum CandidateEntryMode: String, Codable, CaseIterable, Hashable, Sendable {
  case singleText
  case characterGrid
  case checkbox
  case radioGroup
  case signature
  case unknown
}

public enum CandidateReviewDecisionKind: String, Codable, CaseIterable, Hashable, Sendable {
  case confirmed
  case rejected
  case moved
  case resized
  case retyped
  case manuallyCreated
}

public struct CandidateReviewDecision: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let candidateID: UUID
  public let kind: CandidateReviewDecisionKind
  public let region: PDFPageRegion?
  public let fieldType: SuggestedFieldType?
  public let note: String?
  public let createdAt: Date

  public init(
    id: UUID = UUID(),
    candidateID: UUID,
    kind: CandidateReviewDecisionKind,
    region: PDFPageRegion? = nil,
    fieldType: SuggestedFieldType? = nil,
    note: String? = nil,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.candidateID = candidateID
    self.kind = kind
    self.region = region
    self.fieldType = fieldType
    self.note = note
    self.createdAt = createdAt
  }
}

public enum EditPayload: Codable, Equatable, Hashable, Sendable {
  case text(String)
  case characterGrid(text: String, cells: [PDFRect])
  /// Source-bound evidence for a semantic text-run rewrite. The replacement
  /// value stays in EditOperation.value and is never copied to recovery-safe
  /// session metadata.
  case textRunReplacement(originalTextHash: String, runID: String, fontFingerprint: String?)
  case boolean(Bool)
  case choice(String)
  /// A reviewed static choice mark. This is visual evidence, not an AcroForm widget.
  case choiceMark(cell: PDFRect)
  /// Describes an explicitly synthesized widget created from a reviewed static region.
  case nativeField(fieldType: SuggestedFieldType)
  case asset(assetID: String, mimeType: String)
  case stamp(name: String)
  case empty

  private enum CodingKeys: String, CodingKey {
    case kind
    case text
    case characterGrid
    case textRunReplacement
    case textHash
    case runID
    case fontFingerprint
    case boolean
    case choice
    case assetID
    case mimeType
    case name
    case cells
  }

  private enum Kind: String, Codable {
    case text
    case characterGrid
    case textRunReplacement
    case boolean
    case choice
    case choiceMark
    case nativeField
    case asset
    case stamp
    case empty
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .text(let value):
      try container.encode(Kind.text, forKey: .kind)
      try container.encode(value, forKey: .text)
    case .characterGrid(let text, let cells):
      try container.encode(Kind.characterGrid, forKey: .kind)
      try container.encode(text, forKey: .text)
      try container.encode(cells, forKey: .cells)
    case .textRunReplacement(let originalTextHash, let runID, let fontFingerprint):
      try container.encode(Kind.textRunReplacement, forKey: .kind)
      try container.encode(originalTextHash, forKey: .textHash)
      try container.encode(runID, forKey: .runID)
      try container.encodeIfPresent(fontFingerprint, forKey: .fontFingerprint)
    case .boolean(let value):
      try container.encode(Kind.boolean, forKey: .kind)
      try container.encode(value, forKey: .boolean)
    case .choice(let value):
      try container.encode(Kind.choice, forKey: .kind)
      try container.encode(value, forKey: .choice)
    case .choiceMark(let cell):
      try container.encode(Kind.choiceMark, forKey: .kind)
      try container.encode(cell, forKey: .cells)
    case .nativeField(let fieldType):
      try container.encode(Kind.nativeField, forKey: .kind)
      try container.encode(fieldType, forKey: .choice)
    case .asset(let assetID, let mimeType):
      try container.encode(Kind.asset, forKey: .kind)
      try container.encode(assetID, forKey: .assetID)
      try container.encode(mimeType, forKey: .mimeType)
    case .stamp(let name):
      try container.encode(Kind.stamp, forKey: .kind)
      try container.encode(name, forKey: .name)
    case .empty:
      try container.encode(Kind.empty, forKey: .kind)
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(Kind.self, forKey: .kind)
    switch kind {
    case .text:
      self = .text(try container.decode(String.self, forKey: .text))
    case .characterGrid:
      self = .characterGrid(
        text: try container.decode(String.self, forKey: .text),
        cells: try container.decode([PDFRect].self, forKey: .cells)
      )
    case .textRunReplacement:
      self = .textRunReplacement(
        originalTextHash: try container.decode(String.self, forKey: .textHash),
        runID: try container.decode(String.self, forKey: .runID),
        fontFingerprint: try container.decodeIfPresent(String.self, forKey: .fontFingerprint)
      )
    case .boolean:
      self = .boolean(try container.decode(Bool.self, forKey: .boolean))
    case .choice:
      self = .choice(try container.decode(String.self, forKey: .choice))
    case .choiceMark:
      self = .choiceMark(cell: try container.decode(PDFRect.self, forKey: .cells))
    case .nativeField:
      self = .nativeField(fieldType: try container.decode(SuggestedFieldType.self, forKey: .choice))
    case .asset:
      self = .asset(
        assetID: try container.decode(String.self, forKey: .assetID),
        mimeType: try container.decode(String.self, forKey: .mimeType)
      )
    case .stamp:
      self = .stamp(name: try container.decode(String.self, forKey: .name))
    case .empty:
      self = .empty
    }
  }
}

public enum ValidationCheckKind: String, Codable, CaseIterable, Hashable, Sendable {
  case sourceDigest
  case outputReopen
  case pageGeometry
  case nativeFields
  case appliedOperations
  case outsideRegionText
  case visualDiff
  case independentViewer
  case security
  case accessibility
  case providerCapability
}

public enum ValidationCheckStatus: String, Codable, CaseIterable, Hashable, Sendable {
  case passed
  case warning
  case failed
  case skipped
  case unknown
}

public struct ValidationCheck: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let kind: ValidationCheckKind
  public let status: ValidationCheckStatus
  public let message: String
  public let region: PDFPageRegion?
  public let operationIDs: [UUID]

  public init(
    id: UUID = UUID(),
    kind: ValidationCheckKind,
    status: ValidationCheckStatus,
    message: String,
    region: PDFPageRegion? = nil,
    operationIDs: [UUID] = []
  ) {
    self.id = id
    self.kind = kind
    self.status = status
    self.message = message
    self.region = region
    self.operationIDs = operationIDs
  }
}

public struct PDFEditSessionContract: Codable, Equatable, Sendable {
  public let header: PDFContractHeader
  public let source: DocumentSource
  public let reviews: [CandidateReviewDecision]
  public let operations: [EditOperation]

  public init(
    source: DocumentSource,
    provider: PDFProviderDescriptor,
    reviews: [CandidateReviewDecision] = [],
    operations: [EditOperation] = [],
    generatedAt: Date = Date(),
    version: PDFContractVersion = .current
  ) {
    self.header = PDFContractHeader(
      contractName: "pdf-editor.edit-session",
      version: version,
      sourceDigest: source.sha256,
      generatedAt: generatedAt,
      provider: provider
    )
    self.source = source
    self.reviews = reviews
    self.operations = operations
  }
}
