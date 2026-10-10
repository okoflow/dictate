import AppKit
import DictateCore
import Foundation
import Observation
import os

@Observable
package final class VocabularyModel {
    package struct TermDraft: Identifiable {
        package let id = UUID()
        package var term: String
        package var spokenForms: String
    }

    package struct SnippetDraft: Identifiable {
        package let id = UUID()
        package var trigger: String
        package var text: String
    }

    package var terms: [TermDraft] = [] {
        didSet { draftsDidChange() }
    }

    package var snippets: [SnippetDraft] = [] {
        didSet { draftsDidChange() }
    }

    @ObservationIgnored private(set) var current = Vocabulary.empty

    @ObservationIgnored private let store: any ValueStore<Vocabulary>
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var isLoadingDrafts = false

    init(store: any ValueStore<Vocabulary>, fileURL: URL) {
        self.store = store
        self.fileURL = fileURL
        loadDrafts(from: Self.load(from: store) ?? .empty)
    }

    private static func load(from store: any ValueStore<Vocabulary>) -> Vocabulary? {
        do {
            return try store.load()
        } catch {
            Logger.settings
                .error("Couldn't read the dictionary, keeping the last good one: \(error.localizedDescription, privacy: .public)")

            return nil
        }
    }

    private static func vocabulary(from terms: [TermDraft], _ snippets: [SnippetDraft]) -> Vocabulary {
        let validTerms = terms.compactMap { draft -> Vocabulary.Term? in
            let term = draft.term.trimmingCharacters(in: .whitespaces)
            guard !term.isEmpty else { return nil }

            let spoken = draft.spokenForms.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            return Vocabulary.Term(term: term, spoken: spoken)
        }
        let validSnippets = snippets.filter { !$0.trigger.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { Vocabulary.Snippet(trigger: $0.trigger.trimmingCharacters(in: .whitespaces), text: $0.text) }

        return Vocabulary(terms: validTerms, snippets: validSnippets)
    }

    package func addTerm() {
        terms.append(TermDraft(term: "", spokenForms: ""))
    }

    package func removeTerm(_ id: TermDraft.ID) {
        terms.removeAll { $0.id == id }
    }

    package func addSnippet() {
        snippets.append(SnippetDraft(trigger: "", text: ""))
    }

    package func removeSnippet(_ id: SnippetDraft.ID) {
        snippets.removeAll { $0.id == id }
    }

    package func openInEditor() {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            save(current)
        }

        NSWorkspace.shared.open(fileURL)
    }

    package func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    func reloadFromDisk() -> Vocabulary {
        if let latest = Self.load(from: store), latest != current {
            loadDrafts(from: latest)
        }

        return current
    }

    private func loadDrafts(from vocabulary: Vocabulary) {
        isLoadingDrafts = true
        defer { isLoadingDrafts = false }

        current = vocabulary
        terms = vocabulary.terms.map { TermDraft(term: $0.term, spokenForms: $0.spoken.joined(separator: ", ")) }
        snippets = vocabulary.snippets.map { SnippetDraft(trigger: $0.trigger, text: $0.text) }
    }

    private func draftsDidChange() {
        guard !isLoadingDrafts else { return }

        let edited = Self.vocabulary(from: terms, snippets)
        guard edited != current else { return }

        current = edited
        save(edited)
    }

    private func save(_ vocabulary: Vocabulary) {
        do {
            try store.save(vocabulary)
        } catch {
            Logger.settings.error("Couldn't save the dictionary: \(error.localizedDescription, privacy: .public)")
        }
    }
}
