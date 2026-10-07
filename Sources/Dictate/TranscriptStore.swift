import Foundation

/// Saves each transcript as `<name>.txt`, used only by the E2E suite (`--transcript-dir`, and only
/// together with `--event-log`): dictated text is otherwise never written anywhere.
enum TranscriptStore {
    static func save(_ text: String, name: String, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: directory.appendingPathComponent("\(name).txt"), atomically: true, encoding: .utf8)
    }
}
