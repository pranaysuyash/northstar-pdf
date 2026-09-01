import Foundation
import PDFKit
import Testing

import PDFEditorCore
@testable import PDFEditorRecovery

/// NM-T17 / NM-T18: executable export profiles must publish a separate,
/// reopenable copy without mutating the admitted source. Unsupported profiles
/// remain visible as an explicit provider denial.
@MainActor
struct ExportProfileValidationTests {
  private func makeModel(root: URL) -> AppModel {
    let keyStore = RecoveryPayloadKeyStore(
      service: "com.pdfeditor.recovery-payload.test",
      account: "export-profile-\(UUID().uuidString)",
      testKeyData: Data(repeating: 9, count: 32)
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

  private func makeRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-export-profile-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
  }

  @Test("page extraction publishes a validated standalone copy")
  func pageExtractionPublishesValidatedCopy() throws {
    let root = try makeRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = makeModel(root: root)
    model.newDocument()
    model.insertBlankPage()

    let sourceDigest = model.inspection?.source.sha256
    let destination = root.appendingPathComponent("extracted.pdf")
    #expect(model.splitPageRange(from: 0, to: 1, destination: destination))
    #expect(PDFDocument(url: destination)?.pageCount == 2)
    #expect(model.exportReport?.status == .validated)
    #expect(model.inspection?.source.sha256 == sourceDigest)
    #expect(model.sourceURL != destination)
  }

  @Test("sanitized copy removes document attributes and preserves source")
  func sanitizedCopyRemovesAttributesAndPreservesSource() throws {
    let root = try makeRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = makeModel(root: root)
    model.newDocument()
    model.liveDocument?.documentAttributes = [PDFDocumentAttribute.titleAttribute: "Private title"]

    let sourceDigest = model.inspection?.source.sha256
    let destination = root.appendingPathComponent("sanitized.pdf")
    #expect(model.sanitizeAndExportCopy(destination: destination))
    let reopened = PDFDocument(url: destination)
    let attributes = reopened?.documentAttributes ?? [:]
    #expect((attributes[PDFDocumentAttribute.titleAttribute] as? String ?? "").isEmpty)
    #expect((attributes[PDFDocumentAttribute.authorAttribute] as? String ?? "").isEmpty)
    #expect(model.exportReport?.status == .validated)
    #expect(model.inspection?.source.sha256 == sourceDigest)
  }

  @Test("flattened profile is explicitly denied until a form-aware provider exists")
  func flattenedProfileIsExplicitlyDenied() {
    let model = AppModel(initializeLocalVaultState: false, loadsKeychainSignatures: false)
    model.newDocument()
    model.presentExportReview(profile: .flattenedCopy)

    #expect(!model.canPrepareExportReviewProfile)
    model.continueExportReview()
    #expect(model.statusMessage?.contains("unavailable") == true)
    #expect(model.isExportReviewPresented == false)
  }
}
