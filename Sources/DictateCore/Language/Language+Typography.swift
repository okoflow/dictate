extension Language {
    package var hasLetterCase: Bool {
        switch self {
        case .chinese, .japanese, .korean:
            false
        case .dutch, .english, .french, .german, .italian, .polish, .portuguese, .russian, .spanish, .ukrainian:
            true
        }
    }

    package var separatesWordsWithSpaces: Bool {
        switch self {
        case .chinese, .japanese:
            false
        case .dutch, .english, .french, .german, .italian, .korean, .polish, .portuguese, .russian, .spanish, .ukrainian:
            true
        }
    }

    package var hasLooseWordSpacing: Bool {
        switch self {
        case .chinese, .japanese, .korean:
            true
        case .dutch, .english, .french, .german, .italian, .polish, .portuguese, .russian, .spanish, .ukrainian:
            false
        }
    }

    package var spacesBeforeHighPunctuation: Bool {
        self == .french
    }

    package var fullStop: String {
        switch self {
        case .chinese, .japanese:
            "。"
        case .dutch, .english, .french, .german, .italian, .korean, .polish, .portuguese, .russian, .spanish, .ukrainian:
            "."
        }
    }

    package var scripts: Set<WritingScript> {
        switch self {
        case .chinese:
            [.han]
        case .japanese:
            [.han, .kana]
        case .korean:
            [.hangul]
        case .russian, .ukrainian:
            [.cyrillic]
        case .dutch, .english, .french, .german, .italian, .polish, .portuguese, .spanish:
            [.latin]
        }
    }
}
