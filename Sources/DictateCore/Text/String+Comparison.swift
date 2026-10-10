import Foundation

extension String {
    private static let ignoredCategories: Set<Unicode.GeneralCategory> = [
        .connectorPunctuation,
        .dashPunctuation,
        .openPunctuation,
        .closePunctuation,
        .initialPunctuation,
        .finalPunctuation,
        .otherPunctuation,
        .mathSymbol,
        .currencySymbol,
        .modifierSymbol,
        .otherSymbol,
    ]

    func normalizedForComparison(in language: Language) -> String {
        let lowered = precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: language.code))
            .replacingOccurrences(of: "ё", with: "е")
        let kept = String(String.UnicodeScalarView(lowered.unicodeScalars.filter {
            !Self.ignoredCategories.contains($0.properties.generalCategory)
        }))
        let words = kept.split(whereSeparator: \.isWhitespace)

        return language.hasLooseWordSpacing ? words.joined() : words.joined(separator: " ")
    }
}
