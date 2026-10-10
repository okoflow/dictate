import SwiftUI

struct LinkRow: View {
    let title: String
    var detail: String?
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: Metrics.controlSpacing) {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: Metrics.rowSpacing)

                if let detail {
                    Text(detail)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "arrow.up.right")
                    .font(.glyph)
                    .foregroundStyle(.secondary)
            }
            .font(.rowTitle)
            .settingsRowPadding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
