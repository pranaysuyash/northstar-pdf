import Foundation

// MARK: - Capability Tag

/// Simple capability name for registry lookup (distinct from the struct-based ProviderCapability in CompanionProtocol).
public enum CapabilityTag: String, Codable, Sendable, CaseIterable, Hashable {
    // Reading
    case pdfRendering
    case textExtraction
    case metadataReading
    case thumbnailGeneration
    case outlineExtraction
    case linkExtraction
    
    // Forms
    case acroFormInspection
    case acroFormFilling
    case formValidation
    case formFieldDetection
    
    // Text/Image operations
    case textOverlay
    case imageOverlay
    case annotationCreation
    case annotationExport
    
    // Page operations
    case pageReorder
    case pageInsert
    case pageDelete
    case pageSplit
    case pageMerge
    case pageRotate
    case pageExtract
    
    // Security
    case encryption
    case decryption
    case permissionCheck
    case redaction
    case digitalSignature
    
    // OCR
    case ocrTextRecognition
    case ocrBounding
    case searchableOcrLayer
    
    // Validation
    case structuralValidation
    case pdfaValidation
    case pdfuaValidation
    case corruptionDetection
    
    // Batch
    case batchProcessing
    case largeDocumentProcessing
    
    // Export
    case structuredExport
    case csvExport
    case jsonExport
    
    /// Display name for UI.
    public var displayName: String {
        switch self {
        case .pdfRendering: return "PDF Rendering"
        case .textExtraction: return "Text Extraction"
        case .metadataReading: return "Metadata Reading"
        case .thumbnailGeneration: return "Thumbnail Generation"
        case .outlineExtraction: return "Outline Extraction"
        case .linkExtraction: return "Link Extraction"
        case .acroFormInspection: return "AcroForm Inspection"
        case .acroFormFilling: return "AcroForm Filling"
        case .formValidation: return "Form Validation"
        case .formFieldDetection: return "Form Field Detection"
        case .textOverlay: return "Text Overlay"
        case .imageOverlay: return "Image Overlay"
        case .annotationCreation: return "Annotation Creation"
        case .annotationExport: return "Annotation Export"
        case .pageReorder: return "Page Reorder"
        case .pageInsert: return "Page Insert"
        case .pageDelete: return "Page Delete"
        case .pageSplit: return "Page Split"
        case .pageMerge: return "Page Merge"
        case .pageRotate: return "Page Rotate"
        case .pageExtract: return "Page Extract"
        case .encryption: return "Encryption"
        case .decryption: return "Decryption"
        case .permissionCheck: return "Permission Check"
        case .redaction: return "Redaction"
        case .digitalSignature: return "Digital Signature"
        case .ocrTextRecognition: return "OCR Text Recognition"
        case .ocrBounding: return "OCR Bounding Boxes"
        case .searchableOcrLayer: return "Searchable OCR Layer"
        case .structuralValidation: return "Structural Validation"
        case .pdfaValidation: return "PDF/A Validation"
        case .pdfuaValidation: return "PDF/UA Validation"
        case .corruptionDetection: return "Corruption Detection"
        case .batchProcessing: return "Batch Processing"
        case .largeDocumentProcessing: return "Large Document Processing"
        case .structuredExport: return "Structured Export"
        case .csvExport: return "CSV Export"
        case .jsonExport: return "JSON Export"
        }
    }
}

// MARK: - Provider Registration

/// A registered companion provider with its capabilities and metadata.
public struct ProviderRegistration: Codable, Sendable, Identifiable {
    public let id: String
    /// Display name.
    public let name: String
    /// Provider version.
    public let version: String
    /// License classification (uses ProviderLicense from CompanionProtocol).
    public let license: ProviderLicense
    /// URL to the provider binary/module.
    public let binaryURL: String?
    /// Hash of the binary for integrity verification.
    public let binaryHash: String?
    /// Supported capability tags.
    public let capabilities: Set<CapabilityTag>
    /// Input size limits (pages).
    public let maxPages: Int
    /// Input size limits (bytes).
    public let maxInputBytes: Int
    /// Whether the provider is currently enabled.
    public var isEnabled: Bool
    /// Timestamp of last successful handshake.
    public var lastHandshake: Date?
    /// Timestamp of last failure.
    public var lastFailure: Date?
    /// Failure count.
    public var failureCount: Int
    
