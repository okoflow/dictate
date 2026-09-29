import AppKit
import Observation
import SwiftUI

/// The floating pill that shows the input level while recording.
///
/// It must never take focus: the text you are dictating into stays the key window of its app.
@MainActor
final class RecordingOverlay {
    static let accessibilityIdentifier = "dictate.overlay"
    /// The E2E suite tells this window from the others of the app by its size.
    static let size = CGSize(width: 132, height: 44)

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
        panel.moveToBottomCentre()
        // `orderFront` is not enough for an accessory app: it is never active, so the window
        // would stay behind everything.
        panel.orderFrontRegardless()
        levelTimer = Timer.commonModeTimer(interval: 0.05, repeats: true) { [model] in model.push(level()) }
    }

    func hide() {
        levelTimer?.invalidate()
        levelTimer = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.size.width, height: Self.size.height),
            identifier: Self.accessibilityIdentifier,
            label: "Dictate is recording"
        )
        let host = NSHostingView(rootView: LevelPill(model: model))
        host.frame = NSRect(origin: .zero, size: panel.frame.size)
        panel.contentView = host
        return panel
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
