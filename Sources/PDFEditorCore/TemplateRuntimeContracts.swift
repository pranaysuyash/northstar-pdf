import CryptoKit
import Foundation

/// Runtime state that is intentionally separate from the persisted template.
/// A template proposes mappings; a completion proposal records what the user
/// reviewed for one source document.
public enum PDFTemplateMappingReviewState: String, Codable, CaseIterable, Hashable, Sendable {
    case pending
    case approved
    case rejected
}

public enum PDFTemplateValueReviewState: String, Codable, CaseIterable, Hashable, Sendable {
    case unresolved
    case resolvedUnreviewed
    case approved
    case rejected
}

/// The two approvals deliberately carry different identities. Mapping review
/// answers "is this source region the right target?" Profile-value review
/// answers "is this exact value from this profile revision authorized here?".
/// A boolean status without these bindings would allow an old approval to be
/// replayed after either side changed.
public struct PDFTemplateMappingApproval: Codable, Equatable, Hashable, Sendable {
    public let state: PDFTemplateMappingReviewState
    public let mappingID: UUID
    public let targetID: String?
    public let coordinate: PDFPageRegion
    public let reviewedAt: Date

    public init(
        state: PDFTemplateMappingReviewState,
        mappingID: UUID,
        targetID: String?,
        coordinate: PDFPageRegion,
        reviewedAt: Date = Date()
    ) {
        self.state = state
        self.mappingID = mappingID
        self.targetID = targetID
        self.coordinate = coordinate
        self.reviewedAt = reviewedAt
    }
}

public struct PDFTemplateProfileValueApproval: Codable, Equatable, Hashable, Sendable {
    public let state: PDFTemplateValueReviewState
    public let profileID: UUID?
    public let profileRevisionID: UUID?
    public let semanticKey: String
    public let valueDigest: String?
    public let reviewedAt: Date

    public init(
        state: PDFTemplateValueReviewState,
        profileID: UUID?,
        profileRevisionID: UUID?,
        semanticKey: String,
        valueDigest: String?,
        reviewedAt: Date = Date()
    ) {
        self.state = state
        self.profileID = profileID
        self.profileRevisionID = profileRevisionID
        self.semanticKey = semanticKey
        self.valueDigest = valueDigest
        self.reviewedAt = reviewedAt
    }
}

public enum PDFTemplateValueDigest {
    public static func make(_ value: PDFProfileValue) -> String {
        let canonical: String
        switch value {
        case let .text(text): canonical = "text:\(text)"
        case let .choice(choice): canonical = "choice:\(choice)"
        case let .boolean(boolean): canonical = "boolean:\(boolean ? "true" : "false")"
        case let .assetReference(assetID): canonical = "assetReference:\(assetID)"
        }
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

public enum PDFTemplateLearningEventKind: String, Codable, CaseIterable, Hashable, Sendable {
    case mappingConfirmed
    case mappingRejected
    case mappingMoved
    case mappingRetyped
    case completionValidated
    case revisionSaved
    case revisionRevoked
}

public enum PDFTemplateLearningEventStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case pending
    case applied
    case discarded
}

public struct PDFTemplateLearningEvent: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let templateID: UUID
    public let baseRevisionID: UUID
    public let sourceDigest: String
    public let kind: PDFTemplateLearningEventKind
    public let mappingID: UUID?
    public let candidateID: UUID?
    public let completionSessionID: UUID?
    public let status: PDFTemplateLearningEventStatus
    public let note: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        templateID: UUID,
        baseRevisionID: UUID,
        sourceDigest: String,
        kind: PDFTemplateLearningEventKind,
        mappingID: UUID? = nil,
        candidateID: UUID? = nil,
        completionSessionID: UUID? = nil,
        status: PDFTemplateLearningEventStatus = .pending,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.templateID = templateID
        self.baseRevisionID = baseRevisionID
        self.sourceDigest = sourceDigest
        self.kind = kind
        self.mappingID = mappingID
        self.candidateID = candidateID
        self.completionSessionID = completionSessionID
        self.status = status
        self.note = note
        self.createdAt = createdAt
    }

    public func applying() -> PDFTemplateLearningEvent {
        replacing(status: .applied)
    }

    public func discarding() -> PDFTemplateLearningEvent {
        replacing(status: .discarded)
    }

    private func replacing(status: PDFTemplateLearningEventStatus) -> PDFTemplateLearningEvent {
        PDFTemplateLearningEvent(
            id: id,
            templateID: templateID,
            baseRevisionID: baseRevisionID,
            sourceDigest: sourceDigest,
            kind: kind,
            mappingID: mappingID,
            candidateID: candidateID,
            completionSessionID: completionSessionID,
            status: status,
            note: note,
            createdAt: createdAt
        )
    }
}

