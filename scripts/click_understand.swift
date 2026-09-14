import Cocoa
import ApplicationServices

guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "Northstar" }) else {
    print("Northstar not running")
    exit(1)
}

let axApp = AXUIElementCreateApplication(app.processIdentifier)

func findElement(element: AXUIElement, title: String) -> AXUIElement? {
    var childrenRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
    guard result == .success, let children = childrenRef as? [AXUIElement] else { return nil }
    
    for child in children {
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef) == .success,
           let t = titleRef as? String, t == title {
            return child
        }
        if let found = findElement(element: child, title: title) {
            return found
        }
    }
    return nil
}

if let understandButton = findElement(element: axApp, title: "Understand") {
    print("Found Understand element, pressing...")
    AXUIElementPerformAction(understandButton, kAXPressAction as CFString)
    Thread.sleep(forTimeInterval: 1.0)
    print("Pressed!")
} else {
    print("Could not find Understand element")
}
