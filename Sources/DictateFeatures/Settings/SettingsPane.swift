package enum SettingsPane: CaseIterable {
    case general
    case dictation
    case writing
    case cloud
    case dictionary
    case history
    case about

    static let sidebarPanes: [SettingsPane] = [.general, .dictation, .writing, .cloud, .dictionary, .history]

    var title: String {
        switch self {
        case .general: "General"
        case .dictation: "Dictation"
        case .writing: "Writing"
        case .cloud: "Cloud"
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
        case .cloud: "cloud.fill"
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
        case .cloud: .blue
        case .dictionary: .orange
        case .history: .indigo
        }
    }
}
