import DictateCore

package enum AppStatus: Equatable {
    case needsPermission
    case downloading(Double)
    case preparing
    case modelFailed
    case recording
    case ready

    package var symbolName: String {
        switch self {
        case .needsPermission: "mic.slash"
        case .downloading: "arrow.down.circle"
        case .preparing: "hourglass"
        case .modelFailed: "mic.badge.xmark"
        case .recording: "mic.fill"
        case .ready: "mic"
        }
    }

    func title(key: PushToTalkKey) -> String {
        switch self {
        case .needsPermission: "Setup needed"
        case let .downloading(progress): "Downloading speech model… \(Int((progress * 100).rounded()))%"
        case .preparing: "Preparing speech model…"
        case .modelFailed: "Speech model failed"
        case .recording: "Listening…"
        case .ready: "Hold \(key.shortTitle) to dictate"
        }
    }
}
