import Foundation

package enum SpeechGate {
    package static let minimumSpeechDuration = 0.15
    package static let marginAboveNoiseFloor: Float = 8
    package static let absoluteFloorDecibels: Float = -60
    package static let minimumSyllableDuration = 0.06

    private static let windowDuration = 0.02
    private static let silenceDecibels: Float = -90

    package static func containsSpeech(_ samples: [Float], sampleRate: Double) -> Bool {
        loudDuration(of: samples, sampleRate: sampleRate) >= minimumSpeechDuration
    }

    package static func loudDuration(of samples: [Float], sampleRate: Double) -> Double {
        let levels = windowLevels(of: samples, sampleRate: sampleRate)
        guard !levels.isEmpty else { return 0 }

        let noiseFloor = levels.sorted()[levels.count / 10]
        let threshold = max(absoluteFloorDecibels, noiseFloor + marginAboveNoiseFloor)
        let minimumRun = Int((minimumSyllableDuration / windowDuration).rounded())

        return Double(loudWindowCount(in: levels, above: threshold, minimumRun: minimumRun)) * windowDuration
    }

    private static func windowLevels(of samples: [Float], sampleRate: Double) -> [Float] {
        let windowSize = max(1, Int(sampleRate * windowDuration))

        return stride(from: 0, to: samples.count, by: windowSize).map { start in
            let window = samples[start ..< min(start + windowSize, samples.count)]

            return max(silenceDecibels, AudioLevel.decibels(rms: AudioLevel.rms(window)))
        }
    }

    private static func loudWindowCount(in levels: [Float], above threshold: Float, minimumRun: Int) -> Int {
        var count = 0
        var run = 0

        for level in levels + [-.infinity] {
            if level > threshold {
                run += 1

                continue
            }

            if run >= minimumRun {
                count += run
            }

            run = 0
        }

        return count
    }
}
