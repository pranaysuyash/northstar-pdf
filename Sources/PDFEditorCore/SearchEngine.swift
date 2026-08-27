import Foundation

/// Advanced search engine with semantic matching, relevance ranking, and
/// multi-word fuzzy search.
///
/// First principle: search is not just substring matching. Users think in
/// concepts ("revenue", "termination clause"), not exact text. Semantic
/// search bridges the gap between what the user means and what the document says.
///
/// Architecture:
/// - `SearchEngine` — orchestrates all search modes
/// - `SynonymDictionary` — domain-specific synonym sets
/// - `SearchScorer` — relevance scoring for ranking results
/// - `AdvancedSearchQuery` — parsed query with mode, synonyms, and multi-word handling
///
/// Doctrine alignment:
/// - §3: Do things smartly — rank results by relevance, not just page order
/// - §5: Evidence-based — scoring is transparent and deterministic

// MARK: - Search Mode (local copy for PDFEditorCore)

/// Search mode for the advanced search engine.
/// Mirrors the SearchMode in PDFEditorRecovery but lives here for module independence.
public enum AdvancedSearchMode: String, Sendable, CaseIterable {
  case exact = "Exact"
  case fuzzy = "Fuzzy"
  case regex = "Regex"
  case semantic = "Semantic"

  public var displayName: String { rawValue }
}

// MARK: - Search Query

/// A parsed search query with mode and optional synonym expansion.
public struct AdvancedSearchQuery: Sendable {
  /// The original user input.
  public let raw: String
  /// The search mode.
  public let mode: AdvancedSearchMode
  /// The expanded query (original + synonyms if semantic mode).
  public let expandedTerms: [String]
  /// Whether this is a multi-word query.
  public let isMultiWord: Bool
  /// Individual words (for multi-word matching).
  public let words: [String]

  public init(raw: String, mode: AdvancedSearchMode) {
    self.raw = raw
    self.mode = mode
    self.isMultiWord = raw.contains(" ")
    self.words = raw.split(separator: " ").map(String.init)

    switch mode {
    case .exact, .regex, .fuzzy:
      self.expandedTerms = [raw]
    case .semantic:
      self.expandedTerms = SynonymDictionary.expand(raw)
    }
  }
}

// MARK: - Search Result

/// A search result with relevance score.
public struct ScoredResult: Sendable, Identifiable {
  /// Page index where the match was found.
  public let pageIndex: Int
  /// Character start position in the page text.
  public let charStart: Int
  /// Character length of the match.
  public let charLength: Int
  /// The matched text.
  public let matchedText: String
  /// Snippet context around the match.
  public let snippet: String
  /// Relevance score (0.0 – 1.0, higher = more relevant).
  public let score: Double
  /// Which term matched (for semantic mode).
  public let matchedTerm: String
  /// How the match was made (exact/fuzzy/semantic).
  public let matchType: MatchType

  public var id: String {
    "\(pageIndex):\(charStart):\(charLength):\(matchedText.lowercased())"
  }
}

// MARK: - Match Type

/// How a match was found.
public enum MatchType: String, Sendable {
  case exact = "exact"
  case fuzzy = "fuzzy"
  case semantic = "semantic"
}

// MARK: - Synonym Dictionary

/// Domain-specific synonym sets for semantic search.
///
/// Built from common PDF document domains: legal, financial, business,
/// academic, and general. Each set is bidirectional — searching for any
/// term in the set matches all others.
public struct SynonymDictionary: Sendable {

