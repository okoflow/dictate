package enum PushToTalkKey: String, CaseIterable, Codable, Sendable {
    case rightOption
    case rightCommand
    case rightShift

    package var keyCode: Int64 {
        switch self {
        case .rightOption: 61
        case .rightCommand: 54
        case .rightShift: 60
        }
    }

    package var deviceFlag: UInt64 {
        switch self {
        case .rightOption: 0x40
        case .rightCommand: 0x10
        case .rightShift: 0x04
        }
    }

    package var title: String {
        switch self {
        case .rightOption: "Right Option (⌥)"
        case .rightCommand: "Right Command (⌘)"
        case .rightShift: "Right Shift (⇧)"
        }
    }

    package var shortTitle: String {
        switch self {
        case .rightOption: "right ⌥"
        case .rightCommand: "right ⌘"
        case .rightShift: "right ⇧"
        }
    }

    package func event(for keyEvent: KeyEvent) -> PushToTalk.Event? {
        switch keyEvent.kind {
        case .monitorDisabled:
            .monitorDisabled
        case .keyDown:
            .otherKeyDown
        case .modifiersChanged where keyEvent.keyCode == keyCode:
            isMarked(in: keyEvent.flags) ? .keyDown : .keyUp
        case .modifiersChanged:
            nil
        }
    }

    package func isMarked(in flags: UInt64) -> Bool {
        flags & deviceFlag != 0
    }
}
