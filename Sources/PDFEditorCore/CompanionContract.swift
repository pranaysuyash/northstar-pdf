import Foundation
import CryptoKit

// MARK: - Contract Version

/// Semantic version for companion contracts.
public struct ContractVersion: Codable, Sendable, Comparable, Hashable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    
    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// Current contract version.
    public static let current = ContractVersion(major: 1, minor: 0, patch: 0)
    
    /// Minimum compatible version (major must match).
    public var minimumCompatible: ContractVersion {
        ContractVersion(major: major, minor: 0, patch: 0)
    }
    
    /// Whether another version is compatible (same major).
    public func isCompatible(with other: ContractVersion) -> Bool {
        major == other.major
    }
    
    /// String representation.
    public var stringValue: String {
        "\(major).\(minor).\(patch)"
    }
    
    public static func < (lhs: ContractVersion, rhs: ContractVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
    
    /// Parse from string (e.g., "1.2.3").
    public static func parse(_ string: String) -> ContractVersion? {
        let parts = string.split(separator: ".")
        guard parts.count == 3,
              let major = Int(parts[0]),
              let minor = Int(parts[1]),
              let patch = Int(parts[2]) else {
            return nil
        }
        return ContractVersion(major: major, minor: minor, patch: patch)
    }
}

// MARK: - Source Digest

/// Cryptographic digest binding a request to the source document.
public struct SourceDigest: Codable, Sendable, Hashable {
    /// SHA-256 hash of the source PDF bytes.
    public let sha256: String
    /// Size of the source in bytes.
    public let sizeBytes: Int
    /// Timestamp when the digest was computed.
    public let computedAt: Date
    /// Document path (value-free — filename only, no content).
    public let documentName: String
    
    public init(sha256: String, sizeBytes: Int, documentName: String = "", computedAt: Date = Date()) {
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
        self.computedAt = computedAt
        self.documentName = documentName
    }
    
    /// Compute digest from data (convenience).
    public static func compute(from data: Data, documentName: String = "") -> SourceDigest {
        let digest = SHA256Digest.hash(data)
        return SourceDigest(sha256: digest, sizeBytes: data.count, documentName: documentName)
    }
}

