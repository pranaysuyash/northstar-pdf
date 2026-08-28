import Foundation

/// Versioned companion protocol — the contract between the browser core and any installed companion.
///
/// First principle: the companion is optional. The browser core must work without it.
/// Every request is bound to a source digest and contract version.
/// Every response carries a structured state (supported, companionRequired, failed, warning, unknown).
///
/// Doctrine alignment:
/// - §3: Do things smartly — versioned handshake prevents compatibility drift
/// - §5: Evidence-based — every capability is declared, not assumed
/// - §8: Capability activation — companion features are opt-in per provider
/// - §12: Privacy stays value-free — logs never contain PDF content

// MARK: - Protocol Version

/// The current companion protocol version.
public enum CompanionProtocolVersion: Int, Comparable, Codable, Sendable {
  case v1 = 1

  public static func < (lhs: CompanionProtocolVersion, rhs: CompanionProtocolVersion) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public var displayName: String { "v\(rawValue)" }
}

// MARK: - Provider Identity

/// Identifies a companion provider.
public struct ProviderIdentity: Codable, Sendable, Hashable {
  /// Unique provider ID (reverse-DNS style).
  public let providerID: String
  /// Provider version string.
  public let version: String
  /// License identifier (SPDX).
  public let license: ProviderLicense
  /// Human-readable provider name.
  public let displayName: String
  /// Provider homepage URL.
  public let homepage: String?

  public init(
    providerID: String,
    version: String,
    license: ProviderLicense,
    displayName: String,
    homepage: String? = nil
  ) {
    self.providerID = providerID
    self.version = version
    self.license = license
    self.displayName = displayName
    self.homepage = homepage
  }
}

// MARK: - Provider License

/// SPDX license identifier for the provider.
public enum ProviderLicense: String, Codable, Sendable, CaseIterable {
  /// Permissive licenses (allowed by permissive-only policy)
  case mit = "MIT"
  case apache2 = "Apache-2.0"
  case bsd2 = "BSD-2-Clause"
  case bsd3 = "BSD-3-Clause"
  case isc = "ISC"
  case zlib = "Zlib"
  /// Copyleft licenses (excluded by policy)
  case gpl2 = "GPL-2.0"
  case gpl3 = "GPL-3.0"
  case agpl3 = "AGPL-3.0"
  case lgpl = "LGPL"
  /// Weak copyleft (excluded by policy)
  case mpl2 = "MPL-2.0"
  /// Commercial / Proprietary (excluded by policy)
  case commercial = "Commercial"
  case proprietary = "Proprietary"

  /// Whether this license is allowed by the permissive-only policy.
  public var isPermitted: Bool {
    switch self {
    case .mit, .apache2, .bsd2, .bsd3, .isc, .zlib:
      return true
    case .gpl2, .gpl3, .agpl3, .lgpl, .mpl2, .commercial, .proprietary:
      return false
    }
  }

  /// Backward-compatible alias.
  public var isPermissive: Bool { isPermitted }

  public var displayName: String {
    switch self {
    case .mit: return "MIT License"
    case .apache2: return "Apache License 2.0"
    case .bsd2: return "BSD 2-Clause"
    case .bsd3: return "BSD 3-Clause"
    case .isc: return "ISC License"
    case .zlib: return "zlib License"
    case .gpl2: return "GNU General Public License 2.0"
    case .gpl3: return "GNU General Public License 3.0"
    case .agpl3: return "GNU Affero General Public License 3.0"
    case .lgpl: return "GNU Lesser General Public License"
    case .mpl2: return "Mozilla Public License 2.0"
    case .commercial: return "Commercial License"
    case .proprietary: return "Proprietary License"
    }
  }
}

// MARK: - Capability Declaration

/// A single capability declared by a provider.
public struct ProviderCapability: Codable, Sendable, Identifiable {
  public let id: String
  /// The operation category.
  public let category: OperationCategory
  /// Specific operations supported within this category.
  public let operations: [String]
  /// Input limits for this capability.
  public let limits: CapabilityLimits
  /// Whether this capability requires network access.
  public let requiresNetwork: Bool
  /// Model or language versions used (e.g., OCR engine version).
  public let modelVersions: [String]

  public init(
    id: String = UUID().uuidString,
    category: OperationCategory,
    operations: [String],
    limits: CapabilityLimits = CapabilityLimits(),
    requiresNetwork: Bool = false,
    modelVersions: [String] = []
  ) {
    self.id = id
    self.category = category
    self.operations = operations
    self.limits = limits
    self.requiresNetwork = requiresNetwork
    self.modelVersions = modelVersions
  }
}

// MARK: - Operation Categories

/// High-level categories of PDF operations.
public enum OperationCategory: String, Codable, Sendable, CaseIterable {
  case read = "read"
  case render = "render"
  case formFill = "formFill"
  case annotation = "annotation"
  case pageOperation = "pageOperation"
  case ocr = "ocr"
  case redaction = "redaction"
  case signature = "signature"
  case validation = "validation"
  case batch = "batch"
  case search = "search"
  case export = "export"

