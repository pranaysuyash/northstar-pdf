import Foundation

/// Durable capability maturity model.
///
/// Separates five independent dimensions of capability readiness:
/// 1. Product scope — what the capability does for the user
/// 2. Implementation status — what's built vs proposed
/// 3. Provider support — which engine/provider can serve it
/// 4. Evidence clearance — what proof exists at what tier
/// 5. Lane — native, browser, companion, or shared
///
/// First principle: a capability is not "done" until all five dimensions
/// are explicitly stated. Vague claims like "supported" are forbidden.
///
/// Doctrine alignment:
/// - §2: Truth taxonomy — every dimension is labeled (Observed/Verified/Inferred/Proposed)
/// - §5: Evidence-based — evidence clearance is a first-class dimension
/// - §13: Product reality — product scope must match implementation

// MARK: - Maturity Level

/// Implementation maturity level.
public enum MaturityLevel: String, Codable, Sendable, CaseIterable, Comparable {
    /// Not started — only a concept or requirement.
    case proposed = "proposed"
    /// Prototype — works in isolation, not wired into app.
    case prototype = "prototype"
    /// Partial — works for some cases, missing edge cases or integration.
    case partial = "partial"
    /// Complete — works for all reviewed cases, wired into app, tested.
    case complete = "complete"
    /// Hardened — mutation-tested, corpus-validated, production-ready.
    case hardened = "hardened"