public struct PDFTemplateCompletionEntry: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let mappingID: UUID
    public let semanticKey: String
    public let target: PDFTemplateMappingTarget
    public let candidateID: UUID?
    public let mappingReview: PDFTemplateMappingReviewState
    public let profileID: UUID?
    public let profileRevisionID: UUID?
    public let value: PDFProfileValue?
    public let valueReview: PDFTemplateValueReviewState
    public let mappingApproval: PDFTemplateMappingApproval?
    public let profileValueApproval: PDFTemplateProfileValueApproval?
    /// Native field names are keyed in a template. The adapter resolves the
    /// current document's actual field name only after the user reviews it.
    public let resolvedTargetID: String?

    public init(
        id: UUID = UUID(),
        mappingID: UUID,
        semanticKey: String,
        target: PDFTemplateMappingTarget,
        candidateID: UUID? = nil,
        mappingReview: PDFTemplateMappingReviewState = .pending,
        profileID: UUID? = nil,
        profileRevisionID: UUID? = nil,
        value: PDFProfileValue? = nil,
        valueReview: PDFTemplateValueReviewState? = nil,
        mappingApproval: PDFTemplateMappingApproval? = nil,
        profileValueApproval: PDFTemplateProfileValueApproval? = nil,
        resolvedTargetID: String? = nil
    ) {
        self.id = id
        self.mappingID = mappingID
        self.semanticKey = semanticKey
        self.target = target
        self.candidateID = candidateID
        self.mappingReview = mappingReview
        self.profileID = profileID
        self.profileRevisionID = profileRevisionID
        self.value = value
        self.valueReview = valueReview ?? (value == nil ? .unresolved : .resolvedUnreviewed)
        self.mappingApproval = mappingApproval
        self.profileValueApproval = profileValueApproval
        self.resolvedTargetID = resolvedTargetID
    }

    public var isApproved: Bool {
        guard mappingReview == .approved,
              valueReview == .approved,
              value != nil,
              mappingApproval?.state == .approved,
              mappingApproval?.mappingID == mappingID,
              mappingApproval?.coordinate == target.region,
              mappingApproval?.targetID == resolvedTargetID,
              profileValueApproval?.state == .approved,
              profileValueApproval?.profileID == profileID,
              profileValueApproval?.profileRevisionID == profileRevisionID,
              profileValueApproval?.semanticKey == semanticKey,
              let value,
              profileValueApproval?.valueDigest == PDFTemplateValueDigest.make(value)
        else { return false }
        return true
    }

    public func reviewingMapping(as state: PDFTemplateMappingReviewState) -> PDFTemplateCompletionEntry {
        return PDFTemplateCompletionEntry(
            id: id,
            mappingID: mappingID,
            semanticKey: semanticKey,
            target: target,
            candidateID: candidateID,
            mappingReview: state,
            profileID: profileID,
            profileRevisionID: profileRevisionID,
            value: value,
            valueReview: valueReview,
            mappingApproval: PDFTemplateMappingApproval(
                state: state,
                mappingID: mappingID,
                targetID: resolvedTargetID,
                coordinate: target.region
            ),
            profileValueApproval: profileValueApproval,
            resolvedTargetID: resolvedTargetID
        )
    }

    public func reviewingValue(_ value: PDFProfileValue?, as state: PDFTemplateValueReviewState) -> PDFTemplateCompletionEntry {
        PDFTemplateCompletionEntry(
            id: id,
            mappingID: mappingID,
            semanticKey: semanticKey,
            target: target,
            candidateID: candidateID,
            mappingReview: mappingReview,
            profileID: profileID,
            profileRevisionID: profileRevisionID,
            value: value,
            valueReview: state,
            mappingApproval: mappingApproval,
            profileValueApproval: PDFTemplateProfileValueApproval(
                state: state,
                profileID: profileID,
                profileRevisionID: profileRevisionID,
                semanticKey: semanticKey,
                valueDigest: value.map(PDFTemplateValueDigest.make)
            ),
            resolvedTargetID: resolvedTargetID
        )
    }

    public func resolvingTarget(_ targetID: String?) -> PDFTemplateCompletionEntry {
        let targetChanged = targetID != resolvedTargetID
        return PDFTemplateCompletionEntry(
            id: id,
            mappingID: mappingID,
            semanticKey: semanticKey,
            target: target,
            candidateID: candidateID,
            mappingReview: targetChanged ? .pending : mappingReview,
            profileID: profileID,
            profileRevisionID: profileRevisionID,
            value: value,
            valueReview: valueReview,
            mappingApproval: targetChanged ? nil : mappingApproval,
            profileValueApproval: profileValueApproval,
            resolvedTargetID: targetID
        )
    }

    private func replacing(mappingReview: PDFTemplateMappingReviewState) -> PDFTemplateCompletionEntry {
        PDFTemplateCompletionEntry(
            id: id,
            mappingID: mappingID,
            semanticKey: semanticKey,
            target: target,
            candidateID: candidateID,
            mappingReview: mappingReview,
            profileID: profileID,
            profileRevisionID: profileRevisionID,
            value: value,
            valueReview: valueReview,
            mappingApproval: mappingApproval,
            profileValueApproval: profileValueApproval,
            resolvedTargetID: resolvedTargetID
        )
    }
}

