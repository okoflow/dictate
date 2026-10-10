import AppKit
import DictateCore
import SwiftUI
import UniformTypeIdentifiers

struct ModesSettingsPane: View {
    @Bindable var settings: SettingsModel

    let apiKeys: PerProvider<APIKeyModel>
    let shortcutTitle: String

    private var provider: CloudProvider {
        settings.settings.cloudProvider
    }

    private var keyPrompt: String {
        switch provider {
        case .claude: "sk-ant-…"
        case .openAI: "sk-proj-…"
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $settings.settings.mode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        ModeLabel(mode: mode, provider: provider).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                Text("Mode")
            } footer: {
                SectionNote("\(shortcutTitle) switches to the next mode.")
            }

            Section {
                ForEach(settings.settings.appModes.bundleIdentifiers, id: \.self) { bundleIdentifier in
                    AppModeRow(bundleIdentifier: bundleIdentifier, settings: settings)
                }

                Button("Add App…", action: addApp)
            } header: {
                Text("Apps with their own mode")
            }

            Section {
                Picker("Provider", selection: $settings.settings.cloudProvider) {
                    ForEach(CloudProvider.allCases, id: \.self) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                APIKeyRow(apiKey: apiKeys[provider], prompt: keyPrompt)
            } header: {
                Text("Cloud")
            } footer: {
                SectionNote("Cloud modes send the text, never audio, to \(provider.title).")
            }
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.prompt = "Add"

        guard panel.runModal() == .OK, let url = panel.url,
              let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else { return }

        settings.settings.appModes.set(settings.settings.mode, for: bundleIdentifier)
    }
}

private struct ModeLabel: View {
    let mode: Mode
    let provider: CloudProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Text(mode.title)

                if mode.isCloud {
                    Image(systemName: "cloud")
                        .foregroundStyle(.secondary)
                        .help("Sends the recognized text to \(provider.title)")
                }
            }
            Text(mode.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct AppModeRow: View {
    let bundleIdentifier: String

    @Bindable var settings: SettingsModel

    private var icon: NSImage {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .application)
    }

    private var mode: Binding<Mode> {
        Binding(
            get: { settings.settings.appModes.mode(for: bundleIdentifier) ?? settings.settings.mode },
            set: { settings.settings.appModes.set($0, for: bundleIdentifier) },
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)

            Text(FrontmostAppTracker.name(of: bundleIdentifier))

            Spacer()

            Picker("Mode", selection: mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .fixedSize()

            Button {
                settings.settings.appModes.set(nil, for: bundleIdentifier)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Use the main mode in this app")
        }
    }
}

private struct APIKeyRow: View {
    @Bindable var apiKey: APIKeyModel

    let prompt: String

    var body: some View {
        if apiKey.isSet {
            HStack {
                Label("Saved in the Keychain", systemImage: "key.fill")
                Spacer()
                Button("Remove", role: .destructive) { apiKey.remove() }
            }
        }

        HStack {
            SecureField("API key", text: $apiKey.draft, prompt: Text(apiKey.isSet ? "Replace the key" : prompt))
                .labelsHidden()

            Button("Save") { apiKey.saveDraft() }
                .disabled(!apiKey.canSaveDraft)
        }
    }
}
