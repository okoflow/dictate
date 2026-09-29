import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import DictateCore

/// Talks to the real macOS privacy APIs. Kept out of `DictateCore` because it cannot be
/// unit-tested without TCC prompts; the E2E suite covers it instead.
enum SystemPermissionChecker {
    static func status(of permission: Permission) -> PermissionStatus {
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
        case .inputMonitoring:
            CGPreflightListenEventAccess() ? .granted : .denied
        }
    }

    static func currentReport() -> PermissionReport {
        PermissionReport(statusOf: status(of:))
    }

    /// Shows the system prompt where one exists, otherwise opens the right Settings pane.
    @MainActor
    static func request(_ permission: Permission) async {
        switch permission {
        case .microphone:
            if status(of: .microphone) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            } else {
                openSettings(for: permission)
            }
        case .accessibility:
            // Literal key: `kAXTrustedCheckOptionPrompt` is a mutable global, which Swift 6 rejects.
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .inputMonitoring:
            if !CGRequestListenEventAccess() {
                openSettings(for: permission)
            }
        }
    }

    @MainActor
    static func openSettings(for permission: Permission) {
        let base = "x-apple.systempreferences:com.apple.preference.security?"
        if let url = URL(string: base + permission.settingsAnchor) {
            NSWorkspace.shared.open(url)
        }
    }
}