public enum PDFTemplateCompletionError: Error, Equatable, Sendable {
    case staleSource(expected: String, actual: String)
    case noMatch(PDFTemplateMatchState)
    case mappingReviewRequired(UUID)
    case valueReviewRequired(UUID)
    case mappingApprovalRequired(UUID)
    case profileValueApprovalRequired(UUID)
    case missingValue(UUID)
    case unresolvedNativeTarget(UUID)
    case coordinateMismatch(UUID)
    case unsupportedValue(UUID)
}

public struct PDFTemplateCompletionProposal: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let templateID: UUID
    public let revisionID: UUID
    public let sourceDigest: String
    public let matchState: PDFTemplateMatchState
    public let reasons: [String]
    public let entries: [PDFTemplateCompletionEntry]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        templateID: UUID,
        revisionID: UUID,
        sourceDigest: String,
        matchState: PDFTemplateMatchState,
        reasons: [String] = [],
        entries: [PDFTemplateCompletionEntry],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.templateID = templateID
        self.revisionID = revisionID
        self.sourceDigest = sourceDigest
        self.matchState = matchState
        self.reasons = reasons
        self.entries = entries
        self.createdAt = createdAt
    }

    public static func make(
        match: PDFTemplateMatchProposal,
        template: PDFTemplateContract,
        profile: PDFProfileContract? = nil,
        sessionID: UUID = UUID()
    ) -> PDFTemplateCompletionProposal? {
        guard let templateID = match.templateID, let revisionID = match.revisionID else { return nil }
        let mappings = template.payload.mappings.filter { match.approvedMappingIDs.contains($0.id) }
        let entries = mappings.map { mapping in
            let value = profile?.payload.value(for: mapping.semanticKey)
            return PDFTemplateCompletionEntry(
                mappingID: mapping.id,
                semanticKey: mapping.semanticKey,
                target: mapping.target,
                candidateID: mapping.evidenceReferences.compactMap(UUID.init(uuidString:)).first,
                profileID: profile?.payload.profileID,
                profileRevisionID: profile?.payload.revisionID,
                value: value
            )
        }
        return PDFTemplateCompletionProposal(
            sessionID: sessionID,
            templateID: templateID,
            revisionID: revisionID,
            sourceDigest: match.sourceDigest,
            matchState: match.state,
            reasons: match.reasons,
            entries: entries
        )
    }

    public var isReviewableMatch: Bool {
        switch matchState {
        case .exact, .knownVariant, .familyMatch: return true
        case .ambiguous, .stale, .unsupported, .noMatch: return false
        }
    }

    public var isReadyToMaterialize: Bool {
        isReviewableMatch && !entries.isEmpty && entries.allSatisfy { entry in
            entry.isApproved
                && entry.target.pageIndex == entry.target.region.pageIndex
                && (entry.target.kind == .staticRegion || !(entry.resolvedTargetID?.isEmpty ?? true))
        }
    }

    public func reviewingMapping(_ mappingID: UUID, approved: Bool) -> PDFTemplateCompletionProposal {
        replacing(entries: entries.map { entry in
            entry.mappingID == mappingID
                ? entry.reviewingMapping(as: approved ? .approved : .rejected)
                : entry
        })
    }

    public func reviewingValue(_ mappingID: UUID, value: PDFProfileValue?, approved: Bool = false) -> PDFTemplateCompletionProposal {
        replacing(entries: entries.map { entry in
            guard entry.mappingID == mappingID else { return entry }
            let state: PDFTemplateValueReviewState = approved && value != nil && entry.profileID != nil && entry.profileRevisionID != nil
                ? .approved
                : value == nil ? .unresolved : .resolvedUnreviewed
            return entry.reviewingValue(value, as: state)
        })
    }

    public func resolvingNativeTarget(_ mappingID: UUID, targetID: String?) -> PDFTemplateCompletionProposal {
        replacing(entries: entries.map { entry in
            entry.mappingID == mappingID ? entry.resolvingTarget(targetID) : entry
        })
    }

    public func materializeOperations(currentSourceDigest: String) throws -> [EditOperation] {
        guard currentSourceDigest == sourceDigest else {
            throw PDFTemplateCompletionError.staleSource(expected: sourceDigest, actual: currentSourceDigest)
        }
        guard isReviewableMatch else { throw PDFTemplateCompletionError.noMatch(matchState) }
        var operations: [EditOperation] = []
        for entry in entries {
            guard entry.mappingReview == .approved else {
                throw PDFTemplateCompletionError.mappingReviewRequired(entry.mappingID)
            }
            guard entry.mappingApproval?.state == .approved,
                  entry.mappingApproval?.mappingID == entry.mappingID,
                  entry.mappingApproval?.coordinate == entry.target.region,
                  entry.mappingApproval?.targetID == entry.resolvedTargetID
            else {
                throw PDFTemplateCompletionError.mappingApprovalRequired(entry.mappingID)
            }
            guard entry.valueReview == .approved else {
                throw PDFTemplateCompletionError.valueReviewRequired(entry.mappingID)
            }
            guard entry.isApproved else {
                throw PDFTemplateCompletionError.profileValueApprovalRequired(entry.mappingID)
            }
            guard let value = entry.value else {
                throw PDFTemplateCompletionError.missingValue(entry.mappingID)
            }
            guard entry.target.pageIndex == entry.target.region.pageIndex else {
                throw PDFTemplateCompletionError.coordinateMismatch(entry.mappingID)
            }
            if entry.target.kind == .nativeField && (entry.resolvedTargetID?.isEmpty ?? true) {
                throw PDFTemplateCompletionError.unresolvedNativeTarget(entry.mappingID)
            }
            let payload = try Self.editPayload(for: value, entry: entry)
            operations.append(EditOperation(
                pageIndex: entry.target.pageIndex,
                targetID: entry.target.kind == .nativeField ? entry.resolvedTargetID : nil,
                kind: entry.target.kind == .nativeField ? .nativeFieldValue : .overlayText,
                value: Self.stringValue(for: value),
                bounds: entry.target.region.rect,
                candidateID: entry.candidateID,
                sessionID: sessionID,
                sourceDigest: sourceDigest,
                coordinate: entry.target.region,
                payload: payload,
                reversible: true,
                destructive: false
            ))
        }
        return operations
    }

    private func replacing(entries: [PDFTemplateCompletionEntry]) -> PDFTemplateCompletionProposal {
        PDFTemplateCompletionProposal(
            id: id,
            sessionID: sessionID,
            templateID: templateID,
            revisionID: revisionID,
            sourceDigest: sourceDigest,
            matchState: matchState,
            reasons: reasons,
            entries: entries,
            createdAt: createdAt
        )
    }

    private static func stringValue(for value: PDFProfileValue) -> String {
        switch value {
        case let .text(text), let .choice(text), let .assetReference(text): return text
        case let .boolean(value): return value ? "true" : "false"
        }
    }

    private static func editPayload(for value: PDFProfileValue, entry: PDFTemplateCompletionEntry) throws -> EditPayload {
        switch value {
        case let .text(text): return .text(text)
        case let .choice(choice): return .choice(choice)
        case let .boolean(value) where entry.target.kind == .nativeField: return .boolean(value)
        case .boolean, .assetReference: throw PDFTemplateCompletionError.unsupportedValue(entry.mappingID)
        }
    }
}

