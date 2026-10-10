import DictateCore
import SwiftUI

package struct MenuContent: View {
    private let model: AppModel

    package init(model: AppModel) {
        self.model = model
    }

    package var body: some View {
        Text(model.status.title(key: model.settings.settings.pushToTalkKey))

        if model.needsSetup {
            Button("Finish Setup…") { model.windows.showOnboarding() }
        }

        if model.speechModel.state.canRetry {
            Button("Retry Speech Model") { model.speechModel.retry() }
        }

        Divider()

        ModeMenu(settings: model.settings, shortcutTitle: model.modeSwitcher.shortcutTitle)

        if let app = model.frontmostApp.app {
            AppModeMenu(app: app, settings: model.settings)
        }

        LanguageMenu(settings: model.settings) { model.windows.showSettings(.dictation) }

        Divider()

        Button("Copy Last Transcript") { model.copyLastTranscript() }
            .disabled(model.dictation.latestTranscript == nil)

        RecentMenu(history: model.history, copy: model.copy) { model.windows.showSettings(.history) }

        Divider()

        Button("Settings…") { model.windows.showSettings() }
            .keyboardShortcut(",")

        Button("Quit Dictate") { model.quit() }
            .keyboardShortcut("q")
    }
}

private struct ModeMenu: View {
    @Bindable var settings: SettingsModel

    let shortcutTitle: String

    var body: some View {
        Menu("Mode: \(settings.settings.mode.title)") {
            Picker("Mode", selection: $settings.settings.mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.isCloud ? "\(mode.title) ☁︎" : mode.title).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            Divider()

            Text("Next mode: \(shortcutTitle)")
        }
    }
}

private struct AppModeMenu: View {
    let app: FrontmostAppTracker.App

    @Bindable var settings: SettingsModel

    private var ownMode: Mode? {
        settings.settings.appModes.mode(for: app.bundleIdentifier)
    }

    private var mode: Binding<Mode?> {
        Binding(
            get: { ownMode },
            set: { settings.settings.appModes.set($0, for: app.bundleIdentifier) },
        )
    }

    var body: some View {
        Menu("Mode in \(app.name): \(ownMode?.title ?? "Same")") {
            Picker("Mode in \(app.name)", selection: mode) {
                Text("Same as Mode (\(settings.settings.mode.title))").tag(Mode?.none)
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(Mode?.some(mode))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }
}

private struct LanguageMenu: View {
    @Bindable var settings: SettingsModel

    let chooseLanguages: () -> Void

    private var languageNames: String {
        settings.settings.languages.languages.map(\.name).joined(separator: ", ")
    }

    private var pinned: Binding<Language?> {
        Binding(
            get: { settings.settings.languages.pinned },
            set: { settings.settings.languages = settings.settings.languages.pinning($0) },
        )
    }

    var body: some View {
        Menu("Language: \(settings.settings.languages.pinned?.name ?? "Automatic")") {
            Picker("Language", selection: pinned) {
                Text("Automatic (\(languageNames))").tag(Language?.none)
                ForEach(settings.settings.languages.languages, id: \.self) { language in
                    Text(language.name).tag(Language?.some(language))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            Divider()

            Button("Choose Languages…", action: chooseLanguages)
        }
    }
}

private struct RecentMenu: View {
    let history: HistoryModel
    let copy: (DictationHistory.Entry) -> Void
    let showHistory: () -> Void

    var body: some View {
        Menu("Recent") {
            let entries = history.recentEntries(limit: 5)

            if entries.isEmpty {
                Text("Nothing yet")
            }

            ForEach(entries.indices, id: \.self) { index in
                Button(entries[index].preview) { copy(entries[index]) }
            }

            Divider()

            Button("Show History…", action: showHistory)
        }
    }
}
