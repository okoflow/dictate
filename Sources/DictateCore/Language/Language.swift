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

    package init?(localeIdentifier: String) {
        guard let code = Locale.Language(identifier: localeIdentifier).languageCode?.identifier else { return nil }

        self.init(rawValue: code)
    }
}
