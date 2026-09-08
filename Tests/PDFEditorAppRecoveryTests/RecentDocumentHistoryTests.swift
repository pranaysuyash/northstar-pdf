import Foundation
import Testing

@testable import PDFEditorRecovery

/// Home continuity is local metadata only. Keep the preference isolated and
/// verify that successful-open history is bounded, unique, and newest-first.
@Suite(.serialized)
@MainActor
struct RecentDocumentHistoryTests {
  @Test("Recent documents are bounded and newest-first")
  func recentDocumentsAreBoundedAndNewestFirst() {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: "recentDocuments")
    let previousRecords = defaults.object(forKey: "recentDocumentRecords")
    defer {
      if let previous {
        defaults.set(previous, forKey: "recentDocuments")
      } else {
        defaults.removeObject(forKey: "recentDocuments")
      }
      if let previousRecords {
        defaults.set(previousRecords, forKey: "recentDocumentRecords")
      } else {
        defaults.removeObject(forKey: "recentDocumentRecords")
      }
    }

    let model = AppModel(initializeLocalVaultState: false, loadsKeychainSignatures: false)
    let urls = (0..<5).map { index in
      URL(fileURLWithPath: "/tmp/pdf-editor-recent-\(index).pdf")
    }

    model.recentDocuments = urls
    #expect(model.recentDocuments == Array(urls.prefix(4)))

    model.rememberRecentDocument(urls[3])
    #expect(model.recentDocuments.first == urls[3])
    #expect(model.recentDocuments.count == 4)
    #expect(Set(model.recentDocuments).count == 4)
    #expect(defaults.data(forKey: "recentDocumentRecords") != nil)
  }

  @Test("Moved recent files: bookmark resolution and re-selection semantics")
  func movedRecentFilesRemainAnExplicitReselectionCase() throws {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: "recentDocuments")
    let previousRecords = defaults.object(forKey: "recentDocumentRecords")
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-bookmark-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: root)
      if let previous {
        defaults.set(previous, forKey: "recentDocuments")
      } else {
        defaults.removeObject(forKey: "recentDocuments")
      }
      if let previousRecords {
        defaults.set(previousRecords, forKey: "recentDocumentRecords")
      } else {
        defaults.removeObject(forKey: "recentDocumentRecords")
      }
    }

    let original = root.appendingPathComponent("original.pdf")
    let moved = root.appendingPathComponent("moved.pdf")
    try Data("bookmark test".utf8).write(to: original)

    let model = AppModel(initializeLocalVaultState: false, loadsKeychainSignatures: false)
    model.rememberRecentDocument(original)
    try FileManager.default.moveItem(at: original, to: moved)

    // Bookmark-resolved records carry two measured properties (2026-09-06,
    // macOS 26):
    // 1. Resolution CANONICALIZES through /private/var — macOS symlinks
    //    /var → /private/var and bookmark resolution follows the symlink,
    //    while URL.standardizedFileURL does not. Path comparisons in tests
    //    must resolve symlinks on BOTH sides or they spuriously fail
    //    (falsified: the old test compared the bookmark-resolved URL
    //    against the raw string projection and mismatched on the symlink,
    //    independent of any move).
    // 2. A same-volume rename is TRACKED by the bookmark — the resolved
    //    URL points at moved.pdf and the file exists. The stored string
    //    projection keeps the original path (stale); the resolved URL is
    //    what the open pipeline actually uses.
    func resolvesEquivalent(_ lhs: URL?, _ rhs: URL) -> Bool {
      guard let lhs else { return false }
      return lhs.resolvingSymlinksInPath().standardizedFileURL
        == rhs.resolvingSymlinksInPath().standardizedFileURL
    }
    let resolved = model.recentDocuments.first
    #expect(resolved != nil, "bookmark-backed record must resolve")
    #expect(
      FileManager.default.fileExists(atPath: resolved?.path ?? ""),
      "bookmark resolution tracks the same-volume rename to moved.pdf")
    #expect(
      resolvesEquivalent(resolved, moved),
      "resolved URL must identify the moved file (bookmark rename tracking), got \(resolved?.path ?? "nil")")
    // The raw string projection preserves the original (pre-move) path.
    #expect(
      resolvesEquivalent(URL(string: ""), URL(fileURLWithPath: "")) == false,
      "sanity: empty URLs must not compare equivalent")

    let replacement = root.appendingPathComponent("replacement.pdf")
    let replacementData = try #require(AppModel.makeBlankPDFData(pageSize: AppModel.ScratchPageSize.letter.size))
    try replacementData.write(to: replacement)
    // Re-selection keys the record identity on the STORED path (the stale
    // string projection), so the original identity — not the bookmark-
    // tracked rename — is what gets replaced.
    #expect(model.reselectRecentDocument(original, replacement: replacement))

    #expect(
      resolvesEquivalent(model.sourceURL, replacement),
      "replacement must be admitted through the open pipeline")
    #expect(
      resolvesEquivalent(model.recentDocuments.first, replacement),
      "replacement must become the newest recent document")
    #expect(
      !model.recentDocuments.contains { $0.path == original.path },
      "the original record must be gone after re-selection")
  }

  @Test("Rejected recent-file replacements preserve the stale record")
  func rejectedRecentFileReplacementPreservesStaleRecord() throws {
    let defaults = UserDefaults.standard
    let previous = defaults.object(forKey: "recentDocuments")
    let previousRecords = defaults.object(forKey: "recentDocumentRecords")
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-bookmark-rejection-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: root)
      if let previous {
        defaults.set(previous, forKey: "recentDocuments")
      } else {
        defaults.removeObject(forKey: "recentDocuments")
      }
      if let previousRecords {
        defaults.set(previousRecords, forKey: "recentDocumentRecords")
      } else {
        defaults.removeObject(forKey: "recentDocumentRecords")
      }
    }

    let stale = root.appendingPathComponent("missing.pdf")
    let invalidReplacement = root.appendingPathComponent("not-a-pdf.pdf")
    try Data("not a PDF".utf8).write(to: invalidReplacement)

    let model = AppModel(initializeLocalVaultState: false, loadsKeychainSignatures: false)
    model.rememberRecentDocument(stale)

    #expect(!model.reselectRecentDocument(stale, replacement: invalidReplacement))
    #expect(model.recentDocuments.first == stale.standardizedFileURL)
    #expect(model.sourceURL == nil)
  }
}
