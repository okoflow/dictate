import DictateCore

struct DictationJob {
    let samples: [Float]
    let language: Language?
    let mode: Mode
    let cloud: CloudRewrite
    let vocabulary: Vocabulary
    let target: FocusTarget
    let key: PushToTalkKey
    let pastes: Bool
}
