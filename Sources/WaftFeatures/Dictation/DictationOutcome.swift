import Foundation
import WaftCore

enum DictationOutcome {
    case pasted(ProcessedText)
    case copied(ProcessedText)
    case blockedInPasswordField
    case noSpeech
    case failed(String)
    case editFailed(String)

    private static func copiedDetail(_ processed: ProcessedText, provider: ModelProvider) -> String {
        let fallback = processed.fallback?.message(for: provider)

        return [String(localized: "Copied: press ⌘V to paste"), fallback].compactMap(\.self).joined(separator: "\n")
    }

    func message(for provider: ModelProvider) -> HUDMessage {
        switch self {
        case let .pasted(processed):
            HUDMessage(kind: .pasted, title: processed.text, detail: processed.fallback?.message(for: provider))

        case let .copied(processed):
            HUDMessage(kind: .copied, title: processed.text, detail: Self.copiedDetail(processed, provider: provider))

        case .blockedInPasswordField:
            HUDMessage(
                kind: .warning,
                title: String(localized: "Not pasted into a password field"),
                detail: String(localized: "Copy it from the menu: Copy Last Transcript"),
            )

        case .noSpeech:
            HUDMessage(kind: .info, title: String(localized: "Didn't catch that"))

        case let .failed(reason):
            HUDMessage(kind: .warning, title: String(localized: "Transcription failed"), detail: reason)

        case let .editFailed(reason):
            HUDMessage(kind: .warning, title: String(localized: "Couldn't edit the text"), detail: reason)
        }
    }
}
