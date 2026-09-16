import Foundation
import PDFEditorCore
import Testing

@Suite("Advanced Core Capabilities Tests")
struct AdvancedCoreCapabilitiesTests {

  @Test("TextRunFontMatcher resolves monospace, serif, and sans-serif fonts accurately")
  func testTextRunFontMatcher() {
    let matcher = TextRunFontMatcher()

    let courier = matcher.resolveFont(name: "Courier-Bold", pointSize: 12)
    #expect(courier.isMonospace)
    #expect(courier.familyName == "Courier New")

    let times = matcher.resolveFont(name: "TimesNewRomanPS-Italic", pointSize: 14)
    #expect(!times.isMonospace)
    #expect(times.isItalic)
    #expect(times.familyName.contains("Times"))

    let helvetica = matcher.resolveFont(name: "Helvetica-Bold", pointSize: 16)
    #expect(!helvetica.isMonospace)
    #expect(helvetica.weight == .bold)
    #expect(helvetica.familyName == "Helvetica")

    let width = matcher.estimateTextWidth(text: "Hello World", font: helvetica)
    #expect(width > 0)
  }

  @Test("PDFContentStreamRedactor strips matching text and XObject operator sequences")
  func testPDFContentStreamRedactor() {
    let redactor = PDFContentStreamRedactor()

    let rawStream = """
    BT
    /F1 12 Tf
    (Confidential Data) Tj
    ET
    /Im1 Do
    """
    let data = Data(rawStream.utf8)

    let target = PDFContentStreamRedactor.RedactionTarget(
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 10, width: 100, height: 20)
    )

    let (redacted, summary) = redactor.redactStream(
      streamData: data,
      pageIndex: 0,
      targets: [target]
    )

    let resultString = String(decoding: redacted, as: UTF8.self)
    #expect(!resultString.contains("(Confidential Data) Tj"))
    #expect(!resultString.contains("/Im1 Do"))
    #expect(resultString.contains("% [REDACTED_TEXT_OP]"))
    #expect(resultString.contains("% [REDACTED_XOBJECT_OP]"))
    #expect(summary.operatorsRemoved >= 2)
  }

  @Test("PDFSanitizer neutralizes OpenActions, JavaScript, and strips XMP Metadata")
  func testPDFSanitizer() {
    let sanitizer = PDFSanitizer()

    let samplePDF = """
    %PDF-1.7
    1 0 obj
    << /Type /Catalog /OpenAction 2 0 R /AA 3 0 R /Metadata 4 0 R >>
    endobj
    2 0 obj
    << /S /JavaScript /JS (alert('hi')) >>
    endobj
    """
    let data = Data(samplePDF.utf8)

    let (sanitized, report) = sanitizer.sanitize(pdfData: data)
    let sanitizedString = String(decoding: sanitized, as: UTF8.self)

    #expect(!sanitizedString.contains("/OpenAction"))
    #expect(!sanitizedString.contains("/JavaScript"))
    #expect(sanitizedString.contains("/_NeutralizedOpenAction"))
    #expect(sanitizedString.contains("/_NeutralizedJS"))
    #expect(report.actionsNeutralized >= 2)
  }

  @Test("PDFUATaggingEngine generates structural hierarchy and accessibility alt text")
  func testPDFUATaggingEngine() {
    let engine = PDFUATaggingEngine()

    let page = PageSnapshot(
      pageIndex: 0,
      pageLabel: "1",
      bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: nil,
      bleedBox: nil,
      trimBox: nil,
      artBox: nil,
      rotation: 0,
      characterCount: 150,
      annotationCount: 1,
      hasSelectableText: true
    )

    let field = NativeField(
      id: "full_name",
      name: "Full Name",
      kind: .text,
      pageIndex: 0,
      bounds: PDFRect(x: 50, y: 500, width: 200, height: 24),
      value: "",
      choices: []
    )

    let (elements, report) = engine.generateAccessibilityTags(
      pages: [page],
      candidates: [],
      fields: [field],
      signatures: []
    )

    #expect(report.structureRootCreated)
    #expect(report.totalTaggedElements >= 2)
    #expect(elements.contains(where: { $0.type == .document }))
    #expect(elements.contains(where: { $0.type == .section }))
    #expect(elements.contains(where: { $0.type == .formField }))
  }

  @Test("TableExtractor converts StructuredExtractionResult into verified multi-table CSV")
  func testTableExtractorCSVWorkflow() {
    let table1 = DetectedTable(
      rows: 2,
      columns: 2,
      cells: [["Col1", "Col2"], ["Val1", "Val2"]],
      bounds: PDFRect(x: 0, y: 0, width: 200, height: 100),
      confidence: 0.95
    )
    let extraction = StructuredExtractionResult(
      fullText: "Col1 Col2 Val1 Val2",
      blocks: [],
      tables: [table1],
      headings: [],
      pageCount: 1,
      totalCharacters: 20,
      extractionTimeMs: 12.0
    )

    let tableExtractor = TableExtractor(minConfidence: 0.5)
    let result = tableExtractor.extract(extraction: extraction)

    #expect(result.totalTables == 1)
    #expect(result.averageConfidence >= 0.9)

    let csv = tableExtractor.exportAllCSV(result)
    #expect(csv.contains("Table 1 (Page 1, 2x2)"))
    #expect(csv.contains("Col1,Col2"))
    #expect(csv.contains("Val1,Val2"))
  }

  @Test("DocumentDiffBuilder reports field and geometry modifications between document inspections")
  func testDocumentDiffBuilderWorkflow() {
    let page1 = PageSnapshot(
      pageIndex: 0,
      pageLabel: "1",
      bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: nil,
      bleedBox: nil,
      trimBox: nil,
      artBox: nil,
      rotation: 0,
      characterCount: 50,
      annotationCount: 0,
      hasSelectableText: true
    )

    let sourceField = NativeField(
      id: "f1",
      name: "Field1",
      kind: .text,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 10, width: 100, height: 20),
      value: "Original Value",
      choices: []
    )

    let outputField = NativeField(
      id: "f1",
      name: "Field1",
      kind: .text,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 10, width: 100, height: 20),
      value: "Modified Value",
      choices: []
    )

    let sourceInspection = DocumentInspection(
      source: DocumentSource(fileName: "source.pdf", byteCount: 1000, sha256: "sha_source"),
      pages: [page1],
      fields: [sourceField],
      candidates: [],
      warnings: []
    )

    let outputInspection = DocumentInspection(
      source: DocumentSource(fileName: "output.pdf", byteCount: 1050, sha256: "sha_output"),
      pages: [page1],
      fields: [outputField],
      candidates: [],
      warnings: []
    )

    let diff = DocumentDiffBuilder.build(
      source: sourceInspection,
      output: outputInspection,
      operations: []
    )

    #expect(diff.pageCount == 1)
    #expect(diff.pages.first?.regions.count == 1)
    #expect(diff.pages.first?.regions.first?.kind == .nativeFieldChanged)
    #expect(diff.pages.first?.regions.first?.sourceText == "Original Value")
    #expect(diff.pages.first?.regions.first?.outputText == "Modified Value")
  }
}
