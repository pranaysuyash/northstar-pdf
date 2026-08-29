import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - False Positive Report Tests

@Suite("Calibration — False Positive Report")
struct FalsePositiveReportTests {

    @Test("No hard negatives produces empty report")
    func emptyReport() {
        let generator = FalsePositiveReportGenerator()
        let corpus: [CorpusEntry] = [
            CorpusEntry(sourceDigest: "d1", layoutFingerprint: "fp1", expectedTier: .exact, documentClass: "form")
        ]
        let templates: [String: (fingerprint: String, sourceDigest: String)] = [
            "tpl-1": (fingerprint: "fp1", sourceDigest: "d1")
        ]
        let calibrator = RecurringFormCalibrator()
        let report = calibrator.calibrate(corpus: corpus, templates: templates)

        let fpReport = generator.generate(from: report, corpus: corpus)
        #expect(fpReport.totalHardNegatives == 0)
        #expect(fpReport.falsePositiveCount == 0)
        #expect(fpReport.falsePositiveRate == 0)
        #expect(fpReport.passesThreshold)
    }

    @Test("Hard negative that doesn't match passes threshold")
    func hardNegativeRejected() {
        let generator = FalsePositiveReportGenerator()
        let corpus: [CorpusEntry] = [
            CorpusEntry(
                sourceDigest: "hard-neg-1",
                layoutFingerprint: "fp-completely-different",
                expectedTier: .noMatch,
                isHardNegative: true,
                documentClass: "invoice"
            )
        ]
        let templates: [String: (fingerprint: String, sourceDigest: String)] = [
            "tpl-1": (fingerprint: "fp-aaa", sourceDigest: "digest-111")
        ]
        let calibrator = RecurringFormCalibrator()
        let report = calibrator.calibrate(corpus: corpus, templates: templates)

        let fpReport = generator.generate(from: report, corpus: corpus)
        #expect(fpReport.totalHardNegatives == 1)
        #expect(fpReport.falsePositiveCount == 0)
        #expect(fpReport.passesThreshold)
    }

    @Test("Calibration report has recommendations")
    func hasRecommendations() {
        let generator = FalsePositiveReportGenerator()
        let corpus: [CorpusEntry] = [
            CorpusEntry(sourceDigest: "d1", layoutFingerprint: "fp1", expectedTier: .exact, documentClass: "form")
        ]
        let templates: [String: (fingerprint: String, sourceDigest: String)] = [
            "tpl-1": (fingerprint: "fp1", sourceDigest: "d1")
        ]
        let calibrator = RecurringFormCalibrator()
        let report = calibrator.calibrate(corpus: corpus, templates: templates)

        let fpReport = generator.generate(from: report, corpus: corpus)
        #expect(!fpReport.recommendations.isEmpty)
    }
}

// MARK: - Capability Maturity Model Tests

@Suite("Capability Maturity Model")
struct CapabilityMaturityModelTests {

    @Test("MaturityLevel ordering")
    func maturityOrdering() {
        #expect(MaturityLevel.proposed < .prototype)
        #expect(MaturityLevel.prototype < .partial)
        #expect(MaturityLevel.partial < .complete)
        #expect(MaturityLevel.complete < .hardened)
        #expect(!(MaturityLevel.hardened < .proposed))
    }

    @Test("EvidenceClearance ordering")
    func evidenceOrdering() {
        #expect(EvidenceClearance.none < .staticInspection)
        #expect(EvidenceClearance.staticInspection < .targetedTest)
        #expect(EvidenceClearance.targetedTest < .integration)
        #expect(EvidenceClearance.integration < .liveRuntime)
        #expect(EvidenceClearance.liveRuntime < .production)
    }

    @Test("Capability is not claim-ready when immature")
    func notClaimReady() {
        let entry = CapabilityMaturityEntry(
            scope: ProductScope(
                name: "Search",
                userStatement: "I need to find text",
                archetype: "Reader",
                jobID: "J02",
                claim: "Supported",
                claimAccuracy: "Verified"
            ),
            implementation: [.native: .partial],
            providerSupport: [.native: .supported],
            evidenceClearance: [.native: .targetedTest]
        )
        #expect(!entry.isClaimReady)
        #expect(entry.overallMaturity == .partial)
    }

