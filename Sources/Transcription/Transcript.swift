import DictateCore
import Foundation

/// What the recogniser made of one recording.
public struct Transcript: Equatable, Sendable {
    public let text: String
    public let language: Language
    /// Probability of `language` among ru / en / ko when it was detected; `nil` when the language was pinned.
    public let languageProbability: Double?
    /// Seconds the language detection took (0 when the language was pinned).
    public let detectSeconds: Double
    /// Seconds the decoding took.
    public let transcribeSeconds: Double

    public var seconds: Double {
        detectSeconds + transcribeSeconds
    }
}
