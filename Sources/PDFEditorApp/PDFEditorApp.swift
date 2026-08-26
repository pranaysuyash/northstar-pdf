import SwiftUI
import AppKit
import PDFEditorCore
import PDFEditorRecovery

@MainActor
private enum PDFEditorNativeTerminationProbe {
    private static var prepared = false

    private static var environment: [String: String] {
        ProcessInfo.processInfo.environment
    }

    static var isEnabled: Bool {
        environment["PDF_EDITOR_NATIVE_TERMINATION_PROBE"] == "1"
    }

    static func prepare(model: AppModel) {
        guard isEnabled, !prepared,
              let sourcePath = environment["PDF_EDITOR_NATIVE_TERMINATION_SOURCE"] else { return }
        prepared = true

        let sourceURL = URL(fileURLWithPath: sourcePath)
        if model.inspection == nil {
            model.open(url: sourceURL)
        }
        guard let inspection = model.inspection,
              let page = inspection.pages.first,
              let sourceDigest = model.inspection?.source.sha256,
              let sessionID = model.sessionID else {
            write("prepare-failed", to: "PDF_EDITOR_NATIVE_TERMINATION_RESULT")
            return
        }

        let bounds = PDFRect(
            x: page.bounds.x + 24,
            y: page.bounds.y + 24,
            width: min(160, max(48, page.bounds.width - 48)),
            height: 20
        )
        model.operations.append(EditOperation(
            pageIndex: page.pageIndex,
            targetID: "native-termination-probe",
            kind: .overlayText,
            value: "native termination probe",
            bounds: bounds,
            sessionID: sessionID,
            sourceDigest: sourceDigest,
            coordinate: PDFPageRegion(pageIndex: page.pageIndex, rect: bounds)
        ))
        write("ready", to: "PDF_EDITOR_NATIVE_TERMINATION_READY")
    }

    static func record(flushed: Bool) {
        guard isEnabled else { return }
        write(flushed ? "flushed" : "failed", to: "PDF_EDITOR_NATIVE_TERMINATION_RESULT")
    }

    private static func write(_ value: String, to environmentKey: String) {
        guard let path = environment[environmentKey] else { return }
        try? Data(value.utf8).write(to: URL(fileURLWithPath: path), options: [.atomic])
    }
}

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
    private static let liveControllers = NSHashTable<PDFEditorWindowController>.weakObjects()

    weak var window: NSWindow?
    var model: AppModel?

    func register() {
        Self.liveControllers.add(self)
    }

    static var focusedController: PDFEditorWindowController? {
        liveControllers.allObjects.first(where: { $0.window?.isKeyWindow == true })
            ?? liveControllers.allObjects.first
    }

    static func flushRecoveryForTermination() -> Bool {
        liveControllers.allObjects.allSatisfy { controller in
            controller.model?.flushRecoveryForTermination() ?? true
        }
    }

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
                // RG-059: the minimum window size stays usable at 200% zoom
                // and on narrow displays; panes adapt below these bounds.
                .frame(minWidth: 720, minHeight: 480)
            PDFEditorWindowAccessor(controller: windowController)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
            .focusedSceneValue(\.pdfEditorModel, model)
            .focusedSceneValue(\.pdfEditorSearchFocusEvent, $searchFocusEvent)
            .focusedSceneValue(\.pdfEditorWindowController, windowController)
            .onAppear {
                windowController.model = model
                windowController.register()
                PDFEditorNativeTerminationProbe.prepare(model: model)
            }
    }
}

@MainActor
final class PDFEditorAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let flushed = PDFEditorWindowController.flushRecoveryForTermination()
        PDFEditorNativeTerminationProbe.record(flushed: flushed)
        return flushed
            ? .terminateNow
            : .terminateCancel
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
              let controller = PDFEditorWindowController.focusedController,
              let model = controller.model
        else { return }
        model.open(url: url)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}

@main
struct PDFEditorApp: App {
    @NSApplicationDelegateAdaptor(PDFEditorAppDelegate.self) private var appDelegate

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
        .defaultSize(width: 1_280, height: 820)
        .commands {
            AppCommands()
        }
        Settings {
            SettingsView()
        }
    }
}
