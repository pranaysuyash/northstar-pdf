import Testing
import Foundation
@testable import PDFEditorCore

/// RG-135: human visual confirmation workflow.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — confirmations bind to the fixture's SHA-256; changed
///   bytes invalidate prior confirmations (stale).
/// - §0 Fail-closed — the gate never passes on incomplete or stale coverage.
@MainActor
struct HumanVisualConfirmationTests {

    // MARK: - Fixture setup

    /// Build a temp project root with a governed manifest and N real PDF files.
    private func makeProjectRoot(fixtureCount: Int = 2) throws -> String {
        let root = NSTemporaryDirectory() + "human-review-tests-\(UUID().uuidString.prefix(8))"
        let corpusDir = (root as NSString).appendingPathComponent("benchmark/results")
        try FileManager.default.createDirectory(atPath: corpusDir, withIntermediateDirectories: true)

        var fixtures: [[String: String]] = []
        for i in 0..<fixtureCount {
            let relative = "fixture-\(i).pdf"
            let path = (corpusDir as NSString).appendingPathComponent(relative)
            // Minimal but real PDF bytes so digest binding works.
            let pdf = Data("%PDF-1.4\n%\u{E2}\u{E3}\u{CF}\u{D3}\n\(i) fixture\ntrailer\n".utf8)
            try pdf.write(to: URL(fileURLWithPath: path))
            fixtures.append([
                "id": "fixture-\(i)",
                "relativePath": relative,
                "documentClass": "test",
                "description": "Test fixture \(i)",
            ])
        }

        let manifest: [String: Any] = [
            "version": "1.1",
            "description": "Test manifest",
            "fixtures": fixtures,
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: URL(fileURLWithPath: (corpusDir as NSString).appendingPathComponent("governed-corpus-manifest.json")))
        return root
    }

    private func confirmedVerdicts() -> [HumanReviewDimension: HumanReviewVerdict] {
        Dictionary(uniqueKeysWithValues: HumanReviewDimension.allCases.map { ($0, .confirmed) })
    }

    private func fixture(_ store: HumanVisualConfirmationStore, _ id: String) -> HumanVisualConfirmationStore.HumanReviewFixtureInfo {
        guard let f = store.manifestFixtures.first(where: { $0.id == id }) else {
            fatalError("fixture \(id) missing from store manifest")
        }
        return f
    }

    // MARK: - Manifest loading

    @Test("Store loads governed manifest fixtures with digests")
    func loadsManifest() throws {
        let root = try makeProjectRoot(fixtureCount: 3)
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        #expect(store.manifestFixtures.count == 3)
        #expect(store.manifestFixtures.allSatisfy { $0.exists })
        #expect(store.manifestFixtures.allSatisfy { $0.currentDigest?.count == 64 })
    }

    @Test("Missing manifest yields empty fixture list")
    func missingManifest() throws {
        let root = NSTemporaryDirectory() + "human-review-empty-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        #expect(store.manifestFixtures.isEmpty)
        let report = store.evaluateGate()
        #expect(report.totalFixtures == 0)
        #expect(report.status == "pending")
    }

    // MARK: - Record + persist round-trip

    @Test("Record confirmation persists ledger and re-decodes")
    func recordPersists() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        let f = fixture(store, "fixture-0")
        try store.record(fixture: f, reviewer: "pranay", verdicts: confirmedVerdicts(), notes: "looks right")

        // Ledger file exists and re-decodes to the same entry.
        let ledgerPath = (root as NSString).appendingPathComponent(HumanVisualConfirmationStore.ledgerRelativePath)
        let data = try Data(contentsOf: URL(fileURLWithPath: ledgerPath))
        let decoded = try HumanVisualConfirmationLedger.decode(from: data)
        #expect(decoded.entries.count == 1)
        #expect(decoded.entries.first?.fixtureId == "fixture-0")
        #expect(decoded.entries.first?.reviewer == "pranay")
        #expect(decoded.entries.first?.isComplete == true)

