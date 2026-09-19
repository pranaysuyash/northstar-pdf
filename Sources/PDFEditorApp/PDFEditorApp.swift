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

@MainActor
private enum PDFEditorNativeWindowProbe {
    private static var scheduled = false

    private static var environment: [String: String] {
        ProcessInfo.processInfo.environment
    }

    static var isEnabled: Bool {
        environment["PDF_EDITOR_NATIVE_WINDOW_PROBE"] == "1"
    }

    static func recordProcessStarted() {
        guard isEnabled else { return }
        write("process-started")
    }

    /// Observes the AppKit window after SwiftUI has had a chance to attach the
    /// WindowGroup scene. This is diagnostic evidence, not a product behavior.
    static func schedule() {
      guard isEnabled, !scheduled else { return }
      scheduled = true

        let delays: [TimeInterval] = [0, 0.1, 0.5, 1.0, 2.0, 4.0]
        for (index, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let window = NSApplication.shared.windows.first(where: { $0.isVisible })
                guard let window else {
                    if index == delays.count - 1 {
                        write("window-not-observed")
                    }
                    return
                }

                guard window.isVisible else {
                    if index == delays.count - 1 {
                        write("window-attached-not-visible")
                    }
                    return
                }

                write("window-visible:\(Int(window.frame.width))x\(Int(window.frame.height))")
            }
        }
    }

    private static func write(_ value: String) {
        guard let path = environment["PDF_EDITOR_NATIVE_WINDOW_RESULT"] else { return }
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

    /// Every live window controller, for external-open routing decisions.
    static var existingControllers: [PDFEditorWindowController] {
        liveControllers.allObjects
    }

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
                PDFEditorNativeWindowProbe.schedule()
                if ProcessInfo.processInfo.environment["PDF_EDITOR_INITIAL_VAULT"] == "1" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        model.isSecurityVaultPresented = true
                    }
                }
                if model.inspection == nil {
                    if let envPath = ProcessInfo.processInfo.environment["PDF_EDITOR_OPEN_SOURCE"],
                       FileManager.default.fileExists(atPath: envPath) {
                        model.open(url: URL(fileURLWithPath: envPath))
                    } else if let argPath = CommandLine.arguments.dropFirst().first(where: { $0.lowercased().hasSuffix(".pdf") && FileManager.default.fileExists(atPath: $0) }) {
                        model.open(url: URL(fileURLWithPath: argPath))
                    }
                }
            }
    }
}

@MainActor
final class PDFEditorAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launch-services delivers command-line document arguments only to
        // bundled apps; a raw SwiftPM binary must drain argv itself or the
        // buyer path "open this PDF with Northstar" never fires (sim
        // finding PL-I30 GAP-A).
        PDFEditorExternalOpenRouter.drainCommandLineArguments()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let flushed = PDFEditorWindowController.flushRecoveryForTermination()
        PDFEditorNativeTerminationProbe.record(flushed: flushed)
        return flushed
            ? .terminateNow
            : .terminateCancel
    }

    // Launch-time argv on a BARE executable is a SwiftUI/AppKit suppression
    // (no window is ever created; unaffected by this delegate — verified
    // empirically 2026-09-09/11, PL-I30). It is a developer-only artifact:
    // buyers launch the BUNDLED app, where Launch Services delivers real
    // `odoc` events at runtime, handled below. Developers use
    // PDF_EDITOR_OPEN_SOURCE (in-window hook) instead of argv.
    //
    // Runtime Open-With (app already running) arrives here — verified path.
    func application(_ application: NSApplication, open urls: [URL]) {
        PDFEditorExternalOpenRouter.shared.enqueue(urls.filter { $0.isFileURL })
    }
}

/// Single deterministic router for every externally requested document open
/// (Finder "Open With", double-click, `open` with arguments, argv).
///
/// Before this router the open paths diverged: argv files were dropped, and
/// Apple-Event opens raced SwiftUI's own WindowGroup handling, producing a
/// duplicate start-surface window whose focus left the menu bar validating
/// against an empty model (sim finding PL-I30 GAP-B). Routing all opens
/// through one queue, opening into the key window, and closing any *other*
/// visible window that is still a clean scratch surface makes the outcome
/// deterministic: one window, showing the requested document.
@MainActor
final class PDFEditorExternalOpenRouter {
    static let shared = PDFEditorExternalOpenRouter()