  /// Synonym sets grouped by domain.
  private static let synonymSets: [[String]] = [
    // Legal
    ["agreement", "contract", "deal", "accord", "pact"],
    ["termination", "cancellation", "ending", "cessation", "expiration"],
    ["liability", "responsibility", "obligation", "accountability"],
    ["indemnify", "compensate", "reimburse", "protect", "defend"],
    ["confidential", "private", "secret", "proprietary", "classified"],
    ["jurisdiction", "venue", "forum", "court", "authority"],
    ["warranty", "guarantee", "assurance", "representation"],
    ["breach", "violation", "infringement", "default", "noncompliance"],

    // Financial
    ["revenue", "income", "earnings", "proceeds", "receipts"],
    ["expense", "cost", "expenditure", "charge", "outlay"],
    ["profit", "gain", "return", "surplus", "earnings"],
    ["loss", "deficit", "shortfall", "deficiency", "liability"],
    ["payment", "remittance", "settlement", "disbursement"],
    ["invoice", "bill", "statement", "account", "charge"],
    ["tax", "levy", "duty", "tariff", "assessment"],
    ["debt", "obligation", "liability", "arrears", "indebtedness"],

    // Business
    ["employee", "worker", "staff", "personnel", "workforce"],
    ["employer", "company", "firm", "organization", "corporation"],
    ["salary", "wages", "compensation", "pay", "remuneration"],
    ["benefit", "perk", "advantage", "entitlement", "privilege"],
    ["termination", "dismissal", "discharge", "layoff", "separation"],
    ["promotion", "advancement", "elevation", "upgrade"],
    ["training", "education", "instruction", "development", "coaching"],

    // General
    ["important", "significant", "critical", "crucial", "essential"],
    ["require", "need", "demand", "mandate", "compel"],
    ["allow", "permit", "authorize", "enable", "consent"],
    ["prohibit", "forbid", "ban", "restrict", "prevent"],
    ["change", "modify", "alter", "amend", "revise"],
    ["cancel", "revoke", "rescind", "annul", "void"],
    ["begin", "start", "commence", "initiate", "launch"],
    ["end", "conclude", "finish", "complete", "terminate"],
    ["give", "provide", "supply", "deliver", "furnish"],
    ["take", "receive", "obtain", "acquire", "get"],
    ["make", "create", "produce", "generate", "construct"],
    ["use", "utilize", "employ", "apply", "leverage"],
  ]

  /// Build a lookup map: term → set of synonyms (including itself).
  /// Merges overlapping sets so a term in multiple sets gets all synonyms.
  private static let lookup: [String: [String]] = {
    var map: [String: Set<String>] = [:]
    for set in synonymSets {
      let lowerSet = Set(set.map { $0.lowercased() })
      for term in set {
        let lt = term.lowercased()
        var existing = map[lt] ?? Set<String>()
        existing.formUnion(lowerSet)
        map[lt] = existing
      }
    }
    return map.mapValues { Array($0).sorted() }
  }()

  /// Expand a query into synonym-equivalent terms.
  /// Returns the original term plus all synonyms found in the dictionary.
  public static func expand(_ query: String) -> [String] {
    let lower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !lower.isEmpty else { return [] }

    var terms = Set<String>()
    terms.insert(lower)

    // Check each word for synonyms
    let words = lower.split(separator: " ").map(String.init)
    for word in words {
      if let synonyms = lookup[word] {
        for syn in synonyms {
          terms.insert(syn)
        }
      }
    }

    return Array(terms).sorted()
  }

  /// Check if two terms are synonyms.
  public static func areSynonyms(_ a: String, _ b: String) -> Bool {
    let la = a.lowercased()
    let lb = b.lowercased()
    guard la != lb else { return true }
    guard let synonyms = lookup[la] else { return false }
    return synonyms.contains(lb)
  }
}

// MARK: - Search Scorer

/// Computes relevance scores for search results.
public struct SearchScorer: Sendable {

  /// Score a match based on multiple factors.
  public static func score(
    query: String,
    matchedText: String,
    matchType: MatchType,
    pageIndex: Int,
    totalPages: Int
  ) -> Double {
    var score = 0.5 // base score

    // Factor 1: Match type bonus
    switch matchType {
    case .exact:
      score += 0.3
    case .semantic:
      score += 0.2
    case .fuzzy:
      score += 0.1
    }

    // Factor 2: Match length ratio (shorter matches are more precise)
    let queryLen = Double(query.count)
    let matchLen = Double(matchedText.count)
    if queryLen > 0, matchLen > 0 {
      let precision = queryLen / matchLen
      score += precision * 0.1 // up to 0.1 bonus for precise matches
    }

    // Factor 3: Word boundary bonus (match starts at word boundary)
    let lowerMatch = matchedText.lowercased()
    let lowerQuery = query.lowercased()
    if lowerMatch.hasPrefix(lowerQuery) || lowerMatch.hasSuffix(lowerQuery) {
      score += 0.1
    }

    // Factor 4: Early pages get slight bonus (most relevant content is often first)
    if totalPages > 0 {
      let pageRank = 1.0 - (Double(pageIndex) / Double(totalPages))
      score += pageRank * 0.05
    }

    return min(1.0, score)
  }
}

