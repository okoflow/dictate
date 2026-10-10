import SwiftUI

package struct SettingsWindowView: View {
    private let model: AppModel
    private let state: SettingsWindowState

    package init(model: AppModel, state: SettingsWindowState) {
        self.model = model
        self.state = state
    }

    package var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(state: state)
                .frame(width: Metrics.sidebarWidth)
                .padding([.leading, .vertical], Metrics.windowInset)

            SettingsPaneView(model: model, state: state)
        }
        .buttonStyle(PushButtonStyle())
        .reducedMotionPolicy()
        .background(Palette.window)
        .ignoresSafeArea()
    }
}
