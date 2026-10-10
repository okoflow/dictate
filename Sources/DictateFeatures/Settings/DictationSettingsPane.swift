import AppKit
import DictateCore
import SwiftUI

struct DictationSettingsPane: View {
    @Bindable var settings: SettingsModel

    let speechModel: SpeechModelController

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

    private var addableLanguages: [Language] {
        Language.allCases
            .filter { !selection.languages.contains($0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        SettingsSection("Languages", subtitle: "Dictate listens for these languages.") {
            ForEach(selection.languages, id: \.self) { language in
                LanguageRow(language: language, canRemove: selection.languages.count > 1) {
                    settings.settings.languages = selection.including(language, false)
                }
                RowDivider()
            }

            PickerRow("Spoken language", selection: pinnedLanguage, description: spokenLanguageNote) {
                Text("Detect automatically").tag(Language?.none)
                Divider()
                ForEach(selection.languages, id: \.self) { language in
                    Text(language.name).tag(Language?.some(language))
                }
            }
        } footer: {
            Menu("Add Language") {
                ForEach(addableLanguages, id: \.self) { language in
                    Button("\(language.name) · \(language.nativeName)") {
                        settings.settings.languages = selection.including(language, true)
                    }
                }
            }
            .fixedSize()
            .disabled(addableLanguages.isEmpty)
        }

        SettingsSection("Microphone") {
            PickerRow("Record from", selection: $settings.settings.microphoneID) {
                Text("System default").tag(String?.none)
                ForEach(settings.microphones) { microphone in
                    Text(microphone.name).tag(String?.some(microphone.id))
                }
            }
        }

        SettingsSection("Speech model") {
            SpeechModelRow(controller: speechModel)
        }
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

private struct SpeechModelRow: View {
    let controller: SpeechModelController

    var body: some View {
        SettingsRow(controller.state.statusText, description: "Whisper large-v3 turbo · 630 MB") {
            if let progress = controller.state.progress {
                ProgressView(value: progress)
                    .frame(width: 100)
            }

            if controller.state.canRetry {
                Button("Retry") { controller.retry() }
            }

            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([controller.modelDirectory])
            }
        }
    }
}
