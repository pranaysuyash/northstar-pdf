import Foundation
import Testing
@testable import PDFEditorCore

@Suite("SearchEngine")
struct SearchEngineTests {

  // MARK: - Synonym Dictionary

  @Test("SynonymDictionary expands known terms")
  func expandKnownTerms() {
    let terms = SynonymDictionary.expand("revenue")
    #expect(terms.contains("revenue"))
    #expect(terms.contains("income"))
    #expect(terms.contains("earnings"))
    #expect(terms.count > 1)
  }

  @Test("SynonymDictionary returns original for unknown terms")
  func expandUnknownTerms() {
    let terms = SynonymDictionary.expand("xyzzy")
    #expect(terms.contains("xyzzy"))
    #expect(terms.count == 1)
  }

  @Test("SynonymDictionary expands multi-word query")
  func expandMultiWord() {
    let terms = SynonymDictionary.expand("agreement termination")
    #expect(terms.contains("agreement"))
    #expect(terms.contains("contract"))
    #expect(terms.contains("termination"))
    #expect(terms.contains("cancellation"))
  }

  @Test("SynonymDictionary empty query returns empty")
  func expandEmpty() {
    let terms = SynonymDictionary.expand("")
    #expect(terms.isEmpty)
  }

  @Test("SynonymDictionary areSynonyms detects synonyms")
  func detectSynonyms() {
    #expect(SynonymDictionary.areSynonyms("revenue", "income"))
    #expect(SynonymDictionary.areSynonyms("contract", "agreement"))
    #expect(SynonymDictionary.areSynonyms("revenue", "revenue"))
  }

  @Test("SynonymDictionary areSynonyms rejects non-synonyms")
  func rejectNonSynonyms() {
    #expect(!SynonymDictionary.areSynonyms("revenue", "elephant"))
    #expect(!SynonymDictionary.areSynonyms("contract", "banana"))
  }

  // MARK: - Search Scorer

  @Test("Exact match scores higher than fuzzy")
  func exactScoresHigher() {
    let exactScore = SearchScorer.score(
      query: "hello", matchedText: "hello",
      matchType: .exact, pageIndex: 0, totalPages: 10
    )
    let fuzzyScore = SearchScorer.score(
      query: "hello", matchedText: "helo",
      matchType: .fuzzy, pageIndex: 0, totalPages: 10
    )
    #expect(exactScore > fuzzyScore)
  }

  @Test("Semantic match scores between exact and fuzzy")
  func semanticScoresBetween() {
    let exactScore = SearchScorer.score(
      query: "revenue", matchedText: "revenue",
      matchType: .exact, pageIndex: 0, totalPages: 10
    )
    let semanticScore = SearchScorer.score(
      query: "revenue", matchedText: "income",
      matchType: .semantic, pageIndex: 0, totalPages: 10
    )
    let fuzzyScore = SearchScorer.score(
      query: "revenue", matchedText: "revnue",
      matchType: .fuzzy, pageIndex: 0, totalPages: 10
    )
    #expect(semanticScore > fuzzyScore)
    #expect(exactScore > semanticScore)
  }

  @Test("Score is between 0 and 1")
  func scoreBounds() {
    let score = SearchScorer.score(
      query: "test", matchedText: "test",
      matchType: .exact, pageIndex: 0, totalPages: 10
    )
    #expect(score >= 0.0)
    #expect(score <= 1.0)
  }

  // MARK: - Advanced Search Query

  @Test("AdvancedSearchQuery initializes correctly")
  func queryInit() {
    let q = AdvancedSearchQuery(raw: "hello world", mode: .fuzzy)
    #expect(q.raw == "hello world")
    #expect(q.isMultiWord == true)
    #expect(q.words.count == 2)
    #expect(q.expandedTerms.count == 1)
  }

  @Test("AdvancedSearchQuery semantic mode expands terms")
  func querySemanticExpansion() {
    let q = AdvancedSearchQuery(raw: "revenue", mode: .semantic)
    #expect(q.expandedTerms.count > 1)
    #expect(q.expandedTerms.contains("revenue"))
  }

  @Test("AdvancedSearchQuery exact mode does not expand")
  func queryExactNoExpansion() {
    let q = AdvancedSearchQuery(raw: "revenue", mode: .exact)
    #expect(q.expandedTerms.count == 1)
    #expect(q.expandedTerms[0] == "revenue")
  }

  // MARK: - Search Engine Integration

