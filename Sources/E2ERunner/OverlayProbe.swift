import ApplicationServices
import CoreGraphics
import Foundation

/// Looks for the recording overlay in two independent ways: the app's own accessibility tree, and
/// the window server's list of what is really on screen. Either alone can lie (an accessibility
/// window can exist off screen; a window-server entry can lack the identifier).
enum OverlayProbe {
    static let identifier = "dictate.overlay"

    /// The overlay's frame, from `RecordingOverlay`; the menu bar item is also a window of the app,
    /// so size is what tells them apart (names need Screen Recording permission).
    private static let size = CGSize(width: 132, height: 44)

    static func inAccessibilityTree(pid: pid_t) -> Bool {
        Accessibility.find(identifier: identifier, in: Accessibility.application(pid: pid), maxDepth: 3) != nil
    }

    static func onScreen(pid: pid_t) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }
        return windows.contains { window in
            guard window["kCGWindowOwnerPID"] as? pid_t == pid,
                  window["kCGWindowIsOnscreen"] as? Bool == true,
                  (window["kCGWindowAlpha"] as? Double ?? 0) > 0,
                  let bounds = window["kCGWindowBounds"] as? [String: Double]
            else { return false }
            return abs((bounds["Width"] ?? 0) - size.width) < 1 && abs((bounds["Height"] ?? 0) - size.height) < 1
        }
    }
}
