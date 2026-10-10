import DictateCore
import SwiftUI

struct GeneralSettingsPane: View {
    @Bindable var settings: SettingsModel

    let permissions: PermissionMonitor

    private var launchesAtLogin: Binding<Bool> {
        Binding(get: { settings.launchesAtLogin }, set: { settings.setLaunchesAtLogin($0) })
    }

    var body: some View {
        Form {
            Section {
                Picker("Hold to dictate", selection: $settings.settings.pushToTalkKey) {
                    ForEach(PushToTalkKey.allCases, id: \.self) { key in
                        Text(key.title).tag(key)
                    }
                }

                Toggle("Paste into the focused field", isOn: $settings.settings.pastesIntoFocusedField)
                Toggle("Play sounds", isOn: $settings.settings.playsSounds)
            }

            Section {
                Toggle("Open at login", isOn: launchesAtLogin)
            }

            Section("Permissions") {
                ForEach(Permission.allCases, id: \.self) { permission in
                    PermissionRow(permission: permission, monitor: permissions)
                }
            }
        }
    }
}
