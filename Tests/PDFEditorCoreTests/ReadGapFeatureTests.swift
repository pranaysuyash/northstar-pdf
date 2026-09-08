import Testing
import Foundation
import PDFKit
@testable import PDFEditorCore

/// R-01/R-15/R-16 — Missing test coverage for READ-gap features that shipped
/// without dedicated suites.
///
/// Covered here:
/// - R-01  PrivacyAuditTrail (value-free audit trail, append-only semantics)
/// - R-15  ScriptingSurface (ScriptRunner, ScriptWorkflow)
/// - R-15  ScriptingCLI (CLIRunner: path sandbox, history, validate/extract)
/// - R-15  UserScriptRunner (WorkflowRunner: globs, stop-on-failure, audit)
/// - R-16  SharedContracts (version negotiation, coordinate spaces)
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — tests assert observable behavior (Observed evidence).
/// - §5 Evidence-based — each feature has a falsifying test here.
/// - §12 Privacy value-free — audit tests verify no document content is
///   stored, only document IDs and actions.

// MARK: - Fixture discovery (same walk-up as OCRWerGateTests)

private func repoRoot() -> String {
    var root = FileManager.default.currentDirectoryPath
    for _ in 0..<6 {
        if FileManager.default.fileExists(
            atPath: (root as NSString).appendingPathComponent("benchmark/results/ocr-corpus")) {
            break
        }
        let parent = (root as NSString).deletingLastPathComponent
        if parent == root { break }
        root = parent
    }
    return root
}

