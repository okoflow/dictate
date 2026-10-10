import DictateCore
import SwiftUI

struct CloudSettingsPane: View {
    private static let consoles: PerProvider<URL> = PerProvider(
        claude: URL(literal: "https://console.anthropic.com/settings/keys"),
        openAI: URL(literal: "https://platform.openai.com/settings/organization/api-keys"),
    )

    @Bindable var settings: SettingsModel

    let apiKeys: PerProvider<APIKeyModel>

    private var provider: CloudProvider {
        settings.settings.cloudProvider
    }

    var body: some View {
        SettingsSection("Provider", subtitle: "Clean, Formal and Translate send the text, never audio.") {
            SettingsRow("Rewrite with") {
                SegmentedPicker(
                    "Rewrite with",
                    selection: $settings.settings.cloudProvider,
                    options: CloudProvider.allCases,
                    label: \.title,
                )
            }
        }

        SettingsSection("API key", subtitle: "Your own \(provider.title) key, kept in the Keychain.") {
            APIKeyRows(apiKey: apiKeys[provider], provider: provider)
        } footer: {
            Link(destination: Self.consoles[provider]) {
                HStack(spacing: 5) {
                    Text("Get a \(provider.title) Key")

                    Image(systemName: "arrow.up.right")
                        .font(.glyph)
                }
            }
        }
        .animation(.snappy(duration: 0.2), value: apiKeys[provider].isSet)
    }
}

private struct APIKeyRows: View {
    @Bindable var apiKey: APIKeyModel

    let provider: CloudProvider

    private var prompt: String {
        if apiKey.isSet {
            return "Replace the key"
        }

        return switch provider {
        case .claude: "sk-ant-…"
        case .openAI: "sk-proj-…"
        }
    }

    var body: some View {
        if apiKey.isSet {
            SettingsRow("Key saved", description: "Cloud modes are ready to use.") {
                Button("Remove", role: .destructive) { apiKey.remove() }
            }
            RowDivider()
        }

        HStack(spacing: Metrics.controlSpacing) {
            InputField(prompt, text: $apiKey.draft, isSecure: true)

            Button("Save") { apiKey.saveDraft() }
                .disabled(!apiKey.canSaveDraft)
                .keyboardShortcut(.defaultAction)
        }
        .settingsRowPadding()
    }
}
