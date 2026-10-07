import Foundation

/// Light mode: offline clean-up rules, no LLM. Removes hesitation sounds (ээ, мм, um, uh, 음, 어) with the
/// commas Whisper puts around them, tidies spacing, capitalises the start and ends the text with a full stop.
/// Nothing else is changed: real words, the word order and Korean word spacing (띄어쓰기) stay as spoken.
public enum LightRules {
    public static func apply(_ text: String, language: Language) -> String {
        let removed = removingHesitations(from: text, capitalises: language != .ko)
        let tidy = tidiedSpacing(removed)
        let cased = language == .ko ? tidy : capitalisingFirstLetter(tidy)
        return withFinalStop(cased)
    }

    /// Whether `word` is a hesitation sound in any of our languages: "ээ", "эм", "ммм", "хм", "um", "uhh",
    /// "erm", "hmm", "음", "으음", "어", "흠". Letters may be stretched ("эээ", "ummm") or hyphenated ("э-э").
    /// Real words are never matched: "мм" after a number is millimetres, so callers check that separately.
    public static func isHesitation(_ word: String) -> Bool {
        let letters = word.lowercased().filter { $0 != "-" && $0 != "‐" }
        let runs = runs(of: letters)
        return hesitationPatterns.contains { pattern in
            pattern.count == runs.count && zip(pattern, runs).allSatisfy { $0.letter == $1.letter && $1.count >= $0.minimum }
        }
    }

    // MARK: Hesitations

    private struct Run: Equatable {
        let letter: Character
        let minimum: Int
    }

    /// Each pattern is a sequence of letters, each repeated at least `minimum` times.
    private static let hesitationPatterns: [[Run]] = [
        // Russian: э, эм, мм, хм
        [Run(letter: "э", minimum: 1)],
        [Run(letter: "э", minimum: 1), Run(letter: "м", minimum: 1)],
        [Run(letter: "м", minimum: 2)],
        [Run(letter: "х", minimum: 1), Run(letter: "м", minimum: 1)],
        // English: um, uh, uhm, er, erm, hm, mm
        [Run(letter: "u", minimum: 1), Run(letter: "m", minimum: 1)],
        [Run(letter: "u", minimum: 1), Run(letter: "h", minimum: 1)],
        [Run(letter: "u", minimum: 1), Run(letter: "h", minimum: 1), Run(letter: "m", minimum: 1)],
        [Run(letter: "e", minimum: 1), Run(letter: "r", minimum: 1)],
        [Run(letter: "e", minimum: 1), Run(letter: "r", minimum: 1), Run(letter: "m", minimum: 1)],
        [Run(letter: "h", minimum: 1), Run(letter: "m", minimum: 1)],
        [Run(letter: "m", minimum: 2)],
        // Korean: 음, 으음, 어, 흠
        [Run(letter: "음", minimum: 1)],
        [Run(letter: "으", minimum: 1), Run(letter: "음", minimum: 1)],
        [Run(letter: "어", minimum: 1)],
        [Run(letter: "흠", minimum: 1)],
    ]

    private static func runs(of text: String) -> [(letter: Character, count: Int)] {
        var result: [(letter: Character, count: Int)] = []
        for character in text {
            if let last = result.last, last.letter == character {
                result[result.count - 1].count += 1
            } else {
                result.append((character, 1))
            }
        }
        return result
    }

    private struct Piece {
        var text: String
        let isWord: Bool
    }

    /// Splits into words (letters and digits, with inner hyphens and apostrophes: "кто-то", "don't") and the
    /// separators between them.
    private static func pieces(of text: String) -> [Piece] {
        let characters = Array(text)
        var pieces: [Piece] = []
        for (index, character) in characters.enumerated() {
            let isWordCharacter = character.isLetter || character.isNumber || character.unicodeScalars.allSatisfy {
                $0.properties.generalCategory == .nonspacingMark
            } || isInnerJoiner(at: index, in: characters)
            if let last = pieces.last, last.isWord == isWordCharacter {
                pieces[pieces.count - 1].text.append(character)
            } else {
                pieces.append(Piece(text: String(character), isWord: isWordCharacter))
            }
        }
        return pieces
    }

