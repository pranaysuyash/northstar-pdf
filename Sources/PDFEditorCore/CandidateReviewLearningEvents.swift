import CryptoKit
import Foundation

// MARK: - Candidate Review Learning Events (Stage 0)
//
// A value-free, local-only record of how a human adjudicated a detected
// suggestion. These events are the corpus foundation for ranking future
// suggestions on similar layouts (template-scoped priors) without ever
// storing document values, label text, paths, or signature payloads.
//
// Privacy boundary (mirrors the template index posture): structural facts
// only — geometry, detection family, decision kind. The `ValueFreeEventGuard`
// fails closed if a forbidden key ever appears in an encoded event.

public struct CandidateReviewLearningEvent: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    /// Digest binding the event to exact source bytes; never the bytes themselves.
    public let sourceDigest: String
    public let candidateID: UUID
    public let pageIndex: Int
    /// Detection family at review time.
    public let kind: CandidateKind
    public let entryMode: CandidateEntryMode
    public let suggestedFieldType: SuggestedFieldType?
    public let decision: CandidateReviewDecisionKind
    /// Presence flag only — the label string itself never enters the record.
    public let hadLabel: Bool
    public let memberCount: Int
    public let score: Double
    /// Reviewed region geometry. Layout facts are retained; content is not.
    public let bounds: PDFRect
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceDigest: String,
        candidateID: UUID,
        pageIndex: Int,
        kind: CandidateKind,
        entryMode: CandidateEntryMode,
        suggestedFieldType: SuggestedFieldType?,
        decision: CandidateReviewDecisionKind,
        hadLabel: Bool,
        memberCount: Int,
        score: Double,
        bounds: PDFRect,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceDigest = sourceDigest
        self.candidateID = candidateID
        self.pageIndex = pageIndex
        self.kind = kind
        self.entryMode = entryMode
        self.suggestedFieldType = suggestedFieldType
        self.decision = decision
        self.hadLabel = hadLabel
        self.memberCount = max(1, memberCount)
        self.score = min(1, max(0, score))
        self.bounds = bounds
        self.createdAt = createdAt
    }
}

public struct CandidateReviewLearningEventJournal: Codable, Equatable, Sendable {
    public static let contractName = "pdf-editor.candidate-review-learning-journal"
    public static let version = PDFContractVersion(major: 1, minor: 0)

    public let contractName: String
    public let version: PDFContractVersion
    /// Value-free privacy marker validated on open.
    public let privacy: String
    public let events: [CandidateReviewLearningEvent]

    public init(events: [CandidateReviewLearningEvent] = []) {
        self.contractName = Self.contractName
        self.version = Self.version
        self.privacy = "value-free-structural-decisions-only"
        self.events = events
    }

    public func validate() throws {
        guard contractName == Self.contractName else {
            throw PDFSessionPrivacyProvenanceError.sourceMismatch
        }
        guard privacy == "value-free-structural-decisions-only" else {
            throw PDFSessionPrivacyProvenanceError.sourceMismatch
        }
        try ValueFreeEventGuard.assertValueFree(contents: JSONEncoder().encode(self))
    }

    public func appending(_ event: CandidateReviewLearningEvent) -> CandidateReviewLearningEventJournal {
        var updated = events
        updated.append(event)
        return CandidateReviewLearningEventJournal(events: updated)
    }
}

/// Builds events from concrete reviews.
public enum CandidateReviewLearningEventFactory {
    public static func make(
        candidateID: UUID,
        decision: CandidateReviewDecisionKind,
        pageIndex: Int,
        candidate: RegionCandidate?,
        sourceDigest: String
    ) -> CandidateReviewLearningEvent? {
        // Every terminal human decision is learnable; non-terminal state
        // changes (restore-to-suggested) are simply never recorded here.
        let detectionKind = candidate?.kind ?? .manual
        return CandidateReviewLearningEvent(
            sourceDigest: sourceDigest,
            candidateID: candidateID,
            pageIndex: pageIndex,
            kind: detectionKind,
            entryMode: candidate?.entryMode ?? .unknown,
            suggestedFieldType: candidate?.suggestedFieldType,
            decision: decision,
            hadLabel: candidate?.labelText?.isEmpty == false,
            memberCount: candidate?.groupMemberCount ?? 1,
            score: candidate?.score ?? 0,
            bounds: candidate?.bounds ?? PDFRect(x: 0, y: 0, width: 0, height: 0),
            createdAt: Date()
        )
    }
}

/// Fails closed if any forbidden key appears in an encoded event payload.
/// This is the testable boundary required by Stage 0: values, raw text,
/// display names, evidence prose, file paths, and signature material must
/// never enter the learning record.
public enum ValueFreeEventGuard {
    static let forbiddenKeys: Set<String> = [
        "labelText", "displayName", "value", "values", "text", "evidence",
        "evidenceItems", "note", "path", "url", "signature", "image",
        "choices", "name",
    ]

    public static func assertValueFree(contents: Data) throws {
        guard let payload = try JSONSerialization.jsonObject(with: contents) as? [String: Any] else {
            throw PDFSessionPrivacyProvenanceError.sourceMismatch
        }
        var offenders: Set<String> = []
        scan(payload, offenders: &offenders)
        if !offenders.isEmpty {
            throw PDFSessionPrivacyProvenanceError.sourceMismatch
        }
    }

    public static func forbiddenKeysFound(in contents: Data) -> Set<String> {
        guard let payload = try? JSONSerialization.jsonObject(with: contents) as? [String: Any] else {
            return []
        }
        var offenders: Set<String> = []
        scan(payload, offenders: &offenders)
        return offenders
    }

    private static func scan(_ node: Any, offenders: inout Set<String>) {
        if let dictionary = node as? [String: Any] {
            for (key, value) in dictionary {
                if forbiddenKeys.contains(key) {
                    offenders.insert(key)
                }
                scan(value, offenders: &offenders)
            }
        } else if let array = node as? [Any] {
            array.forEach { scan($0, offenders: &offenders) }
        }
    }
}

/// Local JSON persistence, one journal per source digest. Events contain no
/// values, so plaintext-at-rest matches the template index policy.
public struct CandidateReviewLearningEventStore {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            .map { $0.appendingPathComponent("PDFEditor/learning-events", isDirectory: true) }
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("PDFEditor/learning-events", isDirectory: true)
    }

    private func url(for sourceDigest: String) -> URL {
        directory.appendingPathComponent("\(sourceDigest).json")
    }

    public func append(event: CandidateReviewLearningEvent) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = url(for: event.sourceDigest)
        let journal: CandidateReviewLearningEventJournal
        if FileManager.default.fileExists(atPath: target.path),
           let data = try? Data(contentsOf: target),
           let existing = try? JSONDecoder().decode(CandidateReviewLearningEventJournal.self, from: data) {
            journal = existing.appending(event)
        } else {
            journal = CandidateReviewLearningEventJournal(events: [event])
        }
        let encoded = try JSONEncoder().encode(journal)
        try ValueFreeEventGuard.assertValueFree(contents: encoded)
        try encoded.write(to: target, options: [.atomic])
    }

    public func events(sourceDigest: String) -> [CandidateReviewLearningEvent] {
        let target = url(for: sourceDigest)
        guard let data = try? Data(contentsOf: target),
              let journal = try? JSONDecoder().decode(CandidateReviewLearningEventJournal.self, from: data)
        else { return [] }
        return journal.events
    }
}
