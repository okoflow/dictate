package struct LanguageSelection: Codable, Equatable, Sendable {
    private static let maximumPreferredCount = 3

    package private(set) var languages: [Language]
    package private(set) var pinned: Language?

    package var forcedLanguage: Language? {
        pinned ?? (languages.count == 1 ? languages.first : nil)
    }

    package init(languages: [Language], pinned: Language? = nil) {
        let ordered = Language.allCases.filter(languages.contains)
        let enabled = ordered.isEmpty ? [Language.english] : ordered

        self.languages = enabled
        self.pinned = pinned.flatMap { enabled.contains($0) ? $0 : nil }
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let languages = try container.decodeIfPresent([Language].self, forKey: .languages) ?? []
        let pinned = try container.decodeIfPresent(Language.self, forKey: .pinned)

        self.init(languages: languages, pinned: pinned)
    }

    package static func preferred(by localeIdentifiers: [String]) -> LanguageSelection {
        var languages: [Language] = []

        for language in localeIdentifiers.compactMap(Language.init(localeIdentifier:)) where !languages.contains(language) {
            languages.append(language)
        }

        let preferred = Array(languages.prefix(Self.maximumPreferredCount))

        return LanguageSelection(languages: preferred.contains(.english) ? preferred : preferred + [.english])
    }

    package func including(_ language: Language, _ isIncluded: Bool) -> LanguageSelection {
        let languages = isIncluded ? languages + [language] : languages.filter { $0 != language }

        return languages.isEmpty ? self : LanguageSelection(languages: languages, pinned: pinned)
    }

    package func pinning(_ language: Language?) -> LanguageSelection {
        LanguageSelection(languages: languages, pinned: language)
    }
}
