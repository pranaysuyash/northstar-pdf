import AppKit
import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// Regression fixtures for the Fieldroom salvage pass
/// (docs/research/form-field-lab-salvage-assessment-2026-09-21.md).
///
/// Each defect rule was observed in the reference Python pipeline and maps to
/// a failure class this suite must keep closed: token-boundary type inference,
/// wide-shallow hard negatives, per-page native-overlap suppression, and the
/// review-only signature occupancy audit.
struct FormFieldLabSalvageTests {
  // MARK: - A4: token-boundary type inference

  /// S2: before the token-boundary fix, "candidate".contains("date") inferred
  /// a Date field from "Candidate name:".
  @Test func candidateNameIsNotADateField() {
    let candidates = StaticRegionDetector.detect(
      lines: [line("Candidate name: __________")])
    #expect(candidates.count == 1)
    #expect(candidates.first?.suggestedFieldType != .date)
    #expect(candidates.first?.suggestedFieldType == .text)
  }

  /// "design" embeds "sign"; "Designation:" must not infer Signature. The
  /// label filter does not recognize "designation" as a field label at all,
  /// so the conservative outcome is abstention — never a Signature region.
  @Test func designationIsNotASignatureField() {
    let candidates = StaticRegionDetector.detect(
      lines: [line("Designation: __________")])
    #expect(!candidates.contains { $0.suggestedFieldType == .signature })
  }

  /// "ticket" embeds "tick"; "Ticket No:" must not infer Checkbox, and a
  /// standalone "no" must never act as a type cue.
  @Test func ticketNumberIsNotACheckbox() {
    let candidates = StaticRegionDetector.detect(lines: [line("Ticket No: ______")])
    #expect(candidates.count == 1)
    #expect(candidates.first?.suggestedFieldType != .checkbox)
    #expect(candidates.first?.suggestedFieldType == .text)
  }

  /// Positive controls: real cues keep their types after the fix.
  @Test func positiveTypeControls() {
    #expect(inferred("Date of Birth: __________") == .date)
    #expect(inferred("DOB: __________") == .date)
    #expect(inferred("Signature of Applicant: __________") == .signature)
    #expect(inferred("Check here: ______") == .checkbox)
    #expect(inferred("Select One: ______") == .radio)
    #expect(inferred("Phone No: __________") == .number)
    #expect(inferred("Zip: ______") == .number)
    #expect(inferred("Amount: __________") == .number)
  }

  private func inferred(_ text: String) -> SuggestedFieldType? {
    StaticRegionDetector.detect(lines: [line(text)]).first?.suggestedFieldType
  }