    private static func isInnerJoiner(at index: Int, in characters: [Character]) -> Bool {
        guard ["-", "'", "’", "‐"].contains(characters[index]), index > 0, index + 1 < characters.count else { return false }
        let before = characters[index - 1]
        let after = characters[index + 1]
        return (before.isLetter || before.isNumber) && after.isLetter
    }

    private static func removingHesitations(from text: String, capitalises: Bool) -> String {
        let all = pieces(of: text.replacingOccurrences(of: "...", with: "…"))
        var kept: [Piece] = []
        var previousWord: String?
        var capitaliseNext = false
        var index = 0
        while index < all.count {
            let piece = all[index]
            index += 1
            guard piece.isWord else {
                kept.append(piece)
                continue
            }
            let afterNumber = previousWord.map { $0.allSatisfy(\.isNumber) } ?? false
            guard isHesitation(piece.text), !afterNumber else {
                kept.append(capitaliseNext && capitalises ? capitalisingFirstLetter(piece) : piece)
                capitaliseNext = false
                previousWord = piece.text
                continue
            }
            // Drop the word and join the separators on both sides of it into one.
            let before = kept.last?.isWord == false ? kept.removeLast().text : ""
            var after = ""
            if index < all.count, !all[index].isWord {
                after = all[index].text
                index += 1
            }
            let isAtStart = !kept.contains { $0.isWord }
            let isAtEnd = !all[index...].contains { $0.isWord }
            let joined = joinedSeparator(before, after, isAtStart: isAtStart, isAtEnd: isAtEnd)
            if !joined.isEmpty {
                kept.append(Piece(text: joined, isWord: false))
            }
            if isAtStart || joined.contains(where: { ".!?".contains($0) }) {
                capitaliseNext = true
            }
        }
        return kept.map(\.text).joined()
    }

    /// The separator left after removing a word between `before` and `after`. Commas, dashes and ellipses that
    /// only framed the hesitation go; a sentence end before it stays ("Done. Um, next" → "Done. Next"), and one
    /// after it is kept only if there was none before ("we go, um." → "we go.").
    private static func joinedSeparator(_ before: String, _ after: String, isAtStart: Bool, isAtEnd: Bool) -> String {
        let framing: Set<Character> = [",", "…", "-", "–", "—"]
        var left = before.trimmingCharacters(in: .whitespacesAndNewlines)
        var right = after.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = left.last, framing.contains(last) {
            left.removeLast()
        }
        while let first = right.first, framing.contains(first) {
            right.removeFirst()
        }
        let core = left.isEmpty ? right : left
        let breaksLine = (before + after).contains("\n")
        if isAtStart {
            return ""
        }
        if isAtEnd {
            return core
        }
        if core.isEmpty {
            return breaksLine ? "\n" : " "
        }
        return core + (breaksLine ? "\n" : " ")
    }

    private static func capitalisingFirstLetter(_ piece: Piece) -> Piece {
        Piece(text: capitalisingFirstLetter(piece.text), isWord: piece.isWord)
    }

    // MARK: Tidying

    /// One space between words (newlines kept), none before punctuation, none at the ends.
    private static func tidiedSpacing(_ text: String) -> String {
        var result = ""
        var pendingSpace = false
        for character in text {
            if character == " " || character == "\t" {
                pendingSpace = true
                continue
            }
            if pendingSpace, !result.isEmpty, !",.!?;:…".contains(character), result.last != "\n", character != "\n" {
                result.append(" ")
            }
            pendingSpace = false
            result.append(character)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func capitalisingFirstLetter(_ text: String) -> String {
        guard let index = text.firstIndex(where: \.isLetter), text[index].isLowercase else { return text }
        return text.replacingCharacters(in: index ... index, with: text[index].uppercased())
    }

    /// A full stop when the text ends in a letter or a digit; any other ending (punctuation, a bracket, a
    /// quote) is left alone.
    private static func withFinalStop(_ text: String) -> String {
        guard let last = text.last, last.isLetter || last.isNumber else { return text }
        return text + "."
    }
}
