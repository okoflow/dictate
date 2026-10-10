import Foundation

package enum RewriteValidator {
    private static let wrappers: [(open: String, close: String)] = [("<transcript>", "</transcript>"), ("\"", "\""), ("«", "»")]
    private static let compactScripts: Set<WritingScript> = [.han, .hangul, .kana]

    package static func validated(_ answer: String, for input: String, mode: Mode, language: Language) -> String? {
        let text = unwrapped(answer, input: input)
        guard !text.isEmpty, text.count <= maximumLength(for: input, mode: mode, language: language) else { return nil }

        let scripts = expectedScripts(for: input, mode: mode, language: language)

        if let script = WritingScript.dominant(in: text), !scripts.contains(script) {
            return nil
        }

        return text
    }

    private static func maximumLength(for input: String, mode: Mode, language: Language) -> Int {
        let translatesCompactScript = mode == .translate && !language.scripts.isDisjoint(with: compactScripts)

        return input.count * (translatesCompactScript ? 5 : 3) + 60
    }

    private static func expectedScripts(for input: String, mode: Mode, language: Language) -> Set<WritingScript> {
        guard mode != .translate else { return [.latin] }
        guard let transcriptScript = WritingScript.dominant(in: input) else { return language.scripts }

        return language.scripts.union([transcriptScript])
    }

    private static func unwrapped(_ answer: String, input: String) -> String {
        var text = answer.trimmingCharacters(in: .whitespacesAndNewlines)

        for wrapper in wrappers where isWrapped(text, in: wrapper) && !input.hasPrefix(wrapper.open) {
            text = String(text.dropFirst(wrapper.open.count).dropLast(wrapper.close.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text
    }

    private static func isWrapped(_ text: String, in wrapper: (open: String, close: String)) -> Bool {
        text.hasPrefix(wrapper.open) && text.hasSuffix(wrapper.close) && text.count > wrapper.open.count + wrapper.close.count
    }
}
