import Foundation

/// The resolver selects a profile identity only. It never returns profile
/// values, and a selected profile still requires the normal per-value review
/// before any PDF operation can be materialized.
public enum PDFTemplateProfileResolutionState: String, Codable, CaseIterable, Hashable, Sendable {
    case selected
    case ambiguous
    case noMatch
}

public struct PDFTemplateProfileResolutionCandidate: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let profileID: UUID
    public let revisionID: UUID
    public let displayName: String
    public let score: Double
    public let matchedMappingIDs: [UUID]
    public let missingSemanticKeys: [String]
    public let typeMismatches: [String]
    public let reasons: [String]

    public init(
        profileID: UUID,
        revisionID: UUID,
        displayName: String,
        score: Double,
        matchedMappingIDs: [UUID],
        missingSemanticKeys: [String],
        typeMismatches: [String],
        reasons: [String]
    ) {
        self.id = profileID
        self.profileID = profileID
        self.revisionID = revisionID
        self.displayName = displayName
        self.score = score
        self.matchedMappingIDs = matchedMappingIDs
        self.missingSemanticKeys = missingSemanticKeys
        self.typeMismatches = typeMismatches
        self.reasons = reasons
    }
}

public struct PDFTemplateProfileResolutionResult: Codable, Equatable, Hashable, Sendable {
    public let state: PDFTemplateProfileResolutionState
    public let candidates: [PDFTemplateProfileResolutionCandidate]
    public let selectedProfileID: UUID?
    public let selectedRevisionID: UUID?
    public let abstained: Bool
    public let ambiguityMargin: Double
    public let reasons: [String]

    public init(
        state: PDFTemplateProfileResolutionState,
        candidates: [PDFTemplateProfileResolutionCandidate],
        selectedProfileID: UUID? = nil,
        selectedRevisionID: UUID? = nil,
        abstained: Bool,
        ambiguityMargin: Double = 0.05,
        reasons: [String] = []
    ) {
        self.state = state
        self.candidates = candidates
        self.selectedProfileID = selectedProfileID
        self.selectedRevisionID = selectedRevisionID
        self.abstained = abstained
        self.ambiguityMargin = ambiguityMargin
        self.reasons = reasons
    }
}

public enum PDFTemplateProfileResolver {
    public static func resolve(
        template: PDFTemplateContract,
        profiles: [PDFProfileContract],
        ambiguityMargin: Double = 0.05
    ) -> PDFTemplateProfileResolutionResult {
        let mappings = template.payload.mappings.filter(\.isApproved)
        guard !mappings.isEmpty else {
            return PDFTemplateProfileResolutionResult(
                state: .noMatch,
                candidates: [],
                abstained: true,
                ambiguityMargin: ambiguityMargin,
                reasons: ["No reviewed template mappings are available for profile resolution."])
        }

        let candidates = profiles.map { profile in
            candidate(for: profile, mappings: mappings)
        }.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.profileID.uuidString < $1.profileID.uuidString
        }

        guard let top = candidates.first, top.missingSemanticKeys.isEmpty, top.typeMismatches.isEmpty else {
            return PDFTemplateProfileResolutionResult(
                state: .noMatch,
                candidates: candidates,
                abstained: true,
                ambiguityMargin: ambiguityMargin,
                reasons: ["No unlocked profile contains every reviewed semantic key with a compatible value kind."])
        }

        if let second = candidates.dropFirst().first,
           second.missingSemanticKeys.isEmpty,
           second.typeMismatches.isEmpty,
           top.score - second.score < ambiguityMargin {
            return PDFTemplateProfileResolutionResult(
                state: .ambiguous,
                candidates: candidates,
                abstained: true,
                ambiguityMargin: ambiguityMargin,
                reasons: ["Multiple complete profiles are too close to select safely."])
        }

        return PDFTemplateProfileResolutionResult(
            state: .selected,
            candidates: candidates,
            selectedProfileID: top.profileID,
            selectedRevisionID: top.revisionID,
            abstained: false,
            ambiguityMargin: ambiguityMargin,
            reasons: ["Exactly one complete, type-compatible profile was selected for review."])
    }

    private static func candidate(
        for profile: PDFProfileContract,
        mappings: [PDFTemplateMapping]
    ) -> PDFTemplateProfileResolutionCandidate {
        let values = Dictionary(uniqueKeysWithValues: profile.payload.values.map { ($0.semanticKey, $0.value) })
        var matched: [UUID] = []
        var missing: [String] = []
        var mismatches: [String] = []

        for mapping in mappings {
            guard let value = values[mapping.semanticKey] else {
                missing.append(mapping.semanticKey)
                continue
            }
            if isCompatible(value, with: mapping.suggestedFieldType) {
                matched.append(mapping.id)
            } else {
                mismatches.append(mapping.semanticKey)
            }
        }

        let total = Double(max(mappings.count, 1))
        let score = Double(matched.count) / total
        var reasons = ["Matched \(matched.count) of \(mappings.count) reviewed mapping(s) without exposing values."]
        if !missing.isEmpty { reasons.append("Missing \(missing.count) semantic key(s).") }
        if !mismatches.isEmpty { reasons.append("\(mismatches.count) value kind mismatch(es).") }
        return PDFTemplateProfileResolutionCandidate(
            profileID: profile.payload.profileID,
            revisionID: profile.payload.revisionID,
            displayName: profile.payload.displayName,
            score: score,
            matchedMappingIDs: matched.sorted { $0.uuidString < $1.uuidString },
            missingSemanticKeys: missing.sorted(),
            typeMismatches: mismatches.sorted(),
            reasons: reasons)
    }

    private static func isCompatible(_ value: PDFProfileValue, with type: SuggestedFieldType?) -> Bool {
        switch type {
        case .checkbox:
            if case .boolean = value { return true }
            return false
        case .choice, .radio:
            if case .choice = value { return true }
            return false
        case .signature:
            if case .assetReference = value { return true }
            return false
        case .text, .date, .number, .unknown, nil:
            switch value {
            case .text, .choice: return true
            case .boolean, .assetReference: return false
            }
        }
    }
}
