import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Tests for independent control-viewer observation workflow.
@Suite("Control Viewer Observation")
struct ControlViewerObservationTests {
    
    private static let corpus = "\(TestRepoRoot.prefix)benchmark/results"
    
    @Test("Observation runs against real PDF")
    func observationRuns() {
        let pdfPath = "\(Self.corpus)/public-sample-form.pdf"
        let report = ControlViewerObservation.observe(pdfPath: pdfPath)
        
        // 5 PDFKit + 5 Poppler + 5 DualEngine + 1 HumanReviewer = 16 observations
        #expect(report.observations.count == 16)
        #expect(report.overallPassed)
        print("[control-viewer] \(report.summary)")
        
        for obs in report.observations {
            let s = obs.passed ? "✅" : "❌"
            print("[control-viewer] \(s) \(obs.tool) \(obs.type.rawValue): \(obs.description)")
        }
    }
    
    @Test("Observation catches invalid PDF")
    func observationCatchesInvalid() {
        let report = ControlViewerObservation.observe(pdfPath: "/nonexistent.pdf")
        #expect(report.observations.first?.passed == false || !report.overallPassed)
    }
    
    @Test("Observation report is Codable")
    func reportCodable() {
        let pdfPath = "\(Self.corpus)/public-sample-form.pdf"
        let report = ControlViewerObservation.observe(pdfPath: pdfPath)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try! encoder.encode(report)
        let decoded = try! JSONDecoder().decode(ViewerObservationReport.self, from: data)
        
        #expect(decoded.sourcePath == report.sourcePath)
        #expect(decoded.observations.count == report.observations.count)
    }
    
    @Test("Observation types cover all dimensions")
    func observationTypesComplete() {
        let allTypes = ViewerObservationType.allCases
        #expect(allTypes.count == 6)
        #expect(allTypes.contains(.reopen))
        #expect(allTypes.contains(.rotation))
        #expect(allTypes.contains(.visualFidelity))
        #expect(allTypes.contains(.formVisibility))
        #expect(allTypes.contains(.textReadability))
        #expect(allTypes.contains(.humanVisualConfirm))
    }
}
