import SwiftUI

struct CopyButton: View {
    let isCopied: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isCopied {
                    Image(systemName: "checkmark")
                        .font(.glyph)
                        .foregroundStyle(Palette.success)
                        .transition(.scale.combined(with: .opacity))
                }

                Text(isCopied ? "Copied" : "Copy")
                    .contentTransition(.opacity)
            }
            .frame(minWidth: 52)
        }
        .animation(.snappy(duration: 0.2), value: isCopied)
        .accessibilityLabel(isCopied ? "Copied" : "Copy")
    }
}
