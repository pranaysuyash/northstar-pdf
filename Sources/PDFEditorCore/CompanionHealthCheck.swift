import Foundation

// MARK: - Companion Health Check

/// Aggregated health status for the companion subsystem.
/// Pulls live state from ProviderRegistry, CompanionBridge, EgressGate,
/// and ContractStore to present a single source of truth.
@MainActor
public final class CompanionHealthCheck: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var providerStatuses: [ProviderHealthStatus] = []
    @Published public private(set) var egressStatus: EgressStatus = EgressStatus()
    @Published public private(set) var bridgeStatus: BridgeStatus = BridgeStatus()
    @Published public private(set) var contractStatus: ContractStatus = ContractStatus()
    @Published public private(set) var recentLogEntries: [RequestLogEntry] = []
    @Published public private(set) var lastRefreshedAt: Date?

    // MARK: - Dependencies

    private let bridge: CompanionBridge
    private let registry: ProviderRegistry
    private let egressGate: EgressGate
    private let contractStore: ContractStore

    public init(
        bridge: CompanionBridge,
        registry: ProviderRegistry,
        egressGate: EgressGate,
        contractStore: ContractStore
    ) {
        self.bridge = bridge
        self.registry = registry
        self.egressGate = egressGate
        self.contractStore = contractStore
    }

    // MARK: - Public Actions

    /// Clear the bridge request log.
    public func clearLog() async {
        await bridge.clearLog()
        await refresh()
    }

    // MARK: - Refresh

    /// Pull current state from all subsystems. Call on appear and periodically.
    public func refresh() async {
        async let providerSnap = fetchProviderStatuses()
        async let egressSnap = fetchEgressStatus()
        async let bridgeSnap = fetchBridgeStatus()
        async let contractSnap = fetchContractStatus()
        async let logSnap = bridge.recentLog(limit: 100)

        let (providers, egress, bridgeSt, contracts, log) = await (
            providerSnap, egressSnap, bridgeSnap, contractSnap, logSnap
        )

        self.providerStatuses = providers
        self.egressStatus = egress
        self.bridgeStatus = bridgeSt
        self.contractStatus = contracts
        self.recentLogEntries = log
        self.lastRefreshedAt = Date()
    }

    // MARK: - Derived Health

    /// Overall health: green if all providers healthy and bridge connected,
    /// yellow if degraded, red if critical.
    public var overallHealth: HealthLevel {
        if bridgeStatus.state == .disconnected { return .critical }
        let hasFailures = providerStatuses.contains { $0.health == .failed }
        let hasDegraded = providerStatuses.contains { $0.health == .degraded }
        if hasFailures { return .critical }
        if hasDegraded { return .warning }
        return .healthy
    }

    /// Number of healthy providers.
    public var healthyProviderCount: Int {
        providerStatuses.filter { $0.health == .healthy }.count
    }

    /// Number of enabled providers.
    public var enabledProviderCount: Int {
        providerStatuses.filter { $0.isEnabled }.count
    }

    // MARK: - Private Fetch Helpers

    private func fetchProviderStatuses() async -> [ProviderHealthStatus] {
        let providers = await registry.allProviders
        let matrix = await registry.capabilityMatrix()

        var results: [ProviderHealthStatus] = []
        for provider in providers {
            let handshakeFresh = await contractStore.hasFreshHandshake(for: provider.id)
            let handshakeDate = await contractStore.lastValidated(for: provider.id)

            let health: HealthLevel
            if !provider.isEnabled {
                health = .disabled
            } else if provider.failureCount >= 5 {
                health = .failed
            } else if provider.failureCount >= 2 {
                health = .degraded
            } else if !handshakeFresh {
                health = .stale
            } else {
                health = .healthy
            }

            let coveredCapabilities = provider.capabilities.filter { matrix[$0] != nil }

            results.append(ProviderHealthStatus(
                id: provider.id,
                name: provider.name,
                version: provider.version,
                license: provider.license,
                isEnabled: provider.isEnabled,
                health: health,
                failureCount: provider.failureCount,
                lastHandshake: handshakeDate,
                handshakeIsFresh: handshakeFresh,
                capabilities: Array(provider.capabilities).sorted { $0.rawValue < $1.rawValue },
                capabilityCount: coveredCapabilities.count,
                maxPages: provider.maxPages,
                maxInputBytes: provider.maxInputBytes
            ))
        }

        // Sort: failed first, then degraded, then stale, then healthy, then disabled.
        let order: [HealthLevel: Int] = [.failed: 0, .degraded: 1, .stale: 2, .healthy: 3, .disabled: 4]
        results.sort { a, b in
            if order[a.health] != order[b.health] {
                return (order[a.health] ?? 5) < (order[b.health] ?? 5)
            }
            return a.name < b.name
        }

        return results
    }

    private func fetchEgressStatus() async -> EgressStatus {
        let enabled = await egressGate.isEnabled
        let connections = await egressGate.activeConnections
        return EgressStatus(isEnabled: enabled, activeConnections: connections)
    }

    private func fetchBridgeStatus() async -> BridgeStatus {
        let authenticated = await bridge.isAuthenticated
        let connected = await bridge.isTransportConnected
        let pending = await bridge.pendingCount
        let logCount = await bridge.recentLog(limit: Int.max).count

        let state: BridgeStatus.BridgeConnectionState
        if !authenticated {
            state = .unauthenticated
        } else if !connected {
            state = .disconnected
        } else {
            state = .connected
        }

        return BridgeStatus(
            state: state,
            isAuthenticated: authenticated,
            isTransportConnected: connected,
            pendingRequests: pending,
            totalLogEntries: logCount
        )
    }

    private func fetchContractStatus() async -> ContractStatus {
        let ids = await contractStore.registeredProviderIDs
        let handshakes = await contractStore.allHandshakes

        var freshCount = 0
        for hs in handshakes {
            let fresh = await contractStore.hasFreshHandshake(for: hs.providerID)
            if fresh { freshCount += 1 }
        }

        return ContractStatus(
            totalHandshakes: handshakes.count,
            freshHandshakes: freshCount,
            staleHandshakes: handshakes.count - freshCount,
            providerIDs: ids
        )
    }
}

