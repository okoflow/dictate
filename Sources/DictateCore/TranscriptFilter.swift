import Foundation

/// Drops what Whisper makes up when it is given noise: low-confidence output and the stock phrases it
/// learned from subtitles ("Thanks for watching"). Applied to the finished text, after the audio gate.
public enum TranscriptFilter {
    /// Whisper's thresholds, loosened for the log-probability: below this the decoder was guessing.
    public static let minimumAverageLogProbability = -1.5
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

    /// Whether one decoded segment is worth keeping. Judged per segment, so one bad stretch of a long
    /// dictation does not take the good ones with it.
    public static func keepsSegment(averageLogProbability: Double, compressionRatio: Double) -> Bool {
        averageLogProbability >= minimumAverageLogProbability && compressionRatio <= maximumCompressionRatio
    }

    /// Only when the *whole* result is the phrase: the same words inside a real sentence are kept.
    public static func isKnownHallucination(_ text: String, language: Language) -> Bool {
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

public extension TranscriptFilter {
    /// Safety net for Whisper's style drift: a Russian or English text with no capital letter and no
    /// punctuation at all gets its first letter capitalised. Nothing else is invented; Korean is untouched.
    static func capitalisedIfUnstyled(_ text: String, language: Language) -> String {
        guard language != .ko else { return text }
        let hasCapital = text.contains { $0.isUppercase }
        let hasPunctuation = text.contains { $0.isPunctuation }
        guard !hasCapital, !hasPunctuation, let index = text.firstIndex(where: \.isLetter) else { return text }
        return text.replacingCharacters(in: index ... index, with: text[index].uppercased())
    }
}
