package enum WritingScript: Sendable {
    case arabic
    case cyrillic
    case devanagari
    case greek
    case han
    case hangul
    case hebrew
    case kana
    case latin
    case tamil
    case thai

    var hasLetterCase: Bool {
        switch self {
        case .cyrillic, .greek, .latin:
            true
        case .arabic, .devanagari, .han, .hangul, .hebrew, .kana, .tamil, .thai:
            false
        }
    }

    var separatesWordsWithSpaces: Bool {
        switch self {
        case .han, .kana, .thai:
            false
        case .arabic, .cyrillic, .devanagari, .greek, .hangul, .hebrew, .latin, .tamil:
            true
        }
    }

    var hasLooseWordSpacing: Bool {
        switch self {
        case .han, .hangul, .kana, .thai:
            true
        case .arabic, .cyrillic, .devanagari, .greek, .hebrew, .latin, .tamil:
            false
        }
    }

    package init?(_ scalar: Unicode.Scalar) {
        switch scalar.value {
        case 0x0041 ... 0x005A, 0x0061 ... 0x007A, 0x00C0 ... 0x02AF, 0x1E00 ... 0x1EFF:
            self = .latin
        case 0x0370 ... 0x03FF, 0x1F00 ... 0x1FFF:
            self = .greek
        case 0x0400 ... 0x052F:
            self = .cyrillic
        case 0x0590 ... 0x05FF, 0xFB1D ... 0xFB4F:
            self = .hebrew
        case 0x0600 ... 0x06FF, 0x0750 ... 0x077F, 0x0870 ... 0x08FF, 0xFB50 ... 0xFDFF, 0xFE70 ... 0xFEFF:
            self = .arabic
        case 0x0900 ... 0x097F, 0xA8E0 ... 0xA8FF:
            self = .devanagari
        case 0x0B80 ... 0x0BFF:
            self = .tamil
        case 0x0E00 ... 0x0E7F:
            self = .thai
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
