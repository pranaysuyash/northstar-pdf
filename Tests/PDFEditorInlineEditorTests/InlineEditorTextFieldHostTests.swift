import XCTest
import AppKit
import PDFEditorInlineEditor

@MainActor
final class InlineEditorTextFieldHostTests: XCTestCase {

  /// S2 regression guard for the "Enter does nothing" bug. The text field's
  /// delegate must be the host, otherwise AppKit never routes `insertNewline`
  /// to `control(_:textView:doCommandBy:)` and pressing Enter silently fails
  /// to fill the field. This test fails when `textField.delegate = self` is
  /// absent and passes once it is set.
  func testEnterCommitsThroughDelegateWiring() {
    var committed: String?
    let host = InlineEditorTextFieldHost(
      onCommit: { committed = $0 },
      onDismiss: {}
    )

    guard let delegate = host.textField.delegate else {
      XCTFail("textField.delegate must be the host so Enter routes to it (Enter-fix regression)")
      return
    }
    XCTAssertTrue(delegate === host, "textField.delegate should be the host itself")

    host.textField.stringValue = "Pranay"
    let handled = delegate.control?(
      host.textField,
      textView: NSTextView(),
      doCommandBy: #selector(NSResponder.insertNewline(_:))
    ) ?? false

    XCTAssertTrue(handled, "insertNewline must be handled and trigger commit")
    XCTAssertEqual(committed, "Pranay", "Enter should commit the typed value")
  }

  func testCancelDismisses() {
    var dismissed = false
    let host = InlineEditorTextFieldHost(
      onCommit: { _ in },
      onDismiss: { dismissed = true }
    )
    let handled = host.textField.delegate?.control?(
      host.textField,
      textView: NSTextView(),
      doCommandBy: #selector(NSResponder.cancelOperation(_:))
    ) ?? false
    XCTAssertTrue(handled)
    XCTAssertTrue(dismissed)
  }
}
