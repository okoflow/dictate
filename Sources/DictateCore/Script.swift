import Foundation

/// The writing system of a text, judged by its letters. It is how Dictate checks that an LLM answer stayed in
/// the language that was spoken (Clean and Formal) or became English (Translate), without a language model.
public enum Script: String, Codable, Sendable {
    case cyrillic
    case latin
    case hangul

    /// The script most of the letters belong to, if it holds more than half of them. A Russian sentence with
    /// a few English terms is still Cyrillic. `nil` for a text without letters or an even mix.
    public static func dominant(in text: String) -> Script? {
        var counts: [Script: Int] = [:]
        var letters = 0
        for scalar in text.unicodeScalars where scalar.properties.isAlphabetic {
            letters += 1
            if let script = script(of: scalar) {
                counts[script, default: 0] += 1
            }
        }
        guard let (script, count) = counts.max(by: { $0.value < $1.value }), count * 2 > letters else { return nil }
        return script
    }

    /// The script a language is written in.
    public init(_ language: Language) {
        switch language {
        case .ru: self = .cyrillic
        case .en: self = .latin
        case .ko: self = .hangul
        }
    }

    private static func script(of scalar: Unicode.Scalar) -> Script? {
        switch scalar.value {
        case 0x0041 ... 0x005A, 0x0061 ... 0x007A, 0x00C0 ... 0x024F: .latin
        case 0x0400 ... 0x052F: .cyrillic
        case 0x1100 ... 0x11FF, 0x3130 ... 0x318F, 0xAC00 ... 0xD7AF: .hangul
        default: nil
        }
    }
}
