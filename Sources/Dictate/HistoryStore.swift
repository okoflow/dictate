import DictateCore
import Foundation
import Observation

/// The last dictations on disk (`~/Library/Application Support/Dictate/history.json`, or `--history-file`, readable
/// only by you), for the History menu. "Keep history" off stops adding to it; "Clear history" deletes the file.
@MainActor
@Observable
final class HistoryStore {
    private static let key = "keepHistory"
    static let defaultURL = URL.applicationSupportDirectory.appending(path: "Dictate/history.json")

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.key) }
    }

    private(set) var history: DictationHistory
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let url: URL

    init(path: String?, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        url = path.map { URL(fileURLWithPath: $0) } ?? Self.defaultURL
        isEnabled = defaults.object(forKey: Self.key) as? Bool ?? true
        history = (try? JSONDecoder().decode(DictationHistory.self, from: Data(contentsOf: url))) ?? DictationHistory()
    }

    func add(_ entry: DictationHistory.Entry) {
        guard isEnabled else { return }
        history.add(entry)
        save()
    }

    func clear() {
        history.clear()
        try? FileManager.default.removeItem(at: url)
    }

    private func save() {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
