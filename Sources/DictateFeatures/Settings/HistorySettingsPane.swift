import AppKit
import DictateCore
import SwiftUI

struct HistorySettingsPane: View {
    @Bindable var settings: SettingsModel
    @Bindable var history: HistoryModel

    let state: SettingsWindowState
    let copy: (DictationHistory.Entry) -> Void

    private var retention: Binding<HistoryRetention> {
        Binding(
            get: { settings.settings.historyRetention },
            set: { retention in
                settings.settings.historyRetention = retention
                history.keep(for: retention)
            },
        )
    }

    private var emptyText: String {
        history.searchText.isEmpty ? "Nothing yet" : "No matches"
    }

    var body: some View {
        SettingsSection("Saving") {
            ToggleRow("Keep history", isOn: $settings.settings.keepsHistory, description: "Saved only on this Mac.")

            if settings.settings.keepsHistory {
                RowDivider()
                PickerRow("Keep dictations for", selection: retention) {
                    ForEach(HistoryRetention.allCases, id: \.self) { retention in
                        Text(retention.title).tag(retention)
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: settings.settings.keepsHistory)

        SettingsSection("Recent", subtitle: nil) {
            if history.matchingEntries.isEmpty {
                EmptyRow(emptyText)
            }

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(history.matchingEntries, id: \.date) { entry in
                    if entry.date != history.matchingEntries.first?.date {
                        RowDivider()
                    }

                    HistoryRow(entry: entry, isCopied: state.copiedEntry == entry.date) {
                        copy(entry)
                        state.showCopied(entry.date)
                    }
                }
            }
        } accessory: {
            SearchField("Search", text: $history.searchText)
                .frame(width: 200)
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
    let isCopied: Bool
    let copy: () -> Void

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
                    .textSelection(.enabled)

                Text(details)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            CopyButton(isCopied: isCopied, action: copy)
        }
        .settingsRowPadding()
    }
}
