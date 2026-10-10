extension Language {
    private static let cedillaToCommaBelow: [Unicode.Scalar: Unicode.Scalar] = ["\u{015F}": "\u{0219}", "\u{0163}": "\u{021B}"]

    func foldedScalar(_ scalar: Unicode.Scalar) -> Unicode.Scalar? {
        guard !isOptionalMark(scalar) else { return nil }

        return self == .romanian ? Self.cedillaToCommaBelow[scalar, default: scalar] : scalar
    }

    private func isOptionalMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0640, 0x064B ... 0x065F, 0x0670:
            scripts.contains(.arabic)
        case 0x0591 ... 0x05BD, 0x05BF, 0x05C1 ... 0x05C2, 0x05C4 ... 0x05C5, 0x05C7:
            scripts.contains(.hebrew)
        case 0x094D:
            scripts.contains(.devanagari)
        default:
            false
        }
    }
}
