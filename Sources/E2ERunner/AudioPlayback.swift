import AudioDevices
@preconcurrency import AVFoundation
import Foundation

/// A WAV file ready to be played into one specific output device (BlackHole), independent of the
/// system default, so the E2E suite can "speak" into the microphone path without making any sound.
///
/// Preparing is separate from playing on purpose: an `AVAudioEngine` posts a configuration change
/// shortly after it starts, and if that lands in the middle of playback the player stops early and the
/// recording is missing most of the speech. Starting the engine (and letting that settle) before the key
/// is pressed keeps it out of the measured hold.
///
/// `AVAudioEngine` rather than `AudioQueue`: an `AudioQueue` bound to BlackHole (which has both
/// inputs and outputs) blocks forever in `AudioQueueStart` for a process without microphone access
/// of its own, whereas an engine's output unit only touches the output side.
final class PreparedPlayback {
    enum Failure: Error, CustomStringConvertible {
        case cannotSelect(OSStatus)
        case interrupted(played: Double, expected: Double)

        var description: String {
            switch self {
            case let .cannotSelect(status): "cannot select the output device (OSStatus \(status))"
            case let .interrupted(played, expected):
                String(format: "playback ended after %.2f s of %.2f s (audio engine reconfigured)", played, expected)
            }
        }
    }

    private let file: AVAudioFile
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    /// Starts an engine that outputs to `device` and waits for its start-up notifications to pass.
    init(wavAt url: URL, on device: AudioDevice) throws {
        file = try AVAudioFile(forReading: url)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
        guard let unit = engine.outputNode.audioUnit else { throw Failure.cannotSelect(0) }
        var id = device.id
        let status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw Failure.cannotSelect(status) }
        try engine.start()
        Thread.sleep(forTimeInterval: 0.5)
        if !engine.isRunning {
            try engine.start()
        }
    }

    deinit {
        engine.stop()
    }

    /// Blocks until the whole file has been played out; throws if it stopped early.
    func play() throws {
        let finished = DispatchSemaphore(value: 0)
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { _ in finished.signal() }
        let began = ProcessInfo.processInfo.systemUptime
        player.play()
        let seconds = Double(file.length) / file.processingFormat.sampleRate
        _ = finished.wait(timeout: .now() + seconds + 5)
        let played = ProcessInfo.processInfo.systemUptime - began
        guard played >= seconds - 0.05, engine.isRunning else { throw Failure.interrupted(played: played, expected: seconds) }
    }
}
