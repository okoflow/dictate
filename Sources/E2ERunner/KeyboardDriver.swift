import CoreGraphics
import DictateCore
import Foundation

/// Posts synthetic keyboard events for the push-to-talk checks.
///
/// Modifier events are built the way the hardware sends them: an explicit `flagsChanged` type, the key
/// code, and the generic Option flag plus the left/right device bit while the key is down; every event
/// carries its flags explicitly, so keys held on the real keyboard do not leak into it.
///
/// The source is the HID system state, not a private one. Private-state events reach event taps
/// just the same, but the system only intermittently reflects them in `CGEventSource.flagsState`,
/// which the app's watchdog reads to notice a lost key-up; it then ended holds a few hundred
/// milliseconds in, at random. HID-state events are tracked like real key presses.
struct KeyboardDriver {
    enum Modifier {
        case rightOption
        case leftOption

        var keyCode: CGKeyCode {
            switch self {
            case .rightOption: CGKeyCode(Hotkey.rightOptionKeyCode)
            case .leftOption: 58
            }
        }

        /// `NX_DEVICELALTKEYMASK` / `NX_DEVICERALTKEYMASK`.
        var deviceFlag: UInt64 {
            switch self {
            case .rightOption: Hotkey.rightOptionDeviceFlag
            case .leftOption: 0x20
            }
        }

        var heldFlags: CGEventFlags {
            CGEventFlags(rawValue: Hotkey.optionFlag | deviceFlag)
        }
    }

    /// `kVK_ANSI_A`.
    static let letterA: CGKeyCode = 0

    private let source = CGEventSource(stateID: .hidSystemState)

    /// Holds `modifier` while `body` runs. The release is posted in a `defer`, so a check that
    /// fails or throws half way never leaves Option stuck down for the rest of the suite.
    func holding<T>(_ modifier: Modifier, _ body: () throws -> T) rethrows -> T {
        postModifier(modifier, down: true)
        defer { postModifier(modifier, down: false) }
        return try body()
    }

    /// Types `key` (down and up) while `modifier` is held, with the modifier's flags on both events.
    func type(key: CGKeyCode, holding modifier: Modifier) {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            event?.flags = modifier.heldFlags
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Posts a release for every modifier the suite ever presses. Harmless when nothing is held, so it
    /// also heals a keyboard state left behind by an earlier run that was killed.
    func releaseAll() {
        for keyCode in Self.allModifierKeyCodes {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            event?.type = .flagsChanged
            event?.flags = []
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Left and right ⌘ (55, 54), ⇧ (56, 60), ⌃ (59, 62) and ⌥ (58, 61).
    private static let allModifierKeyCodes: [CGKeyCode] = [55, 54, 56, 60, 59, 62, 58, 61]

    /// The modifier bits (⇧⌃⌥⌘ and the left/right device bits) that the system's keyboard state, HID and
    /// login session alike, shows as down. Zero when nothing is stuck.
    static func stuckModifiers() -> UInt64 {
        let deviceBits: UInt64 = 0x0000_207F
        let independent: UInt64 = 0x001E_0000
        let mask = deviceBits | independent
        let hid = CGEventSource.flagsState(.hidSystemState).rawValue
        let session = CGEventSource.flagsState(.combinedSessionState).rawValue
        return (hid | session) & mask
    }

    private func postModifier(_ modifier: Modifier, down: Bool) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: modifier.keyCode, keyDown: down)
        event?.type = .flagsChanged
        event?.flags = down ? modifier.heldFlags : []
        event?.post(tap: .cghidEventTap)
    }
}
