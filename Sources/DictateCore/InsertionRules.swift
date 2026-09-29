import Foundation

/// The pure decisions behind inserting dictated text into another app: spacing, whether it is safe to
/// paste at all, and what to do with the user's clipboard around the paste.
public enum InsertionRules {
    // MARK: Spacing

    /// After these characters (and after whitespace) no space is added: the text continues a bracket,
    /// a quotation or a path. The same for Russian, English and Korean.
    private static let noSpaceAfter: Set<Character> = ["(", "\"", "«", "„", "/", "[", "“"]

    /// `text` as it should be pasted. Whisper's leading and trailing whitespace is dropped, and one space
    /// is put in front unless the caret is at the start of the field, follows whitespace or one of
    /// `( " « „ / [`, or `characterBeforeCaret` could not be read (`nil`): then no space rather than a wrong one.
    public static func prepared(_ text: String, characterBeforeCaret: Character?) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let before = characterBeforeCaret else { return trimmed }
        if before.isWhitespace || before.isNewline || noSpaceAfter.contains(before) {
            return trimmed
        }
        return " " + trimmed
    }

    // MARK: Where the text goes

    public enum SkipReason: String, Codable, Equatable, Sendable {
        /// The focused element is a password field.
        case secureField
        /// The frontmost app or focused element is not the one the user was in when they started speaking.
        case focusChanged
        /// Dictate is not allowed to post key events (Accessibility not granted).
        case noAccessibility
        /// The user is holding the hotkey again, so a ⌘V would arrive as ⌥⌘V.
        case hotkeyHeld
        /// Test-only guard (`--insert-only-into`): the E2E suite must not paste into the user's own apps.
        case notAllowed
    }

    public enum Decision: Equatable, Sendable {
        case paste
        case skip(SkipReason)
    }

    /// Password fields come first: the text must never be typed there, whatever else is true.
    public static func decide(
        focusedElementIsSecure: Bool,
        accessibilityGranted: Bool,
        focusStillOnTarget: Bool,
        hotkeyStillHeld: Bool
    ) -> Decision {
        if focusedElementIsSecure {
            return .skip(.secureField)
        }
        if !accessibilityGranted {
            return .skip(.noAccessibility)
        }
        if !focusStillOnTarget {
            return .skip(.focusChanged)
        }
        if hotkeyStillHeld {
            return .skip(.hotkeyHeld)
        }
        return .paste
    }

    public enum ElementComparison: Equatable, Sendable {
        case same
        case different
        /// One of the two focused elements could not be read (an app with poor accessibility support).
        case unknown
    }

    /// Whether the app in front now is still where the dictation started. Elements are compared when both
    /// could be read; otherwise the process decides.
    public static func focusStillOnTarget(elements: ElementComparison, targetPID: Int32, currentPID: Int32) -> Bool {
        guard targetPID == currentPID else { return false }
        return elements != .different
    }

    // MARK: Clipboard

    public static let maximumSnapshotBytes = 5 * 1024 * 1024
    public static let concealedType = "org.nspasteboard.ConcealedType"
    public static let transientType = "org.nspasteboard.TransientType"

    /// Types that cannot be put back: dynamic UTIs and promised files refer to something that is gone
    /// once the owner is.
    public static func isRestorable(type: String) -> Bool {
        !(type.hasPrefix("dyn.") || type.hasPrefix("com.apple.pasteboard.promised-file") || type.hasPrefix("NSPromised"))
    }

    public enum RestorePlan: Equatable, Sendable {
        case restore
        case skip(String)
    }

    /// Whether the user's clipboard is worth saving and restoring around a paste. A password manager
    /// marks what it copies as concealed or transient and clears it by watching the change count, so
    /// touching that item would break the clearing; an enormous item is not worth holding on to.
    public static func restorePlan(currentTypes: [String], snapshotBytes: Int) -> RestorePlan {
        if currentTypes.contains(concealedType) || currentTypes.contains(transientType) {
            return .skip("the clipboard holds a concealed or transient item")
        }
        if snapshotBytes > maximumSnapshotBytes {
            return .skip("the clipboard holds more than 5 MB")
        }
        return .restore
    }

    /// The saved clipboard goes back only if nobody wrote to it since we did.
    public static func shouldRestore(changeCount: Int, expected: Int) -> Bool {
        changeCount == expected
    }
}
