import Foundation
import Testing
@testable import PDFEditorCore

/// RG-001 verification: the native incremental form writer preserves source
/// bytes as a byte-exact prefix, keeps external AcroForm radio-choice metadata
/// intact, and fails closed on unsupported structures. The external oracle
/// (qpdf structural check + pikepdf/Poppler reopen) mirrors the web lane's
/// RG-002 evidence and is exercised only when the fixture and tools exist.
struct PDFIncrementalWriterTests {
  private var publicSampleURL: URL? {
    guard let path = ProcessInfo.processInfo.environment["PDF_EDITOR_PUBLIC_ACROFORM_INPUT"],
      FileManager.default.fileExists(atPath: path)
    else { return nil }
    return URL(fileURLWithPath: path)
  }

  // MARK: - Pure parsing tests (no fixture needed)

  @Test func classicXrefParsingAndDictPatching() throws {
    // Minimal single-object PDF skeleton with a classic xref table.
    let object1 =
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
    let header = "%PDF-1.4\n"
    let object1Offset = header.count
    let body = header + object1
    let xrefOffset = body.count
    let xref =
      "xref\n0 2\n"
      + "0000000000 65535 f \n"
      + String(format: "%010d %05d n \n", object1Offset, 0)
      + "trailer\n<< /Size 2 /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n"
    let data = Data((body + xref).map { UInt8($0.unicodeScalars.first!.value) })

    let offset = try PDFIncrementalFormWriter.findLastStartxrefOffset(data)
    #expect(offset == xrefOffset)
    let xrefInfo = try PDFIncrementalFormWriter.parseXref(data, offset: offset)
    #expect(xrefInfo.entries[1]?.offset == object1Offset)
    #expect(xrefInfo.trailer["/Root"] == "1 0 R")

    let (gen, text) = try PDFIncrementalFormWriter.objectSpan(
      data, xref: xrefInfo, objectNumber: 1)
    #expect(gen == 0)
    #expect(text.hasPrefix("1 0 obj"))

    let patched = PDFIncrementalFormWriter.insertIntoDict(
      text, pairs: [("/V", "(hello)")])
    #expect(patched.contains("/V (hello)"))
    #expect(patched.contains("/Type /Catalog"))
    // Replacing an existing key rewrites its value in place.
    let replaced = PDFIncrementalFormWriter.insertIntoDict(
      patched, pairs: [("/V", "(world)")])
    #expect(replaced.contains("/V (world)"))
    #expect(!replaced.contains("(hello)"))
  }

  @Test func pdfStringEscapesDelimiters() {
    #expect(PDFIncrementalFormWriter.pdfString("Ada") == "(Ada)")
    #expect(PDFIncrementalFormWriter.pdfString("a(b)c") == "(a\\(b\\)c)")
    #expect(PDFIncrementalFormWriter.pdfString("back\\slash") == "(back\\\\slash)")
  }

