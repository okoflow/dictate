import DictateCore

enum DictationOutcome {
    case pasted(ProcessedText)
    case copied(ProcessedText)
    case blockedInPasswordField
    case noSpeech
    case failed(String)

    var message: HUDMessage {
        switch self {
        case let .pasted(processed):
            HUDMessage(kind: .pasted, title: processed.text, detail: processed.fallback?.message)

        case let .copied(processed):
            HUDMessage(kind: .copied, title: processed.text, detail: Self.copiedDetail(processed))

        case .blockedInPasswordField:
            HUDMessage(
                kind: .warning,
                title: "Not pasted into a password field",
                detail: "Copy it from the menu: Copy Last Transcript",
            )

        case .noSpeech:
            HUDMessage(kind: .info, title: "Didn't catch that")

        case let .failed(reason):
            HUDMessage(kind: .warning, title: "Transcription failed", detail: reason)
        }
    }

    private static func copiedDetail(_ processed: ProcessedText) -> String {
        ["Copied: press ⌘V to paste", processed.fallback?.message].compactMap(\.self).joined(separator: "\n")
    }
}