  /// Semantic keys in the canonicalizer obey the same token boundary:
  /// "statement" is not State, "capacity" is not City, "automobile" is not
  /// Mobile, "excellent" is not Cell, "accountant" is not Account, and
  /// "hotel" is not a phone label.
  @Test func semanticKeyTokenBoundary() {
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Statement:") == nil)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Capacity:") == nil)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Automobile:") == nil)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Excellent:") == nil)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Accountant Signature:") == nil)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Hotel:") == nil)

    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "State:") == SemanticFieldTaxonomy.contactState.rawValue)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "City:") == SemanticFieldTaxonomy.contactCity.rawValue)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Tel:") == SemanticFieldTaxonomy.contactPhone.rawValue)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Cell:") == SemanticFieldTaxonomy.contactMobile.rawValue)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Account No:") == SemanticFieldTaxonomy.financialAccount.rawValue)
    #expect(FieldLabelCanonicalizer.inferSemanticKey(from: "Statement of Account:") == SemanticFieldTaxonomy.financialAccount.rawValue)
  }

  // MARK: - A4: wide-shallow rectangles are hard negatives

  /// A 430x4pt rule — the statement/table hard-negative shape — never becomes
  /// a candidate, with or without a nearby label.
  @Test func wideShallowRectangleAbstains() {
    let rule = PDFRect(x: 72, y: 300, width: 430, height: 4)
    let geometry = PDFVectorStreamParser.ParsedPageGeometry(
      pageIndex: 0,
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      rectangles: [],
      horizontalLines: [],
      potentialInputBoxes: [rule],
      potentialUnderlines: [],
      potentialCheckboxes: []
    )

    let unlabeled = StaticRegionDetector.detect(lines: [], vectorGeometries: [geometry])
    #expect(unlabeled.isEmpty)

    let labeled = StaticRegionDetector.detect(
      lines: [line("Total Amount: ", x: 72, y: 310)],
      vectorGeometries: [geometry]
    )
    // The colon label may legitimately anchor a text-anchored whitespace
    // proposal; the hard-negative property is that the wide-shallow rule
    // itself never becomes a geometry candidate.
    #expect(!labeled.contains { candidate in
      candidate.kind == .vectorRegion
        && !(candidate.bounds.cgRect.intersection(
          CGRect(x: rule.x, y: rule.y, width: rule.width, height: rule.height)
        ).isNull)
    })
  }

  // MARK: - A5: per-page native-overlap suppression

  /// A proposed region duplicating a native widget is suppressed; unrelated
  /// proposals on the same page — and on other pages — survive.
  @Test func nativeDuplicateSuppressionIsPerOverlap() {
    let native = NativeField(
      id: "native-1",
      name: "FullName",
      kind: .text,
      pageIndex: 0,
      bounds: PDFRect(x: 200, y: 400, width: 180, height: 20),
      value: nil,
      choices: []
    )
    let duplicate = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 190, y: 395, width: 200, height: 28),
      kind: .vectorRegion,
      status: .suggested,
      score: 0.8,
      evidence: [],
      suggestedFieldType: .text,
      entryMode: .singleText
    )
    let samePageElsewhere = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 60, y: 120, width: 200, height: 24),
      kind: .vectorRegion,
      status: .suggested,
      score: 0.8,
      evidence: [],
      suggestedFieldType: .text,
      entryMode: .singleText
    )
    let otherPage = RegionCandidate(
      pageIndex: 1,
      bounds: PDFRect(x: 200, y: 400, width: 180, height: 20),
      kind: .vectorRegion,
      status: .suggested,
      score: 0.8,
      evidence: [],
      suggestedFieldType: .text,
      entryMode: .singleText
    )

    let suppressed = StaticRegionDetector.suppressingNativeDuplicates(
      [duplicate, samePageElsewhere, otherPage],
      nativeFields: [native]
    )
    #expect(suppressed.count == 2)
    #expect(!suppressed.contains { $0.id == duplicate.id })
    #expect(suppressed.contains { $0.id == samePageElsewhere.id })
    #expect(suppressed.contains { $0.id == otherPage.id })
  }

  // MARK: - A1: signature occupancy audit (pure rules)

  @Test func roleSlotsRequireMultiSignerBlockInLowerBand() {
    let page = 612.0
    let lines = [
      evidence("John Doe", x: 60, y: 120, pageIndex: 0),
      evidence("Director:", x: 60, y: 100, pageIndex: 0),
      evidence("Jane Roe", x: 60, y: 82, pageIndex: 0),
      evidence("Secretary:", x: 60, y: 62, pageIndex: 0),
      // A role word in the upper page area must not anchor a slot.
      evidence("Managing Director:", x: 60, y: 560, pageIndex: 0),
    ]

    let slots = SignatureOccupancyAudit.roleSlots(
      lines: lines,
      pageHeights: [0: page]
    )
    #expect(slots.count == 2)
    #expect(Set(slots.map(\.role)) == ["Director", "Secretary"])
    #expect(slots.allSatisfy { $0.signer != nil })
    for slot in slots {
      #expect(slot.bounds.y <= page * 0.45)
      #expect(slot.bounds.height == 38)
    }
  }

  @Test func singleRoleLineAbstains() {
    let slots = SignatureOccupancyAudit.roleSlots(
      lines: [evidence("Director:", x: 60, y: 100, pageIndex: 0)],
      pageHeights: [0: 612]
    )
    #expect(slots.isEmpty)
  }

  @Test func occupancyClassificationThresholds() {
    #expect(SignatureOccupancyAudit.classify(darkRatio: 0.0).status == .missing)
    #expect(SignatureOccupancyAudit.classify(darkRatio: 0.0003).status == .missing)
    #expect(SignatureOccupancyAudit.classify(darkRatio: 0.001).status == .uncertain)
    #expect(SignatureOccupancyAudit.classify(darkRatio: 0.01).status == .present)
    #expect(SignatureOccupancyAudit.classify(darkRatio: 0.5).status == .present)
  }

  // MARK: - A1: signature occupancy audit (integration, real PDF)

  /// Two signer blocks in the lower band; ink scribbled into one slot. The
  /// occupied slot must read present, the empty one missing — and a prose
  /// page in the same document contributes nothing.
  @Test func integrationAuditClassifiesInkPresence() throws {
    let pdfData = try makeSignatureFixturePDF()
    let document = try #require(PDFDocument(data: pdfData))
    #expect(document.pageCount == 2)

    let observations = SignatureOccupancyAudit.observations(in: document)
    #expect(observations.count == 2)

    let secretary = try #require(observations.first { $0.role == "Secretary" })
    #expect(secretary.status == .present)

    let director = try #require(observations.first { $0.role == "Director" })
    #expect(director.status == .missing)
    #expect(director.signer == "John Doe")
  }

  // MARK: - Helpers

  private func line(_ text: String, x: Double = 72, y: Double = 400) -> TextLineEvidence {
    TextLineEvidence(
      pageIndex: 0,
      text: text,
      bounds: PDFRect(x: x, y: y, width: 220, height: 14)
    )
  }

  private func evidence(_ text: String, x: Double, y: Double, pageIndex: Int) -> TextLineEvidence {
    TextLineEvidence(
      pageIndex: pageIndex,
      text: text,
      bounds: PDFRect(x: x, y: y, width: 150, height: 12)
    )
  }

  /// Builds a two-page PDF. Page 0: "John Doe / Director:" and "Jane Roe /
  /// Secretary:" blocks near the bottom, with ink scribbled over the
  /// Secretary slot. Page 1: plain prose (must yield zero observations).
  private func makeSignatureFixturePDF() throws -> Data {
    var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    let data = NSMutableData()
    let pdfInfo: [CFString: Any] = [kCGPDFContextCreator: "salvage-fixture"]
    guard let consumer = CGDataConsumer(data: data as CFMutableData),
      let context = CGContext(consumer: consumer, mediaBox: &pageRect, pdfInfo as CFDictionary)
    else { throw FixtureError.contextUnavailable }

    // --- Page 0: two role blocks ---
    context.beginPDFPage(nil as CFDictionary?)
    drawText("John Doe", at: NSPoint(x: 80, y: 170), in: context, size: 11)
    drawText("Director:", at: NSPoint(x: 80, y: 140), in: context, size: 11)
    drawText("Jane Roe", at: NSPoint(x: 80, y: 112), in: context, size: 11)
    drawText("Secretary:", at: NSPoint(x: 80, y: 82), in: context, size: 11)

    // Ink scribble over the Secretary slot band (above the role line).
    context.setStrokeColor(CGColor(gray: 0.1, alpha: 1.0))
    context.setLineWidth(2.0)
    context.beginPath()
    context.move(to: CGPoint(x: 84, y: 122))
    context.addCurve(
      to: CGPoint(x: 170, y: 118),
      control1: CGPoint(x: 105, y: 145),
      control2: CGPoint(x: 140, y: 105)
    )
    context.addCurve(
      to: CGPoint(x: 130, y: 126),
      control1: CGPoint(x: 155, y: 122),
      control2: CGPoint(x: 142, y: 130)
    )
    context.strokePath()
    context.endPDFPage()

    // --- Page 1: prose hard negative ---
    context.beginPDFPage(nil as CFDictionary?)
    for index in 0..<14 {
      drawText(
        "The board reviewed the quarterly statements and noted the variance.",
        at: NSPoint(x: 60, y: CGFloat(700 - index * 28)),
        in: context,
        size: 11
      )
    }
    context.endPDFPage()
    context.closePDF()
    return data as Data
  }

  private enum FixtureError: Error {
    case contextUnavailable
  }

  private func drawText(_ text: String, at point: NSPoint, in context: CGContext, size: CGFloat) {
    let font = NSFont.systemFont(ofSize: size)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.black,
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributed)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    context.textPosition = CGPoint(x: point.x, y: point.y)
    CTLineDraw(line, context)
    NSGraphicsContext.restoreGraphicsState()
  }
}
