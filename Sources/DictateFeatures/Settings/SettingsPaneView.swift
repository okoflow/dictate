import SwiftUI

struct SettingsPaneView: View {
    private let model: AppModel
    private let state: SettingsWindowState

    init(model: AppModel, state: SettingsWindowState) {
        self.model = model
        self.state = state
    }

    var body: some View {
        SettingsPage(state.selection.title) {
            content
        }
        .id(state.selection)
    }

    @ViewBuilder
    private var content: some View {
        switch state.selection {
        case .general:
            GeneralSettingsPane(settings: model.settings, permissions: model.permissions)

        case .dictation:
            DictationSettingsPane(settings: model.settings, speechModel: model.speechModel, keyRecorder: model.keyRecorder)

        case .writing:
            WritingSettingsPane(
                settings: model.settings,
                apiKeys: model.apiKeys,
                shortcutTitle: model.modeSwitcher.shortcutTitle,
                state: state,
            )

        case .aiModels:
            AIModelsSettingsPane(settings: model.settings, apiKeys: model.apiKeys)

        case .dictionary:
            DictionarySettingsPane(vocabulary: model.vocabulary)

        case .history:
            HistorySettingsPane(settings: model.settings, history: model.history, state: state, copy: model.copy)

        case .about:
            AboutSettingsPane()
        }
    }
}
