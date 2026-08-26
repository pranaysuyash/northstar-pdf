import AppKit
import Foundation
import PDFEditorCore
import PDFKit
import Testing

@testable import PDFEditorRecovery

/// Scratch-document authoring: blank creation, image assembly, clipboard
/// text pagination, structural editing, and scratch export. Models are built
/// with isolated test stores and never touch the user's login keychain.
@MainActor
struct ScratchDocumentTests {
  private func makeIsolatedModel(root: URL) -> AppModel {
    let keyData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
    let keyStore = RecoveryPayloadKeyStore(
      service: "com.pdfeditor.recovery-payload.test",
      account: "scratch-\(UUID().uuidString)",
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

  private func makeTestRoot() -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-scratch-tests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  private func makeTinyPNG() -> Data {
    let representation = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: 4,
      pixelsHigh: 4,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0)!
    return representation.representation(using: .png, properties: [:])!
  }

  @Test("new blank document is a real single-page scratch PDF")
  func newDocumentCreatesARealSinglePageScratchDocument() {
    let root = makeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = makeIsolatedModel(root: root)

    model.newDocument()

    #expect(model.alertMessage == nil)
    #expect(model.isScratchDocument)
    #expect(model.inspection?.pages.count == 1)
    #expect(model.liveDocument?.pageCount == 1)
    #expect(model.liveDocument?.page(at: 0) != nil)
    #expect(model.inspection?.source.fileName == "Untitled.pdf")
    #expect((model.inspection?.source.byteCount ?? 0) > 0)
    #expect(model.inspection?.source.sha256.count == 64)
    #expect(model.inspection?.source.sha256.allSatisfy { $0.isHexDigit } == true)
    #expect(model.inspection?.permissions.canModify == true)
    #expect(model.sourceDocument != nil)
  }

  @Test("blank document honors the requested page size")
  func newDocumentHonorsPageSize() {
    let root = makeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = makeIsolatedModel(root: root)

    model.newDocument(pageSize: AppModel.ScratchPageSize.a4.size)

    let bounds = model.inspection?.pages.first?.bounds
    #expect(bounds?.width == 595)
    #expect(bounds?.height == 842)
    #expect(model.liveDocument?.page(at: 0)?.bounds(for: .mediaBox).width == 595)
  }

  @Test("scratch document supports structural editing and export")
  func scratchDocumentSupportsStructuralEditingAndExport() throws {
    let root = makeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = makeIsolatedModel(root: root)

    model.newDocument()
    model.insertBlankPage()

    #expect(model.liveDocument?.pageCount == 2)
    #expect(model.inspection != nil)

    let destination = root.appendingPathComponent("scratch-export.pdf")
    let exported = model.exportScratchCopy(to: destination)

    #expect(exported)
    #expect(model.exportReport?.status == .validated)
    #expect(FileManager.default.fileExists(atPath: destination.path))

    let reopened = try #require(PDFDocument(url: destination))
    #expect(reopened.pageCount == 2)
  }

  @Test("scratch export refuses to overwrite the working copy")
  func scratchExportRefusesToOverwriteWorkingCopy() {
    let root = makeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = makeIsolatedModel(root: root)

    model.newDocument()
    #expect(model.exportScratchCopy(to: model.sourceURL!) == false)
  }

  @Test("new from images builds one page per image")
  func newDocumentFromImagesBuildsOnePagePerImage() throws {
    let root = makeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = makeIsolatedModel(root: root)

    let pngData = makeTinyPNG()
    let firstImageURL = root.appendingPathComponent("first.png")
    let secondImageURL = root.appendingPathComponent("second.png")
    try pngData.write(to: firstImageURL)
    try pngData.write(to: secondImageURL)

    model.newDocumentFromImages(at: [firstImageURL, secondImageURL])

    #expect(model.alertMessage == nil)
    #expect(model.isScratchDocument)
    #expect(model.liveDocument?.pageCount == 2)
    #expect(model.inspection?.pages.count == 2)
  }

  @Test("clipboard text paginates into a real text PDF")
  func clipboardTextPaginationProducesSelectableTextPages() throws {
    let longText = Array(repeating: "The quick brown fox jumps over the lazy dog. ", count: 600)
      .joined()

    let data = try #require(AppModel.makePDFData(
      fromText: longText,
      pageSize: CGSize(width: 612, height: 792)))
    let document = try #require(PDFDocument(data: data))
    #expect(document.pageCount > 1)
    #expect((document.page(at: 0)?.string?.isEmpty) == false)

    let shortData = try #require(AppModel.makePDFData(
      fromText: "Hello, scratch PDF.",
      pageSize: CGSize(width: 612, height: 792)))
    let shortDocument = try #require(PDFDocument(data: shortData))
    #expect(shortDocument.pageCount == 1)
  }

  @Test("reset clears scratch state")
  func resetClearsScratchState() {
    let root = makeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = makeIsolatedModel(root: root)

    model.newDocument()
    #expect(model.isScratchDocument)

    model.resetDocument()

    #expect(model.inspection == nil)
    #expect(model.liveDocument == nil)
    #expect(model.isScratchDocument == false)
  }
}
