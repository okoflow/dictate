import SwiftUI

package struct HUDView: View {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    private let hud: HUDController

    private var transition: AnyTransition {
        reducesMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92, anchor: .bottom))
    }

    package init(hud: HUDController) {
        self.hud = hud
    }

    package var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            pill
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 18)
        .animation(reducesMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.25), value: hud.content)
    }

    @ViewBuilder
    private var pill: some View {
        if hud.content != .hidden {
            HUDPill(content: hud.content, levels: hud.levels)
                .transition(transition)
        }
    }
}
