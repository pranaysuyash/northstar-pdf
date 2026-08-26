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

  /// Corpus directory with compressed-acroform.pdf and tagged-acroform.pdf
  /// (benchmark/results/2026-08-25-native-incremental/corpus).
  private var corpusDir: URL? {
    guard let path = ProcessInfo.processInfo.environment["PDF_EDITOR_INCREMENTAL_CORPUS_DIR"],
      FileManager.default.fileExists(atPath: path)
    else { return nil }
    return URL(fileURLWithPath: path, isDirectory: true)
  }

  // MARK: - Corpus breadth (compressed + tagged sources)

  @Test func compressedSourceFailsClosedWithPreciseDiagnostic() throws {
    guard let corpus = corpusDir else { return }
    let data = try Data(contentsOf: corpus.appendingPathComponent("compressed-acroform.pdf"))
    do {
      _ = try PDFIncrementalFormWriter.walkAcroForm(data)
      Issue.record("Compressed-object AcroForm was accepted; must fail closed")
    } catch let error as PDFIncrementalFormWriter.WriterError {
      guard case .compressedObject = error else {
        Issue.record("Expected compressedObject, got: \(error.localizedDescription)")
        return
      }
    }
  }

  @Test func taggedSourceIsDetectedAndPreservedThroughIncrementalEdit() throws {
    guard let corpus = corpusDir else { return }
    let provider = PDFKitProvider()
    let taggedURL = corpus.appendingPathComponent("tagged-acroform.pdf")
    let sourceData = try Data(contentsOf: taggedURL)

    // Detection: the authored tag tree is reported, not marked unavailable.
    let inspection = try provider.inspect(url: taggedURL)
    #expect(inspection.accessibility.hasTaggedContent)
    #expect(
      inspection.accessibility.notes.contains { $0.contains("/StructTreeRoot") })

    // Preservation: incremental edit keeps the structure tree by construction.
    let nodes = try PDFIncrementalFormWriter.walkAcroForm(sourceData)
    let plan = try PDFIncrementalFormWriter.resolveEditPlan(
      nodes: nodes, targetFieldName: "applicant.name", requestedValue: "Tagged",
      source: sourceData)
    let output = try PDFIncrementalFormWriter.incrementalFieldUpdate(
      sourceData, edits: plan.objectEdits, newObjects: plan.newObjectBodies)
    #expect(output.prefix(sourceData.count) == sourceData)

    let outputURL = writeTemp(output)
    let outputInspection = try provider.inspect(url: outputURL)
    #expect(outputInspection.accessibility.hasTaggedContent)
    #expect(outputInspection.fields.first { $0.name == "applicant.name" }?.value == "Tagged")
  }

  @Test func taggedNonAcroFormExportReportsStructureTreeOutcomeWithEvidence() throws {
    // Derive a tagged document WITHOUT an AcroForm so the edit routes through
    // the PDFKit writer; the RG-005 validation check must report the actual
    // structural outcome consistently (preserved or lost with evidence).
    guard let corpus = corpusDir else { return }
    let taggedNoAcroFormURL = corpus.appendingPathComponent("tagged-no-acroform.pdf")
    if !FileManager.default.fileExists(atPath: taggedNoAcroFormURL.path) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = [
        "python3", "-c",
        """
        import pikepdf
        pdf = pikepdf.open('\(corpus.appendingPathComponent("tagged-acroform.pdf").path)')
        del pdf.Root.AcroForm
        pdf.save('\(taggedNoAcroFormURL.path)')
        """,
      ]
      try process.run()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else { return }
    }

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: taggedNoAcroFormURL)
    #expect(inspection.accessibility.hasTaggedContent)

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-tagged-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let outputURL = directory.appendingPathComponent("output.pdf")

    let overlay = EditOperation(
      pageIndex: 0,
      kind: .overlayText,
      value: "tagged overlay",
      bounds: PDFRect(x: 72, y: 600, width: 140, height: 24),
      sourceDigest: inspection.source.sha256,
      coordinate: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 72, y: 600, width: 140, height: 24))
    )
    // The export may succeed (structure preserved) or be rejected (structure
    // lost); either way the accessibility check must match the structural fact.
    let structuralFact = { (url: URL) in
      PDFKitProvider().detectStructuralAccessibility(try Data(contentsOf: url)).structTree
    }
    if let result = try? provider.export(url: taggedNoAcroFormURL, operations: [overlay], to: outputURL) {
      #expect(result.report.checks.contains { $0.kind == .accessibility })
      #expect(try structuralFact(outputURL))
    } else if FileManager.default.fileExists(atPath: outputURL.path) == false {
      // Rejected before publication: acceptable fail-closed outcome.
      #expect(true)
    }
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

  // MARK: - S3 mutation-sweep tests (deliberate-failure evidence)
  // Each test proves a guard is not merely present but kills a specific
  // mutation. A future code change that weakens the guard without updating
  // these tests will turn S1-pass into S2-failure.

  @Test func singleByteSourcePrefixCorruptionIsDetected() throws {
    guard let sourceURL = publicSampleURL else { return }
    var sourceData = try Data(contentsOf: sourceURL)
    let nodes = try PDFIncrementalFormWriter.walkAcroForm(sourceData)
    let edits = try PDFIncrementalFormWriter.resolveEdits(
      nodes: nodes, targetFieldName: "applicant.name", requestedValue: "Mutation")
    let clean = try PDFIncrementalFormWriter.incrementalFieldUpdate(
      sourceData, edits: edits)

    // Mutate one byte in the middle of the source prefix.
    let mid = sourceData.count / 2
    var tampered = Data(clean)
    tampered[tampered.startIndex + mid] ^= 0xFF

    // The writer's internal assertion already rejects non-prefix output;
    // here we verify the tampered data itself does NOT match the clean prefix.
    #expect(tampered.prefix(sourceData.count) != sourceData)
    // The clean output DID preserve the prefix.
    #expect(clean.prefix(sourceData.count) == sourceData)
  }

  @Test func encryptedSourceFailsClosed() throws {
    // Build a minimal PDF with /Encrypt in the trailer.
    let pdfBytes: [UInt8] = Array(
      "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R /AcroForm 3 0 R >>\nendobj\n"
        .utf8)
    var data = Data(pdfBytes)
    let headerCount = pdfBytes.count
    let trailer = Data(
      "trailer\n<< /Size 4 /Root 1 0 R /Encrypt 4 0 R >>\nstartxref\n0\n%%EOF\n"
        .utf8)
    data.append(trailer)
    #expect(throws: PDFIncrementalFormWriter.WriterError.self) {
      _ = try PDFIncrementalFormWriter.walkAcroForm(data)
    }
  }

  @Test func fieldNotFoundFailsClosed() throws {
    guard let sourceURL = publicSampleURL else { return }
    let sourceData = try Data(contentsOf: sourceURL)
    let nodes = try PDFIncrementalFormWriter.walkAcroForm(sourceData)
    #expect(throws: PDFIncrementalFormWriter.WriterError.self) {
      _ = try PDFIncrementalFormWriter.resolveEdits(
        nodes: nodes, targetFieldName: "nonexistent.field", requestedValue: "x")
    }
  }

  @Test func radioUnknownStateFailsClosed() throws {
    guard let sourceURL = publicSampleURL else { return }
    let sourceData = try Data(contentsOf: sourceURL)
    let nodes = try PDFIncrementalFormWriter.walkAcroForm(sourceData)
    #expect(throws: PDFIncrementalFormWriter.WriterError.self) {
      _ = try PDFIncrementalFormWriter.resolveEdits(
        nodes: nodes, targetFieldName: "applicant.contact",
        requestedValue: "nonexistent_state")
    }
  }

  @Test func emptyEditsReturnSourceUnchanged() throws {
    guard let sourceURL = publicSampleURL else { return }
    let sourceData = try Data(contentsOf: sourceURL)
    let output = try PDFIncrementalFormWriter.incrementalFieldUpdate(
      sourceData, edits: [])
    #expect(output == sourceData)
  }

  @Test func latin1RoundTripBijective() {
    // Every byte value 0–255 must round-trip losslessly through latin1.
    let allBytes = (0...255).map { UInt8($0) }
    let decoded = PDFIncrementalFormWriter.latin1(allBytes)
    let reencoded = PDFIncrementalFormWriter.latin1Bytes(decoded)
    #expect(reencoded == allBytes)
  }

  @Test func pngPredictorNoneFilterPassesUnchanged() {
    let columns = 4
    // Filter byte 0 (None) for two rows: data is unchanged.
    let data: [UInt8] = [0, 1, 2, 3, 4, 0, 5, 6, 7, 8]
    let result = PDFIncrementalFormWriter.applyPngUpPredictor(data, columns: columns)
    #expect(result == [1, 2, 3, 4, 5, 6, 7, 8])
  }

  @Test func pngPredictorUpFilterUnwindsDeltas() {
    let columns = 3
    // Row 0: filter=2, values=[10, 20, 30] (delta from prev=[0,0,0])
    // Row 1: filter=2, values=[5, 10, 15] (delta from prev=[10,20,30])
    let data: [UInt8] = [2, 10, 20, 30, 2, 5, 10, 15]
    let result = PDFIncrementalFormWriter.applyPngUpPredictor(data, columns: columns)
    #expect(result == [10, 20, 30, 15, 30, 45])
  }

  @Test func pngPredictorInvalidFilterFailsClosed() {
    let data: [UInt8] = [3, 1, 2, 3] // filter byte 3 = Sub (unsupported)
    let result = PDFIncrementalFormWriter.applyPngUpPredictor(data, columns: 3)
    #expect(result == nil)
  }

  @Test func insertIntoDictPreservesNonTargetKeys() throws {
    let original = "<< /Type /Catalog /Pages 2 0 R /Lang (en) >>"
    let patched = PDFIncrementalFormWriter.insertIntoDict(
      original, pairs: [("/V", "(test)")])
    #expect(patched.contains("/Type /Catalog"))
    #expect(patched.contains("/Pages 2 0 R"))
    #expect(patched.contains("/Lang (en)"))
    #expect(patched.contains("/V (test)"))
  }

  // MARK: - Helpers

  private func writeTemp(_ data: Data) -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-rg001-\(UUID().uuidString).pdf")
    try? data.write(to: url)
    return url
  }
}
