import Foundation
import Testing
@testable import PDFEditorCore

/// RG-131: Control-viewer observation pre-release gate.
///
/// These tests enforce the gate semantics:
/// - Every governed fixture must pass all 5 observation dimensions
/// - Any single observation failure = gate FAIL (fail closed)
/// - Zero fixtures = gate FAIL (fail closed)
/// - The gate verdict is Codable for CI artifact consumption
/// - Per-fixture reports are individually inspectable
///
/// Doctrine alignment:
/// - §5 Evidence-based — every observation backed by PDFKit tool output
/// - §2 Truth taxonomy — results labeled Observed (tool output)
/// - §1 Outcomes — gate prevents version bumps when fixtures fail
@Suite("RG-131 Control Viewer Observation Gate")
struct ControlViewerObservationGateTests {
    
    private static let corpusDir = "\(FileManager.default.currentDirectoryPath)/benchmark/results"
    
    // MARK: - Gate semantics (fail closed)
    
    @Test("Gate fails closed on zero fixtures")
    func gateFailsOnEmptyCorpus() {
        let tmpDir = NSTemporaryDirectory() + "/empty-gate-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }
        
        let report = ControlViewerObservation.observeCorpus(directoryPath: tmpDir)
        #expect(report.fixtureCount == 0)
        #expect(!report.gatePassed, "Gate must fail closed on zero fixtures")
        print("[rg-131] empty corpus: \(report.summary)")
    }
    
    @Test("Gate fails closed on unreadable directory")
    func gateFailsOnUnreadableDir() {
        let report = ControlViewerObservation.observeCorpus(directoryPath: "/nonexistent/path")
        #expect(!report.gatePassed, "Gate must fail closed on unreadable directory")
        print("[rg-131] unreadable dir: \(report.summary)")
    }
    
    // MARK: - Governed corpus observation
    
    @Test("Governed corpus observation produces a report")
    func governedCorpusObservation() {
        let report = ControlViewerObservation.observeGovernedCorpus()
        
        // The benchmark/results directory has 192+ PDFs across many subdirectories
        #expect(report.fixtureCount > 0, "Corpus must have at least one PDF fixture")
        print("[rg-131] corpus: \(report.fixtureCount) fixtures, \(report.passedCount) passed, \(report.failedCount) failed")
        print("[rg-131] gate: \(report.gatePassed ? "PASS" : "FAIL")")
        
        if !report.gatePassed {
            let joined = report.failedFixtures.joined(separator: ", ")
            print("[rg-131] failed fixtures: \(joined)")
        }
        
        // Print per-fixture details for the first 5
        for v in report.verdicts.prefix(5) {
            let status = v.passed ? "✅" : "❌"
            print("[rg-131]   \(status) \(v.fixtureId): \(v.report.summary)")
            for obs in v.report.observations {
                let s = obs.passed ? "✅" : "❌"
                print("[rg-131]     \(s) \(obs.type.rawValue): \(obs.description)")
            }
        }
    }
    
    // MARK: - Single-fixture gate enforcement
    
    @Test("Single fixture failure makes gate fail")
    func singleFailureFailsGate() {
        // Create a corrupt PDF that will fail observation
        let tmpDir = NSTemporaryDirectory() + "/gate-fail-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }
        
        // Write garbage as a .pdf
        let garbagePath = (tmpDir as NSString).appendingPathComponent("corrupt.pdf")
        try? Data("not a pdf".utf8).write(to: URL(fileURLWithPath: garbagePath))
        
        let report = ControlViewerObservation.observeCorpus(directoryPath: tmpDir)
        #expect(report.fixtureCount == 1)
        #expect(report.failedCount == 1)
        #expect(!report.gatePassed, "Corrupt fixture must make gate fail")
        #expect(report.failedFixtures.contains { $0.contains("corrupt") })
    }
    
