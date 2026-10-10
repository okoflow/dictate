@preconcurrency import AVFoundation
import DictateCore
import os

final class AudioSampleSink: @unchecked Sendable {
    private struct Captured {
        var samples: [Float] = []
        var hasAudio = false
        var coveredUntil: TimeInterval = 0
    }

    static let sampleRate = 16000.0

    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let inputSampleRate: Double
    private let meter: LevelMeter
    private let onFirstBuffer: @Sendable () -> Void
    private let captured = OSAllocatedUnfairLock(initialState: Captured())

    var hasAudio: Bool {
        captured.withLock { $0.hasAudio }
    }

    var coveredUntil: TimeInterval {
        captured.withLock { $0.coveredUntil }
    }

    var samples: [Float] {
        captured.withLock { $0.samples }
    }

    init?(inputFormat: AVAudioFormat, meter: LevelMeter, onFirstBuffer: @escaping @Sendable () -> Void) {
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false,
        ),
            let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        else { return nil }

        converter.downmix = true

        self.converter = converter
        self.outputFormat = outputFormat
        inputSampleRate = inputFormat.sampleRate
        self.meter = meter
        self.onFirstBuffer = onFirstBuffer
    }

    func consume(_ input: AVAudioPCMBuffer, at time: AVAudioTime) {
        let start = time.isHostTimeValid ? AVAudioTime.seconds(forHostTime: time.hostTime) : Uptime.now
        let end = start + Double(input.frameLength) / inputSampleRate
        guard let converted = convert(input) else { return }

        meter.value = AudioLevel.meterValue(rms: AudioLevel.rms(converted))

        let isFirst = captured.withLock { captured in
            defer { captured.hasAudio = true }

            captured.samples.append(contentsOf: converted)
            captured.coveredUntil = end

            return !captured.hasAudio
        }

        if isFirst {
            onFirstBuffer()
        }
    }

    private func convert(_ input: AVAudioPCMBuffer) -> [Float]? {
        let capacity = AVAudioFrameCount((Double(input.frameLength) * Self.sampleRate / inputSampleRate).rounded(.up)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return nil }

        nonisolated(unsafe) var hasHandedOver = false
        var error: NSError?

        converter.convert(to: output, error: &error) { _, status in
            guard !hasHandedOver else {
                status.pointee = .noDataNow

                return nil
            }

            hasHandedOver = true
            status.pointee = .haveData

            return input
        }

        guard error == nil, output.frameLength > 0, let channel = output.floatChannelData?[0] else { return nil }

        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }
}
