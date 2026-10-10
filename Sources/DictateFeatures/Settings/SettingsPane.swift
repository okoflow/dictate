package enum SettingsPane: Int, CaseIterable {
    case general
    case dictation
    case modes
    case dictionary
    case history
    case about

    var title: String {
        switch self {
        case .general: "General"
        case .dictation: "Dictation"
        case .modes: "Modes"
        case .dictionary: "Dictionary"
        case .history: "History"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .dictation: "mic"
        case .modes: "sparkles"
        case .dictionary: "book.closed"
        case .history: "clock"
        case .about: "info.circle"
        }
    }
}