public struct PDFTemplateRevisionPromotion: Codable, Equatable, Hashable, Sendable {
    public let templateID: UUID
    public let parentRevisionID: UUID
    public let promotedRevisionID: UUID
    public let sourceDigest: String
    public let learningEventIDs: [UUID]
    public let validationAt: Date

    public init(
        templateID: UUID,
        parentRevisionID: UUID,
        promotedRevisionID: UUID = UUID(),
        sourceDigest: String,
        learningEventIDs: [UUID],
        validationAt: Date
    ) {
        self.templateID = templateID
        self.parentRevisionID = parentRevisionID
        self.promotedRevisionID = promotedRevisionID
        self.sourceDigest = sourceDigest
        self.learningEventIDs = learningEventIDs
        self.validationAt = validationAt
    }
}

public enum PDFTemplateRevisionGate {
    /// Only a strict validation is allowed to promote learning. Warnings and
    /// unknown checks remain useful evidence, but cannot change future behavior.
    public static func canPromote(
        template: PDFTemplateContract,
        sourceDigest: String,
        validation: ValidationReport,
        events: [PDFTemplateLearningEvent]
    ) -> Bool {
        guard template.payload.lifecycle == .active,
              validation.status == .validated,
              validation.sourceUnchanged,
              validation.outputReopenable,
              validation.sourceDigest == sourceDigest,
              !events.isEmpty else { return false }
        guard events.allSatisfy({
            $0.templateID == template.payload.templateID
                && $0.baseRevisionID == template.payload.revisionID
                && $0.sourceDigest == sourceDigest
                && $0.status == .pending
        }) else { return false }
        return !validation.checks.contains { $0.status == .unknown || $0.status == .failed }
    }

    public static func promote(
        template: PDFTemplateContract,
        sourceDigest: String,
        validation: ValidationReport,
        events: [PDFTemplateLearningEvent],
        promotedRevisionID: UUID = UUID()
    ) -> PDFTemplateRevisionPromotion? {
        guard canPromote(template: template, sourceDigest: sourceDigest, validation: validation, events: events) else {
            return nil
        }
        return PDFTemplateRevisionPromotion(
            templateID: template.payload.templateID,
            parentRevisionID: template.payload.revisionID,
            promotedRevisionID: promotedRevisionID,
            sourceDigest: sourceDigest,
            learningEventIDs: events.map(\.id),
            validationAt: validation.validatedAt ?? Date()
        )
    }
}
