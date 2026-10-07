import AppKit
import DictateCore
import Foundation
import Observation

/// The default mode of some apps, kept in `UserDefaults` (an `--app-mode` launch option replaces them for that
/// launch, unsaved), and the app in front, which the menu offers to give one.
@MainActor
@Observable
final class AppModeSettings {
    private static let key = "appModes"

    private(set) var modes: AppModes
    /// The last app other than Dictate that came to the front: the menu bar menu never takes focus, so it is the
    /// app you were in when you opened the menu.
    private(set) var frontmost: NSRunningApplication?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let persists: Bool

    init(defaults: UserDefaults = .standard, override: AppModes? = nil) {
        self.defaults = defaults
        persists = override == nil
        modes = override ?? AppModes(stored: defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:])
        frontmost = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.activated(app) }
        }
    }

    func set(_ mode: Mode?, for bundleIdentifier: String) {
        modes.set(mode, for: bundleIdentifier)
        if persists {
            defaults.set(modes.stored, forKey: Self.key)
        }
    }

    private func activated(_ app: NSRunningApplication?) {
        guard let app, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        frontmost = app
    }
}
