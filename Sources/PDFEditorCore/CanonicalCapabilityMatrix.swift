import Foundation

/// Canonical long-term native/web/companion capability matrix.
///
/// This is the programmatic version of docs/capability-matrix.md.
/// It owns the capability → provider → contract → evidence gate →
/// sequencing mapping. The markdown doc is a human-readable export.
///
/// First principle: every capability must have:
/// - An owner (who is responsible)
/// - A contract (what interface it exposes)
/// - A provider (which engine serves it)
/// - An evidence gate (what proof is needed)
/// - A sequence (what must come before it)
///
/// Doctrine alignment:
/// - §5: Evidence-based — every gate is measurable
/// - §11: Engineering integrity — sequencing prevents broken dependencies
/// - §13: Product reality — claims must match implementation

// MARK: - Evidence Gate Status

/// Status of an evidence gate.
public enum GateStatus: String, Codable, Sendable {
    case open = "open"
    case partial = "partial"
    case pass = "pass"
    case fail = "fail"
    case waived = "waived"
}

// MARK: - Evidence Gate

/// A single evidence gate that must pass before a capability is claim-ready.
public struct EvidenceGate: Codable, Sendable, Identifiable {
    public let id: String
    /// Gate description.
    public let description: String
    /// Current status.
    public var status: GateStatus
    /// Evidence tier required (maps to doctrine §3).
    public let requiredTier: EvidenceClearance
    /// Test sensitivity required (S0-S3).
    public let requiredSensitivity: String
    /// Date status was last updated.
    public var lastUpdated: Date?
    /// Notes about this gate.
    public var notes: String?

    public init(
        id: String,
        description: String,
        status: GateStatus = .open,
        requiredTier: EvidenceClearance = .integration,
        requiredSensitivity: String = "S1",
        lastUpdated: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.description = description
        self.status = status
        self.requiredTier = requiredTier
        self.requiredSensitivity = requiredSensitivity
        self.lastUpdated = lastUpdated
        self.notes = notes
    }
}

// MARK: - Provider Entry

/// A provider's support for a specific capability.
public struct ProviderEntry: Codable, Sendable, Identifiable {
    public let id: String
    /// Provider name (e.g., "PDFKit", "PDF.js", "pdf-lib").
    public let providerName: String
    /// Which lane this provider serves.
    public let lane: CapabilityLane
    /// Support level.
    public let support: ProviderSupport
    /// Provider version (if known).
    public let version: String?
    /// License type.
    public let license: String?
    /// Known limitations.
    public let limitations: [String]

    public init(
        id: String = UUID().uuidString,
        providerName: String,
        lane: CapabilityLane,
        support: ProviderSupport,
        version: String? = nil,
        license: String? = nil,
        limitations: [String] = []
    ) {
        self.id = id
        self.providerName = providerName
        self.lane = lane
        self.support = support
        self.version = version
        self.license = license
        self.limitations = limitations
    }
}

// MARK: - Capability Matrix Entry

/// A single row in the canonical capability matrix.
public struct CapabilityMatrixEntry: Codable, Sendable, Identifiable {
    public let id: String
    /// Capability name.
    public let capability: String
    /// Product scope.
    public let scope: ProductScope
    /// Providers across all lanes.
    public let providers: [ProviderEntry]
    /// Contracts this capability depends on.
    public let contracts: [String]
    /// Evidence gates that must pass.
    public let evidenceGates: [EvidenceGate]
    /// Capabilities that must be complete before this one.
    public let dependsOn: [String]
    /// Owner.
    public let owner: String
    /// Sequencing priority (lower = earlier).
    public let sequencePriority: Int
    /// Product claim (what we tell users).
    public let productClaim: String
    /// Claim accuracy.
    public let claimAccuracy: String
    /// Last verified.
    public var lastVerified: Date?
    /// Notes.
    public let notes: String?

    public init(
        id: String = UUID().uuidString,
        capability: String,
        scope: ProductScope,
        providers: [ProviderEntry] = [],
        contracts: [String] = [],
        evidenceGates: [EvidenceGate] = [],
        dependsOn: [String] = [],
        owner: String = "",
        sequencePriority: Int = 0,
        productClaim: String = "",
        claimAccuracy: String = "Proposed",
        lastVerified: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.capability = capability
        self.scope = scope
        self.providers = providers
        self.contracts = contracts
        self.evidenceGates = evidenceGates
        self.dependsOn = dependsOn
        self.owner = owner
        self.sequencePriority = sequencePriority
        self.productClaim = productClaim
        self.claimAccuracy = claimAccuracy
        self.lastVerified = lastVerified
        self.notes = notes
    }

    /// Whether all evidence gates pass.
    public var allGatesPass: Bool {
        evidenceGates.allSatisfy { $0.status == .pass || $0.status == .waived }
    }

    /// Overall maturity derived from gate statuses.
    public var overallMaturity: MaturityLevel {
        if allGatesPass { return .complete }
        let passing = evidenceGates.filter { $0.status == .pass || $0.status == .waived }.count
        let total = evidenceGates.count
        guard total > 0 else { return .proposed }
        let ratio = Double(passing) / Double(total)
        if ratio >= 0.8 { return .partial }
        if ratio >= 0.5 { return .prototype }
        return .proposed
    }

