import DictateCore
import Foundation
import Observation

/// The language choice from the menu, kept in `UserDefaults` so it survives a restart.
@MainActor
@Observable
final class LanguageSettings {
    private static let key = "languagePreference"

    var preference: LanguagePreference {
        didSet { defaults.set(preference.storedValue, forKey: Self.key) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preference = LanguagePreference(storedValue: defaults.string(forKey: Self.key))
    }
}
