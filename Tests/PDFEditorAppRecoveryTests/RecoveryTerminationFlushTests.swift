import Foundation
import Testing

import PDFEditorRecovery

struct RecoveryTerminationFlushTests {
  @Test("termination flush persists pending recovery synchronously")
  func terminationFlushPersistsPendingRecovery() async throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory
      .appendingPathComponent("pdf-editor-recovery-termination-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: rootURL) }

    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("benchmark/results/public-sample-form.pdf")
      .standardizedFileURL
    #expect(fileManager.fileExists(atPath: sourceURL.path))

    let keyData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
    let result = await MainActor.run {
      RecoveryInterruptionTestSupport.runTerminationFlush(
        rootURL: rootURL,
        sourceURL: sourceURL,
        keyAccount: "termination-\(UUID().uuidString)",
        keyData: keyData
      )
    }

    #expect(result.flushed)
    #expect(result.observation.committedGeneration == 1)
    #expect(result.observation.discoveredEnvelopeCount == 1)
    #expect(result.observation.replayedOperationCount == 1)
    #expect(result.observation.recoveryStatus == "replayable")
  }
}
