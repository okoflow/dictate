import Foundation

package enum LightModeRules {
    static let framingMarks: Set<Character> = [",", "，", "、", "…", "-", "–", "—"]
    static let sentenceEnds: Set<Character> = [".", "!", "?", "。", "！", "？"]

    private static let closingMarks: Set<Character> = [",", ".", "…", "，", "。", "、", "！", "？", "：", "；"]
    private static let highMarks: Set<Character> = ["!", "?", ";", ":"]

    package static func apply(_ text: String, language: Language) -> String {
        var remover = HesitationRemover(language: language, text: text)
        let tidy = tidiedSpacing(remover.run(), language: language)
        let cased = language.hasLetterCase ? tidy.capitalizingFirstLetter() : tidy

        return withFullStop(cased, language: language)
    }

    package static func isHesitation(_ word: String, in language: Language) -> Bool {
        let letters = word.lowercased().filter { $0 != "-" && $0 != "‐" }
        let runs = runs(of: letters)

        return HesitationPattern.patterns(for: language).contains { $0.matches(runs) }
    }

    private static func runs(of text: String) -> [(letter: Character, count: Int)] {
        var runs: [(letter: Character, count: Int)] = []

        for character in text {
            if let last = runs.last, last.letter == character {
                runs[runs.count - 1].count += 1
            } else {
                runs.append((character, 1))
            }
        }

        return runs
    }

    private static func tidiedSpacing(_ text: String, language: Language) -> String {
        let noSpaceBefore = language.spacesBeforeHighPunctuation ? closingMarks : closingMarks.union(highMarks)
        var result = ""
        var hasPendingSpace = false

        for character in text {
            if character == " " || character == "\t" {
                hasPendingSpace = true

                continue
            }

            let needsSpace = hasPendingSpace && !result.isEmpty && result.last != "\n" && character != "\n"

            if needsSpace, !noSpaceBefore.contains(character) {
                result.append(" ")
            }

            hasPendingSpace = false
            result.append(character)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func withFullStop(_ text: String, language: Language) -> String {
        guard let last = text.last, last.isLetter || last.isNumber else { return text }

        return text + language.fullStop
    }
}

private struct HesitationRemover {
    let language: Language
    let segments: [TextSegment]
    var kept: [TextSegment] = []
    var previousWord: String?
    var capitalizesNextWord = false
    var index = 0

    init(language: Language, text: String) {
        self.language = language
        segments = TextSegment.split(text.replacingOccurrences(of: "...", with: "…"))
    }

    mutating func run() -> String {
        while index < segments.count {
            let segment = segments[index]
            index += 1

            if !segment.isWord {
                kept.append(segment)
            } else if isRemovable(segment) {
                removeHesitation()
            } else {
                keep(segment)
            }
        }

        return kept.map(\.text).joined()
    }

    private func isRemovable(_ word: TextSegment) -> Bool {
        let followsNumber = previousWord?.allSatisfy(\.isNumber) ?? false

        return !followsNumber && LightModeRules.isHesitation(word.text, in: language)
    }

    private mutating func keep(_ word: TextSegment) {
        let capitalizes = capitalizesNextWord && language.hasLetterCase

        kept.append(capitalizes ? TextSegment(text: word.text.capitalizingFirstLetter(), isWord: true) : word)

        capitalizesNextWord = false
        previousWord = word.text
    }

    private mutating func removeHesitation() {
        let before = kept.last?.isWord == false ? kept.removeLast().text : ""
        let after = takeSeparator()
        let isAtStart = !kept.contains(where: \.isWord)
        let isAtEnd = !segments[index...].contains(where: \.isWord)
        let separator = joinedSeparator(before, after, isAtStart: isAtStart, isAtEnd: isAtEnd)

        if !separator.isEmpty {
            kept.append(TextSegment(text: separator, isWord: false))
        }

        if isAtStart || separator.contains(where: LightModeRules.sentenceEnds.contains) {
            capitalizesNextWord = true
        }
    }

    private mutating func takeSeparator() -> String {
        guard index < segments.count, !segments[index].isWord else { return "" }

        let separator = segments[index].text
        index += 1

        return separator
    }

    private func joinedSeparator(_ before: String, _ after: String, isAtStart: Bool, isAtEnd: Bool) -> String {
        let isFraming = LightModeRules.framingMarks.contains
        let trimmedBefore = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAfter = after.trimmingCharacters(in: .whitespacesAndNewlines)
        let left = String(trimmedBefore.reversed().drop(while: isFraming).reversed())
        let right = String(trimmedAfter.drop(while: isFraming))
        let core = left.isEmpty ? right : left
        let gap = (before + after).contains("\n") ? "\n" : (language.separatesWordsWithSpaces ? " " : "")

        if isAtStart {
            return ""
        }

        return isAtEnd ? core : core + gap
    }
}
