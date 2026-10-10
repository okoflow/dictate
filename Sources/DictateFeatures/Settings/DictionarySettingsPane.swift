import SwiftUI

struct DictionarySettingsPane: View {
    @Bindable var vocabulary: VocabularyModel

    var body: some View {
        Form {
            Section {
                ForEach($vocabulary.terms) { $term in
                    HStack {
                        TextField("Term", text: $term.term, prompt: Text("Term"))
                        TextField("Heard as", text: $term.spokenForms, prompt: Text("Heard as, separated by commas"))
                        RemoveButton { vocabulary.removeTerm(term.id) }
                    }
                    .labelsHidden()
                }

                Button("Add Term") { vocabulary.addTerm() }
            } header: {
                Text("Terms")
            } footer: {
                SectionNote(
                    "Names and words that come out wrong. "
                        + "Dictate hints them to Whisper and replaces what it hears instead, as whole words.",
                )
            }

            Section {
                ForEach($vocabulary.snippets) { $snippet in
                    HStack {
                        TextField("Say", text: $snippet.trigger, prompt: Text("Phrase to say"))
                        TextField("Insert", text: $snippet.text, prompt: Text("Text to paste"))
                        RemoveButton { vocabulary.removeSnippet(snippet.id) }
                    }
                    .labelsHidden()
                }

                Button("Add Snippet") { vocabulary.addSnippet() }
            } header: {
                Text("Snippets")
            } footer: {
                SectionNote(
                    "Say the phrase on its own and Dictate pastes the text as it is, without sending anything to the cloud.",
                )
            }

            Section {
                HStack {
                    Button("Open in Editor") { vocabulary.openInEditor() }
                    Button("Show in Finder") { vocabulary.revealInFinder() }
                }
            }
        }
    }
}

private struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Remove")
    }
}
