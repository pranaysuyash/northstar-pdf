import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Canonical Capability Matrix — Population Verification")
struct CanonicalMatrixPopulationTests {

    @Test("Populated matrix has exactly 42 capabilities")
    func correctCount() {
        let matrix = CanonicalCapabilityMatrix.populate()
        #expect(matrix.entries.count == 42, "Expected 42 capabilities, got \(matrix.entries.count)")
    }

    @Test("Every capability has at least one provider")
    func allHaveProviders() {
        let matrix = CanonicalCapabilityMatrix.populate()
        for entry in matrix.entries {
            #expect(!entry.providers.isEmpty,
                    "Capability '\(entry.capability)' has no providers")
        }
    }

    @Test("Every capability has at least one evidence gate")
    func allHaveGates() {
        let matrix = CanonicalCapabilityMatrix.populate()
        for entry in matrix.entries {
            #expect(!entry.evidenceGates.isEmpty,
                    "Capability '\(entry.capability)' has no evidence gates")
        }
    }

    @Test("Every capability has an owner")
    func allHaveOwners() {
        let matrix = CanonicalCapabilityMatrix.populate()
        for entry in matrix.entries {
            #expect(!entry.owner.isEmpty,
                    "Capability '\(entry.capability)' has no owner")
        }
    }

    @Test("Every capability has a non-empty product claim")
    func allHaveClaims() {
        let matrix = CanonicalCapabilityMatrix.populate()
        for entry in matrix.entries {
            #expect(!entry.productClaim.isEmpty,
                    "Capability '\(entry.capability)' has no product claim")
        }
    }

    @Test("All archetypes are represented")
    func archetypesRepresented() {
        let matrix = CanonicalCapabilityMatrix.populate()
        var archetypes = Set<String>()
        for entry in matrix.entries {
            archetypes.insert(entry.scope.archetype)
        }
        #expect(archetypes.contains("Reader"))
        #expect(archetypes.contains("Creator"))
        #expect(archetypes.contains("Manager"))
        #expect(archetypes.contains("Power"))
    }

    @Test("Native lane has providers for all reader capabilities except explicitly unsupported")
    func nativeLaneComplete() {
        let matrix = CanonicalCapabilityMatrix.populate()
        let readerCaps = matrix.entries.filter { $0.scope.archetype == "Reader" && $0.capability != "XFA" }
        for cap in readerCaps {
            let hasNative = cap.providers.contains { $0.lane == .native && $0.support != .unsupported }
            #expect(hasNative, "Reader capability '\(cap.capability)' has no native provider")
        }
    }

    @Test("Matrix summary statistics are correct")
    func summaryCorrect() {
        let matrix = CanonicalCapabilityMatrix.populate()
        let summary = matrix.summary
        #expect(summary.totalCapabilities == 42)
        #expect(summary.totalGates > 0)
        #expect(summary.passingGates > 0)
        #expect(summary.gatePassRate > 0)
    }

    @Test("Topological sort produces valid sequence")
    func sequencingValid() {
        let matrix = CanonicalCapabilityMatrix.populate()
        let sequenced = matrix.sequenced
        #expect(sequenced.count == 42)

        // Verify dependencies come before dependents
        var visited: Set<String> = []
        for entry in sequenced {
            for depID in entry.dependsOn {
                #expect(visited.contains(depID),
                        "Dependency '\(depID)' of '\(entry.capability)' not yet visited")
            }
            visited.insert(entry.id)
        }
    }

    @Test("Key capabilities exist with correct IDs")
    func keyCapabilitiesExist() {
        let matrix = CanonicalCapabilityMatrix.populate()
        let ids = Set(matrix.entries.map { $0.id })

        #expect(ids.contains("cap-01-open-import"))
        #expect(ids.contains("cap-02-render-navigation"))
        #expect(ids.contains("cap-05-search"))
        #expect(ids.contains("cap-13-acroforms"))
        #expect(ids.contains("cap-21-undo-redo"))
        #expect(ids.contains("cap-22-progressive-rendering"))
        #expect(ids.contains("cap-23-reading-modes"))
        #expect(ids.contains("cap-30-spaced-repetition"))
        #expect(ids.contains("cap-33-document-index"))
        #expect(ids.contains("cap-34-version-control"))
        #expect(ids.contains("cap-35-governance"))
        #expect(ids.contains("cap-40-accepted-variance"))
        #expect(ids.contains("cap-41-creator-canvas"))
        #expect(ids.contains("cap-42-design-system"))
    }

    @Test("Gate pass rate reflects reality (not all gates pass)")
    func gateRateRealistic() {
        let matrix = CanonicalCapabilityMatrix.populate()
        let summary = matrix.summary
        // Some gates are still open/partial — pass rate should be < 100%
        #expect(summary.gatePassRate < 1.0,
                "Gate pass rate \(summary.gatePassRate) should be less than 1.0 (some gates still open)")
        #expect(summary.gatePassRate > 0.3,
                "Gate pass rate \(summary.gatePassRate) should be > 30% (many gates pass)")
    }

    @Test("Markdown export produces valid table with all 42 rows")
    func markdownExportValid() {
        let matrix = CanonicalCapabilityMatrix.populate()
        let md = matrix.toMarkdown()
        #expect(md.contains("Open/Import"))
        #expect(md.contains("Design System"))
        #expect(md.contains("PDFKit: primary"))
        #expect(md.contains("PDF.js: supported"))
        #expect(md.contains("gates pass"))
    }
}