    private var pendingURLs: [URL] = []
    private var drainScheduled = false
    private var drainAttempts = 0

    func enqueue(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        pendingURLs.append(contentsOf: urls)
        scheduleDrain()
    }

    /// Process document paths passed on the command line at launch.
    static func drainCommandLineArguments() {
        let urls = CommandLine.arguments.dropFirst()
            .filter { $0.lowercased().hasSuffix(".pdf") }
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { return }
        MainActor.assumeIsolated {
            Self.shared.enqueue(urls)
        }
    }

    private func scheduleDrain() {
        guard !drainScheduled else { return }
        drainScheduled = true
        drainAttempts = 0
        drain()
    }

    /// The first window mounts asynchronously after launch, so an argv open
    /// can arrive before any controller exists. Retry briefly; give up
    /// without data loss — the URLs stay queued for a later enqueue.
    private func drain() {
        guard !pendingURLs.isEmpty else {
            drainScheduled = false
            return
        }
        if let controller = PDFEditorWindowController.focusedController,
           let model = controller.model {
            open(pendingURLs, into: controller, model: model)
            pendingURLs.removeAll()
            drainScheduled = false
            return
        }
        drainAttempts += 1
        if drainAttempts < 30 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.drain()
            }
        } else {
            drainScheduled = false
        }
    }

    private func open(_ urls: [URL], into controller: PDFEditorWindowController, model: AppModel) {
        guard let url = urls.first else { return }
        model.open(url: url)
        controller.window?.makeKeyAndOrderFront(nil)
        closeOtherScratchWindows(keeping: controller)
        // SwiftUI's WindowGroup can create its own start-surface window for
        // the same open event after this router has already run (sim finding
        // PL-I30b). Sweep again once the scene machinery settles; the sweep
        // only ever closes clean scratch surfaces, so re-running is safe.
        for delay in [0.5, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.closeOtherScratchWindows(keeping: controller)
            }
        }
    }

    /// After an external open, exactly one window should show the document.
    /// Any *other* visible window that is still an empty, clean start surface
    /// is closed. Windows with real state (scratch edits, documents) are
    /// never touched — the invariant is "no external open may discard work."
    private func closeOtherScratchWindows(keeping kept: PDFEditorWindowController) {
        for controller in PDFEditorWindowController.existingControllers where controller !== kept {
            guard let model = controller.model,
                  model.inspection == nil,
                  !model.isDirty,
                  let window = controller.window,
                  window.isVisible
            else { continue }
            controller.close()
        }
    }
}

@main
struct PDFEditorApp: App {
    @NSApplicationDelegateAdaptor(PDFEditorAppDelegate.self) private var appDelegate

    init() {
        // A raw executable launched from a terminal still needs normal app
        // activation so the native preview is immediately testable.
        PDFEditorNativeWindowProbe.recordProcessStarted()
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSRunningApplication(processIdentifier: ProcessInfo.processInfo.processIdentifier)?
                .activate(options: [.activateAllWindows])
        }
    }

    var body: some Scene {
        WindowGroup(ProductIdentity.displayName, id: "pdf-editor") {
            PDFEditorWindow()
        }
        .defaultSize(width: 1_280, height: 820)
        .commands {
            AppCommands()
        }
        Window("Governance Dashboard", id: "governance-dashboard") {
            GovernanceStandaloneWindowView()
        }
        .defaultSize(width: 820, height: 560)

        Window("Companion Health", id: "companion-health") {
            CompanionHealthStandaloneWindowView()
        }
        .defaultSize(width: 680, height: 520)

        Window("Northstar Help", id: "northstar-help") {
            NorthstarHelpView()
        }
        .defaultSize(width: 720, height: 620)

        Settings {
            SettingsView()
        }
    }
}
