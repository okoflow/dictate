import Foundation

/// Character error rate for the accuracy checks, with the normalisation that makes it fair:
/// case, punctuation, spacing and (for Korean) word breaks are not recognition errors.
public enum TextMetrics {
    /// Lowercases (by the language's rules), maps ё to е, drops punctuation and symbols and collapses whitespace.
    /// Korean is compared without spaces at all, because its spacing rules are loose and Whisper
    /// and people disagree on them.
    public static func normalise(_ text: String, language: Language) -> String {
        let composed = text.precomposedStringWithCanonicalMapping
        let lowered = composed.lowercased(with: Locale(identifier: language.rawValue))
            .replacingOccurrences(of: "ё", with: "е")
        let letters = lowered.unicodeScalars.filter { !punctuation.contains($0.properties.generalCategory) }
        let kept = String(String.UnicodeScalarView(letters))
        let words = kept.split(whereSeparator: \.isWhitespace)
        return language == .ko ? words.joined() : words.joined(separator: " ")
    }

    /// Edit distance between the normalised texts divided by the length of the normalised reference.
    /// Not capped at 1: a hypothesis much longer than the reference can exceed it.
    public static func cer(reference: String, hypothesis: String, language: Language) -> Double {
        let expected = Array(normalise(reference, language: language))
        let actual = Array(normalise(hypothesis, language: language))
        if expected.isEmpty {
            return actual.isEmpty ? 0 : 1
        }
        return Double(editDistance(expected, actual)) / Double(expected.count)
    }

    /// The lowest CER over the reference and its `alternatives` (digit forms, "3 часа" vs "три часа").
    public static func cer(reference: String, alternatives: [String], hypothesis: String, language: Language) -> Double {
        ([reference] + alternatives).map { cer(reference: $0, hypothesis: hypothesis, language: language) }.min() ?? 1
    }

    private static let punctuation: Set<Unicode.GeneralCategory> = [
        .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
        .initialPunctuation, .finalPunctuation, .otherPunctuation,
        // Symbols too ("+", "$", "°", "№"): Whisper and a transcript disagree on them as often as on commas.
        .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol,
    ]

    /// Levenshtein distance, two rows at a time.
    private static func editDistance(_ lhs: [Character], _ rhs: [Character]) -> Int {
        var previous = Array(0 ... rhs.count)
        for (row, left) in lhs.enumerated() {
            var current = [row + 1]
            for (column, right) in rhs.enumerated() {
                current.append(min(previous[column + 1] + 1, current[column] + 1, previous[column] + (left == right ? 0 : 1)))
            }
            previous = current
        }
        return previous[rhs.count]
    }
}
