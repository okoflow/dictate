import Foundation

/// The personal dictionary: terms and names Whisper should know (they go into its prompt, and the ways it
/// mishears them are replaced afterwards), and snippets (a spoken trigger that becomes a fixed text).
///
/// Stored as JSON (`dictionary.json`):
/// `{"terms": [{"term": "Kubernetes", "spoken": ["кубернетис", "кубер"]}], "snippets": [{"trigger": "моя почта", "text": "ivan@example.com"}]}`
public struct Vocabulary: Codable, Equatable, Sendable {
    public struct Term: Codable, Equatable, Sendable {
        /// How it must be written.
        public let term: String
        /// What Whisper may write instead (any case); the term itself in another case is always corrected.
        public let spoken: [String]

        public init(term: String, spoken: [String] = []) {
            self.term = term
            self.spoken = spoken
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            term = try container.decode(String.self, forKey: .term)
            spoken = try container.decodeIfPresent([String].self, forKey: .spoken) ?? []
        }
    }

    public struct Snippet: Codable, Equatable, Sendable {
        public let trigger: String
        public let text: String

        public init(trigger: String, text: String) {
            self.trigger = trigger
            self.text = text
        }
    }

    public var terms: [Term]
    public var snippets: [Snippet]

    public static let empty = Vocabulary(terms: [], snippets: [])

    public init(terms: [Term], snippets: [Snippet]) {
        self.terms = terms
        self.snippets = snippets
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        terms = try container.decodeIfPresent([Term].self, forKey: .terms) ?? []
        snippets = try container.decodeIfPresent([Snippet].self, forKey: .snippets) ?? []
    }

    /// The terms, for Whisper's prompt.
    public var promptTerms: [String] {
        terms.map(\.term)
    }

    /// Writes every term the way the dictionary says: its spoken forms and its own other-case spellings,
    /// matched as whole words ("кубер" → "Kubernetes", "github" → "GitHub"; Korean particles stay:
    /// "쿠버네티스를" → "Kubernetes를").
    public func correcting(_ text: String) -> String {
        let rules = terms.flatMap { term in ([term.term] + term.spoken).map { (phrase: $0, replacement: term.term) } }
        return PhraseReplacer(rules).apply(to: text)
    }

    /// The snippet text when the whole dictation is its trigger (case and punctuation aside).
    public func wholeSnippet(for text: String) -> String? {
        let spoken = PhraseReplacer.words(of: text)
        guard !spoken.isEmpty else { return nil }
        return snippets.first { PhraseReplacer.words(of: $0.trigger) == spoken }?.text
    }

    /// Replaces triggers inside a longer text with their snippets.
    public func expandingSnippets(in text: String) -> String {
        PhraseReplacer(snippets.map { (phrase: $0.trigger, replacement: $0.text) }).apply(to: text)
    }
}

/// Replaces whole-word phrases, ignoring case (and ё/е). Words of a phrase must be separated by spaces in the
/// text too. A phrase with other characters between its words ("C++", "node.js") cannot be matched word by word,
/// so it is ignored rather than risk matching just "C".
struct PhraseReplacer {
    private struct Rule {
        let words: [String]
        let replacement: String
    }

    private struct Match {
        let replacement: String
        /// The last piece the match covers.
        let end: Int
        /// A Korean particle left on the last word.
        let suffix: String
    }

    private let rules: [Rule]

    init(_ phrases: [(phrase: String, replacement: String)]) {
        rules = phrases.compactMap { phrase, replacement in
            let pieces = TextPiece.split(phrase.trimmingCharacters(in: .whitespacesAndNewlines))
            let separatorsAreSpaces = pieces.allSatisfy { $0.isWord || $0.text.allSatisfy(\.isWhitespace) }
            let words = pieces.filter(\.isWord).map { Self.normalised($0.text) }
            guard !words.isEmpty, separatorsAreSpaces, pieces.first?.isWord == true else { return nil }
            return Rule(words: words, replacement: replacement)
        }
        // Longer phrases first, so "тайп скрипт" wins over "тайп".
        .sorted { $0.words.count > $1.words.count }
    }

    static func words(of text: String) -> [String] {
        TextPiece.split(text).filter(\.isWord).map { normalised($0.text) }
    }

    private static func normalised(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "ё", with: "е")
    }

    func apply(to text: String) -> String {
        guard !rules.isEmpty else { return text }
        let pieces = TextPiece.split(text)
        var result = ""
        var index = 0
        while index < pieces.count {
            if pieces[index].isWord, let match = match(at: index, in: pieces) {
                result += match.replacement + match.suffix
                index = match.end + 1
            } else {
                result += pieces[index].text
                index += 1
            }
        }
        return result
    }

    /// The first rule matching at `start`.
    private func match(at start: Int, in pieces: [TextPiece]) -> Match? {
        for rule in rules {
            var index = start
            var suffix = ""
            var matched = true
            for (offset, word) in rule.words.enumerated() {
                if offset > 0 {
                    guard index + 2 < pieces.count, pieces[index + 1].text.allSatisfy(\.isWhitespace) else {
                        matched = false
                        break
                    }
                    index += 2
                }
                let spoken = Self.normalised(pieces[index].text)
                if spoken == word {
                    continue
                }
                guard offset == rule.words.count - 1, let particle = Self.koreanParticle(after: word, in: spoken) else {
                    matched = false
                    break
                }
                suffix = String(pieces[index].text.suffix(particle.count))
            }
            if matched {
                return Match(replacement: rule.replacement, end: index, suffix: suffix)
            }
        }
        return nil
    }

    /// Korean writes particles onto the word (쿠버네티스 + 를): what follows `word` in `spoken`, if it is one or
    /// two Hangul syllables and `word` is Hangul too.
    private static func koreanParticle(after word: String, in spoken: String) -> String? {
        guard spoken.hasPrefix(word), let last = word.unicodeScalars.last, isHangul(last) else { return nil }
        let rest = String(spoken.dropFirst(word.count))
        guard (1 ... 2).contains(rest.count), rest.unicodeScalars.allSatisfy(isHangul) else { return nil }
        return rest
    }

    private static func isHangul(_ scalar: Unicode.Scalar) -> Bool {
        (0xAC00 ... 0xD7AF).contains(scalar.value)
    }
}
