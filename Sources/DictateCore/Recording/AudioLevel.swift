import Foundation

package enum AudioLevel {
    package static let meterFloorDecibels: Float = -50

    package static func rms(_ samples: some Collection<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }

        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }

        return (sumOfSquares / Float(samples.count)).squareRoot()
    }

    package static func decibels(rms: Float) -> Float {
        rms > 0 ? 20 * log10(rms) : -.infinity
    }

    package static func meterValue(rms: Float) -> Float {
        guard rms > 0 else { return 0 }

        let normalized = (decibels(rms: rms) - meterFloorDecibels) / -meterFloorDecibels

        return min(1, max(0, normalized))
    }
}