    /// Overall evidence clearance derived from gate statuses.
    public var overallEvidence: EvidenceClearance {
        if allGatesPass { return .integration }
        let passing = evidenceGates.filter { $0.status == .pass || $0.status == .waived }.count
        if passing > 0 { return .targetedTest }
        return .staticInspection
    }

    /// Gate status summary.
    public var gateSummary: String {
        let passing = evidenceGates.filter { $0.status == .pass || $0.status == .waived }.count
        return "\(passing)/\(evidenceGates.count) gates pass"
    }

    /// Provider support summary per lane.
    public func providerSummary(for lane: CapabilityLane) -> String {
        let laneProviders = providers.filter { $0.lane == lane }
        if laneProviders.isEmpty { return "No provider" }
        return laneProviders.map { "\($0.providerName): \($0.support.rawValue)" }.joined(separator: ", ")
    }
}

// MARK: - Canonical Capability Matrix

/// The full canonical capability matrix.
public struct CanonicalCapabilityMatrix: Codable, Sendable {
    /// All capability entries.
    public var entries: [CapabilityMatrixEntry]

    public init(entries: [CapabilityMatrixEntry] = []) {
        self.entries = entries
    }

    /// Add or update a capability entry.
    public mutating func upsert(_ entry: CapabilityMatrixEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
    }

    /// Get all capabilities where a specific provider supports them.
    public func capabilities(providedBy providerName: String) -> [CapabilityMatrixEntry] {
        entries.filter { entry in
            entry.providers.contains { $0.providerName == providerName && $0.support != .unsupported }
        }
    }

    /// Get all capabilities in a specific lane.
    public func capabilities(in lane: CapabilityLane) -> [CapabilityMatrixEntry] {
        entries.filter { entry in
            entry.providers.contains { $0.lane == lane }
        }
    }

    /// Get capabilities with all gates passing.
    public var claimReady: [CapabilityMatrixEntry] {
        entries.filter { $0.allGatesPass }
    }

    /// Get capabilities with open gates.
    public var needsWork: [CapabilityMatrixEntry] {
        entries.filter { !$0.allGatesPass }
    }

    /// Topological sort by dependencies.
    public var sequenced: [CapabilityMatrixEntry] {
        var visited: Set<String> = []
        var result: [CapabilityMatrixEntry] = []

        func visit(_ entry: CapabilityMatrixEntry) {
            guard !visited.contains(entry.id) else { return }
            visited.insert(entry.id)

            // Visit dependencies first
            for depID in entry.dependsOn {
                if let dep = entries.first(where: { $0.id == depID }) {
                    visit(dep)
                }
            }

            result.append(entry)
        }

        // Sort by sequencePriority first, then visit
        let sorted = entries.sorted { $0.sequencePriority < $1.sequencePriority }
        for entry in sorted {
            visit(entry)
        }

        return result
    }

    /// Summary statistics.
    public var summary: MatrixSummary {
        var byLane: [CapabilityLane: Int] = [:]
        var byGateStatus: [GateStatus: Int] = [:]
        var totalGates = 0
        var passingGates = 0

        for entry in entries {
            for provider in entry.providers {
                byLane[provider.lane, default: 0] += 1
            }
            for gate in entry.evidenceGates {
                totalGates += 1
                byGateStatus[gate.status, default: 0] += 1
                if gate.status == .pass || gate.status == .waived {
                    passingGates += 1
                }
            }
        }

        return MatrixSummary(
            totalCapabilities: entries.count,
            claimReady: claimReady.count,
            needsWork: needsWork.count,
            totalGates: totalGates,
            passingGates: passingGates,
            byLane: byLane,
            byGateStatus: byGateStatus,
            gatePassRate: totalGates > 0 ? Double(passingGates) / Double(totalGates) : 0
        )
    }

    /// Export to markdown (human-readable version of docs/capability-matrix.md).
    public func toMarkdown() -> String {
        var md = "# Canonical Capability Matrix\n\n"
        md += "| Capability | Native | Browser | Companion | Gates | Claim |\n"
        md += "|---|---|---|---|---|---|\n"

        for entry in sequenced {
            let native = entry.providerSummary(for: .native)
            let browser = entry.providerSummary(for: .browser)
            let companion = entry.providerSummary(for: .companion)
            let gates = entry.gateSummary
            let claim = entry.productClaim.isEmpty ? "—" : entry.productClaim

            md += "| \(entry.capability) | \(native) | \(browser) | \(companion) | \(gates) | \(claim) |\n"
        }

        return md
    }
}

// MARK: - Matrix Summary

/// Summary statistics for the capability matrix.
public struct MatrixSummary: Codable, Sendable {
    public let totalCapabilities: Int
    public let claimReady: Int
    public let needsWork: Int
    public let totalGates: Int
    public let passingGates: Int
    public let byLane: [CapabilityLane: Int]
    public let byGateStatus: [GateStatus: Int]
    public let gatePassRate: Double

    public init(
        totalCapabilities: Int,
        claimReady: Int,
        needsWork: Int,
        totalGates: Int,
        passingGates: Int,
        byLane: [CapabilityLane: Int],
        byGateStatus: [GateStatus: Int],
        gatePassRate: Double
    ) {
        self.totalCapabilities = totalCapabilities
        self.claimReady = claimReady
        self.needsWork = needsWork
        self.totalGates = totalGates
        self.passingGates = passingGates
        self.byLane = byLane
        self.byGateStatus = byGateStatus
        self.gatePassRate = gatePassRate
    }
}
