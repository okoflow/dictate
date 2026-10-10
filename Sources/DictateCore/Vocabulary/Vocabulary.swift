package struct Vocabulary: Codable, Equatable, Sendable {
    package struct Term: Codable, Equatable, Sendable {
        package var term: String
        package var spoken: [String]

        package init(term: String, spoken: [String] = []) {
            self.term = term
            self.spoken = spoken
        }

        package init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            term = try container.decode(String.self, forKey: .term)
            spoken = try container.decodeIfPresent([String].self, forKey: .spoken) ?? []
        }
    }

    package struct Snippet: Codable, Equatable, Sendable {
        package var trigger: String
        package var text: String

        package init(trigger: String, text: String) {
            self.trigger = trigger
            self.text = text
        }
    }

    package static let empty = Vocabulary(terms: [], snippets: [])

    package var terms: [Term]
    package var snippets: [Snippet]

    package var promptTerms: [String] {
        terms.map(\.term)
    }

    package init(terms: [Term], snippets: [Snippet]) {
        self.terms = terms
        self.snippets = snippets
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        terms = try container.decodeIfPresent([Term].self, forKey: .terms) ?? []
        snippets = try container.decodeIfPresent([Snippet].self, forKey: .snippets) ?? []
    }

    package func correcting(_ text: String) -> String {
        let replacements = terms.flatMap { term in
            ([term.term] + term.spoken).map { PhraseReplacer.Replacement(phrase: $0, replacement: term.term) }
        }

        return PhraseReplacer(replacements).apply(to: text)
    }

    package func snippet(matchingWhole text: String) -> String? {
        let spoken = PhraseReplacer.words(of: text)
        guard !spoken.isEmpty else { return nil }

        return snippets.first { PhraseReplacer.words(of: $0.trigger) == spoken }?.text
    }

    package func expandingSnippets(in text: String) -> String {
        let replacements = snippets.map { PhraseReplacer.Replacement(phrase: $0.trigger, replacement: $0.text) }

        return PhraseReplacer(replacements).apply(to: text)
    }
}
