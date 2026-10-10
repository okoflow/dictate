import SwiftUI
import WaftCore
import WaftFeatures

@main
struct WaftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        let settings = appDelegate.model.settings
        let isShown = settings.settings.showsMenuBarIcon

        let isInserted = Binding(
            get: { isShown },
            set: { newValue in
                guard newValue != settings.settings.showsMenuBarIcon else { return }

                settings.settings.showsMenuBarIcon = newValue
            },
        )

        MenuBarExtra(isInserted: isInserted) {
            MenuContent(model: appDelegate.model)
        } label: {
            MenuBarIcon(model: appDelegate.model)
        }
        .menuBarExtraStyle(.menu)
    }
}
