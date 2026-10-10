import AppKit
import DictateCore
import SwiftUI

struct HistorySettingsPane: View {
    @Bindable var settings: SettingsModel
    @Bindable var history: HistoryModel

    let copy: (DictationHistory.Entry) -> Void

    var body: some View {
        Form {
            Section {
                Toggle("Keep history", isOn: $settings.settings.keepsHistory)
            } footer: {
                SectionNote("The last \(DictationHistory.capacity) dictations stay on this Mac, in a file only you can read.")
            }

            Section("Recent") {
                TextField("Search", text: $history.searchText, prompt: Text("Search"))
                    .labelsHidden()

                if history.matchingEntries.isEmpty {
                    Text("Nothing yet")
                        .foregroundStyle(.secondary)
                }

                ForEach(history.matchingEntries.indices, id: \.self) { index in
                    HistoryRow(entry: history.matchingEntries[index], copy: copy)
                }
            }

            Section {
                Button("Clear History…", role: .destructive, action: confirmClear)
                    .disabled(history.history.entries.isEmpty)
            }
        }
    }

    private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = "Clear the dictation history?"
        alert.informativeText = "This deletes every saved dictation. It can't be undone."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        if alert.runModal() == .alertFirstButtonReturn {
            history.removeAll()
        }
    }
}

private struct HistoryRow: View {
    let entry: DictationHistory.Entry
    let copy: (DictationHistory.Entry) -> Void

    private var details: String {
        let time = entry.date.formatted(date: .abbreviated, time: .shortened)
        let app = entry.app.map(FrontmostAppTracker.name(of:))

        return [time, entry.mode.title, app].compactMap(\.self).joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.text)
                    .lineLimit(3)

                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Copy") { copy(entry) }
        }
        .padding(.vertical, 2)
    }
}
