@testable import DictateCore
import Foundation
import Testing

struct WAVEncoderTests {
    private func int16(_ data: Data, at offset: Int) -> Int16 {
        Int16(bitPattern: UInt16(data[offset]) | UInt16(data[offset + 1]) << 8)
    }

    private func uint32(_ data: Data, at offset: Int) -> UInt32 {
        (0 ..< 4).reduce(0) { $0 | UInt32(data[offset + $1]) << (8 * UInt32($1)) }
    }

    @Test func headerDescribesMono16BitPCM() {
        let wav = WAVEncoder.encode([0, 0.5, -0.5], sampleRate: 16000)
        #expect(String(bytes: wav[0 ..< 4], encoding: .ascii) == "RIFF")
        #expect(String(bytes: wav[8 ..< 16], encoding: .ascii) == "WAVEfmt ")
        #expect(String(bytes: wav[36 ..< 40], encoding: .ascii) == "data")
        #expect(uint32(wav, at: 4) == 36 + 6)
        #expect(uint32(wav, at: 24) == 16000)
        #expect(uint32(wav, at: 28) == 32000)
        #expect(uint32(wav, at: 40) == 6)
        #expect(wav.count == WAVEncoder.headerSize + 6)
    }

    @Test func samplesAreScaledAndClipped() {
        let wav = WAVEncoder.encode([0, 1, -1, 2, -2], sampleRate: 16000)
        let values = (0 ..< 5).map { int16(wav, at: WAVEncoder.headerSize + $0 * 2) }
        #expect(values == [0, .max, -.max, .max, -.max])
    }

    @Test func emptyRecordingIsAValidFile() {
        #expect(WAVEncoder.encode([], sampleRate: 16000).count == WAVEncoder.headerSize)
    }
}
