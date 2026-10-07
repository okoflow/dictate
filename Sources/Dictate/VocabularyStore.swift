import AppKit
import DictateCore
import Foundation

/// The personal dictionary file (`~/Library/Application Support/Dictate/dictionary.json`, or `--dictionary`).
/// It is read again whenever it has changed, so edits apply to the next dictation without a restart.
@MainActor
final class VocabularyStore {
    static let defaultURL = URL.applicationSupportDirectory.appending(path: "Dictate/dictionary.json")

    private let url: URL
    private let eventLog: EventLogWriter
    private var cached = Vocabulary.empty
    private var cachedDate: Date?

    init(path: String?, eventLog: EventLogWriter) {
        url = path.map { URL(fileURLWithPath: $0) } ?? Self.defaultURL
        self.eventLog = eventLog
    }

    /// The dictionary as the file says now; empty if there is no file. A broken file keeps the last good one.
    var current: Vocabulary {
        let date = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        guard date != cachedDate else { return cached }
        cachedDate = date
        guard date != nil else {
            cached = .empty
            return cached
        }
        do {
            cached = try JSONDecoder().decode(Vocabulary.self, from: Data(contentsOf: url))
        } catch {
            eventLog.log(.transcriptionFailed("the dictionary file cannot be read: \(error.localizedDescription)"))
        }
        return cached
    }

    /// Opens the file in the default editor, creating an empty one first.
    func openForEditing() {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? Data("{\n  \"terms\": [],\n  \"snippets\": []\n}\n".utf8).write(to: url)
        }
        NSWorkspace.shared.open(url)
    }
}
