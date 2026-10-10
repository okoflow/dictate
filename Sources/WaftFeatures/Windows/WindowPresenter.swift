import AppKit
import SwiftUI

@MainActor
package final class WindowPresenter: NSObject, NSWindowDelegate {
    weak var model: AppModel?

    private let settingsState = SettingsWindowState()
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var transcriptionWindow: NSWindow?
    private var clickMonitor: Any?

    package func showSettings(_ pane: SettingsPane? = nil) {
        guard let model else { return }

        let window = settingsWindow ?? makeSettingsWindow(model: model)

        if let pane {
            settingsState.selection = pane
        }

        model.settings.refreshMicrophones()
        present(window)
    }

    package func showOnboarding() {
        guard let model else { return }

        let window = onboardingWindow ?? makeOnboardingWindow(model: model)

        present(window)
    }

    package func showTranscription() {
        guard let model else { return }

        let window = transcriptionWindow ?? makeTranscriptionWindow(model: model)

        present(window)
    }

    package func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }

        if closing == onboardingWindow {
            model?.onboarding.reset()
        }

        if closing == settingsWindow {
            settingsState.editedInstructions = nil
            model?.keyRecorder.stop()
        }

        let windows = [settingsWindow, onboardingWindow, transcriptionWindow]
        let othersVisible = windows.contains { $0 != nil && $0 != closing && $0?.isVisible == true }

        if !othersVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func closeOnboarding() {
        onboardingWindow?.close()
    }

    private func present(_ window: NSWindow) {
        releaseFocusOnOutsideClicks()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func releaseFocusOnOutsideClicks() {
        guard clickMonitor == nil else { return }

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            MainActor.assumeIsolated {
                self?.releaseFocus(for: event)
            }

            return event
        }
    }

    private func releaseFocus(for event: NSEvent) {
        guard let window = event.window, window == settingsWindow || window == onboardingWindow,
              window.firstResponder is NSText,
              let hit = window.contentView?.hitTest(event.locationInWindow), !hit.isTextInput else { return }

        window.makeFirstResponder(nil)
    }

    private func makeSettingsWindow(model: AppModel) -> NSWindow {
        let content = NSHostingController(rootView: SettingsWindowView(model: model, state: settingsState))
        content.sizingOptions = []

        let window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbar = NSToolbar()
        window.toolbarStyle = .unified
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = Palette.windowColor
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
            settingsWindow?.title = settingsState.selection.title
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.followSelectedPaneTitle()
            }
        }
    }

    private func makeTranscriptionWindow(model: AppModel) -> NSWindow {
        let view = TranscriptionView(model: model.transcription, settings: model.settings, pro: model.pro) { [weak self] in
            self?.showSettings(.pro)
        }
        let content = NSHostingController(rootView: view)
        content.sizingOptions = []

        let window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = String(localized: "Transcribe a File")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = Palette.windowColor
        window.setContentSize(NSSize(width: 600, height: 580))
        window.contentMinSize = NSSize(width: 520, height: 480)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        transcriptionWindow = window

        return window
    }

    private func makeOnboardingWindow(model: AppModel) -> NSWindow {
        let content = NSHostingController(rootView: OnboardingView(model: model))
        content.sizingOptions = .preferredContentSize

        let window = NSWindow(contentViewController: content)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = Palette.windowColor
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        onboardingWindow = window

        return window
    }
}

extension NSView {
    fileprivate var isTextInput: Bool {
        sequence(first: self, next: \.superview).contains { view in
            view is NSTextView || view is NSTextField || (view as? NSScrollView)?.documentView is NSTextView
        }
    }
}
