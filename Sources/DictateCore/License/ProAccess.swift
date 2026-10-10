import Foundation

package struct ProAccess: Equatable, Sendable {
    package enum Status: Equatable, Sendable {
        case licensed(License)
        case trial(daysLeft: Int)
        case expired
    }

    package static let trialLength = 3

    package let status: Status

    package var isUnlocked: Bool {
        status != .expired
    }

    package init(license: License?, trialStarted: Date, now: Date, calendar: Calendar = .current) {
        if let license {
            status = .licensed(license)

            return
        }

        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: trialStarted),
            to: calendar.startOfDay(for: now),
        )
        let daysLeft = Self.trialLength - (elapsed.day ?? 0)

        status = daysLeft > 0 ? .trial(daysLeft: daysLeft) : .expired
    }

    package func allows(_: ProFeature) -> Bool {
        isUnlocked
    }
}
