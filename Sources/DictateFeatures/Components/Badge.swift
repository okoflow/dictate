import SwiftUI

struct Badge: View {
    private let text: LocalizedStringKey
    private let tint: Color?

    init(_ text: LocalizedStringKey, tint: Color? = nil) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.badge)
            .foregroundStyle(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(tint.map { $0.opacity(0.14) } ?? Palette.selection, in: Capsule())
    }
}
