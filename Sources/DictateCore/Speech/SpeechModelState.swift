import Foundation

package struct SpeechModelState: Equatable, Sendable {
    package enum Phase: Equatable, Sendable {
        case notInstalled
        case downloading(progress: Double)
        case loading
        case ready
        case failed(reason: String, during: Step)
    }

    package enum Step: Sendable {
        case download
        case load
    }

    package enum Event: Sendable {
        case started(isInstalled: Bool)
        case downloadProgressed(Double)
        case downloaded
        case loaded
        case failed(String)
        case retryRequested
        case reloadRequested
    }

    package enum Effect: Equatable, Sendable {
        case deleteModel
        case download
        case load
    }

    package private(set) var phase = Phase.notInstalled

    private var hasRetriedLoad = false
    private var needsReload = false

    package var isReady: Bool {
        phase == .ready
    }

    package var canRetry: Bool {
        if case .failed = phase {
            true
        } else {
            false
        }
    }

    package var progress: Double? {
        if case let .downloading(progress) = phase {
            progress
        } else {
            nil
        }
    }

    package var statusText: String {
        switch phase {
        case .notInstalled: String(localized: "Speech model not installed")
        case let .downloading(progress): String(localized: "Downloading speech model… \(Self.percent(progress))")
        case .loading: String(localized: "Preparing speech model…")
        case .ready: String(localized: "Ready")
        case let .failed(reason, _): String(localized: "Speech model failed: \(reason)")
        }
    }

    package var notReadyMessage: String {
        switch phase {
        case .notInstalled, .ready: String(localized: "The speech model isn't ready yet")
        case let .downloading(progress): String(localized: "Downloading the speech model… \(Self.percent(progress))")
        case .loading: String(localized: "Preparing the speech model, about a minute the first time…")
        case .failed: String(localized: "The speech model failed to load. Retry from the menu.")
        }
    }

    package init() {}

    private static func percent(_ progress: Double) -> String {
        progress.formatted(.percent.precision(.fractionLength(0)))
    }

    private static func reason(of event: Event) -> String {
        if case let .failed(reason) = event {
            reason
        } else {
            "unknown error"
        }
    }

    package mutating func handle(_ event: Event) -> [Effect] {
        switch (phase, event) {
        case let (.notInstalled, .started(isInstalled)):
            phase = isInstalled ? .loading : .downloading(progress: 0)

            return [isInstalled ? .load : .download]

        case let (.downloading(current), .downloadProgressed(progress)):
            phase = .downloading(progress: min(1, max(current, progress)))

            return []

        case (.downloading, .downloaded):
            phase = .loading

            return [.load]

        case (.loading, .loaded):
            return finishLoading()

        case (.downloading, .failed), (.loading, .failed):
            phase = .failed(reason: Self.reason(of: event), during: phase == .loading ? .load : .download)

            return []

        case let (.failed(_, step), .retryRequested):
            return retry(after: step)

        case (.ready, .reloadRequested):
            phase = .loading

            return [.load]

        case (.loading, .reloadRequested):
            needsReload = true

            return []

        default:
            return []
        }
    }

    private mutating func finishLoading() -> [Effect] {
        hasRetriedLoad = false

        guard needsReload else {
            phase = .ready

            return []
        }

        needsReload = false

        return [.load]
    }

    private mutating func retry(after step: Step) -> [Effect] {
        switch step {
        case .download:
            phase = .downloading(progress: 0)

            return [.download]

        case .load where !hasRetriedLoad:
            hasRetriedLoad = true
            phase = .loading

            return [.load]

        case .load:
            hasRetriedLoad = false
            phase = .downloading(progress: 0)

            return [.deleteModel, .download]
        }
    }
}
