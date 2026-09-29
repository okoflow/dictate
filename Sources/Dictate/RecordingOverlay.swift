import AppKit
import Observation
import SwiftUI

/// The floating pill that shows the input level while recording.
///
/// It must never take focus: the text you are dictating into stays the key window of its app.
@MainActor
final class RecordingOverlay {
    static let accessibilityIdentifier = "dictate.overlay"

    private let model = OverlayModel()
    private var panel: OverlayPanel?
    private var levelTimer: Timer?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    /// Shows the pill and refreshes it from `level` (0...1) about 20 times a second.
    func show(level: @escaping @MainActor () -> Float) {
        guard !isVisible else { return }
        let panel = panel ?? makePanel()
        self.panel = panel
        model.reset()
        position(panel)
        // `orderFront` is not enough for an accessory app: it is never active, so the window
        // would stay behind everything.
        panel.orderFrontRegardless()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [model] _ in
            MainActor.assumeIsolated { model.push(level()) }
        }
    }

    func hide() {
        levelTimer?.invalidate()
        levelTimer = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 132, height: 44))
        let host = NSHostingView(rootView: LevelPill(model: model))
        host.frame = NSRect(origin: .zero, size: panel.frame.size)
        panel.contentView = host
        return panel
    }

    /// Bottom centre of the screen the mouse is on, where the eye usually is while typing.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        panel.setFrameOrigin(NSPoint(x: area.midX - panel.frame.width / 2, y: area.minY + 48))
    }
}

/// A borderless panel that can be shown without activating the app or stealing key status.
private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        setAccessibilityIdentifier(RecordingOverlay.accessibilityIdentifier)
        setAccessibilityLabel("Dictate is recording")
    }
}

/// The last few input levels, newest last.
@MainActor
@Observable
private final class OverlayModel {
    static let barCount = 9
    private(set) var levels = [Float](repeating: 0, count: barCount)

    func reset() {
        levels = [Float](repeating: 0, count: Self.barCount)
    }

    func push(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }
}

private struct LevelPill: View {
    let model: OverlayModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .foregroundStyle(.red)
            HStack(spacing: 3) {
                ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(.primary)
                        .frame(width: 4, height: 4 + 20 * CGFloat(level))
                }
            }
            .frame(height: 24)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: Capsule())
        .animation(.linear(duration: 0.05), value: model.levels)
    }
}
