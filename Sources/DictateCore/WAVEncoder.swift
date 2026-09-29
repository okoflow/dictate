import Foundation

/// Serialises audio as a canonical 16-bit PCM mono WAV. Hand-written rather than going through
/// `AVAudioFile` so the bytes are deterministic and unit-testable, and there is no file handle
/// to forget to close before the file is renamed into place.
public enum WAVEncoder {
    public static let headerSize = 44

    /// Float samples in -1...1 (values outside are clipped) become little-endian Int16.
    public static func encode(_ samples: [Float], sampleRate: Int) -> Data {
        let dataSize = samples.count * 2
        var data = Data(capacity: headerSize + dataSize)
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(littleEndian: UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        data.append(littleEndian: UInt32(16)) // fmt chunk size
        data.append(littleEndian: UInt16(1)) // PCM
        data.append(littleEndian: UInt16(1)) // mono
        data.append(littleEndian: UInt32(sampleRate))
        data.append(littleEndian: UInt32(sampleRate * 2)) // byte rate
        data.append(littleEndian: UInt16(2)) // block align
        data.append(littleEndian: UInt16(16)) // bits per sample
        data.append(contentsOf: Array("data".utf8))
        data.append(littleEndian: UInt32(dataSize))
        for sample in samples {
            let clipped = max(-1, min(1, sample))
            data.append(littleEndian: Int16((clipped * Float(Int16.max)).rounded()))
        }
        return data
    }
}

private extension Data {
    mutating func append(littleEndian value: some FixedWidthInteger) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
