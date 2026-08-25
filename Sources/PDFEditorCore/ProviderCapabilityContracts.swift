import Foundation

/// Admission state for an installed local provider. This contract is separate
/// from PDFContractVersion because provider installation and capability evidence
/// must evolve without changing document or edit-session payloads.
public enum ProviderInstallState: String, Codable, CaseIterable, Hashable, Sendable {
  case discovered
  case installing
  case installed
  case probing
  case measured
  case enabled
  case revoked
  case quarantined
  case removed
}

public enum ProviderCapabilityState: String, Codable, CaseIterable, Hashable, Sendable {
  case declared
  case unavailable
  case installedUnmeasured
  case measuredPartial
  case enabled
  case revoked
  case quarantined
  case expired
}

public enum ProviderLicenseState: String, Codable, CaseIterable, Hashable, Sendable {
  case approved
  case reviewRequired
  case rejected
}

public enum ProviderMeasurementStatus: String, Codable, CaseIterable, Hashable, Sendable {
  case passed
  case partial
  case failed
}

public enum ProviderEvidenceTier: String, Codable, CaseIterable, Hashable, Sendable {
  case T1
  case T2
  case T3
  case T4
  case T5
}

public enum ProviderEvidenceSensitivity: String, Codable, CaseIterable, Hashable, Sendable {
  case S0
  case S1
  case S2
  case S3
}

public struct ProviderLicenseRecord: Codable, Equatable, Hashable, Sendable {
  public let name: String
  public let status: ProviderLicenseState

  public init(name: String, status: ProviderLicenseState) {
    self.name = name
    self.status = status
  }
}

public struct ProviderCapabilityLimits: Codable, Equatable, Hashable, Sendable {
  public let maxBytes: Int
  public let maxPages: Int
  public let supportsEncrypted: Bool
  public let supportsScanned: Bool

  public init(
    maxBytes: Int,
    maxPages: Int,
    supportsEncrypted: Bool,
    supportsScanned: Bool
  ) {
    self.maxBytes = maxBytes
    self.maxPages = maxPages
    self.supportsEncrypted = supportsEncrypted
    self.supportsScanned = supportsScanned
  }
}

public struct ProviderCapabilityMeasurement: Codable, Equatable, Hashable, Sendable {
  public let measurementID: String
  public let capabilityID: String
  public let artifactDigest: String
  public let corpusDigest: String
  public let reportDigest: String
  public let status: ProviderMeasurementStatus
  public let evidenceTier: ProviderEvidenceTier
  public let sensitivity: ProviderEvidenceSensitivity
  public let gates: [String]

  public init(
    measurementID: String,
    capabilityID: String,
    artifactDigest: String,
    corpusDigest: String,
    reportDigest: String,
    status: ProviderMeasurementStatus,
    evidenceTier: ProviderEvidenceTier,
    sensitivity: ProviderEvidenceSensitivity,
    gates: [String]
  ) {
    self.measurementID = measurementID
    self.capabilityID = capabilityID
    self.artifactDigest = artifactDigest
    self.corpusDigest = corpusDigest
    self.reportDigest = reportDigest
    self.status = status
    self.evidenceTier = evidenceTier
    self.sensitivity = sensitivity
    self.gates = gates
  }
}

public struct ProviderCapabilityRecord: Codable, Equatable, Hashable, Sendable {
  public let capabilityID: String
  public let state: ProviderCapabilityState
  public let limits: ProviderCapabilityLimits
  public let measurementIDs: [String]

  public init(
    capabilityID: String,
    state: ProviderCapabilityState,
    limits: ProviderCapabilityLimits,
    measurementIDs: [String]
  ) {
    self.capabilityID = capabilityID
    self.state = state
    self.limits = limits
    self.measurementIDs = measurementIDs
  }
}

public struct ProviderRevocationRecord: Codable, Equatable, Hashable, Sendable {
  public let revocationID: String
  public let reasonCode: String
  public let effectiveAt: Date

