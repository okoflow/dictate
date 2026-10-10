import Foundation

package struct RecentTranscripts: Sendable {
    package static let capacity = 5
    package static let lifetime: TimeInterval = 600

    private var entries: [(text: String, date: Date)] = []

    package init() {}

    package func latest(at date: Date) -> String? {
        entries.last { date.timeIntervalSince($0.date) <= Self.lifetime }?.text
    }

    package mutating func remember(_ text: String, at date: Date) {
        entries.append((text, date))
        entries.removeFirst(max(0, entries.count - Self.capacity))
    }
}
