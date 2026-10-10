struct HesitationPattern: Sendable {
    struct Run: Sendable {
        let letter: Character
        let count: Int
    }

    private static let patternsByLanguage: [Language: [HesitationPattern]] = shortestSpellings
        .reduce(into: [:]) { patterns, entry in
            patterns[entry.key] = entry.value.map { HesitationPattern(shortestSpelling: $0, in: entry.key) }
        }

    let runs: [Run]

    init(shortestSpelling: String, in language: Language) {
        runs = Self.runs(of: shortestSpelling.folded(in: language))
    }

    static func patterns(for language: Language) -> [HesitationPattern] {
        patternsByLanguage[language] ?? []
    }

    static func runs(of text: String) -> [Run] {
        var runs: [Run] = []

        for letter in text {
            if let last = runs.last, last.letter == letter {
                runs[runs.count - 1] = Run(letter: letter, count: last.count + 1)
            } else {
                runs.append(Run(letter: letter, count: 1))
            }
        }

        return runs
    }

    func matches(_ runs: [Run]) -> Bool {
        self.runs.count == runs.count && zip(self.runs, runs).allSatisfy { $0.letter == $1.letter && $1.count >= $0.count }
    }
}

extension HesitationPattern {
    fileprivate static let shortestSpellings: [Language: [String]] = [
        .arabic: ["إمم", "امم", "ممم"],
        .azerbaijani: ["əə", "hm", "mm"],
        .bosnian: ["eee", "ehm", "hm", "mm"],
        .bulgarian: ["ъ", "еее", "хм", "мм"],
        .catalan: ["eh", "ehm", "emm", "hm", "mm"],
        .chinese: ["呃", "额", "嗯"],
        .croatian: ["eee", "ehm", "hm", "mm"],
        .czech: ["eee", "éé", "ehm", "hm", "mm"],
        .danish: ["øh", "øhm", "æh", "æhm", "hm", "mm"],
        .dutch: ["eh", "ehm", "uh", "uhm", "hm"],
        .english: ["um", "uh", "uhm", "er", "erm", "hm", "mm"],
        .estonian: ["ee", "õõ", "hm", "mm"],
        .filipino: ["um", "uh", "uhm", "hm", "mm"],
        .finnish: ["öö", "öh", "hm", "mm"],
        .french: ["euh", "heu", "hum", "hm"],
        .galician: ["eh", "ehm", "hm", "mm"],
        .german: ["äh", "ähm", "öh", "öhm", "hm"],
        .greek: ["ε", "εμ", "χμ", "μμ"],
        .hebrew: ["אה", "אממ", "הממ", "ממ"],
        .hindi: ["उम", "हम्म"],
        .hungarian: ["őő", "öö", "hm", "mm"],
        .indonesian: ["ee", "ehm", "emm", "hemm", "hm", "mm"],
        .italian: ["eh", "ehm", "mm"],
        .japanese: ["えー", "えーと", "えっと", "ええと", "あのー", "うーん", "んー"],
        .korean: ["음", "으음", "어", "흠"],
        .latvian: ["ee", "hm", "mm"],
        .lithuanian: ["ee", "hm", "mm"],
        .macedonian: ["еее", "хм", "мм"],
        .malay: ["ee", "ehm", "emm", "hemm", "hm", "mm"],
        .norwegian: ["eh", "ehm", "øh", "øhm", "æh", "æhm", "hm", "mm"],
        .polish: ["yy", "ee", "hm"],
        .portuguese: ["hum", "hm", "ahn", "hã"],
        .romanian: ["ă", "î", "ăm", "hm", "mm"],
        .russian: ["э", "эм", "мм", "хм"],
        .serbian: ["eee", "ehm", "hm", "mm", "еее", "ехм", "хм", "мм"],
        .slovak: ["eee", "ehm", "hm", "mm"],
        .slovenian: ["eee", "ehm", "hm", "mm"],
        .spanish: ["eh", "ehm", "em", "mm"],
        .swedish: ["eh", "ehm", "öh", "öhm", "hm", "mm"],
        .tamil: ["ம்ம்", "ஹ்ம்"],
        .thai: ["เอ่อ", "เอิ่ม", "อ่า", "อืม"],
        .turkish: ["ıı", "eee", "hım", "hm", "mm"],
        .ukrainian: ["е", "ем", "мм", "гм", "хм"],
        .urdu: ["امم", "ہمم", "ممم"],
        .vietnamese: ["ờ", "ờm", "ừm", "ưm", "hm", "mm"],
    ]
}
