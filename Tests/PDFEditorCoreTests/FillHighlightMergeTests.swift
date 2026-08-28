import XCTest
import PDFEditorCore

final class FillHighlightMergeTests: XCTestCase {

  private func hl(
    id: String, page: Int, rect: CGRect, state: FillHighlight.State, label: String?
  ) -> FillHighlight {
    FillHighlight(
      id: id,
      pageIndex: page,
      bounds: PDFRect(rect),
      state: state,
      label: label
    )
  }

  /// S2: overlapping same-(page,state,label) highlights collapse to one union rect.
  func testMergesOverlappingSameLabel() {
    let a = hl(id: "a", page: 0, rect: CGRect(x: 0, y: 0, width: 10, height: 10),
               state: .candidateUnfilled, label: "Name")
    let b = hl(id: "b", page: 0, rect: CGRect(x: 2, y: 2, width: 10, height: 10),
               state: .candidateUnfilled, label: "Name")
    let c = hl(id: "c", page: 0, rect: CGRect(x: 100, y: 100, width: 10, height: 10),
               state: .candidateUnfilled, label: "Name")

    let result = mergeOverlappingFillHighlights([a, b, c])

    let nameUnfilled = result.filter {
      $0.pageIndex == 0 && $0.state == .candidateUnfilled && $0.label == "Name"
    }
    XCTAssertEqual(nameUnfilled.count, 2, "overlapping pair merges; disjoint one stays separate")
    let merged = nameUnfilled.first { $0.bounds.cgRect.width == 12 }
    XCTAssertNotNil(merged, "merged highlight should be the union rect (0..12)")
    XCTAssertEqual(merged?.bounds.cgRect, CGRect(x: 0, y: 0, width: 12, height: 12))
  }

  /// Different labels, different states, and empty labels must stay separate.
  func testDoesNotMergeDistinctGroups() {
    let sameLabelDiffState = hl(id: "e", page: 0, rect: CGRect(x: 0, y: 0, width: 10, height: 10),
                               state: .focused, label: "Name")
    let diffLabel = hl(id: "d", page: 0, rect: CGRect(x: 0, y: 0, width: 10, height: 10),
                      state: .candidateUnfilled, label: "Other")
    let emptyLabel = hl(id: "f", page: 0, rect: CGRect(x: 0, y: 0, width: 10, height: 10),
                       state: .candidateUnfilled, label: nil)
    let unfilledName = hl(id: "a", page: 0, rect: CGRect(x: 0, y: 0, width: 10, height: 10),
                          state: .candidateUnfilled, label: "Name")

    let result = mergeOverlappingFillHighlights([unfilledName, sameLabelDiffState, diffLabel, emptyLabel])
    XCTAssertEqual(result.count, 4, "nothing should merge across label/state/empty boundaries")
  }
}
