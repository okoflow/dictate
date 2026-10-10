import AppKit
import DictateCore
import SwiftUI

struct HistorySettingsPane: View {
    @Bindable var settings: SettingsModel
    @Bindable var history: HistoryModel

    let stats: StatsModel
    let state: SettingsWindowState
    let copy: (DictationHistory.Entry) -> Void

    private var retention: Binding<HistoryRetention> {
        Binding(
            get: { settings.settings.historyRetention },
            set: { retention in
                settings.settings.historyRetention = retention
                history.keep(for: retention, limit: settings.settings.historyLimit)
            },
        )
    }

    private var limit: Binding<Int> {
        Binding(
            get: { settings.settings.historyLimit },
            set: { limit in
                settings.settings.historyLimit = limit
                history.keep(for: settings.settings.historyRetention, limit: limit)
            },
        )
    }

    private var emptyText: String {
        history.searchText.isEmpty ? "Nothing yet" : "No matches"
    }

    var body: some View {
        StatsSection(stats: stats)

        SettingsSection("Saving") {
            ToggleRow("Keep history", isOn: $settings.settings.keepsHistory, description: "Saved only on this Mac.")

            if settings.settings.keepsHistory {
                RowDivider()
                    .rowTransition()
                PickerRow("Keep dictations for", selection: retention, current: retention.wrappedValue.title) {
                    ForEach(HistoryRetention.allCases, id: \.self) { retention in
                        Text(retention.title).tag(retention)
                    }
                }
                .rowTransition()
                RowDivider()
                    .rowTransition()
                PickerRow("Keep at most", selection: limit, current: Self.limitTitle(limit.wrappedValue)) {
                    ForEach(DictationHistory.limits, id: \.self) { limit in
                        Text(Self.limitTitle(limit)).tag(limit)
                    }
                }
                .rowTransition()
            }
        }
        .animation(Motion.layout, value: settings.settings.keepsHistory)

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

    private static func limitTitle(_ limit: Int) -> String {
        "\(limit.formatted()) dictations"
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
        HStack(spacing: Metrics.rowSpacing) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.text)
                    .font(.rowTitle)
                    .lineLimit(3)
                    .textSelection(.enabled)

                Text(details)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            CopyButton(isCopied: isCopied, action: copy)
        }
        .settingsRowPadding()
    }
}
