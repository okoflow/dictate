import DictateCore
import SwiftUI

struct GeneralSettingsPane: View {
    @Bindable var settings: SettingsModel

    let permissions: PermissionMonitor

    private var launchesAtLogin: Binding<Bool> {
        Binding(get: { settings.launchesAtLogin }, set: { settings.setLaunchesAtLogin($0) })
    }

    private var menuBarNote: String? {
        settings.settings.showsMenuBarIcon ? nil : "Open Dictate again to get to Settings."
    }

    var body: some View {
        SettingsSection("App") {
            ToggleRow("Open at login", isOn: launchesAtLogin)
            RowDivider()
            ToggleRow("Show in menu bar", isOn: $settings.settings.showsMenuBarIcon, description: menuBarNote)
        }
        .animation(.snappy(duration: 0.2), value: settings.settings.showsMenuBarIcon)

        SettingsSection("Sounds") {
            ToggleRow(
                "Play sounds",
                isOn: $settings.settings.playsSounds,
                description: "A soft click when recording starts and stops.",
            )
        }

        SettingsSection("Permissions", subtitle: "Dictate needs both to type for you.") {
            ForEach(Permission.allCases, id: \.self) { permission in
                if permission != Permission.allCases.first {
                    RowDivider()
                }

                PermissionRow(permission: permission, monitor: permissions)
            }
        }
    }
}
