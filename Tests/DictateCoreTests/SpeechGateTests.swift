@testable import DictateCore
import Testing

struct SpeechGateTests {
    private let rate = 16000.0

    private func tone(seconds: Double, level: Float = 0.3) -> [Float] {
        [Float](repeating: level, count: Int(seconds * rate))
    }

    private func silence(seconds: Double) -> [Float] {
        [Float](repeating: 0, count: Int(seconds * rate))
    }

    @Test func emptyRecordingHasNoSpeech() {
        #expect(SpeechGate.decide(samples: [], sampleRate: rate) == .noSpeech)
    }

    @Test func silenceHasNoSpeech() {
        #expect(SpeechGate.decide(samples: silence(seconds: 2), sampleRate: rate) == .noSpeech)
    }

    @Test func veryQuietNoiseHasNoSpeech() {
        #expect(SpeechGate.decide(samples: tone(seconds: 2, level: 0.001), sampleRate: rate) == .noSpeech)
    }

    @Test func aBlipShorterThanTheMinimumHasNoSpeech() {
        let samples = silence(seconds: 1) + tone(seconds: 0.1) + silence(seconds: 1)
        #expect(SpeechGate.decide(samples: samples, sampleRate: rate) == .noSpeech)
    }

    @Test func aLongEnoughStretchIsTranscribed() {
        let samples = silence(seconds: 0.5) + tone(seconds: 0.5) + silence(seconds: 0.5)
        #expect(SpeechGate.decide(samples: samples, sampleRate: rate) == .transcribe)
    }

    @Test func theBoundaryIsInclusive() {
        let samples = tone(seconds: SpeechGate.minimumSpeechSeconds)
        #expect(SpeechGate.decide(samples: samples, sampleRate: rate) == .transcribe)
    }
}
