import Foundation

package enum Permission: CaseIterable, Sendable {
    case microphone
    case accessibility

    package var title: String {
        switch self {
        case .microphone: String(localized: "Microphone")
        case .accessibility: String(localized: "Accessibility")
        }
    }

    package var purpose: String {
        switch self {
        case .microphone: String(localized: "Records your voice while you hold the dictation key.")
        case .accessibility: String(localized: "Notices the dictation key and pastes the text where you type.")
        }
    }
}

package enum PermissionStatus: Sendable {
    case granted
    case denied
    case notDetermined

    package var isGranted: Bool {
        self == .granted
    }
}
