import Foundation

/// The last dictations, kept on disk by the app (unless switched off) so a text can be copied again later.
public struct DictationHistory: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let date: Date
        public let text: String
        /// The mode that really ran.
        public let mode: Mode
        /// The bundle identifier of the app the text was for.
        public let app: String?

        public init(date: Date, text: String, mode: Mode, app: String?) {
            self.date = date
            self.text = text
            self.mode = mode
            self.app = app
        }

        /// One line for the menu: the start of the text.
        public var menuTitle: String {
            let line = text.replacingOccurrences(of: "\n", with: " ")
            return line.count > 50 ? String(line.prefix(49)) + "…" : line
        }
    }

    public static let capacity = 50

    /// Oldest first.
    public private(set) var entries: [Entry] = []

    public init() {}

    public mutating func add(_ entry: Entry) {
        guard !entry.text.isEmpty else { return }
        entries.append(entry)
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
    }

    public mutating func clear() {
        entries.removeAll()
    }

    public func newest(_ count: Int) -> [Entry] {
        Array(entries.suffix(count).reversed())
    }
}
