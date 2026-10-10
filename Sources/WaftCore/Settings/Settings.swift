package struct Settings: Codable, Equatable, Sendable {
    private enum LegacyKeys: String, CodingKey {
        case cloudProvider
    }

    package var mode = Mode.light
    package var languages = LanguageSelection(languages: [.english])
    package var appModes = AppModeOverrides()
    package var modelProvider = ModelProvider.cloud(.claude)
    package var localServer = LocalServer()
    package var instructions = ModeInstructions()
    package var translation = Translation()
    package var pushToTalkKey = PushToTalkKey.rightOption
    package var handsFreeDoubleTap = true
    package var editKey: PushToTalkKey?
    package var pastesIntoFocusedField = true
    package var keepsHistory = true
    package var historyRetention = HistoryRetention.month
    package var historyLimit = DictationHistory.defaultLimit
    package var playsSounds = true
    package var showsMenuBarIcon = true
    package var microphoneID: String?
    package var hasCompletedSetup = false

    package init(languages: LanguageSelection) {
        self.languages = languages
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings(languages: LanguageSelection(languages: [.english]))

        mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? defaults.mode
        languages = try container.decodeIfPresent(LanguageSelection.self, forKey: .languages) ?? defaults.languages
        appModes = try container.decodeIfPresent(AppModeOverrides.self, forKey: .appModes) ?? defaults.appModes
        modelProvider = try container.decodeIfPresent(ModelProvider.self, forKey: .modelProvider)
            ?? decoder.container(keyedBy: LegacyKeys.self).decodeIfPresent(ModelProvider.self, forKey: .cloudProvider)
            ?? defaults.modelProvider
        localServer = try container.decodeIfPresent(LocalServer.self, forKey: .localServer) ?? defaults.localServer
        instructions = try container.decodeIfPresent(ModeInstructions.self, forKey: .instructions) ?? defaults.instructions
        translation = try container.decodeIfPresent(Translation.self, forKey: .translation) ?? defaults.translation
        pushToTalkKey = try container.decodeIfPresent(PushToTalkKey.self, forKey: .pushToTalkKey) ?? defaults.pushToTalkKey
        handsFreeDoubleTap = try container.decodeIfPresent(Bool.self, forKey: .handsFreeDoubleTap) ?? defaults.handsFreeDoubleTap
        editKey = try container.decodeIfPresent(PushToTalkKey.self, forKey: .editKey)
        pastesIntoFocusedField = try container.decodeIfPresent(Bool.self, forKey: .pastesIntoFocusedField)
            ?? defaults.pastesIntoFocusedField
        keepsHistory = try container.decodeIfPresent(Bool.self, forKey: .keepsHistory) ?? defaults.keepsHistory
        historyRetention = try container.decodeIfPresent(HistoryRetention.self, forKey: .historyRetention)
            ?? defaults.historyRetention
        historyLimit = try container.decodeIfPresent(Int.self, forKey: .historyLimit)
            .flatMap { DictationHistory.limits.contains($0) ? $0 : nil } ?? defaults.historyLimit
        playsSounds = try container.decodeIfPresent(Bool.self, forKey: .playsSounds) ?? defaults.playsSounds
        showsMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showsMenuBarIcon) ?? defaults.showsMenuBarIcon
        microphoneID = try container.decodeIfPresent(String.self, forKey: .microphoneID)
        hasCompletedSetup = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedSetup) ?? defaults.hasCompletedSetup
    }

    package func mode(for bundleIdentifier: String?) -> Mode {
        appModes.mode(for: bundleIdentifier) ?? mode
    }
}
