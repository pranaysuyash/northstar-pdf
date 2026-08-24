import CryptoKit
import Foundation

/// The lifecycle of a template revision. A revision is immutable once active;
/// corrections create a child revision instead of rewriting history.
public enum PDFTemplateLifecycle: String, Codable, CaseIterable, Hashable, Sendable {
    case draft
    case active
    case revoked
    case archived
}

public enum PDFTemplatePrivacyMode: String, Codable, CaseIterable, Hashable, Sendable {
    case localMinimized
    case localWithEncryptedLabels
}

public enum PDFTemplateMappingKind: String, Codable, CaseIterable, Hashable, Sendable {
    case nativeField
    case staticRegion
}

public enum PDFTemplateMappingStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case proposed
    case confirmed
    case rejected
    case revoked
    case superseded
}

public enum PDFTemplateReviewPolicy: String, Codable, CaseIterable, Hashable, Sendable {
    case alwaysReviewMappingAndValue
    case reviewMappingOnly
}

public enum PDFTemplateMatchState: String, Codable, CaseIterable, Hashable, Sendable {
    case exact
    case knownVariant
    case familyMatch
    case ambiguous
    case stale
    case unsupported
    case noMatch
}

public struct PDFTemplateRegionSignature: Codable, Equatable, Hashable, Sendable {
    public let kind: CandidateKind
    public let suggestedFieldType: SuggestedFieldType?
    public let normalizedRect: PDFRect
    public let anchorToken: String?
    public let groupMemberCount: Int

    public init(
        kind: CandidateKind,
        suggestedFieldType: SuggestedFieldType?,
        normalizedRect: PDFRect,
        anchorToken: String? = nil,
        groupMemberCount: Int = 1
    ) {
        self.kind = kind
        self.suggestedFieldType = suggestedFieldType
        self.normalizedRect = normalizedRect
        self.anchorToken = anchorToken
        self.groupMemberCount = max(1, groupMemberCount)
    }
}

public struct PDFTemplatePageSignature: Codable, Equatable, Hashable, Sendable {
    public let pageIndex: Int
    public let widthPoints: Double
    public let heightPoints: Double
    public let rotationDegrees: Int
    public let nativeFieldKinds: [NativeFieldKind]
    public let nativeFieldNameTokens: [String]
    public let anchorTokens: [String]
    public let regionSignatures: [PDFTemplateRegionSignature]

    public init(
        pageIndex: Int,
        widthPoints: Double,
        heightPoints: Double,
        rotationDegrees: Int,
        nativeFieldKinds: [NativeFieldKind],
        nativeFieldNameTokens: [String],
        anchorTokens: [String],
        regionSignatures: [PDFTemplateRegionSignature]
    ) {
        self.pageIndex = pageIndex
        self.widthPoints = widthPoints
        self.heightPoints = heightPoints
        self.rotationDegrees = rotationDegrees
        self.nativeFieldKinds = nativeFieldKinds
        self.nativeFieldNameTokens = nativeFieldNameTokens
        self.anchorTokens = anchorTokens
        self.regionSignatures = regionSignatures
    }
}

/// A privacy-minimized layout identity. Raw labels, source bytes, and profile
/// values do not belong in this record. Keyed tokens are intentionally scoped
/// to one local template store and are not globally linkable identifiers.
public struct PDFTemplateFingerprint: Codable, Equatable, Hashable, Sendable {
    public let algorithm: String
    public let keyScope: String
    public let featureVersion: String
    public let layoutFingerprint: String
    public let exactSourceDigests: [String]
    public let pageSignatures: [PDFTemplatePageSignature]

    public init(
        algorithm: String = "layout-v1+hmac-sha256",
        keyScope: String = "workspace",
        featureVersion: String = "layout-features-1",
        layoutFingerprint: String,
        exactSourceDigests: [String] = [],
        pageSignatures: [PDFTemplatePageSignature]
    ) {
        self.algorithm = algorithm
        self.keyScope = keyScope
        self.featureVersion = featureVersion
        self.layoutFingerprint = layoutFingerprint
        self.exactSourceDigests = exactSourceDigests
        self.pageSignatures = pageSignatures
    }

