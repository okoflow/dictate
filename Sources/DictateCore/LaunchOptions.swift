import Foundation

/// Command-line options of Dictate.app. All are optional; they exist for diagnostics and the
/// E2E suite (a normal launch from Finder passes none).
public struct LaunchOptions: Equatable, Sendable {
    /// Write the permission report here at launch.
    public var reportFile: String?
    /// Append `AppEvent`s here as JSON lines.
    public var eventLog: String?
    /// Keep each finished recording as a WAV file in this directory (otherwise audio stays in memory).
    public var recordingDirectory: String?
    /// Record from the input device with this name instead of the system default.
    public var inputDevice: String?

    /// Only copy dictated text to the clipboard, never paste it (the "Insert into the focused field" setting
    /// forced off; the E2E suite uses it to check the clipboard path).
    public var clipboardOnly: Bool
    /// Test-only, honoured only with `DICTATE_E2E=1`: paste only into the app with this bundle identifier and
    /// do nothing (not even touch the clipboard) elsewhere, so the E2E suite cannot type into the user's apps.
    public var insertOnlyInto: String?
    /// Speech model to use instead of `ModelStore.defaultModel` (a WhisperKit variant name).
    public var model: String?
    /// Save each transcript as `<n>.txt` here. Test-only: honoured only when the environment has
    /// `DICTATE_E2E=1` (the E2E runner sets it), so a normal launch, even with this flag typed by
    /// mistake, never writes dictated text to disk.
    public var transcriptDirectory: String?

    public init(arguments: [String], environment: [String: String] = ProcessInfo.processInfo.environment) {
        reportFile = argumentValue(after: "--report-file", in: arguments)
        eventLog = argumentValue(after: "--event-log", in: arguments)
        recordingDirectory = argumentValue(after: "--recording-dir", in: arguments)
        inputDevice = argumentValue(after: "--input-device", in: arguments)
        clipboardOnly = arguments.contains("--clipboard-only")
        model = argumentValue(after: "--model", in: arguments)
        insertOnlyInto = environment["DICTATE_E2E"] == "1" ? argumentValue(after: "--insert-only-into", in: arguments) : nil
        transcriptDirectory = environment["DICTATE_E2E"] == "1" ? argumentValue(after: "--transcript-dir", in: arguments) : nil
    }
}
