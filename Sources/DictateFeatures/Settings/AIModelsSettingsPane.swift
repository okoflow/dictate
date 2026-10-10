import DictateCore
import SwiftUI

struct AIModelsSettingsPane: View {
    private static let consoles: PerProvider<URL> = PerProvider(
        claude: URL(literal: "https://console.anthropic.com/settings/keys"),
        openAI: URL(literal: "https://platform.openai.com/settings/organization/api-keys"),
    )

    @Bindable var settings: SettingsModel

    let apiKeys: PerProvider<APIKeyModel>

    var body: some View {
        ForEach(CloudProvider.allCases, id: \.self) { provider in
            ProviderSection(
                provider: provider,
                apiKey: apiKeys[provider],
                console: Self.consoles[provider],
                isInUse: settings.settings.cloudProvider == provider,
            ) {
                settings.settings.cloudProvider = provider
            }
        }
    }
}

private struct ProviderSection: View {
    let provider: CloudProvider

    @Bindable var apiKey: APIKeyModel

    let console: URL
    let isInUse: Bool
    let use: () -> Void

    private var company: String {
        switch provider {
        case .claude: "Anthropic"
        case .openAI: "OpenAI"
        }
    }

    var body: some View {
        SettingsSection(provider.title, subtitle: "Clean, Formal and Translate send the text, never audio, to \(company).") {
            APIKeyRows(apiKey: apiKey, provider: provider)
            RowDivider()
            LinkRow(title: "Get an API key", url: console)
        } accessory: {
            if isInUse {
                Badge("In use", tint: .accentColor)
            } else {
                Button("Use", action: use)
            }
        }
        .animation(.snappy(duration: 0.2), value: apiKey.isSet)
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
            SettingsRow("Key saved", description: "Kept in the Keychain.") {
                Button("Remove", role: .destructive) { apiKey.remove() }
            }
            RowDivider()
        }

        HStack(spacing: Metrics.controlSpacing) {
            InputField(prompt, text: $apiKey.draft, isSecure: true)

            Button("Save") { apiKey.saveDraft() }
                .disabled(!apiKey.canSaveDraft)
        }
        .settingsRowPadding()
    }
}
