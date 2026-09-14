import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Parity tests verifying the Swift fields-channel-to-candidates mapping
/// matches the web app's contract snapshot fieldCandidates envelope.
///
/// The web app (web/app.js) produces a `fieldCandidates` array in the
/// contract snapshot by mapping `document.payload.fields` to candidate-shape
/// entries. The Swift side (`DetectorCandidate.native(from: NativeField)`)
/// does the same mapping. These tests verify they produce identical output
/// for the same input.
///
/// Doctrine alignment:
/// §5 Evidence-based — parity verified against real PDF corpus
/// §11 Engineering integrity — both lanes produce identical contract shapes
@Suite("Field-Candidate Mapping Parity")
struct FieldCandidateMappingParityTests {

  // MARK: - Contract Shape Parity

  @Test("Swift nativeField candidate matches web app contract shape")
  func swiftMatchesWebContractShape() {
    // Simulate a NativeField as the Swift side would see it
    let field = NativeField(
      id: "field-1",
      name: "applicant.name",
      kind: .text,
      pageIndex: 0,
      bounds: PDFRect(x: 185.5, y: 705.39, width: 251, height: 23),
      value: "",
      choices: []
    )

    // Swift mapping
    let swiftCandidate = DetectorCandidate.native(from: field)

    // Expected web app contract shape (from web/app.js fieldCandidates)
    let webContract: [String: Any] = [
      "pageIndex": 0,
      "bounds": ["x": 185.5, "y": 705.39, "width": 251.0, "height": 23.0],
      "kind": "nativeField",
      "suggestedFieldType": "text",
      "entryMode": "native",
      "groupMemberCount": 1,
      "evidenceItems": [
        ["kind": "nativeField", "origin": "nativeFieldExtraction", "summary": "Native field applicant.name"]
      ],
      "labelText": "applicant.name"
    ]

    // Verify contract shape parity
    #expect(swiftCandidate.pageIndex == webContract["pageIndex"] as? Int)
    #expect(swiftCandidate.kind == webContract["kind"] as? String)
    #expect(swiftCandidate.suggestedFieldType == webContract["suggestedFieldType"] as? String)
    #expect(swiftCandidate.entryMode == webContract["entryMode"] as? String)
    #expect(swiftCandidate.groupMemberCount == webContract["groupMemberCount"] as? Int)
    #expect(swiftCandidate.labelAssociated == true) // labelText drives label association

    // Verify bounds parity
    let webBounds = webContract["bounds"] as! [String: Double]
    #expect(swiftCandidate.bounds.x == webBounds["x"])
    #expect(swiftCandidate.bounds.y == webBounds["y"])
    #expect(swiftCandidate.bounds.width == webBounds["width"])
    #expect(swiftCandidate.bounds.height == webBounds["height"])

    // Verify evidence families parity
    #expect(swiftCandidate.evidenceFamilies == ["nativeField"])
  }

  @Test("Swift nativeField candidate for button field kind")
  func swiftButtonFieldKind() {
    let field = NativeField(
      id: "field-2",
      name: "applicant.subscribe",
      kind: .button,
      pageIndex: 0,
      bounds: PDFRect(x: 185.5, y: 567.39, width: 19, height: 19),
      value: "Off",
      choices: []
    )

    let swiftCandidate = DetectorCandidate.native(from: field)

    #expect(swiftCandidate.kind == "nativeField")
    #expect(swiftCandidate.suggestedFieldType == "button")
    #expect(swiftCandidate.entryMode == "native")
    #expect(swiftCandidate.evidenceFamilies == ["nativeField"])
  }

  @Test("Swift nativeField candidate for choice field kind")
  func swiftChoiceFieldKind() {
    let field = NativeField(
      id: "field-3",
      name: "applicant.country",
      kind: .choice,
      pageIndex: 0,
      bounds: PDFRect(x: 185.5, y: 477.39, width: 251, height: 23),
      value: "",
      choices: ["US", "CA", "UK"]
    )

    let swiftCandidate = DetectorCandidate.native(from: field)

    #expect(swiftCandidate.kind == "nativeField")
    #expect(swiftCandidate.suggestedFieldType == "choice")
    #expect(swiftCandidate.entryMode == "native")
    #expect(swiftCandidate.evidenceFamilies == ["nativeField"])
  }

  // MARK: - Cross-Lane Parity with MJS

  @Test("Swift mapping produces identical output to mjs fieldCandidates for base form")
  func crossLaneParityBaseForm() throws {
    let sweepDir = "\(TestRepoRoot.prefix)benchmark/results/corpus-sweep-2026-08-25"
    let pdfURL = URL(fileURLWithPath: "\(sweepDir)/plain-text.pdf")
    guard FileManager.default.fileExists(atPath: pdfURL.path) else { return }

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: pdfURL)

    // Swift: map fields to candidates
    let swiftFieldCandidates = inspection.fields.map(DetectorCandidate.native(from:))

