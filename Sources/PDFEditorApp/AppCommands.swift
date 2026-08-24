import AppKit
import SwiftUI

/// The command vocabulary owned by the native Mac shell.
///
/// Commands that mutate document state must route through AppModel. Commands
/// that operate on the active PDFView use the responder chain, which keeps the
/// scene shell independent of the private PDFKitView implementation.
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

/// Typed routing seam for commands that are not currently represented by an
/// AppModel method. Keeping this seam here prevents menu code from inventing a
/// second source of truth for page, scale, or reader state.
@MainActor
private struct PDFEditorCommandRouter {
    let model: AppModel

    func isEnabled(_ command: PDFEditorCommand) -> Bool {
        switch command {
        case .newDocument, .openDocument:
            return true
        case .closeWindow:
            return NSApp.keyWindow != nil
        case .exportCopy, .find, .firstPage, .previousPage, .nextPage, .lastPage,
             .zoomIn, .zoomOut, .actualSize, .fitPage, .fitWidth:
            return model.liveDocument != nil
        case .undo:
            return !model.operations.isEmpty
        case .redo:
            return false
        case .singlePage, .continuous, .twoUp:
            // AppModel exposes the reader state for view bindings, but does
            // not yet expose typed command methods. Keep these visible for
            // discoverability and disabled until the model owns the route.
            return false
        }
    }

    func perform(_ command: PDFEditorCommand) {
        switch command {
        case .newDocument:
            model.resetDocument()
        case .openDocument:
            model.isImporterPresented = true
        case .closeWindow:
            NSApp.keyWindow?.performClose(nil)
        case .exportCopy:
            model.export()
        case .undo:
            model.undoLastEdit()
        case .redo:
            break
        case .find:
            sendResponderAction("performFindPanelAction:")
        case .firstPage:
            sendResponderAction("goToFirstPage:")
        case .previousPage:
            sendResponderAction("goToPreviousPage:")
        case .nextPage:
            sendResponderAction("goToNextPage:")
        case .lastPage:
            sendResponderAction("goToLastPage:")
        case .zoomIn:
            sendResponderAction("zoomIn:")
        case .zoomOut:
            sendResponderAction("zoomOut:")
        case .actualSize, .fitPage, .fitWidth:
            // These require a typed scale-policy method on AppModel. The
            // existing view binding is intentionally not mutated here.
            break
        case .singlePage, .continuous, .twoUp:
            // See isEnabled(_:). These are placeholders for the explicit
            // AppModel command seam described above.
            break
        }
    }

    private func sendResponderAction(_ selectorName: String) {
        NSApp.sendAction(Selector(selectorName), to: nil, from: nil)
    }
}

@MainActor
struct AppCommands: Commands {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    private var router: PDFEditorCommandRouter {
        PDFEditorCommandRouter(model: model)
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
