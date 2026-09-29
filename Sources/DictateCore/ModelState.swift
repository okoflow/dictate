import Foundation

/// Where the speech model is on its way from "not on disk" to "ready to transcribe".
///
/// A pure state machine: the app feeds it what happened and does what the returned `Effect`s say,
/// so the menu, the retry and the clean-up of a broken download are testable without a network.
public struct ModelState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case notDownloaded
        /// `progress` is 0...1.
        case downloading(progress: Double)
        case loading
        case ready
        case failed(reason: String, during: Step)
    }

    /// What was going on when a failure hit; decides what a retry has to redo.
    public enum Step: Equatable, Sendable {
        case download
        case load
    }

    public enum Event: Equatable, Sendable {
        /// The app starts up. `installed` says whether a complete copy is already on disk.
        case start(installed: Bool)
        case downloadProgress(Double)
        case downloaded
        case loaded
        case failed(String)
        /// The user chose "Retry" in the menu.
        case retry
    }

    public enum Effect: Equatable, Sendable {
        /// A model that will not load is deleted before it is fetched again.
        case removeModel
        case download
        case load
    }

    public private(set) var phase = Phase.notDownloaded

    public init() {}

    /// Push-to-talk works only in this state.
    public var isReady: Bool {
        phase == .ready
    }

    /// The menu line.
    public var statusText: String {
        switch phase {
        case .notDownloaded: "Model not downloaded"
        case let .downloading(progress): "Downloading model… \(Int((progress * 100).rounded()))%"
        case .loading: "Loading model…"
        case .ready: "Ready"
        case let .failed(reason, _): "Model failed: \(reason)"
        }
    }

    public var canRetry: Bool {
        if case .failed = phase {
            true
        } else {
            false
        }
    }

    /// Applies `event` and returns what the app has to do about it.
    public mutating func handle(_ event: Event) -> [Effect] {
        switch (phase, event) {
        case (.notDownloaded, .start):
            return begin(event)
        case let (.downloading(current), .downloadProgress(progress)):
            // Progress reports can arrive out of order; the bar must not jump back.
            phase = .downloading(progress: min(1, max(current, progress)))
            return []
        case (.downloading, .downloaded):
            phase = .loading
            return [.load]
        case (.loading, .loaded):
            phase = .ready
            return []
        case (.downloading, .failed), (.loading, .failed):
            return fail(event)
        case (.failed, .retry):
            return retry()
        default:
            return []
        }
    }

    private mutating func begin(_ event: Event) -> [Effect] {
        guard case let .start(installed) = event else { return [] }
        phase = installed ? .loading : .downloading(progress: 0)
        return [installed ? .load : .download]
    }

    private mutating func fail(_ event: Event) -> [Effect] {
        guard case let .failed(reason) = event else { return [] }
        phase = .failed(reason: reason, during: phase == .loading ? .load : .download)
        return []
    }

    private mutating func retry() -> [Effect] {
        guard case let .failed(_, step) = phase else { return [] }
        switch step {
        case .download:
            // The downloader resumes; files that are complete stay.
            phase = .downloading(progress: 0)
            return [.download]
        case .load:
            phase = .downloading(progress: 0)
            return [.removeModel, .download]
        }
    }
}
