import AppKit
import Observation
import SwiftUI

/// The pill that says what happens after the recording: a spinner while the text is being made,
/// then a line of it (or why there is none). A window of its own, so the recording pill keeps its
/// identity and size; never shown together with it.
@MainActor
final class StatusOverlay {
    static let accessibilityIdentifier = "dictate.status"
    /// About this many characters of the text fit; the rest is cut.
    static let previewLength = 60
    private static let minimumWidth: CGFloat = 176
    private static let maximumWidth: CGFloat = 520

    private let model = StatusModel()
    private var panel: OverlayPanel?
    private var hideTask: Task<Void, Never>?
    /// True from `show(message:)` until the message has had its time (or `hide()` cut it short).
    private(set) var isShowingMessage = false
    /// Called when a message has run its course, so the owner can show what waited behind it.
    var onMessageFinished: (() -> Void)?

    /// The spinner never replaces a message that is still being read.
    func showTranscribing() {
        guard !isShowingMessage else { return }
        present(.transcribing)
    }

    /// Shows `text` (cut to `previewLength`) and hides it again after `duration`.
    func show(message text: String, for duration: Duration = .milliseconds(1500)) {
        let shown = text.count > Self.previewLength ? String(text.prefix(Self.previewLength)) + "…" : text
        present(.message(shown))
        isShowingMessage = true
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.hide()
            self?.onMessageFinished?()
        }
    }

    func hide() {
        hideTask?.cancel()
        hideTask = nil
        isShowingMessage = false
        panel?.orderOut(nil)
    }

    private func present(_ content: StatusModel.Content) {
        hideTask?.cancel()
        hideTask = nil
        let panel = panel ?? makePanel()
        self.panel = panel
        model.content = content
        let host = panel.contentView as? NSHostingView<StatusPill>
        host?.layoutSubtreeIfNeeded()
        let fitting = host?.fittingSize ?? CGSize(width: Self.minimumWidth, height: 44)
        panel.setContentSize(CGSize(width: min(Self.maximumWidth, max(Self.minimumWidth, fitting.width)), height: 44))
        panel.moveToBottomCentre()
        panel.orderFrontRegardless()
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.minimumWidth, height: 44),
            identifier: Self.accessibilityIdentifier,
            label: "Dictate status"
        )
        panel.contentView = NSHostingView(rootView: StatusPill(model: model))
        return panel
    }
}

@MainActor
@Observable
private final class StatusModel {
    enum Content: Equatable {
        case transcribing
        case message(String)
    }

    var content = Content.transcribing
}

private struct StatusPill: View {
    let model: StatusModel

    var body: some View {
        HStack(spacing: 10) {
            switch model.content {
            case .transcribing:
                ProgressView()
                    .controlSize(.small)
                Text("Transcribing…")
            case let .message(text):
                Text(text)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .frame(minWidth: 176, maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
        .background(.regularMaterial, in: Capsule())
    }
}
