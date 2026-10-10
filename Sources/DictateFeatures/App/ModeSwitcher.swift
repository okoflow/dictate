import DictateCore
import Observation

@Observable
package final class ModeSwitcher {
    package private(set) var isShortcutAvailable = false

    @ObservationIgnored private let shortcut: any GlobalShortcut
    @ObservationIgnored private let settings: SettingsModel
    @ObservationIgnored private let hud: HUDController

    package var shortcutTitle: String {
        shortcut.title
    }

    init(shortcut: any GlobalShortcut, settings: SettingsModel, hud: HUDController) {
        self.shortcut = shortcut
        self.settings = settings
        self.hud = hud
    }

    func start() {
        isShortcutAvailable = shortcut.register { [weak self] in
            self?.switchToNextMode()
        }
    }

    private func switchToNextMode() {
        settings.settings.mode = settings.settings.mode.next

        hud.show(HUDMessage(kind: .info, title: "Mode: \(settings.settings.mode.title)"))
    }
}
