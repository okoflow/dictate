import DictateCore
import Foundation
import Observation
import os

@Observable
package final class SpeechModelController {
    package private(set) var state = SpeechModelState()

    @ObservationIgnored var onReady: (() -> Void)?

    @ObservationIgnored private let transcriber: any Transcriber
    @ObservationIgnored private var languages: [Language]

    package var modelDirectory: URL {
        transcriber.modelDirectory
    }

    init(transcriber: any Transcriber, languages: [Language]) {
        self.transcriber = transcriber
        self.languages = languages
    }

    package func retry() {
        apply(.retryRequested)
    }

    func start() {
        Task {
            let isInstalled = await transcriber.isModelInstalled()

            apply(.started(isInstalled: isInstalled))
        }
    }

    func reload(for languages: [Language]) {
        self.languages = languages

        apply(.reloadRequested)
    }

    private func apply(_ event: SpeechModelState.Event) {
        for effect in state.handle(event) {
            perform(effect)
        }
    }

    private func perform(_ effect: SpeechModelState.Effect) {
        switch effect {
        case .deleteModel:
            Task { await transcriber.deleteModel() }
        case .download:
            Task { await download() }
        case .load:
            Task { await load() }
        }
    }

    private func download() async {
        do {
            try await transcriber.downloadModel { [weak self] fraction in
                Task { @MainActor in self?.apply(.downloadProgressed(fraction)) }
            }

            apply(.downloaded)
        } catch {
            Logger.speechModel.error("Download failed: \(error.localizedDescription, privacy: .public)")

            apply(.failed(error.localizedDescription))
        }
    }

    private func load() async {
        do {
            let duration = try await transcriber.loadModel(for: languages)

            Logger.speechModel
                .info("Loaded the speech model in \(duration.formatted(.units(allowed: [.seconds])), privacy: .public)")

            apply(.loaded)

            if state.isReady {
                onReady?()
            }
        } catch {
            Logger.speechModel.error("Load failed: \(error.localizedDescription, privacy: .public)")

            apply(.failed(error.localizedDescription))
        }
    }
}
