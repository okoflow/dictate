import Foundation

/// The last few dictated texts, kept in memory only, for "Copy last transcript": the way back when a text
/// was not pasted, or a later paste overwrote the clipboard. Old entries are forgotten.
public struct TranscriptHistory: Sendable {
    public static let capacity = 5
    public static let lifetime: TimeInterval = 600

    private var entries: [(text: String, date: Date)] = []

    public init() {}

    public mutating func remember(_ text: String, at date: Date) {
        entries.append((text, date))
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
    }

    /// The newest text that is not older than `lifetime`.
    public func latest(at date: Date) -> String? {
        entries.last { date.timeIntervalSince($0.date) <= Self.lifetime }?.text
    }

    public var count: Int {
        entries.count
    }
}
