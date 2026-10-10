import AppKit
import SwiftUI

struct HUDBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .environment(\.colorScheme, .dark)
                .background(VisualEffectBackground().clipShape(Capsule()))
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active

        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}

extension View {
    func hudBackground() -> some View {
        modifier(HUDBackground())
    }
}
