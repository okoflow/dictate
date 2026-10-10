struct HesitationPattern: Sendable {
    struct Run: Sendable {
        let letter: Character
        let count: Int
    }

    private static let patternsByLanguage: [Language: [HesitationPattern]] = shortestSpellings
        .mapValues { $0.map(HesitationPattern.init(shortestSpelling:)) }

    let runs: [Run]

    init(shortestSpelling: String) {
        runs = Self.runs(of: shortestSpelling)
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
        .chinese: ["呃", "额", "嗯"],
        .dutch: ["eh", "ehm", "uh", "uhm", "hm"],
        .english: ["um", "uh", "uhm", "er", "erm", "hm", "mm"],
        .french: ["euh", "heu", "hum", "hm"],
        .german: ["äh", "ähm", "öh", "öhm", "hm"],
        .italian: ["eh", "ehm", "mm"],
        .japanese: ["えー", "えーと", "えっと", "ええと", "あのー", "うーん", "んー"],
        .korean: ["음", "으음", "어", "흠"],
        .polish: ["yy", "ee", "hm"],
        .portuguese: ["hum", "hm", "ahn", "hã"],
        .russian: ["э", "эм", "мм", "хм"],
        .spanish: ["eh", "ehm", "em", "mm"],
        .ukrainian: ["е", "ем", "мм", "гм", "хм"],
    ]
}
