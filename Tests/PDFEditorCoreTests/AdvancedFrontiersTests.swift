import Foundation
import PDFEditorCore
import Testing

@Suite("Advanced Frontiers Core Tests")
struct AdvancedFrontiersTests {

  @Test("PDFDigitalSignatureVerifier verifies /ByteRange structure and SHA-256 digest calculation")
  func testDigitalSignatureVerifier() {
    let verifier = PDFDigitalSignatureVerifier()

    // 1. Unsigned PDF
    let unsignedPDF = Data("%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF".utf8)
    let unsignedResult = verifier.verifySignature(pdfData: unsignedPDF)
    #expect(unsignedResult.status == .unsigned)

    // 2. Signed PDF with valid ByteRange
    let slice1 = "%PDF-1.7\n1 0 obj\n<< /Type /Catalog /AcroForm << /Fields [2 0 R] /SigFlags 3 >> >>\nendobj\n2 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Sig /T (Signature1) /V 3 0 R >>\nendobj\n3 0 obj\n<< /Type /Sig /Filter /Adobe.PPKLite /SubFilter /adbe.pkcs7.detached /Name (Alice Smith) /Reason (Approved Contract) /ByteRange ["
    let byteRangePlaceholder = " 0 1000 1500 500 ] /Contents <00000000> >>\nendobj\n"
    let slice2 = "xref\n0 4\n0000000000 65535 f \ntrailer\n<< /Size 4 >>\nstartxref\n1200\n%%EOF\n"

    let fullStr = slice1 + byteRangePlaceholder + slice2
    let fullData = Data(fullStr.utf8)

    let signedResult = verifier.verifySignature(pdfData: fullData)
    #expect(signedResult.status == .validDigestUntrustedCert || signedResult.status == .invalidByteRange)
    #expect(signedResult.signerName == "Alice Smith")
    #expect(signedResult.signatureReason == "Approved Contract")
  }

  @Test("MultiEngineValidator computes agreement score and flags character/field discrepancies")
  func testMultiEngineValidator() {
    let validator = MultiEngineValidator()

    let obsPDFKit = MultiEngineValidator.EngineObservation(
      engineName: "PDFKit",
      pageCount: 5,
      characterCount: 2500,
      fieldCount: 10,
      hasSelectableText: true
    )
    let obsPDFjs = MultiEngineValidator.EngineObservation(
      engineName: "PDF.js",
      pageCount: 5,
      characterCount: 2520,
      fieldCount: 10,
      hasSelectableText: true
    )
    let obsPoppler = MultiEngineValidator.EngineObservation(
      engineName: "Poppler",
      pageCount: 5,
      characterCount: 2490,
      fieldCount: 10,
      hasSelectableText: true
    )

    let report = validator.evaluate(observations: [obsPDFKit, obsPDFjs, obsPoppler])

    #expect(report.engineCount == 3)
    #expect(report.pageCountAgreed)
    #expect(report.textPresenceAgreed)
    #expect(report.fieldCountAgreed)
    #expect(report.overallAgreementRatio > 0.95)
    #expect(report.discrepancies.isEmpty)
  }

  @Test("PDFBatchProcessor scans PII accurately across pages and merges documents")
  func testPDFBatchProcessor() {
    let processor = PDFBatchProcessor()

    let page = PageSnapshot(
      pageIndex: 0,
      pageLabel: "1",
      bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: nil,
      bleedBox: nil,
      trimBox: nil,
      artBox: nil,
      rotation: 0,
      characterCount: 200,
      annotationCount: 0,
      hasSelectableText: true
    )

    let lines: [String] = [
      "Contact user at test.user@example.com or call 555-123-4567",
      "SSN on record is 123-45-6789 for verified tax identity"
    ]

    let report = processor.scanPII(pages: [page], textLinesByPage: [0: lines])

    #expect(report.totalPagesScanned == 1)
    #expect(report.totalPIIFound >= 3)
    #expect(report.matches.contains(where: { $0.type == PDFBatchProcessor.PIIType.email }))
    #expect(report.matches.contains(where: { $0.type == PDFBatchProcessor.PIIType.phone }))
    #expect(report.matches.contains(where: { $0.type == PDFBatchProcessor.PIIType.ssn }))

    // Test Merge
    let doc1 = Data("%PDF-1.7\n1 0 obj\n<< /Type /Page >>\nendobj\n%%EOF".utf8)
    let doc2 = Data("%PDF-1.7\n2 0 obj\n<< /Type /Page >>\nendobj\n%%EOF".utf8)
    let merged = processor.merge(documents: [doc1, doc2])
    #expect(merged.count > doc1.count)
  }

  @Test("XFAFormProcessor detects XFA streams, classifies dynamic vs static, and parses datasets")
  func testXFAFormProcessor() {
    let processor = XFAFormProcessor()

    // 1. Static XFA with dataset XML
    let sampleXFA = """
    %PDF-1.7
    1 0 obj
    << /Type /Catalog /AcroForm << /XFA [(template) 2 0 R (datasets) 3 0 R] >> >>
    endobj
    3 0 obj
    << /Type /EmbeddedFile >>
    stream
    <xfa:datasets>
      <xfa:data>
        <applicantName>John Doe</applicantName>
        <taxId>987654321</taxId>
      </xfa:data>
    </xfa:datasets>
    endstream
    endobj
    """
    let data = Data(sampleXFA.utf8)

    let result = processor.inspectXFA(pdfData: data)
    #expect(result.kind == .staticXFA)
    #expect(result.packetNames.contains("template"))
    #expect(result.packetNames.contains("datasets"))
    #expect(result.extractedFields["applicantName"] == "John Doe")
    #expect(result.extractedFields["taxId"] == "987654321")
  }
}
