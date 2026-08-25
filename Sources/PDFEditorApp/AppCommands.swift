import AppKit
import SwiftUI

private struct PDFEditorWindowControllerFocusedValueKey: FocusedValueKey {
    typealias Value = PDFEditorWindowController
}

extension FocusedValues {
    var pdfEditorWindowController: PDFEditorWindowController? {
        get { self[PDFEditorWindowControllerFocusedValueKey.self] }
        set { self[PDFEditorWindowControllerFocusedValueKey.self] = newValue }
    }
}

/// The command vocabulary owned by the native Mac shell.
///
/// The command layer resolves the model for the focused scene. It routes
/// document and reader state through typed AppModel actions so the menu does
/// not become a second authority for PDFKit or document state.
@MainActor
private enum PDFEditorCommand: Hashable {
    case newDocument
    case openDocument
    case closeWindow
    case exportCopy
    case undo
    case redo
    case find
    case nextSearch
    case previousSearch
    case firstPage
    case previousPage
    case nextPage
    case lastPage
    case zoomIn
    case zoomOut
    case actualSize
    case fitPage
    case fitWidth
    case singlePage
    case continuous
    case twoUp
}

@MainActor
private struct PDFEditorCommandRouter {
    let model: AppModel?
    let windowController: PDFEditorWindowController?
    let openWindow: OpenWindowAction

    func isEnabled(_ command: PDFEditorCommand) -> Bool {
        switch command {
        case .newDocument:
            return true
        case .openDocument:
            return model != nil
        case .closeWindow:
            return model != nil && windowController?.window != nil
        case .exportCopy, .undo, .redo:
            guard let model else { return false }
            switch command {
            case .exportCopy:
                guard model.canExportCurrentOperations,
                      let permissions = model.inspection?.permissions
                else { return false }
                return permissions.canModify || permissions.canAddAnnotations
            case .undo:
                return model.canUndo
            case .redo:
                return model.canRedo
            default:
                return false
            }
        case .find:
            guard let model else { return false }
            return model.liveDocument != nil && (model.inspection?.permissions.canCopy ?? false)
        case .nextSearch, .previousSearch:
            guard let model else { return false }
            return !model.searchMatches.isEmpty
                && (model.inspection?.permissions.canCopy ?? false)
        case .firstPage, .previousPage, .nextPage, .lastPage:
            return (model?.currentPageCount ?? 0) > 0
        case .zoomIn, .zoomOut, .actualSize, .fitPage, .fitWidth,
             .singlePage, .continuous, .twoUp:
            return model?.liveDocument != nil
        }
    }

    func perform(_ command: PDFEditorCommand) {
        switch command {
        case .newDocument:
            if let model {
                withNewWindowConfirmation(model: model) {
                    openWindow(id: "pdf-editor")
                }
            } else {
                openWindow(id: "pdf-editor")
            }
        case .openDocument:
            guard let model else { return }
            withOpenConfirmation(model: model) {
                model.isImporterPresented = true
            }
        case .closeWindow:
            guard let model else { return }
            guard let windowController else { return }
            withCloseConfirmation(model: model, windowController: windowController)
        case .exportCopy:
            model?.export()
        case .undo:
            model?.undo()
        case .redo:
            model?.redo()
        case .find:
            model?.routeSearchCommand()
        case .nextSearch:
            model?.routeNextSearchCommand()
        case .previousSearch:
            model?.routePreviousSearchCommand()
        case .firstPage:
            model?.goToFirstPage()
        case .previousPage:
            model?.goToPreviousPage()
        case .nextPage:
            model?.goToNextPage()
        case .lastPage:
            model?.goToLastPage()
        case .zoomIn:
            if let model {
                model.setScaleMode(.zoom)
                model.setZoom(model.readerZoom + 0.1)
            }
        case .zoomOut:
            if let model {
                model.setScaleMode(.zoom)
                model.setZoom(model.readerZoom - 0.1)
            }
        case .actualSize:
            model?.setActualSize()
        case .fitPage:
            model?.setFitPage()
        case .fitWidth:
            model?.setFitWidth()
        case .singlePage:
            model?.setReaderViewMode(.singlePage)
        case .continuous:
            model?.setReaderViewMode(.continuous)
        case .twoUp:
            model?.setReaderViewMode(.twoPage)
        }
    }

