import AppKit
import ApplicationServices
@preconcurrency import AVFoundation
import WaftCore

@MainActor
package final class SystemPermissions: PermissionProvider {
    private var hasPromptedForAccessibility = false

    package init() {}

    package func status(of permission: Permission) -> PermissionStatus {
        switch permission {
        case .microphone:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: .granted
            case .notDetermined: .notDetermined
            case .denied, .restricted: .denied
            @unknown default: .denied
            }

        case .accessibility:
            AXIsProcessTrusted() ? .granted : .denied
        }
    }

    package func request(_ permission: Permission) async {
        switch permission {
        case .microphone where status(of: .microphone) == .notDetermined:
            _ = await AVCaptureDevice.requestAccess(for: .audio)

        case .accessibility where !hasPromptedForAccessibility:
            hasPromptedForAccessibility = true
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

        case .microphone, .accessibility:
            openSystemSettings(for: permission)
        }
    }

    private func openSystemSettings(for permission: Permission) {
        let anchor = switch permission {
        case .microphone: "Privacy_Microphone"
        case .accessibility: "Privacy_Accessibility"
        }

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
