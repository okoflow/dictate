import Foundation

package enum Mode: String, CaseIterable, Codable, Sendable {
    case raw
    case light
    case clean
    case formal
    case translate

    package var isCloud: Bool {
        switch self {
        case .raw, .light:
            false
        case .clean, .formal, .translate:
            true
        }
    }

    package var next: Mode {
        let modes = Mode.allCases
        let index = modes.firstIndex(of: self) ?? modes.startIndex

        return modes[(index + 1) % modes.count]
    }

    package var title: String {
        switch self {
        case .raw: String(localized: "Raw")
        case .light: String(localized: "Light")
        case .clean: String(localized: "Clean")
        case .formal: String(localized: "Formal")
        case .translate: String(localized: "Translate")
        }
    }

    package var summary: String {
        switch self {
        case .raw: String(localized: "Exactly what was heard.")
        case .light: String(localized: "Drops um and uh, adds a capital letter and a full stop.")
        case .clean: String(localized: "Removes fillers and false starts, fixes grammar, keeps your language.")
        case .formal: String(localized: "Like Clean, in a polite business tone.")
        case .translate: String(localized: "Translates what you said into another language.")
        }
    }
}
