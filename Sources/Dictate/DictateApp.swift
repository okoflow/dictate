import AppKit
import DictateCore
import SwiftUI

struct DictateApp: App {
    @State private var permissions = PermissionsModel()
    @State private var dictation = DictationController(options: LaunchOptions(arguments: CommandLine.arguments))

    var body: some Scene {
        MenuBarExtra("Dictate", systemImage: permissions.report.allGranted ? "mic.fill" : "mic.slash") {
            MenuContent(permissions: permissions, dictation: dictation)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuContent: View {
    let permissions: PermissionsModel
    let dictation: DictationController

    var body: some View {
        switch dictation.hotkeyStatus {
        case .starting: Text("Starting…")
        case .ready: Text("Hold right ⌥ to dictate")
        case .unavailable: Text("Hotkey unavailable: grant Input Monitoring")
        }
        Divider()
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
