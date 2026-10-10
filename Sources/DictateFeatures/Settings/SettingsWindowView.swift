import SwiftUI

package struct SettingsWindowView: View {
    private let model: AppModel
    private let navigation: SettingsNavigation

    package init(model: AppModel, navigation: SettingsNavigation) {
        self.model = model
        self.navigation = navigation
    }

    package var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(navigation: navigation)
                .frame(width: 222)
                .padding([.leading, .vertical], 8)

            SettingsPaneView(model: model, navigation: navigation)
        }
        .background(Palette.window)
        .ignoresSafeArea()
    }
}
