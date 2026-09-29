import Foundation

/// A short, properly written sentence handed to Whisper as the "previous text". Whisper imitates the
/// style of what came before, so a capitalised, punctuated sentence keeps its output the same way; without
/// it a long or quiet recording often comes back in lowercase with no punctuation.
public enum StylePrompt {
    /// `nil` for Korean: it has no capitals to lose, and in the bench the prompt made noisy Korean worse
    /// (25.9 % to 33.3 % character error rate) without improving its punctuation.
    public static func text(for language: Language) -> String? {
        switch language {
        case .ru: "Привет! Это пример текста: с заглавными буквами, запятыми и точками."
        case .en: "Hello! This is a sample of text, with capital letters, commas and full stops."
        case .ko: nil
        }
    }
}

/// Counts of the marks a well-written transcript has, and the comparison the bench makes with them.
public enum PunctuationMetrics {
    public struct Counts: Equatable, Sendable {
        /// Sentence-final marks: `. ! ? …` and the CJK `。`.
        public var sentenceEnds: Int
        /// Commas: `,` and the fullwidth `，` and `、`.
        public var commas: Int
    }

    public static func counts(in text: String) -> Counts {
        var counts = Counts(sentenceEnds: 0, commas: 0)
        for character in text {
            switch character {
            case ".", "!", "?", "…", "。", "！", "？": counts.sentenceEnds += 1
            case ",", "，", "、": counts.commas += 1
            default: break
            }
        }
        return counts
    }

    /// How many marks of each kind the hypothesis got right, by count (not position): at most as many as the
    /// reference has.
    public static func matched(reference: Counts, hypothesis: Counts) -> Counts {
        Counts(
            sentenceEnds: min(reference.sentenceEnds, hypothesis.sentenceEnds),
            commas: min(reference.commas, hypothesis.commas)
        )
    }

    public enum Casing: Equatable, Sendable {
        case upper
        case lower
        /// The first letter has no case (Korean), or there is no letter.
        case uncased
    }

    /// The case of the first letter of `text`.
    public static func startingCase(of text: String) -> Casing {
        guard let first = text.first(where: \.isLetter), first.isCased else { return .uncased }
        return first.isUppercase ? .upper : .lower
    }
}
