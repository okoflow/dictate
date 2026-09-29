import AppKit
import DictateCore
import SwiftUI

struct DictateApp: App {
    @State private var permissions = PermissionsModel()

    var body: some Scene {
        MenuBarExtra("Dictate", systemImage: permissions.report.allGranted ? "mic.fill" : "mic.slash") {
            MenuContent(permissions: permissions)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuContent: View {
    let permissions: PermissionsModel

    var body: some View {
        if permissions.report.allGranted {
            Text("All permissions granted")
        } else {
            Text("Permissions needed")
            ForEach(permissions.report.missing, id: \.self) { permission in
                Button("Grant \(permission.title)…") {
                    permissions.grant(permission)
                }
            }
        }
        Divider()
        Button("Quit Dictate") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