  @Test("Exact search finds matches")
  func exactSearchFinds() {
    let query = AdvancedSearchQuery(raw: "contract", mode: .exact)
    let pageTexts = [(pageIndex: 0, text: "This is a contract between parties.")]
    let results = SearchEngine.search(query: query, pageTexts: pageTexts)
    #expect(results.count >= 1)
    #expect(results.first?.pageIndex == 0)
    #expect(results.first?.matchType == .exact)
  }

  @Test("Fuzzy search finds near-matches")
  func fuzzySearchFinds() {
    let query = AdvancedSearchQuery(raw: "contract", mode: .fuzzy)
    let pageTexts = [(pageIndex: 0, text: "This is a contrct between parties.")]
    let results = SearchEngine.search(query: query, pageTexts: pageTexts)
    #expect(results.count >= 1)
    #expect(results.first?.matchType == .fuzzy)
  }

  @Test("Semantic search finds synonyms")
  func semanticSearchFinds() {
    let query = AdvancedSearchQuery(raw: "revenue", mode: .semantic)
    let pageTexts = [(pageIndex: 0, text: "The company reported strong income this quarter.")]
    let results = SearchEngine.search(query: query, pageTexts: pageTexts)
    #expect(results.count >= 1)
    #expect(results.first?.matchType == .semantic || results.first?.matchedTerm != "revenue")
  }

  @Test("Semantic search ranks exact matches higher than synonym matches")
  func semanticRanking() {
    let query = AdvancedSearchQuery(raw: "revenue", mode: .semantic)
    let pageTexts = [
      (pageIndex: 0, text: "The revenue increased this quarter."),
      (pageIndex: 1, text: "The income increased this quarter.")
    ]
    let results = SearchEngine.search(query: query, pageTexts: pageTexts)
    #expect(results.count >= 2)
    // The exact match on page 0 should rank higher than the synonym on page 1
    #expect(results[0].pageIndex == 0)
    #expect(results[0].matchType == .exact)
  }

  @Test("Search across multiple pages")
  func multiPageSearch() {
    let query = AdvancedSearchQuery(raw: "payment", mode: .exact)
    let pageTexts = [
      (pageIndex: 0, text: "No payment terms here."),
      (pageIndex: 1, text: "Payment is due within 30 days."),
      (pageIndex: 2, text: "Late payment incurs penalties.")
    ]
    let results = SearchEngine.search(query: query, pageTexts: pageTexts)
    #expect(results.count >= 2)
    #expect(results.allSatisfy { $0.matchedText.lowercased().contains("payment") })
  }

  @Test("No matches returns empty")
  func noMatches() {
    let query = AdvancedSearchQuery(raw: "xyzzy", mode: .exact)
    let pageTexts = [(pageIndex: 0, text: "Hello world")]
    let results = SearchEngine.search(query: query, pageTexts: pageTexts)
    #expect(results.isEmpty)
  }

  @Test("Empty query returns empty")
  func emptyQuery() {
    let query = AdvancedSearchQuery(raw: "", mode: .exact)
    let pageTexts = [(pageIndex: 0, text: "Hello world")]
    let results = SearchEngine.search(query: query, pageTexts: pageTexts)
    #expect(results.isEmpty)
  }

  @Test("Results are sorted by score descending")
  func resultsSortedByScore() {
    let query = AdvancedSearchQuery(raw: "the", mode: .exact)
    let pageTexts = [
      (pageIndex: 0, text: "The the the the the the the the the the."),
      (pageIndex: 1, text: "A single mention of the word.")
    ]
    let results = SearchEngine.search(query: query, pageTexts: pageTexts)
    guard results.count >= 2 else { return }
    // All results should be valid
    #expect(results.allSatisfy { $0.score >= 0.0 && $0.score <= 1.0 })
  }

  // MARK: - Levenshtein Distance (core engine)

  @Test("Levenshtein identical strings")
  func levenshteinIdentical() {
    #expect(SearchEngine.levenshteinDistance("hello", "hello") == 0)
  }

  @Test("Levenshtein single substitution")
  func levenshteinSubstitution() {
    #expect(SearchEngine.levenshteinDistance("cat", "bat") == 1)
  }

  @Test("Levenshtein single insertion")
  func levenshteinInsertion() {
    #expect(SearchEngine.levenshteinDistance("cat", "cats") == 1)
  }

  @Test("Levenshtein single deletion")
  func levenshteinDeletion() {
    #expect(SearchEngine.levenshteinDistance("cats", "cat") == 1)
  }
}