/// SHA-256 digest helper using CryptoKit.
enum SHA256Digest {
    static func hash(_ data: Data) -> String {
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Capability Handshake

/// The versioned capability handshake exchanged on first contact.
public struct CapabilityHandshake: Codable, Sendable {
    /// Provider identifier.
    public let providerID: String
    /// Provider version.
    public let providerVersion: String
    /// License signal.
    public let license: ProviderLicense
    /// Supported operations.
    public let supportedOperations: Set<CapabilityTag>
    /// Input limits.
    public let inputLimits: InputLimits
    /// Model/language versions (for OCR).
    public let modelVersions: [String: String]
    /// Contract version the provider supports.
    public let contractVersion: ContractVersion
    
    public init(
        providerID: String,
        providerVersion: String,
        license: ProviderLicense,
        supportedOperations: Set<CapabilityTag>,
        inputLimits: InputLimits,
        modelVersions: [String: String] = [:],
        contractVersion: ContractVersion = .current
    ) {
        self.providerID = providerID
        self.providerVersion = providerVersion
        self.license = license
        self.supportedOperations = supportedOperations
        self.inputLimits = inputLimits
        self.modelVersions = modelVersions
        self.contractVersion = contractVersion
    }
}

/// Input limits declared during handshake.
public struct InputLimits: Codable, Sendable {
    public let maxPages: Int
    public let maxFileSizeBytes: Int
    public let supportedFormats: [String]
    
    public init(maxPages: Int = 500, maxFileSizeBytes: Int = 100 * 1024 * 1024, supportedFormats: [String] = ["pdf"]) {
        self.maxPages = maxPages
        self.maxFileSizeBytes = maxFileSizeBytes
        self.supportedFormats = supportedFormats
    }
}

// MARK: - Request Contract

/// A versioned, digest-bound request to the companion.
public struct CompanionRequest: Codable, Sendable, Identifiable {
    public let id: UUID
    /// Contract version for this request.
    public let contractVersion: ContractVersion
    /// Source digest binding.
    public let sourceDigest: SourceDigest
    /// Requested operation.
    public let operation: CapabilityTag
    /// Provider target.
    public let providerID: String
    /// Operation-specific parameters.
    public let parameters: [String: String]
    /// Timestamp.
    public let timestamp: Date
    
    public init(
        contractVersion: ContractVersion = .current,
        sourceDigest: SourceDigest,
        operation: CapabilityTag,
        providerID: String,
        parameters: [String: String] = [:]
    ) {
        self.id = UUID()
        self.contractVersion = contractVersion
        self.sourceDigest = sourceDigest
        self.operation = operation
        self.providerID = providerID
        self.parameters = parameters
        self.timestamp = Date()
    }
    
    /// Validate this request against a handshake.
    public func validate(against handshake: CapabilityHandshake) -> ContractValidation {
        // 1. Contract version compatibility
        guard contractVersion.isCompatible(with: handshake.contractVersion) else {
            return .versionMismatch(
                expected: contractVersion.stringValue,
                received: handshake.contractVersion.stringValue
            )
        }
        
        // 2. License check
        guard handshake.license.isPermitted else {
            return .licenseRejected(handshake.license.displayName)
        }
        
        // 3. Capability support
        guard handshake.supportedOperations.contains(operation) else {
            return .capabilityUnsupported(operation.rawValue)
        }
        
        // 4. Input limits
        guard sourceDigest.sizeBytes <= handshake.inputLimits.maxFileSizeBytes else {
            return .inputTooLarge(
                actual: sourceDigest.sizeBytes,
                limit: handshake.inputLimits.maxFileSizeBytes
            )
        }
        
        return .valid
    }
}

// MARK: - Contract Validation

/// Result of validating a request against a handshake.
public enum ContractValidation: Sendable {
    case valid
    case versionMismatch(expected: String, received: String)
    case licenseRejected(String)
    case capabilityUnsupported(String)
    case inputTooLarge(actual: Int, limit: Int)
    case sourceDigestMismatch
    
    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
    
    public var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .versionMismatch(let expected, let received):
            return "Contract version mismatch: request requires \(expected), provider supports \(received)"
        case .licenseRejected(let license):
            return "Provider license '\(license)' is not permitted"
        case .capabilityUnsupported(let cap):
            return "Provider does not support capability '\(cap)'"
        case .inputTooLarge(let actual, let limit):
            return "Input too large: \(actual) bytes > \(limit) bytes limit"
        case .sourceDigestMismatch:
            return "Source document has changed since digest was computed"
        }
    }
}

// MARK: - Contract Store

/// Persistent store of validated handshakes.
public actor ContractStore {
    /// Validated handshakes keyed by provider ID.
    private var handshakes: [String: CapabilityHandshake] = [:]
    
    /// Validation timestamps.
    private var validatedAt: [String: Date] = [:]
    
    public init() {}
    
    /// Store a validated handshake.
    public func store(_ handshake: CapabilityHandshake) {
        handshakes[handshake.providerID] = handshake
        validatedAt[handshake.providerID] = Date()
    }
    
    /// Get a stored handshake.
    public func handshake(for providerID: String) -> CapabilityHandshake? {
        handshakes[providerID]
    }
    
    /// When was a provider last validated?
    public func lastValidated(for providerID: String) -> Date? {
        validatedAt[providerID]
    }
    
    /// Remove a handshake.
    public func remove(providerID: String) {
        handshakes.removeValue(forKey: providerID)
        validatedAt.removeValue(forKey: providerID)
    }
    
    /// All stored handshakes.
    public var allHandshakes: [CapabilityHandshake] {
        Array(handshakes.values)
    }
    
    /// Provider IDs with stored handshakes.
    public var registeredProviderIDs: [String] {
        Array(handshakes.keys)
    }
    
    /// Check if a provider has a recent handshake (within last hour).
    public func hasFreshHandshake(for providerID: String) -> Bool {
        guard let date = validatedAt[providerID] else { return false }
        return Date().timeIntervalSince(date) < 3600
    }
}
