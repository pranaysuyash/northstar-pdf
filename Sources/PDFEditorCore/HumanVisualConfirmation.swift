import Foundation
import CryptoKit
import Observation

/// Human visual confirmation workflow (RG-135).
///
/// RG-131's automated dual-engine observations (PDFKit + Poppler) prove what
/// tools can see; they cannot prove what a human sees. This module closes that
/// gap: a reviewer inspects each governed fixture in a real viewer, records
/// per-dimension verdicts, and the ledger persists as a CI artifact.
///
/// Design doctrine:
/// - §2 Truth taxonomy — a confirmation is **Verified** evidence only when it
///   binds to the exact bytes reviewed (SHA-256 digest). A fixture whose
///   digest changed invalidates prior confirmations (stale → unreviewed).
/// - §0 / fail-closed — a fixture without a confirmation is `pending`, and
///   the gate never passes on incomplete coverage.
/// - §5 Evidence-based — every entry carries reviewer, timestamp, per-dimension
///   verdicts, and notes; the gate report is a persisted, schema-tagged artifact.
///
/// Gate status rules:
/// - `fail` — any fixture has a reviewer-recorded failed dimension
/// - `pending` — coverage incomplete (missing or stale confirmations)
/// - `pass` — every manifest fixture confirmed against its current digest,
///   with no failed dimensions

// MARK: - Review Dimensions

public enum HumanReviewDimension: String, Codable, Sendable, CaseIterable {
    case reopen
    case rotation
    case visualFidelity = "visual_fidelity"
    case formVisibility = "form_visibility"
    case textReadability = "text_readability"

    public var displayName: String {
        switch self {
        case .reopen: return "Reopen"
        case .rotation: return "Rotation"
        case .visualFidelity: return "Visual fidelity"
        case .formVisibility: return "Form visibility"
        case .textReadability: return "Text readability"
        }
    }
}

// MARK: - Verdicts

public enum HumanReviewVerdict: String, Codable, Sendable {
    case confirmed
    case failed
}

// MARK: - Confirmation Entry

public struct HumanVisualConfirmation: Codable, Sendable, Equatable {
    /// Governed-manifest fixture id.
    public let fixtureId: String
    /// Manifest-relative path, for human-readable artifact review.
    public let relativePath: String
    /// Document class from the governed manifest.
    public let documentClass: String
    /// SHA-256 of the fixture bytes at review time. Stale if the file changes.
    public let sourceDigest: String
    /// Reviewer identity (recorded in the panel; never inferred).
    public let reviewer: String
    /// Per-dimension verdicts. A confirmation is complete when every
    /// dimension has a verdict.
    public let verdicts: [HumanReviewDimension: HumanReviewVerdict]
    /// Free-form reviewer notes (optional).
    public let notes: String
    /// When the review happened (ISO-8601 in artifacts).
    public let reviewedAt: Date

    public init(
        fixtureId: String,
        relativePath: String,
        documentClass: String,
        sourceDigest: String,
        reviewer: String,
        verdicts: [HumanReviewDimension: HumanReviewVerdict],
        notes: String = "",
        reviewedAt: Date = Date()
    ) {
        self.fixtureId = fixtureId
        self.relativePath = relativePath
        self.documentClass = documentClass
        self.sourceDigest = sourceDigest
        self.reviewer = reviewer
        self.verdicts = verdicts
        self.notes = notes
        self.reviewedAt = reviewedAt
    }

    /// True when the reviewer recorded a verdict for every dimension.
    public var isComplete: Bool {
        Set(verdicts.keys) == Set(HumanReviewDimension.allCases)
    }

    public var failedDimensions: [HumanReviewDimension] {
        HumanReviewDimension.allCases.filter { verdicts[$0] == .failed }
    }
}

// MARK: - Ledger

public struct HumanVisualConfirmationLedger: Codable, Sendable {
    public static let schema = "pdf-editor.human-visual-confirmation"
    public static let version = "1.0"

    public var schema: String
    public var version: String
    public var entries: [HumanVisualConfirmation]
    public var updatedAt: Date

    public init(entries: [HumanVisualConfirmation] = [], updatedAt: Date = Date()) {
        self.schema = Self.schema
        self.version = Self.version
        self.entries = entries
        self.updatedAt = updatedAt
    }

    /// Most recent confirmation per fixture id.
    public var latestByFixture: [String: HumanVisualConfirmation] {
        var latest: [String: HumanVisualConfirmation] = [:]
        for entry in entries {
            if let existing = latest[entry.fixtureId], existing.reviewedAt >= entry.reviewedAt {
                continue
            }
            latest[entry.fixtureId] = entry
        }
        return latest
    }

    public func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> HumanVisualConfirmationLedger {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(HumanVisualConfirmationLedger.self, from: data)
    }
}

// MARK: - Gate Report

public struct HumanReviewGateReport: Codable, Sendable {
    public static let schema = "pdf-editor.human-review-gate"
    public static let version = "1.0"