// MARK: - Search Engine

/// Orchestrates all search modes with scoring and ranking.
public struct SearchEngine: Sendable {

  /// Execute a search across all pages of a document.
  ///
  /// - Parameters:
  ///   - query: The parsed search query.
  ///   - pageTexts: Array of (pageIndex, text) for each page.
  /// - Returns: Scored results sorted by relevance.
  public static func search(
    query: AdvancedSearchQuery,
    pageTexts: [(pageIndex: Int, text: String)]
  ) -> [ScoredResult] {
    var results: [ScoredResult] = []

    for (pageIndex, pageText) in pageTexts {
      let haystack = pageText.lowercased()
      guard !haystack.isEmpty else { continue }

      for term in query.expandedTerms {
        let termLower = term.lowercased()
        let isSynonymMatch = termLower != query.raw.lowercased()

        switch query.mode {
        case .exact:
          searchExact(
            query: query.raw, term: termLower, pageIndex: pageIndex,
            haystack: haystack, pageText: pageText,
            isSynonym: isSynonymMatch, results: &results
          )

        case .fuzzy:
          searchFuzzy(
            query: query.raw, term: termLower, pageIndex: pageIndex,
            haystack: haystack, pageText: pageText,
            isSynonym: isSynonymMatch, results: &results
          )

        case .semantic:
          // Semantic mode tries exact first, then fuzzy for each expanded term
          searchExact(
            query: query.raw, term: termLower, pageIndex: pageIndex,
            haystack: haystack, pageText: pageText,
            isSynonym: isSynonymMatch, results: &results
          )
          searchFuzzy(
            query: query.raw, term: termLower, pageIndex: pageIndex,
            haystack: haystack, pageText: pageText,
            isSynonym: isSynonymMatch, results: &results
          )

        case .regex:
          searchRegex(
            query: query.raw, pageIndex: pageIndex,
            haystack: haystack, pageText: pageText,
            results: &results
          )
        }
      }
    }

    // Deduplicate (same position, keep highest score)
    let deduplicated = deduplicate(results)
    // Sort by score descending, then by page index
    return deduplicated.sorted { a, b in
      if a.score != b.score { return a.score > b.score }
      return a.pageIndex < b.pageIndex
    }
  }

  // MARK: - Exact Search

  private static func searchExact(
    query: String, term: String, pageIndex: Int,
    haystack: String, pageText: String,
    isSynonym: Bool, results: inout [ScoredResult]
  ) {
    let nsHaystack = haystack as NSString
    var cursor = 0
    while cursor < nsHaystack.length {
      let range = nsHaystack.range(
        of: term, options: [],
        range: NSRange(location: cursor, length: nsHaystack.length - cursor))
      if range.location == NSNotFound { break }

      let matchText = (haystack as NSString).substring(with: range)
      let snippet = extractSnippet(haystack: pageText, range: range)
      let matchType: MatchType = isSynonym ? .semantic : .exact
      let score = SearchScorer.score(
        query: query, matchedText: matchText,
        matchType: matchType, pageIndex: pageIndex,
        totalPages: 0 // will be updated later if needed
      )

      results.append(ScoredResult(
        pageIndex: pageIndex, charStart: range.location,
        charLength: range.length, matchedText: matchText,
        snippet: snippet, score: score,
        matchedTerm: term, matchType: matchType
      ))

      cursor = range.location + max(range.length, 1)
    }
  }

  // MARK: - Fuzzy Search

