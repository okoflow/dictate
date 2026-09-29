import AppKit
import ApplicationServices
import Carbon.HIToolbox
import DictateCore
import Foundation

/// Types dictated text into the focused field of the frontmost app by pasting it.
///
/// Pasting is the only method: it works in nearly every app, and setting the field's text through
/// Accessibility does not. The user's clipboard is saved first and put back afterwards.
@MainActor
final class Inserter {
    enum Outcome: Equatable {
        case inserted(characters: Int)
        case skipped(InsertionRules.SkipReason)
    }

    /// The text is offered lazily, so the moment the target app reads it is known.
    private final class LazyText: NSObject, NSPasteboardItemDataProvider, @unchecked Sendable {
        private let text: String
        private let lock = NSLock()
        private var served = false

        init(text: String) {
            self.text = text
        }

        var wasRead: Bool {
            lock.withLock { served }
        }

        func pasteboard(_: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
            item.setString(text, forType: type)
            lock.withLock { served = true }
        }

        func pasteboardFinishedWithDataProvider(_: NSPasteboard) {}
    }

    /// The target app has this long to read the pasteboard before the clipboard is put back regardless.
    private static let readTimeout = 1.5
    /// After the read, a moment for the app to finish before the clipboard changes under it.
    private static let settleDelay = 0.15
    /// How long a held hotkey may delay the paste; then the text stays on the clipboard instead.
    private static let hotkeyWaitLimit = 10.0

    private let eventLog: EventLogWriter

    init(eventLog: EventLogWriter) {
        self.eventLog = eventLog
    }

    /// Pastes `text` into the field that has focus now, provided that is still `target`. Returns what
    /// happened; the event log gets `inserted` or `insertionSkipped` (and `restoreSkipped` when the
    /// user's clipboard could not be put back).
    func insert(_ text: String, target: FocusSnapshot) async -> Outcome {
        let heldOff = await waitForHotkeyRelease()
        let now = FocusProbe.current()
        let decision = InsertionRules.decide(
            focusedElementIsSecure: FocusProbe.isSecureTextField(now.element),
            accessibilityGranted: AXIsProcessTrusted(),
            focusStillOnTarget: InsertionRules.focusStillOnTarget(
                elements: FocusProbe.compare(target.element, now.element), targetPID: target.pid, currentPID: now.pid
            ),
            hotkeyStillHeld: !heldOff
        )
        if case let .skip(reason) = decision {
            eventLog.log(.insertionSkipped(reason))
            return .skipped(reason)
        }
        let prepared = InsertionRules.prepared(text, characterBeforeCaret: FocusProbe.characterBeforeCaret(in: now.element))
        await paste(prepared)
        eventLog.log(.inserted(
            characters: prepared.count,
            app: now.bundleIdentifier ?? "unknown",
            secureInputActive: IsSecureEventInputEnabled()
        ))
        return .inserted(characters: prepared.count)
    }

    // MARK: Paste

    /// Writes `text`, presses ⌘V, waits until the app has read it, and restores the clipboard.
    private func paste(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.take(from: pasteboard)
        let provider = LazyText(text: text)
        let item = NSPasteboardItem()
        item.setDataProvider(provider, forTypes: [.string])
        item.setData(Data(), forType: NSPasteboard.PasteboardType(InsertionRules.transientType))
        item.setData(Data(), forType: NSPasteboard.PasteboardType(InsertionRules.concealedType))
        // Off Universal Clipboard, like every other item Dictate writes.
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        pasteboard.writeObjects([item])
        let ours = pasteboard.changeCount

        postPasteShortcut()
        let deadline = ContinuousClock.now + .seconds(Self.readTimeout)
        while !provider.wasRead, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        if provider.wasRead {
            try? await Task.sleep(for: .seconds(Self.settleDelay))
        }
        restore(snapshot, expecting: ours)
        withExtendedLifetime(provider) {}
    }

    private func restore(_ snapshot: PasteboardSnapshot, expecting changeCount: Int) {
        switch snapshot.plan {
        case let .skip(reason):
            eventLog.log(.restoreSkipped(reason))
        case .restore:
            guard InsertionRules.shouldRestore(changeCount: NSPasteboard.general.changeCount, expected: changeCount) else {
                eventLog.log(.restoreSkipped("the clipboard changed meanwhile"))
                return
            }
            snapshot.restore()
        }
    }

    /// ⌘V from a private event source, so the synthetic ⌘ never enters the HID keyboard state that the
    /// hotkey watchdog reads.
    private func postPasteShortcut() {
        let source = CGEventSource(stateID: .privateState)
        let key = PasteKey.keyCode()
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    /// With Option held the shortcut would be ⌥⌘V ("Paste and Match Style" and other things).
    private func waitForHotkeyRelease() async -> Bool {
        let deadline = ContinuousClock.now + .seconds(Self.hotkeyWaitLimit)
        while hotkeyHeld() {
            guard ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(30))
        }
        return true
    }

    private func hotkeyHeld() -> Bool {
        Hotkey.isStillHeld(
            hidFlags: CGEventSource.flagsState(.hidSystemState).rawValue,
            sessionFlags: CGEventSource.flagsState(.combinedSessionState).rawValue
        )
    }
}
