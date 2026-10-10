import SwiftUI

struct DictionarySettingsPane: View {
    @Bindable var vocabulary: VocabularyModel

    var body: some View {
        SettingsSection("Terms", subtitle: "Names and words that come out wrong.") {
            if vocabulary.terms.isEmpty {
                EmptyRow("No terms yet")
            }

            ForEach(vocabulary.terms) { term in
                if term.id != vocabulary.terms.first?.id {
                    RowDivider()
                }

                EntryRow(
                    first: termField(term.id, \.term),
                    firstPrompt: "Term",
                    second: termField(term.id, \.spokenForms),
                    secondPrompt: "Heard as",
                ) {
                    vocabulary.removeTerm(term.id)
                }
                .rowTransition()
            }
        } footer: {
            Button("Add Term") { vocabulary.addTerm() }
        }
        .animation(Motion.layout, value: vocabulary.terms.count)

        SettingsSection("Snippets", subtitle: "Say the phrase on its own to paste the text.") {
            if vocabulary.snippets.isEmpty {
                EmptyRow("No snippets yet")
            }

            ForEach(vocabulary.snippets) { snippet in
                if snippet.id != vocabulary.snippets.first?.id {
                    RowDivider()
                }

                EntryRow(
                    first: snippetField(snippet.id, \.trigger),
                    firstPrompt: "Phrase to say",
                    second: snippetField(snippet.id, \.text),
                    secondPrompt: "Text to paste",
                ) {
                    vocabulary.removeSnippet(snippet.id)
                }
                .rowTransition()
            }
        } footer: {
            Button("Add Snippet") { vocabulary.addSnippet() }
        }
        .animation(Motion.layout, value: vocabulary.snippets.count)

        SettingsSection("File", subtitle: "Both lists are saved as a JSON file you can edit.") {
            SettingsRow("Dictionary file") {
                Button("Open in Editor") { vocabulary.openInEditor() }
                Button("Show in Finder") { vocabulary.revealInFinder() }
            }
        }
    }

    private func termField(_ id: UUID, _ field: WritableKeyPath<VocabularyModel.TermDraft, String>) -> Binding<String> {
        Binding(
            get: { vocabulary.terms.first { $0.id == id }?[keyPath: field] ?? "" },
            set: { value in
                guard let index = vocabulary.terms.firstIndex(where: { $0.id == id }) else { return }

                vocabulary.terms[index][keyPath: field] = value
            },
        )
    }

    private func snippetField(_ id: UUID, _ field: WritableKeyPath<VocabularyModel.SnippetDraft, String>) -> Binding<String> {
        Binding(
            get: { vocabulary.snippets.first { $0.id == id }?[keyPath: field] ?? "" },
            set: { value in
                guard let index = vocabulary.snippets.firstIndex(where: { $0.id == id }) else { return }

                vocabulary.snippets[index][keyPath: field] = value
            },
        )
    }
}

private struct EntryRow: View {
    @Binding var first: String

    let firstPrompt: LocalizedStringKey

    @Binding var second: String

    let secondPrompt: LocalizedStringKey
    let remove: () -> Void

    var body: some View {
        HStack(spacing: Metrics.controlSpacing) {
            InputField(firstPrompt, text: $first)

            Image(systemName: "arrow.right")
                .font(.glyph)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            InputField(secondPrompt, text: $second)

            RemoveButton(help: "Remove", action: remove)
        }
        .settingsRowPadding()
    }
}
