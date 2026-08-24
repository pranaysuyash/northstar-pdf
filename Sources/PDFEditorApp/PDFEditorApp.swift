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

private struct PDFEditorWindow: View {
    @State private var model = AppModel()

    var body: some View {
        ContentView(model: model)
            .frame(minWidth: 1_080, minHeight: 700)
            .focusedSceneValue(\.pdfEditorModel, model)
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
