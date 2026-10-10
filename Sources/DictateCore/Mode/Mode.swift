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
        case .raw: "Raw"
        case .light: "Light"
        case .clean: "Clean"
        case .formal: "Formal"
        case .translate: "Translate"
        }
    }

    package var summary: String {
        switch self {
        case .raw: "Exactly what was heard."
        case .light: "Drops um and uh, adds a capital letter and a full stop."
        case .clean: "Removes fillers and false starts, fixes grammar, keeps your language."
        case .formal: "Like Clean, in a polite business tone."
        case .translate: "Translates what you said into another language."
        }
    }
}
