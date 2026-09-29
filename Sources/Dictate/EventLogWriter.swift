import DictateCore
import Foundation

/// Appends `AppEvent`s to the `--event-log` file. Does nothing when no file was requested.
@MainActor
final class EventLogWriter {
    private let handle: FileHandle?

    init(path: String?) {
        guard let path, FileManager.default.createFile(atPath: path, contents: nil) else {
            handle = nil
            return
        }
        handle = FileHandle(forWritingAtPath: path)
    }

    func log(_ event: AppEvent) {
        guard let handle, let line = try? event.jsonLine() else { return }
        try? handle.write(contentsOf: Data(line.utf8))
    }
}