  public var displayName: String {
    switch self {
    case .read: return "PDF Reading"
    case .render: return "Rendering"
    case .formFill: return "Form Fill"
    case .annotation: return "Annotations"
    case .pageOperation: return "Page Operations"
    case .ocr: return "OCR"
    case .redaction: return "Redaction"
    case .signature: return "Signatures"
    case .validation: return "Validation"
    case .batch: return "Batch Processing"
    case .search: return "Search"
    case .export: return "Export"
    }
  }
}

// MARK: - Capability Limits

/// Resource limits for a capability.
public struct CapabilityLimits: Codable, Sendable {
  /// Maximum input file size in bytes.
  public let maxInputSize: Int64
  /// Maximum number of pages.
  public let maxPages: Int
  /// Maximum concurrent operations.
  public let maxConcurrent: Int
  /// Timeout in seconds for a single operation.
  public let timeoutSeconds: Double
  /// Maximum output size in bytes.
  public let maxOutputSize: Int64

  public init(
    maxInputSize: Int64 = 100 * 1024 * 1024, // 100MB
    maxPages: Int = 500,
    maxConcurrent: Int = 1,
    timeoutSeconds: Double = 30,
    maxOutputSize: Int64 = 200 * 1024 * 1024 // 200MB
  ) {
    self.maxInputSize = maxInputSize
    self.maxPages = maxPages
    self.maxConcurrent = maxConcurrent
    self.timeoutSeconds = timeoutSeconds
    self.maxOutputSize = maxOutputSize
  }
}

// MARK: - Handshake

/// The initial handshake request from the browser core to a companion.
public struct HandshakeRequest: Codable, Sendable {
  /// Protocol version the browser core supports.
  public let protocolVersion: CompanionProtocolVersion
  /// Source document digest (SHA-256).
  public let sourceDigest: String
  /// Contract version for this session.
  public let contractVersion: Int
  /// Timestamp.
  public let timestamp: Date

  public init(
    sourceDigest: String,
    contractVersion: Int = 1
  ) {
    self.protocolVersion = .v1
    self.sourceDigest = sourceDigest
    self.contractVersion = contractVersion
    self.timestamp = Date()
  }
}

/// The companion's response to a handshake.
public struct HandshakeResponse: Codable, Sendable {
  /// Provider identity.
  public let provider: ProviderIdentity
  /// Declared capabilities.
  public let capabilities: [ProviderCapability]
  /// Whether the companion is ready to accept requests.
  public let isReady: Bool
  /// Any warnings during handshake.
  public let warnings: [String]

  public init(
    provider: ProviderIdentity,
    capabilities: [ProviderCapability],
    isReady: Bool = true,
    warnings: [String] = []
  ) {
    self.provider = provider
    self.capabilities = capabilities
    self.isReady = isReady
    self.warnings = warnings
  }
}

// MARK: - Companion State

/// The state of a companion request.
public enum CompanionState: String, Codable, Sendable {
  /// Operation is supported by this provider.
  case supported
  /// Companion is required but not available.
  case companionRequired
  /// Operation failed.
  case failed
  /// Operation completed with warnings.
  case warning
  /// State is unknown.
  case unknown

  public var displayName: String { rawValue.capitalized }

  public var symbolName: String {
    switch self {
    case .supported: return "checkmark.circle.fill"
    case .companionRequired: return "desktopcomputer"
    case .failed: return "xmark.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .unknown: return "questionmark.circle"
    }
  }

  public var isSuccess: Bool { self == .supported }
}

// MARK: - Request Binding

/// Binds every request to the source document and contract version.
public struct RequestBinding: Codable, Sendable {
  /// SHA-256 digest of the source document.
  public let sourceDigest: String
  /// Contract version for this session.
  public let contractVersion: Int
  /// Request ID (for cancellation and correlation).
  public let requestID: UUID
  /// When the request was created.
  public let timestamp: Date
  /// Maximum time allowed for this request.
  public let deadline: Date

  public init(
    sourceDigest: String,
    contractVersion: Int = 1,
    timeoutSeconds: Double = 30
  ) {
    self.sourceDigest = sourceDigest
    self.contractVersion = contractVersion
    self.requestID = UUID()
    self.timestamp = Date()
    self.deadline = Date().addingTimeInterval(timeoutSeconds)
  }

  /// Whether this request has exceeded its deadline.
  public var isExpired: Bool { Date() > deadline }
}

// MARK: - Companion Response

/// A structured response from a companion provider.
public struct CompanionResponse: Codable, Sendable {
  /// The binding this response corresponds to.
  public let binding: RequestBinding
  /// The state of the response.
  public let state: CompanionState
  /// Response payload (provider-specific).
  public let payload: Data?
  /// Error message if state is .failed.
  public let errorMessage: String?
  /// Warning messages if state is .warning.
  public let warnings: [String]
  /// Provider that produced this response.
  public let providerID: String
  /// When the response was produced.
  public let timestamp: Date

  public init(
    binding: RequestBinding,
    state: CompanionState,
    payload: Data? = nil,
    errorMessage: String? = nil,
    warnings: [String] = [],
    providerID: String
  ) {
    self.binding = binding
    self.state = state
    self.payload = payload
    self.errorMessage = errorMessage
    self.warnings = warnings
    self.providerID = providerID
    self.timestamp = Date()
  }
}
