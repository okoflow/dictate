import AppKit
import SwiftUI

@MainActor
package final class WindowPresenter: NSObject, NSWindowDelegate {
    weak var model: AppModel?

    private let settingsNavigation = SettingsNavigation()
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    package func showSettings(_ pane: SettingsPane? = nil) {
        guard let model else { return }

        let window = settingsWindow ?? makeSettingsWindow(model: model)

        if let pane {
            settingsNavigation.selection = pane
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
        let content = NSHostingController(rootView: SettingsWindowView(model: model, navigation: settingsNavigation))
        content.sizingOptions = []

        let window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbar = NSToolbar()
        window.toolbarStyle = .unified
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = .textBackgroundColor
        window.setContentSize(NSSize(width: 820, height: 660))
        window.contentMinSize = NSSize(width: 760, height: 520)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        settingsWindow = window
        followSelectedPaneTitle()

        return window
    }

    private func followSelectedPaneTitle() {
        withObservationTracking {
            settingsWindow?.title = settingsNavigation.selection.title
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.followSelectedPaneTitle()
            }
        }
    }

    private func makeOnboardingWindow(model: AppModel) -> NSWindow {
        let content = NSHostingController(rootView: OnboardingView(model: model))
        content.sizingOptions = .preferredContentSize

        let window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = .textBackgroundColor
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        onboardingWindow = window

        return window
    }
}
