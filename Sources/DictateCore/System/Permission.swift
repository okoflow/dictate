package enum Permission: CaseIterable, Sendable {
    case microphone
    case accessibility

    package var title: String {
        switch self {
        case .microphone: "Microphone"
        case .accessibility: "Accessibility"
        }
    }

    package var purpose: String {
        switch self {
        case .microphone: "Records your voice while you hold the dictation key."
        case .accessibility: "Notices the dictation key and pastes the text where you type."
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
