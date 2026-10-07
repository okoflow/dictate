import DictateCore
import Foundation
import Observation

/// The language choice from the menu, kept in `UserDefaults` so it survives a restart. A `--language` launch
/// option overrides it for that launch and is not saved, and neither is anything changed during such a launch.
@MainActor
@Observable
final class LanguageSettings {
    private static let key = "languagePreference"

    var preference: LanguagePreference {
        didSet {
            if persists {
                defaults.set(preference.storedValue, forKey: Self.key)
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let persists: Bool

    init(defaults: UserDefaults = .standard, override: LanguagePreference? = nil) {
        self.defaults = defaults
        persists = override == nil
        preference = override ?? LanguagePreference(storedValue: defaults.string(forKey: Self.key))
    }
}
