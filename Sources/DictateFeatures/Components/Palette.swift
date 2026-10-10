import AppKit
import SwiftUI

enum Palette {
    static let windowColor = dynamic(light: (0.965, 1), dark: (0.118, 1))
    static let window = Color(nsColor: windowColor)
    static let sidebar = Color(nsColor: dynamic(light: (1, 1), dark: (0.165, 1)))
    static let sidebarBorder = Color(nsColor: dynamic(light: (0, 0.055), dark: (1, 0.07)))
    static let sidebarShadow = Color(nsColor: dynamic(light: (0, 0.06), dark: (0, 0.35)))
    static let selection = Color(nsColor: dynamic(light: (0, 0.06), dark: (1, 0.1)))
    static let hover = Color(nsColor: dynamic(light: (0, 0.03), dark: (1, 0.05)))
    static let card = Color(nsColor: dynamic(light: (1, 1), dark: (1, 0.055)))
    static let cardBorder = Color(nsColor: dynamic(light: (0, 0.045), dark: (1, 0.04)))
    static let control = Color(nsColor: dynamic(light: (0, 0.075), dark: (1, 0.12)))
    static let controlPressed = Color(nsColor: dynamic(light: (0, 0.14), dark: (1, 0.2)))
    static let field = Color(nsColor: dynamic(light: (0, 0.045), dark: (1, 0.07)))
    static let fieldFocused = Color(nsColor: dynamic(light: (1, 1), dark: (0, 0.25)))
    static let separator = Color(nsColor: .separatorColor)

    private nonisolated static func dynamic(light: (CGFloat, CGFloat), dark: (CGFloat, CGFloat)) -> NSColor {
        NSColor(name: nil) { appearance in
            let (white, alpha) = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light

            return NSColor(white: white, alpha: alpha)
        }
    }
}
