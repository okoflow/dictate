import DictateCore

struct DictationJob {
    let samples: [Float]
    let language: Language?
    let mode: Mode
    let setup: RewriteSetup
    let vocabulary: Vocabulary
    let target: FocusTarget
    let selection: String?
    let key: PushToTalkKey
    let pastes: Bool
    let allowsAI: Bool

    init(
        samples: [Float],
        target: FocusTarget,
        selection: String?,
        settings: Settings,
        vocabulary: Vocabulary,
        allowsAI: Bool,
    ) {
        let mode = settings.mode(for: target.bundleIdentifier)

        self.samples = samples
        language = settings.languages.forcedLanguage
        self.mode = mode
        setup = RewriteSetup(
            provider: settings.modelProvider,
            instructions: settings.instructions.text(for: mode),
            translation: settings.translation,
            localServer: settings.localServer,
        )
        self.vocabulary = vocabulary
        self.target = target
        self.selection = selection
        key = selection == nil ? settings.pushToTalkKey : settings.editKey ?? settings.pushToTalkKey
        pastes = settings.pastesIntoFocusedField
        self.allowsAI = allowsAI
    }
}
