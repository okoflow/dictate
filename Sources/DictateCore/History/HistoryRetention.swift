import Foundation

package enum HistoryRetention: String, CaseIterable, Codable, Sendable {
    case day
    case week
    case month
    case year
    case forever

    package var title: String {
        switch self {
        case .day: "1 day"
        case .week: "1 week"
        case .month: "1 month"
        case .year: "1 year"
        case .forever: "Forever"
        }
    }

    package func cutoff(before date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .day: calendar.date(byAdding: .day, value: -1, to: date)
        case .week: calendar.date(byAdding: .day, value: -7, to: date)
        case .month: calendar.date(byAdding: .month, value: -1, to: date)
        case .year: calendar.date(byAdding: .year, value: -1, to: date)
        case .forever: nil
        }
    }
}
