import Foundation

/// Named long-term PDF capability lanes. A lane is an intent boundary, not a
/// claim that every installed provider can perform it.
public enum PDFCapabilityLane: String, Codable, CaseIterable, Hashable, Sendable {
  case nativeChoice = "native.choice"
  case nativeCheckbox = "native.checkbox"
  case visualSignature = "signature.visual"
  case cryptographicSignature = "signature.cryptographic"
  case ocrTextBounds = "ocr.textBounds"
  case ocrSearchLayer = "ocr.searchLayer"
  case textRunReplacement = "text.runReplacement"
  case textReflow = "text.reflow"
  case permanentRedaction = "redaction.permanent"
  case xfaForms = "xfa.forms"
  case pdfUAConformance = "pdfua.conformance"
  case independentViewerReopen = "independentViewer.reopen"
}

public enum PDFCapabilityOutcome: String, Codable, CaseIterable, Hashable, Sendable {
  case available
  case partial
  case unsupported
  case unknown
  case revoked
  case needsReview
}

public struct PDFCapabilityRequest: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.pdf-capability-request"
  public let contract: String
  public let version: PDFContractVersion
  public let lane: PDFCapabilityLane
  public let sourceDigest: String
  public let operationKinds: [String]
  public let source: ProviderSourceFacts
  public let policy: ProviderCapabilityPolicy

  public init(
    lane: PDFCapabilityLane,
    sourceDigest: String,
    operationKinds: [String],
    source: ProviderSourceFacts,
    policy: ProviderCapabilityPolicy,
    version: PDFContractVersion = .current,
    contract: String = PDFCapabilityRequest.contractName
  ) {
    self.contract = contract
    self.version = version
    self.lane = lane
    self.sourceDigest = sourceDigest
    self.operationKinds = operationKinds
    self.source = source
    self.policy = policy
  }

  public func validate() throws {
    guard contract == Self.contractName, version.isReadableBy(), !sourceDigest.isEmpty else {
      throw ProviderCapabilityError.invalid("PDF capability request identity is invalid")
    }
  }
}

public struct PDFCapabilityOutcomeRecord: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.pdf-capability-outcome"
  public let contract: String
  public let version: PDFContractVersion
  public let lane: PDFCapabilityLane
  public let sourceDigest: String
  public let outcome: PDFCapabilityOutcome
  public let providerID: String?
  public let measurementID: String?
  public let reasonCodes: [String]
  public let requiresReview: Bool

  public init(
    lane: PDFCapabilityLane,
    sourceDigest: String,
    outcome: PDFCapabilityOutcome,
    providerID: String? = nil,
    measurementID: String? = nil,
    reasonCodes: [String] = [],
    requiresReview: Bool = true,
    version: PDFContractVersion = .current,
    contract: String = PDFCapabilityOutcomeRecord.contractName
  ) {
    self.contract = contract
    self.version = version
    self.lane = lane
    self.sourceDigest = sourceDigest
    self.outcome = outcome
    self.providerID = providerID
    self.measurementID = measurementID
    self.reasonCodes = reasonCodes
    self.requiresReview = requiresReview
  }

  public func validate() throws {
    guard contract == Self.contractName, version.isReadableBy(), !sourceDigest.isEmpty else {
      throw ProviderCapabilityError.invalid("PDF capability outcome identity is invalid")
    }
    if outcome == .available && requiresReview {
      throw ProviderCapabilityError.invalid("available capability outcome cannot require review")
    }
  }
}

public enum PDFCapabilityLaneAdmission {
  public static func resolve(
    registry: ProviderCapabilityRegistry,
    request: PDFCapabilityRequest
  ) throws -> PDFCapabilityOutcomeRecord {
    try request.validate()
    let providerRequest = ProviderCapabilityRequest(
      capability: request.lane.rawValue,
      operationKinds: request.operationKinds,
      source: request.source,
      policy: request.policy)
    let decision = try ProviderCapabilityNegotiator.negotiate(registry: registry, request: providerRequest)
    let outcome: PDFCapabilityOutcome = decision.decision == .selected ? .available :
      (decision.reasonCodes.contains("providerRevoked") ? .revoked : .unknown)
    return PDFCapabilityOutcomeRecord(
      lane: request.lane,
      sourceDigest: request.sourceDigest,
      outcome: outcome,
      providerID: decision.providerID,
      measurementID: decision.measurementID,
      reasonCodes: decision.reasonCodes,
      requiresReview: outcome != .available)
  }
}
