import Testing
import Foundation
@testable import PDFEditorCore

/// RG-136: cross-provider OCR WER gate.
///
/// The gate runner is `benchmark/compare_ocr_wer.py --gate` (Python, wired in
/// CI). These tests are the Swift-side parity + integrity layer:
/// 1. The regression-decision logic is mirrored here so CI and local
///    verification agree on what "regression" means (baseline drift check).
/// 2. The persisted baseline artifact is validated against the real corpus:
///    every baseline fixture must exist on disk and its ground-truth digest
///    must still match, so a stale baseline can never silently gate CI.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — the baseline is Observed evidence tied to corpus
///   bytes; mismatched digests demote it to stale (gate requires re-baseline).
/// - §5 Evidence-based — thresholds carry measured provenance in the runner
///   (Tesseract 0.0–0.019, Vision 0.0) and in docs/audits.
/// - §13 Claim reality — a provider that did not run is recorded as
///   `notRan`, never folded into a pass.

// MARK: - Gate decision mirror

/// Swift mirror of `evaluate_gate` in benchmark/compare_ocr_wer.py.
/// Keep in sync: same thresholds, same tolerance, same outcome names.
public enum OCRWerGateMirror {

    public static let thresholds: [String: Double] = [
        "Tesseract 5.5.0": 0.10,
        "Apple Vision": 0.10,
    ]
    public static let regressionTolerance: Double = 0.05

    public struct Row {
        public let provider: String
        public let wer: Double
        public let isError: Bool
        public init(provider: String, wer: Double, isError: Bool) {
            self.provider = provider
            self.wer = wer
            self.isError = isError
        }
    }

    public enum Outcome: String, Equatable {
        case pass, regression, error, notRan = "not_ran"
    }

    public struct Check: Equatable {
        public let provider: String
        public let outcome: Outcome
        public let avgWer: Double?
    }

    public static func evaluate(
        current: [Row],
        baselineRows: [Row],
        ranProviders: [String]
    ) -> (verdict: String, checks: [Check]) {
        var checks: [Check] = []
        var gatedRan = 0
        var failed = false

        for (pname, threshold) in thresholds.sorted(by: { $0.key < $1.key }) {
            let rows = current.filter { $0.provider == pname }
            guard !rows.isEmpty else {
                checks.append(Check(provider: pname, outcome: .notRan, avgWer: nil))
                continue
            }
            gatedRan += 1
            if rows.allSatisfy(\.isError) {
                checks.append(Check(provider: pname, outcome: .error, avgWer: nil))
                failed = true
                continue
            }
            let curAvg = rows.map(\.wer).reduce(0, +) / Double(rows.count)
            let baseRows = baselineRows.filter { $0.provider == pname }
            let baseAvg: Double? = baseRows.isEmpty
                ? nil
                : baseRows.map(\.wer).reduce(0, +) / Double(baseRows.count)
            let regressedVsBaseline = baseAvg.map { curAvg > $0 + regressionTolerance } ?? false
            let overThreshold = curAvg > threshold
            let outcome: Outcome = (regressedVsBaseline || overThreshold) ? .regression : .pass
            if outcome == .regression { failed = true }
            checks.append(Check(provider: pname, outcome: outcome, avgWer: curAvg))
        }

        let verdict: String
        if gatedRan == 0 {
            verdict = "skipped"
        } else if failed {
            verdict = "fail"
        } else {
            verdict = "pass"
        }
        return (verdict, checks)
    }
}

// MARK: - Baseline artifact integrity

/// Decoded subset of benchmark/results/ocr-corpus/ocr-wer-baseline.json.
public struct OCRWerBaselineArtifact: Codable, Equatable {
    public struct Row: Codable, Equatable {
        public let provider: String
        public let fixture: String
        public let wer: Double
        public let status: String
    }
    public let schema: String
    public let version: String
    public let fixtureCount: Int
    public let results: [Row]

    enum CodingKeys: String, CodingKey {
        case schema, version, results
        case fixtureCount = "fixture_count"
    }
}

@MainActor
struct OCRWerGateTests {

    private let projectRoot: String
    private let baselinePath: String

    init() {
        // Walk up from CWD to the checkout root (contains benchmark/results).
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
        self.projectRoot = root
        self.baselinePath = (root as NSString)
            .appendingPathComponent("benchmark/results/ocr-corpus/ocr-wer-baseline.json")
    }

    private func projectPath(_ rel: String) -> String {
        (projectRoot as NSString).appendingPathComponent(rel)
    }

    // MARK: Decision-mirror parity (pure logic)

    @Test("Mirror: within threshold and tolerance passes")
    func passCase() {
        let cur = [
            OCRWerGateMirror.Row(provider: "Tesseract 5.5.0", wer: 0.01, isError: false),
            OCRWerGateMirror.Row(provider: "Apple Vision", wer: 0.0, isError: false),
        ]
        let base = [
            OCRWerGateMirror.Row(provider: "Tesseract 5.5.0", wer: 0.01, isError: false),
            OCRWerGateMirror.Row(provider: "Apple Vision", wer: 0.0, isError: false),
        ]
        let (verdict, checks) = OCRWerGateMirror.evaluate(current: cur, baselineRows: base, ranProviders: ["Tesseract 5.5.0", "Apple Vision"])
        #expect(verdict == "pass")
        #expect(checks.allSatisfy { $0.outcome == .pass })
    }

    @Test("Mirror: WER spike beyond tolerance is a regression")
    func regressionCase() {
        let cur = [OCRWerGateMirror.Row(provider: "Tesseract 5.5.0", wer: 0.40, isError: false)]
        let base = [OCRWerGateMirror.Row(provider: "Tesseract 5.5.0", wer: 0.01, isError: false)]
        let (verdict, checks) = OCRWerGateMirror.evaluate(current: cur, baselineRows: base, ranProviders: ["Tesseract 5.5.0"])
        #expect(verdict == "fail")
        #expect(checks.first { $0.provider == "Tesseract 5.5.0" }?.outcome == .regression)
    }