    public static func make(
        from document: DocumentInspection,
        workspaceKey: Data,
        includeExactSourceDigest: Bool = false
    ) -> PDFTemplateFingerprint {
        precondition(!workspaceKey.isEmpty, "A non-empty local workspace key is required for template fingerprints")
        let pages = document.pages.sorted { $0.pageIndex < $1.pageIndex }
        let pageSignatures = pages.map { page in
            let pageFields = document.fields
                .filter { $0.pageIndex == page.pageIndex }
                .sorted { ($0.bounds.y, $0.bounds.x) < ($1.bounds.y, $1.bounds.x) }
            let pageCandidates = document.candidates
                .filter { $0.pageIndex == page.pageIndex }
                .sorted { ($0.bounds.y, $0.bounds.x) < ($1.bounds.y, $1.bounds.x) }
            let normalizedWidth = max(page.bounds.width, 1)
            let normalizedHeight = max(page.bounds.height, 1)
            let regionSignatures = pageCandidates.map { candidate in
                let anchor = candidate.labelText.map { keyedToken(normalizeStructuralText($0), key: workspaceKey) }
                return PDFTemplateRegionSignature(
                    kind: candidate.kind,
                    suggestedFieldType: candidate.suggestedFieldType,
                    normalizedRect: PDFRect(
                        x: candidate.bounds.x / normalizedWidth,
                        y: candidate.bounds.y / normalizedHeight,
                        width: candidate.bounds.width / normalizedWidth,
                        height: candidate.bounds.height / normalizedHeight
                    ),
                    anchorToken: anchor,
                    groupMemberCount: candidate.groupMemberCount
                )
            }
            let fieldNameTokens = pageFields.map {
                keyedToken(normalizeStructuralText($0.name), key: workspaceKey)
            }
            let anchorTokens = pageCandidates.compactMap { candidate in
                candidate.labelText.map { keyedToken(normalizeStructuralText($0), key: workspaceKey) }
            }
            return PDFTemplatePageSignature(
                pageIndex: page.pageIndex,
                widthPoints: page.bounds.width,
                heightPoints: page.bounds.height,
                rotationDegrees: page.rotation,
                nativeFieldKinds: pageFields.map(\.kind),
                nativeFieldNameTokens: fieldNameTokens,
                anchorTokens: anchorTokens,
                regionSignatures: regionSignatures
            )
        }
        let canonical = canonicalDescriptor(pageSignatures)
        return PDFTemplateFingerprint(
            layoutFingerprint: keyedToken(canonical, key: workspaceKey),
            exactSourceDigests: includeExactSourceDigest ? [document.source.sha256] : [],
            pageSignatures: pageSignatures
        )
    }

    private static func canonicalDescriptor(_ pages: [PDFTemplatePageSignature]) -> String {
        pages.map { page in
            let fields = page.nativeFieldKinds.map(\.rawValue).joined(separator: ",")
            let names = page.nativeFieldNameTokens.joined(separator: ",")
            let anchors = page.anchorTokens.joined(separator: ",")
            let regions = page.regionSignatures.map { region in
                let rect = region.normalizedRect
                return [
                    region.kind.rawValue,
                    region.suggestedFieldType?.rawValue ?? "none",
                    String(format: "%.4f,%.4f,%.4f,%.4f", rect.x, rect.y, rect.width, rect.height),
                    region.anchorToken ?? "none",
                    String(region.groupMemberCount)
                ].joined(separator: "~")
            }.joined(separator: "|")
            return [
                String(page.pageIndex),
                String(format: "%.3f,%.3f", page.widthPoints, page.heightPoints),
                String(page.rotationDegrees),
                fields,
                names,
                anchors,
                regions
            ].joined(separator: "#")
        }.joined(separator: "\n")
    }

    private static func keyedToken(_ value: String, key: Data) -> String {
        let symmetricKey = SymmetricKey(data: key)
        let digest = HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: symmetricKey)
        return "hmac:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizeStructuralText(_ text: String) -> String {
        let lowered = text.lowercased()
        let withoutNumbers = lowered.replacingOccurrences(
            of: "[0-9]+",
            with: "#",
            options: .regularExpression
        )
        let withoutPunctuation = withoutNumbers.replacingOccurrences(
            of: "[^a-z#]+",
            with: " ",
            options: .regularExpression
        )
        return withoutPunctuation.split(whereSeparator: { $0 == " " }).joined(separator: " ")
    }
}

