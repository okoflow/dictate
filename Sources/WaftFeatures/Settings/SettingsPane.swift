import Foundation

package enum SettingsPane: CaseIterable {
    case general
    case dictation
    case writing
    case aiModels
    case dictionary
    case history
    case pro
    case about

    static let sidebarPanes: [SettingsPane] = [.general, .dictation, .writing, .aiModels, .dictionary, .history]

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .dictation: String(localized: "Dictation")
        case .writing: String(localized: "Writing")
        case .aiModels: String(localized: "AI Models")
        case .dictionary: String(localized: "Dictionary")
        case .history: String(localized: "History")
        case .pro: String(localized: "Waft Pro")
        case .about: String(localized: "About")
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape.fill"
        case .dictation: "mic.fill"
        case .writing: "slider.horizontal.3"
        case .aiModels: "cpu.fill"
        case .dictionary: "book.closed.fill"
        case .history: "clock.fill"
        case .pro: "sparkles"
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
        case .pro: .purple
        }
    }
}
