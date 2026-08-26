import Foundation
import Testing
@testable import PDFEditorCore

/// R5/R6 follow-up: measures the scored alias matcher against the legacy
/// first-hit substring heuristics it replaced, over a labeled corpus.
///
/// Evidence tier: Tier 2 (targeted test). The assertion is comparative —
/// the scored matcher must be at least as accurate as the heuristics on
/// every category, strictly better on the disambiguation traps that
/// motivated the replacement.

private struct MatcherCase {
    let label: String
    let expected: StandardSemanticKey?
    let category: String
}

private let benchmarkCorpus: [MatcherCase] = [
    // Exact / near-exact labels
    MatcherCase(label: "Full Name:", expected: .fullName, category: "exact"),
    MatcherCase(label: "First Name", expected: .firstName, category: "exact"),
    MatcherCase(label: "Last Name:", expected: .lastName, category: "exact"),
    MatcherCase(label: "Email Address:", expected: .email, category: "exact"),
    MatcherCase(label: "Phone Number:", expected: .phone, category: "exact"),
    MatcherCase(label: "Date of Birth:", expected: .dateOfBirth, category: "exact"),
    MatcherCase(label: "Street Address:", expected: .addressStreet, category: "exact"),
    MatcherCase(label: "City:", expected: .addressCity, category: "exact"),
    MatcherCase(label: "State:", expected: .addressState, category: "exact"),
    MatcherCase(label: "ZIP Code:", expected: .addressZip, category: "exact"),
    MatcherCase(label: "Social Security Number:", expected: .ssn, category: "exact"),
    MatcherCase(label: "Employer:", expected: .employer, category: "exact"),
    MatcherCase(label: "Job Title:", expected: .jobTitle, category: "exact"),

    // Aliases
    MatcherCase(label: "DOB", expected: .dateOfBirth, category: "alias"),
    MatcherCase(label: "Birth Date", expected: .dateOfBirth, category: "alias"),
    MatcherCase(label: "Surname", expected: .lastName, category: "alias"),
    MatcherCase(label: "Given Name", expected: .firstName, category: "alias"),
    MatcherCase(label: "Telephone", expected: .phone, category: "alias"),
    MatcherCase(label: "Postal Code", expected: .addressZip, category: "alias"),
    MatcherCase(label: "Print Name", expected: .fullName, category: "alias"),

    // Disambiguation traps (the reason the heuristics were replaced)
    MatcherCase(label: "Applicant Name:", expected: .fullName, category: "trap"),
    MatcherCase(label: "Name:", expected: .fullName, category: "trap"),
    MatcherCase(label: "1. FULL NAME:______", expected: .fullName, category: "trap"),
    MatcherCase(label: "Guardian First Name:", expected: .firstName, category: "trap"),
    MatcherCase(label: "Employee Name", expected: .fullName, category: "trap"),

    // Non-field text must not match anything
    MatcherCase(label: "Section 2 of 4", expected: nil, category: "negative"),
    MatcherCase(label: "Ordinary paragraph about weather", expected: nil, category: "negative"),
    MatcherCase(label: "For Office Use Only", expected: nil, category: "negative"),
    MatcherCase(label: "Note:", expected: nil, category: "negative"),
]

/// Verbatim port of the pre-R5 first-hit substring rules, iterated in the
/// same canonical key order the old profile fixture used.
private func legacyMatch(for rawLabel: String) -> StandardSemanticKey? {
    let name = rawLabel.lowercased()
    let orderedKeys: [StandardSemanticKey] = [
        .fullName, .firstName, .lastName, .email, .phone, .dateOfBirth,
        .addressStreet, .addressCity, .addressState, .addressZip,
        .addressCountry, .ssn, .employer, .jobTitle,
    ]
    for key in orderedKeys {
        let k = key.rawValue.lowercased()
        if name.contains("name") && k.contains("fullname") { return key }
        if name.contains("first") && k.contains("firstname") { return key }
        if name.contains("last") && k.contains("lastname") { return key }
        if name.contains("email") && k.contains("email") { return key }
        if name.contains("phone") && k.contains("phone") { return key }
        if name.contains("address") && k.contains("address.street") { return key }
        if name.contains("city") && k.contains("address.city") { return key }
        if name.contains("state") && k.contains("address.state") { return key }
        if (name.contains("zip") || name.contains("postal")) && k.contains("address.zip") { return key }
        if name.contains("ssn") && k.contains("ssn") { return key }
        if (name.contains("dob") || name.contains("birth")) && k.contains("dateofbirth") { return key }
        if (name.contains("employer") || name.contains("company")) && k.contains("employer") { return key }
        if name.contains("title") && k.contains("jobtitle") { return key }
    }
    return nil
}

