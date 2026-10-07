import Foundation

/// Distributed notifications the E2E suite sends to Dictate. The app listens only when launched with
/// `DICTATE_E2E=1` (`LaunchOptions.acceptsTestControl`); the object is a string.
public enum TestNotification {
    /// Object: the path of a 16 kHz mono WAV file to dictate as if it had been spoken.
    public static let dictateFile = "dev.dictate.e2e.dictateFile"
    /// Object: a `Mode` raw value.
    public static let setMode = "dev.dictate.e2e.setMode"
}
