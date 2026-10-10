package enum HallucinationFilter {
    package static let minimumAverageLogProbability = -1.5
    package static let maximumCompressionRatio = 2.4

    private static let enclosingPairs: [(open: Character, close: Character)] = [
        ("[", "]"),
        ("(", ")"),
        ("（", "）"),
        ("【", "】"),
        ("*", "*"),
    ]

    package static func keepsSegment(averageLogProbability: Double, compressionRatio: Double) -> Bool {
        averageLogProbability >= minimumAverageLogProbability && compressionRatio <= maximumCompressionRatio
    }

    package static func isHallucination(_ text: String, in language: Language, prompt: String?) -> Bool {
        isOnlySoundTags(text) || isEcho(of: prompt, in: text, language: language) || isStockPhrase(text, in: language)
    }

    private static func isOnlySoundTags(_ text: String) -> Bool {
        var depth: [Character] = []
        var hasSpokenCharacter = false

        for character in text where character != "♪" {
            if let pair = enclosingPairs.first(where: { $0.close == character }), depth.last == pair.open {
                depth.removeLast()
            } else if let pair = enclosingPairs.first(where: { $0.open == character }) {
                depth.append(pair.open)
            } else if depth.isEmpty, character.isLetter || character.isNumber {
                hasSpokenCharacter = true
            }
        }

        return !hasSpokenCharacter
    }

    private static func isEcho(of prompt: String?, in text: String, language: Language) -> Bool {
        guard let prompt else { return false }

        let normalized = text.normalizedForComparison(in: language)
        let normalizedPrompt = prompt.normalizedForComparison(in: language)
        let isSubstantial = !normalized.isEmpty && normalized.count * 2 >= normalizedPrompt.count

        return isSubstantial && normalizedPrompt.contains(normalized)
    }

    private static func isStockPhrase(_ text: String, in language: Language) -> Bool {
        let normalized = text.normalizedForComparison(in: language)

        return StockPhrase.phrases(for: language).contains { phrase in
            let known = phrase.text.normalizedForComparison(in: language)
            guard normalized.hasPrefix(known) else { return false }

            let rest = normalized.dropFirst(known.count)

            return language.hasLooseWordSpacing
                ? rest.count <= phrase.trailingWords * 3
                : rest.split(separator: " ").count <= phrase.trailingWords
        }
    }
}
