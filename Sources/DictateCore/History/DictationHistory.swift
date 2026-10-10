import Foundation

package struct DictationHistory: Codable, Equatable, Sendable {
    package struct Entry: Codable, Equatable, Sendable {
        package let date: Date
        package let text: String
        package let mode: Mode
        package let app: String?

        package var preview: String {
            let line = text.replacingOccurrences(of: "\n", with: " ")

            return line.count > 50 ? String(line.prefix(49)) + "…" : line
        }

        package init(date: Date, text: String, mode: Mode, app: String?) {
            self.date = date
            self.text = text
            self.mode = mode
            self.app = app
        }
    }

    package static let capacity = 2000

    package private(set) var entries: [Entry] = []

    package var newestFirst: [Entry] {
        entries.reversed()
    }

    package init() {}

    package mutating func add(_ entry: Entry) {
        guard !entry.text.isEmpty else { return }

        entries.append(entry)
        entries.removeFirst(max(0, entries.count - Self.capacity))
    }

    package mutating func removeAll() {
        entries.removeAll()
    }

    package mutating func prune(keeping retention: HistoryRetention, now: Date) {
        if let cutoff = retention.cutoff(before: now) {
            entries.removeAll { $0.date < cutoff }
        }

        entries.removeFirst(max(0, entries.count - Self.capacity))
    }
}
