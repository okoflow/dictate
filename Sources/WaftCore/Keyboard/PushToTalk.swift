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
        case lockHandsFree
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
        case handsFree(since: TimeInterval)
        case stopping
        case cancelled
    }

    package static let minimumHold: TimeInterval = 0.3
    package static let maximumHold: TimeInterval = 300
    package static let doubleTapWindow: TimeInterval = 0.4

    package var allowsHandsFree = true

    private var state = State.idle
    private var lastTapEnded: TimeInterval?

    package init() {}

    package mutating func handle(_ event: Event, at time: TimeInterval) -> Action? {
        switch (state, event) {
        case (.idle, .keyDown), (.cancelled, .keyDown):
            state = .holding(since: time)

            return .startRecording

        case let (.holding(since), .keyUp):
            return release(heldSince: since, at: time)

        case let (.handsFree(since), .keyDown):
            state = .stopping

            return .finishRecording(duration: time - since)

        case let (.holding(since), .tick) where time - since >= Self.maximumHold:
            state = .cancelled

            return .finishRecording(duration: time - since)

        case let (.handsFree(since), .tick) where time - since >= Self.maximumHold:
            state = .stopping

            return .finishRecording(duration: time - since)

        case (.holding, .otherKeyDown):
            state = .cancelled

            return .discardRecording(.otherKeyPressed)

        case (.holding, .monitorDisabled), (.handsFree, .monitorDisabled):
            state = .idle

            return .discardRecording(.interrupted)

        case (.cancelled, .keyUp), (.cancelled, .monitorDisabled), (.stopping, .keyUp), (.stopping, .monitorDisabled):
            state = .idle

            return nil

        default:
            return nil
        }
    }

    private mutating func release(heldSince since: TimeInterval, at time: TimeInterval) -> Action {
        let duration = time - since

        if duration >= Self.minimumHold {
            state = .idle
            lastTapEnded = nil

            return .finishRecording(duration: duration)
        }

        if allowsHandsFree, let lastTapEnded, since - lastTapEnded <= Self.doubleTapWindow {
            state = .handsFree(since: since)
            self.lastTapEnded = nil

            return .lockHandsFree
        }

        state = .idle
        lastTapEnded = time

        return .discardRecording(.tooShort)
    }
}
