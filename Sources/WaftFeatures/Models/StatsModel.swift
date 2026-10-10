import Foundation
import NaturalLanguage
import Observation
import os
import WaftCore

@Observable
package final class StatsModel {
    package private(set) var stats: DictationStats

    @ObservationIgnored private let store: any ValueStore<DictationStats>

    init(store: any ValueStore<DictationStats>) {
        self.store = store

        do {
            stats = try store.load() ?? DictationStats()
        } catch {
            Logger.settings.error("Couldn't read the stats: \(error.localizedDescription, privacy: .public)")

            stats = DictationStats()
        }
    }

    package static func wordCount(of text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        return tokenizer.tokens(for: text.startIndex ..< text.endIndex).count
    }

    func record(_ text: String, seconds: Double) {
        stats.record(words: Self.wordCount(of: text), seconds: seconds, on: Date())
        save()
    }

    func reset() {
        stats = DictationStats()

        do {
            try store.delete()
        } catch {
            Logger.settings.error("Couldn't delete the stats: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            try store.save(stats)
        } catch {
            Logger.settings.error("Couldn't save the stats: \(error.localizedDescription, privacy: .public)")
        }
    }
}
