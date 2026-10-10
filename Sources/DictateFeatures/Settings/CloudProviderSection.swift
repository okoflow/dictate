import DictateCore
import SwiftUI

struct CloudProviderSection: View {
    private static let consoles: PerProvider<URL> = PerProvider(
        claude: URL(literal: "https://console.anthropic.com/settings/keys"),
        openAI: URL(literal: "https://platform.openai.com/settings/organization/api-keys"),
    )

    let provider: CloudProvider

    @Bindable var apiKey: APIKeyModel
    @Bindable var settings: SettingsModel

    private var company: String {
        switch provider {
        case .claude: "Anthropic"
        case .openAI: "OpenAI"
        }
    }

    var body: some View {
        SettingsSection(provider.title, subtitle: "Your own key; the text, never audio, goes to \(company).") {
            APIKeyRows(apiKey: apiKey, provider: provider)
            RowDivider()
            LinkRow(title: "Get an API key", url: Self.consoles[provider])
        } accessory: {
            InUseAccessory(isInUse: settings.settings.modelProvider == .cloud(provider)) {
                settings.settings.modelProvider = .cloud(provider)
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
