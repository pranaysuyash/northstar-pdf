import Foundation

/// Value-free input and output contracts for the native/browser reviewed
/// template benchmark. These records intentionally use strings for provider
/// fingerprints and structural kinds so a browser fixture can round-trip
/// without importing PDFKit-specific enums.
public struct PDFTemplateBenchmarkPolicy: Codable, Equatable, Sendable {
    public let familyThreshold: Double
    public let ambiguityMargin: Double
    public let familyAcceptance: String
    public let calibrationStatus: String?

    public init(
        familyThreshold: Double,
        ambiguityMargin: Double,
        familyAcceptance: String = "review",
        calibrationStatus: String? = nil
    ) {
        self.familyThreshold = familyThreshold
        self.ambiguityMargin = ambiguityMargin
        self.familyAcceptance = familyAcceptance
        self.calibrationStatus = calibrationStatus
    }
}

public struct PDFTemplateBenchmarkRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

public struct PDFTemplateBenchmarkRegion: Codable, Equatable, Sendable {
    public let kind: String
    public let suggestedFieldType: String?
    public let normalizedRect: PDFTemplateBenchmarkRect
    public let groupMemberCount: Int
}

public struct PDFTemplateBenchmarkPage: Codable, Equatable, Sendable {
    public let pageIndex: Int
    public let widthPoints: Double
    public let heightPoints: Double
    public let rotationDegrees: Int
    public let nativeFieldKinds: [String]
    public let nativeFieldNameTokens: [String]
    public let anchorTokens: [String]
    public let regionSignatures: [PDFTemplateBenchmarkRegion]
}

public struct PDFTemplateBenchmarkFingerprint: Codable, Equatable, Sendable {
    public let layoutFingerprint: String
    public let exactSourceDigests: [String]
    public let pageSignatures: [PDFTemplateBenchmarkPage]
}

public struct PDFTemplateBenchmarkTemplatePayload: Codable, Equatable, Sendable {
    public let templateID: String
    public let fingerprint: PDFTemplateBenchmarkFingerprint
}

public struct PDFTemplateBenchmarkTemplate: Codable, Equatable, Sendable {
    public let payload: PDFTemplateBenchmarkTemplatePayload
}

public struct PDFTemplateBenchmarkInput: Codable, Equatable, Sendable {
    public let templates: [PDFTemplateBenchmarkTemplate]
    public let fingerprint: PDFTemplateBenchmarkFingerprint
    public let sourceDigest: String
    public let expectedSourceDigest: String?
}

public struct PDFTemplateBenchmarkExpected: Codable, Equatable, Sendable {
    public let state: String
    public let selectedTemplateID: String?
    public let mustNotSelect: Bool?
    public let forbiddenStates: [String]?
}

public struct PDFTemplateBenchmarkFixture: Codable, Equatable, Sendable {
    public let id: String
    public let documentClass: String
    public let input: PDFTemplateBenchmarkInput
    public let expected: PDFTemplateBenchmarkExpected
}

public struct PDFTemplateBenchmarkCorpus: Codable, Equatable, Sendable {
    public let corpusVersion: PDFContractVersion
    public let policyByDocumentClass: [String: PDFTemplateBenchmarkPolicy]
    public let fixtures: [PDFTemplateBenchmarkFixture]
}

public struct PDFTemplateBenchmarkComponents: Codable, Equatable, Sendable {
    public let pageCount: Int
    public let geometry: Double
    public let nativeFields: Double
    public let anchors: Double
    public let regions: Double
}

public struct PDFTemplateBenchmarkCandidateEvidence: Codable, Equatable, Sendable {
    public let templateID: String
    public let state: String
    public let score: Double
    public let reason: String
    public let components: PDFTemplateBenchmarkComponents
}