  @Test func resolveEditsRadioGroupWritesParentAndKids() throws {
    // Mirrors the public sample's structure: field node with two widget kids.
    func node(
      _ num: Int, fqn: String, widget: Bool, states: [String] = [], fieldType: String? = nil,
      kids: [Int] = []
    ) -> PDFIncrementalFormWriter.FormObjectNode {
      PDFIncrementalFormWriter.FormObjectNode(
        objectNumber: num, fullyQualifiedName: fqn, isWidget: widget, rect: nil,
        buttonStates: states, fieldType: fieldType, childObjectNumbers: kids)
    }
    let nodes = [
      node(24, fqn: "applicant.contact", widget: false, fieldType: "Btn"),
      node(25, fqn: "applicant.contact", widget: true, states: ["/0", "/Off"]),
      node(30, fqn: "applicant.contact", widget: true, states: ["/Off", "/1"]),
    ]

    let edits = try PDFIncrementalFormWriter.resolveEdits(
      nodes: nodes, targetFieldName: "applicant.contact", requestedValue: "1")
    // Parent /V /1; kid 30 /AS /1; kid 25 /AS /Off.
    #expect(edits.count == 3)
    #expect(edits[0].objectNumber == 24)
    #expect(edits[0].pairs.contains { $0.key == "/V" && $0.value == "/1" })
    let kidEdits = edits.dropFirst()
    #expect(kidEdits.contains { $0.objectNumber == 30 && $0.pairs.first?.value == "/1" })
    #expect(kidEdits.contains { $0.objectNumber == 25 && $0.pairs.first?.value == "/Off" })

    // Clearing the radio writes /Off everywhere.
    let cleared = try PDFIncrementalFormWriter.resolveEdits(
      nodes: nodes, targetFieldName: "applicant.contact", requestedValue: "off")
    #expect(cleared.allSatisfy { edit in
      edit.pairs.allSatisfy { $0.value == "/Off" }
    })

    // An unknown state fails closed instead of silently clearing.
    #expect(throws: PDFIncrementalFormWriter.WriterError.self) {
      _ = try PDFIncrementalFormWriter.resolveEdits(
        nodes: nodes, targetFieldName: "applicant.contact", requestedValue: "maybe")
    }
  }

  // MARK: - Fixture-gated oracle tests

  @Test func incrementalWriterPreservesPrefixChoicesAndPassesQpdf() throws {
    guard let sourceURL = publicSampleURL else { return }
    let sourceData = try Data(contentsOf: sourceURL)

    let nodes = try PDFIncrementalFormWriter.walkAcroForm(sourceData)
    let names = Set(nodes.map { $0.fullyQualifiedName })
    #expect(names.contains("applicant.name"))
    #expect(names.contains("applicant.contact"))
    #expect(
      nodes.contains {
        $0.fullyQualifiedName == "applicant.subscribe" && $0.buttonStates.contains("/Yes")
      })

    let edits = try PDFIncrementalFormWriter.resolveEdits(
      nodes: nodes, targetFieldName: "applicant.name", requestedValue: "Ada Lovelace")
    let output = try PDFIncrementalFormWriter.incrementalFieldUpdate(sourceData, edits: edits)

    // RG-017: byte-exact source prefix.
    #expect(output.count > sourceData.count)
    #expect(output.prefix(sourceData.count) == sourceData)

    // PDFKit reopen: the new value is visible and choices survive.
    let reopened = try PDFKitProvider().inspect(url: writeTemp(output))
    #expect(reopened.fields.first { $0.name == "applicant.name" }?.value == "Ada Lovelace")
    let contact = reopened.fields.filter { $0.name == "applicant.contact" }
    #expect(contact.contains { !$0.choices.isEmpty })
  }

  @Test func radioSelectionRoundTripsThroughIncrementalWriter() throws {
    guard let sourceURL = publicSampleURL else { return }
    let sourceData = try Data(contentsOf: sourceURL)
    let nodes = try PDFIncrementalFormWriter.walkAcroForm(sourceData)

    let edits = try PDFIncrementalFormWriter.resolveEdits(
      nodes: nodes, targetFieldName: "applicant.contact", requestedValue: "1")
    let output = try PDFIncrementalFormWriter.incrementalFieldUpdate(sourceData, edits: edits)

    let reopened = try PDFKitProvider().inspect(url: writeTemp(output))
    let contactFields = reopened.fields.filter { $0.name == "applicant.contact" }
    #expect(contactFields.contains { $0.value == "1" })
    #expect(contactFields.contains { $0.value == nil })
    #expect(contactFields.contains { !$0.choices.isEmpty })
  }

  @Test func exportRoutesAcroFormFieldEditsThroughIncrementalWriter() throws {
    guard let sourceURL = publicSampleURL else { return }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-rg001-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let outputURL = directory.appendingPathComponent("output.pdf")

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: sourceURL)
    #expect(!inspection.fields.isEmpty)
    let field = inspection.fields.first { $0.kind == .text }!
    let operation = EditOperation(
      pageIndex: field.pageIndex,
      targetID: field.name,
      kind: .nativeFieldValue,
      value: "Incremental",
      bounds: field.bounds,
      sourceDigest: inspection.source.sha256,
      coordinate: PDFPageRegion(pageIndex: field.pageIndex, rect: field.bounds)
    )
    let result = try provider.export(url: sourceURL, operations: [operation], to: outputURL)
    #expect(result.report.status == .validated)
    #expect(result.report.sourceUnchanged)

    // The published output preserves the source as a byte-exact prefix.
    let sourceData = try Data(contentsOf: sourceURL)
    let outputData = try Data(contentsOf: outputURL)
    #expect(outputData.prefix(sourceData.count) == sourceData)
    #expect(try provider.inspect(url: outputURL).fields.first { $0.name == field.name }?.value == "Incremental")

    // Durable artifact for external oracle runs when requested.
    if let artifactDir = ProcessInfo.processInfo.environment["PDF_EDITOR_RG001_ARTIFACTS"] {
      let dir = URL(fileURLWithPath: artifactDir, isDirectory: true)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      try Data(contentsOf: sourceURL).write(to: dir.appendingPathComponent("source.pdf"))
      try Data(contentsOf: outputURL).write(to: dir.appendingPathComponent("incremental-output.pdf"))
    }
  }

  @Test func nonFieldOperationsOnAcroFormStillFailClosed() throws {
    guard let sourceURL = publicSampleURL else { return }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-rg001-guard-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let outputURL = directory.appendingPathComponent("output.pdf")

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: sourceURL)
    let overlay = EditOperation(
      pageIndex: 0,
      kind: .overlayText,
      value: "nope",
      bounds: PDFRect(x: 72, y: 600, width: 100, height: 20),
      sourceDigest: inspection.source.sha256,
      coordinate: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 72, y: 600, width: 100, height: 20))
    )
    #expect(throws: PDFEditorError.self) {
      _ = try provider.export(url: sourceURL, operations: [overlay], to: outputURL)
    }
    #expect(!FileManager.default.fileExists(atPath: outputURL.path))
  }

  private func writeTemp(_ data: Data) -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-rg001-\(UUID().uuidString).pdf")
    try? data.write(to: url)
    return url
  }
}