    public let schema: String
    public let version: String
    /// "pass" | "fail" | "pending"
    public let status: String
    public let totalFixtures: Int
    public let confirmedCount: Int
    public let staleCount: Int
    public let failedCount: Int
    public let pendingFixtures: [String]
    public let staleFixtures: [String]
    public let failedFixtures: [String]
    public let summary: String
    public let generatedAt: Date

    public init(
        status: String,
        totalFixtures: Int,
        confirmedCount: Int,
        staleCount: Int,
        failedCount: Int,
        pendingFixtures: [String],
        staleFixtures: [String],
        failedFixtures: [String],
        summary: String,
        generatedAt: Date = Date()
    ) {
        self.schema = Self.schema
        self.version = Self.version
        self.status = status
        self.totalFixtures = totalFixtures
        self.confirmedCount = confirmedCount
        self.staleCount = staleCount
        self.failedCount = failedCount
        self.pendingFixtures = pendingFixtures
        self.staleFixtures = staleFixtures
        self.failedFixtures = failedFixtures
        self.summary = summary
        self.generatedAt = generatedAt
    }

    public func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

// MARK: - Digest Helper

public enum HumanReviewDigest {
    /// SHA-256 hex digest of the file at `path`, or nil when unreadable.
    public static func digest(ofFileAt path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Store

/// Loads the governed manifest, tracks reviewer entries, evaluates the gate,
/// and persists the ledger as a CI artifact.
@MainActor
@Observable
public final class HumanVisualConfirmationStore {
    public static let ledgerRelativePath = "benchmark/results/human-visual-confirmation/human-review-ledger.json"
    public static let gateReportRelativePath = "benchmark/results/human-visual-confirmation/human-review-gate-report.json"

    public private(set) var ledger: HumanVisualConfirmationLedger
    public private(set) var manifestFixtures: [HumanReviewFixtureInfo]
    public let projectRoot: String

    public init(projectRoot: String? = nil) {
        let root = projectRoot ?? FileManager.default.currentDirectoryPath
        self.projectRoot = root
        self.ledger = HumanVisualConfirmationStore.loadLedger(projectRoot: root)
            ?? HumanVisualConfirmationLedger()
        self.manifestFixtures = HumanVisualConfirmationStore.loadFixtureInfo(projectRoot: root)
    }

    // MARK: Fixture info

    public struct HumanReviewFixtureInfo: Identifiable, Sendable {
        public let id: String
        public let relativePath: String
        public let documentClass: String
        public let description: String
        public let absolutePath: String
        public let exists: Bool
        public let currentDigest: String?
    }

    public static func loadFixtureInfo(projectRoot: String) -> [HumanReviewFixtureInfo] {
        let corpusDir = (projectRoot as NSString).appendingPathComponent("benchmark/results")
        let manifestPath = (corpusDir as NSString).appendingPathComponent("governed-corpus-manifest.json")
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
              let manifest = try? JSONDecoder().decode(ControlViewerObservation.GovernanceManifest.self, from: data) else {
            return []
        }
        return manifest.fixtures.map { fixture in
            let fullPath = (corpusDir as NSString).appendingPathComponent(fixture.relativePath)
            let exists = FileManager.default.fileExists(atPath: fullPath)
            return HumanReviewFixtureInfo(
                id: fixture.id,
                relativePath: fixture.relativePath,
                documentClass: fixture.documentClass,
                description: fixture.description,
                absolutePath: fullPath,
                exists: exists,
                currentDigest: exists ? HumanReviewDigest.digest(ofFileAt: fullPath) : nil
            )
        }
    }

    public static func loadLedger(projectRoot: String) -> HumanVisualConfirmationLedger? {
        let path = (projectRoot as NSString).appendingPathComponent(Self.ledgerRelativePath)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return try? HumanVisualConfirmationLedger.decode(from: data)
    }

    // MARK: Review state per fixture

    /// Re-read fixture existence and digests from disk (call after reviews,
    /// or when the corpus may have changed under the panel).
    public func reloadFixtures() {
        manifestFixtures = HumanVisualConfirmationStore.loadFixtureInfo(projectRoot: projectRoot)
    }

    public enum FixtureReviewState: Equatable {
        /// No confirmation on record.
        case pending
        /// Confirmed, but the fixture digest changed after review.
        case stale
        /// Reviewer recorded at least one failed dimension.
        case failed
        /// All dimensions confirmed against the current digest.
        case confirmed
    }

    public func reviewState(for fixture: HumanReviewFixtureInfo) -> FixtureReviewState {
        guard let entry = ledger.latestByFixture[fixture.id] else { return .pending }
        // Digest must bind to current bytes; a missing digest (unreadable
        // file) can never match, so it stays stale/pending rather than pass.
        if fixture.currentDigest == nil || entry.sourceDigest != fixture.currentDigest {
            return .stale
        }
        if !entry.failedDimensions.isEmpty { return .failed }
        guard entry.isComplete else { return .pending }
        return .confirmed
    }

    // MARK: Recording

    /// Insert or replace the confirmation for a fixture. The digest is taken
    /// from the fixture's current bytes at record time — the reviewer confirms
    /// what is on disk, not what was reviewed previously.
    public func record(
        fixture: HumanReviewFixtureInfo,
        reviewer: String,
        verdicts: [HumanReviewDimension: HumanReviewVerdict],
        notes: String
    ) throws {
        guard !reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HumanReviewError.missingReviewer
        }
        guard fixture.exists, let digest = fixture.currentDigest else {
            throw HumanReviewError.fixtureUnreadable(fixture.relativePath)
        }
        let entry = HumanVisualConfirmation(
            fixtureId: fixture.id,
            relativePath: fixture.relativePath,
            documentClass: fixture.documentClass,
            sourceDigest: digest,
            reviewer: reviewer.trimmingCharacters(in: .whitespacesAndNewlines),
            verdicts: verdicts,
            notes: notes
        )
        ledger.entries.append(entry)
        ledger.updatedAt = Date()
        try persist()
    }

    public func persist() throws {
        let dir = (projectRoot as NSString)
            .appendingPathComponent("benchmark/results/human-visual-confirmation")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let ledgerPath = (dir as NSString).appendingPathComponent("human-review-ledger.json")
        try ledger.encodedData().write(to: URL(fileURLWithPath: ledgerPath), options: .atomic)
    }

    /// Append a pre-built entry to the ledger and persist (used for
    /// historical-review imports and test seeds).
    public func appendEntry(_ entry: HumanVisualConfirmation) throws {
        ledger.entries.append(entry)
        ledger.updatedAt = Date()
        try persist()
    }

    // MARK: Gate evaluation

    /// Evaluate the gate against the manifest fixture list and current file
    /// digests. Coverage gaps and stale digests yield `pending` (fail-closed);
    /// reviewer-recorded failures yield `fail`.
    public func evaluateGate() -> HumanReviewGateReport {
        var pending: [String] = []
        var stale: [String] = []
        var failed: [String] = []
        var confirmed = 0

        for fixture in manifestFixtures {
            // A fixture missing from disk is a pending gap, not a review failure —
            // the governed manifest and the corpus sweep own file presence.
            guard fixture.exists else {
                pending.append(fixture.id)
                continue
            }
            switch reviewState(for: fixture) {
            case .pending: pending.append(fixture.id)
            case .stale: stale.append(fixture.id)
            case .failed: failed.append(fixture.id); confirmed += 1
            case .confirmed: confirmed += 1
            }
        }

        let status: String
        let summary: String
        if manifestFixtures.isEmpty {
            // §0 fail-closed: an empty/missing manifest is never a vacuous pass.
            status = "pending"
            summary = "PENDING: no governed fixtures found — gate cannot pass with zero coverage."
        } else if !failed.isEmpty {
            status = "fail"
            summary = "FAIL: reviewer recorded failures on \(failed.count) fixture(s): \(failed.joined(separator: ", "))"
        } else if !pending.isEmpty || !stale.isEmpty {
            status = "pending"
            let pendingPart = pending.isEmpty ? "" : "missing: \(pending.joined(separator: ", "))"
            let stalePart = stale.isEmpty ? "" : "stale: \(stale.joined(separator: ", "))"
            let parts = [pendingPart, stalePart].filter { !$0.isEmpty }.joined(separator: "; ")
            summary = "PENDING: \(confirmed)/\(manifestFixtures.count) confirmed (\(parts)). Gate fails closed until all fixtures are reviewed against current bytes."
        } else {
            status = "pass"
            summary = "PASS: \(confirmed)/\(manifestFixtures.count) fixtures human-confirmed against current bytes."
        }

        return HumanReviewGateReport(
            status: status,
            totalFixtures: manifestFixtures.count,
            confirmedCount: confirmed,
            staleCount: stale.count,
            failedCount: failed.count,
            pendingFixtures: pending,
            staleFixtures: stale,
            failedFixtures: failed,
            summary: summary
        )
    }

    /// Persist the gate report artifact (called by tests and the CI step).
    /// Also persists the ledger so the artifact pair is always written together.
    @discardableResult
    public func writeGateReport() throws -> HumanReviewGateReport {
        try persist()
        let report = evaluateGate()
        let dir = (projectRoot as NSString)
            .appendingPathComponent("benchmark/results/human-visual-confirmation")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = (dir as NSString).appendingPathComponent("human-review-gate-report.json")
        try report.encodedData().write(to: URL(fileURLWithPath: path), options: .atomic)
        return report
    }
}

// MARK: - Errors

public enum HumanReviewError: Error, Equatable {
    case missingReviewer
    case fixtureUnreadable(String)
}