public struct PDFTemplateBenchmarkMatch: Codable, Equatable, Sendable {
    public let state: String
    public let score: Double
    public let selectedTemplateID: String?
    public let candidates: [PDFTemplateBenchmarkCandidateEvidence]
    public let abstained: Bool
    public let falsePositiveGatePassed: Bool
    public let falsePositiveGateSelected: Bool
    public let documentClass: String
    public let policy: PDFTemplateBenchmarkPolicy
}

public struct PDFTemplateBenchmarkCaseResult: Codable, Equatable, Sendable {
    public let id: String
    public let documentClass: String
    public let expectedState: String
    public let actualState: String
    public let expectedSelectedTemplateID: String?
    public let actualSelectedTemplateID: String?
    public let abstained: Bool
    public let score: Double
    public let candidates: [PDFTemplateBenchmarkCandidateEvidence]
    public let falsePositiveGatePassed: Bool
    public let falsePositiveGateSelected: Bool
    public let policy: PDFTemplateBenchmarkPolicy
    public let passed: Bool
}

public struct PDFTemplateBenchmarkReport: Codable, Equatable, Sendable {
    public let harness: String
    public let version: PDFContractVersion
    public let adapter: String
    public let corpusVersion: PDFContractVersion
    public let fixtureCount: Int
    public let passed: Bool
    public let counts: [String: Int]
    public let cases: [PDFTemplateBenchmarkCaseResult]
}

public enum PDFTemplateBenchmarkMatcher {
    public static let version = PDFContractVersion(major: 1, minor: 0)

    public static func run(
        corpus: PDFTemplateBenchmarkCorpus,
        adapter: String = "native-swift-pdf-editor-core"
    ) -> PDFTemplateBenchmarkReport {
        let results = corpus.fixtures.map { fixture in
            let policy = corpus.policyByDocumentClass[fixture.documentClass]
                ?? PDFTemplateBenchmarkPolicy(familyThreshold: 0.76, ambiguityMargin: 0.05)
            let match = classify(
                input: fixture.input,
                documentClass: fixture.documentClass,
                policy: policy
            )
            let selectedMatches = fixture.expected.selectedTemplateID == nil
                ? true
                : match.selectedTemplateID == fixture.expected.selectedTemplateID
            let forbiddenPasses = !(fixture.expected.forbiddenStates ?? []).contains(match.state)
            let abstentionPasses = fixture.expected.mustNotSelect != true || match.selectedTemplateID == nil
            let passed = match.state == fixture.expected.state
                && selectedMatches
                && forbiddenPasses
                && abstentionPasses
            return PDFTemplateBenchmarkCaseResult(
                id: fixture.id,
                documentClass: fixture.documentClass,
                expectedState: fixture.expected.state,
                actualState: match.state,
                expectedSelectedTemplateID: fixture.expected.selectedTemplateID,
                actualSelectedTemplateID: match.selectedTemplateID,
                abstained: match.selectedTemplateID == nil,
                score: match.score,
                candidates: match.candidates,
                falsePositiveGatePassed: match.falsePositiveGatePassed,
                falsePositiveGateSelected: match.falsePositiveGateSelected,
                policy: match.policy,
                passed: passed
            )
        }
        var counts: [String: Int] = [:]
        for result in results {
            counts[result.actualState, default: 0] += 1
        }
        return PDFTemplateBenchmarkReport(
            harness: "pdf-editor-template-matching-benchmark",
            version: version,
            adapter: adapter,
            corpusVersion: corpus.corpusVersion,
            fixtureCount: results.count,
            passed: results.allSatisfy(\.passed),
            counts: counts,
            cases: results
        )
    }

