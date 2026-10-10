import Foundation

package enum HistoryRetention: String, CaseIterable, Codable, Sendable {
    case day
    case week
    case month
    case year
    case forever

    package var title: String {
        switch self {
        case .day: String(localized: "1 day")
        case .week: String(localized: "1 week")
        case .month: String(localized: "1 month")
        case .year: String(localized: "1 year")
        case .forever: String(localized: "Forever")
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
