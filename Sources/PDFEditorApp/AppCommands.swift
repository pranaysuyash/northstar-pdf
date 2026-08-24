import AppKit
import SwiftUI

/// The command vocabulary owned by the native Mac shell.
///
/// The command layer resolves the model for the focused scene. It does not
/// mutate PDFKit through the responder chain because PDFKit navigation and
/// zoom are not yet two-way synchronized with AppModel.
@MainActor
private enum PDFEditorCommand: Hashable {
    case newDocument
    case openDocument
    case closeWindow
    case exportCopy
    case undo
    case redo
    case find
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
    let openWindow: OpenWindowAction

    func isEnabled(_ command: PDFEditorCommand) -> Bool {
        switch command {
        case .newDocument:
            return true
        case .openDocument, .closeWindow:
            return model != nil
        case .exportCopy, .undo, .redo:
            guard let model else { return false }
            switch command {
            case .exportCopy:
                return model.canExportCurrentOperations
            case .undo:
                return !model.operations.isEmpty
            case .redo:
                return model.canRedo
            default:
                return false
            }
        case .find, .firstPage, .previousPage, .nextPage, .lastPage,
             .zoomIn, .zoomOut, .actualSize, .fitPage, .fitWidth,
             .singlePage, .continuous, .twoUp:
            // Keep the menu vocabulary discoverable, but do not expose a
            // second state authority through NSApp.sendAction. These become
            // enabled only after typed AppModel routes exist.
            return false
        }
    }

    func perform(_ command: PDFEditorCommand) {
        switch command {
        case .newDocument:
            // New is a new scene, so a dirty focused document is not touched.
            openWindow(id: "pdf-editor")
        case .openDocument:
            guard let model else { return }
            withDirtyConfirmation(model: model, action: "open another document") {
                model.resetDocument()
                model.isImporterPresented = true
            }
        case .closeWindow:
            guard let model else { return }
            withDirtyConfirmation(model: model, action: "close this window") {
                NSApp.keyWindow?.performClose(nil)
            }
        case .exportCopy:
            model?.export()
        case .undo:
            model?.undoLastEdit()
        case .redo:
            model?.redoLastEdit()
        case .find, .firstPage, .previousPage, .nextPage, .lastPage,
             .zoomIn, .zoomOut, .actualSize, .fitPage, .fitWidth,
             .singlePage, .continuous, .twoUp:
            break
        }
    }

    private func withDirtyConfirmation(model: AppModel, action: String, proceed: () -> Void) {
        guard !model.operations.isEmpty else {
            proceed()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "This document has unexported changes."
        alert.informativeText = "Export a copy before you (action), or choose Cancel to keep working."
        alert.addButton(withTitle: action == "close this window" ? "Close Without Exporting" : "Discard and Continue")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        proceed()
    }
}

@MainActor
struct AppCommands: Commands {
    @FocusedValue(\.pdfEditorModel) private var model
    @Environment(\.openWindow) private var openWindow

    private var router: PDFEditorCommandRouter {
        PDFEditorCommandRouter(model: model, openWindow: openWindow)
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
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(!router.isEnabled(.find))

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
