import SwiftUI

package struct HUDView: View {
    private let hud: HUDController

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
        .animation(Motion.layout, value: hud.content)
        .reducedMotionPolicy()
    }

    @ViewBuilder
    private var pill: some View {
        if hud.content != .hidden {
            HUDPill(content: hud.content, levels: hud.levels)
                .transition(AsymmetricTransition(insertion: PillTransition(), removal: PillTransition().animation(Motion.fade)))
        }
    }
}