public struct PDFTemplateMappingTarget: Codable, Equatable, Hashable, Sendable {
    public let kind: PDFTemplateMappingKind
    public let pageIndex: Int
    public let region: PDFPageRegion
    public let nativeFieldNameToken: String?
    public let anchorToken: String?
    public let candidateKind: CandidateKind?

    public init(
        kind: PDFTemplateMappingKind,
        pageIndex: Int,
        region: PDFPageRegion,
        nativeFieldNameToken: String? = nil,
        anchorToken: String? = nil,
        candidateKind: CandidateKind? = nil
    ) {
        self.kind = kind
        self.pageIndex = pageIndex
        self.region = region
        self.nativeFieldNameToken = nativeFieldNameToken
        self.anchorToken = anchorToken
        self.candidateKind = candidateKind
    }
}

public struct PDFTemplateMapping: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let semanticKey: String
    public let target: PDFTemplateMappingTarget
    public let suggestedFieldType: SuggestedFieldType
    public let evidenceReferences: [String]
    public let status: PDFTemplateMappingStatus
    public let reviewPolicy: PDFTemplateReviewPolicy
    public let sourceVariantID: UUID?
    public let createdFromSessionID: UUID?
    public let supersedesMappingID: UUID?

    public init(
        id: UUID = UUID(),
        semanticKey: String,
        target: PDFTemplateMappingTarget,
        suggestedFieldType: SuggestedFieldType,
        evidenceReferences: [String] = [],
        status: PDFTemplateMappingStatus = .proposed,
        reviewPolicy: PDFTemplateReviewPolicy = .alwaysReviewMappingAndValue,
        sourceVariantID: UUID? = nil,
        createdFromSessionID: UUID? = nil,
        supersedesMappingID: UUID? = nil
    ) {
        self.id = id
        self.semanticKey = semanticKey
        self.target = target
        self.suggestedFieldType = suggestedFieldType
        self.evidenceReferences = evidenceReferences
        self.status = status
        self.reviewPolicy = reviewPolicy
        self.sourceVariantID = sourceVariantID
        self.createdFromSessionID = createdFromSessionID
        self.supersedesMappingID = supersedesMappingID
    }

    public var isApproved: Bool {
        status == .confirmed && !semanticKey.isEmpty && target.pageIndex == target.region.pageIndex
    }

    public func reviewed(as newStatus: PDFTemplateMappingStatus) -> PDFTemplateMapping {
        PDFTemplateMapping(
            id: id,
            semanticKey: semanticKey,
            target: target,
            suggestedFieldType: suggestedFieldType,
            evidenceReferences: evidenceReferences,
            status: newStatus,
            reviewPolicy: reviewPolicy,
            sourceVariantID: sourceVariantID,
            createdFromSessionID: createdFromSessionID,
            supersedesMappingID: supersedesMappingID
        )
    }
}

public struct PDFTemplateReviewPolicySet: Codable, Equatable, Hashable, Sendable {
    public let defaultMappingPolicy: PDFTemplateReviewPolicy
    public let requireValueReview: Bool
    public let allowBatchMappingApproval: Bool

    public init(
        defaultMappingPolicy: PDFTemplateReviewPolicy = .alwaysReviewMappingAndValue,
        requireValueReview: Bool = true,
        allowBatchMappingApproval: Bool = false
    ) {
        self.defaultMappingPolicy = defaultMappingPolicy
        self.requireValueReview = requireValueReview
        self.allowBatchMappingApproval = allowBatchMappingApproval
    }
}

public struct PDFTemplatePayload: Codable, Equatable, Hashable, Sendable {
    public let templateID: UUID
    public let revisionID: UUID
    public let parentRevisionID: UUID?
    public let displayName: String
    public let lifecycle: PDFTemplateLifecycle
    public let privacyMode: PDFTemplatePrivacyMode
    public let fingerprint: PDFTemplateFingerprint
    public let mappings: [PDFTemplateMapping]
    public let reviewPolicy: PDFTemplateReviewPolicySet

