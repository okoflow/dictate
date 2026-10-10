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
        SettingsSection(.verbatim(provider.title), subtitle: "Your own key; the text, never audio, goes to \(company).") {
            APIKeyRows(apiKey: apiKey, provider: provider)
            RowDivider()
            LinkRow(title: "Get an API key", url: Self.consoles[provider])
        } accessory: {
            InUseAccessory(isInUse: settings.settings.modelProvider == .cloud(provider)) {
                settings.settings.modelProvider = .cloud(provider)
            }
        }
        .animation(Motion.layout, value: apiKey.isSet)
    }
}

private struct APIKeyRows: View {
    @Bindable var apiKey: APIKeyModel

    let provider: CloudProvider

    private var prompt: LocalizedStringKey {
        if apiKey.isSet {
            return "Replace the key"
        }

        return switch provider {
        case .claude: .verbatim("sk-ant-…")
        case .openAI: .verbatim("sk-proj-…")
        }
    }

    var body: some View {
        if apiKey.isSet {
            SettingsRow("Key saved", description: "Kept in the Keychain.") {
                Button("Remove", role: .destructive) { apiKey.remove() }
            }
            .rowTransition()
            RowDivider()
                .rowTransition()
        }

        HStack(spacing: Metrics.controlSpacing) {
            InputField(prompt, text: $apiKey.draft, isSecure: true)

            Button("Save") { apiKey.saveDraft() }
                .disabled(!apiKey.canSaveDraft)
        }
        .settingsRowPadding()
    }
}
