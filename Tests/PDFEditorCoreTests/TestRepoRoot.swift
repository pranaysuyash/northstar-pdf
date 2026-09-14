import Foundation

/// Resolves the repository root from this file's compile-time location so
/// benchmark-corpus paths resolve on any checkout. CI runners check out to
/// /Users/runner/work/..., so hardcoded /Users/... paths could only ever
/// work on the owner's machine — every corpus fixture IS tracked, the path
/// was the defect. #filePath is per-file, so this stays correct wherever
/// the repo is checked out.
enum TestRepoRoot {
  static let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // Tests/PDFEditorCoreTests
    .deletingLastPathComponent() // Tests
    .deletingLastPathComponent() // repo root

  /// String-interpolable prefix: "\((TestRepoRoot.prefix))benchmark/results/x.pdf"
  static var prefix: String { url.path + "/" }

  static var benchmarkResults: String {
    url.appendingPathComponent("benchmark/results").path
  }

  static func path(_ relative: String) -> String {
    url.appendingPathComponent(relative).path
  }
}