    @Test("Mix of good and bad fixtures fails gate")
    func mixedFixturesFailGate() {
        let tmpDir = NSTemporaryDirectory() + "/gate-mixed-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }
        
        // Copy a real fixture
        let realPDF = "\(Self.corpusDir)/public-sample-form.pdf"
        let realDest = (tmpDir as NSString).appendingPathComponent("good.pdf")
        try? FileManager.default.copyItem(atPath: realPDF, toPath: realDest)
        
        // Write garbage
        let badPath = (tmpDir as NSString).appendingPathComponent("bad.pdf")
        try? Data("not a pdf".utf8).write(to: URL(fileURLWithPath: badPath))
        
        let report = ControlViewerObservation.observeCorpus(directoryPath: tmpDir)
        #expect(report.fixtureCount == 2)
        #expect(report.passedCount == 1)
        #expect(report.failedCount == 1)
        #expect(!report.gatePassed, "One bad fixture must fail the gate")
    }
    
    // MARK: - Verdict is Codable (CI artifact)
    
    @Test("CorpusObservationReport is Codable for CI artifact")
    func reportCodable() {
        let report = ControlViewerObservation.observeGovernedCorpus()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // ISO-8601 dates: a bare numeric Date encodes as reference-date seconds
        // (2001 epoch), which every non-Swift reader misreads as Unix time —
        // the artifact previously carried a "1995" generatedAt.
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(report)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try! decoder.decode(ControlViewerObservation.CorpusObservationReport.self, from: data)

        #expect(decoded.fixtureCount == report.fixtureCount)
        #expect(decoded.gatePassed == report.gatePassed)
        #expect(decoded.verdicts.count == report.verdicts.count)
        #expect(decoded.summary == report.summary)

        // Write artifact for CI consumption
        let artifactPath = "\(Self.corpusDir)/control-viewer-gate-report.json"
        try? data.write(to: URL(fileURLWithPath: artifactPath))
        print("[rg-131] artifact written to \(artifactPath) (\(data.count) bytes)")
    }
    
    // MARK: - Per-fixture observation dimensions
    
    @Test("Each fixture observation has all 5 dimensions")
    func allDimensionsPresent() {
        let report = ControlViewerObservation.observeGovernedCorpus()
        
        for v in report.verdicts.prefix(10) {
            let types = Set(v.report.observations.map { $0.type })
            #expect(types.contains(.reopen), "\(v.fixtureId) missing reopen")
            #expect(types.contains(.rotation), "\(v.fixtureId) missing rotation")
            #expect(types.contains(.visualFidelity), "\(v.fixtureId) missing visualFidelity")
            #expect(types.contains(.formVisibility), "\(v.fixtureId) missing formVisibility")
            #expect(types.contains(.textReadability), "\(v.fixtureId) missing textReadability")
        }
    }
    
    // MARK: - Dual-engine verification
    
    @Test("Dual-engine agreement is recorded for each fixture")
    func dualEngineAgreement() {
        let report = ControlViewerObservation.observeGovernedCorpus()
        
        for v in report.verdicts.prefix(10) {
            let dualEngine = v.report.observations.filter { $0.tool == "DualEngine" }
            #expect(dualEngine.count >= 5, "\(v.fixtureId) expected 5 DualEngine observations, got \(dualEngine.count)")
            for obs in dualEngine {
                let s = obs.passed ? "✅" : "❌"
                print("[rg-131] \(v.fixtureId) dual-engine \(obs.type.rawValue): \(s) \(obs.description)")
            }
        }
    }
    
    @Test("Poppler observations are present for each fixture")
    func popplerObservationsPresent() {
        let report = ControlViewerObservation.observeGovernedCorpus()
        
        for v in report.verdicts.prefix(10) {
            let poppler = v.report.observations.filter { $0.tool == "Poppler" }
            #expect(poppler.count >= 5, "\(v.fixtureId) expected 5 Poppler observations, got \(poppler.count)")
            for obs in poppler {
                let s = obs.passed ? "✅" : "❌"
                print("[rg-131] \(v.fixtureId) Poppler: \(s) \(obs.type.rawValue): \(obs.description)")
            }
        }
    }
    
    // MARK: - Gate verdict is deterministic
    
    @Test("Gate verdict is deterministic across runs")
    func verdictDeterministic() {
        let r1 = ControlViewerObservation.observeGovernedCorpus()
        let r2 = ControlViewerObservation.observeGovernedCorpus()
        
        #expect(r1.fixtureCount == r2.fixtureCount)
        #expect(r1.gatePassed == r2.gatePassed)
        #expect(r1.passedCount == r2.passedCount)
        #expect(r1.failedCount == r2.failedCount)
    }
}
