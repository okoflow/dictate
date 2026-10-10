package struct Settings: Codable, Equatable, Sendable {
    package var mode = Mode.light
    package var languages = LanguageSelection(languages: [.english])
    package var appModes = AppModeOverrides()
    package var cloudProvider = CloudProvider.claude
    package var instructions = ModeInstructions()
    package var pushToTalkKey = PushToTalkKey.rightOption
    package var handsFreeDoubleTap = true
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
        cloudProvider = try container.decodeIfPresent(CloudProvider.self, forKey: .cloudProvider) ?? defaults.cloudProvider
        instructions = try container.decodeIfPresent(ModeInstructions.self, forKey: .instructions) ?? defaults.instructions
        pushToTalkKey = try container.decodeIfPresent(PushToTalkKey.self, forKey: .pushToTalkKey) ?? defaults.pushToTalkKey
        handsFreeDoubleTap = try container.decodeIfPresent(Bool.self, forKey: .handsFreeDoubleTap) ?? defaults.handsFreeDoubleTap
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