// MARK: - Health Level

public enum HealthLevel: String, Sendable, CaseIterable {
    case healthy
    case warning
    case critical
    case degraded
    case failed
    case disabled
    case stale

    public var displayName: String { rawValue.capitalized }

    public var colorName: String {
        switch self {
        case .healthy: return "green"
        case .warning: return "orange"
        case .critical, .failed: return "red"
        case .degraded, .stale: return "yellow"
        case .disabled: return "gray"
        }
    }

    public var symbolName: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .failed: return "xmark.circle.fill"
        case .degraded: return "exclamationmark.circle.fill"
        case .disabled: return "pause.circle.fill"
        case .stale: return "clock.fill"
        }
    }
}

// MARK: - Provider Health Status

public struct ProviderHealthStatus: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let license: ProviderLicense
    public let isEnabled: Bool
    public let health: HealthLevel
    public let failureCount: Int
    public let lastHandshake: Date?
    public let handshakeIsFresh: Bool
    public let capabilities: [CapabilityTag]
    public let capabilityCount: Int
    public let maxPages: Int
    public let maxInputBytes: Int

    public var displayFailureCount: String {
        failureCount == 0 ? "—" : "\(failureCount)"
    }

    public var handshakeDisplay: String {
        if let date = lastHandshake {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return "Never"
    }
}

// MARK: - Egress Status

public struct EgressStatus: Sendable {
    public var isEnabled: Bool
    public var activeConnections: [String]

    public init(isEnabled: Bool = false, activeConnections: [String] = []) {
        self.isEnabled = isEnabled
        self.activeConnections = activeConnections
    }

    public var connectionCount: Int { activeConnections.count }
    public var stateLabel: String { isEnabled ? "Enabled" : "Disabled (zero-egress)" }
}

// MARK: - Bridge Status

public struct BridgeStatus: Sendable {
    public enum BridgeConnectionState: String, Sendable {
        case connected
        case unauthenticated
        case disconnected
    }

    public var state: BridgeConnectionState
    public var isAuthenticated: Bool
    public var isTransportConnected: Bool
    public var pendingRequests: Int
    public var totalLogEntries: Int

    public init(
        state: BridgeConnectionState = .disconnected,
        isAuthenticated: Bool = false,
        isTransportConnected: Bool = false,
        pendingRequests: Int = 0,
        totalLogEntries: Int = 0
    ) {
        self.state = state
        self.isAuthenticated = isAuthenticated
        self.isTransportConnected = isTransportConnected
        self.pendingRequests = pendingRequests
        self.totalLogEntries = totalLogEntries
    }
}

// MARK: - Contract Status

public struct ContractStatus: Sendable {
    public var totalHandshakes: Int
    public var freshHandshakes: Int
    public var staleHandshakes: Int
    public var providerIDs: [String]

    public init(
        totalHandshakes: Int = 0,
        freshHandshakes: Int = 0,
        staleHandshakes: Int = 0,
        providerIDs: [String] = []
    ) {
        self.totalHandshakes = totalHandshakes
        self.freshHandshakes = freshHandshakes
        self.staleHandshakes = staleHandshakes
        self.providerIDs = providerIDs
    }
}
