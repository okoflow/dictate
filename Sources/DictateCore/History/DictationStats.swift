import Foundation

package struct DictationStats: Codable, Equatable, Sendable {
    package struct Day: Codable, Equatable, Sendable {
        package var words = 0
        package var dictations = 0
        package var seconds = 0.0

        package init() {}

        package static func + (lhs: Day, rhs: Day) -> Day {
            var sum = lhs
            sum.words += rhs.words
            sum.dictations += rhs.dictations
            sum.seconds += rhs.seconds

            return sum
        }
    }

    package static let typingWordsPerMinute = 40.0

    package private(set) var days: [String: Day] = [:]

    package init() {}

    package static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)

        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    package mutating func record(words: Int, seconds: Double, on date: Date, calendar: Calendar = .current) {
        var day = days[Self.key(for: date, calendar: calendar)] ?? Day()
        day.words += words
        day.dictations += 1
        day.seconds += seconds
        days[Self.key(for: date, calendar: calendar)] = day
    }

    package func daily(last count: Int, endingOn date: Date, calendar: Calendar = .current) -> [(date: Date, day: Day)] {
        let end = calendar.startOfDay(for: date)

        return (0 ..< count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: end)
                .map { ($0, days[Self.key(for: $0, calendar: calendar)] ?? Day()) }
        }
    }

    package func total(last count: Int, endingOn date: Date, calendar: Calendar = .current) -> Day {
        daily(last: count, endingOn: date, calendar: calendar).map(\.day).reduce(Day(), +)
    }
}
