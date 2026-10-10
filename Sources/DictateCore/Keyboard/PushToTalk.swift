import Foundation

package struct PushToTalk: Sendable {
    package enum Event: Equatable, Sendable {
        case keyDown
        case keyUp
        case otherKeyDown
        case monitorDisabled
        case tick
    }

    package enum Action: Equatable, Sendable {
        case startRecording
        case finishRecording(duration: TimeInterval)
        case discardRecording(DiscardReason)
    }

    package enum DiscardReason: String, Sendable {
        case tooShort
        case otherKeyPressed
        case interrupted
        case modelNotReady
    }

    private enum State: Equatable {
        case idle
        case holding(since: TimeInterval)
        case cancelled
    }

    package static let minimumHold: TimeInterval = 0.3
    package static let maximumHold: TimeInterval = 300

    private var state = State.idle

    package init() {}

    private static func releaseAction(heldFor duration: TimeInterval) -> Action {
        duration >= minimumHold ? .finishRecording(duration: duration) : .discardRecording(.tooShort)
    }

    package mutating func handle(_ event: Event, at time: TimeInterval) -> Action? {
        switch (state, event) {
        case (.idle, .keyDown), (.cancelled, .keyDown):
            state = .holding(since: time)

            return .startRecording

        case let (.holding(since), .keyUp):
            state = .idle

            return Self.releaseAction(heldFor: time - since)

        case let (.holding(since), .tick) where time - since >= Self.maximumHold:
            state = .cancelled

            return .finishRecording(duration: time - since)

        case (.holding, .otherKeyDown):
            state = .cancelled

            return .discardRecording(.otherKeyPressed)

        case (.holding, .monitorDisabled):
            state = .idle

            return .discardRecording(.interrupted)

        case (.cancelled, .keyUp), (.cancelled, .monitorDisabled):
            state = .idle

            return nil

        default:
            return nil
        }
    }
}
