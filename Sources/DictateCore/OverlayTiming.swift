import Foundation

/// How long the pill keeps a message on screen: enough to read it.
public enum OverlayTiming {
    /// A short text stays this long.
    public static let baseSeconds = 2.0
    /// Each further 15 characters add a second.
    public static let charactersPerExtraSecond = 15.0
    public static let maximumSeconds = 10.0

    public static func messageSeconds(characters: Int) -> Double {
        min(maximumSeconds, baseSeconds + Double(max(0, characters)) / charactersPerExtraSecond)
    }
}
