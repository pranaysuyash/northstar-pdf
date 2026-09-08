// window_poll.swift — print ms from now until PID owns an on-screen window
// wider than 100pt, or TIMEOUT. Used by scripts/measure_app_launch.sh.
// Compile: swiftc -O -o /tmp/window_poll scripts/window_poll.swift -framework Cocoa
import Cocoa

guard CommandLine.arguments.count == 3,
      let targetPID = Int32(CommandLine.arguments[1]),
      let deadlineMS = Double(CommandLine.arguments[2]) else { exit(2) }

let start = Date()
let elapsedMS: () -> Double = { Date().timeIntervalSince(start) * 1000 }

while elapsedMS() < deadlineMS {
    if let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
        for w in list {
            let owner = (w[kCGWindowOwnerPID as String] as? Int)
                ?? Int((w[kCGWindowOwnerPID as String] as? Int32) ?? -1)
            let width = (w[kCGWindowBounds as String] as? [String: CGFloat])?["Width"] ?? 0
            if owner == Int(targetPID) && width > 100 {
                print(Int(elapsedMS()))
                exit(0)
            }
        }
    }
    Thread.sleep(forTimeInterval: 0.05)
}
print("TIMEOUT")
exit(1)
