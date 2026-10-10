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
                        .modifier(CheckmarkAppear())
                }

                (isCopied ? Text("Copied") : Text("Copy"))
                    .contentTransition(.opacity)
            }
            .frame(minWidth: 52)
        }
        .animation(Motion.feedback, value: isCopied)
        .accessibilityLabel(isCopied ? Text("Copied") : Text("Copy"))
    }
}
