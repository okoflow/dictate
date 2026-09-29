import Foundation

/// What TestPad reports about itself. The E2E runner treats this file as ground truth
/// and compares it with what Accessibility shows.
public struct TestPadState: Codable, Equatable, Sendable {
    public var text: String
    public var password: String
    public var isFrontmost: Bool

    public init(text: String = "", password: String = "", isFrontmost: Bool = false) {
        self.text = text
        self.password = password
        self.isFrontmost = isFrontmost
    }

    public static let textIdentifier = "testpad.text"
    public static let passwordIdentifier = "testpad.password"
    public static let bundleIdentifier = "dev.dictate.testpad"

    public func write(to url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    public static func read(from url: URL) throws -> TestPadState {
        try JSONDecoder().decode(TestPadState.self, from: Data(contentsOf: url))
    }
}