    public static func classify(
        input: PDFTemplateBenchmarkInput,
        documentClass: String,
        policy: PDFTemplateBenchmarkPolicy
    ) -> PDFTemplateBenchmarkMatch {
        if let expectedSourceDigest = input.expectedSourceDigest,
           expectedSourceDigest != input.sourceDigest {
            return PDFTemplateBenchmarkMatch(
                state: "stale",
                score: 0,
                selectedTemplateID: nil,
                candidates: [],
                abstained: true,
                falsePositiveGatePassed: true,
                falsePositiveGateSelected: false,
                documentClass: documentClass,
                policy: policy
            )
        }

        let ranked = input.templates.map { template in
            let score = score(template.payload.fingerprint, input.fingerprint, policy: policy)
            let exactSource = template.payload.fingerprint.exactSourceDigests.contains(input.sourceDigest)
            let classification: (state: String, score: Double, reason: String)
            if exactSource {
                classification = ("exact", 1, "Reviewed source digest matched.")
            } else if template.payload.fingerprint.layoutFingerprint == input.fingerprint.layoutFingerprint {
                classification = ("knownVariant", 0.9, "Reviewed keyed layout matched a different source digest.")
            } else if policy.familyAcceptance == "disabled" {
                classification = (
                    "noMatch",
                    score.score,
                    "Family matching is disabled for this document class until reviewed calibration exists."
                )
            } else if score.score >= policy.familyThreshold {
                classification = ("familyMatch", score.score, "Structural family evidence exceeded the reviewed threshold.")
            } else {
                classification = ("noMatch", score.score, "No reviewed exact, variant, or family threshold was met.")
            }
            return PDFTemplateBenchmarkCandidateEvidence(
                templateID: template.payload.templateID,
                state: classification.state,
                score: classification.score,
                reason: classification.reason,
                components: score.components
            )
        }.sorted {
            if $0.score == $1.score { return $0.templateID < $1.templateID }
            return $0.score > $1.score
        }

        let viable = ranked.filter { ["exact", "knownVariant", "familyMatch"].contains($0.state) }
        guard let best = viable.first else {
            return PDFTemplateBenchmarkMatch(
                state: "noMatch",
                score: ranked.first?.score ?? 0,
                selectedTemplateID: nil,
                candidates: ranked,
                abstained: true,
                falsePositiveGatePassed: true,
                falsePositiveGateSelected: false,
                documentClass: documentClass,
                policy: policy
            )
        }
        if viable.count > 1,
           best.state != "exact",
           viable[1].state != "exact",
           best.score - viable[1].score < policy.ambiguityMargin {
            return PDFTemplateBenchmarkMatch(
                state: "ambiguous",
                score: best.score,
                selectedTemplateID: nil,
                candidates: viable,
                abstained: true,
                falsePositiveGatePassed: true,
                falsePositiveGateSelected: false,
                documentClass: documentClass,
                policy: policy
            )
        }
        return PDFTemplateBenchmarkMatch(
            state: best.state,
            score: best.score,
            selectedTemplateID: best.templateID,
            candidates: ranked,
            abstained: false,
            falsePositiveGatePassed: true,
            falsePositiveGateSelected: true,
            documentClass: documentClass,
            policy: policy
        )
    }

    private static func score(
        _ left: PDFTemplateBenchmarkFingerprint,
        _ right: PDFTemplateBenchmarkFingerprint,
        policy: PDFTemplateBenchmarkPolicy
    ) -> (score: Double, components: PDFTemplateBenchmarkComponents) {
        let pageCount = left.pageSignatures.count == right.pageSignatures.count ? 1 : 0
        let geometry = pageCount == 1
            ? pageGeometrySimilarity(left.pageSignatures, right.pageSignatures)
            : 0
        var nativeFields = 0.0
        var anchors = 0.0
        var regions = 0.0
        var count = 0
        for (index, page) in left.pageSignatures.enumerated() where index < right.pageSignatures.count {
            let other = right.pageSignatures[index]
            let features = pageFeatureSimilarity(page, other)
            nativeFields += features.nativeFields
            anchors += features.anchors
            regions += features.regions
            count += 1
        }
        let nativeFieldScore = count > 0 ? nativeFields / Double(count) : 0
        let anchorScore = count > 0 ? anchors / Double(count) : 0
        let regionScore = count > 0 ? regions / Double(count) : 0
        let total = clamp(
            geometry * 0.20
                + nativeFieldScore * 0.25
                + anchorScore * 0.25
                + regionScore * 0.30
        )
        return (
            total,
            PDFTemplateBenchmarkComponents(
                pageCount: pageCount,
                geometry: geometry,
                nativeFields: nativeFieldScore,
                anchors: anchorScore,
                regions: regionScore
            )
        )
    }

