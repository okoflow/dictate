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
    /// The speech model is loaded; `loadSeconds` covers the Core ML compile on the first run.
    case modelReady(name: String, loadSeconds: Double)
    /// A recording became text. Only the length is logged, never the text itself.
    case transcribed(language: Language, characters: Int, seconds: Double)
    /// The recording held no speech, or the model heard none; nothing was copied.
    case noSpeech
    case transcriptionFailed(String)
    /// The key-up never reached the event tap and the keyboard state said the key had been up for a second,
    /// so the recording was ended as if it had been released.
    case watchdogReleased
    /// The text was pasted into `app` (a bundle identifier). `secureInputActive` is macOS's global
    /// secure-input flag at that moment; it is reported, not used to decide. Never the text itself.
    case inserted(characters: Int, app: String, secureInputActive: Bool)
    /// The text was not pasted; it stays recoverable ("Copy last transcript", or the clipboard).
    case insertionSkipped(InsertionRules.SkipReason)
    /// The clipboard the user had before the paste was left as it is now, and why.
    case restoreSkipped(String)
    /// The mode was switched (menu or hotkey).
    case modeChanged(Mode)
    /// The transcript went through `mode`; `applied` is what really ran (Light after a fallback, and why).
    /// `cloud` says whether a request was sent to the LLM API. Never the text, only its length after processing.
    case processed(mode: Mode, applied: Mode, fallback: FallbackReason?, cloud: Bool, characters: Int, seconds: Double)
    /// The app the dictation was for has its own mode, and it was used instead of the menu's.
    case appModeUsed(app: String, mode: Mode)
    /// The whole dictation was a snippet's trigger; its text was delivered as it is (no mode, no cloud).
    case snippetExpanded
    /// Test-only: a WAV file was dictated through a notification instead of the microphone.
    case fileSubmitted(file: String)

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
