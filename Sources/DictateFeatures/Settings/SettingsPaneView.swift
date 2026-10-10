import SwiftUI

struct SettingsPaneView: View {
    private let model: AppModel
    private let navigation: SettingsNavigation

    init(model: AppModel, navigation: SettingsNavigation) {
        self.model = model
        self.navigation = navigation
    }

    var body: some View {
        SettingsPage(navigation.selection.title) {
            content
        }
        .id(navigation.selection)
    }

    @ViewBuilder
    private var content: some View {
        switch navigation.selection {
        case .general:
            GeneralSettingsPane(settings: model.settings, permissions: model.permissions)
        case .dictation:
            DictationSettingsPane(settings: model.settings, speechModel: model.speechModel)
        case .modes:
            ModesSettingsPane(settings: model.settings, apiKeys: model.apiKeys, shortcutTitle: model.modeSwitcher.shortcutTitle)
        case .dictionary:
            DictionarySettingsPane(vocabulary: model.vocabulary)
        case .history:
            HistorySettingsPane(settings: model.settings, history: model.history, copy: model.copy)
        case .about:
            AboutSettingsPane()
        }
    }
}
