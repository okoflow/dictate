import AppKit
import ApplicationServices
import DictateCore
import Foundation

/// Where the keyboard focus is: the frontmost app and, when Accessibility allows, its focused element.
/// Apps with poor accessibility support (some Electron apps) give no element; everything here then
/// degrades to "unknown" instead of failing.
/// `AXUIElement` is an immutable, thread-safe Core Foundation object; the snapshot is only ever used on the main actor.
struct FocusSnapshot: @unchecked Sendable {
    let pid: pid_t
    let bundleIdentifier: String?
    let element: AXUIElement?
}

@MainActor
enum FocusProbe {
    /// A stuck app must not stall dictation; 100 ms is far more than a healthy one needs.
    private static let messagingTimeout: Float = 0.1

    static func current() -> FocusSnapshot {
        let app = NSWorkspace.shared.frontmostApplication
        return FocusSnapshot(
            pid: app?.processIdentifier ?? 0,
            bundleIdentifier: app?.bundleIdentifier,
            element: AXIsProcessTrusted() ? focusedElement() : nil
        )
    }

    /// `CFEqual` on two elements: the same accessibility object, not merely the same kind.
    /// Elements that differ still count as the same target when they have the same role in the same window:
    /// many apps hand out a fresh accessibility object for the same field each time it is asked for.
    static func compare(_ lhs: AXUIElement?, _ rhs: AXUIElement?) -> InsertionRules.ElementComparison {
        guard let lhs, let rhs else { return .unknown }
        if CFEqual(lhs, rhs) {
            return .same
        }
        guard let role = string("AXRole", of: lhs), role == string("AXRole", of: rhs),
              let lhsWindow = window(of: lhs), let rhsWindow = window(of: rhs), CFEqual(lhsWindow, rhsWindow)
        else { return .different }
        return .same
    }

    private static func window(of element: AXUIElement) -> AXUIElement? {
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXWindow" as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    static func isSecureTextField(_ element: AXUIElement?) -> Bool {
        guard let element else { return false }
        return string("AXSubrole", of: element) == "AXSecureTextField"
    }

    /// The character just before the caret, read as one UTF-16 unit range. `nil` at the start of the
    /// field and whenever the app does not expose its text.
    static func characterBeforeCaret(in element: AXUIElement?) -> Character? {
        guard let element else { return nil }
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        var selection: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXSelectedTextRange" as CFString, &selection) == .success,
              let selection, CFGetTypeID(selection) == AXValueGetTypeID()
        else { return nil }
        var range = CFRange()
        guard AXValueGetValue(unsafeDowncast(selection, to: AXValue.self), .cfRange, &range), range.location > 0 else {
            return nil
        }
        var previous = CFRange(location: range.location - 1, length: 1)
        guard let parameter = AXValueCreate(.cfRange, &previous) else { return nil }
        var text: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, "AXStringForRange" as CFString, parameter, &text) == .success,
              let character = (text as? String)?.first, character != "\u{FFFD}"
        else { return nil }
        return character
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, messagingTimeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, "AXFocusedUIElement" as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private static func string(_ attribute: String, of element: AXUIElement) -> String? {
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
