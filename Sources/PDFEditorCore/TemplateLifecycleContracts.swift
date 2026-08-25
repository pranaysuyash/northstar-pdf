import Foundation

/// Value-free transfer envelope for reviewed template history. A transfer is
/// layout knowledge, not a PDF copy and not a profile export.
public struct PDFTemplateTransferEnvelope: Codable, Equatable, Sendable {
    public let contractName: String
    public let version: PDFContractVersion
    public let exportedAt: Date
    public let containsSourceBytes: Bool
    public let containsProfileValues: Bool
    public let history: PDFTemplateRevisionSet

    public init(
        history: PDFTemplateRevisionSet,
        exportedAt: Date = Date(),
        containsSourceBytes: Bool = false,
        containsProfileValues: Bool = false
    ) {
        self.contractName = "pdf-editor.template-transfer"
        self.version = .current
        self.exportedAt = exportedAt
        self.containsSourceBytes = containsSourceBytes
        self.containsProfileValues = containsProfileValues
        self.history = history
    }

    public func validate() throws {
        guard contractName == "pdf-editor.template-transfer",
              version.isReadableBy(),
              !containsSourceBytes,
              !containsProfileValues
        else { throw PDFTemplateCaptureError.invalidTransferEnvelope }
        guard history.templateID == history.revisions.first?.payload.templateID else {
            throw PDFTemplateCaptureError.invalidTransferEnvelope
        }
    }
}

public struct PDFTemplateMappingDiff: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum Change: String, Codable, CaseIterable, Hashable, Sendable {
        case added
        case removed
        case changed
    }

    public let id: UUID
    public let change: Change
    public let before: PDFTemplateMapping?
    public let after: PDFTemplateMapping?

    public init(id: UUID, change: Change, before: PDFTemplateMapping?, after: PDFTemplateMapping?) {
        self.id = id
        self.change = change
        self.before = before
        self.after = after
    }
}

/// Revision comparison deliberately excludes generated timestamps and
/// provider serialization. It exposes only user-relevant mapping and variant
/// changes for audit and review UI.
public struct PDFTemplateRevisionDiff: Codable, Equatable, Hashable, Sendable {
    public let templateID: UUID
    public let fromRevisionID: UUID
    public let toRevisionID: UUID
    public let lifecycleChanged: Bool
    public let fingerprintChanged: Bool
    public let exactSourceDigestsAdded: [String]
    public let exactSourceDigestsRemoved: [String]
    public let mappingChanges: [PDFTemplateMappingDiff]

    public init(
        templateID: UUID,
        fromRevisionID: UUID,
        toRevisionID: UUID,
        lifecycleChanged: Bool,
        fingerprintChanged: Bool,
        exactSourceDigestsAdded: [String],
        exactSourceDigestsRemoved: [String],
        mappingChanges: [PDFTemplateMappingDiff]
    ) {
        self.templateID = templateID
        self.fromRevisionID = fromRevisionID
        self.toRevisionID = toRevisionID
        self.lifecycleChanged = lifecycleChanged
        self.fingerprintChanged = fingerprintChanged
        self.exactSourceDigestsAdded = exactSourceDigestsAdded
        self.exactSourceDigestsRemoved = exactSourceDigestsRemoved
        self.mappingChanges = mappingChanges
    }

