import Foundation
import Testing

import PDFEditorCore
@testable import PDFEditorRecovery

/// NMAC-002 / NM-T02: each native WindowGroup scene owns one document session.
/// The model-level contract is testable without claiming an AppKit GUI run.
@MainActor
struct DocumentWindowIsolationTests {
  private func makeModel(root: URL) -> AppModel {
    let keyData = Data(repeating: 7, count: 32)
    let keyStore = RecoveryPayloadKeyStore(
      service: "com.pdfeditor.recovery-payload.test",
      account: "window-isolation-\(UUID().uuidString)",
      testKeyData: keyData
    )
    return AppModel(
      sessionStore: FileSessionStore(directory: root.appendingPathComponent("sessions", isDirectory: true)),
      recoveryStore: SessionRecoveryStore(directory: root.appendingPathComponent("metadata", isDirectory: true)),
      recoveryPayloadStore: SessionPayloadStore(
        directory: root.appendingPathComponent("payload", isDirectory: true),
        keyStore: keyStore
      ),
      recoveryPairStore: RecoveryPairStore(directory: root.appendingPathComponent("pair", isDirectory: true)),
      profileStore: EncryptedPDFProfileVault(directory: root.appendingPathComponent("profiles", isDirectory: true)),
      templateStore: EncryptedPDFTemplateStore(directory: root.appendingPathComponent("templates", isDirectory: true)),
      initializeLocalVaultState: false,
      loadsKeychainSignatures: false
    )
  }

  @Test("document windows keep source, session, and reader state independent")
  func documentWindowsKeepStateIndependent() {
    let firstRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-window-one-\(UUID().uuidString)", isDirectory: true)
    let secondRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-window-two-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: firstRoot, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: secondRoot, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: firstRoot)
      try? FileManager.default.removeItem(at: secondRoot)
    }

    let first = makeModel(root: firstRoot)
    let second = makeModel(root: secondRoot)
    first.newDocument(pageSize: AppModel.ScratchPageSize.letter.size)
    second.newDocument(pageSize: AppModel.ScratchPageSize.a4.size)

    #expect(first.sessionID != nil)
    #expect(second.sessionID != nil)
    #expect(first.sessionID != second.sessionID)
    #expect(first.sourceURL != second.sourceURL)
    #expect(first.inspection?.source.sha256 != second.inspection?.source.sha256)
    #expect(first.inspection?.pages.first?.bounds != second.inspection?.pages.first?.bounds)

    first.selectedPageIndex = 0
    first.readerZoom = 2.5
    first.statusMessage = "first window"
    #expect(second.selectedPageIndex == 0)
    #expect(second.readerZoom == 1.0)
    #expect(second.statusMessage != "first window")
  }
}
