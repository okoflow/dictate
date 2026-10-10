import Carbon.HIToolbox
import DictateCore

@MainActor
package final class CarbonHotKey: GlobalShortcut {
    private static let signature = OSType(0x4463_7421)
    private static var nextIdentifier: UInt32 = 1

    package let title: String

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let identifier: UInt32
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var action: (@MainActor () -> Void)?

    package init(keyCode: Int, modifiers: Int, title: String) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = UInt32(modifiers)
        self.title = title
        identifier = Self.nextIdentifier
        Self.nextIdentifier += 1
    }

    package static func modeCycle() -> CarbonHotKey {
        CarbonHotKey(keyCode: kVK_ANSI_M, modifiers: controlKey | optionKey, title: "⌃⌥M")
    }

    package func register(_ action: @escaping @MainActor () -> Void) -> Bool {
        guard hotKey == nil else { return true }

        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(GetApplicationEventTarget(), carbonHotKeyCallback, 1, &eventType, context, &handler) == noErr
        else {
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)

        return RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKey) == noErr
    }

    fileprivate func handle(_ pressed: EventHotKeyID) -> OSStatus {
        guard pressed.signature == Self.signature, pressed.id == identifier else { return OSStatus(eventNotHandledErr) }

        action?()

        return noErr
    }
}

private let carbonHotKeyCallback: EventHandlerUPP = { _, event, context in
    guard let context, let pressed = pressedHotKey(in: event) else { return OSStatus(eventNotHandledErr) }

    let hotKey = Unmanaged<CarbonHotKey>.fromOpaque(context).takeUnretainedValue()

    return MainActor.assumeIsolated { hotKey.handle(pressed) }
}

private func pressedHotKey(in event: EventRef?) -> EventHotKeyID? {
    var pressed = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &pressed,
    )

    return status == noErr ? pressed : nil
}