    private static func pageFeatureSimilarity(
        _ left: PDFTemplateBenchmarkPage,
        _ right: PDFTemplateBenchmarkPage
    ) -> (nativeFields: Double, anchors: Double, regions: Double) {
        let nativeFields = sequenceSimilarity(left.nativeFieldKinds, right.nativeFieldKinds)
        let nativeNames = sequenceSimilarity(left.nativeFieldNameTokens, right.nativeFieldNameTokens)
        return (
            nativeFields * 0.7 + nativeNames * 0.3,
            setSimilarity(left.anchorTokens, right.anchorTokens),
            regionSimilarity(left.regionSignatures, right.regionSignatures)
        )
    }

    private static func pageGeometrySimilarity(
        _ left: [PDFTemplateBenchmarkPage],
        _ right: [PDFTemplateBenchmarkPage]
    ) -> Double {
        guard !left.isEmpty else { return 1 }
        return zip(left, right).reduce(0) { total, pair in
            let widthDelta = abs(pair.0.widthPoints - pair.1.widthPoints)
                / max(max(pair.0.widthPoints, pair.1.widthPoints), 1)
            let heightDelta = abs(pair.0.heightPoints - pair.1.heightPoints)
                / max(max(pair.0.heightPoints, pair.1.heightPoints), 1)
            let rotation = pair.0.rotationDegrees == pair.1.rotationDegrees ? 0.0 : 1.0
            return total + clamp(1 - widthDelta - heightDelta - rotation)
        } / Double(left.count)
    }

    private static func sequenceSimilarity(_ left: [String], _ right: [String]) -> Double {
        guard !left.isEmpty || !right.isEmpty else { return 1 }
        guard !left.isEmpty && !right.isEmpty else { return 0 }
        var table = Array(
            repeating: Array(repeating: 0, count: right.count + 1),
            count: left.count + 1
        )
        for row in 1...left.count {
            for column in 1...right.count {
                table[row][column] = left[row - 1] == right[column - 1]
                    ? table[row - 1][column - 1] + 1
                    : max(table[row - 1][column], table[row][column - 1])
            }
        }
        return Double(2 * table[left.count][right.count]) / Double(left.count + right.count)
    }

    private static func setSimilarity(_ left: [String], _ right: [String]) -> Double {
        let a = Set(left)
        let b = Set(right)
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        guard !a.isEmpty && !b.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    private static func regionSimilarity(
        _ left: [PDFTemplateBenchmarkRegion],
        _ right: [PDFTemplateBenchmarkRegion]
    ) -> Double {
        guard left.count == right.count else {
            return clamp(1 - Double(abs(left.count - right.count)) / Double(max(max(left.count, right.count), 1)))
        }
        guard !left.isEmpty else { return 1 }
        return zip(left, right).reduce(0) { total, pair in
            let rect = pair.0.normalizedRect
            let other = pair.1.normalizedRect
            let geometryDelta = abs(rect.x - other.x)
                + abs(rect.y - other.y)
                + abs(rect.width - other.width)
                + abs(rect.height - other.height)
            let kind = pair.0.kind == pair.1.kind ? 1.0 : 0
            let fieldType = pair.0.suggestedFieldType == pair.1.suggestedFieldType ? 1.0 : 0
            let groupCount = pair.0.groupMemberCount == pair.1.groupMemberCount ? 1.0 : 0
            return total
                + kind * 0.35
                + fieldType * 0.25
                + groupCount * 0.10
                + clamp(1 - geometryDelta) * 0.30
        } / Double(left.count)
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}
