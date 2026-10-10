import DictateCore

struct DictationJob {
    let samples: [Float]
    let language: Language?
    let mode: Mode
    let setup: RewriteSetup
    let vocabulary: Vocabulary
    let target: FocusTarget
    let key: PushToTalkKey
    let pastes: Bool

    init(samples: [Float], target: FocusTarget, settings: Settings, vocabulary: Vocabulary) {
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
        key = settings.pushToTalkKey
        pastes = settings.pastesIntoFocusedField
    }
}
