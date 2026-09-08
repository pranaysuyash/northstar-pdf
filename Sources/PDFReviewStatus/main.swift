import Foundation
import PDFEditorCore

/// Reviewer pass tracking CLI (RG-135) — shows which governed fixtures still
/// need human confirmation and prints the RG-135 gate status.
///
/// Thin wrapper over `HumanVisualConfirmationStore` (the same gate logic the
/// SwiftUI reviewer panel and CI use); this executable owns only presentation.
///
/// Usage: PDFReviewStatus [project-root] [--write-report]
///
///   project-root    Directory containing benchmark/results/governed-corpus-manifest.json.
///                   When omitted, the root is found by walking up from the
///                   working directory; otherwise the working directory itself
///                   is used (the gate then honestly reports zero coverage).
///   --write-report  Persist the gate report artifact
///                   (benchmark/results/human-visual-confirmation/human-review-gate-report.json),
///                   exactly as the CI RG-135 step does.
///
/// Exit codes: 0 for pass/pending (status report), 2 when the gate is `fail`
/// (a reviewer recorded a failure on current bytes) so scripts can branch.

let args = CommandLine.arguments

var rootCandidate: String? = nil
var writeReport = false
for arg in args.dropFirst() {
    if arg == "--write-report" {
        writeReport = true
    } else if !arg.hasPrefix("-") {
        rootCandidate = arg
    }
}

/// Walk up from `start` looking for the governed manifest marker.
func findProjectRoot(from start: String) -> String {
    var dir = start
    while true {
        let marker = (dir as NSString)
            .appendingPathComponent("benchmark/results/governed-corpus-manifest.json")
        if FileManager.default.fileExists(atPath: marker) { return dir }
        let parent = (dir as NSString).deletingLastPathComponent
        if parent == dir { return start }
        dir = parent
    }
}

let root = findProjectRoot(from: rootCandidate ?? FileManager.default.currentDirectoryPath)

// main.swift's top-level code already runs on the main thread; the store and
// gate evaluation are @MainActor, so assume that isolation synchronously.
// (A detached Task + semaphore would deadlock: top-level code blocks the
// main thread before the task can be scheduled.)
let output: String
let gateStatus: String
var reportError: String?
do {
    let (text, status, writeError) = try MainActor.assumeIsolated {
        let store = HumanVisualConfirmationStore(projectRoot: root)
        let report = store.evaluateGate()

        var lines: [String] = []
        lines.append("RG-135 Human Visual Confirmation — reviewer pass status")
        lines.append("Root: \(root)")
        lines.append(
            "Ledger: \(HumanVisualConfirmationStore.ledgerRelativePath) " +
            "(\(store.ledger.entries.count) \(store.ledger.entries.count == 1 ? "entry" : "entries"))"
        )
        lines.append("")

        let statusLabel: String
        switch report.status {
        case "pass": statusLabel = "PASS"
        case "fail": statusLabel = "FAIL"
        default: statusLabel = "PENDING"
        }
        lines.append(
            "Gate status: \(statusLabel) (\(report.confirmedCount)/\(report.totalFixtures) confirmed, " +
            "stale: \(report.staleCount), failed: \(report.failedCount))"
        )
        lines.append("")

        func pad(_ s: String, _ width: Int) -> String {
            s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
        }
        let stateWidth = 9

        func state(_ s: HumanVisualConfirmationStore.FixtureReviewState) -> String {
            switch s {
            case .confirmed: return "confirmed"
            case .stale: return "stale"
            case .failed: return "failed"
            case .pending: return "pending"
            }
        }

        lines.append("\(pad("STATE", stateWidth)) FIXTURE                              LAST REVIEWER       REVIEWED AT")
        lines.append(String(repeating: "-", count: 96))

        let dateFormatter = ISO8601DateFormatter()
        var needingPass: [String] = []
        var failingDetail: [String] = []

        for fixture in store.manifestFixtures {
            let reviewState = store.reviewState(for: fixture)
            if reviewState != .confirmed { needingPass.append(fixture.id) }

            let latest = store.ledger.latestByFixture[fixture.id]
            let reviewer: String
            let reviewedAt: String
            switch reviewState {
            case .pending:
                reviewer = "—"; reviewedAt = "—"
            case .stale, .failed, .confirmed:
                reviewer = latest?.reviewer ?? "—"
                reviewedAt = latest.map { dateFormatter.string(from: $0.reviewedAt) } ?? "—"
            }

            lines.append("\(pad(state(reviewState), stateWidth)) \(pad(fixture.id, 36)) \(pad(reviewer, 19)) \(reviewedAt)")
            if reviewState == .failed, let entry = latest, !entry.failedDimensions.isEmpty {
                let dims = entry.failedDimensions.map { $0.rawValue }.joined(separator: ", ")
                failingDetail.append("\(fixture.id): failed dimensions — \(dims)")
            }
            if reviewState == .stale {
                failingDetail.append("\(fixture.id): stale — fixture bytes changed after review (re-review required)")
            }
        }

        lines.append("")

        if !failingDetail.isEmpty {
            lines.append("Recorded failures / stale confirmations:")
            for line in failingDetail { lines.append("  - \(line)") }
            lines.append("")
        }

        if needingPass.isEmpty && report.status == "pass" {
            lines.append("No fixtures outstanding — every governed fixture is human-confirmed against current bytes.")
        } else if !needingPass.isEmpty {
            lines.append("Fixtures still needing reviewer pass (\(needingPass.count)):")
            for id in needingPass { lines.append("  - \(id)") }
        }

        lines.append("")
        lines.append("Summary: \(report.summary)")

        // Optional artifact write (same as the CI RG-135 step).
        var writeError: String?
        if writeReport {
            do {
                _ = try store.writeGateReport()
            } catch {
                writeError = "\(error)"
            }
        }

        return (lines.joined(separator: "\n"), report.status, writeError)
    }
    output = text
    gateStatus = status
    reportError = writeError
}

print(output)

if writeReport {
    if let error = reportError {
        FileHandle.standardError.write(("error: failed to write gate report: \(error)\n").data(using: .utf8)!)
        exit(1)
    }
    print("Gate report written: \(HumanVisualConfirmationStore.gateReportRelativePath)")
}

// A reviewer-recorded failure exits nonzero so scripts can branch on it;
// pending is informational (CI's own RG-135 step decides blocking there).
exit(gateStatus == "fail" ? 2 : 0)
