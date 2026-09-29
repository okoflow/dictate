import AppKit
import Foundation

/// Launches and stops `.app` bundles the way a user would (through LaunchServices), so the
/// process gets its own TCC identity instead of borrowing the terminal's.
struct AppLauncher {
    let bundleURL: URL
    let bundleIdentifier: String

    var runningApplication: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
    }

    /// Starts a fresh instance and returns once it is running, or `nil` on timeout.
    func launch(arguments: [String] = [], timeout: TimeInterval = 10) -> NSRunningApplication? {
        terminate()
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-n", bundleURL.path, "--args"] + arguments
        do {
            try open.run()
            open.waitUntilExit()
        } catch {
            return nil
        }
        _ = waitUntil(timeout: timeout) { runningApplication != nil }
        return runningApplication
    }

    func terminate() {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        for app in apps {
            app.terminate()
        }
        let exited = waitUntil(timeout: 3) { runningApplication == nil }
        if !exited {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
                app.forceTerminate()
            }
            _ = waitUntil(timeout: 3) { runningApplication == nil }
        }
    }
}
