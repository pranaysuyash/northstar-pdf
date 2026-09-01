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

  @Test("Moved recent files remain an explicit re-selection case")
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

    // A bookmark is an access grant and identity record, not a promise that
    // every filesystem move can be tracked in every host configuration.
    #expect(model.recentDocuments.first == original.standardizedFileURL)
    #expect(!FileManager.default.fileExists(atPath: model.recentDocuments.first?.path ?? ""))
  }
}
