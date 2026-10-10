import AppKit
import DictateCore
import SwiftUI

struct DictationSettingsPane: View {
    @Bindable var settings: SettingsModel

    let speechModel: SpeechModelController

    private var pinnedLanguage: Binding<Language?> {
        Binding(
            get: { settings.settings.languages.pinned },
            set: { settings.settings.languages = settings.settings.languages.pinning($0) },
        )
    }

    private var languagesFooter: String {
        let languages = settings.settings.languages.languages
        let base = "Dictate listens only for the languages you check. Fewer languages make detection faster and more accurate."
        guard languages.contains(.russian), languages.contains(.ukrainian) else { return base }

        return base + " Russian and Ukrainian sound alike, so pin one if Dictate picks the wrong language."
    }

    var body: some View {
        Form {
            Section {
                LanguageGrid(selection: $settings.settings.languages)

                Picker("Spoken language", selection: pinnedLanguage) {
                    Text("Detect automatically").tag(Language?.none)
                    Divider()
                    ForEach(settings.settings.languages.languages, id: \.self) { language in
                        Text(language.name).tag(Language?.some(language))
                    }
                }
            } header: {
                Text("Languages")
            } footer: {
                SectionNote(languagesFooter)
            }

            Section("Microphone") {
                Picker("Record from", selection: $settings.settings.microphoneID) {
                    Text("System default").tag(String?.none)
                    ForEach(settings.microphones) { microphone in
                        Text(microphone.name).tag(String?.some(microphone.id))
                    }
                }
            }

            Section("Speech model") {
                SpeechModelRow(controller: speechModel)
            }
        }
    }
}

private struct LanguageGrid: View {
    private static let columnCount = 4

    private static var rows: [[Language]] {
        let languages = Language.allCases.sorted { $0.nativeName.localizedStandardCompare($1.nativeName) == .orderedAscending }

        return stride(from: 0, to: languages.count, by: columnCount).map { start in
            Array(languages[start ..< min(start + columnCount, languages.count)])
        }
    }

    @Binding var selection: LanguageSelection

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            ForEach(Self.rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { language in
                        Toggle(isOn: binding(for: language)) {
                            Text(language.nativeName)
                        }
                        .toggleStyle(.checkbox)
                        .help(language.name)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func binding(for language: Language) -> Binding<Bool> {
        Binding(
            get: { selection.languages.contains(language) },
            set: { selection = selection.including(language, $0) },
        )
    }
}

private struct SpeechModelRow: View {
    let controller: SpeechModelController

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(controller.state.statusText)
                Text("Whisper large-v3 turbo, 630 MB, runs on this Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
