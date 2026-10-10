import DictateCore

struct FeatureModels {
    let settings: SettingsModel
    let permissions: PermissionMonitor
    let speechModel: SpeechModelController
    let vocabulary: VocabularyModel
    let history: HistoryModel
    let hud: HUDController

    init(dependencies: AppDependencies) {
        settings = SettingsModel(
            store: dependencies.settingsStore,
            loginItem: dependencies.loginItem,
            audioInputs: dependencies.audioInputs,
        )
        permissions = PermissionMonitor(provider: dependencies.permissions)
        speechModel = SpeechModelController(
            transcriber: dependencies.transcriber,
            languages: settings.settings.languages.languages,
        )
        vocabulary = VocabularyModel(store: dependencies.vocabularyStore, fileURL: dependencies.vocabularyFile)
        history = HistoryModel(store: dependencies.historyStore)
        hud = HUDController()
    }

    func makeQueue(dependencies: AppDependencies) -> DictationQueue {
        DictationQueue(
            transcriber: dependencies.transcriber,
            rewriters: dependencies.rewriters,
            inserter: dependencies.inserter,
            clipboard: dependencies.clipboard,
            history: history,
            settings: settings,
            hud: hud,
        )
    }
}
