import SwiftUI

struct PushButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        PushButton(configuration: configuration, isProminent: isProminent)
    }
}

private struct PushButton: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    let configuration: ButtonStyleConfiguration
    let isProminent: Bool

    private var isLarge: Bool {
        controlSize == .large || controlSize == .extraLarge
    }

    private var foreground: Color {
        if isProminent {
            return .white
        }

        return configuration.role == .destructive ? .red : .primary
    }

    private var fill: Color {
        if isProminent {
            return Color.accentColor.opacity(configuration.isPressed ? 0.82 : 1)
        }

        return configuration.isPressed ? Palette.controlPressed : Palette.control
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: isLarge ? 9 : 7, style: .continuous)

        configuration.label
            .font(.system(size: 13, weight: isProminent ? .medium : .regular))
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, isLarge ? 16 : 12)
            .frame(minHeight: isLarge ? 32 : 24)
            .background(fill, in: shape)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
