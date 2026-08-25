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
        close(afterConfirmed: {})
    }

    /// Requests AppKit's normal close behavior and runs `completion` only
    /// after the target window has actually emitted `didClose`.
    ///
    /// This is intentionally a post-close transaction boundary. A close can
    /// be rejected by AppKit or a window delegate, so callers must not clear
    /// model state merely because `performClose` was requested.
    func close(afterConfirmed completion: @escaping @MainActor () -> Void) {
        guard let window else { return }

        pendingCloseObserver.map(NotificationCenter.default.removeObserver)
        pendingCloseObserver = nil
        pendingCloseCompletion = completion
        let confirmPendingClose: @MainActor @Sendable () -> Void = { [weak self] in
            self?.confirmPendingClose()
        }

        pendingCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { @Sendable _ in
            Task { @MainActor in
                confirmPendingClose()
            }
        }

        window.performClose(nil)

        // `performClose` is synchronous on AppKit's main thread. If the
        // target is still visible, AppKit rejected the request; remove the
        // pending action so a later unrelated close cannot discard recovery.
        if window.isVisible {
            pendingCloseObserver.map(NotificationCenter.default.removeObserver)
            pendingCloseObserver = nil
            pendingCloseCompletion = nil
        }
    }

    private var pendingCloseObserver: NSObjectProtocol?
    private var pendingCloseCompletion: (@MainActor () -> Void)?

    private func confirmPendingClose() {
        guard let completion = pendingCloseCompletion else { return }
        pendingCloseObserver.map(NotificationCenter.default.removeObserver)
        pendingCloseObserver = nil
        pendingCloseCompletion = nil
        completion()
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
