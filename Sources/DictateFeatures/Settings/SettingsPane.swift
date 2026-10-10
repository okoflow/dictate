package enum SettingsPane: CaseIterable {
    case general
    case dictation
    case writing
    case aiModels
    case dictionary
    case history
    case about

    static let sidebarPanes: [SettingsPane] = [.general, .dictation, .writing, .aiModels, .dictionary, .history]

    var title: String {
        switch self {
        case .general: "General"
        case .dictation: "Dictation"
        case .writing: "Writing"
        case .aiModels: "AI Models"
        case .dictionary: "Dictionary"
        case .history: "History"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape.fill"
        case .dictation: "mic.fill"
        case .writing: "slider.horizontal.3"
        case .aiModels: "sparkles"
        case .dictionary: "book.closed.fill"
        case .history: "clock.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: TileTint {
        switch self {
        case .general, .about: .gray
        case .dictation: .red
        case .writing: .teal
        case .aiModels: .blue
        case .dictionary: .orange
        case .history: .indigo
        }
    }
}
