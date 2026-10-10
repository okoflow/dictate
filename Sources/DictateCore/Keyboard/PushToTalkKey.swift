package struct PushToTalkKey: Hashable, Sendable {
    private struct Modifier {
        let name: String
        let symbol: String
        let flag: UInt64
    }

    package static let rightOption = PushToTalkKey(known: 61)
    package static let rightCommand = PushToTalkKey(known: 54)
    package static let rightShift = PushToTalkKey(known: 60)
    package static let function = PushToTalkKey(known: 63)

    private static let modifiers: [Int64: Modifier] = [
        54: Modifier(name: "Right Command", symbol: "⌘", flag: 0x10),
        55: Modifier(name: "Left Command", symbol: "⌘", flag: 0x08),
        56: Modifier(name: "Left Shift", symbol: "⇧", flag: 0x02),
        60: Modifier(name: "Right Shift", symbol: "⇧", flag: 0x04),
        58: Modifier(name: "Left Option", symbol: "⌥", flag: 0x20),
        61: Modifier(name: "Right Option", symbol: "⌥", flag: 0x40),
        59: Modifier(name: "Left Control", symbol: "⌃", flag: 0x01),
        62: Modifier(name: "Right Control", symbol: "⌃", flag: 0x2000),
        63: Modifier(name: "Fn", symbol: "🌐", flag: 0x800000),
    ]

    private static let functionKeys: [Int64: Int] = [
        122: 1,
        120: 2,
        99: 3,
        118: 4,
        96: 5,
        97: 6,
        98: 7,
        100: 8,
        101: 9,
        109: 10,
        103: 11,
        111: 12,
        105: 13,
        107: 14,
        113: 15,
        106: 16,
        64: 17,
        79: 18,
        80: 19,
        90: 20,
    ]

    package let keyCode: Int64

    package var modifierFlag: UInt64? {
        Self.modifiers[keyCode]?.flag
    }

    package var title: String {
        guard let modifier = Self.modifiers[keyCode] else { return functionKeyTitle }

        return "\(modifier.name) (\(modifier.symbol))"
    }

    package var shortTitle: String {
        guard let modifier = Self.modifiers[keyCode] else { return functionKeyTitle }
        guard self != .function, let side = modifier.name.split(separator: " ").first else { return "fn" }

        return "\(side.lowercased()) \(modifier.symbol)"
    }

    private var functionKeyTitle: String {
        "F\(Self.functionKeys[keyCode] ?? 0)"
    }

    package init?(keyCode: Int64) {
        guard Self.modifiers[keyCode] != nil || Self.functionKeys[keyCode] != nil else { return nil }

        self.keyCode = keyCode
    }

    private init(known keyCode: Int64) {
        self.keyCode = keyCode
    }

    package func event(for keyEvent: KeyEvent) -> PushToTalk.Event? {
        switch keyEvent.kind {
        case .monitorDisabled:
            .monitorDisabled
        case .modifiersChanged:
            modifierEvent(for: keyEvent)
        case .keyDown:
            isOwnFunctionKey(keyEvent) ? .keyDown : .otherKeyDown
        case .keyUp:
            isOwnFunctionKey(keyEvent) ? .keyUp : nil
        }
    }

    package func isHeld(in flags: UInt64) -> Bool {
        modifierFlag.map { flags & $0 != 0 } ?? false
    }

    package func isPressed(by keyEvent: KeyEvent) -> Bool {
        guard modifierFlag == nil else { return isHeld(in: keyEvent.flags) }

        return keyEvent.kind == .keyDown && keyEvent.keyCode == keyCode
    }

    private func modifierEvent(for keyEvent: KeyEvent) -> PushToTalk.Event? {
        guard let modifierFlag, keyEvent.keyCode == keyCode else { return nil }

        return keyEvent.flags & modifierFlag != 0 ? .keyDown : .keyUp
    }

    private func isOwnFunctionKey(_ keyEvent: KeyEvent) -> Bool {
        modifierFlag == nil && keyEvent.keyCode == keyCode
    }
}

extension PushToTalkKey: Codable {
    private static let legacyNames: [String: PushToTalkKey] = [
        "rightOption": .rightOption,
        "rightCommand": .rightCommand,
        "rightShift": .rightShift,
    ]

    package init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let name = try? container.decode(String.self) {
            self = Self.legacyNames[name] ?? .rightOption
        } else {
            self = try PushToTalkKey(keyCode: container.decode(Int64.self)) ?? .rightOption
        }
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(keyCode)
    }
}
