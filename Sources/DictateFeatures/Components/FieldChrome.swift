import SwiftUI

struct FieldChrome: ViewModifier {
    let isFocused: Bool
    var cornerRadius = Metrics.controlRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let ringOffset = Metrics.focusRingWidth / 2

        content
            .background(isFocused ? Palette.fieldFocused : Palette.field, in: shape)
            .overlay {
                shape.strokeBorder(Color.accentColor.opacity(isFocused ? 1 : 0), lineWidth: 1)
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius + ringOffset, style: .continuous)
                    .stroke(Color.accentColor.opacity(isFocused ? 0.25 : 0), lineWidth: Metrics.focusRingWidth)
                    .padding(-ringOffset)
            }
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
