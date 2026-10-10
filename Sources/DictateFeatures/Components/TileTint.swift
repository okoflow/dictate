import SwiftUI

enum TileTint {
    case gray
    case red
    case purple
    case orange
    case blue
    case green
    case indigo
    case teal
    case pink

    var gradient: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    private var top: Color {
        switch self {
        case .gray: Color(hex: 0x8C8C8C)
        case .red: Color(hex: 0xF04B5B)
        case .purple: Color(hex: 0x8A4DD2)
        case .orange: Color(hex: 0xF4922A)
        case .blue: Color(hex: 0x30A2F3)
        case .green: Color(hex: 0x1BAA75)
        case .indigo: Color(hex: 0x6E6CF2)
        case .teal: Color(hex: 0x2BBDD0)
        case .pink: Color(hex: 0xF2588F)
        }
    }

    private var bottom: Color {
        switch self {
        case .gray: Color(hex: 0x585858)
        case .red: Color(hex: 0xD02E47)
        case .purple: Color(hex: 0x6130BB)
        case .orange: Color(hex: 0xEE7618)
        case .blue: Color(hex: 0x247DE1)
        case .green: Color(hex: 0x098551)
        case .indigo: Color(hex: 0x4A46D4)
        case .teal: Color(hex: 0x1593B3)
        case .pink: Color(hex: 0xD6346E)
        }
    }
}

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double(hex >> 16 & 0xFF) / 255,
            green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
        )
    }
}
