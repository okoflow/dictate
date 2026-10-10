import Carbon.HIToolbox
import CoreGraphics

enum PasteShortcut {
    private static let fallbackKeyCode = CGKeyCode(kVK_ANSI_V)
    private static let commandModifierState = UInt32((cmdKey >> 8) & 0xFF)
    private static let leftCommandDeviceFlag: UInt64 = 0x08

    static func post() {
        let source = CGEventSource(stateID: .hidSystemState)
        let leftCommand = CGKeyCode(kVK_Command)
        let vKey = keyCodeTypingV()
        let commandFlags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | leftCommandDeviceFlag)

        post(leftCommand, isDown: true, flags: commandFlags, isModifier: true, source: source)
        defer { post(leftCommand, isDown: false, flags: [], isModifier: true, source: source) }

        post(vKey, isDown: true, flags: commandFlags, isModifier: false, source: source)
        post(vKey, isDown: false, flags: commandFlags, isModifier: false, source: source)
    }

    private static func post(_ keyCode: CGKeyCode, isDown: Bool, flags: CGEventFlags, isModifier: Bool, source: CGEventSource?) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)

        if isModifier {
            event?.type = .flagsChanged
        }

        event?.flags = flags
        event?.post(tap: .cghidEventTap)
    }

    private static func keyCodeTypingV() -> CGKeyCode {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return fallbackKeyCode }

        let layout = unsafeBitCast(property, to: CFData.self)
        let keyboardType = UInt32(CGEventSource(stateID: .combinedSessionState)?.keyboardType ?? 0)
        let keyCode = (0 ..< 128).first { character(for: UInt16($0), layout: layout, keyboardType: keyboardType) == "v" }

        return keyCode.map(CGKeyCode.init) ?? fallbackKeyCode
    }

    private static func character(for keyCode: UInt16, layout: CFData, keyboardType: UInt32) -> Character? {
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let layoutBytes = UnsafeRawPointer(CFDataGetBytePtr(layout)).assumingMemoryBound(to: UCKeyboardLayout.self)
        let status = UCKeyTranslate(
            layoutBytes,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            commandModifierState,
            keyboardType,
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters,
        )
        guard status == noErr, length == 1 else { return nil }

        return String(utf16CodeUnits: characters, count: length).first
    }
}
