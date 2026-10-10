import AppKit
import SwiftUI

struct HUDPill: View {
    private let content: HUDContent
    private let levels: [Float]

    init(content: HUDContent, levels: [Float]) {
        self.content = content
        self.levels = levels
    }

    var body: some View {
        switch content {
        case .hidden:
            EmptyView()
        case let .listening(badge, isHandsFree):
            ListeningPill(levels: levels, badge: badge, isHandsFree: isHandsFree)
        case let .working(label):
            WorkingPill(label: label)
        case let .message(message):
            MessagePill(message: message)
        }
    }
}

private struct ListeningPill: View {
    let levels: [Float]
    let badge: String?
    let isHandsFree: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeating)

            LevelBars(levels: levels)

            if let badge {
                Text(badge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if isHandsFree {
                Label("Hands-free", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: isHandsFree)
        .font(.system(size: 15, weight: .semibold))
        .padding(.horizontal, 18)
        .frame(height: 44)
        .hudBackground()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dictate is listening")
    }
}

private struct WorkingPill: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, options: .repeating)

            Text(label)
                .font(.system(size: 14, weight: .medium))
        }
        .font(.system(size: 15, weight: .semibold))
        .padding(.horizontal, 18)
        .frame(height: 44)
        .hudBackground()
    }
}

private struct MessagePill: View {
    private static let maximumTextWidth: CGFloat = 520
    private static let titleFont = NSFont.systemFont(ofSize: 14, weight: .medium)
    private static let detailFont = NSFont.systemFont(ofSize: 12)

    let message: HUDMessage

    private var symbolName: String {
        switch message.kind {
        case .pasted: "checkmark.circle.fill"
        case .copied: "doc.on.clipboard"
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    private var symbolColor: Color {
        switch message.kind {
        case .pasted: .green
        case .copied, .info: .secondary
        case .warning: .orange
        }
    }

    private var textWidth: CGFloat {
        let widths = [
            width(of: message.title, font: Self.titleFont),
            message.detail.map { width(of: $0, font: Self.detailFont) } ?? 0,
        ]

        return min(Self.maximumTextWidth, ceil(widths.max() ?? 0) + 1)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(symbolColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(6)

                if let detail = message.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: textWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .hudBackground()
        .accessibilityElement(children: .combine)
    }

    private func width(of text: String, font: NSFont) -> CGFloat {
        text.split(separator: "\n").map { (String($0) as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
    }
}

private struct LevelBars: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .frame(width: 3.5, height: 4 + 18 * CGFloat(levels[index]))
            }
        }
        .frame(height: 22)
        .animation(.linear(duration: 0.05), value: levels)
    }
}
