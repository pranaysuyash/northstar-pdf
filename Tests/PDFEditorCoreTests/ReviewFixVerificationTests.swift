import AppKit
import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// Regression coverage for the 2026-08-25 review fixes:
/// structural AcroForm detection, radio/checkbox retention semantics,
/// fail-closed image operations, OCR provenance, and rotation-aware raster
/// comparison.
struct ReviewFixVerificationTests {
  @Test func structuralGuardIgnoresLiteralAcroFormText() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-structural-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.pdf")
    let outputURL = directory.appendingPathComponent("output.pdf")
    let fixture = PDFDocument()
    let page = PDFPage()
    fixture.insert(page, at: 0)
    // The literal byte sequence "/AcroForm" inside an annotation string used to
    // trip the raw byte scan even though the document has no AcroForm at all.
    let mention = PDFAnnotation(
      bounds: CGRect(x: 72, y: 700, width: 200, height: 22),
      forType: .freeText,
      withProperties: nil
    )
    mention.contents = "/AcroForm"
    page.addAnnotation(mention)
    #expect(fixture.write(to: sourceURL))

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: sourceURL)
    let overlay = EditOperation(
      pageIndex: 0,
      kind: .overlayText,
      value: "reviewed",
      bounds: PDFRect(x: 72, y: 600, width: 120, height: 22),
      sourceDigest: inspection.source.sha256,
      coordinate: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 72, y: 600, width: 120, height: 22))
    )
    let result = try provider.export(url: sourceURL, operations: [overlay], to: outputURL)
    #expect(result.report.status != .failed)
    #expect(FileManager.default.fileExists(atPath: outputURL.path))
  }

  @Test func buttonValueRetainedRadioSemantics() {
    func kid(_ id: String, name: String, value: String?) -> NativeField {
      NativeField(
        id: id,
        name: name,
        kind: .button,
        pageIndex: 0,
        bounds: PDFRect(x: 0, y: 0, width: 20, height: 20),
        value: value,
        choices: []
      )
    }
    let radioKids = [
      kid("status#0", name: "status", value: "yes"),
      kid("status#1", name: "status", value: nil),
    ]

    // Correct kid on, sibling off.
    #expect(PDFKitProvider.buttonValueRetained(fields: radioKids, requested: "yes"))
    // Wrong kid requested: the "no" kid is not on, so retention must fail even
    // though a sibling is off (the previous rule passed this wrongly).
    #expect(!PDFKitProvider.buttonValueRetained(fields: radioKids, requested: "no"))
    // Both kids on is invalid for a radio group.
    let bothOn = [
      kid("status#0", name: "status", value: "yes"),
      kid("status#1", name: "status", value: "no"),
    ]
    #expect(!PDFKitProvider.buttonValueRetained(fields: bothOn, requested: "yes"))
    // Off request with a kid still on must fail.
    #expect(!PDFKitProvider.buttonValueRetained(fields: radioKids, requested: "off"))
    let allOff = [
      kid("status#0", name: "status", value: nil),
      kid("status#1", name: "status", value: nil),
    ]
    #expect(PDFKitProvider.buttonValueRetained(fields: allOff, requested: "off"))

    // Single checkbox answers boolean tokens.
    let checkboxOn = [kid("consent#0", name: "consent", value: "Yes")]
    let checkboxOff = [kid("consent#0", name: "consent", value: nil)]
    #expect(PDFKitProvider.buttonValueRetained(fields: checkboxOn, requested: " true "))
    #expect(!PDFKitProvider.buttonValueRetained(fields: checkboxOff, requested: "true"))
    #expect(PDFKitProvider.buttonValueRetained(fields: checkboxOff, requested: "false"))

    // Text fields compare with trimmed values (whitespace no longer false-fails).
    let text = [
      NativeField(
        id: "fullName#0", name: "fullName", kind: .text, pageIndex: 0,
        bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), value: "Ada", choices: [])
    ]
    #expect(PDFKitProvider.buttonValueRetained(fields: text, requested: "  Ada  "))
    #expect(!PDFKitProvider.buttonValueRetained(fields: text, requested: "Grace"))
  }

  @Test func overlayImageOperationFailsClosedWithoutPublishing() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-signature-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.pdf")
    let outputURL = directory.appendingPathComponent("output.pdf")
    let fixture = PDFDocument()
    fixture.insert(PDFPage(), at: 0)
    #expect(fixture.write(to: sourceURL))
    let sourceDigest = try PDFKitProvider().inspect(url: sourceURL).source.sha256

    let provider = PDFKitProvider()
    let signature = EditOperation(
      pageIndex: 0,
      kind: .overlayImage,
      value: "signature",
      bounds: PDFRect(x: 72, y: 600, width: 140, height: 48),
      sourceDigest: sourceDigest,
      coordinate: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 72, y: 600, width: 140, height: 48)),
      payload: .asset(assetID: "signature-test", mimeType: "image/png")
    )

    #expect(throws: PDFEditorError.self) {
      try provider.export(url: sourceURL, operations: [signature], to: outputURL)
    }
    // Fail-closed: nothing published, source untouched.
    #expect(!FileManager.default.fileExists(atPath: outputURL.path))
    #expect(try provider.inspect(url: sourceURL).source.sha256 == sourceDigest)
  }

  @Test func rasterCompareSurvivesRotatedPageWithAuthorizedEdit() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-rotated-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.pdf")
    let outputURL = directory.appendingPathComponent("output.pdf")
    let fixture = PDFDocument()
    let page = PDFPage()
    page.rotation = 90
    fixture.insert(page, at: 0)
    #expect(fixture.write(to: sourceURL))

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: sourceURL)
    let region = PDFRect(x: 72, y: 600, width: 140, height: 24)
    let overlay = EditOperation(
      pageIndex: 0,
      kind: .overlayText,
      value: "rotated review",
      bounds: region,
      sourceDigest: inspection.source.sha256,
      coordinate: PDFPageRegion(pageIndex: 0, rect: region)
    )
    let result = try provider.export(url: sourceURL, operations: [overlay], to: outputURL)
    // The authorized edit sits inside the declared region; a rotation-blind
    // exclusion used to sample the wrong area and report outside-region changes.
    #expect(result.report.status != .failed)
    #expect(
      !result.report.messages.contains { $0.contains("outside the authorized operation regions") })
  }

  @Test func detectOCRAppliesFloorAndPreservesProvenance() {
    let pageBounds = PDFRect(x: 0, y: 0, width: 612, height: 792)
    let observations = [
      OCRObservation(
        text: "Applicant name: ________",
        normalizedBounds: PDFRect(x: 0.1, y: 0.8, width: 0.4, height: 0.03),
        confidence: 0.9
      ),
      OCRObservation(
        text: "noise: ______",
        normalizedBounds: PDFRect(x: 0.1, y: 0.5, width: 0.3, height: 0.03),
        confidence: 0.2
      ),
      OCRObservation(
        text: "ordinary sentence without markers",
        normalizedBounds: PDFRect(x: 0.1, y: 0.3, width: 0.5, height: 0.03),
        confidence: 0.95
      ),
    ]

    let candidates = StaticRegionDetector.detectOCR(
      observations: observations, pageIndex: 0, pageBounds: pageBounds)

    // The 0.2-confidence observation is dropped by the floor; the ordinary
    // sentence is dropped by the conservative blank/label gate.
    #expect(candidates.count == 1)
    #expect(candidates[0].kind == .ocrRegion)
    #expect(candidates[0].score <= 0.6)
    #expect(candidates[0].evidence.contains { $0.contains("confidence 0.90") })
    #expect(candidates[0].evidence.contains { $0.contains("not a field contract") })
  }
}