    public init(
        id: String,
        name: String,
        version: String,
        license: ProviderLicense,
        binaryURL: String? = nil,
        binaryHash: String? = nil,
        capabilities: Set<CapabilityTag>,
        maxPages: Int = 500,
        maxInputBytes: Int = 50 * 1024 * 1024,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.license = license
        self.binaryURL = binaryURL
        self.binaryHash = binaryHash
        self.capabilities = capabilities
        self.maxPages = maxPages
        self.maxInputBytes = maxInputBytes
        self.isEnabled = isEnabled
        self.lastHandshake = nil
        self.lastFailure = nil
        self.failureCount = 0
    }
}

// MARK: - Provider Registry

/// Registry of available companion providers with capability-based lookup.
/// Only permissive-licensed providers are allowed.
public actor ProviderRegistry {
    /// Registered providers.
    private var providers: [String: ProviderRegistration] = [:]
    
    public init() {}
    
    /// Register a provider (rejects copyleft/commercial licenses).
    public func register(_ provider: ProviderRegistration) throws {
        guard provider.license.isPermitted else {
            throw ProviderError.licenseNotPermitted(provider.id, provider.license.displayName)
        }
        providers[provider.id] = provider
    }
    
    /// Unregister a provider.
    public func unregister(_ id: String) {
        providers.removeValue(forKey: id)
    }
    
    /// Get a provider by ID.
    public func provider(id: String) -> ProviderRegistration? {
        providers[id]
    }
    
    /// All registered providers.
    public var allProviders: [ProviderRegistration] {
        Array(providers.values)
    }
    
    /// All enabled providers.
    public var enabledProviders: [ProviderRegistration] {
        providers.values.filter { $0.isEnabled }
    }
    
    /// Find providers that support a specific capability tag.
    public func providers(for capability: CapabilityTag) -> [ProviderRegistration] {
        providers.values.filter { $0.isEnabled && $0.capabilities.contains(capability) }
    }
    
    /// Find the best provider for a capability (highest version, fewest failures).
    public func bestProvider(for capability: CapabilityTag) -> ProviderRegistration? {
        providers.values
            .filter { $0.isEnabled && $0.capabilities.contains(capability) }
            .sorted { a, b in
                if a.failureCount != b.failureCount {
                    return a.failureCount < b.failureCount
                }
                return a.version > b.version
            }
            .first
    }
    
    /// Find providers that support ALL of the given capabilities.
    public func providers(forAll capabilities: Set<CapabilityTag>) -> [ProviderRegistration] {
        providers.values.filter { $0.isEnabled && capabilities.isSubset(of: $0.capabilities) }
    }
    
    /// Record a successful handshake.
    public func recordSuccess(id: String) {
        guard var provider = providers[id] else { return }
        provider.lastHandshake = Date()
        provider.failureCount = 0
        providers[id] = provider
    }
    
    /// Record a failure.
    public func recordFailure(id: String) {
        guard var provider = providers[id] else { return }
        provider.lastFailure = Date()
        provider.failureCount += 1
        // Auto-disable after 5 consecutive failures
        if provider.failureCount >= 5 {
            provider.isEnabled = false
        }
        providers[id] = provider
    }
    
    /// Re-enable a disabled provider.
    public func reEnable(id: String) {
        guard var provider = providers[id] else { return }
        provider.isEnabled = true
        provider.failureCount = 0
        providers[id] = provider
    }
    
    /// Provider count.
    public var count: Int {
        providers.count
    }
    
    /// Capability matrix: which capabilities are covered by at least one provider.
    public func capabilityMatrix() -> [CapabilityTag: [String]] {
        var matrix: [CapabilityTag: [String]] = [:]
        for provider in providers.values where provider.isEnabled {
            for cap in provider.capabilities {
                matrix[cap, default: []].append(provider.id)
            }
        }
        return matrix
    }
}

// MARK: - Provider Errors

public enum ProviderError: Error, LocalizedError, Sendable {
    case licenseNotPermitted(String, String)
    case notFound(String)
    case capabilityNotSupported(String, String)
    case handshakeFailed(String)
    case binaryIntegrityMismatch(String)
    
    public var errorDescription: String? {
        switch self {
        case .licenseNotPermitted(let id, let license):
            return "Provider '\(id)' uses non-permissive license '\(license)'"
        case .notFound(let id):
            return "Provider not found: \(id)"
        case .capabilityNotSupported(let id, let cap):
            return "Provider '\(id)' does not support capability '\(cap)'"
        case .handshakeFailed(let id):
            return "Handshake failed for provider '\(id)'"
        case .binaryIntegrityMismatch(let id):
            return "Binary integrity check failed for provider '\(id)'"
        }
    }
}
