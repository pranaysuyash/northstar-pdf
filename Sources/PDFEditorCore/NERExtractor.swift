import Foundation

/// Named Entity Recognition (NER) extractor — identifies people, organizations,
/// and locations in PDF text using pattern-based detection.
///
/// First principle: PDFs contain named entities that users need to find and
/// understand. NER transforms unstructured text into structured, actionable
/// information about who, what, and where.
///
/// Approach: Rule-based pattern matching with contextual validation.
/// No external NLP dependencies — pure Swift, works offline.
///
/// Doctrine alignment:
/// - §3: Do things smartly — pattern-based, no AI dependency
/// - §5: Evidence-based — confidence scores for every entity
/// - §8: Capability routing — works standalone

// MARK: - NER Entity Types

/// Extended entity type for NER.
public enum NEREntityType: String, Sendable, CaseIterable {
    case person = "person"
    case organization = "organization"
    case location = "location"
    case date = "date"
    case amount = "amount"
    case email = "email"
    case url = "url"
    case phoneNumber = "phone_number"
    case percentage = "percentage"
    case sectionReference = "section_reference"
    case pageReference = "page_reference"
}

/// A named entity extracted from text.
public struct NEREntity: Sendable, Identifiable {
    public let id: String
    public let type: NEREntityType
    public let value: String
    public let normalizedValue: String
    public let sourcePageIndex: Int
    public let sourceText: String
    public let confidence: Double
    public let startIndex: Int
    public let endIndex: Int

    public init(
        id: String = UUID().uuidString,
        type: NEREntityType,
        value: String,
        normalizedValue: String? = nil,
        sourcePageIndex: Int,
        sourceText: String = "",
        confidence: Double = 0.8,
        startIndex: Int = 0,
        endIndex: Int = 0
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.normalizedValue = normalizedValue ?? value
        self.sourcePageIndex = sourcePageIndex
        self.sourceText = sourceText
        self.confidence = confidence
        self.startIndex = startIndex
        self.endIndex = endIndex
    }
}

/// Result of NER extraction.
public struct NERResult: Sendable {
    public let entities: [NEREntity]
    public let byType: [NEREntityType: [NEREntity]]
    public let totalCount: Int
    public let typeCount: Int
    public let averageConfidence: Double
    public let extractionTimeMs: Double

    public init(
        entities: [NEREntity],
        byType: [NEREntityType: [NEREntity]],
        totalCount: Int,
        typeCount: Int,
        averageConfidence: Double,
        extractionTimeMs: Double
    ) {
        self.entities = entities
        self.byType = byType
        self.totalCount = totalCount
        self.typeCount = typeCount
        self.averageConfidence = averageConfidence
        self.extractionTimeMs = extractionTimeMs
    }
}

// MARK: - NER Extractor

/// Named Entity Recognition extractor using pattern-based detection.
public struct NERExtractor: Sendable {
    /// Minimum confidence threshold.
    private let minConfidence: Double
    /// Maximum entities per type.
    private let maxPerType: Int

    /// Common first names (top 100 US names for heuristic detection).
    private let commonFirstNames: Set<String> = [
        "james", "john", "robert", "michael", "william", "david", "richard",
        "joseph", "thomas", "charles", "christopher", "daniel", "matthew",
        "anthony", "mark", "donald", "steven", "paul", "andrew", "joshua",
        "kenneth", "kevin", "brian", "george", "timothy", "ronald", "edward",
        "jason", "jeffrey", "ryan", "jacob", "gary", "nicholas", "eric",
        "jonathan", "stephen", "larry", "justin", "scott", "brandon", "benjamin",
        "samuel", "raymond", "gregory", "frank", "patrick", "jack", "dennis",
        "jerry", "alexander", "tyler", "aaron", "jose", "adam", "nathan",
        "mary", "patricia", "jennifer", "linda", "barbara", "elizabeth",
        "susan", "jessica", "sarah", "karen", "lisa", "nancy", "betty",
        "margaret", "sandra", "ashley", "dorothy", "kimberly", "emily",
        "donna", "michelle", "carol", "amanda", "melissa", "deborah",
        "stephanie", "rebecca", "sharon", "laura", "cynthia", "kathleen",
        "amy", "angela", "shirley", "anna", "brenda", "pamela", "emma",
        "nicole", "helen", "samantha", "katherine", "christine", "debra",
        "rachel", "carolyn", "janet", "catherine", "maria", "heather",
        "diane", "ruth", "julie", "olivia", "joyce", "virginia"
    ]

