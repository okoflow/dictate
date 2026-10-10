import Foundation

struct PhraseReplacer {
    struct Replacement {
        let phrase: String
        let replacement: String
    }

    private struct Rule {
        let words: [String]
        let replacement: String
    }

    private struct Match {
        let replacement: String
        let lastSegment: Int
        let particle: String
    }

    private let rules: [Rule]

    init(_ replacements: [Replacement]) {
        rules = replacements
            .compactMap(Self.rule(for:))
            .sorted { $0.words.count > $1.words.count }
    }

    static func words(of text: String) -> [String] {
        TextSegment.split(text).filter(\.isWord).map { normalized($0.text) }
    }

    private static func rule(for replacement: Replacement) -> Rule? {
        let segments = TextSegment.split(replacement.phrase.trimmingCharacters(in: .whitespacesAndNewlines))
        let separatesWithSpaces = segments.allSatisfy { $0.isWord || $0.text.allSatisfy(\.isWhitespace) }
        let words = segments.filter(\.isWord).map { normalized($0.text) }
        guard !words.isEmpty, separatesWithSpaces, segments.first?.isWord == true else { return nil }

        return Rule(words: words, replacement: replacement.replacement)
    }

    private static func normalized(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "ё", with: "е")
    }

    private static func koreanParticle(after word: String, in spoken: String) -> String? {
        guard spoken.hasPrefix(word), let last = word.unicodeScalars.last, isHangulSyllable(last) else { return nil }

        let rest = String(spoken.dropFirst(word.count))
        guard (1 ... 2).contains(rest.count), rest.unicodeScalars.allSatisfy(isHangulSyllable) else { return nil }

        return rest
    }

    private static func isHangulSyllable(_ scalar: Unicode.Scalar) -> Bool {
        (0xAC00 ... 0xD7AF).contains(scalar.value)
    }

    func apply(to text: String) -> String {
        guard !rules.isEmpty else { return text }

        let segments = TextSegment.split(text)
        var result = ""
        var index = 0

        while index < segments.count {
            if segments[index].isWord, let match = match(at: index, in: segments) {
                result += match.replacement + match.particle
                index = match.lastSegment + 1
            } else {
                result += segments[index].text
                index += 1
            }
        }

        return result
    }

    private func match(at start: Int, in segments: [TextSegment]) -> Match? {
        rules.lazy.compactMap { match($0, at: start, in: segments) }.first
    }

    private func match(_ rule: Rule, at start: Int, in segments: [TextSegment]) -> Match? {
        var index = start
        var particle = ""

        for (offset, word) in rule.words.enumerated() {
            if offset > 0 {
                guard index + 2 < segments.count, segments[index + 1].text.allSatisfy(\.isWhitespace) else { return nil }

                index += 2
            }

            let spoken = Self.normalized(segments[index].text)
            guard spoken != word else { continue }
            guard offset == rule.words.count - 1, let found = Self.koreanParticle(after: word, in: spoken) else { return nil }

            particle = String(segments[index].text.suffix(found.count))
        }

        return Match(replacement: rule.replacement, lastSegment: index, particle: particle)
    }
}
