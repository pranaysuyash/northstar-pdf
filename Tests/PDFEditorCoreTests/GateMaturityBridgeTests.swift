import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Gate-Maturity Bridge")
struct GateMaturityBridgeTests {

    @Test("Bridge generates mappings for all 42 capabilities")
    func mapsAllCapabilities() {
        let bridge = GateMaturityBridge()
        let mappings = bridge.mapAll()
        #expect(mappings.count == 42, "Expected 42 mappings, got \(mappings.count)")
    }

    @Test("Every mapping has gate statuses")
    func allHaveGateStatuses() {
        let bridge = GateMaturityBridge()
        let mappings = bridge.mapAll()
        for mapping in mappings {
            #expect(!mapping.gateStatuses.isEmpty,
                    "Mapping for '\(mapping.capabilityName)' has no gate statuses")
        }
    }

    @Test("Recommended status is derived from maturity")
    func recommendedDerivedFromMaturity() {
        let bridge = GateMaturityBridge()

        // A capability with all gates PASS and complete maturity should recommend PASS
        let completeEntry = CapabilityMatrixEntry(
            id: "test-complete",
            capability: "Test Complete",
            scope: ProductScope(name: "Test", userStatement: "", archetype: "", jobID: "", claim: "", claimAccuracy: ""),
            evidenceGates: [
                EvidenceGate(id: "G1", description: "Test", status: .pass),
                EvidenceGate(id: "G2", description: "Test", status: .pass),
            ]
        )
        let mapping = bridge.mapCapability(completeEntry)
        #expect(mapping.recommendedStatus == .pass,
                "Complete capability should recommend PASS, got \(mapping.recommendedStatus.rawValue)")
    }

    @Test("Partial maturity recommends partial")
    func partialRecommendsPartial() {
        let bridge = GateMaturityBridge()

        let partialEntry = CapabilityMatrixEntry(
            id: "test-partial",
            capability: "Test Partial",
            scope: ProductScope(name: "Test", userStatement: "", archetype: "", jobID: "", claim: "", claimAccuracy: ""),
            evidenceGates: [
                EvidenceGate(id: "G1", description: "Test", status: .pass),
                EvidenceGate(id: "G2", description: "Test", status: .partial),
            ]
        )
        let mapping = bridge.mapCapability(partialEntry)
        #expect(mapping.recommendedStatus == .partial,
                "Partial capability should recommend PARTIAL, got \(mapping.recommendedStatus.rawValue)")
    }

    @Test("Summary report has correct statistics")
    func summaryStatistics() {
        let bridge = GateMaturityBridge()
        let report = bridge.summaryReport()

        #expect(report.totalCapabilities == 42)
        #expect(report.consistent + report.inconsistent == 42)
        #expect(report.consistencyPercent >= 0 && report.consistencyPercent <= 100)
    }

    @Test("Markdown export produces valid output")
    func markdownExport() {
        let bridge = GateMaturityBridge()
        let md = bridge.toMarkdown()

        #expect(md.contains("Gate-Maturity Alignment Report"))
        #expect(md.contains("42"))
        #expect(md.contains("Open/Import"))
        #expect(md.contains("Design System"))
    }

    @Test("Inconsistency detection works")
    func inconsistencyDetection() {
        // Create a bridge with a release gate that disagrees with the matrix
        var releaseGates: [String: ReleaseGateEntry] = [:]
        releaseGates["RG-001"] = ReleaseGateEntry(
            id: "RG-001",
            name: "Public AcroForm fidelity",
            lane: "Native/provider",
            status: .pass, // Matrix says .partial — inconsistency
            description: "Test"
        )

        let bridge = GateMaturityBridge(releaseGates: releaseGates)
        let openImport = bridge.matrix.entries.first { $0.id == "cap-01-open-import" }!
        let mapping = bridge.mapCapability(openImport)

        // Should detect the inconsistency
        #expect(!mapping.inconsistencies.isEmpty || !mapping.isConsistent,
                "Should detect inconsistency between matrix and release gate")
    }

    @Test("ReleaseGateStatus ordering")
    func statusOrdering() {
        #expect(ReleaseGateStatus.fail < .blocked)
        #expect(ReleaseGateStatus.blocked < .open)
        #expect(ReleaseGateStatus.open < .partial)
        #expect(ReleaseGateStatus.partial < .pass)
    }

    @Test("MaturityLevel ordering")
    func maturityOrdering() {
        #expect(MaturityLevel.proposed < .prototype)
        #expect(MaturityLevel.prototype < .partial)
        #expect(MaturityLevel.partial < .complete)
        #expect(MaturityLevel.complete < .hardened)
    }

    @Test("All gate IDs in matrix are valid format")
    func validGateIDs() {
        let bridge = GateMaturityBridge()
        let mappings = bridge.mapAll()
        for mapping in mappings {
            for gateID in mapping.gateStatuses.keys {
                #expect(gateID.hasPrefix("RG-") || gateID.hasPrefix("G"),
                        "Gate ID '\(gateID)' in '\(mapping.capabilityName)' has invalid format")
            }
        }
    }

    @Test("No capability has all gates failing")
    func noAllFailCapabilities() {
        let bridge = GateMaturityBridge()
        let mappings = bridge.mapAll()
        for mapping in mappings {
            let allFail = mapping.gateStatuses.values.allSatisfy { $0 == .fail }
            #expect(!allFail,
                    "Capability '\(mapping.capabilityName)' has all gates FAIL — should be removed or fixed")
        }
    }
}
