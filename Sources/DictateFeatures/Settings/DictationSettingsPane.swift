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

    private var spokenLanguageNote: LocalizedStringKey? {
        guard let alike = Language.soundAlike(among: selection.languages) else { return nil }

        let names = Language.inlineList(alike)

        return .verbatim(String(localized: "\(names) sound alike: pin one if Dictate mixes them up.").sentenceCased)
    }

    private var suggestedLanguages: [Language] {
        var suggested: [Language] = []

        for language in Locale.preferredLanguages.compactMap(Language.init(localeIdentifier:))
            where !selection.languages.contains(language) && !suggested.contains(language) {
            suggested.append(language)
        }

        return suggested
    }

    private var keyNote: LocalizedStringKey? {
        if let note = keyRecorder.note(for: .dictation) {
            return note
        }

        return settings.settings.pushToTalkKey == .function
            ? "Set “Press 🌐 key to” to Do Nothing in System Settings › Keyboard."
            : nil
    }

    private var microphoneName: String {
        settings.microphones.first { $0.id == settings.settings.microphoneID }?.name ?? String(localized: "System default")
    }

    private var addableLanguages: [Language] {
        Language.allCases
            .filter { !selection.languages.contains($0) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        SettingsSection("Recording") {
            SettingsRow("Hold to dictate", description: keyNote) {
                KeyRecorderField(
                    field: .dictation,
                    key: settings.settings.pushToTalkKey,
                    takenKey: settings.settings.editKey,
                    recorder: keyRecorder,
                ) { key in
                    settings.settings.pushToTalkKey = key
                }
            }
            RowDivider()
            ToggleRow(
                "Double-tap for hands-free",
                isOn: $settings.settings.handsFreeDoubleTap,
                description: "Tap the key twice to dictate without holding it, then press it once to finish.",
            )
            RowDivider()
            PickerRow("Microphone", selection: $settings.settings.microphoneID, current: microphoneName) {
                Text("System default").tag(String?.none)
                ForEach(settings.microphones) { microphone in
                    Text(microphone.name).tag(String?.some(microphone.id))
                }
            }
        }

        EditKeySection(settings: settings, keyRecorder: keyRecorder)

        SettingsSection("Languages", subtitle: "Dictate listens for these languages.") {
            ForEach(selection.languages, id: \.self) { language in
                LanguageRow(language: language, canRemove: selection.languages.count > 1) {
                    settings.settings.languages = selection.including(language, false)
                }
                .rowTransition()
                RowDivider()
                    .rowTransition()
            }

            PickerRow(
                "Spoken language",
                selection: pinnedLanguage,
                current: selection.pinned?.displayName ?? String(localized: "Detect automatically"),
                description: spokenLanguageNote,
            ) {
                Text("Detect automatically").tag(Language?.none)
                Divider()
                ForEach(selection.languages, id: \.self) { language in
                    Text(language.displayName).tag(Language?.some(language))
                }
            }
        } footer: {
            Menu {
                if !suggestedLanguages.isEmpty {
                    Section("Suggested") {
                        ForEach(suggestedLanguages, id: \.self) { language in
                            AddLanguageButton(language: language, settings: settings)
                        }
                    }
                }

                Section("All Languages") {
                    ForEach(addableLanguages, id: \.self) { language in
                        AddLanguageButton(language: language, settings: settings)
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
        .animation(Motion.layout, value: selection.languages)
        .onDisappear { keyRecorder.stop() }
    }
}

private struct AddLanguageButton: View {
    let language: Language

    @Bindable var settings: SettingsModel

    private var title: String {
        language.displayName == language.nativeName ? language.displayName : "\(language.displayName) · \(language.nativeName)"
    }

    var body: some View {
        Button(title) {
            settings.settings.languages = settings.settings.languages.including(language, true)
        }
    }
}

private struct LanguageRow: View {
    let language: Language
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        SettingsRow(
            .verbatim(language.nativeName),
            description: language.nativeName == language.displayName ? nil : .verbatim(language.displayName),
        ) {
            RemoveButton(help: "Remove \(language.displayName)", action: remove)
                .disabled(!canRemove)
        }
    }
}
