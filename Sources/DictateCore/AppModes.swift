import Foundation

/// A default mode for some apps, by bundle identifier: Formal in Mail, Raw in the terminal. Apps without one
/// use the mode chosen in the menu.
public struct AppModes: Equatable, Sendable {
    public private(set) var modes: [String: Mode]

    public init(modes: [String: Mode] = [:]) {
        self.modes = modes
    }

    /// From `UserDefaults`; unknown modes are skipped.
    public init(stored: [String: String]) {
        modes = stored.compactMapValues(Mode.init(rawValue:))
    }

    /// From the `--app-mode` launch option: `com.google.Chrome=formal,com.apple.Terminal=raw`.
    public init(launchValue: String) {
        let pairs = launchValue.split(separator: ",").compactMap { pair -> (String, Mode)? in
            let parts = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, !parts[0].isEmpty, let mode = Mode(rawValue: parts[1]) else { return nil }
            return (parts[0], mode)
        }
        modes = Dictionary(pairs, uniquingKeysWith: { _, last in last })
    }

    public var stored: [String: String] {
        modes.mapValues(\.rawValue)
    }

    public func mode(for bundleIdentifier: String?) -> Mode? {
        bundleIdentifier.flatMap { modes[$0] }
    }

    /// `nil` removes the app's own mode.
    public mutating func set(_ mode: Mode?, for bundleIdentifier: String) {
        modes[bundleIdentifier] = mode
    }
}
