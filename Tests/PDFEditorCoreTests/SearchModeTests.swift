import Foundation
import Testing
@testable import PDFEditorCore
@testable import PDFEditorRecovery

@Suite("SearchMode")
struct SearchModeTests {
  // MARK: - SearchMode Enum

  @Test("SearchMode has all cases")
  func allCasesExist() {
    #expect(SearchMode.allCases.count == 4)
    #expect(SearchMode.allCases.contains(.exact))
    #expect(SearchMode.allCases.contains(.fuzzy))
    #expect(SearchMode.allCases.contains(.regex))
    #expect(SearchMode.allCases.contains(.semantic))
  }

  @Test("SearchMode raw values round-trip")
  func rawValuesRoundTrip() {
    for mode in SearchMode.allCases {
      #expect(SearchMode(rawValue: mode.rawValue) == mode)
    }
  }

  @Test("SearchMode display names are distinct")
  func displayNamesDistinct() {
    let names = Set(SearchMode.allCases.map(\.displayName))
    #expect(names.count == SearchMode.allCases.count)
  }

  @Test("SearchMode symbol names are distinct")
  func symbolNamesDistinct() {
    let symbols = Set(SearchMode.allCases.map(\.symbolName))
    #expect(symbols.count == SearchMode.allCases.count)
  }

  @Test("SearchMode help text is non-empty")
  func helpTextNonEmpty() {
    for mode in SearchMode.allCases {
      #expect(!mode.helpText.isEmpty)
    }
  }

  // MARK: - Levenshtein Distance

  @Test("Identical strings have distance 0")
  func identicalStrings() {
    #expect(AppModel.levenshteinDistance("hello", "hello") == 0)
  }

  @Test("Empty vs non-empty")
  func emptyVsNonEmpty() {
    #expect(AppModel.levenshteinDistance("", "abc") == 3)
    #expect(AppModel.levenshteinDistance("abc", "") == 3)
  }

  @Test("Both empty")
  func bothEmpty() {
    #expect(AppModel.levenshteinDistance("", "") == 0)
  }

  @Test("Single character substitution")
  func singleSubstitution() {
    #expect(AppModel.levenshteinDistance("cat", "bat") == 1)
    #expect(AppModel.levenshteinDistance("cat", "car") == 1)
  }

  @Test("Single character insertion")
  func singleInsertion() {
    #expect(AppModel.levenshteinDistance("cat", "cats") == 1)
    #expect(AppModel.levenshteinDistance("cat", "cart") == 1)
  }

  @Test("Single character deletion")
  func singleDeletion() {
    #expect(AppModel.levenshteinDistance("cats", "cat") == 1)
    #expect(AppModel.levenshteinDistance("cart", "cat") == 1)
  }

  @Test("Multiple edits")
  func multipleEdits() {
    #expect(AppModel.levenshteinDistance("kitten", "sitting") == 3)
    #expect(AppModel.levenshteinDistance("saturday", "sunday") == 3)
  }

  @Test("Completely different strings")
  func completelyDifferent() {
    #expect(AppModel.levenshteinDistance("abc", "xyz") == 3)
  }

  @Test("Case sensitivity — Levenshtein is case-sensitive")
  func caseSensitivity() {
    // Levenshtein treats case literally; callers lowercase before calling
    #expect(AppModel.levenshteinDistance("Hello", "hello") == 1)
    #expect(AppModel.levenshteinDistance("hello", "hello") == 0)
  }

  // MARK: - Fuzzy Match Tolerance

  @Test("Fuzzy tolerance: 33% of query length")
  func fuzzyTolerance() {
    let query = "document"
    let maxDistance = max(1, query.count / 3) // 8/3 = 2
    #expect(maxDistance == 2)
    #expect(AppModel.levenshteinDistance(query, "documnt") == 1) // 1 deletion
    #expect(AppModel.levenshteinDistance(query, "dcoument") == 2) // 2 transpositions
    #expect(AppModel.levenshteinDistance(query, "docxment") == 1) // 1 substitution
  }

  // MARK: - Regex Pattern Validation

  @Test("Valid regex compiles")
  func validRegex() {
    let regex = try? NSRegularExpression(pattern: "\\d{4}-\\d{2}-\\d{2}", options: .caseInsensitive)
    #expect(regex != nil)
  }

  @Test("Invalid regex returns nil")
  func invalidRegex() {
    let regex = try? NSRegularExpression(pattern: "[invalid", options: .caseInsensitive)
    #expect(regex == nil)
  }

  @Test("Regex matches dates")
  func regexMatchesDates() {
    let regex = try! NSRegularExpression(pattern: "\\d{4}-\\d{2}-\\d{2}", options: [])
    let text = "Created on 2026-08-27 and updated 2026-08-26"
    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    #expect(matches.count == 2)
  }

  @Test("Regex matches emails")
  func regexMatchesEmails() {
    let regex = try! NSRegularExpression(pattern: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", options: .caseInsensitive)
    let text = "Contact us at support@example.com or sales@test.org"
    let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    #expect(matches.count == 2)
  }

  // MARK: - SearchMode Sendable

  @Test("SearchMode is Sendable")
  func sendableCompliance() {
    let mode: SearchMode = .fuzzy
    Task {
      let captured = mode
      #expect(captured == .fuzzy)
    }
  }
}
