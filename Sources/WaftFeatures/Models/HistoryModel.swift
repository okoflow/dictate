import Foundation
import Observation
import os
import WaftCore

@Observable
package final class HistoryModel {
    package private(set) var history: DictationHistory
    package var searchText = ""

    @ObservationIgnored private let store: any ValueStore<DictationHistory>

    package var matchingEntries: [DictationHistory.Entry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return history.newestFirst }

        return history.newestFirst.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    init(store: any ValueStore<DictationHistory>) {
        self.store = store

        do {
            history = try store.load() ?? DictationHistory()
        } catch {
            Logger.settings.error("Couldn't read the history: \(error.localizedDescription, privacy: .public)")

            history = DictationHistory()
        }
    }

    package func recentEntries(limit: Int) -> [DictationHistory.Entry] {
        Array(history.newestFirst.prefix(limit))
    }

    package func removeAll() {
        history.removeAll()

        do {
            try store.delete()
        } catch {
            Logger.settings.error("Couldn't delete the history: \(error.localizedDescription, privacy: .public)")
        }
    }

    package func keep(for retention: HistoryRetention, limit: Int) {
        let previous = history
        history.prune(keeping: retention, limit: limit, now: Date())

        if history != previous {
            save()
        }
    }

    func add(_ entry: DictationHistory.Entry, keepingFor retention: HistoryRetention, limit: Int) {
        history.add(entry)
        history.prune(keeping: retention, limit: limit, now: entry.date)
        save()
    }

    private func save() {
        do {
            try store.save(history)
        } catch {
            Logger.settings.error("Couldn't save the history: \(error.localizedDescription, privacy: .public)")
        }
    }
}
