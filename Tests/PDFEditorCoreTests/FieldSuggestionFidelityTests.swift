import CoreGraphics
import Foundation
import Testing
@testable import PDFEditorCore

/// Regression coverage for the field-suggestion fidelity fixes:
/// label canonicalization, bounds refinement (blank-run isolation,
/// collision-aware clipping, metric-derived underline bands, decorative
/// rejection, outlier splits), option naming, and scored profile matching.
struct FieldSuggestionFidelityTests {

  // MARK: - Label canonicalization (R1)

  @Test func canonicalizerTrimsDelimitersAndBlankRuns() {
    #expect(FieldLabelCanonicalizer.canonicalize("Full Name:")?.displayName == "Full Name")
    #expect(
      FieldLabelCanonicalizer.canonicalize("1. FULL NAME:_______")?.displayName == "Full Name")
    #expect(FieldLabelCanonicalizer.canonicalize("a) Home Address *")?.displayName == "Home Address")
    #expect(
      FieldLabelCanonicalizer.canonicalize("APPLICANT NAME")?.displayName == "Applicant Name")
    #expect(
      FieldLabelCanonicalizer.canonicalize("Date  of  Birth")?.displayName == "Date of Birth")
  }

  @Test func canonicalizerRejectsGenericLayoutText() {
    #expect(FieldLabelCanonicalizer.canonicalize("Section:") == nil)
    #expect(FieldLabelCanonicalizer.canonicalize("Note:") == nil)
    #expect(FieldLabelCanonicalizer.canonicalize("") == nil)
    #expect(FieldLabelCanonicalizer.canonicalize(":____") == nil)
  }

  @Test func candidateDisplayNameDerivesAutomatically() throws {
    let labeled = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 100, y: 500, width: 120, height: 18),
      kind: .textAnchored, score: 0.58, evidence: ["e"],
      labelText: "Full Name:")
    #expect(labeled.displayName == "Full Name")
    #expect(labeled.effectiveDisplayName == "Full Name")

    // Round-trip: older payloads without displayName re-derive it on decode.
    let encoder = JSONEncoder()
    let data = try encoder.encode(labeled)
    var payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    payload.removeValue(forKey: "displayName")
    let reencoded = try JSONSerialization.data(withJSONObject: payload)
    let decoded = try JSONDecoder().decode(RegionCandidate.self, from: reencoded)
    #expect(decoded.displayName == "Full Name")

    let unlabeled = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 100, y: 500, width: 120, height: 18),
      kind: .vectorRegion, score: 0.55, evidence: ["e"])
    #expect(unlabeled.effectiveDisplayName == "Entry region")
  }

  @Test func effectiveOptionLabelsFallBackPositionally() {
    let named = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 100, y: 500, width: 120, height: 20),
      kind: .vectorRegion, score: 0.85, evidence: ["e"],
      entryMode: .checkbox, labelText: "Agree to terms:",
      memberBounds: [PDFRect(x: 100, y: 500, width: 14, height: 14)],
      memberLabels: ["Yes ", "", "Male"])
    #expect(named.effectiveOptionLabels == ["Yes", "", "Male"])

    let unnamed = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 100, y: 500, width: 120, height: 20),
      kind: .vectorRegion, score: 0.85, evidence: ["e"], entryMode: .checkbox)
    #expect(unnamed.effectiveOptionLabels.isEmpty)
  }

  // MARK: - Bounds refinement (R2)

  @Test func textAnchoredUnderscoreLineHighlightsOnlyBlankRun() {
    let line = TextLineEvidence(
      pageIndex: 0,
      text: "Applicant name: __________",
      bounds: PDFRect(x: 72, y: 600, width: 240, height: 18)
    )
    let candidates = StaticRegionDetector.detect(lines: [line])

    #expect(candidates.count == 1)
    let bounds = candidates[0].bounds
    // The candidate must start well after the label text begins.
    #expect(bounds.x > line.bounds.x + 60)
    // And must not cover the full line width.
    #expect(bounds.width < line.bounds.width * 0.6)
    #expect(candidates[0].evidence.contains { $0.contains("Blank-run isolated") })
  }

  @Test func textAnchoredColonLineClipsToNearestSameRowContent() {
    let label = TextLineEvidence(
      pageIndex: 0,
      text: "Address:",
      bounds: PDFRect(x: 72, y: 445, width: 53, height: 24)
    )
    // A second-column label blocks the previously unbounded 220pt whitespace.
    let neighbor = TextLineEvidence(
      pageIndex: 0,
      text: "City:",
      bounds: PDFRect(x: 200, y: 445, width: 40, height: 24)
    )
    let candidates = StaticRegionDetector.detect(lines: [label, neighbor])

    // The Address row's entry box, clipped before the neighbor.
    let addressCandidates = candidates.filter { $0.labelText == "Address:" }
    #expect(addressCandidates.count == 1)
    let bounds = addressCandidates[0].bounds
    // Clipped before the neighbor minus padding.
    #expect(bounds.x + bounds.width <= neighbor.bounds.x - 7)
    #expect(candidates[0].evidence.contains { $0.contains("width clipped") })
  }

  @Test func underlineBandHeightFollowsLabelMetrics() {
    let geometry = PDFVectorStreamParser.ParsedPageGeometry(
      pageIndex: 0,
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      rectangles: [],
      horizontalLines: [],
      potentialInputBoxes: [],
      potentialUnderlines: [PDFRect(x: 180, y: 520, width: 140, height: 1)],
      potentialCheckboxes: []
    )
    let tallLabel = TextLineEvidence(
      pageIndex: 0,
      text: "Date of Birth:",
      bounds: PDFRect(x: 72, y: 548, width: 90, height: 22)
    )
    let candidates = StaticRegionDetector.detect(
      lines: [tallLabel], vectorGeometries: [geometry])

    let underlineCandidates = candidates.filter { $0.kind == .vectorRegion }
    #expect(underlineCandidates.count == 1)
    let bandHeight = underlineCandidates[0].bounds.height
    #expect(abs(bandHeight - min(26.0, max(10.0, 22 * 1.35))) < 0.01)
  }

  @Test func decorativeRectangleWithDenseInteriorTextIsRejected() {
    let box = PDFRect(x: 180, y: 300, width: 260, height: 80)
    let geometry = PDFVectorStreamParser.ParsedPageGeometry(
      pageIndex: 0,
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      rectangles: [],
      horizontalLines: [],
      potentialInputBoxes: [box],
      potentialUnderlines: [],
      potentialCheckboxes: []
    )
    // A plausible label sits left of the box, but its interior is a wall
    // of static paragraph text — decoration, not an entry area.
    let label = TextLineEvidence(
      pageIndex: 0,
      text: "Reference number:",
      bounds: PDFRect(x: 60, y: 330, width: 110, height: 16)
    )
    let paragraphLines = (0..<5).map { index in
      TextLineEvidence(
        pageIndex: 0,
        text: "Body text run \(index)",
        bounds: PDFRect(x: 190, y: CGFloat(310 + index * 14), width: 240, height: 12)
      )
    }
    let candidates = StaticRegionDetector.detect(
      lines: [label] + paragraphLines, vectorGeometries: [geometry])
    #expect(candidates.isEmpty)
  }

  @Test func groupOutlierWidthIsSplitOff() {
    // Five uniform cells plus one stray wide cell sharing the row signature.
    var cells = (0..<5).map { index in
      PDFRect(x: 120 + Double(index * 18), y: 600, width: 17, height: 13)
    }
    cells.append(PDFRect(x: 120 + 5 * 18 + 30, y: 600, width: 120, height: 13))
    let label = TextLineEvidence(
      pageIndex: 0,
      text: "First name:",
      bounds: PDFRect(x: 120, y: 632, width: 250, height: 16)
    )
    let geometry = PDFVectorStreamParser.ParsedPageGeometry(
      pageIndex: 0,
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      rectangles: cells.map(\.cgRect),
      horizontalLines: [],
      potentialInputBoxes: cells,
      potentialUnderlines: [],
      potentialCheckboxes: []
    )
    let candidates = StaticRegionDetector.detect(
      lines: [label], vectorGeometries: [geometry])

    // The grouped region keeps only the uniform run; the outlier no longer
    // balloons the union bounds.
    let gridCandidates = candidates.filter { $0.entryMode == .characterGrid }
    #expect(gridCandidates.count == 1)
    #expect(gridCandidates[0].groupMemberCount == 5)
    #expect(gridCandidates[0].bounds.width < 100)
  }

  @Test func checkboxMembersReceiveAdjacentOptionLabels() {
    let yesCell = PDFRect(x: 200, y: 600, width: 14, height: 14)
    let noCell = PDFRect(x: 280, y: 600, width: 14, height: 14)
    let label = TextLineEvidence(
      pageIndex: 0,
      text: "Gender:",
      bounds: PDFRect(x: 120, y: 598, width: 60, height: 16)
    )
    let yesText = TextLineEvidence(
      pageIndex: 0,
      text: "Yes",
      bounds: PDFRect(x: 218, y: 600, width: 22, height: 14)
    )
    let noText = TextLineEvidence(
      pageIndex: 0,
      text: "No",
      bounds: PDFRect(x: 298, y: 600, width: 20, height: 14)
    )
    let geometry = PDFVectorStreamParser.ParsedPageGeometry(
      pageIndex: 0,
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      rectangles: [yesCell.cgRect, noCell.cgRect],
      horizontalLines: [],
      potentialInputBoxes: [yesCell, noCell],
      potentialUnderlines: [],
      potentialCheckboxes: [yesCell, noCell]
    )
    let candidates = StaticRegionDetector.detect(
      lines: [label, yesText, noText], vectorGeometries: [geometry])

    let checkboxCandidates = candidates.filter { $0.entryMode == .checkbox }
    #expect(!checkboxCandidates.isEmpty)
    #expect(checkboxCandidates.contains { $0.memberLabels == ["Yes"] })
  }

  // MARK: - Scored matching and value suggestions (R5)

  @Test func matcherPrefersFirstNameOverFullNameForFirst() {
    var profile = UserProfile(displayName: "Test")
    profile.setValue("Ada Lovelace", for: StandardSemanticKey.fullName.rawValue)
    profile.setValue("Ada", for: StandardSemanticKey.firstName.rawValue)

    let firstMatch = profile.bestMatch(forLabel: "First Name:")
    #expect(firstMatch?.key == StandardSemanticKey.firstName.rawValue)
    #expect(firstMatch?.value == "Ada")

    let fullNameMatch = profile.bestMatch(forLabel: "Full Name:")
    #expect(fullNameMatch?.key == StandardSemanticKey.fullName.rawValue)

    let bareNameMatch = profile.bestMatch(forLabel: "Name:")
    #expect(bareNameMatch?.key == StandardSemanticKey.fullName.rawValue)
  }

  @Test func matcherResolvesAliasesDeterministically() {
    var profile = UserProfile(displayName: "Test")
    profile.setValue("1990-01-15", for: StandardSemanticKey.dateOfBirth.rawValue)
    profile.setValue("(555) 010-0100", for: StandardSemanticKey.phone.rawValue)

    #expect(profile.bestMatch(forLabel: "DOB")?.key == StandardSemanticKey.dateOfBirth.rawValue)
    #expect(profile.bestMatch(forLabel: "Birth Date:")?.key == StandardSemanticKey.dateOfBirth.rawValue)
    #expect(profile.bestMatch(forLabel: "Telephone:")?.key == StandardSemanticKey.phone.rawValue)
    #expect(profile.bestMatch(forLabel: "Ordinary sentence about weather") == nil)
  }

  @Test func valueSuggestionsFormatDatesAndPhones() {
    var profile = UserProfile(displayName: "Test")
    profile.setValue("1990-01-15", for: StandardSemanticKey.dateOfBirth.rawValue)
    profile.setValue("5550100100", for: StandardSemanticKey.phone.rawValue)

    let dateSuggestions = profile.valueSuggestions(
      labelText: "Date of Birth:", fieldType: .date)
    #expect(dateSuggestions.first == "01/15/1990")

    let phoneSuggestions = profile.valueSuggestions(
      labelText: "Phone:", fieldType: .number)
    #expect(phoneSuggestions.first == "(555) 010-0100")

    // SSN-shaped values must pass through untouched (9 digits, not a phone).
    var profileWithSSN = UserProfile(displayName: "T3")
    profileWithSSN.setValue("123-45-6789", for: StandardSemanticKey.ssn.rawValue)
    let ssnSuggestions = profileWithSSN.valueSuggestions(
      labelText: "SSN:", fieldType: .number)
    #expect(ssnSuggestions.first == "123-45-6789")

    // Unmatched labels produce no suggestions.
    #expect(profile.valueSuggestions(labelText: "Favorite color:", fieldType: nil).isEmpty)
  }
}
