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
        Text("Model: \(dictation.models.state.statusText)")
        if dictation.models.state.canRetry {
            Button("Retry") {
                dictation.models.retry()
            }
        }
        Menu("Language: \(dictation.language.preference.menuTitle)") {
            Picker("Language", selection: Bindable(dictation.language).preference) {
                ForEach(LanguagePreference.allChoices, id: \.storedValue) { choice in
                    Text(choice.menuTitle).tag(choice)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        Toggle("Insert into the focused field", isOn: Bindable(dictation.insertion).isEnabled)
        Button("Copy last transcript") {
            if let text = dictation.lastTranscript.text {
                Clipboard.copy(text)
            }
        }
        .disabled(dictation.lastTranscript.text == nil)
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
            Task {
                // A paste in progress still has to give the user's clipboard back.
                await dictation.prepareToQuit()
                NSApplication.shared.terminate(nil)
            }
        }
        .keyboardShortcut("q")
    }
}
