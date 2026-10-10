import Foundation

package struct ReleaseWatchdog: Sendable {
    package enum Verdict: Equatable, Sendable {
        case holding
        case released(since: TimeInterval)
    }

    package static let requiredReleasedPolls = 4

    private var releasedSince: TimeInterval?
    private var releasedPolls = 0

    package init() {}

    package mutating func poll(isHeld: Bool, at time: TimeInterval) -> Verdict {
        guard !isHeld else {
            reset()

            return .holding
        }

        let since = releasedSince ?? time

        releasedSince = since
        releasedPolls += 1

        return releasedPolls >= Self.requiredReleasedPolls ? .released(since: since) : .holding
    }

    package mutating func keyWasSeen() {
        reset()
    }

    package mutating func reset() {
        releasedSince = nil
        releasedPolls = 0
    }
}
