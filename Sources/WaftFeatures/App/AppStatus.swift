import Foundation
import WaftCore

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
        case .needsPermission: String(localized: "Setup needed")

        case let .downloading(progress): String(
                localized: "Downloading speech model… \(progress.formatted(.percent.precision(.fractionLength(0))))",
            )

        case .preparing: String(localized: "Preparing speech model…")

        case .modelFailed: String(localized: "Speech model failed")

        case .recording: String(localized: "Listening…")

        case .ready: String(localized: "Hold \(key.shortTitle) to dictate")
        }
    }
}