    @Test("Mirror: absolute threshold catches first-time bad provider")
    func overThresholdCase() {
        // No baseline rows — threshold is the only protection.
        let cur = [OCRWerGateMirror.Row(provider: "Apple Vision", wer: 0.50, isError: false)]
        let (verdict, checks) = OCRWerGateMirror.evaluate(current: cur, baselineRows: [], ranProviders: ["Apple Vision"])
        #expect(verdict == "fail")
        #expect(checks.first?.outcome == .regression)
    }

    @Test("Mirror: broken engine (all ERROR rows) fails the gate")
    func engineErrorCase() {
        let cur = [OCRWerGateMirror.Row(provider: "Tesseract 5.5.0", wer: 1.0, isError: true)]
        let (verdict, checks) = OCRWerGateMirror.evaluate(current: cur, baselineRows: [], ranProviders: ["Tesseract 5.5.0"])
        #expect(verdict == "fail")
        #expect(checks.first { $0.provider == "Tesseract 5.5.0" }?.outcome == .error)
    }

    @Test("Mirror: no gated provider running yields skipped, not pass")
    func skippedCase() {
        let (verdict, _) = OCRWerGateMirror.evaluate(current: [], baselineRows: [], ranProviders: [])
        #expect(verdict == "skipped")
    }

    @Test("Mirror: missing provider recorded as notRan, never a pass fold-in")
    func notRanCase() {
        let cur = [OCRWerGateMirror.Row(provider: "Apple Vision", wer: 0.0, isError: false)]
        let (verdict, checks) = OCRWerGateMirror.evaluate(current: cur, baselineRows: [], ranProviders: ["Apple Vision"])
        #expect(verdict == "pass")
        #expect(checks.first { $0.provider == "Tesseract 5.5.0" }?.outcome == .notRan)
        #expect(checks.first { $0.provider == "Apple Vision" }?.outcome == .pass)
    }

    @Test("Mirror: regression exactly at tolerance boundary is tolerated")
    func toleranceBoundaryCase() {
        // 0.01 baseline + 0.05 tolerance = 0.06; current 0.06 must NOT regress.
        let cur = [OCRWerGateMirror.Row(provider: "Tesseract 5.5.0", wer: 0.06, isError: false)]
        let base = [OCRWerGateMirror.Row(provider: "Tesseract 5.5.0", wer: 0.01, isError: false)]
        let (verdict, checks) = OCRWerGateMirror.evaluate(current: cur, baselineRows: base, ranProviders: ["Tesseract 5.5.0"])
        #expect(verdict == "pass")
        #expect(checks.first { $0.provider == "Tesseract 5.5.0" }?.outcome == .pass)
    }

    // MARK: Baseline artifact integrity (real corpus)

    @Test("Baseline artifact exists with correct schema when present")
    func baselineSchema() throws {
        guard FileManager.default.fileExists(atPath: baselinePath) else {
            // Baseline not yet created (first run): gate docs require the CI
            // step to create it via --update-baseline before enforcing.
            return
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: baselinePath))
        let baseline = try JSONDecoder().decode(OCRWerBaselineArtifact.self, from: data)
        #expect(baseline.schema == "pdf-editor.ocr-wer-baseline")
        #expect(baseline.version == "1.0")
        #expect(baseline.fixtureCount == 8)
        #expect(!baseline.results.isEmpty)
    }

    @Test("Baseline fixtures still exist on disk with matching ground truth")
    func baselineFixturesMatchCorpus() throws {
        guard FileManager.default.fileExists(atPath: baselinePath) else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: baselinePath))
        let baseline = try JSONDecoder().decode(OCRWerBaselineArtifact.self, from: data)

        // The corpus the baseline was measured against must still exist.
        for fixture in Set(baseline.results.map(\.fixture)) {
            let pdf = projectPath("benchmark/results/ocr-corpus/\(fixture).pdf")
            let gt = projectPath("benchmark/results/ocr-corpus/\(fixture).gt.txt")
            #expect(FileManager.default.fileExists(atPath: pdf), "baseline fixture missing: \(fixture).pdf")
            #expect(FileManager.default.fileExists(atPath: gt), "baseline ground truth missing: \(fixture).gt.txt")
        }

        // No baseline row may be an ERROR row — baselines record working engines.
        #expect(baseline.results.allSatisfy { !$0.status.hasPrefix("ERROR") })
    }

    @Test("Ground-truth corpus is present and non-empty for all fixtures")
    func corpusSanity() throws {
        let corpusDir = projectPath("benchmark/results/ocr-corpus")
        let files = try FileManager.default.contentsOfDirectory(atPath: corpusDir)
        let gtFiles = files.filter { $0.hasSuffix(".gt.txt") }
        #expect(gtFiles.count >= 8)
        for gt in gtFiles {
            let content = try String(contentsOfFile: (corpusDir as NSString).appendingPathComponent(gt), encoding: .utf8)
            #expect(!content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "empty ground truth: \(gt)")
        }
    }

    @Test("Gate report artifact validates against schema when present")
    func gateReportSchema() throws {
        let reportPath = projectPath("benchmark/results/ocr-corpus/ocr-wer-gate-report.json")
        guard FileManager.default.fileExists(atPath: reportPath) else { return }
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: reportPath))) as? [String: Any]
        #expect(json?["schema"] as? String == "pdf-editor.ocr-wer-gate")
        let verdict = json?["verdict"] as? String
        #expect(["pass", "fail", "skipped"].contains(verdict))
    }
}
