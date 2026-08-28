import Foundation
import Testing
@testable import PDFEditorCore

@Suite
struct ZZDiagTests {
  @Test func printEncodings() throws {
    let legacyJSON = """
    {"selectedPageIndex": 2, "viewMode": "continuous", "scaleMode": "fitWidth", "pageRotation": 90, "selectedSearchMatchIndex": 1}
    """
    let decoded = try JSONDecoder().decode(DocumentSessionViewState.self, from: Data(legacyJSON.utf8))
    let fresh = DocumentSessionViewState(selectedPageIndex: 2, viewMode: .continuous, scaleMode: .fitWidth, pageRotation: 90, selectedSearchMatchIndex: 1)
    let a = try JSONEncoder().encode(decoded)
    let b = try JSONEncoder().encode(fresh)
    print("DIAG equal:", decoded == fresh)
    print("DIAG bytesEqual:", a == b)
    print("DIAG A:", String(decoding: a, as: UTF8.self))
    print("DIAG B:", String(decoding: b, as: UTF8.self))
  }
}
