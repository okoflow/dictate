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
        private var armed = false
        private var served = false

        init(text: String) {
            self.text = text
        }

        /// Whether the text was read *after* `arm()`. Reads before it (a clipboard manager looking at every
        /// new item) are served but do not count: the target app has not pressed ⌘V yet.
        var wasRead: Bool {
            lock.withLock { served }
        }

        /// Called right before ⌘V is posted.
        func arm() {
            lock.withLock { armed = true }
        }

        func pasteboard(_: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
            item.setString(text, forType: type)
            lock.withLock { served = served || armed }
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
    /// Pastes in progress, including their clipboard restore: quitting waits for them to finish.
    private var activeInsertions = 0

    init(eventLog: EventLogWriter) {
        self.eventLog = eventLog
    }

    /// Pastes `text` into the field that has focus now, provided that is still `target`. Returns what
    /// happened; the event log gets `inserted` or `insertionSkipped` (and `restoreSkipped` when the
    /// user's clipboard could not be put back).
    func insert(_ text: String, target: FocusSnapshot) async -> Outcome {
        activeInsertions += 1
        defer { activeInsertions -= 1 }
        let heldOff = await waitForHotkeyRelease()
        let now = FocusProbe.current()
        let decision = InsertionRules.decide(
            // With no element to look at, an active secure-input session (a password prompt) is the only hint.
            focusedElementIsSecure: FocusProbe.isSecureTextField(now.element)
                || (now.element == nil && IsSecureEventInputEnabled()),
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
        guard await paste(prepared) else {
            eventLog.log(.insertionSkipped(.hotkeyHeld))
            return .skipped(.hotkeyHeld)
        }
        eventLog.log(.inserted(
            characters: prepared.count,
            app: now.bundleIdentifier ?? "unknown",
            secureInputActive: IsSecureEventInputEnabled()
        ))
        return .inserted(characters: prepared.count)
    }

    // MARK: Paste

    /// Waits until no paste is running (a clipboard restore is still due), for at most `timeout` seconds.
    func waitUntilIdle(timeout: Double = 2) async {
        let deadline = ContinuousClock.now + .seconds(timeout)
        while activeInsertions > 0, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Writes `text`, presses ⌘V, waits until the app has read it, and restores the clipboard. `false` if
    /// the hotkey went down again just before the shortcut (then nothing was pressed and the clipboard is as it was).
    private func paste(_ text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        // Read off the main thread: the data of a big item can take a while to arrive.
        let snapshot = await Task.detached { PasteboardSnapshot.take() }.value
        let provider = LazyText(text: text)
        let item = NSPasteboardItem()
        item.setDataProvider(provider, forTypes: [.string])
        item.setData(Data(), forType: NSPasteboard.PasteboardType(InsertionRules.transientType))
        item.setData(Data(), forType: NSPasteboard.PasteboardType(InsertionRules.concealedType))
        item.setData(Data(), forType: NSPasteboard.PasteboardType(InsertionRules.ownType))
        // Off Universal Clipboard, like every other item Dictate writes.
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        pasteboard.writeObjects([item])
        let ours = pasteboard.changeCount

        // Checked again right before pressing: the first check was before the snapshot, a key can go down since.
        guard !hotkeyHeld() else {
            restore(snapshot, expecting: ours)
            return false
        }
        provider.arm()
        postPasteShortcut()
        let deadline = ContinuousClock.now + .seconds(Self.readTimeout)
        while !provider.wasRead, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        defer { withExtendedLifetime(provider) {} }
        guard provider.wasRead else {
            // A slow app may still paste after the timeout. Putting the user's clipboard back now would
            // hand it the old (possibly private) contents instead of the dictation, so leave the text there.
            keepOnClipboard(text, expecting: ours)
            eventLog.log(.restoreSkipped("the app did not read the text in time"))
            return true
        }
        try? await Task.sleep(for: .seconds(Self.settleDelay))
        restore(snapshot, expecting: ours)
        return true
    }

    /// Replaces the lazy item with the plain text, so a late paste still gets the dictation after the
    /// data provider is gone. Skipped when something else has taken the clipboard since.
    private func keepOnClipboard(_ text: String, expecting changeCount: Int) {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == changeCount else { return }
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType(InsertionRules.transientType))
        item.setData(Data(), forType: NSPasteboard.PasteboardType(InsertionRules.concealedType))
        item.setData(Data(), forType: NSPasteboard.PasteboardType(InsertionRules.ownType))
        pasteboard.prepareForNewContents(with: .currentHostOnly)
        pasteboard.writeObjects([item])
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

    /// ⌘V as a real key sequence: ⌘ down, v down, v up, ⌘ up, all from the HID system state, with the ⌘
    /// release in a `defer` so it is posted whatever happens in between. A `v` that merely *carries* the ⌘
    /// flag (the earlier form, from a private source) was seen to leave ⌘ set in the system's modifier
    /// state for good; a key-down with its own key-up cannot.
    private func postPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let key = PasteKey.keyCode()
        let leftCommand = CGKeyCode(kVK_Command)
        // NX_DEVICELCMDKEYMASK: the left ⌘ is what a keyboard sends.
        let commandFlags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x08)
        func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags, modifier: Bool = false) {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            if modifier {
                event?.type = .flagsChanged
            }
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
        post(leftCommand, down: true, flags: commandFlags, modifier: true)
        defer { post(leftCommand, down: false, flags: [], modifier: true) }
        post(key, down: true, flags: commandFlags)
        post(key, down: false, flags: commandFlags)
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
