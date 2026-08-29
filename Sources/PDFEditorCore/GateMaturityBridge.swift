import Foundation

/// Bridge between CapabilityMaturityModel and release-gates.md.
///
/// Maps capability evidence gates to release gate statuses and generates
/// recommendations for gate promotion based on capability maturity.
///
/// First principle: gate status should be derivable from capability maturity.
/// If a capability's gates are all PASS, the corresponding release gates
/// should be PASS. If any gate is PARTIAL, the release gate should be PARTIAL.
/// This prevents manual gate manipulation from diverging from actual maturity.
///
/// Doctrine alignment:
/// - §5: Evidence-based — gate status derived from evidence, not claims
/// - §11: Engineering integrity — automated consistency checking
/// - §13: Product reality — gate status matches implementation

// MARK: - Gate Status (release gate side)

/// Release gate status (matches release-gates.md vocabulary).
public enum ReleaseGateStatus: String, Codable, Sendable, CaseIterable, Comparable {
    case pass = "PASS"
    case partial = "PARTIAL"
    case open = "OPEN"
    case blocked = "BLOCKED"
    case fail = "FAIL"

    public static func < (lhs: ReleaseGateStatus, rhs: ReleaseGateStatus) -> Bool {
        let order: [ReleaseGateStatus] = [.fail, .blocked, .open, .partial, .pass]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: - Gate Entry (release gate side)

/// A single release gate entry from release-gates.md.
public struct ReleaseGateEntry: Codable, Sendable, Identifiable {
    public let id: String // e.g., "RG-001"
    public let name: String
    public let lane: String
    public var status: ReleaseGateStatus
    public let description: String

    public init(id: String, name: String, lane: String, status: ReleaseGateStatus, description: String = "") {
        self.id = id
        self.name = name
        self.lane = lane
        self.status = status
        self.description = description
    }
}

// MARK: - Gate-Maturity Mapping

/// Maps a capability's evidence gates to release gate statuses.
public struct GateMaturityMapping: Codable, Sendable {
    /// The capability ID.
    public let capabilityID: String
    /// The capability name.
    public let capabilityName: String
    /// The capability's overall maturity.
    public let maturity: MaturityLevel
    /// The capability's overall evidence clearance.
    public let evidence: EvidenceClearance
    /// Mapped release gate statuses.
    public let gateStatuses: [String: ReleaseGateStatus]
    /// Recommended release gate status based on maturity.
    public let recommendedStatus: ReleaseGateStatus
    /// Whether the current release gate status matches the recommendation.
    public let isConsistent: Bool
    /// Inconsistencies found.
    public let inconsistencies: [String]

    public init(
        capabilityID: String,
        capabilityName: String,
        maturity: MaturityLevel,
        evidence: EvidenceClearance,
        gateStatuses: [String: ReleaseGateStatus],
        recommendedStatus: ReleaseGateStatus,
        isConsistent: Bool,
        inconsistencies: [String]
    ) {
        self.capabilityID = capabilityID
        self.capabilityName = capabilityName
        self.maturity = maturity
        self.evidence = evidence
        self.gateStatuses = gateStatuses
        self.recommendedStatus = recommendedStatus
        self.isConsistent = isConsistent
        self.inconsistencies = inconsistencies
    }
}

// MARK: - Gate Maturity Bridge

/// Bridges capability maturity to release gate status.
public struct GateMaturityBridge: Sendable {
    /// The populated capability matrix.
    public let matrix: CanonicalCapabilityMatrix
    /// Known release gate statuses (from release-gates.md).
    public let releaseGates: [String: ReleaseGateEntry]

    public init(
        matrix: CanonicalCapabilityMatrix = CanonicalCapabilityMatrix.populate(),
        releaseGates: [String: ReleaseGateEntry] = [:]
    ) {
        self.matrix = matrix
        self.releaseGates = releaseGates
    }

    // MARK: - Mapping

    /// Generate maturity-to-gate mappings for all capabilities.
    public func mapAll() -> [GateMaturityMapping] {
        matrix.entries.map { mapCapability($0) }
    }

    /// Map a single capability's gates to release gate statuses.
    public func mapCapability(_ entry: CapabilityMatrixEntry) -> GateMaturityMapping {
        var gateStatuses: [String: ReleaseGateStatus] = [:]
        var inconsistencies: [String] = []

        for gate in entry.evidenceGates {
            let releaseStatus: ReleaseGateStatus
            switch gate.status {
            case .pass: releaseStatus = .pass
            case .partial: releaseStatus = .partial
            case .open: releaseStatus = .open
            case .waived: releaseStatus = .pass // waived = treated as pass
            case .fail: releaseStatus = .fail
            }
            gateStatuses[gate.id] = releaseStatus

            // Check consistency with release-gates.md
            if let releaseGate = releaseGates[gate.id] {
                if releaseGate.status != releaseStatus {
                    inconsistencies.append(
                        "\(gate.id): matrix says \(releaseStatus.rawValue), release-gates says \(releaseGate.status.rawValue)"
                    )
                }
            }
        }

        // Derive recommended status from capability maturity
        let recommendedStatus = deriveRecommendedStatus(from: entry)

        // Check overall consistency
        let isConsistent = inconsistencies.isEmpty && recommendedStatus == currentOverallStatus(entry)

        return GateMaturityMapping(
            capabilityID: entry.id,
            capabilityName: entry.capability,
            maturity: entry.overallMaturity,
            evidence: entry.overallEvidence,
            gateStatuses: gateStatuses,
            recommendedStatus: recommendedStatus,
            isConsistent: isConsistent,
            inconsistencies: inconsistencies
        )
    }

    // MARK: - Recommendations

    /// Derive recommended release gate status from capability maturity.
    public func deriveRecommendedStatus(from entry: CapabilityMatrixEntry) -> ReleaseGateStatus {
        let maturity = entry.overallMaturity
        let evidence = entry.overallEvidence
        let allGatesPass = entry.allGatesPass

        if allGatesPass && maturity >= .complete && evidence >= .integration {
            return .pass
        } else if maturity >= .partial || evidence >= .targetedTest {
            return .partial
        } else if maturity >= .prototype {
            return .open
        } else {
            return .open
        }
    }

    /// Get the current overall status from a capability's gates.
    private func currentOverallStatus(_ entry: CapabilityMatrixEntry) -> ReleaseGateStatus {
        if entry.allGatesPass {
            return .pass
        } else if entry.evidenceGates.contains(where: { $0.status == .fail }) {
            return .fail
        } else if entry.evidenceGates.contains(where: { $0.status == .partial }) {
            return .partial
        } else {
            return .open
        }
    }

    // MARK: - Summary

    /// Generate a summary report of all mappings.
    public func summaryReport() -> GateMaturityReport {
        let mappings = mapAll()
        let consistent = mappings.filter { $0.isConsistent }.count
        let inconsistent = mappings.filter { !$0.isConsistent }.count
        let allInconsistencies = mappings.flatMap { $0.inconsistencies }

        var byRecommended: [ReleaseGateStatus: Int] = [:]
        for mapping in mappings {
            byRecommended[mapping.recommendedStatus, default: 0] += 1
        }

        var byMaturity: [MaturityLevel: Int] = [:]
        for mapping in mappings {
            byMaturity[mapping.maturity, default: 0] += 1
        }

        return GateMaturityReport(
            totalCapabilities: mappings.count,
            consistent: consistent,
            inconsistent: inconsistent,
            inconsistencies: allInconsistencies,
            byRecommendedStatus: byRecommended,
            byMaturity: byMaturity,
            mappings: mappings
        )
    }

    // MARK: - Markdown Export

    /// Export gate-maturity alignment as markdown.
    public func toMarkdown() -> String {
        let report = summaryReport()
        var md = "# Gate-Maturity Alignment Report\n\n"
        md += "**Date:** \(Date().ISO8601Format())\n"
        md += "**Capabilities:** \(report.totalCapabilities)\n"
        md += "**Consistent:** \(report.consistent)\n"
        md += "**Inconsistent:** \(report.inconsistent)\n\n"

        if !report.inconsistencies.isEmpty {
            md += "## Inconsistencies\n\n"
            for inc in report.inconsistencies {
                md += "- ⚠️ \(inc)\n"
            }
            md += "\n"
        }

        md += "## Capability → Gate Mapping\n\n"
        md += "| Capability | Maturity | Evidence | Gates | Recommended | Consistent |\n"
        md += "|---|---|---|---|---|---|\n"

        for mapping in report.mappings.sorted(by: { $0.recommendedStatus > $1.recommendedStatus }) {
            let gates = mapping.gateStatuses.map { "\($0.key): \($0.value.rawValue)" }.joined(separator: ", ")
            let status = mapping.isConsistent ? "✅" : "⚠️"
            md += "| \(mapping.capabilityName) | \(mapping.maturity.rawValue) | \(mapping.evidence.rawValue) | \(gates) | \(mapping.recommendedStatus.rawValue) | \(status) |\n"
        }

        return md
    }
}

// MARK: - Gate Maturity Report

/// Summary report of gate-maturity alignment.
public struct GateMaturityReport: Codable, Sendable {
    public let totalCapabilities: Int
    public let consistent: Int
    public let inconsistent: Int
    public let inconsistencies: [String]
    public let byRecommendedStatus: [ReleaseGateStatus: Int]
    public let byMaturity: [MaturityLevel: Int]
    public let mappings: [GateMaturityMapping]

    public init(
        totalCapabilities: Int,
        consistent: Int,
        inconsistent: Int,
        inconsistencies: [String],
        byRecommendedStatus: [ReleaseGateStatus: Int],
        byMaturity: [MaturityLevel: Int],
        mappings: [GateMaturityMapping]
    ) {
        self.totalCapabilities = totalCapabilities
        self.consistent = consistent
        self.inconsistent = inconsistent
        self.inconsistencies = inconsistencies
        self.byRecommendedStatus = byRecommendedStatus
        self.byMaturity = byMaturity
        self.mappings = mappings
    }

    /// Consistency percentage.
    public var consistencyPercent: Double {
        totalCapabilities > 0 ? Double(consistent) / Double(totalCapabilities) * 100 : 0
    }
}
