import AppKit
import Charts
import DictateCore
import SwiftUI

struct StatsSection: View {
    private static let chartDays = 14

    let stats: StatsModel

    private var week: DictationStats.Day {
        stats.stats.total(last: 7, endingOn: Date())
    }

    private var days: [(date: Date, day: DictationStats.Day)] {
        stats.stats.daily(last: Self.chartDays, endingOn: Date())
    }

    private var savedTime: String {
        let minutes = max(0, Double(week.words) / DictationStats.typingWordsPerMinute - week.seconds / 60)

        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private var speed: String {
        guard week.seconds > 0 else { return "–" }

        return Int((Double(week.words) / (week.seconds / 60)).rounded()).formatted()
    }

    var body: some View {
        SettingsSection("This week", subtitle: "Counted on this Mac: words and time, never the text.") {
            HStack(spacing: 0) {
                Metric(value: week.words.formatted(), label: "words")
                Metric(value: savedTime, label: "saved over typing")
                Metric(value: speed, label: "words a minute")
            }

            RowDivider()

            if days.allSatisfy({ $0.day.words == 0 }) {
                EmptyRow("Dictate something to see your days here.")
            } else {
                WordsChart(days: days)
                    .settingsRowPadding()
            }
        } footer: {
            Button("Reset Stats…", action: confirmReset)
                .disabled(stats.stats.days.isEmpty)
        }
        .animation(.snappy(duration: 0.3), value: week.words)
    }

    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = "Reset your dictation stats?"
        alert.informativeText = "This sets the word and time counts back to zero. Your history stays."
        alert.addButton(withTitle: "Reset Stats")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        if alert.runModal() == .alertFirstButtonReturn {
            stats.reset()
        }
    }
}

private struct Metric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.metric)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(label)
                .font(.rowDetail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metrics.rowPadding + 4)
        .accessibilityElement(children: .combine)
    }
}

private struct WordsChart: View {
    let days: [(date: Date, day: DictationStats.Day)]

    var body: some View {
        Chart(days, id: \.date) { item in
            BarMark(
                x: .value("Day", item.date, unit: .day),
                y: .value("Words", item.day.words),
                width: .ratio(0.6),
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(3)
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.day(), centered: true)
            }
        }
        .frame(height: 96)
        .accessibilityLabel("Words dictated each day for the last two weeks")
    }
}