    public init(
        templateID: UUID = UUID(),
        revisionID: UUID = UUID(),
        parentRevisionID: UUID? = nil,
        displayName: String,
        lifecycle: PDFTemplateLifecycle = .draft,
        privacyMode: PDFTemplatePrivacyMode = .localMinimized,
        fingerprint: PDFTemplateFingerprint,
        mappings: [PDFTemplateMapping] = [],
        reviewPolicy: PDFTemplateReviewPolicySet = PDFTemplateReviewPolicySet()
    ) {
        self.templateID = templateID
        self.revisionID = revisionID
        self.parentRevisionID = parentRevisionID
        self.displayName = displayName
        self.lifecycle = lifecycle
        self.privacyMode = privacyMode
        self.fingerprint = fingerprint
        self.mappings = mappings
        self.reviewPolicy = reviewPolicy
    }

    public var approvedMappings: [PDFTemplateMapping] {
        mappings.filter(\.isApproved)
    }
}

public struct PDFTemplateHeader: Codable, Equatable, Hashable, Sendable {
    public let contractName: String
    public let version: PDFContractVersion
    public let templateDigest: String
    public let generatedAt: Date
    public let provider: PDFProviderDescriptor

    public init(
        templateDigest: String,
        provider: PDFProviderDescriptor,
        generatedAt: Date = Date(),
        version: PDFContractVersion = .current,
        contractName: String = "pdf-editor.template"
    ) {
        self.contractName = contractName
        self.version = version
        self.templateDigest = templateDigest
        self.generatedAt = generatedAt
        self.provider = provider
    }
}

public struct PDFTemplateContract: Codable, Equatable, Sendable {
    public let header: PDFTemplateHeader
    public let payload: PDFTemplatePayload

    public init(header: PDFTemplateHeader, payload: PDFTemplatePayload) {
        self.header = header
        self.payload = payload
    }

    public var isReadableByCurrentVersion: Bool {
        header.version.isReadableBy()
    }
}

public enum PDFProfileValue: Codable, Equatable, Hashable, Sendable {
    case text(String)
    case boolean(Bool)
    case choice(String)
    case assetReference(String)

    private enum CodingKeys: String, CodingKey { case kind, text, boolean, choice, assetID }
    private enum Kind: String, Codable { case text, boolean, choice, assetReference }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(value):
            try container.encode(Kind.text, forKey: .kind)
            try container.encode(value, forKey: .text)
        case let .boolean(value):
            try container.encode(Kind.boolean, forKey: .kind)
            try container.encode(value, forKey: .boolean)
        case let .choice(value):
            try container.encode(Kind.choice, forKey: .kind)
            try container.encode(value, forKey: .choice)
        case let .assetReference(value):
            try container.encode(Kind.assetReference, forKey: .kind)
            try container.encode(value, forKey: .assetID)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .text: self = .text(try container.decode(String.self, forKey: .text))
        case .boolean: self = .boolean(try container.decode(Bool.self, forKey: .boolean))
        case .choice: self = .choice(try container.decode(String.self, forKey: .choice))
        case .assetReference: self = .assetReference(try container.decode(String.self, forKey: .assetID))
        }
    }
}

public struct PDFProfileValueRecord: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let semanticKey: String
    public let value: PDFProfileValue

    public init(id: UUID = UUID(), semanticKey: String, value: PDFProfileValue) {
        self.id = id
        self.semanticKey = semanticKey
        self.value = value
    }
}

public enum PDFProfileStorageScope: String, Codable, CaseIterable, Hashable, Sendable {
    case deviceLocal
    case userSelectedVault
}

public struct PDFProfilePayload: Codable, Equatable, Hashable, Sendable {
    public let profileID: UUID
    public let revisionID: UUID
    public let parentRevisionID: UUID?
    public let displayName: String
    public let revisionNumber: Int
    public let storageScope: PDFProfileStorageScope
    public let requiresUnlock: Bool
    public let values: [PDFProfileValueRecord]

    public init(
        profileID: UUID = UUID(),
        revisionID: UUID = UUID(),
        parentRevisionID: UUID? = nil,
        displayName: String,
        revisionNumber: Int = 1,
        storageScope: PDFProfileStorageScope = .deviceLocal,
        requiresUnlock: Bool = true,
        values: [PDFProfileValueRecord] = []
    ) {
        precondition(revisionNumber > 0, "Profile revision numbers must be positive")
        self.profileID = profileID
        self.revisionID = revisionID
        self.parentRevisionID = parentRevisionID
        self.displayName = displayName
        self.revisionNumber = revisionNumber
        self.storageScope = storageScope
        self.requiresUnlock = requiresUnlock
        self.values = values
    }