    /// Common last name prefixes that indicate a person.
    private let namePatterns = [
        #"(?:Mr|Mrs|Ms|Dr|Prof|Rev)\.?\s+[A-Z][a-z]+"#,
        #"[A-Z][a-z]+\s+[A-Z][a-z]+"#  // "John Smith" pattern
    ]

    /// Common organization suffixes.
    private let orgSuffixes = [
        "inc", "llc", "ltd", "corp", "corporation", "company", "co",
        "group", "associates", "partners", "enterprises", "solutions",
        "technologies", "systems", "services", "consulting", "global",
        "international", "national", "institute", "foundation", "council",
        "association", "society", "bureau", "agency", "department", "division"
    ]

    /// Common organization prefixes.
    private let orgPrefixes = [
        "university", "college", "school", "hospital", "center", "centre",
        "bank", "court", "lab", "labs", "research", "medical", "legal",
        "federal", "state", "city", "county", "national", "international"
    ]

    /// Common location indicators.
    private let locationIndicators = [
        "street", "st", "avenue", "ave", "boulevard", "blvd", "road", "rd",
        "drive", "dr", "lane", "ln", "court", "ct", "place", "pl",
        "suite", "ste", "floor", "building", "tower", "plaza",
        "city", "town", "village", "county", "state", "country",
        "north", "south", "east", "west", "central", "downtown"
    ]

