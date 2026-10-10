import AppKit
import SwiftUI

final class HUDPanel: NSPanel {
    private static let canvasSize = CGSize(width: 720, height: 220)
    private static let bottomInset: CGFloat = 36

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    init(rootView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.canvasSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = NSHostingView(rootView: rootView)
        setAccessibilityIdentifier("waft.hud")
    }

    func showOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.screens.first

        if let area = screen?.visibleFrame {
            setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.minY + Self.bottomInset - 18))
        }

        orderFrontRegardless()
    }
}
