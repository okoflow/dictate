import AppKit
import DictateCore
import SwiftUI

struct HistorySettingsPane: View {
    @Bindable var settings: SettingsModel
    @Bindable var history: HistoryModel

    let copy: (DictationHistory.Entry) -> Void

    private var emptyText: String {
        history.searchText.isEmpty ? "Nothing yet" : "No matches"
    }

    var body: some View {
        SettingsSection("Saving") {
            ToggleRow(
                "Keep history",
                isOn: $settings.settings.keepsHistory,
                description: "The last \(DictationHistory.capacity) dictations stay on this Mac.",
            )
        }

        SettingsSection("Recent", subtitle: nil) {
            if history.matchingEntries.isEmpty {
                EmptyRow(emptyText)
            }

            ForEach(history.matchingEntries.indices, id: \.self) { index in
                if index > 0 {
                    RowDivider()
                }

                HistoryRow(entry: history.matchingEntries[index], copy: copy)
            }
        } accessory: {
            SearchField(text: $history.searchText, prompt: "Search")
                .frame(width: 180)
        } footer: {
            Button("Clear History…", role: .destructive, action: confirmClear)
                .disabled(history.history.entries.isEmpty)
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.text)
                    .font(.system(size: 13))
                    .lineLimit(3)

                Text(details)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Copy") { copy(entry) }
        }
        .settingsRowPadding()
    }
}
