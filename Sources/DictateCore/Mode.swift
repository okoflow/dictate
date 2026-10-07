import Foundation

/// What happens to the recognised text before it is pasted.
public enum Mode: String, CaseIterable, Codable, Sendable {
    /// Whisper's text as-is.
    case raw
    /// Offline rules (`LightRules`): hesitations, spacing, capital letter, final full stop.
    case light
    /// An LLM removes fillers and self-corrections and fixes grammar, in the language spoken.
    case clean
    /// Clean, in a business tone.
    case formal
    /// Translated to English.
    case translate

    /// Whether the text is sent to the LLM API. Raw and Light never leave the Mac.
    public var isCloud: Bool {
        switch self {
        case .raw, .light: false
        case .clean, .formal, .translate: true
        }
    }

    /// The mode after this one when cycling with the hotkey; the last one wraps around to the first.
    public var next: Mode {
        let all = Mode.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    public var displayName: String {
        switch self {
        case .raw: "Raw"
        case .light: "Light"
        case .clean: "Clean"
        case .formal: "Formal"
        case .translate: "Translate → EN"
        }
    }

    /// The name with ☁︎ for the modes that send text to the cloud, for the menu and the pill.
    public var menuTitle: String {
        isCloud ? "\(displayName) ☁︎" : displayName
    }

    /// Reads a stored or typed value; anything unknown (or missing) gives `fallback`.
    public init(storedValue: String?, fallback: Mode = .light) {
        self = storedValue.flatMap(Mode.init(rawValue:)) ?? fallback
    }
}