    /// US state abbreviations.
    private let stateAbbreviations: Set<String> = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
    ]

    public init(minConfidence: Double = 0.6, maxPerType: Int = 100) {
        self.minConfidence = minConfidence
        self.maxPerType = maxPerType
    }

    /// Extract named entities from extraction result.
    public func extract(extraction: StructuredExtractionResult) -> NERResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var allEntities: [NEREntity] = []

        for (pageIndex, block) in extraction.blocks.enumerated() {
            let entities = extractFromText(block.text, pageIndex: pageIndex)
            allEntities.append(contentsOf: entities)
        }

        // Deduplicate by value + type + page
        var seen = Set<String>()
        allEntities = allEntities.filter { entity in
            let key = "\(entity.type.rawValue):\(entity.value):\(entity.sourcePageIndex)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        // Group by type
        var byType: [NEREntityType: [NEREntity]] = [:]
        for entity in allEntities {
            byType[entity.type, default: []].append(entity)
        }

        // Trim per type
        for (type, entities) in byType {
            byType[type] = Array(entities.prefix(maxPerType))
        }

        let avgConfidence = allEntities.isEmpty ? 0 : allEntities.reduce(0) { $0 + $1.confidence } / Double(allEntities.count)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        return NERResult(
            entities: allEntities,
            byType: byType,
            totalCount: allEntities.count,
            typeCount: byType.count,
            averageConfidence: avgConfidence,
            extractionTimeMs: elapsed
        )
    }

    /// Extract named entities from a text string.
    public func extractFromText(_ text: String, pageIndex: Int) -> [NEREntity] {
        var entities: [NEREntity] = []

        entities.append(contentsOf: findPersons(text, pageIndex: pageIndex))
        entities.append(contentsOf: findOrganizations(text, pageIndex: pageIndex))
        entities.append(contentsOf: findLocations(text, pageIndex: pageIndex))
        entities.append(contentsOf: findDates(text, pageIndex: pageIndex))
        entities.append(contentsOf: findAmounts(text, pageIndex: pageIndex))
        entities.append(contentsOf: findEmails(text, pageIndex: pageIndex))
        entities.append(contentsOf: findURLs(text, pageIndex: pageIndex))
        entities.append(contentsOf: findPhoneNumbers(text, pageIndex: pageIndex))
        entities.append(contentsOf: findPercentages(text, pageIndex: pageIndex))
        entities.append(contentsOf: findSectionRefs(text, pageIndex: pageIndex))
        entities.append(contentsOf: findPageRefs(text, pageIndex: pageIndex))

        return entities.filter { $0.confidence >= minConfidence }
    }

    // MARK: - Person Detection

    private func findPersons(_ text: String, pageIndex: Int) -> [NEREntity] {
        var entities: [NEREntity] = []

        // Pattern 1: Title + Name (Mr. Smith, Dr. Johnson)
        let titlePattern = "(?:Mr|Mrs|Ms|Dr|Prof|Rev)\\.?\\s+([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)?)"
        entities.append(contentsOf: findPatternMatches(
            titlePattern, in: text, type: .person, pageIndex: pageIndex, confidence: 0.9
        ))

        // Pattern 2: Two consecutive capitalized words (John Smith)
        // But filter out common false positives
        let twoWordPattern = "\\b([A-Z][a-z]+)\\s+([A-Z][a-z]+)\\b"
        if let regex = try? NSRegularExpression(pattern: twoWordPattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            for match in matches {
                guard let firstNameRange = Range(match.range(at: 1), in: text),
                      let lastNameRange = Range(match.range(at: 2), in: text) else { continue }
                let firstName = String(text[firstNameRange]).lowercased()
                let lastName = String(text[lastNameRange]).lowercased()

                // Validate: first name should be common, or context should suggest person
                let isCommonFirstName = commonFirstNames.contains(firstName)
                let isAtSentenceStart = match.range.location < 5 ||
                    text[text.index(text.startIndex, offsetBy: max(0, match.range.location - 1))...].hasPrefix(" ")
                let confidence = isCommonFirstName ? 0.85 : (isAtSentenceStart ? 0.65 : 0.5)

                if confidence >= minConfidence {
                    let full = "\(text[firstNameRange]) \(text[lastNameRange])"
                    entities.append(NEREntity(
                        type: .person,
                        value: full,
                        normalizedValue: full,
                        sourcePageIndex: pageIndex,
                        sourceText: getContext(text: text, at: match.range.location, length: match.range.length),
                        confidence: confidence,
                        startIndex: match.range.location,
                        endIndex: match.range.location + match.range.length
                    ))
                }
            }
        }

        return entities
    }

    // MARK: - Organization Detection

    private func findOrganizations(_ text: String, pageIndex: Int) -> [NEREntity] {
        var entities: [NEREntity] = []
        let lowercased = text.lowercased()

        // Pattern 1: Organization with known suffix (Apple Inc., Google LLC)
        for suffix in orgSuffixes {
            let pattern = "\\b([A-Z][A-Za-z&\\s]+?)\\s+\(suffix)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: range)
                for match in matches {
                    guard let matchRange = Range(match.range, in: text) else { continue }
                    let value = String(text[matchRange]).trimmingCharacters(in: .whitespaces)
                    if value.count > 2 && value.count < 100 {
                        entities.append(NEREntity(
                            type: .organization,
                            value: value,
                            sourcePageIndex: pageIndex,
                            sourceText: getContext(text: text, at: match.range.location, length: match.range.length),
                            confidence: 0.85,
                            startIndex: match.range.location,
                            endIndex: match.range.location + match.range.length
                        ))
                    }
                }
            }
        }

        // Pattern 2: Organization with known prefix (University of X, City of Y)
        for prefix in orgPrefixes {
            let pattern = "\\b\(prefix)\\s+(?:of\\s+)?([A-Z][A-Za-z\\s]+)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: range)
                for match in matches {
                    guard let matchRange = Range(match.range, in: text) else { continue }
                    let value = String(text[matchRange]).trimmingCharacters(in: .whitespaces)
                    if value.count > 5 && value.count < 100 {
                        entities.append(NEREntity(
                            type: .organization,
                            value: value,
                            sourcePageIndex: pageIndex,
                            sourceText: getContext(text: text, at: match.range.location, length: match.range.length),
                            confidence: 0.8,
                            startIndex: match.range.location,
                            endIndex: match.range.location + match.range.length
                        ))
                    }
                }
            }
        }

        return entities
    }

    // MARK: - Location Detection

    private func findLocations(_ text: String, pageIndex: Int) -> [NEREntity] {
        var entities: [NEREntity] = []

        // Pattern 1: Address with street number
        let addressPattern = "\\d{1,5}\\s+[A-Z][a-z]+\\s+(?:Street|St|Avenue|Ave|Boulevard|Blvd|Road|Rd|Drive|Dr|Lane|Ln|Court|Ct|Place|Pl)(?:\\s*,?\\s*[A-Z][a-z]+(?:\\s*,?\\s*[A-Z]{2})?\\s*\\d{5}(?:-\\d{4})?)?"
        entities.append(contentsOf: findPatternMatches(
            addressPattern, in: text, type: .location, pageIndex: pageIndex, confidence: 0.85
        ))

        // Pattern 2: City, State ZIP
        let cityStatePattern = "([A-Z][a-z]+(?:\\s[A-Z][a-z]+)*),\\s*([A-Z]{2})\\s+(\\d{5}(?:-\\d{4})?)"
        entities.append(contentsOf: findPatternMatches(
            cityStatePattern, in: text, type: .location, pageIndex: pageIndex, confidence: 0.9
        ))

        // Pattern 3: State abbreviation in context
        for state in stateAbbreviations {
            let pattern = "\\b[A-Z][a-z]+,\\s*\(state)\\b"
            entities.append(contentsOf: findPatternMatches(
                pattern, in: text, type: .location, pageIndex: pageIndex, confidence: 0.75
            ))
        }

        return entities
    }

    // MARK: - Date Detection

    private func findDates(_ text: String, pageIndex: Int) -> [NEREntity] {
        var entities: [NEREntity] = []

        // ISO format
        entities.append(contentsOf: findPatternMatches(
            "\\d{4}-\\d{2}-\\d{2}", in: text, type: .date, pageIndex: pageIndex, confidence: 0.9
        ))

        // US format
        entities.append(contentsOf: findPatternMatches(
            "\\d{1,2}/\\d{1,2}/\\d{4}", in: text, type: .date, pageIndex: pageIndex, confidence: 0.85
        ))

        // Written format
        entities.append(contentsOf: findPatternMatches(
            "(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\.?\\s+\\d{1,2},?\\s+\\d{4}",
            in: text, type: .date, pageIndex: pageIndex, confidence: 0.9
        ))

        return entities
    }

    // MARK: - Amount Detection

    private func findAmounts(_ text: String, pageIndex: Int) -> [NEREntity] {
        findPatternMatches(
            "(?:\\$|USD|EUR|GBP|¥|€|£)\\s*\\d{1,3}(?:,\\d{3})*(?:\\.\\d{2})?",
            in: text, type: .amount, pageIndex: pageIndex, confidence: 0.9
        )
    }

    // MARK: - Email Detection

    private func findEmails(_ text: String, pageIndex: Int) -> [NEREntity] {
        findPatternMatches(
            "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
            in: text, type: .email, pageIndex: pageIndex, confidence: 0.95
        )
    }

    // MARK: - URL Detection

    private func findURLs(_ text: String, pageIndex: Int) -> [NEREntity] {
        findPatternMatches(
            "https?://[^\\s\"'<>]+",
            in: text, type: .url, pageIndex: pageIndex, confidence: 0.95
        )
    }

    // MARK: - Phone Number Detection

    private func findPhoneNumbers(_ text: String, pageIndex: Int) -> [NEREntity] {
        findPatternMatches(
            "(?:\\+1[-.]?\\s*)?(?:\\(\\d{3}\\)|\\d{3})[-.\\s]?\\d{3}[-.]?\\d{4}",
            in: text, type: .phoneNumber, pageIndex: pageIndex, confidence: 0.85
        )
    }

    // MARK: - Percentage Detection

    private func findPercentages(_ text: String, pageIndex: Int) -> [NEREntity] {
        findPatternMatches(
            "\\d{1,3}(?:\\.\\d{1,2})?\\s*%",
            in: text, type: .percentage, pageIndex: pageIndex, confidence: 0.95
        )
    }

    // MARK: - Section Reference Detection

    private func findSectionRefs(_ text: String, pageIndex: Int) -> [NEREntity] {
        findPatternMatches(
            "(?:§|Section|SEC)\\.?\\s*\\d+(?:\\.\\d+)*",
            in: text, type: .sectionReference, pageIndex: pageIndex, confidence: 0.9
        )
    }

    // MARK: - Page Reference Detection

    private func findPageRefs(_ text: String, pageIndex: Int) -> [NEREntity] {
        findPatternMatches(
            "(?:page|pp?\\.?|pages)\\s+\\d+(?:\\s*[-–]\\s*\\d+)?",
            in: text, type: .pageReference, pageIndex: pageIndex, confidence: 0.85
        )
    }

    // MARK: - Helpers

    private func findPatternMatches(
        _ pattern: String,
        in text: String,
        type: NEREntityType,
        pageIndex: Int,
        confidence: Double
    ) -> [NEREntity] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.prefix(maxPerType).compactMap { match -> NEREntity? in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            let value = String(text[matchRange])
            return NEREntity(
                type: type,
                value: value,
                sourcePageIndex: pageIndex,
                sourceText: getContext(text: text, at: match.range.location, length: match.range.length),
                confidence: confidence,
                startIndex: match.range.location,
                endIndex: match.range.location + match.range.length
            )
        }
    }

    private func getContext(text: String, at location: Int, length: Int) -> String {
        let contextRadius = 40
        let start = max(0, location - contextRadius)
        let end = min(text.count, location + length + contextRadius)
        let startIdx = text.index(text.startIndex, offsetBy: start, limitedBy: text.endIndex) ?? text.startIndex
        let endIdx = text.index(text.startIndex, offsetBy: end, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[startIdx..<endIdx])
    }
}
