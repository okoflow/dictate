@preconcurrency import AVFoundation
import DictateCore
import os

/// The audio thread's half of a recording: converts each tap buffer to 16 kHz mono and keeps it.
///
/// The tap block runs on a real-time audio thread, so it may capture only this object, never
/// anything main-actor isolated (that traps under Swift 6). The class is `@unchecked Sendable`
/// because its one mutable field lives behind an unfair lock and the rest is immutable.
final class AudioSink: @unchecked Sendable {
    static let sampleRate = 16000.0

    private struct Kept {
        var samples: [Float] = []
        var sawFirstBuffer = false
        /// Uptime (seconds) at the end of the last buffer kept: how far the recording reaches in time.
        var coveredUntil = 0.0
    }

    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let inputRate: Double
    private let kept = OSAllocatedUnfairLock(initialState: Kept())
    private let meter: LevelMeter
    private let onFirstBuffer: @Sendable () -> Void

    /// `nil` if CoreAudio cannot convert `inputFormat` to 16 kHz mono.
    init?(inputFormat: AVAudioFormat, meter: LevelMeter, onFirstBuffer: @escaping @Sendable () -> Void) {
        guard let output = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1, interleaved: false
        ),
            let converter = AVAudioConverter(from: inputFormat, to: output)
        else { return nil }
        // Without this a stereo source (BlackHole, most USB mics) is reduced to its first channel.
        converter.downmix = true
        self.converter = converter
        outputFormat = output
        inputRate = inputFormat.sampleRate
        self.meter = meter
        self.onFirstBuffer = onFirstBuffer
    }

    /// Called on the audio thread for every tap buffer; `time` says when its first sample was captured.
    func consume(_ input: AVAudioPCMBuffer, at time: AVAudioTime) {
        let start = time.isHostTimeValid ? AVAudioTime.seconds(forHostTime: time.hostTime) : uptimeSeconds()
        let end = start + Double(input.frameLength) / inputRate
        let capacity = AVAudioFrameCount((Double(input.frameLength) * Self.sampleRate / inputRate).rounded(.up)) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        // Hand the buffer over once, then say "no more for now". `.endOfStream` would finish the
        // converter permanently and every later buffer would come out empty.
        // The block runs synchronously inside `convert`, so this flag is never touched concurrently.
        nonisolated(unsafe) var handedOver = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if handedOver {
                status.pointee = .noDataNow
                return nil
            }
            handedOver = true
            status.pointee = .haveData
            return input
        }
        guard error == nil, output.frameLength > 0, let channel = output.floatChannelData?[0] else { return }

        let converted = UnsafeBufferPointer(start: channel, count: Int(output.frameLength))
        meter.value = AudioLevel.meterValue(rms: AudioLevel.rms(converted))
        // Unchecked: `converted` points into `output`, which outlives this synchronous call.
        let isFirst = kept.withLockUnchecked { kept in
            kept.samples.append(contentsOf: converted)
            kept.coveredUntil = end
            defer { kept.sawFirstBuffer = true }
            return !kept.sawFirstBuffer
        }
        if isFirst {
            onFirstBuffer()
        }
    }

    /// Whether any audio has arrived yet.
    var hasAudio: Bool {
        kept.withLock { $0.sawFirstBuffer }
    }

    /// Uptime (seconds) up to which audio has been captured.
    var coveredUntil: Double {
        kept.withLock { $0.coveredUntil }
    }

    /// Everything captured so far.
    func takeSamples() -> [Float] {
        kept.withLock { $0.samples }
    }
}

/// Latest input level (0...1), written on the audio thread and read by the overlay's timer.
final class LevelMeter: Sendable {
    private let stored = OSAllocatedUnfairLock(initialState: Float(0))

    var value: Float {
        get { stored.withLock { $0 } }
        set { stored.withLock { $0 = newValue } }
    }
}