    private func withNewWindowConfirmation(model: AppModel, proceed: () -> Void) {
        guard model.isDirty else {
            proceed()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "This document has unexported changes."
        alert.informativeText = "New Document opens an independent window and keeps this document and its recoverable work open. Export Copy... remains available if you want a separate edited PDF."
        alert.addButton(withTitle: "Open New Window")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        proceed()
    }

    private func withOpenConfirmation(model: AppModel, proceed: () -> Void) {
        guard model.isDirty else {
            proceed()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "This document has unexported changes."
        alert.informativeText = "Choose Continue to Open to replace this window only after the selected PDF is admitted successfully. Export Copy... creates a separate edited PDF and never overwrites the source."
        alert.addButton(withTitle: "Continue to Open")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        proceed()
    }

    private func withCloseConfirmation(
        model: AppModel,
        windowController: PDFEditorWindowController
    ) {
        guard model.isDirty else {
            windowController.close()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "This document has unexported changes."
        alert.informativeText = "Choose whether to keep a recoverable session for this work or discard the recovery session. Export Copy... creates a separate edited PDF and never overwrites the source."
        alert.addButton(withTitle: "Close and Keep Recovery")
        alert.addButton(withTitle: "Close and Discard Recovery")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            windowController.close()
        case .alertSecondButtonReturn:
            // The dedicated recovery discard method is private in AppModel.
            // resetDocument() is the existing public model-owned transition
            // that clears the active document and its recovery pair.
            model.resetDocument()
            windowController.close()
        default:
            break
        }
    }
}

@MainActor
struct AppCommands: Commands {
    @FocusedValue(\.pdfEditorModel) private var model
    @FocusedValue(\.pdfEditorSearchFocusEvent) private var searchFocusEvent
    @FocusedValue(\.pdfEditorWindowController) private var windowController
    @Environment(\.openWindow) private var openWindow

    private var router: PDFEditorCommandRouter {
        PDFEditorCommandRouter(
            model: model,
            windowController: windowController,
            openWindow: openWindow
        )
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Document") {
                router.perform(.newDocument)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open...") {
                router.perform(.openDocument)
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(!router.isEnabled(.openDocument))
        }

        CommandGroup(after: .newItem) {
            Button("Close Window") {
                router.perform(.closeWindow)
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(!router.isEnabled(.closeWindow))
        }

        CommandGroup(after: .saveItem) {
            Button("Export Copy...") {
                router.perform(.exportCopy)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!router.isEnabled(.exportCopy))
            .help(
                router.isEnabled(.exportCopy)
                    ? "Creates a separate edited PDF without overwriting the source."
                    : "Unavailable until there are authorized, validated edits to export."
            )
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                router.perform(.undo)
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!router.isEnabled(.undo))

            Button("Redo") {
                router.perform(.redo)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!router.isEnabled(.redo))
        }

        CommandGroup(after: .textEditing) {
            Divider()

            Button("Find...") {
                router.perform(.find)
                searchFocusEvent?.wrappedValue += 1
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(!router.isEnabled(.find))

            Button("Find Next") {
                router.perform(.nextSearch)
            }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(!router.isEnabled(.nextSearch))

            Button("Find Previous") {
                router.perform(.previousSearch)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(!router.isEnabled(.previousSearch))

            Divider()

            Button("First Page") {
                router.perform(.firstPage)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            .disabled(!router.isEnabled(.firstPage))

            Button("Previous Page") {
                router.perform(.previousPage)
            }
            .keyboardShortcut(.pageUp, modifiers: .command)
            .disabled(!router.isEnabled(.previousPage))

            Button("Next Page") {
                router.perform(.nextPage)
            }
            .keyboardShortcut(.pageDown, modifiers: .command)
            .disabled(!router.isEnabled(.nextPage))

            Button("Last Page") {
                router.perform(.lastPage)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            .disabled(!router.isEnabled(.lastPage))
        }

        CommandGroup(after: .toolbar) {
            Menu("Zoom") {
                Button("Zoom In") {
                    router.perform(.zoomIn)
                }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!router.isEnabled(.zoomIn))

                Button("Zoom Out") {
                    router.perform(.zoomOut)
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!router.isEnabled(.zoomOut))

                Divider()

                Button("Actual Size") {
                    router.perform(.actualSize)
                }
                .disabled(!router.isEnabled(.actualSize))

                Button("Fit Page") {
                    router.perform(.fitPage)
                }
                .disabled(!router.isEnabled(.fitPage))

                Button("Fit Width") {
                    router.perform(.fitWidth)
                }
                .disabled(!router.isEnabled(.fitWidth))
            }

            Menu("Reader Mode") {
                Button("Single Page") {
                    router.perform(.singlePage)
                }
                .disabled(!router.isEnabled(.singlePage))

                Button("Continuous") {
                    router.perform(.continuous)
                }
                .disabled(!router.isEnabled(.continuous))

                Button("Two Pages") {
                    router.perform(.twoUp)
                }
                .disabled(!router.isEnabled(.twoUp))
            }
        }

        CommandGroup(after: .windowArrangement) {
            Button("Bring All to Front") {
                NSApp.arrangeInFront(nil)
            }
        }

        CommandGroup(replacing: .appSettings) {
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