    @Test("Capability is claim-ready when complete with integration evidence")
    func claimReady() {
        let entry = CapabilityMaturityEntry(
            scope: ProductScope(
                name: "Search",
                userStatement: "I need to find text",
                archetype: "Reader",
                jobID: "J02",
                claim: "Supported",
                claimAccuracy: "Verified"
            ),
            implementation: [.native: .complete, .browser: .complete],
            providerSupport: [.native: .supported, .browser: .supported],
            evidenceClearance: [.native: .integration, .browser: .integration]
        )
        #expect(entry.isClaimReady)
        #expect(entry.overallMaturity == .complete)
    }

    @Test("Model tracks capabilities by level")
    func trackByLevel() {
        var model = CapabilityMaturityModel()
        model.upsert(CapabilityMaturityEntry(
            scope: ProductScope(name: "A", userStatement: "A", archetype: "R", jobID: "J1", claim: "", claimAccuracy: "Proposed"),
            implementation: [.native: .complete],
            providerSupport: [:],
            evidenceClearance: [:]
        ))
        model.upsert(CapabilityMaturityEntry(
            scope: ProductScope(name: "B", userStatement: "B", archetype: "R", jobID: "J2", claim: "", claimAccuracy: "Proposed"),
            implementation: [.native: .proposed],
            providerSupport: [:],
            evidenceClearance: [:]
        ))

        #expect(model.capabilities(atOrAbove: .complete).count == 1)
        #expect(model.capabilities(atOrAbove: .proposed).count == 2)
        // Both are gaps because isClaimReady requires both maturity >= complete AND evidence >= integration
        #expect(model.gaps.count == 2)
    }

    @Test("Summary statistics are correct")
    func summaryStats() {
        var model = CapabilityMaturityModel()
        model.upsert(CapabilityMaturityEntry(
            scope: ProductScope(name: "A", userStatement: "A", archetype: "R", jobID: "J1", claim: "", claimAccuracy: "Proposed"),
            implementation: [.native: .complete, .browser: .partial],
            providerSupport: [:],
            evidenceClearance: [.native: .integration, .browser: .targetedTest]
        ))

        let summary = model.summary
        #expect(summary.totalCapabilities == 1)
        #expect(summary.claimReady == 0) // browser is partial
        #expect(summary.gaps == 1)
    }
}

// MARK: - Canonical Capability Matrix Tests

@Suite("Canonical Capability Matrix")
struct CanonicalCapabilityMatrixTests {