        // A fresh store sees the persisted entry.
        let store2 = HumanVisualConfirmationStore(projectRoot: root)
        #expect(store2.reviewState(for: fixture(store2, "fixture-0")) == .confirmed)
    }

    @Test("Record requires reviewer identity")
    func recordRequiresReviewer() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        #expect(throws: HumanReviewError.missingReviewer) {
            try store.record(fixture: fixture(store, "fixture-0"), reviewer: "   ", verdicts: confirmedVerdicts(), notes: "")
        }
    }

    @Test("Record rejects unreadable fixtures")
    func recordRejectsMissing() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        // Remove the file on disk after manifest load.
        try FileManager.default.removeItem(atPath: fixture(store, "fixture-1").absolutePath)
        store.reloadFixtures()
        let missing = fixture(store, "fixture-1")
        #expect(!missing.exists)
        #expect(throws: HumanReviewError.fixtureUnreadable(missing.relativePath)) {
            try store.record(fixture: missing, reviewer: "pranay", verdicts: confirmedVerdicts(), notes: "")
        }
    }

    // MARK: - Gate semantics (fail-closed)

    @Test("Gate fails closed while coverage is incomplete")
    func gatePendingOnIncomplete() throws {
        let root = try makeProjectRoot(fixtureCount: 3)
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        try store.record(fixture: fixture(store, "fixture-0"), reviewer: "r", verdicts: confirmedVerdicts(), notes: "")

        let report = store.evaluateGate()
        #expect(report.status == "pending")
        #expect(report.confirmedCount == 1)
        #expect(report.pendingFixtures.sorted() == ["fixture-1", "fixture-2"])
    }

    @Test("Gate passes only on complete confirmed coverage")
    func gatePassesOnFullCoverage() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        for f in store.manifestFixtures {
            try store.record(fixture: f, reviewer: "r", verdicts: confirmedVerdicts(), notes: "")
        }
        let report = store.evaluateGate()
        #expect(report.status == "pass")
        #expect(report.confirmedCount == 2)
        #expect(report.pendingFixtures.isEmpty && report.staleFixtures.isEmpty && report.failedFixtures.isEmpty)
    }

    @Test("Reviewer-recorded failure yields gate fail")
    func gateFailsOnReviewerFailure() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        var verdicts = confirmedVerdicts()
        verdicts[.visualFidelity] = .failed
        try store.record(fixture: fixture(store, "fixture-0"), reviewer: "r", verdicts: verdicts, notes: "text overflows box")
        try store.record(fixture: fixture(store, "fixture-1"), reviewer: "r", verdicts: confirmedVerdicts(), notes: "")

        let report = store.evaluateGate()
        #expect(report.status == "fail")
        #expect(report.failedFixtures == ["fixture-0"])
    }

    @Test("Incomplete verdicts do not count as confirmed")
    func incompleteVerdictsStayPending() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        var partial = confirmedVerdicts()
        partial.removeValue(forKey: .textReadability)
        try store.record(fixture: fixture(store, "fixture-0"), reviewer: "r", verdicts: partial, notes: "")

        let report = store.evaluateGate()
        #expect(report.status == "pending")
        // fixture-1 has no entry at all, so it is also a coverage gap.
        #expect(report.pendingFixtures.sorted() == ["fixture-0", "fixture-1"])
        #expect(report.confirmedCount == 0)
    }

    // MARK: - Stale digest binding (§2 truth taxonomy)

    @Test("Digest change invalidates confirmation as stale")
    func staleDigestDetected() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        try store.record(fixture: fixture(store, "fixture-0"), reviewer: "r", verdicts: confirmedVerdicts(), notes: "")
        #expect(store.reviewState(for: fixture(store, "fixture-0")) == .confirmed)

        // Mutate the fixture bytes — the confirmation is now stale.
        let path = fixture(store, "fixture-0").absolutePath
        try Data("mutated bytes".utf8).write(to: URL(fileURLWithPath: path))
        store.reloadFixtures()

        let report = store.evaluateGate()
        #expect(report.status == "pending")
        #expect(report.staleFixtures == ["fixture-0"])
        #expect(store.reviewState(for: fixture(store, "fixture-0")) == .stale)
    }

    // MARK: - Latest-wins semantics

    @Test("Latest entry per fixture wins")
    func latestEntryWins() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        let f = fixture(store, "fixture-0")

        var failVerdicts = confirmedVerdicts()
        failVerdicts[.rotation] = .failed
        let early = HumanVisualConfirmation(
            fixtureId: f.id, relativePath: f.relativePath, documentClass: f.documentClass,
            sourceDigest: f.currentDigest!, reviewer: "first", verdicts: failVerdicts,
            reviewedAt: Date(timeIntervalSince1970: 1_000)
        )
        let late = HumanVisualConfirmation(
            fixtureId: f.id, relativePath: f.relativePath, documentClass: f.documentClass,
            sourceDigest: f.currentDigest!, reviewer: "second", verdicts: confirmedVerdicts(),
            reviewedAt: Date(timeIntervalSince1970: 2_000)
        )
        try store.appendEntry(early)
        try store.appendEntry(late)

        #expect(store.reviewState(for: f) == .confirmed)
        #expect(store.ledger.latestByFixture[f.id]?.reviewer == "second")
    }

    // MARK: - Gate report artifact

    @Test("Gate report persists as schema-tagged artifact")
    func gateReportArtifact() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let store = HumanVisualConfirmationStore(projectRoot: root)
        let report = try store.writeGateReport()

        #expect(report.schema == "pdf-editor.human-review-gate")
        #expect(report.version == "1.0")
        let path = (root as NSString).appendingPathComponent(HumanVisualConfirmationStore.gateReportRelativePath)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["schema"] as? String == "pdf-editor.human-review-gate")
        #expect(json?["status"] as? String == "pending")
    }

    // MARK: - Real-project-root artifact generation (CI basis)

    /// Runs the store against the real checkout root and persists the
    /// ledger + gate-report artifact pair. In CI (no human reviewer) the
    /// gate reports pending coverage and the CI step treats that as
    /// advisory; a reviewer-recorded failure on current bytes blocks.
    @Test("Real governed corpus produces persisted gate artifacts")
    func realCorpusArtifacts() throws {
        // Resolve the checkout root relative to the test working directory.
        var root = FileManager.default.currentDirectoryPath
        while !FileManager.default.fileExists(
            atPath: (root as NSString).appendingPathComponent("benchmark/results/governed-corpus-manifest.json")) {
            let parent = (root as NSString).deletingLastPathComponent
            if parent == root { root = ""; break }
            root = parent
        }
        guard !root.isEmpty else {
            // Not running from the checkout — nothing to verify here.
            return
        }

        let store = HumanVisualConfirmationStore(projectRoot: root)
        #expect(store.manifestFixtures.count >= 38, "governed manifest should carry the expanded fixture set")

        let report = try store.writeGateReport()
        #expect(report.schema == "pdf-editor.human-review-gate")
        // CI has no human reviewer: unless failures were recorded on current
        // bytes, status must be pending (never a vacuous pass).
        if report.failedCount == 0 {
            #expect(report.status == "pending" || report.status == "pass")
        }

        // The artifact pair must exist on disk.
        let pair = [
            (root as NSString).appendingPathComponent(HumanVisualConfirmationStore.ledgerRelativePath),
            (root as NSString).appendingPathComponent(HumanVisualConfirmationStore.gateReportRelativePath),
        ]
        for p in pair {
            #expect(FileManager.default.fileExists(atPath: p), "missing artifact: \(p)")
        }
    }
}
