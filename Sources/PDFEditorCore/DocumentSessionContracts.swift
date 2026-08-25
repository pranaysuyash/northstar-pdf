import Foundation

// MARK: - Session schema

/// The version of the persisted session envelope, independent of the PDF
/// contract and independent of any inspection provider.
public struct DocumentSessionSchemaVersion: Codable, Equatable, Hashable, Sendable {
  public let major: Int
  public let minor: Int

  public init(major: Int, minor: Int) {
    self.major = major
    self.minor = minor
  }

  public static let current = DocumentSessionSchemaVersion(major: 1, minor: 0)

  public func isReadableBy(
    _ supported: DocumentSessionSchemaVersion = .current
  ) -> Bool {
    major == supported.major && minor <= supported.minor
  }
}

// MARK: - Immutable source and derived inspection

/// The identity of the immutable source artifact used by a session.
///
/// This is deliberately a reference, not the source bytes. A recovery
/// envelope can therefore prove which source it belongs to without copying
/// the PDF, embedding a file URL, or persisting document content.
public struct DocumentSessionSourceArtifact: Codable, Equatable, Hashable, Sendable {
  public let artifactID: UUID
  public let source: DocumentSource

  public init(
    artifactID: UUID = UUID(),
    source: DocumentSource
  ) {
    self.artifactID = artifactID
    self.source = source
  }

  public var sourceDigest: String { source.sha256 }
}

/// A compact identity for derived inspection data. Full pages, fields,
/// candidates, labels, OCR text, and provider output remain outside the
/// recovery envelope and can be regenerated from the source artifact.
public struct DocumentSessionInspectionReference: Codable, Equatable, Hashable, Sendable {
  public let inspectionID: UUID
  public let sourceDigest: String
  public let inspectionRevision: String
  public let pageCount: Int
  public let nativeFieldCount: Int
  public let candidateCount: Int
  public let derivedAt: Date

  public init(
    inspectionID: UUID = UUID(),
    sourceDigest: String,
    inspectionRevision: String = "inspection-v1",
    pageCount: Int,
    nativeFieldCount: Int,
    candidateCount: Int,
    derivedAt: Date = Date()
  ) {
    self.inspectionID = inspectionID
    self.sourceDigest = sourceDigest
    self.inspectionRevision = inspectionRevision
    self.pageCount = max(0, pageCount)
    self.nativeFieldCount = max(0, nativeFieldCount)
    self.candidateCount = max(0, candidateCount)
    self.derivedAt = derivedAt
  }
}

// MARK: - Operation ledger metadata

/// The shape of an operation payload, without the payload itself.
///
/// The corresponding value is intentionally absent. If a caller needs to
/// resume a value-bearing edit, it must resolve the opaque payload reference
/// from a separately governed store with its own privacy and retention rules.
public enum DocumentSessionOperationPayloadKind: String, Codable, CaseIterable, Hashable, Sendable {
  case none
  case text
  case characterGrid
  case textRunReplacement
  case boolean
  case choice
  case choiceMark
  case nativeField
  case asset
  case stamp
}

/// A privacy-safe, typed summary of one operation in the document ledger.
///
/// This type intentionally has no `value`, `previousValue`, or `EditPayload`
/// property. `targetID` is represented by an opaque digest so field names or
/// other source-derived identifiers cannot leak into recovery files.
public struct DocumentSessionOperationMetadata: Codable, Equatable, Hashable, Identifiable, Sendable {
  public let id: UUID
  public let sourceDigest: String
  public let pageIndex: Int
  public let targetIDDigest: String?
  public let kind: EditKind
  public let payloadKind: DocumentSessionOperationPayloadKind
  public let bounds: PDFRect?
  public let candidateID: UUID?
  public let coordinate: PDFPageRegion?
  public let createdAt: Date
  public let parentOperationID: UUID?
  public let payloadReferenceID: UUID?
  public let reversible: Bool
  public let destructive: Bool

  public init(
    id: UUID = UUID(),
    sourceDigest: String,
    pageIndex: Int,
    targetIDDigest: String? = nil,
    kind: EditKind,
    payloadKind: DocumentSessionOperationPayloadKind = .none,
    bounds: PDFRect? = nil,
    candidateID: UUID? = nil,
    coordinate: PDFPageRegion? = nil,
    createdAt: Date = Date(),
    parentOperationID: UUID? = nil,
    payloadReferenceID: UUID? = nil,
    reversible: Bool = true,
    destructive: Bool = false
  ) {
    self.id = id
    self.sourceDigest = sourceDigest
    self.pageIndex = pageIndex
    self.targetIDDigest = targetIDDigest
    self.kind = kind
    self.payloadKind = payloadKind
    self.bounds = bounds
    self.candidateID = candidateID
    self.coordinate = coordinate
    self.createdAt = createdAt
    self.parentOperationID = parentOperationID
    self.payloadReferenceID = payloadReferenceID
    self.reversible = reversible
    self.destructive = destructive
  }

