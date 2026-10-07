import Carbon.HIToolbox
import Foundation

/// ⌃⌥M, anywhere: switches to the next mode. A Carbon hot key, unlike the listen-only push-to-talk tap, takes
/// the key press for itself (the focused app does not get it) and needs no permission.
@MainActor
final class ModeHotkey {
    static let title = "⌃⌥M"

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let onPress: () -> Void

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
    }

    /// Registers the hot key; `false` if another app already holds ⌃⌥M.
    func start() -> Bool {
        guard hotKey == nil else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), modeHotkeyCallback, 1, &spec, context, &handler) == noErr else {
            return false
        }
        // "Dct!" identifies our hot key in the event.
        let identifier = EventHotKeyID(signature: OSType(0x4463_7421), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_M), UInt32(controlKey | optionKey), identifier, GetApplicationEventTarget(), 0, &hotKey
        )
        return status == noErr
    }

    fileprivate func pressed() {
        onPress()
    }
}

/// A C callback, so the hot key object arrives as an opaque pointer. Carbon calls it on the main thread.
private let modeHotkeyCallback: EventHandlerUPP = { _, _, context in
    guard let context else { return OSStatus(eventNotHandledErr) }
    let hotkey = Unmanaged<ModeHotkey>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { hotkey.pressed() }
    return noErr
}
