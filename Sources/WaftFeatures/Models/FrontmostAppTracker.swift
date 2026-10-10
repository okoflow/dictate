import AppKit
import Foundation
import Observation
import WaftCore

@Observable
package final class FrontmostAppTracker {
    package struct App: Equatable {
        package let bundleIdentifier: String
        package let name: String
    }

    package private(set) var app: App?

    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init() {
        app = Self.app(from: NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main,
        ) { [weak self] notification in
            let running = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let app = Self.app(from: running)

            MainActor.assumeIsolated { self?.activated(app) }
        }
    }

    package static func name(of bundleIdentifier: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
            ?? bundleIdentifier
    }

    private nonisolated static func app(from running: NSRunningApplication?) -> App? {
        guard let running, let bundleIdentifier = running.bundleIdentifier,
              bundleIdentifier != AppIdentity.bundleIdentifier else {
            return nil
        }

        return App(bundleIdentifier: bundleIdentifier, name: running.localizedName ?? bundleIdentifier)
    }

    private func activated(_ app: App?) {
        if let app {
            self.app = app
        }
    }
}
