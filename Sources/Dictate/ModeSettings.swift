import DictateCore
import Foundation
import Observation

/// The processing mode from the menu or the ⌃⌥M hotkey, kept in `UserDefaults`. A `--mode` launch option
/// overrides it for that launch and is not saved, and neither is anything changed during such a launch.
@MainActor
@Observable
final class ModeSettings {
    private static let key = "mode"

    var mode: Mode {
        didSet {
            guard mode != oldValue else { return }
            if persists {
                defaults.set(mode.rawValue, forKey: Self.key)
            }
            onChange?(mode)
        }
    }

    /// Called after every change, from the menu or the hotkey.
    @ObservationIgnored var onChange: ((Mode) -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let persists: Bool

    init(defaults: UserDefaults = .standard, override: Mode? = nil) {
        self.defaults = defaults
        persists = override == nil
        mode = override ?? Mode(storedValue: defaults.string(forKey: Self.key))
    }
}
