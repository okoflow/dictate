import AppKit
import SwiftUI

@MainActor
package final class WindowPresenter: NSObject, NSWindowDelegate {
    weak var model: AppModel?

    private var settingsWindow: NSWindow?
    private var settingsTabs: NSTabViewController?
    private var onboardingWindow: NSWindow?

    package func showSettings(_ pane: SettingsPane? = nil) {
        guard let model else { return }

        let window = settingsWindow ?? makeSettingsWindow(model: model)

        if let pane {
            settingsTabs?.selectedTabViewItemIndex = pane.rawValue
        }

        model.settings.refreshMicrophones()
        present(window)
    }

    package func showOnboarding() {
        guard let model else { return }

        let window = onboardingWindow ?? makeOnboardingWindow(model: model)

        present(window)
    }

    package func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }

        if closing == onboardingWindow {
            model?.onboarding.reset()
        }

        let othersVisible = [settingsWindow, onboardingWindow].contains { $0 != nil && $0 != closing && $0?.isVisible == true }

        if !othersVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func closeOnboarding() {
        onboardingWindow?.close()
    }

    private func present(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makeSettingsWindow(model: AppModel) -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar

        for pane in SettingsPane.allCases {
            let content = NSHostingController(rootView: SettingsPaneView(pane: pane, model: model))
            content.sizingOptions = .preferredContentSize
            content.title = pane.title

            let item = NSTabViewItem(viewController: content)
            item.label = pane.title
            item.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: pane.title)

            tabs.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        settingsTabs = tabs
        settingsWindow = window

        return window
    }

    private func makeOnboardingWindow(model: AppModel) -> NSWindow {
        let content = NSHostingController(rootView: OnboardingView(model: model))
        content.sizingOptions = .preferredContentSize

        let window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        onboardingWindow = window

        return window
    }
}
