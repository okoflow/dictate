import Foundation

package enum Language: String, CaseIterable, Codable, Sendable {
    case chinese = "zh"
    case dutch = "nl"
    case english = "en"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case polish = "pl"
    case portuguese = "pt"
    case russian = "ru"
    case spanish = "es"
    case ukrainian = "uk"

    package var code: String {
        rawValue
    }

    package var name: String {
        switch self {
        case .chinese: "Chinese"
        case .dutch: "Dutch"
        case .english: "English"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .polish: "Polish"
        case .portuguese: "Portuguese"
        case .russian: "Russian"
        case .spanish: "Spanish"
        case .ukrainian: "Ukrainian"
        }
    }

    package var nativeName: String {
        switch self {
        case .chinese: "中文"
        case .dutch: "Nederlands"
        case .english: "English"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .polish: "Polski"
        case .portuguese: "Português"
        case .russian: "Русский"
        case .spanish: "Español"
        case .ukrainian: "Українська"
        }
    }

    package init?(localeIdentifier: String) {
        guard let code = Locale.Language(identifier: localeIdentifier).languageCode?.identifier else { return nil }

        self.init(rawValue: code)
    }
}