/// Copy a real corpus PDF into a temp dir so ScriptRunner/WorkflowRunner have
/// a real `%PDF-` file to operate on.
private func tempFixturePDF() throws -> URL {
    let root = repoRoot()
    let src = (root as NSString).appendingPathComponent("benchmark/results/ocr-corpus/clean-english.pdf")
    guard FileManager.default.fileExists(atPath: src) else {
        throw NSError(domain: "ReadGapFeatureTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "corpus fixture missing: \(src)"])
    }
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("readgap-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let dst = dir.appendingPathComponent("clean-english.pdf")
    try FileManager.default.copyItem(at: URL(fileURLWithPath: src), to: dst)
    return dst
}

// MARK: - R-01 PrivacyAuditTrail

@MainActor
@Suite("R-01 PrivacyAuditTrail")
struct PrivacyAuditTrailTests {

    /// Isolated trail: unique storage key per test avoids cross-suite
    /// pollution of the production UserDefaults key.
    private func isolatedTrail() -> AuditTrail {
        AuditTrail(storageKey: "test.audit.\(UUID().uuidString)")
    }

    @Test("Record events and query by document / type")
    func recordAndQuery() {
        let trail = isolatedTrail()
        trail.recordOpen(documentID: "doc-a.pdf")
        trail.recordRead(documentID: "doc-a.pdf", pageIndex: 3)
        trail.recordExport(documentID: "doc-a.pdf", format: "pdf")
        trail.recordOpen(documentID: "doc-b.pdf")

        #expect(trail.count == 4)
        #expect(trail.events(for: "doc-a.pdf").count == 3)
        #expect(trail.events(ofType: .documentOpened).count == 2)
        #expect(trail.auditedDocuments == ["doc-a.pdf", "doc-b.pdf"])
    }

    @Test("Trail is value-free: no query text or document content in records")
    func valueFree() {
        let trail = isolatedTrail()
        trail.recordSearch(documentID: "confidential.pdf", query: "password=secret123")
        trail.recordRead(documentID: "confidential.pdf", pageIndex: 0)

        let json = trail.exportJSON()
        #expect(json != nil)
        let text = String(data: json!, encoding: .utf8) ?? ""
        // Search text is user content: the trail stores the query length only.
        #expect(!text.contains("password=secret123"))
        #expect(text.contains("query_length:18"))
        // And never the file bytes.
        #expect(!text.contains("%PDF-"))
    }

    @Test("Trail is a bounded rolling window: oldest events evicted at maxEvents")
    func boundedWindow() {
        let trail = isolatedTrail()
        let cap = AuditTrail.maxEvents
        for index in 0..<(cap + 25) {
            trail.recordOpen(documentID: "doc-\(index).pdf")
        }
        #expect(trail.count == cap)
        // Newest kept, oldest evicted — the documented rolling-window bound.
        #expect(trail.events(for: "doc-\(cap + 24).pdf").count == 1)
        #expect(trail.events(for: "doc-0.pdf").isEmpty)
        #expect(trail.events(for: "doc-24.pdf").isEmpty)
        #expect(trail.events(for: "doc-25.pdf").count == 1)
    }

    @Test("Export report groups by document chronologically")
    func reportFormat() {
        let trail = isolatedTrail()
        trail.recordOpen(documentID: "x.pdf")
        trail.recordClose(documentID: "x.pdf")
        let report = trail.exportReport()
        #expect(report.contains("# Privacy Audit Trail"))
        #expect(report.contains("## x.pdf"))
        #expect(report.contains("Opened"))
        #expect(report.contains("Closed"))
    }

    @Test("Events are append-only with newest first")
    func appendOnly() {
        let trail = isolatedTrail()
        trail.recordOpen(documentID: "a.pdf")
        trail.recordClose(documentID: "a.pdf")
        // Newest inserted at front for display.
        #expect(trail.events.first?.type == .documentClosed)
        // Recorded events never mutate: re-query returns same set.
        let count = trail.count
        trail.recordOpen(documentID: "a.pdf")
        #expect(trail.count == count + 1)
    }
}

// MARK: - R-15 ScriptingSurface

@Suite("R-15 ScriptingSurface")
struct ScriptingSurfaceTests {

    @Test("Command registry is complete and Codable")
    func commandRegistry() throws {
        let all = ScriptCommand.allCases
        #expect(all.count == 7)
        let encoded = try JSONEncoder().encode(ScriptCommand.extractText)
        let decoded = try JSONDecoder().decode(ScriptCommand.self, from: encoded)
        #expect(decoded == .extractText)
        #expect(ScriptCommand.validatePDF.displayName == "Validate PDF")
    }

    @Test("Runner fails cleanly on missing file")
    func missingFile() {
        let runner = ScriptRunner()
        let url = URL(fileURLWithPath: "/nonexistent/definitely-missing.pdf")
        let result = runner.execute(.validatePDF, fileURL: url)
        #expect(!result.success)
        #expect(result.error?.contains("File not found") == true)
    }

    @Test("Validate command accepts a real PDF")
    func validateRealPDF() throws {
        let fixture = try tempFixturePDF()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let runner = ScriptRunner()
        let result = runner.execute(.validatePDF, fileURL: fixture)
        #expect(result.success)
        #expect(result.output.contains("PDF is valid"))
    }

    @Test("Workflow stops on first failure when stopOnFailure")
    func workflowStopOnFailure() {
        let workflow = ScriptWorkflow(
            name: "bad-input",
            steps: [
                ScriptStep(command: .validatePDF, inputPath: "/missing/one.pdf"),
                ScriptStep(command: .validatePDF, inputPath: "/missing/two.pdf"),
            ],
            stopOnFailure: true
        )
        let results = ScriptRunner().executeWorkflow(workflow)
        #expect(results.count == 1)
        #expect(!results[0].success)
    }

    @Test("Workflow continues when stopOnFailure is false")
    func workflowContinue() {
        let workflow = ScriptWorkflow(
            name: "continue",
            steps: [
                ScriptStep(command: .validatePDF, inputPath: "/missing/one.pdf"),
                ScriptStep(command: .validatePDF, inputPath: "/missing/two.pdf"),
            ],
            stopOnFailure: false
        )
        let results = ScriptRunner().executeWorkflow(workflow)
        #expect(results.count == 2)
        #expect(results.allSatisfy { !$0.success })
    }
}

// MARK: - R-15 ScriptingCLI

@MainActor
@Suite("R-15 ScriptingCLI")
struct ScriptingCLITests {

    @Test("CLIRunner rejects paths outside allowed directories (V-01)")
    func pathSandbox() async {
        let runner = CLIRunner()
        let result = await runner.execute(.validatePDF, inputPath: "/etc/passwd")
        #expect(!result.success)
        #expect(result.error?.contains("Path rejected") == true)
        #expect(runner.failureCount == 1)
    }

    @Test("CLIRunner validates a real PDF from temp dir")
    func validatePDF() async throws {
        let fixture = try tempFixturePDF()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let runner = CLIRunner()
        let result = await runner.execute(.validatePDF, inputPath: fixture.path)
        #expect(result.success)
        #expect(result.output.contains("pageCount"))
        #expect(runner.totalExecuted == 1)
        #expect(runner.successCount == 1)
    }

    @Test("CLIRunner export citation works on a real PDF")
    func citation() async throws {
        let fixture = try tempFixturePDF()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        let runner = CLIRunner()
        let result = await runner.execute(.exportCitation, inputPath: fixture.path)
        #expect(result.success)
        #expect(result.output.contains("clean-english"))
    }

    @Test("History is clearable")
    func clearHistory() async throws {
        let runner = CLIRunner()
        let fixture = try tempFixturePDF()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }
        _ = await runner.execute(.validatePDF, inputPath: fixture.path)
        #expect(runner.totalExecuted == 1)
        runner.clearHistory()
        #expect(runner.totalExecuted == 0)
    }
}

// MARK: - R-15 UserScriptRunner

@MainActor
@Suite("R-15 UserScriptRunner")
struct UserScriptRunnerTests {

    @Test("UserScript metadata and estimates")
    func scriptMetadata() {
        let script = UserScript(
            name: "Audit batch",
            steps: [
                WorkflowStep(name: "validate all", operation: .validate, inputPattern: "*.pdf", estimatedSeconds: 3),
                WorkflowStep(name: "extract", operation: .extractText, inputPattern: "*.pdf", estimatedSeconds: 7),
            ],
            timeoutSeconds: 60,
            requiresConsent: true,
            tags: ["batch"]
        )
        #expect(script.stepCount == 2)
        #expect(script.estimatedSeconds == 10)
        #expect(script.requiresConsent)
        #expect(script.tags.contains("batch"))
    }

    @Test("WorkflowRunner executes validate on a real directory")
    func runValidate() async throws {
        let fixture = try tempFixturePDF()
        let dir = fixture.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: dir) }

        let runner = WorkflowRunner()
        let script = UserScript(
            name: "validate",
            steps: [WorkflowStep(name: "check", operation: .validate, inputPattern: "*.pdf")]
        )
        let result = await runner.execute(script: script, directory: dir.path)
        #expect(result.allSucceeded)
        #expect(result.successCount == 1)
        #expect(result.summary.contains("1/1"))
        #expect(runner.runHistory.count == 1)
        #expect(!runner.isRunning)
    }

    @Test("WorkflowRunner fails when no files match the pattern")
    func noFilesMatch() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("empty-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let runner = WorkflowRunner()
        let script = UserScript(
            name: "empty",
            steps: [WorkflowStep(name: "check", operation: .validate, inputPattern: "*.pdf")]
        )
        let result = await runner.execute(script: script, directory: dir.path)
        #expect(!result.allSucceeded)
        #expect(result.stepResults.first?.error?.contains("No input files") == true)
    }

    @Test("Optional failing step does not stop the workflow")
    func optionalStepContinues() async throws {
        let fixture = try tempFixturePDF()
        let dir = fixture.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: dir) }

        let runner = WorkflowRunner()
        let script = UserScript(
            name: "optional",
            steps: [
                WorkflowStep(name: "optional-validate", operation: .validate, inputPattern: "nope-*.pdf", isOptional: true),
                WorkflowStep(name: "real-validate", operation: .validate, inputPattern: "*.pdf"),
            ]
        )
        let result = await runner.execute(script: script, directory: dir.path)
        #expect(result.stepResults.count == 2)  // optional failure did not stop the run
        // The optional step's failure is honestly recorded (not hidden), but the
        // non-optional step after it still ran and succeeded.
        #expect(!result.stepResults[0].success)
        #expect(result.stepResults[1].success)
    }

    @Test("Custom operation registration")
    func customOperation() async throws {
        let fixture = try tempFixturePDF()
        let dir = fixture.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: dir) }

        let runner = WorkflowRunner()
        runner.registerCustomOperation(name: "ping") { params, _ in
            WorkflowStepResult(stepName: "ping", success: true, outputFiles: [], executionTimeMs: 1)
        }
        let script = UserScript(
            name: "custom",
            steps: [WorkflowStep(name: "ping", operation: .custom(name: "ping", parameters: [:]), inputPattern: "*.pdf")]
        )
        let result = await runner.execute(script: script, directory: dir.path)
        #expect(result.allSucceeded)
    }
}

