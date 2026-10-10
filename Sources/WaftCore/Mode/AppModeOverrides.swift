package struct AppModeOverrides: Codable, Equatable, Sendable {
    package private(set) var modes: [String: Mode] = [:]

    package var bundleIdentifiers: [String] {
        modes.keys.sorted()
    }

    package init() {}

    package func mode(for bundleIdentifier: String?) -> Mode? {
        bundleIdentifier.flatMap { modes[$0] }
    }

    package mutating func set(_ mode: Mode?, for bundleIdentifier: String) {
        modes[bundleIdentifier] = mode
    }
}
