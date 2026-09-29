import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// The virtual key code that types "v" in the current keyboard layout. ⌘V is a shortcut for the key
/// that *produces* "v", so on Dvorak or Colemak the physical key differs from `kVK_ANSI_V`. The
/// ASCII-capable layout is used, so a Russian or Korean input source still finds it (the shortcut then
/// follows the Latin layout, as macOS does for ⌘V).
enum PasteKey {
    static let fallback: CGKeyCode = 9

    static func keyCode() -> CGKeyCode {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return fallback }
        let layout = unsafeBitCast(property, to: CFData.self)
        let keyboardType = UInt32(CGEventSource(stateID: .combinedSessionState)?.keyboardType ?? 0)
        for code in 0 ..< 128 where character(for: UInt16(code), layout: layout, keyboardType: keyboardType) == "v" {
            return CGKeyCode(code)
        }
        return fallback
    }

    private static func character(for keyCode: UInt16, layout: CFData, keyboardType: UInt32) -> Character? {
        var deadKeys: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layout.withBytes { bytes in
            UCKeyTranslate(
                bytes.assumingMemoryBound(to: UCKeyboardLayout.self), keyCode, UInt16(kUCKeyActionDisplay), 0,
                keyboardType, OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters
            )
        }
        guard status == noErr, length == 1 else { return nil }
        return String(utf16CodeUnits: characters, count: length).first
    }
}

private extension CFData {
    func withBytes<T>(_ body: (UnsafeRawPointer) -> T) -> T {
        body(UnsafeRawPointer(CFDataGetBytePtr(self)))
    }
}
