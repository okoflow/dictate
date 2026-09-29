import DictateCore
import Foundation

/// Saves recordings as WAV files, used only with `--recording-dir` (by default audio never
/// touches the disk).
enum RecordingStore {
    /// Writes `samples` as `<timestamp>.wav` in `directory` and returns its URL.
    ///
    /// The bytes go to `<timestamp>.tmp` first and the file is renamed only once it is complete,
    /// so a reader that sees a `.wav` never sees half a recording.
    static func save(_ samples: [Float], in directory: URL, at date: Date = Date()) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let name = formatter.string(from: date)
        let partial = directory.appendingPathComponent("\(name).tmp")
        let final = directory.appendingPathComponent("\(name).wav")
        try WAVEncoder.encode(samples, sampleRate: Int(AudioSink.sampleRate)).write(to: partial)
        try FileManager.default.moveItem(at: partial, to: final)
        return final
    }
}
