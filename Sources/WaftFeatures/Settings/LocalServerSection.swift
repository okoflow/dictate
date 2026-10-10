import SwiftUI
import WaftCore

struct LocalServerSection: View {
    @Bindable var settings: SettingsModel

    let localModels: LocalModelsModel

    private var baseURL: Binding<String> {
        Binding(
            get: { settings.settings.localServer.baseURL },
            set: { settings.settings.localServer.baseURL = $0 },
        )
    }

    private var model: Binding<String> {
        Binding(
            get: { settings.settings.localServer.model },
            set: { settings.settings.localServer.model = $0 },
        )
    }

    private var status: LocalizedStringKey {
        switch localModels.serverState {
        case .unknown: "Not checked yet"
        case .checking: "Checking…"
        case .running: localModels.serverModels.isEmpty ? "Running, but no models are loaded" : "Running"
        case .notRunning: "Not running at this address"
        }
    }

    private var modelTitle: String {
        settings.settings.localServer.model.isEmpty ? String(localized: "Choose") : settings.settings.localServer.model
    }

    var body: some View {
        SettingsSection(
            "Local server",
            subtitle: "Ollama, LM Studio, llama.cpp, MLX or Jan on this Mac; the text never leaves it.",
        ) {
            HStack(spacing: Metrics.controlSpacing) {
                InputField(.verbatim("http://localhost:11434/v1"), text: baseURL)
                    .onSubmit { refresh() }

                Button("Detect", action: detect)
            }
            .settingsRowPadding()
            RowDivider()
            SettingsRow("Model", description: status) {
                if localModels.serverModels.isEmpty {
                    Button("Check", action: refresh)
                } else {
                    MenuPicker("Model", selection: model, current: modelTitle) {
                        ForEach(localModels.serverModels, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
            }
        } accessory: {
            InUseAccessory(
                isInUse: settings.settings.modelProvider == .localServer,
                canUse: settings.settings.localServer.isConfigured,
            ) {
                settings.settings.modelProvider = .localServer
            }
        }
        .task { await localModels.refresh(settings.settings.localServer) }
    }

    private func refresh() {
        Task { await localModels.refresh(settings.settings.localServer) }
    }

    private func detect() {
        Task {
            guard let server = await localModels.detect() else { return }

            settings.settings.localServer = server
        }
    }
}
