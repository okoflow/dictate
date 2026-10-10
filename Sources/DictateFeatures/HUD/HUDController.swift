import AppKit
import Observation

@Observable
package final class HUDController {
    private static let barCount = 9
    private static let levelRefreshInterval: TimeInterval = 0.05

    package private(set) var content = HUDContent.hidden
    package private(set) var levels = [Float](repeating: 0, count: barCount)

    @ObservationIgnored private var panel: HUDPanel?
    @ObservationIgnored private var queuedMessages: [HUDMessage] = []
    @ObservationIgnored private var workingLabel: String?
    @ObservationIgnored private var levelTimer: Timer?
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored private var orderOutTask: Task<Void, Never>?

    package var isListening: Bool {
        if case .listening = content {
            true
        } else {
            false
        }
    }

    private var isShowingMessage: Bool {
        if case .message = content {
            true
        } else {
            false
        }
    }

    package init() {}

    package func showListening(badge: String?, isHandsFree: Bool, level: @escaping @MainActor () -> Float) {
        messageTask?.cancel()
        levels = [Float](repeating: 0, count: Self.barCount)

        present(.listening(badge: badge, isHandsFree: isHandsFree))

        levelTimer?.invalidate()
        levelTimer = .scheduledInCommonModes(every: Self.levelRefreshInterval, repeats: true) { [weak self] in
            self?.pushLevel(level())
        }
    }

    package func lockHandsFree() {
        guard case let .listening(badge, _) = content else { return }

        content = .listening(badge: badge, isHandsFree: true)
    }

    package func hideListening() {
        guard isListening else { return }

        levelTimer?.invalidate()
        levelTimer = nil

        hide()
        showNext()
    }

    package func setWorking(_ label: String?) {
        workingLabel = label

        showNext()
    }

    package func show(_ message: HUDMessage) {
        queuedMessages.append(message)
        showNext()
    }

    package func makePanel() {
        guard panel == nil else { return }

        panel = HUDPanel(rootView: HUDView(hud: self))
    }

    private func showNext() {
        guard !isListening, !isShowingMessage else { return }

        if !queuedMessages.isEmpty {
            showMessage(queuedMessages.removeFirst())
        } else if let workingLabel {
            present(.working(workingLabel))
        } else {
            hide()
        }
    }

    private func hide() {
        content = .hidden

        orderOutTask?.cancel()
        orderOutTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, self?.content == .hidden else { return }

            self?.panel?.orderOut(nil)
        }
    }

    private func showMessage(_ message: HUDMessage) {
        present(.message(message))

        messageTask = Task { [weak self] in
            try? await Task.sleep(for: message.duration)
            guard !Task.isCancelled else { return }

            self?.messageDidExpire()
        }
    }

    private func messageDidExpire() {
        guard isShowingMessage else { return }

        hide()
        showNext()
    }

    private func present(_ newContent: HUDContent) {
        makePanel()
        orderOutTask?.cancel()

        if content == .hidden {
            panel?.showOnActiveScreen()
        }

        content = newContent
    }

    private func pushLevel(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }
}
