import Foundation

/// Something the app did, written one JSON object per line to the file given with
/// `--event-log`. The E2E suite reads it back. Never contains dictated text or audio.
public enum AppEvent: Codable, Equatable, Sendable {
    /// The hotkey listener is installed and the app is ready for push-to-talk.
    case ready
    /// The hotkey listener could not be installed (usually: no Input Monitoring permission).
    case hotkeyUnavailable
    /// The first audio buffer arrived from `device` (its name), so the microphone is really live.
    case recordingStarted(device: String)
    /// `seconds` is the hold time; `samples` counts the 16 kHz mono samples kept, so a consumer can
    /// check `samples / 16000 ≈ seconds`. `file` is set only with `--recording-dir`.
    case recordingFinished(seconds: Double, samples: Int, file: String?)
    case recordingDiscarded(PushToTalk.DiscardReason)
    case recordingFailed(String)
    case overlayShown
    case overlayHidden
    case tapReenabled

    public func jsonLine() throws -> String {
        let data = try JSONEncoder().encode(self)
        return (String(bytes: data, encoding: .utf8) ?? "") + "\n"
    }

    /// Parses a whole event-log file; malformed lines (for example, one being written) are skipped.
    public static func parseLog(_ text: String) -> [AppEvent] {
        text.split(separator: "\n").compactMap { line in
            try? JSONDecoder().decode(AppEvent.self, from: Data(line.utf8))
        }
    }
}
