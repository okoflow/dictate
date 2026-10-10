import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os
import WaftCore

@MainActor
package final class PasteboardInserter: TextInserter {
    private static let readTimeout = Duration.seconds(1.5)
    private static let settleDelay = Duration.milliseconds(150)
    private static let keyReleaseTimeout = Duration.seconds(10)
    private static let idleTimeout = Duration.seconds(2)
    private static let pollInterval = Duration.milliseconds(20)

    private let focusTracker: any FocusTracker
    private let keyboardState: any KeyboardState
    private var activeInsertions = 0

    package init(focusTracker: any FocusTracker, keyboardState: any KeyboardState) {
        self.focusTracker = focusTracker
        self.keyboardState = keyboardState
    }

    package func insert(_ text: String, into target: FocusTarget, releasing key: PushToTalkKey) async -> InsertionOutcome {
        activeInsertions += 1
        defer { activeInsertions -= 1 }

        let wasReleased = await waitForRelease(of: key)
        let current = focusTracker.currentFocus()
        let decision = decide(target: target, current: current, isKeyHeld: !wasReleased)

        if case let .skip(reason) = decision {
            Logger.insertion.notice("Skipped pasting: \(reason.rawValue, privacy: .public)")

            return .skipped(reason)
        }

        let prepared = InsertionSpacing.prepared(text, after: current.element?.characterBeforeCaret)
        guard await paste(prepared, releasing: key) else { return .skipped(.keyHeld) }

        let app = current.bundleIdentifier ?? "an unknown app"

        Logger.insertion.info("Pasted \(prepared.count) characters into \(app, privacy: .public)")

        return .pasted
    }

    package func waitUntilIdle() async {
        let deadline = ContinuousClock.now + Self.idleTimeout

        while activeInsertions > 0, ContinuousClock.now < deadline {
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    private func decide(target: FocusTarget, current: FocusTarget, isKeyHeld: Bool) -> InsertionDecision {
        let isSecureField = current.element?.isSecureTextField ?? IsSecureEventInputEnabled()
        let comparison = target.element.flatMap { element in current.element.map(element.compare) } ?? .unknown
        let isFocusOnTarget = InsertionDecision.isFocusOnTarget(
            comparison,
            targetProcessID: target.processID,
            currentProcessID: current.processID,
        )

        return InsertionDecision.decide(
            isSecureField: isSecureField,
            canPostKeys: AXIsProcessTrusted(),
            isFocusOnTarget: isFocusOnTarget,
            isKeyHeld: isKeyHeld,
        )
    }

    private func paste(_ text: String, releasing key: PushToTalkKey) async -> Bool {
        let pasteboard = NSPasteboard.general
        let snapshot = await Task.detached { PasteboardSnapshot.take() }.value

        let lazyText = LazyPasteboardText(text)
        let item = NSPasteboardItem()
        item.setDataProvider(lazyText, forTypes: [.string])

        let ownChangeCount = pasteboard.writePrivately(item)

        guard !keyboardState.isHeld(key) else {
            restore(snapshot, expecting: ownChangeCount)

            return false
        }

        lazyText.arm()
        PasteShortcut.post()

        guard await waitUntilRead(lazyText) else {
            keepOnPasteboard(text, expecting: ownChangeCount)

            Logger.insertion.notice("Kept the text on the clipboard: the app didn't read it in time")

            return true
        }

        try? await Task.sleep(for: Self.settleDelay)

        restore(snapshot, expecting: ownChangeCount)

        return true
    }

    private func waitForRelease(of key: PushToTalkKey) async -> Bool {
        let deadline = ContinuousClock.now + Self.keyReleaseTimeout

        while keyboardState.isHeld(key) {
            guard ContinuousClock.now < deadline else { return false }

            try? await Task.sleep(for: Self.pollInterval)
        }

        return true
    }

    private func waitUntilRead(_ lazyText: LazyPasteboardText) async -> Bool {
        let deadline = ContinuousClock.now + Self.readTimeout

        while !lazyText.wasReadAfterArming, ContinuousClock.now < deadline {
            try? await Task.sleep(for: Self.pollInterval)
        }

        return withExtendedLifetime(lazyText) { lazyText.wasReadAfterArming }
    }

    private func keepOnPasteboard(_ text: String, expecting changeCount: Int) {
        guard NSPasteboard.general.changeCount == changeCount else { return }

        NSPasteboard.general.writePrivately(text)
    }

    private func restore(_ snapshot: PasteboardSnapshot, expecting changeCount: Int) {
        switch snapshot.plan {
        case let .skip(reason):
            Logger.insertion.notice("Left the clipboard as it is: \(reason, privacy: .public)")
        case .restore where NSPasteboard.general.changeCount != changeCount:
            Logger.insertion.notice("Left the clipboard as it is: it changed during the paste")
        case .restore:
            snapshot.restore()
        }
    }
}
