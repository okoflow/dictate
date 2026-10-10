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

        SettingsSection("File") {
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
        HStack(spacing: 8) {
            TextField(firstPrompt, text: $first, prompt: Text(firstPrompt))

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            TextField(secondPrompt, text: $second, prompt: Text(secondPrompt))

            RemoveButton(help: "Remove", action: remove)
        }
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
        .settingsRowPadding()
    }
}
