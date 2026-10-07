import Foundation

/// The "previous text" Whisper gets before a recording: the style sentence (`StylePrompt`) and the dictionary's
/// terms, so it writes "Kubernetes" rather than "кубернетис". Whisper reads at most 224 prompt tokens, so the
/// terms are cut to `maximumTermCharacters`.
public enum WhisperPrompt {
    public static let maximumTermCharacters = 200

    /// `nil` when there is nothing to say: Korean (no style sentence) with no terms.
    public static func text(for language: Language, terms: [String]) -> String? {
        var glossary = ""
        for term in terms.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !term.isEmpty {
            let next = glossary.isEmpty ? term : glossary + ", " + term
            guard next.count <= maximumTermCharacters else { break }
            glossary = next
        }
        let parts = [StylePrompt.text(for: language), glossary.isEmpty ? nil : glossary + "."].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
