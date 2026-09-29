import AppKit
import DictateCore
import Observation
import SwiftUI

/// The one pill at the bottom centre of the screen: it shows the input level while you hold the key,
/// then a spinner while the text is made, then the text itself (or why there is none). It never takes
/// focus and ignores the mouse: the text you are dictating into stays in the key window of its app.
///
/// Whoever owns it decides what comes next (see `TranscriptionPipeline`); the recording state always wins.
@MainActor
final class Overlay {
    /// The recording pill keeps this exact size and accessibility identifier: the E2E suite looks for it.
    static let recordingIdentifier = "dictate.overlay"
    static let recordingSize = CGSize(width: 132, height: 44)
    private static let statusIdentifier = "dictate.status"
    private static let minimumWidth: CGFloat = 176
    private static let padding = CGSize(width: 36, height: 24)
    private static let font = NSFont.systemFont(ofSize: 14)

    private let model = OverlayModel()
    private var panel: OverlayPanel?
    private var levelTimer: Timer?
    private var hideTask: Task<Void, Never>?
    /// True from `show(message:)` until the message has had its time (or something else replaced it).
    private(set) var isShowingMessage = false
    /// Called when a message has run its course, so the owner can show what waited behind it.
    var onMessageFinished: (() -> Void)?

    /// The level meter is showing, i.e. a recording is in progress.
    var isRecording: Bool {
        model.content == .recording && panel?.isVisible == true
    }

    // MARK: Recording

    /// Shows the level pill and refreshes it from `level` (0...1) about 20 times a second.
    func showRecording(level: @escaping @MainActor () -> Float) {
        guard !isRecording else { return }
        cancelHide()
        model.reset()
        model.content = .recording
        present(size: Self.recordingSize, identifier: Self.recordingIdentifier, label: "Dictate is recording")
        levelTimer = Timer.commonModeTimer(interval: 0.05, repeats: true) { [model] in model.push(level()) }
    }

    /// Takes the level pill away (the owner then shows the next thing, if any).
    func hideRecording() {
        guard isRecording else { return }
        levelTimer?.invalidate()
        levelTimer = nil
        panel?.orderOut(nil)
        model.content = .none
    }

    // MARK: After the recording

    /// The spinner never replaces a message that is still being read, and never the recording pill.
    func showTranscribing() {
        guard !isRecording, !isShowingMessage else { return }
        model.content = .transcribing
        present(size: CGSize(width: Self.minimumWidth, height: 44), identifier: Self.statusIdentifier, label: "Dictate status")
    }

    /// Shows all of `text`, wrapped, for as long as `OverlayTiming` says, then hides it and calls
    /// `onMessageFinished`. Ignored while recording.
    func show(message text: String) {
        guard !isRecording else { return }
        cancelHide()
        model.content = .message(text)
        isShowingMessage = true
        present(size: messageSize(for: text), identifier: Self.statusIdentifier, label: "Dictate status")
        let seconds = OverlayTiming.messageSeconds(characters: text.count)
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.hideStatus()
            self?.onMessageFinished?()
        }
    }

    /// Hides a spinner or message (not the recording pill).
    func hideStatus() {
        guard !isRecording else { return }
        cancelHide()
        panel?.orderOut(nil)
        model.content = .none
    }

    // MARK: Layout

    private func cancelHide() {
        hideTask?.cancel()
        hideTask = nil
        isShowingMessage = false
    }

    private func present(size: CGSize, identifier: String, label: String) {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.setAccessibilityIdentifier(identifier)
        panel.setAccessibilityLabel(label)
        panel.setContentSize(size)
        panel.moveToBottomCentre()
        // `orderFront` is not enough for an accessory app: it is never active, so the window
        // would stay behind everything.
        panel.orderFrontRegardless()
    }

    /// Room for the whole text: up to 60 % of the screen wide, as many lines as it needs.
    private func messageSize(for text: String) -> CGSize {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        let widest = (screen?.visibleFrame.width ?? 1200) * 0.6
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: widest - Self.padding.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: Self.font]
        )
        return CGSize(
            width: min(widest, max(Self.minimumWidth, ceil(bounds.width) + Self.padding.width)),
            height: max(44, ceil(bounds.height) + Self.padding.height)
        )
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: NSRect(origin: .zero, size: Self.recordingSize),
            identifier: Self.recordingIdentifier,
            label: "Dictate is recording"
        )
        panel.contentView = NSHostingView(rootView: OverlayView(model: model))
        return panel
    }
}

/// What the pill shows, and the last few input levels (newest last) for the meter.
@MainActor
@Observable
private final class OverlayModel {
    enum Content: Equatable {
        case none
        case recording
        case transcribing
        case message(String)
    }

    static let barCount = 9
    var content = Content.none
    private(set) var levels = [Float](repeating: 0, count: barCount)

    func reset() {
        levels = [Float](repeating: 0, count: Self.barCount)
    }

    func push(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }
}

private struct OverlayView: View {
    let model: OverlayModel

    var body: some View {
        content
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder private var content: some View {
        switch model.content {
        case .none, .recording:
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
            .animation(.linear(duration: 0.05), value: model.levels)
        case .transcribing:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Transcribing…")
            }
        case let .message(text):
            Text(text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
