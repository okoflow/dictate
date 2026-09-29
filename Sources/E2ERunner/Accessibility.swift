import ApplicationServices
import Foundation

/// Thin wrappers over the Accessibility C API. String keys are used on purpose: the `kAX*`
/// globals are mutable in the SDK and Swift 6 refuses to read them.
enum Accessibility {
    static func application(pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    static func string(_ name: String, of element: AXUIElement) -> String? {
        attribute(name, of: element) as? String
    }

    static func children(of element: AXUIElement) -> [AXUIElement] {
        (attribute("AXChildren", of: element) as? [AXUIElement]) ?? []
    }

    /// Breadth-first search for the element with the given `AXIdentifier`.
    static func find(identifier: String, in root: AXUIElement, maxDepth: Int = 12) -> AXUIElement? {
        var level = [root]
        for _ in 0 ..< maxDepth {
            var next: [AXUIElement] = []
            for element in level {
                if string("AXIdentifier", of: element) == identifier {
                    return element
                }
                next += children(of: element)
            }
            if next.isEmpty {
                return nil
            }
            level = next
        }
        return nil
    }

    /// Like `find`, but keeps looking while the app is still building its window.
    static func waitForElement(identifier: String, in root: AXUIElement, timeout: TimeInterval = 5) -> AXUIElement? {
        var found: AXUIElement?
        _ = waitUntil(timeout: timeout) {
            found = find(identifier: identifier, in: root)
            return found != nil
        }
        return found
    }

    static func bringToFront(_ application: AXUIElement) {
        AXUIElementSetAttributeValue(application, "AXFrontmost" as CFString, kCFBooleanTrue)
    }

    /// Puts the caret at `location` (UTF-16 offset) with nothing selected.
    @discardableResult
    static func setCaret(at location: Int, of element: AXUIElement) -> Bool {
        var range = CFRange(location: location, length: 0)
        guard let value = AXValueCreate(.cfRange, &range) else { return false }
        return AXUIElementSetAttributeValue(element, "AXSelectedTextRange" as CFString, value) == .success
    }

    @discardableResult
    static func setValue(_ text: String, of element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, "AXValue" as CFString, text as CFString) == .success
    }
}

/// Polls `condition` until it holds or `timeout` seconds pass.
func waitUntil(timeout: TimeInterval, interval: TimeInterval = 0.05, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        Thread.sleep(forTimeInterval: interval)
    }
    return condition()
}
