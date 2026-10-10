package enum InsertionDecision: Equatable, Sendable {
    case paste
    case skip(InsertionSkipReason)

    package static func decide(
        isSecureField: Bool,
        canPostKeys: Bool,
        isFocusOnTarget: Bool,
        isKeyHeld: Bool,
    ) -> InsertionDecision {
        if isSecureField {
            .skip(.secureField)
        } else if !canPostKeys {
            .skip(.noAccessibility)
        } else if !isFocusOnTarget {
            .skip(.focusChanged)
        } else if isKeyHeld {
            .skip(.keyHeld)
        } else {
            .paste
        }
    }

    package static func isFocusOnTarget(_ comparison: FocusComparison, targetProcessID: Int32, currentProcessID: Int32) -> Bool {
        targetProcessID == currentProcessID && comparison != .different
    }
}

package enum InsertionSkipReason: String, Sendable {
    case secureField
    case noAccessibility
    case focusChanged
    case keyHeld
}
