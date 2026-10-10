import DictateCore

struct DictationJob {
    let samples: [Float]
    let language: Language?
    let mode: Mode
    let vocabulary: Vocabulary
    let target: FocusTarget
    let key: PushToTalkKey
    let pastes: Bool
}