  public init(revocationID: String, reasonCode: String, effectiveAt: Date) {
    self.revocationID = revocationID
    self.reasonCode = reasonCode
    self.effectiveAt = effectiveAt
  }
}

public struct ProviderCapabilityManifest: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.provider-capability"

  public let contract: String
  public let version: PDFContractVersion
  public let providerID: String
  public let engineFamily: String
  public let providerVersion: String
  public let runtimeKind: String
  public let artifactDigest: String
  public let installState: ProviderInstallState
  public let license: ProviderLicenseRecord
  public let capabilities: [ProviderCapabilityRecord]
  public let measurements: [ProviderCapabilityMeasurement]
  public let revocations: [ProviderRevocationRecord]

  public init(
    providerID: String,
    engineFamily: String,
    providerVersion: String,
    runtimeKind: String,
    artifactDigest: String,
    installState: ProviderInstallState,
    license: ProviderLicenseRecord,
    capabilities: [ProviderCapabilityRecord],
    measurements: [ProviderCapabilityMeasurement],
    revocations: [ProviderRevocationRecord] = [],
    version: PDFContractVersion = PDFContractVersion(major: 1, minor: 0),
    contract: String = ProviderCapabilityManifest.contractName
  ) {
    self.contract = contract
    self.version = version
    self.providerID = providerID
    self.engineFamily = engineFamily
    self.providerVersion = providerVersion
    self.runtimeKind = runtimeKind
    self.artifactDigest = artifactDigest
    self.installState = installState
    self.license = license
    self.capabilities = capabilities
    self.measurements = measurements
    self.revocations = revocations
  }

  public func validate() throws {
    guard contract == Self.contractName, version.major == 1 else {
      throw ProviderCapabilityError.invalid("unsupported provider capability contract")
    }
    guard !providerID.isEmpty, !engineFamily.isEmpty, !providerVersion.isEmpty,
      !runtimeKind.isEmpty, Self.isDigest(artifactDigest)
    else {
      throw ProviderCapabilityError.invalid("provider identity or artifact digest is invalid")
    }
    guard !license.name.isEmpty else {
      throw ProviderCapabilityError.invalid("provider license name is empty")
    }
    var measurementByID = [String: ProviderCapabilityMeasurement]()
    for measurement in measurements {
      guard measurementByID[measurement.measurementID] == nil else {
        throw ProviderCapabilityError.invalid("duplicate measurement ID")
      }
      measurementByID[measurement.measurementID] = measurement
    }
    var capabilityIDs = Set<String>()
    for capability in capabilities {
      guard capabilityIDs.insert(capability.capabilityID).inserted else {
        throw ProviderCapabilityError.invalid("duplicate capability ID")
      }
      guard !capability.capabilityID.isEmpty,
        capability.limits.maxBytes >= 0,
        capability.limits.maxPages >= 0
      else {
        throw ProviderCapabilityError.invalid("provider capability limits or ID is invalid")
      }
      if capability.state == .enabled && capability.measurementIDs.isEmpty {
        throw ProviderCapabilityError.invalid("enabled capability requires a measurement reference")
      }
      for measurementID in capability.measurementIDs {
        guard let measurement = measurementByID[measurementID],
          measurement.capabilityID == capability.capabilityID,
          measurement.artifactDigest == artifactDigest
        else {
          throw ProviderCapabilityError.invalid("measurement binding is not source-artifact bound")
        }
      }
    }
  }

  private static func isDigest(_ value: String) -> Bool {
    value.count == 64 && value.allSatisfy { $0.isNumber || "abcdefABCDEF".contains($0) }
  }
}

public struct ProviderCapabilityRegistry: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.provider-capability-registry"

  public let contract: String
  public let version: PDFContractVersion
  public let registryID: String
  public let providers: [ProviderCapabilityManifest]

  public init(
    registryID: String,
    providers: [ProviderCapabilityManifest],
    version: PDFContractVersion = PDFContractVersion(major: 1, minor: 0),
    contract: String = ProviderCapabilityRegistry.contractName
  ) {
    self.contract = contract
    self.version = version
    self.registryID = registryID
    self.providers = providers
  }

  public func validate() throws {
    guard contract == Self.contractName, version.major == 1, !registryID.isEmpty else {
      throw ProviderCapabilityError.invalid("provider registry contract is invalid")
    }
    var IDs = Set<String>()
    for provider in providers {
      try provider.validate()
      guard IDs.insert(provider.providerID).inserted else {
        throw ProviderCapabilityError.invalid("duplicate provider ID")
      }
    }
  }
}