  /// Projects an edit into the recovery-safe ledger shape. The edit value,
  /// previous value, and raw target identifier are intentionally not copied.
  public init(
    operation: EditOperation,
    sourceDigest: String,
    targetIDDigest: String? = nil,
    payloadReferenceID: UUID? = nil
  ) {
    self.init(
      id: operation.id,
      sourceDigest: sourceDigest,
      pageIndex: operation.pageIndex,
      targetIDDigest: targetIDDigest,
      kind: operation.kind,
      payloadKind: Self.payloadKind(for: operation.payload),
      bounds: operation.bounds,
      candidateID: operation.candidateID,
      coordinate: operation.coordinate,
      createdAt: operation.createdAt,
      parentOperationID: operation.parentOperationID,
      payloadReferenceID: payloadReferenceID,
      reversible: operation.reversible,
      destructive: operation.destructive
    )
  }

  private static func payloadKind(
    for payload: EditPayload?
  ) -> DocumentSessionOperationPayloadKind {
    switch payload {
    case nil:
      return .none
    case .some(.empty):
      return .none
    case .some(.text(_)):
      return .text
    case .some(.characterGrid(_, _)):
      return .characterGrid
    case .some(.textRunReplacement(_, _, _)):
      return .textRunReplacement
    case .some(.boolean(_)):
      return .boolean
    case .some(.choice(_)):
      return .choice
    case .some(.choiceMark(_)):
      return .choiceMark
    case .some(.nativeField(_)):
      return .nativeField
    case .some(.asset(_, _)):
      return .asset
    case .some(.stamp(_)):
      return .stamp
    }
  }
}

// MARK: - View session metadata

/// View state is recoverable session context, not document content. Search
/// text is not persisted; only a digest and selection index may be supplied
/// by a caller that explicitly wants search restoration.
public struct DocumentSessionViewState: Codable, Equatable, Hashable, Sendable {
  public let selectedPageIndex: Int
  public let viewMode: ReaderViewMode
  public let scaleMode: ReaderScaleMode
  public let zoomScale: Double?
  public let pageRotation: Int
  public let selectedCandidateID: UUID?
  public let selectedFieldIDDigest: String?
  public let searchQueryDigest: String?
  public let selectedSearchMatchIndex: Int?

  public init(
    selectedPageIndex: Int = 0,
    viewMode: ReaderViewMode = .singlePage,
    scaleMode: ReaderScaleMode = .fitPage,
    zoomScale: Double? = nil,
    pageRotation: Int = 0,
    selectedCandidateID: UUID? = nil,
    selectedFieldIDDigest: String? = nil,
    searchQueryDigest: String? = nil,
    selectedSearchMatchIndex: Int? = nil
  ) {
    self.selectedPageIndex = max(0, selectedPageIndex)
    self.viewMode = viewMode
    self.scaleMode = scaleMode
    self.zoomScale = zoomScale
    self.pageRotation = ((pageRotation % 360) + 360) % 360
    self.selectedCandidateID = selectedCandidateID
    self.selectedFieldIDDigest = selectedFieldIDDigest
    self.searchQueryDigest = searchQueryDigest
    self.selectedSearchMatchIndex = selectedSearchMatchIndex.map { max(0, $0) }
  }
}

// MARK: - Recovery metadata and session model

public enum DocumentSessionRecoveryState: String, Codable, CaseIterable, Hashable, Sendable {
  case pending
  case restored
  case discarded
}

public enum DocumentSessionRecoveryReason: String, Codable, CaseIterable, Hashable, Sendable {
  case autosave
  case applicationTermination
  case unexpectedTermination
  case manualResumePoint
}

/// Lifecycle metadata for the recovery record. It contains no process state,
/// credentials, profile values, template values, or source content.
public struct DocumentSessionRecoveryMetadata: Codable, Equatable, Hashable, Sendable {
  public let state: DocumentSessionRecoveryState
  public let reason: DocumentSessionRecoveryReason
  public let createdAt: Date
  public let updatedAt: Date
  public let autosaveSequence: Int
  public let hasUnexportedChanges: Bool

