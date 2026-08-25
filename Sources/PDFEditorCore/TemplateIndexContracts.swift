import Foundation

/// A value-free local index entry. The index stores enough keyed structural
/// evidence to retrieve a revision, but never stores a profile value or PDF
/// bytes. The full revision remains in the encrypted template store.
public struct PDFTemplateIndexEntry: Codable, Equatable, Sendable {
    public let templateID: UUID
    public let revisionID: UUID
    public let parentRevisionID: UUID?
    public let displayName: String
    public let lifecycle: PDFTemplateLifecycle
    public let fingerprint: PDFTemplateFingerprint
    public let exactSourceDigests: [String]

    public init(revision: PDFTemplateContract) {
        self.templateID = revision.payload.templateID
        self.revisionID = revision.payload.revisionID
        self.parentRevisionID = revision.payload.parentRevisionID
        self.displayName = revision.payload.displayName
        self.lifecycle = revision.payload.lifecycle
        self.fingerprint = revision.payload.fingerprint
        self.exactSourceDigests = revision.payload.fingerprint.exactSourceDigests
    }
}

public struct PDFTemplateIndex: Codable, Equatable, Sendable {
    public static let contractName = "pdf-editor.template-index"
    public let contractName: String
    public let version: PDFContractVersion
    public let privacy: String
    public let entries: [PDFTemplateIndexEntry]

    public init(entries: [PDFTemplateIndexEntry]) throws {
        self.contractName = Self.contractName
        self.version = .current
        self.privacy = "value-free-keyed-layout-only"
        self.entries = entries.sorted { ($0.templateID.uuidString, $0.revisionID.uuidString) < ($1.templateID.uuidString, $1.revisionID.uuidString) }
        try validate()
    }

    public init(histories: [PDFTemplateRevisionSet]) throws {
        try self.init(entries: histories.flatMap { history in
            history.revisions.map { revision in PDFTemplateIndexEntry(revision: revision) }
        })
    }

    public func validate() throws {
        guard contractName == Self.contractName, version.isReadableBy(), privacy == "value-free-keyed-layout-only" else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("template index contract or privacy is invalid")
        }
        var seen = Set<String>()
        for entry in entries {
            guard seen.insert("\(entry.templateID.uuidString):\(entry.revisionID.uuidString)").inserted else {
                throw PDFTemplatePersistenceError.invalidRevisionHistory("duplicate template index revision")
            }
            guard !entry.displayName.isEmpty,
                  !entry.exactSourceDigests.contains(where: { $0.contains("%PDF-") }) else {
                throw PDFTemplatePersistenceError.invalidRevisionHistory("template index contains unsafe content")
            }
        }
    }
}

public struct PDFTemplateIndexCandidate: Codable, Equatable, Sendable {
    public let state: PDFTemplateMatchState
    public let score: Double
    public let entry: PDFTemplateIndexEntry
    public let sourceDigest: String
    public let reasons: [String]

    public init(state: PDFTemplateMatchState, score: Double, entry: PDFTemplateIndexEntry, sourceDigest: String, reasons: [String]) {
        self.state = state
        self.score = score
        self.entry = entry
        self.sourceDigest = sourceDigest
        self.reasons = reasons
    }
}

public struct PDFTemplateIndexQueryResult: Codable, Equatable, Sendable {
    public let state: PDFTemplateMatchState
    public let candidates: [PDFTemplateIndexCandidate]
    public let selectedRevisionID: UUID?
    public let abstained: Bool
    public let ambiguityMargin: Double
    public let reasons: [String]

    public init(
        state: PDFTemplateMatchState,
        candidates: [PDFTemplateIndexCandidate],
        selectedRevisionID: UUID?,
        abstained: Bool,
        ambiguityMargin: Double = 0.05,
        reasons: [String] = []
    ) {
        self.state = state
        self.candidates = candidates
        self.selectedRevisionID = selectedRevisionID
        self.abstained = abstained
        self.ambiguityMargin = ambiguityMargin
        self.reasons = reasons
    }
}

public enum PDFTemplateIndexQuery {
    private static let familyThreshold = 0.72
    private static let ambiguityMargin = 0.05

