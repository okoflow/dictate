import Foundation

package enum Language: String, CaseIterable, Codable, Sendable {
    case arabic = "ar"
    case azerbaijani = "az"
    case bosnian = "bs"
    case bulgarian = "bg"
    case catalan = "ca"
    case chinese = "zh"
    case croatian = "hr"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case english = "en"
    case estonian = "et"
    case filipino = "tl"
    case finnish = "fi"
    case french = "fr"
    case galician = "gl"
    case german = "de"
    case greek = "el"
    case hebrew = "he"
    case hindi = "hi"
    case hungarian = "hu"
    case indonesian = "id"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko"
    case latvian = "lv"
    case lithuanian = "lt"
    case macedonian = "mk"
    case malay = "ms"
    case norwegian = "no"
    case polish = "pl"
    case portuguese = "pt"
    case romanian = "ro"
    case russian = "ru"
    case serbian = "sr"
    case slovak = "sk"
    case slovenian = "sl"
    case spanish = "es"
    case swedish = "sv"
    case tamil = "ta"
    case thai = "th"
    case turkish = "tr"
    case ukrainian = "uk"
    case urdu = "ur"
    case vietnamese = "vi"

    private static let localeAliases = ["fil": "tl", "in": "id", "iw": "he", "nb": "no", "nn": "no"]

    package var code: String {
        rawValue
    }

    var locale: Locale {
        Locale(identifier: code)
    }

    package init?(localeIdentifier: String) {
        guard let code = Locale.Language(identifier: localeIdentifier).languageCode?.identifier else { return nil }

        self.init(rawValue: Self.localeAliases[code] ?? code)
    }
}
