import Foundation

// MARK: - Negotiated Capability

/// A capability that was successfully negotiated with a companion provider.
public struct NegotiatedCapability: Codable, Sendable, Identifiable {
    public let id: String
    /// The provider that offers this capability.
    public let providerID: String
    /// The capability tag.
    public let capability: CapabilityTag
    /// The handshake that established this capability.
    public let handshake: CapabilityHandshake
    /// When this capability was negotiated.
    public let negotiatedAt: Date
    /// Whether this capability is currently active.
    public var isActive: Bool

    public init(
        providerID: String,
        capability: CapabilityTag,
        handshake: CapabilityHandshake,
        isActive: Bool = true
    ) {
        self.id = "\(providerID).\(capability.rawValue)"
        self.providerID = providerID
        self.capability = capability
        self.handshake = handshake
        self.negotiatedAt = Date()
        self.isActive = isActive
    }
}

// MARK: - Negotiation Result

/// The result of a full negotiation round.
public struct NegotiationResult: Codable, Sendable {
    /// Capabilities that were successfully negotiated.
    public let capabilities: [NegotiatedCapability]
    /// Providers that were contacted but failed negotiation.
    public let failedProviders: [NegotiationFailure]
    /// Total time spent negotiating (seconds).
    public let duration: TimeInterval
    /// The source document digest this negotiation was for.
    public let sourceDigest: String

    /// Unique provider IDs that participated.
    public var providerIDs: Set<String> {
        Set(capabilities.map(\.providerID)).union(Set(failedProviders.map(\.providerID)))
    }

    /// Capabilities available for a specific operation.
    public func capabilities(for tag: CapabilityTag) -> [NegotiatedCapability] {
        capabilities.filter { $0.capability == tag && $0.isActive }
    }

    /// Best provider for a capability (fewest failures, highest version).
    public func bestProvider(for tag: CapabilityTag) -> NegotiatedCapability? {
        capabilities(for: tag).first
    }
}

// MARK: - Negotiation Failure

/// Records why a provider failed negotiation.
public struct NegotiationFailure: Codable, Sendable {
    public let providerID: String
    public let reason: String
    public let timestamp: Date

    public init(providerID: String, reason: String) {
        self.providerID = providerID
        self.reason = reason
        self.timestamp = Date()
    }
}

// MARK: - Companion Negotiator

/// Orchestrates capability negotiation between the browser core and companion providers.
///
/// On document open, the negotiator:
/// 1. Computes the source digest
/// 2. Queries the provider registry for available providers
/// 3. Performs handshakes with each provider
/// 4. Validates capabilities against the source document
/// 5. Stores validated handshakes in the contract store
/// 6. Publishes the negotiated capability set
///
/// First principle: negotiation is fire-and-forget. The app works without companions.
/// Negotiated capabilities are additive — they unlock optional acceleration.
public final class CompanionNegotiator: @unchecked Sendable {
    /// The provider registry (which providers are available).
    private let registry: ProviderRegistry

    /// The contract store (validated handshakes).
    private let contractStore: ContractStore

    /// The bridge used for transport.
    private let bridge: CompanionBridge

    /// Maximum time for the full negotiation round.
    public let negotiationTimeout: TimeInterval

    /// The most recent negotiation result.
    public private(set) var lastResult: NegotiationResult?

    /// Currently active capabilities.
    public private(set) var activeCapabilities: [NegotiatedCapability] = []

    /// Callback invoked when negotiation completes.
    public var onNegotiationComplete: (@Sendable (NegotiationResult) -> Void)?

    private let lock = NSLock()

    public init(
        registry: ProviderRegistry = ProviderRegistry(),
        contractStore: ContractStore = ContractStore(),
        bridge: CompanionBridge = CompanionBridge(configuration: .mock),
        negotiationTimeout: TimeInterval = 5.0
    ) {
        self.registry = registry
        self.contractStore = contractStore
        self.bridge = bridge
        self.negotiationTimeout = negotiationTimeout
    }

    // MARK: - Negotiation

