package enum WritingScript: Sendable {
    case cyrillic
    case han
    case hangul
    case kana
    case latin

    package init?(_ scalar: Unicode.Scalar) {
        switch scalar.value {
        case 0x0041 ... 0x005A, 0x0061 ... 0x007A, 0x00C0 ... 0x024F, 0x1E00 ... 0x1EFF:
            self = .latin
        case 0x0400 ... 0x052F:
            self = .cyrillic
        case 0x1100 ... 0x11FF, 0x3130 ... 0x318F, 0xA960 ... 0xA97F, 0xAC00 ... 0xD7AF, 0xD7B0 ... 0xD7FF:
            self = .hangul
        case 0x3040 ... 0x30FF, 0x31F0 ... 0x31FF, 0xFF66 ... 0xFF9F:
            self = .kana
        case 0x3005, 0x3400 ... 0x4DBF, 0x4E00 ... 0x9FFF, 0xF900 ... 0xFAFF, 0x20000 ... 0x323AF:
            self = .han
        default:
            return nil
        }
    }

    package static func dominant(in text: String) -> WritingScript? {
        var counts: [WritingScript: Int] = [:]
        var letters = 0

        for scalar in text.unicodeScalars where scalar.properties.isAlphabetic {
            letters += 1

            if let script = WritingScript(scalar) {
                counts[script, default: 0] += 1
            }
        }

        guard let (script, count) = counts.max(by: { $0.value < $1.value }), count * 2 > letters else { return nil }

        return script
    }
}
