import AppKit
import DictateCore
import SwiftUI

struct DictationSettingsPane: View {
    @Bindable var settings: SettingsModel

    let keyRecorder: KeyRecorder

    private var selection: LanguageSelection {
        settings.settings.languages
    }

    private var pinnedLanguage: Binding<Language?> {
        Binding(
            get: { selection.pinned },
            set: { settings.settings.languages = selection.pinning($0) },
        )
    }

    private var spokenLanguageNote: String? {
        let languages = selection.languages

        guard languages.contains(.russian), languages.contains(.ukrainian) else { return nil }

        return "Russian and Ukrainian sound alike: pin one if Dictate mixes them up."
    }

    private var keyNote: String? {
        if keyRecorder.rejectedKey {
            return "That key types text. Press a modifier, fn, or an F-key."
        }

        if keyRecorder.isRecording {
            return "Press Option, Command, Shift or Control on either side, fn, or an F-key. Esc cancels."
        }

        return settings.settings.pushToTalkKey == .function
            ? "Set “Press 🌐 key to” to Do Nothing in System Settings › Keyboard."
            : nil
    }

    private var microphoneName: String {
        settings.microphones.first { $0.id == settings.settings.microphoneID }?.name ?? "System default"
    }

    private var addableLanguages: [Language] {
        Language.allCases
            .filter { !selection.languages.contains($0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        SettingsSection("Recording") {
            SettingsRow("Hold to dictate", description: keyNote) {
                KeyRecorderField(key: settings.settings.pushToTalkKey, recorder: keyRecorder) { key in
                    settings.settings.pushToTalkKey = key
                }
            }
            RowDivider()
            PickerRow("Microphone", selection: $settings.settings.microphoneID, current: microphoneName) {
                Text("System default").tag(String?.none)
                ForEach(settings.microphones) { microphone in
                    Text(microphone.name).tag(String?.some(microphone.id))
                }
            }
        }

        SettingsSection("Languages", subtitle: "Dictate listens for these languages.") {
            ForEach(selection.languages, id: \.self) { language in
                LanguageRow(language: language, canRemove: selection.languages.count > 1) {
                    settings.settings.languages = selection.including(language, false)
                }
                RowDivider()
            }

            PickerRow(
                "Spoken language",
                selection: pinnedLanguage,
                current: selection.pinned?.name ?? "Detect automatically",
                description: spokenLanguageNote,
            ) {
                Text("Detect automatically").tag(Language?.none)
                Divider()
                ForEach(selection.languages, id: \.self) { language in
                    Text(language.name).tag(Language?.some(language))
                }
            }
        } footer: {
            Menu {
                ForEach(addableLanguages, id: \.self) { language in
                    Button("\(language.name) · \(language.nativeName)") {
                        settings.settings.languages = selection.including(language, true)
                    }
                }
            } label: {
                Label("Add Language", systemImage: "plus")
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(addableLanguages.isEmpty)
        }
        .animation(.snappy(duration: 0.2), value: selection.languages)
        .onDisappear { keyRecorder.stop() }
    }
}

private struct LanguageRow: View {
    let language: Language
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        SettingsRow(language.nativeName, description: language.nativeName == language.name ? nil : language.name) {
            RemoveButton(help: "Remove \(language.name)", action: remove)
                .disabled(!canRemove)
        }
    }
}
