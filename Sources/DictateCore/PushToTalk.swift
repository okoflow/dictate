import Foundation

/// What the keyboard did, reduced to what push-to-talk cares about.
public enum KeyboardSignal: Equatable, Sendable {
    case hotkeyDown
    case hotkeyUp
    /// Any other key pressed while the hotkey is held: the user is typing a combination
    /// (Option+letter), not dictating.
    case otherKeyDown
    /// macOS switched the event tap off (it was too slow, or secure input kicked in).
    case tapDisabled
    case ignored
}

/// Raw keyboard event, independent of CoreGraphics so it can be unit-tested.
public struct RawKeyEvent: Sendable {
    public enum Kind: Sendable {
        case flagsChanged
        case keyDown
        case tapDisabledByTimeout
        case tapDisabledByUserInput
        case other
    }

    public let kind: Kind
    public let keyCode: Int64
    public let flags: UInt64

    public init(kind: Kind, keyCode: Int64 = 0, flags: UInt64 = 0) {
        self.kind = kind
        self.keyCode = keyCode
        self.flags = flags
    }
}

/// The hotkey: the right Option key, which on its own types nothing.
public enum Hotkey {
    /// `kVK_RightOption`.
    public static let rightOptionKeyCode: Int64 = 61
    /// `NX_DEVICERALTKEYMASK`: set while the *right* Option key is down, whatever the left one does.
    public static let rightOptionDeviceFlag: UInt64 = 0x0000_0040
    /// `kCGEventFlagMaskAlternate`: set while either Option key is down.
    public static let optionFlag: UInt64 = 0x0008_0000

    public static func classify(_ event: RawKeyEvent) -> KeyboardSignal {
        switch event.kind {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            .tapDisabled
        case .keyDown:
            .otherKeyDown
        case .flagsChanged where event.keyCode == rightOptionKeyCode:
            event.flags & rightOptionDeviceFlag != 0 ? .hotkeyDown : .hotkeyUp
        case .flagsChanged, .other:
            .ignored
        }
    }
}

/// Push-to-talk state machine. Recording starts the moment the hotkey goes down (so the first
/// word is not lost); on release it is kept only if the press was long enough and no other key
/// was pressed meanwhile.
public struct PushToTalk: Sendable {
    public enum Action: Equatable, Sendable {
        case startRecording
        case finishRecording(seconds: Double)
        case discardRecording(DiscardReason)
    }

    public enum DiscardReason: String, Codable, Equatable, Sendable {
        case tooShort
        /// The user pressed another key: an Option+letter combination, not dictation.
        case otherKeyPressed
        /// The key-up can no longer be trusted (macOS disabled the event tap), so the recording
        /// was stopped rather than left running.
        case interrupted
    }

    public static let minimumPress: Double = 0.3

    private enum State: Equatable {
        case idle
        case holding(since: Double)
        /// Combination detected; wait for the hotkey release before arming again. Escapes: a fresh
        /// `hotkeyDown` (the release was lost, the user is pressing again) or `tapDisabled`.
        case cancelled
    }

    private var state = State.idle

    public init() {}

    public var isHolding: Bool {
        if case .holding = state {
            true
        } else {
            false
        }
    }

    /// Feeds one signal at time `now` (seconds, any monotonic clock); returns what to do, if anything.
    public mutating func handle(_ signal: KeyboardSignal, at now: Double) -> Action? {
        switch (state, signal) {
        case (.idle, .hotkeyDown):
            state = .holding(since: now)
            return .startRecording
        case let (.holding(since), .hotkeyUp):
            state = .idle
            let seconds = now - since
            return seconds >= Self.minimumPress ? .finishRecording(seconds: seconds) : .discardRecording(.tooShort)
        case (.holding, .otherKeyDown):
            state = .cancelled
            return .discardRecording(.otherKeyPressed)
        case (.holding, .tapDisabled):
            // Key-up may never arrive while the tap is off; do not leave the microphone on.
            state = .idle
            return .discardRecording(.interrupted)
        case (.cancelled, .hotkeyUp), (.cancelled, .tapDisabled):
            state = .idle
            return nil
        case (.cancelled, .hotkeyDown):
            // The release of the previous press never reached us; do not stay deaf to the key.
            state = .holding(since: now)
            return .startRecording
        default:
            return nil
        }
    }
}
