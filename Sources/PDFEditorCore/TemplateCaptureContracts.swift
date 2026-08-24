import Foundation

public enum PDFTemplateCaptureError: Error, Equatable, Sendable {
    case sourceDigestMissing
    case templateMustBeDraft
    case parentMustBeActive
    case noReviewedMappings
    case unresolvedMappingDecisions
    case duplicateRevision
    case templateIDMismatch
    case missingRevisionParent
}

/// A local append-only revision history. The value type makes accidental
/// in-place mutation impossible: appending returns a new history value.
public struct PDFTemplateRevisionSet: Codable, Equatable, Sendable {
    public let templateID: UUID
    public let revisions: [PDFTemplateContract]

    public init(templateID: UUID, revisions: [PDFTemplateContract] = []) throws {
        guard revisions.allSatisfy({ $0.payload.templateID == templateID }) else {
            throw PDFTemplateCaptureError.templateIDMismatch
        }
        let revisionIDs = revisions.map { $0.payload.revisionID }
        guard Set(revisionIDs).count == revisionIDs.count else {
            throw PDFTemplateCaptureError.duplicateRevision
        }
        for revision in revisions {
            if let parentID = revision.payload.parentRevisionID,
               !revisionIDs.contains(parentID) {
                throw PDFTemplateCaptureError.missingRevisionParent
            }
        }
        self.templateID = templateID
        self.revisions = revisions
    }

    public var activeRevision: PDFTemplateContract? {
        revisions.last { $0.payload.lifecycle == .active }
    }

    public func appending(_ revision: PDFTemplateContract) throws -> PDFTemplateRevisionSet {
        guard revision.payload.templateID == templateID else {
            throw PDFTemplateCaptureError.templateIDMismatch
        }
        guard !revisions.contains(where: { $0.payload.revisionID == revision.payload.revisionID }) else {
            throw PDFTemplateCaptureError.duplicateRevision
        }
        if let parentID = revision.payload.parentRevisionID,
           !revisions.contains(where: { $0.payload.revisionID == parentID }) {
            throw PDFTemplateCaptureError.missingRevisionParent
        }
        return try PDFTemplateRevisionSet(templateID: templateID, revisions: revisions + [revision])
    }
}

public enum PDFTemplateCapture {
    /// Creates a value-free draft from one local inspection. Every generated
    /// mapping is proposed until the user explicitly reviews it.
    public static func captureDraft(
        from inspection: DocumentInspection,
        workspaceKey: Data,
        displayName: String = "Reviewed local layout",
        templateID: UUID = UUID(),
        sessionID: UUID? = nil
    ) throws -> PDFTemplateContract {
        guard !inspection.source.sha256.isEmpty else { throw PDFTemplateCaptureError.sourceDigestMissing }
        let fingerprint = PDFTemplateFingerprint.make(
            from: inspection,
            workspaceKey: workspaceKey,
            includeExactSourceDigest: true
        )
        let mappings = draftMappings(from: inspection, fingerprint: fingerprint, sessionID: sessionID)
        let payload = PDFTemplatePayload(
            templateID: templateID,
            revisionID: UUID(),
            parentRevisionID: nil,
            displayName: displayName,
            lifecycle: .draft,
            privacyMode: .localMinimized,
            fingerprint: fingerprint,
            mappings: mappings,
            reviewPolicy: PDFTemplateReviewPolicySet()
        )
        return PDFTemplateContract(
            header: PDFTemplateHeader(
                templateDigest: fingerprint.layoutFingerprint,
                provider: PDFProviderDescriptor(id: "pdf-editor-core", version: "1", platform: "shared")
            ),
            payload: payload
        )
    }

    /// Finalizes a draft by creating a new active child revision. The draft is
    /// never rewritten and remains available for audit or discard.
    public static func activateReviewedRevision(
        from draft: PDFTemplateContract,
        approvedMappingIDs: Set<UUID>,
        reviewedMappingIDs: Set<UUID>,
        sessionID: UUID? = nil
    ) throws -> PDFTemplateContract {
        guard draft.payload.lifecycle == .draft else { throw PDFTemplateCaptureError.templateMustBeDraft }
        let mappingIDs = Set(draft.payload.mappings.map(\.id))
        guard mappingIDs == reviewedMappingIDs, approvedMappingIDs.isSubset(of: reviewedMappingIDs) else {
            throw PDFTemplateCaptureError.unresolvedMappingDecisions
        }
        guard !approvedMappingIDs.isEmpty else { throw PDFTemplateCaptureError.noReviewedMappings }
        let mappings = draft.payload.mappings.map { mapping in
            mapping.reviewed(as: approvedMappingIDs.contains(mapping.id) ? .confirmed : .rejected)
        }
        return makeRevision(
            from: draft,
            mappings: mappings,
            lifecycle: .active,
            sessionID: sessionID
        )
    }

