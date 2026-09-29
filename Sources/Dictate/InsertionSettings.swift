import Foundation
import Observation

/// The "Insert into the focused field" switch from the menu, kept in `UserDefaults`. Off means the
/// text only goes to the clipboard (the M2 behaviour).
@MainActor
@Observable
final class InsertionSettings {
    private static let key = "insertIntoFocusedField"

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.key) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Self.key) as? Bool ?? true
    }
}

/// The last dictated text, in memory only, for the "Copy last transcript" menu item: the way back when
/// the text was not pasted (a password field) or the paste went to the wrong place.
@MainActor
@Observable
final class LastTranscript {
    private(set) var text: String?

    func remember(_ text: String) {
        self.text = text
    }
}
