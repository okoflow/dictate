import Foundation
import Observation
import WaftCore

@Observable
package final class ModeSwitcher {
    package private(set) var isShortcutAvailable = false

    @ObservationIgnored private let shortcut: any GlobalShortcut
    @ObservationIgnored private let settings: SettingsModel
    @ObservationIgnored private let hud: HUDController
    @ObservationIgnored private let pro: ProModel

    package var shortcutTitle: String {
        shortcut.title
    }

    init(shortcut: any GlobalShortcut, settings: SettingsModel, hud: HUDController, pro: ProModel) {
        self.shortcut = shortcut
        self.settings = settings
        self.hud = hud
        self.pro = pro
    }

    func start() {
        isShortcutAvailable = shortcut.register { [weak self] in
            self?.switchToNextMode()
        }
    }

    private func switchToNextMode() {
        settings.settings.mode = settings.settings.mode.next(includingAI: pro.allows(.aiModes))

        hud.show(HUDMessage(kind: .info, title: String(localized: "Mode: \(settings.settings.mode.title)")))
    }
}
