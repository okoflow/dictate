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

    public init(arguments: [String]) {
        reportFile = argumentValue(after: "--report-file", in: arguments)
        eventLog = argumentValue(after: "--event-log", in: arguments)
        recordingDirectory = argumentValue(after: "--recording-dir", in: arguments)
        inputDevice = argumentValue(after: "--input-device", in: arguments)
    }
}
