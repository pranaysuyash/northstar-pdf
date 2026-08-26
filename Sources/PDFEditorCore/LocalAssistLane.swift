import Foundation

// MARK: - Local Assist Lane (R7)
//
// The constrained-assist lane from the local-models adoption plan: model
// involvement is limited to *explaining* suggestions and assisting hard-case
// label canonicalization. It never mutates documents, never bypasses review,
// never receives permission authority, and always has a deterministic
// fallback so offline or unsupported systems behave identically to today.

/// A human-readable explanation card assembled from candidate evidence.
public struct SuggestionExplanationCard: Equatable, Hashable, Sendable {
    public let title: String
    public let reasons: [String]
    public let cautions: [String]
    public let providerID: String

    public init(title: String, reasons: [String], cautions: [String], providerID: String) {
        self.title = title
        self.reasons = reasons
        self.cautions = cautions
        self.providerID = providerID
    }
}

/// Deterministic evidence-card builder. This is the baseline every model
/// path must beat, and the fallback whenever a model is unavailable.
public enum SuggestionExplainer {
    public static let providerID = "deterministic-evidence-cards"

    public static func explain(_ candidate: RegionCandidate) -> SuggestionExplanationCard {
        var reasons: [String] = []
        var cautions: [String] = []

        if let fusion = candidate.fusion {
            switch fusion.state {
            case "supported":
                reasons.append("Multiple independent evidence families agree on this region.")
            case "review":
                cautions.append("Evidence is mixed; this region needs your review.")
            default:
                cautions.append("Evidence did not clear the confidence bar.")
            }
            if fusion.reasonCodes.contains("conflictingHighConfidenceEvidence") {
                cautions.append("Strong evidence disagrees about where the field is.")
            }
            if fusion.reasonCodes.contains("singleEvidenceFamily") {
                cautions.append("Only one kind of evidence supports this region.")
            }
        }

        for item in candidate.evidenceItems {
            switch item.kind {
            case .vectorRectangle, .underline:
                reasons.append("Detected drawn geometry at this location.")
            case .repeatedPattern:
                reasons.append(
                    "Grouped \(candidate.groupMemberCount) matching cells into one field.")
            case .textLabel:
                if candidate.hadLabel {
                    reasons.append("A nearby label names this region.")
                }
            case .whitespace:
                reasons.append("Empty space follows a label-shaped text run.")
            case .spatialRelationship:
                continue
            case .nativeField, .manual, .ocrText, .vectorLine:
                continue
            }
        }

        if reasons.isEmpty {
            reasons.append("Detected by document structure analysis.")
        }

        return SuggestionExplanationCard(
            title: candidate.effectiveDisplayName,
            reasons: reasons,
            cautions: cautions,
            providerID: providerID
        )
    }
}

extension RegionCandidate {
    /// Presence flag only; keeps the explainer concise at call sites.
    var hadLabel: Bool { labelText?.isEmpty == false }
}

// MARK: - Label canonicalization assist

/// Hard-case label assist protocol. Deterministic canonicalization remains
/// the source of truth; a model may only propose alternatives for strings
/// the deterministic pass could not handle, and its output carries the same
/// review requirements as any other suggestion.
public protocol LabelCanonicalizationAssist: Sendable {
    var providerID: String { get }
    /// Returns nil when the provider cannot improve on the deterministic
    /// result or is unavailable. Never throws into caller flows.
    func proposeCanonicalForm(for rawLabel: String) async -> CanonicalLabel?
}

/// The always-available baseline: the same pure canonicalizer used at
/// detection time.
public struct DeterministicLabelAssist: LabelCanonicalizationAssist {
    public let providerID = "field-label-canonicalizer"

    public init() {}

    public func proposeCanonicalForm(for rawLabel: String) async -> CanonicalLabel? {
        FieldLabelCanonicalizer.canonicalize(rawLabel)
    }
}

#if canImport(FoundationModels)
import FoundationModels

/// Apple Foundation Models assist, available only on macOS 26+ with an
/// on-device model present. Every failure mode returns nil so callers fall
/// back to `DeterministicLabelAssist`. The model receives only the raw
/// static label string — never document values, paths, or signatures.
@available(macOS 26.0, *)
public struct FoundationModelsLabelAssist: LabelCanonicalizationAssist {
    public let providerID = "foundation-models-label-assist"

    public init() {}

    public func proposeCanonicalForm(for rawLabel: String) async -> CanonicalLabel? {
        // Guarded compile: the session type only exists in the 26 SDK.
        guard ProcessInfo.processInfo.isiOSAppOnMac == false else { return nil }
        do {
            let session = LanguageModelSession()
            let prompt = """
                Rewrite this PDF form label as a short Title Case field name. \
                Remove colons, underscores, numbering, and filler words. \
                Reply with the name only. Label: \(rawLabel)
                """
            let response = try await session.respond(to: prompt)
            let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 80 else { return nil }
            // Model output re-enters through the deterministic validator so
            // formatting rules stay authoritative regardless of the model.
            return FieldLabelCanonicalizer.canonicalize(trimmed)
        } catch {
            return nil
        }
    }
}
#endif

/// Chooses the best available assist at runtime. Callers never see model
/// errors: absence of a model equals today's deterministic behavior.
public enum LabelAssistService {
    public static func canonicalize(_ rawLabel: String) async -> CanonicalLabel? {
        let deterministic = await DeterministicLabelAssist().proposeCanonicalForm(for: rawLabel)
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            // Only consult the model when the deterministic pass had nothing
            // useful to offer (generic rejection or nil).
            if deterministic == nil {
                return await FoundationModelsLabelAssist().proposeCanonicalForm(for: rawLabel)
            }
        }
        #endif
        return deterministic
    }
}
