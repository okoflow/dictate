import AppKit
import DictateCore
import SwiftUI
import UniformTypeIdentifiers

struct WritingSettingsPane: View {
    private static var languagesByName: [Language] {
        Language.allCases.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    @Bindable var settings: SettingsModel

    let apiKeys: PerProvider<APIKeyModel>
    let localModels: LocalModelsModel
    let shortcutTitle: String
    let pro: ProModel
    let state: SettingsWindowState

    private var provider: ModelProvider {
        settings.settings.modelProvider
    }

    private var translationTarget: Binding<Language> {
        Binding(
            get: { settings.settings.translation.target },
            set: { target in
                let twoWay = settings.settings.translation.twoWayLanguage

                settings.settings.translation = Translation(target: target, twoWayLanguage: twoWay)
            },
        )
    }

    private var twoWayLanguage: Binding<Language?> {
        Binding(
            get: { settings.settings.translation.twoWayLanguage },
            set: { language in
                settings.settings.translation = Translation(
                    target: settings.settings.translation.target,
                    twoWayLanguage: language,
                )
            },
        )
    }

    private var translationNote: LocalizedStringKey {
        let target = settings.settings.translation.target.inlineName

        guard let other = settings.settings.translation.twoWayLanguage?.inlineName else {
            return .verbatim(String(localized: "Translate turns anything you say into \(target)."))
        }

        return .verbatim(String(localized: "Speak \(other) to get \(target), and \(target) to get \(other).").sentenceCased)
    }

    private var setupNote: LocalizedStringKey? {
        switch provider {
        case let .cloud(cloud):
            apiKeys[cloud].isSet ? nil : "Clean, Formal and Translate need a \(cloud.title) API key."
        case .localServer:
            settings.settings.localServer.isConfigured ? nil : "Clean, Formal and Translate need a local server and model."
        case .apple:
            localModels.appleAvailability == .available ? nil : "Apple Intelligence isn't available on this Mac yet."
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

                ModeRow(
                    mode: mode,
                    provider: provider,
                    isLocked: mode.isCloud && !pro.allows(.aiModes),
                    settings: settings,
                    state: state,
                )
            }
        } footer: {
            if let setupNote {
                Text(setupNote)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)

                Button("Set Up…") { state.selection = .aiModels }
            }
        }

        SettingsSection("Translation", subtitle: translationNote) {
            PickerRow("Translate into", selection: translationTarget, current: settings.settings.translation.target.displayName) {
                ForEach(Self.languagesByName, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }
            RowDivider()
            PickerRow(
                "Two-way with",
                selection: twoWayLanguage,
                current: settings.settings.translation.twoWayLanguage?.displayName ?? String(localized: "Off"),
            ) {
                Text("Off").tag(Language?.none)
                Divider()
                ForEach(Self.languagesByName.filter { $0 != settings.settings.translation.target }, id: \.self) { language in
                    Text(language.displayName).tag(Language?.some(language))
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
                        .rowTransition()
                }

                AppModeRow(bundleIdentifier: bundleIdentifier, settings: settings)
                    .rowTransition()
            }
        } footer: {
            Button("Add App…", action: addApp)
        }
        .animation(Motion.layout, value: appIdentifiers)

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
        panel.prompt = String(localized: "Add")

        guard panel.runModal() == .OK, let url = panel.url,
              let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else { return }

        settings.settings.appModes.set(settings.settings.mode, for: bundleIdentifier)
    }
}

private struct ModeRow: View {
    let mode: Mode
    let provider: ModelProvider
    let isLocked: Bool

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
                if isLocked {
                    state.selection = .pro
                } else {
                    settings.settings.mode = mode
                }
            } label: {
                HStack(spacing: 0) {
                    ModeLabel(mode: mode, provider: provider, isCustomized: isCustomized)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if isLocked {
                Badge("Pro", tint: .purple)
            } else if mode.isCloud {
                InstructionsButton(mode: mode, provider: provider, settings: settings, state: state)
            }

            ZStack {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.sectionTitle)
                        .foregroundStyle(.tint)
                        .transition(.pop)
                }
            }
            .frame(width: 14)
            .animation(Motion.feedback, value: isSelected)
            .accessibilityHidden(true)
        }
        .settingsRowPadding()
    }
}

private struct ModeLabel: View {
    let mode: Mode
    let provider: ModelProvider
    let isCustomized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(mode.title)
                    .font(.rowTitle)

                if mode.isCloud {
                    Image(systemName: provider.isCloud ? "cloud" : "cpu")
                        .font(.glyph)
                        .foregroundStyle(.secondary)
                        .help(provider
                            .isCloud ? Text("Sends the recognized text to \(provider.title)") :
                            Text("Runs on this Mac with \(provider.title)"))
                }

                if isCustomized {
                    Badge("Edited")
                        .transition(.pop)
                }
            }

            Text(mode.summary)
                .font(.rowDetail)
                .foregroundStyle(.secondary)
        }
        .animation(Motion.feedback, value: isCustomized)
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