public struct ProviderSourceFacts: Codable, Equatable, Hashable, Sendable {
  public let byteCount: Int
  public let pageCount: Int
  public let isEncrypted: Bool
  public let isScanned: Bool

  public init(byteCount: Int, pageCount: Int, isEncrypted: Bool, isScanned: Bool) {
    self.byteCount = byteCount
    self.pageCount = pageCount
    self.isEncrypted = isEncrypted
    self.isScanned = isScanned
  }
}

public enum ProviderMinimumState: String, Codable, Hashable, Sendable {
  case enabled
  case measuredPartial
  case installedUnmeasured
}

public struct ProviderCapabilityPolicy: Codable, Equatable, Hashable, Sendable {
  public let localOnly: Bool
  public let minimumState: ProviderMinimumState
  public let allowExperimental: Bool
  public let preferredProviderIDs: [String]

  public init(
    localOnly: Bool,
    minimumState: ProviderMinimumState,
    allowExperimental: Bool,
    preferredProviderIDs: [String] = []
  ) {
    self.localOnly = localOnly
    self.minimumState = minimumState
    self.allowExperimental = allowExperimental
    self.preferredProviderIDs = preferredProviderIDs
  }
}

public struct ProviderCapabilityRequest: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.provider-capability-request"

  public let contract: String
  public let version: PDFContractVersion
  public let capability: String
  public let operationKinds: [String]
  public let source: ProviderSourceFacts
  public let policy: ProviderCapabilityPolicy

  public init(
    capability: String,
    operationKinds: [String],
    source: ProviderSourceFacts,
    policy: ProviderCapabilityPolicy,
    version: PDFContractVersion = PDFContractVersion(major: 1, minor: 0),
    contract: String = ProviderCapabilityRequest.contractName
  ) {
    self.contract = contract
    self.version = version
    self.capability = capability
    self.operationKinds = operationKinds
    self.source = source
    self.policy = policy
  }
}

public enum ProviderNegotiationDecision: String, Codable, Hashable, Sendable {
  case selected
  case abstained
}

public struct ProviderCapabilityDecision: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.provider-capability-decision"

  public let contract: String
  public let version: PDFContractVersion
  public let decision: ProviderNegotiationDecision
  public let providerID: String?
  public let capability: String
  public let measurementID: String?
  public let fallbackProviderIDs: [String]
  public let reasonCodes: [String]
  public let expiresAt: Date?

  public init(
    decision: ProviderNegotiationDecision,
    providerID: String?,
    capability: String,
    measurementID: String?,
    fallbackProviderIDs: [String],
    reasonCodes: [String],
    expiresAt: Date? = nil,
    version: PDFContractVersion = PDFContractVersion(major: 1, minor: 0),
    contract: String = ProviderCapabilityDecision.contractName
  ) {
    self.contract = contract
    self.version = version
    self.decision = decision
    self.providerID = providerID
    self.capability = capability
    self.measurementID = measurementID
    self.fallbackProviderIDs = fallbackProviderIDs
    self.reasonCodes = reasonCodes
    self.expiresAt = expiresAt
  }
}

