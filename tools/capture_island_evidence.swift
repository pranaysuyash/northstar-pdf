import Cocoa

let pdfPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf"
let outPath = "/Users/pranay/Projects/pdf_editor/docs/audits/screenshots/2026-09-24_workspace_after_islands.png"

let binary = "/Users/pranay/Projects/pdf_editor/.build/arm64-apple-macosx/debug/PDFEditor"
guard FileManager.default.isExecutableFile(atPath: binary) else {
    print("Binary not executable at \(binary)")
    exit(1)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: binary)
process.arguments = [pdfPath]

try process.run()
print("App launched with PID: \(process.processIdentifier)")

Thread.sleep(forTimeInterval: 4.0)

let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

var targetWindowID: CGWindowID?
for info in windowList {
    let pid = info[kCGWindowOwnerPID as String] as? pid_t
    if pid == process.processIdentifier {
        if let wid = info[kCGWindowNumber as String] as? CGWindowID {
            let bounds = info[kCGWindowBounds as String] as? [String: Any]
            let width = bounds?["Width"] as? Double ?? 0
            if width > 300 {
                targetWindowID = wid
                break
            }
        }
    }
}

if let wid = targetWindowID {
    print("Found window ID: \(wid). Capturing screenshot to \(outPath)...")
    let cap = Process()
    cap.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    cap.arguments = ["-l\(wid)", "-o", outPath]
    try cap.run()
    cap.waitUntilExit()
    print("Screenshot captured successfully to \(outPath)!")
} else {
    print("No specific window found for PID, capturing active screen region as fallback...")
    let cap = Process()
    cap.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    cap.arguments = ["-x", outPath]
    try cap.run()
    cap.waitUntilExit()
    print("Captured screen fallback to \(outPath)")
}

process.terminate()
print("Evidence capture complete.")