    public static func make(from: PDFTemplateContract, to: PDFTemplateContract) throws -> PDFTemplateRevisionDiff {
        guard from.payload.templateID == to.payload.templateID else {
            throw PDFTemplateCaptureError.templateIDMismatch
        }
        let before = Dictionary(uniqueKeysWithValues: from.payload.mappings.map { ($0.id, $0) })
        let after = Dictionary(uniqueKeysWithValues: to.payload.mappings.map { ($0.id, $0) })
        let mappingChanges = Set(before.keys).union(after.keys).compactMap { id -> PDFTemplateMappingDiff? in
            let left = before[id]
            let right = after[id]
            guard left != right else { return nil }
            let change: PDFTemplateMappingDiff.Change = left == nil ? .added : right == nil ? .removed : .changed
            return PDFTemplateMappingDiff(id: id, change: change, before: left, after: right)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        let beforeDigests = Set(from.payload.fingerprint.exactSourceDigests)
        let afterDigests = Set(to.payload.fingerprint.exactSourceDigests)
        return PDFTemplateRevisionDiff(
            templateID: from.payload.templateID,
            fromRevisionID: from.payload.revisionID,
            toRevisionID: to.payload.revisionID,
            lifecycleChanged: from.payload.lifecycle != to.payload.lifecycle,
            fingerprintChanged: from.payload.fingerprint.layoutFingerprint != to.payload.fingerprint.layoutFingerprint,
            exactSourceDigestsAdded: afterDigests.subtracting(beforeDigests).sorted(),
            exactSourceDigestsRemoved: beforeDigests.subtracting(afterDigests).sorted(),
            mappingChanges: mappingChanges)
    }
}

public struct PDFTemplateLearningEventJournal: Codable, Equatable, Hashable, Sendable {
    public let templateID: UUID
    public let events: [PDFTemplateLearningEvent]

    public init(templateID: UUID, events: [PDFTemplateLearningEvent] = []) throws {
        guard events.allSatisfy({ $0.templateID == templateID }) else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("learning event template identity mismatch")
        }
        let ids = events.map(\.id)
        guard Set(ids).count == ids.count else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("learning event IDs must be unique")
        }
        self.templateID = templateID
        self.events = events
    }

    public func appending(_ event: PDFTemplateLearningEvent) throws -> PDFTemplateLearningEventJournal {
        guard event.templateID == templateID else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("learning event template identity mismatch")
        }
        guard !events.contains(where: { $0.id == event.id }) else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("duplicate learning event")
        }
        return try PDFTemplateLearningEventJournal(templateID: templateID, events: events + [event])
    }
}

public extension PDFTemplateCapture {
    /// Creates the reusable child revision produced by a strictly validated
    /// completion. The caller still decides when to persist it.
    static func makeValidatedCompletionRevision(
        from parent: PDFTemplateContract,
        sourceDigest: String,
        sessionID: UUID? = nil
    ) throws -> PDFTemplateContract {
        guard parent.payload.lifecycle == .active else {
            throw PDFTemplateCaptureError.parentMustBeActive
        }
        guard !sourceDigest.isEmpty else {
            throw PDFTemplateCaptureError.sourceDigestMissing
        }
        let fingerprint = PDFTemplateFingerprint(
            algorithm: parent.payload.fingerprint.algorithm,
            keyScope: parent.payload.fingerprint.keyScope,
            featureVersion: parent.payload.fingerprint.featureVersion,
            layoutFingerprint: parent.payload.fingerprint.layoutFingerprint,
            exactSourceDigests: Array(Set(parent.payload.fingerprint.exactSourceDigests + [sourceDigest])).sorted(),
            pageSignatures: parent.payload.fingerprint.pageSignatures)
        let mappings = parent.payload.mappings.map { mapping in
            PDFTemplateMapping(
                id: mapping.id,
                semanticKey: mapping.semanticKey,
                target: mapping.target,
                suggestedFieldType: mapping.suggestedFieldType,
                evidenceReferences: mapping.evidenceReferences,
                status: mapping.status,
                reviewPolicy: mapping.reviewPolicy,
                sourceVariantID: mapping.sourceVariantID,
                createdFromSessionID: sessionID ?? mapping.createdFromSessionID,
                supersedesMappingID: mapping.supersedesMappingID)
        }
        return PDFTemplateContract(
            header: PDFTemplateHeader(
                templateDigest: parent.header.templateDigest,
                provider: parent.header.provider),
            payload: PDFTemplatePayload(
                templateID: parent.payload.templateID,
                revisionID: UUID(),
                parentRevisionID: parent.payload.revisionID,
                displayName: parent.payload.displayName,
                lifecycle: .active,
                privacyMode: parent.payload.privacyMode,
                fingerprint: fingerprint,
                mappings: mappings,
                reviewPolicy: parent.payload.reviewPolicy))
    }
}
