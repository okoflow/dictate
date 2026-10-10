import SwiftUI

struct DictionarySettingsPane: View {
    @Bindable var vocabulary: VocabularyModel

    var body: some View {
        SettingsSection("Terms", subtitle: "Names and words that come out wrong.") {
            if vocabulary.terms.isEmpty {
                EmptyRow("No terms yet")
            }

            ForEach($vocabulary.terms) { $term in
                if term.id != vocabulary.terms.first?.id {
                    RowDivider()
                }

                EntryRow(first: $term.term, firstPrompt: "Term", second: $term.spokenForms, secondPrompt: "Heard as") {
                    vocabulary.removeTerm(term.id)
                }
            }
        } footer: {
            Button("Add Term") { vocabulary.addTerm() }
        }
        .animation(.snappy(duration: 0.2), value: vocabulary.terms.count)

        SettingsSection("Snippets", subtitle: "Say the phrase on its own to paste the text.") {
            if vocabulary.snippets.isEmpty {
                EmptyRow("No snippets yet")
            }

            ForEach($vocabulary.snippets) { $snippet in
                if snippet.id != vocabulary.snippets.first?.id {
                    RowDivider()
                }

                EntryRow(
                    first: $snippet.trigger,
                    firstPrompt: "Phrase to say",
                    second: $snippet.text,
                    secondPrompt: "Text to paste",
                ) {
                    vocabulary.removeSnippet(snippet.id)
                }
            }
        } footer: {
            Button("Add Snippet") { vocabulary.addSnippet() }
        }
        .animation(.snappy(duration: 0.2), value: vocabulary.snippets.count)

        SettingsSection("File", subtitle: "Both lists are saved as a JSON file you can edit.") {
            SettingsRow("Dictionary file") {
                Button("Open in Editor") { vocabulary.openInEditor() }
                Button("Show in Finder") { vocabulary.revealInFinder() }
            }
        }
    }
}

private struct EntryRow: View {
    @Binding var first: String

    let firstPrompt: String

    @Binding var second: String

    let secondPrompt: String
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