  private static func searchFuzzy(
    query: String, term: String, pageIndex: Int,
    haystack: String, pageText: String,
    isSynonym: Bool, results: inout [ScoredResult]
  ) {
    let windowSize = term.count
    guard windowSize > 0, haystack.count >= windowSize else { return }

    let maxDistance = max(1, windowSize / 3)
    let haystackChars = Array(haystack)

    for i in 0...(haystackChars.count - windowSize) {
      let window = String(haystackChars[i..<(i + windowSize)])
      let distance = levenshteinDistance(term, window)
      if distance <= maxDistance {
        let nsHaystack = haystack as NSString
        let start = haystack.index(haystack.startIndex, offsetBy: i)
        let end = haystack.index(start, offsetBy: windowSize)
        let nsRange = NSRange(start..<end, in: haystack)

        let matchText = (haystack as NSString).substring(with: nsRange)
        let snippet = extractSnippet(haystack: pageText, range: nsRange)
        let matchType: MatchType = isSynonym ? .semantic : .fuzzy
        let score = SearchScorer.score(
          query: query, matchedText: matchText,
          matchType: matchType, pageIndex: pageIndex,
          totalPages: 0
        )

        results.append(ScoredResult(
          pageIndex: pageIndex, charStart: nsRange.location,
          charLength: nsRange.length, matchedText: matchText,
          snippet: snippet, score: score,
          matchedTerm: term, matchType: matchType
        ))
      }
    }
  }

  // MARK: - Regex Search

  private static func searchRegex(
    query: String, pageIndex: Int,
    haystack: String, pageText: String,
    results: inout [ScoredResult]
  ) {
    guard let regex = try? NSRegularExpression(pattern: query, options: .caseInsensitive) else { return }
    let fullRange = NSRange(haystack.startIndex..., in: haystack)
    let matches = regex.matches(in: haystack, range: fullRange)
    for match in matches {
      guard match.range.location != NSNotFound else { continue }
      let matchText = (haystack as NSString).substring(with: match.range)
      let snippet = extractSnippet(haystack: pageText, range: match.range)
      let score = SearchScorer.score(
        query: query, matchedText: matchText,
        matchType: .exact, pageIndex: pageIndex,
        totalPages: 0
      )

      results.append(ScoredResult(
        pageIndex: pageIndex, charStart: match.range.location,
        charLength: match.range.length, matchedText: matchText,
        snippet: snippet, score: score,
        matchedTerm: query, matchType: .exact
      ))
    }
  }

  // MARK: - Helpers

  private static func extractSnippet(haystack: String, range: NSRange) -> String {
    let snippetStart = max(0, range.location - 32)
    let snippetEnd = min(haystack.count, range.location + range.length + 78)
    let startIdx = haystack.index(haystack.startIndex, offsetBy: snippetStart)
    let endIdx = haystack.index(haystack.startIndex, offsetBy: snippetEnd)
    return String(haystack[startIdx..<endIdx]).replacingOccurrences(of: "\n", with: " ")
  }

  private static func deduplicate(_ results: [ScoredResult]) -> [ScoredResult] {
    var seen = [String: ScoredResult]()
    for result in results {
      let key = "\(result.pageIndex):\(result.charStart):\(result.charLength)"
      if let existing = seen[key] {
        if result.score > existing.score {
          seen[key] = result
        }
      } else {
        seen[key] = result
      }
    }
    return Array(seen.values)
  }

  // MARK: - Levenshtein Distance

  nonisolated static func levenshteinDistance(_ a: String, _ b: String) -> Int {
    let aChars = Array(a)
    let bChars = Array(b)
    let aLen = aChars.count
    let bLen = bChars.count
    guard aLen > 0 else { return bLen }
    guard bLen > 0 else { return aLen }

    var prev = [Int](repeating: 0, count: bLen + 1)
    var curr = [Int](repeating: 0, count: bLen + 1)
    for j in 0...bLen { prev[j] = j }

    for i in 1...aLen {
      curr[0] = i
      for j in 1...bLen {
        let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
        curr[j] = min(
          prev[j] + 1,
          curr[j - 1] + 1,
          prev[j - 1] + cost
        )
      }
      prev = curr
      curr = [Int](repeating: 0, count: bLen + 1)
    }
    return prev[bLen]
  }
}
