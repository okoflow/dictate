package enum SettingsPane: CaseIterable {
    case general
    case dictation
    case modes
    case dictionary
    case history
    case about

    static let sidebarPanes: [SettingsPane] = [.general, .dictation, .modes, .dictionary, .history]

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
        case .general: "gearshape.fill"
        case .dictation: "mic.fill"
        case .modes: "slider.horizontal.3"
        case .dictionary: "book.closed.fill"
        case .history: "clock.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: TileTint {
        switch self {
        case .general, .about: .gray
        case .dictation: .red
        case .modes: .purple
        case .dictionary: .orange
        case .history: .blue
        }
    }
}
