import AppKit
import DictateCore
import SwiftUI

struct LicenseSection: View {
    @Bindable var pro: ProModel

    private var problem: LocalizedStringKey? {
        switch pro.activationProblem {
        case .unreadable: "That doesn't look like a Dictate license key."
        case .invalid: "This license key isn't valid."
        case nil: nil
        }
    }

    var body: some View {
        if let license = pro.license {
            SettingsSection("License") {
                SettingsRow(.verbatim(license.name ?? license.email), description: .verbatim(license.email)) {
                    Button("Remove License…", role: .destructive, action: confirmRemoval)
                }
            }
        } else {
            SettingsSection("License", subtitle: "Bought Pro? Paste the key from your receipt email.") {
                SettingsRow("License key", description: problem) {
                    InputField(.verbatim("DCT1…"), text: $pro.draft)
                        .frame(width: 220)
                        .onChange(of: pro.draft) { pro.clearProblem() }

                    Button("Activate") { pro.activate(pro.draft) }
                        .buttonStyle(PushButtonStyle(isProminent: true))
                        .fixedSize()
                        .disabled(pro.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func confirmRemoval() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Remove the license from this Mac?")
        alert.informativeText = String(localized: "Pro features stop working here until you enter the key again.")
        alert.addButton(withTitle: String(localized: "Remove License"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.buttons.first?.hasDestructiveAction = true

        if alert.runModal() == .alertFirstButtonReturn {
            pro.deactivate()
        }
    }
}
