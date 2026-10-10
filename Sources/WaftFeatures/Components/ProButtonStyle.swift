import SwiftUI

struct ProButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.prominentControl)
            .foregroundStyle(Color(red: 0.42, green: 0.22, blue: 0.82))
            .padding(.horizontal, Metrics.largeControlPadding)
            .frame(height: Metrics.largeControlHeight)
            .background(.white.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
            .animation(configuration.isPressed ? nil : Motion.fade, value: configuration.isPressed)
    }
}
