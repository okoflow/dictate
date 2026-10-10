import AppKit
import DictateCore
import SwiftUI

struct AIModelsSettingsPane: View {
    @Bindable var settings: SettingsModel

    let speechModel: SpeechModelController
    let apiKeys: PerProvider<APIKeyModel>
    let localModels: LocalModelsModel

    var body: some View {
        SettingsSection("Speech recognition", subtitle: "Whisper runs on this Mac, so audio never leaves it.") {
            SpeechModelRow(controller: speechModel)
        }

        AppleIntelligenceSection(settings: settings, localModels: localModels)
        LocalServerSection(settings: settings, localModels: localModels)

        ForEach(CloudProvider.allCases, id: \.self) { provider in
            CloudProviderSection(provider: provider, apiKey: apiKeys[provider], settings: settings)
        }
    }
}

private struct SpeechModelRow: View {
    let controller: SpeechModelController

    var body: some View {
        SettingsRow(controller.state.statusText, description: "Whisper large-v3 turbo · 630 MB") {
            if let progress = controller.state.progress {
                ProgressView(value: progress)
                    .frame(width: 100)
            }

            if controller.state.canRetry {
                Button("Retry") { controller.retry() }
            }

            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([controller.modelDirectory])
            }
        }
    }
}
