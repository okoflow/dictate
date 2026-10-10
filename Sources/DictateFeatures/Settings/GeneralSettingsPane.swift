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

        SettingsSection("Dictation") {
            PickerRow("Hold to dictate", selection: $settings.settings.pushToTalkKey) {
                ForEach(PushToTalkKey.allCases, id: \.self) { key in
                    Text(key.title).tag(key)
                }
            }
            RowDivider()
            ToggleRow("Paste into the focused field", isOn: $settings.settings.pastesIntoFocusedField)
        }

        SettingsSection("Sounds") {
            ToggleRow("Play sounds", isOn: $settings.settings.playsSounds)
        }

        SettingsSection("Permissions") {
            ForEach(Permission.allCases, id: \.self) { permission in
                if permission != Permission.allCases.first {
                    RowDivider()
                }

                PermissionRow(permission: permission, monitor: permissions)
            }
        }
    }
}
