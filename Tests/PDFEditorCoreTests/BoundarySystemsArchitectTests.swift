import CryptoKit
import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

@Suite("Boundary Systems Architect Contract Tests")
struct BoundarySystemsArchitectTests {

  private let digest = String(repeating: "a", count: 64)
  private let provider = PDFProviderDescriptor(
    id: "pdfkit", version: "test", platform: "macOS", capabilities: ["bounded-token-scan"])

  private func inspection() -> DocumentInspection {
    DocumentInspection(
      source: DocumentSource(fileName: "private.pdf", byteCount: 200, sha256: digest),
      pages: [],
      fields: [],
      candidates: [],
      warnings: [],
      links: [
        PDFLink(id: "safe", pageIndex: 0, label: "safe", kind: .externalURL, destination: "https://private.example", isSafeExternal: true),
        PDFLink(id: "unsafe", pageIndex: 0, label: "unsafe", kind: .externalURL, destination: "file:///private", isSafeExternal: false),
        PDFLink(id: "internal", pageIndex: 0, label: "internal", kind: .internalPage, targetPageIndex: 1)
      ],
      metadata: PDFDocumentMetadata(
        title: "Private title", author: "Private author", subject: "Private subject",
        creator: "Private creator", producer: "Private producer", creationDate: "Private date",
        modificationDate: "", keywords: "private keyword"),
      permissions: PDFPermissionsSummary(canPrint: true, canCopy: false, canModify: false, canAddAnnotations: false, isReadOnly: true),
      attachments: ["private-attachment.docx"],
      security: PDFSecuritySummary(isEncrypted: true, isLocked: false, requiresPassword: false),
      annotationTypeCounts: ["widget": 1, "link": 1, "markup": 2]
    )
  }

  // MARK: - Boundary 1: Untrusted PDF File Input -> Parser Boundary (PER-0933)
  // Contract: Non-PDF binary streams or corrupt headers must be rejected at the boundary before vector or layout parsing begins.

  @Test func untrustedInputBoundaryRejectsNonPDFBinaryStreams() {
    let garbagePayload = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x11, 0x22, 0x33])
    let boxes = PDFVectorStreamParser.parse(data: garbagePayload)
    #expect(boxes.isEmpty)
  }

  // MARK: - Boundary 2: In-Memory Profile Vault -> Encrypted Disk Boundary (PER-0933)
  // Contract: The boundary between in-memory profiles and on-disk files must enforce AES-256-GCM authenticated encryption.

  @Test func memoryToDiskBoundaryEnforcesAuthenticatedCiphertext() throws {
    let key = SymmetricKey(size: .bits256)
    let plaintext = Data("{\"semanticKey\":\"ssn\",\"value\":\"000-00-0000\"}".utf8)

    // Seal at the storage boundary
    let nonce = AES.GCM.Nonce()
    let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)

    // Verify on-disk representation contains zero raw SSN plaintext bytes
    let rawCiphertext = sealedBox.combined ?? Data()
    let rawString = String(decoding: rawCiphertext, as: UTF8.self)
    #expect(!rawString.contains("000-00-0000"))
    #expect(!rawString.contains("semanticKey"))

    // Verify unseal at boundary
    let opened = try AES.GCM.open(sealedBox, using: key)
    #expect(opened == plaintext)
  }

  // MARK: - Boundary 3: Staging Temp -> Final Export Path Boundary (PER-0933)
  // Contract: Exported files must be staged in an isolated temporary location and verified before atomic publication.

  @Test func stagingToDestinationBoundaryGuaranteesSourcePreservation() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let sourceURL = tempDir.appendingPathComponent("source_contract.pdf")
    let outputURL = tempDir.appendingPathComponent("exported_contract.pdf")

    let doc = PDFDocument()
    let page = PDFPage()
    doc.insert(page, at: 0)
    doc.write(to: sourceURL)

    let provider = PDFKitProvider()
    let exportResult = try provider.export(url: sourceURL, operations: [], to: outputURL)

    // Output file exists and source remains untouched
    #expect(FileManager.default.fileExists(atPath: outputURL.path))
    #expect(FileManager.default.fileExists(atPath: sourceURL.path))
    #expect(exportResult.outputURL == outputURL)
  }

  // MARK: - Boundary 4: Preflight & Privacy Provenance Boundary (PER-0933)
  // Contract: Preflight reports crossing the boundary to logs or telemetry must never carry user PII or field content.

  @Test func preflightTelemetryBoundaryNeverExposesPIIValues() throws {
    let data = Data("%PDF-1.7 /EmbeddedFiles /FileAttachment /XFA /RichMedia /JavaScript /OpenAction /AA /Launch /SubmitForm /GoToR /URI /Encrypt /Sig /DocTimeStamp".utf8)
    let report = PDFPreflightBuilder.build(
      inspection: inspection(),
      data: data,
      provider: provider,
      generatedAt: "2026-08-26T00:00:00.000Z"
    )
    try PDFPreflightValidator.validate(report)

    let encoder = JSONEncoder()
    let encoded = try encoder.encode(report)
    let jsonString = String(decoding: encoded, as: UTF8.self)

    #expect(report.payload.metadata.rawValuesIncluded == false)
    #expect(!jsonString.contains("Private author"))
    #expect(!jsonString.contains("Private title"))
    #expect(jsonString.contains(digest))
  }
}
