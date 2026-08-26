import AppKit

/// Host view for the on-canvas inline text editor. Lives in its own module so
/// the Enter-to-commit wiring can be unit-tested (the original bug was that
/// `textField.delegate` was never assigned, so `control(_:textView:doCommandBy:)`
/// never fired and pressing Enter did nothing).
public final class InlineEditorTextFieldHost: NSView, NSTextFieldDelegate {
  public let textField: NSTextField
  /// Names the region being filled so the user never edits an anonymous box.
  public let nameLabel: NSTextField
  public var onCommit: (String) -> Void
  public var onDismiss: () -> Void

  public init(onCommit: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
    self.onCommit = onCommit
    self.onDismiss = onDismiss
    self.textField = NSTextField()
    self.nameLabel = NSTextField(labelWithString: "")
    super.init(frame: .zero)

    wantsLayer = true
    layer?.cornerRadius = 4
    layer?.masksToBounds = true
    layer?.borderColor = NSColor.controlAccentColor.cgColor
    layer?.borderWidth = 1.5
    layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

    nameLabel.font = NSFont.systemFont(ofSize: 9, weight: .semibold)
    nameLabel.textColor = .secondaryLabelColor
    nameLabel.lineBreakMode = .byTruncatingTail
    addSubview(nameLabel)

    textField.isBordered = false
    textField.drawsBackground = false
    textField.font = NSFont.preferredFont(forTextStyle: .callout)
    textField.focusRingType = .none
    textField.autoresizingMask = [.width]
    textField.delegate = self
    addSubview(textField)
    layoutEditorSubviews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func layoutEditorSubviews() {
    let showLabel = !nameLabel.stringValue.isEmpty
    let labelHeight: CGFloat = showLabel ? 12 : 0
    nameLabel.frame = CGRect(
      x: 6, y: bounds.height - labelHeight - 2,
      width: max(0, bounds.width - 12), height: labelHeight)
    nameLabel.isHidden = !showLabel
    textField.frame = CGRect(
      x: 6, y: 3,
      width: max(0, bounds.width - 12),
      height: max(14, bounds.height - labelHeight - 8))
  }

  public func setLabel(_ label: String) {
    guard nameLabel.stringValue != label else { return }
    nameLabel.stringValue = label
    textField.placeholderString = label
    layoutEditorSubviews()
  }

  public override func resizeSubviews(withOldSize oldSize: NSSize) {
    super.resizeSubviews(withOldSize: oldSize)
    layoutEditorSubviews()
  }

  public func updateText(_ text: String) {
    if textField.stringValue != text {
      textField.stringValue = text
    }
  }

  public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      onCommit(textField.stringValue)
      return true
    } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
      onDismiss()
      return true
    }
    return false
  }

  public func controlTextDidEndEditing(_ obj: Notification) {
    if let field = obj.object as? NSTextField {
      onCommit(field.stringValue)
    }
  }
}