    /// Creates an immutable child revision from an active revision after a
    /// reviewed correction or explicit variant save.
    public static func makeChildRevision(
        from parent: PDFTemplateContract,
        mappings: [PDFTemplateMapping],
        lifecycle: PDFTemplateLifecycle = .active,
        sessionID: UUID? = nil
    ) throws -> PDFTemplateContract {
        guard parent.payload.lifecycle == .active else { throw PDFTemplateCaptureError.parentMustBeActive }
        guard !mappings.isEmpty, mappings.allSatisfy({ $0.status != .proposed }) else {
            throw PDFTemplateCaptureError.unresolvedMappingDecisions
        }
        return makeRevision(from: parent, mappings: mappings, lifecycle: lifecycle, sessionID: sessionID)
    }

    private static func makeRevision(
        from parent: PDFTemplateContract,
        mappings: [PDFTemplateMapping],
        lifecycle: PDFTemplateLifecycle,
        sessionID: UUID?
    ) -> PDFTemplateContract {
        return PDFTemplateContract(
            header: PDFTemplateHeader(
                templateDigest: parent.header.templateDigest,
                provider: parent.header.provider
            ),
            payload: PDFTemplatePayload(
                templateID: parent.payload.templateID,
                revisionID: UUID(),
                parentRevisionID: parent.payload.revisionID,
                displayName: parent.payload.displayName,
                lifecycle: lifecycle,
                privacyMode: parent.payload.privacyMode,
                fingerprint: parent.payload.fingerprint,
                mappings: mappings.map { mapping in
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
                        supersedesMappingID: mapping.supersedesMappingID
                    )
                },
                reviewPolicy: parent.payload.reviewPolicy
            )
        )
    }

    private static func draftMappings(
        from inspection: DocumentInspection,
        fingerprint: PDFTemplateFingerprint,
        sessionID: UUID?
    ) -> [PDFTemplateMapping] {
        var mappings: [PDFTemplateMapping] = []
        let fields = inspection.fields.sorted { ($0.pageIndex, $0.bounds.y, $0.bounds.x) < ($1.pageIndex, $1.bounds.y, $1.bounds.x) }
        for (index, field) in fields.enumerated() {
            let page = fingerprint.pageSignatures.first { $0.pageIndex == field.pageIndex }
            let pageFields = fields.filter { $0.pageIndex == field.pageIndex }
            let fieldIndex = pageFields.firstIndex { $0.id == field.id } ?? 0
            let region = PDFPageRegion(pageIndex: field.pageIndex, rect: field.bounds)
            mappings.append(PDFTemplateMapping(
                semanticKey: "field.\(field.kind.rawValue).\(index + 1)",
                target: PDFTemplateMappingTarget(
                    kind: .nativeField,
                    pageIndex: field.pageIndex,
                    region: region,
                    nativeFieldNameToken: page?.nativeFieldNameTokens[safe: fieldIndex]
                ),
                suggestedFieldType: suggestedType(for: field.kind),
                evidenceReferences: [],
                status: .proposed,
                createdFromSessionID: sessionID
            ))
        }
        let candidates = inspection.candidates
            .filter { $0.coordinate != nil && $0.isDirectlyEditable }
            .sorted { ($0.pageIndex, $0.bounds.y, $0.bounds.x) < ($1.pageIndex, $1.bounds.y, $1.bounds.x) }
        for (index, candidate) in candidates.enumerated() {
            guard let coordinate = candidate.coordinate else { continue }
            mappings.append(PDFTemplateMapping(
                semanticKey: "region.\(candidate.suggestedFieldType?.rawValue ?? "text").\(index + 1)",
                target: PDFTemplateMappingTarget(
                    kind: .staticRegion,
                    pageIndex: candidate.pageIndex,
                    region: coordinate,
                    candidateKind: candidate.kind
                ),
                suggestedFieldType: candidate.suggestedFieldType ?? .unknown,
                evidenceReferences: [candidate.id.uuidString] + candidate.evidenceItems.map { $0.id.uuidString },
                status: .proposed,
                createdFromSessionID: sessionID
            ))
        }
        return mappings
    }

    private static func suggestedType(for kind: NativeFieldKind) -> SuggestedFieldType {
        switch kind {
        case .choice: return .choice
        case .button: return .checkbox
        case .signature: return .signature
        case .text: return .text
        case .unknown: return .unknown
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
