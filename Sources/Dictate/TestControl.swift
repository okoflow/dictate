import AVFoundation
import DictateCore
import Foundation

/// Test-only: lets the E2E suite dictate a WAV file and set the mode without posting keys (the WAV audio source of
/// the plan). Installed only when the app was launched with `DICTATE_E2E=1`.
@MainActor
enum TestControl {
    /// The observers live as long as the app, so they are never removed.
    static func install(onDictateFile: @escaping @MainActor (String) -> Void, onSetMode: @escaping @MainActor (Mode) -> Void) {
        let center = DistributedNotificationCenter.default()
        _ = center.addObserver(forName: .init(TestNotification.dictateFile), object: nil, queue: .main) { note in
            guard let path = note.object as? String else { return }
            MainActor.assumeIsolated { onDictateFile(path) }
        }
        _ = center.addObserver(forName: .init(TestNotification.setMode), object: nil, queue: .main) { note in
            guard let mode = (note.object as? String).flatMap(Mode.init(rawValue:)) else { return }
            MainActor.assumeIsolated { onSetMode(mode) }
        }
    }

    /// The samples of a 16 kHz mono WAV file, or `nil` if it cannot be read or has another format.
    nonisolated static func samples(ofWAVAt path: String) -> [Float]? {
        guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else { return nil }
        let format = file.processingFormat
        guard format.sampleRate == 16000, format.channelCount == 1,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil,
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}