/// Deterministic admission policy shared by native and companion callers.
/// This selects an eligible capability, never an arbitrary executable.
public enum ProviderCapabilityNegotiator {
  public static func negotiate(
    registry: ProviderCapabilityRegistry,
    request: ProviderCapabilityRequest
  ) throws -> ProviderCapabilityDecision {
    try registry.validate()
    guard request.contract == ProviderCapabilityRequest.contractName,
      request.version.major == 1,
      !request.capability.isEmpty,
      request.source.byteCount >= 0,
      request.source.pageCount >= 0
    else {
      throw ProviderCapabilityError.invalid("provider capability request is invalid")
    }

    var preferred = [String: Int]()
    for (index, providerID) in request.policy.preferredProviderIDs.enumerated() {
      guard preferred[providerID] == nil else {
        throw ProviderCapabilityError.invalid("duplicate preferred provider ID")
      }
      preferred[providerID] = index
    }
    var eligible: [(provider: ProviderCapabilityManifest, capability: ProviderCapabilityRecord, preferred: Int)] = []
    var rejectionReasons = Set<String>()

    for provider in registry.providers {
      guard let capability = provider.capabilities.first(where: { $0.capabilityID == request.capability }) else {
        continue
      }
      guard provider.installState == .enabled || provider.installState == .measured else {
        rejectionReasons.insert("providerState:\(provider.installState.rawValue)")
        continue
      }
      guard provider.license.status == .approved else {
        rejectionReasons.insert("licenseUnapproved")
        continue
      }
      guard ![.revoked, .quarantined, .expired, .unavailable].contains(capability.state) else {
        rejectionReasons.insert("capabilityState:\(capability.state.rawValue)")
        continue
      }
      if capability.state == .installedUnmeasured && !request.policy.allowExperimental {
        rejectionReasons.insert("capabilityUnmeasured")
        continue
      }
      if request.policy.minimumState == .enabled && capability.state != .enabled {
        rejectionReasons.insert("capabilityBelowMinimumState")
        continue
      }
      if request.policy.minimumState == .measuredPartial
        && capability.state != .enabled && capability.state != .measuredPartial
      {
        rejectionReasons.insert("capabilityBelowMinimumState")
        continue
      }
      let limits = capability.limits
      guard request.source.byteCount <= limits.maxBytes,
        request.source.pageCount <= limits.maxPages,
        !request.source.isEncrypted || limits.supportsEncrypted,
        !request.source.isScanned || limits.supportsScanned
      else {
        rejectionReasons.insert("sourceOutsideProviderLimits")
        continue
      }
      let passedMeasurements = provider.measurements.filter {
        capability.measurementIDs.contains($0.measurementID) && $0.status == .passed
      }
      if capability.state == .enabled && passedMeasurements.isEmpty {
        rejectionReasons.insert("missingPassedMeasurement")
        continue
      }
      guard provider.revocations.isEmpty else {
        rejectionReasons.insert("providerRevoked")
        continue
      }
      eligible.append((provider, capability, preferred[provider.providerID] ?? Int.max))
    }

    eligible.sort {
      if $0.preferred != $1.preferred { return $0.preferred < $1.preferred }
      return $0.provider.providerID < $1.provider.providerID
    }

    guard let selected = eligible.first else {
      return ProviderCapabilityDecision(
        decision: .abstained,
        providerID: nil,
        capability: request.capability,
        measurementID: nil,
        fallbackProviderIDs: [],
        reasonCodes: rejectionReasons.sorted() + ["noEligibleLocalProvider"]
      )
    }

    let measurementID = providerMeasurementID(provider: selected.provider, capability: selected.capability)
    return ProviderCapabilityDecision(
      decision: .selected,
      providerID: selected.provider.providerID,
      capability: request.capability,
      measurementID: measurementID,
      fallbackProviderIDs: eligible.dropFirst().map { $0.provider.providerID },
      reasonCodes: ["exactArtifactMeasured", "licenseApproved", "sourceWithinLimits"]
        + (request.policy.localOnly ? ["localOnly"] : [])
    )
  }

  private static func providerMeasurementID(
    provider: ProviderCapabilityManifest,
    capability: ProviderCapabilityRecord
  ) -> String? {
    provider.measurements.first {
      capability.measurementIDs.contains($0.measurementID) && $0.status == .passed
    }?.measurementID
  }
}

public enum ProviderCapabilityError: Error, LocalizedError, Equatable, Sendable {
  case invalid(String)

  public var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}
