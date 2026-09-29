import Foundation

/// The languages Dictate recognises.
public enum Language: String, CaseIterable, Codable, Sendable {
    // swiftlint:disable identifier_name
    // ISO 639-1 codes: they are what Whisper, the manifest and the event log call the languages.
    case ru
    case en
    case ko
    // swiftlint:enable identifier_name

    public var displayName: String {
        switch self {
        case .ru: "Russian"
        case .en: "English"
        case .ko: "Korean"
        }
    }

    /// The most probable of our three languages in `probabilities`, ignoring any other. The detector is
    /// already narrowed to the three (`RestrictedTokenizer`) and returns one entry, so this mostly reads
    /// that entry; the filter keeps it correct for a full table too. `nil` when none of ours is present.
    public static func pick(from probabilities: [String: Float]) -> (language: Language, probability: Float)? {
        allCases
            .compactMap { language in probabilities[language.rawValue].map { (language, $0) } }
            .max { $0.1 < $1.1 }
    }
}

/// Which language to dictate in: let the model choose among ours, or pin one.
public enum LanguagePreference: Hashable, Sendable {
    case auto
    case fixed(Language)

    public static let allChoices: [LanguagePreference] = [.auto] + Language.allCases.map { .fixed($0) }

    /// The value kept in `UserDefaults`.
    public var storedValue: String {
        switch self {
        case .auto: "auto"
        case let .fixed(language): language.rawValue
        }
    }

    /// Reads a stored value; anything unknown (or missing) means `.auto`.
    public init(storedValue: String?) {
        self = storedValue.flatMap(Language.init(rawValue:)).map { .fixed($0) } ?? .auto
    }

    public var menuTitle: String {
        switch self {
        case .auto: "Auto (ru / en / ko)"
        case let .fixed(language): language.displayName
        }
    }

    /// The language to force, or `nil` when the model should detect it.
    public var language: Language? {
        if case let .fixed(language) = self {
            language
        } else {
            nil
        }
    }
}