private func scoredMatch(for rawLabel: String) -> StandardSemanticKey? {
    guard let best = UserProfile.matchScoreBestInCorpus(rawLabel) else { return nil }
    return best
}

extension UserProfile {
    /// Benchmark helper: best semantic key for a label across all standard
    /// keys, independent of any stored values.
    static func matchScoreBestInCorpus(_ rawLabel: String) -> StandardSemanticKey? {
        var best: (key: StandardSemanticKey, score: Double)?
        for key in [
            StandardSemanticKey.fullName, .firstName, .lastName, .email, .phone,
            .dateOfBirth, .addressStreet, .addressCity, .addressState,
            .addressZip, .addressCountry, .ssn, .employer, .jobTitle,
        ] {
            let score = UserProfile.labelAliases[key.rawValue].map { aliases in
                Self.scoreAliases(aliases, for: rawLabel)
            } ?? 0
            if score >= 0.6, score > (best?.score ?? 0) {
                best = (key, score)
            }
        }
        return best?.key
    }

    /// Extracted scoring core shared with `matchScore(label:semanticKey:)`.
    static func scoreAliases(_ aliases: [String], for rawLabel: String) -> Double {
        let labelTokens = normalizedTokenSet(rawLabel)
        guard !labelTokens.isEmpty else { return 0 }
        var best = 0.0
        for alias in aliases {
            let aliasTokens = normalizedTokenSet(alias)
            guard !aliasTokens.isEmpty else { continue }
            if labelTokens == aliasTokens { return 1.0 }
            if aliasTokens.isSubset(of: labelTokens) {
                let precision = Double(aliasTokens.count) / Double(labelTokens.count)
                best = max(best, 0.6 + 0.35 * precision)
                continue
            }
            let shared = labelTokens.intersection(aliasTokens)
            if aliasTokens.count >= 2 && shared.count >= 1 {
                let recall = Double(shared.count) / Double(aliasTokens.count)
                if recall >= 0.5 {
                    best = max(best, 0.3 + 0.25 * recall)
                }
            }
        }
        return min(best, 0.99)
    }

    static func normalizedTokenSet(_ text: String) -> Set<String> {
        let cleaned = text.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
        return Set(cleaned.split(separator: " ").map(String.init))
    }
}

struct ProfileMatcherBenchmarkTests {

    @Test func scoredMatcherMeetsOrBeatsLegacyEverywhere() {
        var legacyCorrect = 0
        var scoredCorrect = 0
        var failures: [String] = []

        for testCase in benchmarkCorpus {
            let legacyPick = legacyMatch(for: testCase.label)
            let scoredPick = scoredMatch(for: testCase.label)

            if legacyPick == testCase.expected { legacyCorrect += 1 }
            if scoredPick == testCase.expected {
                scoredCorrect += 1
            } else {
                failures.append(
                    "[\(testCase.category)] \(testCase.label) → expected "
                        + "\(testCase.expected?.rawValue ?? "nil"), got \(scoredPick?.rawValue ?? "nil")")
            }
        }

        let total = benchmarkCorpus.count
        let legacyRate = Double(legacyCorrect) / Double(total)
        let scoredRate = Double(scoredCorrect) / Double(total)

        // Comparative gate: the replacement must not regress anywhere.
        #expect(scoredRate >= legacyRate,
                "scored \(scoredRate) < legacy \(legacyRate): \(failures)")
        // And must clear the traps that motivated it.
        #expect(scoredCorrect == total, "scored matcher misses: \(failures)")

        print(
            "matcher-benchmark: scored \(scoredCorrect)/\(total), "
                + "legacy \(legacyCorrect)/\(total)"
        )
    }

    @Test func disambiguationTrapsFailUnderLegacyHeuristics() {
        // Sensitivity S2 evidence: the first-name trap genuinely mis-fired
        // under the old rules ("first name" contains "name" → fullName).
        #expect(legacyMatch(for: "Guardian First Name:") == .fullName)
        #expect(scoredMatch(for: "Guardian First Name:") == .firstName)
    }
}
