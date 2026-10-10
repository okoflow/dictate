import SwiftUI

struct SettingsPaneView: View {
    private let pane: SettingsPane
    private let model: AppModel

    private var height: CGFloat {
        switch pane {
        case .general: 400
        case .dictation: 430
        case .modes: 770
        case .dictionary: 520
        case .history: 480
        case .about: 360
        }
    }

    init(pane: SettingsPane, model: AppModel) {
        self.pane = pane
        self.model = model
    }

    var body: some View {
        content
            .formStyle(.grouped)
            .frame(width: 560, height: height)
    }

    @ViewBuilder
    private var content: some View {
        switch pane {
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
