import AppKit
import SwiftUI

enum Palette {
    static let window = Color(nsColor: .textBackgroundColor)
    static let sidebar = Color(nsColor: dynamic(light: (0.98, 1), dark: (0.155, 1)))
    static let sidebarBorder = Color(nsColor: dynamic(light: (0, 0.045), dark: (1, 0.08)))
    static let sidebarShadow = Color(nsColor: dynamic(light: (0, 0.1), dark: (0, 0.4)))
    static let selection = Color(nsColor: dynamic(light: (0, 0.068), dark: (1, 0.1)))
    static let card = Color(nsColor: dynamic(light: (0, 0.031), dark: (1, 0.055)))
    static let separator = Color(nsColor: .separatorColor)

    private nonisolated static func dynamic(light: (CGFloat, CGFloat), dark: (CGFloat, CGFloat)) -> NSColor {
        NSColor(name: nil) { appearance in
            let (white, alpha) = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light

            return NSColor(white: white, alpha: alpha)
        }
    }
}
