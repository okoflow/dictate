import Foundation

/// Drops what Whisper makes up when it is given noise: low-confidence output and the stock phrases it
/// learned from subtitles ("Thanks for watching"). Applied to the finished text, after the audio gate.
public enum TranscriptFilter {
    public enum Verdict: Equatable, Sendable {
        case keep
        case drop(String)
    }

    /// Whisper's own thresholds: below this the decoder was guessing.
    public static let minimumAverageLogProbability = -1.0
    /// Above this the text is repetitive nonsense.
    public static let maximumCompressionRatio = 2.4

    private struct Phrase {
        let text: String
        /// A prefix also matches when up to `extraWords` follow it (a credited name).
        let extraWords: Int
    }

    /// Compared after `TextMetrics.normalise`, so case, punctuation and (for Korean) spaces do not matter.
    private static let phrases: [Language: [Phrase]] = [
        .ru: [
            Phrase(text: "продолжение следует", extraWords: 0),
            Phrase(text: "спасибо за просмотр", extraWords: 0),
            Phrase(text: "субтитры сделал", extraWords: 3),
            Phrase(text: "субтитры создавал", extraWords: 3),
            Phrase(text: "редактор субтитров", extraWords: 3),
        ],
        .en: [
            Phrase(text: "thanks for watching", extraWords: 0),
            Phrase(text: "thank you for watching", extraWords: 0),
            Phrase(text: "please subscribe", extraWords: 0),
        ],
        .ko: [
            Phrase(text: "시청해 주셔서 감사합니다", extraWords: 0),
            Phrase(text: "구독과 좋아요 부탁드립니다", extraWords: 0),
        ],
    ]

    /// `averageLogProbability` and `compressionRatio` come from the decoder's segments (`nil` when unknown).
    public static func verdict(
        text: String,
        language: Language,
        averageLogProbability: Double?,
        compressionRatio: Double?
    ) -> Verdict {
        if let averageLogProbability, averageLogProbability < minimumAverageLogProbability {
            return .drop("low confidence")
        }
        if let compressionRatio, compressionRatio > maximumCompressionRatio {
            return .drop("repetitive text")
        }
        return isKnownHallucination(text, language: language) ? .drop("known hallucination") : .keep
    }

    /// Only when the *whole* result is the phrase: the same words inside a real sentence are kept.
    static func isKnownHallucination(_ text: String, language: Language) -> Bool {
        let normalised = TextMetrics.normalise(text, language: language)
        return (phrases[language] ?? []).contains { phrase in
            let known = TextMetrics.normalise(phrase.text, language: language)
            if normalised == known {
                return true
            }
            guard phrase.extraWords > 0, normalised.hasPrefix(known) else { return false }
            let rest = normalised.dropFirst(known.count).split(separator: " ")
            return rest.count <= phrase.extraWords
        }
    }
}
