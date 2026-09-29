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

    /// A steady hum: loud in absolute terms, but never louder than itself.
    private func fan(seconds: Double, level: Float = 0.05) -> [Float] {
        (0 ..< Int(seconds * rate)).map { $0.isMultiple(of: 2) ? level : -level }
    }

    /// `count` clicks of 10 ms, evenly spread over `seconds`.
    private func clicks(count: Int, over seconds: Double) -> [Float] {
        var samples = silence(seconds: seconds)
        let gap = samples.count / count
        for index in 0 ..< count {
            for offset in 0 ..< Int(0.01 * rate) {
                samples[index * gap + offset] = 0.8
            }
        }
        return samples
    }

    @Test func emptyRecordingHasNoSpeech() {
        #expect(SpeechGate.decide(samples: [], sampleRate: rate) == .noSpeech)
    }

    @Test func silenceHasNoSpeech() {
        #expect(SpeechGate.decide(samples: silence(seconds: 2), sampleRate: rate) == .noSpeech)
    }

    @Test func veryQuietNoiseHasNoSpeech() {
        #expect(SpeechGate.decide(samples: tone(seconds: 2, level: 0.0005), sampleRate: rate) == .noSpeech)
    }

    @Test func aBlipShorterThanTheMinimumHasNoSpeech() {
        let samples = silence(seconds: 1) + tone(seconds: 0.1) + silence(seconds: 1)
        #expect(SpeechGate.decide(samples: samples, sampleRate: rate) == .noSpeech)
    }

    @Test func keyClicksAloneAreNotSpeechHoweverLongTheyStretch() {
        // The first and the last click are 4 s apart, but together they are loud for 0.2 s and each is a blip.
        #expect(SpeechGate.decide(samples: clicks(count: 10, over: 4), sampleRate: rate) == .noSpeech)
        #expect(SpeechGate.loudSeconds(of: clicks(count: 10, over: 4), sampleRate: rate) == 0)
    }

    @Test func steadyNoiseIsNotSpeech() {
        #expect(SpeechGate.decide(samples: fan(seconds: 3), sampleRate: rate) == .noSpeech)
    }

    @Test func speechOverSteadyNoiseIsTranscribed() {
        let noise = fan(seconds: 3)
        var samples = noise
        for index in Int(1.0 * rate) ..< Int(1.6 * rate) {
            samples[index] += index.isMultiple(of: 2) ? 0.4 : -0.4
        }
        #expect(SpeechGate.decide(samples: samples, sampleRate: rate) == .transcribe)
    }

    @Test func aLongEnoughStretchIsTranscribed() {
        let samples = silence(seconds: 0.5) + tone(seconds: 0.5) + silence(seconds: 0.5)
        #expect(SpeechGate.decide(samples: samples, sampleRate: rate) == .transcribe)
    }

    @Test func separateSyllablesAddUp() {
        let syllable = tone(seconds: 0.1) + silence(seconds: 0.1)
        let samples = silence(seconds: 0.5) + Array([[Float]](repeating: syllable, count: 4).joined()) + silence(seconds: 0.5)
        #expect(abs(SpeechGate.loudSeconds(of: samples, sampleRate: rate) - 0.4) < 0.05)
        #expect(SpeechGate.decide(samples: samples, sampleRate: rate) == .transcribe)
    }

    @Test func theBoundaryIsInclusive() {
        let samples = silence(seconds: 1) + tone(seconds: SpeechGate.minimumSpeechSeconds) + silence(seconds: 1)
        #expect(SpeechGate.decide(samples: samples, sampleRate: rate) == .transcribe)
    }
}