// MARK: - R-16 SharedContracts

@Suite("R-16 SharedContracts")
struct SharedContractsTests {

    @Test("Version negotiation: reader accepts same major and known minor")
    func versionReadable() {
        // isReadableBy(supported): "this version can be read by the supported
        // reader". A v1.0 reader accepts v1.0 payloads; it rejects v1.1
        // payloads (conservative — never guess an unknown minor).
        let v1_0 = PDFContractVersion(major: 1, minor: 0)
        let v1_1 = PDFContractVersion(major: 1, minor: 1)
        #expect(v1_0.isReadableBy(PDFContractVersion(major: 1, minor: 0)))
        #expect(!v1_1.isReadableBy(PDFContractVersion(major: 1, minor: 0)))
        // A v1.1 reader is backward compatible with v1.0 payloads.
        #expect(v1_0.isReadableBy(PDFContractVersion(major: 1, minor: 1)))
    }

    @Test("Version negotiation: different major is never readable")
    func versionMajorBoundary() {
        let v1 = PDFContractVersion(major: 1, minor: 0)
        let v2 = PDFContractVersion(major: 2, minor: 0)
        #expect(!v1.isReadableBy(v2))
        #expect(!v2.isReadableBy(v1))
    }

    @Test("Envelope readability follows header version")
    func envelopeReadability() {
        let provider = PDFProviderDescriptor(id: "native", version: "1.0", platform: "macos", capabilities: ["text"])
        let header = PDFContractHeader(
            contractName: "test",
            version: PDFContractVersion(major: 1, minor: 0),
            sourceDigest: "abc",
            provider: provider
        )
        // PDFContractEnvelope is generic; use the concrete DocumentInspection
        // typealias path only if available — here we just test the header rule.
        #expect(header.version.isReadableBy())
        #expect(header.version.major == 1)
    }

    @Test("Coordinate space defaults are page user space (lower-left, crop)")
    func coordinateSpace() {
        let space = PDFCoordinateSpace()
        #expect(space.unit == .points)
        #expect(space.origin == .lowerLeft)
        #expect(space.pageBox == .crop)
        #expect(space.rotationDegrees == 0)
        #expect(PDFCoordinateUnit.allCases == [.points])
        #expect(PDFPageBox.allCases.count == 5)
    }

    @Test("Coordinate space Codable round-trip")
    func coordinateCodable() throws {
        let space = PDFCoordinateSpace(origin: .upperLeft, pageBox: .media, rotationDegrees: 90)
        let data = try JSONEncoder().encode(space)
        let decoded = try JSONDecoder().decode(PDFCoordinateSpace.self, from: data)
        #expect(decoded == space)
    }
}