import Foundation

package enum RewriteValidator {
    private static let wrappers: [(open: String, close: String)] = [("<transcript>", "</transcript>"), ("\"", "\""), ("«", "»")]

    package static func validated(_ answer: String, for input: String, mode: Mode, language: Language) -> String? {
        let text = unwrapped(answer, input: input)
        guard !text.isEmpty, text.count <= input.count * 3 + 60 else { return nil }

        let expectedScripts: Set<WritingScript> = mode == .translate ? [.latin] : language.scripts

        if let script = WritingScript.dominant(in: text), !expectedScripts.contains(script) {
            return nil
        }

        return text
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