    public func value(for semanticKey: String) -> PDFProfileValue? {
        values.first { $0.semanticKey == semanticKey }?.value
    }
}

public struct PDFProfileHeader: Codable, Equatable, Hashable, Sendable {
    public let contractName: String
    public let version: PDFContractVersion
    public let profileID: UUID
    public let revisionID: UUID
    public let generatedAt: Date
    public let provider: PDFProviderDescriptor

    public init(
        profileID: UUID,
        revisionID: UUID,
        provider: PDFProviderDescriptor,
        generatedAt: Date = Date(),
        version: PDFContractVersion = .current,
        contractName: String = "pdf-editor.profile"
    ) {
        self.contractName = contractName
        self.version = version
        self.profileID = profileID
        self.revisionID = revisionID
        self.generatedAt = generatedAt
        self.provider = provider
    }
}

public struct PDFProfileContract: Codable, Equatable, Sendable {
    public let header: PDFProfileHeader
    public let payload: PDFProfilePayload

    public init(header: PDFProfileHeader, payload: PDFProfilePayload) {
        self.header = header
        self.payload = payload
    }

    public var isReadableByCurrentVersion: Bool {
        header.version.isReadableBy()
    }
}

public struct PDFTemplateMatchProposal: Codable, Equatable, Hashable, Sendable {
    public let state: PDFTemplateMatchState
    public let score: Double
    public let templateID: UUID?
    public let revisionID: UUID?
    public let sourceDigest: String
    public let reasons: [String]
    public let approvedMappingIDs: [UUID]
    public let requiresMappingReview: Bool
    public let requiresValueReview: Bool

    public init(
        state: PDFTemplateMatchState,
        score: Double,
        templateID: UUID?,
        revisionID: UUID?,
        sourceDigest: String,
        reasons: [String],
        approvedMappingIDs: [UUID] = [],
        requiresMappingReview: Bool = true,
        requiresValueReview: Bool = true
    ) {
        self.state = state
        self.score = score
        self.templateID = templateID
        self.revisionID = revisionID
        self.sourceDigest = sourceDigest
        self.reasons = reasons
        self.approvedMappingIDs = approvedMappingIDs
        self.requiresMappingReview = requiresMappingReview
        self.requiresValueReview = requiresValueReview
    }
}

public enum PDFTemplateMatcher {
    public static func propose(
        fingerprint: PDFTemplateFingerprint,
        sourceDigest: String,
        template: PDFTemplateContract
    ) -> PDFTemplateMatchProposal {
        let payload = template.payload
        guard payload.lifecycle == .active else {
            return PDFTemplateMatchProposal(
                state: .unsupported,
                score: 0,
                templateID: payload.templateID,
                revisionID: payload.revisionID,
                sourceDigest: sourceDigest,
                reasons: ["The template revision is not active and cannot propose mappings."]
            )
        }

        let exactSource = fingerprint.exactSourceDigests.contains(sourceDigest)
        let layoutMatch = fingerprint.layoutFingerprint == payload.fingerprint.layoutFingerprint
        let state: PDFTemplateMatchState
        let score: Double
        let reasons: [String]
        if exactSource {
            state = .exact
            score = 1.0
            reasons = ["The source digest is a reviewed exact template example."]
        } else if layoutMatch {
            state = .knownVariant
            score = 0.90
            reasons = ["The keyed layout fingerprint matches, but this source digest is a different example."]
        } else {
            state = .noMatch
            score = 0
            reasons = ["The source does not match the template fingerprint."]
        }

        let approvedIDs = state == .noMatch ? [] : payload.approvedMappings.map(\.id)
        return PDFTemplateMatchProposal(
            state: state,
            score: score,
            templateID: payload.templateID,
            revisionID: payload.revisionID,
            sourceDigest: sourceDigest,
            reasons: reasons,
            approvedMappingIDs: approvedIDs,
            requiresMappingReview: true,
            requiresValueReview: payload.reviewPolicy.requireValueReview
        )
    }
}