    public static func query(
        index: PDFTemplateIndex,
        fingerprint: PDFTemplateFingerprint,
        sourceDigest: String,
        maxResults: Int = 8
    ) throws -> PDFTemplateIndexQueryResult {
        try index.validate()
        guard !sourceDigest.isEmpty else { throw PDFTemplateCaptureError.sourceDigestMissing }
        let candidates = index.entries.compactMap { entry -> PDFTemplateIndexCandidate? in
            let exact = entry.exactSourceDigests.contains(sourceDigest)
            let layout = entry.fingerprint.layoutFingerprint == fingerprint.layoutFingerprint
            let score = layout ? 0.90 : structuralScore(entry.fingerprint, fingerprint)
            let state: PDFTemplateMatchState
            if entry.lifecycle != .active {
                state = exact ? .stale : .unsupported
            } else if exact {
                state = .exact
            } else if layout {
                state = .knownVariant
            } else if score >= familyThreshold {
                state = .familyMatch
            } else {
                return nil
            }
            return PDFTemplateIndexCandidate(
                state: state,
                score: exact ? 1 : score,
                entry: entry,
                sourceDigest: sourceDigest,
                reasons: exact
                    ? ["The source digest is a reviewed exact template example."]
                    : layout
                        ? ["The keyed layout fingerprint matches a reviewed source variant."]
                        : ["The structural family score exceeds the review threshold; mapping review remains required."])
        }.sorted {
            let ranks: [PDFTemplateMatchState: Int] = [.exact: 3, .knownVariant: 2, .familyMatch: 1, .stale: 0, .unsupported: 0, .noMatch: 0]
            if ranks[$0.state, default: 0] != ranks[$1.state, default: 0] {
                return ranks[$0.state, default: 0] > ranks[$1.state, default: 0]
            }
            if $0.score != $1.score { return $0.score > $1.score }
            return "\($0.entry.templateID.uuidString):\($0.entry.revisionID.uuidString)" < "\($1.entry.templateID.uuidString):\($1.entry.revisionID.uuidString)"
        }
        guard let top = candidates.first else {
            return PDFTemplateIndexQueryResult(state: .noMatch, candidates: [], selectedRevisionID: nil, abstained: true, reasons: ["No reviewed template family exceeded the acceptance threshold."])
        }
        if let second = candidates.dropFirst().first,
           top.state == .familyMatch,
           second.state == .familyMatch,
           top.score - second.score < ambiguityMargin {
            return PDFTemplateIndexQueryResult(
                state: .ambiguous,
                candidates: Array(candidates.prefix(maxResults)),
                selectedRevisionID: nil,
                abstained: true,
                reasons: ["Multiple local template revisions are too close to select safely."])
        }
        return PDFTemplateIndexQueryResult(
            state: top.state,
            candidates: Array(candidates.prefix(maxResults)),
            selectedRevisionID: top.entry.revisionID,
            abstained: top.state == .stale,
            reasons: top.reasons)
    }

    private static func structuralScore(_ left: PDFTemplateFingerprint, _ right: PDFTemplateFingerprint) -> Double {
        let leftPages = left.pageSignatures
        let rightPages = right.pageSignatures
        let count = max(max(leftPages.count, rightPages.count), 1)
        let shared = min(leftPages.count, rightPages.count)
        guard shared > 0 else { return 0 }
        var total = 0.0
        for index in 0..<shared {
            let a = leftPages[index]
            let b = rightPages[index]
            let width = max(max(a.widthPoints, b.widthPoints), 1)
            let height = max(max(a.heightPoints, b.heightPoints), 1)
            let geometry = max(0, 1 - (abs(a.widthPoints - b.widthPoints) / width + abs(a.heightPoints - b.heightPoints) / height) / 2)
            let rotation = a.rotationDegrees == b.rotationDegrees ? 1.0 : 0.0
            let fields = histogramSimilarity(a.nativeFieldKinds.map(\.rawValue), b.nativeFieldKinds.map(\.rawValue))
            let regions = histogramSimilarity(
                a.regionSignatures.map { "\($0.kind.rawValue):\($0.suggestedFieldType?.rawValue ?? "unknown")" },
                b.regionSignatures.map { "\($0.kind.rawValue):\($0.suggestedFieldType?.rawValue ?? "unknown")" })
            let anchors = histogramSimilarity(a.anchorTokens, b.anchorTokens)
            total += geometry * 0.25 + rotation * 0.10 + fields * 0.25 + regions * 0.25 + anchors * 0.15
        }
        return total / Double(count)
    }

    private static func histogramSimilarity(_ left: [String], _ right: [String]) -> Double {
        var counts: [String: (Int, Int)] = [:]
        for value in left {
            var pair = counts[value] ?? (0, 0)
            pair.0 += 1
            counts[value] = pair
        }
        for value in right {
            var pair = counts[value] ?? (0, 0)
            pair.1 += 1
            counts[value] = pair
        }
        let total = counts.values.reduce(0) { $0 + max($1.0, $1.1) }
        let distance = counts.values.reduce(0) { $0 + abs($1.0 - $1.1) }
        return total == 0 ? 1 : max(0, 1 - Double(distance) / Double(total))
    }
}
