import DictateCore

enum DictationOutcome {
    case pasted(ProcessedText)
    case copied(ProcessedText)
    case blockedInPasswordField
    case noSpeech
    case failed(String)

    private static func copiedDetail(_ processed: ProcessedText, provider: CloudProvider) -> String {
        let fallback = processed.fallback?.message(for: provider)

        return ["Copied: press ⌘V to paste", fallback].compactMap(\.self).joined(separator: "\n")
    }

    func message(for provider: CloudProvider) -> HUDMessage {
        switch self {
        case let .pasted(processed):
            HUDMessage(kind: .pasted, title: processed.text, detail: processed.fallback?.message(for: provider))

        case let .copied(processed):
            HUDMessage(kind: .copied, title: processed.text, detail: Self.copiedDetail(processed, provider: provider))

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
}