    public static func < (lhs: MaturityLevel, rhs: MaturityLevel) -> Bool {
        let order: [MaturityLevel] = [.proposed, .prototype, .partial, .complete, .hardened]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: - Evidence Tier

/// Evidence clearance level (maps to doctrine §3 tiers).
public enum EvidenceClearance: String, Codable, Sendable, CaseIterable, Comparable {
    /// No evidence — claim is unverified.
    case none = "none"
    /// Tier 1: Static inspection (code exists, compiles).
    case staticInspection = "static_inspection"
    /// Tier 2: Targeted test (unit test passes).
    case targetedTest = "targeted_test"
    /// Tier 3: Integration test (end-to-end flow works).
    case integration = "integration"
    /// Tier 4: Live runtime observation.
    case liveRuntime = "live_runtime"
    /// Tier 5: Production-like external verification.
    case production = "production"

    public static func < (lhs: EvidenceClearance, rhs: EvidenceClearance) -> Bool {
        let order: [EvidenceClearance] = [
            .none, .staticInspection, .targetedTest, .integration, .liveRuntime, .production
        ]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: - Provider Support

/// How a specific provider supports a capability.
public enum ProviderSupport: String, Codable, Sendable {
    /// Provider cannot serve this capability.
    case unsupported = "unsupported"
    /// Provider can serve it with known limitations.
    case conditional = "conditional"
    /// Provider fully supports it.
    case supported = "supported"
    /// Provider supports it as the primary/required provider.
    case primary = "primary"
}

// MARK: - Capability Lane

/// Which execution lane serves the capability.
public enum CapabilityLane: String, Codable, Sendable, CaseIterable {
    /// Native macOS (PDFKit, Vision, AppKit).
    case native = "native"
    /// Browser (PDF.js, pdf-lib, web APIs).
    case browser = "browser"
    /// Companion (installed local process).
    case companion = "companion"
    /// Shared (contract/interface shared across lanes).
    case shared = "shared"
}

// MARK: - Product Scope

/// What the capability does for the user.
public struct ProductScope: Codable, Sendable {
    /// User-facing capability name.
    public let name: String
    /// User statement (JTBD format).
    public let userStatement: String
    /// Which archetype this serves (Reader, Creator, Manager, Power).
    public let archetype: String
    /// Which JTBD job this maps to.
    public let jobID: String
    /// User-facing claim (what we tell users).
    public let claim: String
    /// Claim accuracy (Observed/Verified/Inferred/Proposed).
    public let claimAccuracy: String

    public init(
        name: String,
        userStatement: String,
        archetype: String,
        jobID: String,
        claim: String,
        claimAccuracy: String
    ) {
        self.name = name
        self.userStatement = userStatement
        self.archetype = archetype
        self.jobID = jobID
        self.claim = claim
        self.claimAccuracy = claimAccuracy
    }
}

// MARK: - Capability Maturity Entry

/// A single capability's maturity across all five dimensions.
public struct CapabilityMaturityEntry: Codable, Sendable, Identifiable {
    public let id: String
    /// Product scope.
    public let scope: ProductScope
    /// Implementation maturity per lane.
    public let implementation: [CapabilityLane: MaturityLevel]
    /// Provider support per lane.
    public let providerSupport: [CapabilityLane: ProviderSupport]
    /// Evidence clearance per lane.
    public let evidenceClearance: [CapabilityLane: EvidenceClearance]
    /// Contracts this capability depends on.
    public let contracts: [String]
    /// Evidence gates that must pass before promotion.
    public let evidenceGates: [String]
    /// Owner (team or person responsible).
    public let owner: String
    /// Sequencing: which capabilities must be complete before this one.
    public let dependsOn: [String]
    /// Last verified date.
    public let lastVerified: Date?
    /// Notes or caveats.
    public let notes: String?

    public init(
        id: String = UUID().uuidString,
        scope: ProductScope,
        implementation: [CapabilityLane: MaturityLevel],
        providerSupport: [CapabilityLane: ProviderSupport],
        evidenceClearance: [CapabilityLane: EvidenceClearance],
        contracts: [String] = [],
        evidenceGates: [String] = [],
        owner: String = "",
        dependsOn: [String] = [],
        lastVerified: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.scope = scope
        self.implementation = implementation
        self.providerSupport = providerSupport
        self.evidenceClearance = evidenceClearance
        self.contracts = contracts
        self.evidenceGates = evidenceGates
        self.owner = owner
        self.dependsOn = dependsOn
        self.lastVerified = lastVerified
        self.notes = notes
    }

    /// Overall maturity: minimum across all lanes.
    public var overallMaturity: MaturityLevel {
        let levels = implementation.values
        return levels.min(by: { $0 < $1 }) ?? .proposed
    }

    /// Overall evidence: minimum across all lanes.
    public var overallEvidence: EvidenceClearance {
        let levels = evidenceClearance.values
        return levels.min(by: { $0 < $1 }) ?? .none
    }

    /// Whether this capability is ready for user-facing claims.
    public var isClaimReady: Bool {
        overallMaturity >= .complete && overallEvidence >= .integration
    }
}

// MARK: - Capability Maturity Model

/// The full capability maturity model.
public struct CapabilityMaturityModel: Codable, Sendable {
    /// All capability entries.
    public var entries: [CapabilityMaturityEntry]

    public init(entries: [CapabilityMaturityEntry] = []) {
        self.entries = entries
    }

    /// Add or update a capability entry.
    public mutating func upsert(_ entry: CapabilityMaturityEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.append(entry)
        }
    }

    /// Get all capabilities at or above a maturity level.
    public func capabilities(atOrAbove level: MaturityLevel) -> [CapabilityMaturityEntry] {
        entries.filter { $0.overallMaturity >= level }
    }

    /// Get all capabilities with evidence at or above a tier.
    public func capabilities(withEvidenceAtOrAbove tier: EvidenceClearance) -> [CapabilityMaturityEntry] {
        entries.filter { $0.overallEvidence >= tier }
    }

    /// Get capabilities that are claim-ready.
    public var claimReadyCapabilities: [CapabilityMaturityEntry] {
        entries.filter { $0.isClaimReady }
    }

    /// Get capabilities that need work (below complete or below integration evidence).
    public var gaps: [CapabilityMaturityEntry] {
        entries.filter { !$0.isClaimReady }
    }

    /// Summary statistics.
    public var summary: MaturitySummary {
        var byLevel: [MaturityLevel: Int] = [:]
        var byLane: [CapabilityLane: [MaturityLevel: Int]] = [:]
        var byEvidence: [EvidenceClearance: Int] = [:]

        for entry in entries {
            byLevel[entry.overallMaturity, default: 0] += 1
            byEvidence[entry.overallEvidence, default: 0] += 1

            for (lane, level) in entry.implementation {
                byLane[lane, default: [:]][level, default: 0] += 1
            }
        }

        return MaturitySummary(
            totalCapabilities: entries.count,
            claimReady: claimReadyCapabilities.count,
            gaps: gaps.count,
            byLevel: byLevel,
            byLane: byLane,
            byEvidence: byEvidence
        )
    }
}

// MARK: - Maturity Summary

/// Summary statistics for the maturity model.
public struct MaturitySummary: Codable, Sendable {
    public let totalCapabilities: Int
    public let claimReady: Int
    public let gaps: Int
    public let byLevel: [MaturityLevel: Int]
    public let byLane: [CapabilityLane: [MaturityLevel: Int]]
    public let byEvidence: [EvidenceClearance: Int]

    public init(
        totalCapabilities: Int,
        claimReady: Int,
        gaps: Int,
        byLevel: [MaturityLevel: Int],
        byLane: [CapabilityLane: [MaturityLevel: Int]],
        byEvidence: [EvidenceClearance: Int]
    ) {
        self.totalCapabilities = totalCapabilities
        self.claimReady = claimReady
        self.gaps = gaps
        self.byLevel = byLevel
        self.byLane = byLane
        self.byEvidence = byEvidence
    }

    /// Claim-readiness percentage.
    public var claimReadinessPercent: Double {
        totalCapabilities > 0 ? Double(claimReady) / Double(totalCapabilities) * 100 : 0
    }
}
