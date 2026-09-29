import Foundation

/// Loudness helpers for the level meter and for checking that a recording is not silence.
public enum AudioLevel {
    /// Root mean square of the samples (full scale = 1).
    public static func rms(_ samples: some Collection<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sum / Float(samples.count)).squareRoot()
    }

    /// Maps RMS to 0...1 for the meter: -50 dBFS and below is 0, 0 dBFS is 1.
    public static func meterValue(rms: Float, floorDecibels: Float = -50) -> Float {
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        return min(1, max(0, (decibels - floorDecibels) / -floorDecibels))
    }

    /// Seconds between the first and the last loud window: the stretch that contains speech,
    /// ignoring leading and trailing silence. A window is loud when its RMS exceeds `thresholdDecibels`.
    /// `nil` when no window is loud.
    public static func speechSpan(
        of samples: [Float],
        sampleRate: Double,
        window: Double = 0.02,
        thresholdDecibels: Float = -40
    ) -> Double? {
        let size = max(1, Int(sampleRate * window))
        let loud = stride(from: 0, to: samples.count, by: size).map { start in
            let level = rms(samples[start ..< min(start + size, samples.count)])
            return level > 0 && 20 * log10(level) > thresholdDecibels
        }
        guard let first = loud.firstIndex(of: true), let last = loud.lastIndex(of: true) else { return nil }
        return Double(last - first + 1) * window
    }
}
