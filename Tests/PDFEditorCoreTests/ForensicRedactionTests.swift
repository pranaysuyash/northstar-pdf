import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

@Suite("Forensic Permanent Redaction Engine Tests")
struct ForensicRedactionTests {

  @Test("Lane 1 & 2: PDFContentStreamRedactor tokenizes text operators and injects vector burn-in")
  func testContentStreamRedactorGlyphExcision() {
    let redactor = PDFContentStreamRedactor()
    let streamText = """
    q
    1 0 0 1 0 0 cm
    BT
    /F1 12 Tf
    72 700 Td
    (Confidential SSN: 123-45-6789) Tj
    ET
    BT
    /F1 12 Tf
    72 650 Td
    (Public Unclassified Text) Tj
    ET
    Q
    """
    let streamData = streamText.data(using: .isoLatin1)!

    let target = PDFContentStreamRedactor.RedactionTarget(
      pageIndex: 0,
      bounds: PDFRect(x: 70, y: 690, width: 200, height: 25),
      sensitiveText: "123-45-6789"
    )

    let (redactedData, summary) = redactor.redactStream(
      streamData: streamData,
      pageIndex: 0,
      targets: [target]
    )

    let outputString = String(data: redactedData, encoding: .isoLatin1)!

    #expect(summary.operatorsRemoved == 1)
    #expect(summary.vectorBoxesBurned == 1)
    #expect(!outputString.contains("123-45-6789"))
    #expect(outputString.contains("[FORENSIC_REDACTED_TEXT_OP]"))
    #expect(outputString.contains("Public Unclassified Text"))
    #expect(outputString.contains("0 0 0 rg 0 0 0 RG 70.000 690.000 200.000 25.000 re f"))
  }

  @Test("Lane 3 & 6: Forensic Redaction physically destroys text and passes postcondition verification")
  func testForensicRedactionOnRealPDF() throws {
    // 1. Create a pristine PDF document with sensitive text
    let pdfData = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
      Issue.record("Failed to create CGContext")
      return
    }

    context.beginPage(mediaBox: &mediaBox)
    let text = "CLASSIFIED EYES ONLY: 987-65-4321"
    let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
    let attrString = NSAttributedString(string: text, attributes: [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    ])
    let line = CTLineCreateWithAttributedString(attrString)
    context.textPosition = CGPoint(x: 72, y: 700)
    CTLineDraw(line, context)
    context.endPage()
    context.closePDF()

    let sourceData = pdfData as Data
    let sourceDoc = try #require(PDFDocument(data: sourceData))
    let sourcePage = try #require(sourceDoc.page(at: 0))
    let initialText = sourcePage.string ?? ""
    #expect(initialText.contains("CLASSIFIED EYES ONLY"))

    // 2. Execute First-Principles Forensic Redaction
    let engine = ForensicRedactionEngine.shared
    let target = ForensicRedactionEngine.Target(
      pageIndex: 0,
      bounds: PDFRect(x: 70, y: 690, width: 300, height: 30),
      sensitiveText: "CLASSIFIED EYES ONLY"
    )

    let (redactedData, receipt) = try engine.redact(
      pdfData: sourceData,
      targets: [target],
      options: ForensicRedactionEngine.Options(
        sanitizeMetadata: true,
        burnVectorRectangles: true,
        purgeRedactionAnnotations: true,
        verifyForensicPostconditions: true,
        allowRasterFlatteningFallback: true
      )
    )

    #expect(receipt.targetCount == 1)
    #expect(receipt.zeroExtractableCharactersVerified)
    #expect(receipt.pagesModified == [0])

    // 3. Postcondition Verification via independent reopen
    let reopenedDoc = try #require(PDFDocument(data: redactedData))
    let reopenedPage = try #require(reopenedDoc.page(at: 0))

    // Assert: zero extractable characters within redaction bounds
    let targetRect = CGRect(x: 70, y: 690, width: 300, height: 30)
    let extractedInBox = reopenedPage.selection(for: targetRect)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    #expect(extractedInBox.isEmpty)

    // Assert: sensitive text is eliminated from page string
    let pageAllText = reopenedPage.string ?? ""
    #expect(!pageAllText.contains("CLASSIFIED EYES ONLY"))
    #expect(!pageAllText.contains("987-65-4321"))
  }

  @Test("Lane 6: Postcondition verification fails closed when sensitive data leaks")
  func testForensicPostconditionVerificationCatchesLeak() {
    // PDF that contains the sensitive text
    let pdfData = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
      return
    }
    context.beginPage(mediaBox: &mediaBox)
    let attrString = NSAttributedString(string: "LEAKED_SECRET_KEY_12345", attributes: [:])
    let line = CTLineCreateWithAttributedString(attrString)
    context.textPosition = CGPoint(x: 100, y: 500)
    CTLineDraw(line, context)
    context.endPage()
    context.closePDF()

    let engine = ForensicRedactionEngine.shared
    let target = ForensicRedactionEngine.Target(
      pageIndex: 0,
      bounds: PDFRect(x: 90, y: 490, width: 250, height: 30),
      sensitiveText: "LEAKED_SECRET_KEY_12345"
    )

    // Verify verification gate throws when called against unredacted data
    #expect(throws: ForensicRedactionEngine.RedactionError.self) {
      try engine.verifyForensicPostconditions(
        data: pdfData as Data,
        targets: [target]
      )
    }
  }

  @Test("Fail-Closed Boundary: Empty targets throws emptyTargets error")
  func testEmptyTargetsFailsClosed() {
    let engine = ForensicRedactionEngine.shared
    #expect(throws: ForensicRedactionEngine.RedactionError.emptyTargets) {
      _ = try engine.redact(pdfData: Data([0x25, 0x50, 0x44, 0x46]), targets: [])
    }
  }
}
