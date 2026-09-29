import DictateCore
import Foundation
import Observation

/// Live view of the permission report for the menu. Polls because macOS sends no
/// notification when the user flips a switch in System Settings.
@MainActor
@Observable
final class PermissionsModel {
    private(set) var report = SystemPermissionChecker.currentReport()

    init() {
        // Lives as long as the app, so the timer is never stopped.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let latest = SystemPermissionChecker.currentReport()
        if latest != report {
            report = latest
        }
    }

    func grant(_ permission: Permission) {
        Task {
            await SystemPermissionChecker.request(permission)
            refresh()
        }
    }
}
