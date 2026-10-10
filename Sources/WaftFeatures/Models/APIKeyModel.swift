import Foundation
import Observation
import os
import WaftCore

@Observable
package final class APIKeyModel {
    package private(set) var isSet: Bool
    package var draft = ""

    @ObservationIgnored private let store: any ValueStore<String>

    package var canSaveDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(store: any ValueStore<String>) {
        self.store = store
        isSet = store.exists()
    }

    package func saveDraft() {
        let key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        do {
            try store.save(key)

            draft = ""
        } catch {
            Logger.settings.error("Couldn't save the API key: \(error.localizedDescription, privacy: .public)")
        }

        refresh()
    }

    package func remove() {
        try? store.delete()
        refresh()
    }

    private func refresh() {
        isSet = store.exists()
    }
}
