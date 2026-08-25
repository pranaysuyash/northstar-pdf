import Foundation

public enum PDFTemplateMigrationState: String, Codable, CaseIterable, Hashable, Sendable {
    case reviewRequired
    case ready
    case abstained
}

public struct PDFTemplateMigrationDecision: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let change: PDFTemplateMappingDiff.Change
    public let before: PDFTemplateMapping?
    public let after: PDFTemplateMapping?
    public let reviewed: Bool
    public let approved: Bool

    public init(
        id: UUID,
        change: PDFTemplateMappingDiff.Change,
        before: PDFTemplateMapping?,
        after: PDFTemplateMapping?,
        reviewed: Bool = false,
        approved: Bool = false
    ) {
        self.id = id
        self.change = change
        self.before = before
        self.after = after
        self.reviewed = reviewed
        self.approved = approved
    }

    public func reviewing(as approved: Bool) -> PDFTemplateMigrationDecision {
        PDFTemplateMigrationDecision(
            id: id,
            change: change,
            before: before,
            after: after,
            reviewed: true,
            approved: approved)
    }
}

public struct PDFTemplateMigrationProposal: Codable, Equatable, Sendable {
    public let id: UUID
    public let templateID: UUID
    public let fromRevisionID: UUID
    public let toRevisionID: UUID
    public let sourceDigest: String
    public let fromRevision: PDFTemplateContract
    public let toRevision: PDFTemplateContract
    public let decisions: [PDFTemplateMigrationDecision]
    public let state: PDFTemplateMigrationState
    public let reasons: [String]

    public init(
        id: UUID = UUID(),
        templateID: UUID,
        fromRevisionID: UUID,
        toRevisionID: UUID,
        sourceDigest: String,
        fromRevision: PDFTemplateContract,
        toRevision: PDFTemplateContract,
        decisions: [PDFTemplateMigrationDecision],
        state: PDFTemplateMigrationState,
        reasons: [String]
    ) {
        self.id = id
        self.templateID = templateID
        self.fromRevisionID = fromRevisionID
        self.toRevisionID = toRevisionID
        self.sourceDigest = sourceDigest
        self.fromRevision = fromRevision
        self.toRevision = toRevision
        self.decisions = decisions
        self.state = state
        self.reasons = reasons
    }

    public var canMaterialize: Bool {
        state == .ready && decisions.allSatisfy(\.reviewed) && !sourceDigest.isEmpty
    }

    public func reviewing(mappingID: UUID, approved: Bool) -> PDFTemplateMigrationProposal {
        let next = decisions.map { decision in
            decision.id == mappingID ? decision.reviewing(as: approved) : decision
        }
        return Self.replacing(self, decisions: next)
    }

    public func materialize() throws -> PDFTemplateContract {
        guard canMaterialize else {
            throw PDFTemplateCaptureError.unresolvedMappingDecisions
        }
        let fromByID = Dictionary(uniqueKeysWithValues: fromRevision.payload.mappings.map { ($0.id, $0) })
        let toByID = Dictionary(uniqueKeysWithValues: toRevision.payload.mappings.map { ($0.id, $0) })
        let approvedIDs = Set(decisions.filter(\.approved).map(\.id))
        let explicitlyRemovedIDs = Set(decisions.filter { $0.approved && $0.change == .removed }.map(\.id))
        let changedIDs = Set(decisions.map(\.id))
        let mappings = Set(fromByID.keys).union(toByID.keys).compactMap { id -> PDFTemplateMapping? in
            if explicitlyRemovedIDs.contains(id) { return nil }
            if approvedIDs.contains(id) { return toByID[id] ?? fromByID[id] }
            if changedIDs.contains(id) { return fromByID[id] }
            return toByID[id] ?? fromByID[id]
        }.map { mapping in
            mapping.status == .proposed ? mapping.reviewed(as: .rejected) : mapping
        }.sorted { $0.id.uuidString < $1.id.uuidString }

        guard !mappings.isEmpty else { throw PDFTemplateCaptureError.noReviewedMappings }
        let fingerprint = PDFTemplateFingerprint(
            algorithm: fromRevision.payload.fingerprint.algorithm,
            keyScope: fromRevision.payload.fingerprint.keyScope,
            featureVersion: fromRevision.payload.fingerprint.featureVersion,
            layoutFingerprint: toRevision.payload.fingerprint.layoutFingerprint,
            exactSourceDigests: Array(Set(fromRevision.payload.fingerprint.exactSourceDigests + [sourceDigest])).sorted(),
            pageSignatures: toRevision.payload.fingerprint.pageSignatures)
        return PDFTemplateContract(
            header: PDFTemplateHeader(templateDigest: toRevision.header.templateDigest, provider: toRevision.header.provider),
            payload: PDFTemplatePayload(
                templateID: fromRevision.payload.templateID,
                revisionID: UUID(),
                parentRevisionID: fromRevision.payload.revisionID,
                displayName: toRevision.payload.displayName,
                lifecycle: .active,
                privacyMode: fromRevision.payload.privacyMode,
                fingerprint: fingerprint,
                mappings: mappings,
                reviewPolicy: toRevision.payload.reviewPolicy))
    }

    private static func replacing(_ proposal: PDFTemplateMigrationProposal, decisions: [PDFTemplateMigrationDecision]) -> PDFTemplateMigrationProposal {
        let ready = decisions.allSatisfy(\.reviewed)
        return PDFTemplateMigrationProposal(
            id: proposal.id,
            templateID: proposal.templateID,
            fromRevisionID: proposal.fromRevisionID,
            toRevisionID: proposal.toRevisionID,
            sourceDigest: proposal.sourceDigest,
            fromRevision: proposal.fromRevision,
            toRevision: proposal.toRevision,
            decisions: decisions,
            state: ready ? .ready : .reviewRequired,
            reasons: ready ? ["Every revision change has an explicit migration decision."] : ["Review every mapping change before migration."])
    }
}

public enum PDFTemplateMigrationPlanner {
    public static func make(
        from: PDFTemplateContract,
        to: PDFTemplateContract,
        sourceDigest: String
    ) throws -> PDFTemplateMigrationProposal {
        guard from.payload.templateID == to.payload.templateID else { throw PDFTemplateCaptureError.templateIDMismatch }
        guard from.payload.lifecycle == .active, to.payload.lifecycle == .active else { throw PDFTemplateCaptureError.parentMustBeActive }
        guard !sourceDigest.isEmpty else { throw PDFTemplateCaptureError.sourceDigestMissing }
        let diff = try PDFTemplateRevisionDiff.make(from: from, to: to)
        let decisions = diff.mappingChanges.map {
            PDFTemplateMigrationDecision(id: $0.id, change: $0.change, before: $0.before, after: $0.after)
        }
        let state: PDFTemplateMigrationState = decisions.isEmpty ? .ready : .reviewRequired
        return PDFTemplateMigrationProposal(
            templateID: from.payload.templateID,
            fromRevisionID: from.payload.revisionID,
            toRevisionID: to.payload.revisionID,
            sourceDigest: sourceDigest,
            fromRevision: from,
            toRevision: to,
            decisions: decisions,
            state: state,
            reasons: decisions.isEmpty
                ? ["The revisions differ only in source identity or layout metadata; no mapping migration is required."]
                : ["The candidate revision contains mapping changes that require explicit review."])
    }
}
