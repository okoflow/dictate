import Foundation

/// Decides whether a recording is worth sending to the recogniser. Whisper invents text for
/// silence ("Thanks for watching"), and its own no-speech probability is not usable through WhisperKit
/// (it is always 0), so the check is made here on the audio.
///
/// "Loud" is relative to the recording's own noise floor: a fan or street noise is loud in absolute
/// terms but never louder than itself, and a keyboard click is loud but far too short.
public enum SpeechGate {
    /// The least total time of loud audio that counts as speech.
    public static let minimumSpeechSeconds = 0.3
    /// A window must beat the noise floor by this much.
    public static let marginDecibels: Float = 12
    /// Nothing quieter than this is ever loud, however silent the rest of the recording is.
    public static let absoluteFloorDecibels: Float = -60
    /// Speech is made of syllables at least this long; clicks and pops are shorter.
    public static let minimumRunSeconds = 0.06

    private static let window = 0.02

    public enum Decision: Equatable, Sendable {
        case transcribe
        /// Too little loud audio to be speech.
        case noSpeech
    }

    /// Seconds of audio that stand out from the noise floor in runs of at least `minimumRunSeconds`.
    public static func loudSeconds(of samples: [Float], sampleRate: Double) -> Double {
        let size = max(1, Int(sampleRate * window))
        let levels = stride(from: 0, to: samples.count, by: size).map { start -> Float in
            let level = AudioLevel.rms(samples[start ..< min(start + size, samples.count)])
            return level > 0 ? max(-90, 20 * log10(level)) : -90
        }
        guard !levels.isEmpty else { return 0 }
        // The quietest tenth of the windows is what the recording sounds like between words.
        let floor = levels.sorted()[levels.count / 10]
        let threshold = max(absoluteFloorDecibels, floor + marginDecibels)
        let minimumRun = Int((minimumRunSeconds / window).rounded())
        var loudWindows = 0
        var run = 0
        for level in levels + [-Float.infinity] {
            if level > threshold {
                run += 1
            } else {
                if run >= minimumRun {
                    loudWindows += run
                }
                run = 0
            }
        }
        return Double(loudWindows) * window
    }

    public static func decide(samples: [Float], sampleRate: Double) -> Decision {
        loudSeconds(of: samples, sampleRate: sampleRate) >= minimumSpeechSeconds ? .transcribe : .noSpeech
    }
}
