import AVFoundation
import DictateCore

package struct MediaAudioReader: MediaDecoder {
    package init() {}

    private static func append(_ buffer: CMSampleBuffer, to samples: inout [Float]) {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { return }

        let length = CMBlockBufferGetDataLength(block)
        let count = length / MemoryLayout<Float>.size
        let start = samples.count

        samples.append(contentsOf: repeatElement(0, count: count))
        samples.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else { return }

            _ = CMBlockBufferCopyDataBytes(
                block,
                atOffset: 0,
                dataLength: count * MemoryLayout<Float>.size,
                destination: base + start * MemoryLayout<Float>.size,
            )
        }
    }

    @concurrent
    package func samples(of url: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw MediaAudioError.noAudio }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: SpeechAudio.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)

        guard reader.startReading() else { throw reader.error ?? MediaAudioError.unreadable }

        var samples: [Float] = []

        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            Self.append(buffer, to: &samples)
        }

        guard reader.status == .completed else { throw reader.error ?? MediaAudioError.unreadable }

        return samples
    }
}

package enum MediaAudioError: LocalizedError {
    case noAudio
    case unreadable

    package var errorDescription: String? {
        switch self {
        case .noAudio: String(localized: "The file has no sound to transcribe.")
        case .unreadable: String(localized: "Dictate can't read this file.")
        }
    }
}