  public init(
    state: DocumentSessionRecoveryState = .pending,
    reason: DocumentSessionRecoveryReason = .autosave,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    autosaveSequence: Int = 0,
    hasUnexportedChanges: Bool = true
  ) {
    self.state = state
    self.reason = reason
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.autosaveSequence = max(0, autosaveSequence)
    self.hasUnexportedChanges = hasUnexportedChanges
  }
}

/// Provider-neutral in-memory session model. The recovery store persists this
/// model as an envelope, but never persists the source bytes or edit values.
public struct DocumentSession: Codable, Equatable, Hashable, Sendable, Identifiable {
  public let sessionID: UUID
  public let sourceArtifact: DocumentSessionSourceArtifact
  public let inspectionReference: DocumentSessionInspectionReference?
  /// Value-minimized processing and export provenance for this session.
  /// Optional keeps older recovery envelopes readable; new adapters should
  /// populate it whenever a PDF session is created or autosaved.
  public let privacyProvenance: PDFSessionPrivacyProvenance?
  public let operationLedger: [DocumentSessionOperationMetadata]
  public let viewState: DocumentSessionViewState
  public let recovery: DocumentSessionRecoveryMetadata

  public init(
    sessionID: UUID = UUID(),
    sourceArtifact: DocumentSessionSourceArtifact,
    inspectionReference: DocumentSessionInspectionReference? = nil,
    privacyProvenance: PDFSessionPrivacyProvenance? = nil,
    operationLedger: [DocumentSessionOperationMetadata] = [],
    viewState: DocumentSessionViewState = DocumentSessionViewState(),
    recovery: DocumentSessionRecoveryMetadata = DocumentSessionRecoveryMetadata()
  ) {
    self.sessionID = sessionID
    self.sourceArtifact = sourceArtifact
    self.inspectionReference = inspectionReference
    self.privacyProvenance = privacyProvenance
    self.operationLedger = operationLedger
    self.viewState = viewState
    self.recovery = recovery
  }

  public var sourceDigest: String { sourceArtifact.sourceDigest }

  /// SwiftUI/List identity projection; `sessionID` remains the persisted source of truth.
  public var id: UUID { sessionID }

  public var operationIDs: [UUID] {
    operationLedger.map(\.id)
  }
}

/// The durable interchange envelope. The contract name makes accidental
/// decoding as a different JSON record less likely, while the schema version
/// gives future readers a deliberate migration point.
public struct DocumentSessionRecoveryEnvelope: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.document-session-recovery"

  public let contract: String
  public let schemaVersion: DocumentSessionSchemaVersion
  public let sourceDigest: String
  public let encodedAt: Date
  public let session: DocumentSession

  public init(
    session: DocumentSession,
    schemaVersion: DocumentSessionSchemaVersion = .current,
    encodedAt: Date = Date()
  ) {
    self.contract = Self.contractName
    self.schemaVersion = schemaVersion
    self.sourceDigest = session.sourceDigest
    self.encodedAt = encodedAt
    self.session = session
  }

  private enum CodingKeys: String, CodingKey {
    case contract
    case schemaVersion
    case sourceDigest
    case encodedAt
    case session
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.contract = try container.decode(String.self, forKey: .contract)
    self.schemaVersion = try container.decode(
      DocumentSessionSchemaVersion.self,
      forKey: .schemaVersion
    )
    self.encodedAt = try container.decode(Date.self, forKey: .encodedAt)
    self.session = try container.decode(DocumentSession.self, forKey: .session)
    // Keep records written before the envelope-level digest was introduced
    // readable without weakening the store's consistency checks.
    self.sourceDigest = try container.decodeIfPresent(
      String.self,
      forKey: .sourceDigest
    ) ?? session.sourceDigest
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(contract, forKey: .contract)
    try container.encode(schemaVersion, forKey: .schemaVersion)
    try container.encode(sourceDigest, forKey: .sourceDigest)
    try container.encode(encodedAt, forKey: .encodedAt)
    try container.encode(session, forKey: .session)
  }

  public var isReadableByCurrentSchema: Bool {
    contract == Self.contractName && schemaVersion.isReadableBy()
  }

  public func isReadableBy(
    _ supported: DocumentSessionSchemaVersion = .current
  ) -> Bool {
    contract == Self.contractName && schemaVersion.isReadableBy(supported)
  }
}
