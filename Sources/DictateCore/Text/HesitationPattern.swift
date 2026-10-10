struct HesitationPattern: Sendable {
    struct Run: Sendable {
        let letter: Character
        let minimumCount: Int
    }

    let runs: [Run]

    init(_ runs: (Character, Int)...) {
        self.runs = runs.map { Run(letter: $0.0, minimumCount: $0.1) }
    }

    static func patterns(for language: Language) -> [HesitationPattern] {
        switch language {
        case .chinese: chinese
        case .dutch: dutch
        case .english: english
        case .french: french
        case .german: german
        case .italian: italian
        case .japanese: japanese
        case .korean: korean
        case .polish: polish
        case .portuguese: portuguese
        case .russian: russian
        case .spanish: spanish
        case .ukrainian: ukrainian
        }
    }

    func matches(_ runs: [(letter: Character, count: Int)]) -> Bool {
        self.runs.count == runs.count && zip(self.runs, runs).allSatisfy { $0.letter == $1.letter && $1.count >= $0.minimumCount }
    }
}

extension HesitationPattern {
    fileprivate static let chinese = [
        HesitationPattern(("呃", 1)),
        HesitationPattern(("额", 1)),
        HesitationPattern(("嗯", 1)),
    ]

    fileprivate static let dutch = [
        HesitationPattern(("e", 1), ("h", 1)),
        HesitationPattern(("e", 1), ("h", 1), ("m", 1)),
        HesitationPattern(("u", 1), ("h", 1)),
        HesitationPattern(("u", 1), ("h", 1), ("m", 1)),
        HesitationPattern(("h", 1), ("m", 1)),
    ]

    fileprivate static let english = [
        HesitationPattern(("u", 1), ("m", 1)),
        HesitationPattern(("u", 1), ("h", 1)),
        HesitationPattern(("u", 1), ("h", 1), ("m", 1)),
        HesitationPattern(("e", 1), ("r", 1)),
        HesitationPattern(("e", 1), ("r", 1), ("m", 1)),
        HesitationPattern(("h", 1), ("m", 1)),
        HesitationPattern(("m", 2)),
    ]

    fileprivate static let french = [
        HesitationPattern(("e", 1), ("u", 1), ("h", 1)),
        HesitationPattern(("h", 1), ("e", 1), ("u", 1)),
        HesitationPattern(("h", 1), ("u", 1), ("m", 1)),
        HesitationPattern(("h", 1), ("m", 1)),
    ]

    fileprivate static let german = [
        HesitationPattern(("ä", 1), ("h", 1)),
        HesitationPattern(("ä", 1), ("h", 1), ("m", 1)),
        HesitationPattern(("ö", 1), ("h", 1)),
        HesitationPattern(("ö", 1), ("h", 1), ("m", 1)),
        HesitationPattern(("h", 1), ("m", 1)),
    ]

    fileprivate static let italian = [
        HesitationPattern(("e", 1), ("h", 1)),
        HesitationPattern(("e", 1), ("h", 1), ("m", 1)),
        HesitationPattern(("m", 2)),
    ]

    fileprivate static let japanese = [
        HesitationPattern(("え", 1), ("ー", 1)),
        HesitationPattern(("え", 1), ("ー", 1), ("と", 1)),
        HesitationPattern(("え", 1), ("っ", 1), ("と", 1)),
        HesitationPattern(("え", 2), ("と", 1)),
        HesitationPattern(("あ", 1), ("の", 1), ("ー", 1)),
        HesitationPattern(("う", 1), ("ー", 1), ("ん", 1)),
        HesitationPattern(("ん", 1), ("ー", 1)),
    ]

    fileprivate static let korean = [
        HesitationPattern(("음", 1)),
        HesitationPattern(("으", 1), ("음", 1)),
        HesitationPattern(("어", 1)),
        HesitationPattern(("흠", 1)),
    ]

    fileprivate static let polish = [
        HesitationPattern(("y", 2)),
        HesitationPattern(("e", 2)),
        HesitationPattern(("h", 1), ("m", 1)),
    ]

    fileprivate static let portuguese = [
        HesitationPattern(("h", 1), ("u", 1), ("m", 1)),
        HesitationPattern(("h", 1), ("m", 1)),
        HesitationPattern(("a", 1), ("h", 1), ("n", 1)),
        HesitationPattern(("h", 1), ("ã", 1)),
    ]

    fileprivate static let russian = [
        HesitationPattern(("э", 1)),
        HesitationPattern(("э", 1), ("м", 1)),
        HesitationPattern(("м", 2)),
        HesitationPattern(("х", 1), ("м", 1)),
    ]

    fileprivate static let spanish = [
        HesitationPattern(("e", 1), ("h", 1)),
        HesitationPattern(("e", 1), ("h", 1), ("m", 1)),
        HesitationPattern(("e", 1), ("m", 1)),
        HesitationPattern(("m", 2)),
    ]

    fileprivate static let ukrainian = [
        HesitationPattern(("е", 1)),
        HesitationPattern(("е", 1), ("м", 1)),
        HesitationPattern(("м", 2)),
        HesitationPattern(("г", 1), ("м", 1)),
        HesitationPattern(("х", 1), ("м", 1)),
    ]
}
