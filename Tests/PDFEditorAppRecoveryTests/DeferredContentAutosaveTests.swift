import Foundation
import PDFKit
import Testing

@testable import PDFEditorRecovery
import PDFEditorCore

/// Content autosave is debounced off the edit click so a single edit never
/// performs synchronous multi-file recovery writes on the main thread. The
/// durability boundaries are unchanged: `flushPendingContentAutosave()` and
/// `flushRecoveryForTermination()` persist synchronously, and the write
/// protocol (payload → pair manifest → metadata commit pointer) is the same
/// one the interruption harness exercises.
///
/// These tests pin the new timing contract:
/// 1. an applied edit does not synchronously write a recovery generation;
/// 2. the flush hook persists the pending generation synchronously;
/// 3. the termination flush also covers a pending content save.
@Suite(.serialized)
struct DeferredContentAutosaveTests {
  private let fileManager = FileManager.default

  @MainActor
  private func makeModel(rootURL: URL) -> AppModel {
    let keyStore = RecoveryPayloadKeyStore(
      service: "com.pdfeditor.recovery-payload.test",
      account: "deferred-autosave-\(UUID().uuidString)",
      testKeyData: Data((0..<32).map { _ in UInt8.random(in: 0...255) })
    )
    return AppModel(
      sessionStore: FileSessionStore(
        directory: rootURL.appendingPathComponent("sessions", isDirectory: true)),
      recoveryStore: SessionRecoveryStore(
        directory: rootURL.appendingPathComponent("metadata", isDirectory: true)),
      recoveryPayloadStore: SessionPayloadStore(
        directory: rootURL.appendingPathComponent("payload", isDirectory: true),
        keyStore: keyStore),
      recoveryPairStore: RecoveryPairStore(
        directory: rootURL.appendingPathComponent("pair", isDirectory: true)),
      profileStore: EncryptedPDFProfileVault(
        directory: rootURL.appendingPathComponent("profiles", isDirectory: true)),
      templateStore: EncryptedPDFTemplateStore(
        directory: rootURL.appendingPathComponent("templates", isDirectory: true)),
      initializeLocalVaultState: false,
      loadsKeychainSignatures: false
    )
  }

  /// A freshly generated, unencrypted PDF: PDFKit reports full modify and
  /// annotation permissions for it, so the manual-text edit path is admitted.
  private func makeSourcePDF(rootURL: URL) throws -> URL {
    let document = PDFDocument()
    document.insert(PDFPage(), at: 0)
    let url = rootURL.appendingPathComponent("deferred-autosave-source.pdf")
    try document.write(to: url)
    return url
  }

  private func makeContext() throws -> (rootURL: URL, sourceURL: URL) {
    let rootURL = fileManager.temporaryDirectory
      .appendingPathComponent(
        "pdf-editor-deferred-autosave-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    let sourceURL = try makeSourcePDF(rootURL: rootURL)
    return (rootURL, sourceURL)
  }

  @MainActor
  private func applyOneEditTextEdit(_ model: AppModel) {
    model.manualTextPlacement = ManualTextPlacement(
      pageIndex: 0,
      bounds: PDFRect(x: 72, y: 700, width: 160, height: 20)
    )
    model.manualTextDraft = "deferred autosave probe"
    model.applyManualText()
  }

  @Test("edit defers the recovery generation write until flush")
  @MainActor
  func editDefersAutosaveUntilFlush() throws {
    let context = try makeContext()
    defer {
      try? fileManager.removeItem(at: context.rootURL)
    }

    let model = makeModel(rootURL: context.rootURL)
    model.open(url: context.sourceURL)
    #expect(model.inspection != nil)

    applyOneEditTextEdit(model)
    #expect(model.operations.count == 1)
    // Debounced: the click path itself must not have written a generation.
    #expect(!model.hasSavedSession)

    // The flush hook persists synchronously, preserving the ordering contract
    // the interruption and termination harnesses rely on.
    #expect(model.flushPendingContentAutosave())
    #expect(model.hasSavedSession)
    #expect(model.recoveryStatus == .replayable)
  }

  @Test("termination flush covers a pending content autosave")
  @MainActor
  func terminationFlushCoversPendingContentSave() throws {
    let context = try makeContext()
    defer {
      try? fileManager.removeItem(at: context.rootURL)
    }

    let model = makeModel(rootURL: context.rootURL)
    model.open(url: context.sourceURL)
    #expect(model.inspection != nil)

    applyOneEditTextEdit(model)
    #expect(model.operations.count == 1)
    #expect(!model.hasSavedSession)

    #expect(model.flushRecoveryForTermination())
    #expect(model.hasSavedSession)
    #expect(model.recoveryStatus == .replayable)
  }
}
