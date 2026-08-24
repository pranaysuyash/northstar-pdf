import SwiftUI
import AppKit

@main
struct PDFEditorApp: App {
    @State private var model = AppModel()

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
        WindowGroup("PDF Editor") {
            ContentView(model: model)
                .frame(minWidth: 1_080, minHeight: 700)
        }
        .commands {
            AppCommands(model: model)
        }
        Settings {
            SettingsView()
        }
    }
}
