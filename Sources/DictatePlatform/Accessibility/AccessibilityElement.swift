import ApplicationServices
import DictateCore

struct AccessibilityElement: FocusedElement, @unchecked Sendable {
    private static let messagingTimeout: Float = 0.1

    let element: AXUIElement

    var isSecureTextField: Bool {
        string(kAXSubroleAttribute) == kAXSecureTextFieldSubrole
    }

    var characterBeforeCaret: Character? {
        guard let selection = selectedRange(), selection.location > 0 else { return nil }

        var previous = CFRange(location: selection.location - 1, length: 1)
        guard let parameter = AXValueCreate(.cfRange, &previous) else { return nil }

        var value: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            parameter,
            &value,
        )
        guard status == .success, let character = (value as? String)?.first, character != "\u{FFFD}" else { return nil }

        return character
    }

    private var window: AXUIElement? {
        Self.attribute(kAXWindowAttribute, of: element)
    }

    init(_ element: AXUIElement) {
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
        self.element = element
    }

    static func focusedElement() -> AccessibilityElement? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, messagingTimeout)

        return attribute(kAXFocusedUIElementAttribute, of: systemWide).map(AccessibilityElement.init)
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    func compare(with other: any FocusedElement) -> FocusComparison {
        guard let other = other as? AccessibilityElement else { return .unknown }

        if CFEqual(element, other.element) {
            return .same
        }

        let sameRole = string(kAXRoleAttribute).map { $0 == other.string(kAXRoleAttribute) } ?? false
        guard sameRole, let window, let otherWindow = other.window, CFEqual(window, otherWindow) else { return .different }

        return .same
    }

    private func string(_ name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }

        return value as? String
    }

    private func selectedRange() -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success, let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }

        var range = CFRange()

        return AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cfRange, &range) ? range : nil
    }
}
