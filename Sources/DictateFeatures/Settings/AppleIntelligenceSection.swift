import DictateCore
import SwiftUI

struct AppleIntelligenceSection: View {
    @Bindable var settings: SettingsModel

    let localModels: LocalModelsModel

    private var status: LocalizedStringKey {
        switch localModels.appleAvailability {
        case .available: "Ready"
        case .notEnabled: "Turn on Apple Intelligence in System Settings"
        case .notReady: "Getting ready, try again in a few minutes"
        case .notSupported: "Not available on this Mac"
        case .needsNewerSystem: "Needs macOS 26 or later"
        }
    }

    var body: some View {
        SettingsSection(
            "Apple Intelligence",
            subtitle: "Apple's model on this Mac: free, offline, and the text never leaves it.",
        ) {
            SettingsRow(status, description: "Works best in English and the other languages Apple Intelligence supports.") {
                if localModels.appleAvailability == .available {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.success)
                }
            }
        } accessory: {
            InUseAccessory(
                isInUse: settings.settings.modelProvider == .apple,
                canUse: localModels.appleAvailability == .available,
            ) {
                settings.settings.modelProvider = .apple
            }
        }
        .onAppear { localModels.refreshApple() }
    }
}