    @Test("Matrix tracks capabilities per provider")
    func providerTracking() {
        var matrix = CanonicalCapabilityMatrix()
        matrix.upsert(CapabilityMatrixEntry(
            capability: "Open/Import",
            scope: ProductScope(name: "Open", userStatement: "Open PDF", archetype: "Reader", jobID: "J01", claim: "Supported", claimAccuracy: "Verified"),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported),
            ]
        ))

        #expect(matrix.capabilities(providedBy: "PDFKit").count == 1)
        #expect(matrix.capabilities(providedBy: "PDF.js").count == 1)
        #expect(matrix.capabilities(providedBy: "NonExistent").count == 0)
    }

    @Test("Matrix tracks capabilities per lane")
    func laneTracking() {
        var matrix = CanonicalCapabilityMatrix()
        matrix.upsert(CapabilityMatrixEntry(
            capability: "Search",
            scope: ProductScope(name: "Search", userStatement: "Find text", archetype: "Reader", jobID: "J02", claim: "Supported", claimAccuracy: "Verified"),
            providers: [
                ProviderEntry(providerName: "PDFKit", lane: .native, support: .supported),
                ProviderEntry(providerName: "PDF.js", lane: .browser, support: .supported),
            ]
        ))

        #expect(matrix.capabilities(in: .native).count == 1)
        #expect(matrix.capabilities(in: .browser).count == 1)
        #expect(matrix.capabilities(in: .companion).count == 0)
    }

    @Test("Gate pass/fail tracking")
    func gateTracking() {
        var matrix = CanonicalCapabilityMatrix()
        matrix.upsert(CapabilityMatrixEntry(
            capability: "OCR",
            scope: ProductScope(name: "OCR", userStatement: "Extract text from images", archetype: "Reader", jobID: "J03", claim: "Experimental", claimAccuracy: "Inferred"),
            evidenceGates: [
                EvidenceGate(id: "G1", description: "Unit test", status: .pass),
                EvidenceGate(id: "G2", description: "Integration test", status: .open),
            ]
        ))

        let entry = matrix.entries[0]
        #expect(!entry.allGatesPass)
        #expect(entry.gateSummary == "1/2 gates pass")
    }

    @Test("Sequencing respects dependencies")
    func sequencing() {
        var matrix = CanonicalCapabilityMatrix()
        let entryA = CapabilityMatrixEntry(
            id: "A",
            capability: "Foundation",
            scope: ProductScope(name: "A", userStatement: "", archetype: "", jobID: "", claim: "", claimAccuracy: ""),
            dependsOn: [],
            sequencePriority: 10
        )
        let entryB = CapabilityMatrixEntry(
            id: "B",
            capability: "Advanced",
            scope: ProductScope(name: "B", userStatement: "", archetype: "", jobID: "", claim: "", claimAccuracy: ""),
            dependsOn: ["A"],
            sequencePriority: 20
        )

        matrix.upsert(entryB)
        matrix.upsert(entryA)

        let sequenced = matrix.sequenced
        #expect(sequenced.first?.capability == "Foundation")
        #expect(sequenced.last?.capability == "Advanced")
    }

    @Test("Summary statistics are correct")
    func summaryStats() {
        var matrix = CanonicalCapabilityMatrix()
        matrix.upsert(CapabilityMatrixEntry(
            capability: "A",
            scope: ProductScope(name: "A", userStatement: "", archetype: "", jobID: "", claim: "", claimAccuracy: ""),
            providers: [ProviderEntry(providerName: "PDFKit", lane: .native, support: .supported)],
            evidenceGates: [EvidenceGate(id: "G1", description: "Test", status: .pass)]
        ))
        matrix.upsert(CapabilityMatrixEntry(
            capability: "B",
            scope: ProductScope(name: "B", userStatement: "", archetype: "", jobID: "", claim: "", claimAccuracy: ""),
            providers: [ProviderEntry(providerName: "PDF.js", lane: .browser, support: .conditional)],
            evidenceGates: [EvidenceGate(id: "G2", description: "Test", status: .open)]
        ))

        let summary = matrix.summary
        #expect(summary.totalCapabilities == 2)
        #expect(summary.claimReady == 1)
        #expect(summary.needsWork == 1)
        #expect(summary.totalGates == 2)
        #expect(summary.passingGates == 1)
        #expect(summary.gatePassRate == 0.5)
    }

    @Test("Markdown export produces valid table")
    func markdownExport() {
        var matrix = CanonicalCapabilityMatrix()
        matrix.upsert(CapabilityMatrixEntry(
            capability: "Open",
            scope: ProductScope(name: "Open", userStatement: "", archetype: "", jobID: "", claim: "Supported", claimAccuracy: "Verified"),
            providers: [ProviderEntry(providerName: "PDFKit", lane: .native, support: .primary)],
            evidenceGates: [EvidenceGate(id: "G1", description: "Test", status: .pass)]
        ))

        let md = matrix.toMarkdown()
        #expect(md.contains("| Open |"))
        #expect(md.contains("PDFKit: primary"))
        #expect(md.contains("1/1 gates pass"))
    }

    @Test("CapabilityMatrixEntry claim readiness")
    func claimReadiness() {
        let ready = CapabilityMatrixEntry(
            capability: "Search",
            scope: ProductScope(name: "Search", userStatement: "", archetype: "", jobID: "", claim: "", claimAccuracy: ""),
            evidenceGates: [
                EvidenceGate(id: "G1", description: "Test", status: .pass),
                EvidenceGate(id: "G2", description: "Test", status: .waived),
            ]
        )
        #expect(ready.allGatesPass)

        let notReady = CapabilityMatrixEntry(
            capability: "OCR",
            scope: ProductScope(name: "OCR", userStatement: "", archetype: "", jobID: "", claim: "", claimAccuracy: ""),
            evidenceGates: [
                EvidenceGate(id: "G1", description: "Test", status: .pass),
                EvidenceGate(id: "G2", description: "Test", status: .open),
            ]
        )
        #expect(!notReady.allGatesPass)
    }
}
