import DictateCore
import Foundation
import Observation
import os

@Observable
package final class SettingsModel {
    package var settings: Settings {
        didSet { settingsDidChange(from: oldValue) }
    }

    package private(set) var launchesAtLogin: Bool
    package private(set) var microphones: [AudioInputDevice] = []

    @ObservationIgnored var onLanguagesChange: (([Language]) -> Void)?
    @ObservationIgnored var onModeChange: ((Mode) -> Void)?

    @ObservationIgnored private let store: any ValueStore<Settings>
    @ObservationIgnored private let loginItem: any LoginItem
    @ObservationIgnored private let audioInputs: any AudioInputProvider

    init(store: any ValueStore<Settings>, loginItem: any LoginItem, audioInputs: any AudioInputProvider) {
        self.store = store
        self.loginItem = loginItem
        self.audioInputs = audioInputs
        settings = Self.loadSettings(from: store)
        launchesAtLogin = loginItem.isEnabled
    }

    private static func loadSettings(from store: any ValueStore<Settings>) -> Settings {
        do {
            if let settings = try store.load() {
                return settings
            }
        } catch {
            Logger.settings.error("Couldn't read the settings: \(error.localizedDescription, privacy: .public)")
        }

        return Settings(languages: .preferred(by: Locale.preferredLanguages))
    }

    package func setLaunchesAtLogin(_ isEnabled: Bool) {
        do {
            try loginItem.setEnabled(isEnabled)
        } catch {
            Logger.settings.error("Couldn't change the login item: \(error.localizedDescription, privacy: .public)")
        }

        launchesAtLogin = loginItem.isEnabled
    }

    package func refreshMicrophones() {
        microphones = audioInputs.inputDevices()
    }

    private func settingsDidChange(from oldValue: Settings) {
        guard settings != oldValue else { return }

        do {
            try store.save(settings)
        } catch {
            Logger.settings.error("Couldn't save the settings: \(error.localizedDescription, privacy: .public)")
        }

        if settings.languages.languages != oldValue.languages.languages {
            onLanguagesChange?(settings.languages.languages)
        }

        if settings.mode != oldValue.mode {
            onModeChange?(settings.mode)
        }
    }
}
