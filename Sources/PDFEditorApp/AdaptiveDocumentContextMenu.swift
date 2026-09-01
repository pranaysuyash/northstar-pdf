import AppKit
import PDFEditorCore
import PDFEditorRecovery
import SwiftUI

/// The document canvas presentation of the Core adaptive command policy.
///
/// This view owns no document mutation policy. It converts a selected command
/// into an existing AppModel or annotation-store action, while the model keeps
/// the final permission and ledger checks authoritative.
struct AdaptiveDocumentContextMenu: View {
  private let commandHistory = AdaptiveCommandHistory.shared
  let model: AppModel
  let annotationStore: AnnotationStore?
  let selectedAnnotation: AnnotationMark?
  let selectedText: String
  let selectedBounds: PDFRect
  let selectedPageIndex: Int
  @Binding var isCommandPalettePresented: Bool
  @Binding var isSearchExpanded: Bool
  @FocusState.Binding var isSearchFieldFocused: Bool

  private var target: AdaptiveInteractionTarget {
    if selectedAnnotation != nil { return .annotation }
    return selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? .documentScrolling
      : .textSelection
  }

  private var policyInput: AdaptiveCommandPolicyInput {
    AdaptiveCommandContext.input(model: model, intent: intentLens, target: target)
  }

  private var intentLens: AdaptiveIntentLens {
    switch model.editorMode {
    case .read:
      return .read
    case .fill, .sign:
      return .complete
    case .edit:
      return .review
    }
  }

  var body: some View {
    let result = AdaptiveCommandPolicy.standard.resolve(policyInput)

    ForEach(result.primaryCommands, id: \.id) { command in
      commandButton(command)
    }

    if !result.overflowCommands.isEmpty {
      Divider()
      Menu("More Actions", systemImage: "ellipsis.circle") {
        ForEach(result.overflowCommands, id: \.id) { command in
          commandButton(command)
        }
      }
    }
  }

  @ViewBuilder
  private func commandButton(_ command: AdaptiveCommand) -> some View {
    Button {
      if perform(command.id) {
        commandHistory.record(command.id)
      }
    } label: {
      Label(command.title, systemImage: symbolName(for: command.id))
    }
  }

  @discardableResult
  private func perform(_ command: AdaptiveCommandID) -> Bool {
    switch command {
    case .search:
      model.routeSearchCommand()
      isSearchExpanded = true
      isSearchFieldFocused = true
      return true
    case .commandPalette:
      isCommandPalettePresented = true
      return true
    case .continueReading:
      model.readingMode = .study
      return true
    case .understandDocument:
      model.readingMode = .study
      return true
    case .fillForm:
      model.setEditorMode(.fill)
      return true
    case .editText:
      guard let selectedText = nonEmptySelectedText else { return false }
      model.beginDirectTextPlacement(pageIndex: selectedPageIndex, point: selectedBounds.center)
      model.manualTextDraft = selectedText
      return true
    case .annotate:
      guard let annotationStore, let selectedText = nonEmptySelectedText else { return false }
      annotationStore.addMark(
        AnnotationMark(
          type: .highlight,
          pageIndex: selectedPageIndex,
          bounds: selectedBounds,
          selectedText: selectedText,
          note: "",
          color: .yellow
        )
      )
      return true
    case .extractText:
      guard let selectedText = nonEmptySelectedText else { return false }
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(selectedText, forType: .string)
      return true
    case .export:
      model.presentExportReview()
      return true
    case .undo:
      model.undo()
      return true
    case .redo:
      model.redo()
      return true
    case .organizePages, .editImage:
      // Page organization has a concrete page-rail surface. Image/object
      // targeting still needs a native detector and an executable editor.
      return false
    case .inspectAnnotation:
      guard let selectedAnnotation else { return false }
      model.selectedAnnotationID = selectedAnnotation.id
      model.statusMessage = "Selected \(selectedAnnotation.type.displayName.lowercased()) on page \(selectedAnnotation.pageIndex + 1)."
      return true
    }
  }

  private var nonEmptySelectedText: String? {
    let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : selectedText
  }

  private func symbolName(for command: AdaptiveCommandID) -> String {
    switch command {
    case .search: return "magnifyingglass"
    case .commandPalette: return "command"
    case .continueReading: return "book"
    case .understandDocument: return "text.magnifyingglass"
    case .fillForm: return "character.cursor.ibeam"
    case .editText: return "pencil"
    case .annotate: return "highlighter"
    case .extractText: return "doc.on.clipboard"
    case .export: return "square.and.arrow.up"
    case .undo: return "arrow.uturn.backward"
    case .redo: return "arrow.uturn.forward"
    case .organizePages: return "rectangle.split.3x1"
    case .inspectAnnotation: return "text.bubble"
    case .editImage: return "photo"
    }
  }
}

private extension PDFRect {
  var center: CGPoint {
    CGPoint(x: x + width / 2, y: y + height / 2)
  }
}
