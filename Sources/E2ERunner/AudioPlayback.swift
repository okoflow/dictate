import AudioDevices
@preconcurrency import AVFoundation
import Foundation

/// Plays a WAV file into one specific output device (BlackHole), independent of the system default,
/// so the E2E suite can "speak" into the microphone path without making any sound.
///
/// `AVAudioEngine` rather than `AudioQueue`: an `AudioQueue` bound to BlackHole (which has both
/// inputs and outputs) blocks forever in `AudioQueueStart` for a process without microphone access
/// of its own, whereas an engine's output unit only touches the output side.
enum AudioPlayback {
    enum Failure: Error, CustomStringConvertible {
        case cannotSelect(OSStatus)
        case timedOut

        var description: String {
            switch self {
            case let .cannotSelect(status): "cannot select the output device (OSStatus \(status))"
            case .timedOut: "playback did not finish"
            }
        }
    }

    /// Blocks until the whole file has been played out.
    static func play(wavAt url: URL, on device: AudioDevice) throws {
        let file = try AVAudioFile(forReading: url)
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

        guard let unit = engine.outputNode.audioUnit else { throw Failure.cannotSelect(0) }
        var id = device.id
        let status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw Failure.cannotSelect(status) }

        try engine.start()
        defer { engine.stop() }
        let finished = DispatchSemaphore(value: 0)
        player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { _ in finished.signal() }
        player.play()
        let seconds = Double(file.length) / file.processingFormat.sampleRate
        guard finished.wait(timeout: .now() + seconds + 5) == .success else { throw Failure.timedOut }
    }
}
