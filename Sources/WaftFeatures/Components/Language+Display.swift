import Foundation
import WaftCore

extension Language {
    static let interfaceLocale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")

    var displayName: String {
        inlineName.sentenceCased
    }

    var inlineName: String {
        Self.interfaceLocale.localizedString(forLanguageCode: self == .filipino ? "fil" : rawValue) ?? name
    }

    static func inlineList(_ languages: [Language]) -> String {
        let formatter = ListFormatter()
        formatter.locale = interfaceLocale

        return formatter.string(from: languages.map(\.inlineName)) ?? languages.map(\.inlineName).joined(separator: ", ")
    }
}

extension String {
    var sentenceCased: String {
        prefix(1).uppercased(with: Language.interfaceLocale) + dropFirst()
    }
}
