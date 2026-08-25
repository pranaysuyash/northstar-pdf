import SwiftUI
import AppKit

private struct PDFEditorModelFocusedValueKey: FocusedValueKey {
    typealias Value = AppModel
}

extension FocusedValues {
    var pdfEditorModel: AppModel? {
        get { self[PDFEditorModelFocusedValueKey.self] }
        set { self[PDFEditorModelFocusedValueKey.self] = newValue }
    }
}

private struct PDFEditorSearchFocusEventKey: FocusedValueKey {
    typealias Value = Binding<Int>
}

extension FocusedValues {
    var pdfEditorSearchFocusEvent: Binding<Int>? {
        get { self[PDFEditorSearchFocusEventKey.self] }
        set { self[PDFEditorSearchFocusEventKey.self] = newValue }
    }
}

@MainActor
final class PDFEditorWindowController {
    weak var window: NSWindow?

    func close() {
        window?.performClose(nil)
    }
}

private struct PDFEditorWindowAccessor: NSViewRepresentable {
    let controller: PDFEditorWindowController

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    Task { @MainActor [weak controller, weak view] in
      controller?.window = view?.window
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    Task { @MainActor [weak controller, weak nsView] in
      controller?.window = nsView?.window
    }
  }
}

private struct PDFEditorWindow: View {
    @State private var model = AppModel()
    @State private var searchFocusEvent = 0
    @State private var windowController = PDFEditorWindowController()

    var body: some View {
        ZStack {
            ContentView(model: model, searchFocusEvent: $searchFocusEvent)
                .frame(minWidth: 1_080, minHeight: 700)
            PDFEditorWindowAccessor(controller: windowController)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
            .focusedSceneValue(\.pdfEditorModel, model)
            .focusedSceneValue(\.pdfEditorSearchFocusEvent, $searchFocusEvent)
            .focusedSceneValue(\.pdfEditorWindowController, windowController)
    }
}

@main
struct PDFEditorApp: App {
    init() {
        // A raw executable launched from a terminal still needs normal app
        // activation so the native preview is immediately testable.
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSRunningApplication(processIdentifier: ProcessInfo.processInfo.processIdentifier)?
                .activate(options: [.activateAllWindows])
        }
    }

    var body: some Scene {
        WindowGroup("PDF Editor", id: "pdf-editor") {
            PDFEditorWindow()
        }
        .commands {
            AppCommands()
        }
        Settings {
            SettingsView()
        }
    }
}
