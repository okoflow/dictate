package enum SpeechAudio {
    package static let sampleRate = 16000.0

    package static func duration(of samples: [Float]) -> Double {
        Double(samples.count) / sampleRate
    }
}