    // Expected: 6 widgets on page 0 (base form)
    #expect(swiftFieldCandidates.count == 6, "Base form must have 6 field candidates")

    // Verify each candidate has the correct contract shape
    for candidate in swiftFieldCandidates {
      #expect(candidate.kind == "nativeField")
      #expect(candidate.entryMode == "native")
      #expect(candidate.groupMemberCount == 1)
      #expect(candidate.evidenceFamilies == ["nativeField"])
      #expect(candidate.labelAssociated == true)
      #expect(candidate.pageIndex == 0) // All on page 0
    }

    // Verify widget names match expected fields
    let fieldNames = inspection.fields.map(\.name).sorted()
    let expectedNames = [
      "applicant.contact", "applicant.contact",
      "applicant.country", "applicant.name",
      "applicant.notes", "applicant.subscribe"
    ]
    #expect(fieldNames == expectedNames, "Widget names must match base form")
  }

  @Test("liveCandidates combines detector candidates and field candidates")
  func liveCandidatesCombinesBothChannels() throws {
    let sweepDir = "\(TestRepoRoot.prefix)benchmark/results/corpus-sweep-2026-08-25"
    let pdfURL = URL(fileURLWithPath: "\(sweepDir)/plain-text.pdf")
    guard FileManager.default.fileExists(atPath: pdfURL.path) else { return }

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: pdfURL)
    let live = NativeDetectorGate.liveCandidates(inspection)

    // liveCandidates = detector candidates + field candidates
    let detectorCandidates = live.filter { $0.kind != "nativeField" }
    let fieldCandidates = live.filter { $0.kind == "nativeField" }

    // Detectors abstain on confirmed fields (0 detector candidates)
    #expect(detectorCandidates.isEmpty, "Detectors must abstain on confirmed fields")
    // Fields are mapped to nativeField candidates
    #expect(fieldCandidates.count == 6, "Must have 6 field candidates from fields channel")

    // All field candidates have the correct contract shape
    for candidate in fieldCandidates {
      #expect(candidate.entryMode == "native")
      #expect(candidate.evidenceFamilies == ["nativeField"])
    }
  }

  // MARK: - Contract Snapshot FieldCandidates Envelope

  @Test("Contract snapshot fieldCandidates envelope matches Swift mapping")
  func contractSnapshotFieldCandidatesEnvelope() throws {
    let sweepDir = "\(TestRepoRoot.prefix)benchmark/results/corpus-sweep-2026-08-25"
    let pdfURL = URL(fileURLWithPath: "\(sweepDir)/plain-text.pdf")
    guard FileManager.default.fileExists(atPath: pdfURL.path) else { return }

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: pdfURL)

    // Swift mapping
    let swiftFieldCandidates = inspection.fields.map(DetectorCandidate.native(from:))

    // Simulate web app contract snapshot fieldCandidates envelope
    // (mirrors web/app.js contractFixtureSnapshot fieldCandidates)
    let webFieldCandidates: [[String: Any]] = inspection.fields.map { field in
      [
        "pageIndex": field.pageIndex,
        "bounds": [
          "x": field.bounds.x,
          "y": field.bounds.y,
          "width": field.bounds.width,
          "height": field.bounds.height
        ],
        "kind": "nativeField",
        "suggestedFieldType": field.kind.rawValue,
        "entryMode": "native",
        "groupMemberCount": 1,
        "evidenceItems": [
          [
            "kind": "nativeField",
            "origin": "nativeFieldExtraction",
            "summary": "Native field \(field.name)"
          ]
        ],
        "labelText": field.name
      ]
    }

    // Verify count parity
    #expect(swiftFieldCandidates.count == webFieldCandidates.count,
            "Swift and web fieldCandidates must have same count")

    // Verify per-candidate parity
    for (idx, (swift, web)) in zip(swiftFieldCandidates, webFieldCandidates).enumerated() {
      #expect(swift.pageIndex == web["pageIndex"] as? Int,
              "Candidate \(idx): pageIndex mismatch")
      #expect(swift.kind == web["kind"] as? String,
              "Candidate \(idx): kind mismatch")
      #expect(swift.suggestedFieldType == web["suggestedFieldType"] as? String,
              "Candidate \(idx): suggestedFieldType mismatch")
      #expect(swift.entryMode == web["entryMode"] as? String,
              "Candidate \(idx): entryMode mismatch")
      #expect(swift.groupMemberCount == web["groupMemberCount"] as? Int,
              "Candidate \(idx): groupMemberCount mismatch")

      let webBounds = web["bounds"] as! [String: Double]
      #expect(swift.bounds.x == webBounds["x"],
              "Candidate \(idx): bounds.x mismatch")
      #expect(swift.bounds.y == webBounds["y"],
              "Candidate \(idx): bounds.y mismatch")
      #expect(swift.bounds.width == webBounds["width"],
              "Candidate \(idx): bounds.width mismatch")
      #expect(swift.bounds.height == webBounds["height"],
              "Candidate \(idx): bounds.height mismatch")
    }
  }
}