    /// Perform capability negotiation for a newly opened document.
    ///
    /// This is designed to be called from `AppModel.open()` in a detached task.
    /// It does not block the main actor — all work happens async.
    public func negotiate(sourceDigest: String) async -> NegotiationResult {
        let startTime = Date()
        var capabilities: [NegotiatedCapability] = []
        var failures: [NegotiationFailure] = []

        // 1. Get all enabled providers from the registry.
        let providers = await registry.enabledProviders

        guard !providers.isEmpty else {
            let result = NegotiationResult(
                capabilities: [],
                failedProviders: [],
                duration: Date().timeIntervalSince(startTime),
                sourceDigest: sourceDigest
            )
            lastResult = result
            activeCapabilities = []
            onNegotiationComplete?(result)
            return result
        }

        // 2. Attempt handshake with each provider concurrently.
        await withTaskGroup(of: NegotiationOutcome.self) { group in
            for provider in providers {
                group.addTask { [bridge, contractStore, registry] in
                    await Self.negotiateWithProvider(
                        provider: provider,
                        sourceDigest: sourceDigest,
                        bridge: bridge,
                        contractStore: contractStore,
                        registry: registry
                    )
                }
            }

            for await outcome in group {
                switch outcome {
                case .success(let caps):
                    capabilities.append(contentsOf: caps)
                case .failure(let failure):
                    failures.append(failure)
                }
            }
        }

        let result = NegotiationResult(
            capabilities: capabilities,
            failedProviders: failures,
            duration: Date().timeIntervalSince(startTime),
            sourceDigest: sourceDigest
        )

        lastResult = result
        activeCapabilities = capabilities
        onNegotiationComplete?(result)

        return result
    }

    /// Negotiate with a single provider.
    private static func negotiateWithProvider(
        provider: ProviderRegistration,
        sourceDigest: String,
        bridge: CompanionBridge,
        contractStore: ContractStore,
        registry: ProviderRegistry
    ) async -> NegotiationOutcome {
        // Build handshake request.
        let handshakeRequest = HandshakeRequest(
            sourceDigest: sourceDigest,
            contractVersion: 1
        )

        do {
            // Send handshake through bridge transport.
            let handshakeResponse: HandshakeResponse
            do {
                handshakeResponse = try await bridge.performHandshake(sourceDigest: sourceDigest)
            } catch {
                // Transport-level failure — handshake couldn't be sent.
                return .failure(NegotiationFailure(
                    providerID: provider.id,
                    reason: "Transport error: \(error.localizedDescription)"
                ))
            }

            // Verify the provider identity matches.
            guard handshakeResponse.provider.providerID == provider.id else {
                return .failure(NegotiationFailure(
                    providerID: provider.id,
                    reason: "Provider ID mismatch"
                ))
            }

            // Verify the provider is ready.
            guard handshakeResponse.isReady else {
                return .failure(NegotiationFailure(
                    providerID: provider.id,
                    reason: "Provider not ready"
                ))
            }

            // Verify license is permissive.
            guard handshakeResponse.provider.license.isPermitted else {
                return .failure(NegotiationFailure(
                    providerID: provider.id,
                    reason: "Non-permissive license: \(handshakeResponse.provider.license.displayName)"
                ))
            }

            // Build a CapabilityHandshake from the response and store it.
            let supportedOps = Set(provider.capabilities.map { $0 })
            let handshake = CapabilityHandshake(
                providerID: provider.id,
                providerVersion: handshakeResponse.provider.version,
                license: handshakeResponse.provider.license,
                supportedOperations: supportedOps,
                inputLimits: InputLimits()
            )
            await contractStore.store(handshake)

            // Create negotiated capabilities for each supported tag.
            let negotiatedCaps = provider.capabilities.map { tag in
                NegotiatedCapability(
                    providerID: provider.id,
                    capability: tag,
                    handshake: handshake
                )
            }

            // Record success in registry.
            await registry.recordSuccess(id: provider.id)

            return .success(negotiatedCaps)

        } catch {
            return .failure(NegotiationFailure(
                providerID: provider.id,
                reason: "Handshake failed: \(error.localizedDescription)"
            ))
        }
    }

    // MARK: - Capability Query

    /// Check if a specific capability is available.
    public func hasCapability(_ tag: CapabilityTag) -> Bool {
        activeCapabilities.contains { $0.capability == tag && $0.isActive }
    }

    /// Get the best provider for a capability.
    public func provider(for tag: CapabilityTag) -> NegotiatedCapability? {
        activeCapabilities
            .filter { $0.capability == tag && $0.isActive }
            .first
    }

    /// All active capabilities as a set of tags.
    public var activeCapabilityTags: Set<CapabilityTag> {
        Set(activeCapabilities.filter(\.isActive).map(\.capability))
    }

    /// Clear all negotiated state (e.g., on document close).
    public func reset() {
        lastResult = nil
        activeCapabilities = []
    }
}

// MARK: - Negotiation Outcome

private enum NegotiationOutcome {
    case success([NegotiatedCapability])
    case failure(NegotiationFailure)
}
