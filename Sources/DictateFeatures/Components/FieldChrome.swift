import SwiftUI

struct FieldChrome: ViewModifier {
    let isFocused: Bool
    var cornerRadius: CGFloat = 7

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(isFocused ? Palette.fieldFocused : Palette.field, in: shape)
            .overlay {
                shape.strokeBorder(Color.accentColor.opacity(isFocused ? 0.75 : 0), lineWidth: 1.5)
            }
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}
