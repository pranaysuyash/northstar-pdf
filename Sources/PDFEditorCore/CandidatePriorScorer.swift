import Foundation

// MARK: - Review Priors (R6 Stage 1)
//
// Closes the learning loop opened by CandidateReviewLearningEvents: past
// human decisions on a document shape how its remaining suggestions are
// ranked. Priors bias *presentation order and traversal*, never contract
// scores, review requirements, or permissions.

/// Aggregated accept/reject counts keyed by the structural factors a
/// candidate exhibits. Counts are value-free by construction — they come
/// only from `CandidateReviewLearningEvent`.
public struct CandidatePriors: Equatable, Sendable {
    public struct FactorCounts: Equatable, Sendable {
        public var confirmed: Int = 0
        public var rejected: Int = 0

        public var total: Int { confirmed + rejected }
        public var acceptanceRate: Double {
            total == 0 ? 0.5 : Double(confirmed) / Double(total)
        }

        public init() {}
    }

    public var byEntryMode: [CandidateEntryMode: FactorCounts] = [:]
    public var byFieldType: [SuggestedFieldType: FactorCounts] = [:]
    public var byDetectionKind: [CandidateKind: FactorCounts] = [:]
    /// Total terminal decisions observed for this source.
    public let sampleCount: Int

    /// Decisions below this count carry no signal; the ranker stays neutral.
    public static let minimumSamplesForSignal = 3

    public init(sampleCount: Int) {
        self.sampleCount = sampleCount
    }

    /// Builds priors from a journal of value-free events.
    public init(events: [CandidateReviewLearningEvent]) {
        var entryModes: [CandidateEntryMode: FactorCounts] = [:]
        var fieldTypes: [SuggestedFieldType: FactorCounts] = [:]
        var kinds: [CandidateKind: FactorCounts] = [:]
        var terminal = 0

        for event in events {
            // Only terminal human decisions teach the ranker.
            let accepted: Bool?
            switch event.decision {
            case .confirmed: accepted = true
            case .rejected: accepted = false
            case .moved, .resized, .retyped, .manuallyCreated: accepted = nil
            }
            guard let accepted else { continue }
            terminal += 1

            func record<T: Hashable>(_ key: T, in table: inout [T: FactorCounts]) {
                var counts = table[key] ?? FactorCounts()
                if accepted { counts.confirmed += 1 } else { counts.rejected += 1 }
                table[key] = counts
            }
            record(event.entryMode, in: &entryModes)
            if let fieldType = event.suggestedFieldType {
                record(fieldType, in: &fieldTypes)
            }
            record(event.kind, in: &kinds)
        }

        self.byEntryMode = entryModes
        self.byFieldType = fieldTypes
        self.byDetectionKind = kinds
        self.sampleCount = terminal
    }

    public var hasSignal: Bool { sampleCount >= Self.minimumSamplesForSignal }

    /// Acceptance rate for one factor with Laplace smoothing toward neutral,
    /// so one lucky confirm cannot dominate.
    func smoothedRate(_ counts: FactorCounts?) -> Double {
        guard let counts, counts.total > 0 else { return 0.5 }
        // Beta(2,2) prior: pseudo-confirm + pseudo-reject.
        return Double(counts.confirmed + 1) / Double(counts.total + 2)
    }

    /// Combined prior multiplier in [0.6, 1.4] for a candidate's factors.
    /// Neutral (1.0) when no signal exists.
    public func multiplier(
        entryMode: CandidateEntryMode,
        fieldType: SuggestedFieldType?,
        detectionKind: CandidateKind
    ) -> Double {
        guard hasSignal else { return 1.0 }
        let rates = [
            smoothedRate(byEntryMode[entryMode]),
            smoothedRate(fieldType.flatMap { byFieldType[$0] }),
            smoothedRate(byDetectionKind[detectionKind]),
        ]
        // Geometric mean keeps any single factor from dominating.
        let product = rates.reduce(1.0, *)
        let mean = pow(product, 1.0 / Double(rates.count))
        return min(1.4, max(0.6, mean / 0.5 * 0.5 + 0.5))
    }

    /// Prior-adjusted ranking score in [0, 1]. The base score is never
    /// mutated; this exists for ordering only.
    public func adjustedScore(for candidate: RegionCandidate) -> Double {
        let multiplier = multiplier(
            entryMode: candidate.entryMode,
            fieldType: candidate.suggestedFieldType,
            detectionKind: candidate.kind
        )
        return min(1.0, max(0.0, candidate.score * multiplier))
    }
}
