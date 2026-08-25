import XCTest
@testable import PDFEditorCore

final class EvidenceFusionTests: XCTestCase {
  private let alignedRegion = PDFRect(x: 100, y: 200, width: 120, height: 20)

  func testAlignedIndependentEvidenceIsSupported() {
    let result = EvidenceFusion.fuse(signals: [
      EvidenceFusionSignal(id: "native-1", kind: .nativeField, origin: .provider, score: 1, region: alignedRegion),
      EvidenceFusionSignal(id: "vector-1", kind: .vectorRectangle, origin: .geometryExtraction, score: 0.9, region: alignedRegion),
      EvidenceFusionSignal(id: "label-1", kind: .textLabel, origin: .textExtraction, score: 0.8, region: alignedRegion)
    ])
    XCTAssertEqual(result.state, "supported")
    XCTAssertEqual(result.reasonCodes, ["independentEvidenceAgreement"])
    XCTAssertEqual(result.evidenceIDs, ["label-1", "native-1", "vector-1"])
  }

  func testOcrOnlyEvidenceRequiresReview() {
    let result = EvidenceFusion.fuse(signals: [
      EvidenceFusionSignal(id: "ocr-1", kind: .ocrText, origin: .ocr, score: 0.7, region: alignedRegion)
    ])
    XCTAssertEqual(result.state, "review")
    XCTAssertEqual(result.reasonCodes, ["singleEvidenceFamily"])
  }

  func testConflictingHighConfidenceEvidenceAbstains() {
    let result = EvidenceFusion.fuse(signals: [
      EvidenceFusionSignal(id: "vector-a", kind: .vectorRectangle, origin: .geometryExtraction, score: 0.95, region: alignedRegion),
      EvidenceFusionSignal(id: "ocr-b", kind: .ocrText, origin: .ocr, score: 0.95, region: PDFRect(x: 500, y: 600, width: 120, height: 20))
    ])
    XCTAssertEqual(result.state, "abstain")
    XCTAssertEqual(result.reasonCodes, ["conflictingHighConfidenceEvidence", "lowGeometricAgreement"])
  }

  func testEmptyEvidenceAbstains() {
    let result = EvidenceFusion.fuse(signals: [])
    XCTAssertEqual(result.state, "abstain")
    XCTAssertEqual(result.reasonCodes, ["noEvidence"])
  }
}
