import Foundation

/// Decides, from polls of the keyboard state, that the hotkey was released without the key-up ever
/// reaching the event tap. The tap is the authority: a single poll that misses the key (the state words
/// are only intermittently in step with the real keyboard) must not end a dictation, so the release is
/// declared only after `requiredPolls` polls in a row found the key up, and any sign of the key from the
/// tap starts the count again.
public struct ReleaseWatchdog: Sendable {
    /// Polls in a row that must find the key up; at the app's 250 ms poll interval that is one second.
    public static let requiredPolls = 4

    public enum Verdict: Equatable, Sendable {
        case holding
        /// The key has been up since `since`, the time of the first of the polls that found it so.
        case released(since: Double)
    }

    private var releasedSince: Double?
    private var releasedPolls = 0

    public init() {}

    /// One poll at time `now` (any monotonic clock, seconds); `held` is what the keyboard state says.
    public mutating func poll(held: Bool, at now: Double) -> Verdict {
        guard !held else {
            reset()
            return .holding
        }
        if releasedSince == nil {
            releasedSince = now
        }
        releasedPolls += 1
        guard releasedPolls >= Self.requiredPolls, let since = releasedSince else { return .holding }
        return .released(since: since)
    }

    /// The tap delivered an event that carries the right-Option bit: the key is down.
    public mutating func sawHotkeyEvent() {
        reset()
    }

    public mutating func reset() {
        releasedSince = nil
        releasedPolls = 0
    }
}
