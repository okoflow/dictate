import Foundation

/// Decides whether a recording is worth sending to the recogniser. Whisper invents text for
/// silence ("Thanks for watching"), so a recording without speech never reaches it.
public enum SpeechGate {
    /// The shortest stretch of speech (between the first and the last loud window) that counts.
    public static let minimumSpeechSeconds = 0.3

    public enum Decision: Equatable, Sendable {
        case transcribe
        /// No loud window, or too short a stretch of them.
        case noSpeech
    }

    public static func decide(samples: [Float], sampleRate: Double) -> Decision {
        guard let span = AudioLevel.speechSpan(of: samples, sampleRate: sampleRate), span >= minimumSpeechSeconds else {
            return .noSpeech
        }
        return .transcribe
    }
}
