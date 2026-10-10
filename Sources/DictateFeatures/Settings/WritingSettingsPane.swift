import AppKit
import DictateCore
import SwiftUI
import UniformTypeIdentifiers

struct WritingSettingsPane: View {
    @Bindable var settings: SettingsModel

    let apiKeys: PerProvider<APIKeyModel>
    let shortcutTitle: String
    let state: SettingsWindowState

    private var provider: CloudProvider {
        settings.settings.cloudProvider
    }

    private var needsKey: Bool {
        !apiKeys[provider].isSet
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

                ModeRow(mode: mode, provider: provider, settings: settings, state: state)
            }
        } footer: {
            if needsKey {
                Text("Cloud modes need a \(provider.title) API key.")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)

                Button("Set Up…") { state.selection = .cloud }
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
        .animation(.snappy(duration: 0.2), value: appIdentifiers)

        SettingsSection("Output") {
            ToggleRow(
                "Paste into the focused field",
                isOn: $settings.settings.pastesIntoFocusedField,
                description: "When off, Dictate copies the text and you paste it yourself.",
            )
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

    @Bindable var settings: SettingsModel

    let state: SettingsWindowState

    private var isSelected: Bool {
        settings.settings.mode == mode
    }

    private var isCustomized: Bool {
        mode.isCloud && settings.settings.instructions.isCustomized(mode)
    }

    var body: some View {
        HStack(spacing: Metrics.controlSpacing + 4) {
            Button {
                settings.settings.mode = mode
            } label: {
                HStack(spacing: 0) {
                    ModeLabel(mode: mode, provider: provider, isCustomized: isCustomized)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if mode.isCloud {
                InstructionsButton(mode: mode, provider: provider, settings: settings, state: state)
            }

            Image(systemName: "checkmark")
                .font(.sectionTitle)
                .foregroundStyle(.tint)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)
        }
        .settingsRowPadding()
    }
}

private struct ModeLabel: View {
    let mode: Mode
    let provider: CloudProvider
    let isCustomized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(mode.title)
                    .font(.rowTitle)

                if mode.isCloud {
                    Image(systemName: "cloud")
                        .font(.glyph)
                        .foregroundStyle(.secondary)
                        .help("Sends the recognized text to \(provider.title)")
                }

                if isCustomized {
                    Badge("Edited")
                }
            }

            Text(mode.summary)
                .font(.rowDetail)
                .foregroundStyle(.secondary)
        }
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
                .frame(width: Metrics.tileSize, height: Metrics.tileSize)
                .accessibilityHidden(true)

            Text(FrontmostAppTracker.name(of: bundleIdentifier))
                .font(.rowTitle)

            Spacer(minLength: 16)

            MenuPicker("Mode", selection: mode, current: mode.wrappedValue.title) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            RemoveButton(help: "Use the main mode in this app") {
                settings.settings.appModes.set(nil, for: bundleIdentifier)
            }
        }
        .settingsRowPadding()
    }
}
