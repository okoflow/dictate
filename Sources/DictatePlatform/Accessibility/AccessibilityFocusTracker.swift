import AppKit
import ApplicationServices
import DictateCore

@MainActor
package final class AccessibilityFocusTracker: FocusTracker {
    package init() {}

    package func currentFocus() -> FocusTarget {
        let app = NSWorkspace.shared.frontmostApplication
        let element = AXIsProcessTrusted() ? AccessibilityElement.focusedElement() : nil

        return FocusTarget(processID: app?.processIdentifier ?? 0, bundleIdentifier: app?.bundleIdentifier, element: element)
    }
}
