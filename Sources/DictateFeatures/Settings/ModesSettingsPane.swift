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

    private var appIdentifiers: [String] {
        settings.settings.appModes.bundleIdentifiers
    }

    var body: some View {
        SettingsSection("Mode", subtitle: "\(shortcutTitle) switches to the next mode.") {
            ForEach(Mode.allCases, id: \.self) { mode in
                if mode != Mode.allCases.first {
                    RowDivider()
                }

                ModeRow(mode: mode, provider: provider, isSelected: settings.settings.mode == mode) {
                    settings.settings.mode = mode
                }
            }
        }

        SettingsSection("Apps", subtitle: "These apps get their own mode.") {
            if appIdentifiers.isEmpty {
                EmptyRow("No apps yet")
            }

            ForEach(appIdentifiers, id: \.self) { bundleIdentifier in
                if bundleIdentifier != appIdentifiers.first {
                    RowDivider()
                }

                AppModeRow(bundleIdentifier: bundleIdentifier, settings: settings)
            }
        } footer: {
            Button("Add App…", action: addApp)
        }

        SettingsSection("Cloud", subtitle: "Cloud modes send the text, never audio, to \(provider.title).") {
            SettingsRow("Provider") {
                Picker("Provider", selection: $settings.settings.cloudProvider) {
                    ForEach(CloudProvider.allCases, id: \.self) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            RowDivider()
            APIKeyRows(apiKey: apiKeys[provider], prompt: keyPrompt)
        }

        SettingsSection("Instructions", subtitle: "How each cloud mode rewrites your text.") {
            ForEach(Mode.allCases.filter(\.isCloud), id: \.self) { mode in
                if mode != Mode.allCases.first(where: \.isCloud) {
                    RowDivider()
                }

                InstructionsEditor(mode: mode, settings: settings)
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

private struct ModeRow: View {
    let mode: Mode
    let provider: CloudProvider
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(mode.title)
                            .font(.system(size: 13))

                        if mode.isCloud {
                            Image(systemName: "cloud")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .help("Sends the recognized text to \(provider.title)")
                        }
                    }

                    Text(mode.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tint)
                    .opacity(isSelected ? 1 : 0)
            }
            .settingsRowPadding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(FrontmostAppTracker.name(of: bundleIdentifier))
                .font(.system(size: 13))

            Spacer(minLength: 16)

            Picker("Mode", selection: mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .labelsHidden()
            .fixedSize()

            RemoveButton(help: "Use the main mode in this app") {
                settings.settings.appModes.set(nil, for: bundleIdentifier)
            }
        }
        .settingsRowPadding()
    }
}

private struct APIKeyRows: View {
    @Bindable var apiKey: APIKeyModel

    let prompt: String

    var body: some View {
        if apiKey.isSet {
            SettingsRow("API key", description: "Saved in the Keychain") {
                Button("Remove", role: .destructive) { apiKey.remove() }
            }
            RowDivider()
        }

        HStack(spacing: 8) {
            SecureField("API key", text: $apiKey.draft, prompt: Text(apiKey.isSet ? "Replace the key" : prompt))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()

            Button("Save") { apiKey.saveDraft() }
                .disabled(!apiKey.canSaveDraft)
        }
        .settingsRowPadding()
    }
}

private struct InstructionsEditor: View {
    let mode: Mode

    @Bindable var settings: SettingsModel

    private var text: Binding<String> {
        Binding(
            get: { settings.settings.instructions.editableText(for: mode) },
            set: { settings.settings.instructions.set($0, for: mode) },
        )
    }

    private var isCustomized: Bool {
        settings.settings.instructions.isCustomized(mode)
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .trailing, spacing: 8) {
                TextEditor(text: text)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: 132)
                    .background(Palette.window, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Palette.separator, lineWidth: 1)
                    }

                Button("Reset to Default") { settings.settings.instructions.reset(mode) }
                    .disabled(!isCustomized)
            }
            .padding(.top, 10)
        } label: {
            RowLabel(title: mode.title, description: isCustomized ? "Edited" : nil)
        }
        .settingsRowPadding()
    }
}
